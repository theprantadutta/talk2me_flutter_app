import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// App-specific exceptions
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error. Please check your connection.'])
      : super(code: 'network_error');
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// Error handler utility
class ErrorHandler {
  ErrorHandler._();

  /// Convert Firebase Auth errors to user-friendly messages
  static String getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Convert Firestore errors to user-friendly messages
  static String getFirestoreErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'already-exists':
        return 'This data already exists.';
      case 'resource-exhausted':
        return 'Too many requests. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      case 'cancelled':
        return 'Operation cancelled.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  /// Get user-friendly error message from any exception
  static String getMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return getAuthErrorMessage(error);
    }

    if (error is FirebaseException) {
      return getFirestoreErrorMessage(error);
    }

    if (error is AppException) {
      return error.message;
    }

    if (error is NetworkException) {
      return error.message;
    }

    // Check for common error patterns
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your connection.';
    }

    if (errorString.contains('permission')) {
      return 'Permission denied.';
    }

    return 'An unexpected error occurred. Please try again.';
  }

  /// Show error in a snackbar
  static void showError(BuildContext context, dynamic error) {
    final message = getMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success message in a snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  /// Wrap an async operation with error handling
  static Future<T?> handle<T>(
    Future<T> Function() operation, {
    BuildContext? context,
    String? errorMessage,
    VoidCallback? onError,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (context != null && context.mounted) {
        showError(context, errorMessage ?? e);
      }
      onError?.call();
      return null;
    }
  }
}
