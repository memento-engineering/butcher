import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import '../engine/run_aborted.dart';
import '../log/rad_logger.dart';
import '../rad_paths.dart';
import '../report/console_report_sink.dart';
import '../report/metrics.dart';
import '../report/stryker_json_sink.dart';
import '../version.dart';

/// Default path of the Stryker JSON report, relative to the project root.
const defaultReportPath = 'mutation-report.json';

/// Runs the `rad` CLI over [arguments]; returns the process exit code.
///
/// Exit codes: 0 success, 1 MSI below `--threshold`, 64 usage error,
/// 70 aborted run (red background reading, failed pub get).
///
/// [paths] overrides every filesystem location used by the invocation.
Future<int> radMain(
  List<String> arguments, {
  StringSink? out,
  RadPaths? paths,
}) async {
  final sink = out ?? stdout;
  final parser = ArgParser()
    ..addOption(
      'threshold',
      abbr: 't',
      help: 'Criticality gate: exit 1 when the MSI is below this percentage.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: defaultReportPath,
      help: 'Path of the Stryker JSON report.',
    )
    ..addOption(
      'max-timeouts',
      help:
          'Honesty gate: exit 1 when more mutants than this time out. '
          'Timeouts are inconclusive and score as neither killed nor survived.',
    )
    ..addOption(
      'jobs',
      abbr: 'j',
      help:
          'Parallel workers, each with its own containment copy. '
          'Defaults to half the CPU cores.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Also stream structured log events to the console.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');

  final ArgResults options;
  final double? threshold;
  final int? jobs;
  final int? maxTimeouts;
  try {
    options = parser.parse(arguments);
    if (options.rest.length > 1) {
      throw FormatException(
        'expected at most one project root, got: ${options.rest.join(' ')}',
      );
    }
    threshold = _threshold(options);
    jobs = _jobs(options);
    maxTimeouts = _maxTimeouts(options);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage(parser));
    return 64;
  }
  if (options.flag('help')) {
    sink.writeln(_usage(parser));
    return 0;
  }

  final projectRoot = p.normalize(
    p.absolute(options.rest.isEmpty ? '.' : options.rest.single),
  );
  final resolvedPaths = paths ?? RadPaths.systemTemp();
  final runsDir = Directory(resolvedPaths.runLogs)..createSync(recursive: true);
  for (final entry in runsDir.listSync()) {
    entry.deleteSync(recursive: true);
  }
  final verbose = options.flag('verbose');
  final watch = Stopwatch()..start();
  final logger = RadLogger(
    verbose: verbose,
    path: resolvedPaths.toolLog,
    console: sink,
  );
  logger.info('starting rad {ToolVersion} on {ProjectRoot} with {Jobs} jobs', {
    'ToolVersion': packageVersion,
    'ProjectRoot': projectRoot,
    'Jobs': jobs ?? Engine.defaultJobs,
    'Dart': Platform.version,
    'Os': Platform.operatingSystem,
    'Argv': arguments,
  });

  final engine = Engine(
    projectRoot: projectRoot,
    paths: resolvedPaths,
    jobs: jobs,
    logger: logger,
    onProgress: verbose
        // The rendered `classified` event already covers verbose progress.
        ? null
        : (done, total, result) => sink.writeln(
            '[$done/$total] ${result.mutant.id} -> ${result.outcome.name}',
          ),
  );

  try {
    sink.writeln('irradiating $projectRoot');
    final result = await engine.run();
    sink.writeln(
      'background reading: ${result.backgroundReading.inSeconds}s, '
      'half-life: ${result.halfLife.inSeconds}s',
    );

    await ConsoleReportSink(out: sink).write(result.results);
    final reportPath = p.join(projectRoot, options.option('output')!);
    await StrykerJsonSink(
      sources: result.sources,
      outputPath: reportPath,
    ).write(result.results);
    sink.writeln('report: $reportPath');

    final metrics = Metrics.fromResults(result.results);
    final belowThreshold = threshold != null && metrics.msi < threshold;
    final tooManyTimeouts =
        maxTimeouts != null && metrics.timedOut > maxTimeouts;
    final gated = belowThreshold || tooManyTimeouts;
    logger.info(
      'run complete: MSI {Msi}% over {MutantCount} mutants, exit {ExitCode}',
      {
        'Msi': double.parse(metrics.msi.toStringAsFixed(2)),
        'MutantCount': result.results.length,
        'ExitCode': gated ? 1 : 0,
        'Counts': metrics.counts.map((k, v) => MapEntry(k.name, v)),
        'CoveredMsi': double.parse(metrics.coveredMsi.toStringAsFixed(2)),
        'BackgroundMs': result.backgroundReading.inMilliseconds,
        'HalfLifeMs': result.halfLife.inMilliseconds,
        'DurationMs': watch.elapsedMilliseconds,
        'Report': reportPath,
      },
    );
    if (belowThreshold) {
      stderr.writeln(
        'MSI ${metrics.msi.toStringAsFixed(2)}% is below the '
        '${threshold.toStringAsFixed(2)}% threshold',
      );
    }
    if (tooManyTimeouts) {
      stderr.writeln(
        '${metrics.timedOut} mutants timed out, above the '
        '--max-timeouts ceiling of $maxTimeouts',
      );
    }
    return gated ? 1 : 0;
  } on RunAborted catch (abort) {
    logger.error('run aborted: {Reason}', {
      'Reason': abort.message,
      'DurationMs': watch.elapsedMilliseconds,
    });
    stderr.writeln(abort.message);
    return 70;
  }
}

int? _jobs(ArgResults options) {
  final raw = options.option('jobs');
  if (raw == null) return null;
  final value = int.tryParse(raw);
  if (value == null || value < 1) {
    throw FormatException('--jobs must be a positive integer: $raw');
  }
  return value;
}

int? _maxTimeouts(ArgResults options) {
  final raw = options.option('max-timeouts');
  if (raw == null) return null;
  final value = int.tryParse(raw);
  if (value == null || value < 0) {
    throw FormatException('--max-timeouts must be a non-negative integer: $raw');
  }
  return value;
}

double? _threshold(ArgResults options) {
  final raw = options.option('threshold');
  if (raw == null) return null;
  final value = double.tryParse(raw);
  if (value == null || value < 0 || value > 100) {
    throw FormatException('--threshold must be a number from 0 to 100: $raw');
  }
  return value;
}

String _usage(ArgParser parser) =>
    'Usage: rad [options] [project root]\n\n${parser.usage}';
