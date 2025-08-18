meta:
  id: standard_midi_file
  title: Standard MIDI file
  file-extension:
    - mid
    - midi
    - smf
  xref:
    justsolve: MIDI
    loc:
      - fdd000102 # MIDI Sequence Data
      - fdd000119 # Standard MIDI File
    mime: audio/midi
    pronom: x-fmt/230
    wikidata: Q10610388
  license: Cc0-1.0
  imports:
    - /common/vlq_base128_be
  endian: be
doc: |
  Standard MIDI file, typically known just as "MID", is a standard way
  to serialize series of MIDI events, which is a protocol used in many
  music synthesizers to transfer music data: notes being played,
  effects being applied, etc.

  Internally, file consists of a header and series of tracks, every
  track listing MIDI events with certain header designating time these
  events are happening.

  NOTE: Rarely, MIDI files employ certain stateful compression scheme
  to avoid storing certain elements of further elements, instead
  reusing them from events which happened earlier in the
  stream. Kaitai Struct (as of v0.9) is currently unable to parse
  these, but files employing this mechanism are relatively rare.
seq:
  - id: hdr
    type: header
  - id: tracks
    type: track
    repeat: expr
    repeat-expr: hdr.num_tracks
types:
  header:
    seq:
      - id: magic
        contents: "MThd"
      - id: len_header
        type: u4
      - id: format
        type: u2
      - id: num_tracks
        type: u2
      - id: division
        type: s2
  track:
    seq:
      - id: magic
        contents: "MTrk"
      - id: len_events
        type: u4
      - id: events
        type: track_events
        size: len_events
  track_events:
    seq:
      - id: event
        type: track_event
        repeat: eos
  track_event:
    seq:
      - id: v_time
        type: vlq_base128_be
      - id: event_header
        type: u1
      - id: meta_event_body
        type: meta_event_body
        if: event_header == 0xff
      - id: sysex_body
        type: sysex_event_body
        if: event_header == 0xf0
      - id: event_body
        type:
          switch-on: event_type
          cases:
            0x80: note_off_event
            0x90: note_on_event
            0xa0: polyphonic_pressure_event
            0xb0: controller_event
            0xc0: program_change_event
            0xd0: channel_pressure_event
            0xe0: pitch_bend_event
    instances:
      event_type:
        value: event_header & 0xf0
      channel:
        value: event_header & 0xf
        if: event_type != 0xf0
  meta_event_body:
    seq:
      - id: meta_type
        type: u1
        enum: meta_type_enum
      - id: len
        type: vlq_base128_be
      - id: body
        size: len.value
    enums:
      meta_type_enum:
        0x00: sequence_number
        0x01: text_event
        0x02: copyright
        0x03: sequence_track_name
        0x04: instrument_name
        0x05: lyric_text
        0x06: marker_text
        0x07: cue_point
        0x20: midi_channel_prefix_assignment
        0x2f: end_of_track
        0x51: tempo
        0x54: smpte_offset
        0x58: time_signature
        0x59: key_signature
        0x7f: sequencer_specific_event
  note_off_event:
    -webide-representation: '{note_name}'
    seq:
      - id: note
        type: u1
      - id: velocity
        type: u1
    instances:
      note_name:
        value: '["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][note % 12] + (note / 12 - 1).to_s'
  note_on_event:
    -webide-representation: '{note_name}'
    seq:
      - id: note
        type: u1
      - id: velocity
        type: u1
    instances:
      note_name:
        value: '["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][note % 12] + (note / 12 - 1).to_s'
  polyphonic_pressure_event:
    seq:
      - id: note
        type: u1
      - id: pressure
        type: u1
  controller_event:
    seq:
      - id: controller
        type: u1
      - id: value
        type: u1
  program_change_event:
    seq:
      - id: program
        type: u1
  channel_pressure_event:
    seq:
      - id: pressure
        type: u1
  pitch_bend_event:
    seq:
      - id: b1
        type: u1
      - id: b2
        type: u1
    instances:
      bend_value:
        value: (b2 << 7) + b1 - 0x4000
      adj_bend_value:
        value: bend_value - 0x4000
  sysex_event_body:
    -webide-representation: '{body.sub_id}'
    seq:
      - id: len
        type: vlq_base128_be
      - id: sysex_type
        type: u1
      - id: device_id
        type: u1
      - id: body
        type:
          switch-on: sysex_type
          cases:
            0x7e: sysex_non_real_time_body
            0x7f: sysex_real_time_body
      - id: eox
        contents: [0xf7]
  sysex_non_real_time_body:
    seq:
      - id: sub_id
        type: u2
  sysex_non_real_time_body:
    seq:
      - id: sub_id
        type: u2
      - id: data
        size: _parent.len.value - 5
  sysex_real_time_body:
    seq:
      - id: sub_id
        type: u2
        enum: sysex_real_time_enum
      - id: data
        size: _parent.len.value - 5
        type:
          switch-on: sub_id
          cases:
            'sysex_real_time_enum::midi_tuning_standard_single_note_tuning_change': sysex_mts_single
    enums:
      sysex_real_time_enum:
        0x0101: midi_time_code_full_message
        0x0102: midi_time_code_user_bits
        0x0200: midi_show_control
        0x0300: notation_bar_number
        0x0301: notation_time_signature_immediate
        0x0302: notation_time_signature_delayed
        0x0401:	device_control_master_volume
        0x0402: device_control_master_balance
        0x0403: device_control_master_fine_tuning
        0x0404: device_control_master_coarse_tuning
        0x0405: device_control_global_parameter_control
        0x0500:	real_time_mtc_cueing_special
        0x0501:	real_time_mtc_cueing_punch_in_points
        0x0502:	real_time_mtc_cueing_punch_out_points
        0x0505:	real_time_mtc_cueing_event_start_points
        0x0506:	real_time_mtc_cueing_event_stop_points
        0x0507:	real_time_mtc_cueing_event_start_points_additional_info
        0x0508:	real_time_mtc_cueing_event_stop_points_additional_info
        0x050b:	real_time_mtc_cueing_cue_points
        0x050c:	real_time_mtc_cueing_cue_points_additional_info
        0x050d:	real_time_mtc_cueing_reserved
        0x050e:	real_time_mtc_cueing_event_name_additional_info
        0x0802:	midi_tuning_standard_single_note_tuning_change
        0x0807:	midi_tuning_standard_single_note_tuning_change_bank_select
        0x0808:	midi_tuning_standard_scale_octave_tuning_1_byte_format
        0x0809:	midi_tuning_standard_scale_octave_tuning_2_byte_format
  sysex_mts_single:
    seq:
      - id: program
        type: u1
      - id: count
        type: u1
      - id: tunings
        type: three_byte_tuning
        repeat: expr
        repeat-expr: count
  three_byte_tuning:
    seq:
      - id: key
        type: u1
      - id: semitone
        type: u1
      - id: msb
        type: u1
      - id: lsb
        type: u1
    instances:
      cents:
        value: |
          semitone == 0x7f and msb == 0x7f and lsb == 0x7f ? (key - 60.0) * 100.0 :
          (semitone - 60.0) * 100.0 + msb * 100.0 / 128.0 + lsb * 100.0 / 16384.0
      frequency:
        value: |
          semitone == 0x7f and msb == 0x7f and lsb == 0x7f ? _root.midi_note_to_frequency[key] :
          msb == 0 and lsb == 0 ? _root.midi_note_to_frequency[semitone] :
          0.0
        doc: |
          Power operator (**) is not implemented, so frequency will show 0.0
          when the lookup into midi_note_to_frequency cannot be done.
