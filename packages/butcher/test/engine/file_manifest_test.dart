// Measured copy sets for this repository, 2026-09-22, reproduced by:
//
//   git ls-files --cached --others --exclude-standard --deduplicate -z \
//     | xargs -0 stat -f%z | awk '{n++; b+=$1} END {print n, b}'
//   -> 179 files, 473620 bytes
//
//   find . \( -name .git -o -name .dart_tool -o -path ./build \
//     -o -path ./coverage \) -prune -o -type f -print0 \
//     | xargs -0 stat -f%z | awk '{n++; b+=$1} END {print n, b}'
//   -> 180 files, 484807 bytes
//
// The one file between them is the gitignored `pubspec.lock`, which the
// always-include rule puts back, so butcher's own sandbox copies the same
// 180 files either way: this repository gitignores nothing but tooling
// output, which the walk already excluded. The reduction the manifest buys
// scales with what a project gitignores, not with its source.
import 'dart:io';

import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/file_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

/// A lister answering every invocation with [stdout], recording the
/// arguments it was called with.
({GitLister lister, List<List<String>> calls}) recorded(
  String stdout, {
  int exitCode = 0,
  String stderr = '',
}) {
  final calls = <List<String>>[];
  return (
    lister: (arguments) async {
      calls.add(arguments);
      return ProcessResult(0, exitCode, stdout, stderr);
    },
    calls: calls,
  );
}

void main() {
  test('lists the workspace root without repeating its paths', () async {
    final git = recorded('lib/a.dart\u0000a dir/with space.txt\u0000');

    final manifest = await FileManifest.of('/no/such/root', lister: git.lister);

    expect(manifest.paths, {'lib/a.dart', 'a dir/with space.txt'});
    expect(git.calls.first.take(3), ['-C', '/no/such/root', 'ls-files']);
    expect(
      git.calls.first,
      containsAll([
        '--cached',
        '--others',
        '--exclude-standard',
        '--deduplicate',
        '-z',
      ]),
    );
    for (final call in git.calls) {
      expect(call, isNot(contains('--full-name')));
      expect(call, isNot(contains('--recurse-submodules')));
    }
  });

  test('signals a root outside a repository distinctly', () async {
    final git = recorded(
      '',
      exitCode: 128,
      stderr:
          'fatal: not a git repository (or any of the parent '
          'directories): .git\n',
    );

    await expectLater(
      FileManifest.of('/no/such/root', lister: git.lister),
      throwsA(isA<NotAGitRepository>()),
    );
  });

  test('aborts on any other git failure', () async {
    final git = recorded('', exitCode: 1, stderr: 'fatal: bad pathspec\n');

    await expectLater(
      FileManifest.of('/no/such/root', lister: git.lister),
      throwsA(isA<RunAborted>()),
    );
  });

  test('always includes gitignored lockfiles and generated sources', () async {
    final root = await Directory.systemTemp.createTemp('butcher_manifest_');
    addTearDown(() => root.delete(recursive: true));
    void write(String relative, String content) {
      final file = File(p.join(root.path, relative));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    write('.gitignore', 'pubspec.lock\n*.g.dart\nbulk/\n');
    write('pubspec.yaml', 'name: workspace\n');
    write('pubspec.lock', 'root lock');
    write('lib/a.dart', 'const a = 1;\n');
    write('lib/a.g.dart', 'const generated = 1;\n');
    write('packages/member/pubspec.yaml', 'name: member\n');
    write('packages/member/pubspec.lock', 'member lock');
    write('bulk/blob.bin', 'bulk');
    await initGitRepository(root.path);

    final manifest = await FileManifest.of(root.path);

    expect(
      manifest.paths,
      containsAll([
        'pubspec.lock',
        'packages/member/pubspec.lock',
        'lib/a.g.dart',
        'lib/a.dart',
      ]),
    );
    expect(manifest.paths, isNot(contains('bulk/blob.bin')));
  });
}
