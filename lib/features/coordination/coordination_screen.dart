import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/agents/agent_providers.dart';
import '../../core/mcp/mcp_providers.dart';
import '../../core/theme/color_contrast.dart';

/// Milestone 5: multi-machine coordination — work grouped by repository.
class CoordinationScreen extends ConsumerWidget {
  const CoordinationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final byRepo = ref.watch(coordinationByRepoProvider);
    final agentsAsync = ref.watch(agentsProvider);
    final workAsync = ref.watch(agentWorkMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordination'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(agentsProvider);
              ref.invalidate(agentWorkMapProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Agents',
            onPressed: () => context.push('/agents'),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
        ],
      ),
      body: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (agents) {
          if (agents.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No agents yet', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Register agent endpoints and point their side-car URL at a '
                    'side-car that exposes /active-work. Then this view groups '
                    'active PRs by repository across machines.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/agents'),
                    child: const Text('Open Agents'),
                  ),
                ],
              ),
            );
          }

          if (workAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (workAsync.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load endpoint activity',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The endpoint registry is available, but activity state '
                    'is not. Refresh to retry; this is not an idle signal.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(agentWorkMapProvider),
                    child: const Text('Retry activity'),
                  ),
                ],
              ),
            );
          }

          final work = workAsync.valueOrNull ?? const {};
          final unavailable = agents
              .where((agent) => work[agent.id]?.isUnavailable == true)
              .toList();

          if (byRepo.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${agents.length} agent(s) registered',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unavailable.isEmpty
                        ? 'None reported fresh active work. Ensure each endpoint '
                              'URL uses HTTPS (or debug-only loopback HTTP) and '
                              'serves GET /active-work with a current updated_at value.'
                        : 'No verified fresh activity. ${unavailable.length} '
                              'endpoint(s) are unavailable; this is not an idle signal.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final a in agents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(a.colorArgb),
                        child: Text(
                          a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: foregroundFor(Color(a.colorArgb)),
                          ),
                        ),
                      ),
                      title: Text(a.name),
                      subtitle: Text(
                        [
                          a.machine,
                          if (work[a.id]?.isUnavailable == true)
                            work[a.id]!.error!
                          else if (a.mcpBaseUrl.isNotEmpty)
                            'no fresh active work reported'
                          else
                            'no side-car URL configured',
                        ].join(' · '),
                      ),
                    ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Active work by repository',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Same repo, different machines — related efforts at a glance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              if (unavailable.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${unavailable.length} endpoint(s) unavailable. '
                      'Results below are partial; refresh to retry.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final entry in byRepo.entries) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        for (final row in entry.value)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(row.agent.colorArgb),
                              child: Text(
                                row.agent.name.isNotEmpty
                                    ? row.agent.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: foregroundFor(
                                    Color(row.agent.colorArgb),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              '#${row.work.prNumber} ${row.work.title.isEmpty ? row.work.branch : row.work.title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                row.agent.name,
                                row.agent.machine,
                                row.work.status,
                                if (row.work.branch.isNotEmpty) row.work.branch,
                              ].join(' · '),
                            ),
                            onTap: () => context.push(
                              '/${row.work.owner}/${row.work.repo}/pulls/${row.work.prNumber}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
