#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "slash plugin works" {
  mma=$(cat test/data/slash.mma |${MMA_HOME:-mma}/mma.py -II -n -)
  run echo "$mma"
  assert_output --partial 'Defining new chord m<-9'
}

@test "tuning plugin works" {
  mma=$(cat test/data/tuning.mma |${MMA_HOME:-mma}/mma.py -II -n -)
  run echo "$mma"
}
