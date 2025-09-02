<?xml version="1.0" encoding="UTF-8"?>

<!--
  Test the lib-musicxml XSL accumulators and functions.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  exclude-result-prefixes="#all"
>

  <xsl:include href="../src/xsl/lib-musicxml.xsl"/>

  <xsl:output method="json" indent="no" encoding="UTF-8"/>

  <xsl:variable name="test">
<![CDATA[
<score-partwise version="4.0">
   <part-list>
      <score-part id="P1">
         <part-name>Music</part-name>
      </score-part>
   </part-list>
   <part id="P1">
      <measure number="1">
         <attributes>
            <divisions>1</divisions>
            <key>
               <fifths>0</fifths>
            </key>
            <time>
               <beats>4</beats>
               <beat-type>4</beat-type>
            </time>
            <clef>
               <sign>G</sign>
               <line>2</line>
            </clef>
         </attributes>
         <note>
            <pitch>
               <step>C</step>
               <octave>4</octave>
            </pitch>
            <duration>4</duration>
            <type>whole</type>
         </note>
      </measure>
   </part>
</score-partwise>
]]>
  </xsl:variable>

  <xsl:template name="test">
    <xsl:apply-templates select="parse-xml($test)/score-partwise/part"/>
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
