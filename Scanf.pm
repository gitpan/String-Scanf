package String::Scanf;

require 5;

require Exporter;

use Carp;

use strict;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(sscanf);

my $debug  = 0;

my %compat;

=head1 NAME

sscanf - emulate the sscanf() of the C<C> stdio library

=head1 SYNOPSIS

	use String::Scanf;	# this will import sscanf() into the
				# current namespace

	@values = sscanf($scanf_format_string, $scalar_to_scan);

	# the default scan target is the $_
	@values = sscanf($scanf_format_string);

	# converting scanf formats to regexps (::format_to_re
	# is never exported to the current namespace)

	$regexp_string = String::Scanf::format_to_re($scanf_format_string);

=head1 DESCRIPTION

Perl sscanf() can be used very much like the C<C> stdio sscanf(), for
detailed sscanf() documentation please refer to your usual
documentation resources. The supported formats are: C<[diuoxefgsc]>
and the character class C<[]>.

B<All> of the format must match. If not, an empty list is returned
and all the values end up empty.

The C<c> format returns an anonymous list (see perlref)
containing the numeric values of the characters it matched.

The ::format_to_re() function may be helpful if one wants to
develop her own parsing routines.

=head1 FEATURES

Embedded underscores are accepted in numbers just like in Perl, even
in octal/hexadecimal numbers (Perl does not currently support
this). Please note the word B<embedded>, not leading or trailing.

If the C<oh> formats are used, the octal/hexadecimal interpretation
is forced even without the leading C<0> or C<0x>.

=head1 LIMITATIONS

Certain features of the C sscanf() are unsupported:

	* the formats C<[npSC]>
	* in the C<[efg]> formats the C<INF> and various C<NaN>s

The numeric formats are scanned in as strings, this meaning that
numeric overflows may occur. For example: C<1.2345e67890> will match
the C<%g> format but in most machines Perl cannot handle that large
floating point numbers and bizarre values may end up in the Perl
variable. Similar caveats apply for integer-type numbers. Results of
such huge numbers (or very tiny numbers, say, C<1.24345e-67890>) are
implementation-defined, which translates quite often as I<garbage>.
B<NOTE>: if you really want B<Big> numbers please consider
using the C<Math::BigInt> and C<Math::BigFloat>, these packages come
standard with Perl 5, or the C<Math::Pari> package, available from
C<CPAN>.

For Perl <integers> and I<floating point numbers> are the same thing.
Also, the possible C<hl> modifiers for the I<integers> mean nothing:
they are accepted but still they do nothing because Perl does not care
about short/long integer differences.

The character class format is not so rigorously checked for
correctness that an illegal character class definition could
not be sneaked in. For example C<[z-a,X]> is a C<bad> example:
perfectly illegal as a character class but C<String::Scanf> will
happily accept it. Beware.

The ::format_to_re() only does the scanf format -> regular expression
conversion. It ignores tricky things like the C<c> format (see above)
and the %n$ argument reordering. If you want these, you may as well use
the full ::sscanf().

=head1 EXAMPLES

	# business as usual

        ($i, $s, $x) = sscanf('%d %3s %g', ' -5_678     abc 3.14e-99 9');

	# 'skip leading whitespace': $x becomes 42 despite the leading space
	# 'the illegal character': $y becomes 'ab' despite the '3'
	# 'c' format: $z becomes [120 100], the numeric values of 'x'
	# and 'd' (assuming ASCII or ISO Latin 1)

	($x, $y, $z) = sscanf('%i%3[a-e]%2c', ' 42acxde');

	# reordering the arguments: $a becomes 34, $b becomes 12

	($a, $b) = sscanf('%2$d %1$d', '12 34');

	# converting scanf formats to regexps

        $re = String::Scanf::format_to_re('%x');

More examples in the test set C<t/scanf.t>.

=head1 COMPATIBILITY

Versions prior to 1.3 scanned "0123" with [efg] formats as an octal number.
C<C> sscanf would, however, understand this as a decimal number.  Versions
starting from 1.3 will use the decimal interpretation.  If you have old code
that depends on the old interpretation, you can say

	String::Scanf::set_compat('efg_oct' => 1);

=head1 INTERNALS

The Perl C<sscanf()> turns the C<C>-C<stdio> style C<sscanf()> format
string into a Perl regexp (see perlre) which captures the wanted
values into submatches and returns the submatches as a list.

Originally written for purposes of debugging but also useful
for educational purposes:

	String::Scanf::debug(1);	# turn on debugging: shows the regexps
				# used and the possible reordering list
				# and the character (%c) conversion targets
	String::Scanf::debug(0);		# turn off debugging
	print String::Scanf::debug(), "\n";	# the current debug status

=head1 CREATED

v1.1, -Id: Scanf.pm,v 1.8 1995/12/27 08:32:28 jhi Exp -

=head1 AUTHOR

Jarkko Hietaniemi, C<Jarkko.Hietaniemi@iki.fi>

=cut

sub debug {
  if (@_) {
    if ($_[0] =~ /^\d+/) {
      $debug = $_[0];
    } elsif ($debug) {
      print STDERR @_;
    }
  } else {
    $debug;
  }
}

sub set_compat {
    my %set_compat = @_;
    if (exists $set_compat{'efg_oct'}) {
	$compat{'efg_oct'} = $set_compat{'efg_oct'};
    }
}

