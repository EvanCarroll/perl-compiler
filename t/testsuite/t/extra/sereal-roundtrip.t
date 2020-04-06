#!perl

use strict;
use warnings;

use Sereal::Encoder ();
use Sereal::Decoder ();

my ( @input, @output );

push @input, {
    a => 1, b => [ 1 .. 4 ], c => { x => 42 },
};

push @input, {
    french  => q[Les naïfs ægithales hâtifs pondant à Noël où il gèle sont sûrs d'être déçus en voyant leurs drôles d'œufs abîmés.],
    spanish => q[El pingüino Wenceslao hizo kilómetros bajo exhaustiva lluvia y frío, añoraba a su querido cachorro.],
    hebrew  => q[זה כיף סתם לשמוע איך תנצח קרפד עץ טוב בגן.],
};

# encode some data
my @encoded;
my $encoder = Sereal::Encoder->new;
foreach my $data (@input) {
    push @encoded, $encoder->encode($data);
}

# decode some data
my $decoder = Sereal::Decoder->new;
foreach my $blob (@encoded) {
    my $decoded;
    $decoder->decode( $blob, $decoded );
    push @output, $decoded;
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
