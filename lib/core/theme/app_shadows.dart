import 'package:flutter/material.dart';

/// Shadow presets for elevation effects.
abstract class AppShadows {
  // Light theme shadows
  static List<BoxShadow> none = [];

  static List<BoxShadow> subtle(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> small(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> medium(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.1),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> large(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // Glassmorphism glow effect
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: -2,
    ),
  ];

  // Neon glow for dark mode
  static List<BoxShadow> neonGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.2),
      blurRadius: 24,
      spreadRadius: 4,
    ),
  ];

  // Single glow shadow for buttons and interactive elements
  static BoxShadow glowShadow(Color color, {double intensity = 0.3}) => BoxShadow(
    color: color.withValues(alpha: intensity),
    blurRadius: 16,
    spreadRadius: 2,
  );
}
