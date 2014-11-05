package Pandoc::Walker;
use strict;
use warnings;

our $VERSION = '0.02';

use Scalar::Util qw(reftype);
use parent 'Exporter';
our @EXPORT = qw(walk query transform);

sub transform {
    my $ast    = shift;
    my $action = shift;

    my $reftype = reftype($ast) || ''; 

    if ($reftype eq 'ARRAY') {
        my $i = 0;
        foreach my $item (@$ast) {
            if ((reftype $item || '') eq 'HASH' and $item->{t}) {
                my $res = $action->($item->{t}, $item->{c}, @_);
                if (defined $res) {
                    my @elements = map { transform($_, $action, @_) } @$res;
                    splice @$ast, $i, $i+1, @elements;
                    $i += scalar @elements;
                    next;
                }
            }
            transform($item, $action, @_);
            $i++;
        }
    } elsif ($reftype eq 'HASH') {
        foreach (keys %$ast) {
            transform($ast->{$_}, $action, @_);
        }
    }

    $ast;
}

sub walk(@) {
    my ($ast, $query, @arguments) = @_;

    transform( $ast, sub { $query->(@_); return }, @arguments );
}

sub query(@) {
    my ($ast, $query, @arguments) = @_;

    my $list = [];
    transform( $ast, sub { push @$list, $query->(@_); return; }, @arguments );
    return $list;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Walker - utility functions to traverse Pandoc documents

=head1 SYNOPSIS

    use Pandoc::Walker;
    use JSON;

    my $ast = decode_json(<>);

    # extract all links
    my $links = query $ast, sub {
        my ($key, $value) = @_;
        return unless ($key eq 'Link' or $key eq 'Image');
        return $value->[1][0];
    };

    # print all links
    walk $ast, sub {
        my ($key, $value) = @_;
        return unless ($key eq 'Link' or $key eq 'Image');
        print $value->[1][0];
    };

    # remove of all links
    transform $ast, sub {
        my ($key, $value) = @_;
        return ($key eq 'Link' ? [] : ());
    };

    # replace all links by their link text angle brackets
    use Pandoc::Elements 'Str';
    transform $ast, sub {
        my ($key, $value) = @_;
        return unless $key eq 'Link';
        return (Str "<", $value->[0], Str ">");
    };

=head1 DESCRIPTION

This module provides to helper functions to traverse the abstract syntax tree
of a pandoc document.

=head1 FUNCTIONS

=head2 walk( $ast, $action [, @arguments ] )

Walks an abstract syntax tree and calls an action on every element. Additional
arguments are also passed to the action.

=head2 query( $ast, $query [, @arguments ] )

Walks an abstract syntax tree and applies a query function to extract results.
The query function is expected to return a list. The combined query result is
returned as array reference.

=head2 transform( $ast, $action [, @arguments ] )

Walks an abstract syntax tree and applies an action on every element to either
keep it (if the action returns C<undef>), remove it (if it returns an empty
array reference), or replace it with one or more elements (returned by array
reference or as single value).

=head1 AUTHOR

Jakob Voß E<lt>jakob.voss@gbv.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Pandoc::Elements> for utility functions to build abstract syntax trees of
pandoc documents.

L<Pandoc::Filter> for a higher level application.

Haskell module L<Text.Pandoc.Walk|http://hackage.haskell.org/package/pandoc-types/docs/Text-Pandoc-Walk.html> for the original.

=cut
