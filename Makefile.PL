
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "CJM's plugins for Dist::Zilla",
  "AUTHOR" => "Christopher J. Madsen <perl\@cjmweb.net>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Dist-Zilla-Plugins-CJM",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Dist::Zilla::Plugins::CJM",
  "PREREQ_PM" => {
    "CPAN::Meta::Converter" => "2.101550",
    "CPAN::Meta::Requirements" => "2.121",
    "Data::Dumper" => 0,
    "Dist::Zilla" => "4.300009",
    "Dist::Zilla::Plugin::InlineFiles" => 0,
    "Dist::Zilla::Plugin::MakeMaker" => "4.300009",
    "File::Copy" => 0,
    "File::HomeDir" => "0.81",
    "File::Temp" => "0.19",
    "Module::Metadata" => 0,
    "Moose" => 0,
    "Moose::Autobox" => 0,
    "Moose::Role" => 0,
    "Path::Class" => 0,
    "Scalar::Util" => 0,
    "autodie" => 0,
    "namespace::autoclean" => 0,
    "version" => "0.77"
  },
  "TEST_REQUIRES" => {
    "File::pushd" => 0,
    "Parse::CPAN::Meta" => 0,
    "Test::DZil" => 0,
    "Test::More" => "0.88",
    "Try::Tiny" => 0
  },
  "VERSION" => "4.20",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

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



