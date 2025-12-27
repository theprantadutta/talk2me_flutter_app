import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstract user service interface.
abstract class UserService {
  /// Get a stream of user data by ID
  Stream<DocumentSnapshot> getUserStream(String userId);

  /// Get user data by ID (one-time fetch)
  Future<DocumentSnapshot> getUser(String userId);

  /// Create a new user profile
  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String username,
    required String email,
    String? avatarUrl,
    String? authProvider,
  });

  /// Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data);

  /// Update user online status
  Future<void> updateOnlineStatus(String userId, bool isOnline);

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username);

  /// Get all users stream (excluding current user)
  Stream<QuerySnapshot> getAllUsersStream(String currentUserId);

  /// Search users by name
  Future<QuerySnapshot> searchUsers(String query, String currentUserId);
}
