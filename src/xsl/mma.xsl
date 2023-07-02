<?xml version="1.0" encoding="UTF-8"?>

<!--
  Convert a MusicXML score to Musical MIDI Accompaniment (MMA) script.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mma="http://www.mellowood.ca/mma"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
>

  <xsl:include href="musicxml.xsl"/>

  <xsl:output method="text" media-type="text/plain" omit-xml-declaration="yes"/>

  <!--
    User-defined arguments.
  -->
  <xsl:param name="useSef" as="xs:boolean" select="false()"/>
  <xsl:param name="chordVolume" select="50"/>
  <xsl:param name="melodyInstrument" select="'TenorSax'"/>
  <xsl:param name="chordInstrument" select="'Piano1'"/>
  <xsl:param name="melodyVoice" select="1"/>
  <xsl:param name="globalGroove" select="''"/>
  <xsl:param name="renumberMeasures" as="xs:boolean" select="false()"/>

  <!--
    Global state.
  -->
  <xsl:accumulator name="groove" as="xs:string" initial-value="if ($globalGroove != '' and lower-case($globalGroove) != 'none') then $globalGroove else ''">
    <xsl:accumulator-rule match="sound/play/other-play[@type = 'groove']" select="text()"/>
  </xsl:accumulator>

  <!--
    Functions.
  -->
  <!--
    Convert MusicXML note to MMA pitch.
  -->
  <xsl:function name="mma:note" as="xs:integer">
    <xsl:param name="step"/>
    <xsl:param name="alter"/>
    <xsl:choose>
      <xsl:when test="($step = 'G' and $alter = '1') or ($step = 'A' and $alter = '-1')"><xsl:sequence select="-4"/></xsl:when>
      <xsl:when test="($step = 'A' and $alter = '1') or ($step = 'B' and $alter = '-1')"><xsl:sequence select="-2"/></xsl:when>
      <xsl:when test="($step = 'C' and $alter = '1') or ($step = 'D' and $alter = '-1')"><xsl:sequence select="1"/></xsl:when>
      <xsl:when test="($step = 'D' and $alter = '1') or ($step = 'E' and $alter = '-1')"><xsl:sequence select="3"/></xsl:when>
      <xsl:when test="($step = 'G' and $alter = '-1')"><xsl:sequence select="-6"/></xsl:when>
      <xsl:when test="($step = 'C' and $alter = '-1')"><xsl:sequence select="-1"/></xsl:when>
      <xsl:when test="($step = 'B' and $alter = '1')"><xsl:sequence select="0"/></xsl:when>
      <xsl:when test="($step = 'F' and $alter = '-1')"><xsl:sequence select="4"/></xsl:when>
      <xsl:when test="($step = 'E' and $alter = '1')"><xsl:sequence select="5"/></xsl:when>
      <xsl:when test="($step = 'F' and $alter = '1')"><xsl:sequence select="6"/></xsl:when>
      <xsl:when test="$step = 'G'"><xsl:sequence select="-5"/></xsl:when>
      <xsl:when test="$step = 'A'"><xsl:sequence select="-3"/></xsl:when>
      <xsl:when test="$step = 'D'"><xsl:sequence select="2"/></xsl:when>
      <xsl:when test="$step = 'B'"><xsl:sequence select="-1"/></xsl:when>
      <xsl:when test="$step = 'C'"><xsl:sequence select="0"/></xsl:when>
      <xsl:when test="$step = 'E'"><xsl:sequence select="4"/></xsl:when>
      <xsl:when test="$step = 'F'"><xsl:sequence select="5"/></xsl:when>
    </xsl:choose>
  </xsl:function>

  <!--
    Map incoming groove name to MMA groove.
  -->
  <xsl:function name="mma:groove">
    <xsl:param name="groove"/>
    <xsl:param name="time"/>
    <!--
      TODO Perform complete mapping between iReal Pro grooves and MMA grooves.
      Use `npm run print:grooves` to list all available MMA grooves.
    -->
    <xsl:choose>
      <xsl:when test="contains(lower-case($groove), 'swing') or contains(lower-case($groove), 'jazz')">
        <xsl:choose>
          <xsl:when test="$time/beats = 5 and $time/beat-type = 4"><xsl:sequence select="'Jazz54'"/></xsl:when>
          <xsl:otherwise><xsl:sequence select="'Swing'"/></xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:function>

  <!--
    Python mod function for compatibility with Slash MMA plugin.
    https://stackoverflow.com/a/60182730/209184
  -->
  <xsl:function name="mma:mod" as="xs:decimal">
    <xsl:param name="dividend"/>
    <xsl:param name="divisor"/>
    <xsl:sequence select="$dividend - floor($dividend div $divisor) * $divisor"/>
  </xsl:function>

  <!--
    First unroll the score.
  -->
  <xsl:variable name="stylesheetParams" select="map {
    QName('', 'renumberMeasures'): $renumberMeasures
  }"/>
  <xsl:variable name="unrolled">
    <xsl:if test="not($useSef)">
      <xsl:sequence select="transform(map {
        'source-node': /,
        'stylesheet-node': doc('unroll.xsl'),
        'stylesheet-params': $stylesheetParams
      })?output"/>
    </xsl:if>
    <xsl:if test="$useSef">
      <xsl:sequence select="transform(map {
        'source-node': /,
        'package-text': unparsed-text('unroll.sef.json'),
        'stylesheet-params': $stylesheetParams
      })?output"/>
    </xsl:if>
  </xsl:variable>

  <!--
    Apply the MMA transformation to the unrolled score.
  -->
  <xsl:template match="/">
    <xsl:apply-templates select="$unrolled/score-partwise"/>
  </xsl:template>

  <xsl:template match="score-partwise">
    <xsl:text>
