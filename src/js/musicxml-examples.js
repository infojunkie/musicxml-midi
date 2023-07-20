#!/usr/bin/env node

/**
 * Scrape MusicXML examples from the official site
 * https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/
 */

const URL_EXAMPLES_ROOT = 'https://www.w3.org/2021/06/musicxml40/musicxml-reference/examples/'

import fetch from 'node-fetch'
import * as cheerio from 'cheerio'
import fs from 'fs'
import process from 'process'
import path from 'path'

const output = process.argv[2] || ''
if (output != '' && !fs.existsSync(output)) {
  console.error(`Missing output dir ${output}`)
  process.exit(1)
}

async function extractMusicXML(page, title) {
  const response = await fetch(page)
  const body = await response.text()
  const $ = cheerio.load(body)
  const musicxml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" + $('.xmlmarkup').text()
  fs.writeFileSync(path.join(output, `${title}.musicxml`), musicxml)
}

const response = await fetch(URL_EXAMPLES_ROOT)
const main = await response.text()
const $ = cheerio.load(main)
for (const example of $('body').find('a:has(img)')) {
  const href = $(example).prop('href')
  console.log(`Extracting ${href}...`)
  await extractMusicXML(URL_EXAMPLES_ROOT + href, href.replace('/', ''))
}
