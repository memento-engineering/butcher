import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';

void main() {
  group('Calculator (well tested)', () {
    final calc = Calculator();

    test('add', () {
      expect(calc.add(2, 3), 5);
      expect(calc.add(-2, 2), 0);
    });

    test('subtract', () {
      expect(calc.subtract(5, 3), 2);
      expect(calc.subtract(3, 5), -2);
    });

    test('multiply', () {
      expect(calc.multiply(3, 4), 12);
      expect(calc.multiply(3, 0), 0);
      expect(calc.multiply(-3, 4), -12);
    });

    test('divide', () {
      expect(calc.divide(10, 3), 3);
      expect(calc.divide(9, 3), 3);
      expect(() => calc.divide(1, 0), throwsArgumentError);
    });

    test('max', () {
      expect(calc.max(1, 2), 2);
      expect(calc.max(2, 1), 2);
      expect(calc.max(3, 3), 3);
    });

    test('inRange', () {
      expect(calc.inRange(5, 1, 10), isTrue);
      expect(calc.inRange(1, 1, 10), isTrue);
      expect(calc.inRange(10, 1, 10), isTrue);
      expect(calc.inRange(0, 1, 10), isFalse);
      expect(calc.inRange(11, 1, 10), isFalse);
    });
  });

  group('DiscountService (weakly tested)', () {
    final service = DiscountService();

    // Only one happy-path case; boundaries, VIP logic and null handling are
    // never exercised, so mutations there should survive.
    test('gives 10 percent above 100', () {
      expect(service.discountFor(total: 200), 10.0);
    });

    // Result is only checked loosely, so many mutations survive.
    test('apply returns something non-negative', () {
      expect(service.apply(200, 10), greaterThanOrEqualTo(0));
    });
  });
}
