package B::REGEXP;

use strict;

use B qw/cstring RXf_EVAL_SEEN/;
use B::C::Save qw/savecowpv/;
use B::C::Config;
use B::C::File qw/init init_static_assignments svsect xpvregexpsect/;

sub do_save {
    my ( $sv, $fullname ) = @_;
    
    my $sv_ix = svsect()->add('FAKE_REGEXP');
    svsect()->debug( $fullname, $sv );
    my $sym = sprintf( "&sv_list[%d]", $sv_ix );
     
#(gdb) p *(regexp*) 0x626c48
#$5 = {
#  paren_names = 0x0, 
#  extflags = 6553600, 
#  minlen = 4, 
#  minlenret = 4, 
#  gofs = 0, 
#  substrs = 0x6287e0, 
#  nparens = 0, 
#  intflags = 0, 
#  pprivate = 0x60a450, 
#  lastparen = 0, 
#  lastcloseparen = 0, 
#  offs = 0x625330, 
#  recurse_locinput = 0x0, 
#  subbeg = 0x0, 
#  saved_copy = 0x0, 
#  sublen = 0, 
#  suboffset = 0, 
#  subcoffset = 0, 
#  maxlen = 32767, 
#  pre_prefix = 4, 
#  compflags = 0, 
#  qr_anoncv = 0x0
#}    

    my $xpvlenu_pv = cstring($sv->PV);
    my $cur = $sv->CUR;
    
    
    my $qr_anoncv = $sv->qr_anoncv ? $sv->qr_anoncv->save : 'NULL';
    my $compflags = $sv->compflags;
    
    # Provided by C.xs -- Needs to go upstream!!!
    my $mother_re = $sv->mother_re ? $sv->mother_re->save : "NULL";
    my $paren_names = $sv->paren_names ? $sv->paren_names->save : "NULL";
    
    print STDERR sprintf("PAREN type %s = %s\n", ref $paren_names, defined $paren_names ? "defined" : "undefined");
    exit;

    xpvregexpsect()->comment('xmg_stash, xmg_u, xpv_cur, xpv_len_u, engine, mother_re, paren_names, extflags, minlen, minlenret, gofs, substrs, nparens, intflags, pprivate, lastparen, lastcloseparen, offs, recurse_locinput, subbeg, ... ');

    my $xpv_ix = xpvregexpsect()->saddl(
        "%s"   => $sv->save_magic_stash,         # xmg_stash
        "{%s}" => $sv->save_magic($fullname),    # xmg_u
        "%u"   => $cur,                          # xpv_cur
        "{.xpvlenu_pv=%s}" => $xpvlenu_pv,       # xpv_len_u
        
        # Begin _REGEXP_COMMON
        "%s"   => 'NULL',                       #  const struct regexp_engine* engine;  /* what engine created this regexp? */ # STATIC_HV: We should have code to detect if engine is not PL_core_reg_engine.
        "%s"   => $mother_re,                   #  REGEXP *mother_re; /* what re is this a lightweight copy of?
        "%s"   => $paren_names,                 #  HV *paren_names;   /* Optional hash of paren names */
        
        # Information about the match that the perl core uses to manage things
        "%u" => $sv->extflags,                   #  U32 extflags;   /* Flags used both externally and internally */
        "%d" => $sv->minlen,                     #  SSize_t minlen; /* mininum possible number of chars in string to match */\
        "%d" => $sv->minlenret,                  #  SSize_t minlenret; /* mininum possible number of chars in $& */
        "%u" => $sv->gofs,                       #  STRLEN gofs;    /* chars left of pos that we search from */
        
        # substring data about strings that must appear in the final match, used for optimisations
        "%s" => 'NULL',                          # ? struct reg_substr_data *substrs;
        "%u" => $sv->nparens,                    # U32 nparens;    /* number of capture buffers */
        
        # private engine specific data
        "%u" => $sv->intflags,                   # U32 intflags;   /* Engine Specific Internal flags */
        "%s" => 'NULL',                          # ? void *pprivate; /* Data private to the regex engine which created this object. */
        
        # Data about the last/current match. These are modified during matching
        "%u" => $sv->lastparen,                  # U32 lastparen;      /* last open paren matched */
        "%u" => $sv->lastcloseparen,             # U32 lastcloseparen; /* last close paren matched */
        
        # Array of offsets for (@-) and (@+)
        "%s" => 'NULL',                          # ? regexp_paren_pair *offs;
        "%s" => 'NULL',                          # char **recurse_locinput; /* used to detect infinite recursion, XXX: move to internal */
        
        # saved or original string so \digit works forever.
        "%s" => 'NULL',                          # char *subbeg;
        "%s" => 'NULL',                          # SV *saved_copy; /* If non-NULL, SV which is COW from original */ ( #ifdef PERL_ANY_COW ) # HV_STASH: is PERL_ANY_COW set for our perl?
        "%d" => $sv->sublen,                     # SSize_t sublen; /* Length of string pointed by subbeg */
        "%d" => $sv->suboffset,                  # SSize_t suboffset; /* byte offset of subbeg from logical start of str */
        "%d" => $sv->subcoffset,                 # SSize_t subcoffset; /* suboffset equiv, but in chars (for @-/@+) */
        
        # Information about the match that isn't often used
        "%d" => $sv->maxlen,                     # SSize_t maxlen;        /* mininum possible number of chars in string to match */
        
        #  offset from wrapped to the start of precomp
        "%u" => $sv->pre_prefix,                 # PERL_BITFIELD32 pre_prefix:4;
        
        # original flags used to compile the pattern, may differ from extflags in various ways
        "%u" => $compflags,                      # PERL_BITFIELD32 compflags:9;
        "%s"   => $qr_anoncv,                    # CV *qr_anoncv   /* the anon sub wrapped round qr/(?{..})/ */
    );

    my $any_sym = sprintf("&xpvregexp_list[%d]", $xpv_ix);
    svsect()->supdate( $sv_ix, "%s, %Lu, 0x%x, {NULL}", $any_sym, $xpv_ix, $sv->REFCNT, $sv->FLAGS );
    
    init_static_assignments()->sadd("((regexp*)%s)->engine = PL_core_reg_engine;", $any_sym); 

    return $sym;
}


1;

