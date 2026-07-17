import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Forgejo Connection'),
            subtitle: Text('Coming in Milestone 1'),
          ),
          ListTile(
            title: Text('Local Agents'),
            subtitle: Text('Coming in Milestone 3'),
          ),
        ],
      ),
    );
  }
}
