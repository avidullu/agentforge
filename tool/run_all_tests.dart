/// Unified test runner for AgentForge.
///
/// A single, discoverable entry point for the full test suite + coverage gate:
///
/// ```bash
/// dart run tool/run_all_tests.dart              # full suite + coverage floor
/// dart run tool/run_all_tests.dart -- -t agent   # filter by test name (passthrough)
/// dart run tool/run_all_tests.dart -- --no-coverage  # skip coverage
/// dart run tool/run_all_tests.dart --floor 35    # raise the coverage floor
/// ```
///
/// Everything after `--` is passed through to `flutter test`.
///
/// Exit code is non-zero on test failure or coverage below floor.
/// Coverage floor defaults to 29% (tracker baseline; ratchet UP only).
library;

import 'dart:io';

import 'check_coverage.dart' as coverage;

const _defaultFloor = 29;
const _coverageFile = 'coverage/lcov.info';

Future<void> main(List<String> args) async {
  // Split args: everything after '--' goes to flutter test.
  final split = args.indexOf('--');
  final ourArgs = split == -1 ? args : args.sublist(0, split);
  final flutterArgs = split == -1 ? <String>[] : args.sublist(split + 1);

  // Parse our args.
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

  // Build the flutter test command.
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

  // Run flutter test.
  final result = await Process.run('flutter', testArgs);

  if (result.exitCode != 0) {
    stderr.writeln('\n❌ Tests failed (exit ${result.exitCode}).');
    exitCode = result.exitCode;
    return;
  }

  // Coverage gate.
  if (!noCoverage) {
    final covFile = File(_coverageFile);
    if (!covFile.existsSync()) {
      stderr.writeln(
        '⚠  No coverage file found at $_coverageFile — skipping floor check.',
      );
    } else {
      try {
        coverage.main([_coverageFile, '$floor']);
      } catch (_) {
        // check_coverage sets exitCode itself
      }
      if (exitCode != 0) {
        stderr.writeln(
          '\n❌ Coverage below floor ($floor%). Ratchet the floor UP, never down.',
        );
        return;
      }
    }
  }

  stdout.writeln('\n✅ All tests passed.');
  if (!noCoverage && exitCode == 0) {
    stdout.writeln('✅ Coverage floor ($floor%) met.');
  }
}
