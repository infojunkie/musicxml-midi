#!/usr/bin/env node

import compression from 'compression'
import express from 'express'
import SaxonJS from 'saxon-js'
import fileUpload from 'express-fileupload'
import util from 'util'
import morgan from 'morgan'
import crypto from 'crypto'
import { promises as fs, constants } from 'fs'
import { TextDecoder } from 'util'
import path from 'path'
import unzip from 'unzipit'
import { validateXMLWithXSD } from 'validate-with-xmllint'
import cors from 'cors'
import { fileURLToPath } from 'url'
import process from 'process'

// Ensure working directory is this script.
// https://stackoverflow.com/a/62892482/209184
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
process.chdir(path.join(__dirname, '..', '..'))

// Import package.json the "easy" way.
// https://www.stefanjudis.com/snippets/how-to-import-json-files-in-es-modules-node-js/
import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { name, description, version, author } = require('../../package.json')

// A Promise-based version of exec.
// https://nodejs.org/api/child_process.html#child_process_child_process_exec_command_options_callback
const exec = util.promisify(require('child_process').exec)

class AbortChainError extends Error {
  static chain(handler) {
    return function(error) {
      handler(error)
      throw new AbortChainError()
    }
  }
}

const LIMIT_FILE_SIZE = process.env.LIMIT_FILE_SIZE || 1 * 1024 * 1024
const ERROR_BAD_PARAM = 'Expecting a POST multipart/form-data request with `musicXml` field containing a valid MusicXML file.'
const ERROR_MMA_CRASH = 'Conversion failed unexpectedly. Please contact the server operator.'

export const app = express()
app.use(cors())
app.use(compression())
app.use(fileUpload({
  limits: {
    fileSize: LIMIT_FILE_SIZE,
  },
  abortOnLimit: true
}))
app.use(morgan('combined'))

app.get('/', (req, res) => res.json({ name, version, description, author }))

app.get('/grooves', (req, res) => res.status(200).sendFile(path.resolve('build/grooves.txt')))

app.get('/convert', (req, res) => res.status(400).send(ERROR_BAD_PARAM))

async function tryCompressedMusicXml(buffer) {
  try {
    const decoder = new TextDecoder()
    const { entries } = await unzip.unzip(new Uint8Array(buffer))

    // Extract rootfile from META-INF/container.xml.
    const containerBuffer = await entries['META-INF/container.xml'].arrayBuffer()
    const doc = await SaxonJS.getResource({
      type: 'xml',
      encoding: 'utf8',
      text: decoder.decode(containerBuffer)
    })
    const rootFile = SaxonJS.XPath.evaluate('string(//rootfile[1]/@full-path)', doc)
    const rootBuffer = await entries[rootFile].arrayBuffer()
    return decoder.decode(rootBuffer)
  }
  catch {
    return buffer.toString('utf8')
  }
}

app.post('/convert', async (req, res, next) => {
  if (!req.files || !('musicXml' in req.files) ) {
    return res.status(400).json(ERROR_BAD_PARAM)
  }

  // Assemble parameters.
  const params = {}
  if (req.body) {
    ['globalGroove'].forEach(param => {
      if (param in req.body) params[param] = req.body[param]
    })
  }

  // Check first in cache.
  const hash = crypto.createHash('sha256')
  hash.update(req.files.musicXml.data.toString('utf8') + JSON.stringify(params))
  const sig = hash.digest('hex')
  const cacheFile = path.resolve(path.join(process.env.CACHE_DIR || 'cache', `${sig}.mid`))
  try {
    await fs.access(cacheFile, constants.R_OK)
    res.status(200).sendFile(cacheFile)
    return
  }
  catch {
    // Could not access cache file: Keep going below to generate it.
  }

  try {
    const xml = await tryCompressedMusicXml(req.files.musicXml.data)
    await validateXMLWithXSD(xml, 'src/xsd/musicxml.xsd')
    .catch(AbortChainError.chain(error => {
      console.error(`[xmllint] ${error.message}`)
      res.status(400).send(ERROR_BAD_PARAM)
    }))
    const doc = await SaxonJS.getResource({
      type: 'xml',
      encoding: 'utf8',
      text: xml
    })
    .catch(AbortChainError.chain(error => {
      console.error(`[SaxonJS] ${error.code}: ${error.message}`)
      res.status(400).send(ERROR_BAD_PARAM)
    }))
    const title = SaxonJS.XPath.evaluate('//work/work-title/text()', doc)?.nodeValue || '(untitled)'
    console.info(`[SaxonJS] Transforming document '${title}'...`)
    const mma = await SaxonJS.transform({
      stylesheetFileName: 'build/musicxml-mma.sef.json',
      sourceNode: doc,
      destination: 'serialized',
      stylesheetParams: { useSef: true, ...params },
    }, 'async')
    .catch(AbortChainError.chain(error => {
      console.error(`[SaxonJS] ${error.code}: ${error.message}`)
      res.status(400).send(ERROR_BAD_PARAM)
    }))
    const execResult = await exec('echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -f "$out" -', {
      env: { ...process.env, 'mma': mma.principalResult, 'out': cacheFile }
    })
    .catch(AbortChainError.chain(error => {
      console.error(`[MMA] ${error.stdout.replace(/^\s+|\s+$/g, '')}`)
      res.status(500).send(ERROR_MMA_CRASH)
    }))
    console.info('[MMA] ' + execResult.stdout.replace(/^\s+|\s+$/g, ''))
    return res.status(200).sendFile(cacheFile)
  }
  catch {
    // Do nothing.
  }
})

const port = process.env.PORT || 3000
export const server = app.listen(port, () => console.log(`${name} v${version} listening at http://localhost:${port}`))
