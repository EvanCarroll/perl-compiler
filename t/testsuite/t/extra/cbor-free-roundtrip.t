#!perl

use strict;
use warnings;

use Config;

use CBOR::Free ();

my ( @input, @output );

push @input, {
    a => 1, b => [ 1 .. 4 ], c => { x => 42 },
};

push @input, {
    french  => q[Les naïfs ægithales hâtifs pondant à Noël où il gèle sont sûrs d'être déçus en voyant leurs drôles d'œufs abîmés.],
    spanish => q[El pingüino Wenceslao hizo kilómetros bajo exhaustiva lluvia y frío, añoraba a su querido cachorro.],
    hebrew  => q[זה כיף סתם לשמוע איך תנצח קרפד עץ טוב בגן.],
};

push @input, \%Config; # fixed in 0.23

# encode some data
my @encoded;
foreach my $data (@input) {
    push @encoded, CBOR::Free::encode($data);
    push @output,  CBOR::Free::decode( $encoded[-1] );
}

# load Test2 for lazy/easy testing and embedded cmp_deep
require Test2::Bundle::Extended;
Test2::Bundle::Extended->import;

for ( my $i = 0; $i < scalar @input; ++$i ) {
    my $data      = $input[$i];
    my $roundtrip = $output[$i];

    is( $roundtrip, $data, "roundtrip for input $i" );
}

done_testing();
