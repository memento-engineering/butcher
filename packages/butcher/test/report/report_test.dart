import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher_report/butcher_report.dart' as schema;
import 'package:test/test.dart';

MutantResult result(
  Outcome outcome, {
  int offset = 27,
  String id = 'm',
  String filePath = 'lib/a.dart',
  TestRun? testRun,
  String? error,
}) => MutantResult(
  mutant: Mutant(
    id: id,
    mutation: Mutation(
      filePath: filePath,
      offset: offset,
      length: 1,
      original: '+',
      replacement: '-',
      mutatorId: 'arithmetic',
      description: 'replace + with -',
    ),
  ),
  outcome: outcome,
  testRun: testRun,
  error: error,
);

/// Writes [results] through the sink and returns the JSON text it wrote.
Future<String> writeReport(
  List<MutantResult> results, {
  Map<String, String> sources = const {
    'lib/a.dart': '// header\nint add(int a, int b) => a + b;\n',
  },
}) async {
  final dir = await Directory.systemTemp.createTemp('butcher_report_');
  addTearDown(() => dir.delete(recursive: true));
  final output = p.join(dir.path, 'report.json');
  await StrykerJsonSink(sources: sources, outputPath: output).write(results);
  return File(output).readAsStringSync();
}

/// The mutant entries of `lib/a.dart` in a decoded [report].
List<Map<String, dynamic>> mutantsOf(Map<String, dynamic> report) =>
    (((report['files'] as Map<String, dynamic>)['lib/a.dart']
                as Map<String, dynamic>)['mutants']
            as List<dynamic>)
        .cast<Map<String, dynamic>>();

/// Every outcome's mutant, written in taxonomy order under one id each.
Future<List<Map<String, dynamic>>> everyOutcomeWritten() async => mutantsOf(
  jsonDecode(
        await writeReport([
          for (final outcome in Outcome.values)
            result(outcome, offset: 37, id: outcome.name),
        ]),
      )
      as Map<String, dynamic>,
);

