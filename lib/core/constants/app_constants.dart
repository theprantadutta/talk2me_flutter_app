/// General app constants.
abstract class AppConstants {
  // App info
  static const String appName = 'Talk2Me';
  static const String appTagline = 'Connect and chat with anyone';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxUsernameLength = 30;
  static const int maxMessageLength = 5000;
  static const int maxGroupNameLength = 50;

  // Pagination
  static const int messagesPerPage = 50;
  static const int chatsPerPage = 20;
  static const int usersPerPage = 20;

  // Timeouts
  static const int typingTimeoutSeconds = 5;
  static const int typingStaleSeconds = 7;
  static const int messageEditWindowMinutes = 15;

  // Shared Preferences Keys
  static const String themeModePrefKey = 'isDarkMode';
  static const String fcmTokenPrefKey = 'fcmToken';
  static const String notificationsEnabledKey = 'notificationsEnabled';

  // Asset paths
  static const String logoPath = 'assets/logo.png';
  static const String defaultAvatarPath = 'assets/default_avatar.png';

  // Message types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeVideo = 'video';
  static const String messageTypeAudio = 'audio';
  static const String messageTypeFile = 'file';
}
