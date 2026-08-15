import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../temp.dart';

/// The single logger of a run; emits wide events as JSON lines (ADR 0016).
///
/// Events go to a log file that is flushed per event; with [verbose] they
/// also stream to the console.
final class RadLogger {
  /// Creates the logger, replacing any log file left by a previous run.
  RadLogger({required this.verbose, String? path, StringSink? console})
    : path = path ?? defaultPath,
      console = console ?? stdout,
      runId = DateTime.now().microsecondsSinceEpoch.toRadixString(36) {
    final file = File(this.path);
    if (file.existsSync()) file.deleteSync();
    file.parent.createSync(recursive: true);
  }

  /// Default log file location: `rad.log` in the rad temp folder.
  static String get defaultPath => p.join(radTempPath(), 'rad.log');

  /// Whether events also stream to [console].
  final bool verbose;

  /// Absolute path of the JSON-lines log file.
  final String path;

  /// Console sink used when [verbose] is set.
  final StringSink console;

  /// Correlates every event of this run.
  final String runId;

  /// Emits an informational wide event of [type] with [fields].
  void info(String type, Map<String, Object?> fields) =>
      _event('info', type, fields);

  /// Emits an error wide event of [type] with [fields].
  void error(String type, Map<String, Object?> fields) =>
      _event('error', type, fields);

  void _event(String level, String type, Map<String, Object?> fields) {
    final line = jsonEncode({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'type': type,
      'run_id': runId,
      ...fields,
    });
    File(path).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    if (verbose) console.writeln(line);
  }
}
