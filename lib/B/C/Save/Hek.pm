package B::C::Save::Hek;

use strict;

use B qw(cstring);
use B::C::Config;
use B::C::File qw( decl init init0 sharedhe);
use B::C::Helpers qw/strlen_flags/;
use B::C::SaveCOW qw/savepv/;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/save_hek save_shared_he/;

my %hektable;
my $hek_index = 0;

# Shared global string in PL_strtab.
# Mostly GvNAME and GvFILE, but also CV prototypes or bareword hash keys.
# Note: currently not used in list context
sub save_hek {
    my ( $str, $fullname, $dynamic ) = @_;    # not cstring'ed
                                              # $dynamic not yet implemented. see lexsub CvNAME in CV::save

    # $dynamic not yet implemented. see lexsub CvNAME in CV::save
    # force empty string for CV prototypes
    return "NULL" unless defined $str;
    return "NULL" if !length $str and !@_ and $fullname !~ /unopaux_item.* const/;

    # The first assigment is already refcount bumped, we have to manually
    # do it for all others
    return sprintf( "share_hek_hek(%s)", $hektable{$str} ) if defined $hektable{$str};

    my ( $cstr, $cur, $utf8 ) = strlen_flags($str);
    $cur  = -$cur if $utf8;
    $cstr = '""'  if $cstr eq "0";

    my $sym = sprintf( "hek%d", $hek_index++ );
    $hektable{$str} = $sym;
    decl()->add( sprintf( "Static HEK *%s;", $sym ) );

    debug( pv => "Saving hek %s %s cur=%d", $sym, $cstr, $cur );

    # randomized global shared hash keys:
    #   share_hek needs a non-zero hash parameter, unlike hv_store.
    #   Vulnerable to oCERT-2011-003 style DOS attacks?
    #   user-input (object fields) does not affect strtab, it is pretty safe.
    # But we need to randomize them to avoid run-time conflicts
    #   e.g. "Prototype mismatch: sub bytes::length (_) vs (_)"

    init()->add(
        sprintf(
            "%s = share_hek(%s, %d, %s);",
            $sym, $cstr, $cur, '0'
        )
    );

    return $sym;
}

my %saved_shared_hash;

sub save_shared_he {
    my $key = shift;

    return $saved_shared_hash{$key} if $saved_shared_hash{$key};

    B::C::File::add_prerendering_hook_once( \&init0_sharedhes );

    my ( $cstr, $cur, $utf8 ) = strlen_flags($key);

    sharedhe($cur)->comment(
        qq{
        0: HE *hent_next; 
        1: HEK *hent_hek; 
        2: union { SV *hent_val;  Size_t hent_refcount; } he_valu;  
        3: U32 hek_hash;  
        4: I32 hek_len;  
        5: char hek_key[ $cur + 1]; 
        6: char flags}
    );
    sharedhe($cur)->add( sprintf( "NULL, NULL, { .hent_refcount = IMMORTAL_PL_strtab }, 0, %d, %s, %d", $cur, $cstr, $utf8 ? 1 : 0 ) );

    my $index = sharedhe($cur)->index();

    return $saved_shared_hash{$key} = sprintf( q{sharedhe%d_list[%d]}, $cur, $index );
}

# init PL_strtab with sharedhes [ moved it away from B::C::File ]
sub init0_sharedhes {
    my $bcfile = B::C::File::singleton();

    my $sharedhes = { total => 0 };
    my @all_sharedhes = sort grep { $_ =~ q{^sharedhe[0-9]+$} } keys %$bcfile;

    return $sharedhes unless scalar \@all_sharedhes;

    eval q/use Data::Dumper/;

    my $total = 0;
    foreach my $se (@all_sharedhes) {
        $total += $bcfile->{$se}->index() + 1;
    }

    init0()->add(
        q{/* init PL_strtab with sharedhes */},
        '{
         int pl_strtab_max = ((XPVHV*) SvANY(PL_strtab))->xhv_max;
         int i;
         HE   *entry;
         HE  **oentry;
         HEK  *hek_struct;
',
        sprintf( "((XPVHV*) SvANY(PL_strtab))->xhv_keys = %d;", $total ),
    );

    foreach my $se (@all_sharedhes) {
        init0()->add(qq{/* add elements from $se to PL_strtab */});

        my $list = $se . '_list';
        init0()->add(
            sprintf( q[for ( i = 0; i < %d; i++) {],                          $bcfile->{$se}->index() + 1 ),
            sprintf( q{entry = &(((SHARED_HE*)&%s[i])->shared_he_he);},       $list ),
            sprintf( q{hek_struct = &(((SHARED_HE*)&%s[i])->shared_he_hek);}, $list ),
            q{
                HeKEY_hek(entry) = hek_struct;
            PERL_HASH (hek_struct->hek_hash,
                       hek_struct->hek_key,
                       hek_struct->hek_len);

            /* Insert the hes */
            oentry = &(HvARRAY (PL_strtab))[HEK_HASH(hek_struct) & (I32) pl_strtab_max ];
            HeNEXT(entry) = *oentry;
            *oentry = entry;
},

            '}',
        );

    }

    init0()->add('} /* END of PL_strtab with sharedhes */');

    return $sharedhes;
}

1;
