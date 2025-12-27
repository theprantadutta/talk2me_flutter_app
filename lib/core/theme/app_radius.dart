import 'package:flutter/material.dart';

/// Border radius constants for consistent rounded corners.
abstract class AppRadius {
  // Radius values
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  // Common border radius
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius avatarRadius = BorderRadius.all(Radius.circular(full));

  // Message bubble radius
  static const BorderRadius messageBubbleSent = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
    bottomLeft: Radius.circular(lg),
    bottomRight: Radius.circular(xs),
  );
  static const BorderRadius messageBubbleReceived = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
    bottomLeft: Radius.circular(xs),
    bottomRight: Radius.circular(lg),
  );
}
