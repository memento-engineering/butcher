import 'dart:io';

import 'package:butcher/src/engine/flutter_sdk.dart';
import 'package:butcher/src/engine/run_aborted.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String temp;
  final command = Platform.isWindows ? 'flutter.bat' : 'flutter';

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('butcher_flutter_sdk_');
    addTearDown(() => dir.delete(recursive: true));
    temp = dir.path;
  });

  String package(String dependencies) {
    final root = p.join(temp, 'package');
    File(p.join(root, 'pubspec.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('name: fixture\n$dependencies');
    return root;
  }

  String sdk(String name) {
    final flutter = File(p.join(temp, name, 'bin', command))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('');
    return p.dirname(p.dirname(flutter.path));
  }

  const flutterTest = 'dev_dependencies:\n  flutter_test:\n    sdk: flutter\n';

  test('is null for a package that needs nothing from Flutter', () {
    final root = package('dependencies:\n  path: any\n');

    expect(flutterFor(root, environment: const {}), isNull);
  });

  test('takes the command beside the dart butcher runs on', () {
    final root = package(flutterTest);
    final flutter = sdk('bundled');

    expect(
      flutterFor(
        root,
        dart: p.join(flutter, 'bin', 'cache', 'dart-sdk', 'bin', 'dart'),
        environment: {'FLUTTER_ROOT': sdk('elsewhere')},
      ),
      p.join(flutter, 'bin', command),
    );
  });

  test('falls back to FLUTTER_ROOT for a standalone dart', () {
    final root = package(flutterTest);
    final flutter = sdk('rooted');

    expect(
      flutterFor(
        root,
        dart: p.join(temp, 'dart-sdk', 'bin', 'dart'),
        environment: {'FLUTTER_ROOT': flutter},
      ),
      p.join(flutter, 'bin', command),
    );
  });

  test('aborts when a Flutter package finds no flutter command', () {
    final root = package('dependencies:\n  flutter:\n    sdk: flutter\n');

    expect(
      () => flutterFor(
        root,
        dart: p.join(temp, 'dart-sdk', 'bin', 'dart'),
        environment: const {},
      ),
      throwsA(isA<RunAborted>()),
    );
  });
}
