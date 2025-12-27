import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import 'user_service.dart';

/// Firebase implementation of [UserService].
class FirebaseUserService implements UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(FirebaseConstants.usersCollection);

  @override
  Stream<DocumentSnapshot> getUserStream(String userId) {
    return _usersCollection.doc(userId).snapshots();
  }

  @override
  Future<DocumentSnapshot> getUser(String userId) {
    return _usersCollection.doc(userId).get();
  }

  @override
  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String username,
    required String email,
    String? avatarUrl,
    String? authProvider,
  }) async {
    await _usersCollection.doc(uid).set({
      FirebaseConstants.userUid: uid,
      FirebaseConstants.userFullName: fullName,
      FirebaseConstants.userUsername: username.toLowerCase(),
      FirebaseConstants.userEmail: email,
      FirebaseConstants.userAvatarUrl: avatarUrl ?? '',
      FirebaseConstants.userIsOnline: true,
      FirebaseConstants.userLastSeen: FieldValue.serverTimestamp(),
      FirebaseConstants.userCreatedAt: FieldValue.serverTimestamp(),
      FirebaseConstants.userUpdatedAt: FieldValue.serverTimestamp(),
      if (authProvider != null) FirebaseConstants.userAuthProvider: authProvider,
    });
  }

  @override
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    data[FirebaseConstants.userUpdatedAt] = FieldValue.serverTimestamp();
    await _usersCollection.doc(userId).update(data);
  }

  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _usersCollection.doc(userId).update({
      FirebaseConstants.userIsOnline: isOnline,
      FirebaseConstants.userLastSeen: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final query = await _usersCollection
        .where(FirebaseConstants.userUsername, isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  @override
  Stream<QuerySnapshot> getAllUsersStream(String currentUserId) {
    return _usersCollection
        .where(FieldPath.documentId, isNotEqualTo: currentUserId)
        .snapshots();
  }

  @override
  Future<QuerySnapshot> searchUsers(String query, String currentUserId) async {
    // Note: Firestore doesn't support full-text search natively.
    // For production, consider Algolia or Cloud Functions with ElasticSearch.
    // This implementation does a basic prefix search on fullName.
    return _usersCollection
        .where(FieldPath.documentId, isNotEqualTo: currentUserId)
        .orderBy(FirebaseConstants.userFullName)
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();
  }
}
