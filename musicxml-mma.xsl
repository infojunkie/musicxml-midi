<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0"
>
<xsl:output media-type="text/plain" omit-xml-declaration="yes"/>

<xsl:template match="/">
// <xsl:value-of select="//work/work-title"/>
  <xsl:apply-templates select="//identification/creator[@type='lyricist']"/>
  <xsl:apply-templates select="//part/measure"/>
</xsl:template>

<xsl:template match="creator">
<!--
  Extract "groove" from //identification/creator[@type='lyricist'] at the moment, as exported by iReal Pro
  See discussion at https://github.com/w3c/musicxml/issues/347
  For now, we assume that a MMA groove exists verbatim for whatever is extracted here.
  TODO Better mapping between groove spec and selected MMA groove.
-->
Groove <xsl:value-of select="if (contains(., '(')) then translate(replace(., '.*?\((.*?)\)', '$1'), ' ', '') else translate(., ' ', '')"/>
</xsl:template>

<xsl:template match="measure">
  <xsl:apply-templates select="attributes/time"/>
  <xsl:apply-templates select="direction/sound[@tempo]" mode="tempo"/>
  <xsl:text>&#xa;</xsl:text>
  <xsl:value-of select="@number"/>
  <xsl:apply-templates select="harmony"/>
</xsl:template>

<xsl:template match="harmony">
  <xsl:text> </xsl:text>
  <xsl:choose>
    <!--
      N.C. is expressed as "z" in MMA.
    -->
    <xsl:when test="kind = 'none'">z</xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="root/root-step"/>
      <xsl:variable name="rootAlter"><xsl:value-of select="root/root-alter"/></xsl:variable>
      <xsl:value-of select="if ($rootAlter = '1') then '#' else if ($rootAlter = '-1') then 'b' else ''"/>
      <xsl:value-of select="kind/@text"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="sound" mode="tempo">
Tempo <xsl:value-of select="@tempo"/>
</xsl:template>

<xsl:template match="time">
<!--
  Time signature in MMA is expressed as "number of quarter notes in a measure".
-->
Time <xsl:value-of select="beats * 4 div beat-type"/>
TimeSig <xsl:value-of select="beats"/>/<xsl:value-of select="beat-type"/>
</xsl:template>

</xsl:stylesheet>