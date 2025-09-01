#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "tuning produces a valid and correct ASCL file for salma-ya-salama" {
  tuning=$(xslt3 -xsl:src/xsl/tuning.xsl -s:test/data/salma-ya-salama.musicxml)
  run echo $tuning
  assert_output --partial '@ABL NOTE_NAMES "C" "Csharp" "D" "E" "F" "Fsharp" "G" "Gsharp" "A" "B"'
}