MidiText Generated by musicxml-mma converter https://github.com/infojunkie/musicxml-mma

Begin Chord-Custom
  Voice </xsl:text><xsl:value-of select="$chordInstrument"/><xsl:text>
  Octave 5
  Articulate 80
  Volume f
End

Solo Voice </xsl:text><xsl:value-of select="$melodyInstrument"/><xsl:text>

DefChord mb6 (0, 3, 7, 8) (0, 2, 3, 5, 7, 8, 10)
DefChord 7(add6) (0, 4, 7, 9, 10) (0, 2, 4, 5, 7, 9, 10)
DefChord +(addM7)(add9) (0, 4, 8, 11, 14) (0, 2, 4, 5, 8, 9, 11)
DefChord +7(add9) (0, 4, 8, 10, 14) (0, 2, 4, 5, 8, 9, 10)
DefChord 7+#9 (0, 4, 8, 10, 15) (0, 3, 4, 5, 8, 9, 10)
DefChord 7+b9 (0, 4, 8, 10, 13) (0, 1, 4, 5, 8, 9, 10)
DefChord 7b9#9 (0, 4, 7, 10, 13, 15) (0, 1, 3, 4, 5, 7, 10)
DefChord 7b5b9#9#5 (0, 4, 6, 8, 10, 13, 15) (0, 1, 3, 5, 6, 8, 10)
DefChord 7susb13 (0, 5, 10, 20) (0, 2, 5, 5, 8, 9, 10)
DefChord 7(add3)(add4) (0, 4, 5, 7, 10) (0, 2, 4, 5, 7, 9, 10)
DefChord M7+ (0, 4, 8, 11) (0, 2, 4, 5, 8, 9, 11)
DefChord dimb13 (0, 3, 6, 9, 8) (0, 2, 3, 5, 6, 8, 9)
DefChord 13(omit3) (0, 7, 10, 21) (0, 2, 5, 5, 7, 9, 10)
DefChord m(add2) (0, 2, 3, 7) (0, 2, 3, 5, 7, 8, 8)
DefChord m7+#9 (0, 3, 8, 10, 15) (0, 3, 3, 5, 8, 8, 10)
DefChord m7+b9 (0, 3, 8, 10, 13) (0, 1, 3, 5, 8, 8, 10)
DefChord m7+b9#11 (0, 3, 8, 10, 13, 18) (0, 1, 3, 6, 8, 9, 10)
DefChord m7b5(add9)(add11) (0, 3, 6, 10, 14, 17) (0, 2, 3, 5, 6, 9, 10)
DefChord m7+ (0, 3, 7, 11) (0, 2, 3, 5, 7, 8, 11)
DefChord mM7b5 (0, 3, 6, 11) (0, 2, 3, 5, 6, 8, 11)
DefChord (omit3)(add9) (0, 0, 7, 14) (0, 2, 4, 5, 7, 9, 10)
DefChord sus#9 (0, 5, 7, 15) (0, 2, 5, 5, 7, 9, 11)
DefChord susb9 (0, 5, 7, 13) (0, 2, 5, 5, 7, 9, 11)

