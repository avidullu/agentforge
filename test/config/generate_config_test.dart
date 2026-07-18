import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';
import '../../tool/generate_config.dart';
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

  group('generateConfigOutputs (isolated temp root only)', () {
    late Directory fixtureRoot;

    setUp(() {
      fixtureRoot = Directory.systemTemp.createTempSync('af-gen-root-');
      _materializeIsolatedRoot(fixtureRoot, repoRoot);
    });

    tearDown(() {
      if (fixtureRoot.existsSync()) {
        fixtureRoot.deleteSync(recursive: true);
      }
    });

    test('writes synthetic selected + natives with relative log labels only', () {
      final logs = <String>[];
      final example = File(
        '${fixtureRoot.path}/config/agentforge.config.example.json',
      );
      generateConfigOutputs(
        repoRoot: fixtureRoot,
        configFile: example,
        release: false,
        log: logs.add,
      );
      final joined = logs.join('\n');
      expect(joined, isNot(contains(fixtureRoot.path)));
      expect(joined, isNot(contains(repoRoot.path)));
      expect(joined, isNot(contains('origin=')));
      expect(
        File(
          '${fixtureRoot.path}/lib/core/config/generated/app_config.selected.dart',
        ).readAsStringSync(),
        contains(kSyntheticOrigin),
      );
    });

    test('release validation fails closed before writing when signing empty', () {
      final example = File(
        '${fixtureRoot.path}/config/agentforge.config.example.json',
      );
      final selected = File(
        '${fixtureRoot.path}/lib/core/config/generated/app_config.selected.dart',
      );
      final before = selected.readAsBytesSync();
      expect(
        () => generateConfigOutputs(
          repoRoot: fixtureRoot,
          configFile: example,
          release: true,
        ),
        throwsA(isA<ConfigValidationException>()),
      );
      expect(selected.readAsBytesSync(), before);
    });

    test(
      'explicit config with synthetic origin never rewrites tracked natives',
      () {
        final trackedProps = File(
          '${fixtureRoot.path}/agentforge-config.properties',
        );
        final trackedXc = File(
          '${fixtureRoot.path}/ios/Flutter/AgentForge.xcconfig',
        );
        final beforeProps = trackedProps.readAsBytesSync();
        final beforeXc = trackedXc.readAsBytesSync();

        final explicit = File('${fixtureRoot.path}/explicit.json')
          ..writeAsStringSync(
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

        generateConfigOutputs(
          repoRoot: fixtureRoot,
          configFile: explicit,
          release: false,
        );
        expect(trackedProps.readAsBytesSync(), beforeProps);
        expect(trackedXc.readAsBytesSync(), beforeXc);
        expect(
          File(
            '${fixtureRoot.path}/agentforge-config.local.properties',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('default generation is byte-idempotent on fixture', () {
      final example = File(
        '${fixtureRoot.path}/config/agentforge.config.example.json',
      );
      generateConfigOutputs(
        repoRoot: fixtureRoot,
        configFile: example,
        release: false,
      );
      final props = File('${fixtureRoot.path}/agentforge-config.properties');
      final xc = File('${fixtureRoot.path}/ios/Flutter/AgentForge.xcconfig');
      final selected = File(
        '${fixtureRoot.path}/lib/core/config/generated/app_config.selected.dart',
      );
      // Snapshot AFTER first generation (order-independent vs prior tests).
      final bProps = props.readAsBytesSync();
      final bXc = xc.readAsBytesSync();
      final bSelected = selected.readAsBytesSync();

      generateConfigOutputs(
        repoRoot: fixtureRoot,
        configFile: example,
        release: false,
      );
      expect(props.readAsBytesSync(), bProps);
      expect(xc.readAsBytesSync(), bXc);
      expect(selected.readAsBytesSync(), bSelected);
    });
  });

  group('generate_config CLI (no tracked mutation on failure paths)', () {
    test('--release fails closed without writing when signing empty', () {
      final env = Map<String, String>.from(Platform.environment)
        ..remove('AGENTFORGE_CONFIG');
      final result = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart', '--release'],
        workingDirectory: repoRoot.path,
        environment: env,
      );
      expect(result.exitCode, isNot(0));
      final combined = result.stderr.toString() + result.stdout.toString();
      expect(combined, contains('release mode'));
      expect(combined, isNot(contains(repoRoot.path)));
    });

    test('missing AGENTFORGE_CONFIG path does not leak absolute path', () {
      final env = Map<String, String>.from(Platform.environment)
        ..['AGENTFORGE_CONFIG'] = '/no/such/agentforge-config.json';
      final result = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart'],
        workingDirectory: repoRoot.path,
        environment: env,
      );
      expect(result.exitCode, isNot(0));
      final err = result.stderr.toString();
      expect(err, contains('missing file'));
      expect(err, isNot(contains('/no/such')));
    });
  });
}

void _materializeIsolatedRoot(Directory fixtureRoot, Directory realRepo) {
  for (final rel in [
    'config/agentforge.config.example.json',
    'config/agentforge.config.schema.json',
    'lib/core/config/generated/app_config.selected.dart',
    'agentforge-config.properties',
    'ios/Flutter/AgentForge.xcconfig',
  ]) {
    final from = File('${realRepo.path}/$rel');
    final to = File('${fixtureRoot.path}/$rel');
    to.parent.createSync(recursive: true);
    to.writeAsBytesSync(from.readAsBytesSync());
  }
  Directory('${fixtureRoot.path}/ios/Runner').createSync(recursive: true);
}

File _tempJson(Map<String, dynamic> map) {
  final f = File(
    '${Directory.systemTemp.path}/agentforge-config-test-${map.hashCode}.json',
  );
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
  addTearDown(() {
    if (f.existsSync()) f.deleteSync();
  });
  return f;
}
