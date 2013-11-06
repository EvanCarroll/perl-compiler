#!perl -w

# Tests if $$ and getppid return consistent values across threads

BEGIN {
    chdir 't/CORE' if -d 't';
    unshift @INC, "./lib";
    require './test.pl';
}

use strict;
use Config;

BEGIN {
    eval 'use threads; use threads::shared';
    plan tests => 3;
    if ($@) {
	fail("unable to load thread modules");
    }
    else {
	pass("thread modules loaded");
    }
}

my ($pid, $ppid) = ($$, getppid());
my $pid2 : shared = 0;
my $ppid2 : shared = 0;

new threads( sub { ($pid2, $ppid2) = ($$, getppid()); } ) -> join();

is($pid,  $pid2,  'pids');
is($ppid, $ppid2, 'ppids');
