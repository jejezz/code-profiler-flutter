import 'dart:io';

import 'package:profile_engine/profile_engine.dart';
import 'package:test/test.dart';

import 'fixtures/fixture.dart';

final Rules _defaults = loadDefaultRules().valueOrNull!;

Rules _withScan(ScanConfig scan, {List<TypeRule>? types}) => Rules(
  version: 1,
  scan: scan,
  variables: _defaults.variables,
  types: types ?? _defaults.types,
  sizeRules: _defaults.sizeRules,
);

AnalysisResult _analyze(String path, {Rules? rules}) {
  final r = analyzeSync(path, rules: rules ?? _defaults);
  expect(r, isA<Ok<AnalysisResult>>(), reason: '${r.errorOrNull}');
  return r.valueOrNull!;
}

List<String> _ids(AnalysisResult r) => [for (final t in r.types) t.typeId];

void main() {
  group('fixtures (design doc 8.1)', () {
    test('esp_idf: esp-idf wins and cmake is suppressed', () {
      final fx = createFixture({
        'CMakeLists.txt':
            'include(\$ENV{IDF_PATH}/tools/cmake/project.cmake)\n',
        'sdkconfig': 'CONFIG_X=y\n',
        'main/main.c': 'int main(){}\n',
      });
      final r = _analyze(fx.path);
      expect(_ids(r), ['esp-idf']);
      final evidence = r.types.single.evidence;
      expect(
        evidence.map((e) => e.ruleId),
        containsAll(['file', 'fileContains']),
      );
      expect(evidence.first.relativePath, 'sdkconfig');
    });

    test('aosp_module: detected under a .repo root, aospRoot resolved', () {
      final fx = createFixture({
        'aosp/.repo/': '',
        'aosp/build/envsetup.sh': '# envsetup\n',
        'aosp/vendor/x/hal/Android.bp': 'cc_binary {}\n',
      });
      final r = _analyze('${fx.path}/aosp/vendor/x/hal');
      expect(_ids(r), ['aosp-module']);
      expect(r.variables['aospRoot']!.replaceAll(r'\', '/'), endsWith('/aosp'));
      expect(
        r.types.single.evidence.map((e) => e.ruleId),
        containsAll(['file', 'variable']),
      );
    });

    test('aosp_no_root: Android.bp alone is not an AOSP module', () {
      final fx = createFixture({'Android.bp': 'cc_binary {}\n'});
      final r = _analyze(fx.path);
      expect(_ids(r), isEmpty);
      expect(r.variables, isEmpty);
    });

    test('gradle: java-gradle', () {
      final fx = createFixture({
        'settings.gradle.kts': 'rootProject.name = "x"\n',
        'app/build.gradle.kts': 'plugins {}\n',
      });
      expect(_ids(_analyze(fx.path)), ['java-gradle']);
    });

    test('kernel: linux-kernel wins and make is suppressed', () {
      final fx = createFixture({'Kconfig': '', 'Makefile': 'all:\n'});
      expect(_ids(_analyze(fx.path)), ['linux-kernel']);
    });

    test('mixed_web_py: both detected in rules order, same priority', () {
      final fx = createFixture({'package.json': '{}', 'requirements.txt': ''});
      final r = _analyze(fx.path);
      expect(_ids(r), ['node', 'python']);
      expect(r.types.map((t) => t.priority).toSet(), {60});
    });

    test('big_tree: truncates at maxFiles, root marker files still found', () {
      final fx = createFixture({
        'Makefile': 'all:\n',
        for (var i = 0; i < 30; i++) 'src/f$i.c': '',
      });
      final rules = _withScan(
        const ScanConfig(maxDepth: 3, maxFiles: 10, skipDirs: []),
      );
      final r = _analyze(fx.path, rules: rules);
      expect(r.stats.truncated, isTrue);
      expect(r.stats.fileCount, 10);
      expect(_ids(r), ['make']);
    });

    test('exactly maxFiles files is not truncated', () {
      final fx = createFixture({for (var i = 0; i < 5; i++) 'f$i.c': ''});
      final rules = _withScan(
        const ScanConfig(maxDepth: 3, maxFiles: 5, skipDirs: []),
      );
      final r = _analyze(fx.path, rules: rules);
      expect(r.stats.truncated, isFalse);
      expect(r.stats.fileCount, 5);
    });

    test(
      'skip_dirs: files inside skipDirs are ignored but listed as present',
      () {
        final fx = createFixture({'node_modules/pkg/pom.xml': '<project/>'});
        final r = _analyze(fx.path);
        expect(_ids(r), isEmpty);
        expect(r.stats.fileCount, 0);
        expect(r.stats.largeDirsPresent, ['node_modules']);
      },
    );

    test('symlink_loop: terminates without following links', () {
      final fx = createFixture({'Makefile': 'all:\n', 'a/x.c': ''});
      try {
        Link('${fx.path}/a/loop').createSync('..');
      } on FileSystemException {
        markTestSkipped('cannot create symlinks on this machine');
        return;
      }
      final r = _analyze(fx.path);
      expect(r.stats.fileCount, 2);
      expect(_ids(r), ['make']);
    });
  });

  group('scan limits', () {
    test('files deeper than maxDepth are not scanned', () {
      final fx = createFixture({'a/b/c/d/pom.xml': '', 'a/b/c/pom.xml': ''});
      final r = _analyze(
        fx.path,
        rules: _withScan(
          const ScanConfig(maxDepth: 3, maxFiles: 100, skipDirs: []),
        ),
      );
      expect(r.stats.fileCount, 1);
      final shallow = _analyze(
        fx.path,
        rules: _withScan(
          const ScanConfig(maxDepth: 2, maxFiles: 100, skipDirs: []),
        ),
      );
      expect(shallow.stats.fileCount, 0);
      expect(_ids(shallow), isEmpty);
    });

    test('a directory matcher sees skipDirs by existence', () {
      final fx = createFixture({'out/soong/x.txt': ''});
      const rule = TypeRule(
        id: 'has-out',
        label: 'Has out',
        priority: 1,
        match: DirMatcher('out'),
        profile: 'P',
      );
      final r = _analyze(
        fx.path,
        rules: _withScan(_defaults.scan, types: [rule]),
      );
      expect(_ids(r), ['has-out']);
      expect(r.types.single.evidence.single.relativePath, 'out');
      expect(r.stats.fileCount, 0);
    });
  });

  group('matchers', () {
    test('fileContains needs the pattern, not just the file', () {
      final fx = createFixture({'CMakeLists.txt': 'project(plain)\n'});
      final r = _analyze(fx.path);
      expect(_ids(r), ['cmake']);
    });

    test('nested all/any', () {
      final fx = createFixture({'a.txt': '', 'c.txt': ''});
      final rule = TypeRule(
        id: 'n',
        label: 'N',
        priority: 1,
        match: AllMatcher([
          AnyMatcher([FileMatcher('a.txt'), FileMatcher('b.txt')]),
          const FileMatcher('c.txt'),
        ]),
        profile: 'P',
      );
      final r = _analyze(
        fx.path,
        rules: _withScan(_defaults.scan, types: [rule]),
      );
      expect(_ids(r), ['n']);
      expect(r.types.single.evidence, hasLength(2));
    });

    test('all fails when one child fails', () {
      final fx = createFixture({'a.txt': ''});
      final rule = TypeRule(
        id: 'n',
        label: 'N',
        priority: 1,
        match: AllMatcher([FileMatcher('a.txt'), FileMatcher('b.txt')]),
        profile: 'P',
      );
      final r = _analyze(
        fx.path,
        rules: _withScan(_defaults.scan, types: [rule]),
      );
      expect(_ids(r), isEmpty);
    });

    test('types are sorted by priority, highest first', () {
      final fx = createFixture({
        'pom.xml': '',
        'CMakeLists.txt': 'project(x)\n',
        'Makefile': '',
      });
      final r = _analyze(fx.path);
      expect(_ids(r), ['java-maven', 'cmake', 'make']);
    });
  });

  group('errors and the Isolate wrapper', () {
    test('missing path is an Err', () {
      final r = analyzeSync(
        '${Directory.systemTemp.path}/no_such_dir_xyz',
        rules: _defaults,
      );
      expect(r, isA<Err<AnalysisResult>>());
    });

    test('a file path is an Err', () {
      final fx = createFixture({'f.txt': ''});
      final r = analyzeSync('${fx.path}/f.txt', rules: _defaults);
      expect(r, isA<Err<AnalysisResult>>());
    });

    test('analyze() in an Isolate matches analyzeSync()', () async {
      final fx = createFixture({
        'CMakeLists.txt': 'include(\$ENV{IDF_PATH}/x)\n',
        'sdkconfig': '',
      });
      final viaIsolate = await analyze(fx.path);
      expect(
        viaIsolate,
        isA<Ok<AnalysisResult>>(),
        reason: '${viaIsolate.errorOrNull}',
      );
      expect(_ids(viaIsolate.valueOrNull!), ['esp-idf']);
      final sync = _analyze(fx.path);
      expect(viaIsolate.valueOrNull!.stats.toJson(), sync.stats.toJson());
    });

    test('analyze() reports a missing path as Err', () async {
      final r = await analyze('${Directory.systemTemp.path}/no_such_dir_xyz');
      expect(r, isA<Err<AnalysisResult>>());
    });
  });
}
