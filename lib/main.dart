import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'constants/selectors.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const Talk2MeApp());
}

class Talk2MeApp extends StatefulWidget {
  const Talk2MeApp({super.key});

  @override
  State<Talk2MeApp> createState() => _Talk2MeAppState();

  //https://gist.github.com/ben-xx/10000ed3bf44e0143cf0fe7ac5648254
  // ignore: library_private_types_in_public_api
  static _Talk2MeAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_Talk2MeAppState>()!;
}

class _Talk2MeAppState extends State<Talk2MeApp> {
  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _sharedPreferences;

  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    initializeSharedPreferences();
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
      _sharedPreferences?.setBool(kIsDarkModeKey, themeMode == ThemeMode.dark);
    });
  }

  void initializeSharedPreferences() async {
    try {
      _sharedPreferences = await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing SharedPreferences: $e');
      }
    }
    final isDarkMode = _sharedPreferences?.getBool(kIsDarkModeKey);
    if (isDarkMode != null) {
      setState(
        () => _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk 2 Me',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      home: AuthGate(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryVariant,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.tertiary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textOnSurface,
        onError: AppColors.textOnPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.fabBackground,
        foregroundColor: AppColors.fabIcon,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textPrimary),
        displayMedium: TextStyle(color: AppColors.textPrimary),
        displaySmall: TextStyle(color: AppColors.textPrimary),
        headlineLarge: TextStyle(color: AppColors.textPrimary),
        headlineMedium: TextStyle(color: AppColors.textPrimary),
        headlineSmall: TextStyle(color: AppColors.textPrimary),
        titleLarge: TextStyle(color: AppColors.textPrimary),
        titleMedium: TextStyle(color: AppColors.textPrimary),
        titleSmall: TextStyle(color: AppColors.textPrimary),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        labelLarge: TextStyle(color: AppColors.textOnPrimary),
        labelMedium: TextStyle(color: AppColors.textSecondary),
        labelSmall: TextStyle(color: AppColors.textSecondary),
      ),
      iconTheme: const IconThemeData(color: AppColors.icon),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        disabledColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: AppColors.textOnPrimary),
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        primaryContainer: AppColorsDark.primaryVariant,
        secondary: AppColorsDark.secondary,
        secondaryContainer: AppColorsDark.tertiary,
        surface: AppColorsDark.surface,
        error: AppColorsDark.error,
        onPrimary: AppColorsDark.textOnPrimary,
        onSecondary: AppColorsDark.textOnPrimary,
        onSurface: AppColorsDark.textOnSurface,
        onError: AppColorsDark.textOnPrimary,
      ),
      scaffoldBackgroundColor: AppColorsDark.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.appBarBackground,
        foregroundColor: AppColorsDark.textPrimary,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColorsDark.fabBackground,
        foregroundColor: AppColorsDark.fabIcon,
      ),
      cardTheme: const CardThemeData(
        color: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsDark.divider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColorsDark.textPrimary),
        displayMedium: TextStyle(color: AppColorsDark.textPrimary),
        displaySmall: TextStyle(color: AppColorsDark.textPrimary),
        headlineLarge: TextStyle(color: AppColorsDark.textPrimary),
        headlineMedium: TextStyle(color: AppColorsDark.textPrimary),
        headlineSmall: TextStyle(color: AppColorsDark.textPrimary),
        titleLarge: TextStyle(color: AppColorsDark.textPrimary),
        titleMedium: TextStyle(color: AppColorsDark.textPrimary),
        titleSmall: TextStyle(color: AppColorsDark.textPrimary),
        bodyLarge: TextStyle(color: AppColorsDark.textPrimary),
        bodyMedium: TextStyle(color: AppColorsDark.textPrimary),
        bodySmall: TextStyle(color: AppColorsDark.textSecondary),
        labelLarge: TextStyle(color: AppColorsDark.textOnPrimary),
        labelMedium: TextStyle(color: AppColorsDark.textSecondary),
        labelSmall: TextStyle(color: AppColorsDark.textSecondary),
      ),
      iconTheme: const IconThemeData(color: AppColorsDark.icon),
      chipTheme: ChipThemeData(
        backgroundColor: AppColorsDark.surfaceVariant,
        disabledColor: AppColorsDark.surfaceVariant,
        selectedColor: AppColorsDark.primary,
        secondarySelectedColor: AppColorsDark.primary,
        padding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(color: AppColorsDark.textPrimary),
        secondaryLabelStyle: const TextStyle(
          color: AppColorsDark.textOnPrimary,
        ),
        brightness: Brightness.dark,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While Firebase is still checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is logged in
        if (snapshot.hasData) {
          final user = snapshot.data!;
          return HomeScreen(currentUserId: user.uid);
        }

        // User is NOT logged in
        return const AuthScreen();
      },
    );
  }
}
