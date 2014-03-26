use strict;
use warnings;
package Cache::Meh;

use Carp qw(confess);
use Storable qw(nstore retrieve);
use File::Spec::Functions qw(tmpdir catfile);
use File::Temp qw(tempfile);

# ABSTRACT: A cache of indifferent quality

=head1 SYNOPSIS

    use 5.008;
    use Cache::Meh;

    my $cache = Cache::Meh->new(
        filename => 'blort',
        validity => 10, # seconds
        lookup => sub { 
            my $key = shift;
            really_expensive_operation($key);
        },
    );

    my $value = $cache->get('some_key');

    print "$value\n";

=head1 OVERVIEW

This module is intended to implement a very simple memory cache where the internal
cache state is serialized to disk by L<Storable> so that the data structure
persists beyond a single execution environment which makes it suitable for
things like cron tasks or CGI handlers and the like.

Since this module is intended to be run under Perl 5.8 (but perferably much
much more recent Perls) it sadly eschews fancy object systems like Moo.

Besides, this is a cache of indifferent quality. You probably ought to be
using something awesome like L<CHI> or L<Cache::Cache> or L<Cache>.

=attr filename

This is the filename for your L<Storable> file. Required.

=cut

sub filename {
    my $self = shift;

    return $self->{filename};
}

=attr validity

Pass an argument to set it; no argument to get its current value.

How long keys should be considered valid in seconds.  Each key has an 
insert time; when the insert time + validity is greater than the current 
time, the cache refreshes the cached value by executing the lookup 
function or evicting the key from the cache if no lookup function is provided.

This value defaults to 300 seconds (5 minutes) if not provided.

=cut

sub validity {
    my $self = shift;
    my $validity = shift;

    if ( $validity ) {
        $self->{validity} = $validity+0;
    }

    return $self->{validity};
}

=attr lookup

Pass an argument to set it; no argument to get its current value.

A coderef which is executed when a key is no longer valid or not
found in the cache. The coderef is given the cache key as a parameter.

Optional; no default.

=cut

sub lookup {
    my $self = shift;
    my $coderef = shift;

    if ( ref($coderef) ne "CODE" ) {
        return $self->{lookup};
    }
    else {
        $self->{lookup} = $coderef;
    }

    return $self->{lookup};
}

=method new

A constructor. You must provide the filename. You may optionally provide
a validity time and lookup function.

=cut

sub new {
    my $class = shift;
    my %args = @_;

    my $self = {};

    bless $self, $class;

    confess "You must give a filename" unless exists $args{filename};

    $self->filename($args{filename});

    $self->{'~~~~cache'} = $self->_load();

    if ( exists $args{validity} ) {
        $self->validity($args{validity});
    }
    else {
        $self->validity(300);
    }

    $self->{_path} = 

    $self->lookup($args{lookup}) if exists $args{lookup};

    return $self;
}

sub _load {
    my $self = shift;

    my $fname = catfile(tmpdir(), $self->filename());

    if ( -e $fname && -r _ ) {
        return retrieve($fname);
    }

    return {};
}

sub _store {
    my $self = shift;

    my ($fh, $filename) = tempfile();

    nstore($self->{'~~~~cache'}, $filename) or 
        confess "Couldn't store cache in $filename: $!\n";

    my $fname = catfile(tmpdir(), $self->filename());
    rename $filename, $fname or confess "Couldn't rename $filename to $fname: $!\n";

    return 1;
}

=method get

Takes a key which can be any valid Perl hash key term. Returns the cached
value or undef if no lookup function is defined.

=method set

Takes a key and a value which is inserted into the cache.



1;
