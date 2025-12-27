import '../constants/app_constants.dart';

/// Form field validators.
abstract class Validators {
  /// Validate email address
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate password
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  /// Validate password with confirmation
  static String? confirmPassword(String? value, String? originalPassword) {
    final passwordError = password(value);
    if (passwordError != null) return passwordError;

    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validate username
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > AppConstants.maxUsernameLength) {
      return 'Username must be less than ${AppConstants.maxUsernameLength} characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  /// Validate full name
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    return null;
  }

  /// Validate required field
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate group name
  static String? groupName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Group name is required';
    }
    if (value.length > AppConstants.maxGroupNameLength) {
      return 'Group name must be less than ${AppConstants.maxGroupNameLength} characters';
    }
    return null;
  }

  /// Validate message
  static String? message(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty messages are allowed (just won't send)
    }
    if (value.length > AppConstants.maxMessageLength) {
      return 'Message is too long';
    }
    return null;
  }
}

/// Input sanitization utilities
abstract class Sanitizer {
  /// Remove potentially dangerous HTML/script content
  static String sanitizeText(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();
  }

  /// Sanitize username input
  static String sanitizeUsername(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
  }

  /// Sanitize search query
  static String sanitizeSearchQuery(String input) {
    return input
        .replaceAll(RegExp(r'[^\w\s@.-]'), '')
        .trim();
  }

  /// Sanitize message content
  static String sanitizeMessage(String input) {
    // Remove null bytes and control characters (except newlines and tabs)
    return input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
  }
}
