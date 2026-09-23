/// The `Thresholds` type of the mutation-testing report schema.
library;

import 'json_object.dart';

/// The mutation-score bands a report is graded against.
///
/// Both bounds are percentages: integers from 0 to 100 inclusive, which parse
/// enforces. A score at or above [high] is good, a score below [low] is bad,
/// and anything between is a warning.
final class Thresholds {
  /// Creates the bands with the given [high] and [low] percentages.
  const Thresholds({required this.high, required this.low});

  /// The schema fields thresholds must carry.
  static const requiredJsonFields = <String>{'high', 'low'};

  /// The schema fields thresholds may carry.
  static const optionalJsonFields = <String>{};

  /// The smallest percentage the schema allows for either bound.
  static const minimumPercentage = 0;

  /// The largest percentage the schema allows for either bound.
  static const maximumPercentage = 100;

  /// Reads thresholds from decoded JSON.
  static Thresholds fromJson(Object? json) {
    final object = JsonObject.read(json, 'Thresholds');
    return Thresholds(
      high: object.requiredInteger(
        'high',
        minimum: minimumPercentage,
        maximum: maximumPercentage,
      ),
      low: object.requiredInteger(
        'low',
        minimum: minimumPercentage,
        maximum: maximumPercentage,
      ),
    );
  }

  /// The upper bound percentage.
  final int high;

  /// The lower bound percentage.
  final int low;

  /// Writes these thresholds as decoded JSON.
  Map<String, Object?> toJson() => <String, Object?>{'high': high, 'low': low};

  @override
  bool operator ==(Object other) =>
      other is Thresholds && other.high == high && other.low == low;

  @override
  int get hashCode => Object.hash(high, low);

  @override
  String toString() => 'Thresholds(high: $high, low: $low)';
}
