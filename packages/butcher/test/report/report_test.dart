import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

MutantResult result(Outcome outcome, {int offset = 27, String id = 'm'}) =>
    MutantResult(
      mutant: Mutant(
        id: id,
        mutation: Mutation(
          filePath: 'lib/a.dart',
          offset: offset,
          length: 1,
          original: '+',
          replacement: '-',
          mutatorId: 'arithmetic',
          description: 'replace + with -',
        ),
      ),
      outcome: outcome,
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

    final dir = await Directory.systemTemp.createTemp('butcher_status_');
    addTearDown(() => dir.delete(recursive: true));
    final output = p.join(dir.path, 'report.json');

    await StrykerJsonSink(
      sources: {'lib/a.dart': '// header\nint add(int a, int b) => a + b;\n'},
      outputPath: output,
    ).write([
      for (final outcome in Outcome.values)
        result(outcome, offset: 37, id: outcome.name),
    ]);

    final report =
        jsonDecode(File(output).readAsStringSync()) as Map<String, dynamic>;
    final mutants =
        ((report['files'] as Map<String, dynamic>)['lib/a.dart']
                as Map<String, dynamic>)['mutants']
            as List<dynamic>;
    expect(
      {
        for (final mutant in mutants.cast<Map<String, dynamic>>())
          mutant['id'] as String: mutant['status'] as String,
      },
      {for (final outcome in Outcome.values) outcome.name: expected[outcome]!},
    );
  });
}
