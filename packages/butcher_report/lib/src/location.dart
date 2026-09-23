/// The `Position`, `Location` and `OpenEndLocation` types of the schema.
library;

import 'json_object.dart';

/// A point in a source file.
///
/// Both [line] and [column] start at one, as the schema's `Position`
/// definition states; a zero or negative value is rejected on parse. A
/// character offset is not part of the schema, so callers that work in offsets
/// convert before building a position.
final class Position {
  /// Creates the position at [line] and [column], both one-based.
  const Position({required this.line, required this.column});

  /// The schema fields a position must carry.
  static const requiredJsonFields = <String>{'line', 'column'};

  /// The schema fields a position may carry.
  static const optionalJsonFields = <String>{};

  /// Reads a position from decoded JSON.
  static Position fromJson(Object? json) {
    final object = JsonObject.read(json, 'Position');
    return Position(
      line: object.requiredInteger('line', minimum: 1),
      column: object.requiredInteger('column', minimum: 1),
    );
  }

  /// The one-based line.
  final int line;

  /// The one-based column.
  final int column;

  /// Writes this position as decoded JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'line': line,
    'column': column,
  };

  @override
  bool operator ==(Object other) =>
      other is Position && other.line == line && other.column == column;

  @override
  int get hashCode => Object.hash(line, column);

  @override
  String toString() => 'Position(line: $line, column: $column)';
}

/// The span a mutation covers.
///
/// [start] is inclusive and [end] is exclusive, as the schema's `Location`
/// definition states, so a one-character mutation at line 4 column 3 ends at
/// line 4 column 4.
final class Location {
  /// Creates the span from the inclusive [start] to the exclusive [end].
  const Location({required this.start, required this.end});

  /// The schema fields a location must carry.
  static const requiredJsonFields = <String>{'start', 'end'};

  /// The schema fields a location may carry.
  static const optionalJsonFields = <String>{};

  /// Reads a location from decoded JSON.
  static Location fromJson(Object? json) {
    final object = JsonObject.read(json, 'Location');
    return Location(
      start: object.requiredObject('start', Position.fromJson),
      end: object.requiredObject('end', Position.fromJson),
    );
  }

  /// The first position the mutation covers.
  final Position start;

  /// The first position after the mutation, which it does not cover.
  final Position end;

  /// Writes this location as decoded JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'start': start.toJson(),
    'end': end.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is Location && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Location(start: $start, end: $end)';
}

/// The span a test definition covers, whose end may be unknown.
///
/// [start] is inclusive and [end], when present, is exclusive. The schema
/// keeps this separate from [Location] because a test framework often reports
/// where a test begins without reporting where it stops.
final class OpenEndLocation {
  /// Creates the span from the inclusive [start] to the exclusive [end].
  const OpenEndLocation({required this.start, this.end});

  /// The schema fields an open-ended location must carry.
  static const requiredJsonFields = <String>{'start'};

  /// The schema fields an open-ended location may carry.
  static const optionalJsonFields = <String>{'end'};

  /// Reads an open-ended location from decoded JSON.
  static OpenEndLocation fromJson(Object? json) {
    final object = JsonObject.read(json, 'OpenEndLocation');
    return OpenEndLocation(
      start: object.requiredObject('start', Position.fromJson),
      end: object.optionalObject('end', Position.fromJson),
    );
  }

  /// The first position the test covers.
  final Position start;

  /// The first position after the test, or null when the producer omits it.
  final Position? end;

  /// Writes this location as decoded JSON, omitting an absent end.
  Map<String, Object?> toJson() => <String, Object?>{
    'start': start.toJson(),
    if (end case final end?) 'end': end.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is OpenEndLocation && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'OpenEndLocation(start: $start, end: $end)';
}
