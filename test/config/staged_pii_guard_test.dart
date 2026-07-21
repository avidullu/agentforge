import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/pii_guard.dart';

/// Covers the AF-019 pre-commit guard: it must scan INDEX content, because a
/// commit publishes the index, not the working tree.
void main() {
  late Directory repo;

  void git(List<String> args) {
    final r = Process.runSync('git', args, workingDirectory: repo.path);
    if (r.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${r.stderr}');
    }
  }

  void write(String rel, String content) {
    final f = File('${repo.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  setUp(() {
    repo = Directory.systemTemp.createTempSync('af-staged-guard-');
    git(['init', '--quiet']);
    git(['config', 'user.email', 'test@example.invalid']);
    git(['config', 'user.name', 'AgentForge Test']);
    git(['config', 'commit.gpgsign', 'false']);
  });

  tearDown(() {
    if (repo.existsSync()) repo.deleteSync(recursive: true);
  });

  group('scanStagedStructuralHttps', () {
    test('clean when nothing is staged', () {
      expect(scanStagedStructuralHttps(repo), isEmpty);
    });

    test('allows the exact synthetic origin', () {
      write('config.dart', "const o = 'https://forge.example.test';\n");
      git(['add', 'config.dart']);
      expect(scanStagedStructuralHttps(repo), isEmpty);
    });

    test('flags a staged private origin', () {
      write('config.dart', "const o = 'https://private.example.invalid';\n");
      git(['add', 'config.dart']);

      final hits = scanStagedStructuralHttps(repo);
      expect(hits, hasLength(1));
      expect(hits.first.path, 'config.dart');
      expect(hits.first.line, 1);
      expect(hits.first.patternLabel, 'structural-https');
      // Hit strings must never echo the private value back into CI logs.
      expect(hits.first.toString(), isNot(contains('private')));
    });

    test('reports the staged blob even after the worktree is cleaned', () {
      // The bypass this guard exists to prevent: stage a leak, then "fix" the
      // file on disk. `git commit` would still publish the staged content.
      write('config.dart', "const o = 'https://private.example.invalid';\n");
      git(['add', 'config.dart']);
      write('config.dart', "const o = 'https://forge.example.test';\n");

      expect(scanStagedStructuralHttps(repo), hasLength(1));
    });

    test('ignores an unstaged worktree leak', () {
      write('config.dart', "const o = 'https://forge.example.test';\n");
      git(['add', 'config.dart']);
      git(['commit', '--quiet', '-m', 'init']);
      // Regenerating with a real config leaves this dirty; that is expected and
      // must not block unrelated commits.
      write('config.dart', "const o = 'https://private.example.invalid';\n");

      expect(scanStagedStructuralHttps(repo), isEmpty);
    });

    test('ignores staged deletions', () {
      write('doomed.dart', "const o = 'https://private.example.invalid';\n");
      git(['add', 'doomed.dart']);
      git(['commit', '--quiet', '-m', 'init']);
      git(['rm', '--quiet', 'doomed.dart']);

      expect(listStagedPaths(repo), isEmpty);
      expect(scanStagedStructuralHttps(repo), isEmpty);
    });

    test('skips binary blobs without throwing', () {
      File('${repo.path}/blob.bin').writeAsBytesSync([0, 1, 2, 0, 255, 10, 0]);
      git(['add', 'blob.bin']);

      expect(listStagedPaths(repo), contains('blob.bin'));
      expect(readStagedBlob(repo, 'blob.bin'), isNull);
      expect(scanStagedStructuralHttps(repo), isEmpty);
    });

    test('reads index content, not the worktree copy', () {
      write('a.txt', 'staged\n');
      git(['add', 'a.txt']);
      write('a.txt', 'worktree\n');

      expect(readStagedBlob(repo, 'a.txt'), 'staged\n');
    });

    test('returns null for a path that is not in the index', () {
      expect(readStagedBlob(repo, 'missing.txt'), isNull);
    });

    test('finds hits across multiple staged files and lines', () {
      write(
        'one.dart',
        '// ok https://forge.example.test\n'
            "const a = 'https://one.example.invalid';\n",
      );
      write('two.dart', "const b = 'https://two.example.invalid';\n");
      git(['add', 'one.dart', 'two.dart']);

      final hits = scanStagedStructuralHttps(repo);
      expect(hits, hasLength(2));
      expect(hits.map((h) => h.path).toSet(), {'one.dart', 'two.dart'});
      expect(hits.firstWhere((h) => h.path == 'one.dart').line, 2);
    });
  });

  group('staged scope limiting', () {
    test('limitTo ignores files outside the guarded set', () {
      // A doc link or the scanner's own regex must not block a commit.
      write('docs/notes.md', 'See https://developer.mozilla.org/en-US/x\n');
      git(['add', 'docs/notes.md']);

      expect(scanStagedStructuralHttps(repo), isNotEmpty);
      expect(
        scanStagedStructuralHttps(repo, limitTo: kGeneratedTrackedConfigPaths),
        isEmpty,
      );
    });

    test('still flags a leak inside the guarded generated config', () {
      const guarded = 'lib/core/config/generated/app_config.selected.dart';
      write(guarded, "const u = 'https://private.example.invalid';\n");
      git(['add', guarded]);

      final hits = scanStagedStructuralHttps(
        repo,
        limitTo: kGeneratedTrackedConfigPaths,
      );
      expect(hits, hasLength(1));
      expect(hits.first.path, guarded);
    });

    test('guarded set covers every tracked generator output', () {
      // Keep this in lockstep with tool/generate_config.dart.
      expect(
        kGeneratedTrackedConfigPaths,
        contains('agentforge-config.properties'),
      );
      expect(
        kGeneratedTrackedConfigPaths,
        contains('ios/Flutter/AgentForge.xcconfig'),
      );
    });
  });

  group('stagedNeverCommitPaths', () {
    test('is empty when no private file is staged', () {
      write('a.txt', 'x\n');
      git(['add', 'a.txt']);
      expect(stagedNeverCommitPaths(repo), isEmpty);
    });

    test('flags a force-added real config regardless of content', () {
      // `git add -f` defeats .gitignore; content may look perfectly synthetic.
      write('config/agentforge.config.json', '{"forgejo":{}}\n');
      git(['add', '-f', 'config/agentforge.config.json']);

      expect(
        stagedNeverCommitPaths(repo),
        contains('config/agentforge.config.json'),
      );
    });

    test('flags the gitignored local native outputs', () {
      write('agentforge-config.local.properties', 'forgejo.host=x\n');
      write('ios/Flutter/AgentForge.local.xcconfig', 'HOST = x\n');
      git([
        'add',
        '-f',
        'agentforge-config.local.properties',
        'ios/Flutter/AgentForge.local.xcconfig',
      ]);

      expect(stagedNeverCommitPaths(repo), hasLength(2));
    });
  });

  group('scanStructuralHttpsLines', () {
    test('is line-indexed from 1 and shared with the worktree scan', () {
      final hits = scanStructuralHttpsLines(
        path: 'x.dart',
        lines: const [
          'https://forge.example.test',
          'nothing here',
          'https://leak.example.invalid',
        ],
      );
      expect(hits, hasLength(1));
      expect(hits.first.line, 3);
      expect(hits.first.path, 'x.dart');
    });

    test('handles an empty document', () {
      expect(
        scanStructuralHttpsLines(path: 'x.dart', lines: const []),
        isEmpty,
      );
    });
  });
}
