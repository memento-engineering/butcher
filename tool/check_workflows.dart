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
const _dependabotPath = '.github/dependabot.yml';
const _codeownersPath = '.github/CODEOWNERS';
const _parseScriptPath = '.github/parse_release_tag.sh';
const _rootPubspecPath = 'pubspec.yaml';

/// The job running the slow-tagged selection on every platform.
const _slowJobName = 'slow';

/// The one job branch protection requires, whatever the matrix does.
const _requiredJobName = 'ci-required';

/// The release job that turns the tag into a member directory.
const _parseJobName = 'parse';

/// The release job that gates the publish on a dry run and a pana score.
const _verifyJobName = 'verify';

/// The release job that hands the member to pub.dev.
const _publishJobName = 'publish';

/// The release job that opens the GitHub release.
const _releaseJobName = 'release';

/// The reusable workflow the Dart team publishes with, minus its ref.
const _reusablePublishWorkflow =
    'dart-lang/setup-dart/.github/workflows/publish.yml@';

/// The platforms the engine branches on, as runner-label prefixes.
const _platforms = ['ubuntu', 'macos', 'windows'];

/// Platforms kept off the slow job by policy rather than by accident.
///
/// While the repository is private, macOS runners bill at ten times Linux,
/// and the slow suites are the long ones, so they run on the maintainer's
/// Mac and stay out of the slow job by design (ruling 2026-09-23). At
/// go-public this list becomes empty and the leg returns.
const _slowSuitesRunLocally = ['macos'];

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
      name: 'the slow suites run on every CI platform and gate the build',
      run: _checkSlowJob,
    ),
    (name: 'branch protection has one stable check name', run: _checkRequired),
    (
      name: 'the release workflow triggers only on per-package tags',
      run: _checkReleaseTriggers,
    ),
    (
      name: 'the release workflow parses the tag with the shared script',
      run: _checkParseJob,
    ),
    (
      name: 'the release is verified from the parsed member directory',
      run: _checkVerifyJob,
    ),
    (
      name: 'the pana threshold is the largest recorded deduction',
      run: _checkPanaThreshold,
    ),
    (
      name: 'the publish job authenticates with an identity token',
      run: _checkPublishJob,
    ),
    (name: 'the release job names the parsed version', run: _checkReleaseJob),
    (
      name: 'the release workflow records the tag-push limit',
      run: _checkTagPushLimit,
    ),
    (
      name: 'the ownership file names an owner of this org',
      run: _checkCodeowners,
    ),
    (
      name:
          'dependabot updates pub at the workspace root and the actions '
          'ecosystem',
      run: _checkDependabot,
    ),
    (name: 'ci pins the Dart SDK to the workspace floor', run: _checkSdkPin),
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

