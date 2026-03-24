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
  license: CC0-1.0
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
    -webide-representation: '{event_type}'
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
            'event_type_enum::note_off': note_off_event
            'event_type_enum::note_on': note_on_event
            'event_type_enum::polyphonic_pressure': polyphonic_pressure_event
            'event_type_enum::controller': controller_event
            'event_type_enum::program_change': program_change_event
            'event_type_enum::channel_pressure': channel_pressure_event
            'event_type_enum::pitch_bend': pitch_bend_event
    instances:
      event_type:
        value: event_header & 0xf0
        enum: event_type_enum
      channel:
        value: event_header & 0xf
        if: event_type != event_type_enum::meta_or_sysex_event
    enums:
      event_type_enum:
        0x80: note_off
        0x90: note_on
        0xa0: polyphonic_pressure
        0xb0: controller
        0xc0: program_change
        0xd0: channel_pressure
        0xe0: pitch_bend
        0xf0: meta_or_sysex_event
  meta_event_body:
    seq:
      - id: meta_type
        type: u1
        enum: meta_type_enum
      - id: len
        type: vlq_base128_be
      - id: body
        type:
          switch-on: meta_type
          cases:
            'meta_type_enum::sequence_number': meta_sequence_number_event
            'meta_type_enum::text_event': meta_generic_event
            'meta_type_enum::copyright': meta_generic_event
            'meta_type_enum::sequence_track_name': meta_generic_event
            'meta_type_enum::instrument_name': meta_generic_event
            'meta_type_enum::lyric_text': meta_generic_event
            'meta_type_enum::marker_text': meta_generic_event
            'meta_type_enum::cue_point': meta_generic_event
            'meta_type_enum::midi_channel_prefix_assignment': meta_generic_event
            'meta_type_enum::end_of_track': meta_end_of_track_event
            'meta_type_enum::tempo': meta_tempo_event
            'meta_type_enum::smpte_offset': meta_generic_event
            'meta_type_enum::time_signature': meta_time_signature_event
            'meta_type_enum::key_signature': meta_key_signature_event
            'meta_type_enum::sequencer_specific_event': meta_generic_event
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
  meta_generic_event:
    -webide-representation: '{text}'
    seq:
      - id: text
        type: str
        encoding: ASCII
        size: _parent.len.value
  meta_sequence_number_event:
    seq:
      - id: sequence_number
        type: u2
        if: _parent.len.value > 0
  meta_end_of_track_event:
    seq: []
  meta_key_signature_event:
    -webide-representation: '{key_signature}'
    seq:
      - id: sharps
        type: s1
      - id: minor
        type: u1
    instances:
      key_signature:
        value: '["Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E", "B", "F#", "C#"][sharps + 7] + ["maj", "min"][minor]'
  meta_time_signature_event:
    -webide-representation: '{numerator_s}/{denominator_s}'
    seq:
      - id: numerator
        type: u1
        doc: Numerator of the time signature and has values between 0x00 and 0xFF (0 and 255).
      - id: denominator
        type: u1
        doc: |
          The power to which the number 2 must be raised to obtain the time signature denominator.
          Thus, if the fifth byte is 0, the denominator is 20 = 1, denoting whole notes.
          If the fifth byte is 1, the denominator is 21=2 denoting half notes, and so on.
      - id: pulse
        type: u1
        doc: |
          The metronome pulse in terms of the number of MIDI clock ticks per click.
          Assuming 24 MIDI clocks per quarter note, if the value of the sixth byte is 48,
          the metronome will click every two quarter notes, or in other words, every half-note.
      - id: beat
        type: u1
        doc: The number of 32nd notes per beat. This byte is usually 8 as there is usually one quarter note per beat and one quarter note contains eight 32nd notes.
    instances:
      numerator_s:
        value: numerator.to_s
      denominator_s:
        value: '["1", "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024"][denominator]'
  meta_tempo_event:
    -webide-representation: '{bpm:dec} bpm'
    seq:
      - id: b3
        type: u1
      - id: b2
        type: u1
      - id: b1
        type: u1
    instances:
      bpm:
        value: '60000000 / (b1 | (b2 << 8) | (b3 << 16))'
  note_off_event:
    -webide-representation: 'key={key} note={note} drum={drum}'
    seq:
      - id: key
        type: u1
      - id: velocity
        type: u1
    instances:
      note:
        value: '["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][key % 12] + (key / 12 - 1).to_s'
        if: _parent.channel != 9
      drum:
        value: key
        enum: general_midi_drums
        if: _parent.channel == 9
  note_on_event:
    -webide-representation: 'key={key} note={note} drum={drum}'
    seq:
      - id: key
        type: u1
      - id: velocity
        type: u1
    instances:
      note:
        value: '["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][key % 12] + (key / 12 - 1).to_s'
        if: _parent.channel != 9
      drum:
        value: key
        enum: general_midi_drums
        if: _parent.channel == 9
  polyphonic_pressure_event:
    seq:
      - id: key
        type: u1
      - id: pressure
        type: u1
  controller_event:
    -webide-representation: '{controller} {value:dec}'
    seq:
      - id: controller
        type: u1
        enum: cc_enum
      - id: value
        type: u1
    enums:
      cc_enum:
        0x00: bank_select
        0x01: modulation
        0x02: breath_controller
        0x03: cc_undefined1
        0x04: foot_controller
        0x05: portamento_time
        0x06: data_entry_msb
        0x07: volume
        0x08: balance
        0x09: cc_undefined2
        0x0a: pan
        0x0b: expression
        0x0c: effect_controller1
        0x0d: effect_controller2
        0x0e: cc_undefined3
        0x0f: cc_undefined4
        0x10: cc_general1
        0x11: cc_general2
        0x12: cc_general3
        0x13: cc_general4
        0x14: cc_undefined5
        0x15: cc_undefined6
        0x16: cc_undefined7
        0x17: cc_undefined8
        0x18: cc_undefined9
        0x19: cc_undefined10
        0x1a: cc_undefined11
        0x1b: cc_undefined12
        0x1c: cc_undefined13
        0x1d: cc_undefined14
        0x1e: cc_undefined15
        0x20: controller0_lsb
        0x21: controller1_lsb
        0x22: controller2_lsb
        0x23: controller3_lsb
        0x24: controller4_lsb
        0x25: controller5_lsb
        0x26: controller6_lsb
        0x27: controller7_lsb
        0x28: controller8_lsb
        0x29: controller9_lsb
        0x2a: controller10_lsb
        0x2b: controller11_lsb
        0x2c: controller12_lsb
        0x2d: controller13_lsb
        0x2e: controller14_lsb
        0x2f: controller15_lsb
        0x30: controller16_lsb
        0x31: controller17_lsb
        0x32: controller18_lsb
        0x33: controller19_lsb
        0x34: controller20_lsb
        0x35: controller21_lsb
        0x36: controller22_lsb
        0x37: controller23_lsb
        0x38: controller24_lsb
        0x39: controller25_lsb
        0x3a: controller26_lsb
        0x3b: controller27_lsb
        0x3c: controller28_lsb
        0x3d: controller29_lsb
        0x3e: controller30_lsb
        0x3f: controller31_lsb
        0x40: damper_sustain_switch
        0x41: portamento_switch
        0x42: sostenuto_switch
        0x43: soft_pedal_switch
        0x44: legato_switch
        0x45: hold2
        0x46: sound_controller1
        0x47: sound_controller2
        0x48: sound_controller3
        0x49: sound_controller4
        0x4a: sound_controller5
        0x4b: sound_controller6
        0x4c: sound_controller7
        0x4d: sound_controller8
        0x4e: sound_controller9
        0x4f: sound_controller10
        0x50: generic_controller_switch1
        0x51: generic_controller_switch2
        0x52: generic_controller_switch3
        0x53: generic_controller_switch4
        0x54: portamento_control
        0x55: cc_undefined16
        0x56: cc_undefined17
        0x57: cc_undefined18
        0x58: cc_undefined19
        0x59: cc_undefined20
        0x5a: cc_undefined21
        0x5b: effect1_depth_reverb
        0x5c: effect2_depth_tremolo
        0x5d: effect3_depth_chorus
        0x5e: effect4_depth_detune
        0x5f: effect5_depth_phaser
        0x60: data_increment
        0x61: data_decrement
        0x62: nrpn_lsb
        0x63: nrpn_msb
        0x64: rpn_lsb
        0x65: rpn_msb
        0x66: cc_undefined22
        0x67: cc_undefined23
        0x68: cc_undefined24
        0x69: cc_undefined25
        0x6a: cc_undefined26
        0x6b: cc_undefined27
        0x6c: cc_undefined28
        0x6d: cc_undefined29
        0x6e: cc_undefined30
        0x6f: cc_undefined31
        0x70: cc_undefined32
        0x71: cc_undefined33
        0x72: cc_undefined34
        0x73: cc_undefined35
        0x74: cc_undefined36
        0x75: cc_undefined37
        0x76: cc_undefined38
        0x77: cc_undefined39
        0x78: all_sound_off
        0x79: reset_all_controllers
        0x7a: local_switch
        0x7b: all_notes_off
        0x7c: omni_off_mode
        0x7d: omni_on_mode
        0x7e: mono_mode
        0x7f: poly_mode
  program_change_event:
    -webide-representation: '{program}'
    seq:
      - id: program
        type: u1
        enum: general_midi_program
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
      bend:
        value: (b2 << 7) + b1 - 0x4000
      adj_bend:
        value: bend - 0x4000
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
    -webide-representation: '{key:dec} = {cents_int:dec} cents'
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
      cents_int:
        value: cents.as<s4>
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
enums:
  general_midi_program:
    0:  piano_acoustic_grand
    1:  piano_bright_acoustic
    2:  piano_electric_grand
    3:  piano_honky_tonk
    4:  piano_electric1
    5:  piano_electric2
    6:  piano_harpsichord
    7:  piano_clavinet
    8:  chromatic_perc_celesta
    9:  chromatic_perc_glockenspiel
    10: chromatic_perc_music_box
    11: chromatic_perc_vibraphone
    12: chromatic_perc_marimba
    13: chromatic_perc_xylophone
    14: chromatic_perc_tubular_bells
    15: chromatic_perc_dulcimer
    16: organ_drawbar
    17: organ_percussive
    18: organ_rock
    19: organ_church
    20: organ_reed
    21: organ_accordion
    22: organ_harmonica
    23: organ_tango
    24: guitar_nylon_string
    25: guitar_steel_string
    26: guitar_electric_jazz
    27: guitar_electric_clean
    28: guitar_electric_muted
    29: guitar_overdriven
    30: guitar_distortion
    31: guitar_harmonics
    32: bass_acoustic
    33: bass_electric_finger
    34: bass_electric_pick
    35: bass_fretless
    36: bass_slap1
    37: bass_slap2
    38: bass_synth1
    39: bass_synth2
    40: strings_violin
    41: strings_viola
    42: strings_cello
    43: strings_contrabass
    44: strings_tremolo
    45: strings_pizzicato
    46: strings_orchestral
    47: strings_timpani
    48: strings_ensemble1
    49: strings_ensemble2
    50: strings_synth1
    51: strings_synth2
    52: strings_choir_aahs
    53: strings_voice_oohs
    54: strings_synth_voice
    55: strings_orchestra_hit
    56: brass_trumpet
    57: brass_trombone
    58: brass_tuba
    59: brass_muted_trumpet
    60: brass_french_horn
    61: brass_section
    62: brass_synth1
    63: brass_synth2
    64: reed_soprano_sax
    65: reed_alto_sax
    66: reed_tenor_sax
    67: reed_baritone_sax
    68: reed_oboe
    69: reed_english_horn
    70: reed_bassoon
    71: reed_clarinet
    72: pipe_piccolo
    73: pipe_flute
    74: pipe_recorder
    75: pipe_pan_flute
    76: pipe_bottle_blow
    77: pipe_shakuhachi
    78: pipe_whistle
    79: pipe_ocarina
    80: lead_square
    81: lead_sawtooth
    82: lead_calliope
    83: lead_chiff
    84: lead_charang
    85: lead_voice
    86: lead_fifths
    87: bass_lead
    88: pad_new_age
    89: pad_warm
    90: pad_polysynth
    91: pad_choir
    92: pad_bowed
    93: pad_metallic
    94: pad_halo
    95: pad_sweep
    96: fx_rain
    97: fx_soundtrack
    98: fx_crystal
    99: fx_atmosphere
    100: fx_brightness
    101: fx_goblins
    102: fx_echoes
    103: fx_scifi
    104: ethnic_sitar
    105: ethnic_banjo
    106: ethnic_shamisen
    107: ethnic_koto
    108: ethnic_kalimba
    109: ethnic_bagpipe
    110: ethnic_fiddle
    111: ethnic_shanai
    112: percussive_tinkle_bell
    113: percussive_agogo_bells
    114: percussive_steel_drums
    115: percussive_woodblock
    116: percussive_taiko_drum
    117: percussive_melodic_tom
    118: percussive_synth_drum
    119: percussive_reverse_cymbal
    120: fx_guitar_fret_noise
    121: fx_breath_noise
    122: fx_seashore
    123: fx_bird_tweet
    124: fx_telephone_ring
    125: fx_helicopter
    126: fx_applause
    127: fx_gunshot
  general_midi_drums:
    27: high_q
    28: slap
    29: scratch_push
    30: scratch_pull
    31: sticks
    32: square_click
    33: metronome_click
    34: metronome_bell
    35: kick_drum2
    36: kick_drum1
    37: side_kick
    38: snare_drum1
    39: hand_clap
    40: snare_drum2
    41: low_tom2
    42: closed_hihat
    43: low_tom1
    44: pedal_hihat
    45: mid_tom2
    46: open_hihat
    47: mid_tom1
    48: high_tom2
    49: crash_cymbal1
    50: high_tom1
    51: ride_cymbal1
    52: chinese_cymbal
    53: ride_bell
    54: tambourine
    55: splash_cymbal
    56: cow_bell
    57: crash_cymbal2
    58: vibra_slap
    59: ride_cymbal2
    60: high_bongo
    61: low_bongo
    62: mute_high_conga
    63: open_high_conga
    64: low_conga
    65: high_timbale
    66: low_timbale
    67: high_agogo
    68: low_agogo
    69: cabasa
    70: maracas
    71: short_hi_whistle
    72: long_low_whistle
    73: short_guiro
    74: long_guiro
    75: claves
    76: high_wood_block
    77: low_wood_block
    78: mute_cuica
    79: open_cuica
    80: mute_triangle
    81: open_triangle
    82: shaker
    83: jingle_bell
    84: belltree
    85: castanets
    86: mute_surdo
    87: open_surdo
