#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "tuning produces a valid and correct ASCL file for salma-ya-salama" {
  tuning=$(xslt3 -xsl:src/xsl/tuning.xsl -s:test/data/salma-ya-salama.musicxml)
  run echo $tuning
  assert_output --partial '@ABL NOTE_NAMES "C" "Csharp" "D" "E" "F" "Fsharp" "G" "Gsharp" "A" "B"'
}

@test "tuning produces a valid and correct ASCL file for sagittal" {
  tuning=$(xslt3 -xsl:src/xsl/tuning.xsl -s:test/data/sagittal.musicxml 2>&1)
  run echo $tuning
  assert_output --partial "[musicxml:noteAlter] Unhandled accidental 'accSagittalUnused3'"
  assert_output --partial '@ABL NOTE_NAMES "C" "D" "EaccSagittalFlat7CDown" "EaccSagittalFlat5CUp" "EaccSagittal5CommaDown+accSagittalUnused3/EaccSagittal5CommaDown" "FaccSagittal7CommaDown" "F" "FaccSagittal11MediumDiesisUp" "FaccSagittalSharp5CDown" "G" "AaccSagittalFlat5CUp" "AaccSagittal35LargeDiesisDown" "AaccSagittal5CommaDown" "A" "BaccSagittalFlat7CDown" "BaccSagittalFlat" "BaccSagittalFlat5CUp" "BaccSagittal35LargeDiesisDown" "BaccSagittal11LargeDiesisDown" "BaccSagittal5CommaDown"'
}

@test "tuning throws an error on inconsistent pitch alterations" {
  run xslt3 -xsl:src/xsl/tuning.xsl -s:test/data/tuning-error-alter.musicxml
  assert_failure
}