void main() {
  group('Metrics', () {
    test('keeps timeouts out of both MSI terms', () {
      final metrics = Metrics.fromResults([
        result(Outcome.killed),
        result(Outcome.timeout),
        result(Outcome.survived),
        result(Outcome.noCoverage),
        result(Outcome.runError),
        result(Outcome.unviable),
      ]);
      expect(metrics.killed, 1);
      expect(metrics.survived, 1);
      expect(metrics.uncovered, 1);
      expect(metrics.timedOut, 1);
      expect(metrics.msi, closeTo(33.33, 0.01));
      expect(metrics.coveredMsi, 50);
      expect(metrics.timeoutRate, closeTo(33.33, 0.01));
    });

    test('has no score when nothing is scoreable', () {
      expect(Metrics.fromResults([]).msi, isNull);
      expect(Metrics.fromResults([result(Outcome.runError)]).msi, isNull);
      expect(Metrics.fromResults([result(Outcome.timeout)]).msi, isNull);
      expect(Metrics.fromResults([]).coveredMsi, isNull);
      expect(Metrics.fromResults([]).timeoutRate, 0);
    });
  });

  test('ConsoleReportSink prints counts and both scores', () async {
    final out = StringBuffer();
    await ConsoleReportSink(
      out: out,
    ).write([result(Outcome.killed), result(Outcome.survived)]);
    final text = out.toString();
    expect(text, contains('2 mutants:'));
    expect(text, contains('killed: 1'));
    expect(text, contains('survived: 1'));
    expect(text, contains('MSI: 50.00%'));
    expect(text, isNot(contains('timeout')));
  });

  test('ConsoleReportSink reports timeouts as an inconclusive peer', () async {
    final out = StringBuffer();
    await ConsoleReportSink(out: out).write([
      result(Outcome.killed),
      result(Outcome.survived),
      result(Outcome.timeout),
    ]);
    final text = out.toString();
    expect(text, contains('timeout: 1'));
    expect(text, contains('MSI: 50.00%'));
    expect(text, contains('Timeout rate: 33.33%'));
  });

  test('ConsoleReportSink reports a no-score run explicitly', () async {
    final out = StringBuffer();
    await ConsoleReportSink(out: out).write([result(Outcome.timeout)]);
    final text = out.toString();
    expect(text, contains('MSI: none (no scoreable mutants)'));
    expect(text, contains('Covered-code MSI: none (no scoreable mutants)'));
  });

  test(
    'StrykerJsonSink writes schema-shaped JSON with 1-based positions',
    () async {
      final dir = await Directory.systemTemp.createTemp('butcher_report_');
      addTearDown(() => dir.delete(recursive: true));
      final output = p.join(dir.path, 'report.json');

      await StrykerJsonSink(
        sources: {'lib/a.dart': '// header\nint add(int a, int b) => a + b;\n'},
        outputPath: output,
      ).write([
        result(Outcome.killed, offset: 37, id: 'lib/a.dart:37:arithmetic:-'),
      ]);

      final report =
          jsonDecode(File(output).readAsStringSync()) as Map<String, dynamic>;
      expect(report['schemaVersion'], '1');
      final file =
          (report['files'] as Map<String, dynamic>)['lib/a.dart']
              as Map<String, dynamic>;
      expect(file['language'], 'dart');
      expect(file['source'], contains('int add'));
      final mutant =
          (file['mutants'] as List<dynamic>).single as Map<String, dynamic>;
      expect(mutant['status'], 'Killed');
      expect(mutant['mutatorName'], 'arithmetic');
      expect(mutant['location'], {
        'start': {'line': 2, 'column': 28},
        'end': {'line': 2, 'column': 29},
      });
    },
  );

  test('StrykerJsonSink emits the interop status names unchanged', () async {
    // Wire names on a published schema: they survive every rename of the
    // tool's own vocabulary, so each one is pinned as it is emitted.
    const expected = {
      Outcome.killed: 'Killed',
      Outcome.survived: 'Survived',
      Outcome.noCoverage: 'NoCoverage',
      Outcome.timeout: 'Timeout',
      Outcome.unviable: 'CompileError',
      Outcome.runError: 'RuntimeError',
      Outcome.memoryError: 'RuntimeError',
      Outcome.equivalent: 'Ignored',
    };
    expect(
      expected.keys,
      containsAll(Outcome.values),
      reason: 'every outcome maps to a wire name',
    );

    final mutants = await everyOutcomeWritten();
    expect(
      {
        for (final mutant in mutants)
          mutant['id'] as String: mutant['status'] as String,
      },
      {for (final outcome in Outcome.values) outcome.name: expected[outcome]!},
    );
  });

  test(
    'StrykerJsonSink writes the version and thresholds it declares',
    () async {
      final report =
          jsonDecode(await writeReport([result(Outcome.killed, offset: 37)]))
              as Map<String, dynamic>;
      expect(report['schemaVersion'], strykerSchemaVersion);
      expect(report['thresholds'], {
        'high': strykerHighThreshold,
        'low': strykerLowThreshold,
      });
    },
  );

  test('StrykerJsonSink explains the failures a status cannot', () async {
    // Two outcomes collapse onto RuntimeError and a third, unviable, has a
    // status nobody can read; all three get a reason. The memory error is
    // reserved — no classification path assigns it — so this result is
    // constructed directly rather than driven through a run.
    final mutants = await everyOutcomeWritten();
    final reasons = {
      for (final mutant in mutants)
        mutant['id'] as String: mutant['statusReason'],
    };

    const explained = [Outcome.runError, Outcome.memoryError, Outcome.unviable];
    for (final outcome in explained) {
      expect(
        reasons[outcome.name],
        allOf(isA<String>(), isNotEmpty),
        reason: '${outcome.name} must say why',
      );
    }
    expect(
      {for (final outcome in explained) reasons[outcome.name]}.length,
      explained.length,
      reason: 'the collapse onto RuntimeError must stay distinguishable',
    );

    for (final outcome in Outcome.values.toSet().difference(
      explained.toSet(),
    )) {
      expect(
        reasons[outcome.name],
        isNull,
        reason: '${outcome.name} speaks for itself',
      );
    }
  });

  test(
    'StrykerJsonSink emits the measured duration, not attribution',
    () async {
      final mutants = mutantsOf(
        jsonDecode(
              await writeReport([
                result(
                  Outcome.killed,
                  offset: 37,
                  id: 'measured',
                  testRun: const TestRun(
                    exitCode: 1,
                    timedOut: false,
                    output: '',
                    duration: Duration(milliseconds: 1234),
                  ),
                ),
                result(Outcome.noCoverage, offset: 37, id: 'unrun'),
              ]),
            )
            as Map<String, dynamic>,
      );
      final byId = {
        for (final mutant in mutants) mutant['id'] as String: mutant,
      };

      expect(byId['measured']!['duration'], 1234);
      expect(
        byId['unrun'],
        isNot(contains('duration')),
        reason: 'no run, nothing measured',
      );
      for (final field in ['coveredBy', 'killedBy', 'testsCompleted']) {
        expect(
          byId['measured'],
          isNot(contains(field)),
          reason: 'the runner carries no per-test identity',
        );
      }
    },
  );

  test('StrykerJsonSink quotes the diagnostic behind a run error', () async {
    final mutants = mutantsOf(
      jsonDecode(
            await writeReport([
              result(
                Outcome.runError,
                offset: 37,
                id: 'crashed',
                error: 'PathNotFoundException: no such directory\n  #0 main',
              ),
            ]),
          )
          as Map<String, dynamic>,
    );
    expect(
      mutants.single['statusReason'],
      contains('PathNotFoundException: no such directory'),
    );
    expect(mutants.single['statusReason'], isNot(contains('#0 main')));
  });

  test('StrykerJsonSink writes a document the schema package parses', () async {
    TestRun ran(int milliseconds) => TestRun(
      exitCode: 1,
      timedOut: false,
      output: '',
      duration: Duration(milliseconds: milliseconds),
    );
    final results = [
      result(Outcome.killed, offset: 37, id: 'a', testRun: ran(12)),
      result(Outcome.survived, offset: 39, id: 'b', testRun: ran(345)),
      result(Outcome.unviable, offset: 37, id: 'c'),
      result(
        Outcome.runError,
        offset: 39,
        id: 'd',
        error: 'StateError: the sandbox vanished',
      ),
      result(Outcome.memoryError, offset: 37, id: 'e'),
      result(
        Outcome.noCoverage,
        offset: 12,
        id: 'f',
        filePath: 'lib/b.dart',
        testRun: ran(7),
      ),
    ];

    // Round trip: the written bytes go back through the report package's own
    // parser, which reds if any field the schema requires went missing.
    final parsed = schema.parseMutationTestReport(
      await writeReport(
        results,
        sources: const {
          'lib/a.dart': '// header\nint add(int a, int b) => a + b;\n',
          'lib/b.dart': 'bool ok() => true;\n',
        },
      ),
    );

    expect(parsed.schemaVersion, strykerSchemaVersion);
    expect(
      parsed.thresholds,
      const schema.Thresholds(
        high: strykerHighThreshold,
        low: strykerLowThreshold,
      ),
    );
    expect(parsed.files.keys, ['lib/a.dart', 'lib/b.dart']);
    expect(parsed.files['lib/b.dart']!.source, 'bool ok() => true;\n');

    final mutants = [for (final file in parsed.files.values) ...file.mutants];
    expect(mutants, hasLength(results.length));
    expect(
      {for (final mutant in mutants) mutant.id: mutant.status.wireName},
      {
        'a': 'Killed',
        'b': 'Survived',
        'c': 'CompileError',
        'd': 'RuntimeError',
        'e': 'RuntimeError',
        'f': 'NoCoverage',
      },
    );
    expect(
      {for (final mutant in mutants) mutant.id: mutant.duration},
      {'a': 12, 'b': 345, 'c': null, 'd': null, 'e': null, 'f': 7},
    );
    final reasons = {
      for (final mutant in mutants) mutant.id: mutant.statusReason,
    };
    expect(reasons['a'], isNull);
    expect(reasons['b'], isNull);
    expect(reasons['f'], isNull);
    expect(reasons['d'], contains('StateError: the sandbox vanished'));
    expect(
      {reasons['c'], reasons['d'], reasons['e']}.length,
      3,
      reason: 'the three explained failures stay distinguishable',
    );
  });
}
