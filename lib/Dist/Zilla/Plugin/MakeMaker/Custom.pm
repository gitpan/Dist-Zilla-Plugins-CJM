#---------------------------------------------------------------------
package Dist::Zilla::Plugin::MakeMaker::Custom;
#
# Copyright 2010 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 11 Mar 2010
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Allow a dist to have a custom Makefile.PL
#---------------------------------------------------------------------

our $VERSION = '4.03';
# This file is part of Dist-Zilla-Plugins-CJM 4.06 (January 2, 2012)


use Moose;
use Moose::Autobox;
extends 'Dist::Zilla::Plugin::MakeMaker';
with qw(Dist::Zilla::Role::FilePruner
        Dist::Zilla::Role::HashDumper);

# We're trying to make the template executable before it's filled in,
# so we want delimiters that look like comments:
has '+delim' => (
  default  => sub { [ '##{', '##}' ] },
);

# Get rid of any META.yml we may have picked up from MakeMaker:
sub prune_files
{
  my ($self) = @_;

  my $files = $self->zilla->files;
  @$files = grep { not($_->name =~ /^META\.(?:yml|json)$/ and
                       $_->isa('Dist::Zilla::File::OnDisk')) } @$files;

  return;
} # end prune_files
#---------------------------------------------------------------------


sub get_prereqs
{
  shift->get_default(qw(BUILD_REQUIRES CONFIGURE_REQUIRES PREREQ_PM));
} # end get_prereqs

#---------------------------------------------------------------------


sub get_default
{
  my $self = shift;

  return $self->extract_keys(WriteMakefile => $self->__write_makefile_args, @_);
} # end get_default

has _mmc_running_parent_setup => (
  is   => 'rw',
  init_arg  => undef,
);

has _mmc_share_dir_block => (
  is        => 'rw',
  isa       => 'ArrayRef[Str]',
  init_arg  => undef,
);

has _mmc_perl_prereq => (
  is        => 'rw',
  isa       => 'Maybe[Str]',
  init_arg  => undef,
);

# Nasty hack to collect the parameters generated by MakeMaker:
around fill_in_string => sub {
  my $orig = shift;
  my $self = shift;

  if ($self->_mmc_running_parent_setup) {
    my $data = $_[1];
    $self->_mmc_share_dir_block($data->{share_dir_block})
        if exists $data->{share_dir_block};
    $self->_mmc_perl_prereq(${ $data->{perl_prereq} })
        if exists $data->{perl_prereq};

    return '';
  } else {
    $self->$orig(@_);
  }
};

sub add_file {}                 # Don't let parent class add any files

#---------------------------------------------------------------------
around setup_installer => sub {
  my $orig = shift;
  my $self = shift;

  $self->_mmc_running_parent_setup(1);
  $self->$orig(@_);
  $self->_mmc_running_parent_setup(0);

  my $file = $self->zilla->files->grep(sub { $_->name eq 'Makefile.PL' })->head
      or $self->log_fatal("No Makefile.PL found in dist");

  # Process Makefile.PL through Text::Template:
  my %data = (
     dist    => $self->zilla->name,
     meta    => $self->zilla->distmeta,
     plugin  => \$self,
     version => $self->zilla->version,
     zilla   => \$self->zilla,
     eumm_version    => \($self->eumm_version),
     perl_prereq     => \($self->_mmc_perl_prereq),
     share_dir_block => $self->_mmc_share_dir_block,
  );

  # The STRICT option hasn't been implemented in a released version of
  # Text::Template, but you can apply Template_strict.patch.  Since
  # Text::Template ignores unknown options, this code will still work
  # even if you don't apply the patch; you just won't get strict checking.
  my %parms = (
    STRICT => 1,
    BROKEN => sub { $self->template_error(@_) },
  );

  $self->log_debug("Processing Makefile.PL as template");
  $file->content($self->fill_in_string($file->content, \%data, \%parms));

  return;
}; # end setup_installer

sub template_error
{
  my ($self, %e) = @_;

  # Put the filename into the error message:
  my $err = $e{error};
  $err =~ s/ at template line (?=\d)/ at Makefile.PL line /g;

  $self->log_fatal($err);
} # end template_error

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Dist::Zilla::Plugin::MakeMaker::Custom - Allow a dist to have a custom Makefile.PL

=head1 VERSION

This document describes version 4.03 of
Dist::Zilla::Plugin::MakeMaker::Custom, released January 2, 2012
as part of Dist-Zilla-Plugins-CJM version 4.06.

=head1 SYNOPSIS

