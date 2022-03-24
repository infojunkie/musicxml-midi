#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-mma produces a valid file for take-five" {
  mma=$(xslt3 -xsl:musicxml-mma.sef.json -s:test/data/take-five.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial 'Groove Jazz54'
  assert_output --partial '1 Ebm@1 Bbm7@4 {576tr;384tr;}'
}

@test "musicxml-mma produces a valid file for salma-ya-salama" {
  mma=$(xslt3 -xsl:musicxml-mma.sef.json -s:test/data/salma-ya-salama.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial 'Chord-Custom Sequence { 1 384t 50; 3 384t 50; }'
  assert_output --partial '12 E+@1 E7@3 {96tf+;96te+;96te+;96td+;96te+;96tg#+;96tc++;96tb+;}'
}

@test "musicxml-mma produces a correct sequence for repeats" {
  mma=$(xslt3 -xsl:musicxml-mma.sef.json -s:test/data/repeats.musicxml)
  run echo ${mma}
  assert_output --partial 'MidiMark Measure:1 1 z {768tr;} MidiMark Measure:2 2 z {768tr;} MidiMark Measure:1 1 z {768tr;} MidiMark Measure:2 2 z {768tr;} MidiMark Measure:1 1 z {768tr;} MidiMark Measure:2 2 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:4 4 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:4 4 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:5 5 z {768tr;} MidiMark Measure:6 6 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:5 5 z {768tr;} MidiMark Measure:6 6 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:5 5 z {768tr;} MidiMark Measure:6 6 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:5 5 z {768tr;} MidiMark Measure:6 6 z {768tr;} MidiMark Measure:7 7 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:9 9 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:10 10 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:9 9 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:10 10 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:9 9 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:10 10 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:9 9 z {768tr;} MidiMark Measure:8 8 z {768tr;} MidiMark Measure:11 11 z {768tr;} MidiMark Measure:12 12 z {768tr;} MidiMark Measure:1 1 z {768tr;} MidiMark Measure:2 2 z {768tr;} MidiMark Measure:3 3 z {768tr;} MidiMark Measure:4 4 z {768tr;} MidiMark Measure:13 13 z {768tr;} MidiMark Measure:14 14 z {768tr;} MidiMark Measure:7 7 z {768tr;} MidiMark Measure:8 8 z {768tr;}'
}

@test "musicxml-mma produces a valid file for chords" {
  mma=$(xslt3 -xsl:musicxml-mma.sef.json -s:test/data/chords.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
}

@test "musicxml-mma produces a valid and correct file for ties" {
  mma=$(xslt3 -xsl:musicxml-mma.sef.json -s:test/data/ties.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial 'MidiMark Measure:1 1 z {192tc+;192td+;384te+;} MidiMark Measure:2 2 z {336tc+;48tr;384td+;} MidiMark Measure:3 3 z {192tc+;192td+;192te+;576tf+~;} MidiMark Measure:4 4 z {~1344tc+~;} MidiMark Measure:5 5 z {~<>~;} MidiMark Measure:6 6 z {~768tc+,e+,g+~;} MidiMark Measure:7 7 z {~576tc+,e+,g+;} MidiMark Measure:8 8 z {192tf,a,d+;192ta,d+,f+;192ta,c+,e+;192tf,a,d+;}'
}
