/// User-configurable connection settings for the Forgejo instance.
class AppSettings {
  const AppSettings({required this.baseUrl, required this.token});

  /// e.g. `https://avis-pbook.tail651ec3.ts.net` (no trailing slash).
  final String baseUrl;

  /// Personal access token (empty if not configured).
  final String token;

  static const defaultBaseUrl = 'https://avis-pbook.tail651ec3.ts.net';
  static const trustedHost = 'avis-pbook.tail651ec3.ts.net';

  bool get isConfigured => baseUrl.trim().isNotEmpty && token.trim().isNotEmpty;

  AppSettings copyWith({String? baseUrl, String? token}) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
    );
  }

  static String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
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
