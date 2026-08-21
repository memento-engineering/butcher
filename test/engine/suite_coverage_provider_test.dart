import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:test/test.dart';

/// A mutant on the line [line] of `lib/calc.dart`, whose source is one
/// statement per line.
Mutant mutantOnLine(int line) => Mutant(
  id: 'lib/calc.dart:$line',
  mutation: Mutation(
    filePath: 'lib/calc.dart',
    offset: (line - 1) * 4,
    length: 1,
    original: '+',
    replacement: '-',
    operatorId: 'arithmetic',
    description: 'replace + with -',
  ),
);

/// A provider over `lib/calc.dart` alone: [merged] are its recorded line
/// counts, [perSuite] which lines each test file hit.
SuiteCoverageProvider providerOver({
  required Map<int, int> merged,
  required Map<String, Map<String, Set<int>>> perSuite,
  Map<String, Duration> durations = const {},
}) => SuiteCoverageProvider(
  merged: LcovCoverageProvider(hits: {'lib/calc.dart': merged}),
  perSuite: perSuite,
  durations: durations,
  wholeRun: const Duration(seconds: 30),
)..indexSources({'lib/calc.dart': 'a;\nb;\nc;\nd;\n'});

void main() {
  test('routes a line to the suites that hit it, cheapest first', () {
    final provider = providerOver(
      merged: {1: 2, 2: 1},
      perSuite: {
        'test/slow_test.dart': {
          'lib/calc.dart': {1},
        },
        'test/fast_test.dart': {
          'lib/calc.dart': {1, 2},
        },
      },
      durations: {
        'test/slow_test.dart': const Duration(seconds: 9),
        'test/fast_test.dart': const Duration(seconds: 1),
      },
    );

    expect(provider.suitesFor(mutantOnLine(1))?.map((suite) => suite.path), [
      'test/fast_test.dart',
      'test/slow_test.dart',
    ]);
    expect(provider.suitesFor(mutantOnLine(2))?.map((suite) => suite.path), [
      'test/fast_test.dart',
    ]);
  });

  test('routes an unrecorded line to every suite that loaded its file', () {
    final provider = providerOver(
      merged: {1: 2},
      perSuite: {
        'test/a_test.dart': {
          'lib/calc.dart': {1},
        },
        'test/b_test.dart': {
          'lib/other.dart': {1},
        },
      },
    );

    expect(provider.isCovered(mutantOnLine(3)), isTrue);
    expect(provider.suitesFor(mutantOnLine(3))?.map((suite) => suite.path), [
      'test/a_test.dart',
    ]);
  });

  test('runs the whole suite when no suite covers the mutant', () {
    final provider = providerOver(
      merged: {1: 2},
      perSuite: {
        'test/a_test.dart': {
          'lib/other.dart': {1},
        },
      },
    );

    expect(provider.suitesFor(mutantOnLine(1)), isNull);
  });

  test('sorts a suite the collection run did not time last', () {
    final provider = providerOver(
      merged: {1: 2},
      perSuite: {
        'test/untimed_test.dart': {
          'lib/calc.dart': {1},
        },
        'test/timed_test.dart': {
          'lib/calc.dart': {1},
        },
      },
      durations: {'test/timed_test.dart': const Duration(seconds: 9)},
    );

    final routed = provider.suitesFor(mutantOnLine(1))!;
    expect(routed.map((suite) => suite.path), [
      'test/timed_test.dart',
      'test/untimed_test.dart',
    ]);
    expect(routed.last.duration, const Duration(seconds: 30));
  });
}
