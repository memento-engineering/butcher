@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/src/cli/cli.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

const _partiallyTestedCalc = '''
int add(int a, int b) => a + b;
bool isEven(int n) => n % 2 == 0;
''';

void main() {
  test('produces a Stryker JSON report and kills tested mutants', () async {
    final dir = await createFixturePackage(calc: _partiallyTestedCalc);
    final out = StringBuffer();

    final exit = await radMain(['--output', 'report.json', dir.path], out: out);

    expect(exit, 0, reason: out.toString());
    final reportFile = File(p.join(dir.path, 'report.json'));
    expect(reportFile.existsSync(), isTrue);

    final report =
        jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
    final file =
        (report['files'] as Map<String, dynamic>)['lib/calc.dart']
            as Map<String, dynamic>;
    final statusById = {
      for (final raw in file['mutants'] as List<dynamic>)
        (raw as Map<String, dynamic>)['id']: raw['status'],
    };

    expect(statusById['lib/calc.dart:27:arithmetic'], 'Killed');
    expect(statusById['lib/calc.dart:56:arithmetic'], 'Survived');
    expect(statusById['lib/calc.dart:60:equality'], 'Survived');
    expect(out.toString(), contains('MSI: 33.33%'));

    final untouched = File(p.join(dir.path, 'lib', 'calc.dart'));
    expect(untouched.readAsStringSync(), _partiallyTestedCalc);
  });

  test('gates on --threshold via exit code 1', () async {
    final dir = await createFixturePackage(calc: _partiallyTestedCalc);
    final out = StringBuffer();
    final exit = await radMain(['--threshold', '90', dir.path], out: out);
    expect(exit, 1, reason: out.toString());
  });

  test('aborts with exit code 70 on a red background reading', () async {
    final dir = await createFixturePackage(
      calc: 'int add(int a, int b) => a * b;\n',
    );
    final exit = await radMain([dir.path], out: StringBuffer());
    expect(exit, 70);
  });

  test('rejects an invalid threshold with exit code 64', () async {
    expect(await radMain(['--threshold', 'nope'], out: StringBuffer()), 64);
  });
}
