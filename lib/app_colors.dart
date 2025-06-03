// import 'package:flutter/material.dart';

// class AppColors {
//   static const Color primary = Color(0xFF007BFF); // Vibrant Blue
//   static const Color primaryVariant = Color(0xFF0056b3); // Darker Blue
//   static const Color secondary = Color(0xFFFF8C00); // Dark Orange (for accents)

//   static const Color background = Color(0xFFF8F9FA); // Very Light Grey
//   static const Color surface = Color(
//     0xFFFFFFFF,
//   ); // White (for cards, text fields)
//   static const Color surfaceVariant = Color(
//     0xFFF1F3F5,
//   ); // Slightly darker white/grey for selected items or hover

//   static const Color error = Color(0xFFDC3545); // Standard Red
//   static const Color success = Color(0xFF28A745); // Standard Green

//   static const Color textPrimary = Color(0xFF212529); // Almost Black
//   static const Color textSecondary = Color(0xFF6C757D); // Grey
//   static const Color textOnPrimary = Color(
//     0xFFFFFFFF,
//   ); // Text on primary color background
//   static const Color textOnSurface = Color(
//     0xFF212529,
//   ); // Text on surface color background

//   static const Color icon = Color(0xFF495057); // Darker Grey for icons
//   static const Color iconOnPrimary = Color(
//     0xFFFFFFFF,
//   ); // Icons on primary color background

//   static const Color border = Color(0xFFDEE2E6); // Light Grey for borders
//   static const Color borderFocused = primary;

//   // Specific UI elements
//   static const Color onlineIndicator = success;
//   static const Color offlineIndicator = textSecondary;
//   static const Color unreadBadgeBackground = primary;
//   static const Color unreadBadgeText = textOnPrimary;
//   static const Color avatarBackground = primary;
//   static const Color avatarText = textOnPrimary;

//   static const Color appBarBackground = surface;
//   static const Color searchBarBackground = surface;
//   static const Color mainContentBackground = surface;
//   static const Color dialogBackground = surface;
//   static const Color fabBackground = primary;
//   static const Color fabIcon = textOnPrimary;

//   static const Color listItemSelected =
//       primaryVariant; // Example for selected items
//   static const Color listItemUnselected = surface;

//   // Specific UI elements if needed
//   static const Color logoBackground = primary;
//   static const Color logoIcon = textOnPrimary;
// }

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
