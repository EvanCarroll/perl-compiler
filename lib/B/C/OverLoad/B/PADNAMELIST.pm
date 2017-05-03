package B::PADNAMELIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/init init_magic padnamelistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub add_to_section {
    my ( $self, $cv ) = @_;

    padnamelistsect()->comment("xpadnl_fill, xpadnl_alloc, xpadnl_max, xpadnl_max_named, xpadnl_refcnt");

    # TODO: max_named walk all names and look for non-empty names
    my $refcnt   = $self->REFCNT + 1;    # XXX defer free to global destruction: 28
    my $fill     = $self->fill;
    my $maxnamed = $self->MAXNAMED;

    my $ix = padnamelistsect->add("$fill, NULL, $fill, $maxnamed, $refcnt /* +1 */");

    my $sym = savesym( $self, "&padnamelist_list[$ix]" );

    return $sym;
}

sub add_to_init {
    my ( $self, $sym, $acc ) = @_;

    my $fill1 = $self->fill + 1;

    init_magic()->no_split;
    init_magic()->add("{");
    init_magic()->add("\tregister int gcount;") if $acc =~ qr{\bgcount\b};
    init_magic()->sadd( "\tPADNAME **svp = INITPADNAME($sym, %d);", $fill1 );
    init_magic()->add( substr( $acc, 0, -2 ) );
    init_magic()->add("}");
    init_magic()->split;

    return;
}

sub fill {
    my $self = shift;
    return $self->MAX;
}

sub cast_sv {
    return "(PADNAME*)";
}

1;
