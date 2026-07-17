import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agents/agent_models.dart';
import '../../core/agents/agent_providers.dart';

class AgentsScreen extends ConsumerWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);
    final workAsync = ref.watch(agentWorkMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Agents'),
        actions: [
          IconButton(
            tooltip: 'Refresh work',
            onPressed: () {
              ref.invalidate(agentsProvider);
              ref.invalidate(agentWorkMapProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref),
        child: const Icon(Icons.add),
      ),
      body: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (agents) {
          if (agents.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No agents registered yet.\n\n'
                'Add Claude / Codex / Gemini / Grok instances running on your '
                'Tailscale machines. Optional MCP base URL enables active-work polling.',
              ),
            );
          }
          final work = workAsync.valueOrNull ?? const {};
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: agents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = agents[i];
              final items = work[a.id] ?? const <AgentWorkItem>[];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(a.colorArgb),
                  child: Text(
                    a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(a.name),
                subtitle: Text(
                  [
                    a.machine,
                    if (a.mcpBaseUrl.isNotEmpty) a.mcpBaseUrl,
                    if (items.isEmpty)
                      'no active work reported'
                    else
                      items
                          .map((w) => '${w.fullName}#${w.prNumber}')
                          .join(', '),
                  ].join('\n'),
                ),
                isThreeLine: true,
                onTap: () => _showEditor(context, ref, existing: a),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref.read(agentControllerProvider).remove(a.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    AgentEntry? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final machineCtrl = TextEditingController(text: existing?.machine ?? '');
    final mcpCtrl = TextEditingController(text: existing?.mcpBaseUrl ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add agent' : 'Edit agent'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Codex on MSI',
                ),
              ),
              TextField(
                controller: machineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Machine',
                  hintText: 'avis-msi / avis-pbook',
                ),
              ),
              TextField(
                controller: mcpCtrl,
                decoration: const InputDecoration(
                  labelText: 'MCP base URL (optional)',
                  hintText: 'http://100.x.y.z:8765',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final machine = machineCtrl.text.trim();
    if (name.isEmpty || machine.isEmpty) return;

    final entry = existing == null
        ? ref.read(agentControllerProvider).draft(
              name: name,
              machine: machine,
              mcpBaseUrl: mcpCtrl.text.trim(),
            )
        : existing.copyWith(
            name: name,
            machine: machine,
            mcpBaseUrl: mcpCtrl.text.trim(),
          );
    await ref.read(agentControllerProvider).upsert(entry);
  }
}
