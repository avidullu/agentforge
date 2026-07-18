import 'package:agentforge/core/settings/app_settings.dart';
import 'package:agentforge/core/settings/secure_store.dart';
import 'package:agentforge/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production-like store: no key enumeration (like FlutterSecureStorage).
class IndexOnlySecureStore implements SecureKeyValueStore {
  IndexOnlySecureStore([Map<String, String>? seed])
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
  Future<List<String>> keys() async => const [];
}

void main() {
  const originA = 'https://forge.example.test';
  const originB = 'https://other.example.test';

  group('SettingsRepository origin-bound credentials (AF-010)', () {
    late MemorySecureKeyValueStore store;
    late SettingsRepository repo;

    setUp(() {
      store = MemorySecureKeyValueStore();
      repo = SettingsRepository(store: store);
    });

    test('saves and loads token only for the bound origin', () async {
      await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
      final loaded = await repo.load();
      expect(loaded.token, 'pat-a');
      expect(loaded.credentialState, CredentialLoadState.bound);
      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
        'pat-a',
      );
      expect(
        store.snapshot.containsKey(SettingsRepository.kLegacyToken),
        isFalse,
      );
      expect(
        store.snapshot[SettingsRepository.kBoundOriginsIndex],
        contains(originA),
      );
    });

    test('never returns another origin PAT for the current origin', () async {
      await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
      await store.write(SettingsRepository.kBaseUrl, originB);

      final loaded = await repo.load();
      expect(loaded.baseUrl, originB);
      expect(loaded.token, isEmpty);
      expect(loaded.credentialState, CredentialLoadState.originMismatch);
      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
        'pat-a',
      );
    });

    test(
      'loadForOrigin reports originMismatch when another origin is bound',
      () async {
        await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
        final forB = await repo.loadForOrigin(originB);
        expect(forB.token, isEmpty);
        expect(forB.credentialState, CredentialLoadState.originMismatch);
        expect(forB.needsCredentialReentry, isTrue);
      },
    );

    test(
      'upgrade: legacy unscoped key is deleted and never auto-bound',
      () async {
        await store.write(SettingsRepository.kLegacyToken, 'legacy-pat');
        await store.write(SettingsRepository.kBaseUrl, originB);

        final loaded = await repo.load();

        expect(
          store.snapshot.containsKey(SettingsRepository.kLegacyToken),
          isFalse,
        );
        expect(loaded.token, isEmpty);
        expect(
          store.snapshot[SettingsRepository.tokenKeyForOrigin(originB)],
          isNull,
        );
        expect(
          loaded.credentialState,
          CredentialLoadState.legacyClearedRequiresReentry,
        );
        expect(loaded.needsCredentialReentry, isTrue);
      },
    );

    test('upgrade: after re-entry, token is origin-scoped only', () async {
      await store.write(SettingsRepository.kLegacyToken, 'legacy-pat');
      await store.write(SettingsRepository.kBaseUrl, originA);

      final first = await repo.load();
      expect(first.needsCredentialReentry, isTrue);

      await repo.save(const AppSettings(baseUrl: originA, token: 'new-pat'));
      final second = await repo.load();
      expect(second.token, 'new-pat');
      expect(second.credentialState, CredentialLoadState.bound);
      expect(
        store.snapshot.containsKey(SettingsRepository.kLegacyToken),
        isFalse,
      );
      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
        'new-pat',
      );
    });

    test('clearToken removes only the current origin key + legacy', () async {
      await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
      await store.write(SettingsRepository.tokenKeyForOrigin(originB), 'pat-b');
      // Keep index consistent for B as production would after save.
      await store.write(
        SettingsRepository.kBoundOriginsIndex,
        '["$originA","$originB"]',
      );
      await repo.clearToken(origin: originA);

      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
        isNull,
      );
      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originB)],
        'pat-b',
      );
      final index = store.snapshot[SettingsRepository.kBoundOriginsIndex] ?? '';
      expect(index.contains(originA), isFalse);
      expect(index.contains(originB), isTrue);
    });

    test('normalizeOrigin strips path for scoping', () async {
      await repo.save(
        const AppSettings(baseUrl: 'https://forge.example.test/', token: 'pat'),
      );
      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
        'pat',
      );
    });

    test('normalizeOrigin keeps non-443 ports in the key', () {
      expect(
        AppSettings.normalizeOrigin('https://forge.example.test:8443'),
        'https://forge.example.test:8443',
      );
      expect(
        AppSettings.normalizeOrigin('https://forge.example.test'),
        'https://forge.example.test',
      );
    });
  });

  group('production-equivalent store (no key enumeration)', () {
    test(
      'originMismatch works via bound-origins index without keys()',
      () async {
        final store = IndexOnlySecureStore();
        final repo = SettingsRepository(store: store);

        await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
        // Simulate persisted base moving to B without a token for B.
        await store.write(SettingsRepository.kBaseUrl, originB);

        final loaded = await repo.load();
        expect(loaded.token, isEmpty);
        expect(loaded.credentialState, CredentialLoadState.originMismatch);
        expect(loaded.needsCredentialReentry, isTrue);
        // Prior-origin PAT remains stored but is not returned.
        expect(
          store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
          'pat-a',
        );
      },
    );

    test(
      'loadForOrigin on new origin after bind forces reentry state',
      () async {
        final store = IndexOnlySecureStore();
        final repo = SettingsRepository(store: store);
        await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
        final forB = await repo.loadForOrigin(originB);
        expect(forB.token, isEmpty);
        expect(forB.credentialState, CredentialLoadState.originMismatch);
      },
    );

    test(
      'load(currentOrigin:) never returns prior-origin PAT without keys()',
      () async {
        final store = IndexOnlySecureStore();
        final repo = SettingsRepository(store: store);
        await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));

        // App now targets B (e.g. build/config origin change) while A remains
        // in secure storage under its scoped key + index entry.
        final loaded = await repo.load(currentOrigin: originB);
        expect(loaded.baseUrl, originB);
        expect(loaded.token, isEmpty);
        expect(loaded.credentialState, CredentialLoadState.originMismatch);
        expect(loaded.needsCredentialReentry, isTrue);
        expect(
          store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
          'pat-a',
        );
      },
    );
  });
}
