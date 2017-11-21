#!perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Subtest;

use Capture::Tiny ':all';

use File::Temp;

my $tmp = File::Temp->newdir( "BC-POSIX-constant-test-XXXXXXX", TMPDIR => 1, DIR => $ENV{HOME}, CLEANUP => 1 );
my $dir = $tmp->dirname;

ok chdir($dir), "chdir";    # note: bc do not support full path in -o file...

my $perlcc = $^X . q{cc};   # perlcc
note "Using perlcc: ", $perlcc;
die "cannot find bc binary" unless -x $perlcc;

my $oneliner = q[use POSIX;  BEGIN { MB_CUR_MAX() } POSIX->import; print MB_CUR_MAX()];

my ( $stdout, $stderr );

my %backup_ENV = %ENV;

{
    ( $stdout, $stderr ) = capture \&run_uncompiled;
    is [ $stdout, $stderr ], [ 6, '' ],  "MB_CUR_MAX = 6 uncompiled";

    my $binary = compile_oneliner_to();
    ( $stdout, $stderr ) = capture sub { system "./$binary" };
    is [ $stdout, $stderr ], [ 6, '' ], "same output when running the compiled version";
}

ok chdir('/tmp'), 'chdir /tmp';    # require to purge the tmp directory

done_testing();
exit;

sub compile_oneliner_to {
    my $out = shift // 'a.out';

    note "compiling $out...";
    local %ENV = %backup_ENV;

    unlink $out if -e $out;    # protection
    ok !-e $out, "binary not available";
    my $status;
    note qq[$perlcc -o$out -e '$oneliner'];
    my ( $stdout, $stderr, $exit ) = capture { system qq[$perlcc -o$out -e '$oneliner']; $status = $? };
    is $status, 0, "perlcc compiled $out";
    ok -x $out, "compiled binary $out is available";

    return $out;
}

sub run_uncompiled {
    system qq{$^X -e '$oneliner'};
}
