#!perl

use strict;
use warnings;

use TAP::Harness ();

#use Time::HiRes qw/sleep gettimeofday tv_interval/;
use Test::More tests => 11;

my $file_to_test = $0;
$file_to_test =~ s{BINARY/}{}g;    # Strip the BINARY dir off to look for this test elsewhere.
$file_to_test =~ s{--}{/}g;

ok( !-z $file_to_test, "$file_to_test exists" );

open( my $fh, '<', $file_to_test ) or die("Can't open $file_to_test");
my $taint = <$fh>;
close $fh;
$taint = ( ( $taint =~ m/\s\-T/ ) ? '-T' : '' );
pass( $taint ? "Taint mode!" : "Not in taint mode" );

( my $c_file   = $file_to_test ) =~ s/\.t$/.c/;
( my $bin_file = $file_to_test ) =~ s/\.t$/.bin/;
unlink $bin_file, $c_file;

my $PERL = $^X;

my $cmd = "$PERL $taint -MO=-qq,C,-O3,-fno-fold,-o$c_file $file_to_test 2>&1";

#diag $cmd;
my $BC_output = `$cmd`;
diag $BC_output if ($BC_output);
ok( -e $c_file,  "$c_file created" );
ok( !-z $c_file, "$c_file isn't empty" )
  or do {
    unlink $c_file;
    die("Can't proceed without a c file to compile");
  };

my $compile_output = `$PERL script/cc_harness -q $c_file -o $bin_file 2>&1`;
diag $compile_output if ($compile_output);

ok( -x $bin_file, "$bin_file is compiled and ready to run." );

$ENV{HARNESS_NOTTY} = 1;

my $out = '';
use IO::Scalar;
my $out_fh = new IO::Scalar \$out;

my %args = (
    verbosity => 1,
    lib       => [],
    merge     => 1,
    stdout    => $out_fh,
);
my $harness = TAP::Harness->new( \%args );
my $res     = $harness->runtests($bin_file);
close $out_fh;

my $parser = $res->{parser_for}->{$bin_file};
ok( $parser,                        "Output parsed by TAP::Harness" );
ok( $parser->{is_good_plan},        "Plan was valid" );
ok( $parser->{exit} == 0,           "Exit code is $parser->{exit}" );
ok( !scalar @{ $parser->{failed} }, "Test results:" );
foreach my $line ( split( "\n", $out ) ) {
    print "    $line\n";
}
ok( !scalar @{ $parser->{failed} }, "No test failures" )
  or diag( "Failed tests: " . join( ", ", @{ $parser->{failed} } ) );
ok( !scalar @{ $parser->{todo_passed} }, "No TODO tests passed" )
  or diag( "TODO Passed: " . join( ", ", @{ $parser->{todo_passed} } ) );

unlink $bin_file, $c_file;
