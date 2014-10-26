use Test::More tests => 11;

diag("Testing Dist-Zilla-Plugins-CJM 4.09");

use_ok('Dist::Zilla::Plugin::ArchiveRelease');
use_ok('Dist::Zilla::Plugin::MakeMaker::Custom');
use_ok('Dist::Zilla::Plugin::Metadata');
use_ok('Dist::Zilla::Plugin::ModuleBuild::Custom');
use_ok('Dist::Zilla::Plugin::RecommendedPrereqs');
use_ok('Dist::Zilla::Plugin::TemplateCJM');
use_ok('Dist::Zilla::Plugin::Test::PrereqsFromMeta');
use_ok('Dist::Zilla::Plugin::VersionFromModule');
use_ok('Dist::Zilla::Role::HashDumper');
use_ok('Dist::Zilla::Role::ModuleInfo');

SKIP: {
  skip 'Git::Wrapper not installed', 1 unless eval "use Git::Wrapper; 1";

  use_ok('Dist::Zilla::Plugin::GitVersionCheckCJM');
}
