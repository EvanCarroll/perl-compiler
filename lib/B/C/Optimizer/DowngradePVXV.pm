package B::C::Optimizer::DowngradePVXV;

use strict;

# use B qw/svref_2object/;
# use B::C::Config;
# use B::C::Packages qw/is_package_used/;
use B::C::Decimal qw/get_integer_value/;
use B qw{SVf_NOK SVp_NOK SVs_OBJECT SVf_IOK SVf_ROK SVf_POK SVp_POK SVp_IOK SVf_IsCOW SVf_READONLY SVs_PADSTALE SVs_PADTMP SVf_PROTECT};

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/downgrade_pviv downgrade_pvnv/;

# we need to keep them in memory to do not reuse the same memory location
my @EXTRA;

sub SVt_IV   { 1 }
sub SVt_NV   { 2 }
sub SVt_PV   { 3 }
sub SVt_PVIV { 5 }
sub SVt_PVNV { 6 }
sub SVt_MASK { 0xf }    # smallest bitmask that covers all types

my $DEBUG = 1;

sub ddebug {
    return unless $DEBUG;
    my (@what) = @_;

    local %ENV;         # avoid error with taint from op/taint.t
    my $msg = join ' ', @what;

    qx{/usr/bin/echo '$msg' >> /tmp/flags};
    return 1;
}

sub is_simple_pviv {
    my $sv = shift;

    my $flags = $sv->FLAGS;

    return if $flags & SVf_ROK == SVf_ROK;
    return if $flags & SVt_MASK != SVt_PVIV;

    # remove insignificant flags for us as a PVIV
    $flags &= ~SVf_IsCOW if $flags & SVp_POK;
    $flags &= ~SVf_IOK;
    $flags &= ~SVf_POK;
    $flags &= ~SVp_IOK;
    $flags &= ~SVp_POK;
    $flags &= ~SVf_READONLY;

    # remove the type
    $flags &= ~SVt_MASK();

    ddebug( "PVIV with flags", $flags ) if $flags;

    return $flags == 0;
}

sub is_simple_pvnv {    # should factorized them
    my $sv = shift;

    my $flags = $sv->FLAGS;

    return if $flags & SVf_ROK == SVf_ROK;
    return if $flags & SVt_MASK != SVt_PVNV;

    # remove insignificant flags for us as a PVIV
    $flags &= ~SVf_IsCOW if $flags & SVp_POK;
    $flags &= ~SVf_IOK;
    $flags &= ~SVf_POK;
    $flags &= ~SVf_NOK;
    $flags &= ~SVp_IOK;
    $flags &= ~SVp_POK;
    $flags &= ~SVp_NOK;

    # bonus ?
    $flags &= ~SVf_READONLY;
    $flags &= ~SVs_PADSTALE;
    $flags &= ~SVs_PADTMP;
    $flags &= ~SVf_PROTECT;

    # remove the type
    $flags &= ~SVt_MASK();

    ddebug( "PVNV with flags", $flags ) if $flags;

    return $flags == 0;
}

sub custom_flags {
    my ( $sv, $type ) = @_;

    $type ||= 0;

    # remove the current type
    my $flags = $sv->FLAGS & ~SVt_MASK();

    # use the new type
    $flags |= $type;

    if ( $type == SVt_IV() ) {
        $flags |= ( SVf_IOK | SVp_IOK );

        $flags &= ~SVf_NOK;
        $flags &= ~SVp_NOK;
        $flags &= ~SVf_POK;
        $flags &= ~SVp_POK;

    }
    elsif ( $type == SVt_NV() ) {
        $flags |= ( SVf_NOK | SVp_NOK );

        $flags &= ~SVf_IOK;
        $flags &= ~SVp_IOK;
        $flags &= ~SVf_POK;
        $flags &= ~SVp_POK;

    }
    elsif ( $type == SVt_PV() ) {
        $flags |= ( SVf_POK | SVp_POK | SVf_IsCOW );

        $flags &= ~SVf_IOK;
        $flags &= ~SVp_IOK;
        $flags &= ~SVf_NOK;
        $flags &= ~SVp_NOK;
    }

    return $flags;
}

