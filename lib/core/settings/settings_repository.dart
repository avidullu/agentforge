import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_settings.dart';

/// Persists Forgejo connection settings.
///
/// PAT is always stored via [FlutterSecureStorage]. Base URL uses the same
/// store for simplicity (single dependency, small payload).
class SettingsRepository {
  SettingsRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _kBaseUrl = 'forgejo_base_url';
  static const _kToken = 'forgejo_token';

  final FlutterSecureStorage _storage;

  Future<AppSettings> load() async {
    final base = await _storage.read(key: _kBaseUrl);
    final token = await _storage.read(key: _kToken);
    return AppSettings(
      baseUrl: (base == null || base.isEmpty)
          ? AppSettings.defaultBaseUrl
          : AppSettings.normalizeBaseUrl(base),
      token: token ?? '',
    );
  }

  Future<void> save(AppSettings settings) async {
    await _storage.write(
      key: _kBaseUrl,
      value: AppSettings.normalizeBaseUrl(settings.baseUrl),
    );
    await _storage.write(key: _kToken, value: settings.token.trim());
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _kToken);
  }
}
