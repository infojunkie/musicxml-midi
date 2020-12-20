#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

@test "saxonb-xslt is installed" {
  run saxonb-xslt -t
  assert_failure 2
}

@test "saxonb-xslt works" {
  run saxonb-xslt -xsl:test/data/test.xsl -s:test/data/take-five.musicxml
  assert_output --partial 'Take Five'
  assert_output --partial 'Measure #24'
}
