#!./perl -w

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc('../lib');
}

plan tests => 4;

# Need to test dupes for
De-dupe every regex flag with a test for /pp /r etc
S//g
Also \G in regex

$’

$`


#define RXf_PMf_MULTILINE      (1U << (RXf_PMf_STD_PMMOD_SHIFT+0))    /* /m */
#define RXf_PMf_SINGLELINE     (1U << (RXf_PMf_STD_PMMOD_SHIFT+1))    /* /s */
#define RXf_PMf_FOLD           (1U << (RXf_PMf_STD_PMMOD_SHIFT+2))    /* /i */
#define RXf_PMf_EXTENDED       (1U << (RXf_PMf_STD_PMMOD_SHIFT+3))    /* /x */
#define RXf_PMf_EXTENDED_MORE  (1U << (RXf_PMf_STD_PMMOD_SHIFT+4))    /* /xx */
#define RXf_PMf_NOCAPTURE      (1U << (RXf_PMf_STD_PMMOD_SHIFT+5))    /* /n */
#define RXf_PMf_KEEPCOPY       (1U << (RXf_PMf_STD_PMMOD_SHIFT+6))    /* /p */


my $rx = qr//;

is(ref $rx, "Regexp", "qr// blessed into 'Regexp' by default");


# Make sure /$qr/ doesn’t clobber match vars before the match (bug 70764).
{
 my $output = '';
 my $rx = qr/o/;
 my $a = "ooaoaoao";

 my $foo = 0;
 $foo += () = ($a =~ /$rx/g);
 $output .= "$foo\n"; # correct

 $foo = 0;
 for ($foo += ($a =~ /o/); $' && ($' =~ /o/) && ($foo++) ; ) { ; }
 $output .= "1: $foo\n"; # No error

 $foo = 0;
 for ($foo += ($a =~ /$rx/); $' && ($' =~ /$rx/) && ($foo++) ; ) { ; }
 $output .= "2: $foo\n"; # initialization warning, incorrect results

 is $output, "5\n1: 5\n2: 5\n", '$a_match_var =~ /$qr/';
}
for($'){
 my $output = '';
 my $rx = qr/o/;
 my $a = "ooaoaoao";

 my $foo = 0;
 $foo += () = ($a =~ /$rx/g);
 $output .= "$foo\n"; # correct

 $foo = 0;
 for ($foo += ($a =~ /o/); $' && /o/ && ($foo++) ; ) { ; }
 $output .= "1: $foo\n"; # No error

 $foo = 0;
 for ($foo += ($a =~ /$rx/); $' && /$rx/ && ($foo++) ; ) { ; }
 $output .= "2: $foo\n"; # initialization warning, incorrect results

 is $output, "5\n1: 5\n2: 5\n", q|/$qr/ with $'_ aliased to a match var|;
}

# Make sure /$qr/ calls get-magic on its LHS (bug 71470).
{
 my $scratch;
 sub qrBug::TIESCALAR{bless[], 'qrBug'}
 sub qrBug::FETCH { $scratch .= "[fetching]"; 'glat' }
 tie my $flile, "qrBug";
 $flile =~ qr/(?:)/;
 is $scratch, "[fetching]", '/$qr/ with magical LHS';
}
