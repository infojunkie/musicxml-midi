#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-mma produces a valid file for take-five" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/take-five.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial 'Groove Jazz54'
}

@test "musicxml-mma produces a valid file for salma-ya-salama" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/salma-ya-salama.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial 'Chord-Custom Sequence { 1 384t 50; 3 384t 50; }'
  assert_output --partial '12 E+@1 E7@3 {96tf+;96te+;96te+;96td+;96te+;96tg#+;96tc++;96tb+;}'
}

@test "musicxml-mma produces a correct sequence for repeats" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/repeats.musicxml)
  run echo ${mma}
  assert_output --partial '1 z {768tr;} 2 z {768tr;} 1 z {768tr;} 2 z {768tr;} 1 z {768tr;} 2 z {768tr;} 3 z {768tr;} 4 z {768tr;} 3 z {768tr;} 4 z {768tr;} 3 z {768tr;} 5 z {768tr;} 6 z {768tr;} 3 z {768tr;} 5 z {768tr;} 6 z {768tr;} 3 z {768tr;} 5 z {768tr;} 6 z {768tr;} 3 z {768tr;} 5 z {768tr;} 6 z {768tr;} 7 z {768tr;} 8 z {768tr;} 9 z {768tr;} 8 z {768tr;} 10 z {768tr;} 8 z {768tr;} 9 z {768tr;} 8 z {768tr;} 10 z {768tr;} 8 z {768tr;} 9 z {768tr;} 8 z {768tr;} 10 z {768tr;} 8 z {768tr;} 9 z {768tr;} 8 z {768tr;} 11 z {768tr;} 12 z {768tr;} 1 z {768tr;} 2 z {768tr;} 3 z {768tr;} 4 z {768tr;} 13 z {768tr;} 14 z {768tr;} 7 z {768tr;} 8 z {768tr;}'
}

@test "musicxml-mma produces a valid file for chords" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/chords.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
}

@test "musicxml-mma produces a valid and correct file for ties" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/ties.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial '1 z {192tc+;192td+;384te+;} 2 z {336tc+;48tr;384td+;} 3 z {192tc+;192td+;192te+;576tf+~;} 4 z {~1344tc+~;} 5 z {~<>~;} 6 z {~768tc+,e+,g+~;} 7 z {~576tc+,e+,g+;} 8 z {192tf,a,d+;192ta,d+,f+;192ta,c+,e+;192tf,a,d+;}'
}
