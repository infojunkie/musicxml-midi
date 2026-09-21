<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:saxon="http://saxon.sf.net/"
                extension-element-prefixes="saxon"
                exclude-result-prefixes="xs"
>
    <xsl:strip-space elements="*"/>
    <xsl:output indent="yes" omit-xml-declaration="no" saxon:indent-spaces="2"/>

    <xsl:param name="xpath" as="xs:string" select="''"/>

    <xsl:template match="/">
        <xsl:variable name="toRemove" as="node()*">
            <xsl:if test="$xpath != ''">
                <xsl:evaluate xpath="$xpath" context-item="."/>
            </xsl:if>
        </xsl:variable>

        <xsl:apply-templates select="node()">
            <xsl:with-param name="toRemove" select="$toRemove" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="node() | @*">
        <xsl:param name="toRemove" as="node()*" tunnel="yes"/>
        <xsl:if test="not(. intersect $toRemove)">
            <xsl:copy>
                <xsl:apply-templates select="node() | @*"/>
            </xsl:copy>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
