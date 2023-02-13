#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-unroll produces a valid file for salma-ya-salama" {
  unroll=$(xslt3 -xsl:musicxml-unroll.xsl -s:test/data/salma-ya-salama.musicxml)
  echo "${unroll}" | xmllint --schema musicxml.xsd --nonet --noout -
}
