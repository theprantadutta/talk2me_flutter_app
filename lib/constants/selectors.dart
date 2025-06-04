import 'package:flutter/material.dart';

const String kIsDarkModeKey = 'isDarkMode';

LinearGradient getDefaultGradient(Color mainHelper, Color helperColor) =>
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.1, 0.9],
      colors: [mainHelper, helperColor],
    );
