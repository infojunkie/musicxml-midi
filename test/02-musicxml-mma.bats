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
