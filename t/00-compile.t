use Test::More tests => 6;

diag("Testing Dist-Zilla-Plugins-CJM 3.02");

use_ok('Dist::Zilla::Plugin::ArchiveRelease');
use_ok('Dist::Zilla::Plugin::ModuleBuild::Custom');
use_ok('Dist::Zilla::Plugin::TemplateCJM');
use_ok('Dist::Zilla::Plugin::VersionFromModule');
use_ok('Dist::Zilla::Role::ModuleInfo');

SKIP: {
  skip 'Git::Wrapper not installed', 1 unless eval "use Git::Wrapper; 1";

  use_ok('Dist::Zilla::Plugin::GitVersionCheckCJM');
}
