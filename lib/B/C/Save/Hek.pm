package B::C::Save::Hek;

use strict;

use B qw(cstring);
use B::C::Config;
use B::C::File qw( decl init );
use B::C::Helpers qw/strlen_flags/;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/save_hek/;

my ( %hektable, %statichektable );
my $hek_index = 0;

# Shared global string in PL_strtab.
# Mostly GvNAME and GvFILE, but also CV prototypes or bareword hash keys.
# Note: currently not used in list context
sub save_hek {
    my ( $str, $fullname, $dynamic ) = @_;    # not cstring'ed
                                              # $dynamic not yet implemented. see lexsub CvNAME in CV::save

    # $dynamic: see lexsub CvNAME in CV::save
    # force empty string for CV prototypes
    return "NULL" unless defined $str;
    return "NULL"
      if $dynamic
      and !length $str
      and !@_
      and $fullname !~ /unopaux_item.* const/;

    # The first assigment is already refcount bumped, we have to manually
    # do it for all others
    my ( $cstr, $cur, $utf8 ) = strlen_flags($str);
    my $hek_key = $str . ":" . $utf8;
    if ( $dynamic and defined $hektable{$hek_key} ) {
        return sprintf( "share_hek_hek(%s)", $hektable{$hek_key} );
    }
    if ( !$dynamic and defined $statichektable{$hek_key} ) {    # FIXME statichek...
        return $statichektable{$hek_key};
    }

    $cur  = -$cur if $utf8;
    $cstr = '""'  if $cstr eq "0";

    my $sym = sprintf( "hek%d", $hek_index++ );
    if ( !$dynamic ) {
        $statichektable{$hek_key} = $sym;
        my $key = $cstr;
        my $len = abs($cur);

        # strip CowREFCNT
        if ( $key =~ /\\000\\001"$/ ) {
            $key =~ s/\\000\\001"$/"/;
            $len -= 2;
        }

        # add the flags. a static hek is unshared
        if ( !$utf8 ) {    # 0x88: HVhek_STATIC + HVhek_UNSHARED
            $key =~ s/"$/\\000\\210"/;
        }
        else {             # 0x89: + HVhek_UTF8
            $key =~ s/"$/\\000\\211"/;
        }

        #warn sprintf("Saving static hek %s %s cur=%d\n", $sym, $cstr, $cur)
        #  if $debug{pv};
        # not const because we need to set the HASH at init
        decl()->add(
            sprintf(
                "Static struct hek_ptr %s = { %u, %d, %s};",
                $sym, 0, $len, $key
            )
        );
        init()->add( sprintf( "PERL_HASH(%s.hek_hash, %s.hek_key, %u);", $sym, $sym, $len ) );
    }
    else {
        $hektable{$hek_key} = $sym;
        decl()->add( sprintf( "Static HEK *%s;", $sym ) );
        debug( pv => "Saving hek %s %s cur=%d", $sym, $cstr, $cur );

        # randomized global shared hash keys:
        #   share_hek needs a non-zero hash parameter, unlike hv_store.
        #   Vulnerable to oCERT-2011-003 style DOS attacks?
        #   user-input (object fields) does not affect strtab, it is pretty safe.
        # But we need to randomize them to avoid run-time conflicts
        #   e.g. "Prototype mismatch: sub bytes::length (_) vs (_)"

        # init()->add(
        #     sprintf(
        #         "%s = share_hek(%s, %d, %s);",
        #         $sym, $cstr, $cur, '0'
        #     )
        # );

        init()->add( sprintf( "%s = share_hek(%s, %d);", $sym, $cstr, $cur ) );
    }

    return $sym;
}

1;
