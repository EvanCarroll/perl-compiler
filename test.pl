#!/bin/env perl
my ( $h1, $h2 );
BEGIN {
	$h1 = {
		apple  => 42,
		banana => 51,
		cherry => 60,
	};
	$h2 = {
		lemon  => 41232,
		banana => 51231,
		pear   => 61230,
	};
}

foreach my $h ( $h1, $h2 ) {
	print "Ref: ".ref($h) . "\n";
	print "Scalar: ". scalar(%$h) . "\n";
	print "Keys: " . join( ", ", sort keys(%$h)) . "\n";	
	print "Values: " . join( ", ", sort values(%$h)) . "\n";	
	print "-"x10; print "\n";
}
print "#"x20; print "\n";