#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

set -euo pipefail

@test "mma produces a valid file for take-five with score groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Groove iRealPro-MediumUpSwing54 MidiMark Groove:iRealPro-MediumUpSwing54'
}

@test "mma produces a valid file for take-five with null groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five.musicxml globalGroove=None)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Chord-Sequence Sequence { 1 576t 90; 4 384t 90; } MidiMark Measure:1:2500 Ebm@1 Bbm7@4'
}

@test "mma produces a valid file for take-five with default groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five.musicxml globalGroove=Default)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Groove iRealPro-MediumUpSwing54 MidiMark Groove:iRealPro-MediumUpSwing54'
}

@test "mma produces a valid file for take-five with unknown groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/take-five-unknown.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Chord-Sequence Sequence { 1 576t 90; 4 384t 90; } MidiMark Measure:1:2500 Ebm@1 Bbm7@4'
}

@test "mma produces a valid file for salma-ya-salama" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/salma-ya-salama.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Chord-Sequence Sequence { 1 384t 90; 3 384t 90; }'
  assert_output --partial 'E+@1 E7@3'
}

@test "mma produces a valid file for salma-ya-salama with overridden groove" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/salma-ya-salama.musicxml globalGroove=Maqsum)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'Groove Maqsum MidiMark Groove:Maqsum'
}

@test "mma produces a correct sequence for repeats" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/repeats.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'KeySig 0 Time 4 TimeSig 4/4 Tempo 120 MidiMark Measure:0:2000 z MidiMark Measure:1:2000 z KeySig 0 Time 4 TimeSig 4/4 MidiMark Measure:0:2000 z MidiMark Measure:1:2000 z KeySig 0 Time 4 TimeSig 4/4 MidiMark Measure:0:2000 z MidiMark Measure:1:2000 z MidiMark Measure:2:2000 z MidiMark Measure:3:2000 z MidiMark Measure:2:2000 z MidiMark Measure:3:2000 z MidiMark Measure:2:2000 z MidiMark Measure:4:2000 z MidiMark Measure:5:2000 z MidiMark Measure:2:2000 z MidiMark Measure:4:2000 z MidiMark Measure:5:2000 z MidiMark Measure:2:2000 z MidiMark Measure:4:2000 z MidiMark Measure:5:2000 z MidiMark Measure:2:2000 z MidiMark Measure:4:2000 z MidiMark Measure:5:2000 z MidiMark Measure:6:2000 z MidiMark Measure:7:2000 z MidiMark Measure:8:2000 z MidiMark Measure:7:2000 z MidiMark Measure:9:2000 z MidiMark Measure:7:2000 z MidiMark Measure:8:2000 z MidiMark Measure:7:2000 z MidiMark Measure:9:2000 z MidiMark Measure:7:2000 z MidiMark Measure:8:2000 z MidiMark Measure:7:2000 z MidiMark Measure:9:2000 z MidiMark Measure:7:2000 z MidiMark Measure:8:2000 z MidiMark Measure:7:2000 z MidiMark Measure:10:2000 z MidiMark Measure:11:2000 z KeySig 0 Time 4 TimeSig 4/4 MidiMark Measure:0:2000 z MidiMark Measure:1:2000 z MidiMark Measure:2:2000 z MidiMark Measure:3:2000 z MidiMark Measure:12:2000 z MidiMark Measure:13:2000 z MidiMark Measure:6:2000 z MidiMark Measure:7:2000 z'
}

@test "mma produces a valid file for chords" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/chords.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid and correct file for key-signatures" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/key-signatures.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'KeySig 0'
  assert_output --partial 'KeySig 1# Major'
  assert_output --partial 'KeySig 2# Minor'
  assert_output --partial 'KeySig 3#'
  assert_output --partial 'KeySig 4#'
  assert_output --partial 'KeySig 5#'
  assert_output --partial 'KeySig 6#'
  assert_output --partial 'KeySig 7#'
  assert_output --partial 'KeySig 7b'
  assert_output --partial 'KeySig 6b'
  assert_output --partial 'KeySig 5b'
  assert_output --partial 'KeySig 4b'
  assert_output --partial 'KeySig 3b'
  assert_output --partial 'KeySig 2b'
  assert_output --partial 'KeySig 1b'
  log=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/key-signatures.musicxml 2>&1 >/dev/null)
  run echo $log
  assert_output --partial '[KeySig] Unhandled mode dorian'
  assert_output --partial '[KeySig] Unhandled mode phrygian'
  assert_output --partial '[KeySig] Unhandled mode lydian'
  assert_output --partial '[KeySig] Unhandled mode mixolydian'
  assert_output --partial '[KeySig] Unhandled mode aeolian'
  assert_output --partial '[KeySig] Unhandled mode ionian'
  assert_output --partial '[KeySig] Unhandled mode locrian'
  assert_output --partial '[KeySig] Unhandled key signature'
}

@test "mma produces a valid file for aquele-um" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/aquele-um.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid file for asa-branca" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/asa-branca.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
  run echo $mma
  assert_output --partial 'BeatAdjust -1'
}

@test "mma produces a valid file for that-s-what-friends-are-for" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/that-s-what-friends-are-for.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
}

@test "mma produces a valid file for capim" {
  mma=$(xslt3 -xsl:src/xsl/mma.xsl -s:test/data/capim.musicxml)
  echo "$mma" | ${MMA_HOME:-mma}/mma.py -II -n -
}
