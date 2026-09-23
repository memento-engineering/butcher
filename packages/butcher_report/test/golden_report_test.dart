import 'dart:convert';
import 'dart:io';

import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

/// The fixture document, read relative to the package root the suite runs in.
final _source = File('test/fixtures/full_report.json').readAsStringSync();

void main() {
  group('the golden report', () {
    final decoded = jsonDecode(_source) as Map<String, Object?>;

    test('parses identically through both entry points', () {
      expect(
        parseMutationTestReport(_source),
        parseMutationTestReportJson(decoded),
      );
    });

    test('emits the source document again from both entry points', () {
      final fromString = parseMutationTestReport(_source).toJson();
      final fromJson = parseMutationTestReportJson(decoded).toJson();
      expect(fromString, decoded);
      expect(fromJson, decoded);
      expect(fromString, fromJson);
    });

    test('survives a second round trip through encoded text', () {
      final once = parseMutationTestReport(_source);
      final twice = parseMutationTestReport(jsonEncode(once.toJson()));
      expect(twice, once);
      expect(twice.toJson(), decoded);
    });

    test('exercises every status the schema declares', () {
      final report = parseMutationTestReport(_source);
      final seen = <MutantStatus>{
        for (final file in report.files.values)
          for (final mutant in file.mutants) mutant.status,
      };
      expect(seen, MutantStatus.values.toSet());
    });

    test('reaches all four nesting levels', () {
      final report = parseMutationTestReport(_source);
      final file = report.files['lib/src/adder.dart']!;
      final mutant = file.mutants.first;
      expect(report.schemaVersion, '2.0.0');
      expect(file.language, 'dart');
      expect(mutant.id, '1');
      expect(mutant.location.start, const Position(line: 1, column: 27));
      expect(mutant.coveredBy, <String>['t1', 't2']);
      expect(mutant.isStatic, isFalse);
      expect(mutant.testsCompleted, 1);
    });

    test('keeps the free-form config untouched, nulls and all', () {
      final report = parseMutationTestReport(_source);
      expect(report.config, decoded['config']);
      final nested = report.config!['nested']! as Map<String, Object?>;
      expect(nested.containsKey('absent'), isTrue);
      expect(nested['absent'], isNull);
    });

    test('keeps a test definition whose location has no end', () {
      final report = parseMutationTestReport(_source);
      final tests = report.testFiles!['test/adder_test.dart']!.tests;
      expect(tests.last.location!.end, isNull);
      expect(
        report.testFiles!['AdderClassTests']!.tests.single.location,
        isNull,
      );
    });

    test('rejects the document with any required field removed', () {
      for (final field in MutationTestResult.requiredJsonFields) {
        final broken = Map<String, Object?>.of(decoded)..remove(field);
        expect(
          () => parseMutationTestReportJson(broken),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(field),
            ),
          ),
          reason: 'the golden document must not survive losing $field',
        );
      }
    });

    test('rejects text that is not a JSON object', () {
      expect(() => parseMutationTestReport('[]'), throwsFormatException);
      expect(() => parseMutationTestReport('"1"'), throwsFormatException);
    });
  });
}
