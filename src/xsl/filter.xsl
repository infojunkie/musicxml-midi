<?xml version="1.0" encoding="UTF-8"?>

<!--
  Filter out unwanted tags passed on the command line.

  https://stackoverflow.com/a/2641719/209184
-->

<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>
 <xsl:output omit-xml-declaration="no" indent="yes"/>

 <xsl:param name="filter" required="yes"/>

 <xsl:template match="node()|@*">
  <xsl:copy>
   <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
 </xsl:template>

 <xsl:template match="*[local-name()=tokenize($filter,'\|')]"/>
</xsl:stylesheet>