sub _do_percent {
  my ($i, $orderidx, $ignore, $width, $hl, $format,
      $reord, $num, $c_format, $a_format) = @_;
  my ($re, $is_num, $is_oct, $is_hex, $is_c);

  undef $re;

  push(@{$reord}, $orderidx) if (defined $orderidx);

  push(@{$a_format}, $format);

  $is_num = 0;
  $is_oct = 0;
  $is_hex = 0;
  $is_c   = 0;

  if ($format =~ /^\[/) {
    $re = $format;
  } elsif ($format =~ /^[diuoxefgsc]$/) {
    if (defined $hl) {
      if ($hl eq 'h' and $format =~ /^[dioux]$/) {
	# do nothing part 1
      } elsif ($hl eq 'l' and $format =~ /^[diouxefg]$/) {
	# do nothing part 2
      } else {
	croak "sscanf: % '$hl' modifier for format '$format' unsupported";
      }
    }
    if ($format eq 'c') {
      $is_c = 1;
      $re = '[\000-\377]';
    } else {
      if ($format =~ /^[diu]$/) {
	$re = '\d+';
	$re = '[\+\-]?'.$re unless ($format eq 'u');
	$is_num = 1;
      } elsif ($format eq 'o') {
	$re = '(?:0[oO])?[0-7]+(?:_[0-7]+)?';
	$is_num = 1;
	$is_oct = 1;
      } elsif ($format eq 'x') {
	$re = '(?:0[xX])?[0-9a-fA-F]+(?:_[0-9a-fA-F]+)*';
	$is_num = 1;
	$is_hex = 1;
      } elsif ($format =~ /^[efg]$/) {
	# NOTE: INF NaN NaNQ NaNS unimplemented
	$re = '[\+\-]?(?:(?:(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][\+\-]?\d+)?))';
	$is_num = 1;
      } elsif ($format eq 's') {
	$re = '[\000-\377]';
      }
    }
  } elsif ($format eq 'n') {
    croak "sscanf: % format 'n' for counting unsupported";
  } elsif ($format eq 'p') {
    croak "sscanf: % format 'p' for pointers unsupported";
  } elsif ($format =~ /^[SC]$/) {
    croak "sscanf: % formats S and C for wide characters unsupported";
  } else {
    croak "sscanf: % format '$format' unknown";
  }

  push(@{$num},
       ($is_num ? 'n' : '') . ($is_oct ? 'o' : '') . ($is_hex ? 'h' : ''));
  ${$c_format}{$$i} = 1 if ($is_c);

  $re = $re."{0,$width}" if (defined $width);

  $re = "($re)" unless ($ignore or $format eq '%');

  $re = '\s*'.$re unless ($format =~ /^[cCn\[]/);

  $$i++;

  $re;
}

sub _do_format {
  my $re = shift;
  my $i        = 0;
  my $num      = [];
  my $reord    = [];
  my $c_format = {};
  my $a_format = [];

  $re =~
  s/
   %(?:(\d+)\$)?(\*)?(\d+)?([hl])?(\[(?:[\^\]])?.*\]|.)
   /
   &_do_percent(\$i, $1, $2, $3, $4, $5, $reord, $num, $c_format, $a_format)
   /gexo;

  $re =~ s/\\d([+*])/\\d$1(?:_\\d+)*/g;	# allow embedded underscores
  $re =~ s/\s+(?:\\s\*)?/\\s+/g;	# yes, this looks funny

  debug("sscanf: re = '$re'\n");

  ($re, $num, $reord, $c_format, $a_format);
}

sub _do_reorder {
  my ($reord, @scan) = @_;
  my $nreord = @{$reord};
  my $nscan  = @scan;
  my @reord  = ();

  debug("sscanf: reord = '@{$reord}'\n");

  if ($nreord == $nscan) {
    my $i;

    for $i (@{$reord}) {
      croak "sscanf: % reordering: subformats 1..$nscan, reordered $i"
	if ($i < 1 or $i > $nscan);
      $reord[$i-1] = shift(@scan);
    }
  } else {
    croak "sscanf: % reordering: $nscan subformats, reordering $nreord";
  }

  @reord;
}

sub _do_num {
  my ($num, $a_format, @scan) = @_;
  my (@num) = ();
  my ($i, $scan, $format, $is_n);

  for $i (@{$num}) {
    $scan   = shift(@scan);
    $format = shift(@{$a_format});
    if ($scan =~ /^0/ && $format =~ /^[efg]/i) {
	if ($compat{'efg_oct'}) {
	    $scan =~ s/\.$//; # let "0123." parse octally
	} else {
	    $scan =~ s/^0+//; # let "0123"  parse decimally
	}
    }
    $scan =~ tr/_//d if ($is_n = $i =~ /n/);
    $scan =~ s/^/0/  if ($i =~ /o/ and $scan !~ /^0/);
    $scan =~ s/^/0x/ if ($i =~ /h/ and $scan !~ /^0[xX]/);
    push(@num, $is_n ? eval $scan : $scan);
  }

  @num;
}

sub _do_c_format {
  my ($c_format, @scan) = @_;
  my @c = ();
  my ($v, $i);
  
  debug("sscanf: c_format = '@{[keys %{$c_format}]}'\n");

  $i = 0;
  for $v (@scan) {
    push(@c, exists ${$c_format}{$i++} ? [ map { ord } split(//, $v) ] : $v);
  }
  
  @c;
}

sub format_to_re {
  my ($re) = _do_format($_[0]);
  
  $re;
}

sub sscanf {
  my ($re, $num, $reord, $c_format, $a_format) = &_do_format(shift);
  my ($input) = @_ ? shift : $_;
  my (@scan) = ($input =~ /$re/);

  @scan = _do_num($num, $a_format, @scan);
  @scan = _do_c_format($c_format, @scan) if (%{$c_format});
  @scan = _do_reorder($reord, @scan)     if (@{$reord});
  
  @scan;
}

1;

# eof
