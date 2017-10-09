#!./perl

package MyPackage;

sub mysub {
    return 42;
}

sub foo {
    return 'bar';
}

1;

package B::C::Custom;

sub skip_subs_from_package {
    return {
        'MyPackage' => [qw(mysub)],
    };
}

1;

package main;

print "1..2\n";

sub f {
    my $sub = 'MyPackage'->can('mysub');
    return $sub ? $sub->() : 0;
}

if ( is_compiled() ) {
    print "ok 1 - MyPackage::mysub is not compiled\n" if f() == 0;
}
else {
    print "ok 1 - f() == 42 - uncompileed\n" if f() == 42;
}

print "ok 2 - foo() eq bar - uncompileed\n" if MyPackage::foo() eq 'bar';

sub is_compiled {
    return $0 =~ qr{\.bin$} ? 1 : 0;
}

1;
