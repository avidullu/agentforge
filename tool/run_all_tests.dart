/// Unified test runner for AgentForge.
///
/// ```bash
/// dart run tool/run_all_tests.dart
/// dart run tool/run_all_tests.dart -- -t agent
/// dart run tool/run_all_tests.dart -- --no-coverage
/// dart run tool/run_all_tests.dart --floor 35
/// ```
///
/// Everything after `--` is passed through to `flutter test`.
library;

import 'dart:io';

const _defaultFloor = 29;
const _coverageFile = 'coverage/lcov.info';

Future<void> main(List<String> args) async {
  final split = args.indexOf('--');
  final ourArgs = split == -1 ? args : args.sublist(0, split);
  final flutterArgs = split == -1 ? <String>[] : args.sublist(split + 1);

  var floor = _defaultFloor;
  var noCoverage = false;
  for (var i = 0; i < ourArgs.length; i++) {
    if (ourArgs[i] == '--floor' && i + 1 < ourArgs.length) {
      floor = int.tryParse(ourArgs[i + 1]) ?? _defaultFloor;
      i++;
    } else if (ourArgs[i] == '--no-coverage') {
      noCoverage = true;
    }
  }

  final testArgs = <String>['test'];
  if (!noCoverage) {
    testArgs.add('--coverage');
  }
  testArgs.addAll(flutterArgs);

  stdout.writeln('=== AgentForge test suite ===');
  stdout.writeln('Command: flutter ${testArgs.join(' ')}');
  if (!noCoverage) {
    stdout.writeln('Coverage floor: $floor%');
  }
  stdout.writeln();

  final result = await Process.run('flutter', testArgs, runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('\nTests failed (exit ${result.exitCode}).');
    exitCode = result.exitCode;
    return;
  }

  if (!noCoverage) {
    final covFile = File(_coverageFile);
    if (!covFile.existsSync()) {
      stderr.writeln(
        'No coverage file at $_coverageFile — skipping floor check.',
      );
    } else {
      final cov = await Process.run('dart', [
        'run',
        'tool/check_coverage.dart',
        _coverageFile,
        '$floor',
      ], runInShell: true);
      stdout.write(cov.stdout);
      stderr.write(cov.stderr);
      if (cov.exitCode != 0) {
        stderr.writeln(
          '\nCoverage below floor ($floor%). Ratchet the floor UP, never down.',
        );
        exitCode = cov.exitCode;
        return;
      }
    }
  }

  stdout.writeln('\nAll tests passed.');
  if (!noCoverage && exitCode == 0) {
    stdout.writeln('Coverage floor ($floor%) met.');
  }
}
