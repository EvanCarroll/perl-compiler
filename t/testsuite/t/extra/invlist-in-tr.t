#!perl

print "1..1\n";
q[ABCDE] !~ tr/\0-\377//c and print qq[ok 1\n];