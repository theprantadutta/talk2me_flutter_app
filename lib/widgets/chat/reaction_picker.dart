import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/chat_message.dart';

/// A popup widget for selecting message reactions
class ReactionPicker extends StatelessWidget {
  final Function(String emoji) onReactionSelected;
  final List<String>? currentUserReactions;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.currentUserReactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: AppRadius.xl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.xl,
            color: isDark
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ReactionEmojis.all.map((emoji) {
              final isSelected = currentUserReactions?.contains(emoji) ?? false;

              return GestureDetector(
                onTap: () => onReactionSelected(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Show reaction picker as a popup
  static Future<String?> show(
    BuildContext context, {
    required Offset position,
    List<String>? currentUserReactions,
  }) async {
    return await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            // Dismiss on tap outside
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            // Positioned picker
            Positioned(
              left: position.dx,
              top: position.dy,
              child: ReactionPicker(
                currentUserReactions: currentUserReactions,
                onReactionSelected: (emoji) {
                  Navigator.pop(context, emoji);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Widget to display reactions on a message
class MessageReactions extends StatelessWidget {
  final Map<String, MessageReaction> reactions;
  final String currentUserId;
  final Function(String emoji) onReactionTap;
  final bool isMe;

  const MessageReactions({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final reaction = entry.value;
        final hasUserReacted = reaction.hasUser(currentUserId);

        return GestureDetector(
          onTap: () => onReactionTap(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: hasUserReacted
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: hasUserReacted
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                if (reaction.count > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${reaction.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasUserReacted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
