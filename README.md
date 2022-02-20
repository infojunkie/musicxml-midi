# musicxml-mma

A MusicXML converter to [Musical MIDI Accompaniment (MMA)](http://www.mellowood.ca/mma/).

![GitHub Build Status](https://github.com/infojunkie/musicxml-mma/workflows/Test/badge.svg)

## Usage

- `git submodule update --init --recursive`
- `git clone git@github.com:infojunkie/mma.git` and set env var `MMA_HOME=/path/to/mma`
- `npm install && npm run grooves`
- `npm run build:mma song.musicxml && npm run build:midi song.mma`
