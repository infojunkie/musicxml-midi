<?xml version="1.0" encoding="UTF-8"?>

<!--
  Unroll a MusicXML score to expand all jumps/repeats.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
>

  <xsl:output method="xml" indent="yes" encoding="UTF-8"
    omit-xml-declaration="no" standalone="no"
    doctype-system="http://www.musicxml.org/dtds/partwise.dtd"
    doctype-public="-//Recordare//DTD MusicXML 4.0 Partwise//EN"/>

  <!--
    Global state.

    We store the measure attributes, because these are implicitly carried forward from measure to measure
    unless they are explicitly changed. In case of repeats, we will need to re-apply the implicit attributes.
  -->
  <xsl:accumulator name="time" as="element()" initial-value="()">
    <xsl:accumulator-rule match="measure" select="if (./attributes/time) then ./attributes/time else $value"/>
  </xsl:accumulator>
  <xsl:accumulator name="clef" as="element()" initial-value="()">
    <xsl:accumulator-rule match="measure" select="if (./attributes/clef) then ./attributes/clef else $value"/>
  </xsl:accumulator>
  <xsl:accumulator name="divisions" as="element()" initial-value="()">
    <xsl:accumulator-rule match="measure" select="if (./attributes/divisions) then ./attributes/divisions else $value"/>
  </xsl:accumulator>
  <xsl:accumulator name="key" as="element()" initial-value="()">
    <xsl:accumulator-rule match="measure" select="if (./attributes/key) then ./attributes/key else $value"/>
  </xsl:accumulator>

  <!--
    Start here.
  -->
  <xsl:template match="/">
    <xsl:apply-templates select="./score-partwise"/>
  </xsl:template>

  <xsl:template match="part">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="measure[1]">
        <xsl:with-param name="repeatMeasure" select="measure[1]"/>
        <xsl:with-param name="repeatCount" select="1"/>
        <xsl:with-param name="jump"/>
        <xsl:with-param name="previousMeasure"/>
        <xsl:with-param name="previousTime" select="()"/>
        <xsl:with-param name="previousDivisions" select="()"/>
        <xsl:with-param name="previousKey" select="()"/>
        <xsl:with-param name="previousClef" select="()"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!--
    Unroll the repeats and jumps into a linear sequence of measures. To do this, we advance measure by measure, carrying a state made of:
    - Previous measure
    - Previous attributes
    - Current loop starting measure, typically indicated by a forward-facing repeat barline
    - Current loop counter
    - Current jump status
    Based on the current measure's repeats and jumps, and the current state, we choose which measure to output next.
  -->
  <xsl:template match="measure">
    <xsl:param name="previousMeasure"/>
    <xsl:param name="previousTime"/>
    <xsl:param name="previousDivisions"/>
    <xsl:param name="previousKey"/>
    <xsl:param name="previousClef"/>
    <xsl:param name="repeatMeasure"/>
    <xsl:param name="repeatCount"/>
    <xsl:param name="jump"/>

    <xsl:variable name="time" select="accumulator-after('time')"/>
    <xsl:variable name="divisions" select="accumulator-after('divisions')"/>
    <xsl:variable name="key" select="accumulator-after('key')"/>
    <xsl:variable name="clef" select="accumulator-after('clef')"/>

    <!--
      Alternate ending start: Skip to the matching following alternate ending if the loop counter isn't mentioned in the current ending.
    -->
    <xsl:choose><xsl:when test="barline[ending/@type = 'start'] and not(index-of(tokenize(barline/ending[@type = 'start']/@number, '\s*,\s*'), format-number($repeatCount, '0')))">
      <xsl:variable name="nextMeasure" select="following-sibling::measure[barline/ending/@type = 'start' and index-of(tokenize(barline/ending[@type = 'start']/@number, '\s*,\s*'), format-number($repeatCount, '0'))][1]"/>
      <xsl:apply-templates select="$nextMeasure">
        <xsl:with-param name="repeatMeasure" select="$repeatMeasure"/>
        <xsl:with-param name="repeatCount" select="$repeatCount"/>
        <xsl:with-param name="jump" select="$jump"/>
        <xsl:with-param name="previousMeasure" select="."/>
        <xsl:with-param name="previousTime" select="$time"/>
        <xsl:with-param name="previousDivisions" select="$divisions"/>
        <xsl:with-param name="previousKey" select="$key"/>
        <xsl:with-param name="previousClef" select="$clef"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>

    <!--
      Output the measure
      - minus any jump/repeat information
      - plus any implicit measure attributes that need redeclaring
    -->
    <xsl:copy>
      <xsl:apply-templates select="@*"/>

      <!--
        Generate new attributes if they're different than previous attributes and are not explicitly declared in this measure.
        Add a new <attributes> element if any such attribute is generated.
        Note that the attributes are generated in the expected order as per musicxml.xsd.
      -->
      <xsl:variable name="attributes">
        <xsl:if test="$divisions and not(deep-equal($divisions, $previousDivisions)) and not(./attributes/divisions)">
          <xsl:copy-of select="$divisions"/>
        </xsl:if>
        <xsl:if test="$key and not(deep-equal($key, $previousKey)) and not(./attributes/key)">
          <xsl:copy-of select="$key"/>
        </xsl:if>
        <xsl:if test="$time and not(deep-equal($time, $previousTime)) and not(./attributes/time)">
          <xsl:copy-of select="$time"/>
        </xsl:if>
        <xsl:if test="$clef and not(deep-equal($clef, $previousClef)) and not(./attributes/clef)">
          <xsl:copy-of select="$clef"/>
        </xsl:if>
      </xsl:variable>
      <xsl:if test="$attributes != ''">
        <xsl:element name="attributes">
          <xsl:copy-of select="$attributes"/>
        </xsl:element>
      </xsl:if>

      <xsl:apply-templates select="*[not(
        self::barline |
        self::*/sound[@segno] |
        self::*/sound[@dalsegno] |
        self::*/sound[@fine] |
        self::*/sound[@dacapo] |
        self::*/sound[@tocoda]
      )]"/>
    </xsl:copy>

    <!--
      Advance to next measure with our unrolling algorithm.
    -->
    <xsl:choose>
      <!--
        Fine: Stop everything
        TODO Handle sound/@time-only for alternate endings.
      -->
      <xsl:when test="*/sound/@fine = 'yes' and $jump != ''">
      </xsl:when>
      <!--
        To Coda: Jump forward to labeled coda
        TODO Handle sound/@time-only for alternate endings.
      -->
      <xsl:when test="*/sound[@tocoda] and $jump != ''">
        <xsl:variable name="coda" select="*/sound/@tocoda"/>
        <xsl:variable name="nextMeasure" select="following-sibling::measure[*/sound/@coda = $coda]"/>
        <xsl:apply-templates select="$nextMeasure">
          <xsl:with-param name="repeatMeasure" select="//measure[1]"/>
          <xsl:with-param name="repeatCount" select="10000"/>
          <xsl:with-param name="jump" select="$coda"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        Opening repeat: Save this measure as the loop start. Reset loop counter to 1 unless we're already looping.
        TODO Handle sound/@forward-repeat attribute for the same effect.
      -->
      <xsl:when test="barline/repeat/@direction = 'forward' or generate-id(.) = generate-id($repeatMeasure)">
        <xsl:apply-templates select="following-sibling::measure[1]">
          <xsl:with-param name="repeatMeasure" select="."/>
          <xsl:with-param name="repeatCount" select="if (generate-id(.) = generate-id($repeatMeasure)) then $repeatCount else 1"/>
          <xsl:with-param name="jump" select="$jump"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        Closing repeat without alternate ending: Loop back if the loop counter hasn't reached the requested times and after-jump repeats are ok.
      -->
      <xsl:when test="
        barline[not(ending)]/repeat/@direction = 'backward' and
        ($jump = '' or barline[not(ending)]/repeat/@after-jump = 'yes') and
        (if (barline[not(ending)]/repeat/@times) then number(barline[not(ending)]/repeat/@times) else 2) &gt; $repeatCount
      ">
        <xsl:apply-templates select="$repeatMeasure">
          <xsl:with-param name="repeatMeasure" select="$repeatMeasure"/>
          <xsl:with-param name="repeatCount" select="$repeatCount + 1"/>
          <xsl:with-param name="jump" select="$jump"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        Alternate ending end: Jump back to loop start if next loop counter is mentioned in any alternate ending for the current repeat block.
      -->
      <xsl:when test="barline[ending/@type = 'stop']/repeat/@direction = 'backward' and $repeatMeasure/following-sibling::measure[
        preceding-sibling::measure[barline/repeat/@direction = 'forward'][1][generate-id(.) = generate-id($repeatMeasure)] and
        barline/ending/@type = 'start'
        and index-of(tokenize(barline/ending[@type = 'start']/@number, '\s*,\s*'), format-number($repeatCount + 1, '0'))
      ]">
        <xsl:apply-templates select="$repeatMeasure">
          <xsl:with-param name="repeatMeasure" select="$repeatMeasure"/>
          <xsl:with-param name="repeatCount" select="$repeatCount + 1"/>
          <xsl:with-param name="jump" select="$jump"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        Da capo: Go back to start.
      -->
      <xsl:when test="*/sound/@dacapo = 'yes' and $jump != 'capo'">
        <xsl:apply-templates select="//measure[1]">
          <xsl:with-param name="repeatMeasure" select="//measure[1]"/>
          <xsl:with-param name="repeatCount" select="10000"/>
          <xsl:with-param name="jump" select="'capo'"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        Dal segno: Go back to labeled sign.
      -->
      <xsl:when test="*/sound[@dalsegno] and $jump != */sound/@dalsegno">
        <xsl:variable name="segno" select="*/sound/@dalsegno"/>
        <xsl:variable name="nextMeasure" select="preceding-sibling::measure[*/sound/@segno = $segno]"/>
        <xsl:apply-templates select="$nextMeasure">
          <xsl:with-param name="repeatMeasure" select="//measure[1]"/>
          <xsl:with-param name="repeatCount" select="10000"/>
          <xsl:with-param name="jump" select="$segno"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        Closing repeat without alternate ending: Go straight and reset state if the loop counter has reached the requested times.
      -->
      <xsl:when test="barline[not(ending)]/repeat/@direction = 'backward' and number(barline/repeat/@times) &lt;= $repeatCount">
        <xsl:apply-templates select="following-sibling::measure[1]">
          <xsl:with-param name="repeatMeasure" select="//measure[1]"/>
          <xsl:with-param name="repeatCount" select="10000"/>
          <xsl:with-param name="jump" select="$jump"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:when>
      <!--
        General case: Keep going straight, remembering current state.
      -->
      <xsl:otherwise>
        <xsl:apply-templates select="following-sibling::measure[1]">
          <xsl:with-param name="repeatMeasure" select="$repeatMeasure"/>
          <xsl:with-param name="repeatCount" select="$repeatCount"/>
          <xsl:with-param name="jump" select="$jump"/>
          <xsl:with-param name="previousMeasure" select="."/>
          <xsl:with-param name="previousTime" select="$time"/>
          <xsl:with-param name="previousDivisions" select="$divisions"/>
          <xsl:with-param name="previousKey" select="$key"/>
          <xsl:with-param name="previousClef" select="$clef"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:otherwise></xsl:choose>
  </xsl:template>

  <!--
    The identity transformation.
  -->
  <xsl:template match="text()">
    <xsl:value-of select="." />
  </xsl:template>

  <!--
    Whitespace within an xsl:copy could cause problems with
    empty elements.
  -->
  <xsl:template match="*|@*|comment()|processing-instruction()">
    <xsl:copy><xsl:apply-templates
        select="*|@*|comment()|processing-instruction()|text()"
    /></xsl:copy>
  </xsl:template>

</xsl:stylesheet>
