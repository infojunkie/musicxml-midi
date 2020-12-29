#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-mma produces a valid file for take-five" {
  xslt3 -xsl:musicxml-mma.xsl -s:test/data/take-five.musicxml | ${MMA_HOME:-../mma}/mma.py -n -
}
