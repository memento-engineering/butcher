/// Asserts the shape of the GitHub workflow files against parsed YAML.
///
/// A shell grep can tell you a string is present; it cannot tell you that the
/// string sits at the key that GitHub actually reads. These checks parse the
/// workflows and walk them, so a CI leg cannot be lost to a typo in a key, and
/// the release workflow cannot be left calling a file that no longer exists.
///
/// Run from the repository root:
///
/// ```
/// dart run tool/check_workflows.dart
/// ```
///
/// Exits 0 when every check passes, or 1 with a report naming the first
/// violated check.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

const _workflowsDir = '.github/workflows';
const _ciPath = '$_workflowsDir/ci.yaml';
const _retiredCiPath = '$_workflowsDir/ci.yml';
const _publishPath = '$_workflowsDir/publish.yml';

/// The job running the slow-tagged selection on every platform.
const _slowJobName = 'slow';

/// The one job branch protection requires, whatever the matrix does.
const _requiredJobName = 'ci-required';

/// The platforms the engine branches on, as runner-label prefixes.
const _platforms = ['ubuntu', 'macos', 'windows'];

/// Raised by a check that its subject violates, carrying the operator-readable
/// reason.
class CheckFailure implements Exception {
  /// Creates a failure reported under [check] for [reason].
  CheckFailure(this.check, this.reason);

  /// The name of the check that failed.
  final String check;

  /// Why it failed, in terms an operator can act on.
  final String reason;

  @override
  String toString() => '$check: $reason';
}

/// One named assertion over the workflow tree.
typedef Check = ({String name, void Function() run});

void main() {
  final checks = <Check>[
    (name: 'the CI workflow uses the yaml spelling', run: _checkCiFileName),
    (
      name: 'the release workflow calls CI by that name',
      run: _checkPublishCall,
    ),
    (name: 'the CI matrix covers all three platforms', run: _checkMatrix),
    (
      name: 'the slow suites run on all three platforms and gate the build',
      run: _checkSlowJob,
    ),
    (name: 'branch protection has one stable check name', run: _checkRequired),
  ];

  for (final check in checks) {
    try {
      check.run();
    } on CheckFailure catch (failure) {
      stderr.writeln('check_workflows: FAILED');
      stderr.writeln('  ${failure.check}');
      stderr.writeln('  ${failure.reason}');
      exitCode = 1;
      return;
    }
    stdout.writeln('check_workflows: ok - ${check.name}');
  }

  stdout.writeln('check_workflows: ${checks.length} checks passed');
}

YamlMap _load(String path, String check) {
  final file = File(path);
  if (!file.existsSync()) {
    throw CheckFailure(check, 'no such workflow file: $path');
  }

  final document = loadYaml(file.readAsStringSync(), sourceUrl: file.uri);
  if (document is! YamlMap) {
    throw CheckFailure(check, '$path does not parse as a YAML mapping');
  }

  return document;
}

void _checkCiFileName() {
  const check = 'the CI workflow uses the yaml spelling';

  _load(_ciPath, check);

  if (File(_retiredCiPath).existsSync()) {
    throw CheckFailure(
      check,
      '$_retiredCiPath still exists; the workflow was renamed to $_ciPath and '
      'the two spellings must not both be present',
    );
  }
}

void _checkPublishCall() {
  const check = 'the release workflow calls CI by that name';

  final publish = _load(_publishPath, check);
  final jobs = publish['jobs'];
  if (jobs is! YamlMap) {
    throw CheckFailure(check, '$_publishPath declares no jobs mapping');
  }

  final callers = <String>[];
  for (final entry in jobs.entries) {
    final job = entry.value;
    if (job is! YamlMap) continue;

    final uses = job['uses'];
    if (uses is! String) continue;
    if (!uses.startsWith('./$_workflowsDir/')) continue;

    callers.add(uses);
  }

  if (callers.isEmpty) {
    throw CheckFailure(
      check,
      '$_publishPath calls no local workflow; it must call ./$_ciPath so the '
      'release runs the same gate as every other ref',
    );
  }

  final wrong = callers.where((uses) => uses != './$_ciPath').toList();
  if (wrong.isNotEmpty) {
    throw CheckFailure(
      check,
      '$_publishPath calls ${wrong.join(', ')}; it must call ./$_ciPath, which '
      'is the only local workflow that exists',
    );
  }
}

