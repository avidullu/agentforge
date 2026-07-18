import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';
import 'hermetic_dart.dart';

/// Valid Android assetlinks SHA-256 fingerprint (32 colon-separated hex pairs).
const kValidFingerprint =
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';

const kValidTeamId = 'ABCD123456';

void main() {
  final repoRoot = findRepoRoot();
  final dartBin = hermeticDartExecutable();

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

    test('rejects unknown root properties', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': kSyntheticOrigin},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
          'extra': true,
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects non-string fingerprint entries', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': kSyntheticOrigin},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
          'signing': {
            'androidSha256Fingerprints': [123],
            'appleTeamId': kValidTeamId,
          },
        }),
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

    test('fails closed on malformed fingerprint', () {
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
          'appleTeamId': kValidTeamId,
        },
      });
      expect(
        () => validateRelease(config),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('fails closed on malformed team id', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {
          'androidSha256Fingerprints': [kValidFingerprint],
          'appleTeamId': 'TEAMID12',
        },
      });
      expect(
        () => validateRelease(config),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('accepts well-formed signing', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {
          'androidSha256Fingerprints': [kValidFingerprint],
          'appleTeamId': kValidTeamId,
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
      final result = Process.runSync(dartBin, [
        'run',
        'tool/generate_config.dart',
      ], workingDirectory: repoRoot.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final selected = File(
        '${repoRoot.path}/lib/core/config/generated/app_config.selected.dart',
      );
      expect(selected.readAsStringSync(), contains(kSyntheticOrigin));
      final log = result.stdout.toString();
      expect(log, isNot(contains(repoRoot.path)));
      expect(log, isNot(contains('origin=')));
    });

    test('--release fails closed without signing fingerprints', () {
      final result = Process.runSync(dartBin, [
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

    test(
      'explicit config with synthetic origin never rewrites tracked natives',
      () {
        final trackedProps = File(
          '${repoRoot.path}/agentforge-config.properties',
        );
        final trackedXc = File(
          '${repoRoot.path}/ios/Flutter/AgentForge.xcconfig',
        );
        final beforeProps = trackedProps.readAsStringSync();
        final beforeXc = trackedXc.readAsStringSync();

        final tmp = File(
          '${Directory.systemTemp.path}/agentforge-explicit-synthetic.json',
        );
        tmp.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'schemaVersion': 1,
            'forgejo': {'origin': kSyntheticOrigin},
            'app': {
              'applicationId': 'com.explicit.agentforge',
              'gradleNamespace': 'dev.agentforge.app',
              'urlScheme': 'agentforge',
            },
          }),
        );

        final result = Process.runSync(
          dartBin,
          ['run', 'tool/generate_config.dart'],
          workingDirectory: repoRoot.path,
          environment: {...Platform.environment, 'AGENTFORGE_CONFIG': tmp.path},
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(trackedProps.readAsStringSync(), beforeProps);
        expect(trackedXc.readAsStringSync(), beforeXc);
        expect(
          File(
            '${repoRoot.path}/agentforge-config.local.properties',
          ).existsSync(),
          isTrue,
        );
        final localXcText = File(
          '${repoRoot.path}/ios/Flutter/AgentForge.local.xcconfig',
        ).readAsStringSync();
        // No assignment — entitlement override deferred to AF-014.
        expect(localXcText.contains('CODE_SIGN_ENTITLEMENTS='), isFalse);
        expect(
          File(
            '${repoRoot.path}/ios/Runner/Runner.entitlements.local',
          ).existsSync(),
          isFalse,
        );

        // Cleanup local gens and restore selected synthetic.
        File(
          '${repoRoot.path}/agentforge-config.local.properties',
        ).deleteSync();
        File(
          '${repoRoot.path}/ios/Flutter/AgentForge.local.xcconfig',
        ).deleteSync();
        Process.runSync(dartBin, [
          'run',
          'tool/generate_config.dart',
        ], workingDirectory: repoRoot.path);
        if (tmp.existsSync()) tmp.deleteSync();
      },
    );
  });
}

File _tempJson(Map<String, dynamic> map) {
  final f = File(
    '${Directory.systemTemp.path}/agentforge-config-test-${map.hashCode}.json',
  );
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
  return f;
}
