import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

void main() {
  group('MutantStatus', () {
    test('has exactly the schema\'s eight values', () {
      expect(MutantStatus.values, hasLength(8));
      expect(
        MutantStatus.values.map((status) => status.wireName),
        containsAllInOrder(<String>[
          'Killed',
          'Survived',
          'NoCoverage',
          'CompileError',
          'RuntimeError',
          'Timeout',
          'Ignored',
          'Pending',
        ]),
      );
    });

    test('round-trips every value through its wire name', () {
      for (final status in MutantStatus.values) {
        expect(MutantStatus.fromWireName(status.wireName), status);
      }
    });

    test('throws a format exception naming an unknown value', () {
      expect(
        () => MutantStatus.fromWireName('Murdered'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Murdered'),
          ),
        ),
      );
    });

    test('rejects a differently cased spelling', () {
      expect(() => MutantStatus.fromWireName('killed'), throwsFormatException);
    });
  });
}
