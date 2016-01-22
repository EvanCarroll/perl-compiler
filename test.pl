#!./perl

sub like ($$@)   { like_yn( 0, @_ ) }
sub unlike ($$@) { like_yn( 1, @_ ) };    # no segfault if commented

sub like_yn {
    return re::is_regexp(123);            # no segfault if commented
}

sub run_multiple_progs {
    my $results = q{};
    $results =~ s/^(syntax|parse) error/syntax error/mig;    # no segfault if commented
}

{
    eval 'use Scalar::Util "dualvar";';                      # no segfault if commented
}

print "ok\n";
