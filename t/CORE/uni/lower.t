BEGIN {
    chdir 't' if -d 't';
    push @INC, qw{t/CORE/lib t/CORE/uni}
    require "case.pl";
}

casetest(0, # No extra tests run here,
	"Lowercase_Mapping",
	 sub { lc $_[0] }, sub { my $a = ""; lc ($_[0] . $a) },
	 sub { lcfirst $_[0] }, sub { my $a = ""; lcfirst ($_[0] . $a) });
