#---------------------------------------------------------------------
package Dist::Zilla::Plugin::GitVersionCheckCJM;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 15 Nov 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Ensure version numbers are up-to-date
#---------------------------------------------------------------------

our $VERSION = '0.08';
# This file is part of Dist-Zilla-Plugins-CJM 0.09 (April 15, 2010)


use Moose;
use Moose::Autobox;
with(
  'Dist::Zilla::Role::FileMunger',
  'Dist::Zilla::Role::ModuleInfo',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ ':InstallModules' ],
  },
);


use Git ();

#---------------------------------------------------------------------
# Main entry point:

sub munge_files {
  my ($self) = @_;

  # Get the released versions:
  my $git = Git->repository( $self->zilla->root );

  my %released = map { /^v?([\d._]+)$/ ? ($1, 1) : () } $git->command('tag');

  # Get the list of modified but not-checked-in files:
  my %modified = map { $_ => 1 } (
    # Files that need to be committed:
    split(/\0/, scalar $git->command(qw( diff-index -z HEAD --name-only ))),
    # Files that are not tracked by git yet:
    split(/\0/, scalar $git->command(qw( ls-files -oz --exclude-standard ))),
  );

  # Get the list of modules:
  my $files = $self->found_files;

  # Check each module:
  my $errors = 0;
  foreach my $file ($files->flatten) {
    ++$errors if $self->munge_file($file, $git, \%modified, \%released);
  } # end foreach $file

  die "Stopped because of errors\n" if $errors;
} # end munge_files

#---------------------------------------------------------------------
# Check the version of a module:

sub munge_file
{
  my ($self, $file, $git, $modifiedRef, $releasedRef) = @_;

  # Extract information from the module:
  my $pmFile  = $file->name;
  my $pm_info = $self->get_module_info($file);

  my $version = $pm_info->version
      or $self->log_fatal("ERROR: Can't find version in $pmFile");

  # If module version matches dist version, it's current:
  #   (unless that dist has already been released)
  if ($version eq $self->zilla->version) {
    return unless $releasedRef->{$version};
  }

  # If the module hasn't been committed yet, it needs updating:
  #   (since it doesn't match the dist version)
  if ($modifiedRef->{$pmFile}) {
    $self->log("ERROR: $pmFile: $version needs to be updated");
    return 1;
  }

  # If the module's version doesn't match the dist, and that version
  # hasn't been released, that's a problem:
  unless ($releasedRef->{$version}) {
    $self->log("ERROR: $pmFile: $version does not seem to have been released, but is not current");
    return 1;
  }

  # See if we checked in the module without updating the version:
  my $lastChangedRev = $git->command_oneline(
    qw(rev-list -n1 HEAD --) => $pmFile
  );

  my $inRelease = $git->command_oneline(
    qw(name-rev --refs), "refs/tags/$version",
    $lastChangedRev
  );

  # We're ok if the last change was part of the indicated release:
  return if $inRelease =~ m! tags/\Q$version\E!;

  $self->log("ERROR: $pmFile: $version needs to be updated");
  return 1;
} # end munge_file

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Dist::Zilla::Plugin::GitVersionCheckCJM - Ensure version numbers are up-to-date

=head1 VERSION

This document describes version 0.08 of
Dist::Zilla::Plugin::GitVersionCheckCJM, released April 15, 2010
as part of Dist-Zilla-Plugins-CJM version 0.09.

=head1 SYNOPSIS

In your F<dist.ini>:

  [GitVersionCheckCJM]

=head1 DESCRIPTION

This plugin makes sure that module version numbers are updated as
necessary.  In a distribution with multiple module, I like to update a
module's version only when a change is made to that module.  In other
words, a module's version is the version of the last distribution
release in which it was modified.

This plugin checks each module in the distribution, and makes sure
that it matches one of two conditions:

=over

=item 1.

There is a tag matching the version, and the last commit on that
module is included in that tag.

=item 2.

The version matches the distribution's version, and that version has
not been tagged yet (i.e., the distribution has not been released).

=back

If neither condition holds, it prints an error message.  After
checking all modules, it aborts the build if any module had an error.


=for Pod::Coverage
munge_file
munge_files

=head1 ATTRIBUTES

=head2 finder

This FileFinder provides the list of modules that will be checked.
The default is C<:InstallModules>.  The C<finder> attribute may be
listed any number of times.

=head1 DEPENDENCIES

GitVersionCheckCJM requires L<Dist::Zilla> (2.100960 or later).
It also requires L<Git>, which is not on CPAN, but is distributed as
part of C<git>.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Christopher J. Madsen  S<C<< <perl AT cjmweb.net> >>>

Please report any bugs or feature requests to
S<C<< <bug-Dist-Zilla-Plugins-CJM AT rt.cpan.org> >>>,
or through the web interface at
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=Dist-Zilla-Plugins-CJM>

You can follow or contribute to Dist-Zilla-Plugins-CJM's development at
L<< http://github.com/madsen/dist-zilla-plugins-cjm >>.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Christopher J. Madsen.

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
