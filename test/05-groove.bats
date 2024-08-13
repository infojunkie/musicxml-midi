#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "groove produces a valid file for baiao-miranda groove" {
  mma=$(xslt3 -it:groove -xsl:src/xsl/groove.xsl groove=Baiao-Miranda)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Groove Baiao-Miranda MidiMark Groove:Baiao-Miranda'
  assert_output --partial 'Measure:3'
}
