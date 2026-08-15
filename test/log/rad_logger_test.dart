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

  test('writes JSON lines with level, type, run id, and timestamp', () {
    final logger =
        RadLogger(verbose: false, path: path, console: StringBuffer())
          ..info('run_start', {'os': 'windows'})
          ..error('run_aborted', {'message': 'red baseline'});

    final lines = events();
    expect(lines, hasLength(2));
    expect(lines.first['level'], 'info');
    expect(lines.first['type'], 'run_start');
    expect(lines.first['os'], 'windows');
    expect(lines.first['run_id'], logger.runId);
    expect(DateTime.parse(lines.first['timestamp'] as String), isNotNull);
    expect(lines.last['level'], 'error');
    expect(lines.last['message'], 'red baseline');
    expect(lines.last['run_id'], lines.first['run_id']);
  });

  test('replaces the log file of a previous run', () {
    RadLogger(
      verbose: false,
      path: path,
      console: StringBuffer(),
    ).info('run_start', {'run': 1});
    RadLogger(
      verbose: false,
      path: path,
      console: StringBuffer(),
    ).info('run_start', {'run': 2});

    final lines = events();
    expect(lines, hasLength(1));
    expect(lines.single['run'], 2);
  });

  test('defaults to the log file inside the single rad temp folder', () {
    expect(RadLogger.defaultPath, p.join(radTempPath(), 'rad.log'));
  });

  test('streams events to the console only when verbose', () {
    final quiet = StringBuffer();
    RadLogger(
      verbose: false,
      path: path,
      console: quiet,
    ).info('mutant', {'id': 'x'});
    expect(quiet.toString(), isEmpty);

    final loud = StringBuffer();
    RadLogger(
      verbose: true,
      path: path,
      console: loud,
    ).info('mutant', {'id': 'x'});
    expect(loud.toString(), contains('"type":"mutant"'));
    expect(loud.toString(), contains('"id":"x"'));
  });
}
