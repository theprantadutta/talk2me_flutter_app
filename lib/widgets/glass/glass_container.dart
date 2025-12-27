import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';

/// A container with glassmorphism effect - frosted glass with blur and transparency.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.backgroundColor,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? AppRadius.lg;
    final effectiveBorderColor = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.5));
    final effectiveBackgroundColor = backgroundColor ??
        (isDark
            ? Colors.black.withValues(alpha: opacity)
            : Colors.white.withValues(alpha: opacity));

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: effectiveBorderRadius,
              color: gradient == null ? effectiveBackgroundColor : null,
              gradient: gradient,
              border: Border.all(
                color: effectiveBorderColor,
                width: borderWidth,
              ),
              boxShadow: shadows,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A more subtle glass effect for cards and panels.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final BorderRadius? borderRadius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 8.0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      blur: blur,
      opacity: isDark ? 0.15 : 0.2,
      borderRadius: borderRadius ?? AppRadius.md,
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.4),
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
