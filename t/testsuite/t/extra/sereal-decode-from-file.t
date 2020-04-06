#!perl

use strict;
use warnings;

use Config;

use Sereal qw(
  write_sereal_file read_sereal_file
  decode_sereal scalar_looks_like_sereal
);

my $tmp = "/tmp/bc_sereal.$$.data";
END { unlink $tmp }

write_sereal_file( $tmp, \%Config );

# load Test2 for lazy/easy testing and embedded cmp_deep
require Test2::Bundle::Extended;
Test2::Bundle::Extended->import;

ok( -s $tmp, "file tmp is not null" );

my $decoded = read_sereal_file($tmp);
is( $decoded, \%Config, "read_sereal_file Config" );

my $read;
{
    local $/;
    open( my $fh, '<', $tmp ) or die;
    $read = <$fh>;
}

ok( scalar_looks_like_sereal($read), "scalar_looks_like_sereal" );

my $decoded_from_file;
decode_sereal( $read, undef, $decoded_from_file );
is( $decoded_from_file, \%Config, "decode_sereal from manual read" );

done_testing();
