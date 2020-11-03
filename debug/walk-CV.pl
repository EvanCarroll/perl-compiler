
use B;

sub check {

    my $str = q[ABCDE];

    # $str !~ tr/\0-\377//c; # -> SVOP
    # $str !~ tr/\0-\377//;  # -> PVOP

    # $str !~ tr/\0-\376//c; # => PVOP
    # $str !~ tr/\0-\377//c; # => SVOP

    #my $trans = tr/\0-\377//c;

    # ... invlist
    ## SVOP
    $str !~ tr/\0-\377//c;    # REF: B::SVOP=SCALAR(0x252b408) ; NAME: trans ; TYPE: 34

    # invlist too ??
    ### PVOP
    $str !~ tr/[[:alpha:]]//c;    # PVOP ...
    $str !~ tr/[[:ascii:]]//c;    # PVOP ...
}

my $op = B::svref_2object( \*main::check );
warn $op->CV;

*B::OP::print_name = sub {
    my $op = shift;
    print "REF: $op ; NAME: " . $op->name . " ; TYPE: " . $op->type . "\n";

    if ( $op->name && $op->name eq 'trans' ) {

        if ( ref $op eq 'B::PVOP' ) {
            warn "\tthis is one pvop...: " . $op->pv;
            return;
        }
        my $sv = $op->sv;
        warn "SV: $sv = " . $sv->LEN . " " . $sv->CUR;
        warn "PV: " . $sv->PV;
        warn "SV " . $sv->FLAGS;
        warn join( ' ', $sv->ARRAY );
        foreach my $pv ( $sv->ARRAY ) {
            next unless ref $pv eq 'B::INVLIST';
            warn "==== " . $pv;
        }

    }

};

B::walkoptree( $op->CV->ROOT, 'print_name' );


