import 'package:sandbox/src/modern.dart';
import 'package:test/test.dart';

void main() {
  group('modern syntax', () {
    test('area of shapes', () {
      expect(area(const Circle(2)), closeTo(12.566, 0.001));
      expect(area(const Circle(0)), 0);
      expect(area(const Circle(-1)), 0);
      expect(area(const Rect(3, 4)), 12);
    });

    test('minMax record', () {
      expect(minMax([3, 1, 4, 1, 5]), (1, 5));
      expect(minMax([7]), (7, 7));
    });

    test('isWide destructuring', () {
      expect(isWide((1500, 10)), isTrue);
      expect(isWide((1000, 10)), isFalse);
      expect(isWide((999, 10)), isFalse);
    });

    test('Meters extension type', () {
      final total = Meters(1.5) + Meters(2.5);
      expect(total.value, 4.0);
      expect(total.isPositive, isTrue);
      expect(Meters(-1).isPositive, isFalse);
      expect(Meters(0).isPositive, isFalse);
    });

    test('compact null-aware elements', () {
      expect(compact(1, 2), [1, 2, 0]);
      expect(compact(null, 2), [2, 0]);
      expect(compact(null, null), [0]);
    });
  });
}
