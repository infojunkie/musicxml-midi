#!/usr/bin/env node

// Convert an iReal Pro playlist into a series of MusicXML / MMA / MIDI files.

import ireal from 'ireal-musicxml'
import glob from 'glob'
import fs from 'fs'
import SaxonJS from 'saxon-js'
import util from 'util'
import sanitize from 'sanitize-filename'
import path from 'path'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const execp = util.promisify(require('child_process').exec);
const globp = util.promisify(glob)

class AbortChainError extends Error {
  static chain(handler) {
    return function(error) {
      handler(error)
      throw new AbortChainError()
    }
  }
}

const input = process.argv[2] || 'test/data/*.txt'
const output = process.argv[3] || 'test/data/output'

const files = await globp(input, null)
for await (const file of files) {
  const playlist = await ireal.convert(fs.readFileSync(file))
  .catch(AbortChainError.chain(error => {
    console.error(`[iReal-MusicXML] [${file}] ${error.message}`)
  }))
  for await (const song of playlist.songs) {
    try {
      const outFile = path.join(output, `${sanitize(song.title)}`)
      const midFile = `${outFile}.mid`
      if (fs.existsSync(midFile)) continue
      await fs.promises.writeFile(`${outFile}.musicxml`, song.musicXml)
      const saxonResult = await SaxonJS.transform({
        stylesheetFileName: 'musicxml-mma.sef.json',
        sourceText: song.musicXml,
        destination: 'serialized'
      }, 'async')
      .catch(AbortChainError.chain(error => {
        console.error(`[SaxonJS] [${file}/${song.title}] ${error.code} at ${error.xsltModule}:${error.xsltLineNr}: ${error.message}`)
      }))
      await fs.promises.writeFile(`${outFile}.mma`, saxonResult.principalResult)
      const execResult = await execp('echo "$mma" | ${MMA_HOME:-../mma}/mma.py -II -f "$out" -', {
        env: { ...process.env, 'mma': saxonResult.principalResult, 'out': midFile }
      })
      .catch(AbortChainError.chain(error => {
        console.error(`[MMA] [${file}/${song.title}] ${error.stdout.replace(/^\s+|\s+$/g, '')}`)
      }))
    }
    catch {
      // Do nothing.
    }
  }
}
