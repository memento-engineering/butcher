import 'package:butcher_process/butcher_process.dart';
import 'package:test/test.dart';

void main() {
  test('the factory returns an interlock for the host platform', () {
    final interlock = ProcessInterlock.create();
    expect(interlock, isNotNull);
    interlock.dispose();
  });

  test('dispose is idempotent', () {
    final interlock = ProcessInterlock.create();
    interlock.dispose();
    expect(interlock.dispose, returnsNormally);
  });
}
