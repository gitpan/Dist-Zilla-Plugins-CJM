
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'Dist::Zilla::Plugins::CJM',
                       'DISTNAME' => 'Dist-Zilla-Plugins-CJM',
                       'CONFIGURE_REQUIRES' => {
                                                 'ExtUtils::MakeMaker' => '6.31'
                                               },
                       'AUTHOR' => 'Christopher J. Madsen <perl@cjmweb.net>',
                       'BUILD_REQUIRES' => {},
                       'ABSTRACT' => 'CJM\'s plugins for Dist::Zilla',
                       'EXE_FILES' => [],
                       'VERSION' => '0.09',
                       'PREREQ_PM' => {
                                        'Scalar::Util' => '0',
                                        'File::HomeDir' => '0.81',
                                        'Moose::Autobox' => '0.09',
                                        'List::Util' => '0',
                                        'Module::Build::ModuleInfo' => '0.28',
                                        'File::Temp' => '0',
                                        'Dist::Zilla' => '2.100960',
                                        'autodie' => '0',
                                        'Path::Class' => '0',
                                        'Moose' => '0.65'
                                      },
                       'LICENSE' => 'perl'
                     );


delete $WriteMakefileArgs{BUILD_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.56) };

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