/// The job that runs the platform matrix, and the name it is declared under.
({String name, YamlMap job}) _matrixJob(String check) {
  final ci = _load(_ciPath, check);
  final jobs = ci['jobs'];
  if (jobs is! YamlMap) {
    throw CheckFailure(check, '$_ciPath declares no jobs mapping');
  }

  for (final entry in jobs.entries) {
    final job = entry.value;
    if (job is! YamlMap) continue;

    final matrix = (job['strategy'] as YamlMap?)?['matrix'];
    if (matrix is! YamlMap) continue;
    if (matrix['os'] == null) continue;

    return (name: '${entry.key}', job: job);
  }

  throw CheckFailure(check, '$_ciPath declares no job with an os matrix');
}

void _checkMatrix() {
  const check = 'the CI matrix covers all three platforms';

  final matrix = _matrixJob(check);
  _checkPlatforms(_operatingSystems(matrix.job, matrix.name, check), check);
}

/// The `os` list of [job]'s matrix, declared in the workflow under [jobName].
List<String> _operatingSystems(YamlMap job, String jobName, String check) {
  final strategy = job['strategy'];
  final matrix = strategy is YamlMap ? strategy['matrix'] : null;
  final operatingSystems = matrix is YamlMap ? matrix['os'] : null;
  if (operatingSystems is! YamlList) {
    throw CheckFailure(
      check,
      'the $jobName job declares no os matrix list, so it runs on one '
      'platform whatever the list beside it says',
    );
  }

  return operatingSystems.map((runner) => '$runner').toList();
}

/// Fails unless [runners] carries a runner for every platform in [_platforms].
void _checkPlatforms(List<String> runners, String check) {
  for (final platform in _platforms) {
    final covered = runners.any((runner) => runner.startsWith(platform));
    if (!covered) {
      throw CheckFailure(
        check,
        'no $platform runner in ${runners.join(', ')}; the engine branches on '
        'the platform, so every one it supports has to run',
      );
    }
  }
}

/// The job names [job] declares it waits for.
List<String> _needsOf(YamlMap job) {
  final needs = job['needs'];
  return switch (needs) {
    String() => [needs],
    YamlList() => needs.map((need) => '$need').toList(),
    _ => const <String>[],
  };
}

void _checkSlowJob() {
  const check = 'the slow suites run on all three platforms and gate the build';

  final ci = _load(_ciPath, check);
  final jobs = ci['jobs'];
  if (jobs is! YamlMap) {
    throw CheckFailure(check, '$_ciPath declares no jobs mapping');
  }

  final slow = jobs[_slowJobName];
  if (slow is! YamlMap) {
    throw CheckFailure(
      check,
      '$_ciPath declares no $_slowJobName job; the slow-tagged suites are '
      'excluded from the matrix job, so without it they run nowhere',
    );
  }

  _checkPlatforms(_operatingSystems(slow, _slowJobName, check), check);

  final required = jobs[_requiredJobName];
  if (required is! YamlMap) {
    throw CheckFailure(check, '$_ciPath declares no $_requiredJobName job');
  }

  if (!_needsOf(required).contains(_slowJobName)) {
    throw CheckFailure(
      check,
      '$_requiredJobName does not need the $_slowJobName job, so it would '
      'report success without the slow suites having run',
    );
  }
}

void _checkRequired() {
  const check = 'branch protection has one stable check name';

  final matrixName = _matrixJob(check).name;
  final ci = _load(_ciPath, check);
  final jobs = ci['jobs'] as YamlMap;

  final required = jobs[_requiredJobName];
  if (required is! YamlMap) {
    throw CheckFailure(
      check,
      '$_ciPath declares no $_requiredJobName job; branch protection needs one '
      'check name that survives a change to the matrix',
    );
  }

  if (!_needsOf(required).contains(matrixName)) {
    throw CheckFailure(
      check,
      '$_requiredJobName does not need the $matrixName job, so it would report '
      'success without the matrix having run',
    );
  }
}
