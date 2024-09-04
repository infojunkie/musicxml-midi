#!/usr/bin/env node

/**
 * Parse MMA grooves and output a MusicXML file for each.
 */

const MUSICXML_VERSION = '4.0'
const INSTRUMENTS = 'src/xml/drums.xml'
const DIVISIONS = 384
const DIVISIONS_WHOLE = DIVISIONS*8/1
const DIVISIONS_HALF = DIVISIONS*8/2
const DIVISIONS_QUARTER = DIVISIONS*8/4
const DIVISIONS_EIGHTH = DIVISIONS*8/8
const DIVISIONS_16th = DIVISIONS*8/16
const DIVISIONS_32nd = DIVISIONS*8/32
const DIVISIONS_64th = DIVISIONS*8/64
const DIVISIONS_128th = DIVISIONS*8/128
const DIVISIONS_256th = DIVISIONS*8/256
const DIVISIONS_512th = DIVISIONS*8/512
const DIVISIONS_1024th = DIVISIONS*8/1024
const TOLERANCE = 0

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
    default: '120'
  }
}
const { values: args } = (() => {
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

/**
 * Main entrypoint for MusicXML generation.
 */
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

/**
 * Create <part-list> section.
 *
 * We first compute the score parts. The score parts are based on a drums.xml file.
 * Each part corresponds to a drum set <instrument> element.
 * An <instrument> element has a number of <drum> elements whose @midi attribute corresponds to the MIDI drum voice.
 */
function createPartList(groove) {
  // Loop on each track to find which instrument(s) it belongs to.
  const partCandidates = groove.tracks.reduce((partCandidates, track) => {
    track.candidateInstrumentIds = []
    const midi = track.midi[0] // In grooves.json, all MIDI notes are the same for each track
    const trackCandidates = SaxonJS.XPath.evaluate(`//instrument[drum[@midi="${midi}"]]/@id`, instruments, { resultForm: 'array' })
    if (trackCandidates.length < 1) {
      console.warn(`[${track.track}] No instrument found for MIDI drum voice ${track.voice[0]} (${midi}). Creating a new one.`)
      const instrument = createInstrument(instruments, groove, track)
      trackCandidates.push({ value: instrument.getAttribute('id') })
    }

    // It can happen that a MIDI drum voice is used by multiple instruments,
    // so we gather all matching instruments and later select those with the most voices.
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

/**
 * Create <part> sections.
 *
 * We've already created partId entries in each track, so we can now aggregate those in each <part> entry.
 * A <part> entry has measures.
 */
function createParts(groove) {
  const parts = groove.tracks
    .reduce((parts, track) => {
      if (track.partId === undefined) {
        console.error(`[${track.track}] Found track without an assigned part. Ignoring.`)
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
        ${createPartMeasures(groove, partId, parts[partId])}
      </part>
    `.trim()
  }).join('')
}

/**
 * Create <part-list> entries.
 *
 * Iterate on all instrument Drum entries, create a score-instrument and a midi-instrument for each.
 * Generate an score-instrument id which is the part id followed by the drum pitch.
 * This score-instrument id is used in the part's notes to reference the corresponding instrument.
 * Update each groove track with its score-instrument id.
 */
function createPartListEntry(groove, instrumentId, partId) {
  const instrument = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]`, instruments)
  const entries = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum`, instruments, { resultForm: 'array' })
  .reduce((entries, drum) => {
    const scoreInstrumentId = `P${partId}-I${drum.getAttribute('midi')}`
    groove.tracks.filter(t => t.midi[0].toString() === drum.getAttribute('midi').toString()).forEach((track, index) => {
      if (index > 0) {
        console.warn(`[${track.track}] Found a track with duplicate drum voice ${track.voice[0]}. This may indicate a name mismatch in the MMA groove.`)
      }
      track.partId = partId
      track.scoreInstrumentId = scoreInstrumentId
    })
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

/**
 * Create measures for a part.
 *
 * For the first measure of first part, we add <direction> for metronome.
 * For the first measure of each part, we add <attributes> for divisions, time signature, clef, staff lines.
 * For each measure, we add notes.
 */
function createPartMeasures(groove, partId, part) {
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
    return `
      <measure number="${i + 1}">
        ${attributes}
        ${direction}
        ${createMeasureNotes(groove, part, i)}
      </measure>
    `.trim()
  }).join('')
}

/**
 * Create notes for a single measure.
 *
 * A single measure results from blending multiple tracks that belong to the same part.
 *
 * The notes go through a pipeline of transformations:
 * - Convert the textual note representation to a flat array of objects
 * - Sort the notes by voice and by onset
 * - Calculate the duration of notes
 * - Insert extra rests when a duration crosses beat boundaries (since we're dealing with drum beats)
 * - Generate the MusicXML note representation, including detecting note type/duration/timing.
 */
function createMeasureNotes(groove, part, i) {
  const instrumentId = part[0].candidateInstrumentIds[0]
  const beats = parseInt(groove.timeSignature.split('/')[0])
  const beatType = parseInt(groove.timeSignature.split('/')[1])

  // Step 1: Gather all notes and parse them.
  // Ignore full rests and notes with velocity 0.
  // TODO Handle case of empty measure.
  return part.reduce((notes, track) => {
    const voice = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum[@midi="${track.midi[0]}"]/voice/text()`, instruments) ?? '1'
    return notes.concat(track.sequence[i].split(';').map(note => {
      const parts = note.split(/\s+/).filter(part => !!part)
      return parts[0] !== 'z' ? {
        midi: track.midi[0],
        onset: parseFloat(parts[0]),
        duration: undefined,
        velocity: parseInt(parts[2]),
        partId: track.partId,
        track: track.track,
        voice: parseInt(voice)
      } : undefined
    }).filter(note => !!note && note.velocity > 0))
  }, [])

  // Step 2: Sort the notes, first by voice, then by onset.
  .sort((n1, n2) => {
    return n1.voice !== n2.voice ?
      n1.voice - n2.voice :
      n1.onset - n2.onset
  })

  // Step 3: Calculate note durations.
  // A note's duration is the difference between the next note's onset and its own onset.
  // Therefore, at each note, we can calculate the previous note's duration.
  // At the first note of each voice, if the onset is > 1, we insert a rest to start the measure.
  // At the last note of each voice, the duration is the remaining time until the measure end.
  .reduce((notes, note, index, input) => {
    const isFirstNote = notes.length === 0 || notes[notes.length - 1].voice !== note.voice
    const isLastNote = index === input.length - 1 || input[index + 1].voice !== note.voice
    const previous = isFirstNote ? 1 : notes[notes.length-1].onset
    const duration = note.onset - previous
    if (duration > 0) {
      // If the first note starts later than 1, insert a rest before the note.
      if (isFirstNote) {
        notes.push({
          midi: undefined, // rest
          onset: previous,
          duration,
          track: note.track,
          voice: note.voice
        })
      }
      else {
        notes.filter(n => n.onset === previous && n.voice === note.voice).forEach(note => { note.duration = duration })
      }
    }

    // Only add the note if it's being sounded.
    if (note.velocity > 0) {
      notes.push(note)
    }

    // If we're at the end of the measure, calculate the duration of all remaining notes.
    if (isLastNote) {
      notes.filter(n => n.duration === undefined && n.voice === note.voice).forEach(note => {
        note.duration = beats + 1 - note.onset
      })
    }
    return notes
  }, [])

  // Step 3.5: Discard notes whose duration is under the tolerance level.
  .filter(note => note.duration > TOLERANCE)

  // Step 4. Insert extra rests where needed.
  // Each note is at most 1 beat, and does not cross beat boundaries.
  // Any note with duration that crosses beat boundaries get truncated and the rest of the time is filled with rests.
  .reduce((notes, note) => {
    const extra = []
    const boundary = Math.floor(note.onset) + 1 - note.onset
    const spillover = note.duration - boundary
    if (spillover > Number.EPSILON) {
      note.duration = boundary
      for (let s = spillover; s > 0; s -= 1) {
        extra.push({
          midi: undefined,
          duration: Math.min(1, s),
          onset: Math.floor(note.onset) + 1 + Math.ceil(spillover - s),
          track: note.track,
          voice: note.voice
        })
      }
    }
    notes.push(note, ...extra)
    return notes
  }, [])

  // Step 5: Generate MusicXML.
  // When voices change, we backup to the beginning of the measure.
  .map((note, index, notes) => {
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
    const backup = (index > 0 && notes[index - 1].voice !== note.voice) ? `
      <backup>
        <duration>${beats * DIVISIONS}</duration>
      </backup>
    `.trim() : ''
    return `
      ${backup}
      <note>
        ${chord}
        ${pitch}
        <duration>${duration}</duration>
        ${instrument}
        <voice>${note.voice}</voice>
        ${createNoteTiming(note, index, notes, beatType)}
        ${stem}
        ${notehead}
        ${createNoteNotations(note, index, notes, beatType)}
      </note>
    `.trim()
  }).join('')
}

/**
 * Derive a note type given its raw duration.
 *
 * This is a heuristic algorithm that can grow arbitrarily complex in the general case.
 * We use the fact that we're dealing with drum beats and knowledge about MMA grooves to avoid going down the full rabbit hole.
 */
function createNoteTiming(note, index, notes, beatType) {
  // Don't attempt to detect notes < 16th.
  const types = {
    [DIVISIONS_WHOLE]: 'whole',
    [DIVISIONS_HALF]: 'half',
    [DIVISIONS_QUARTER]: 'quarter',
    [DIVISIONS_EIGHTH]: 'eighth',
    [DIVISIONS_16th]: '16th',
  }
  const elements = []
  const scoreDuration = Math.round(note.duration * DIVISIONS * 8 / beatType)
  const isLastNote = index === notes.length - 1 || notes[index + 1].voice !== note.voice

  // Detect 2nd note in pair of swing notes.
  // The first note in the pair will set the swing value for this one.
  if ('swing' in note) {
    elements.push(`<type>${note.swing}</type>`)
    elements.push(`<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>`)
  }
  // Detect simple types from the map above.
  else if (scoreDuration in types) {
    elements.push(`<type>${types[scoreDuration]}</type>`)
  }
  // Detect first note in pair of swing 8th notes.
  // The sum of first + second swing notes = 1.
  // Set the swing value for the 2nd note to catch it early next time.
  else if (!isLastNote && Math.abs(note.duration + notes[index + 1].duration - 1) <= Number.EPSILON) {
    if (note.duration > notes[index + 1].duration) {
      elements.push(`<type>quarter</type>`)
      notes[index + 1].swing = 'eighth'
    }
    else {
      elements.push(`<type>eighth</type>`)
      notes[index + 1].swing = 'quarter'
    }
    elements.push(`<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>`)
  }
  else for (const [entry, type] of Object.entries(types)) {
    // Detect simple types with epsilon tolerance.
    if (Math.abs(scoreDuration - entry) <= Number.EPSILON) {
      elements.push(`<type>${type}</type>`)
      break
    }

    // Detect dotted notes.
    if (entry < scoreDuration) {
      const dots = Math.log(2 - scoreDuration / entry) / Math.log(0.5)
      if (Number.isInteger(dots)) {
        elements.push(`<type>${type}</type>`)
        elements.push(...Array.from(Array(dots), _ => '<dot/>'))
        break
      }
    }

    // Detect 3- and 5-tuplets.
    for (const tuplet of [3, 5]) {
      if (Math.abs(scoreDuration * tuplet - entry * 2) < Number.EPSILON) {
        elements.push(`<type>${type}</type>`)
        elements.push(`<time-modification><actual-notes>${tuplet}</actual-notes><normal-notes>2</normal-notes></time-modification>`)
        break
      }
    }
  }

  if (elements.length < 1) {
    console.error(`[${note.track}] Could not transform note duration ${note.duration} to MusicXML.`)
  }
  return elements.join('')
}

/**
 * Create extra note notations including articulations.
 */
function createNoteNotations(note, _index, _notes) {
  const articulations = []
  if ('staccato' in note ) {
    articulations.push('<staccato/>')
  }
  return articulations.length ? `
    <notations>
      <articulations>
        ${articulations.join('')}
      </articulations>
    </notations>
  `.trim() : ''
}

/**
 * Create a synthetic (undocumented) <instrument> from a single track.
 * The structure is compatible with drums.xml entries.
 */
function createInstrument(document, _groove, track) {
  // Function to create an XML node element.
  const createElement = (target, obj) => {
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

  return createElement(document.documentElement, {
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
  return unsafe.replace(/[<>&'"]/g, c => {
    switch (c) {
      case '<': return '&lt;'
      case '>': return '&gt;'
      case '&': return '&amp;'
      case '\'': return '&apos;'
      case '"': return '&quot;'
    }
  })
}
