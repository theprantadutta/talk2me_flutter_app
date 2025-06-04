import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors (Teal)
  static const Color primary = Color(0xFF008080); // Rich Teal
  static const Color primaryVariant = Color(0xFF006666); // Darker Teal
  static const Color secondary = Color(
    0xFFFF6B35,
  ); // Vibrant Orange (for accents)
  static const Color tertiary = Color(
    0xFF6A4C93,
  ); // Soft Purple (optional accent)

  // Background & Surface Colors
  static const Color background = Color(0xFFF5F7FA); // Very Light Grey-Blue
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color surfaceVariant = Color(
    0xFFEBEEF2,
  ); // Slightly darker white/grey

  // Status Colors
  static const Color error = Color(0xFFE74C3C); // Soft Red
  static const Color success = Color(0xFF2ECC71); // Emerald Green
  static const Color warning = Color(0xFFF39C12); // Golden Yellow
  static const Color info = Color(0xFF3498DB); // Bright Blue

  // Text Colors
  static const Color textPrimary = Color(0xFF2C3E50); // Dark Blue-Grey
  static const Color textSecondary = Color(0xFF7F8C8D); // Grey
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSurface = Color(0xFF2C3E50);

  // Icon Colors
  static const Color icon = Color(0xFF555555); // Dark Grey for icons
  static const Color iconOnPrimary = Color(0xFFFFFFFF);

  // Border Colors
  static const Color border = Color(0xFFD6DBDF); // Light Grey-Blue
  static const Color borderFocused = primary;

  // UI Elements
  static const Color onlineIndicator = success;
  static const Color offlineIndicator = textSecondary;
  static const Color unreadBadgeBackground = secondary; // Using accent color
  static const Color unreadBadgeText = textOnPrimary;
  static const Color avatarBackground = primaryVariant;
  static const Color avatarText = textOnPrimary;

  // Component Colors
  static const Color appBarBackground = surface;
  static const Color searchBarBackground = surfaceVariant;
  static const Color mainContentBackground = background;
  static const Color dialogBackground = surface;
  static const Color fabBackground = primary;
  static const Color fabIcon = textOnPrimary;

  // List Items
  static const Color listItemSelected = Color(0xFFE0F2F1); // Light Teal tint
  static const Color listItemUnselected = surface;

  // Additional Colors
  static const Color highlight = Color(0x15008080); // Primary with 8% opacity
  static const Color splash = Color(0x1A008080); // Primary with 10% opacity
  static const Color divider = Color(0xFFECF0F1);

  // Specific UI elements if needed
  static const Color logoBackground = primary;
  static const Color logoIcon = textOnPrimary;
}

class AppColorsDark {
  // Primary Colors (Teal - slightly lighter for dark theme)
  static const Color primary = Color(
    0xFF00A0A0,
  ); // Brighter Teal for visibility
  static const Color primaryVariant = Color(
    0xFF008080,
  ); // Original teal becomes variant
  static const Color secondary = Color(0xFFFF7B4D); // Slightly lighter orange
  static const Color tertiary = Color(0xFF7D5FA8); // Lighter purple

  // Background & Surface Colors
  static const Color background = Color(0xFF121212); // Dark grey
  static const Color surface = Color(0xFF1E1E1E); // Slightly lighter dark
  static const Color surfaceVariant = Color(0xFF252525); // Even lighter dark

  // Status Colors (more vibrant for dark theme)
  static const Color error = Color(0xFFFF6659); // Brighter red
  static const Color success = Color(0xFF4CD964); // Brighter green
  static const Color warning = Color(0xFFFFCC00); // Brighter yellow
  static const Color info = Color(0xFF5AC8FA); // Brighter blue

  // Text Colors
  static const Color textPrimary = Color(0xFFE1E1E1); // Light grey
  static const Color textSecondary = Color(0xFFA0A0A0); // Medium grey
  // static const Color textOnPrimary = Color(0xFF000000); // Black on primary
  static const Color textOnPrimary = Color(0xFFFFFFFF); // Black on primary
  static const Color textOnSurface = Color(0xFFE1E1E1);

  // Icon Colors (darker in light areas, lighter in dark areas)
  static const Color icon = Color(0xFFB0B0B0); // Light grey for dark bg
  static const Color iconOnPrimary = Color(0xFF000000); // Dark icons on primary

  // Border Colors
  static const Color border = Color(0xFF333333); // Dark grey
  static const Color borderFocused = primary;

  // UI Elements
  static const Color onlineIndicator = success;
  static const Color offlineIndicator = Color(0xFF666666);
  static const Color unreadBadgeBackground = secondary;
  static const Color unreadBadgeText = textOnPrimary;
  static const Color avatarBackground = primaryVariant;
  static const Color avatarText = textOnPrimary;

  // Component Colors
  static const Color appBarBackground = surface;
  static const Color searchBarBackground = Color(0xFF2A2A2A);
  static const Color mainContentBackground = background;
  static const Color dialogBackground = surface;
  static const Color fabBackground = primary;
  static const Color fabIcon = textOnPrimary;

  // List Items
  static const Color listItemSelected = Color(0xFF2D3E3E); // Dark teal tint
  static const Color listItemUnselected = surface;

  // Additional Colors
  static const Color highlight = Color(0x1A00A0A0); // Primary with 10% opacity
  static const Color splash = Color(0x3300A0A0); // Primary with 20% opacity
  static const Color divider = Color(0xFF333333);

  // Darker Icons Variants
  static const Color iconDark = Color(0xFF8E8E8E); // For less important icons
  static const Color iconDarker = Color(0xFF757575); // For disabled icons
  static const Color iconDarkest = Color(0xFF5E5E5E); // For very subtle icons

  // Specific UI elements if needed
  static const Color logoBackground = primary;
  static const Color logoIcon = textOnPrimary;
}
