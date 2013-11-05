# -*- cperl -*-
# t/testcore.t - run the core testsuite with the compilers B::C ONLY
# Usage:
#   t/testcore.t -fail             known failing tests only
#   t/testcore.t -c                run C compiler tests only (also -bc or -cc)
#   t/testcore.t t/CORE/op/goto.t  run this test only
#
# Prereq:
# Copy your matching CORE t dirs into t/CORE.
# For now we test qw(base comp lib op run)
# Then fixup the @INC setters, and various require ./test.pl calls.
#
#   perl -pi -e 's/^(\s*\@INC = )/# $1/' t/CORE/*/*.t
#   perl -pi -e "s|^(\s*)chdir 't' if -d|\$1chdir 't/CORE' if -d|" t/CORE/*/*.t
#   perl -pi -e "s|require './|use lib "CORE"; require '|" `grep -l "require './" t/CORE/*/*.t`
#
# See TESTS for recent results


use Cwd;
use File::Copy;

print "1..0 #skip t/CORE missing. Read t/testcore.t how to setup.\n";
unshift @INC, ("t");

require "test.pl";

sub vcmd {
  my $cmd = join "", @_;
  print "#",$cmd,"\n";
  return run_cmd($cmd, 120); # timeout 2min
}

my $dir = getcwd();

unlink ("t/perl", "t/CORE/perl");
#symlink "t/perl", $^X;
#symlink "t/CORE/perl", $^X;
#symlink "t/CORE/test.pl", "t/test.pl" unless -e "t/CORE/test.pl";
#symlink "t/CORE/harness", "t/test.pl" unless -e "t/CORE/harness";
`ln -sf $^X t/perl`;
`ln -sf $^X t/CORE/perl`;
# CORE t/test.pl would be better, but this fails only on 2 tests
#-e "t/CORE/test.pl" or `ln -sf t/test.pl t/CORE/test.pl`;
#-e "t/CORE/harness" or `ln -s t/test.pl t/CORE/harness`; # better than nothing
#`ln -s t/test.pl harness`; # base/term
#`ln -s t/test.pl TEST`;  # cmd/mod 8

my %ALLOW_PERL_OPTIONS;
for (qw(
        comp/cpp.t
        run/runenv.t
       )) {
  $ALLOW_PERL_OPTIONS{"t/CORE/$_"} = 1;
}

my @fail = map { "t/CORE/$_" }
  qw{};

my @tests = $ARGV[0] eq '-fail'
  ? @fail
  : ((@ARGV and $ARGV[0] !~ /^-/)
     ? @ARGV
     : <t/CORE/*/*.t>);
shift if $ARGV[0] eq '-fail';
my $Mblib = $^O eq 'MSWin32' ? '-Iblib\arch -Iblib\lib' : "-Iblib/arch -Iblib/lib";

sub run_c {
  my ($t, $backend) = @_;
  chdir $dir;
  my $result = $t; $result =~ s/\.t$/-c.result/;
  my $a = $backend eq 'C' ? 'a' : 'aa';
  $result =~ s/-c.result$/-cc.result/ if $backend eq 'CC';
  unlink ($a, "$a.c", "t/$a.c", "t/CORE/$a.c", $result);
  # perlcc 2.06 should now work also: omit unneeded B::Stash -u<> and fixed linking
  # see t/c_argv.t
  my $backopts = $backend eq 'C' ? "-qq,C,-O2" : "-qq,CC";
  $backopts .= ",-fno-warnings" if $backend =~ /^C/ and $] >= 5.013005;
  $backopts .= ",-fno-fold"     if $backend =~ /^C/ and $] >= 5.013009;

  vcmd "$^X $Mblib -MO=$backopts,-o$a.c $t";
  # CORE often does BEGIN chdir "t", patched to chdir "t/CORE"
  chdir $dir;
  move ("t/$a.c", "$a.c") if -e "t/$a.c";
  move ("t/CORE/$a.c", "$a.c") if -e "t/CORE/$a.c";
  my $d = "";
  $d = "-DALLOW_PERL_OPTIONS" if $ALLOW_PERL_OPTIONS{$t};
  vcmd "$^X $Mblib script/cc_harness -q $d $a.c -o $a" if -e "$a.c";
  my $ok = 1;
  if ( -e "$a" ) {
    my ( $result, $out, $err ) = vcmd "./$a | tee $result";  
    $ok = 0 if $out =~ m{^\s+Failed tests:\s+}im;
    $ok = 0 if $out =~ m{^not\s+ok\s+}im;
  }  
  $ok &&= prove ($a, $result, $i, $t, $backend);
  $i++;
  return $ok;
}

sub prove {
  my ($a, $result, $i, $t, $backend) = @_;
  if ( -e "$a" and -s $result) {
    system(qq[prove -Q --exec cat $result || echo -n "n";echo "ok $i - $backend $t"]);
  } else {
    print "not ok $i - $backend $t\n";
    return 0;
  }
  return 1;
}

{
  system 'mkdir', 'locks' unless -d 'locks'; 
  # skip tests flags as working in a previous run
  @tests = map {
    my $lock = get_lock_for_test($_);
    -e $lock ? () : $_ 
   } @tests;
}

my @runtests = qw(C CC BC);
if ($ARGV[0] and $ARGV[0] =~ /^-(c|cc|bc)$/i) {
  @runtests = ( uc(substr($ARGV[0],1) ) );
}
my $numtests = scalar @tests * scalar @runtests;
my %runtests = map {$_ => 1} @runtests;

print "1..", $numtests, "\n";
my $i = 1;

my $add_lock = grep { m/-add-?lock/ } @ARGV;

for my $t (@tests) {
    next if $t =~ m/^-/;
    if ($runtests{C}) {
        (print "ok $i #skip $SKIP->{C}->{$t}\n" and next)
        if exists $SKIP->{C}->{$t};
        my $ok = run_c($t, "C");
        system 'touch', get_lock_for_test($t) if $add_lock && $ok;
    }
}

sub get_lock_for_test {
  my $test = shift;
  $test =~ s{/}{-}g;
  $test =~ s{\s+}{-}g;
  $test =~ s{--+}{-}g;

  return 'locks/'.$test;
}

END {
  unless ( grep { m/-noclean/ } @ARGV ) {
    unlink ( "t/perl", "t/CORE/perl", "harness", "TEST" );
    unlink ("a","a.c","t/a.c","t/CORE/a.c","aa.c","aa","t/aa.c","t/CORE/aa.c","b.plc");
  }
}
