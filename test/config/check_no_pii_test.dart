import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';
import '../../tool/pii_guard.dart';
import 'hermetic_dart.dart';

void main() {
  final repoRoot = findRepoRoot();
  final fixtures = Directory('${repoRoot.path}/test/config/fixtures');
  final dartBin = hermeticDartExecutable();

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
      // Never embed matched values in hit strings.
      expect(hits.first.toString(), isNot(contains('pii-host')));
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

    test('rejects suffix-host bypass of synthetic origin', () {
      final f = File('${Directory.systemTemp.path}/struct-suffix.txt')
        ..writeAsStringSync('u=https://forge.example.test.evil.invalid/x\n');
      addTearDown(() {
        if (f.existsSync()) f.deleteSync();
      });
      final hits = scanStructuralHttps(files: [f], repoRoot: '');
      expect(hits, isNotEmpty);
    });

    test('rejects userinfo, path, query, fragment, alt port', () {
      final f = File('${Directory.systemTemp.path}/struct-adversarial.txt')
        ..writeAsStringSync(
          'a=https://forge.example.test@evil.invalid\n'
          'b=https://forge.example.test/path\n'
          'c=https://forge.example.test?q=1\n'
          'd=https://forge.example.test#frag\n'
          'e=https://forge.example.test:8443\n',
        );
      addTearDown(() {
        if (f.existsSync()) f.deleteSync();
      });
      final hits = scanStructuralHttps(files: [f], repoRoot: '');
      expect(hits.length, greaterThanOrEqualTo(5));
    });

    test('allows exact synthetic origin only', () {
      final f = File('${Directory.systemTemp.path}/struct-exact.txt')
        ..writeAsStringSync('u=https://forge.example.test\n');
      addTearDown(() {
        if (f.existsSync()) f.deleteSync();
      });
      final hits = scanStructuralHttps(files: [f], repoRoot: '');
      expect(hits, isEmpty);
    });
  });

  group('check_no_pii CLI', () {
    test('blocklist mode fails closed on dirty fixture root', () {
      final result = Process.runSync(dartBin, [
        'run',
        'tool/check_no_pii.dart',
        '--mode=blocklist',
        '--scope=fixture',
        '--root=${fixtures.path}',
        '--blocklist=${fixtures.path}/blocklist_sample.txt',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, isNot(0));
      expect(result.stdout.toString(), contains('hit'));
      // Matched blocklist values must not appear in logs.
      expect(
        result.stdout.toString(),
        isNot(contains('pii-host.example.invalid')),
      );
    });

    test('report mode exits 0 even when hits exist', () {
      final result = Process.runSync(dartBin, [
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
      final result = Process.runSync(dartBin, [
        'run',
        'tool/check_no_pii.dart',
        '--mode=report',
        '--scope=tracked',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    });

    test('unexpected failures print stable category without stacks/paths', () {
      final result = Process.runSync(dartBin, [
        'run',
        'tool/check_no_pii.dart',
        '--mode=blocklist',
        '--scope=fixture',
        '--root=${fixtures.path}',
        '--blocklist=/definitely/missing/blocklist-file.txt',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, isNot(0));
      final err = result.stderr.toString();
      expect(
        err.contains('check_no_pii failed') || err.contains('missing'),
        isTrue,
      );
      expect(err, isNot(contains('#0 '))); // no stack frames
      expect(err, isNot(contains(repoRoot.path)));
    });
  });

  group('hermeticDartExecutable', () {
    test('resolves an existing dart CLI', () {
      final path = hermeticDartExecutable();
      expect(File(path).existsSync(), isTrue);
      // Use URI segments so Windows paths with mixed/forward separators work.
      final base = File(path).uri.pathSegments.isNotEmpty
          ? File(path).uri.pathSegments.last.toLowerCase()
          : '';
      expect(base == 'dart' || base == 'dart.exe', isTrue);
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
      expect(RegExp(r'\btoken\b').hasMatch(lower), isFalse);
      expect(RegExp(r'\bpassword\b').hasMatch(lower), isFalse);
      expect(RegExp(r'\bsecret\b').hasMatch(lower), isFalse);
    });
  });
}
