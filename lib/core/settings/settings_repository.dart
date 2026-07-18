import 'app_settings.dart';
import 'secure_store.dart';

/// Persists Forgejo connection settings with **origin-bound** PATs (AF-010).
///
/// Storage layout:
/// - `forgejo_base_url` — last configured origin (normalized)
/// - `forgejo_token::<normalizedOrigin>` — PAT scoped to that origin only
/// - legacy `forgejo_token` — deleted on first load (never auto-bound)
class SettingsRepository {
  SettingsRepository({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureKeyValueStore();

  static const kBaseUrl = 'forgejo_base_url';
  static const kLegacyToken = 'forgejo_token';
  static const kTokenKeyPrefix = 'forgejo_token::';

  final SecureKeyValueStore _store;

  /// Storage key for a PAT bound to [normalizedOrigin].
  static String tokenKeyForOrigin(String normalizedOrigin) =>
      '$kTokenKeyPrefix$normalizedOrigin';

  Future<AppSettings> load() async {
    final legacyCleared = await _deleteLegacyTokenIfPresent();

    final rawBase = await _store.read(kBaseUrl);
    final baseUrl = (rawBase == null || rawBase.isEmpty)
        ? AppSettings.defaultBaseUrl
        : AppSettings.normalizeBaseUrl(rawBase);
    final origin = AppSettings.normalizeOrigin(baseUrl);

    final token = (await _store.read(tokenKeyForOrigin(origin))) ?? '';

    final CredentialLoadState state;
    if (token.isNotEmpty) {
      state = CredentialLoadState.bound;
    } else if (legacyCleared) {
      // Legacy unscoped PAT cannot be attributed to an origin — re-enter.
      state = CredentialLoadState.legacyClearedRequiresReentry;
    } else {
      state = CredentialLoadState.unbound;
    }

    return AppSettings(baseUrl: baseUrl, token: token, credentialState: state);
  }

  /// Load settings for an explicit [origin] without writing base URL.
  ///
  /// Never returns a PAT stored for a different host. When [origin] has no
  /// bound token but other origins do, [CredentialLoadState.originMismatch]
  /// surfaces the re-entry prompt.
  Future<AppSettings> loadForOrigin(String origin) async {
    final legacyCleared = await _deleteLegacyTokenIfPresent();
    final normalized = AppSettings.normalizeOrigin(origin);
    final token = (await _store.read(tokenKeyForOrigin(normalized))) ?? '';

    if (token.isNotEmpty) {
      return AppSettings(
        baseUrl: normalized,
        token: token,
        credentialState: CredentialLoadState.bound,
      );
    }
    if (legacyCleared) {
      return AppSettings(
        baseUrl: normalized,
        token: '',
        credentialState: CredentialLoadState.legacyClearedRequiresReentry,
      );
    }
    final otherBound = await _hasAnyScopedToken(exceptOrigin: normalized);
    return AppSettings(
      baseUrl: normalized,
      token: '',
      credentialState: otherBound
          ? CredentialLoadState.originMismatch
          : CredentialLoadState.unbound,
    );
  }

  Future<bool> _hasAnyScopedToken({required String exceptOrigin}) async {
    final exceptKey = tokenKeyForOrigin(exceptOrigin);
    for (final key in await _store.keys()) {
      if (!key.startsWith(kTokenKeyPrefix) || key == exceptKey) continue;
      final value = await _store.read(key);
      if (value != null && value.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> save(AppSettings settings) async {
    final origin = AppSettings.normalizeOrigin(settings.baseUrl);
    await _store.write(kBaseUrl, origin);

    final token = settings.token.trim();
    final key = tokenKeyForOrigin(origin);
    if (token.isEmpty) {
      await _store.delete(key);
    } else {
      await _store.write(key, token);
    }
    // Never re-create the legacy unscoped key.
    await _store.delete(kLegacyToken);
  }

  /// Clears the PAT for [origin] (defaults to stored base URL).
  Future<void> clearToken({String? origin}) async {
    final rawBase = origin ?? await _store.read(kBaseUrl);
    final resolved = (rawBase == null || rawBase.isEmpty)
        ? AppSettings.defaultBaseUrl
        : rawBase;
    await _store.delete(
      tokenKeyForOrigin(AppSettings.normalizeOrigin(resolved)),
    );
    await _store.delete(kLegacyToken);
  }

  /// Returns true if a legacy unscoped key was present and deleted.
  Future<bool> _deleteLegacyTokenIfPresent() async {
    final legacy = await _store.read(kLegacyToken);
    if (legacy == null) return false;
    await _store.delete(kLegacyToken);
    return true;
  }
}
