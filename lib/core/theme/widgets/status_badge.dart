import 'package:flutter/material.dart';

import '../color_contrast.dart';

/// A compact, display-only status badge (chip).
///
/// Replaces the `Chip` + `MaterialTapTargetSize.shrinkWrap` pattern used in
/// `home_screen.dart` and `agent_context_panel.dart` while keeping the visual
/// appearance compact. It deliberately has no gesture handler: screens that
/// need an action must provide their own accessible control and tap target.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.avatarColor,
    this.avatarLabel = '',
  });

  final String label;
  final Color? backgroundColor;
  final Color? avatarColor;
  final String avatarLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final fg = foregroundFor(bg);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatarColor != null) ...[
            CircleAvatar(
              backgroundColor: avatarColor,
              radius: 8,
              foregroundColor: foregroundFor(avatarColor!),
              child: Text(
                avatarLabel,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
