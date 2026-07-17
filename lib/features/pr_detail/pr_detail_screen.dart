import 'package:flutter/material.dart';

class PrDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$owner/$repo #$number'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deep Link Received!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Owner: $owner'),
            Text('Repo: $repo'),
            Text('PR Number: $number'),
            const SizedBox(height: 32),
            const Text(
              'This screen will later show the full PR conversation, '
              'agent context, and review actions.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
