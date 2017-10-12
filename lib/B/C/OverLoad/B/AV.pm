package B::AV;

use strict;

use B::C::Flags ();

use B::C::Debug qw/debug/;
use B::C::File qw/init xpvavsect svsect init_static_assignments init_bootstraplink/;
use B::C::Helpers qw/key_was_in_starting_stash/;

# maybe need to move to setup/config
my ( $use_av_undef_speedup, $use_svpop_speedup ) = ( 1, 1 );
my $MYMALLOC = $B::C::Flags::Config{usemymalloc} eq 'define';

sub fill {
    my $av = shift;

    my $fill = eval { $av->FILL };    # cornercase: tied array without FETCHSIZE
    $fill = -1 if $@;                 # catch error in tie magic

    return $fill;
}

sub cast_sv {
    return "(SV*)";
}

sub cast_section {                    ### Stupid move it to section !!! a section know its type
    return "AV*";
}

sub section_sv {
    return svsect();
}

sub update_sv {
    my ( $av, $ix, $fullname, $args ) = @_;

    my $fill = $args->{fill};
    my $max  = $args->{fill};         # for AVs optimization ?

    xpvavsect()->comment('xmg_stash, xmg_u, xav_fill, xav_max, xav_alloc');
    my $xpv_ix = xpvavsect()->saddl(
        "%s"   => $av->save_magic_stash,         # xmg_stash
        "{%s}" => $av->save_magic($fullname),    # xmg_u
        "%s"   => $fill,                         # xav_fill
        "%s"   => $max,                          # xav_max
        "%s"   => "NULL",                        # xav_alloc  /* pointer to beginning of C array of SVs */ This has to be dynamically setup at init().
    );

    svsect()->supdate( $ix, "&xpvav_list[%d], %Lu, 0x%x, {%s}", $xpv_ix, $av->REFCNT, $av->FLAGS, 0 );

    return;
}

# helper to skip backref SV
sub skip_backref_sv {
    my ($sv) = @_;

    return 0 unless $sv->can('FULLNAME');
    my $name = $sv->FULLNAME();
    return 1 if $name =~ m/::(?:bootstrap)$/;    # BEGIN
    return 1 unless key_was_in_starting_stash($name);

    return;
}

sub do_save {
    my ( $av, $fullname, $cv, $is_backref ) = @_;

    $av->FLAGS & 2048 and die sprintf( "Unexpected SVf_ROK found in %s\n", ref $av );
    $fullname ||= '';

    my $fill = $av->fill();

    my $section = $av->section_sv();

    my ( $ix, $sym ) = $section->reserve( $av, $av->cast_section );

    #$sym = "($type_to_cast) $sym";
    #warn sprintf( "### SEC %s TTC %s sym %s\n", $section->{name}, $type_to_cast, $sym );

    debug( av => "saving AV %s 0x%x [%s] FILL=%d", $fullname, $$av, ref($av), $fill );

    # XXX AVf_REAL is wrong test: need to save comppadlist but not stack
    # We used to block save on @- and @+ by checking for magic of type D. save_magic doesn't advertize this now so we don't have the "same" blocker.
    if ( $fill > -1 and $fullname !~ m/^(main::)?[-+]$/ ) {
        my @array = $av->ARRAY;    # crashes with D magic (Getopt::Long)

        #	my @names = map($_->save, @array);
        # XXX Better ways to write loop?
        # Perhaps svp[0] = ...; svp[1] = ...; svp[2] = ...;
        # Perhaps I32 i = 0; svp[i++] = ...; svp[i++] = ...; svp[i++] = ...;

        # micro optimization: op/pat.t ( and other code probably )
        # has very large pads ( 20k/30k elements ) passing them to
        # ->add is a performance bottleneck: passing them as a
        # single string cuts runtime from 6min20sec to 40sec

        # you want to keep this out of the no_split/split
        # map("\t*svp++ = (SV*)$_;", @names),
        my $acc = '';

        # remove element from the array when it's a backref

        my ( $count, @values ) = (0);
        {
            # TODO: This local may no longer be needed now we've removed the 5.16 conditional here.
            if ($is_backref) {
                my @new_array;
                foreach my $elt (@array) {
                    next if skip_backref_sv($elt);
                    push @new_array, $elt;
                }
                @array = @new_array;

                if ( !scalar @array ) {

                    # nothing to save there
                    if ( $ix == $section->index ) {
                        $section->remove;    # lives dangerously but should be fine :-\
                    }
                    else {
                        # sanity check: we know this is a svsect here...
                        die $section->name unless $section->name eq 'sv';

                        # too late to remove it, let's update our svsect to an empty entry
                        $section->supdate( $ix, "NULL, 0, 0, {NULL}" );
                        $section->debug('unused svsect entry too late to remove it');
                    }
                    return q{NULL};
                }

                # Idea: bypass the AV save if there's only one element in the array
            }

            @values = map { $_->save( $fullname . "[" . $count++ . "]" ) || () } @array;
            $fill = scalar(@values) if $is_backref;
        }

        my $svpcast = $av->cast_sv();    # could be using PADLIST, PADNAMELIST, or AV method for this.
        $count = scalar @values;
        my $cast = $svpcast;
        $cast =~ tr{()*}{}d;
        my $list = "($cast * []) {" . join( ',', map { "$svpcast" . ( $_ ? $_ : '&PL_sv_undef' ) } @values ) . "}";
        $acc = "memcpy(svp,$list,sizeof($cast *) * $count);\t\n";

        $av->add_to_init( $sym, $acc, $fill, $fullname );

        # should really scan for \n, but that would slow
        # it down
        init()->inc_count($#array);
    }
    else {
        my $max = $av->MAX;
        init()->sadd( "av_extend(%s, %d);", $sym, $max ) if $max > -1;
    }

    $av->update_sv( $ix, $fullname, { fill => $fill } );    # could be using PADLIST, PADNAMELIST, or AV method for this.

    return $sym;                                            # return the reserved symbol
}

# With -fav-init faster initialize the array as the initial av_extend()
# is very expensive.
# The problem was calloc, not av_extend.
# Since we are always initializing every single element we don't need
# calloc, only malloc. wmemset'ting the pointer to PL_sv_undef
# might be faster also.

sub add_to_init {
    my ( $av, $sym, $acc, $fill, $fullname ) = @_;

    my $deferred_init = $acc =~ qr{BOOTSTRAP_XS_}m ? init_bootstraplink() : init_static_assignments();

    $deferred_init->open_block( sprintf( "Initialize array %s", $fullname ) );

    $deferred_init->add("register int gcount;") if $acc =~ m/\(gcount=/m;
    $av->add_malloc_line_for_array_init( $deferred_init, $sym, $fill );
    $deferred_init->add( substr( $acc, 0, -2 ) );    # AvFILLp already in XPVAV

    $deferred_init->close_block();
}

sub add_malloc_line_for_array_init {
    my ( $av, $deferred_init, $sym, $fill ) = @_;
    return if !defined $fill;

    $fill = $fill < 3 ? 3 : $fill + 1;

    $deferred_init->sadd( "SV **svp = %s;", B::C::Memory::INITAv( $deferred_init, $sym, $fill ) );

    return;
}

1;
