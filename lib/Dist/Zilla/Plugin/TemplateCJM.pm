#---------------------------------------------------------------------
package Dist::Zilla::Plugin::TemplateCJM;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 24 Sep 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Process templates, including version numbers & changes
#---------------------------------------------------------------------

our $VERSION = '0.08';
# This file is part of Dist-Zilla-Plugins-CJM 0.09 (April 15, 2010)


use Moose;
use Moose::Autobox;
use List::Util ();

# We operate as an InstallTool instead of a FileMunger because the
# prerequisites have not been collected when FileMungers are run.
with(
  'Dist::Zilla::Role::InstallTool',
  'Dist::Zilla::Role::BeforeRelease',
  'Dist::Zilla::Role::ModuleInfo',
  'Dist::Zilla::Role::TextTemplate',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ ':InstallModules' ],
  },
);

sub mvp_multivalue_args { qw(file) }


has changelog => (
  is   => 'ro',
  isa  => 'Str',
  default  => 'Changes',
);


has changes => (
  is   => 'ro',
  isa  => 'Int',
  default  => 1,
);


has template_files => (
  is   => 'ro',
  isa  => 'ArrayRef',
  lazy => 1,
  init_arg => 'file',
  default  => sub { [ 'README' ] },
);


#---------------------------------------------------------------------
# Main entry point:

sub setup_installer {
  my ($self) = @_;

  my $files = $self->zilla->files;

  # Get release date & changes from Changes file:
  my $changelog = $self->changelog;
  my $changesFile = $files->grep(sub{ $_->name eq $changelog })->head
      or die "No $changelog file\n";

  my ($release_date, $changes) = $self->check_Changes($changesFile);

  # Process template_files:
  my %data = (
     changes => $changes,
     date    => $release_date,
     dist    => $self->zilla->name,
     meta    => $self->zilla->distmeta,
     t       => \$self,
     version => $self->zilla->version,
     zilla   => \$self->zilla,
  );

  $data{dist_version} = $data{version};

  # The STRICT option hasn't been implemented in a released version of
  # Text::Template, but you can apply Template_strict.patch.  Since
  # Text::Template ignores unknown options, this code will still work
  # even if you don't apply the patch; you just won't get strict checking.
  my %parms = (
    STRICT => 1,
    BROKEN => sub { $self->template_error(@_) },
  );

  my $any = $self->template_files->any;

  foreach my $file ($files->grep(sub { $_->name eq $any })->flatten) {
    $self->log('Processing ' . $file->name);
    $self->_cur_filename($file->name);
    $self->_cur_offset(0);
    $file->content($self->fill_in_string($file->content, \%data, \%parms));
  } # end foreach $file

  # Munge POD sections in modules:
  $files = $self->found_files;

  foreach my $file ($files->flatten) {
    $self->munge_file($file, \%data, \%parms);
  } # end foreach $file
} # end setup_installer

#---------------------------------------------------------------------
# Make sure we have a release date:

has _release_date => (
  is       => 'rw',
  isa      => 'Str',
  init_arg => undef,
);

sub before_release
{
  my $self = shift;

  my $release_date = $self->_release_date;

  $self->log_fatal(["Invalid release date in %s: %s",
                    $self->changelog, $release_date ])
      if not $release_date or $release_date =~ /^[[:upper:]]+$/;

} # end before_release

#---------------------------------------------------------------------
# Make sure that we've listed this release in Changes:
#
# Returns:
#   A list (release_date, change_text)

sub check_Changes
{
  my ($self, $changesFile) = @_;

  my $file = $changesFile->name;

  my $version = $self->zilla->version;

  # Get the number of releases to include from Changes:
  my $list_releases = $self->changes;

  # Read the Changes file and find the line for dist_version:
  open(my $Changes, '<', \$changesFile->content) or die;

  my ($release_date, $text);

  while (<$Changes>) {
    if (/^(\d[\d._]*)\s+(.+)/) {
      die "ERROR: $file begins with version $1, expected version $version"
          unless $1 eq $version;
      $release_date = $2;
      $text = '';
      while (<$Changes>) {
        last if /^\S/ and --$list_releases <= 0;
        $text .= $_;
      }
      $text =~ s/\s*\z/\n/;     # Normalize trailing whitespace
      die "ERROR: $file contains no history for version $version"
          unless length($text) > 1;
      last;
    } # end if found the first version in Changes
  } # end while more lines in Changes

  close $Changes;

  # Report the results:
  die "ERROR: Can't find any versions in $file" unless $release_date;

  chomp $text;

  $self->log("Version $version released $release_date");
  $self->zilla->chrome->logger->log($text); # No prefix

  $self->_release_date($release_date); # Remember it for before_release

  return ($release_date, $text);
} # end check_Changes

