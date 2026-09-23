import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'butcher_config.dart';

/// True when the project-relative posix path is out of mutation scope.
typedef MutationExclusion = bool Function(String relativePath);

/// Exclude-only glob matching over project-relative posix paths.
///
/// The semantics are exclude-only and the dialect is the analyzer's `exclude`
/// dialect, so `**` crosses path separators anywhere. There is no include
/// list, no negation and no re-include: one pattern never undoes another and
/// the order of the patterns does not affect the result. A path is out of
/// scope when any pattern matches it.
///
/// No parity is claimed with gitignore or with any other mutation tool's
/// configuration format.
///
/// Every pattern compiles against an explicit posix context, because the
/// default context is the host's own syntax and a Windows run would otherwise
/// match different strings than a posix run against the same configuration.
final class MutationScope {
  /// Compiles [patterns] against a posix context.
  MutationScope(List<String> patterns)
    : _patterns = [
        for (final pattern in patterns) Glob(pattern, context: p.posix),
      ];

  /// Compiles the `exclude` list of [config].
  factory MutationScope.of(ButcherConfig config) =>
      MutationScope(config.exclude);

  /// Compiles the `exclude` list of the [butcherConfigFile] at [projectRoot].
  factory MutationScope.load(String projectRoot) =>
      MutationScope.of(ButcherConfig.load(projectRoot));

  final List<Glob> _patterns;

  /// True when any pattern matches the project-relative posix path
  /// [relativePath].
  bool excludes(String relativePath) =>
      _patterns.any((pattern) => pattern.matches(relativePath));
}