/// The raw text of [path], for the assertions whose subject is a comment.
///
/// Comments do not survive parsing, and three of the claims this script makes
/// -- the recorded pana measurements, the deferral of the engine member and
/// the tag-push limit -- live in them, because their audience is the person
/// reading the workflow.
String _text(String path, String check) {
  final file = File(path);
  if (!file.existsSync()) {
    throw CheckFailure(check, 'no such file: $path');
  }

  return file.readAsStringSync();
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
  const check = 'the slow suites run on every CI platform and gate the build';

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

  final runners = _operatingSystems(slow, _slowJobName, check);

  for (final platform in _platforms) {
    if (_slowSuitesRunLocally.contains(platform)) continue;

    final covered = runners.any((runner) => runner.startsWith(platform));
    if (!covered) {
      throw CheckFailure(
        check,
        'no $platform runner in ${runners.join(', ')}; the slow job must '
        'cover every CI platform except the ones _slowSuitesRunLocally '
        'names',
      );
    }
  }

  for (final platform in _slowSuitesRunLocally) {
    final present = runners.any((runner) => runner.startsWith(platform));
    if (present) {
      throw CheckFailure(
        check,
        '$platform is kept off the slow job while the repository is '
        'private; remove it from _slowSuitesRunLocally to bring it back',
      );
    }
  }

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

/// One publishable workspace member.
final class _Member {
  /// Creates the member published from [directory] as [name].
  _Member(this.directory, this.name);

  /// The member's directory, relative to the repository root.
  final String directory;

  /// The package name it publishes, which is also its release-tag prefix.
  final String name;

  /// The other members it depends on, filled in once every name is known.
  final List<String> siblings = [];
}

/// The workspace members, read from the root pubspec rather than listed here,
/// so a member added to the workspace is a member these checks demand.
List<_Member> _members(String check) {
  final root = _load(_rootPubspecPath, check);
  final workspace = root['workspace'];
  if (workspace is! YamlList || workspace.isEmpty) {
    throw CheckFailure(
      check,
      '$_rootPubspecPath declares no workspace members, so there is nothing to '
      'release',
    );
  }

  final members = <_Member>[];
  for (final entry in workspace) {
    final directory = '$entry';
    final pubspec = _load('$directory/pubspec.yaml', check);
    final name = pubspec['name'];
    if (name is! String) {
      throw CheckFailure(check, '$directory/pubspec.yaml declares no name');
    }

    members.add(_Member(directory, name));
  }

  final names = {for (final member in members) member.name};
  for (final member in members) {
    final pubspec = _load('${member.directory}/pubspec.yaml', check);
    final dependencies = pubspec['dependencies'];
    if (dependencies is! YamlMap) continue;

    for (final dependency in dependencies.keys) {
      if (names.contains('$dependency')) member.siblings.add('$dependency');
    }
  }

  return members;
}

/// The members pana can score on this tree: the ones that depend on no
/// sibling, so a hosted resolution finds everything they ask for.
List<_Member> _scorableMembers(String check) =>
    _members(check).where((member) => member.siblings.isEmpty).toList();

/// The members pana cannot score until their siblings are on pub.dev.
List<_Member> _deferredMembers(String check) =>
    _members(check).where((member) => member.siblings.isNotEmpty).toList();

/// The `on` block of [workflow].
///
/// Looked up under both spellings: YAML 1.1 reads a bare `on` as a boolean,
/// and which one a parser hands back is not this script's business.
YamlMap _triggers(YamlMap workflow, String check) {
  final triggers = workflow['on'] ?? workflow[true];
  if (triggers is! YamlMap) {
    throw CheckFailure(check, '$_publishPath declares no on block');
  }

  return triggers;
}

/// The jobs mapping of the workflow at [path].
YamlMap _jobsOf(String path, String check) {
  final jobs = _load(path, check)['jobs'];
  if (jobs is! YamlMap) {
    throw CheckFailure(check, '$path declares no jobs mapping');
  }

  return jobs;
}

/// The job declared under [name] in the release workflow.
YamlMap _releaseJob(String name, String check) {
  final job = _jobsOf(_publishPath, check)[name];
  if (job is! YamlMap) {
    throw CheckFailure(check, '$_publishPath declares no $name job');
  }

  return job;
}

/// Whether [value] reads an output of the parse job.
bool _readsParseOutput(Object? value, String output) =>
    value is String && value.contains('needs.$_parseJobName.outputs.$output');

void _checkReleaseTriggers() {
  const check = 'the release workflow triggers only on per-package tags';

  final triggers = _triggers(_load(_publishPath, check), check);
  final extra = triggers.keys.where((key) => '$key' != 'push').toList();
  if (extra.isNotEmpty) {
    throw CheckFailure(
      check,
      '$_publishPath also triggers on ${extra.join(', ')}; a release is a tag '
      'and nothing else, or an ordinary push would try to publish',
    );
  }

  final push = triggers['push'];
  if (push is! YamlMap) {
    throw CheckFailure(check, '$_publishPath declares no push trigger');
  }

  if (push['branches'] != null) {
    throw CheckFailure(
      check,
      '$_publishPath still triggers on a branch push; every push to it would '
      'enter the release path',
    );
  }

  final tags = push['tags'];
  if (tags is! YamlList) {
    throw CheckFailure(
      check,
      '$_publishPath declares no tag patterns, so it runs on every tag',
    );
  }

  final patterns = tags.map((pattern) => '$pattern').toList();
  for (final member in _members(check)) {
    final prefix = '${member.name}-v';
    final covered = patterns.where((pattern) => pattern.startsWith(prefix));
    if (covered.isEmpty) {
      throw CheckFailure(
        check,
        'no tag pattern starts with $prefix, so ${member.directory} can never '
        'be released; the patterns are ${patterns.join(', ')}',
      );
    }

    final bounded = covered.where((pattern) => !pattern.endsWith('*'));
    if (bounded.isNotEmpty) {
      throw CheckFailure(
        check,
        '${bounded.join(', ')} does not end in a wildcard, so a prerelease '
        'suffix such as -beta.1 would trigger nothing',
      );
    }
  }
}

void _checkParseJob() {
  const check = 'the release workflow parses the tag with the shared script';

  if (!File(_parseScriptPath).existsSync()) {
    throw CheckFailure(
      check,
      'no such file: $_parseScriptPath; the tag-to-directory mapping lives '
      'there so the validation plan can exercise it with a real tag',
    );
  }

  final parse = _releaseJob(_parseJobName, check);
  final outputs = parse['outputs'];
  if (outputs is! YamlMap) {
    throw CheckFailure(
      check,
      'the $_parseJobName job exposes no outputs, so no job below it can know '
      'which member the tag releases',
    );
  }

  for (final output in ['directory', 'package', 'version']) {
    if (outputs[output] == null) {
      throw CheckFailure(
        check,
        'the $_parseJobName job exposes no $output output',
      );
    }
  }

  final steps = parse['steps'];
  final calls =
      steps is YamlList &&
      steps.any(
        (step) =>
            step is YamlMap &&
            step['run'] is String &&
            (step['run'] as String).contains(_parseScriptPath),
      );
  if (!calls) {
    throw CheckFailure(
      check,
      'the $_parseJobName job never runs $_parseScriptPath, so the mapping the '
      'validation plan exercises is not the one the release uses',
    );
  }
}

void _checkVerifyJob() {
  const check = 'the release is verified from the parsed member directory';

  final verify = _releaseJob(_verifyJobName, check);
  if (!_needsOf(verify).contains(_parseJobName)) {
    throw CheckFailure(
      check,
      'the $_verifyJobName job does not need the $_parseJobName job, so it '
      'cannot read the directory it has to verify',
    );
  }

  final jobs = _jobsOf(_publishPath, check);
  final ciCallers = jobs.entries
      .where(
        (entry) =>
            entry.value is YamlMap &&
            (entry.value as YamlMap)['uses'] == './$_ciPath',
      )
      .map((entry) => '${entry.key}')
      .toList();
  if (ciCallers.every((caller) => !_needsOf(verify).contains(caller))) {
    throw CheckFailure(
      check,
      'the $_verifyJobName job does not need the job calling ./$_ciPath, so a '
      'release could be verified without the gate having run',
    );
  }

  final steps = verify['steps'];
  if (steps is! YamlList) {
    throw CheckFailure(check, 'the $_verifyJobName job declares no steps');
  }

  for (final subject in ['publish --dry-run', 'pana']) {
    final matching = steps.whereType<YamlMap>().where(
      (step) => step['run'] is String && '${step['run']}'.contains(subject),
    );
    if (matching.isEmpty) {
      throw CheckFailure(
        check,
        'the $_verifyJobName job runs no $subject step',
      );
    }

    final misplaced = matching.where(
      (step) => !_readsParseOutput(step['working-directory'], 'directory'),
    );
    if (misplaced.isNotEmpty) {
      throw CheckFailure(
        check,
        'a $subject step does not run in the parsed member directory, so it '
        'would measure the workspace root instead of the released package',
      );
    }
  }
}

/// A recorded measurement comment, as `# packages/x  160/160  deduction 0`.
final _measurementPattern = RegExp(
  r'^\s*#\s+(packages/\S+)\s+(\d+)/(\d+)\s+deduction\s+(\d+)\s*$',
  multiLine: true,
);

void _checkPanaThreshold() {
  const check = 'the pana threshold is the largest recorded deduction';

  final text = _text(_publishPath, check);

  final threshold = RegExp(r'--exit-code-threshold\s+(\d+)').firstMatch(text);
  if (threshold == null) {
    throw CheckFailure(
      check,
      '$_publishPath runs pana with no --exit-code-threshold, so a score that '
      'fell would still publish',
    );
  }

  final recorded = <String, int>{};
  for (final match in _measurementPattern.allMatches(text)) {
    final directory = match[1]!;
    final points = int.parse(match[2]!);
    final total = int.parse(match[3]!);
    final deduction = int.parse(match[4]!);

    if (total - points != deduction) {
      throw CheckFailure(
        check,
        'the recorded measurement for $directory says $points/$total and a '
        'deduction of $deduction, which do not agree',
      );
    }

    recorded[directory] = deduction;
  }

  for (final member in _scorableMembers(check)) {
    if (!recorded.containsKey(member.directory)) {
      throw CheckFailure(
        check,
        'no pana measurement is recorded for ${member.directory}; the '
        'threshold has to be a measurement rather than a guess',
      );
    }
  }

  for (final member in _deferredMembers(check)) {
    final deferred = RegExp(
      '${RegExp.escape(member.directory)}[\\s\\S]{0,400}?first-publish',
    );
    if (recorded.containsKey(member.directory)) continue;
    if (!deferred.hasMatch(text)) {
      throw CheckFailure(
        check,
        '${member.directory} has no measurement and no recorded deferral to '
        'the first-publish bead; it depends on ${member.siblings.join(', ')}, '
        'which pana resolves from pub.dev, so silence here reads as an '
        'oversight',
      );
    }
  }

  final largest = recorded.values.reduce((a, b) => a > b ? a : b);
  final declared = int.parse(threshold[1]!);
  if (declared != largest) {
    throw CheckFailure(
      check,
      'the pana threshold is $declared but the largest recorded deduction is '
      '$largest; a threshold above the measurements tolerates a regression '
      'and one below them fails the publish',
    );
  }
}

void _checkPublishJob() {
  const check = 'the publish job authenticates with an identity token';

  final publish = _releaseJob(_publishJobName, check);

  final permissions = publish['permissions'];
  if (permissions is! YamlMap || permissions['id-token'] != 'write') {
    throw CheckFailure(
      check,
      'the $_publishJobName job does not grant id-token: write, so pub.dev has '
      'no JWT to authenticate and the publish would ask for a credential',
    );
  }

  final uses = publish['uses'];
  if (uses is! String || !uses.startsWith(_reusablePublishWorkflow)) {
    throw CheckFailure(
      check,
      'the $_publishJobName job does not delegate to '
      '$_reusablePublishWorkflow<ref>; it calls ${uses ?? 'nothing'}',
    );
  }

  final with_ = publish['with'];
  if (with_ is! YamlMap ||
      !_readsParseOutput(with_['working-directory'], 'directory')) {
    throw CheckFailure(
      check,
      'the $_publishJobName job does not pass the parsed member directory as '
      'working-directory, so it would publish the workspace root',
    );
  }

  if (publish['secrets'] != null) {
    throw CheckFailure(
      check,
      'the $_publishJobName job passes secrets; trusted publishing needs none, '
      'and a stored credential is the thing this workflow exists to avoid',
    );
  }
}

void _checkReleaseJob() {
  const check = 'the release job names the parsed version';

  final release = _releaseJob(_releaseJobName, check);
  if (!_needsOf(release).contains(_publishJobName)) {
    throw CheckFailure(
      check,
      'the $_releaseJobName job does not need the $_publishJobName job, so a '
      'release could be announced for a version that never reached pub.dev',
    );
  }

  if (!_needsOf(release).contains(_parseJobName)) {
    throw CheckFailure(
      check,
      'the $_releaseJobName job does not need the $_parseJobName job',
    );
  }

  if (!_readsParseOutput(release.span.text, 'version')) {
    throw CheckFailure(
      check,
      'the $_releaseJobName job never reads the parsed version, so the release '
      'it opens cannot name what was published',
    );
  }
}

void _checkTagPushLimit() {
  const check = 'the release workflow records the tag-push limit';

  final text = _text(_publishPath, check);
  final recorded = RegExp(
    r'^\s*#.*more than three tags.*$',
    multiLine: true,
  ).hasMatch(text);
  if (!recorded) {
    throw CheckFailure(
      check,
      '$_publishPath carries no comment recording that a push of more than '
      'three tags fires nothing; with three members that is reachable, and it '
      'fails by doing nothing at all',
    );
  }
}

void _checkCodeowners() {
  const check = 'the ownership file names an owner of this org';

  final text = _text(_codeownersPath, check);
  final owners = <String>[
    for (final line in text.split('\n'))
      if (!line.trimLeft().startsWith('#'))
        ...RegExp(r'@[\w./-]+').allMatches(line).map((match) => match[0]!),
  ];

  if (owners.isEmpty) {
    throw CheckFailure(
      check,
      '$_codeownersPath names no owner, so every review request is routed '
      'nowhere',
    );
  }

  final foreign = owners
      .where((owner) => !owner.startsWith('@memento-engineering'))
      .toList();
  if (foreign.isNotEmpty) {
    throw CheckFailure(
      check,
      '$_codeownersPath names ${foreign.join(', ')}, which does not resolve '
      'inside this organisation; a request routed there fails silently',
    );
  }
}

void _checkDependabot() {
  const check =
      'dependabot updates pub at the workspace root and the actions '
      'ecosystem';

  final updates = _load(_dependabotPath, check)['updates'];
  if (updates is! YamlList) {
    throw CheckFailure(check, '$_dependabotPath declares no updates list');
  }

  final entries = updates.whereType<YamlMap>().toList();

  /// The entry watching [directory] for [ecosystem], or null.
  YamlMap? entryFor(String ecosystem, String directory) {
    for (final entry in entries) {
      if ('${entry['package-ecosystem']}' != ecosystem) continue;
      if ('${entry['directory']}' != directory) continue;
      return entry;
    }

    return null;
  }

  void checkCadence(YamlMap entry, String prefix, String subject) {
    final schedule = entry['schedule'];
    if (schedule is! YamlMap || '${schedule['interval']}' != 'monthly') {
      throw CheckFailure(
        check,
        'the $subject entry does not run monthly; the cadence is the fork\'s '
        'and is kept deliberately',
      );
    }

    final message = entry['commit-message'];
    if (message is! YamlMap || '${message['prefix']}' != prefix) {
      throw CheckFailure(
        check,
        'the $subject entry does not prefix its commits with $prefix, so its '
        'pull requests would not read like the rest of the history',
      );
    }
  }

  final pubEntries = entries
      .where((entry) => '${entry['package-ecosystem']}' == 'pub')
      .toList();
  if (pubEntries.isEmpty) {
    throw CheckFailure(
      check,
      '$_dependabotPath declares no pub entry; a pub workspace is updated '
      'from one entry at the root, not from a member directory',
    );
  }

  if (pubEntries.length > 1) {
    final directories = pubEntries
        .map((entry) => '${entry['directory']}')
        .join(', ');
    throw CheckFailure(
      check,
      '$_dependabotPath declares ${pubEntries.length} pub entries '
      '($directories); a pub workspace\'s dependency_services run refuses '
      'anything but the root ("Only apply dependency_services to the root '
      'of the workspace"), so one root entry is what updates every '
      'member\'s constraints',
    );
  }

  final pub = entryFor('pub', '/');
  if (pub == null) {
    throw CheckFailure(
      check,
      '$_dependabotPath\'s pub entry does not watch directory /; a pub '
      'workspace\'s dependency_services run refuses anything but the root '
      'directory',
    );
  }

  checkCadence(pub, 'chore', 'pub');

  final actions = entryFor('github-actions', '/');
  if (actions == null) {
    throw CheckFailure(
      check,
      '$_dependabotPath watches no github-actions ecosystem, so the pinned '
      'action versions in the workflows go stale unnoticed',
    );
  }

  checkCadence(actions, 'ci', 'github-actions');
}

/// The `major.minor` of [_rootPubspecPath]'s `environment.sdk` lower bound,
/// e.g. `^3.12.0` -> `3.12`.
String _sdkFloor(String check) {
  final root = _load(_rootPubspecPath, check);
  final environment = root['environment'];
  final constraint = environment is YamlMap ? environment['sdk'] : null;
  if (constraint is! String) {
    throw CheckFailure(
      check,
      '$_rootPubspecPath declares no environment.sdk constraint, so there is '
      'no floor to pin CI to',
    );
  }

  final match = RegExp(r'(\d+)\.(\d+)').firstMatch(constraint);
  if (match == null) {
    throw CheckFailure(
      check,
      '$_rootPubspecPath\'s environment.sdk constraint "$constraint" names no '
      'major.minor lower bound',
    );
  }

  return '${match[1]}.${match[2]}';
}

void _checkSdkPin() {
  const check = 'ci pins the Dart SDK to the workspace floor';

  final floor = _sdkFloor(check);
  final jobs = _jobsOf(_ciPath, check);

  var sawSetupDart = false;
  for (final entry in jobs.entries) {
    final job = entry.value;
    if (job is! YamlMap) continue;

    final steps = job['steps'];
    if (steps is! YamlList) continue;

    for (final step in steps) {
      if (step is! YamlMap) continue;

      final uses = step['uses'];
      if (uses is! String || !uses.startsWith('dart-lang/setup-dart@')) {
        continue;
      }
      sawSetupDart = true;

      final with_ = step['with'];
      final sdk = with_ is YamlMap ? with_['sdk'] : null;
      if (sdk == null) {
        throw CheckFailure(
          check,
          'the ${entry.key} job\'s dart-lang/setup-dart@v1 step declares no '
          'with.sdk, so it floats to whatever the default channel resolves '
          'to on the day it runs; dart format\'s canonical layout differs '
          'between SDK minors, so the format check needs one pinned SDK',
        );
      }

      final pinned = '$sdk';
      if (pinned != floor && !pinned.startsWith('$floor.')) {
        throw CheckFailure(
          check,
          'the ${entry.key} job pins dart-lang/setup-dart@v1 to $pinned, '
          'which is not $floor or $floor.x -- the major.minor of the '
          'workspace\'s environment.sdk floor in $_rootPubspecPath; bump the '
          'pin together with that floor',
        );
      }
    }
  }

  if (!sawSetupDart) {
    throw CheckFailure(
      check,
      '$_ciPath uses no dart-lang/setup-dart@v1 step, so there is nothing to '
      'pin',
    );
  }
}
