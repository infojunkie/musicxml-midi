<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mma="http://www.mellowood.ca/mma"
  exclude-result-prefixes="xs mma"
  version="2.0"
>
<xsl:output media-type="text/plain" omit-xml-declaration="yes"/>

<!-- Inspired by https://github.com/k8bushlover/XSLT-MusicXmlToSessionBand -->

<xsl:param name="chordVolume" select="50"/>

<xsl:variable name="divisions" select="score-partwise/part/measure/attributes/divisions"/>
<xsl:variable name="beats" select="score-partwise/part/measure/attributes/time/beats"/>
<xsl:variable name="beatType" select="score-partwise/part/measure/attributes/time/beat-type"/>
<xsl:variable name="style" select="score-partwise/identification/creator[@type='lyricist']"/>

<xsl:template match="score-partwise">
// <xsl:value-of select="translate(work/work-title, '&#xa;', ' ')"/>
  <xsl:apply-templates select="identification/creator[@type='lyricist']" mode="style"/>
  <xsl:if test="not($style)">
Begin Chord
  Voice Piano1
  Octave 5
  Articulate 80
  Volume m
End
  </xsl:if>
  <xsl:apply-templates select="part/measure"/>
</xsl:template>

<xsl:template match="creator" mode="style">
<!--
  Extract playback style from //identification/creator[@type='lyricist'] as exported by iReal Pro (and emulated by infojunkie/ireal-musicxml).
  See discussion at https://github.com/w3c/musicxml/issues/347

  TODO Map iReal Pro grooves to MMA grooves
-->
  <xsl:variable name="groove" select="if (contains(., '(')) then translate(replace(., '.*?\((.*?)\)', '$1'), ' ', '') else translate(., ' ', '')"/>
Groove <xsl:choose>
    <xsl:when test="contains(lower-case($groove), 'swing')">
      <xsl:choose>
        <xsl:when test="$beats = 5 and $beatType = 4">Jazz54</xsl:when>
        <xsl:otherwise>Swing</xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$groove"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="barline" mode="start">
  <xsl:text>&#xa;</xsl:text>
  <xsl:choose>
    <!-- Start a Repeat block. -->
    <xsl:when test="repeat/@direction = 'forward'">Repeat</xsl:when>
    <!-- Start a RepeatEnding block unless it's the last repeat section (of this Repeat block or of the entire score). -->
    <xsl:when test="
      ending/@type = 'start'
      and ../following-sibling::measure/barline[ending/@type='start']
      and not(../following-sibling::measure/barline[ending/@type='start']/ending/@number < ending/@number)
    ">RepeatEnding</xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="barline" mode="end">
  <xsl:text>&#xa;</xsl:text>
  <xsl:choose>
    <!--
      Close the Repeat block.

      TODO Don't close it if there's a RepeatEnding coming next.
    -->
    <xsl:when test="repeat/@direction = 'backward'">RepeatEnd</xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="measure">
  <xsl:apply-templates select="attributes/time"/>
  <xsl:apply-templates select="direction/sound[@tempo]" mode="tempo"/>
  <xsl:text>&#xa;</xsl:text>
  <xsl:apply-templates select="barline" mode="start"/>
  <xsl:if test="not($style)">
    <xsl:text>&#xa;</xsl:text>
    <xsl:apply-templates select="harmony[1]" mode="sequence">
      <xsl:with-param name="start" select="1"/>
    </xsl:apply-templates>
    <xsl:if test="count(harmony) = 0">
      <!-- In case of no chord in this measure, get the last chord of the closest preceding measure that had a chord. -->
      <xsl:apply-templates select="preceding-sibling::measure[harmony][1]/harmony[last()]" mode="sequence">
        <xsl:with-param name="start" select="1"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:if>
  <xsl:text>&#xa;</xsl:text>
  <xsl:value-of select="@number"/>
  <xsl:apply-templates select="harmony[1]" mode="chords">
    <xsl:with-param name="start" select="1"/>
  </xsl:apply-templates>
  <xsl:if test="count(harmony) = 0">
    <!-- In case of no chord in this measure, get the last chord of the closest preceding measure that had a chord. -->
    <xsl:apply-templates select="preceding-sibling::measure[harmony][1]/harmony[last()]" mode="chords">
      <xsl:with-param name="start" select="1"/>
    </xsl:apply-templates>
  </xsl:if>
  <xsl:apply-templates select="barline" mode="end"/>
</xsl:template>

