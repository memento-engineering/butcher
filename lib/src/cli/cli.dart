import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import '../engine/run_aborted.dart';
import '../log/rad_logger.dart';
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
/// [logPath] overrides the log file location, [RadLogger.defaultPath].
Future<int> radMain(
  List<String> arguments, {
  StringSink? out,
  String? logPath,
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
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Also stream structured log events to the console.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');

  final ArgResults options;
  final double? threshold;
  try {
    options = parser.parse(arguments);
    if (options.rest.length > 1) {
      throw FormatException(
        'expected at most one project root, got: ${options.rest.join(' ')}',
      );
    }
    threshold = _threshold(options);
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
  final watch = Stopwatch()..start();
  final logger = RadLogger(
    verbose: options.flag('verbose'),
    path: logPath,
    console: sink,
  );
  logger.info('run_start', {
    'tool_version': packageVersion,
    'dart': Platform.version,
    'os': Platform.operatingSystem,
    'project_root': projectRoot,
    'argv': arguments,
  });

  final engine = Engine(
    projectRoot: projectRoot,
    onProgress: (done, total, result) {
      final mutation = result.mutant.mutation;
      sink.writeln(
        '[$done/$total] ${result.mutant.id} -> ${result.outcome.name}',
      );
      logger.info('mutant', {
        'id': result.mutant.id,
        'file': mutation.filePath,
        'offset': mutation.offset,
        'operator': mutation.operatorId,
        'replacement': mutation.replacement,
        'outcome': result.outcome.name,
        'exit_code': result.testRun?.exitCode,
        'timed_out': result.testRun?.timedOut,
        'duration_ms': result.testRun?.duration.inMilliseconds,
        'done': done,
        'total': total,
      });
    },
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
    final gated = threshold != null && metrics.msi < threshold;
    logger.info('run_complete', {
      'mutants': result.results.length,
      'counts': metrics.counts.map((k, v) => MapEntry(k.name, v)),
      'msi': metrics.msi,
      'covered_msi': metrics.coveredMsi,
      'background_ms': result.backgroundReading.inMilliseconds,
      'half_life_ms': result.halfLife.inMilliseconds,
      'duration_ms': watch.elapsedMilliseconds,
      'report': reportPath,
      'exit_code': gated ? 1 : 0,
    });
    if (gated) {
      stderr.writeln(
        'MSI ${metrics.msi.toStringAsFixed(2)}% is below the '
        '${threshold.toStringAsFixed(2)}% threshold',
      );
      return 1;
    }
    return 0;
  } on RunAborted catch (abort) {
    logger.error('run_aborted', {
      'message': abort.message,
      'duration_ms': watch.elapsedMilliseconds,
    });
    stderr.writeln(abort.message);
    return 70;
  }
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
