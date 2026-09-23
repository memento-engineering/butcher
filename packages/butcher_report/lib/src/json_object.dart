/// Typed reads of one decoded JSON object, with schema-aware error messages.
library;

/// A decoded JSON object being read as one named schema type.
///
/// Every read either returns a value of the schema's declared type or throws a
/// [FormatException] naming both the schema type and the offending field, so a
/// consumer can tell exactly which part of a report document is malformed.
final class JsonObject {
  /// Wraps [fields] as the body of the schema type titled [owner].
  const JsonObject(this.owner, this.fields);

  /// The schema title of the type being read, used in every error message.
  final String owner;

  /// The decoded object's fields.
  final Map<String, Object?> fields;

  /// Wraps [value] as the body of [owner], throwing when it is not an object.
  static JsonObject read(Object? value, String owner) {
    if (value is Map<String, Object?>) {
      return JsonObject(owner, value);
    }
    if (value is Map) {
      return JsonObject(owner, <String, Object?>{
        for (final entry in value.entries) '${entry.key}': entry.value,
      });
    }
    throw FormatException(
      '$owner must be a JSON object, but found ${describeJson(value)}.',
    );
  }

  Object? _present(String field) {
    final value = fields[field];
    if (value == null) {
      throw FormatException('$owner is missing the required field "$field".');
    }
    return value;
  }

  Never _wrongType(String field, String expected, Object? value) {
    throw FormatException(
      '$owner field "$field" must be $expected, but found '
      '${describeJson(value)}.',
    );
  }

  /// Reads the required string [field].
  String requiredString(String field) {
    final value = _present(field);
    if (value is String) return value;
    return _wrongType(field, 'a string', value);
  }

  /// Reads the optional string [field], or null when it is absent.
  String? optionalString(String field) {
    final value = fields[field];
    if (value == null) return null;
    if (value is String) return value;
    return _wrongType(field, 'a string', value);
  }

  /// Reads the required number [field].
  num requiredNumber(String field) {
    final value = _present(field);
    if (value is num) return value;
    return _wrongType(field, 'a number', value);
  }

  /// Reads the optional number [field], or null when it is absent.
  num? optionalNumber(String field) {
    final value = fields[field];
    if (value == null) return null;
    if (value is num) return value;
    return _wrongType(field, 'a number', value);
  }

  /// Reads the required integer [field], bounded by [minimum] and [maximum].
  int requiredInteger(String field, {int? minimum, int? maximum}) {
    final value = _present(field);
    if (value is! int) return _wrongType(field, 'an integer', value);
    return _bounded(field, value, minimum, maximum);
  }

  int _bounded(String field, int value, int? minimum, int? maximum) {
    if (minimum != null && value < minimum) {
      throw FormatException(
        '$owner field "$field" must be at least $minimum, but was $value.',
      );
    }
    if (maximum != null && value > maximum) {
      throw FormatException(
        '$owner field "$field" must be at most $maximum, but was $value.',
      );
    }
    return value;
  }

  /// Reads the required boolean [field].
  bool requiredBoolean(String field) {
    final value = _present(field);
    if (value is bool) return value;
    return _wrongType(field, 'a boolean', value);
  }

  /// Reads the optional boolean [field], or null when it is absent.
  bool? optionalBoolean(String field) {
    final value = fields[field];
    if (value == null) return null;
    if (value is bool) return value;
    return _wrongType(field, 'a boolean', value);
  }

  /// Reads the required free-form object [field].
  Map<String, Object?> requiredFreeFormObject(String field) =>
      read(_present(field), '$owner field "$field"').fields;

  /// Reads the optional free-form object [field], or null when it is absent.
  Map<String, Object?>? optionalFreeFormObject(String field) {
    final value = fields[field];
    if (value == null) return null;
    return read(value, '$owner field "$field"').fields;
  }

  /// Reads the required nested object [field] through [parse].
  T requiredObject<T>(String field, T Function(Object? json) parse) =>
      parse(_present(field));

  /// Reads the optional nested object [field] through [parse].
  T? optionalObject<T>(String field, T Function(Object? json) parse) {
    final value = fields[field];
    if (value == null) return null;
    return parse(value);
  }

  /// Reads the required array [field] as a list of strings.
  List<String> requiredStringList(String field) =>
      _stringList(field, _present(field));

  /// Reads the optional array [field] as a list of strings.
  List<String>? optionalStringList(String field) {
    final value = fields[field];
    if (value == null) return null;
    return _stringList(field, value);
  }

  List<String> _stringList(String field, Object? value) {
    if (value is! List) return _wrongType(field, 'an array of strings', value);
    return <String>[
      for (final element in value)
        if (element is String)
          element
        else
          _wrongType(field, 'an array of strings', element),
    ];
  }

  /// Reads the required array [field], parsing each element with [parse].
  List<T> requiredList<T>(String field, T Function(Object? json) parse) =>
      _list(field, _present(field), parse);

  /// Reads the optional array [field], parsing each element with [parse].
  List<T>? optionalList<T>(String field, T Function(Object? json) parse) {
    final value = fields[field];
    if (value == null) return null;
    return _list(field, value, parse);
  }

  List<T> _list<T>(String field, Object? value, T Function(Object?) parse) {
    if (value is! List) return _wrongType(field, 'an array', value);
    return <T>[for (final element in value) parse(element)];
  }

  /// Reads the required dictionary [field], parsing each value with [parse].
  Map<String, T> requiredDictionary<T>(
    String field,
    T Function(Object? json) parse,
  ) => _dictionary(field, _present(field), parse);

  /// Reads the optional dictionary [field], parsing each value with [parse].
  Map<String, T>? optionalDictionary<T>(
    String field,
    T Function(Object? json) parse,
  ) {
    final value = fields[field];
    if (value == null) return null;
    return _dictionary(field, value, parse);
  }

  Map<String, T> _dictionary<T>(
    String field,
    Object? value,
    T Function(Object?) parse,
  ) {
    final object = read(value, '$owner field "$field"');
    return <String, T>{
      for (final entry in object.fields.entries) entry.key: parse(entry.value),
    };
  }

  /// Reads the optional dictionary [field] as a map of strings to strings.
  Map<String, String>? optionalStringDictionary(String field) {
    final value = fields[field];
    if (value == null) return null;
    final object = read(value, '$owner field "$field"');
    return <String, String>{
      for (final entry in object.fields.entries)
        entry.key: entry.value is String
            ? entry.value! as String
            : _wrongType(field, 'an object of strings', entry.value),
    };
  }
}

/// Names the JSON kind of [value] for an error message.
String describeJson(Object? value) => switch (value) {
  null => 'null',
  String() => 'a string',
  bool() => 'a boolean',
  int() => 'an integer',
  num() => 'a number',
  List() => 'an array',
  Map() => 'an object',
  _ => 'a ${value.runtimeType}',
};
