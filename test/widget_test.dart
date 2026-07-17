import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agentforge/app.dart';
import 'package:agentforge/core/settings/app_settings.dart';
import 'package:agentforge/core/settings/settings_providers.dart';
import 'package:agentforge/router.dart';

void main() {
  testWidgets('App starts on home without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) async => const AppSettings(
              baseUrl: AppSettings.defaultBaseUrl,
              token: '',
            ),
          ),
        ],
        child: const AgentForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AgentForge'), findsWidgets);
    expect(find.text('Connect Forgejo'), findsOneWidget);
  });

  testWidgets('Cold-start initialLocation opens PR detail', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialLocationProvider.overrideWithValue(
            '/Khelsutra/badminton-highlight-indexer/pulls/611',
          ),
          settingsProvider.overrideWith(
            (ref) async => const AppSettings(
              baseUrl: AppSettings.defaultBaseUrl,
              token: '',
            ),
          ),
        ],
        child: const AgentForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Unconfigured: AppBar + body both show owner/repo/number
    expect(
      find.textContaining('Khelsutra/badminton-highlight-indexer #611'),
      findsWidgets,
    );
    expect(find.textContaining('Connect Forgejo in Settings'), findsOneWidget);
  });
}
