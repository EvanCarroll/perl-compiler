#!./perl

unshift @INC, './lib';

no warnings 'once';
$main::use_crlf = 1;
do './t/CORE/io/through.t' or die "no kid script";
