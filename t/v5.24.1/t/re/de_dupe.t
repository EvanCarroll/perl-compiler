#!./perl -w

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc('../lib');
}

plan tests => 12;

{
	note q{Testing $` $'};
	my $dog = 'happygreendogcow';
	$dog =~ m{dog}g;
	my $pos = pos($dog);

	is($`,'happygreen', "Match before ok");
	is($','cow', "Match after ok");
	is($pos,13,"The position is 13");

	$dog =~ m{dog}g;
	$pos = pos($dog);

	is($`,'happygreen', "Match before ok (2x)");
	is($','cow', "Match after ok (2x)");
	is($pos,13,"The position is 13 (2x)");


	$dog = 'happybluedogfrog';
	$dog =~ m{dog}g;
	$pos = pos($dog);

	is($`,'happyblue', "Match before ok (changed)");
	is($','frog', "Match after ok (changed)");
	is($pos,12,"The position is 12 (changed)");


	$dog = 'happybluedogfrog';
	$dog =~ m{dog}g;
	$pos = pos($dog);

	is($`,'happyblue', "Match before ok (changed 2x)");
	is($','frog', "Match after ok (changed 2x)");
	is($pos,12,"The position is 12 (changed 2x)");
}

# Need to test dupes for

#De-dupe every regex flag with a test for /pp /r etc
#S//g
#Also \G in regex




#define RXf_PMf_MULTILINE      (1U << (RXf_PMf_STD_PMMOD_SHIFT+0))    /* /m */
#define RXf_PMf_SINGLELINE     (1U << (RXf_PMf_STD_PMMOD_SHIFT+1))    /* /s */
#define RXf_PMf_FOLD           (1U << (RXf_PMf_STD_PMMOD_SHIFT+2))    /* /i */
#define RXf_PMf_EXTENDED       (1U << (RXf_PMf_STD_PMMOD_SHIFT+3))    /* /x */
#define RXf_PMf_EXTENDED_MORE  (1U << (RXf_PMf_STD_PMMOD_SHIFT+4))    /* /xx */
#define RXf_PMf_NOCAPTURE      (1U << (RXf_PMf_STD_PMMOD_SHIFT+5))    /* /n */
#define RXf_PMf_KEEPCOPY       (1U << (RXf_PMf_STD_PMMOD_SHIFT+6))    /* /p */

