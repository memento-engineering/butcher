import 'dart:convert';
import 'dart:io';

/// The single logger of a run; emits wide events as CLEF lines (ADR 0016).
///
/// Every event is one Compact Log Event Format JSON line: `@t` timestamp,
/// `@mt` message template with `{Property}` holes, `@l` level (absent means
/// informational), plus the event's properties. The file is flushed per
/// event; with [verbose] events also render human-readably to the console.
final class RadLogger {
  /// Creates the logger, replacing any log file left by a previous run.
  ///
  /// [colors] defaults to auto-detection: on only when writing to a
  /// terminal that supports ANSI escapes. Pass [runId] to correlate this
  /// log with another one (e.g. mutant-run logs with the tool log).
  RadLogger({
    required this.verbose,
    required this.path,
    StringSink? console,
    bool? colors,
    String? runId,
  }) : console = console ?? stdout,
       colors = colors ?? (console == null && stdout.supportsAnsiEscapes),
       runId =
           runId ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    file.parent.createSync(recursive: true);
  }

  /// Whether events also render to [console].
  final bool verbose;

  /// Absolute path of the CLEF log file.
  final String path;

  /// Console sink used when [verbose] is set.
  final StringSink console;

  /// Whether console rendering uses ANSI colors.
  final bool colors;

  /// Correlates every event of this run; the `RunId` property.
  final String runId;

  static final _hole = RegExp(r'\{([A-Za-z0-9_]+)\}');

  /// Emits an informational event: [template] holes name [properties] keys.
  void info(String template, [Map<String, Object?> properties = const {}]) =>
      _event(null, template, properties);

  /// Emits an error event: [template] holes name [properties] keys.
  void error(String template, [Map<String, Object?> properties = const {}]) =>
      _event('Error', template, properties);

  void _event(String? level, String template, Map<String, Object?> properties) {
    final line = jsonEncode({
      '@t': DateTime.now().toUtc().toIso8601String(),
      '@mt': template,
      '@l': ?level,
      'RunId': runId,
      ...properties,
    });
    File(path).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    if (verbose) console.writeln(_render(level, template, properties));
  }

  String _render(
    String? level,
    String template,
    Map<String, Object?> properties,
  ) {
    final now = DateTime.now();
    final time = '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
    final label = level == null ? _paint('INF', _green) : _paint('ERR', _red);
    final message = template.replaceAllMapped(_hole, (match) {
      final value = properties[match[1]];
      return value == null ? match[0]! : _paint('$value', _cyan);
    });
    return '${_paint(time, _gray)} $label $message';
  }

  String _paint(String text, String code) =>
      colors ? '$code$text\x1B[0m' : text;

  static String _two(int value) => value.toString().padLeft(2, '0');

  static const _gray = '\x1B[90m';
  static const _green = '\x1B[32m';
  static const _red = '\x1B[31m';
  static const _cyan = '\x1B[36m';
}
