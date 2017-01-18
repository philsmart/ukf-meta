#!/usr/bin/perl

use Xalan;

#
# Load extra addresses.
#
# One extra address per line.  Blank lines and lines starting with '#' are
# ignored.
#
open(EXTRAS, "extra_addresses.txt") || die "could not open extra addresses file";
while (<EXTRAS>) {
	chomp;	# remove \n
	next if /^#/;
	$extras{$_} = 1 unless $_ eq '';
}
close EXTRAS;

#
# Load addresses from the metadata.
#
# Exclude support addresses using some XSLT magic.
#
# UK addresses
#
open(XML, xalanCall . " -IN ../mdx/uk/collected.xml -XSL extract_addresses.xsl|") || die "could not open input file";
while (<XML>) {
	if (/<EmailAddress>(mailto:)?(.*)<\/EmailAddress>/) {
		$metadata{$2} = 1;
	}
}
close XML;

#
# Now figure out the addresses we want to see in the mailing list.
# Make them lower case for comparisons.
#
foreach $addr (keys %extras) {
	$wanted{lc $addr} = $addr;
}
foreach $addr (keys %metadata) {
	$wanted{lc $addr} = $addr;
}

#
# List all wanted addresses.
#
print "--- LIST BEGIN ---\n";
foreach $addr (sort keys %wanted) {
	my $a = $wanted{$addr};
	print "$a\n";
}
print "--- LIST END ---\n";
