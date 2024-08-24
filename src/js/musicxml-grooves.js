#!/usr/bin/env node

/**
 * Parse MMA grooves and output a MusicXML file for each.
 */

const MUSICXML_VERSION = '4.0'
const DIVISIONS = 192
const INSTRUMENTS = 'src/xml/drums.xml'

import fs from 'fs'
import xmlFormat from 'xml-formatter'
import { parseArgs } from 'node:util'
import { createRequire } from 'node:module'
import { validateXMLWithXSD } from 'validate-with-xmllint'
import SaxonJS from 'saxon-js'

const require = createRequire(import.meta.url)
const { version } = require('../../package.json')

const options = {
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
  'validate': {
    type: 'boolean'
  },
  'grooves': {
    type: 'string',
    short: 'g'
  },
  'tempo': {
    type: 'string',
    default: '100'
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
Usage: musicxml-grooves v${version} [--output|-o /path/to/output] [--grooves|-g comma-separated-grooves] [--validate] [--version|-v] [--help|-h]

Converts MMA grooves to MusicXML.
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

const instruments = await SaxonJS.getResource({
  type: 'xml',
  encoding: 'utf8',
  location: INSTRUMENTS
})
.catch(error => {
  console.error(`[SaxonJS] ${error.code}: ${error.message}`)
  process.exit(1)
})

const grooves = 'grooves' in args ? args['grooves'].split(',').map(g => g.trim()) : []
for (const groove of JSON.parse(fs.readFileSync('build/grooves.json'))) {
  if (grooves.length > 0 && grooves.indexOf(groove.groove) < 0) continue

  console.error(`Generating ${groove.groove}...`)
  const musicxml = createMusicXML(groove)

  if ('validate' in args) {
    await validateXMLWithXSD(musicxml, 'src/xsd/musicxml.xsd')
    .catch(error => {
      console.error(`Failed to validate MusicXML: ${error.message}`)
    })
  }

  if ('output' in args) {
    fs.writeFileSync(path.join(args['output'], `${groove}.musicxml`), musicxml)
  }
  else {
    process.stdout.write(musicxml + '\n')
  }
}

function createMusicXML(groove) {
  const template = `
  <?xml version="1.0" encoding="utf-8" standalone="no"?>
  <!DOCTYPE score-partwise PUBLIC
      "-//Recordare//DTD MusicXML ${MUSICXML_VERSION} Partwise//EN"
      "http://www.musicxml.org/dtds/partwise.dtd">
  <score-partwise version="${MUSICXML_VERSION}">
    <work>
      <work-title>${groove.groove}</work-title>
    </work>
    <identification>
      <encoding>
        <software>musicxml-grooves ${version}</software>
        <encoding-date>${new Date().toJSON().slice(0, 10)}</encoding-date>
      </encoding>
    </identification>
    ${createPartList(groove)}
    ${createParts(groove)}
  </score-partwise>
  `.trim()

  return xmlFormat(template, { collapseContent: true })
}

function createPartList(groove) {
  // The parts are based on MuseScore's instruments.xml file. Each part corresponds to a drum <Instrument> element.
  // Each drum <Instrument> element has a number of <Drum> elements whose @pitch attribute corresponds to the MIDI drum voice.
  // It can happen that a MIDI drum voice is used by multiple instruments,
  // so we gather all matching instruments and later select those with the most voices.
  const tracks = groove.tracks.filter(t => t.track.startsWith('DRUM')).reverse()
  const partCandidates = tracks.reduce((partCandidates, track) => {
    track.candidateInstrumentIds = []
    const midi = track.midi[0] // In grooves.json, all MIDI notes are the same for each track
    const trackCandidates = SaxonJS.XPath.evaluate(`//instrument[drum[@midi="${midi}"]]/@id`, instruments, { resultForm: 'array' })
    if (!trackCandidates) {
      console.error(`No instrument found for MIDI drum voice ${track.voice[0]} (${midi})`)
      return partCandidates
    }
    trackCandidates.forEach(candidate => {
      const id = candidate.value
      track.candidateInstrumentIds.push(id)
      if (!(id in partCandidates)) {
        partCandidates[id] = { usage: 1 }
      }
      else {
        partCandidates[id].usage++
      }
    })

    return partCandidates
  }, {})

  // Now select the most used instrument for each drum track.
  // If there are multiple instruments with the same usage, we pick the one already used by another track.
  // Otherwise, we pick the instrument with the least pitches.
  const parts = tracks.reduce((parts, track) => {
    track.candidateInstrumentIds = track.candidateInstrumentIds.sort((a, b) => {
      if (partCandidates[b].usage === partCandidates[a].usage) {
        if (a in parts) return -1
        if (b in parts) return 1
        return
          SaxonJS.XPath.evaluate(`count(//instrument[@id="${a}"]/drum)`, instruments) -
          SaxonJS.XPath.evaluate(`count(//instrument[@id="${b}"]/drum)`, instruments)
      }
      else {
        return partCandidates[b].usage - partCandidates[a].usage
      }
    })
    const instrumentId = track.candidateInstrumentIds[0]
    if (instrumentId && !(instrumentId in parts)) {
      parts[instrumentId] = createPartListEntry(groove, instrumentId, Object.keys(parts).length + 1)
    }
    return parts
  }, {})

  return `
  <part-list>
    ${Object.values(parts).join('')}
  </part-list>
  `.trim()
}

function createParts(groove) {
  const parts = groove.tracks
    .filter(t => t.track.startsWith('DRUM'))
    .reverse()
    .reduce((parts, track) => {
      const partId = track.partId
      if (!(partId in parts)) {
        parts[partId] = []
      }
      parts[partId].push(track)
      return parts
    }, {})

  return Object.keys(parts).map((partId) => {
    return `
      <part id="P${partId}">
        ${createPartEntry(groove, parts[partId])}
      </part>
    `.trim()
  }).join('')
}

function createPartListEntry(groove, instrumentId, partId) {
  const instrument = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]`, instruments)

  // Iterate on all instrument Drum entries, create a score-instrument and a midi-instrument for each.
  // Generate an score-instrument id which is the part id followed by the drum pitch.
  // This score-instrument id is used in the part's notes to reference the corresponding instrument.
  // Update each groove track with its score-instrument id.
  const entries = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum`, instruments, { resultForm: 'array' })
  .reduce((entries, drum) => {
    const scoreInstrumentId = `P${partId}-I${drum.getAttribute('midi')}`
    const track = groove.tracks.find(t => t.midi[0].toString() === drum.getAttribute('midi'))
    if (track) {
      track.partId = partId
      track.scoreInstrumentId = scoreInstrumentId
    }
    entries.push({
      scoreInstrument: `
        <score-instrument id="${scoreInstrumentId}">
          <instrument-name>${drum.getElementsByTagName('instrument-name')[0].textContent}</instrument-name>
          <instrument-sound>${drum.getElementsByTagName('instrument-sound')[0].textContent}</instrument-sound>
        </score-instrument>
      `.trim(),
      midiInstrument: `
        <midi-instrument id="${scoreInstrumentId}">
          <midi-channel>10</midi-channel>
          <midi-unpitched>${parseInt(drum.getAttribute('midi')) + 1}</midi-unpitched>
        </midi-instrument>
      `.trim()
    })
    return entries
  }, [])

  return `
    <score-part id="P${partId}">
      <part-name>${instrument.getElementsByTagName('part-name')[0].textContent}</part-name>
      <part-abbreviation>${instrument.getElementsByTagName('part-abbreviation')[0].textContent}</part-name>
      ${entries.map(e => e.scoreInstrument).join('\n')}
      ${entries.map(e => e.midiInstrument).join('\n')}
    </score-part>
  `.trim()
}

