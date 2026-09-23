/// The integration proof: butcher run against one of its own workspace
/// members, end to end, through the [Engine] rather than the CLI entry point.
///
/// The CLI hands back an exit code and nothing else — no typed result, no
/// event stream — and the assertions here are about the typed result, the
/// stream and the sandbox on disk, so the engine is the right level. The
/// CLI's own behaviour is covered by `test/cli`.
///
/// Wall time, measured on macOS (Dart 3.12, 10 cores) at the commit that
/// introduced this file: 18 s for the suite, of which the engine run is 13 s
/// over 9 mutants against a 2.9 s baseline. The run is bounded by a temporary
/// `butcher.yaml` written into the member, whose exclude list leaves exactly
/// one small source file in mutation scope; without it the member's whole
/// `lib/` is in scope and the run is an order of magnitude longer.
@Tags(['slow'])
@Timeout(Duration(minutes: 15))
library;

import 'dart:io';

import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/file_manifest.dart'
    show FileManifest, lockfileName;
import 'package:butcher/src/engine/sandbox.dart'
    show defaultSandboxExcludes, sandboxPrefix;
import 'package:butcher_process/butcher_process.dart';
import 'package:butcher_report/butcher_report.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The one source file of the member left in mutation scope, as a
/// project-relative posix path.
///
/// Small, pure and covered: its mutants are generated, compiled and
/// classified in seconds, which is what keeps the run inside a lane.
const _inScope = 'lib/src/thresholds.dart';

/// The workspace member driven, relative to the workspace root.
const _member = 'packages/butcher_report';

void main() {
  test('runs end to end against $_member', () async {
    final workspaceRoot = _workspaceRoot();
    final projectRoot = p.join(workspaceRoot, p.joinAll(_member.split('/')));
    final scratch = Directory.systemTemp.createTempSync('butcher_self_run_');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final paths = ButcherPaths(root: p.join(scratch.path, 'butcher'));
    final reportPath = p.join(scratch.path, 'mutation-report.json');

    _narrowScopeTo(projectRoot, _inScope);

    // The census counts the whole host, so it is only ever compared against
    // another reading taken the same way — see [hostProcessCount].
    final processesBefore = await hostProcessCount();

    // One worker: this suite proves the pipeline composes, not that it
    // scales, and every extra worker is another whole-workspace clone.
    final engine = Engine(projectRoot: projectRoot, paths: paths, jobs: 1);
    // Collected before `run`, so the opening event cannot be missed, and
    // awaited after it, since `run` closes the stream on its way out and
    // delivery is asynchronous.
    final published = engine.events.toList();

    final watch = Stopwatch()..start();
    final result = await engine.run();
    watch.stop();
    final events = await published;

    final processCeiling = processesBefore + _censusTolerance;
    final processesAfter = await _settledHostProcessCount(processCeiling);

    printOnFailure(
      'self run took ${watch.elapsed} over ${result.results.length} mutants',
    );

    // A red baseline aborts the run, so reaching here is the green reading;
    // the typed result carries what it measured and what it derived.
    expect(result.results, isNotEmpty);
    expect(result.baseline, greaterThan(Duration.zero));
    expect(result.deadline, Engine.deadlineFor(result.baseline));
    expect(result.deadline, greaterThan(Duration.zero));
    expect(result.sources.keys, [_inScope]);

    await StrykerJsonSink(
      sources: result.sources,
      outputPath: reportPath,
    ).write(result.results);

    // Parsed through the schema package's own entry point: it throws on any
    // schema violation, so a malformed document reds this test.
    final report = parseMutationTestReport(File(reportPath).readAsStringSync());
    final reported = report.files.values.fold(
      0,
      (total, file) => total + file.mutants.length,
    );
    expect(reported, result.results.length);

    final started = events.whereType<RunStarted>().toList();
    final classified = events.whereType<MutantClassified>().toList();
    final completed = events.whereType<RunCompleted>().toList();
    expect(started, hasLength(1));
    expect(completed, hasLength(1));
    expect(started.single.mutantCount, result.results.length);
    expect(started.single.baseline, result.baseline);
    expect(started.single.deadline, result.deadline);
    // Counts, not samples: one classification per mutant, and the same set of
    // classified results the report was written from. Event order is
    // non-deterministic, so the comparison is over sets.
    expect(classified, hasLength(result.results.length));
    expect({
      for (final event in classified) event.result,
    }, result.results.toSet());

    await _expectSandboxIsFiltered(paths.root, workspaceRoot);

    // A leaked suite descendant outlives the run and shows up here.
    expect(
      processesAfter,
      lessThanOrEqualTo(processCeiling),
      reason:
          'host process count went from $processesBefore to $processesAfter '
          'and stayed there; the run leaked descendants',
    );
  });
}

