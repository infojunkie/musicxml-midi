#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "lib-musicxml parses batwanness-beek" {
  test=$(xslt3 -xsl:test/lib-musicxml.test.xsl -s:test/data/batwanness-beek.musicxml)
  run echo "$test"
  assert_output --partial '{"measure":{"duration":48,"divisions":12,"index":157,"number":"158","notes":[{},{}],"onset":7536,"tempo":160}}'
}
