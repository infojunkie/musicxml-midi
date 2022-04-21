# musicxml-mma

A MusicXML converter to [Musical MIDI Accompaniment (MMA)](http://www.mellowood.ca/mma/).

![GitHub Build Status](https://github.com/infojunkie/musicxml-mma/workflows/Test/badge.svg)

## Converting a MusicXML file to MIDI
- `git submodule update --init --recursive`
- `git clone git@github.com:infojunkie/mma.git` and set env var `MMA_HOME=/path/to/mma`
- `npm install && npm run build:grooves && npm run build:sef`
- `npm run convert:mma song.musicxml && npm run convert:midi song.mma`

## Serving a conversion API endpoint
- `PORT=3001 npm run develop` for development (including hot-reload)
- `PORT=3001 npm run start` for production
- `curl -sSf -F "musicXml=@test/data/salma-ya-salama.musicxml" -F "globalGroove=Maqsum" http://localhost:3001/convert -o "salma-ya-salama.mid"`

## Theory of operation

This converter aims to create a valid MMA accompaniment script out of a MusicXML lead sheet. To accomplish this, it expects to find the following information in the sheet:

- Chord information, expressed as [`harmony` elements](https://w3c.github.io/musicxml/musicxml-reference/elements/harmony/). MMA recognizes a large number of chords, but MusicXML's harmony representation is more general and can lead to invalid chord names. Refer to [chords.musicxml](test/data/chords.musicxml) for a reference on how to express all MMA-supported chords.

- Melody information, expressed as [`note` elements](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/note/). This is converted to an MMA `SOLO` sequence for each measure.

- Optional playback style information, expressed as [`sound/play/other-play` elements](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/other-play/) with attribute `@type = 'groove'`. The content of this element represents the "groove" that is passed to MMA to generate an accompaniment. In case no such playback style information is found, or the specified style is not mapped to an existing groove, the chords are played back as per the lead sheet without further accompaniment. Note that several styles can be specified in a single sheet, since the `sound` element is associated with `measure` or `measure/direction` elements.

##