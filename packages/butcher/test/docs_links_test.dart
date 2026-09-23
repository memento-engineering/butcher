import 'dart:io';

import 'package:butcher/src/cli/cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// One markdown link: its visible text and its target.
typedef _Link = ({String text, String target});

/// Every `[text](target)` link in [markdown], in source order.
List<_Link> _links(String markdown) => RegExp(r'\[([^\]\n]*)\]\(([^)\s]+)\)')
    .allMatches(markdown)
    .map((m) => (text: m.group(1)!, target: m.group(2)!))
    .toList();

/// The `repository:` field of this package's own manifest, which is the URL
/// every published docs link is written against.
String _repositoryUrl() {
  final manifest = File('pubspec.yaml');
  expect(
    manifest.existsSync(),
    isTrue,
    reason: 'run this suite from the package root, where pubspec.yaml lives',
  );

  final match = RegExp(
    r'''^repository:\s*(\S+)\s*$''',
    multiLine: true,
  ).firstMatch(manifest.readAsStringSync());

  expect(match, isNotNull, reason: 'pubspec.yaml declares no repository');

  return match!.group(1)!;
}

/// The directory holding the workspace manifest, found by walking up from the
/// current directory. The published README lives one level below it, so the
/// root README is only reachable this way.
Directory _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    final manifest = File(p.join(directory.path, 'pubspec.yaml'));
    if (manifest.existsSync() &&
        RegExp(
          r'^workspace:\s*$',
          multiLine: true,
        ).hasMatch(manifest.readAsStringSync())) {
      return directory;
    }
    final parent = directory.parent;
    expect(
      parent.path,
      isNot(directory.path),
      reason: 'no workspace pubspec.yaml above ${Directory.current.path}',
    );
    directory = parent;
  }
}

void main() {
  test('the published README quotes the usage the CLI prints', () async {
    final sink = StringBuffer();

    final code = await butcherMain(const ['--help'], out: sink);

    expect(code, 0);
    final usage = sink.toString().trim();
    expect(usage, startsWith('Usage: butcher'));
    expect(
      File('README.md').readAsStringSync(),
      contains(usage),
      reason: 'the README must quote the usage block verbatim',
    );
  });

  test('every published docs link is a full repository URL', () {
    final repository = _repositoryUrl();
    final readme = File('README.md').readAsStringSync();

    final docsLinks = _links(
      readme,
    ).where((link) => link.target.contains('docs/')).toList();

    expect(
      docsLinks,
      isNotEmpty,
      reason: 'the README points at the docs tree; the rule needs a subject',
    );
    for (final link in docsLinks) {
      expect(
        link.target,
        startsWith('$repository/'),
        reason:
            'pub.dev renders this README standalone, so "${link.target}" '
            'must be a full repository URL, not a relative path',
      );
    }
  });

  group('the workspace root README', () {
    late Directory root;
    late String readme;

    setUp(() {
      root = _workspaceRoot();
      readme = File(p.join(root.path, 'README.md')).readAsStringSync();
    });

    test('names all three workspace members', () {
      for (final member in ['butcher', 'butcher_process', 'butcher_report']) {
        expect(readme, contains('packages/$member'));
      }
    });

    test('resolves every relative link', () {
      final relative = _links(readme)
          .map((link) => link.target)
          .where((target) => !target.contains('://') && !target.startsWith('#'))
          .toList();

      expect(relative, isNotEmpty);
      for (final target in relative) {
        final path = p.join(root.path, target.split('#').first);
        expect(
          File(path).existsSync() || Directory(path).existsSync(),
          isTrue,
          reason: '"$target" resolves to nothing under the workspace root',
        );
      }
    });
  });
}
