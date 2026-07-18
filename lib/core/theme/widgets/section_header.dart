import 'package:flutter/material.dart';

/// A labeled section divider with an optional trailing action.
///
/// Used throughout the app to separate list sections with consistent
/// spacing and typography. The trailing action is typically a small
/// text button or icon button for actions like "See all" or "Add."
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
