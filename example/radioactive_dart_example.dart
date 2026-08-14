import 'package:radioactive_dart/radioactive_dart.dart';

void main() {
  const mutation = Mutation(
    filePath: 'lib/circle.dart',
    offset: 42,
    length: 1,
    original: '*',
    replacement: '/',
    operatorId: 'arithmetic',
    description: 'replace * with /',
  );
  const mutant = Mutant(
    id: 'lib/circle.dart:42:arithmetic',
    mutation: mutation,
  );

  const coverage = FullCoverageProvider();
  const selector = WholeSuiteSelector();

  print('covered: ${coverage.isCovered(mutant)}');
  print('tests to run: ${selector.select(mutant) ?? 'whole suite'}');
}
