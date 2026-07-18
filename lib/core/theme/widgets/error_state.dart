import 'package:flutter/material.dart';

/// A full-width error panel with a title, message, retry button, and
/// fallback body text.
///
/// Extracted from the private `_ErrorPane` pattern used in
/// `pr_detail_screen.dart`. Gives every screen a consistent error
/// recovery affordance.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.fallback = '',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
          if (fallback.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(fallback, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
