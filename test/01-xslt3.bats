#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

@test "xslt3 is installed" {
  run xslt3 -?
  assert_success
}

@test "xslt3 works" {
  run xslt3 -xsl:test/data/test.xsl -s:test/data/take-five.musicxml
  assert_output --partial 'Take Five'
  assert_output --partial 'Measure #24'
}
