#!/usr/bin/env node

/**
 * Parse a MIDI file and output a MeasureTimemap, which is a JSON array of the form:
 *
 * [
 *    {
 *       measure: number,
 *       timestamp: number
 *    },
 *    ...
 * ]
 *
 * measure is an integer starting at 0
 * timestamp is a real-valued time offset specified in millisecs starting at 0
 */

import { parseMidi } from 'midi-file'
import process from 'process'
import fs from 'fs'

const input = process.argv[2]
if (!input || !fs.existsSync(input)) {
  console.error(`Missing input file ${input}`)
  process.exit(1)
}

const midi = parseMidi(fs.readFileSync(input))
const timemap = []
let microsecondsPerQuarter = 500000 // 60,000,000 microseconds per minute / 120 beats per minute
let offset = 0
midi.tracks[0].forEach((event) => {
  if (event.type === 'setTempo') {
    microsecondsPerQuarter = Number(event.microsecondsPerBeat)
  }
  offset += Number(event.deltaTime)
  if (event.type === 'marker') {
    const marker = event.text.split(':')
    if (
      marker[0].localeCompare('Measure', undefined, {
        sensitivity: 'base',
      }) === 0
    ) {
      const measure = Number(marker[1])
      const timestamp = Math.round(offset * (microsecondsPerQuarter / midi.header.ticksPerBeat)) / 1000
      timemap.push({
        measure,
        timestamp
      })
    }
  }
})

const output = JSON.stringify(timemap)
if (process.argv[3]) {
    fs.writeFileSync(process.argv[3], Buffer.from(output))
}
else {
    process.stdout.write(output)
}
