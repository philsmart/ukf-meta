<?xml version="1.0" encoding="UTF-8"?>
<!--

	v13_to_v12_trust.xsl
	
	XSL stylesheet converting a SAML 2 metadata file describing a Shibboleth
	1.3 federation into the equivalent Shibboleth 1.2 trust file.
	
	Author: Ian A. Young <ian@iay.org.uk>

	$Id: v13_to_v12_trust.xsl,v 1.2 2005/04/05 16:20:18 iay Exp $
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
	xmlns:shibmeta="urn:mace:shibboleth:metadata:1.0"
	xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xmlns="urn:mace:shibboleth:trust:1.0"
	exclude-result-prefixes="shibmeta md">

	<!--
		Version information for this file.  Remember to peel off the dollar signs
		before dropping the text into another versioned file.
	-->
	<xsl:param name="cvsId">$Id: v13_to_v12_trust.xsl,v 1.2 2005/04/05 16:20:18 iay Exp $</xsl:param>

	<!--
		Add a comment to the start of the output file.
	-->
	<xsl:template match="/">
		<xsl:comment>
			<xsl:text>&#10;&#9;***DO NOT EDIT THIS FILE***&#10;&#10;</xsl:text>
			<xsl:text>&#9;Converted by:&#10;&#10;&#9;</xsl:text>
			<xsl:value-of select="substring-before(substring-after($cvsId, ': '), '$')"/>
			<xsl:text>&#10;</xsl:text>
		</xsl:comment>
		<Trust>
			<xsl:attribute name="xsi:schemaLocation">
				<xsl:text>urn:mace:shibboleth:trust:1.0 shibboleth-trust-1.0.xsd </xsl:text>
				<xsl:text>http://www.w3.org/2000/09/xmldsig# xmldsig-core-schema.xsd</xsl:text>
			</xsl:attribute>
			<xsl:apply-templates/>
		</Trust>
	</xsl:template>

	<!--Force UTF-8 encoding for the output.-->
	<xsl:output omit-xml-declaration="no" method="xml" encoding="UTF-8" indent="yes"/>

	<!--
		Extract a KeyAuthority extension from an EntitiesDescriptor or EntityDescriptor.
	-->
	<xsl:template match="md:EntitiesDescriptor | md:EntityDescriptor">
	
		<!-- extract KeyAuthority metadata, if any -->
		<xsl:if test="md:Extensions/shibmeta:KeyAuthority/ds:KeyInfo">
			<xsl:apply-templates select="md:Extensions/shibmeta:KeyAuthority">
				<xsl:with-param name="name" select="@Name"/>
			</xsl:apply-templates>
		</xsl:if>

		<!-- proceed to nested EntitiesDescriptor and EntityDescriptor elements -->
		<xsl:apply-templates select="md:EntitiesDescriptor | md:EntityDescriptor"/>
	</xsl:template>

	<!--
		Map shibmeta:KeyAuthority to trust:KeyAuthority
	-->
	<xsl:template match="shibmeta:KeyAuthority">
		<xsl:param name="name"/>
		<KeyAuthority>
			<!-- copy across VerifyDepth attribute if present -->
			<xsl:apply-templates select="@VerifyDepth"/>

			<!-- generate KeyName -->
			<ds:KeyName>
				<xsl:value-of select="$name"/>
			</ds:KeyName>

			<!-- generate single output KeyInfo element -->
			<ds:KeyInfo>
				<!-- extract the insides of all KeyInfo elements in the input -->
				<xsl:apply-templates select="text() | comment() | ds:KeyInfo/* | ds:KeyInfo/comment() | ds:KeyInfo/text()"/>
			</ds:KeyInfo>
		</KeyAuthority>
	</xsl:template>

	<!--
		Generic recursive copy for ds:* elements.
		
		This works better than an xsl:copy-of because it does not copy across spurious
		namespace nodes.
	-->
	<xsl:template match="ds:*">
		<xsl:element name="{name()}">
			<xsl:apply-templates select="ds:* | text() | comment() | @*"/>
		</xsl:element>
	</xsl:template>

	<!--
		By default, copy referenced attributes through unchanged.
	-->
	<xsl:template match="@*">
		<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
	</xsl:template>

	<!--
		By default, copy comments and text nodes through to the output unchanged.
	-->
	<xsl:template match="text()|comment()">
		<xsl:copy/>
	</xsl:template>

</xsl:stylesheet>
