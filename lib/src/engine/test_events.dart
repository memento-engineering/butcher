import 'dart:convert';

/// Parsed `dart test --reporter json` event stream.
///
/// Structured events keep classification correct even when tests themselves
/// print nested `dart test` output: nested text arrives quoted inside
/// `print` events and never parses as a top-level event.
final class TestEvents {
  TestEvents._();

  /// Parses [output]; lines that are not JSON events are ignored.
  factory TestEvents.parse(String output) {
    final events = TestEvents._();
    final names = <int, String>{};
    for (final line in LineSplitter.split(output)) {
      final Object? decoded;
      try {
        decoded = jsonDecode(line) as Object?;
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;
      switch (decoded['type']) {
        case 'testStart':
          final test = decoded['test'];
          if (test is Map<String, dynamic>) {
            names[test['id'] as int? ?? -1] = test['name'] as String? ?? '';
          }
        case 'testDone':
          if (decoded['result'] != 'success' &&
              decoded['hidden'] != true &&
              decoded['skipped'] != true) {
            final name = names[decoded['testID']] ?? '';
            (name.startsWith('loading ')
                    ? events.loadFailures
                    : events.testFailures)
                .add(name);
          }
        case 'error':
          final name = names[decoded['testID']] ?? '';
          events.errors.add('$name: ${decoded['error']}');
      }
    }
    return events;
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
