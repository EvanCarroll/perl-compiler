#!perl

use strict;
use warnings;

use TAP::Harness ();
use IO::Scalar;

use Test::More;

#my @optimizations = ( '-O3,-fno-fold', '-O1' );
my @optimizations = ( '-O3,-fno-fold');
my $todo = '';

# Setup file_to_test to be the file we actually want to test.
my $file_to_test = $0;
if ( $file_to_test =~ s{==(.*)\.t$}{.t} ) {
    my $options = $1;
    $todo = "Compiled binary segfaults. Issues: $1"             if ( $options =~ /SEGV-([\d-]+)/ );
    $todo = "Fails to compile with perlcc. Issues: $1"          if ( $options =~ /NOCOMPILE-([\d-]+)/ );
    $todo = "Fails tests when compiled with perlcc. Issues: $1" if ( $options =~ /BADTEST-([\d-]+)/ );
}

$file_to_test =~ s{--}{/}g;
$file_to_test =~ s{C-COMPILED/}{};    # Strip the BINARY dir off to look for this test elsewhere.

if ( $] != '5.014004' && $file_to_test =~ m{^t/CORE/} ) {
    plan skip_all => "Perl CORE tests only supported in 5.14.4 right now.";
}
else {
    plan tests => 3 + 8 * scalar @optimizations;
}

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

my $check = `$PERL -c $taint '$file_to_test' 2>&1`;
like( $check, qr/syntax OK/, "$PERL -c $taint $file_to_test" );

$ENV{HARNESS_NOTTY} = 1;

foreach my $optimization (@optimizations) {
  TODO: SKIP: {
        local $TODO = "Tests don't pass at the moment - $todo" if ( $todo =~ /Fails to compile/ );

        # Generate the C code at $optimization level
        my $cmd = "$PERL $taint -MO=-qq,C,$optimization,-o$c_file $file_to_test 2>&1";

        #diag $cmd;
        my $BC_output = `$cmd`;
        diag $BC_output if ($BC_output);
        ok( !-z $c_file, "$c_file is generated ($optimization)" );

        if ( -z $c_file ) {
            unlink $c_file;
            skip( "Can't test further due to failure to create a c file.", 7 );
        }

        # gcc the c code.
        my $compile_output = `$PERL script/cc_harness -q $c_file -o $bin_file 2>&1`;
        diag $compile_output if ($compile_output);

        # Validate compiles
        ok( -x $bin_file, "$bin_file is compiled and ready to run." );

        if ( !-x $bin_file ) {
            unlink $c_file, $bin_file;
            skip( "Can't test further due to failure to create a binary file.", 6 );
        }

        # Parse through TAP::Harness
        my $out    = '';
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

        local $TODO = "Tests don't pass at the moment - $todo" if ( $todo =~ /Compiled binary segfaults/ );

        my $parser = $res->{parser_for}->{$bin_file};
        ok( $parser,                 "Output parsed by TAP::Harness" );
        ok( $parser->{is_good_plan}, "Plan was valid" );

        local $TODO = "Tests don't pass at the moment - $todo" if ( $todo =~ /Fails tests when compiled with perlcc/ );
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
    }
}
