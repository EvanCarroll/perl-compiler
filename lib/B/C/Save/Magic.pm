package B::C::Save::Magic;

use strict;

use B::C::File qw/init_vtables/;

#use B::C::File qw(sharedhe sharedhestructs);
#use B::C::Helpers qw/strlen_flags/;

use Exporter ();
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw/save_mgvtable set_init_vtables/;

my %saved_mgvtable;

sub save_mgvtable {
    my ( $vtable, $ix ) = @_;

    $saved_mgvtable{$vtable} ||= [];
    push @{ $saved_mgvtable{$vtable} }, $ix;

    return;
}

sub set_init_vtables {

    foreach my $vtable ( sort keys %saved_mgvtable ) {
        init_vtables()->sadd( '/* PL_vtbl_%s */', $vtable );
        my $MGVTBL = sprintf( '(MGVTBL*) &PL_vtbl_%s', $vtable );
        my $count = scalar @{ $saved_mgvtable{$vtable} };
        if ( $count == 1 ) {    # preserve one single line syntax
            my $ix = $saved_mgvtable{$vtable}->[0];
            init_vtables()->sadd( 'magic_list[%d].mg_virtual = %s;', $ix, $MGVTBL );
        }
        else {                  # more than one magic is using the same vtbl, let's use the multi helper

            # use Test::More;
            # print STDERR "IX: ", explain( [ @{ $saved_mgvtable{$vtable} } ] );
            # print STDERR "RANGE: ", explain( ranges( @{ $saved_mgvtable{$vtable} } ) );
            # print STDERR "\n";

            my @RangeValues;

            my $ix_ranges = get_ranges( @{ $saved_mgvtable{$vtable} } );

            my @SingleValues;

            foreach my $ix_range (@$ix_ranges) {
                if ( ref $ix_range ) {
                    push @RangeValues, "{ $ix_range->[0], $ix_range->[1] }";
                }
                else {
                    push @SingleValues, $ix_range;
                }
            }

            my $size_singles = scalar @SingleValues;
            if ( $size_singles == 1 ) {
                init_vtables()->sadd( 'magic_list[%d].mg_virtual = %s;', $SingleValues[0], $MGVTBL );
            }
            elsif ( $size_singles > 1 ) {

                init_vtables()->sadd(
                    'MULTI_SET_MAGIC_LIST_VTBL( (const int[]){%s}, %d, %s );',
                    join( ',', @SingleValues ),
                    scalar @SingleValues,
                    $MGVTBL
                );

            }

            if ( scalar @RangeValues ) {
                init_vtables()->sadd(
                    'MULTI_SET_MAGIC_LIST_VTBL_RANGE( (const IntegerRange[]){%s}, %d, %s );',

                    #join( ',', map { '{ INTEGER, ' . $_ . ' }' } @{ $saved_mgvtable{$vtable} } ),
                    join( ',', @RangeValues ),
                    scalar @RangeValues,
                    $MGVTBL
                );

            }
        }

        init_vtables()->add('');    # empty line for readability
    }

    return;
}

sub get_ranges {                    # move to a more generic helper
    my @list = @_;

    my @ranges;
    my ( $from, $to );

    my $do_range = sub {
        push @ranges, $from == $to ? $from : [ $from, $to ];
    };

    foreach my $i (@list) {

        # initialize the first range
        if ( !defined $from ) {
            $from = $to = $i;
            next;
        }

        # check if we can grow
        if ( $i == $to + 1 ) {
            $to = $i;
        }
        else {    # close the current range
            $do_range->();
            $from = $to = $i;    # reinitialize a new range
        }
    }

    # close the last range
    $do_range->() if defined $from;

    return [@ranges];
}

1;
