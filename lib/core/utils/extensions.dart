import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Extension on BuildContext for easier access to theme and media query.
extension ContextExtensions on BuildContext {
  // Theme shortcuts
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;

  // Media query shortcuts
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get padding => mediaQuery.padding;
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  // Brightness
  bool get isDarkMode => theme.brightness == Brightness.dark;
  bool get isLightMode => theme.brightness == Brightness.light;

  // Screen size helpers
  bool get isSmallScreen => screenWidth < 360;
  bool get isMediumScreen => screenWidth >= 360 && screenWidth < 600;
  bool get isLargeScreen => screenWidth >= 600;
}

/// Extension on String for validation and formatting.
extension StringExtensions on String {
  // Validation
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(this);
  }

  bool get isValidUsername {
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(this) && length >= 3;
  }

  // Formatting
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get capitalizeWords {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  // Truncation
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }
}

/// Extension on DateTime for formatting.
extension DateTimeExtensions on DateTime {
  // Chat time formatting
  String get chatTimeFormat {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(year, month, day);

    if (messageDate == today) {
      return DateFormat.jm().format(this); // e.g., "2:30 PM"
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(this).inDays < 7) {
      return DateFormat.E().format(this); // e.g., "Mon"
    } else {
      return DateFormat.MMMd().format(this); // e.g., "Jan 5"
    }
  }

  // Message time formatting (alias for messageTimeFormat)
  String get messageTimeFormat {
    return DateFormat.jm().format(this); // e.g., "2:30 PM"
  }

  // Time only (short form, same as messageTimeFormat)
  String get timeOnly => messageTimeFormat;

  // Full date format
  String get fullDateFormat {
    return DateFormat.yMMMd().format(this); // e.g., "Jan 5, 2024"
  }

  // Relative time (alias: timeAgo)
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return fullDateFormat;
    }
  }

  // Time ago (alias for relativeTime)
  String get timeAgo => relativeTime;

  // Date label for message grouping
  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(year, month, day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(this).inDays < 7) {
      return DateFormat.EEEE().format(this); // e.g., "Monday"
    } else if (now.year == year) {
      return DateFormat.MMMd().format(this); // e.g., "Jan 5"
    } else {
      return DateFormat.yMMMd().format(this); // e.g., "Jan 5, 2024"
    }
  }
}

/// Extension on Color for manipulation.
extension ColorExtensions on Color {
  // Darken color
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  // Lighten color
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }
}
