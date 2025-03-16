MusicXML to MIDI converter
======================

A suite of tools to convert MusicXML scores to MIDI using [Musical MIDI Accompaniment (MMA)](http://www.mellowood.ca/mma/).

![GitHub Build Status](https://github.com/infojunkie/musicxml-mma/workflows/Test/badge.svg)

# Installation
- Install `xmllint` (included in [libxml2](http://www.xmlsoft.org/) on most platforms)
- `git submodule update --init --recursive`
- `npm install && npm run build`

# Convert a MusicXML score to MIDI
- `npm run --silent convert:unroll song.musicxml > song-unrolled.musicxml` to unroll a MusicXML score by expanding all jumps and repeats
- `npm run --silent convert:mma song.musicxml > song.mma` to both unroll a score and convert it to an MMA script
- `npm run --silent convert:groove groove-name [chords="A,B,C"] [tempo=X] [count=Y] [keysig=Z] > groove.mma` to generate a groove MMA script
- `npm run convert:midi /path/to/song.mma` to convert an MMA script to MIDI file at `/path/to/song.mid`
- `npm run --silent convert:timemap song.musicxml > song.timemap.json` to convert a score to a timemap JSON file

# Serve a conversion API endpoint
- `PORT=3000 npm run develop` for development (including hot-reload)
- `PORT=3000 npm run start` for production
- `curl -sSf -F"musicXml=@test/data/salma-ya-salama.musicxml" -F"globalGroove=Maqsum" http://localhost:3000/convert -o "salma-ya-salama.mid"`
- `curl -sSf -F"groove=Maqsum" -F"chords=I, vi, ii, V7" -F"count=8" http://localhost:3000/groove -o "maqsum.mid"`
- `curl -sSf -F"jq=.[] |= {groove,description,timeSignature}" http://localhost:3000/grooves.json`

# Other operations
- Convert a MIDI file to a timemap JSON file: `./src/js/midi-timemap.js song.mid > song.timemap.json`
- Scrape MusicXML examples from the official site: `./src/js/musicxml-examples.js --output=./test/data/examples`
- Convert MMA grooves to MusicXML: `./src/js/musicxml-grooves.js --output=./test/data/grooves`
- Convert MIDI to JSON and back: `./src/js/midi-json.js < source.mid | jq [..] | ./src/js/midi-json.js > target.mid`

# Theory of operation
This converter aims to create a valid MMA accompaniment script out of a MusicXML score. The MMA script is then converted to MIDI using the bundled `mma` tool. To accomplish this, the converter expects to find the following information in the sheet:

- Chord information, expressed as [`harmony` elements](https://w3c.github.io/musicxml/musicxml-reference/elements/harmony/). MMA recognizes a large number of chords, but MusicXML's harmony representation is more general and can lead to invalid chord names. Refer to [chords.musicxml](test/data/chords.musicxml) for a reference on how to express all MMA-supported chords.

- Melody information, expressed as [`note` elements](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/note/). This is converted to an MMA `SOLO` sequence for each measure.

- Optional playback style information, expressed as [`sound/play/other-play` elements](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/other-play/) with attribute `@type = 'groove'`. The content of this element represents the "groove" that is passed to MMA to generate an accompaniment. In case no such playback style information is found, or the specified style is not mapped to an existing MMA groove, the chords are played back as per the lead sheet without further accompaniment. Note that several styles can be specified in a single sheet, since the `sound` element is associated with `measure` or `measure/direction` elements. The groove can be overridden with the argument `globalGroove`.

## Output metadata in the MIDI file
The produced MMA script / MIDI file contains metadata that can be useful to downstream consumers. This metadata is generally expressed as [MIDI Marker meta messages](https://www.recordingblogs.com/wiki/midi-marker-meta-message), with the following syntax:
- `Measure:N:T` informs the consumer that the MIDI playback has reached measure N (0-based) with duration T milliseconds.
- `Groove:X` informs the consumer that the MIDI playback is henceforth using the specified playback style.
