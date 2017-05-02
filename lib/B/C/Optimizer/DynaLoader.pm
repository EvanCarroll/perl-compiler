package B::C::Optimizer::DynaLoader;

use strict;
use warnings;

use B qw(svref_2object);

use B::C::Flags ();

use B::C::Config qw/verbose debug/;

sub new {
    my $class = shift or die;
    my $self  = shift or die;
    ref $self eq 'HASH' or die( ref $self );

    $self->{'xsub'}            or die;
    $self->{'skip_package'}    or die;
    $self->{'output_file'}     or die;
    exists $self->{'staticxs'} or die;

    # Initialize in case there's no dynaloader and we return early.
    $self->{'stash'} = {
        'dl'         => 0,
        'dl_modules' => [],
        'fixups'     => {},
      },

      return bless $self, $class;
}

sub stash {
    my $self = shift or die;

    return $self->{'stash'};
}

sub optimize {
    my $self = shift or die;
    ref $self eq __PACKAGE__ or die;

    my ( $boot, $dl ) = ( '', 0 );
    my @dl_modules = @DynaLoader::dl_modules;

    foreach my $stashname (@dl_modules) {
        if ( $stashname eq 'attributes' ) {
            $self->{'xsub'}->{$stashname} = 'Dynamic-' . $INC{'attributes.pm'};
        }

        if ( exists( $self->{'xsub'}->{$stashname} ) && $self->{'xsub'}->{$stashname} =~ m/^Dynamic/ ) {

            # XSLoader.pm: $modlibname = (caller())[1]; needs a path at caller[1] to find auto,
            # otherwise we only have -e
            $dl++;
        }

        my $stashxsub = $stashname;
        $stashxsub =~ s/::/__/g;
        if ( exists( $self->{'xsub'}->{$stashname} ) && $self->{'xsub'}->{$stashname} =~ m/^Dynamic-/ ) {
            $boot .= "EXTERN_C void boot_$stashxsub(pTHX_ CV* cv);\n";
        }

    }
    debug( cv => "\%B::C::xsub: " . join( " ", sort keys %{ $self->{'xsub'} } ) ) if verbose();

    return 0 if !$dl;

    my $xsfh;        # Will close automatically when it goes out of scope.

    # enforce attributes at the front of dl_init, #259
    # also Encode should be booted before PerlIO::encoding
    for my $front (qw(Encode attributes)) {
        if ( grep { $_ eq $front } @dl_modules ) {
            @dl_modules = grep { $_ ne $front } @dl_modules;
            unshift @dl_modules, $front;
        }
    }

    if ( $self->{'staticxs'} ) {
        my $file = $self->{'output_file'} . '.lst';
        open( $xsfh, ">", $file ) or die("Can't open $file: $!");
    }

    foreach my $stashname (@dl_modules) {
        if ( exists( $self->{'xsub'}->{$stashname} ) && $self->{'xsub'}->{$stashname} =~ m/^Dynamic/ ) {
            {
                # Scoped no warnings without loading the module.
                local $^W;
                BEGIN { ${^WARNING_BITS} = 0; }
                $B::C::use_xsloader = 1;    # TODO: This setting is totally worthless since the code that uses this variable has already been run??
            }
            if ( $self->{'xsub'}->{$stashname} eq 'Dynamic' ) {
                no strict 'refs';
                verbose("dl_init $stashname");

                # just in case we missed it. DynaLoader really needs the @ISA (#308)
                svref_2object( \@{ $stashname . "::ISA" } )->save;
            }
            else {                          # XS: need to fix cx for caller[1] to find auto/...
                verbose("bootstrapping $stashname added to XSLoader dl_init");
            }

            # TODO: Why no strict refs? Also why are we doing a second save here?
            no strict 'refs';
            unless ( grep /^DynaLoader$/, B::C::get_isa($stashname) ) {
                push @{ $stashname . "::ISA" }, 'DynaLoader';
                svref_2object( \@{ $stashname . "::ISA" } )->save;
            }

            debug( gv => '@', $stashname, "::ISA=(", join( ",", @{ $stashname . "::ISA" } ), ")" );

            if ( $self->{'staticxs'} ) {
                my ($laststash) = $stashname =~ /::([^:]+)$/;
                my $path = $stashname;
                $path =~ s/::/\//g;
                $path .= "/" if $path;    # can be empty
                $laststash = $stashname unless $laststash;    # without ::
                my $sofile = "auto/" . $path . $laststash . '\.' . $B::C::Flags::Config{'dlext'};

                #warn "staticxs search $sofile in @DynaLoader::dl_shared_objects\n"
                #  if verbose() and $self->{'debug'}->{pkg};
                for (@DynaLoader::dl_shared_objects) {
                    if (m{^(.+/)$sofile$}) {
                        print $xsfh $stashname, "\t", $_, "\n";
                        verbose("staticxs $stashname\t$_");
                        $sofile = '';
                        last;
                    }
                }
                print {$xsfh} $stashname, "\n" if $sofile;    # error case
                verbose("staticxs $stashname\t - $sofile not loaded") if $sofile;
            }
        }
        else {
            verbose( "no dl_init for $stashname, " . ( !$self->{'xsub'}->{$stashname} ? "not bootstrapped\n" : "bootstrapped as $self->{'xsub'}->{$stashname}" ) );

            # XXX Too late. This might fool run-time DynaLoading.
            # We really should remove this via init from @DynaLoader::dl_modules
            @DynaLoader::dl_modules = grep { $_ ne $stashname } @DynaLoader::dl_modules;
        }
    }

    $self->{'stash'} = {
        'boot'       => $boot,
        'dl'         => $dl,
        'dl_modules' => \@dl_modules,
        'fixups'     => {

            # Coro readonly symbols in BOOT (#293)
            'coro' => ( exists $self->{'xsub'}->{"Coro::State"} and grep { $_ eq "Coro::State" } @dl_modules ) ? 1 : 0,
            'EV'   => ( exists $self->{'xsub'}->{"EV"}          and grep { $_ eq "EV" } @dl_modules )          ? 1 : 0,
        },
    };

    return 1;
}

1;
