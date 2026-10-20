import 'dart:io';

import 'package:butcher/src/config/diff_scope.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  late String root;

  void write(String relative, String content) {
    File(p.join(root, relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  Future<void> git(List<String> arguments) async {
    final result = await Process.run('git', [
      '-C',
      root,
      '-c',
      'user.name=butcher',
      '-c',
      'user.email=butcher@example.com',
      ...arguments,
    ]);
    if (result.exitCode != 0) fail('git $arguments: ${result.stderr}');
  }

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('butcher_diff_scope_');
    addTearDown(() => dir.delete(recursive: true));
    root = dir.path;
    await initGitRepository(root);
    write('lib/edited.dart', 'int a = 1;\n');
    write('lib/deleted.dart', 'int b = 1;\n');
    write('lib/untouched.dart', 'int c = 1;\n');
    write('lib/committed.dart', 'int d = 1;\n');
    await git(['add', '.']);
    await git(['commit', '-q', '-m', 'base']);
    await git(['tag', 'base']);
    write('lib/committed.dart', 'int d = 2;\n');
    await git(['commit', '-q', '-am', 'change']);
  });

  test('takes committed, uncommitted and untracked lib files', () async {
    write('lib/edited.dart', 'int a = 2;\n');
    write('lib/src/added.dart', 'int e = 1;\n');
    write('test/added_test.dart', 'void main() {}\n');
    File(p.join(root, 'lib/deleted.dart')).deleteSync();

    expect(await diffScope(root, 'base'), {
      'lib/committed.dart',
      'lib/edited.dart',
      'lib/src/added.dart',
    });
  });

  test('is empty when nothing changed', () async {
    expect(await diffScope(root, 'HEAD'), isEmpty);
  });

  test('rejects a ref git cannot resolve', () {
    expect(diffScope(root, 'no-such-ref'), throwsFormatException);
  });
}
