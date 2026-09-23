import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Name of butcher's own configuration file, read from the project root.
const butcherConfigFile = 'butcher.yaml';

const _excludeKey = 'exclude';

/// butcher's configuration, read from [butcherConfigFile] at the project root.
///
/// The file carries one key, `exclude`, holding a list of glob strings. The
/// key name, the list shape and the glob dialect are deliberately the
/// analyzer's `exclude` schema, so a reader who has written an analyzer
/// exclude already knows this file. butcher never reads `analysis_options.yaml`
/// and carries no configuration block in any package manifest.
///
/// A missing file, a missing key and an empty list all mean the same thing:
/// nothing is excluded.
final class ButcherConfig {
  /// Creates a configuration whose glob patterns are [exclude].
  const ButcherConfig({this.exclude = const []});

  /// Parses [source] as the contents of a [butcherConfigFile].
  ///
  /// Throws a [FormatException] naming the offending key when `exclude` holds
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
    if (!document.containsKey(_excludeKey)) return const ButcherConfig();
    final value = document[_excludeKey];
    if (value is! YamlList || value.any((entry) => entry is! String)) {
      throw FormatException(
        "'$_excludeKey' in $butcherConfigFile must be a list of glob strings",
      );
    }
    return ButcherConfig(exclude: List<String>.unmodifiable(value.cast()));
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
}
