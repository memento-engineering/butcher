import 'dart:convert';

/// Parsed `dart test --reporter json` event stream.
///
/// Structured events keep classification correct even when tests themselves
/// print nested `dart test` output: nested text arrives quoted inside `print`
/// events and never parses as a top-level event.
final class TestEvents {
  /// Creates a parser that accepts reporter output through [add].
  TestEvents();

  /// Parses a complete reporter [output].
  factory TestEvents.parse(String output) {
    final events = TestEvents()..add(output);
    events.close();
    return events;
  }

  /// Maximum reporter line length retained by the live parser.
  static const maxLineLength = 1024 * 1024;

  final Map<int, String> _names = {};
  final _pending = StringBuffer();
  var _closed = false;
  var _discardingLine = false;

  /// Parses the next reporter-output [chunk].
  void add(String chunk) {
    if (_closed) throw StateError('test event stream is closed');
    var start = 0;
    if (_discardingLine) {
      final end = chunk.indexOf('\n');
      if (end < 0) return;
      _discardingLine = false;
      start = end + 1;
    }
    while (start < chunk.length) {
      final end = chunk.indexOf('\n', start);
      if (end < 0) {
        _append(chunk.substring(start), complete: false);
        return;
      }
      _append(chunk.substring(start, end), complete: true);
      start = end + 1;
    }
  }

  void _append(String fragment, {required bool complete}) {
    if (_pending.length + fragment.length > maxLineLength) {
      _pending.clear();
      _discardingLine = !complete;
      return;
    }
    _pending.write(fragment);
    if (!complete) return;
    _parseLine('$_pending');
    _pending.clear();
  }

  /// Parses the final partial line and closes the stream.
  void close() {
    if (_closed) return;
    if (!_discardingLine && _pending.isNotEmpty) _parseLine('$_pending');
    _pending.clear();
    _closed = true;
  }

  void _parseLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line) as Object?;
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    switch (decoded['type']) {
      case 'testStart':
        final test = decoded['test'];
        if (test is Map<String, dynamic>) {
          _names[test['id'] as int? ?? -1] = test['name'] as String? ?? '';
        }
      case 'testDone':
        if (decoded['result'] != 'success' &&
            decoded['hidden'] != true &&
            decoded['skipped'] != true) {
          final name = _names[decoded['testID']] ?? '';
          (name.startsWith('loading ') ? loadFailures : testFailures).add(name);
        }
        _names.remove(decoded['testID']);
      case 'error':
        final name = _names[decoded['testID']] ?? '';
        errors.add('$name: ${decoded['error']}');
    }
  }

  /// Names of failed tests: assertion failures and in-test errors.
  final List<String> testFailures = [];

  /// Names of suites that failed to compile or load.
  final List<String> loadFailures = [];

  /// Error messages, each prefixed with its test name.
  final List<String> errors = [];

  /// Human-readable failure summary; empty when nothing failed.
  String summarize() => errors.map((error) => '- $error').join('\n');
}
