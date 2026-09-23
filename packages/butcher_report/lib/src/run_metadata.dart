/// The optional run-metadata types of the mutation-testing report schema:
/// `PerformanceStatistics`, `FrameworkInformation` and `SystemInformation`.
library;

import 'equality.dart';
import 'json_object.dart';

/// How long each phase of a mutation run took, in milliseconds.
///
/// The three phases are required and should roughly sum to the wall time of
/// the whole run. The schema types each as a number, not an integer.
final class PerformanceStatistics {
  /// Creates the per-phase timings.
  const PerformanceStatistics({
    required this.setup,
    required this.initialRun,
    required this.mutation,
  });

  /// The schema fields performance statistics must carry.
  static const requiredJsonFields = <String>{'setup', 'initialRun', 'mutation'};

  /// The schema fields performance statistics may carry.
  static const optionalJsonFields = <String>{};

  /// Reads performance statistics from decoded JSON.
  static PerformanceStatistics fromJson(Object? json) {
    final object = JsonObject.read(json, 'PerformanceStatistics');
    return PerformanceStatistics(
      setup: object.requiredNumber('setup'),
      initialRun: object.requiredNumber('initialRun'),
      mutation: object.requiredNumber('mutation'),
    );
  }

  /// Time the setup phase took, in milliseconds.
  final num setup;

  /// Time the initial, unmutated test run took, in milliseconds.
  final num initialRun;

  /// Time the mutation phase took, in milliseconds.
  final num mutation;

  /// Writes these statistics as decoded JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'setup': setup,
    'initialRun': initialRun,
    'mutation': mutation,
  };

  @override
  bool operator ==(Object other) =>
      other is PerformanceStatistics &&
      other.setup == setup &&
      other.initialRun == initialRun &&
      other.mutation == mutation;

  @override
  int get hashCode => Object.hash(setup, initialRun, mutation);

  @override
  String toString() =>
      'PerformanceStatistics(setup: $setup, initialRun: $initialRun, '
      'mutation: $mutation)';
}

/// Which mutation-testing framework produced the report.
final class FrameworkInformation {
  /// Creates the framework record for the framework called [name].
  const FrameworkInformation({
    required this.name,
    this.version,
    this.branding,
    this.dependencies,
  });

  /// The schema fields framework information must carry.
  static const requiredJsonFields = <String>{'name'};

  /// The schema fields framework information may carry.
  static const optionalJsonFields = <String>{
    'version',
    'branding',
    'dependencies',
  };

  /// Reads framework information from decoded JSON.
  static FrameworkInformation fromJson(Object? json) {
    final object = JsonObject.read(json, 'FrameworkInformation');
    return FrameworkInformation(
      name: object.requiredString('name'),
      version: object.optionalString('version'),
      branding: object.optionalObject('branding', BrandingInformation.fromJson),
      dependencies: object.optionalStringDictionary('dependencies'),
    );
  }

  /// The framework's name.
  final String name;

  /// The framework's version.
  final String? version;

  /// How a report viewer should brand the framework.
  final BrandingInformation? branding;

  /// The framework's own dependencies, by name and version.
  final Map<String, String>? dependencies;

  /// Writes this record as decoded JSON, omitting every absent optional.
  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'version': ?version,
    if (branding case final branding?) 'branding': branding.toJson(),
    'dependencies': ?dependencies,
  };

  @override
  bool operator ==(Object other) =>
      other is FrameworkInformation &&
      other.name == name &&
      other.version == version &&
      other.branding == branding &&
      deepEquals(other.dependencies, dependencies);

  @override
  int get hashCode =>
      Object.hash(name, version, branding, deepHash(dependencies));

  @override
  String toString() => 'FrameworkInformation(name: $name, version: $version)';
}

/// How a report viewer should brand the producing framework.
final class BrandingInformation {
  /// Creates the branding record pointing at [homepageUrl].
  const BrandingInformation({required this.homepageUrl, this.imageUrl});

  /// The schema fields branding information must carry.
  static const requiredJsonFields = <String>{'homepageUrl'};

  /// The schema fields branding information may carry.
  static const optionalJsonFields = <String>{'imageUrl'};

  /// Reads branding information from decoded JSON.
  static BrandingInformation fromJson(Object? json) {
    final object = JsonObject.read(json, 'BrandingInformation');
    return BrandingInformation(
      homepageUrl: object.requiredString('homepageUrl'),
      imageUrl: object.optionalString('imageUrl'),
    );
  }

  /// The framework's homepage.
  final String homepageUrl;

  /// An image for the framework, which may be a data URL.
  final String? imageUrl;

  /// Writes this record as decoded JSON, omitting an absent image.
  Map<String, Object?> toJson() => <String, Object?>{
    'homepageUrl': homepageUrl,
    'imageUrl': ?imageUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is BrandingInformation &&
      other.homepageUrl == homepageUrl &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(homepageUrl, imageUrl);

  @override
  String toString() => 'BrandingInformation(homepageUrl: $homepageUrl)';
}

/// The machine the mutation run happened on.
///
/// Only [ci] is required, and the schema is explicit that a producer decides
/// it on a best-effort basis rather than knowing it for certain.
final class SystemInformation {
  /// Creates the system record for a run that did or did not happen in CI.
  const SystemInformation({required this.ci, this.os, this.cpu, this.ram});

