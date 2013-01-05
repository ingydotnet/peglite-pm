# This PegLite test shows an address grammar parsing a street address.
# We parse it 3 different ways, to get different desired results.


use strict; use warnings;
use Test::More tests => 3;
use PegLite;
use YAML::XS;

use XXX;

# A sample street address
my $address = <<'...';
John Doe
123 Main St
Los Angeles, CA 90009
...

# Expected result tree for default/plain parsing
my $parse_plain = <<'...';
---
- John Doe
- 123 Main St
- - Los Angeles
  - CA
  - '90009'
...

# Expected result tree using the 'wrap' option
my $parse_wrap = <<'...';
---
address:
- - name:
    - John Doe
  - street:
    - 123 Main St
  - place:
    - - city:
        - Los Angeles
      - state:
        - CA
      - zip:
        - '90009'
...

# Expected result tree from our Custom parser extension
my $parse_custom = <<'...';
---
city: Los Angeles
name: John Doe
state: CA
street: 123 Main St
zipcode: '90008'
...

# Run 3 tests
sub tests {
    # Parse address to an array of arrays
    {
        my $parser = AddressParser->new;
        my $result = $parser->parse($address);
        is YAML::XS::Dump($result), $parse_plain, "Plain parse works";
    };
    # Turn on 'wrap' to add rule name to each result
    {
        my $parser = AddressParser->new(wrap => 1);
        my $result = $parser->parse($address);
        is YAML::XS::Dump($result), $parse_wrap, "Wrapping parse works";
    };
    # Return a custom AST
    {
        my $parser = AddressParserCustom->new;
        my $result = $parser->parse($address);
        is YAML::XS::Dump($result), $parse_custom, "Custom parse works";
    };
}

# This class defines a complete address parser using PegLite
{
    package AddressParser;
    use base 'PegLite';
    use PegLite 'rule';
    rule address => "name street place";
    rule name => qr/(.*?)\n/;
    rule street => qr/(.*?)\n/;
    rule place => "city COMMA _ state __ zip NL";
    rule city => qr/(\w+(?: \w+)?)/;
    rule state => qr/(WA|OR|CA)/;       # Left Coast Rulez
    rule zip => qr/(\d{5})/;
};

# Extend AddressParser
{
    package AddressParserCustom;
    use base 'AddressParser';

    sub address {
        my ($self) = @_;
        my $got = $self->match or return;
        my ($name, $street, $place) = @{$got->[0]};
        my ($city, $state, $zip) = @$place;
        # Make the final AST from the parts collected.
        $self->{got} = {
            name => $name,
            street => $street,
            city => $city,
            state => $state,
            # Show as 'zipcode' instead of 'zip'
            zipcode => $zip,
        };
    }

    # Subtract 1 from the zipcode for fun
    sub zip {
        my ($self) = @_;
        my $got = $self->match or return;
        sprintf "%05d", $got->[0] - 1;
    }
};

tests();
