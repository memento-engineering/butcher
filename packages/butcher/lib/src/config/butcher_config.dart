import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Name of butcher's own configuration file, read from the project root.
const butcherConfigFile = 'butcher.yaml';

const _excludeKey = 'exclude';

const _testsKey = 'tests';

/// butcher's configuration, read from [butcherConfigFile] at the project root.
///
/// `exclude` holds a list of glob strings. The key name, the list shape and
/// the glob dialect are deliberately the analyzer's `exclude` schema, so a
/// reader who has written an analyzer exclude already knows this file.
/// butcher never reads the analyzer's own configuration file and carries no
/// configuration block in any package manifest.
///
/// `tests` lists the test files every suite run executes, in place of every
/// `*_test.dart` under `test/`.
///
/// A missing file, a missing key and an empty list all mean the same thing:
/// the default.
final class ButcherConfig {
  /// Creates a configuration whose glob patterns are [exclude].
  const ButcherConfig({this.exclude = const [], this.tests = const []});

  /// Parses [source] as the contents of a [butcherConfigFile].
  ///
  /// Throws a [FormatException] naming the offending key when a key holds
  /// anything but a list of strings, and one naming the file when the document
  /// is not a map.
  factory ButcherConfig.parse(String source) {
    final document = loadYaml(source);
    if (document == null) return const ButcherConfig();
    if (document is! YamlMap) {
      throw FormatException(
        '$butcherConfigFile must hold a map of configuration keys',
      );
    }
    return ButcherConfig(
      exclude: _strings(document, _excludeKey, 'glob strings'),
      tests: _strings(document, _testsKey, 'test file paths'),
    );
  }

  static List<String> _strings(YamlMap document, String key, String what) {
    if (!document.containsKey(key)) return const [];
    final value = document[key];
    if (value is! YamlList || value.any((entry) => entry is! String)) {
      throw FormatException(
        "'$key' in $butcherConfigFile must be a list of $what",
      );
    }
    return List<String>.unmodifiable(value.cast());
  }

  /// Reads [butcherConfigFile] from [projectRoot]; a missing file excludes
  /// nothing.
  factory ButcherConfig.load(String projectRoot) {
    final file = File(p.join(projectRoot, butcherConfigFile));
    if (!file.existsSync()) return const ButcherConfig();
    return ButcherConfig.parse(file.readAsStringSync());
  }

  /// Glob patterns whose matches are out of mutation scope.
  final List<String> exclude;

  /// Project-relative test files run in place of the discovered suite.
  final List<String> tests;
}
