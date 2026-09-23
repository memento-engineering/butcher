import 'package:butcher_process/butcher_process.dart';
import 'package:test/test.dart';

void main() {
  test('the barrel exports the package name', () {
    expect(butcherProcessPackageName, 'butcher_process');
  });
}
