# NAME

Cache::Meh - A cache of indifferent quality

# VERSION

version 0.01

# SYNOPSIS

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

# OVERVIEW

This module is intended to implement a very simple memory cache where the internal
cache state is serialized to disk by [Storable](http://search.cpan.org/perldoc?Storable) so that the cached data
persists beyond a single execution environment which makes it suitable for
things like cron tasks or CGI handlers and the like.

Cache state is stored to disk when a key is set in the cache; keys are only
purged from the cache when they expire and there is no `lookup` function
available.  These are arguably bad design decisions which may encourage you
to seek your caching pleasure elsewhere. On the other hand, pull requests
are welcome. 

Since this module is intended to be run under Perl 5.8 (but perferably much
much more recent Perls) it sadly eschews fancy object systems like Moo.

Besides, this is a cache of indifferent quality. You probably ought to be
using something awesome like [CHI](http://search.cpan.org/perldoc?CHI) or [Cache::Cache](http://search.cpan.org/perldoc?Cache::Cache) or [Cache](http://search.cpan.org/perldoc?Cache).

# ATTRIBUTES

## filename

This is the filename for your [Storable](http://search.cpan.org/perldoc?Storable) file. Required.

The file is written to the "temporary" path as provided by [File::Spec](http://search.cpan.org/perldoc?File::Spec) 
`tmpdir`. On Unix systems, you may influence this directory by
setting the `TMPDIR` environment variable.

## validity

Pass an argument to set it; no argument to get its current value.

How long keys should be considered valid in seconds. Arguments must
be positive integers.

Each key has an insert time; when the insert time + validity is greater than
the current time, the cache refreshes the cached value by executing the lookup 
function or evicting the key from the cache if no lookup function is provided.

This value defaults to 300 seconds (5 minutes) if not provided.

## lookup

Pass an argument to set it; no argument to get its current value.

A coderef which is executed when a key is no longer valid or not
found in the cache. The coderef is given the cache key as a parameter.

Optional; no default.

# METHODS

## new

A constructor. You must provide the filename. You may optionally provide
a validity time and lookup function. The cache state is loaded (if available)
as part of object construction.

## get

Takes a key which can be any valid Perl hash key term. Returns the cached
value or undef if no lookup function is defined.

## set

Takes a key and a value which is unconditionally inserted into the cache. Returns the cache object.

The cache state is serialized during set operations.

# AUTHOR

Mark Allen <mrallen1@yahoo.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Mark Allen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