  /// The schema fields system information must carry.
  static const requiredJsonFields = <String>{'ci'};

  /// The schema fields system information may carry.
  static const optionalJsonFields = <String>{'os', 'cpu', 'ram'};

  /// Reads system information from decoded JSON.
  static SystemInformation fromJson(Object? json) {
    final object = JsonObject.read(json, 'SystemInformation');
    return SystemInformation(
      ci: object.requiredBoolean('ci'),
      os: object.optionalObject('os', OsInformation.fromJson),
      cpu: object.optionalObject('cpu', CpuInformation.fromJson),
      ram: object.optionalObject('ram', RamInformation.fromJson),
    );
  }

  /// Whether the run happened in a continuous-integration pipeline.
  final bool ci;

  /// The operating system the run happened on.
  final OsInformation? os;

  /// The processor the run happened on.
  final CpuInformation? cpu;

  /// The memory the machine had.
  final RamInformation? ram;

  /// Writes this record as decoded JSON, omitting every absent optional.
  Map<String, Object?> toJson() => <String, Object?>{
    'ci': ci,
    if (os case final os?) 'os': os.toJson(),
    if (cpu case final cpu?) 'cpu': cpu.toJson(),
    if (ram case final ram?) 'ram': ram.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is SystemInformation &&
      other.ci == ci &&
      other.os == os &&
      other.cpu == cpu &&
      other.ram == ram;

  @override
  int get hashCode => Object.hash(ci, os, cpu, ram);

  @override
  String toString() => 'SystemInformation(ci: $ci, os: $os)';
}

/// The operating system a mutation run happened on.
final class OsInformation {
  /// Creates the record for the platform called [platform].
  const OsInformation({required this.platform, this.description, this.version});

  /// The schema fields OS information must carry.
  static const requiredJsonFields = <String>{'platform'};

  /// The schema fields OS information may carry.
  static const optionalJsonFields = <String>{'description', 'version'};

  /// Reads OS information from decoded JSON.
  static OsInformation fromJson(Object? json) {
    final object = JsonObject.read(json, 'OSInformation');
    return OsInformation(
      platform: object.requiredString('platform'),
      description: object.optionalString('description'),
      version: object.optionalString('version'),
    );
  }

  /// The platform identifier, such as `linux` or `win32`.
  final String platform;

  /// A human-readable description of the operating system.
  final String? description;

  /// The operating system or distribution version.
  final String? version;

  /// Writes this record as decoded JSON, omitting every absent optional.
  Map<String, Object?> toJson() => <String, Object?>{
    'platform': platform,
    'description': ?description,
    'version': ?version,
  };

  @override
  bool operator ==(Object other) =>
      other is OsInformation &&
      other.platform == platform &&
      other.description == description &&
      other.version == version;

  @override
  int get hashCode => Object.hash(platform, description, version);

  @override
  String toString() => 'OsInformation(platform: $platform, version: $version)';
}

/// The processor a mutation run happened on.
final class CpuInformation {
  /// Creates the record for a processor with [logicalCores] cores.
  const CpuInformation({
    required this.logicalCores,
    this.baseClock,
    this.model,
  });

  /// The schema fields CPU information must carry.
  static const requiredJsonFields = <String>{'logicalCores'};

  /// The schema fields CPU information may carry.
  static const optionalJsonFields = <String>{'baseClock', 'model'};

  /// Reads CPU information from decoded JSON.
  static CpuInformation fromJson(Object? json) {
    final object = JsonObject.read(json, 'CpuInformation');
    return CpuInformation(
      logicalCores: object.requiredNumber('logicalCores'),
      baseClock: object.optionalNumber('baseClock'),
      model: object.optionalString('model'),
    );
  }

  /// How many logical cores the processor has.
  final num logicalCores;

  /// The processor's base clock speed, in MHz.
  final num? baseClock;

  /// The processor's model name.
  final String? model;

  /// Writes this record as decoded JSON, omitting every absent optional.
  Map<String, Object?> toJson() => <String, Object?>{
    'logicalCores': logicalCores,
    'baseClock': ?baseClock,
    'model': ?model,
  };

  @override
  bool operator ==(Object other) =>
      other is CpuInformation &&
      other.logicalCores == logicalCores &&
      other.baseClock == baseClock &&
      other.model == model;

  @override
  int get hashCode => Object.hash(logicalCores, baseClock, model);

  @override
  String toString() => 'CpuInformation(logicalCores: $logicalCores)';
}

/// The memory the machine a mutation run happened on had.
final class RamInformation {
  /// Creates the record for a machine with [total] megabytes of memory.
  const RamInformation({required this.total});

  /// The schema fields RAM information must carry.
  static const requiredJsonFields = <String>{'total'};

  /// The schema fields RAM information may carry.
  static const optionalJsonFields = <String>{};

  /// Reads RAM information from decoded JSON.
  static RamInformation fromJson(Object? json) {
    final object = JsonObject.read(json, 'RamInformation');
    return RamInformation(total: object.requiredNumber('total'));
  }

  /// The machine's total memory, in megabytes.
  final num total;

  /// Writes this record as decoded JSON.
  Map<String, Object?> toJson() => <String, Object?>{'total': total};

  @override
  bool operator ==(Object other) =>
      other is RamInformation && other.total == total;

  @override
  int get hashCode => total.hashCode;

  @override
  String toString() => 'RamInformation(total: $total)';
}
