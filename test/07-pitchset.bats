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
  assert_output --partial '"BaccSagittal35LargeDiesisDown":{"accidental":"accSagittal35LargeDiesisDown","pitch":"B","alter":-0.64915},"EaccSagittal5CommaDown+accSagittalUnused3":{"accidental":["accSagittal5CommaDown","accSagittalUnused3"],"pitch":"E","alter":-0.21506},"BaccSagittal5CommaDown":{"accidental":"accSagittal5CommaDown","pitch":"B","alter":-0.21506},"AaccSagittalFlat5CUp":{"accidental":"accSagittalFlat5CUp","pitch":"A","alter":-0.92179},"AaccSagittal5CommaDown":{"accidental":"accSagittal5CommaDown","pitch":"A","alter":-0.21506},"EaccSagittalFlat5CUp":{"accidental":"accSagittalFlat5CUp","pitch":"E","alter":-0.92179},"BaccSagittalFlat5CUp":{"accidental":"accSagittalFlat5CUp","pitch":"B","alter":-0.92179}'
}

@test "pitchset produecs a valud and correct JSON file for Baiao-Miranda" {
  pitchset=$(xslt3 -xsl:src/xsl/pitchset.xsl -s:test/data/grooves/Baiao-Miranda.musicxml)
  run echo $pitchset
  assert_output --partial '"E4":{"notehead":"normal","pitch":"E","octave":"4"},"E4x":{"notehead":"x","pitch":"E","octave":"4"},"F4":{"notehead":"normal","pitch":"F","octave":"4"}'
}