Plugin Slash</xsl:text>
    <xsl:apply-templates select="//harmony[bass]" mode="declaration">
      <xsl:with-param name="definition" select="true()"/>
    </xsl:apply-templates>
    <xsl:text>&#xa;</xsl:text>

    <xsl:apply-templates select="part/measure"/>
  </xsl:template>

  <!--
    Output a measure.
  -->
  <xsl:template match="measure">
    <!--
      Time signature.
    -->
    <xsl:apply-templates select="attributes/time"/>

    <!--
      Tempo.
    -->
    <xsl:apply-templates select="direction/sound[@tempo]" mode="tempo"/>

    <!--
      Groove.
    -->
    <xsl:variable name="groove">
      <xsl:choose>
        <xsl:when test="@number = '0'"/>
        <xsl:when test="@number = '1' and $globalGroove != '' and lower-case($globalGroove) != 'none'">
          <xsl:value-of select="$globalGroove"/>
        </xsl:when>
        <xsl:when test="accumulator-before('groove') = accumulator-after('groove')"/>
        <xsl:otherwise>
          <xsl:value-of select="mma:groove(
            */sound/play/other-play[@type = 'groove']/text(),
            accumulator-after('time')
          )"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$groove != ''">
Groove <xsl:value-of select="$groove"/>
MidiMark Groove:<xsl:value-of select="$groove"/>
      </xsl:when>
      <xsl:when test="accumulator-after('groove') != '' and mma:groove(accumulator-after('groove'), accumulator-after('time')) != ''"/>
      <xsl:otherwise>
        <xsl:apply-templates select="harmony[1]" mode="sequence">
          <xsl:with-param name="start" select="1"/>
        </xsl:apply-templates>
        <xsl:if test="not(harmony)">
          <!--
            In case of no chord in this measure, get the last chord.
          -->
          <xsl:apply-templates select="accumulator-after('harmony')" mode="sequence">
            <xsl:with-param name="start" select="1"/>
          </xsl:apply-templates>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>

    <!--
      Measure number.
    -->
    <xsl:text>&#xa;</xsl:text>
    <xsl:text>MidiMark Measure:</xsl:text><xsl:value-of select="accumulator-after('measureIndex')(@number)"/>
    <xsl:text>&#xa;</xsl:text>

    <!--
      Chords.
    -->
    <xsl:apply-templates select="harmony[1]" mode="duration">
      <xsl:with-param name="start" select="1"/>
    </xsl:apply-templates>
    <xsl:if test="not(harmony)">
      <!--
        In case of no chord in this measure, get the last chord.
      -->
      <xsl:if test="not(accumulator-after('harmony'))"> z</xsl:if>
      <xsl:apply-templates select="accumulator-after('harmony')" mode="duration">
        <xsl:with-param name="start" select="1"/>
      </xsl:apply-templates>
    </xsl:if>

    <!--
      Notes.
    -->
    <xsl:apply-templates select="note[voice = $melodyVoice][1]">
      <xsl:with-param name="shouldIgnoreTieStop" select="if (not(preceding-sibling::measure[1])) then false() else not(preceding-sibling::measure[1]/note[voice = $melodyVoice][not(chord)][last()]/tie[@type = 'start'])"/>
      <xsl:with-param name="isAnyNotePrinted" select="false()"/>
    </xsl:apply-templates>

    <xsl:variable name="durationDifference" select="round((sum(note[voice = $melodyVoice][not(chord)]/duration) div accumulator-after('divisions')) - (accumulator-after('time')/beats * 4 div accumulator-after('time')/beat-type))"/>
    <xsl:if test="$durationDifference != 0">
