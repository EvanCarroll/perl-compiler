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
        my $MGVTBL = sprintf( '(MGVTBL*) &PL_vtbl_%s', $vtable );
        my $count = scalar @{ $saved_mgvtable{$vtable} };
        if ( $count == 1 ) {    # preserve one single line syntax
            my $ix = $saved_mgvtable{$vtable}->[0];
            init_vtables()->sadd( 'magic_list[%d].mg_virtual = %s;', $ix, $MGVTBL );
        }
        else {                  # more than one magic is using the same vtbl, let's use the multi helper

            init_vtables()->sadd(
                'MULTI_SET_MAGIC_LIST_VTBL( (const int[]){%s}, %d, %s );',
                join( ',', @{ $saved_mgvtable{$vtable} } ),
                $count,
                $MGVTBL
            );
        }

        init_vtables()->add('');    # empty line for readability
    }

    return;
}

1;
