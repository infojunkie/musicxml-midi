#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-unroll produces a valid file for repeats" {
  unroll=$(xslt3 -xsl:src/xsl/musicxml-unroll.xsl -s:test/data/repeats.musicxml)
  echo "${unroll}" | xmllint --schema src/xsd/musicxml.xsd --nonet --noout -
}

teardown() {
  if [[ ! -z "${unroll1-}" ]]; then rm -f "$unroll1"; fi
  if [[ ! -z "${unroll2-}" ]]; then rm -f "$unroll2"; fi
}

@test "musicxml-unroll produces an idempotent file for repeats" {
  unroll1=$(mktemp -u)
  xslt3 -xsl:src/xsl/musicxml-unroll.xsl -s:test/data/repeats.musicxml -o:"$unroll1"
  unroll2=$(mktemp -u)
  xslt3 -xsl:src/xsl/musicxml-unroll.xsl -s:"$unroll1" -o:"$unroll2"
  assert $(diff "$unroll1" "$unroll2")
}

@test "musicxml-unroll maintains implicit state" {
  unroll=$(xslt3 -xsl:src/xsl/musicxml-unroll.xsl -s:test/data/blue-bag-folly.musicxml)
  echo "${unroll}" | xmllint --schema src/xsd/musicxml.xsd --nonet --noout -
  run $(echo "${unroll}" | xmllint --xpath "count(//measure[@number='11']//sound[@tempo])" -)
  assert_output --partial '1'
}

@test "musicxml-unroll with renumbering produces a valid file" {
  unroll=$(xslt3 -xsl:src/xsl/musicxml-unroll.xsl -s:test/data/salma-ya-salama.musicxml "renumberMeasures=1")
  echo "${unroll}" | xmllint --schema src/xsd/musicxml.xsd --nonet --noout -
  run $(echo "${unroll}" | xmllint --xpath "count(//measure[@number='1'])" -)
  assert_output --partial '1'
  unroll=$(xslt3 -xsl:src/xsl/musicxml-unroll.xsl -s:test/data/salma-ya-salama.musicxml "renumberMeasures=0")
  echo "${unroll}" | xmllint --schema src/xsd/musicxml.xsd --nonet --noout -
  run $(echo "${unroll}" | xmllint --xpath "count(//measure[@number='1'])" -)
  assert_output --partial '2'
}
