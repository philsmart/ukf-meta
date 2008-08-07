#!/usr/bin/perl -w
use File::Temp qw(tempfile);
use Date::Parse;
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);

#
# Load RSA key blacklists.
#
print "Loading key blacklists...\n";
open KEYS, '../build/blacklist.RSA-1024' || die "can't open RSA 1024 blacklist";
while (<KEYS>) {
	chomp;
	$rsa1024{$_} = 1;
}
close KEYS;
open KEYS, '../build/blacklist.RSA-2048' || die "can't open RSA 2048 blacklist";
while (<KEYS>) {
	chomp;
	$rsa2048{$_} = 1;
}
close KEYS;
print "Blacklists loaded.\n";

while (<>) {

	#
	# Handle Entity/KeyName header line.
	#
	if (/^Entity:/) {
		@olines = ();
		@args = split;
		$entity = $args[1];
		$keyname = $args[3];
		
		#
		# Output header line.
		#
		$oline = "Entity $entity ";
		$hasKeyName = !($keyname eq '(none)');
		if ($hasKeyName) {
			$oline .= "has KeyName $keyname";
		} else {
			$oline .= "has no KeyName";
		}
		push(@olines, $oline);

		#
		# Create a temporary file for this certificate in PEM format.
		#
		($fh, $filename) = tempfile(UNLINK => 1);
		#print "temp file is: $filename\n";

		# do not buffer output to the temporary file
		select((select($fh), $|=1)[0]);
		next;
	}
	
	#
	# Put other lines into a temporary file.
	#
	print $fh $_;
	
	#
	# If this is the last line of the certificate, actually do
	# something with it.
	#
	if (/END CERTIFICATE/) {
		#
		# Don't close the temporary file yet, because that would cause it
		# to be deleted.  We've already arranged for buffering to be
		# disabled, so the file can simply be passed to other applications
		# as input, perhaps multiple times.
		#
		
		#
		# Use openssl to convert the certificate to text
		#
		my(@lines, $issuer, $subjectCN, $issuerCN);
		$cmd = "openssl x509 -in $filename -noout -text -nameopt RFC2253 -modulus |";
		open(SSL, $cmd) || die "could not open openssl subcommand";
		while (<SSL>) {
			push @lines, $_;
			if (/^\s*Issuer:\s*(.*)$/) {
				$issuer = $1;
				if ($issuer =~ /CN=([^,]+)/) {
					$issuerCN = $1;
				} else {
					$issuerCN = $issuer;
				}
			}
			if (/^\s*Subject:\s*.*?CN=([a-z0-9\-\.]+).*$/) {
				$subjectCN = $1;
				# print "subjectCN = $subjectCN\n";
			}
			if (/RSA Public Key: \((\d+) bit\)/) {
				$pubSize = $1;
				# print "   Public key size: $pubSize\n";
				if ($pubSize < 1024) {
					push(@olines, "      *** PUBLIC KEY TOO SHORT ***");
				}
			}
			if (/Not After : (.*)$/) {
				$notAfter = $1;
				$days = (str2time($notAfter)-time())/86400.0;
				if ($days < 0) {
					push(@olines, "   *** EXPIRED ***");
				} elsif ($days < 30) {
					$days = int($days);
					push(@olines, "   *** expires in $days days");
				} elsif ($days < 90) {
					$days = int($days);
					push(@olines, "   expires in $days days");
				}
			}

			#
			# Check for weak (Debian) keys
			#
			# Weak key fingerprints loaded from files are hex SHA-1 digests of the
			# line you get from "openssl x509 -modulus", including the "Modulus=".
			#
			if (/^Modulus=(.*)$/) {
				$modulus = $_;
				# print "   modulus: $modulus\n";
				$fpr = sha1_hex($modulus);
				# print "   fpr: $fpr\n";
				if ($pubSize == 1024) {
					if (defined($rsa1024{$fpr})) {
						push(@olines, "   *** WEAK DEBIAN KEY ***");
					}
				} elsif ($pubSize == 2048) {
					if (defined($rsa2048{$fpr})) {
						push(@olines, "   *** WEAK DEBIAN KEY ***");
					}
				}
			}
			
		}
		close SSL;
		#print "   text lines: $#lines\n";

		#
		# Check KeyName if one has been supplied.
		#
		if ($hasKeyName && $keyname ne $subjectCN) {
			push(@olines, "   *** KeyName mismatch: $keyname != $subjectCN");
		}
		
		#
		# Use openssl to ask whether this matches our trust fabric or not.
		#
		my $error = '';
		$serverOK = 1;
		$cmd = "openssl verify -CAfile authorities.pem -purpose sslserver $filename |";
		open(SSL, $cmd) || die "could not open openssl subcommand 2";
		while (<SSL>) {
			chomp;
			if (/error/) {
				$error = $_;
				$serverOK = 0;
			}
		}
		close SSL;
		$clientOK = 1;
		$cmd = "openssl verify -CAfile authorities.pem -purpose sslclient $filename |";
		open(SSL, $cmd) || die "could not open openssl subcommand 3";
		while (<SSL>) {
			chomp;
			if (/error/) {
				$error = $_;
				$clientOK = 0;
			}
		}
		close SSL;
		
		#
		# Irrespective of what went wrong, client and server results should match.
		#
		if ($clientOK != $serverOK) {
			push(@olines, "   *** client/server purpose result mismatch: $clientOK != $serverOK");
		}
		
		#
		# Reduce error if possible.
		#
		if ($error =~ m/^error \d+ at \d+ depth lookup:\s*(.*)$/) {
			$error = $1;
		}
		
		#
		# Now, adjust for our expectations.
		#
		# Pretty much any certificate is fine if we don't have a KeyName.
		#
		if (!$hasKeyName) {
			if ($error eq 'self signed certificate') {
				$error = '';
				push(@olines, "   (self signed certificate)");
			} elsif ($error eq 'unable to get local issuer certificate') {
				$error = '';
				push(@olines, "   (unknown issuer: $issuerCN)");
			}
		}

		if ($hasKeyName && $error eq 'self signed certificate') {
			$error = 'self signed certificate: remove KeyName?';
		}

		if ($error eq 'unable to get local issuer certificate') {
			$error = "unknown issuer: $issuerCN";
		}

		if ($error ne '') {
			push(@olines, "   *** $error");
		}
		
		#
		# Close the temporary file, which will also cause
		# it to be deleted.
		#
		close $fh;

		#
		# Print any interesting things related to this certificate.
		#
		if (@olines > 1) {
			foreach $oline (@olines) {
				print $oline, "\n";
			}
			print "\n";
		}
	}
}