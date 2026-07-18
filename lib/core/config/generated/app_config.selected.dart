// GENERATED FILE — do not edit by hand.
// Source: agentforge config (see tool/generate_config.dart).
// Regenerate: dart run tool/generate_config.dart
// Only the synthetic origin may be committed to git.

/// Build-time AgentForge configuration (const; never holds credentials).
class AppConfig {
  const AppConfig._();

  /// Normalized HTTPS origin (no trailing slash).
  static const String defaultBaseUrl = 'https://forge.example.test';

  /// Host derived from [defaultBaseUrl].
  static const String trustedHost = 'forge.example.test';

  /// Android application id / iOS bundle id shape (D1 allow-listed in real builds).
  static const String applicationId = 'com.example.agentforge';

  /// Android Gradle namespace (D2 neutral path target).
  static const String gradleNamespace = 'dev.agentforge.app';

  /// Custom URL scheme for deep links.
  static const String urlScheme = 'agentforge';
}
