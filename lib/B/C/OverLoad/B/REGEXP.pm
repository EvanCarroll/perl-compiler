package B::REGEXP;

use strict;

use B qw/RXf_EVAL_SEEN/;
use B::C::Save qw/savecowpv/;
use B::C::Config;
use B::C::File qw/init svsect xpvsect/;

sub do_save {
    my ( $sv, $fullname ) = @_;

    my $pv = $sv->PV;
    my ( $pvsym, $cur, $len ) = savecowpv($pv);

    xpvregexpsect()->comment('xmg_stash, xmg_u, xpv_cur, xpv_len_u, engine, mother_re, paren_names, extflags, minlen, minlenret, gofs, substrs, nparens, intflags, pprivate, lastparen, lastcloseparen, offs, recurse_locinput, subbeg, ... ');

    my $xpv_ix = xpvregexpsect()->saddl(
        "%s"   => $sv->save_magic_stash,         # xmg_stash
        "{%s}" => $sv->save_magic($fullname),    # xmg_u
        "%u"   => $cur,                          # xpv_cur
        "{%u}" => $len,                          # xpv_len_u STATIC_HV: length is 0 ???

        # Begin _REGEXP_COMMON
        "%s" => $engine,                         #  const struct regexp_engine* engine;  /* what engine created this regexp? */
        "%s" => $mother_re,                      #  REGEXP *mother_re; /* what re is this a lightweight copy of?
        "%s" => $paren_names,                    #  HV *paren_names;   /* Optional hash of paren names */

        # Information about the match that the perl core uses to manage things
        "%s" => $extflags,                       #  U32 extflags;   /* Flags used both externally and internally */
        "%s" => $minlen,                         #  SSize_t minlen; /* mininum possible number of chars in string to match */\
        "%s" => $minlenret,                      #  SSize_t minlenret; /* mininum possible number of chars in $& */
        "%s" => $gofs,                           #  STRLEN gofs;    /* chars left of pos that we search from */

        # substring data about strings that must appear in the final match, used for optimisations
        "%s" => $substrs,                        # struct reg_substr_data *substrs;
        "%s" => $nparens,                        # U32 nparens;    /* number of capture buffers */

        # private engine specific data
        "%s" => $intflags,                       # U32 intflags;   /* Engine Specific Internal flags */
        "%s" => $pprivate,                       # void *pprivate; /* Data private to the regex engine which created this object. */

        # Data about the last/current match. These are modified during matching
        "%s" => $lastparen,                      # U32 lastparen;      /* last open paren matched */
        "%s" => $lastcloseparen,                 # U32 lastcloseparen; /* last close paren matched */

        # Array of offsets for (@-) and (@+)
        "%s" => $offs,                           # regexp_paren_pair *offs;
        "%s" => $recurse_locinput,               # char **recurse_locinput; /* used to detect infinite recursion, XXX: move to internal */

        # saved or original string so \digit works forever.
        "%s" => $subbeg,                         # char *subbeg;
        "%s" => $saved_copy,                     # SV *saved_copy; /* If non-NULL, SV which is COW from original */ ( #ifdef PERL_ANY_COW ) # HV_STASH: is PERL_ANY_COW set for our perl?
        "%s" => $sublen,                         # SSize_t sublen; /* Length of string pointed by subbeg */
        "%s" => $suboffset,                      # SSize_t suboffset; /* byte offset of subbeg from logical start of str */
        "%s" => $subcoffset,                     # SSize_t subcoffset; /* suboffset equiv, but in chars (for @-/@+) */

        # Information about the match that isn't often used
        "%s" => $maxlen,                         # SSize_t maxlen;        /* mininum possible number of chars in string to match */

        #  offset from wrapped to the start of precomp
        "%s" => $pre_prefix,                     # PERL_BITFIELD32 pre_prefix:4;

        # original flags used to compile the pattern, may differ from extflags in various ways
        "%s" => $compflags,                      # PERL_BITFIELD32 compflags:9;
        "%s" => $qr_anoncv,                      # CV *qr_anoncv   /* the anon sub wrapped round qr/(?{..})/ */
    );

    my $ix = svsect()->sadd(
        "&xpvregexp_list[%d], %Lu, 0x%x, {NULL}",
        $xpv_ix, $sv->REFCNT, $sv->FLAGS
    );

    svsect()->debug( $fullname, $sv );

    return sprintf( "&sv_list[%d]", $ix );
}

1;
