import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/sandbox.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

Future<Directory> fixtureProject() async {
  final dir = await Directory.systemTemp.createTemp('butcher_sandbox_src_');
  addTearDown(() => dir.delete(recursive: true));
  void write(String relative, String content) {
    final file = File(p.join(dir.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  write('lib/a.dart', 'int add(int a, int b) => a + b;\n');
  write('test/a_test.dart', 'void main() {}\n');
  write('.dart_tool/package_config.json', '{}');
  write('build/out.txt', 'x');
  write('lib/nested/build/gen.dart', 'const g = 1;\n');
  write('tool/build', '#!/bin/sh\n');
  write('packages/sub/lib/b.dart', 'const b = 1;\n');
  write('packages/sub/.dart_tool/package_config.json', '{}');
  write('packages/sub/build/out.txt', 'x');
  write('packages/sub/.git/config', 'x');
  write('assets/big/blob.bin', 'x');
  write('assets/big/keep.txt', 'keep');
  write('assets/small.txt', 'keep');
  write('deep/nested/trace.log', 'x');
  write(
    '.gitignore',
    '# comment\n\n*.log\nassets/big/**\n!assets/big/keep.txt\n',
  );
  await initGitRepository(dir.path);
  return dir;
}

void main() {
  late Directory source;
  late ButcherPaths paths;
  late Sandbox sandbox;

  setUp(() async {
    source = await fixtureProject();
    paths = await isolatedButcherPaths('butcher_sandbox_state_');
    sandbox = await Sandbox.create(source.path, paths: paths);
  });

  test('lives inside the configured temp folder', () {
    expect(p.isWithin(paths.root, sandbox.root), isTrue);
  });

  test('copies the project without excluded paths', () {
    bool has(String relative) =>
        File(p.join(sandbox.root, relative)).existsSync();
    expect(has('lib/a.dart'), isTrue);
    expect(has('test/a_test.dart'), isTrue);
    expect(has('assets/small.txt'), isTrue);
    expect(has('.git/config'), isFalse);
    expect(has('.dart_tool/package_config.json'), isFalse);
    expect(has('build/out.txt'), isFalse);
    expect(has('assets/big/blob.bin'), isFalse);
    expect(has('assets/big/keep.txt'), isTrue);
    expect(has('deep/nested/trace.log'), isFalse);
  });

  test('prunes nested tooling directories only', () {
    bool has(String relative) =>
        File(p.join(sandbox.root, relative)).existsSync();
    expect(has('packages/sub/lib/b.dart'), isTrue);
    expect(has('packages/sub/.dart_tool/package_config.json'), isFalse);
    expect(has('packages/sub/.git/config'), isFalse);
    expect(has('packages/sub/build/out.txt'), isTrue);
    expect(has('lib/nested/build/gen.dart'), isTrue);
    expect(has('tool/build'), isTrue);
  });

  test('keeps a directory rule from being undone below it', () async {
    final project = await fixtureProject();
    File(
      p.join(project.path, '.gitignore'),
    ).writeAsStringSync('assets/big/\n!assets/big/keep.txt\n');
    final copy = await Sandbox.create(
      project.path,
      paths: await isolatedButcherPaths('butcher_sandbox_rule_'),
    );
    expect(Directory(p.join(copy.root, 'assets/big')).existsSync(), isFalse);
    expect(File(p.join(copy.root, 'assets/small.txt')).existsSync(), isTrue);
  });

  test('does not copy an in-project butcher root', () async {
    final project = await fixtureProject();
    final inProject = ButcherPaths(root: p.join(project.path, '.butcher_temp'));
    final copy = await Sandbox.create(project.path, paths: inProject);
    expect(Directory(p.join(copy.root, '.butcher_temp')).existsSync(), isFalse);
    expect(File(p.join(copy.root, 'lib/a.dart')).existsSync(), isTrue);
  });

  test('copies the project when the butcher root equals it', () async {
    final project = await fixtureProject();
    final copy = await Sandbox.create(
      project.path,
      paths: ButcherPaths(root: project.path),
    );
    expect(File(p.join(copy.root, 'lib/a.dart')).existsSync(), isTrue);
    expect(Directory(p.join(copy.root, copy.name)).existsSync(), isFalse);
  });

  test('recreates an in-workspace link and skips one pointing out', () async {
    final project = await fixtureProject();
    final outside = await Directory.systemTemp.createTemp('butcher_outside_');
    addTearDown(() => outside.delete(recursive: true));
    File(p.join(outside.path, 'secret.txt')).writeAsStringSync('secret');
    Link(
      p.join(project.path, 'inside.link'),
    ).createSync(p.join('lib', 'a.dart'));
    Link(
      p.join(project.path, 'outside.link'),
    ).createSync(p.join(outside.path, 'secret.txt'));
    final linkPaths = await isolatedButcherPaths('butcher_sandbox_link_');
    final logger = ButcherLogger(
      verbose: false,
      path: p.join(linkPaths.root, 'links.log'),
    );

    final copy = await Sandbox.create(
      project.path,
      paths: linkPaths,
      logger: logger,
    );

    expect(
      p.equals(
        Link(p.join(copy.root, 'inside.link')).targetSync(),
        p.join('lib', 'a.dart'),
      ),
      isTrue,
    );
    expect(
      File(p.join(copy.root, 'inside.link')).readAsStringSync(),
      contains('a + b'),
    );
    expect(
      FileSystemEntity.typeSync(
        p.join(copy.root, 'outside.link'),
        followLinks: false,
      ),
      FileSystemEntityType.notFound,
    );
    expect(
      File(
        logger.path,
      ).readAsLinesSync().where((line) => line.contains('skipped symlink')),
      hasLength(1),
    );
  });

  test('nativizes a posix-style relative link target on recreation', () async {
    final project = await fixtureProject();
    // Git always records a relative link target with posix separators,
    // whatever platform checks it out, so write the source link with a
    // literal forward slash rather than a native-separator path: that is
    // the shape a real checkout hands the sandbox on every OS.
    Link(p.join(project.path, 'posix.link')).createSync('lib/a.dart');
    final linkPaths = await isolatedButcherPaths('butcher_sandbox_posix_');

    final copy = await Sandbox.create(project.path, paths: linkPaths);

    final recreated = Link(p.join(copy.root, 'posix.link')).targetSync();
    if (Platform.pathSeparator == r'\') {
      expect(recreated, isNot(contains('/')));
    } else {
      expect(recreated, 'lib/a.dart');
    }
  });

  test('falls back to the built-in exclusions outside a repository', () async {
    final plain = await Directory.systemTemp.createTemp('butcher_plain_');
    addTearDown(() => plain.delete(recursive: true));
    void write(String relative, String content) {
      final file = File(p.join(plain.path, relative));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    write('lib/a.dart', 'int add(int a, int b) => a + b;\n');
    write('build/out.txt', 'x');
    write('.dart_tool/package_config.json', '{}');
    write('deep/nested/trace.log', 'x');
    final plainPaths = await isolatedButcherPaths('butcher_sandbox_plain_');
    final logger = ButcherLogger(
      verbose: false,
      path: p.join(plainPaths.root, 'plain.log'),
    );

    final copy = await Sandbox.create(
      plain.path,
      paths: plainPaths,
      logger: logger,
    );

    bool has(String relative) => File(p.join(copy.root, relative)).existsSync();
    expect(has('lib/a.dart'), isTrue);
    expect(has('deep/nested/trace.log'), isTrue);
    expect(has('build/out.txt'), isFalse);
    expect(has('.dart_tool/package_config.json'), isFalse);
    expect(
      File(logger.path).readAsLinesSync().where(
        (line) => line.contains('it is not a git repository'),
      ),
      hasLength(1),
    );
  });

  test('clones the copy set rather than the sandbox tree', () async {
    int files(String root) => Directory(
      root,
    ).listSync(recursive: true, followLinks: false).whereType<File>().length;
    // What the baseline suite drops in the tree is not the copy set, so no
    // worker inherits it.
    File(p.join(sandbox.root, 'dropped.txt')).writeAsStringSync('x');

    final template = await sandbox.clone();
    final worker = await template.clone();

    expect(File(p.join(template.root, 'dropped.txt')).existsSync(), isFalse);
    expect(files(template.root), files(sandbox.root) - 1);
    expect(files(worker.root), files(template.root));
    expect(files(template.root), lessThan(files(source.path)));
  });

  test('clones the copied tree into an independent sandbox', () async {
    File(p.join(sandbox.root, '.dart_tool/package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"resolved": true}');
    final clone = await sandbox.clone();

    expect(p.isWithin(paths.root, clone.root), isTrue);
    expect(clone.root, isNot(sandbox.root));
    expect(
      File(
        p.join(clone.root, '.dart_tool/package_config.json'),
      ).readAsStringSync(),
      '{"resolved": true}',
    );

    const mutation = Mutation(
      filePath: 'lib/a.dart',
      offset: 27,
      length: 1,
      original: '+',
      replacement: '-',
      mutatorId: 'arithmetic',
      description: 'replace + with -',
    );
    await clone.apply(mutation);
    expect(
      File(p.join(clone.root, 'lib/a.dart')).readAsStringSync(),
      contains('a - b'),
    );
    expect(
      File(p.join(sandbox.root, 'lib/a.dart')).readAsStringSync(),
      contains('a + b'),
    );

    await sandbox.apply(mutation);
    await sandbox.restore('lib/a.dart');
    expect(
      File(p.join(clone.root, 'lib/a.dart')).readAsStringSync(),
      contains('a - b'),
    );
  });

  test('copies a workspace while targeting only its member', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'butcher_sandbox_workspace_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final member = Directory(p.join(workspace.path, 'packages', 'member'));
    void write(String relative, String contents) {
      final file = File(p.join(workspace.path, relative));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    write('pubspec.yaml', 'name: workspace\n');
    write('.gitignore', 'bulk/\n');
    write('bulk/blob.bin', 'workspace bulk');
    write('build/root.txt', 'root output');
    write('packages/member/pubspec.yaml', 'name: member\n');
    write('packages/member/.gitignore', 'assets/\n');
    write('packages/member/lib/a.dart', 'int add(int a, int b) => a + b;\n');
    write('packages/member/assets/blob.bin', 'member bulk');
    write('packages/member/build/member.txt', 'member output');
    write('packages/member/.dart_tool/config.json', '{}');
    write('packages/sibling/lib/b.dart', 'const b = 1;\n');
    write('packages/sibling/build/kept.txt', 'sibling source');
    write('packages/sibling/.git/config', 'metadata');
    await initGitRepository(workspace.path);

    final copy = await Sandbox.create(
      member.path,
      workspaceRoot: workspace.path,
      paths: await isolatedButcherPaths('butcher_sandbox_workspace_state_'),
    );

    expect(copy.projectRoot, p.join(copy.root, 'packages', 'member'));
    expect(File(p.join(copy.root, 'bulk', 'blob.bin')).existsSync(), isFalse);
    expect(File(p.join(copy.root, 'build', 'root.txt')).existsSync(), isFalse);
    expect(
      File(p.join(copy.projectRoot, 'assets', 'blob.bin')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(copy.projectRoot, 'build', 'member.txt')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(copy.projectRoot, '.dart_tool', 'config.json')).existsSync(),
      isFalse,
    );
    expect(
      File(
        p.join(copy.root, 'packages', 'sibling', 'lib', 'b.dart'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(copy.root, 'packages', 'sibling', 'build', 'kept.txt'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(copy.root, 'packages', 'sibling', '.git', 'config'),
      ).existsSync(),
      isFalse,
    );

    const mutation = Mutation(
      filePath: 'lib/a.dart',
      offset: 27,
      length: 1,
      original: '+',
      replacement: '-',
      mutatorId: 'arithmetic',
      description: 'replace + with -',
    );
    await copy.apply(mutation);
    expect(
      File(p.join(copy.projectRoot, 'lib', 'a.dart')).readAsStringSync(),
      contains('a - b'),
    );
    await copy.restore(mutation.filePath);

    final clone = await copy.clone();
    expect(clone.projectRoot, p.join(clone.root, 'packages', 'member'));
    expect(
      File(
        p.join(clone.root, 'packages', 'sibling', 'lib', 'b.dart'),
      ).existsSync(),
      isTrue,
    );
    await clone.apply(mutation);
    expect(
      File(p.join(clone.projectRoot, 'lib', 'a.dart')).readAsStringSync(),
      contains('a - b'),
    );
    await clone.restore(mutation.filePath);

    expect(
      File(p.join(member.path, 'lib', 'a.dart')).readAsStringSync(),
      'int add(int a, int b) => a + b;\n',
    );
    expect(
      File(
        p.join(workspace.path, 'packages', 'sibling', 'lib', 'b.dart'),
      ).readAsStringSync(),
      'const b = 1;\n',
    );
  });

  test('rejects a selected package outside the workspace root', () async {
    final workspace = await fixtureProject();
    final member = await fixtureProject();

    await expectLater(
      Sandbox.create(
        member.path,
        workspaceRoot: workspace.path,
        paths: await isolatedButcherPaths('butcher_sandbox_outside_'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'applies and restores a mutation without touching the source tree',
    () async {
      const mutation = Mutation(
        filePath: 'lib/a.dart',
        offset: 27,
        length: 1,
        original: '+',
        replacement: '-',
        mutatorId: 'arithmetic',
        description: 'replace + with -',
      );
      final copied = File(p.join(sandbox.root, 'lib/a.dart'));

      await sandbox.apply(mutation);
      expect(copied.readAsStringSync(), contains('a - b'));
      expect(
        File(p.join(source.path, 'lib/a.dart')).readAsStringSync(),
        contains('a + b'),
      );

      await sandbox.restore('lib/a.dart');
      expect(copied.readAsStringSync(), contains('a + b'));
    },
  );

  test('rejects a mutation whose original text does not match', () async {
    const drifted = Mutation(
      filePath: 'lib/a.dart',
      offset: 0,
      length: 1,
      original: '+',
      replacement: '-',
      mutatorId: 'arithmetic',
      description: 'replace + with -',
    );
    await expectLater(sandbox.apply(drifted), throwsStateError);
  });

  test('rejects a mutation past the end of the copied file', () async {
    const pastEnd = Mutation(
      filePath: 'lib/a.dart',
      offset: 1000,
      length: 1,
      original: '+',
      replacement: '-',
      mutatorId: 'arithmetic',
      description: 'replace + with -',
    );
    await expectLater(sandbox.apply(pastEnd), throwsStateError);
  });
}
