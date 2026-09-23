/// The `MutantResult` type of the mutation-testing report schema.
library;

import 'equality.dart';
import 'json_object.dart';
import 'location.dart';
import 'mutant_status.dart';

/// One mutant's result inside a file's entry of a report.
///
/// Four fields are required — [id], [mutatorName], [location] and [status] —
/// and the other eight are optional. An absent optional is omitted from
/// [toJson] rather than written as null, because the schema distinguishes a
/// field a producer did not measure from one it measured as empty.
final class ReportMutant {
  /// Creates a mutant result.
  const ReportMutant({
    required this.id,
    required this.mutatorName,
    required this.location,
    required this.status,
    this.coveredBy,
    this.description,
    this.duration,
    this.killedBy,
    this.replacement,
    this.isStatic,
    this.statusReason,
    this.testsCompleted,
  });

  /// The schema fields a mutant result must carry.
  static const requiredJsonFields = <String>{
    'id',
    'mutatorName',
    'location',
    'status',
  };

  /// The schema fields a mutant result may carry.
  static const optionalJsonFields = <String>{
    'coveredBy',
    'description',
    'duration',
    'killedBy',
    'replacement',
    'static',
    'statusReason',
    'testsCompleted',
  };

  /// Reads a mutant result from decoded JSON.
  static ReportMutant fromJson(Object? json) {
    final object = JsonObject.read(json, 'MutantResult');
    return ReportMutant(
      id: object.requiredString('id'),
      mutatorName: object.requiredString('mutatorName'),
      location: object.requiredObject('location', Location.fromJson),
      status: MutantStatus.fromWireName(object.requiredString('status')),
      coveredBy: object.optionalStringList('coveredBy'),
      description: object.optionalString('description'),
      duration: object.optionalNumber('duration'),
      killedBy: object.optionalStringList('killedBy'),
      replacement: object.optionalString('replacement'),
      isStatic: object.optionalBoolean('static'),
      statusReason: object.optionalString('statusReason'),
      testsCompleted: object.optionalNumber('testsCompleted'),
    );
  }

  /// Unique id, used to correlate this mutant across reports.
  final String id;

  /// The category of the mutation, such as `ConditionalExpression`.
  final String mutatorName;

  /// The span the mutation covers, start inclusive and end exclusive.
  final Location location;

  /// The outcome of testing this mutant.
  final MutantStatus status;

  /// The ids of the tests that covered this mutant.
  ///
  /// Null when the producer does not measure coverage, which the schema
  /// distinguishes from an empty list meaning nothing covered it.
  final List<String>? coveredBy;

  /// A human-readable description of the applied mutation.
  final String? description;

  /// The net time testing this mutant took, in milliseconds.
  ///
  /// The schema types this as a number rather than an integer, so a producer
  /// reporting fractional milliseconds round-trips.
  final num? duration;

  /// The ids of the tests that killed this mutant.
  final List<String>? killedBy;

  /// The text the mutation put in place of the original.
  final String? replacement;

  /// Whether the mutant is static: loaded once during initialization.
  ///
  /// Named for Dart, since `static` is a reserved word; the wire spelling is
  /// `static`.
  final bool? isStatic;

  /// Why the mutant has this status, such as a failure or error message.
  final String? statusReason;

  /// How many tests actually ran against this mutant.
  ///
  /// Can differ from [coveredBy] when the producer bails on the first failing
  /// test. The schema types it as a number.
  final num? testsCompleted;

  /// Writes this mutant as decoded JSON, omitting every absent optional.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'mutatorName': mutatorName,
    'location': location.toJson(),
    'status': status.wireName,
    'coveredBy': ?coveredBy,
    'description': ?description,
    'duration': ?duration,
    'killedBy': ?killedBy,
    'replacement': ?replacement,
    'static': ?isStatic,
    'statusReason': ?statusReason,
    'testsCompleted': ?testsCompleted,
  };

  @override
  bool operator ==(Object other) =>
      other is ReportMutant &&
      other.id == id &&
      other.mutatorName == mutatorName &&
      other.location == location &&
      other.status == status &&
      deepEquals(other.coveredBy, coveredBy) &&
      other.description == description &&
      other.duration == duration &&
      deepEquals(other.killedBy, killedBy) &&
      other.replacement == replacement &&
      other.isStatic == isStatic &&
      other.statusReason == statusReason &&
      other.testsCompleted == testsCompleted;

  @override
  int get hashCode => Object.hash(
    id,
    mutatorName,
    location,
    status,
    deepHash(coveredBy),
    description,
    duration,
    deepHash(killedBy),
    replacement,
    isStatic,
    statusReason,
    testsCompleted,
  );

  @override
  String toString() =>
      'ReportMutant(id: $id, mutatorName: $mutatorName, '
      'location: $location, status: ${status.wireName})';
}
