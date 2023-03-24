#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-unroll produces a valid file for repeats" {
  unroll=$(xslt3 -xsl:musicxml-unroll.xsl -s:test/data/repeats.musicxml)
  echo "${unroll}" | xmllint --schema musicxml.xsd --nonet --noout -
}

teardown() {
  if [[ ! -z "${unroll1-}" ]]; then rm -f "$unroll1"; fi
  if [[ ! -z "${unroll2-}" ]]; then rm -f "$unroll2"; fi
}

@test "musicxml-unroll produces an idempotent file for repeats" {
  unroll1=$(mktemp -u)
  xslt3 -xsl:musicxml-unroll.xsl -s:test/data/repeats.musicxml -o:"$unroll1"
  unroll2=$(mktemp -u)
  xslt3 -xsl:musicxml-unroll.xsl -s:"$unroll1" -o:"$unroll2"
  assert $(diff "$unroll1" "$unroll2")
}