<xsl:template match="harmony" mode="sequence">
  <xsl:param name="start"/>
  <xsl:variable name="id" select="generate-id(.)"/>
  <xsl:if test="$start = 1">
    <xsl:text>Chord Sequence { </xsl:text>
  </xsl:if>
  <xsl:value-of select="$start"/><xsl:text> </xsl:text>
  <xsl:variable name="duration"><xsl:value-of select="sum(following-sibling::note[not(chord) and generate-id(preceding-sibling::harmony[1]) = $id]/duration) div $divisions"/></xsl:variable>
  <!-- Express the duration in MIDI ticks = 192 * quarter note -->
  <xsl:value-of select="$duration * 192"/><xsl:text>t </xsl:text>
  <xsl:value-of select="$chordVolume"/><xsl:text>; </xsl:text>
  <xsl:apply-templates select="following-sibling::harmony[1]" mode="sequence">
    <xsl:with-param name="start" select="$start + $duration"/>
  </xsl:apply-templates>
  <xsl:if test="count(following-sibling::harmony[1]) = 0">
    <xsl:text>}</xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="harmony" mode="chords">
  <xsl:param name="start"/>
  <xsl:variable name="id" select="generate-id(.)"/>
  <xsl:text> </xsl:text>
  <xsl:choose>
    <!-- N.C. is expressed as "z" in MMA. -->
    <xsl:when test="kind = 'none'">z</xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="root/root-step"/>
      <xsl:variable name="rootAlter"><xsl:value-of select="root/root-alter"/></xsl:variable>
      <xsl:value-of select="if ($rootAlter = '1') then '#' else if ($rootAlter = '-1') then 'b' else ''"/>
      <!-- https://www.w3.org/2021/06/musicxml40/musicxml-reference/data-types/kind-value/ -->
      <xsl:choose>
        <xsl:when test="kind = 'augmented'">aug</xsl:when>
        <xsl:when test="kind = 'augmented-seventh'">aug7</xsl:when>
        <xsl:when test="kind = 'diminished'">dim</xsl:when>
        <xsl:when test="kind = 'diminished-seventh'">dim7</xsl:when>
        <xsl:when test="kind = 'dominant'">7</xsl:when>
        <xsl:when test="kind = 'dominant-11th'">11</xsl:when>
        <xsl:when test="kind = 'dominant-13th'">13</xsl:when>
        <xsl:when test="kind = 'dominant-ninth'">9</xsl:when>
        <xsl:when test="kind = 'French'"><!-- TODO --></xsl:when>
        <xsl:when test="kind = 'German'"><!-- TODO --></xsl:when>
        <xsl:when test="kind = 'half-diminished'">7b5</xsl:when>
        <xsl:when test="kind = 'Italian'"><!-- TODO --></xsl:when>
        <xsl:when test="kind = 'major'"></xsl:when>
        <xsl:when test="kind = 'major-11th'">maj11</xsl:when>
        <xsl:when test="kind = 'major-13th'">maj13</xsl:when>
        <xsl:when test="kind = 'major-minor'">m(maj7)</xsl:when>
        <xsl:when test="kind = 'major-ninth'">maj9</xsl:when>
        <xsl:when test="kind = 'major-seventh'">maj7</xsl:when>
        <xsl:when test="kind = 'major-sixth'">6</xsl:when>
        <xsl:when test="kind = 'minor'">m</xsl:when>
        <xsl:when test="kind = 'minor-11th'">m11</xsl:when>
        <xsl:when test="kind = 'minor-13th'">m13</xsl:when>
        <xsl:when test="kind = 'minor-ninth'">m9</xsl:when>
        <xsl:when test="kind = 'minor-seventh'">m7</xsl:when>
        <xsl:when test="kind = 'minor-sixth'">m6</xsl:when>
        <xsl:when test="kind = 'Neapolitan'"><!-- TODO --></xsl:when>
        <xsl:when test="kind = 'other'"><!-- TODO --></xsl:when>
        <xsl:when test="kind = 'pedal'"><!-- TODO --></xsl:when>
        <xsl:when test="kind = 'power'">5</xsl:when>
        <xsl:when test="kind = 'suspended-fourth'">sus4</xsl:when>
        <xsl:when test="kind = 'suspended-second'">sus2</xsl:when>
        <xsl:when test="kind = 'Tristan'"><!-- TODO --></xsl:when>
      </xsl:choose>
      <!-- TODO Handle modified degrees -->
      <!-- TODO Handle bass note -->
    </xsl:otherwise>
  </xsl:choose>
  <xsl:text>@</xsl:text><xsl:value-of select="$start"/>
  <!-- TODO Handle melody notes -->
  <xsl:variable name="duration"><xsl:value-of select="sum(following-sibling::note[not(chord) and generate-id(preceding-sibling::harmony[1]) = $id]/duration) div $divisions"/></xsl:variable>
  <xsl:apply-templates select="following-sibling::harmony[1]" mode="chords">
    <!--
      Get the next chord in this measure.

      The following sum() function accumulates the durations of all notes following the current harmony element
      until the next harmony element. It skips chord notes which don't contribute additional duration.
      The sum is divided by $divisions which is the global time resolution of the whole score.

      TODO Handle multiple tied notes for duration.
    -->
    <xsl:with-param name="start" select="$start + $duration"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="sound" mode="tempo">
Tempo <xsl:value-of select="@tempo"/>
</xsl:template>

<xsl:template match="time">
<!-- Time signature in MMA is expressed as "number of quarter notes in a measure". -->
Time <xsl:value-of select="beats * 4 div beat-type"/>
TimeSig <xsl:value-of select="beats"/>/<xsl:value-of select="beat-type"/>
</xsl:template>

</xsl:stylesheet>
