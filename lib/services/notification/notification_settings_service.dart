import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notification settings model
class NotificationPreferences {
  final bool enabled;
  final bool showPreview;
  final bool sound;
  final bool vibration;
  final List<String> mutedChats;

  const NotificationPreferences({
    this.enabled = true,
    this.showPreview = true,
    this.sound = true,
    this.vibration = true,
    this.mutedChats = const [],
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      enabled: map['enabled'] ?? true,
      showPreview: map['showPreview'] ?? true,
      sound: map['sound'] ?? true,
      vibration: map['vibration'] ?? true,
      mutedChats: List<String>.from(map['mutedChats'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'showPreview': showPreview,
      'sound': sound,
      'vibration': vibration,
      'mutedChats': mutedChats,
    };
  }

  NotificationPreferences copyWith({
    bool? enabled,
    bool? showPreview,
    bool? sound,
    bool? vibration,
    List<String>? mutedChats,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      showPreview: showPreview ?? this.showPreview,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      mutedChats: mutedChats ?? this.mutedChats,
    );
  }

  /// Check if a specific chat is muted
  bool isChatMuted(String chatId) => mutedChats.contains(chatId);
}

/// Service for managing notification settings
class NotificationSettingsService {
  static const String _prefsKey = 'notification_preferences';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;

  NotificationPreferences _preferences = const NotificationPreferences();
  NotificationPreferences get preferences => _preferences;

  /// Initialize with user ID
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _loadPreferences();
  }

  /// Load preferences from local storage and Firestore
  Future<void> _loadPreferences() async {
    try {
      // First try to load from local storage for faster startup
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString(_prefsKey);

      if (localData != null) {
        // Parse local preferences (simplified - would need JSON parsing)
        // For now, we'll just use Firestore
      }

      // Then sync with Firestore
      if (_currentUserId != null) {
        final doc = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('settings')
            .doc('notifications')
            .get();

        if (doc.exists) {
          _preferences = NotificationPreferences.fromMap(doc.data()!);
        }
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  /// Save preferences to Firestore
  Future<void> _savePreferences() async {
    if (_currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('settings')
          .doc('notifications')
          .set(_preferences.toMap());
    } catch (e) {
      debugPrint('Error saving notification preferences: $e');
    }
  }

  /// Toggle notifications enabled
  Future<void> setEnabled(bool enabled) async {
    _preferences = _preferences.copyWith(enabled: enabled);
    await _savePreferences();
  }

  /// Toggle show preview
  Future<void> setShowPreview(bool showPreview) async {
    _preferences = _preferences.copyWith(showPreview: showPreview);
    await _savePreferences();
  }

  /// Toggle sound
  Future<void> setSound(bool sound) async {
    _preferences = _preferences.copyWith(sound: sound);
    await _savePreferences();
  }

  /// Toggle vibration
  Future<void> setVibration(bool vibration) async {
    _preferences = _preferences.copyWith(vibration: vibration);
    await _savePreferences();
  }

  /// Mute a chat
  Future<void> muteChat(String chatId) async {
    if (!_preferences.mutedChats.contains(chatId)) {
      final updatedList = [..._preferences.mutedChats, chatId];
      _preferences = _preferences.copyWith(mutedChats: updatedList);
      await _savePreferences();
    }
  }

  /// Unmute a chat
  Future<void> unmuteChat(String chatId) async {
    if (_preferences.mutedChats.contains(chatId)) {
      final updatedList = _preferences.mutedChats.where((id) => id != chatId).toList();
      _preferences = _preferences.copyWith(mutedChats: updatedList);
      await _savePreferences();
    }
  }

  /// Toggle chat mute status
  Future<void> toggleChatMute(String chatId) async {
    if (_preferences.isChatMuted(chatId)) {
      await unmuteChat(chatId);
    } else {
      await muteChat(chatId);
    }
  }

  /// Check if notifications should be shown for a chat
  bool shouldShowNotification(String chatId) {
    return _preferences.enabled && !_preferences.isChatMuted(chatId);
  }
}
