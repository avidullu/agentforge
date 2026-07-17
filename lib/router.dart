import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/pr_detail/pr_detail_screen.dart';
import 'features/settings/settings_screen.dart';

/// Cold-start location from the OS deep link (defaults to `/`).
final initialLocationProvider = Provider<String>((ref) => '/');

final routerProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.watch(initialLocationProvider);

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // Deep link target for Forgejo PRs
      // Supports both:
      //   /owner/repo/pulls/42
      //   /owner/repo/pull/42
      GoRoute(
        path: '/:owner/:repo/pulls/:number',
        name: 'pr',
        builder: (context, state) {
          final owner = state.pathParameters['owner']!;
          final repo = state.pathParameters['repo']!;
          final number =
              int.tryParse(state.pathParameters['number'] ?? '') ?? 0;
          return PrDetailScreen(
            owner: owner,
            repo: repo,
            number: number,
          );
        },
      ),
      GoRoute(
        path: '/:owner/:repo/pull/:number',
        name: 'pr-alt',
        builder: (context, state) {
          final owner = state.pathParameters['owner']!;
          final repo = state.pathParameters['repo']!;
          final number =
              int.tryParse(state.pathParameters['number'] ?? '') ?? 0;
          return PrDetailScreen(
            owner: owner,
            repo: repo,
            number: number,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
