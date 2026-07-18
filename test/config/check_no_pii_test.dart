import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';
import '../../tool/pii_guard.dart';

void main() {
  final repoRoot = findRepoRoot();
  final fixtures = Directory('${repoRoot.path}/test/config/fixtures');

  group('scanWithBlocklist (fixtures)', () {
    test('clean fixture has no hits for synthetic patterns', () {
      final blocklist = File('${fixtures.path}/blocklist_sample.txt');
      final patterns = loadBlocklistPatterns(blocklist);
      final hits = scanWithBlocklist(
        files: [File('${fixtures.path}/clean_sample.txt')],
        patterns: patterns,
        repoRoot: repoRoot.path,
      );
      expect(hits, isEmpty);
    });

    test('dirty fixture fails blocklist mode patterns', () {
      final blocklist = File('${fixtures.path}/blocklist_sample.txt');
      final patterns = loadBlocklistPatterns(blocklist);
      final hits = scanWithBlocklist(
        files: [File('${fixtures.path}/dirty_sample.txt')],
        patterns: patterns,
        repoRoot: repoRoot.path,
      );
      expect(hits, isNotEmpty);
      expect(hits.first.patternLabel, 'blocklist');
    });
  });

  group('scanStructuralHttps (fixtures)', () {
    test('clean fixture allows synthetic + loopback', () {
      final hits = scanStructuralHttps(
        files: [File('${fixtures.path}/clean_sample.txt')],
        repoRoot: repoRoot.path,
      );
      expect(hits, isEmpty);
    });

    test('dirty fixture flags non-synthetic https host', () {
      final hits = scanStructuralHttps(
        files: [File('${fixtures.path}/dirty_sample.txt')],
        repoRoot: repoRoot.path,
      );
      expect(hits, isNotEmpty);
      expect(hits.first.patternLabel, 'structural-https');
    });
  });

  group('check_no_pii CLI', () {
    test('blocklist mode fails closed on dirty fixture root', () {
      final result = Process.runSync('dart', [
        'run',
        'tool/check_no_pii.dart',
        '--mode=blocklist',
        '--scope=fixture',
        '--root=${fixtures.path}',
        '--blocklist=${fixtures.path}/blocklist_sample.txt',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, isNot(0));
      expect(result.stdout.toString(), contains('hit'));
    });

    test('report mode exits 0 even when hits exist', () {
      final result = Process.runSync('dart', [
        'run',
        'tool/check_no_pii.dart',
        '--mode=report',
        '--scope=fixture',
        '--root=${fixtures.path}',
        '--blocklist=${fixtures.path}/blocklist_sample.txt',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout.toString(), contains('hit'));
    });

    test('report mode on tracked tree is non-blocking without blocklist', () {
      final result = Process.runSync('dart', [
        'run',
        'tool/check_no_pii.dart',
        '--mode=report',
        '--scope=tracked',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });
  });

  group('committed selected AppConfig', () {
    test('selected.dart is synthetic-only and has no secret identifiers', () {
      final selected = File(
        '${repoRoot.path}/lib/core/config/generated/app_config.selected.dart',
      );
      final text = selected.readAsStringSync();
      expect(text, contains(kSyntheticOrigin));
      expect(text, contains("trustedHost = 'forge.example.test'"));
      final lower = text.toLowerCase();
      // Property names, not comments about secrets.
      expect(RegExp(r'\btoken\b').hasMatch(lower), isFalse);
      expect(RegExp(r'\bpassword\b').hasMatch(lower), isFalse);
      expect(RegExp(r'\bsecret\b').hasMatch(lower), isFalse);
    });
  });
}
