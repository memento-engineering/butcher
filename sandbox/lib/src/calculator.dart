/// Well-tested arithmetic helpers. Mutations here should mostly be killed.
class Calculator {
  int add(int a, int b) => a + b;

  int subtract(int a, int b) => a - b;

  int multiply(int a, int b) => a * b;

  /// Integer division that throws on division by zero.
  int divide(int a, int b) {
    if (b == 0) {
      throw ArgumentError('division by zero');
    }
    return a ~/ b;
  }

  /// Returns the larger of two values.
  int max(int a, int b) {
    if (a > b) {
      return a;
    }
    return b;
  }

  /// True if [value] lies in the inclusive range [low, high].
  bool inRange(int value, int low, int high) {
    return value >= low && value <= high;
  }
}
