<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0"
>
<xsl:output media-type="text/plain" omit-xml-declaration="yes" />

<xsl:variable name="divisions" select="score-partwise/part/measure/attributes/divisions" />
<xsl:variable name="beats" select="score-partwise/part/measure/attributes/time/beats" />
<xsl:variable name="beat-type" select="score-partwise/part/measure/attributes/time/beat-type" />

<xsl:template match="score-partwise">
  <!--
    Check out https://github.com/k8bushlover/XSLT-MusicXmlToSessionBand
  -->
// <xsl:value-of select="work/work-title" />
  <xsl:apply-templates select="identification/creator[@type='lyricist']" />
  <xsl:apply-templates select="part/measure" />
</xsl:template>

<xsl:template match="creator">
<!--
  Extract playback style from //identification/creator[@type='lyricist'] as exported by iReal Pro (and emulated by infojunkie/ireal-musicxml).
  See discussion at https://github.com/w3c/musicxml/issues/347
  For now, we manually map between iReal Pro styles and MMA grooves here.
-->
  <xsl:variable name="groove" select="if (contains(., '(')) then translate(replace(., '.*?\((.*?)\)', '$1'), ' ', '') else translate(., ' ', '')" />
Groove <xsl:choose>
    <xsl:when test="contains(lower-case($groove), 'swing')">
      <xsl:choose>
        <xsl:when test="$beats = 5 and $beat-type = 4">Jazz54</xsl:when>
        <xsl:otherwise>Swing</xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$groove" /></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="measure">
  <xsl:apply-templates select="attributes/time" />
  <xsl:apply-templates select="direction/sound[@tempo]" mode="tempo" />
  <xsl:text>&#xa;</xsl:text>
  <xsl:value-of select="@number" />
  <xsl:apply-templates select="harmony[1]">
    <xsl:with-param name="start" select="1" />
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="harmony">
  <xsl:param name="start" />
  <xsl:text> </xsl:text>
  <xsl:choose>
    <!--
      N.C. is expressed as "z" in MMA.
    -->
    <xsl:when test="kind = 'none'">z</xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="root/root-step" />
      <xsl:variable name="rootAlter"><xsl:value-of select="root/root-alter"/></xsl:variable>
      <xsl:value-of select="if ($rootAlter = '1') then '#' else if ($rootAlter = '-1') then 'b' else ''" />
      <xsl:value-of select="kind/@text" />
      <xsl:text>@</xsl:text><xsl:value-of select="$start" />
    </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="following-sibling::harmony[1]">
    <!--
      TODO Handle multiple tied notes for duration.
    -->
    <xsl:with-param name="start" select="$start + (following-sibling::note[1]/duration div $divisions)" />
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="sound" mode="tempo">
Tempo <xsl:value-of select="@tempo" />
</xsl:template>

<xsl:template match="time">
<!--
  Time signature in MMA is expressed as "number of quarter notes in a measure".
-->
Time <xsl:value-of select="beats * 4 div beat-type" />
TimeSig <xsl:value-of select="beats" />/<xsl:value-of select="beat-type" />
</xsl:template>

</xsl:stylesheet>
