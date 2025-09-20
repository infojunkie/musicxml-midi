<?xml version="1.0" encoding="UTF-8"?>

<!--
  Generate an Ableton ASCL tuning given an input MusicXML.
  The generated tuning is created based on associating note accidentals with pitch alterations.
  An error is thrown if the same note/accidental combination is associated with different pitch/alters.
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

  <xsl:output method="text" media-type="text/plain" omit-xml-declaration="yes"/>

  <!--
    State: Accumulate notes with their tunings in cents.
  -->
  <xsl:accumulator name="tunings" as="map(xs:string, map(xs:string, xs:anyAtomicType))" initial-value="map{}">
    <xsl:accumulator-rule match="note[pitch]">
      <xsl:sequence select="
        let
        $accidental := accumulator-after('noteAccidentals')(pitch/step),
        $notename := concat(xs:string(pitch/step), if ($accidental = 'natural') then '' else $accidental),
        $alter := if (pitch/alter) then xs:double(pitch/alter) else musicxml:noteAlter($accidental),
        $tuning := round(utils:positive-mod($alter * 100 + musicxml:noteTuning(xs:string(pitch/step)), 1200) * 10000) div 10000,
        $valid := if (map:contains($value, $notename) and map:get($value, $notename)?tuning != $tuning)
          then fn:error(errors:unhandled, 'Found multiple tunings for note ' || $notename) else true()

        return map:merge((
          $value,
          map{ $notename: map{ 'notename': $notename, 'tuning': $tuning }}
        ), map{ 'duplicates': 'use-last' })
      "/>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <xsl:template match="/">
    <xsl:variable name="tuning" select="
      let $t1 := array:sort(array{ map:for-each(accumulator-after('tunings'), function($k, $v) { $v }) }, (), function($v) { $v?tuning })
      return array:fold-left($t1, array{}, function($t, $v) {
        let $dupes := array:filter($t1, function($d) {
          $d?tuning = $v?tuning and 0 = array:size(array:filter($t, function($dt) { $dt?tuning = $v?tuning }))
        })
        return if (array:size($dupes) > 0) then array:append($t, map{
          'notename': string-join(array:for-each($dupes, function($d) { $d?notename }), '/'),
          'tuning': $v?tuning
        }) else $t
      })
    "/>
<xsl:text>! </xsl:text><xsl:value-of select="replace(tokenize(base-uri(), '/')[last()], '\.[^\.]*$', '.ascl')" />
!
Automatically generated tuning from the score <xsl:value-of select="base-uri()"/>
!
! default tuning: degree 0 = 261.625565 Hz
!
<xsl:value-of select="array:size($tuning)"/>
! <xsl:iterate select="2 to array:size($tuning)">
  <xsl:text>&#xa;</xsl:text>
  <xsl:value-of select="map:get(array:get($tuning, .), 'tuning')"/>. ! <xsl:value-of select="map:get(array:get($tuning, .), 'notename')"/>
</xsl:iterate>
1200. ! <xsl:value-of select="map:get(array:get($tuning, 1), 'notename')"/>
!
! Note names are formatted as per MusicXML/SMuFL accidentals.
!
! @ABL NOTE_NAMES <xsl:iterate select="1 to array:size($tuning)">"<xsl:value-of select="map:get(array:get($tuning, .), 'notename')"/>" </xsl:iterate>
! @ABL REFERENCE_PITCH 4 0 261.625565
  </xsl:template>
</xsl:stylesheet>
