<?xml version="1.0" encoding="UTF-8"?>

<!--
  Unroll a MusicXML score to expand all jumps/repeats.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
>

  <xsl:output method="json" indent="yes" encoding="UTF-8"/>

  <xsl:include href="musicxml.xsl"/>

  <xsl:template match="/">
    <xsl:apply-templates select="./score-partwise/part"/>
  </xsl:template>

  <xsl:template match="part" as="array(*)">
    <xsl:variable name="output" as="map(*)*">
      <xsl:apply-templates select="measure"/>
    </xsl:variable>
    <xsl:sequence select="array{$output}"/>
  </xsl:template>

  <xsl:template match="measure" as="map(*)*">
    <!--
      Output JSON.
    -->
    <xsl:sequence select="map {
      'measure': number(@number),
      'timestamp': musicxml:timestamp(
        accumulator-before('measureOnset'),
        accumulator-after('divisions'),
        accumulator-after('tempo')
      )
    }"/>
  </xsl:template>

</xsl:stylesheet>
