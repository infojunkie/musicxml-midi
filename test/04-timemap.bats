#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "timemap produces a valid and correct JSON file for asa-branca" {
  timemap=$(xslt3 -xsl:src/xsl/timemap.xsl -s:test/data/asa-branca.musicxml)
  echo "${timemap}" | jq type 1>/dev/null
  select=$(echo "${timemap}" | jq '.[] | select(.measure == 1)')
  run echo ${select}
  assert_output --partial '"timestamp": 500'
  assert_output --partial '"duration": 1000'
}
