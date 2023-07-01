<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="3.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="#all"
  expand-text="yes">

  <xsl:output method="text" media-type="text/plain" omit-xml-declaration="yes"/>

  <!--
    User-defined arguments
  -->
  <xsl:param name="useSef" as="xs:boolean" select="false()"/>
  <xsl:param name="chordVolume" select="50"/>
  <xsl:param name="melodyInstrument" select="'TenorSax'"/>
  <xsl:param name="chordInstrument" select="'Piano1'"/>
  <xsl:param name="melodyVoice" select="1"/>
  <xsl:param name="globalGroove"/>
  <xsl:variable name="stylesheetParams" select="
    map {
      QName('', 'chordVolume'): $chordVolume,
      QName('', 'melodyInstrument'): $melodyInstrument,
      QName('', 'chordInstrument'): $chordInstrument,
      QName('', 'melodyVoice'): $melodyVoice,
      QName('', 'globalGroove'): $globalGroove
    }
  "/>

  <!--
    Convert a MusicXML score to MMA in 2 steps:
    1. Unroll the score into a linear one
    2. Convert the unrolled score to MMA

    Chaining the transformations using https://stackoverflow.com/a/75594839/209184
  -->
  <xsl:param name="xslt-uris" as="xs:string*" select="'unroll.xsl', 'musicxml-mma-unrolled.xsl'"/>
  <xsl:param name="sef-uris" as="xs:string*" select="'unroll.sef.json', 'musicxml-mma-unrolled.sef.json'"/>

  <xsl:output indent="yes"/>

  <xsl:template match="/" name="xsl:initial-template">
    <xsl:if test="not($useSef)">
      <xsl:sequence
        select="fold-left($xslt-uris, /, function($a, $s) {
          transform(map{'source-node': $a, 'stylesheet-node': doc($s), 'stylesheet-params': $stylesheetParams })?output
        })"
      />
    </xsl:if>
    <xsl:if test="$useSef">
      <xsl:sequence
        select="fold-left($sef-uris, /, function($a, $s) {
          transform(map{'source-node': $a, 'package-text': unparsed-text($s), 'stylesheet-params': $stylesheetParams })?output
        })"
      />
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
