#!/usr/bin/env node
import { parseMidi } from "midi-file"
import process from 'process'
import fs from 'fs'

const input = process.argv[2]
if (!input || !fs.existsSync(input)) {
    console.error(`Missing input file ${input}`)
    process.exit(1)
}

const output = JSON.stringify(parseMidi(fs.readFileSync(input)))
if (process.argv[3]) {
    fs.writeFileSync(process.argv[3], Buffer.from(output))
}
else {
    process.stdout.write(output)
}
