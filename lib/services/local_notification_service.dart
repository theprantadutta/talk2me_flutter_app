import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('app_icon');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: 'Open notification');

      const WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
            appName: 'Talk 2 Me',
            appUserModelId: 'com.pranta.talk2me',
            guid: '169ef813-9414-4c5e-9537-6deeb8e0ea62',
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin,
            linux: initializationSettingsLinux,
            windows: initializationSettingsWindows,
          );

      await notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            onDidReceiveBackgroundNotificationResponse,
      );

      // Create notification channels (Android 8.0+)
      await _createNotificationChannels();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  static Future<void> _createNotificationChannels() async {
    // Android notification channel
    const AndroidNotificationChannel androidChannel =
        AndroidNotificationChannel(
          'talk2me_id',
          'Instant Notifications',
          description: 'Instant notification channel',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await notificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'talk2me_id',
            'Instant Notifications',
            channelDescription: 'Instant notification channel',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            colorized: true,
            color: Colors.blue,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  // iOS specific notification handler
  static Future<void> onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    debugPrint('Received local notification: $title - $body');
    // Handle iOS notification when app is in foreground
  }

  // Notification tapped handler (app in foreground)
  static Future<void> onDidReceiveNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap when app is in foreground
  }

  // Background notification handler (app in background/terminated)
  static Future<void> onDidReceiveBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint('Background notification tapped: ${response.payload}');
    // Handle notification tap when app is in background
  }

  // Additional useful methods
  static Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await notificationsPlugin.pendingNotificationRequests();
  }
}
