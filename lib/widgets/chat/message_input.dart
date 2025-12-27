import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/animation_constants.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// A floating glassmorphic message input bar.
class MessageInput extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onVoice;
  final VoidCallback? onEmoji;
  final String? hintText;
  final bool enabled;
  final bool showAttachments;
  final bool showVoice;
  final bool showEmoji;
  final Widget? replyPreview;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSend,
    this.onAttachment,
    this.onVoice,
    this.onEmoji,
    this.hintText,
    this.enabled = true,
    this.showAttachments = true,
    this.showVoice = true,
    this.showEmoji = true,
    this.replyPreview,
    this.onCancelReply,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonAnimation;
  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.isNotEmpty;

    _sendButtonController = AnimationController(
      duration: AnimationConstants.fast,
      vsync: this,
    );
    _sendButtonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.elasticOut),
    );

    if (_hasText) {
      _sendButtonController.forward();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _sendButtonController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _sendButtonController.forward();
      } else {
        _sendButtonController.reverse();
      }
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onSend() {
    if (_hasText && widget.onSend != null) {
      HapticFeedback.lightImpact();
      widget.onSend!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (widget.replyPreview != null) _buildReplyPreview(theme, isDark),
        // Input bar
        Container(
          padding: EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: AppSpacing.sm,
            bottom: AppSpacing.sm + mediaQuery.padding.bottom,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xl,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: AnimationConstants.fast,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.xl,
                  color: isDark
                      ? Colors.white.withValues(alpha: _isFocused ? 0.12 : 0.08)
                      : Colors.white.withValues(alpha: _isFocused ? 0.95 : 0.85),
                  border: Border.all(
                    color: _isFocused
                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                    if (_isFocused)
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Emoji button
                    if (widget.showEmoji)
                      _IconButton(
                        icon: Icons.emoji_emotions_outlined,
                        onPressed: widget.onEmoji,
                      ),
                    // Text field
                    Expanded(
                      child: Focus(
                        onFocusChange: (focused) {
                          setState(() => _isFocused = focused);
                        },
                        child: TextField(
                          controller: _controller,
                          focusNode: widget.focusNode,
                          enabled: widget.enabled,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyLarge,
                          cursorColor: theme.colorScheme.primary,
                          decoration: InputDecoration(
                            hintText: widget.hintText ?? 'Message...',
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.md,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    // Attachment button
                    if (widget.showAttachments && !_hasText)
                      _IconButton(
                        icon: Icons.attach_file_rounded,
                        onPressed: widget.onAttachment,
                      ),
                    // Voice/Send button
                    AnimatedBuilder(
                      animation: _sendButtonAnimation,
                      builder: (context, child) {
                        return _hasText
                            ? Transform.scale(
                                scale: _sendButtonAnimation.value,
                                child: _SendButton(onPressed: _onSend),
                              )
                            : (widget.showVoice
                                ? _IconButton(
                                    icon: Icons.mic_rounded,
                                    onPressed: widget.onVoice,
                                  )
                                : const SizedBox.shrink());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.7),
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: widget.replyPreview!),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onCancelReply,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _IconButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      splashRadius: 20,
      padding: const EdgeInsets.all(AppSpacing.sm),
      constraints: const BoxConstraints(
        minWidth: 40,
        minHeight: 40,
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _SendButton({this.onPressed});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.send_rounded,
            color: theme.colorScheme.onPrimary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// A scroll to bottom FAB for chat.
class ScrollToBottomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final int unreadCount;
  final bool visible;

  const ScrollToBottomButton({
    super.key,
    this.onPressed,
    this.unreadCount = 0,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedOpacity(
      duration: AnimationConstants.fast,
      opacity: visible ? 1.0 : 0.0,
      child: AnimatedScale(
        duration: AnimationConstants.fast,
        scale: visible ? 1.0 : 0.8,
        child: GestureDetector(
          onTap: onPressed,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.9),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
