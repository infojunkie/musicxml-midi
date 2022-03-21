import compression from 'compression'
import express from 'express'
import SaxonJS from 'saxon-js'
import fileUpload from 'express-fileupload'
import util from 'util'
import temp from 'temp'
import morgan from 'morgan'

// Import package.json the "easy" way.
// https://www.stefanjudis.com/snippets/how-to-import-json-files-in-es-modules-node-js/
import { createRequire } from 'module'
const require = createRequire(import.meta.url)
const { name, description, version, author } = require('./package.json')

// A Promise-based version of exec.
// https://nodejs.org/api/child_process.html#child_process_child_process_exec_command_options_callback
const exec = util.promisify(require('child_process').exec);

const ERROR_BAD_PARAM = 'Expecting a POST multipart/form-data request with `musicxml` field containing a valid MusicXML file upload.'
const ERROR_MMA_CRASH = 'Conversion failed unexpectedly. Please contact the server operator.'

const app = express()
app.use(compression())
app.use(fileUpload({
  useTempFiles : true,
  tempFileDir : '/tmp/',
  preserveExtension: true,
}))
app.use(morgan('combined'))

app.get('/', (req, res) => res.json({ name, version, description, author }))

app.get('/convert', (req, res) => res.status(400).send(ERROR_BAD_PARAM))

app.post('/convert', async (req, res, next) => {
  if (!req.files || !('musicxml' in req.files) ) {
    return res.status(400).json(ERROR_BAD_PARAM)
  }

  let saxonResult = null;
  try {
    saxonResult = await SaxonJS.transform({
      stylesheetFileName: 'musicxml-mma.sef.json',
      sourceFileName: req.files.musicxml.tempFilePath,
      destination: 'serialized'
    }, 'async')
  }
  catch (error) {
    console.error(`[SaxonJS] ${error.code}: ${error.message}`)
    return res.status(400).send(ERROR_BAD_PARAM)
  }

  const tempFile = temp.path({ suffix: '.mid' })
  let execResult = null
  try {
    execResult = await exec('echo "$mma" | ${MMA_HOME:-../mma}/mma.py -f "$temp" -', {
      env: { ...process.env, 'mma': saxonResult.principalResult, 'temp': tempFile }
    })
  }
  catch (error) {
    console.error(`[MMA] ${error.stdout.replace(/^\s+|\s+$/g, '')}`)
    return res.status(500).send(ERROR_MMA_CRASH)
  }

  console.log(execResult.stdout.replace(/^\s+|\s+$/g, ''))
  return res.status(200).sendFile(tempFile)
})

const port = process.env.PORT || 3000
app.listen(port, () => console.log(`${name} v${version} listening at http://localhost:${port}`))
