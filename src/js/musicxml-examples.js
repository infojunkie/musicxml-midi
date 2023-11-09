#!/usr/bin/env node

/**
 * Scrape MusicXML examples from the official site
 * https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/
 */

const URL_EXAMPLES_ROOT = 'https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/'
const MUSICXML_VERSION = '4.0'

import fetch from 'node-fetch'
import * as cheerio from 'cheerio'
import fs from 'fs'
import process from 'process'
import path from 'path'
import { parseArgs } from 'node:util'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const { version } = require('../../package.json')

const options = {
  'xml': {
    type: 'boolean',
    short: 'x',
  },
  'output': {
    type: 'string',
    short: 'o'
  },
  'help': {
    type: 'boolean',
    short: 'h'
  },
  'version': {
    type: 'boolean',
    short: 'v'
  }
}
const { values: args } = (function() {
  try {
    return parseArgs({ options, allowPositionals: false })
  }
  catch (e) {
    console.error(e.message)
    process.exit(1)
  }
})()

if ('help' in args) {
  console.log(`
Usage: musicxml-examples v${version} [--output|-o /path/to/output] [--xml|-x] [--version|-v] [--help|-h]

Extracts MusicXML examples from ${URL_EXAMPLES_ROOT}.
Use --xml to recreate a valid MusicXML structure around examples that lack it.
`.trim())
  process.exit(0)
}

if ('version' in args) {
  console.log(`musicxml-examples v${version}`)
  process.exit(0)
}

const output = args['output'] || ''
if (output != '' && !fs.existsSync(output)) {
  console.error(`Missing output dir ${output}`)
  process.exit(1)
}

async function extractMusicXml(page, title) {
  const response = await fetch(page)
  const body = await response.text()
  const $ = cheerio.load(body)
  const musicxml = scaffoldMusicXml($('.xmlmarkup').text(), title)
  fs.writeFileSync(path.join(output, `${title}.musicxml`), musicxml)
}

const xmlHeader = `
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
    "-//Recordare//DTD MusicXML ${MUSICXML_VERSION} Partwise//EN"
    "http://www.musicxml.org/dtds/partwise.dtd">
`.trim()

const xmlTemplate = `
<score-partwise version="${MUSICXML_VERSION}">
  <part-list>
    <score-part id="P1">
      <part-name>Music</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key>
          <fifths>0</fifths>
        </key>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef>
          <sign>G</sign>
          <line>2</line>
        </clef>
      </attributes>
      <note>
        <pitch>
          <step>C</step>
          <octave>4</octave>
        </pitch>
        <duration>4</duration>
        <type>whole</type>
      </note>
    </measure>
  </part>
</score-partwise>
`.trim()

function scaffoldMusicXml(xml, title) {
  if (!('xml' in args)) {
    return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" + xml
  }

  // Compare the incoming XML with the template above,
  // Filling in successive levels from the template if they don't appear in the source.
  const src = cheerio.load(xml, { xmlMode: true })
  const tmp = cheerio.load(xmlTemplate, { xmlMode: true })

  return xmlHeader + "\n" + src.html()
}

const response = await fetch(URL_EXAMPLES_ROOT)
const main = await response.text()
const $ = cheerio.load(main)
for (const example of $('body').find('a:has(img)')) {
  const href = $(example).prop('href')
  console.log(`Extracting ${href}...`)
  await extractMusicXml(URL_EXAMPLES_ROOT + href, href.replace('/', ''))
}
