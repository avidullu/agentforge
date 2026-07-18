import 'package:agentforge/core/settings/app_settings.dart';
import 'package:agentforge/core/settings/secure_store.dart';
import 'package:agentforge/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });

    test('never returns another origin PAT for the current origin', () async {
      await repo.save(const AppSettings(baseUrl: originA, token: 'pat-a'));
      await store.write(SettingsRepository.kBaseUrl, originB);

      final loaded = await repo.load();
      expect(loaded.baseUrl, originB);
      expect(loaded.token, isEmpty);
      expect(loaded.credentialState, isNot(CredentialLoadState.bound));
      // Origin A token remains stored but is not used for B.
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

        // (a) legacy key gone
        expect(
          store.snapshot.containsKey(SettingsRepository.kLegacyToken),
          isFalse,
        );
        // (b) no PAT sent/loaded for the configured origin
        expect(loaded.token, isEmpty);
        expect(
          store.snapshot[SettingsRepository.tokenKeyForOrigin(originB)],
          isNull,
        );
        // (c) UI state requires re-entry (mismatch/legacy wipe prompt)
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
      await repo.clearToken(origin: originA);

      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originA)],
        isNull,
      );
      expect(
        store.snapshot[SettingsRepository.tokenKeyForOrigin(originB)],
        'pat-b',
      );
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
  });
}
