import 'dart:convert';
import 'dart:io';

/// Supported schema version for AgentForge config.
const int kSupportedSchemaVersion = 1;

/// Exact synthetic origin committed in the example config and selected Dart.
const String kSyntheticOrigin = 'https://forge.example.test';

/// Forbidden property name tokens (non-secret guarantee).
const List<String> kForbiddenSecretPropertyNames = [
  'token',
  'secret',
  'password',
];

/// Parsed, validated AgentForge configuration.
class AgentForgeConfig {
  AgentForgeConfig({
    required this.schemaVersion,
    required this.origin,
    required this.applicationId,
    required this.gradleNamespace,
    required this.urlScheme,
    required this.androidSha256Fingerprints,
    required this.appleTeamId,
  });

  final int schemaVersion;
  final String origin;
  final String applicationId;
  final String gradleNamespace;
  final String urlScheme;
  final List<String> androidSha256Fingerprints;
  final String appleTeamId;

  String get trustedHost => Uri.parse(origin).host;

  bool get isSyntheticOrigin => origin == kSyntheticOrigin;
}

class ConfigValidationException implements Exception {
  ConfigValidationException(this.message);
  final String message;

  @override
  String toString() => 'ConfigValidationException: $message';
}

/// Locate the repository root (directory containing `pubspec.yaml`).
Directory findRepoRoot([Directory? start]) {
  var dir = start ?? Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find repo root (pubspec.yaml) from $start');
    }
    dir = parent;
  }
}

/// Resolve which JSON config file to load.
///
/// Order: `AGENTFORGE_CONFIG` env → `config/agentforge.config.json` → example.
File resolveConfigFile(Directory repoRoot) {
  final fromEnv = Platform.environment['AGENTFORGE_CONFIG'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) {
    final f = File(fromEnv.trim());
    if (!f.existsSync()) {
      throw ConfigValidationException(
        'AGENTFORGE_CONFIG points to missing file: ${f.path}',
      );
    }
    return f;
  }
  final real = File('${repoRoot.path}/config/agentforge.config.json');
  if (real.existsSync()) return real;
  return File('${repoRoot.path}/config/agentforge.config.example.json');
}

Map<String, dynamic> loadConfigJson(File file) {
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw ConfigValidationException('${file.path}: root must be a JSON object');
  }
  _assertNoSecretPropertyNames(decoded, path: '');
  return decoded;
}

void _assertNoSecretPropertyNames(Object? node, {required String path}) {
  if (node is Map) {
    for (final entry in node.entries) {
      final key = entry.key.toString();
      final lower = key.toLowerCase();
      for (final banned in kForbiddenSecretPropertyNames) {
        if (lower == banned || lower.endsWith('_$banned')) {
          throw ConfigValidationException(
            'Forbidden property name "$key" at $path$key '
            '(schema forbids token/secret/password)',
          );
        }
      }
      _assertNoSecretPropertyNames(
        entry.value,
        path: path.isEmpty ? '$key.' : '$path$key.',
      );
    }
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      _assertNoSecretPropertyNames(node[i], path: '$path[$i].');
    }
  }
}

/// Build-safe validation (always).
AgentForgeConfig parseAndValidateBuildSafe(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int || schemaVersion != kSupportedSchemaVersion) {
    throw ConfigValidationException(
      'schemaVersion must be exactly $kSupportedSchemaVersion',
    );
  }

  final forgejo = json['forgejo'];
  if (forgejo is! Map) {
    throw ConfigValidationException('forgejo must be an object');
  }
  final originRaw = forgejo['origin'];
  if (originRaw is! String || originRaw.trim().isEmpty) {
    throw ConfigValidationException('forgejo.origin is required');
  }
  final origin = _normalizeAndValidateOrigin(originRaw);

  final app = json['app'];
  if (app is! Map) {
    throw ConfigValidationException('app must be an object');
  }
  final applicationId = _requireNonEmptyString(app, 'applicationId');
  final gradleNamespace = _requireNonEmptyString(app, 'gradleNamespace');
  final urlScheme = _requireNonEmptyString(app, 'urlScheme');
  _validateApplicationId(applicationId, 'app.applicationId');
  _validateApplicationId(gradleNamespace, 'app.gradleNamespace');
  _validateUrlScheme(urlScheme);

  final signing = json['signing'];
  var fingerprints = <String>[];
  var appleTeamId = '';
  if (signing != null) {
    if (signing is! Map) {
      throw ConfigValidationException('signing must be an object when present');
    }
    final fp = signing['androidSha256Fingerprints'];
    if (fp != null) {
      if (fp is! List) {
        throw ConfigValidationException(
          'signing.androidSha256Fingerprints must be an array',
        );
      }
      fingerprints = fp.map((e) => e.toString()).toList();
    }
    final team = signing['appleTeamId'];
    if (team != null) appleTeamId = team.toString();
  }

  return AgentForgeConfig(
    schemaVersion: schemaVersion,
    origin: origin,
    applicationId: applicationId,
    gradleNamespace: gradleNamespace,
    urlScheme: urlScheme,
    androidSha256Fingerprints: fingerprints,
    appleTeamId: appleTeamId,
  );
}

