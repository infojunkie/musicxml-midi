#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "mma produces a valid file for take-five with swing groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'Groove Jazz54'
  assert_output --partial 'Ebm@1 Bbm7@4 {576tr;384tr;}'
}

@test "mma produces a valid file for take-five with overridden groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five.musicxml globalGroove=None)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'Chord-Custom Sequence { 1 576t 50; 4 384t 50; }'
  assert_output --partial 'Ebm@1 Bbm7@4 {576tr;384tr;}'
}

@test "mma produces a valid file for take-five with default groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five.musicxml globalGroove=Default)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'Groove Jazz54'
  assert_output --partial 'Ebm@1 Bbm7@4 {576tr;384tr;}'
}

@test "mma produces a valid file for take-five with unknown groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five-unknown.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'Chord-Custom Sequence { 1 576t 50; 4 384t 50; }'
  assert_output --partial 'Ebm@1 Bbm7@4 {576tr;384tr;}'
}

@test "mma produces a valid file for salma-ya-salama" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/salma-ya-salama.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'Chord-Custom Sequence { 1 384t 50; 3 384t 50; }'
  assert_output --partial 'E+@1 E7@3 {96tfn+;96ten+;96ten+;96tdn+;96ten+;96tg#+;96tcn++;96tbn+;}'
}

@test "mma produces a valid file for salma-ya-salama with overridden groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/salma-ya-salama.musicxml globalGroove=Maqsum)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'Groove Maqsum MidiMark Groove:Maqsum'
}

@test "mma produces a correct sequence for repeats" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/repeats.musicxml)
  run echo ${mma}
  assert_output --partial 'Time 4 TimeSig 4/4 MidiMark Measure:0 z {768tr;} MidiMark Measure:1 z {768tr;} Time 4 TimeSig 4/4 MidiMark Measure:0 z {768tr;} MidiMark Measure:1 z {768tr;} Time 4 TimeSig 4/4 MidiMark Measure:0 z {768tr;} MidiMark Measure:1 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:3 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:3 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:4 z {768tr;} MidiMark Measure:5 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:4 z {768tr;} MidiMark Measure:5 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:4 z {768tr;} MidiMark Measure:5 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:4 z {768tr;} MidiMark Measure:5 z {768tr;} MidiMark Measure:6 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:8 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:9 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:8 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:9 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:8 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:9 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:8 z {768tr;} MidiMark Measure:7 z {768tr;} MidiMark Measure:10 z {768tr;} MidiMark Measure:11 z {768tr;} Time 4 TimeSig 4/4 MidiMark Measure:0 z {768tr;} MidiMark Measure:1 z {768tr;} MidiMark Measure:2 z {768tr;} MidiMark Measure:3 z {768tr;} MidiMark Measure:12 z {768tr;} MidiMark Measure:13 z {768tr;} MidiMark Measure:6 z {768tr;} MidiMark Measure:7 z {768tr;}'
}

@test "mma produces a valid file for chords" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/chords.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid and correct file for ties" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/ties.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'MidiMark Measure:0 z {192tcn+;192tdn+;384ten+;} MidiMark Measure:1 z {336tcn+;48tr;384tdn+;} MidiMark Measure:2 z {192tcn+;192tdn+;192ten+;576tfn+~;} MidiMark Measure:3 z {~1344tcn+~;} MidiMark Measure:4 z {~<>~;} MidiMark Measure:5 z {~768tcn+,en+,gn+~;} MidiMark Measure:6 z {~576tcn+,en+,gn+;} MidiMark Measure:7 z {192tfn,an,dn+;192tan,dn+,fn+;192tan,cn+,en+;192tfn,an,dn+;}'
}

@test "mma produces a valid file for aquele-um" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/aquele-um.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid file for batwanness-beek" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/batwanness-beek.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid file for asa-branca" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/asa-branca.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo ${mma}
  assert_output --partial 'BeatAdjust -1'
}

@test "mma produces a valid file for that-s-what-friends-are-for" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/that-s-what-friends-are-for.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid file for capim" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/capim.musicxml)
  echo "${mma}" | ${MMA_HOME:-mma}/mma.py -II -n -
}
