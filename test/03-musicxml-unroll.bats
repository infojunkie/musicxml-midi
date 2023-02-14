#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-unroll produces a valid file for salma-ya-salama" {
  unroll=$(xslt3 -xsl:musicxml-unroll.xsl -s:test/data/salma-ya-salama.musicxml)
  echo "${unroll}" | xmllint --schema musicxml.xsd --nonet --noout -
}

@test "musicxml-unroll produces an idempotent file for salma-ya-salama" {
  unroll=$(mktemp)
  xslt3 -xsl:musicxml-unroll.xsl -s:test/data/salma-ya-salama.musicxml -o:"$unroll"
  mma=$(xslt3 -xsl:musicxml-mma.xsl -s:test/data/salma-ya-salama.musicxml)
  mma_unroll=$(xslt3 -xsl:musicxml-mma.xsl -s:"$unroll")
  rm -f "$unroll"
  assert_equal "$mma" "$mma_unroll"
}
