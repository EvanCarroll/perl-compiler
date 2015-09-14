#!./perl -w

BEGIN {
    chdir 't' if -d 't';
    push @INC, "t/CORE/lib";
    require 'test.pl';
}

plan tests => 1;

ok(defined [(1)x127,qr//,1]->[127], "qr// should extend the stack properly");
