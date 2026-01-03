#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "xmlstarlet val works" {
  run xmlstarlet val -q -e -s src/xsd/musicxml.xsd test/data/capim.musicxml
  assert_success
  run xmlstarlet val -q -e -s src/xsd/musicxml.xsd test/data/invalid.musicxml
  assert_failure
  assert_output --partial "The attribute 'bad-attribute' is not allowed"
}

@test "xmlstarlet sel works" {
  output=$(xmlstarlet fo -D test/data/salma-ya-salama.musicxml | xmlstarlet sel -t -v "count(//measure)" -)
  run echo "$output"
  assert_output "36"
  output=$(xmlstarlet fo -D test/data/salma-ya-salama.musicxml | xmlstarlet sel -t -m "//creator[@type='arranger']" -c "text()" -)
  run echo "$output"
  assert_output "Hesham Galal"
}