#---------------------------------------------------------------------
# Process all POD sections of a module as templates:

sub munge_file
{
  my ($self, $file, $dataRef, $parmsRef) = @_;

  # Extract information from the module:
  my $pmFile  = $file->name;
  my $pm_info = $self->get_module_info($file);

  my $version = $pm_info->version
      or die "ERROR: Can't find version in $pmFile";

  $self->log("$pmFile: VERSION $version");

  $dataRef->{version} = "$version";
  $dataRef->{module}  = $pm_info->name;
  $dataRef->{pm_info} = \$pm_info;

  $parmsRef->{FILENAME} = $pmFile;

  # Process all POD sections:
  my $content = $file->content;

  $self->_cur_filename($pmFile);
  $self->_cur_content(\$content);

  $content =~ s{( ^=(?!cut\b)\w .*? (?: \z | ^=cut\b ) )}
               {
                 $self->_cur_offset($-[0]);
                 $self->fill_in_string($1, $dataRef, $parmsRef)
               }xgems;

  # And comments at BOL:
  $content =~ s{( ^\#.+ )}
               {
                 $self->_cur_offset($-[0]);
                 $self->fill_in_string($1, $dataRef, $parmsRef)
               }xgem;

  $file->content($content);
  $self->_cur_content(undef);

  return;
} # end munge_file
#---------------------------------------------------------------------


sub build_instructions
{
  my ($self, $indent) = @_;

  $indent = "\t" unless defined $indent;

  # Compute build instructions:
  my $builder = $self->zilla->files
                     ->map(sub{ $_->name })
                     ->grep(sub{ /^(?:Build|Makefile)\.PL$/ })
                     ->sort->head;

  $self->log_fatal("Unable to locate Build.PL or Makefile.PL in distribution\n".
                   "TemplateCJM must come after ModuleBuild or MakeMaker")
      unless $builder;

  my $build = ($builder eq 'Build.PL' ? './Build' : 'make');

  join("\n", map { $indent . $_ }
    "perl $builder",
    "$build",
    "$build test",
    "$build install",
  );
} # end build_instructions
#---------------------------------------------------------------------


sub dependency_link
{
  my ($self, $module) = @_;

  my $meta = $self->zilla->distmeta;
  my $ver;

  for my $key (qw(requires recommends)) {
    last if defined($ver = $meta->{$key}{$module});
  } # end for each $key

  $self->log("WARNING: Can't find $module in prerequisites")
      unless defined $ver;

  if ($ver) { "L<$module> ($ver or later)" }
  else      { "L<$module>" }
} # end dependency_link
#---------------------------------------------------------------------


sub dependency_list
{
  my ($self) = @_;

  my $requires = $self->zilla->distmeta->{requires};

  my @modules = sort grep { $_ ne 'perl' } keys %$requires;

  unshift @modules, 'perl' if $requires->{perl};

  my $width = List::Util::max(map { length $_ } @modules) + 1;

  my $text = sprintf("  %-${width}s %s\n  ", 'Package', 'Minimum Version');
  $text .= ('-' x $width) . " ---------------\n";

  ++$width;

  foreach my $req (@modules) {
    $text .= sprintf("  %-${width}s %s\n", $req, $requires->{$req} || '');
  }

  $text =~ s/\s+\z//;           # Remove final newline

  $text;
} # end dependency_list

#---------------------------------------------------------------------
# Report a template error and die:

has _cur_filename => (
  is   => 'rw',
  isa  => 'Str',
);

# This is a reference to the text we're processing templates in
has _cur_content => (
  is   => 'rw',
  isa  => 'Maybe[ScalarRef]',
);

# This is the position in _cur_content where this template began
has _cur_offset => (
  is   => 'rw',
  isa  => 'Int',
);

sub template_error
{
  my ($self, %e) = @_;

  # Calculate the line number where the template started:
  my $offset = $self->_cur_offset;
  if ($offset) {
    $offset = substr(${ $self->_cur_content }, 0, $offset) =~ tr/\n//;
  }

  # Put the filename & line number into the error message:
  my $err = $e{error};
  my $fn  = $self->_cur_filename;
  $err =~ s/ at template line (\d+)/ " at $fn line " . ($1 + $offset) /eg;

  die $err;
} # end template_error

#---------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Dist::Zilla::Plugin::TemplateCJM - Process templates, including version numbers & changes

=head1 VERSION

This document describes version 0.08 of
Dist::Zilla::Plugin::TemplateCJM, released April 15, 2010
as part of Dist-Zilla-Plugins-CJM version 0.09.

=head1 SYNOPSIS

In your F<dist.ini>:

  [TemplateCJM]
  changelog = Changes      ; this is the default
  changes   = 1            ; this is the default
  file      = README       ; this is the default

=head1 DESCRIPTION

This plugin is the successor to L<Module::Build::DistVersion>.
It performs the following actions:

=over

=item 1.

It opens the F<Changes> file, and finds the first version listed.  The
line must begin with the version number, and everything after the
version number is considered to be the release date.  The version
number from Changes must match Dist::Zilla's idea of the
distribution version, or the process stops here with an error.

=item 2.

It processes each template file with Text::Template.  Template files
are specified with the L<< C<file> attribute|/"file" >>.  Any number of
templates may be present.

Each template may use the following variables:

=over

=item C<$changes>

The changes in the current release.  This is a string containing all
lines in F<Changes> following the version/release date line up to (but
not including) the next line that begins with a non-whitespace
character (or end-of-file).  The string does B<not> end with a newline
(since version 0.08).

You can include the changes from more than one release by setting the
L<< C<changes> attribute/"changes" >>.  This is useful when you make a
major release immediately followed by a bugfix release.

=item C<$date>

The release date as it appeared in F<Changes>.

=item C<$dist>

The name of the distribution.

=item C<%meta>

The hash of metadata that will be stored in F<META.yml>.

=item C<$t>

The TemplateCJM object that is processing the template.

=item C<$version>

The distribution's version number.  (Also available as C<$dist_version>.)

=item C<$zilla>

The Dist::Zilla object that is creating the distribution.

=back

=item 3.

For each module to be installed, it processes each POD section and
each comment that starts at the beginning of a line through
Text::Template.

Each section may use the same variables as step 2, plus the following:

=over

=item C<$module>

The name of the module being processed (i.e., its package).

=item C<$pm_info>

A Module::Build::ModuleInfo object containing information about the
module.  (Note that the filename in C<$pm_info> will not be correct.)

=item C<$version>

The module's version number.  This may be different than the
distribution's version, which is available as C<$dist_version>.

=back

=back

It also peforms a L<BeforeRelease|Dist::Zilla::Role::BeforeRelease>
check to ensure that the relase date in the changelog is not a single
uppercase word.  (I set the date to NOT until I'm ready to release.)


=for Pod::Coverage
before_release
check_Changes
munge_file
mvp_multivalue_args
setup_installer
template_error

=head1 ATTRIBUTES

=head2 changelog

This is the name of the F<Changes> file.  It defaults to F<Changes>.


=head2 changes

This is the number of releases to include in the C<$changes> variable
passed to templates.  It defaults to 1 (meaning only changes in the
current release).  This is useful when you make a major release
immediately followed by a bugfix release.


=head2 file

This is the name of a file to process with Text::Template in step 2.
The C<file> attribute may be listed any number of times.  If you don't
list any C<file>s, it defaults to F<README>.  If you do specify any
C<file>s, then F<README> is not processed unless explicitly specified.


=head2 finder

This FileFinder provides the list of files that are processed in step
3.  The default is C<:InstallModules>.  The C<finder> attribute may be
listed any number of times.

=head1 METHODS

=head2 build_instructions

  $t->build_instructions( [$prefix] )

A template can use this method to add build instructions for the
distribution (normally used in README).  C<$prefix> is prepended to
each line, and defaults to a single TAB.

It returns either

	perl Build.PL
	./Build
	./Build test
	./Build install

or

	perl Makefile.PL
	make
	make test
	make install

depending on whether your distribution includes a Build.PL.  The
string will NOT end with a newline.

It throws an error if neither Build.PL nor Makefile.PL is found.


=head2 dependency_link

  $t->dependency_link('Foo::Bar')

A template can use this method to add a link to the documentation of a
required module.  It returns either

  L<Foo::Bar> (VERSION or later)

or

  L<Foo::Bar>

depending on whether VERSION is non-zero.  (It determines VERSION by
checking C<requires> and C<recommends> in your prerequisites.)


=head2 dependency_list

  $t->dependency_list

A template can use this method to add a list of required modules.
It returns a string like:

  Package                Minimum Version
  ---------------------- ---------------
  perl                    5.8.0
  List::Util
  Moose                   0.90

If C<perl> is one of he dependencies, it is listed first.  All other
dependencies are listed in ASCIIbetical order.  The string will NOT
end with a newline.

=head1 DEPENDENCIES

TemplateCJM requires L<Dist::Zilla> (2.100960 or later) and
L<Text::Template>.  I also recommend applying F<Template_strict.patch>
to Text::Template.  This will add support for the STRICT option, which
will help catch errors in your templates.

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
