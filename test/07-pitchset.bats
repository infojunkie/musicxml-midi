#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "pitchset produces a valid and correct JSON file for batwanness-beek" {
  pitchset=$(xslt3 -xsl:src/xsl/pitchset.xsl -s:test/data/batwanness-beek.musicxml)
  run echo $pitchset
  assert_output --partial '"Fquarter-sharp":{"accidental":"quarter-sharp","pitch":"F","alter":0.5}'
}

@test "pitchset produecs a valud and correct JSON file for sagittal" {
  pitchset=$(xslt3 -xsl:src/xsl/pitchset.xsl -s:test/data/sagittal.musicxml)
  run echo $pitchset
  assert_output --partial '"BaccSagittal35LargeDiesisDown":{"accidental":"accSagittal35LargeDiesisDown","pitch":"B","alter":null},"BaccSagittal5CommaDown":{"accidental":"accSagittal5CommaDown","pitch":"B","alter":null}'
}

@test "pitchset produecs a valud and correct JSON file for Baiao-Miranda" {
  pitchset=$(xslt3 -xsl:src/xsl/pitchset.xsl -s:test/data/grooves/Baiao-Miranda.musicxml)
  run echo $pitchset
  assert_output --partial '"E4":{"notehead":"normal","pitch":"E","octave":"4"},"E4x":{"notehead":"x","pitch":"E","octave":"4"},"F4":{"notehead":"normal","pitch":"F","octave":"4"}'
}