/// Release/deployment validation — fails closed on empty signing.
void validateRelease(AgentForgeConfig config) {
  if (config.androidSha256Fingerprints.isEmpty ||
      config.androidSha256Fingerprints.any((e) => e.trim().isEmpty)) {
    throw ConfigValidationException(
      'release mode requires non-empty signing.androidSha256Fingerprints',
    );
  }
  if (config.appleTeamId.trim().isEmpty) {
    throw ConfigValidationException(
      'release mode requires non-empty signing.appleTeamId',
    );
  }
}

String _normalizeAndValidateOrigin(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ConfigValidationException('forgejo.origin must be an absolute URL');
  }
  if (uri.scheme != 'https') {
    throw ConfigValidationException('forgejo.origin must use HTTPS');
  }
  // Uri.parse omits default ports; explicit non-443 must fail.
  if (uri.hasPort && uri.port != 443) {
    throw ConfigValidationException(
      'forgejo.origin must use port 443 only (got ${uri.port})',
    );
  }
  if (uri.userInfo.isNotEmpty) {
    throw ConfigValidationException('forgejo.origin must not include userinfo');
  }
  if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
    throw ConfigValidationException(
      'forgejo.origin must not include query or fragment',
    );
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    throw ConfigValidationException('forgejo.origin must not include a path');
  }
  return 'https://${uri.host}';
}

String _requireNonEmptyString(Map app, String key) {
  final v = app[key];
  if (v is! String || v.trim().isEmpty) {
    throw ConfigValidationException('app.$key must be a non-empty string');
  }
  return v.trim();
}

void _validateApplicationId(String value, String field) {
  final re = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$');
  if (!re.hasMatch(value)) {
    throw ConfigValidationException('$field is not a well-formed package id');
  }
}

void _validateUrlScheme(String value) {
  final re = RegExp(r'^[a-z][a-z0-9+.-]*$');
  if (!re.hasMatch(value)) {
    throw ConfigValidationException(
      'app.urlScheme is not a well-formed scheme',
    );
  }
}

String renderSelectedDart(AgentForgeConfig config) {
  return '''
// GENERATED FILE — do not edit by hand.
// Source: agentforge config (see tool/generate_config.dart).
// Regenerate: dart run tool/generate_config.dart
// Only the synthetic origin may be committed to git.

/// Build-time AgentForge configuration (const; never holds credentials).
class AppConfig {
  const AppConfig._();

  /// Normalized HTTPS origin (no trailing slash).
  static const String defaultBaseUrl = '${config.origin}';

  /// Host derived from [defaultBaseUrl].
  static const String trustedHost = '${config.trustedHost}';

  /// Android application id / iOS bundle id shape (D1 allow-listed in real builds).
  static const String applicationId = '${config.applicationId}';

  /// Android Gradle namespace (D2 neutral path target).
  static const String gradleNamespace = '${config.gradleNamespace}';

  /// Custom URL scheme for deep links.
  static const String urlScheme = '${config.urlScheme}';
}
''';
}

String renderProperties(AgentForgeConfig config) {
  return '''
# AgentForge config properties (generated).
# Tracked synthetic defaults use agentforge-config.properties.
# Real overrides belong only in agentforge-config.local.properties (gitignored).
forgejo.origin=${config.origin}
forgejo.host=${config.trustedHost}
app.applicationId=${config.applicationId}
app.gradleNamespace=${config.gradleNamespace}
app.urlScheme=${config.urlScheme}
''';
}

String renderXcconfig(AgentForgeConfig config) {
  return '''
// AgentForge xcconfig (generated).
// Tracked synthetic defaults use AgentForge.xcconfig.
// Real overrides belong only in AgentForge.local.xcconfig (gitignored).
// Do not set PRODUCT_BUNDLE_IDENTIFIER here — identity stays target-level (D1).
AGENTFORGE_FORGEJO_HOST=${config.trustedHost}
AGENTFORGE_URL_SCHEME=${config.urlScheme}
''';
}

String renderEntitlementsLocal(AgentForgeConfig config) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:${config.trustedHost}?mode=developer</string>
	</array>
</dict>
</plist>
''';
}

String renderLocalXcconfigWithEntitlements() {
  return '''
// Generated local overrides — do not commit.
CODE_SIGN_ENTITLEMENTS=Runner/Runner.entitlements.local
''';
}
