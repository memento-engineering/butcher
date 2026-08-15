import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../engine/engine.dart';
import '../engine/run_aborted.dart';
import '../report/console_report_sink.dart';
import '../report/metrics.dart';
import '../report/stryker_json_sink.dart';

/// Default path of the Stryker JSON report, relative to the project root.
const defaultReportPath = 'mutation-report.json';

/// Runs the `rad` CLI over [arguments]; returns the process exit code.
///
/// Exit codes: 0 success, 1 MSI below `--threshold`, 64 usage error,
/// 70 aborted run (red background reading, failed pub get).
Future<int> radMain(List<String> arguments, {StringSink? out}) async {
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

  final engine = Engine(
    projectRoot: projectRoot,
    onProgress: (done, total, mutant, outcome) =>
        sink.writeln('[$done/$total] ${mutant.id} -> ${outcome.name}'),
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

    final msi = Metrics.fromResults(result.results).msi;
    if (threshold != null && msi < threshold) {
      stderr.writeln(
        'MSI ${msi.toStringAsFixed(2)}% is below the '
        '${threshold.toStringAsFixed(2)}% threshold',
      );
      return 1;
    }
    return 0;
  } on RunAborted catch (abort) {
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
