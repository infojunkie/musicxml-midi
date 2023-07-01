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
    Global state that is carried across measures.
  -->
  <xsl:accumulator name="divisions" as="xs:decimal" initial-value="1">
    <xsl:accumulator-rule match="attributes/divisions" select="text()"/>
  </xsl:accumulator>

  <xsl:accumulator name="tempo" as="xs:decimal" initial-value="120">
    <xsl:accumulator-rule match="sound[@tempo]" select="@tempo"/>
  </xsl:accumulator>

  <xsl:accumulator name="metronome" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/direction[direction-type/metronome]" select="."/>
  </xsl:accumulator>

  <xsl:accumulator name="time" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/time" select="."/>
  </xsl:accumulator>

  <xsl:accumulator name="clef" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/clef" select="."/>
  </xsl:accumulator>

  <xsl:accumulator name="key" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/key" select="."/>
  </xsl:accumulator>

  <xsl:accumulator name="measureIndex" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="measure" select="$value + 1"/>
  </xsl:accumulator>

  <xsl:accumulator name="measureDuration" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="measure/forward" select="$value + xs:decimal(./forward/duration)"/>
    <xsl:accumulator-rule match="measure/backup" select="$value - xs:decimal(./backup/duration)"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="./cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="./chord"><xsl:sequence select="$value"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + xs:decimal(./duration)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <xsl:accumulator name="measureOnset" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="measure" phase="start" select="$value"/>
    <xsl:accumulator-rule match="measure" phase="end" select="$value + accumulator-after('measureDuration')"/>
  </xsl:accumulator>

  <xsl:accumulator name="noteDuration" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="./cue"><xsl:sequence select="0"/></xsl:when>
        <xsl:when test="./chord"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="./tie[@type='stop']"><xsl:sequence select="$value + xs:decimal(./duration)"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="xs:decimal(./duration)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <xsl:accumulator name="noteOnset" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="note" phase="end">
      <xsl:choose>
        <xsl:when test="./cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="./chord"><xsl:sequence select="$value"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + xs:decimal(./duration)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <xsl:accumulator name="harmonyPreviousDuration" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="harmony" phase="end" select="0"/>
    <xsl:accumulator-rule match="note" phase="end">
      <xsl:choose>
        <xsl:when test="./cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="./chord"><xsl:sequence select="$value"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + xs:decimal(./duration)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    MusicXML functions.
  -->
  <xsl:function name="musicxml:timestamp" as="xs:decimal">
    <xsl:param name="offset" as="xs:decimal"/>
    <xsl:param name="divisions" as="xs:decimal"/>
    <xsl:param name="tempo" as="xs:decimal"/>
    <xsl:sequence select="$offset * 60000 div $divisions div $tempo"/>
  </xsl:function>

  <!-- Identity template : copy all text nodes, elements and attributes
  <xsl:template match="@*|node()">
      <xsl:copy>
          <xsl:apply-templates select="@*|node()" />
      </xsl:copy>
  </xsl:template>

  <xsl:template match="measure">
      <xsl:message>
        MEASURE <xsl:value-of select="accumulator-after('measureIndex') - 1"/>
        starts <xsl:value-of select="musicxml:timestamp(
          accumulator-before('measureOnset'),
          accumulator-after('divisions'),
          accumulator-after('tempo')
        )"/>
        TIME <xsl:value-of select="accumulator-after('time')"/>
      </xsl:message>
      <xsl:copy>
          <xsl:apply-templates select="@*|node()" />
      </xsl:copy>
  </xsl:template>

  <xsl:template match="note">
      <xsl:message>
        <xsl:if test="not(./tie) or (./tie[@type='start'] and not(./tie[@type='stop']))">
          NOTE
          <xsl:value-of select="if (./pitch) then ./pitch else if (./rest) then 'rest' else 'unknown'"/>
          starts <xsl:value-of select="accumulator-before('noteOnset')"/>
        </xsl:if>
        <xsl:if test="not(./tie) or (./tie[@type='stop'] and not (./tie[@type='start']))">
          lasts <xsl:value-of select="accumulator-after('noteDuration')"/>
        </xsl:if>
      </xsl:message>
      <xsl:copy>
          <xsl:apply-templates select="@*|node()" />
      </xsl:copy>
  </xsl:template>

  <xsl:template match="harmony">
      <xsl:message>
        CHORD
        <xsl:value-of select="."/>
        starts <xsl:value-of select="accumulator-after('noteOnset')"/>
        previous duration <xsl:value-of select="accumulator-before('harmonyPreviousDuration')"/>
      </xsl:message>
      <xsl:copy>
          <xsl:apply-templates select="@*|node()" />
      </xsl:copy>
  </xsl:template> -->

</xsl:stylesheet>