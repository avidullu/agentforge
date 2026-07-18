import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/agents/agent_models.dart';
import '../../core/forgejo/forgejo_providers.dart';
import '../../core/mcp/mcp_models.dart';
import '../../core/mcp/mcp_providers.dart';
import '../../core/theme/color_contrast.dart';
import '../../core/theme/widgets/status_badge.dart';

/// Prototype agent plan, rationale summary, and feedback for this PR.
class AgentContextPanel extends ConsumerWidget {
  const AgentContextPanel({super.key, required this.prKey});

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
            'No side-car-enabled agent currently claims this PR. '
            'Refresh agent work or link an agent explicitly before sharing '
            'PR context or sending feedback.',
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
        final agentsById = {for (final agent in agents) agent.id: agent};
        final byId = {
          for (final c in contexts)
            if (agentsById[c.agentId] case final agent?
                when agentContextMatchesEndpoint(agent, c))
              c.agentId: c,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final agent in agents) ...[
              _AgentContextCard(
                key: ValueKey((agent.id, agent.mcpBaseUrl.trim())),
                contextData:
                    byId[agent.id] ??
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
    super.key,
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
  String? _pendingFeedbackText;
  String? _pendingClientMessageId;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final retryMessageId = _pendingFeedbackText == text
        ? _pendingClientMessageId ?? ''
        : '';
    final result = await ref
        .read(mcpActionsProvider)
        .sendFeedback(
          agent: widget.agent,
          key: widget.prKey,
          message: text,
          clientMessageId: retryMessageId,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.ok) {
        _pendingFeedbackText = null;
        _pendingClientMessageId = null;
      } else {
        _pendingFeedbackText = text;
        _pendingClientMessageId = result.clientMessageId;
      }
    });
    final receiptSuffix = result.ok && result.deliveryId.isNotEmpty
        ? ' Receipt: ${result.deliveryId}'
        : !result.ok && result.clientMessageId.isNotEmpty
        ? ' Message ID: ${result.clientMessageId}'
        : '';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${result.message}$receiptSuffix')));
    if (result.ok) _feedbackCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.contextData;
    final updated = c.updatedAt;
    final avatarColor = Color(widget.agent.colorArgb);

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
                  backgroundColor: avatarColor,
                  child: Text(
                    widget.agent.name.isNotEmpty
                        ? widget.agent.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 12,
                      color: foregroundFor(avatarColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.agent.name} · ${widget.agent.machine}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (c.status.isNotEmpty) StatusBadge(label: c.status),
              ],
            ),
            if (c.error != null) ...[
              const SizedBox(height: 8),
              Text(c.error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (c.plan.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Plan', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(c.plan, style: theme.textTheme.bodyMedium),
            ],
            if (c.rationaleSummary.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Rationale summary', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(
                c.rationaleSummary,
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
