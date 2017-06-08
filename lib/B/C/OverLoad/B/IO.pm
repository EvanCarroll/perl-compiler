package B::IO;

use strict;

use B qw/cstring cchar svref_2object/;
use B::C::Config;
use B::C::Save qw/savecowpv/;
use B::C::File qw/init init2 svsect xpviosect/;
use B::C::Helpers::Symtable qw/savesym/;

sub save_io_and_data {
    my ( $io, $globname, $data ) = @_;

    warn "#### ... " . ref( svref_2object( \$data ) );

    my $ref = svref_2object( \$data )->save;

    # force inclusion of PerlIO::scalar as it was loaded in BEGIN.
    init2()->add_eval( sprintf 'open(%s, \'<:scalar\', \\\\$%s);', $globname, $globname );

    init()->pre_destruct( sprintf 'eval_pv("close %s;", 1);', $globname );    # is this really required ?
    $B::C::use_xsloader = 1;                                                  # layers are not detected as XSUB CV, so force it

    # STATIC_HV: This needs to be done earlier in C.pm -- TODO
    require PerlIO;
    require PerlIO::scalar;

    # save "PerlIO::scalar" ???

    $B::C::curINC{'PerlIO/scalar.pm'} = $INC{'PerlIO/scalar.pm'};
    $B::C::xsub{'PerlIO::scalar'}     = 'Dynamic-' . $INC{'PerlIO/scalar.pm'};    # force dl_init boot

    # Do some sorta magic to save the XS also.
    my $io_sym = $io->save( $globname, 'is_DATA' );

    return ( $io_sym, $ref );
}

sub do_save {
    my ( $io, $fullname, $is_DATA ) = @_;

    #return 'NULL' if $io->IsSTD($fullname);

    my ( $xio_top_name,    undef, undef ) = savecowpv( $io->TOP_NAME    || '' );
    my ( $xio_fmt_name,    undef, undef ) = savecowpv( $io->FMT_NAME    || '' );
    my ( $xio_bottom_name, undef, undef ) = savecowpv( $io->BOTTOM_NAME || '' );

    my $top_gv    = $io->TOP_GV->save;
    my $fmt_gv    = $io->FMT_GV->save;
    my $bottom_gv = $io->BOTTOM_GV->save;
    foreach ( $top_gv, $fmt_gv, $bottom_gv ) {
        $_ = 'NULL' if ( $_ eq 'Nullsv' );
    }

    xpviosect()->comment('xmg_stash, xmg_u, xpv_cur, xpv_len_u, xiv_u, xio_ofp, xio_dirpu, xio_page, xio_page_len, xio_lines_left, xio_top_name, xio_top_gv, xio_fmt_name, xio_fmt_gv, xio_bottom_name, xio_bottom_gv, xio_type, xio_flags');
    my $xpvio_ix;
    if ($is_DATA) {
        warn "DATA.....IO\n";
        $xpvio_ix = xpviosect()->saddl(

            #head
            "%s"                => 'NULL',      # xmg_stash
            "{%s}"              => 0,           # xmg_u
            "%u"                => $io->CUR,    # xpv_cur
            "{.xpvlenu_len=%u}" => $io->LEN,    # xpv_len_u

            # end of head
            "{.xivu_uv=%d}"           => 0,                       # xiv_u # ???
            "(PerlIO*) %d"            => 0,                       # xio_ofp
            "{.xiou_any =(void*) %s}" => q{NULL},                 # xio_dirpu
            "%d"                      => $io->PAGE,               # xio_page
            "%d"                      => $io->PAGE_LEN,           # xio_page_len
            "%d"                      => $io->LINES_LEFT,         # xio_lines_left
            "(char*) %s"              => 'NULL',                  # xio_top_name
            "(GV*)%s"                 => 'NULL',                  # xio_top_gv
            "(char*)%s"               => 'NULL',                  # xio_fmt_name
            "(GV*)%s"                 => 'NULL',                  # xio_fmt_gv
            "(char*)%s"               => 'NULL',                  # xio_bottom_name
            "(GV*) %s"                => 'NULL',                  # xio_bottom_gv
            '%s'                      => cchar( $io->IoTYPE ),    # xio_type
            "0x%x"                    => $io->IoFLAGS,            # xio_flags
        );
    }
    else {

        $xpvio_ix = xpviosect()->saddl(
            "%s"                => $io->save_magic_stash,         # xmg_stash
            "{%s}"              => $io->save_magic($fullname),    # xmg_u
            "%u"                => $io->CUR,                      # xpv_cur
            "{.xpvlenu_len=%u}" => $io->LEN,                      # xpv_len_u

            # end of head
            "{.xivu_uv=%d}"           => 0,                       # xiv_u
            "(PerlIO*) %d"            => 0,                       # xio_ofp
            "{.xiou_any =(void*) %s}" => q{NULL},                 # xio_dirpu
            "%d"                      => $io->PAGE,               # xio_page
            "%d"                      => $io->PAGE_LEN,           # xio_page_len
            "%d"                      => $io->LINES_LEFT,         # xio_lines_left
            "(char*) %s"              => $xio_top_name,           # xio_top_name
            "(GV*)%s"                 => $top_gv,                 # xio_top_gv
            "(char*)%s"               => $xio_fmt_name,           # xio_fmt_name
            "(GV*)%s"                 => $fmt_gv,                 # xio_fmt_gv
            "(char*)%s"               => $xio_bottom_name,        # xio_bottom_name
            "(GV*) %s"                => $bottom_gv,              # xio_bottom_gv
            '%s'                      => cchar( $io->IoTYPE ),    # xio_type
            "0x%x"                    => $io->IoFLAGS,            # xio_flags
        );
    }

    # svsect()->comment("any=xpvcv, refcnt, flags, sv_u");
    my $sv_ix = svsect->sadd( "(XPVIO*)&xpvio_list[%u], %Lu, 0x%x, {%s}", $xpvio_ix, $io->REFCNT + 1, $io->FLAGS, '0' );

    return savesym( $io, "&sv_list[$sv_ix]" );
}

1;