/// Host processes the census may drift by over a run without that meaning a
/// leak.
///
/// Measured on an idle macOS host: `ps -A` moved by at most one over six
/// consecutive readings a second apart.
const _censusTolerance = 2;

/// How long the census is given to come back down before a rise counts as a
/// leak.
///
/// The census counts the whole host, so a sibling suite spawning its own
/// processes raises it too: running this file inside the package's full
/// `dart test` put it 12 above its starting point while the kill-tree and CLI
/// suites were running. That rise is transient and a leak is not, which is
/// what this window separates. It only ever costs time when something else is
/// running: on a quiet host the first reading already settles.
const _censusSettleWindow = Duration(minutes: 2);

/// The host process count once it is at or below [ceiling], or its last
/// reading when it never gets there within [_censusSettleWindow].
Future<int> _settledHostProcessCount(int ceiling) async {
  final waited = Stopwatch()..start();
  var reading = await hostProcessCount();
  while (reading > ceiling && waited.elapsed < _censusSettleWindow) {
    await Future<void>.delayed(const Duration(seconds: 1));
    reading = await hostProcessCount();
  }
  return reading;
}

/// The workspace root, found by walking up from the directory the suite runs
/// in until the manifest declaring the `workspace` is found.
String _workspaceRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    final manifest = File(p.join(directory.path, 'pubspec.yaml'));
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains(
          RegExp(r'^workspace:', multiLine: true),
        )) {
      return directory.path;
    }
    final parent = directory.parent;
    if (p.equals(parent.path, directory.path)) {
      fail('no workspace manifest above ${Directory.current.path}');
    }
    directory = parent;
  }
}

