
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'CJM\'s plugins for Dist::Zilla',
  'AUTHOR' => 'Christopher J. Madsen <perl@cjmweb.net>',
  'BUILD_REQUIRES' => {
    'Dist::Zilla::Tester' => '4.101800',
    'File::pushd' => '0',
    'Test::More' => '0.88'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Dist-Zilla-Plugins-CJM',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Dist::Zilla::Plugins::CJM',
  'PREREQ_PM' => {
    'CPAN::Meta::Converter' => '2.101550',
    'Dist::Zilla' => '3',
    'File::Copy' => '0',
    'File::HomeDir' => '0.81',
    'File::Temp' => '0.19',
    'List::Util' => '0',
    'Module::Build::ModuleInfo' => '0.28',
    'Moose' => '0.65',
    'Moose::Autobox' => '0.09',
    'Path::Class' => '0',
    'Scalar::Util' => '0',
    'autodie' => '0',
    'version' => '0.77'
  },
  'VERSION' => '3.03',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