instances:
  midi_note_to_frequency:
    value: |
      [
        8.18, 8.66, 9.18, 9.72, 10.30, 10.91, 11.56, 12.25,
        12.98, 13.75, 14.57, 15.43, 16.35, 17.32, 18.35, 19.45,
        20.60, 21.83, 23.12, 24.50, 25.96, 27.50, 29.14, 30.87,
        32.70, 34.65, 36.71, 38.89, 41.20, 43.65, 46.25, 49.00,
        51.91, 55.00, 58.27, 61.74, 65.41, 69.30, 73.42, 77.78,
        82.41, 87.31, 92.50, 98.00, 103.83, 110.00, 116.54, 123.47,
        130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.00, 196.00,
        207.65, 220.00, 233.08, 246.94, 261.63, 277.18, 293.66, 311.13,
        329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88,
        523.25, 554.37, 587.33, 622.25, 659.26, 698.46, 739.99, 783.99,
        830.61, 880.00, 932.33, 987.77, 1046.50, 1108.73, 1174.66, 1244.51,
        1318.51, 1396.91, 1479.98, 1567.98, 1661.22, 1760.00, 1864.66, 1975.53,
        2093.00, 2217.46, 2349.32, 2489.02, 2637.02, 2793.83, 2959.96, 3135.96,
        3322.44, 3520.00, 3729.31, 3951.07, 4186.01, 4434.92, 4698.64, 4978.03,
        5274.04, 5587.65, 5919.91, 6271.93, 6644.88, 7040.00, 7458.62, 7902.13,
        8372.02, 8869.84, 9397.27, 9956.06, 10548.08, 11175.30, 11839.82, 12543.85
      ]
    doc: |
      Lookup table to convert a MIDI note into a frequency in Hz
      The lookup table represents the formula (2 ** ((midi_note - 69) / 12)) * 440
    doc-ref: https://en.wikipedia.org/wiki/MIDI_tuning_standard
