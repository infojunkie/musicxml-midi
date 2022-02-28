<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mma="http://www.mellowood.ca/mma"
  exclude-result-prefixes="xs mma"
  version="2.0"
>
<xsl:output media-type="text/plain" omit-xml-declaration="yes"/>

<!-- Inspired by https://github.com/k8bushlover/XSLT-MusicXmlToSessionBand - I love k8bush too! -->

<xsl:param name="chordVolume" select="50"/>

<xsl:variable name="divisions" select="score-partwise/part/measure/attributes/divisions"/>
<xsl:variable name="beats" select="score-partwise/part/measure/attributes/time/beats"/>
<xsl:variable name="beatType" select="score-partwise/part/measure/attributes/time/beat-type"/>
<xsl:variable name="groove" select="score-partwise/identification/creator[@type='lyricist']"/>

<xsl:template match="score-partwise">
// <xsl:value-of select="translate(work/work-title, '&#xa;', ' ')"/>
  <xsl:apply-templates select="identification/creator[@type='lyricist']" mode="groove"/>
  <xsl:if test="not($groove)">
Begin Chord
  Voice Piano1
  Octave 5
  Articulate 80
  Volume m
End</xsl:if>
  <xsl:apply-templates select="part/measure[1]">
    <xsl:with-param name="lastHarmony"/>
    <xsl:with-param name="repeatMeasure"/>
    <xsl:with-param name="repeatCount" select="1"/>
    <xsl:with-param name="jump"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="creator" mode="groove">
<!--
  Extract playback style from //identification/creator[@type='lyricist'] as exported by iReal Pro (and emulated by infojunkie/ireal-musicxml).
  See discussion at https://github.com/w3c/musicxml/issues/347

  TODO Map iReal Pro grooves to MMA grooves
-->
  <xsl:variable name="playback" select="if (contains(., '(')) then translate(replace(., '.*?\((.*?)\)', '$1'), ' ', '') else translate(., ' ', '')"/>
