import 'dart:convert';

import 'app_settings.dart';
import 'secure_store.dart';

/// Persists Forgejo connection settings with **origin-bound** PATs (AF-010).
///
/// Storage layout:
/// - `forgejo_base_url` — last configured origin (normalized)
/// - `forgejo_token::<normalizedOrigin>` — PAT scoped to that origin only
/// - `forgejo_bound_origins` — JSON array of origins that have a non-empty PAT
///   (production-safe index; Flutter secure storage cannot enumerate keys)
/// - legacy `forgejo_token` — deleted on first load (never auto-bound)
class SettingsRepository {
  SettingsRepository({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureKeyValueStore();

  static const kBaseUrl = 'forgejo_base_url';
  static const kLegacyToken = 'forgejo_token';
  static const kTokenKeyPrefix = 'forgejo_token::';
  static const kBoundOriginsIndex = 'forgejo_bound_origins';

  final SecureKeyValueStore _store;

  /// Storage key for a PAT bound to [normalizedOrigin].
  static String tokenKeyForOrigin(String normalizedOrigin) =>
      '$kTokenKeyPrefix$normalizedOrigin';

  /// Load settings for the active Forgejo origin.
  ///
  /// When [currentOrigin] is set, token resolution uses that origin only
  /// (docs/11 §5.5 `load(currentOrigin)`). Otherwise uses the persisted
  /// `forgejo_base_url`, falling back to [AppSettings.defaultBaseUrl].
  ///
  /// Never returns a PAT stored under a different origin. Production mismatch
  /// detection uses [kBoundOriginsIndex] because Flutter secure storage cannot
  /// enumerate keys.
  Future<AppSettings> load({String? currentOrigin}) async {
    final legacyCleared = await _deleteLegacyTokenIfPresent();

    final String baseUrl;
    final String origin;
    if (currentOrigin != null && currentOrigin.trim().isNotEmpty) {
      baseUrl = AppSettings.normalizeBaseUrl(currentOrigin);
      origin = AppSettings.normalizeOrigin(currentOrigin);
    } else {
      final rawBase = await _store.read(kBaseUrl);
      baseUrl = (rawBase == null || rawBase.isEmpty)
          ? AppSettings.defaultBaseUrl
          : AppSettings.normalizeBaseUrl(rawBase);
      origin = AppSettings.normalizeOrigin(baseUrl);
    }

    return _loadForNormalizedOrigin(
      baseUrl: baseUrl,
      origin: origin,
      legacyCleared: legacyCleared,
    );
  }

  /// Load settings for an explicit [origin] without writing base URL.
  ///
  /// Used by the settings UI when the Instance URL field changes so the form
  /// never carries a PAT across hosts and can surface
  /// [CredentialLoadState.originMismatch] in production.
  Future<AppSettings> loadForOrigin(String origin) =>
      load(currentOrigin: origin);

  Future<AppSettings> _loadForNormalizedOrigin({
    required String baseUrl,
    required String origin,
    required bool legacyCleared,
  }) async {
    final token = (await _store.read(tokenKeyForOrigin(origin))) ?? '';

    final CredentialLoadState state;
    if (token.isNotEmpty) {
      state = CredentialLoadState.bound;
    } else if (legacyCleared) {
      state = CredentialLoadState.legacyClearedRequiresReentry;
    } else if (await _hasAnyScopedToken(exceptOrigin: origin)) {
      state = CredentialLoadState.originMismatch;
    } else {
      state = CredentialLoadState.unbound;
    }

    return AppSettings(baseUrl: baseUrl, token: token, credentialState: state);
  }

  Future<bool> _hasAnyScopedToken({required String exceptOrigin}) async {
    final exceptKey = tokenKeyForOrigin(exceptOrigin);

    // Prefer persisted index (works with Flutter secure storage).
    for (final origin in await _readBoundOrigins()) {
      if (origin == exceptOrigin) continue;
      final value = await _store.read(tokenKeyForOrigin(origin));
      if (value != null && value.isNotEmpty) return true;
    }

    // Fallback for stores that can enumerate keys (in-memory tests).
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
      await _removeBoundOrigin(origin);
    } else {
      await _store.write(key, token);
      await _addBoundOrigin(origin);
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
    final normalized = AppSettings.normalizeOrigin(resolved);
    await _store.delete(tokenKeyForOrigin(normalized));
    await _removeBoundOrigin(normalized);
    await _store.delete(kLegacyToken);
  }

  Future<bool> _deleteLegacyTokenIfPresent() async {
    final legacy = await _store.read(kLegacyToken);
    if (legacy == null) return false;
    await _store.delete(kLegacyToken);
    return true;
  }

  Future<List<String>> _readBoundOrigins() async {
    final raw = await _store.read(kBoundOriginsIndex);
    if (raw == null || raw.trim().isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];
      // Growable copy — callers may mutate before rewriting the index.
      return decoded
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _writeBoundOrigins(List<String> origins) async {
    final unique = origins.toSet().toList()..sort();
    if (unique.isEmpty) {
      await _store.delete(kBoundOriginsIndex);
      return;
    }
    await _store.write(kBoundOriginsIndex, jsonEncode(unique));
  }

  Future<void> _addBoundOrigin(String origin) async {
    final list = await _readBoundOrigins();
    if (!list.contains(origin)) {
      list.add(origin);
      await _writeBoundOrigins(list);
    }
  }

  Future<void> _removeBoundOrigin(String origin) async {
    final list = await _readBoundOrigins();
    if (list.remove(origin)) {
      await _writeBoundOrigins(list);
    }
  }
}
