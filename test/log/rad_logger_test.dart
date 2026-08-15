import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:test/test.dart';

void main() {
  late String path;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('rad_log_');
    addTearDown(() => dir.delete(recursive: true));
    path = p.join(dir.path, 'rad.log');
  });

  List<Map<String, dynamic>> events() =>
      File(path)
          .readAsLinesSync()
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();

  RadLogger logger({bool verbose = false, StringSink? console, bool? colors}) =>
      RadLogger(
        verbose: verbose,
        path: path,
        console: console ?? StringBuffer(),
        colors: colors,
      );

  test('writes CLEF lines: @t, @mt, properties, and @l only on errors', () {
    final log = logger()
      ..info('starting rad {ToolVersion}', {'ToolVersion': '0.1.0-dev'})
      ..error('run aborted: {Reason}', {'Reason': 'red baseline'});

    final lines = events();
    expect(lines, hasLength(2));
    expect(lines.first['@mt'], 'starting rad {ToolVersion}');
    expect(lines.first['ToolVersion'], '0.1.0-dev');
    expect(lines.first.containsKey('@l'), isFalse, reason: 'info is default');
    expect(lines.first['RunId'], log.runId);
    expect(DateTime.parse(lines.first['@t'] as String), isNotNull);
    expect(lines.last['@l'], 'Error');
    expect(lines.last['Reason'], 'red baseline');
    expect(lines.last['RunId'], lines.first['RunId']);
  });

  test('replaces the log file of a previous run', () {
    logger().info('run {N}', {'N': 1});
    logger().info('run {N}', {'N': 2});

    final lines = events();
    expect(lines, hasLength(1));
    expect(lines.single['N'], 2);
  });

  test('uses paths resolved by the caller', () {
    final paths = RadPaths(root: p.dirname(path));
    expect(paths.toolLog, path);
    expect(paths.runLogs, p.join(p.dirname(path), 'runs'));
  });

  test('renders humans-first console lines only when verbose', () {
    final quiet = StringBuffer();
    logger(console: quiet).info('classified {MutantId}', {'MutantId': 'x'});
    expect(quiet.toString(), isEmpty);

    final loud = StringBuffer();
    logger(verbose: true, console: loud)
      ..info('classified {MutantId} as {Outcome}', {
        'MutantId': 'lib/a.dart:27:arithmetic:-',
        'Outcome': 'killed',
      })
      ..error('run aborted: {Reason}', {'Reason': 'red'});

    final rendered = loud.toString();
    expect(rendered, isNot(contains('@mt')), reason: 'no raw JSON');
    expect(
      rendered,
      contains('INF classified lib/a.dart:27:arithmetic:- as killed'),
    );
    expect(rendered, contains('ERR run aborted: red'));
    expect(rendered, matches(RegExp(r'\d{2}:\d{2}:\d{2} ')));
    expect(rendered, isNot(contains('\x1B')), reason: 'no colors off-terminal');
  });

  test('colors the level and interpolated properties when enabled', () {
    final loud = StringBuffer();
    logger(
      verbose: true,
      console: loud,
      colors: true,
    ).info('classified {MutantId}', {'MutantId': 'x'});

    final rendered = loud.toString();
    expect(rendered, contains('\x1B[32mINF\x1B[0m'));
    expect(rendered, contains('\x1B[36mx\x1B[0m'));
  });

  test('adopts a caller-provided run id for correlation', () {
    logger(); // Claims `path`; the correlated logger writes elsewhere.
    final correlated = RadLogger(
      verbose: false,
      path: '$path.child',
      console: StringBuffer(),
      runId: 'parent-run',
    )..info('child event');
    expect(correlated.runId, 'parent-run');
    final line = jsonDecode(
      File('$path.child').readAsLinesSync().single,
    ) as Map<String, dynamic>;
    expect(line['RunId'], 'parent-run');
  });

  test('leaves unknown template holes untouched', () {
    final loud = StringBuffer();
    logger(verbose: true, console: loud).info('missing {Nope}');
    expect(loud.toString(), contains('missing {Nope}'));
  });
}
