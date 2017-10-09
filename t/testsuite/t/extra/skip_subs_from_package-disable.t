#!./perl

package MyPackage;

sub mysub {
	return 42;
}

sub foo {
	return 'bar'
}

1;

package main;

print "1..2\n";

sub f {
	my $sub = 'MyPackage'->can('mysub');
	return $sub ? $sub->() : 0;
}

print "ok 1 - f() == 42 - uncompileed\n" if f() == 42;
print "ok 2 - foo() eq bar - uncompileed\n" if MyPackage::foo() eq 'bar';

1;