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
	ok($string =~ m{\nbob}s, "String matches RXf_PMf_SINGLELINE");
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

	
}



{
	# test RXf_PMf_EXTENDED_MORE /xx

	
}

{
	# test RXf_PMf_NOCAPTURE /n

	
}


{
	# test RXf_PMf_KEEPCOPY /p

	
}

# Need to test dupes for

#s//g
#Also \G in regex
