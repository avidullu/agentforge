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

const Set<String> kRootKeys = {'schemaVersion', 'forgejo', 'app', 'signing'};
const Set<String> kForgejoKeys = {'origin'};
const Set<String> kAppKeys = {'applicationId', 'gradleNamespace', 'urlScheme'};
const Set<String> kSigningKeys = {'androidSha256Fingerprints', 'appleTeamId'};

/// Android assetlinks SHA-256 fingerprint: 32 colon-separated hex pairs.
final RegExp kAndroidSha256FingerprintRe = RegExp(
  r'^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$',
);

/// Apple Team ID: 10 alphanumeric characters.
final RegExp kAppleTeamIdRe = RegExp(r'^[A-Z0-9]{10}$');

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
///
/// Walks ancestors from [start] (default: cwd). No environment override —
/// tests inject an isolated root via [generateConfigOutputs] APIs instead.
Directory findRepoRoot([Directory? start]) {
  var dir = start ?? Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find repo root (pubspec.yaml)');
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
        'AGENTFORGE_CONFIG points to a missing file',
      );
    }
    return f;
  }
  final real = File('${repoRoot.path}/config/agentforge.config.json');
  if (real.existsSync()) return real;
  return File('${repoRoot.path}/config/agentforge.config.example.json');
}

/// True only when the resolved source is the checked-in example file.
///
/// Source path — not origin value — decides whether native writes may refresh
/// tracked synthetics (review finding: real config with synthetic origin).
bool isExampleConfigSource(File configFile, Directory repoRoot) {
  final example = File(
    '${repoRoot.path}/config/agentforge.config.example.json',
  );
  return _sameFile(configFile, example);
}

bool isRealConfigSource(File configFile, Directory repoRoot) {
  return !isExampleConfigSource(configFile, repoRoot);
}

bool _sameFile(File a, File b) {
  return a.absolute.path == b.absolute.path;
}

/// Repo-relative path label for logs (never absolute workspace paths).
String repoRelativeLabel(Directory repoRoot, String absolutePath) {
  final root = repoRoot.absolute.path;
  final path = File(absolutePath).absolute.path;
  final prefix = root.endsWith(Platform.pathSeparator)
      ? root
      : '$root${Platform.pathSeparator}';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length).replaceAll('\\', '/');
  }
  return path.split(Platform.pathSeparator).last;
}

Map<String, dynamic> loadConfigJson(File file) {
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw ConfigValidationException('config root must be a JSON object');
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

void _rejectUnknownKeys(Map map, Set<String> allowed, String path) {
  for (final key in map.keys) {
    final k = key.toString();
    if (!allowed.contains(k)) {
      throw ConfigValidationException(
        'unknown property "$k" at $path (additionalProperties: false)',
      );
    }
  }
}

/// Build-safe validation (always).
AgentForgeConfig parseAndValidateBuildSafe(Map<String, dynamic> json) {
  _rejectUnknownKeys(json, kRootKeys, 'root');

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
  _rejectUnknownKeys(forgejo, kForgejoKeys, 'forgejo');
  final originRaw = forgejo['origin'];
  if (originRaw is! String || originRaw.trim().isEmpty) {
    throw ConfigValidationException('forgejo.origin is required');
  }
  final origin = _normalizeAndValidateOrigin(originRaw);

  final app = json['app'];
  if (app is! Map) {
    throw ConfigValidationException('app must be an object');
  }
  _rejectUnknownKeys(app, kAppKeys, 'app');
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
    _rejectUnknownKeys(signing, kSigningKeys, 'signing');
    final fp = signing['androidSha256Fingerprints'];
    if (fp != null) {
      if (fp is! List) {
        throw ConfigValidationException(
          'signing.androidSha256Fingerprints must be an array',
        );
      }
      for (final e in fp) {
        if (e is! String) {
          throw ConfigValidationException(
            'signing.androidSha256Fingerprints entries must be strings',
          );
        }
        fingerprints.add(e);
      }
    }
    final team = signing['appleTeamId'];
    if (team != null) {
      if (team is! String) {
        throw ConfigValidationException('signing.appleTeamId must be a string');
      }
      appleTeamId = team;
    }
  }

  // Reject placeholder-looking values in required app fields.
  for (final value in [origin, applicationId, gradleNamespace, urlScheme]) {
    if (value.contains('<') || value.contains('>')) {
      throw ConfigValidationException(
        'unresolved placeholder remaining in config value',
      );
    }
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

/// Release/deployment validation — fails closed on empty/malformed signing.
void validateRelease(AgentForgeConfig config) {
  if (config.androidSha256Fingerprints.isEmpty) {
    throw ConfigValidationException(
      'release mode requires non-empty signing.androidSha256Fingerprints',
    );
  }
  for (final fp in config.androidSha256Fingerprints) {
    if (!kAndroidSha256FingerprintRe.hasMatch(fp.trim())) {
      throw ConfigValidationException(
        'release mode requires valid SHA-256 fingerprint shape '
        '(32 colon-separated hex pairs), got malformed entry',
      );
    }
  }
  final team = config.appleTeamId.trim();
  if (team.isEmpty || !kAppleTeamIdRe.hasMatch(team)) {
    throw ConfigValidationException(
      'release mode requires signing.appleTeamId as 10 alphanumeric chars',
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
// Entitlement override path deferred to AF-014 (not emitted in S1).
AGENTFORGE_FORGEJO_HOST=${config.trustedHost}
AGENTFORGE_URL_SCHEME=${config.urlScheme}
''';
}
