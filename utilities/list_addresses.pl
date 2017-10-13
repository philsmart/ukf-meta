#!/usr/bin/perl -w
#
# Script to extract technical and administrative contact email addresses
# from a SAML metadata file, and add extra addresses from a well-known location.
#
# Author: Alex Stuart, alex.stuart@jisc.ac.uk
#

#
# Parameters
#
$metadata = '../mdx/uk/collected.xml';
$extra_addresses = '../../ukf-data/members/extra_addresses.txt';

#
# Subroutines
#
use Getopt::Long;
use XML::LibXML;

sub usage {
    print <<EOF;

    $0 [-h] [-f <metadata file>]
    
    -h - prints this help text and exits
    -f <metadata file> - takes metadata from this file, not the pre-defined file.
    --security - also extract the security contacts
        
    Extracts email addresses of contacts in a metadata file.
    
    By default, this extracts the technical and administrative contacts
    from the metadata file, and includes extra addresses.
    
EOF
}

#
# Options processing
#
my $help;
my $file;
my $security;
GetOptions( "help" => \$help,
            "file=s" => \$file,
            "security" => \$security
            );

if ( $help ) {
    usage();
    exit 0;
}

if ( $file ) {
    $metadata = $file;
}

if ( ! $metadata ) {
        print "ERROR: could not find metadata file $metadata\n";
        usage();
        exit 1;
}

if ( ! -r $metadata ) {
    print "ERROR: metadata file $metadata must be readable\n";
    usage();
    exit 2;
}


#
# Extract addresses from metadata file
#
my $dom = XML::LibXML->load_xml( location => $metadata );
my $xpc = XML::LibXML::XPathContext->new( $dom );
$xpc->registerNs( 'md', 'urn:oasis:names:tc:SAML:2.0:metadata' );
@tech_contacts = $xpc->findnodes( '//md:EntityDescriptor/md:ContactPerson/md:EmailAddress[../@contactType="technical"]');
foreach( @tech_contacts ) { 
    $email = ${_}->to_literal;
    $email =~ s/^mailto://i;
    $metadata{$email} = 1;
}


@admin_contacts = $xpc->findnodes( '//md:EntityDescriptor/md:ContactPerson/md:EmailAddress[../@contactType="administrative"]');
foreach( @admin_contacts ) { 
    $email = ${_}->to_literal;
    $email =~ s/^mailto://i;
    $metadata{$email} = 1;
}

if ( $security ) {
    $xpc->registerNs( 'remd', 'http://refeds.org/metadata' );
    @security_contacts = $xpc->findnodes(   '//md:EntityDescriptor/md:ContactPerson/md:EmailAddress
                                            [../@contactType="other"]
                                            [../@remd:contactType="http://refeds.org/metadata/contactType/security"]'
                                        );
    foreach( @security_contacts ) { 
        $email = ${_}->to_literal;
        $email =~ s/^mailto://i;
        $metadata{$email} = 1;
    }
}

#
# Load extra addresses.
#
# One extra address per line.  Blank lines and lines starting with '#' are
# ignored.
#
open(EXTRAS, "$extra_addresses") || die "could not open extra addresses file $extra_addresses";
while (<EXTRAS>) {
	chomp;	# remove \n
	next if /^#/;
	$extras{$_} = 1 unless $_ eq '';
}
close EXTRAS;

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
