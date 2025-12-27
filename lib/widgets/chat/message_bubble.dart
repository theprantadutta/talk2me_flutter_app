import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/animation_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/extensions.dart';
import '../../models/message_model.dart';

/// A glassmorphic message bubble with gradient for sent messages.
class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isSent;
  final bool showSenderName;
  final bool showAvatar;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final MessageStatus status;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showSenderName = false,
    this.showAvatar = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.onLongPress,
    this.onDoubleTap,
    this.status = MessageStatus.sent,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPressStart() {
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  void _onLongPressEnd() {
    _controller.reverse();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate border radius based on position in group
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(widget.isSent ? 20 : (widget.isFirstInGroup ? 20 : 8)),
      topRight: Radius.circular(widget.isSent ? (widget.isFirstInGroup ? 20 : 8) : 20),
      bottomLeft: Radius.circular(widget.isSent ? 20 : (widget.isLastInGroup ? 4 : 8)),
      bottomRight: Radius.circular(widget.isSent ? (widget.isLastInGroup ? 4 : 8) : 20),
    );

    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        left: widget.isSent ? 60 : AppSpacing.md,
        right: widget.isSent ? AppSpacing.md : 60,
        top: widget.isFirstInGroup ? AppSpacing.sm : AppSpacing.xxs,
        bottom: widget.isLastInGroup ? AppSpacing.sm : AppSpacing.xxs,
      ),
      child: Align(
        alignment: widget.isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: (_) => _onLongPressEnd(),
          onLongPressCancel: () => _controller.reverse(),
          onDoubleTap: widget.onDoubleTap,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Column(
              crossAxisAlignment:
                  widget.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name (for group chats)
                if (widget.showSenderName && widget.isFirstInGroup && !widget.isSent)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.xxs,
                    ),
                    child: Text(
                      widget.message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Message bubble
                Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: widget.isSent ? 0 : 10,
                        sigmaY: widget.isSent ? 0 : 10,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          gradient: widget.isSent
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withValues(alpha: 0.85),
                                    theme.colorScheme.secondary.withValues(alpha: 0.8),
                                  ],
                                )
                              : null,
                          color: widget.isSent
                              ? null
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.8)),
                          border: widget.isSent
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                          boxShadow: [
                            if (widget.isSent)
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Message content
                            Text(
                              widget.message.content,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: widget.isSent
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            // Time and status
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.message.isEdited) ...[
                                  Text(
                                    'edited',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: (widget.isSent
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface)
                                          .withValues(alpha: 0.6),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                ],
                                Text(
                                  widget.message.timestamp?.timeOnly ?? '',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: (widget.isSent
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface)
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                if (widget.isSent) ...[
                                  const SizedBox(width: AppSpacing.xxs),
                                  _MessageStatusIcon(status: widget.status),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class _MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _MessageStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimary.withValues(alpha: 0.7);

    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: 14,
          color: color,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: color,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.lightBlueAccent,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: theme.colorScheme.error,
        );
    }
  }
}

/// A typing indicator bubble for the chat.
class TypingBubble extends StatefulWidget {
  final String? senderName;

  const TypingBubble({
    super.key,
    this.senderName,
  });

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: 60,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.senderName != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.xxs,
                ),
                child: Text(
                  widget.senderName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final delay = index * 0.2;
                          final value = (_controller.value + delay) % 1.0;
                          final bounce = (value < 0.5 ? value : 1.0 - value) * 2;
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            transform: Matrix4.translationValues(
                              0,
                              -4 * bounce,
                              0,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3 + (0.5 * bounce),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date separator for message list.
class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            date.dateLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