In F<dist.ini>:

  [MakeMaker::Custom]
  eumm_version = 0.34  ; the default comes from the MakeMaker plugin

In your F<Makefile.PL>:

  use ExtUtils::MakeMaker;

  ##{ $share_dir_block[0] ##}

  WriteMakefile(
    NAME => "My::Module",
  ##{ $plugin->get_prereqs ##}
  );

  ##{ $share_dir_block[1] ##}

Of course, your F<Makefile.PL> should be more complex than that, or you
don't need this plugin.

=head1 DESCRIPTION

This plugin is for people who need something more complex than the
auto-generated F<Makefile.PL> or F<Makefile.PL> generated by the
L<MakeMaker|Dist::Zilla::Plugin::MakeMaker> or
L<MakeMaker|Dist::Zilla::Plugin::MakeMaker> plugins.

It is a subclass of the L<MakeMaker plugin|Dist::Zilla::Plugin::MakeMaker>,
but it does not write a F<Makefile.PL> for you.  Instead, you write your
own F<Makefile.PL>, which may do anything L<ExtUtils::MakeMaker> is capable of.

This plugin will process F<Makefile.PL> as a template (using
L<Text::Template>), which allows you to add data from Dist::Zilla to
the version you distribute (if you want).  The template delimiters are
C<##{> and C<##}>, because that makes them look like comments.
That makes it easier to have a F<Makefile.PL> that works both before and
after it is processed as a template.

This is particularly useful for XS-based modules, because it can allow
you to build and test the module without the overhead of S<C<dzil build>>
after every small change.

The template may use the following variables:

=over

=item C<$dist>

The name of the distribution.

=item C<$eumm_version>

The minimum version of ExtUtils::MakeMaker required
(from the C<eumm_version> attribute of this plugin).

=item C<$meta>

The hash of metadata (in META 2 format) that will be stored in F<META.json>.

=item C<$perl_prereq>

The minimum version of Perl required (from the prerequisites in the metadata).
May be C<undef>.

=item C<$plugin>

The MakeMaker::Custom object that is processing the template.

=item C<@share_dir_block>

An array of two strings containing the code for loading
C<File::ShareDir::Install> (if it's used by this dist).  Put
S<C<##{ $share_dir_block[0] ##}>> after the S<C<use ExtUtils::MakeMaker>>
line, and put S<C<##{ $share_dir_block[1] ##}>> after the C<WriteMakefile>
call.

=item C<$version>

The distribution's version number.

=item C<$zilla>

The Dist::Zilla object that is creating the distribution.

=back

=head1 METHODS

=head2 get_default

  $plugin->get_default(qw(key1 key2 ...))

A template can call this method to extract the specified key(s) from
the default WriteMakefile arguments created by the normal MakeMaker
plugin and have them formatted into a comma-separated list suitable
for a hash constructor or a function's parameter list.

If any key has no value (or its value is an empty hash or array ref)
it will be omitted from the list.  If all keys are omitted, the empty
string is returned.  Otherwise, the result always ends with a comma.


=head2 get_prereqs

  $plugin->get_prereqs

This is equivalent to

  $plugin->get_default(qw(BUILD_REQUIRES CONFIGURE_REQUIRES PREREQ_PM))

In other words, it returns all the keys that describe the
distribution's prerequisites.

=head1 SEE ALSO

The <ModuleBuild::Custom|Dist::Zilla::Plugin::ModuleBuild::Custom>
plugin does basically the same thing as this plugin, but for
F<Build.PL> (if you prefer L<Module::Build>).


=for Pod::Coverage
add_file
prune_files
setup_installer
template_error

=head1 DEPENDENCIES

MakeMaker::Custom requires L<Dist::Zilla> (4 or later) and
L<Text::Template>.  I also recommend applying F<Template_strict.patch>
to Text::Template.  This will add support for the STRICT option, which
will help catch errors in your templates.

=head1 INCOMPATIBILITIES

You must not use this in conjunction with the
L<MakeMaker|Dist::Zilla::Plugin::MakeMaker> plugin.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Christopher J. Madsen  S<C<< <perl AT cjmweb.net> >>>

Please report any bugs or feature requests
to S<C<< <bug-Dist-Zilla-Plugins-CJM AT rt.cpan.org> >>>
or through the web interface at
L<< http://rt.cpan.org/Public/Bug/Report.html?Queue=Dist-Zilla-Plugins-CJM >>.

You can follow or contribute to Dist-Zilla-Plugins-CJM's development at
L<< http://github.com/madsen/dist-zilla-plugins-cjm >>.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Christopher J. Madsen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut