#!/usr/bin/env node

/**
 * Parse MMA grooves and output a MusicXML file for each.
 */

const MUSICXML_VERSION = '4.0'
const INSTRUMENTS = 'src/xml/drums.xml'
const DIVISIONS = 768
const DIVISIONS_WHOLE = DIVISIONS*4
const DIVISIONS_HALF = DIVISIONS*2
const DIVISIONS_QUARTER = DIVISIONS
const DIVISIONS_EIGHTH = DIVISIONS/2
const DIVISIONS_16th = DIVISIONS/4
const DIVISIONS_32nd = DIVISIONS/8
const DIVISIONS_64th = DIVISIONS/16
const DIVISIONS_128th = DIVISIONS/32
const DIVISIONS_256th = DIVISIONS/64
const DIVISIONS_512th = DIVISIONS/128
const DIVISIONS_1024th = DIVISIONS/256
const QUANTIZATION_DEFAULT_GRID = [4, 3]
const QUANTIZATION_FINEST_GRID = [32]

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
  },
  'grid': {
    type: 'string',
    default: QUANTIZATION_DEFAULT_GRID.join(',')
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

const grid = args['grid'].split(',').map(g => parseInt(g.trim()))
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
    throw error
  }
}

/**
 * Main entrypoint for MusicXML generation.
 */
