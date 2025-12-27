import 'package:flutter/material.dart';

/// Border radius constants for consistent rounded corners.
abstract class AppRadius {
  // Radius values (as doubles for custom usage)
  static const double noneValue = 0.0;
  static const double xsValue = 4.0;
  static const double smValue = 8.0;
  static const double mdValue = 12.0;
  static const double lgValue = 16.0;
  static const double xlValue = 20.0;
  static const double xxlValue = 24.0;
  static const double fullValue = 999.0;

  // BorderRadius presets (use these for widgets)
  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius xs = BorderRadius.all(Radius.circular(xsValue));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(smValue));
  static const BorderRadius md = BorderRadius.all(Radius.circular(mdValue));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(lgValue));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(xlValue));
  static const BorderRadius xxl = BorderRadius.all(Radius.circular(xxlValue));
  static const BorderRadius full = BorderRadius.all(Radius.circular(fullValue));

  // Common border radius (named presets for specific use cases)
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lgValue));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(mdValue));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(mdValue));
  static const BorderRadius dialogRadius = BorderRadius.all(Radius.circular(xlValue));
  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(xlValue),
  );
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(smValue));
  static const BorderRadius avatarRadius = BorderRadius.all(Radius.circular(fullValue));

  // Message bubble radius
  static const BorderRadius messageBubbleSent = BorderRadius.only(
    topLeft: Radius.circular(lgValue),
    topRight: Radius.circular(lgValue),
    bottomLeft: Radius.circular(lgValue),
    bottomRight: Radius.circular(xsValue),
  );
  static const BorderRadius messageBubbleReceived = BorderRadius.only(
    topLeft: Radius.circular(lgValue),
    topRight: Radius.circular(lgValue),
    bottomLeft: Radius.circular(xsValue),
    bottomRight: Radius.circular(lgValue),
  );
}
