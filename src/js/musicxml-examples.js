#!/usr/bin/env node

/**
 * Scrape MusicXML examples from the official site
 * https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/
 */

const URL_EXAMPLES_ROOT = 'https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/'
const MUSICXML_VERSION = '4.0'

import fetch from 'node-fetch'
import * as cheerio from 'cheerio'
import xmlFormat from 'xml-formatter'
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
  'examples': {
    type: 'string',
    short: 'e'
  },
  'validate': {
    type: 'boolean'
  },
  'source': {
    type: 'string',
    short: 's'
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

if (!('source' in args)) {
  args['source'] = URL_EXAMPLES_ROOT
}

if ('help' in args) {
  console.log(`
Usage: musicxml-examples v${version} [--output|-o /path/to/output] [--examples|-e comma-separated-example-slugs] [--source|-s url/or/path/to/examples/] [--xml|-x] [--validate] [--version|-v] [--help|-h]

Extracts MusicXML examples from ${args['source']}.
Use --xml to recreate a valid MusicXML structure around examples that lack it.
`.trim())
  process.exit(0)
}

if ('version' in args) {
  console.log(`musicxml-examples v${version}`)
  process.exit(0)
}

if ('output' in args && !fs.existsSync(args['output'])) {
  console.error(`Missing output dir ${args['output']}`)
  process.exit(1)
}

const examples = 'examples' in args ? args['examples'].split(',').map(e => e.trim()) : []
const main = await fetchPage(args['source'])
const $ = cheerio.load(main)
for (const example of $('body').find('a:has(img)')) {
  const href = $(example).prop('href')
  const slug = href.replace('/', '')
  if (examples.length > 0 && examples.indexOf(slug) < 0) continue

  console.error(`Extracting ${href}...`)
  await extractMusicXml(args['source'] + href, slug)
}

async function extractMusicXml(page, slug) {
  const body = await fetchPage(page)
  const $ = cheerio.load(body)
  const musicxml = scaffoldMusicXml($('.xmlmarkup').text())

  if ('validate' in args) {
    await validateXMLWithXSD(musicxml, 'src/xsd/musicxml.xsd')
    .catch(error => {
      console.error(`Failed to validate MusicXML: ${error.message}`)
    })
  }

  if ('output' in args) {
    fs.writeFileSync(path.join(args['output'], `${slug}.musicxml`), musicxml)
  }
  else {
    process.stdout.write(musicxml + '\n')
  }
}

async function fetchPage(url) {
  if (/^http/.test(url)) {
    const response = await fetch(url, {
      "headers": {
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "accept-language": "en",
        "cache-control": "no-cache",
        "pragma": "no-cache",
        "priority": "u=0, i",
        "sec-ch-ua": "\"Not)A;Brand\";v=\"99\", \"Google Chrome\";v=\"127\", \"Chromium\";v=\"127\"",
        "sec-ch-ua-arch": "\"x86\"",
        "sec-ch-ua-bitness": "\"64\"",
        "sec-ch-ua-full-version": "\"127.0.6533.72\"",
        "sec-ch-ua-full-version-list": "\"Not)A;Brand\";v=\"99.0.0.0\", \"Google Chrome\";v=\"127.0.6533.72\", \"Chromium\";v=\"127.0.6533.72\"",
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-model": "\"\"",
        "sec-ch-ua-platform": "\"Linux\"",
        "sec-ch-ua-platform-version": "\"6.9.3\"",
        "sec-fetch-dest": "document",
        "sec-fetch-mode": "navigate",
        "sec-fetch-site": "same-origin",
        "sec-fetch-user": "?1",
        "upgrade-insecure-requests": "1",
        "Referer": "https://www.w3.org/2021/06/musicxml40/musicxml-reference/",
        "Referrer-Policy": "same-origin"
      },
      "body": null,
      "method": "GET"
    });
    return await response.text()
  }
  return fs.readFileSync(path.join(url, 'index.html'), { encoding: 'utf-8' })
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