BeatAdjust <xsl:value-of select="$durationDifference"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="harmony" mode="sequence">
    <xsl:param name="start"/>
    <xsl:variable name="id" select="generate-id(.)"/>
    <xsl:if test="$start = 1">
Chord-Custom Sequence { </xsl:if>
    <xsl:value-of select="$start"/><xsl:text> </xsl:text>
    <!--
      Calculate this chord's duration, which is the total duration of following non-chord notes until next harmony element,
      The total is divided by the current time resolution of the score.
      The final duration is expressed in "beats" == quarter note time.
    -->
    <xsl:variable name="duration">
      <xsl:value-of select="(
        sum(following-sibling::note[voice = $melodyVoice][not(chord) and generate-id(preceding-sibling::harmony[1]) = $id]/duration)
      ) div accumulator-after('divisions')"/>
    </xsl:variable>
    <!--
      Express the duration in MIDI ticks = 192 * quarter note
    -->
    <xsl:value-of select="round($duration * 192)"/><xsl:text>t </xsl:text>
    <xsl:value-of select="$chordVolume"/><xsl:text>; </xsl:text>
    <xsl:apply-templates select="following-sibling::harmony[1]" mode="sequence">
      <xsl:with-param name="start" select="$start + $duration"/>
    </xsl:apply-templates>
    <xsl:if test="not(following-sibling::harmony)">}</xsl:if>
  </xsl:template>

  <xsl:template match="harmony" mode="name">
    <xsl:param name="definition"/>
    <xsl:choose>
      <xsl:when test="kind = 'none'">z</xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="root/root-step"/>
        <xsl:value-of select="if (root/root-alter = '1') then '#' else if (root/root-alter = '-1') then 'b' else ''"/>
        <!-- https://www.w3.org/2021/06/musicxml40/musicxml-reference/data-types/kind-value/ -->
        <xsl:choose>
          <xsl:when test="kind = 'augmented'">+</xsl:when>
          <xsl:when test="kind = 'augmented-seventh'">+7</xsl:when>
          <xsl:when test="kind = 'diminished'">dim</xsl:when>
          <xsl:when test="kind = 'diminished-seventh'">dim7</xsl:when>
          <xsl:when test="kind = 'dominant'">7</xsl:when>
          <xsl:when test="kind = 'dominant-11th'">11</xsl:when>
          <xsl:when test="kind = 'dominant-13th'">13</xsl:when>
          <xsl:when test="kind = 'dominant-ninth'">9</xsl:when>
          <xsl:when test="kind = 'French'"><!-- TODO --></xsl:when>
          <xsl:when test="kind = 'German'"><!-- TODO --></xsl:when>
          <xsl:when test="kind = 'half-diminished'">m7b5</xsl:when>
          <xsl:when test="kind = 'Italian'"><!-- TODO --></xsl:when>
          <xsl:when test="kind = 'major'"></xsl:when>
          <xsl:when test="kind = 'major-11th'">M11</xsl:when>
          <xsl:when test="kind = 'major-13th'">M13</xsl:when>
          <xsl:when test="kind = 'major-minor'">mM7</xsl:when>
          <xsl:when test="kind = 'major-ninth'">M9</xsl:when>
          <xsl:when test="kind = 'major-seventh'">M7</xsl:when>
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
          <xsl:when test="kind = 'suspended-fourth'">sus</xsl:when>
          <xsl:when test="kind = 'suspended-second'">sus2</xsl:when>
          <xsl:when test="kind = 'Tristan'"><!-- TODO --></xsl:when>
        </xsl:choose>
        <!--
          Handle modified degrees.

          We try our best to have a rational naming algorithm, and we resort to DefChord when MMA does not recognize our chords:
          - Detect add 4, omit 3 => sus
          - Detect add 2, omit 3 => sus2
          - Detect alter #5 => +
          - Altered degrees: expecting either sharp or flat alterations
          - Added degrees except for sus/sus2: emit (addX) if no alteration. Special case for 7 => M7 when adding this degree.
          - Omitted degrees except for sus/sus2: alterations are not expected

          This algorithm misses some cases. We could try to detect them but it's easier to use MMA's DefChord
          to define our output as synonyms to existing chords. Use `npm run print:chord "sus(addb9)"` to print the syntax for an existing
          code definition that needs to be cloned.
        -->
        <xsl:variable name="sus">
          <xsl:choose>
            <xsl:when test="degree[degree-type = 'add' and degree-value = '4'] and degree[degree-type = 'subtract' and degree-value = '3']">sus</xsl:when>
            <xsl:when test="degree[degree-type = 'add' and degree-value = '2'] and degree[degree-type = 'subtract' and degree-value = '3']">sus2</xsl:when>
            <xsl:when test="degree[degree-type = 'alter' and degree-value = '5' and degree-alter = '1']">+</xsl:when>
            <xsl:otherwise></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="$sus"/>
        <xsl:for-each select="degree[degree-type = 'subtract' and not(degree-value = '3' and $sus != '')]">
          <xsl:text>(omit</xsl:text>
          <xsl:value-of select="degree-value"/>
          <xsl:text>)</xsl:text>
        </xsl:for-each>
        <xsl:for-each select="degree[degree-type = 'alter' and not(degree-value = '5' and $sus != '')]">
          <xsl:value-of select="if (degree-alter = '1') then '#' else if (degree-alter = '-1') then 'b' else ''"/>
          <xsl:value-of select="degree-value"/>
        </xsl:for-each>
        <xsl:for-each select="degree[degree-type = 'add' and not((degree-value = '4' or degree-value = '2') and $sus != '')]">
          <xsl:value-of select="if (degree-alter = '1') then '#' else if (degree-alter = '-1') then 'b' else '(add'"/>
          <xsl:value-of select="if (degree-value = '7' and degree-alter = '0') then 'M7' else degree-value"/>
          <xsl:value-of select="if (degree-alter = '1') then '' else if (degree-alter = '-1') then '' else ')'"/>
        </xsl:for-each>
        <!--
          Handle bass note.
        -->
        <xsl:if test="bass">
          <xsl:choose>
            <xsl:when test="$definition">
              <xsl:text>/</xsl:text>
              <xsl:value-of select="bass/bass-step"/>
              <xsl:value-of select="if (bass/bass-alter = '1') then '#' else if (bass/bass-alter = '-1') then 'b' else ''"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text disable-output-escaping="yes">&lt;</xsl:text>
              <xsl:value-of select="mma:mod(mma:note(bass/bass-step, bass/bass-alter) - mma:note(root/root-step, root/root-alter), -12)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="harmony" mode="duration">
    <xsl:param name="start"/>

    <xsl:variable name="id" select="generate-id(.)"/>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="." mode="name"/>
    <xsl:text>@</xsl:text><xsl:value-of select="$start"/>
    <xsl:variable name="duration"><xsl:value-of select="sum(following-sibling::note[not(chord) and generate-id(preceding-sibling::harmony[1]) = $id]/duration) div accumulator-after('divisions')"/></xsl:variable>
    <xsl:apply-templates select="following-sibling::harmony[1]" mode="duration">
      <xsl:with-param name="start" select="$start + $duration"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="note" mode="duration">
    <xsl:param name="duration"/>
    <xsl:variable name="tie" select="if (cue) then notations/tied else tie"/>
    <xsl:choose>
      <xsl:when test="$tie[@type = 'stop'] and not($tie[@type = 'start'])"><xsl:value-of select="$duration + duration"/></xsl:when>
      <xsl:otherwise>
        <xsl:variable name="recursiveDuration">
          <xsl:apply-templates select="if (following-sibling::note[voice = $melodyVoice][not(chord)]) then following-sibling::note[voice = $melodyVoice][not(chord)][1] else ../following-sibling::measure[1]/note[voice = $melodyVoice][not(chord)][1]" mode="duration">
            <xsl:with-param name="duration" select="duration + $duration"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:value-of select="$recursiveDuration"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="note">
    <xsl:param name="shouldIgnoreTieStop" as="xs:boolean"/>
    <xsl:param name="isAnyNotePrinted" as="xs:boolean"/>
    <!--
      A note sequence (SOLO track in MMA glossary) is made of several pieces:
      - Opening bracket "{" to start measure
      - For grace notes, the keyword <grace>
      - For non-chord notes and non-stopping ties, a duration expressed in MIDI ticks. The duration is computed recursively in the case of ties.
      - For pitched notes, the lower-case note + accidental + octave (4 is the base octave)
      - For rests and cue notes, "r"
      - A tilde "~" in case a tie carries over from previous and/or to next measure
      - A comma "," for next chord note
      - A semicolon for next non-chord note
      - Closing bracket "}" to end measure

      TODO Handle the following:
      - Articulations
      - Sound directives
      - Chords with unequal ties
      - Unpitched notes
    -->
    <xsl:variable name="tie" select="if (cue) then notations/tied else tie"/>
    <xsl:variable name="tieStop" select="$tie[@type = 'stop'] and not($shouldIgnoreTieStop)"/>
    <xsl:variable name="tieStart" select="$tie[@type = 'start']"/>

    <xsl:if test="not(preceding-sibling::note[voice = $melodyVoice])">
      <xsl:text> {</xsl:text>
      <xsl:if test="$tieStop">~</xsl:if>
    </xsl:if>

    <xsl:if test="grace">
      <xsl:text disable-output-escaping="yes">&lt;grace&gt;</xsl:text>
    </xsl:if>

    <xsl:if test="not(chord or $tieStop)">
      <xsl:variable name="duration">
        <xsl:choose>
          <xsl:when test="$tieStart">
            <xsl:apply-templates select="." mode="duration">
              <xsl:with-param name="duration" select="0"/>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="duration"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:if test="$duration != ''">
        <xsl:if test="$isAnyNotePrinted">;</xsl:if>
        <xsl:value-of select="floor(192 * $duration div accumulator-after('divisions'))"/>
        <xsl:text>t</xsl:text>
      </xsl:if>
    </xsl:if>

    <xsl:if test="not($tieStop)">
      <xsl:choose>
        <xsl:when test="rest or cue or notehead = 'slash'">r</xsl:when>
        <xsl:when test="pitch">
          <xsl:if test="chord"><xsl:text>,</xsl:text></xsl:if>
          <xsl:value-of select="lower-case(pitch/step)"/>
          <xsl:value-of disable-output-escaping="yes" select="if (pitch/alter = '1') then '#' else if (pitch/alter = '-1') then '&amp;' else 'n'"/>
          <xsl:choose>
            <xsl:when test="pitch/octave &gt; 4">
              <xsl:for-each select="1 to xs:integer(pitch/octave - 4)">+</xsl:for-each>
            </xsl:when>
            <xsl:when test="pitch/octave &lt; 4">
              <xsl:for-each select="1 to xs:integer(4 - pitch/octave)">-</xsl:for-each>
            </xsl:when>
          </xsl:choose>
        </xsl:when>
      </xsl:choose>
    </xsl:if>

    <xsl:if test="not(following-sibling::note[voice = $melodyVoice])">
      <xsl:if test="not($isAnyNotePrinted or not(chord or $tieStop))">
        <xsl:text disable-output-escaping="yes">&lt;&gt;</xsl:text>
      </xsl:if>
      <xsl:if test="$tieStart">~</xsl:if>
      <xsl:text>;}</xsl:text>
    </xsl:if>

    <xsl:apply-templates select="following-sibling::note[voice = $melodyVoice][1]">
      <xsl:with-param name="shouldIgnoreTieStop" select="false()"/>
      <xsl:with-param name="isAnyNotePrinted" select="$isAnyNotePrinted or not(chord or $tieStop)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="sound" mode="tempo">
Tempo <xsl:value-of select="@tempo"/>
  </xsl:template>

  <!--
    Time signature in MMA is expressed as "number of quarter notes in a measure".
  -->
  <xsl:template match="time">
Time <xsl:value-of select="beats * 4 div beat-type"/>
TimeSig <xsl:value-of select="beats"/>/<xsl:value-of select="beat-type"/>
  </xsl:template>

  <xsl:template match="harmony" mode="declaration">
    <xsl:if test="not(preceding::harmony[deep-equal(.,current())])">
@Slash <xsl:apply-templates select="." mode="name">
      <xsl:with-param name="definition" select="true()"/>
    </xsl:apply-templates></xsl:if>
  </xsl:template>

</xsl:stylesheet>
