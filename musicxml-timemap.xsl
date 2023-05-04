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

  <xsl:output method="json" indent="yes" encoding="UTF-8"/>

  <!--
    Global state.
  -->
  <xsl:accumulator name="divisions" as="xs:decimal" initial-value="1">
    <!-- TODO Handle mid-measure division changes. -->
    <xsl:accumulator-rule match="measure" select="if (./attributes/divisions) then xs:decimal(./attributes/divisions/text()) else $value"/>
  </xsl:accumulator>
  <xsl:accumulator name="tempo" as="xs:decimal" initial-value="120">
    <xsl:accumulator-rule match="measure" select="if (./direction[sound/@tempo]) then xs:decimal(./direction/sound/@tempo) else $value"/>
  </xsl:accumulator>
  <xsl:accumulator name="measures" as="map(xs:string, xs:integer)" initial-value="map{}">
    <xsl:accumulator-rule match="measure" select="if (map:contains($value, @number)) then map:put($value, @number, map:get($value, @number)) else map:put($value, @number, map:size($value))"/>
  </xsl:accumulator>
  <xsl:accumulator name="duration" as="xs:decimal" initial-value="0">
    <xsl:accumulator-rule match="measure" phase="start" select="0"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="./cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="./chord"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="./forward"><xsl:sequence select="$value + xs:decimal(./forward/duration)"/></xsl:when>
        <xsl:when test="./backup"><xsl:sequence select="$value - xs:decimal(./backup/duration)"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + xs:decimal(./duration)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    Start here.
  -->
  <xsl:template match="/">
    <xsl:apply-templates select="./score-partwise/part"/>
  </xsl:template>

  <xsl:template match="part" as="array(*)">
    <xsl:variable name="output" as="map(*)*">
      <xsl:apply-templates select="measure[1]">
        <xsl:with-param name="repeatMeasure" select="measure[1]"/>
        <xsl:with-param name="repeatCount" select="1"/>
        <xsl:with-param name="jump"/>
        <xsl:with-param name="previousMeasure"/>
        <xsl:with-param name="previousTimestamp" select="0"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:sequence select="array{$output}"/>
  </xsl:template>

  <!--
    Unroll the repeats and jumps into a linear sequence of measures. To do this, we advance measure by measure, carrying a state made of:
    - Current loop starting measure, typically indicated by a forward-facing repeat barline
    - Current loop counter
    - Current jump status
    - Previous measure
    - Previous attributes that carry over to the current measure
    Based on the current measure's repeats and jumps, and the current state, we choose which measure to output next.
  -->
  <xsl:template match="measure" as="map(*)*">
    <xsl:param name="repeatMeasure"/>
    <xsl:param name="repeatCount"/>
    <xsl:param name="jump"/>
    <xsl:param name="previousMeasure"/>
    <xsl:param name="previousTimestamp"/>

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
        <xsl:with-param name="previousTimestamp" select="$previousTimestamp"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>

    <!--
      Adjust carried-over state.
    -->
    <xsl:variable name="timestamp" select="$previousTimestamp + accumulator-after('duration') * accumulator-after('divisions') * accumulator-after('tempo')"/>

    <!--
      Output JSON.
    -->
    <xsl:sequence select="map {
      'measure': accumulator-after('measures')(@number),
      'timestamp': $previousTimestamp
    }"/>

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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
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
          <xsl:with-param name="previousTimestamp" select="$timestamp"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>

  </xsl:otherwise></xsl:choose>
  </xsl:template>
</xsl:stylesheet>
