import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agentforge/app.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AgentForgeApp(),
      ),
    );
    expect(find.text('AgentForge'), findsOneWidget);
  });
}
