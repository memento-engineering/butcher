import 'package:radioactive_dart/radioactive_dart.dart';

Future<void> main() async {
  final engine = Engine(
    projectRoot: '.',
    paths: RadPaths.systemTemp(),
    onProgress: (done, total, result) =>
        print('[$done/$total] ${result.mutant.id} -> ${result.outcome.name}'),
  );

  final result = await engine.run();

  await ConsoleReportSink().write(result.results);
  await StrykerJsonSink(
    sources: result.sources,
    outputPath: 'mutation-report.json',
  ).write(result.results);
}
