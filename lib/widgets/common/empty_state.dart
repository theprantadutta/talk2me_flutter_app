import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../glass/glass_button.dart';

/// An empty state widget with glassmorphism styling.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.iconSize = 80,
  });

  /// Empty state for no chats.
  factory EmptyState.noChats({VoidCallback? onStartChat}) {
    return EmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'No conversations yet',
      subtitle: 'Start a new chat to connect with friends',
      actionText: 'Start Chat',
      onAction: onStartChat,
    );
  }

  /// Empty state for no messages.
  factory EmptyState.noMessages() {
    return const EmptyState(
      icon: Icons.message_outlined,
      title: 'No messages yet',
      subtitle: 'Send a message to start the conversation',
    );
  }

  /// Empty state for no search results.
  factory EmptyState.noResults({String? query}) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No results found',
      subtitle: query != null ? 'No results for "$query"' : 'Try a different search term',
    );
  }

  /// Empty state for no users found.
  factory EmptyState.noUsers() {
    return const EmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No users found',
      subtitle: 'Try searching with a different name or email',
    );
  }

  /// Empty state for error.
  factory EmptyState.error({
    String? message,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      subtitle: message ?? 'Please try again later',
      actionText: 'Retry',
      onAction: onRetry,
    );
  }

  /// Empty state for no internet.
  factory EmptyState.noInternet({VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'No internet connection',
      subtitle: 'Please check your connection and try again',
      actionText: 'Retry',
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize + 40,
              height: iconSize + 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ]
                      : [
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                          theme.colorScheme.secondary.withValues(alpha: 0.05),
                        ],
                ),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              GlassButton(
                text: actionText,
                onPressed: onAction,
                showGlow: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A loading indicator with optional message.
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
