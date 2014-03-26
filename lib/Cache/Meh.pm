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
    use Digest::SHA qw(sha1);

    my $cache = Cache::Meh->new(
        filename => 'blort',
        validity => 10, # seconds
        lookup => sub { 
            my $key = shift;
            return sha1($key);
        },
    );

    my $value = $cache->get('some_key');

    if ( sha1('some_key') eq $value ) {
        print "equal\n";
    }
    else {
        print "not equal\n";
    }

=head1 OVERVIEW

This module is intended to implement a very simple memory cache where the internal
cache state is serialized to disk by L<Storable> so that the cached data
persists beyond a single execution environment which makes it suitable for
things like cron tasks or CGI handlers and the like.

Cache state is stored to disk when a key is set in the cache; keys are only
purged from the cache when they expire and there is no C<lookup> function
available.  These are arguably bad design decisions which may encourage you
to seek your caching pleasure elsewhere. On the other hand, pull requests
are welcome. 

Since this module is intended to be run under Perl 5.8 (but preferably much
much more recent Perls) it sadly eschews fancy object systems like Moo. It
doesn't require any dependencies beyond core modules.  I maybe would have
called it Cache::Tiny, but then people might use it.

Besides, this is a cache of indifferent quality. You probably ought to be
using something awesome like L<CHI> or L<Cache::Cache> or L<Cache>.

=attr filename

This is the filename for your L<Storable> file. Required.

The file is written to the "temporary" path as provided by L<File::Spec> 
C<tmpdir>. On Unix systems, you may influence this directory by
setting the C<TMPDIR> environment variable.

=cut

sub filename {
    my ($self, $f) = @_;

    if ( defined $f ) {
        $self->{filename} = $f;
    }

    return $self->{filename};
}

=attr validity

Pass an argument to set it; no argument to get its current value.

How long keys should be considered valid in seconds. Arguments must
be positive integers.

Each key has an insert time; when the insert time + validity is greater than
the current time, the cache refreshes the cached value by executing the lookup 
function or evicting the key from the cache if no lookup function is provided.

This value defaults to 300 seconds (5 minutes) if not provided.

=cut

sub validity {
    my $self = shift;
    my $validity = shift;

    if ( defined $validity ) {
        if ( $validity > 0 ) {
            $self->{validity} = int($validity);
        }
        else {
            confess "$validity is not a positive integer\n";
        }
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
a validity time and lookup function. The cache state is loaded (if available)
as part of object construction.

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

    $self->lookup($args{lookup}) if exists $args{lookup};

    return $self;
}

sub _load {
    my $self = shift;

    my $fname = catfile(tmpdir(), $self->filename());

    if ( -e $fname ) {
        if ( -r $fname ) {
            return retrieve($fname);
        }
        else {
            confess "$fname exists but is not readable.\n";
        }
    }

    return {};
}

# This method stores the new cache file into a temporary file, then renames the tempfile
# to the cache state file name, which should help protect against new file write failures,
# leaving at least *some* state that will persist. I guess you could call this "atomic"
# but there are still a ton of race conditions in the IO layer which could bite you in the
# rear-end.

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

=cut

sub get {
    my ($self, $key) = @_;

    if ( exists $self->{'~~~~cache'}->{$key} ) {
        my $i = $self->{'~~~~cache'}->{$key}->{'insert_time'} + $self->validity;
        return $self->{'~~~~cache'}->{$key}->{'value'} if ( time < $i ) ;
    } 

    if ( exists $self->{lookup} && ref($self->{lookup}) eq 'CODE' ) {
        my $value = $self->{lookup}->($key);
        $self->set( $key, $value );
        return $value;
    }

    if ( exists $self->{'~~~~cache'}->{$key} ) {
        delete $self->{'~~~~cache'}->{$key};
        $self->_store();
    }

    return undef;
}

=method set

Takes a key and a value which is unconditionally inserted into the cache. Returns the cache object.

The cache state is serialized during set operations.

=cut

sub set {
    my ($self, $key, $value) = @_;

    $self->{'~~~~cache'}->{$key}->{'value'} = $value;
    $self->{'~~~~cache'}->{$key}->{'insert_time'} = time;

    $self->_store();

    return $self;
}

1;
