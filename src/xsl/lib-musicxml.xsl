<?xml version="1.0" encoding="UTF-8"?>

<!--
  Reusable functions for MusicXML documents.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
>

  <!--
    Global: Parameters.
  -->
  <xsl:param name="defaultScalingMillimeters" select="7.0"/>
  <xsl:param name="defaultScalingTenths" select="40"/>

  <!--
    Template: Get accumulator value at node.
    Function: Get accumulator value at node.
  -->
  <xsl:template match="node()" mode="accumulatorBefore">
    <xsl:param name="accumulator"/>
    <xsl:value-of select="accumulator-before($accumulator)"/>
  </xsl:template>
  <xsl:template match="node()" mode="accumulatorAfter">
    <xsl:param name="accumulator"/>
    <xsl:value-of select="accumulator-after($accumulator)"/>
  </xsl:template>
  <xsl:function name="musicxml:accumulatorBefore">
    <xsl:param name="accumulator"/>
    <xsl:param name="node"/>
    <xsl:sequence>
      <xsl:apply-templates select="$node" mode="accumulatorBefore">
        <xsl:with-param name="accumulator" select="$accumulator"/>
      </xsl:apply-templates>
    </xsl:sequence>
  </xsl:function>
  <xsl:function name="musicxml:accumulatorAfter">
    <xsl:param name="accumulator"/>
    <xsl:param name="node"/>
    <xsl:sequence>
      <xsl:apply-templates select="$node" mode="accumulatorAfter">
        <xsl:with-param name="accumulator" select="$accumulator"/>
      </xsl:apply-templates>
    </xsl:sequence>
  </xsl:function>

  <!--
    State: Current divisions value.
  -->
  <xsl:accumulator name="divisions" as="xs:double" initial-value="1">
    <xsl:accumulator-rule match="attributes/divisions" select="text()"/>
  </xsl:accumulator>

  <!--
    State: Current tempo value.
  -->
  <xsl:accumulator name="tempo" as="xs:double" initial-value="120">
    <xsl:accumulator-rule match="sound[@tempo]" select="@tempo"/>
  </xsl:accumulator>

  <!--
    State: Current metronome nodeset.
  -->
  <xsl:accumulator name="metronome" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/direction[direction-type/metronome]" select="."/>
  </xsl:accumulator>

  <!--
    State: Current time signature nodeset.
  -->
  <xsl:accumulator name="time" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/time" select="."/>
  </xsl:accumulator>

  <!--
    State: Current clef nodeset.
  -->
  <xsl:accumulator name="clef" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/clef" select="."/>
  </xsl:accumulator>

  <!--
    State: Current key signature nodeset.
  -->
  <xsl:accumulator name="key" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/key" select="."/>
  </xsl:accumulator>

  <!--
    State: Current harmony nodeset.
  -->
  <xsl:accumulator name="harmony" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="harmony" select="."/>
  </xsl:accumulator>

  <!--
    State: Current segno.
  -->
  <xsl:accumulator name="segno" as="xs:string" initial-value="''">
    <xsl:accumulator-rule match="sound[@segno]" select="@segno"/>
  </xsl:accumulator>

  <!--
    State: Current coda.
  -->
  <xsl:accumulator name="coda" as="xs:string" initial-value="''">
    <xsl:accumulator-rule match="sound[@coda]" select="@coda"/>
  </xsl:accumulator>

  <!--
    State: Current measure repeat mode.
  -->
  <xsl:accumulator name="measureRepeat" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/measure-style/measure-repeat[@type = 'start']" select="."/>
    <xsl:accumulator-rule match="measure/attributes/measure-style/measure-repeat[@type = 'stop']" select="()"/>
  </xsl:accumulator>

  <!--
    State: Map of measure number to index.
  -->
  <xsl:accumulator name="measureIndex" as="map(xs:string, xs:integer)" initial-value="map {}">
    <xsl:accumulator-rule match="measure" select="if (map:contains($value, @number)) then map:put($value, @number, map:get($value, @number)) else map:put($value, @number, map:size($value))"/>
  </xsl:accumulator>

  <!--
    State: Current measure duration / internal offset.
  -->
  <xsl:accumulator name="measureDuration" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="forward" select="$value + duration"/>
    <xsl:accumulator-rule match="backup" select="$value - duration"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="rest[@measure='yes']">
          <xsl:sequence select="musicxml:measureDuration(ancestor::measure)"/>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Current measure onset.
  -->
  <xsl:accumulator name="measureOnset" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" phase="start" select="$value"/>
    <xsl:accumulator-rule match="measure" phase="end" select="$value + accumulator-after('measureDuration')"/>
  </xsl:accumulator>

  <!--
    State: Current note duration.
  -->
  <xsl:accumulator name="noteDuration" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="rest[@measure='yes']">
          <xsl:sequence select="musicxml:measureDuration(ancestor::measure)"/>
        </xsl:when>
        <xsl:when test="tie[@type='stop']"><xsl:sequence select="$value + duration"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Current note onset within measure.
  -->
  <xsl:accumulator name="noteOnset" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="forward" select="$value + duration"/>
    <xsl:accumulator-rule match="backup" select="$value - duration"/>
    <xsl:accumulator-rule match="note" phase="end">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="rest[@measure='yes']">
          <xsl:sequence select="musicxml:measureDuration(ancestor::measure)"/>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Previous harmony duration.

    Because <harmony> is declared before a note, its duration is not known until the next harmony element, or the measure end,
    or some other criterion.
  -->
  <xsl:accumulator name="harmonyDuration" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="harmony" select="0"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Defaults.
  -->
  <xsl:accumulator name="scalingMillimeters" as="xs:double" initial-value="$defaultScalingMillimeters">
    <xsl:accumulator-rule match="//defaults/scaling" select="number(millimeters)"/>
  </xsl:accumulator>
  <xsl:accumulator name="scalingTenths" as="xs:double" initial-value="$defaultScalingTenths">
    <xsl:accumulator-rule match="//defaults/scaling" select="number(tenths)"/>
  </xsl:accumulator>

  <!--
    Function: Measure duration (as per current time signature).
  -->
  <xsl:function name="musicxml:measureDuration" as="xs:double">
    <xsl:param name="measure"/>
    <xsl:sequence><xsl:apply-templates select="$measure" mode="measureDuration"/></xsl:sequence>
  </xsl:function>
  <xsl:template match="measure" mode="measureDuration">
    <xsl:value-of select="accumulator-after('divisions') * number(accumulator-after('time')/beats) * 4 div number(accumulator-after('time')/beat-type)"/>
  </xsl:template>

  <!--
    Function: Convert MusicXML time units to milliseconds.
  -->
  <xsl:function name="musicxml:timeToMillisecs" as="xs:double">
    <xsl:param name="time" as="xs:double"/>
    <xsl:param name="divisions" as="xs:double"/>
    <xsl:param name="tempo" as="xs:double"/>
    <xsl:sequence select="$time * 60000 div $divisions div $tempo"/>
  </xsl:function>

  <!--
    Function: Convert MusicXML time units to MIDI ticks.
  -->
  <xsl:function name="musicxml:timeToMIDITicks" as="xs:double">
    <xsl:param name="time" as="xs:double"/>
    <xsl:param name="divisions" as="xs:double"/>
    <xsl:sequence select="round($time * 192 div $divisions)"/>
  </xsl:function>

  <!--
    Function: Calculate harmony duration.
  -->
  <xsl:function name="musicxml:harmonyDuration" as="xs:double">
    <xsl:param name="harmony"/>
    <xsl:sequence select="
      sum($harmony/following-sibling::note[not(chord) and generate-id(preceding-sibling::harmony[1]) = generate-id($harmony)]/duration)
    "/>
  </xsl:function>

  <!--
    Function: Preceding and following non-note measure elements.
  -->
  <xsl:function name="musicxml:precedingMeasureElements" as="element()*">
    <xsl:param name="note"/>
    <xsl:sequence select="$note/preceding-sibling::*[not(local-name() = 'note') and following-sibling::note[1][generate-id(.) = generate-id($note)]]"/>
  </xsl:function>

  <xsl:function name="musicxml:followingMeasureElements" as="element()*">
    <xsl:param name="note"/>
    <xsl:sequence select="$note/following-sibling::*[not(local-name() = 'note') and preceding-sibling::note[1][generate-id(.) = generate-id($note)]]"/>
  </xsl:function>

  <!--
    Function: Derive alter value from note.
  -->
  <xsl:function name="musicxml:noteAlterValue" as="xs:double">
    <xsl:param name="note"/>
    <xsl:choose>
      <xsl:when test="$note/pitch/alter"><xsl:sequence select="number($note/pitch/alter)"/></xsl:when>
      <xsl:when test="$note/accidental">
        <xsl:choose>
          <xsl:when test="$note/accidental = 'sharp'"><xsl:sequence select="1"/></xsl:when>
          <xsl:when test="$note/accidental = 'natural'"><xsl:sequence select="0"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat'"><xsl:sequence select="-1"/></xsl:when>
          <xsl:when test="$note/accidental = 'double-sharp'"><xsl:sequence select="2"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-sharp'"><xsl:sequence select="2"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-flat'"><xsl:sequence select="-2"/></xsl:when>
          <xsl:when test="$note/accidental = 'natural-sharp'"><xsl:sequence select="1"/></xsl:when>
          <xsl:when test="$note/accidental = 'natural-flat'"><xsl:sequence select="-1"/></xsl:when>
          <xsl:when test="$note/accidental = 'quarter-flat'"><xsl:sequence select="-0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'quarter-sharp'"><xsl:sequence select="0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'three-quarters-flat'"><xsl:sequence select="-1.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'three-quarters-sharp'"><xsl:sequence select="1.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-down'"><xsl:sequence select="0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-up'"><xsl:sequence select="1.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'natural-down'"><xsl:sequence select="-0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'natural-up'"><xsl:sequence select="0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-down'"><xsl:sequence select="-1.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-up'"><xsl:sequence select="-0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'double-sharp-down'"><xsl:sequence select="1.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'double-sharp-up'"><xsl:sequence select="2.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-flat-down'"><xsl:sequence select="-2.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-flat-up'"><xsl:sequence select="-1.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'arrow-down'"><xsl:sequence select="-0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'arrow-up'"><xsl:sequence select="0.5"/></xsl:when>
          <xsl:when test="$note/accidental = 'triple-sharp'"><xsl:sequence select="3"/></xsl:when>
          <xsl:when test="$note/accidental = 'triple-flat'"><xsl:sequence select="-3"/></xsl:when>
          <xsl:when test="$note/accidental = 'slash-quarter-sharp'"><xsl:sequence select="0.56"/></xsl:when>
          <xsl:when test="$note/accidental = 'slash-sharp'"><xsl:sequence select="0.89"/></xsl:when>
          <xsl:when test="$note/accidental = 'slash-flat'"><xsl:sequence select="-0.44"/></xsl:when>
          <xsl:when test="$note/accidental = 'double-slash-flat'"><xsl:sequence select="-0.89"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-1'"><xsl:sequence select="0.222"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-2'"><xsl:sequence select="0.444"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-3'"><xsl:sequence select="0.667"/></xsl:when>
          <xsl:when test="$note/accidental = 'sharp-5'"><xsl:sequence select="1.111"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-1'"><xsl:sequence select="-0.222"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-2'"><xsl:sequence select="-0.444"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-3'"><xsl:sequence select="-0.667"/></xsl:when>
          <xsl:when test="$note/accidental = 'flat-4'"><xsl:sequence select="-0.889"/></xsl:when>
          <xsl:when test="$note/accidental = 'sori'"><xsl:sequence select="0.33"/></xsl:when>
          <xsl:when test="$note/accidental = 'koron'"><xsl:sequence select="-0.67"/></xsl:when>
          <xsl:otherwise>
            <xsl:message>[note] Unhandled accidental '<xsl:value-of select="$note/accidental"/>'</xsl:message>
            <xsl:sequence select="0"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise><xsl:sequence select="0"/></xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    Template: Catch-all and issue a warning.
  -->
  <xsl:template match="*">
    <xsl:message terminate="no">[<xsl:value-of select="name()"/>] Unhandled element</xsl:message>
  </xsl:template>
</xsl:stylesheet>