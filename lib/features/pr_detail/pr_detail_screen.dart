import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/forgejo/forgejo_client.dart';
import '../../core/forgejo/forgejo_providers.dart';

class PrDetailScreen extends ConsumerWidget {
  final String owner;
  final String repo;
  final int number;

  const PrDetailScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.number,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = PrKey(owner, repo, number);
    final detailAsync = ref.watch(pullRequestDetailProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: Text('$owner/$repo #$number'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Could not load PR', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(forgejoErrorMessage(e)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(pullRequestDetailProvider(key)),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 24),
              _DeepLinkFallback(owner: owner, repo: repo, number: number),
            ],
          ),
        ),
        data: (detail) {
          if (detail == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deep link target',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('$owner/$repo #$number'),
                  const SizedBox(height: 16),
                  Text(
                    'Connect Forgejo in Settings to load title, body, and later reviews.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          final s = detail.summary;
          final updated = s.updatedAt;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (s.draft)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Chip(
                    label: const Text('Draft'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              Text(s.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                [
                  s.fullName,
                  '#${s.number}',
                  s.state,
                  if (s.user.login.isNotEmpty) 'by ${s.user.login}',
                  if (updated != null) timeago.format(updated),
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text('Description', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                detail.body.trim().isEmpty ? '(no description)' : detail.body,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 32),
              Text(
                'Conversation, agent context, and review actions arrive in '
                'Milestones 2–4.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeepLinkFallback extends StatelessWidget {
  const _DeepLinkFallback({
    required this.owner,
    required this.repo,
    required this.number,
  });

  final String owner;
  final String repo;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Deep link params: owner=$owner repo=$repo number=$number',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
