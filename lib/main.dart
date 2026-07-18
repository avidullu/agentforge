import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/deep_links/deep_link.dart';
import 'core/deep_links/deep_link_listener.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cold start: if the OS launched us from a PR URL, open that route first.
  String initialLocation = '/';
  try {
    final initialUri = await agentForgeAppLinks.getInitialLink();
    final fromLink = deepLinkToLocation(initialUri);
    if (fromLink != null) {
      initialLocation = fromLink;
    }
  } catch (_) {
    // Platform channels can fail in tests / unsupported platforms — fall back.
  }

  runApp(
    ProviderScope(
      overrides: [initialLocationProvider.overrideWithValue(initialLocation)],
      child: const AgentForgeApp(),
    ),
  );
}
