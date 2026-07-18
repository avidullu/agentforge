import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/agents/agent_models.dart';
import '../../core/agents/agent_providers.dart';
import '../../core/forgejo/forgejo_client.dart';
import '../../core/forgejo/forgejo_providers.dart';
import '../../core/forgejo/models.dart';
import '../../core/theme/widgets/empty_state.dart';
import '../../core/theme/widgets/status_badge.dart';
import '../../core/settings/settings_providers.dart';

/// Home list filter.
enum PrListFilter { all, withAgents }

final prListFilterProvider = StateProvider<PrListFilter>(
  (ref) => PrListFilter.all,
);

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
            tooltip: 'Coordination',
            icon: const Icon(Icons.hub_outlined),
            onPressed: () => context.push('/coordination'),
          ),
          IconButton(
            tooltip: 'Agents',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.push('/agents'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(openPullRequestsProvider);
              ref.invalidate(settingsProvider);
              ref.invalidate(agentWorkMapProvider);
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
        error: (e, _) => EmptyState(
          title: 'Could not load settings',
          body: e.toString(),
          actionLabel: 'Open Settings',
          onAction: () => context.push('/settings'),
        ),
        data: (settings) {
          if (!settings.isConfigured) {
            return EmptyState(
              title: 'Connect Forgejo',
              body:
                  'Add your Forgejo instance URL and a personal access token '
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
    final filter = ref.watch(prListFilterProvider);
    final agentsByPr = ref.watch(agentsByPrProvider);
    final workAsync = ref.watch(agentWorkMapProvider);

    return prs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        title: 'Failed to load PRs',
        body: forgejoErrorMessage(e),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(openPullRequestsProvider),
        secondaryLabel: 'Settings',
        onSecondary: () => context.push('/settings'),
      ),
      data: (list) {
        final activityIncomplete =
            workAsync.isLoading ||
            workAsync.hasError ||
            (workAsync.valueOrNull?.values.any(
                  (result) => result.isUnavailable,
                ) ??
                false);
        final filtered = filter == PrListFilter.all
            ? list
            : list
                  .where(
                    (p) => (agentsByPr['${p.fullName}#${p.number}'] ?? const [])
                        .isNotEmpty,
                  )
                  .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All open'),
                    selected: filter == PrListFilter.all,
                    onSelected: (_) =>
                        ref.read(prListFilterProvider.notifier).state =
                            PrListFilter.all,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('With agents'),
                    selected: filter == PrListFilter.withAgents,
                    onSelected: (_) =>
                        ref.read(prListFilterProvider.notifier).state =
                            PrListFilter.withAgents,
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            if (activityIncomplete)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Agent activity is loading or partial; “With agents” may '
                    'omit PRs until endpoint health recovers.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      title:
                          filter == PrListFilter.withAgents &&
                              activityIncomplete
                          ? 'Agent activity incomplete'
                          : filter == PrListFilter.withAgents
                          ? 'No agent-linked PRs'
                          : 'No open pull requests',
                      body:
                          filter == PrListFilter.withAgents &&
                              activityIncomplete
                          ? 'One or more endpoint activity results are loading '
                                'or unavailable. Retry before treating this as '
                                'an empty result.'
                          : filter == PrListFilter.withAgents
                          ? 'Register agents and expose /active-work, or switch to All open.'
                          : 'Nothing open on repos visible to this token.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(openPullRequestsProvider);
                        ref.invalidate(agentWorkMapProvider);
                        await ref.read(openPullRequestsProvider.future);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _PrTile(pr: filtered[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PrTile extends ConsumerWidget {
  const _PrTile({required this.pr});

  final PullRequestSummary pr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final updated = pr.updatedAt;
    final agents =
        ref.watch(agentsByPrProvider)['${pr.fullName}#${pr.number}'] ??
        const <AgentEntry>[];

    return ListTile(
      leading: Icon(
        pr.draft ? Icons.drafts_outlined : Icons.merge_type,
        color: theme.colorScheme.primary,
      ),
      title: Text(pr.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              '${pr.fullName} #${pr.number}',
              if (pr.user.login.isNotEmpty) pr.user.login,
              if (updated != null) timeago.format(updated),
              if (pr.draft) 'draft',
            ].join(' · '),
          ),
          if (agents.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final a in agents)
                  StatusBadge(
                    label: a.name,
                    avatarColor: Color(a.colorArgb),
                    avatarLabel: a.name[0].toUpperCase(),
                  ),
              ],
            ),
          ],
        ],
      ),
      isThreeLine: agents.isNotEmpty,
      onTap: () => context.push(pr.routePath),
    );
  }
}
