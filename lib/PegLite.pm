use strict; use warnings;
package PegLite;
use PegLite::Compiler;
use Exporter 'import';

use XXX;

our $VERSION = '0.0.3';
our $PegLiteTopRule;
our @EXPORT_OK = ('rule');

sub rule {
    my ($name, $rule) = @_;
    $PegLiteTopRule ||= $name;
    if (ref $rule eq 'Regexp') {
        my $regex = $rule; # Regexp.new(rule.to_s.sub(/:/, ':\\A'))
        $rule = {
          type => 'rgx',
          rule => $regex,
          min => 1,
          max => 1,
        }
    }
    elsif (not ref $rule) {
        $rule = PegLite::Compiler->new($rule)->compile;
    }
    else {
        die "Don't know how to make rule 'rule_$name' from '$rule'"
    }
    my $package = caller;
    no strict 'refs';
    *{"$package\::rule_$name"} = sub {
        my ($self) = @_;
        $self->match($rule);
    }
}

# TODO define all the Pegex Atoms here
rule _ => qr/\s*/;
rule __ => qr/\s+/;
rule LCURLY => qr/\{/;
rule RCURLY => qr/\}/;
rule LSQUARE => qr/\[/;
rule RSQUARE => qr/\]/;
rule EQUAL => qr/=/;
rule COMMA => qr/,/;
rule COLON => qr/:/;
rule PLUS => qr/\+/;
rule NL => qr/\n/;
rule EOL => qr/\r?\n/;
$PegLiteTopRule = undef;

sub new {
    my $class = shift;
    my $self = bless {
        wrap => 0,
        debug => 0,
        input => undef,
        @_,
    }, $class;

    $self->{pos} = 0;
    $self->{far} = 0;
    return $self;
}

sub parse {
    my ($self, $input, $top) = @_;
    $input ||= $self->input
        or die "PegLite parse() method requires an input string";
    $top ||= $PegLiteTopRule || 'top';
    $self->{input} = $input;
    my $got = $self->match_ref($top);
    $self->failure if $self->{pos} < length $self->{input};
    return exists $self->{got}
        ? $self->{got}
        : $got->[0];
}

sub match {
    my ($self, $rule) = @_;
    if (not($rule) or ref($rule) ne 'HASH') {
        $rule ||= do{
            my $name = (caller(1))[3];
            $name =~ s/.*:://;
            $name;
        };
        my $method_name = "rule_$rule";
        return $self->$method_name if $self->can($method_name);
        die "Can't find rule for '$rule'";
    }

    my ($pos, $count, $matched, $type, $child, $min, $max) =
      ($self->{pos}, 0, [], @{$rule}{qw(type rule min max)});

    my $method = "match_$type";
    while (my $result = $self->$method($child)) {
        my $pos = $self->{pos};
        $count++;
        if (ref($result) eq 'ARRAY') {
            push @$matched, @$result;
        }
        else {
            push @$matched, $result;
        }
        last if $max == 1;
    }

    if ($count >= $min and ($max == 0 or $count <= $max)) {
        return $matched;
    }
    else {
        $self->{pos} = $pos;
        return;
    }
}

sub match_all {
    my ($self, $all) = @_;
    my ($pos, $set, $count) = ($self->{pos}, [], 0);
    for my $elem (@$all) {
        if (my $m = $self->match($elem)) {
            push @$set, @$m;
            $count++;
        }
        else {
            if (($self->{pos} = $pos) > $self->{far}) {
                $self->{far} = $pos;
            }
            return;
        }
    }
    $set = [ $set ] if $count > 1;
    return $set;
}

=begin
  def match_any any
    any.each do |elem|
      if (m = match elem)
        return m
      end
    end
    return
  end
=cut

# TODO move trace/debug out of default match_ref method
sub match_ref {
    my ($self, $ref) = @_;
    $self->trace("Try #{ref}") if $self->{debug};
    my $method = $self->can($ref) || $self->can("rule_$ref")
        or die "No rule defined for '$ref'";
    my $m = $self->$method;
    if ($m) {
        $m = ($self->{wrap} and @$m) ? [{$ref => $m}] : $m;
        $self->trace("Got #{ref}") if $self->{debug};
    }
    else {
        $self->trace("Not #{ref}") if $self->{debug};
    }
    return $m;
}

sub match_rgx {
    my ($self, $regex) = @_;
    substr($self->{input}, $self->{pos}) =~ $regex or return;

    $self->{pos} += $+[0];
    no strict 'refs';
    my $match = [ map $$_, 1..$#+ ];
    $match = [ $match ] if $#+ > 1;
    $self->{far} = $self->{pos} if $self->{pos} > $self->{far};
    return $match
}

=begin
  #----------------------------------------------------------------------------
  # Debugging and error reporting support methods
  #----------------------------------------------------------------------------
  def trace action
    indent = !!action.match(/^Try /)
    @indent ||= 0
    @indent -= 1 unless indent
    $stderr.print ' ' * @indent
    @indent += 1 if indent
    snippet = @input[@pos..-1]
    snippet = snippet[0..30] + '...' if snippet.length > 30;
    snippet.gsub! /\n/, "\\n"
    $stderr.printf "%-30s", action
    $stderr.print indent ? " >#{snippet}<\n" : "\n"
  end

  def failure
    msg = "Parse failed for some reason"
    raise PegexParseError, format_error(msg)
  end

  class PegexParseError < RuntimeError;end
  def format_error msg
    buffer = @input
    position = @far
    real_pos = @pos

    line = buffer[0, position].scan(/\n/).size + 1
    column = position - (buffer.rindex("\n", position) || -1)

    pretext = @input[
      position < 50 ? 0 : position - 50,
      position < 50 ? position : 50
    ]
    context = @input[position, 50]
    pretext.gsub! /.*\n/m, ''
    context.gsub! /\n/, "\\n"

    return <<"..."
Error parsing Pegex document:
  message:  #{msg}
  line:     #{line}
  column:   #{column}
  position: #{position}
  context:  #{pretext}#{context}
  #{' ' * (pretext.length + 10)}^
...
  end
end
=cut

1;
