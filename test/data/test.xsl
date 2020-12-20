<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0"
>

<xsl:output method="text"/>

<xsl:template match="/">
  <xsl:value-of select="/score-partwise/work/work-title"/>
  <xsl:apply-templates select="/score-partwise/part/measure"/>
</xsl:template>

<xsl:template match="measure">
Measure #<xsl:value-of select="@number"/>
</xsl:template>

</xsl:stylesheet>
