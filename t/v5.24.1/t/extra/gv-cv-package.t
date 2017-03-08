package MyPackage;

sub ok { "ok 1 - using MyPackage::ok\n" if -e q{/} }

package main;
print "1..1\n";
print MyPackage::ok();
