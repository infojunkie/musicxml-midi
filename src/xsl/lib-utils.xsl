<?xml version="1.0" encoding="UTF-8"?>

<!--
  Reusable general functions.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:utils="https://github.com/infojunkie/musicxml-midi/utils"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
>

  <!--
    Template: Get accumulator value at node.
    Function: Get accumulator value at node.
  -->
  <xsl:template match="node()" mode="accumulator-before">
    <xsl:param name="accumulator"/>
    <xsl:value-of select="accumulator-before($accumulator)"/>
  </xsl:template>
  <xsl:template match="node()" mode="accumulator-after">
    <xsl:param name="accumulator"/>
    <xsl:value-of select="accumulator-after($accumulator)"/>
  </xsl:template>
  <xsl:function name="utils:accumulator-before">
    <xsl:param name="accumulator"/>
    <xsl:param name="node"/>
    <xsl:sequence>
      <xsl:apply-templates select="$node" mode="accumulator-before">
        <xsl:with-param name="accumulator" select="$accumulator"/>
      </xsl:apply-templates>
    </xsl:sequence>
  </xsl:function>
  <xsl:function name="utils:accumulator-after">
    <xsl:param name="accumulator"/>
    <xsl:param name="node"/>
    <xsl:sequence>
      <xsl:apply-templates select="$node" mode="accumulator-after">
        <xsl:with-param name="accumulator" select="$accumulator"/>
      </xsl:apply-templates>
    </xsl:sequence>
  </xsl:function>

  <!--
    Function: Python-like mod function.
    https://stackoverflow.com/a/60182730/209184
  -->
  <xsl:function name="utils:negative-mod" as="xs:double">
    <xsl:param name="dividend" as="xs:double"/>
    <xsl:param name="divisor" as="xs:double"/>
    <xsl:sequence select="$dividend - floor($dividend div $divisor) * $divisor"/>
  </xsl:function>

  <!--
    Function: Positive mod.
  -->
  <xsl:function name="utils:positive-mod" as="xs:double">
    <xsl:param name="dividend" as="xs:double"/>
    <xsl:param name="divisor" as="xs:double"/>
    <xsl:sequence select="($dividend mod $divisor + $divisor) mod $divisor"/>
  </xsl:function>

</xsl:stylesheet>
