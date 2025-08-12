<?xml version="1.0" encoding="UTF-8"?>

<!--
  Test the lib-musicxml XSL accumulators and functions.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mma="http://www.mellowood.ca/mma"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  exclude-result-prefixes="#all"
>

  <xsl:include href="../src/xsl/lib-musicxml.xsl"/>

  <xsl:output method="json" indent="no" encoding="UTF-8"/>

  <xsl:template match="/">
    <xsl:apply-templates select="score-partwise/part"/>
  </xsl:template>

  <xsl:template match="part" as="array(*)">
    <xsl:variable name="measures" as="map(*)*">
      <xsl:apply-templates select="measure"/>
    </xsl:variable>
    <xsl:sequence select="array{$measures}"/>
  </xsl:template>

  <xsl:template match="measure" as="map(*)*">
    <xsl:map>
      <xsl:map-entry key="'measure'">
        <xsl:map>
          <xsl:map-entry key="'index'" select="accumulator-after('measureIndex')(@number)"/>
          <xsl:map-entry key="'number'" select="xs:string(@number)"/>
          <xsl:map-entry key="'onset'" select="accumulator-before('measureOnset')"/>
          <xsl:map-entry key="'duration'" select="accumulator-after('measureDuration')"/>
          <xsl:map-entry key="'divisions'" select="accumulator-after('divisions')"/>
          <xsl:map-entry key="'tempo'" select="accumulator-after('tempo')"/>
          <xsl:variable name="notes" as="map(*)*">
            <xsl:apply-templates select="note"/>
          </xsl:variable>
          <xsl:map-entry key="'notes'" select="array{$notes}"/>
        </xsl:map>
      </xsl:map-entry>
    </xsl:map>
  </xsl:template>

  <xsl:template match="note" as="map(*)*">
    <xsl:map>
    </xsl:map>
  </xsl:template>

</xsl:stylesheet>
