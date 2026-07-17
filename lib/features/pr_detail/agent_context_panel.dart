import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/agents/agent_models.dart';
import '../../core/forgejo/forgejo_providers.dart';
import '../../core/mcp/mcp_models.dart';
import '../../core/mcp/mcp_providers.dart';

/// Milestone 4: live agent plan / reasoning / feedback for this PR.
class AgentContextPanel extends ConsumerWidget {
  const AgentContextPanel({
    super.key,
    required this.prKey,
  });

  final PrKey prKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agents = ref.watch(agentsForPrProvider(prKey));
    final ctxAsync = ref.watch(agentContextProvider(prKey));

    if (agents.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'No agents registered with an MCP URL. '
            'Add one under Agents to see plan/reasoning and send feedback.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return ctxAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('$e'),
      data: (contexts) {
        final byId = {for (final c in contexts) c.agentId: c};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final agent in agents) ...[
              _AgentContextCard(
                contextData: byId[agent.id] ??
                    AgentContext.unavailable(
                      agentId: agent.id,
                      agentName: agent.name,
                      error: 'No context loaded',
                    ),
                agent: agent,
                prKey: prKey,
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _AgentContextCard extends ConsumerStatefulWidget {
  const _AgentContextCard({
    required this.contextData,
    required this.agent,
    required this.prKey,
  });

  final AgentContext contextData;
  final AgentEntry agent;
  final PrKey prKey;

  @override
  ConsumerState<_AgentContextCard> createState() => _AgentContextCardState();
}

class _AgentContextCardState extends ConsumerState<_AgentContextCard> {
  final _feedbackCtrl = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final result = await ref.read(mcpActionsProvider).sendFeedback(
          agent: widget.agent,
          key: widget.prKey,
          message: text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.ok) _feedbackCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.contextData;
    final updated = c.updatedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(widget.agent.colorArgb),
                  child: Text(
                    widget.agent.name.isNotEmpty
                        ? widget.agent.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.agent.name} · ${widget.agent.machine}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (c.status.isNotEmpty)
                  Chip(
                    label: Text(c.status, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (c.error != null) ...[
              const SizedBox(height: 8),
              Text(
                c.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (c.plan.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Plan', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(c.plan, style: theme.textTheme.bodyMedium),
            ],
            if (c.reasoning.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Reasoning', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                c.reasoning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
            if (c.recentActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Recent actions', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              for (final a in c.recentActions.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $a', style: theme.textTheme.bodySmall),
                ),
            ],
            if (updated != null) ...[
              const SizedBox(height: 8),
              Text(
                'Updated ${timeago.format(updated)} · ${c.rawSource}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackCtrl,
              minLines: 1,
              maxLines: 3,
              enabled: !_sending,
              decoration: const InputDecoration(
                labelText: 'Feedback to agent',
                hintText: 'e.g. Prefer option B; skip the docs refactor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
