import 'package:flutter/material.dart';

/// A centered empty-state placeholder with a title, descriptive body,
/// and one or two action buttons.
///
/// Extracted from the private `_MessageBody` pattern used in
/// `home_screen.dart`. Consistent padding, typography, and button
/// ordering across all screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ],
      ),
    );
  }
}
