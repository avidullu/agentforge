import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgentForge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestone 0',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Deep linking is wired for avis-pbook Forgejo PRs.\n\n'
              'Open a PR link from Gmail (HTTPS) or try agentforge://pr/owner/repo/42 '
              'and you should land on the PR detail screen.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 32),
            Text(
              'Next after device CUJ: connect to Forgejo API (Milestone 1).',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
