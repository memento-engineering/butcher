import 'dart:io';

import 'package:butcher/src/engine/workspace_closure.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late String root;

  void member(String name, {String dependencies = '', String dev = ''}) {
    File(p.join(root, 'packages', name, 'pubspec.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
name: $name
resolution: workspace
environment:
  sdk: ^3.12.0
${dependencies.isEmpty ? '' : 'dependencies:\n$dependencies'}
${dev.isEmpty ? '' : 'dev_dependencies:\n$dev'}
''');
  }

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('butcher_closure_');
    addTearDown(() => dir.delete(recursive: true));
    root = dir.path;
    File(p.join(root, 'pubspec.yaml')).writeAsStringSync('''
name: closure_workspace
publish_to: none
environment:
  sdk: ^3.12.0
workspace:
  - packages/target
  - packages/direct
  - packages/dev_only
  - packages/unrelated
''');
    member('target', dependencies: '  direct: any\n');
    member('direct', dev: '  dev_only: any\n');
    member('dev_only');
    member('unrelated', dependencies: '  direct: any\n');
  });

  test('keeps what the target reaches, dev dependencies included', () async {
    final closure = await WorkspaceClosure.resolve(
      root,
      p.join(root, 'packages', 'target'),
    );

    expect(closure.kept, {
      '.',
      'packages/target',
      'packages/direct',
      'packages/dev_only',
    });
    expect(closure.dropped, {'packages/unrelated'});
    expect(closure.excludes('packages/unrelated'), isTrue);
    expect(closure.excludes('packages/unrelated/lib/a.dart'), isTrue);
    expect(closure.excludes('packages/direct/lib/a.dart'), isFalse);
    expect(closure.excludes('pubspec.yaml'), isFalse);
  });

  test('narrows the root workspace list to the kept members', () async {
    final closure = await WorkspaceClosure.resolve(
      root,
      p.join(root, 'packages', 'target'),
    );
    final source = File(p.join(root, 'pubspec.yaml')).readAsStringSync();

    final trimmed = loadYaml(closure.trim(source)) as YamlMap;

    expect(trimmed['workspace'], [
      'packages/dev_only',
      'packages/direct',
      'packages/target',
    ]);
    expect(trimmed['name'], 'closure_workspace');
  });
}
