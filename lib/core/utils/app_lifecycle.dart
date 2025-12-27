import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manages app lifecycle events and user presence
class AppLifecycleManager extends WidgetsBindingObserver {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppLifecycleManager({required this.userId});

  /// Start observing lifecycle events
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _updateOnlineStatus(true);
  }

  /// Stop observing lifecycle events
  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _updateOnlineStatus(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _updateOnlineStatus(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _updateOnlineStatus(false);
        break;
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }
}

/// Connectivity status helper
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// App info utilities
class AppInfo {
  AppInfo._();

  /// Check if running in debug mode
  static bool get isDebug => kDebugMode;

  /// Check if running in release mode
  static bool get isRelease => kReleaseMode;

  /// Check if running in profile mode
  static bool get isProfile => kProfileMode;

  /// Get the current platform
  static String get platform {
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }

  /// Check if running on mobile
  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Check if running on desktop
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}
