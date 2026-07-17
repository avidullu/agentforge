import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/forgejo/forgejo_client.dart';
import '../../core/forgejo/forgejo_providers.dart';
import '../../core/forgejo/models.dart';
import '../../core/settings/settings_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgentForge'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(openPullRequestsProvider);
              ref.invalidate(settingsProvider);
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _MessageBody(
          title: 'Could not load settings',
          body: e.toString(),
          actionLabel: 'Open Settings',
          onAction: () => context.push('/settings'),
        ),
        data: (settings) {
          if (!settings.isConfigured) {
            return _MessageBody(
              title: 'Connect Forgejo',
              body:
                  'Add your avis-pbook instance URL and a personal access token '
                  'to list open pull requests over Tailscale.',
              actionLabel: 'Open Settings',
              onAction: () => context.push('/settings'),
            );
          }
          return const _PullRequestList();
        },
      ),
    );
  }
}

class _PullRequestList extends ConsumerWidget {
  const _PullRequestList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(openPullRequestsProvider);

    return prs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _MessageBody(
        title: 'Failed to load PRs',
        body: forgejoErrorMessage(e),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(openPullRequestsProvider),
        secondaryLabel: 'Settings',
        onSecondary: () => context.push('/settings'),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _MessageBody(
            title: 'No open pull requests',
            body: 'Nothing open on repos visible to this token.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(openPullRequestsProvider);
            await ref.read(openPullRequestsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _PrTile(pr: list[index]),
          ),
        );
      },
    );
  }
}

class _PrTile extends StatelessWidget {
  const _PrTile({required this.pr});

  final PullRequestSummary pr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updated = pr.updatedAt;

    return ListTile(
      leading: Icon(
        pr.draft ? Icons.drafts_outlined : Icons.merge_type,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        pr.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          '${pr.fullName} #${pr.number}',
          if (pr.user.login.isNotEmpty) pr.user.login,
          if (updated != null) timeago.format(updated),
          if (pr.draft) 'draft',
        ].join(' · '),
      ),
      onTap: () => context.push(pr.routePath),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}
