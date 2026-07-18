import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal async key-value store used by [SettingsRepository].
///
/// [FlutterSecureStorage] is the production backend; tests inject an in-memory
/// map without platform plugins.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Best-effort key listing (empty when the backend cannot enumerate).
  Future<List<String>> keys();
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<List<String>> keys() async => const [];
}

/// In-memory store for unit tests (no platform channel).
class MemorySecureKeyValueStore implements SecureKeyValueStore {
  MemorySecureKeyValueStore([Map<String, String>? seed])
    : _data = Map<String, String>.from(seed ?? const {});

  final Map<String, String> _data;

  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<List<String>> keys() async => _data.keys.toList(growable: false);
}
