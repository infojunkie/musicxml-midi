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
GROOVE <xsl:value-of select="if (contains(., '(')) then translate(replace(., '.*?\((.*?)\)', '$1'), ' ', '') else translate(., ' ', '')"/>
</xsl:template>

<xsl:template match="measure">
  <xsl:apply-templates select="attributes/time"/>
  <xsl:text>&#xa;</xsl:text>
  <xsl:value-of select="@number"/>
  <xsl:apply-templates select="harmony"/>
</xsl:template>

<xsl:template match="harmony">
  <xsl:text> </xsl:text>
  <xsl:choose>
    <xsl:when test="kind = 'none'">z</xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="root/root-step"/>
      <xsl:variable name="rootAlter"><xsl:value-of select="root/root-alter"/></xsl:variable>
      <xsl:value-of select="if ($rootAlter='1') then '#' else if ($rootAlter='-1') then 'b' else ''"/>
      <xsl:value-of select="kind/@text"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="time">
TIME <xsl:value-of select="beats * 4 div beat-type"/>
</xsl:template>

</xsl:stylesheet>