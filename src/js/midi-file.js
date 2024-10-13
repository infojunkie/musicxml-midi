#!/usr/bin/env node

/**
 * Parse a MIDI file into JSON and back.
 *
 * Usage: midi-file.js < source.mid | jq [..] | midi-file.js > target.mid
 */

import { parseMidi, writeMidi } from 'midi-file'
import fs from 'fs'
import process from 'process'
import { buffer } from 'stream/consumers'

const input = await buffer(process.stdin)
try {
  const midi = JSON.parse(input)
  const buffer = Buffer.from(writeMidi(midi))
  fs.writeFileSync(1, buffer)
}
catch {
  const midi = parseMidi(input)
  const buffer = Buffer.from(JSON.stringify(midi))
  process.stdout.write(buffer)
}
