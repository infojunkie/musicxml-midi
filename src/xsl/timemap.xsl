<?xml version="1.0" encoding="UTF-8"?>

<!--
  Generate a JSON timemap given an input MusicXML.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
>

  <xsl:include href="lib-musicxml.xsl"/>

  <xsl:output method="json" indent="yes" encoding="UTF-8"/>

  <!--
    User-defined arguments.
  -->
  <xsl:param name="useSef" as="xs:boolean" select="false()"/>
  <xsl:param name="renumberMeasures" as="xs:boolean" select="false()"/>

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
    Apply the timemap transformation to the unrolled score.
  -->
  <xsl:template match="/">
    <xsl:apply-templates select="$unrolled/score-partwise/part"/>
  </xsl:template>

  <xsl:template match="part" as="array(*)">
    <xsl:variable name="measures" as="map(*)*">
      <xsl:apply-templates select="measure"/>
    </xsl:variable>
    <xsl:sequence select="array{$measures}"/>
  </xsl:template>

  <xsl:template match="measure" as="map(*)*">
    <xsl:sequence select="map {
      'measure': accumulator-after('measureIndex')(@number),
      'timestamp': musicxml:timeToMillisecs(
        accumulator-before('measureOnset'),
        accumulator-after('divisions'),
        accumulator-after('tempo')
      ),
      'duration': musicxml:timeToMillisecs(
        accumulator-after('measureDuration'),
        accumulator-after('divisions'),
        accumulator-after('tempo')
      )
    }"/>
  </xsl:template>

</xsl:stylesheet>
