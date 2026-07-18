import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/diff_coverage.dart';

void main() {
  group('normalizeCoveragePath', () {
    test('normalizes absolute Unix and Windows paths to repo-relative lib', () {
      expect(
        normalizeCoveragePath('/work/agentforge/lib/core/a.dart'),
        'lib/core/a.dart',
      );
      expect(
        normalizeCoveragePath(r'C:\work\agentforge\lib\core\a.dart'),
        'lib/core/a.dart',
      );
    });

    test('strips an explicit repository root', () {
      expect(
        normalizeCoveragePath(
          '/work/agentforge/lib/a.dart',
          repoRoot: '/work/agentforge',
        ),
        'lib/a.dart',
      );
    });
  });

  test('parseLcov merges duplicate records using the highest hit count', () {
    final parsed = parseLcov('''
SF:/work/agentforge/lib/a.dart
DA:2,0
DA:3,1
end_of_record
SF:/work/agentforge/lib/a.dart
DA:2,4
end_of_record
''');
    expect(parsed['lib/a.dart'], {2: 4, 3: 1});
  });

  test(
    'parseLcov rejects an outside-root source with a colliding lib path',
    () {
      final parsed = parseLcov('''
SF:/dependency/lib/a.dart
DA:2,99
end_of_record
SF:/work/agentforge/lib/a.dart
DA:2,0
end_of_record
''', repoRoot: '/work/agentforge');
      expect(parsed, {
        'lib/a.dart': {2: 0},
      });
    },
  );

  test('parseUnifiedDiff tracks only added new-file line numbers', () {
    final parsed = parseUnifiedDiff('''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,2 +1,3 @@
-old
+first
 context
+third
''');
    expect(
      parsed['lib/a.dart']!.map((line) => '${line.line}:${line.text}').toList(),
      ['1:first', '3:third'],
    );
  });

  test('parseUnifiedDiff does not treat Dart increment code as a header', () {
    final parsed = parseUnifiedDiff('''
diff --git a/lib/a.dart b/lib/a.dart
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1 +1,2 @@
 existing();
+++ value;
''');
    expect(
      parsed['lib/a.dart']!.map((line) => '${line.line}:${line.text}').toList(),
      ['2:++ value;'],
    );
  });

  test('NUL-safe path inventory makes a C-quoted path fail closed', () {
    final parsed = parseUnifiedDiff(r'''
diff --git "a/lib/\303\251.dart" "b/lib/\303\251.dart"
--- "a/lib/\303\251.dart"
+++ "b/lib/\303\251.dart"
@@ -0,0 +1 @@
+void f() {}
''');
    final unparsed = unparsedEligibleDartPaths(
      expectedPaths: const ['lib/é.dart'],
      parsedPaths: parsed.keys,
    );
    expect(unparsed, {'lib/é.dart'});
  });

  test('parseNullSeparatedUtf8 preserves spaces and Unicode', () {
    final paths = parseNullSeparatedUtf8([
      ...utf8.encode('lib/a file.dart'),
      0,
      ...utf8.encode('lib/é.dart'),
      0,
    ]);
    expect(paths, ['lib/a file.dart', 'lib/é.dart']);
  });

  test('numstat inventory keeps only paths with added lines', () {
    final paths = parseAddedPathsFromNumstat([
      ...utf8.encode('2\t0\tlib/a file.dart'),
      0,
      ...utf8.encode('0\t0\tlib/rename only.dart'),
      0,
      ...utf8.encode('0\t0\tlib/empty.dart'),
      0,
      ...utf8.encode('1\t3\tlib/é.dart'),
      0,
    ]);
    expect(paths, ['lib/a file.dart', 'lib/é.dart']);
  });

  test('numstat inventory handles rename records without false failures', () {
    final paths = parseAddedPathsFromNumstat([
      ...utf8.encode('0\t0\t'),
      0,
      ...utf8.encode('lib/old.dart'),
      0,
      ...utf8.encode('lib/rename only.dart'),
      0,
      ...utf8.encode('2\t1\t'),
      0,
      ...utf8.encode('lib/before.dart'),
      0,
      ...utf8.encode('lib/after.dart'),
      0,
    ]);
    expect(paths, ['lib/after.dart']);
  });

  test('real Git pure rename has no added-path coverage obligation', () {
    final fixture = Directory.systemTemp.createTempSync(
      'agentforge-diff-coverage-',
    );
    try {
      ProcessResult runGit(
        List<String> arguments, {
        bool binaryOutput = false,
      }) {
        final result = Process.runSync(
          'git',
          arguments,
          workingDirectory: fixture.path,
          stdoutEncoding: binaryOutput ? null : systemEncoding,
        );
        expect(
          result.exitCode,
          0,
          reason: 'git ${arguments.join(' ')} failed: ${result.stderr}',
        );
        return result;
      }

      runGit(['init', '--quiet']);
      runGit(['config', 'user.name', 'AgentForge CI']);
      runGit(['config', 'user.email', 'ci@agentforge.invalid']);
      runGit(['config', 'core.autocrlf', 'false']);
      final lib = Directory('${fixture.path}/lib')..createSync();
      File('${lib.path}/a.dart').writeAsStringSync('void f() {}\n');
      runGit(['add', 'lib/a.dart']);
      runGit(['commit', '--quiet', '-m', 'base']);
      runGit(['mv', 'lib/a.dart', 'lib/b.dart']);
      runGit(['commit', '--quiet', '-m', 'rename']);

      final patch = runGit([
        '-c',
        'core.quotePath=false',
        'diff',
        '--no-ext-diff',
        '--unified=0',
        '--diff-filter=ACMR',
        'HEAD^...HEAD',
        '--',
        'lib',
      ]);
      final inventory = runGit([
        'diff',
        '--numstat',
        '-z',
        '--diff-filter=ACMR',
        'HEAD^...HEAD',
        '--',
        'lib',
      ], binaryOutput: true);

      expect(parseUnifiedDiff(patch.stdout.toString()), isEmpty);
      expect(parseAddedPathsFromNumstat(inventory.stdout), isEmpty);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('numstat inventory rejects malformed and binary counts', () {
    expect(
      () => parseAddedPathsFromNumstat(utf8.encode('bad-record\u0000')),
      throwsFormatException,
    );
    expect(
      () => parseAddedPathsFromNumstat(utf8.encode('-\t-\tlib/a.dart\u0000')),
      throwsFormatException,
    );
  });

  test('coverage floor rejects non-finite and out-of-range values', () {
    expect(parseCoverageFloor('NaN'), isNull);
    expect(parseCoverageFloor('Infinity'), isNull);
    expect(parseCoverageFloor('-1'), isNull);
    expect(parseCoverageFloor('101'), isNull);
    expect(parseCoverageFloor('80'), 80);
  });

  test('evaluateDiffCoverage counts instrumented changed lines only', () {
    final result = evaluateDiffCoverage(
      lcov: {
        'lib/a.dart': {4: 1, 5: 0, 6: 0},
      },
      changed: {
        'lib/a.dart': const [
          ChangedLine(path: 'lib/a.dart', line: 4, text: 'hit();'),
          ChangedLine(path: 'lib/a.dart', line: 5, text: 'miss();'),
          ChangedLine(path: 'lib/a.dart', line: 7, text: '// no DA record'),
        ],
      },
    );
    expect(result.found, 2);
    expect(result.hit, 1);
    expect(result.percent, 50);
    expect(result.uncovered, {
      'lib/a.dart': [5],
    });
  });

  test('a new source absent from LCOV cannot evade the gate', () {
    final result = evaluateDiffCoverage(
      lcov: const {},
      changed: {
        'lib/new_file.dart': const [
          ChangedLine(path: 'lib/new_file.dart', line: 1, text: '// comment'),
          ChangedLine(path: 'lib/new_file.dart', line: 2, text: ''),
          ChangedLine(path: 'lib/new_file.dart', line: 3, text: 'void f() {}'),
        ],
      },
    );
    expect(result.found, 1);
    expect(result.hit, 0);
    expect(result.uncovered, {
      'lib/new_file.dart': [3],
    });
  });

  test('non-lib and non-Dart changes are ignored', () {
    final result = evaluateDiffCoverage(
      lcov: const {},
      changed: {
        'test/a_test.dart': const [
          ChangedLine(path: 'test/a_test.dart', line: 1, text: 'test();'),
        ],
        'lib/readme.txt': const [
          ChangedLine(path: 'lib/readme.txt', line: 1, text: 'text'),
        ],
      },
    );
    expect(result.found, 0);
    expect(result.percent, 100);
  });
}
