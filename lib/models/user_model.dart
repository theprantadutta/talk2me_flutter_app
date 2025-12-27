import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_constants.dart';

/// User model representing a user in the app.
class UserModel {
  final String uid;
  final String fullName;
  final String username;
  final String email;
  final String avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? authProvider;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    this.avatarUrl = '',
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
    this.authProvider,
  });

  /// Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data[FirebaseConstants.userFullName] ?? '',
      username: data[FirebaseConstants.userUsername] ?? '',
      email: data[FirebaseConstants.userEmail] ?? '',
      avatarUrl: data[FirebaseConstants.userAvatarUrl] ?? '',
      isOnline: data[FirebaseConstants.userIsOnline] ?? false,
      lastSeen: (data[FirebaseConstants.userLastSeen] as Timestamp?)?.toDate(),
      createdAt: (data[FirebaseConstants.userCreatedAt] as Timestamp?)?.toDate(),
      updatedAt: (data[FirebaseConstants.userUpdatedAt] as Timestamp?)?.toDate(),
      authProvider: data[FirebaseConstants.userAuthProvider],
    );
  }

  /// Create UserModel from Map (for JSON parsing)
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      fullName: data[FirebaseConstants.userFullName] ?? '',
      username: data[FirebaseConstants.userUsername] ?? '',
      email: data[FirebaseConstants.userEmail] ?? '',
      avatarUrl: data[FirebaseConstants.userAvatarUrl] ?? '',
      isOnline: data[FirebaseConstants.userIsOnline] ?? false,
      lastSeen: data[FirebaseConstants.userLastSeen] is Timestamp
          ? (data[FirebaseConstants.userLastSeen] as Timestamp).toDate()
          : null,
      createdAt: data[FirebaseConstants.userCreatedAt] is Timestamp
          ? (data[FirebaseConstants.userCreatedAt] as Timestamp).toDate()
          : null,
      updatedAt: data[FirebaseConstants.userUpdatedAt] is Timestamp
          ? (data[FirebaseConstants.userUpdatedAt] as Timestamp).toDate()
          : null,
      authProvider: data[FirebaseConstants.userAuthProvider],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.userUid: uid,
      FirebaseConstants.userFullName: fullName,
      FirebaseConstants.userUsername: username,
      FirebaseConstants.userEmail: email,
      FirebaseConstants.userAvatarUrl: avatarUrl,
      FirebaseConstants.userIsOnline: isOnline,
      FirebaseConstants.userLastSeen: lastSeen != null
          ? Timestamp.fromDate(lastSeen!)
          : FieldValue.serverTimestamp(),
      FirebaseConstants.userCreatedAt: createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      FirebaseConstants.userUpdatedAt: FieldValue.serverTimestamp(),
      if (authProvider != null) FirebaseConstants.userAuthProvider: authProvider,
    };
  }

  /// Create a copy with some fields changed
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? username,
    String? email,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authProvider,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  /// Get initials for avatar fallback
  String get initials {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'UserModel(uid: $uid, fullName: $fullName)';
}
