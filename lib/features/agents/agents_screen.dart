import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agents/agent_models.dart';
import '../../core/agents/agent_providers.dart';

class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  Future<void> _showEditor({AgentEntry? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final machineCtrl = TextEditingController(text: existing?.machine ?? '');
    final mcpCtrl = TextEditingController(text: existing?.mcpBaseUrl ?? '');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add agent' : 'Edit agent'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'Codex on MSI',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: machineCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Machine *',
                    hintText: 'avis-msi / avis-pbook',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: mcpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'MCP base URL (optional)',
                    hintText: 'http://127.0.0.1:8765',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final machine = machineCtrl.text.trim();
    final mcp = mcpCtrl.text.trim();

    try {
      final entry = existing == null
          ? ref.read(agentControllerProvider).draft(
                name: name,
                machine: machine,
                mcpBaseUrl: mcp,
              )
          : existing.copyWith(
              name: name,
              machine: machine,
              mcpBaseUrl: mcp,
            );
      await ref.read(agentControllerProvider).upsert(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Agent “$name” added' : 'Agent “$name” updated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save agent: $e')),
      );
    } finally {
      nameCtrl.dispose();
      machineCtrl.dispose();
      mcpCtrl.dispose();
    }
  }

  Future<void> _confirmDelete(AgentEntry a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove agent?'),
        content: Text('Remove “${a.name}” (${a.machine})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(agentControllerProvider).remove(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${a.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add agent'),
      ),
      body: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Failed to load agents: $e'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(agentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (agents) {
          if (agents.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No agents registered yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap “Add agent” and fill Name + Machine (required). '
                    'MCP base URL is optional — use http://127.0.0.1:8765 '
                    'with the mock server for a local demo.',
                  ),
                ],
              ),
            );
          }
          final work = workAsync.valueOrNull ?? const {};
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
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
                onTap: () => _showEditor(existing: a),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(a),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
