import 'package:radioactive_dart/radioactive_dart.dart';

Future<void> main() async {
  final engine = Engine(
    projectRoot: '.',
    onProgress: (done, total, mutant, outcome) =>
        print('[$done/$total] ${mutant.id} -> ${outcome.name}'),
  );

  final result = await engine.run();

  await ConsoleReportSink().write(result.results);
  await StrykerJsonSink(
    projectRoot: '.',
    outputPath: 'mutation-report.json',
  ).write(result.results);
}
