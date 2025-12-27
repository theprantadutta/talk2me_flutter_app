import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_shadows.dart';

/// A glassmorphic avatar with online indicator and glow effect.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool isOnline;
  final bool showOnlineIndicator;
  final bool showGlow;
  final Color? glowColor;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderWidth;
  final Color? borderColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.isOnline = false,
    this.showOnlineIndicator = false,
    this.showGlow = false,
    this.glowColor,
    this.onTap,
    this.backgroundColor,
    this.borderWidth,
    this.borderColor,
  });

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final names = name!.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return names[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveGlowColor = glowColor ?? theme.colorScheme.primary;
    final effectiveBackgroundColor = backgroundColor ??
        (isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.3)
            : theme.colorScheme.primary.withValues(alpha: 0.1));

    final indicatorSize = size * 0.25;
    final indicatorOffset = size * 0.05;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: borderWidth != null
            ? Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.5),
                width: borderWidth!,
              )
            : null,
        boxShadow: showGlow
            ? [
                AppShadows.glowShadow(effectiveGlowColor, intensity: 0.4),
              ]
            : null,
        gradient: imageUrl == null || imageUrl!.isEmpty
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                  theme.colorScheme.secondary.withValues(alpha: 0.6),
                ],
              )
            : null,
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (context, url) => _buildInitials(theme),
                errorWidget: (context, url, error) => _buildInitials(theme),
              )
            : _buildInitials(theme),
      ),
    );

    if (showOnlineIndicator) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: indicatorOffset,
            bottom: indicatorOffset,
            child: _OnlineIndicator(
              size: indicatorSize,
              isOnline: isOnline,
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildInitials(ThemeData theme) {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OnlineIndicator extends StatefulWidget {
  final double size;
  final bool isOnline;

  const _OnlineIndicator({
    required this.size,
    required this.isOnline,
  });

  @override
  State<_OnlineIndicator> createState() => _OnlineIndicatorState();
}

class _OnlineIndicatorState extends State<_OnlineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isOnline) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _OnlineIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline != oldWidget.isOnline) {
      if (widget.isOnline) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                widget.isOnline ? const Color(0xFF4CAF50) : Colors.grey[400],
            border: Border.all(
              color: theme.scaffoldBackgroundColor,
              width: widget.size * 0.15,
            ),
            boxShadow: widget.isOnline
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50)
                          .withValues(alpha: 0.5 / _pulseAnimation.value),
                      blurRadius: 4 * _pulseAnimation.value,
                      spreadRadius: 1 * _pulseAnimation.value,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

/// Avatar group for showing multiple participants.
class AvatarGroup extends StatelessWidget {
  final List<AvatarData> avatars;
  final double size;
  final int maxVisible;
  final double overlap;

  const AvatarGroup({
    super.key,
    required this.avatars,
    this.size = 36,
    this.maxVisible = 3,
    this.overlap = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleAvatars = avatars.take(maxVisible).toList();
    final remaining = avatars.length - maxVisible;
    final overlapPx = size * overlap;

    return SizedBox(
      width: size + (visibleAvatars.length - 1) * (size - overlapPx) +
          (remaining > 0 ? size - overlapPx : 0),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visibleAvatars.length; i++)
            Positioned(
              left: i * (size - overlapPx),
              child: AppAvatar(
                imageUrl: visibleAvatars[i].imageUrl,
                name: visibleAvatars[i].name,
                size: size,
                borderWidth: 2,
                borderColor: theme.scaffoldBackgroundColor,
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: visibleAvatars.length * (size - overlapPx),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Data class for avatar group.
class AvatarData {
  final String? imageUrl;
  final String? name;

  const AvatarData({
    this.imageUrl,
    this.name,
  });
}
