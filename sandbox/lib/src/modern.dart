/// Modern Dart 3.x syntax showcase, used to probe how well mutation tools
/// parse and mutate current language features.
library;

/// Sealed class hierarchy (Dart 3.0) with class modifiers.
sealed class Shape {
  const Shape();
}

final class Circle extends Shape {
  const Circle(this.radius);
  final double radius;
}

final class Rect extends Shape {
  const Rect(this.width, this.height);
  final double width;
  final double height;
}

/// Switch expression with patterns and guards (Dart 3.0).
double area(Shape shape) => switch (shape) {
      Circle(radius: final r) when r > 0 => 3.14159 * r * r,
      Circle() => 0,
      Rect(width: final w, height: final h) => w * h,
    };

/// Records (Dart 3.0): positional + named fields.
(int, int) minMax(List<int> values) {
  var min = values.first;
  var max = values.first;
  for (final v in values) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return (min, max);
}

/// Destructuring with patterns, digit separators (Dart 3.6),
/// wildcard variables (Dart 3.7).
bool isWide((int width, int height) size) {
  final (w, _) = size;
  return w > 1_000;
}

/// Extension type (Dart 3.3).
extension type Meters(double value) {
  Meters operator +(Meters other) => Meters(value + other.value);
  bool get isPositive => value > 0;
}

/// Null-aware elements in collection literals (Dart 3.8).
List<int> compact(int? a, int? b) => [?a, ?b, 0];