sub downgrade_pviv {
    my ( $sv, $fullname ) = @_;

    return unless is_simple_pviv($sv);

    #my $iok = $sv->FLAGS & ( SVf_IOK | SVp_IOK);
    #my $pok = $sv->FLAGS & ( SVf_POK | SVp_POK );
    my $iok = $sv->FLAGS & SVf_IOK;
    my $pok = $sv->FLAGS & SVf_POK;

    if (  !$pok && $iok
        or $iok && $sv->PV =~ qr{^[0-9]+$}
        or $pok && !$iok && $sv->PV eq ( $sv->IVX || 0 ) ) {    # PVIV used as IV let's downgrade it as an IV
        ddebug("downgrade PVIV to IV - case a");

        push @EXTRA, int get_integer_value( $sv->IVX );
        my $sviv = B::svref_2object( \$EXTRA[-1] );
        return B::IV::save( $sviv, $fullname, { flags => custom_flags( $sv, SVt_IV() ), refcnt => $sv->REFCNT } );

        #return B::IV::save( $sviv, $fullname );
    }
    elsif ( $pok && $sv->PV =~ qr{^[0-9]+$} && length( $sv->PV ) <= 18 ) {    # use Config{...}
        ddebug("downgrade PVIV to IV - case b");

        # downgrade a PV that looks like an IV (and not too long) to a simple IV
        push @EXTRA, int( "" . $sv->PV );
        my $sviv = B::svref_2object( \$EXTRA[-1] );
        return B::IV::save( $sviv, $fullname, { flags => custom_flags( $sv, SVt_IV() ), refcnt => $sv->REFCNT } );
    }

    # elsif ($pok) {                                                            # maybe do not downgrade it to PV if the string is only 0-9 ??
    #                                                                           # downgrade the PVIV as a regular PV
    #     qx{echo '- downgrade PV' >> /tmp/flags};
    #     push @EXTRA, "" . $sv->PV;
    #     my $svpv = B::svref_2object( \$EXTRA[-1] );
    #     return B::PV::save( $svpv, $fullname );
    # }

    return;
}

# > perl -MDevel::Peek -e 'my $a = "aa"; $a += 42; Dump($a)'
# SV = PVNV(0x7fbf488036b0) at 0x7fbf4882db90
#   REFCNT = 1
#   FLAGS = (NOK,pNOK)
#   IV = 0
#   NV = 42
#   PV = 0

sub downgrade_pvnv {
    my ( $sv, $fullname ) = @_;

    return unless is_simple_pvnv($sv);

    my $iok = $sv->FLAGS & SVf_IOK;
    my $nok = $sv->FLAGS & SVf_NOK;
    my $pok = $sv->FLAGS & SVf_POK;

    if (
           $nok
        && !$pok
        && !$iok
        && $sv->NV =~ qr{^[0-9]+$}
        && length( $sv->NV ) <= 18

        #or !$nok && $pok && !$iok && $sv->PV =~ qr{^[0-9]+$} && length( $sv->PV ) <= 18

        #or !$nok && $pok && $sv->PV eq ( $sv->NV || 0 )
      ) {    # PVNV used as IV let's downgrade it as an IV
        ddebug( "downgrade PVNV to IV - case a ", $sv->FLAGS );

        #eval q{use Devel::Peek}; Dump($sv);

        push @EXTRA, int get_integer_value( $sv->NV );
        my $sviv = B::svref_2object( \$EXTRA[-1] );
        return B::IV::save( $sviv, $fullname, { flags => custom_flags( $sv, SVt_IV() ), refcnt => $sv->REFCNT } );
    }

    # elsif ( $pok && $sv->PV =~ qr{^[0-9]+$} && length( $sv->PV ) <= 18 ) {    # use Config{...}
    #     ddebug("downgrade PVNV to IV - case b");
    #     # downgrade a PV that looks like an IV (and not too long) to a simple IV
    #     push @EXTRA, int( "" . $sv->PV );
    #     my $sviv = B::svref_2object( \$EXTRA[-1] );
    #     return B::IV::save( $sviv, $fullname, { flags => custom_flags($sv, SVt_IV() ), refcnt => $sv->REFCNT } );
    # }
    # elsif ($pok) {                                                            # maybe do not downgrade it to PV if the string is only 0-9 ??
    #                                                                           # downgrade the PVIV as a regular PV
    #     ddebug("downgrade PVNV to IV - case c");
    #     push @EXTRA, "" . $sv->PV;
    #     my $svpv = B::svref_2object( \$EXTRA[-1] );
    #     return B::PV::save( $svpv, $fullname );
    # }

    return;
}

1;