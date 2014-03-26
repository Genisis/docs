<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text"/>

  <xsl:template match="/">
    <xsl:apply-templates mode="not-guide" />
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="span[@class='coming']" mode="guide" />
  <xsl:template match="span[@class='added']" mode="guide" />
  <xsl:template match="span[@class='deprecated']" mode="guide" />
  <xsl:template match="a[@class='sense_widget']" mode="guide" />
  <xsl:template match="ulink[@role='edit_me']" mode="guide" />

  <xsl:template match="text()" mode="not-guide" />

  <xsl:template match="text()" mode="guide">
    <xsl:value-of select="normalize-space(.)" />
  </xsl:template>

  <xsl:template match="text()" mode="guide">
    <xsl:value-of select="normalize-space(.)" />
  </xsl:template>

  <xsl:template match="code|b|strong|em|span|i" mode="guide">
    <xsl:text> </xsl:text>
    <xsl:apply-templates mode="guide" />
    <xsl:text> </xsl:text>
  </xsl:template>

  <xsl:template match="article[@class='guide_content']" mode="not-guide">
    <xsl:apply-templates mode="guide" />
  </xsl:template>

  <xsl:template match="p|th|td|dt|dd|li" mode="guide">
    <xsl:variable name="content">
      <xsl:value-of select="normalize-space(.)" />
    </xsl:variable>
    <xsl:if test="string-length($content)!= 0">
      <xsl:value-of select="$content" />
      <xsl:text>&#10;&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="pre" mode="guide">
    <xsl:apply-templates />
    <xsl:text>&#10;&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="h1|h2|h3|h4|h5|h6|p[@class='title']" mode="guide">
    <xsl:variable name="content">
      <xsl:copy>
        <xsl:apply-templates mode="guide"/>
      </xsl:copy>
    </xsl:variable>
    <xsl:text>============================&#10;</xsl:text>
    <xsl:for-each select="descendant::a[@id]">
      <xsl:text>#</xsl:text>
      <xsl:value-of select="attribute::id" />
      <xsl:text> </xsl:text>
    </xsl:for-each>
    <xsl:value-of select="normalize-space($content)" />
    <xsl:text>&#10;============================&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="*[@class='breadcrumbs']|*[@class='toc']|*[@class='navheader']|*[@class='navfooter']" mode="guide" />

</xsl:stylesheet>

