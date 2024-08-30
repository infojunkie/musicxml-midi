#!/usr/bin/env node

/**
 * Parse MMA grooves and output a MusicXML file for each.
 */

const MUSICXML_VERSION = '4.0'
const DIVISIONS = 384
const DURATION_WHOLE = DIVISIONS*8/1
const DURATION_HALF = DIVISIONS*8/2
const DURATION_QUARTER = DIVISIONS*8/4
const DURATION_EIGHTH = DIVISIONS*8/8
const DURATION_16th = DIVISIONS*8/16
const DURATION_32nd = DIVISIONS*8/32
const DURATION_64th = DIVISIONS*8/64
const DURATION_128th = DIVISIONS*8/128
const DURATION_256th = DIVISIONS*8/256
const DURATION_512th = DIVISIONS*8/512
const DURATION_1024th = DIVISIONS*8/1024
const INSTRUMENTS = 'src/xml/drums.xml'

import fs from 'fs'
import xmlFormat from 'xml-formatter'
import { parseArgs } from 'node:util'
import { createRequire } from 'node:module'
import { validateXMLWithXSD } from 'validate-with-xmllint'
import SaxonJS from 'saxon-js'
import path from 'path'

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
    short: 't',
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
Usage: musicxml-grooves v${version} [--output|-o /path/to/output] [--grooves|-g comma-separated-grooves] [--tempo|-t beats-per-minute] [--validate] [--version|-v] [--help|-h]

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

  try {
    console.error(`Generating ${groove.groove}...`)
    const musicxml = createMusicXML(groove)

    if ('validate' in args) {
      await validateXMLWithXSD(musicxml, 'src/xsd/musicxml.xsd')
      .catch(error => {
        console.error(`Failed to validate MusicXML: ${error.message}`)
      })
    }

    if ('output' in args) {
      fs.writeFileSync(path.join(args['output'], `${groove.groove}.musicxml`), musicxml)
    }
    else {
      process.stdout.write(musicxml + '\n')
    }
  }
  catch (error) {
    console.error(`Failed to convert ${groove.groove} to MusicXML: ${error}`)
  }
}

