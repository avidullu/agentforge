import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agentforge/app.dart';
import 'package:agentforge/router.dart';

void main() {
  testWidgets('App starts on home without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgentForgeApp(),
      ),
    );
    // google_fonts may trigger async font loading
    await tester.pump();
    expect(find.text('AgentForge'), findsOneWidget);
  });

  testWidgets('Cold-start initialLocation opens PR detail', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialLocationProvider.overrideWithValue(
            '/Khelsutra/badminton-highlight-indexer/pulls/611',
          ),
        ],
        child: const AgentForgeApp(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Deep Link Received'), findsOneWidget);
    expect(find.textContaining('Khelsutra/badminton-highlight-indexer #611'), findsOneWidget);
    expect(find.text('Owner: Khelsutra'), findsOneWidget);
    expect(find.text('PR Number: 611'), findsOneWidget);
  });
}
