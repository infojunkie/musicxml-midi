#!/usr/bin/env node

/**
 * Scrape MusicXML examples from the official site
 * https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/
 */

const URL_EXAMPLES_ROOT = 'https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/'
const MUSICXML_VERSION = '4.0'

import fetch from 'node-fetch'
import * as cheerio from 'cheerio'
import xmlFormat from 'xml-formatter';
import fs from 'fs'
import process from 'process'
import path from 'path'
import { parseArgs } from 'node:util'
import { createRequire } from 'node:module'
import { validateXMLWithXSD } from 'validate-with-xmllint'

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
  },
  'example': {
    type: 'string',
    short: 'e'
  },
  'validate': {
    type: 'boolean'
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
Usage: musicxml-examples v${version} [--output|-o /path/to/output] [--example|-e example-slug] [--xml|-x] [--validate] [--version|-v] [--help|-h]

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
if (output !== '' && !fs.existsSync(output)) {
  console.error(`Missing output dir ${output}`)
  process.exit(1)
}

const response = await fetch(URL_EXAMPLES_ROOT)
const main = await response.text()
const $ = cheerio.load(main)
for (const example of $('body').find('a:has(img)')) {
  const href = $(example).prop('href')
  if ('example' in args && args['example'] !== href.replace('/', '')) continue
  console.error(`Extracting ${href}...`)
  await extractMusicXml(URL_EXAMPLES_ROOT + href, href.replace('/', ''))
}

async function extractMusicXml(page, slug) {
  const response = await fetch(page)
  const body = await response.text()
  const $ = cheerio.load(body)
  const musicxml = scaffoldMusicXml($('.xmlmarkup').text())

  if ('validate' in args) {
    await validateXMLWithXSD(musicxml, 'src/xsd/musicxml.xsd')
    .catch(error => {
      console.error(`Failed to validate MusicXML: ${error.message}`)
    })
  }

  if (output !== '') {
    fs.writeFileSync(path.join(output, `${slug}.musicxml`), musicxml)
  }
  else {
    process.stdout.write(musicxml + '\n')
  }
}

function scaffoldMusicXml(xml) {
  if (!('xml' in args)) {
    return `<?xml version="1.0" encoding="utf-8"?>\n${xml}`
  }

  const template = `
  <?xml version="1.0" encoding="utf-8" standalone="no"?>
  <!DOCTYPE score-partwise PUBLIC
      "-//Recordare//DTD MusicXML ${MUSICXML_VERSION} Partwise//EN"
      "http://www.musicxml.org/dtds/partwise.dtd">
  <score-partwise version="${MUSICXML_VERSION}">
    <defaults>
      <system-layout optional-example="yes"/>
      <staff-layout optional-example="yes"/>
      <appearance optional-example="yes"/>
    </defaults>
    <credit optional-example="yes"/>
    <part-list>
      <part-group optional-example="yes"/>
      <score-part id="P1">
        <part-name>placeholder</part-name>
      </score-part>
    </part-list>
    <part id="P1">
      <measure number="1">
        <direction optional-example="yes">
          <direction-type optional-example="yes">
            <dynamics optional-example="yes"/>
            <metronome optional-example="yes"/>
            <scordatura optional-example="yes"/>
            <accordion-registration optional-example="yes"/>
          </direction-type>
        </direction>
        <attributes>
          <divisions>1</divisions>
          <key>
            <fifths>0</fifths>
          </key>
          <time>
            <beats>4</beats>
            <beat-type>4</beat-type>
            <interchangeable optional-example="yes">
              <time-relation optional-example="yes"/>
            </interchangeable>
          </time>
          <clef>
            <sign>G</sign>
            <line>2</line>
          </clef>
          <staff-details optional-example="yes"/>
          <measure-style optional-example="yes"/>
        </attributes>
        <harmony>
          <root>
            <root-step>C</root-step>
          </root>
          <kind use-symbols="yes">major-seventh</kind>
          <inversion optional-example="yes"/>
          <degree optional-example="yes"/>
          <frame optional-example="yes"/>
        </harmony>
        <figured-bass optional-example="yes"/>
        <note>
          <pitch>
            <step>C</step>
            <octave>4</octave>
          </pitch>
          <duration>4</duration>
          <type>whole</type>
          <notehead-text optional-example="yes"/>
          <notations>
            <technical optional-example="yes"/>
          </notations>
          <lyric optional-example="yes"/>
        </note>
        <barline optional-example="yes"/>
        <print>
          <part-name-display optional-example="yes"/>
          <part-abbreviation-display optional-example="yes"/>
        </print>
      </measure>
    </part>
  </score-partwise>
  `.trim()

  // Insert the example fragment into the fully-formed template.
  // - Find the example's root element in the template
  // - Replace it with the full example fragment
  // - Remove optional-example attribute from parents of the example fragment
  // - Remove all elements that still include attribute optional-example="yes"
  const src = cheerio.load(xml, { xml: true })
  const core = src.root().children().first().prop('nodeName')
  const dst = cheerio.load(template, { xml: { xmlMode: true, lowerCaseTags: true, lowerCaseAttributeNames : true }})
  if (dst(core).length === 0) {
    console.error(`${core} element not found in template. Returning verbatim XML.`)
    return `<?xml version="1.0" encoding="utf-8"?>\n${xml}`
  }
  dst(core).replaceWith(src.root())
  dst(src.root()).parents().removeAttr('optional-example')
  dst('[optional-example="yes"]').remove()
  return xmlFormat(dst.html(), { collapseContent: true })
}