function createPartEntry(groove, part) {
  // Create part measures by combining the notes of all tracks in the part.
  // The notes are sorted by time and then by pitch.
  const instrumentId = part[0].candidateInstrumentIds[0]
  const instrument = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]`, instruments)
  const beats = parseInt(groove.timeSignature.split('/')[0])
  const beatType = parseInt(groove.timeSignature.split('/')[1])
  return part[0].sequence.map((measure, i) => {
    const attributes = i > 0 ? '' : `
      <attributes>
        <divisions>${DIVISIONS}</divisions>
        <time>
          <beats>${beats}</beats>
          <beat-type>${beatType}</beat-type>
        </time>
        <clef>
          <sign>percussion</sign>
          <line>${instrument.getElementsByTagName('line')[0].textContent}</line>
        </clef>
      </attributes>
    `.trim()
    const notes = part.reduce((notes, track) => {
      return notes.concat(track.sequence[i].split(';').map(note => {
        const p = note.split(/\s+/).filter(p => !!p)
        return p[0] === 'z' ? {
          midi: undefined
        } : {
          midi: track.midi[0],
          onset: parseFloat(p[0]),
          duration: undefined,
          velocity: parseInt(p[2]),
          partId: track.partId,
        }
      }).filter(n => !!n.midi))
    }, []).sort((n1, n2) => {
      return n1.onset - n2.onset
    }).reduce((notes, note, index, source) => {
      const onset = notes.length > 0 ? notes[notes.length-1].onset : 1
      const duration = note.onset - onset;
      if (duration > 0) {
        if (notes.length === 0) {
          notes.push({
            midi: undefined,
            onset,
            duration
          })
        }
        else {
          notes.filter(note => note.onset === onset).forEach(note => { note.duration = duration })
        }
      }
      notes.push(note)
      if (index === source.length - 1) {
        notes.filter(note => note.duration === undefined).forEach(note => { note.duration = beats + 1 - note.onset })
      }
      return notes
    }, []).map((note, index, notes) => {
      const drum = note.midi ? SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum[@midi="${note.midi}"]`, instruments) : undefined
      const pitch = drum ? `
        <unpitched>
          <display-step>${drum.getElementsByTagName('display-step')[0].textContent}</display-step>
          <display-octave>${drum.getElementsByTagName('display-octave')[0].textContent}</display-octave>
        </unpitched>
      `.trim() : '<rest/>'
      const chord = (index > 0 && notes[index - 1].onset === note.onset) ? '<chord/>' : ''
      const duration = DIVISIONS * note.duration
      return `
        <note>
          ${chord}
          ${pitch}
          <duration>${duration}</duration>
          ${getNoteType(note, index, notes, beatType)}
          <instrument id="P${note.partId}-I${note.midi}"/>
          <stem>${drum.getElementsByTagName('stem')[0].textContent}</stem>
          <notehead>${drum.getElementsByTagName('notehead')[0].textContent}</notehead>
        </note>
      `.trim()
    }).join('')
    return `
      <measure number="${i + 1}">
        ${attributes}
        ${notes}
      </measure>
    `.trim()
  }).join('')
}

function getNoteType(note, index, notes, beatType) {
  const types = {
    6: '256th',
    12: '128th',
    24: '64th',
    48: '32th',
    96: '16th',
    192: 'eighth',
    384: 'quarter',
    768: 'half',
    1536: 'whole',
  }
  const duration = note.duration * DIVISIONS * 8 / beatType
  if (duration in types) {
    return `<type>${types[duration]}</type>`
  }
  for (const [entry, type] of Object.entries(types).reverse()) {
    if (entry < duration) {
      const dots = Math.log(2 - duration / entry) / Math.log(0.5)
      if (Number.isInteger(dots)) {
        return `<type>${types[entry]}</type>${[...Array(dots)].map(_ => '<dot/>')}`
      }
    }
  }
  console.error(`Could not find note duration ${note.duration} = ${entry} in duration map.`)
  return '';
}
