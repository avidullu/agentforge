import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';

void main() {
  final repoRoot = findRepoRoot();

  group('parseAndValidateBuildSafe', () {
    test('accepts the checked-in example config', () {
      final file = File(
        '${repoRoot.path}/config/agentforge.config.example.json',
      );
      final config = parseAndValidateBuildSafe(loadConfigJson(file));
      expect(config.origin, kSyntheticOrigin);
      expect(config.trustedHost, 'forge.example.test');
      expect(config.applicationId, 'com.example.agentforge');
      expect(config.gradleNamespace, 'dev.agentforge.app');
      expect(config.urlScheme, 'agentforge');
      expect(config.isSyntheticOrigin, isTrue);
    });

    test('rejects non-443 port', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': 'https://forge.example.test:8443'},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects path on origin', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': 'https://forge.example.test/forgejo'},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects forbidden secret property names', () {
      expect(
        () => loadConfigJson(
          _tempJson({
            'schemaVersion': 1,
            'forgejo': {'origin': kSyntheticOrigin},
            'app': {
              'applicationId': 'com.example.agentforge',
              'gradleNamespace': 'dev.agentforge.app',
              'urlScheme': 'agentforge',
            },
            'token': 'nope',
          }),
        ),
        throwsA(isA<ConfigValidationException>()),
      );
    });
  });

  group('validateRelease', () {
    test('fails closed on empty signing', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {'androidSha256Fingerprints': <String>[], 'appleTeamId': ''},
      });
      expect(
        () => validateRelease(config),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('accepts populated signing', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {
          'androidSha256Fingerprints': ['AA:BB:CC'],
          'appleTeamId': 'TEAMID12',
        },
      });
      expect(() => validateRelease(config), returnsNormally);
    });
  });

  group('renderSelectedDart', () {
    test('emits const AppConfig with synthetic origin', () {
      final config = parseAndValidateBuildSafe(
        loadConfigJson(
          File('${repoRoot.path}/config/agentforge.config.example.json'),
        ),
      );
      final out = renderSelectedDart(config);
      expect(out, contains("defaultBaseUrl = 'https://forge.example.test'"));
      expect(out, contains("trustedHost = 'forge.example.test'"));
      expect(RegExp(r'\btoken\b').hasMatch(out.toLowerCase()), isFalse);
      expect(RegExp(r'\bpassword\b').hasMatch(out.toLowerCase()), isFalse);
      expect(RegExp(r'\bsecret\b').hasMatch(out.toLowerCase()), isFalse);
    });
  });

  group('generate_config CLI', () {
    test('build-safe run exits 0 on example', () {
      final result = Process.runSync('dart', [
        'run',
        'tool/generate_config.dart',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final selected = File(
        '${repoRoot.path}/lib/core/config/generated/app_config.selected.dart',
      );
      expect(selected.readAsStringSync(), contains(kSyntheticOrigin));
    });

    test('--release fails closed without signing fingerprints', () {
      final result = Process.runSync('dart', [
        'run',
        'tool/generate_config.dart',
        '--release',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, isNot(0));
      expect(
        result.stderr.toString() + result.stdout.toString(),
        contains('release mode'),
      );
    });
  });
}

File _tempJson(Map<String, dynamic> map) {
  final f = File(
    '${Directory.systemTemp.path}/agentforge-config-test-${map.hashCode}.json',
  );
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
  return f;
}
