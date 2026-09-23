/// Hand-written structural equality and hashing for the schema value types.
///
/// The report models compare by value, and several of their fields are lists,
/// dictionaries or the schema's free-form `config` object. Writing the deep
/// comparison here keeps every model's `==` hand-written and keeps the package
/// free of any runtime dependency.
library;

/// Whether [a] and [b] are equal, comparing lists and maps element by element.
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List) {
    if (b is! List || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map) {
    if (b is! Map || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  return a == b;
}

/// A hash of [value] consistent with [deepEquals].
///
/// Lists hash in order; maps hash their entries without order, so two equal
/// dictionaries built in different insertion orders hash alike.
int deepHash(Object? value) {
  if (value is List) {
    return Object.hashAll(<Object?>[
      for (final element in value) deepHash(element),
    ]);
  }
  if (value is Map) {
    return Object.hashAllUnordered(<Object?>[
      for (final entry in value.entries)
        Object.hash(deepHash(entry.key), deepHash(entry.value)),
    ]);
  }
  return value.hashCode;
}
