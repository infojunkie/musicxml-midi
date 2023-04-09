# musicxml-mma

A MusicXML converter to MIDI via [Musical MIDI Accompaniment (MMA)](http://www.mellowood.ca/mma/).

![GitHub Build Status](https://github.com/infojunkie/musicxml-mma/workflows/Test/badge.svg)

## Installation
- Install `xmllint` (included in [libxml2](http://www.xmlsoft.org/) on most platforms)
- `git submodule update --init --recursive`
- `npm install && npm run build:grooves && npm run build:sef`

## Converting a MusicXML score
- `npm run convert song.musicxml` to convert a MusicXML score to MIDI `song.mid`, which includes the following transformations:
- `npm run convert:unroll song.musicxml` to "unroll" a MusicXML score by expanding all jumps and repeats, to `song.unroll.musicxml`
- `npm run convert:mma song.musicxml` to both unroll a score and convert it to an MMA script `song.mma`
- `npm run convert:midi song.mma` to convert the MMA script to MIDI `song.mid`

## Serving a conversion API endpoint
- `PORT=3001 npm run develop` for development (including hot-reload)
- `PORT=3001 npm run start` for production
- `curl -sSf -F "musicXml=@test/data/salma-ya-salama.musicxml" -F "globalGroove=Maqsum" http://localhost:3001/convert -o "salma-ya-salama.mid"`

## Theory of operation
This converter aims to create a valid MMA accompaniment script out of a MusicXML lead sheet. To accomplish this, it expects to find the following information in the sheet:

- Chord information, expressed as [`harmony` elements](https://w3c.github.io/musicxml/musicxml-reference/elements/harmony/). MMA recognizes a large number of chords, but MusicXML's harmony representation is more general and can lead to invalid chord names. Refer to [chords.musicxml](test/data/chords.musicxml) for a reference on how to express all MMA-supported chords.

- Melody information, expressed as [`note` elements](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/note/). This is converted to an MMA `SOLO` sequence for each measure.

- Optional playback style information, expressed as [`sound/play/other-play` elements](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/other-play/) with attribute `@type = 'groove'`. The content of this element represents the "groove" that is passed to MMA to generate an accompaniment. In case no such playback style information is found, or the specified style is not mapped to an existing MMA groove, the chords are played back as per the lead sheet without further accompaniment. Note that several styles can be specified in a single sheet, since the `sound` element is associated with `measure` or `measure/direction` elements. The groove can be overridden with the argument `globalGroove`.

### Transformation pipeline
The conversion process applies 2 consecutive XSD transformations to the input MusicXML score:
- The first transformation `musicxml-unroll.xsd` "unrolls" the score by expanding all the repeats and jumps into a linear score. the output of this transformation is a new MusicXML score that contains no repeats or jumps, but is otherwise exactly equivalent to the source when it is played back.
- The second transformation `musicxml-mma-unrolled.xsd` transforms a MusicXML score that _it assumes to be unrolled_ to a MMA script that can then be ran through the `mma` tool to produce a MIDI file.

These two transformations are packaged in the higher-lever XSD transformation `musicml-mma.xsd`.

### Output metadata in the MIDI file
The produced MMA script contains metadata that can be useful to downstream consumers of the MIDI file. This metadata is generally expressed as [MIDI Marker meta messages](https://www.recordingblogs.com/wiki/midi-marker-meta-message), with the following syntax:
- `Measure:N` informs the consumer that the MIDI playback has reached measure N (0-based) in the score.
- `Groove:X` informs the consumer that the MIDI playback is henceforth using the specified playback style.
