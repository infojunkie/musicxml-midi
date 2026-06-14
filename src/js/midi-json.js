#!/usr/bin/env node

/**
 * Parse a MIDI file into JSON and back. Typically used to manipulate the tracks via jq or equivalent tool.
 *
 * Usage: midi-json.js < source.mid | jq [..] | midi-json.js [-r|--running|--no-running] > target.mid
 */

import { parseMidi, writeMidi } from 'midi-file'
import fs from 'fs'
import process from 'process'
import { buffer } from 'stream/consumers'
import { parseArgs } from 'util'

const {
  values
} = parseArgs({
  options: {
    running: {
      type: 'boolean',
      short: 'r',
      default: false
    }
  },
  allowNegative: true,
  allowPositionals: false
})

const input = await buffer(process.stdin)
try {
  const midi = JSON.parse(input)
  const buffer = Buffer.from(writeMidi(midi, { useByte9ForNoteOff: values.running, running: values.running }))
  fs.writeFileSync(1, buffer)
}
catch {
  const midi = parseMidi(input)
  const buffer = Buffer.from(JSON.stringify(midi))
  process.stdout.write(buffer)
}