function createMusicXML(groove) {
  groove.tracks = groove.tracks.filter(t => t.track.startsWith('DRUM')).reverse()
  if (!groove.tracks.length) {
    throw Error(`[${groove.groove}] No drum tracks found.`)
  }

  const template = `
  <?xml version="1.0" encoding="utf-8" standalone="no"?>
  <!DOCTYPE score-partwise PUBLIC
      "-//Recordare//DTD MusicXML ${MUSICXML_VERSION} Partwise//EN"
      "http://www.musicxml.org/dtds/partwise.dtd">
  <score-partwise version="${MUSICXML_VERSION}">
    <work>
      <work-title>${escapeXml(groove.groove)}</work-title>
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
        return SaxonJS.XPath.evaluate(`count(//instrument[@id="${a}"]/drum)`, instruments) -
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
 * - Generate note timings, including quantization, extra ties and rests
 * - Generate the MusicXML note representation
 */
function createMeasureNotes(groove, part, i) {
  const instrumentId = part[0].candidateInstrumentIds[0]
  const beats = parseInt(groove.timeSignature.split('/')[0])
  const beatType = parseInt(groove.timeSignature.split('/')[1])

  // Gather all notes and parse them.
  return part.reduce((notes, track) => {
    const voice = SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum[@midi="${track.midi[0]}"]/voice/text()`, instruments) ?? '1'
    return notes.concat(track.sequence[i].split(';').map(note => {
      const parts = note.split(/\s+/).filter(part => !!part)
      return parts[0] === 'z' ? undefined : {
        midi: track.midi[0],
        onset: parseFloat(parts[0]),
        duration: undefined,
        velocity: parseInt(parts[2]),
        partId: track.partId,
        track: track.track,
        voice: voice.textContent,
        measure: i
      }
    }).filter(note => !!note))
  }, [])

  // Detect velocity 0 notes which indicate the closing of a previous note.
  // TODO Actually close the notes.
  // TODO Handle notes that were open in previous measure.
  .reduce((notes, note) => {
    if (note.velocity > 0) {
      notes.push(note)
    }
    // else {
    //   const previous = notes.reverse().find(n => n.midi === note.midi && n.voice === note.voice)
    //   if (previous) {
    //     previous.duration = note.onset - previous.onset
    //   }
    // }
    return notes
  }, [])

  // Sort the notes, first by voice, then by onset.
  .sort((n1, n2) => {
    return n1.voice !== n2.voice ?
      n1.voice.localeCompare(n2.voice, undefined, { numeric: true, sensitivity: 'base'}) :
      n1.onset - n2.onset
  })

  // Calculate notes duration.
  // A note's duration is the difference between the next note's onset and its own onset.
  // A note's duration does not exceed beat boundaries (drum tracks only).
  // At each note, we calculate the previous note's duration.
  // At the first note of each voice, if the onset is > 1, we insert a rest to start the measure.
  // At the last note of each voice, the duration is the remaining time until the measure end.
  .reduce((notes, note, index, input) => {
    const isFirstNote = notes.length === 0 || notes[notes.length - 1].voice !== note.voice
    const isLastNote = index === input.length - 1 || input[index + 1].voice !== note.voice
    const previousOnset = isFirstNote ? 1 : notes[notes.length - 1].onset
    const boundary = Math.floor(previousOnset) + 1 - previousOnset
    const duration = Math.min(note.onset - previousOnset, boundary)
    if (duration > 0) {
      notes.filter(n => n.onset === previousOnset && n.voice === note.voice && n.duration === undefined).forEach(n => { n.duration = duration })
    }
    notes.push(note)

    // If we're at the end of the measure, calculate the duration of all remaining notes.
    if (isLastNote) {
      notes.filter(n => n.duration === undefined && n.voice === note.voice).forEach(n => {
        const boundary = Math.floor(n.onset) + 1 - n.onset
        n.duration = Math.min(beats + 1 - n.onset, boundary)
      })
    }

    return notes
  }, [])

  // Quantize the notes on a grid and fill the gaps with rests.
  // Each note is at most 1 beat, and does not cross beat boundaries.
  .reduce((notes, note, index, input) => {
    quantizeNoteOnset(note, index, input, beats, grid)
    notes.push(note)
    return notes
  }, [])
  .reduce((notes, note, index, input) => {
    const [restsBefore, restsAfter] = quantizeNoteDuration(note, index, input, beats, grid)
    notes.push(...restsBefore, note, ...restsAfter)
    return notes
  }, [])

  // Generate note types, durations and extra notes as needed.
  // Ignore notes that have already been processed by an earlier iteration in createNoteTiming().
  .reduce((notes, note, index, input) => {
    const extra = 'musicXml' in note ? [] : createNoteTiming(note, index, input)
    notes.push(note, ...extra)
    return notes
  }, [])

  // Generate MusicXML.
  // When voices change, we backup to the beginning of the measure.
  // TODO Add dynamics, articulations.
  .map((note, index, notes) => {
    const backup = (index > 0 && notes[index-1].voice !== note.voice) ? `
      <backup>
        <duration>${beats * DIVISIONS}</duration>
      </backup>
    `.trim() : ''
    const drum = 'midi' in note ? SaxonJS.XPath.evaluate(`//instrument[@id="${instrumentId}"]/drum[@midi="${note.midi}"]`, instruments) : undefined
    const chord = (index > 0 && notes[index-1].quantized.onset === note.quantized.onset) ? '<chord/>' : ''
    const pitch = drum ? `
      <unpitched>
        <display-step>${drum.getElementsByTagName('display-step')[0].textContent}</display-step>
        <display-octave>${drum.getElementsByTagName('display-octave')[0].textContent}</display-octave>
      </unpitched>
    `.trim() : '<rest/>'
    const tieStart = 'tie' in note.musicXml && note.musicXml.tie.start ? `<tie type="start"/>` : ''
    const tieStop = 'tie' in note.musicXml && note.musicXml.tie.stop ? `<tie type="stop"/>` : ''
    const instrument = 'midi' in note ? `<instrument id="P${note.partId}-I${note.midi}"/>` : ''
    const type = 'type' in note.musicXml ? `<type>${note.musicXml.type}</type>` : ''
    const dots = 'dots' in note.musicXml ? Array.from(Array(note.musicXml.dots), _ => '<dot/>') : []
    const timeModification = 'tuplet' in note.musicXml ? `
      <time-modification>
        <actual-notes>${note.musicXml.tuplet.actualNotes}</actual-notes>
        <normal-notes>${note.musicXml.tuplet.normalNotes}</normal-notes>
        <normal-type>${note.musicXml.tuplet.normalType}</normal-type>
      </time-modification>
    `.trim() : ''
    const stem = drum ? `<stem>${drum.getElementsByTagName('stem')[0].textContent}</stem>` : ''
    const notehead = drum ? `<notehead>${drum.getElementsByTagName('notehead')[0].textContent}</notehead>` : ''
    const tiedStart = 'tie' in note.musicXml && note.musicXml.tie.start ? `<tied type="start"/>` : ''
    const tiedStop = 'tie' in note.musicXml && note.musicXml.tie.stop ? `<tied type="stop"/>` : ''
    const tuplet = 'tuplet' in note.musicXml ? (
      'startStop' in note.musicXml.tuplet && note.musicXml.tuplet.startStop !== undefined ? (
        note.musicXml.tuplet.startStop === 'start' ? `
          <tuplet bracket="yes" number="${note.musicXml.tuplet.number}" placement="above" type="start">
            <tuplet-actual>
              <tuplet-number>${note.musicXml.tuplet.actualNotes}</tuplet-number>
              <tuplet-type>${note.musicXml.type}</tuplet-type>
            </tuplet-actual>
            <tuplet-normal>
              <tuplet-number>${note.musicXml.tuplet.normalNotes}</tuplet-number>
              <tuplet-type>${note.musicXml.tuplet.normalType}</tuplet-type>
            </tuplet-normal>
          </tuplet>
        `.trim() : `<tuplet number="${note.musicXml.tuplet.number}" type="stop" />`
      ) : ''
    ) : ''

    return `
      ${backup}
      <note>
        ${chord}
        ${pitch}
        <duration>${note.musicXml.duration}</duration>
        ${tieStart}
        ${tieStop}
        ${instrument}
        <voice>${note.voice}</voice>
        ${type}
        ${dots.join('')}
        ${timeModification}
        ${stem}
        ${notehead}
        <notations>
          ${tiedStart}
          ${tiedStop}
          ${tuplet}
        </notations>
      </note>
    `.trim()
  }).join('')
}

/**
 * Quantize a single note onset.
 */
function quantizeNoteOnset(note, index, notes, beats, grid) {
  const isFirstNote = index === 0 || notes[index - 1].voice !== note.voice
  const isLastNote = index === notes.length - 1 || notes[index + 1].voice !== note.voice
  const scoreDuration = Math.round(note.duration * DIVISIONS)
  const scoreOnset = Math.round((note.onset - 1) * DIVISIONS)
  const onset = grid.map(unit => {
    return nearestMultiple(scoreOnset, DIVISIONS/unit)
  }).flat().sort((m1, m2) => {
    return m1.error_abs - m2.error_abs
  }).reduce((onset, candidate) => {
    if (onset !== undefined) {
      return onset
    }

    if (isFirstNote || notes[index - 1].quantized.onset < candidate.multiple) {
      return candidate
    }
  }, undefined)

  if (onset === undefined) {
    console.warn(`[${note.track}:${note.measure+1}] Failed to quantize note onset at ${note.onset} to avoid collision with previous note.`)
  }

  // Adjust note.
  note.quantized = {
    onset: onset.multiple,
    duration: scoreDuration - onset.error_sgn
  }
}

/**
 * Quantize a single note duration.
 * Don't let duration remain at 0.
 */
function quantizeNoteDuration(note, index, notes, beats, grid) {
  const isFirstNote = index === 0 || notes[index - 1].voice !== note.voice
  const isLastNote = index === notes.length - 1 || notes[index + 1].voice !== note.voice
  const scoreOffset = Math.min(
    note.quantized.onset + note.quantized.duration,
    isLastNote ? beats * DIVISIONS : (notes[index + 1].quantized.onset + notes[index + 1].quantized.duration)
  )
  const offset = grid.map(unit => {
    return nearestMultiple(scoreOffset, DIVISIONS/unit)
  }).flat().sort((m1, m2) => {
    return m1.error_abs - m2.error_abs
  }).reduce((offset, candidate) => {
    if (offset !== undefined) {
      return offset
    }
    const duration = candidate.multiple - note.quantized.onset
    if (duration > Number.EPSILON) {
      return candidate
    }
  }, undefined)

  if (offset === undefined) {
    console.warn(`[${note.track}:${note.measure+1}] Failed to quantize note duration at ${note.onset} to avoid zero duration.`)
  }

  // Adjust note.
  note.quantized.duration = offset.multiple - note.quantized.onset
  note.onset = note.quantized.onset / DIVISIONS + 1
  note.duration = note.quantized.duration / DIVISIONS

  // Add rests before and after note if needed.
  const previousOffset = isFirstNote ? 0 : notes[index - 1].quantized.onset + notes[index - 1].quantized.duration
  return [
    fillWithRests(note, previousOffset, note.quantized.onset),
    isLastNote ? fillWithRests(note, note.quantized.onset + note.quantized.duration, beats * DIVISIONS) : []
  ]
}

/**
 * Fill a gap with rests.
 * Each rest is at most 1 beat, and does not cross beat boundaries.
 */
function fillWithRests(note, gapStart, gapEnd) {
  const rests = []
  let gap = gapEnd - gapStart
  if (gap > Number.EPSILON) {
    const head = gapStart % DIVISIONS_QUARTER
    if (head > Number.EPSILON) {
      rests.push({
        track: note.track,
        voice: note.voice,
        measure: note.measure,
        quantized: {
          onset: gapStart,
          duration: DIVISIONS_QUARTER - head
        },
        onset: gapStart / DIVISIONS + 1,
        duration: (DIVISIONS_QUARTER - head) / DIVISIONS,
      })
      gap -= rests[rests.length - 1].quantized.duration
    }
    while (gap > Number.EPSILON) {
      rests.push({
        track: note.track,
        voice: note.voice,
        measure: note.measure,
        quantized: {
          onset: gapEnd - gap,
          duration: Math.min(gap, DIVISIONS_QUARTER)
        },
        onset: (gapEnd - gap) / DIVISIONS + 1,
        duration: Math.min(gap, DIVISIONS_QUARTER) / DIVISIONS
      })
      gap -= rests[rests.length - 1].quantized.duration
    }
  }
  return rests
}

/**
 * Derive a note type and timing given its raw duration and onset.
 *
 * This function _mutates_ the current note to set the MusicXML information about the note's timing:
 *
 * note.musicXml = {
 *   duration, // <duration> (expressed in multiples of score <divisions>)
 *   type, // <type>
 *   dots, // count of <dot/>
 *   tuplet: { // Information for both <time-modification> and <notations><tuplet>
 *     actualNotes,
 *     normalNotes,
 *     normalType,
 *     startStop, // undefined | 'start' | 'stop',
 *     number, // <tuplet number>
 *   },
 *   tie: { // Information for both <tie> and <notations><tied>
 *     start, // true | false
 *     stop, // true | false
 *   }
 * }
 *
 * The function also _returns_ an array of extra notes that should be inserted following the current one, to complement the note timing,
 * such as extra rests or tied notes.
 *
 * The function potentially also _mutates_ the next note(s) in the incoming array with their own musicXml structure, to account for
 * cases like swing note pairs or other tuplets.
 */
function createNoteTiming(note, index, notes) {
  const tuplets = (note, index, notes, tuplets) => notes.filter((n, i) => n.voice === note.voice && i >= index && i < index + tuplets)
  const tupletsDuration = (tuplets) => tuplets.reduce((s, n) => s + n.quantized.duration, 0)

  // The map from score duration to MusicXML note type, and its opposite function.
  const types = [
    [DIVISIONS_WHOLE, 'whole'],
    [DIVISIONS_HALF, 'half'],
    [DIVISIONS_QUARTER, 'quarter'],
    [DIVISIONS_EIGHTH, 'eighth'],
    [DIVISIONS_16th, '16th'],
    [DIVISIONS_32nd, '32nd'],
    [DIVISIONS_64th, '64th'],
    [DIVISIONS_128th, '128th'],
    [DIVISIONS_256th, '256th'],
    [DIVISIONS_512th, '512th'],
    [DIVISIONS_1024th, '1024th'],
  ]
  const scoreDuration = note.quantized.duration

  // Fill in this MusicXML timing structure.
  note.musicXml = {
    duration: scoreDuration
  }
  for (const [entry, type] of types) {
    // Detect simple types.
    if (Math.abs(scoreDuration - entry) <= Number.EPSILON) {
      note.musicXml = { ...note.musicXml, type }
      break
    }

    // // Detect dotted notes, only for non-rests.
    // if ('midi' in note && entry < scoreDuration) {
    //   const dots = Math.log(2 - scoreDuration / entry) / Math.log(0.5)
    //   if (Number.isInteger(dots)) {
    //     note.musicXml = { ...note.musicXml, type, dots }
    //     break
    //   }
    // }

    // TODO Detect 3- and 5-tuplets.
    for (const tuplet of [3, 5]) {
    }

    // Detect swing 8th pair.
    // To qualify, 2 consecutive notes must:
    // - Sum up to a quarter
    // - Each be within a triplet factor of a quarter
    if (entry === DIVISIONS_QUARTER && entry > scoreDuration) {
      const pair = tuplets(note, index, notes, 2)
      const [swingHi, swingLo] = [2 * entry / 3, entry / 3]
      if (
        pair.length == 2 &&
        Math.abs(tupletsDuration(pair) - entry) <= Number.EPSILON &&
        pair.every(n => Math.abs(swingHi - n.quantized.duration) <= Number.EPSILON || Math.abs(swingLo - n.quantized.duration) <= Number.EPSILON)
      ) {
        note.musicXml = {
          ...note.musicXml,
          type: pair[0].quantized.duration > pair[1].quantized.duration ? 'quarter' : 'eighth',
          tuplet: {
            actualNotes: 3,
            normalNotes: 2,
            normalType: 'eighth',
            startStop: 'start',
            number: 1
          }
        }
        pair[1].musicXml = {
          duration: pair[1].quantized.duration,
          type: pair[0].quantized.duration < pair[1].quantized.duration ? 'quarter' : 'eighth',
          tuplet: {
            actualNotes: 3,
            normalNotes: 2,
            normalType: 'eighth',
            startStop: 'stop',
            number: 1
          }
        }
        break;
      }
    }
  }

  // None of the closed formulas worked. Create extra notes to add up to the duration.
  // - First "extra" note is actually current note.
  // - All notes will be tied. First note starts a tie, last note ends a tie, middle notes have both.
  // - Add a dot to notes if they are in consecutive fractional order.
  if (!('type' in note.musicXml) && 'midi' in note) {
    const extra = []
    let remainingDuration = scoreDuration
    let onset = note.quantized.onset
    for (const [entry, type] of types) {
      if (remainingDuration >= entry) {
        if (extra.length > 0 && extra[extra.length - 1].duration === entry * 2) {
          extra[extra.length - 1].dots += 1
          extra[extra.length - 1].duration += entry
        }
        else {
          extra.push({
            onset,
            duration: entry,
            type,
            dots: 0,
            tie: { start: true, stop: extra.length > 0 },
          })
        }
        remainingDuration -= entry
        onset += entry
      }
    }

    // Close up the last tie.
    extra[extra.length - 1].tie.start = false

    // Transfer first extra note to current note.
    note.musicXml = extra.shift()

    // Return extra notes.
    return extra.map((e, i, input) => {
      return {
        midi: note.midi,
        velocity: note.velocity,
        partId: note.partId,
        track: note.track,
        voice: note.voice,
        measure: note.measure,
        musicXml: e,
        quantized: {
          onset: e.onset,
          duration: e.duration
        }
      }
    })
  }

  return []
}

/**
 * Create a synthetic <instrument> from a single track.
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
function escapeXml(unsafe) {
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

// music21.common.numberTools.nearestMultiple()
function nearestMultiple(n, unit) {
  const m = Math.floor(n / unit)
  const half = unit / 2
  const matchLo = unit * m
  const matchHi = unit * (m + 1)
  const result = [{
    multiple: matchLo,
    error_abs: +Number(n - matchLo).toFixed(5),
    error_sgn: +Number(n - matchLo).toFixed(5)
  }, {
    multiple: matchHi,
    error_abs: +Number(matchHi - n).toFixed(5),
    error_sgn: +Number(n - matchHi).toFixed(5)
  }]
  if (matchLo <= n && n <= (matchLo + half)) {
    return result
  }
  else /*if (matchHi >= n && n >= (matchHi - half))*/ {
    return result.reverse()
  }
}
