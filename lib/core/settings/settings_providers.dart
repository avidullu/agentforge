import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Loaded connection settings (async; re-read after [settingsControllerProvider] saves).
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsRepositoryProvider).load();
});

final settingsControllerProvider = Provider<SettingsController>(
  (ref) => SettingsController(ref),
);

class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  Future<void> save(AppSettings settings) async {
    await _ref.read(settingsRepositoryProvider).save(settings);
    _ref.invalidate(settingsProvider);
  }

  Future<void> disconnect() async {
    await _ref.read(settingsRepositoryProvider).clearToken();
    _ref.invalidate(settingsProvider);
  }
}
