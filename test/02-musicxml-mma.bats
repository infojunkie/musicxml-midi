#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-mma produces a valid file for take-five" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/take-five.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial '// Take Five'
  assert_output --partial 'Groove Jazz54'
}

@test "musicxml-mma produces a valid file for salma-ya-salama" {
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/salma-ya-salama.musicxml)
  echo ${mma} | ${MMA_HOME:-../mma}/mma.py -n -
  run echo ${mma}
  assert_output --partial 'Chord Sequence { 1 384t 50; 3 384t 50; }'
  assert_output --partial '12 Eaug@1 E7@3'
}
