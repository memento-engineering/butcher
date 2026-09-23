import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

void main() {
  const mutation = Mutation(
    filePath: 'lib/a.dart',
    offset: 4,
    length: 1,
    original: '+',
    replacement: '-',
    operatorId: 'arithmetic',
    description: 'replace + with -',
  );
  const mutant = Mutant(id: 'lib/a.dart:4:arithmetic', mutation: mutation);

  test('FullCoverageProvider covers every mutant', () {
    expect(const FullCoverageProvider().isCovered(mutant), isTrue);
  });

  test('FullCoverageProvider routes every mutant to the whole suite', () {
    expect(const FullCoverageProvider().suitesFor(mutant), isNull);
  });
}