/// Writes a temporary [butcherConfigFile] into [projectRoot] excluding every
/// source of that member except [keep], and removes it again afterwards.
///
/// The configuration surface is exclude-only, so narrowing is expressed as
/// what it removes. The list is computed from the member's own `lib/` rather
/// than written out by hand, so a source added to the member is excluded by
/// this suite instead of silently widening its run.
///
/// The file lands in [projectRoot] because that is where the engine reads it
/// from; the scratch directory holds the run's own outputs.
void _narrowScopeTo(String projectRoot, String keep) {
  final config = File(p.join(projectRoot, butcherConfigFile));
  expect(
    config.existsSync(),
    isFalse,
    reason:
        '${config.path} already exists; this suite would overwrite a real '
        'configuration file',
  );

  final sources =
      Directory(p.join(projectRoot, 'lib'))
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((file) => p.relative(file.path, from: projectRoot))
          .map((relative) => relative.replaceAll(r'\', '/'))
          .where((relative) => relative.endsWith('.dart'))
          .where((relative) => relative != keep)
          .toList()
        ..sort();
  expect(sources, isNotEmpty);

  config.writeAsStringSync(
    [
      '# Written by test/e2e/self_run_test.dart; deleted when it finishes.',
      'exclude:',
      for (final source in sources) "  - '$source'",
      '',
    ].join('\n'),
  );
  addTearDown(() {
    if (config.existsSync()) config.deleteSync();
  });
}

/// Asserts the sandboxes under [butcherRoot] hold the repository's own
/// listing rather than an unfiltered copy of [workspaceRoot].
///
/// The saving is stated twice, at two strengths, because the loose ratio
/// alone is not stable across checkouts. A sandbox holds the workspace's
/// tracked listing and the artefacts the run resolved into it, and nothing
/// else: no git storage, no build or coverage output, no ignored file. That
/// exact statement is the one an unfiltered copy always violates, whatever
/// the checkout looks like.
///
/// Measured on this workspace: a sandbox holds 228 of the 1339 files on disk,
/// a ratio of 0.17, the difference being the 1111-file git object store the
/// listing keeps out. That ratio is a property of the checkout rather than of
/// the engine — a shallow CI checkout keeps only about thirty files in its
/// object store, so the same correct copy measures near 0.9 there — which is
/// why the fraction is asserted loosely and the copy set exactly.
Future<void> _expectSandboxIsFiltered(
  String butcherRoot,
  String workspaceRoot,
) async {
  final sandboxes = Directory(butcherRoot)
      .listSync()
      .whereType<Directory>()
      .where((entry) => p.basename(entry.path).startsWith(sandboxPrefix))
      .toList();
  expect(sandboxes, isNotEmpty, reason: 'the run created no sandbox');

  final workspaceFiles =
      _fileCount(workspaceRoot) + _gitStoreFileCount(workspaceRoot);
  expect(workspaceFiles, greaterThan(0));
  final listed = (await FileManifest.of(workspaceRoot)).paths;

  for (final sandbox in sandboxes) {
    final copied = sandbox
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((file) => p.relative(file.path, from: sandbox.path))
        .map((relative) => relative.replaceAll(r'\', '/'))
        .toList();
    expect(copied, isNotEmpty);

    // Every copied path is one the repository names, or an artefact the run
    // resolved inside the sandbox and cloned rather than resolved again.
    final unexplained = copied
        .where((relative) => !listed.contains(relative))
        .where((relative) => !_isResolvedArtefact(relative))
        .toList();
    expect(
      unexplained,
      isEmpty,
      reason:
          '${sandbox.path} copied files the repository does not list, so the '
          'copy is no longer manifest-driven',
    );

    // And nothing from a directory the copy prunes, which is what a full-tree
    // copy would drag in first.
    for (final excluded in const [
      // `.dart_tool` is left out on purpose: it is pruned from the source and
      // then written by the sandbox's own resolution, so it is present here
      // by design and [_isResolvedArtefact] is what accounts for it.
      '.git',
      ...defaultSandboxExcludes,
    ]) {
      expect(
        copied.where((relative) => p.posix.split(relative).contains(excluded)),
        isEmpty,
        reason: '${sandbox.path} copied $excluded, so the copy is unfiltered',
      );
    }

    expect(
      copied.length,
      lessThan(workspaceFiles),
      reason:
          '${sandbox.path} holds ${copied.length} of $workspaceFiles files on '
          'disk; the manifest-driven copy is no longer saving anything',
    );
  }
}

/// Whether the sandbox-relative posix path [relative] is something the run
/// resolved into the sandbox rather than copied out of the workspace.
bool _isResolvedArtefact(String relative) {
  final segments = p.posix.split(relative);
  return segments.contains('.dart_tool') || segments.last == lockfileName;
}

/// Files on disk under [root], symlinks never followed.
int _fileCount(String root) => Directory(
  root,
).listSync(recursive: true, followLinks: false).whereType<File>().length;

/// Files in the git object store backing [root], when it lives outside the
/// tree.
///
/// A clone keeps it in `.git` inside the tree, where [_fileCount] has already
/// counted it. A linked worktree keeps it beside the tree, and leaving it out
/// there would compare the copy against a source that is already filtered.
int _gitStoreFileCount(String root) {
  final common = Process.runSync('git', [
    '-C',
    root,
    'rev-parse',
    '--path-format=absolute',
    '--git-common-dir',
  ]);
  if (common.exitCode != 0) return 0;
  final directory = '${common.stdout}'.trim();
  if (directory.isEmpty || p.isWithin(root, directory)) return 0;
  return Directory(directory).existsSync() ? _fileCount(directory) : 0;
}
