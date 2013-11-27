#!./perl

BEGIN {
	unshift @INC, './lib';
	require 't/CORE/test.pl';
}

no warnings 'once';
$main::use_crlf = 1;

my $script = './io/through.t';

die "No script: $script" unless -f $script;
do './io/through.t' or die "no kid script";
