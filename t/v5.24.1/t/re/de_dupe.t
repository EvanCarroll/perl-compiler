#!./perl -w

BEGIN {
 #   chdir 't' if -d 't';
 #   require './test.pl';
 #   set_up_inc('../lib');
}

use Test::More;
plan tests => 12;

{
	note q{Testing $` $'};
	my $dog = 'happygreendogcow';
	ok($dog =~ m{dog}g,"Match once with /g");
	my $pos = pos($dog);

	is($`,'happygreen', "Match before ok");
	is($','cow', "Match after ok");
	is($pos,13,"The position is 13");

	ok($dog !~ m{dog}g,"No match once we matched once with /g");
	$pos = pos($dog);

	is($`,'happygreen', "Match before ok (2x)");
	is($','cow', "Match after ok (2x)");
	is($pos,undef,"The position undef since we already matched");


	$dog = 'happybluedogfrog';
	ok($dog =~ m{dog}g,"Match once with /g");
	$pos = pos($dog);

	is($`,'happyblue', "Match before ok (changed)");
	is($','frog', "Match after ok (changed)");
	is($pos,12,"The position is 12 (changed)");


	$dog = 'happybluedogfrog';
	ok($dog =~ m{dog}g,"Match once with /g");
	$pos = pos($dog);

	is($`,'happyblue', "Match before ok (changed 2x)");
	is($','frog', "Match after ok (changed 2x)");
	is($pos,12,"The position is 12 (changed 2x)");
}

{
	# test RXf_PMf_MULTILINE

	my $string = "bob\ncow\nfrog\ndog\n";

	ok($string =~ m{^cow}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^bob}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^cow}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^bob}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^bob}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^dog}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^dog}m, "String matches RXf_PMf_MULTILINE");
	ok($string =~ m{^dog}m, "String matches RXf_PMf_MULTILINE");
}

{
	# test RXf_PMf_SINGLELINE

	my $string = "bob\ncow\nfrog\ndog\n";

	ok($string =~ m{\ncow}s, "String matches RXf_PMf_SINGLELINE");
	ok($string !~ m{\nbob}s, "String matches RXf_PMf_SINGLELINE");
	ok($string =~ m{\ncow}s, "String matches RXf_PMf_SINGLELINE");
	ok($string =~ m{^bob}s, "String matches RXf_PMf_SINGLELINE");
	ok($string =~ m{^bob}s, "String matches RXf_PMf_SINGLELINE");
	ok($string =~ m{\ndog}s, "String matches RXf_PMf_SINGLELINE");
	ok($string =~ m{\ndog}s, "String matches RXf_PMf_SINGLELINE");
	ok($string =~ m{\ndog}s, "String matches RXf_PMf_SINGLELINE");
}


{
	# test RXf_PMf_OLDF

	my $string = "BOBFROGcowDOG";

	ok($string =~ m{cow}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{bob}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{cow}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{bob}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{bob}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{dog}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{dog}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{dog}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{frog}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{frog}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{frogcow}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{FROG}i, "String matches with RXf_PMf_OLDF");
	ok($string =~ m{FROG}i, "String matches with RXf_PMf_OLDF");
}

{
	# test RXf_PMf_EXTENDED /x
	my $program = <<EOM;
dog /* cow */
frog /* pig */
EOM

	$program =~ s {
		/\*	# Match the opening delimiter.
		.*?	# Match a minimal number of characters.
		\*/	# Match the closing delimiter.
        } []gsx;
is($program,"dog \nfrog \n", "The regex strips the comments from the program RXf_PMf_EXTENDED");

	$program = <<EOM;
cow /* frog */
frog /* pig */
EOM
    $program =~ s {
		/\*	# Match the opening delimiter.
		.*?	# Match a minimal number of characters.
		\*/	# Match the closing delimiter.
        } []gsx;
is($program,"cow \nfrog \n", "The regex strips the comments from the program RXf_PMf_EXTENDED");

	$program = <<EOM;
cow /* frog */
cow /* pig */
EOM

    $program =~ s {
		/\*	# Match the opening delimiter.
		.*?	# Match a minimal number of characters.
		\*/	# Match the closing delimiter.
        } []gsx;
is($program,"cow \ncow \n", "The regex strips the comments from the program RXf_PMf_EXTENDED");

	$program = <<EOM;
cow /* frog */
cow /* pig */
EOM

    $program =~ s {
		/\*	# Match the opening delimiter.
		.*?	# Match a minimal number of characters.
		\*/	# Match the closing delimiter.
        } []gsx;
is($program,"cow \ncow \n", "The regex strips the comments from the program RXf_PMf_EXTENDED");


}



{
	# test RXf_PMf_EXTENDED_MORE /xx

	my $string = "#######";

	ok($string =~ /[ ! @ " # $ % ^ & * () = ? <> ' ]/x, "String matches with RXf_PMf_EXTENDED_MORE");
	ok($string =~ /[ ! @ " # $ % ^ & * () = ? <> ' ]/x, "String matches with RXf_PMf_EXTENDED_MORE");
	ok($string =~ /[ ! @ " # $ % ^ & * () = ? <> ' ]/x, "String matches with RXf_PMf_EXTENDED_MORE");
	ok($string =~ /[ ! @ " # $ % ^ & * () = ? <> ' ]/x, "String matches with RXf_PMf_EXTENDED_MORE");

}
{
	# test RXf_PMf_NOCAPTURE /n
	my $string = "bobfrogcowdog";

	ok($string =~ m{cow}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{bob}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{cow}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{bob}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{bob}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{dog}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{dog}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{dog}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{frog}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{frog}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{frogcow}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{frog}n, "String matches with RXf_PMf_NOCAPTURE");
	ok($string =~ m{frog}n, "String matches with RXf_PMf_NOCAPTURE");
	
}


{
	# test RXf_PMf_KEEPCOPY /p
	my $string = "bobfrogcowdog";

	ok($string =~ m{cow}p, "String matches with RXf_PMf_KEEPCOPY");
	is(${^PREMATCH},'bobfrog', "PREMATCH SET");
	is(${^MATCH},'cow',"MATCH SET");
	is(${^POSTMATCH},'dog',"MATCH SET");


	ok($string =~ m{bob}p, "String matches with RXf_PMf_KEEPCOPY");

	is(${^PREMATCH},'', "PREMATCH SET");
	is(${^MATCH},'bob',"MATCH SET");
	is(${^POSTMATCH},'frogcowdog',"MATCH SET");

	ok($string =~ m{cow}p, "String matches with RXf_PMf_KEEPCOPY");
	is(${^PREMATCH},'bobfrog', "PREMATCH SET");
	is(${^MATCH},'cow',"MATCH SET");
	is(${^POSTMATCH},'dog',"MATCH SET");

	ok($string =~ m{bob}p, "String matches with RXf_PMf_KEEPCOPY");
		is(${^PREMATCH},'', "PREMATCH SET");
	is(${^MATCH},'bob',"MATCH SET");
	is(${^POSTMATCH},'frogcowdog',"MATCH SET");
	ok($string =~ m{bob}p, "String matches with RXf_PMf_KEEPCOPY");
		is(${^PREMATCH},'', "PREMATCH SET");
	is(${^MATCH},'bob',"MATCH SET");
	is(${^POSTMATCH},'frogcowdog',"MATCH SET");

	ok($string =~ m{dog}p, "String matches with RXf_PMf_KEEPCOPY");
	is(${^PREMATCH},'bobfrogcow', "PREMATCH SET");
	is(${^MATCH},'dog',"MATCH SET");
	is(${^POSTMATCH},'',"MATCH SET");

	ok($string =~ m{dog}p, "String matches with RXf_PMf_KEEPCOPY");
		is(${^PREMATCH},'bobfrogcow', "PREMATCH SET");
	is(${^MATCH},'dog',"MATCH SET");
	is(${^POSTMATCH},'',"MATCH SET");
	ok($string =~ m{dog}p, "String matches with RXf_PMf_KEEPCOPY");
		is(${^PREMATCH},'bobfrogcow', "PREMATCH SET");
	is(${^MATCH},'dog',"MATCH SET");
	is(${^POSTMATCH},'',"MATCH SET");
	ok($string =~ m{frog}p, "String matches with RXf_PMf_KEEPCOPY");

	is(${^PREMATCH},'bob', "PREMATCH SET");
	is(${^MATCH},'frog',"MATCH SET");
	is(${^POSTMATCH},'cowdog',"MATCH SET");

	ok($string =~ m{frog}p, "String matches with RXf_PMf_KEEPCOPY");

	is(${^PREMATCH},'bob', "PREMATCH SET");
	is(${^MATCH},'frog',"MATCH SET");
	is(${^POSTMATCH},'cowdog',"MATCH SET");

	ok($string =~ m{frogcow}p, "String matches with RXf_PMf_KEEPCOPY");

	is(${^PREMATCH},'bob', "PREMATCH SET");
	is(${^MATCH},'frogcow',"MATCH SET");
	is(${^POSTMATCH},'dog',"MATCH SET");
	ok($string =~ m{frog}p, "String matches with RXf_PMf_KEEPCOPY");

	is(${^PREMATCH},'bob', "PREMATCH SET");
	is(${^MATCH},'frog',"MATCH SET");
	is(${^POSTMATCH},'cowdog',"MATCH SET");
	ok($string =~ m{frog}p, "String matches with RXf_PMf_KEEPCOPY");

	is(${^PREMATCH},'bob', "PREMATCH SET");
	is(${^MATCH},'frog',"MATCH SET");
	is(${^POSTMATCH},'cowdog',"MATCH SET");
	
}

# Need to test dupes for

#s//g
#Also \G in regex
