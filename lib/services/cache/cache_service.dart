import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple in-memory and persistent cache service
class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  CacheService._();

  final Map<String, _CacheEntry> _memoryCache = {};
  SharedPreferences? _prefs;

  /// Initialize the cache service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get value from cache (memory first, then disk)
  T? get<T>(String key) {
    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return memoryEntry.value as T?;
    }

    // Check disk cache
    if (_prefs != null) {
      final diskValue = _prefs!.getString('cache_$key');
      if (diskValue != null) {
        try {
          final data = jsonDecode(diskValue);
          final expiry = data['expiry'] as int?;
          if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
            // Expired, remove it
            _prefs!.remove('cache_$key');
            return null;
          }
          return data['value'] as T?;
        } catch (e) {
          debugPrint('Cache decode error: $e');
          return null;
        }
      }
    }

    return null;
  }

  /// Set value in cache
  Future<void> set<T>(
    String key,
    T value, {
    Duration? expiry,
    bool persist = false,
  }) async {
    final expiryTime = expiry != null
        ? DateTime.now().add(expiry).millisecondsSinceEpoch
        : null;

    // Store in memory
    _memoryCache[key] = _CacheEntry(
      value: value,
      expiryTime: expiryTime,
    );

    // Optionally persist to disk
    if (persist && _prefs != null) {
      final data = jsonEncode({
        'value': value,
        'expiry': expiryTime,
      });
      await _prefs!.setString('cache_$key', data);
    }
  }

  /// Remove a specific key from cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove('cache_$key');
  }

  /// Clear all memory cache
  void clearMemory() {
    _memoryCache.clear();
  }

  /// Clear all cache (memory and disk)
  Future<void> clearAll() async {
    _memoryCache.clear();

    if (_prefs != null) {
      final keys = _prefs!.getKeys().where((k) => k.startsWith('cache_'));
      for (final key in keys) {
        await _prefs!.remove(key);
      }
    }
  }

  /// Get or compute a cached value
  Future<T> getOrCompute<T>(
    String key,
    Future<T> Function() compute, {
    Duration? expiry,
    bool persist = false,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final value = await compute();
    await set(key, value, expiry: expiry, persist: persist);
    return value;
  }

  /// Clean up expired entries from memory
  void cleanupExpired() {
    _memoryCache.removeWhere((_, entry) => entry.isExpired);
  }
}

class _CacheEntry {
  final dynamic value;
  final int? expiryTime;

  _CacheEntry({
    required this.value,
    this.expiryTime,
  });

  bool get isExpired {
    if (expiryTime == null) return false;
    return DateTime.now().millisecondsSinceEpoch > expiryTime!;
  }
}

/// Cache keys used throughout the app
class CacheKeys {
  CacheKeys._();

  static const String userProfile = 'user_profile';
  static const String chatList = 'chat_list';
  static const String notificationSettings = 'notification_settings';

  static String chatMessages(String chatId) => 'messages_$chatId';
  static String userInfo(String userId) => 'user_$userId';
}
