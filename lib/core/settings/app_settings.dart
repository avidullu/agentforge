/// Load-time binding of the PAT to the configured Forgejo origin (AF-010).
enum CredentialLoadState {
  /// No token stored for the current origin.
  unbound,

  /// Token present for the current origin only.
  bound,

  /// Legacy unscoped `forgejo_token` was deleted; user must re-enter.
  legacyClearedRequiresReentry,

  /// Token was requested for an origin that has no stored credentials
  /// (e.g. origin changed after a bound session).
  originMismatch,
}

/// User-configurable connection settings for the Forgejo instance.
class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.token,
    this.credentialState = CredentialLoadState.unbound,
  });

  /// e.g. `https://forge.example.test` (no trailing slash).
  final String baseUrl;

  /// Personal access token (empty if not configured for [baseUrl]).
  final String token;

  /// How the [token] relates to [baseUrl] after load/migration.
  final CredentialLoadState credentialState;

  static const defaultBaseUrl = 'https://avis-pbook.tail651ec3.ts.net';
  static const trustedHost = 'avis-pbook.tail651ec3.ts.net';

  bool get isConfigured => baseUrl.trim().isNotEmpty && token.trim().isNotEmpty;

  /// UI should prompt for a PAT (legacy wipe or origin without bound token).
  bool get needsCredentialReentry =>
      credentialState == CredentialLoadState.legacyClearedRequiresReentry ||
      credentialState == CredentialLoadState.originMismatch;

  AppSettings copyWith({
    String? baseUrl,
    String? token,
    CredentialLoadState? credentialState,
  }) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      credentialState: credentialState ?? this.credentialState,
    );
  }

  static String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Normalized origin for credential scoping.
  ///
  /// Default HTTPS port 443 is omitted from the key. Non-443 ports are kept
  /// so credentials never collide if validation is later relaxed (AF-011+).
  static String normalizeOrigin(String raw) {
    final normalized = normalizeBaseUrl(raw);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return normalized;
    }
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (uri.hasPort &&
        !((scheme == 'https' && uri.port == 443) ||
            (scheme == 'http' && uri.port == 80))) {
      return '$scheme://$host:${uri.port}';
    }
    return '$scheme://$host';
  }

  static String? baseUrlValidationError(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid absolute URL';
    }
    if (uri.scheme != 'https') return 'Forgejo must use HTTPS';
    if (uri.host.toLowerCase() != trustedHost || uri.port != 443) {
      return 'This build trusts only $defaultBaseUrl';
    }
    if (uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return 'Use only the Forgejo origin, without credentials or a path';
    }
    return null;
  }
}
