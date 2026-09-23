import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

const _performance = PerformanceStatistics(
  setup: 120,
  initialRun: 3400.5,
  mutation: 91000,
);

const _framework = FrameworkInformation(
  name: 'butcher',
  version: '0.1.0',
  branding: BrandingInformation(
    homepageUrl: 'https://github.com/memento-engineering/butcher',
    imageUrl: 'https://example.invalid/butcher.png',
  ),
  dependencies: <String, String>{'analyzer': '8.4.0'},
);

const _system = SystemInformation(
  ci: true,
  os: OsInformation(
    platform: 'macos',
    description: 'macOS 15',
    version: '15.6.0',
  ),
  cpu: CpuInformation(logicalCores: 10, baseClock: 3200, model: 'Apple M1 Pro'),
  ram: RamInformation(total: 32768),
);

/// Each type under test, paired with a fully populated instance's JSON.
final _types =
    <String, (Set<String>, Map<String, Object?>, Object? Function(Object?))>{
      'PerformanceStatistics': (
        PerformanceStatistics.requiredJsonFields,
        _performance.toJson(),
        PerformanceStatistics.fromJson,
      ),
      'FrameworkInformation': (
        FrameworkInformation.requiredJsonFields,
        _framework.toJson(),
        FrameworkInformation.fromJson,
      ),
      'BrandingInformation': (
        BrandingInformation.requiredJsonFields,
        _framework.branding!.toJson(),
        BrandingInformation.fromJson,
      ),
      'SystemInformation': (
        SystemInformation.requiredJsonFields,
        _system.toJson(),
        SystemInformation.fromJson,
      ),
      'OSInformation': (
        OsInformation.requiredJsonFields,
        _system.os!.toJson(),
        OsInformation.fromJson,
      ),
      'CpuInformation': (
        CpuInformation.requiredJsonFields,
        _system.cpu!.toJson(),
        CpuInformation.fromJson,
      ),
      'RamInformation': (
        RamInformation.requiredJsonFields,
        _system.ram!.toJson(),
        RamInformation.fromJson,
      ),
    };

void main() {
  group('run metadata', () {
    _types.forEach((owner, entry) {
      final (required, json, parse) = entry;
      test('$owner names each missing required field', () {
        for (final field in required) {
          final missing = Map<String, Object?>.of(json)..remove(field);
          expect(
            () => parse(missing),
            throwsA(
              isA<FormatException>().having(
                (error) => error.message,
                'message',
                allOf(contains(owner), contains(field)),
              ),
            ),
            reason: 'removing $field from $owner must be reported by name',
          );
        }
      });
    });

    test('performance statistics round-trip', () {
      expect(
        PerformanceStatistics.fromJson(_performance.toJson()),
        _performance,
      );
      expect(
        _performance,
        isNot(
          const PerformanceStatistics(
            setup: 120,
            initialRun: 3400.5,
            mutation: 90000,
          ),
        ),
      );
    });

    test('framework information round-trips with its nested records', () {
      expect(FrameworkInformation.fromJson(_framework.toJson()), _framework);
      expect(
        FrameworkInformation.fromJson(_framework.toJson()).dependencies,
        <String, String>{'analyzer': '8.4.0'},
      );
    });

    test('framework information omits every absent optional', () {
      const bare = FrameworkInformation(name: 'butcher');
      expect(bare.toJson().keys, <String>['name']);
      expect(FrameworkInformation.fromJson(bare.toJson()), bare);
    });

    test('system information round-trips with its nested records', () {
      expect(SystemInformation.fromJson(_system.toJson()), _system);
    });

    test('system information omits every absent optional', () {
      const bare = SystemInformation(ci: false);
      expect(bare.toJson().keys, <String>['ci']);
      expect(SystemInformation.fromJson(bare.toJson()), bare);
    });

    test('a non-boolean ci flag is rejected', () {
      expect(
        () => SystemInformation.fromJson(<String, Object?>{'ci': 'yes'}),
        throwsFormatException,
      );
    });

    test('a dependencies map of non-strings is rejected', () {
      expect(
        () => FrameworkInformation.fromJson(<String, Object?>{
          'name': 'butcher',
          'dependencies': <String, Object?>{'analyzer': 8},
        }),
        throwsFormatException,
      );
    });
  });
}