Groove <xsl:choose>
    <xsl:when test="contains(lower-case($playback), 'swing')">
      <xsl:choose>
        <xsl:when test="$beats = 5 and $beatType = 4">Jazz54</xsl:when>
        <xsl:otherwise>Swing</xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$playback"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--
  Unroll the repeats and jumps into a linear sequence of measures. To do this, we advance measure by measure, carrying a state made of:
  - Last chord we saw (to set in current measure in case it's empty)
  - Current loop starting measure, typically indicated by a forward-facing repeat barline
  - Current loop counter
  - Current jump status
  Based on the current measure's repeats and jumps, and the current state, we choose which measure to output next.
-->
<xsl:template match="measure">
  <xsl:param name="lastHarmony"/>
  <xsl:param name="repeatMeasure"/>
  <xsl:param name="repeatCount" as="xs:integer"/>
  <xsl:param name="jump"/>
  <xsl:variable name="nextHarmony" select="if (count(harmony) = 0) then generate-id(//harmony[generate-id(.) = $lastHarmony]) else generate-id(harmony[last()])"/>
  <xsl:variable name="repeatMeasureReal" select="if ($repeatMeasure) then $repeatMeasure else generate-id(//measure[1])"/>

  <!-- Alternate ending start: Skip to the matching following alternate ending if the loop counter isn't mentioned in the current ending. -->
  <xsl:choose><xsl:when test="barline[ending/@type = 'start'] and not(index-of(tokenize(barline/ending[@type = 'start']/@number, '\s*,\s*'), format-number($repeatCount, '0')))">
    <xsl:apply-templates select="following-sibling::measure[barline/ending/@type = 'start' and index-of(tokenize(barline/ending[@type = 'start']/@number, '\s*,\s*'), format-number($repeatCount, '0'))][1]">
      <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
      <xsl:with-param name="repeatMeasure" select="$repeatMeasure"/>
      <xsl:with-param name="repeatCount" select="$repeatCount"/>
      <xsl:with-param name="jump" select="$jump"/>
    </xsl:apply-templates>
  </xsl:when>
  <xsl:otherwise>

  <!-- Set the time signature and tempo if this is the first iteration in a loop. -->
  <xsl:if test="$repeatCount = 1 and $jump = ''">
    <xsl:apply-templates select="attributes/time"/>
    <xsl:apply-templates select="direction/sound[@tempo]" mode="tempo"/>
  </xsl:if>
  <!-- If we don't have a groove, add our hand-made chord sequence that replicates the rhythm notation of the chords. -->
  <xsl:if test="not($groove)">
    <xsl:apply-templates select="harmony[1]" mode="sequence">
      <xsl:with-param name="start" select="1"/>
    </xsl:apply-templates>
    <xsl:if test="count(harmony) = 0">
      <!-- In case of no chord in this measure, get the last chord of the closest preceding measure that had a chord. -->
      <xsl:apply-templates select="//harmony[generate-id(.) = $lastHarmony]" mode="sequence">
        <xsl:with-param name="start" select="1"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:if>
  <xsl:text>&#xa;</xsl:text>
  <xsl:value-of select="@number"/>
  <!-- Add the chord information. -->
  <xsl:apply-templates select="harmony[1]" mode="chords">
    <xsl:with-param name="start" select="1"/>
  </xsl:apply-templates>
  <xsl:if test="count(harmony) = 0">
    <!-- In case of no chord in this measure, get the last chord of the closest preceding measure that had a chord. -->
    <xsl:apply-templates select="//harmony[generate-id(.) = $lastHarmony]" mode="chords">
      <xsl:with-param name="start" select="1"/>
    </xsl:apply-templates>
  </xsl:if>
  <!-- Advance to next measure with our unrolling algorithm. -->
  <xsl:choose>
    <!-- Fine: Stop everything -->
    <xsl:when test="./*/sound/@fine = 'yes' and not($jump = '')">
    </xsl:when>
    <!-- Opening repeat: Save this measure as the loop start. Reset loop counter to 1 unless we're already looping. -->
    <xsl:when test="barline/repeat/@direction = 'forward' or generate-id(.) = $repeatMeasure">
      <xsl:apply-templates select="following-sibling::measure[1]">
        <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
        <xsl:with-param name="repeatMeasure" select="generate-id(.)"/>
        <xsl:with-param name="repeatCount" select="if (generate-id(.) = $repeatMeasure) then $repeatCount else 1"/>
        <xsl:with-param name="jump" select="$jump"/>
      </xsl:apply-templates>
    </xsl:when>
    <!-- Closing repeat without alternate ending: Loop back if the loop counter hasn't reached the requested times. -->
    <xsl:when test="barline[not(ending)]/repeat/@direction = 'backward' and (if (barline/repeat/@times) then number(barline/repeat/@times) else 2) &gt; $repeatCount">
      <xsl:apply-templates select="//measure[generate-id(.) = $repeatMeasureReal]">
        <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
        <xsl:with-param name="repeatMeasure" select="$repeatMeasureReal"/>
        <xsl:with-param name="repeatCount" select="$repeatCount + 1"/>
        <xsl:with-param name="jump" select="$jump"/>
      </xsl:apply-templates>
    </xsl:when>
    <!-- Alternate ending end: Jump back to loop start if next loop counter is mentioned in any alternate ending for the current repeat block. -->
    <xsl:when test="barline[ending/@type = 'stop']/repeat/@direction = 'backward' and //measure[generate-id(.) = $repeatMeasureReal]/following-sibling::measure[
      preceding-sibling::measure[barline/repeat/@direction = 'forward'][1][generate-id(.) = $repeatMeasureReal] and
      barline/ending/@type = 'start'
      and index-of(tokenize(barline/ending[@type = 'start']/@number, '\s*,\s*'), format-number($repeatCount + 1, '0'))
    ]/@number">
      <xsl:apply-templates select="//measure[generate-id(.) = $repeatMeasureReal]">
        <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
        <xsl:with-param name="repeatMeasure" select="$repeatMeasureReal"/>
        <xsl:with-param name="repeatCount" select="$repeatCount + 1"/>
        <xsl:with-param name="jump" select="$jump"/>
      </xsl:apply-templates>
    </xsl:when>
    <!-- Da capo: Go back to start -->
    <xsl:when test="./*/sound/@dacapo = 'yes' and $jump = ''">
      <xsl:apply-templates select="//measure[1]">
        <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
        <xsl:with-param name="repeatMeasure"/>
        <xsl:with-param name="repeatCount" select="1"/>
        <xsl:with-param name="jump" select="capo"/>
      </xsl:apply-templates>
    </xsl:when>
    <!-- Closing repeat without alternate ending: Go straight and reset state if the loop counter has reached the requested times. -->
    <xsl:when test="barline[not(ending)]/repeat/@direction = 'backward' and number(barline/repeat/@times) &lt;= $repeatCount">
      <xsl:apply-templates select="following-sibling::measure[1]">
        <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
        <xsl:with-param name="repeatMeasure"/>
        <xsl:with-param name="repeatCount" select="1"/>
        <xsl:with-param name="jump" select="$jump"/>
      </xsl:apply-templates>
    </xsl:when>
    <!-- General case: Keep going straight, remembering current state. -->
    <xsl:otherwise>
      <xsl:apply-templates select="following-sibling::measure[1]">
        <xsl:with-param name="lastHarmony" select="$nextHarmony"/>
        <xsl:with-param name="repeatMeasure" select="$repeatMeasure"/>
        <xsl:with-param name="repeatCount" select="$repeatCount"/>
        <xsl:with-param name="jump" select="$jump"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>

</xsl:otherwise></xsl:choose>
</xsl:template>

<xsl:template match="harmony" mode="sequence">
  <xsl:param name="start"/>
  <xsl:variable name="id" select="generate-id(.)"/>
  <xsl:if test="$start = 1">
Chord Sequence { </xsl:if>
  <xsl:value-of select="$start"/><xsl:text> </xsl:text>
  <xsl:variable name="duration"><xsl:value-of select="sum(following-sibling::note[not(chord) and generate-id(preceding-sibling::harmony[1]) = $id]/duration) div $divisions"/></xsl:variable>
  <!-- Express the duration in MIDI ticks = 192 * quarter note -->
  <xsl:value-of select="$duration * 192"/><xsl:text>t </xsl:text>
  <xsl:value-of select="$chordVolume"/><xsl:text>; </xsl:text>
  <xsl:apply-templates select="following-sibling::harmony[1]" mode="sequence">
    <xsl:with-param name="start" select="$start + $duration"/>
  </xsl:apply-templates>
  <xsl:if test="count(following-sibling::harmony[1]) = 0">}</xsl:if>
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
