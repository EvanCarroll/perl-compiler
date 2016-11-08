package B::C::Packages;

# Maintains the state of the optimized perl program we're parsing
# unused (0) - Tracks packages we've determined should not be compiled in.
# used   (1) - Tracks packages we've identified need to be here?
# deleted / unknown? (undef) - default state also

use Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw/mark_package_removed mark_package_unused mark_package_used mark_package_deleted is_package_used get_all_packages_used include_package_list/;

our %include_package;

sub new {
    my $inc = $B::C::settings->{'starting_INC'};
    #%B::C::curINC = %INC;
    %B::C::curINC = %$inc;
    %B::C::savINC = %$inc;#%INC;
}

sub mark_package_unused {
    return _mark_package( $_[0], 0 );
}

sub mark_package_used {
    return _mark_package( $_[0], 1 );
}

# TODO: check if we can merge delete and remove
sub mark_package_deleted {
    return _mark_package( $_[0], undef );
}

sub mark_package_removed {
    delete $include_package{ $_[0] };
    return;
}

# todo: should rename it to avoid confusion
#	need to check if this cannot be merged
sub _mark_package {
    my ( $pkg, $val ) = @_;

    # if ( !$val ) {
    #     print STDERR "DISABLE: $pkg => $val\n";
    # }
    #return unless $val;
    #print STDERR "MARK: $pkg => $val\n";
    #if ( $val ne B::C::package_was_compiled_in($pkg) ) {
    #    print STDERR "XXX: sub_was_compiled_in($pkg) = " . B::C::package_was_compiled_in($pkg) . " / $val\n";    
    #    print STDERR 'B::C::Save'->can('_caller_comment')->();
    #}
    
    $include_package{$pkg} = $val or B::C::package_was_compiled_in($pkg);

    return 1;
}

# better name ? include_package
sub is_package_used {
    my $pkg = shift;
    return unless defined $pkg;
    
    return $include_package{$pkg};# && B::C::package_was_compiled_in($pkg);
}

sub get_all_packages_used {
    return grep( $include_package{$_}, sort keys %include_package );
}

sub include_package_list {
    return sort keys %include_package;
}

1;
