#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "musicxml-timemap produces a valid JSON file for salma-ya-salama" {
  timemap=$(xslt3 -xsl:musicxml-timemap.xsl -s:test/data/salma-ya-salama.musicxml)
  echo "${timemap}" | jq type 1>/dev/null
}
