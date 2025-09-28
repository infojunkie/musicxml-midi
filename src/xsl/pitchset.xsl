<?xml version="1.0" encoding="UTF-8"?>

<!--
  Generate an JSON listing of the pitch set (collection) given an input MusicXML.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:utils="https://github.com/infojunkie/musicxml-midi/utils"
  xmlns:errors="https://github.com/infojunkie/musicxml-midi/errors"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:fn="http://www.w3.org/2005/xpath-functions"
  exclude-result-prefixes="#all"
>

  <xsl:include href="lib-utils.xsl"/>
  <xsl:include href="lib-musicxml.xsl"/>

  <xsl:output method="json" indent="no" encoding="UTF-8"/>

  <!--
    State: Accumulate unique pitches.
  -->
  <xsl:accumulator name="pitches" as="map(*)" initial-value="map{}">
    <xsl:accumulator-rule match="note[pitch]">
      <xsl:sequence select="
        let
        $accidental := accumulator-after('noteAccidentals')(pitch/step),
        $notename := concat(xs:string(pitch/step), if ($accidental != 'natural') then fn:string-join($accidental,'+') else ''),
        $alter := if (pitch/alter) then xs:double(pitch/alter) else musicxml:noteAlter($accidental),
        $valid := if (map:contains($value, $notename) and map:get($value, $notename)?alter != $alter)
          then fn:error(errors:unhandled, 'Found multiple alterations for note ' || $notename) else true()

        return map:merge((
          $value,
          map{ $notename: map{
            'pitch': xs:string(pitch/step),
            'accidental': if (count($accidental) = 1) then $accidental else array{$accidental},
            'alter': $alter
          }}
        ), map{ 'duplicates': 'use-last' })
      "/>
    </xsl:accumulator-rule>
    <xsl:accumulator-rule match="note[unpitched]">
      <xsl:sequence select="
        let
        $notehead := if (notehead) then translate(notehead, ' ', '-') else (),
        $notename := concat(xs:string(unpitched/display-step), xs:string(unpitched/display-octave), if ($notehead != 'normal') then $notehead else '')

        return map:merge((
          $value,
          map{ $notename: map{
            'pitch': xs:string(unpitched/display-step),
            'octave': xs:string(unpitched/display-octave),
            'notehead': $notehead
          }}
        ), map{ 'duplicates': 'use-last' })
      "/>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <xsl:template match="/" as="map(*)*">
    <xsl:sequence select="accumulator-after('pitches')"/>
  </xsl:template>
</xsl:stylesheet>
