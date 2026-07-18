import 'dart:io';

import 'config_model.dart';
import 'diff_coverage.dart';

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'Usage: dart run tool/check_diff_coverage.dart '
      '<lcov.info> <base-commit> <floor>',
    );
    exitCode = 64;
    return;
  }

  final coverageFile = File(args[0]);
  final base = args[1];
  final floor = parseCoverageFloor(args[2]);
  if (!coverageFile.existsSync() ||
      floor == null ||
      !RegExp(r'^[0-9a-fA-F]{7,64}$').hasMatch(base)) {
    stderr.writeln('Coverage file, base commit, or floor is invalid.');
    exitCode = 64;
    return;
  }

  final repoRoot = findRepoRoot();
  final diffArgs = [
    '-c',
    'core.quotePath=false',
    'diff',
    '--no-ext-diff',
    '--unified=0',
    '--diff-filter=ACMR',
    '$base...HEAD',
    '--',
    'lib',
  ];
  final diff = Process.runSync(
    'git',
    diffArgs,
    workingDirectory: repoRoot.path,
  );
  if (diff.exitCode != 0) {
    stderr.writeln('Unable to compute the changed-line coverage diff.');
    exitCode = 1;
    return;
  }

  final inventory = Process.runSync(
    'git',
    [
      'diff',
      '--numstat',
      '-z',
      '--diff-filter=ACMR',
      '$base...HEAD',
      '--',
      'lib',
    ],
    workingDirectory: repoRoot.path,
    stdoutEncoding: null,
  );
  if (inventory.exitCode != 0) {
    stderr.writeln('Unable to inventory added source lines.');
    exitCode = 1;
    return;
  }

  final lcov = parseLcov(
    coverageFile.readAsStringSync(),
    repoRoot: repoRoot.absolute.path,
  );
  final changed = parseUnifiedDiff(diff.stdout.toString());
  List<String> expectedPaths;
  try {
    expectedPaths = parseAddedPathsFromNumstat(inventory.stdout);
  } on FormatException {
    stderr.writeln('Changed source inventory was malformed or not UTF-8.');
    exitCode = 1;
    return;
  }
  final unparsed = unparsedEligibleDartPaths(
    expectedPaths: expectedPaths,
    parsedPaths: changed.keys,
  );
  if (unparsed.isNotEmpty) {
    stderr.writeln(
      'Unable to parse ${unparsed.length} changed Dart source path(s); '
      'failing closed.',
    );
    exitCode = 1;
    return;
  }
  final result = evaluateDiffCoverage(lcov: lcov, changed: changed);

  if (result.found == 0) {
    stdout.writeln(
      'Changed-line coverage: no changed executable lib/**/*.dart lines.',
    );
    return;
  }

  stdout.writeln(
    'Changed-line coverage: ${result.hit}/${result.found} = '
    '${result.percent.toStringAsFixed(2)}% '
    '(floor ${floor.toStringAsFixed(2)}%)',
  );
  for (final entry in result.uncovered.entries) {
    final lines = entry.value.take(20).join(',');
    final suffix = entry.value.length > 20 ? ',…' : '';
    stdout.writeln('  uncovered ${entry.key}:$lines$suffix');
  }

  if (result.percent < floor) exitCode = 1;
}
