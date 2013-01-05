use strict; use warnings;
package PegLite::Compiler;

use XXX;

sub new {
    my ($class, $peglite_rule) = @_;
    my $self = bless {
        tokens => [],
    }, $class;
    $self->tokenize($peglite_rule);
    return $self;
}

sub compile {
    my ($self) = @_;
    my $tokens = $self->{tokens};
    die unless @$tokens;
    my $got;
    if ($tokens->[0] eq '(') {
        shift @$tokens;
        $got = $self->compile;
        die if not @$tokens or $tokens->[0] !~ /^\)([\?\*\+]?)/;
        $got = {%$got, $self->compile_limits($1)};
        shift @$tokens;
    }
    elsif (@$tokens > 1) {
        $got = ($tokens->[1] eq '|')
            ? $self->compile_any
            : $self->compile_all;
    }
    else {
          die "@$tokens"
    }
    return $got;
}

sub compile_all {
    my ($self) = @_;
    my $tokens = $self->{tokens};
    die unless @$tokens;
    my $all = [];
    while (@$tokens) {
        if ($tokens->[0] eq '(') {
            push @$all, $self->compile;
        }
        elsif ($tokens->[0] =~ /^\)/) {
            last;
        }
        elsif ($tokens->[0] =~ /^\w/) {
            push @$all, $self->compile_ref;
        }
        else {
            die;
        }
    }
    return {
      type => 'all',
      rule => $all,
      min => 1,
      max => 1,
    }
}
=begin

  def compile_any
    fail if @tokens.empty?
    any = []
    until @tokens.empty?
      if @tokens[0] == '('
        any.push compile
      elsif @tokens[0].match /^\)/
        break
      elsif @tokens[0].match /^\w/
        any.push compile_ref
        if not @tokens.empty?
          if @tokens[0] == '|'
            @tokens.shift
          elsif not @tokens[0].match /^\)/
            fail
          end
        end
      else
        fail
      end
    end
    return {
      'type' => 'any',
      'rule' => any,
      'min' => 1,
      'max' => 1,
    }
  end
=cut

sub compile_ref {
    my ($self) = @_;
    my $tokens = $self->{tokens};
    die unless @$tokens;
    my $token = shift @$tokens;
    $token =~ /^(\w+)([\?\*\+]?)$/ or die;
    my ($rule, $quantifier) = ($1, $2);
    return {
        type => 'ref',
        rule => $rule,
        %{$self->compile_limits($quantifier)},
    };
}

sub compile_limits {
    my ($self, $quantifier) = @_;
    return
        $quantifier eq '?' ? { min => 0, max => 1 } :
        $quantifier eq '*' ? { min => 0, max => 0 } :
        $quantifier eq '+' ? { min => 1, max => 0 } :
        { min => 1, max => 1 };
}

my $patterns = [
    qr/^\s+/,
    qr/^(\()/,
    qr/^(\w+[\?\*\+]?)/,
    qr/^(\|)/,
    qr/^(\)[\?\*\+]?)/,
];
sub tokenize {
    my ($self, $text) = @_;
    my $tokens = $self->{tokens} = [];
  TOKEN:
    while (length $text) {
        for my $r (@$patterns) {
            if ($text =~ s/$r//) {
                push @$tokens, $1 if defined $1;
                next TOKEN;
            }
        }
        die "Failed to find next token in '$text'";
    }
}

1;
