#!/usr/bin/perl

package Method::Specialize;

use strict;
use warnings;

use Carp;
use Class::MethodCache qw(:all);
use Scalar::Util qw(refaddr weaken);
use Sub::Name qw(subname);

use namespace::clean;

use Sub::Exporter -setup => {
    exports => [qw(
        specializing_method
        generate_specializing
        install_specialized
        wrap_specialized
    )],
    groups => {
        default => [qw(specializing_method)],
    },
};

sub specializing_method ($$) {
    my ( $name, $generator ) = @_;

    my $class = caller();

    my $fq = "$class\::$name";

    subname "$class\::specialize<$name>", $generator;

    my $code = generate_specializing($name, $generator);

    subname $fq, $code;

    no strict 'refs';
    *$fq = $code;
}

sub generate_specializing {
    my ( $name, $generator ) = @_;

    my $self;

    my $copy = $self = sub {
        my $class = ref($_[0]) || $_[0];

        my $specialized = $class->$generator();

        install_specialized($class, $name, $self, $specialized);

        goto $specialized;
    };

    weaken($self); # weaken the closed over var to prevent a circular ref

    return $self;
}

sub install_specialized {
    my ( $class, $name, $normal, $specialized ) = @_;

    my $glob = "$class\::$name";

    if ( !get_cvgen($glob) and my $cv = get_cv($glob) ) {
        my $wrapped = wrap_specialized($class, $name, $cv, $specialized);
        subname "$class\::$name", $wrapped;
        set_cv($glob, $wrapped);
    } else {
        set_cached_method($glob, $specialized);
    }

    return $specialized;
}

# This is a reimplementation of the GvCVGEN logic for when you replace the
# generating method with itself
# it's necessary because if we set CVGEN for real perl will delete the entry
# and then traverse our linearized isa without the current class, so the
# specializing generator is gone
# this could be done in XS by hijacking the nextstate's ppaddr of the
# specialized version and stashing data in the SvANY of the CV, making it
# virtually no cost compared to this goto() using version.
sub wrap_specialized {
    my ( $class, $name, $normal, $specialized ) = @_;

    my $gen = get_class_gen($class);


    sub {
        if ( (ref($_[0]) || $_[0]) eq $class ) {
            if ( get_class_gen($class) == $gen ) {
                goto $specialized;
            } else {
                no strict 'refs';
                set_cv *{"$class\::$name"}, $normal;
            }
        }

        goto $normal;
    }
}

sub DESTROY {

}

__PACKAGE__

__END__

=pod

=head1 NAME

Method::Specialize - Generate per-subclass variants for your methods.

=head1 SYNOPSIS

	use Method::Specialize;

=head1 DESCRIPTION

=head1 VERSION CONTROL

This module is maintained using Darcs. You can get the latest version from
L<http://nothingmuch.woobling.org/code>, and use C<darcs send> to commit
changes.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

	Copyright (c) 2008 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut
