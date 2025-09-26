#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "lib-musicxml parses hello-world" {
  test=$(xslt3 -xsl:test/lib-musicxml.hello-world.xsl -it:test)
  run echo "$test"
  assert_output '[{"measure":{"duration":4,"divisions":1,"index":0,"number":"1","notes":[{}],"onset":0,"tempo":120}}]'
}

@test "lib-musicxml parses note accidentals" {
  test=$(xslt3 -xsl:test/lib-musicxml.accidentals.xsl -it:test)
  run echo "$test"
  assert_output '[{"measure":{"notes":[{"accidental":"natural","note":"C"}]}},{"measure":{"notes":[{"accidental":"sharp","note":"C"}]}},{"measure":{"notes":[{"accidental":"flat","note":"C"}]}},{"measure":{"notes":[{"accidental":"slash-flat","note":"A"},{"accidental":"quarter-flat","note":"B"},{"accidental":"natural","note":"C"},{"accidental":"accSagittalSharp","note":"F"},{"accidental":"accSagittalFlat","note":"C"}]}}]'
}

@test "lib-musicxml parses note alters" {
  test=$(xslt3 -xsl:test/lib-musicxml.alters.xsl -it:test)
  run echo "$test"
  assert_output --partial '[{"measure":{"notes":[{"accidental":"natural","note":"C","tuning":0}]}},{"measure":{"notes":[{"accidental":"sharp","note":"C","tuning":1}]}},{"measure":{"notes":[{"accidental":"flat","note":"C","tuning":-1}]}},{"measure":{"notes":[{"accidental":"slash-flat","note":"A","tuning":-0.44},{"accidental":"quarter-flat","note":"B","tuning":-0.5},{"accidental":"natural","note":"C","tuning":0},{"accidental":"accidentalParensLeft","note":"F","tuning":null},{"accidental":["accSagittalFlat","accSagittalSharp"],"note":"C","tuning":0}]}}]'
}