function createMusicXML(groove) {
  groove.tracks = groove.tracks.filter(t => t.track.startsWith('DRUM')).reverse()
  if (!groove.tracks.length) {
    throw Error('No drum tracks found.')
  }

  const template = `
  <?xml version="1.0" encoding="utf-8" standalone="no"?>
  <!DOCTYPE score-partwise PUBLIC
      "-//Recordare//DTD MusicXML ${MUSICXML_VERSION} Partwise//EN"
      "http://www.musicxml.org/dtds/partwise.dtd">
  <score-partwise version="${MUSICXML_VERSION}">
    <work>
      <work-title>${escape(groove.groove)}</work-title>
    </work>
    <identification>
      <encoding>
        <software>musicxml-grooves ${version}</software>
        <encoding-date>${new Date().toJSON().slice(0, 10)}</encoding-date>
        <supports element="accidental" type="yes"/>
        <supports element="beam" type="yes"/>
        <supports element="print" attribute="new-page" type="yes" value="yes"/>
        <supports element="print" attribute="new-system" type="yes" value="yes"/>
        <supports element="stem" type="yes"/>
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
  const partCandidates = groove.tracks.reduce((partCandidates, track) => {
    track.candidateInstrumentIds = []
    const midi = track.midi[0] // In grooves.json, all MIDI notes are the same for each track
    const trackCandidates = SaxonJS.XPath.evaluate(`//instrument[drum[@midi="${midi}"]]/@id`, instruments, { resultForm: 'array' })
    if (trackCandidates.length < 1) {
      console.warn(`No instrument found for MIDI drum voice ${track.voice[0]} (${midi}). Creating a new one.`)
      const instrument = createInstrument(instruments, groove, track)
      trackCandidates.push({ value: instrument.getAttribute('id') })
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
  const parts = groove.tracks.reduce((parts, track) => {
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
    .reduce((parts, track) => {
      if (track.partId === undefined) {
        console.error(`Found track ${track.track} without a part, which usually indicates a track name mismatch. Ignoring.`)
        return parts
      }
      if (!(track.partId in parts)) {
        parts[track.partId] = []
      }
      parts[track.partId].push(track)
      return parts
    }, {})

  return Object.keys(parts).map((partId) => {
    return `
      <part id="P${partId}">
        ${createPartEntry(groove, partId, parts[partId])}
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
    const track = groove.tracks.find(t => t.midi[0].toString() === drum.getAttribute('midi').toString())
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

function createPartEntry(groove, partId, part) {
  // Create part measures by combining the notes of all tracks in the part.
  // The notes are sorted by time and then by pitch.
  const instrumentId = part[0].candidateInstrumentIds[0]
  const instrument = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]`, instruments)
  const beats = parseInt(groove.timeSignature.split('/')[0])
  const beatType = parseInt(groove.timeSignature.split('/')[1])
  const types = {
    2: 'half',
    4: 'quarter',
    8: 'eighth',
    16: '16th'
  }
  return part[0].sequence.map((_, i) => {
    const attributes = i > 0 ? '' : `
      <attributes>
        <divisions>${DIVISIONS}</divisions>
        <time>
          <beats>${beats}</beats>
          <beat-type>${beatType}</beat-type>
        </time>
        <clef>
          <sign>percussion</sign>
        </clef>
        <staff-details>
          <staff-lines>${instrument.getElementsByTagName('staff-lines')[0].textContent}</staff-lines>
        </staff-details>
      </attributes>
    `.trim()
    const direction = (i > 0 || partId > 1) ? '' : `
      <direction placement="above">
        <direction-type>
          <metronome parentheses="no" default-x="-37.06" relative-x="-33.03" relative-y="21.27">
            <beat-unit>${types[beatType]}</beat-unit>
            <per-minute>${args['tempo']}</per-minute>
          </metronome>
        </direction-type>
        <sound tempo="${args['tempo']}"/>
      </direction>
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
      const duration = note.onset - onset
      if (duration > 0) {
        if (notes.length === 0) {
          notes.push({
            midi: undefined, // rest
            onset,
            duration
          })
        }
        else {
          // Maximum duration of a drum beat is 1.
          notes.filter(note => note.onset === onset).forEach(note => { note.duration = Math.min(1, duration) })
          if (duration > 1) {
            notes.push({
              midi: undefined,
              onset: onset + 1,
              duration: duration - 1
            })
          }
        }
      }
      notes.push(note)
      if (index === source.length - 1) {
        const duration = beats + 1 - note.onset
        if (duration <= 0) {
          console.warn(`Found note with duration 0. Ignoring.`)
        }
        notes.filter(note => note.duration === undefined).forEach(note => { note.duration = Math.min(1, duration) })
        if (duration > 1) {
          notes.push({
            midi: undefined,
            onset: onset + 1,
            duration: duration - 1
          })
        }
      }
      return notes
    }, []).filter(note => note.duration > 0).map((note, index, notes) => {
      const drum = note.midi ? SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum[@midi="${note.midi}"]`, instruments) : undefined
      const pitch = drum ? `
        <unpitched>
          <display-step>${drum.getElementsByTagName('display-step')[0].textContent}</display-step>
          <display-octave>${drum.getElementsByTagName('display-octave')[0].textContent}</display-octave>
        </unpitched>
      `.trim() : '<rest/>'
      const instrument = drum ? `<instrument id="P${note.partId}-I${note.midi}"/>` : ''
      const chord = (index > 0 && notes[index - 1].onset === note.onset) ? '<chord/>' : ''
      const stem = drum ? `<stem>${drum.getElementsByTagName('stem')[0].textContent}</stem>` : ''
      const notehead = drum ? `<notehead>${drum.getElementsByTagName('notehead')[0].textContent}</notehead>` : ''
      const duration = Math.round(note.duration * DIVISIONS)
      return `
        <note>
          ${chord}
          ${pitch}
          <duration>${duration}</duration>
          ${instrument}
          ${getNoteTiming(note, index, notes, beatType)}
          ${stem}
          ${notehead}
        </note>
      `.trim()
    }).join('')
    return `
      <measure number="${i + 1}">
        ${attributes}
        ${direction}
        ${notes}
      </measure>
    `.trim()
  }).join('')
}

function getNoteTiming(note, _index, _notes, beatType) {
  const types = {
    [DURATION_WHOLE]: 'whole',
    [DURATION_HALF]: 'half',
    [DURATION_QUARTER]: 'quarter',
    [DURATION_EIGHTH]: 'eighth',
    [DURATION_16th]: '16th',
    [DURATION_32nd]: '32nd',
    [DURATION_64th]: '64th',
    [DURATION_128th]: '128th',
    [DURATION_256th]: '256th',
    [DURATION_512th]: '512th',
    [DURATION_1024th]: '1024th',
  }
  const elements = []
  const duration = Math.round(note.duration * DIVISIONS * 8 / beatType)
  if (duration in types) {
    elements.push(`<type>${types[duration]}</type>`)
  }
  else for (const [entry, type] of Object.entries(types)) {
    if (entry > duration) {
      const dots = Math.log(2 - duration / entry) / Math.log(0.5)
      if (Number.isInteger(dots)) {
        elements.push(`<type>${type}</type>`)
        elements.push(...Array.from(Array(dots), _ => '<dot/>'))
        break
      }
    }
    for (const tuplet of [3, 5]) {
      if (Math.abs(duration * tuplet - entry * 2) < Number.EPSILON) {
        elements.push(`<type>${type}</type>`)
        elements.push(`<time-modification><actual-notes>${tuplet}</actual-notes><normal-notes>2</normal-notes></time-modification>`)
        break
      }
    }
    // TODO: Detect swing mode.
  }

  if (elements.length < 1) {
    console.error(`Could not transform note duration ${note.duration} to MusicXML.`)
  }
  return elements.join('')
}

function createInstrument(document, _groove, track) {
  const createElement = function (target, obj) {
    const el = document.createElement(obj.tagName)
    if (obj.hasOwnProperty('text')) {
      el.appendChild(document.createTextNode(obj.text))
    }
    if (obj.hasOwnProperty('attributes')) {
      obj.attributes.forEach(attribute => {
        el.setAttribute(attribute.name, attribute.value)
      })
    }
    target.appendChild(el)
    if (obj.hasOwnProperty('children')) {
      obj.children.forEach(child => {
        createElement(el, child)
      })
    }
    return el
  }
  return createElement(instruments.documentElement, {
    tagName: 'instrument',
    attributes: [{
      name: 'id', value: `unknown-${track.voice[0].toLowerCase()}`
    }],
    children: [{
      tagName: 'part-name',
      attributes: [{
        name: 'lang', value: 'en'
      }],
      text: `Unknown ${track.voice[0]}`,
    }, {
      tagName: 'part-abbreviation',
      attributes: [{
        name: 'lang', value: 'en'
      }],
      text: `Unk. ${track.voice[0].substring(0, 4)}.`,
    }, {
      tagName: 'staff-lines',
      text: '1'
    }, {
      tagName: 'drum',
      attributes: [{
        name: 'midi', value: track.midi[0]
      }],
      children: [{
        tagName: 'instrument-name',
        attributes: [{
          name: 'lang', value: 'en'
        }],
        text: track.voice[0],
      }, {
        tagName: 'instrument-sound',
        text: ''
      }, {
        tagName: 'display-step',
        text: 'E'
      }, {
        tagName: 'display-octave',
        text: '4'
      }, {
        tagName: 'stem',
        text: 'up'
      }, {
        tagName: 'notehead',
        text: 'normal'
      }]
    }]
  })
}

// https://stackoverflow.com/a/27979933/209184
function escape(unsafe) {
  return unsafe.replace(/[<>&'"]/g, function (c) {
    switch (c) {
      case '<': return '&lt;'
      case '>': return '&gt;'
      case '&': return '&amp;'
      case '\'': return '&apos;'
      case '"': return '&quot;'
    }
  })
}
