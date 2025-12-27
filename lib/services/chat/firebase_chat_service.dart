import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firebase_constants.dart';
import 'chat_service.dart';

/// Firebase implementation of [ChatService].
class FirebaseChatService implements ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection(FirebaseConstants.chatsCollection);

  @override
  Stream<QuerySnapshot> getChatsStream(String userId) {
    return _chatsCollection
        .where(FirebaseConstants.chatParticipants, arrayContains: userId)
        .orderBy(FirebaseConstants.chatLastMessageTime, descending: true)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .orderBy(FirebaseConstants.messageTimestamp, descending: false)
        .snapshots();
  }

  @override
  Future<DocumentSnapshot> getChat(String chatId) {
    return _chatsCollection.doc(chatId).get();
  }

  @override
  Future<String> createIndividualChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    // Check if chat already exists
    final existingChatId = await findExistingChat(currentUserId, otherUserId);
    if (existingChatId != null) {
      return existingChatId;
    }

    // Create new chat
    final newChat = await _chatsCollection.add({
      FirebaseConstants.chatParticipants: [currentUserId, otherUserId],
      FirebaseConstants.chatParticipantNames: {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      },
      FirebaseConstants.chatIsGroupChat: false,
      FirebaseConstants.chatLastMessage: '',
      FirebaseConstants.chatLastMessageTime: FieldValue.serverTimestamp(),
      FirebaseConstants.chatLastMessageSenderId: '',
      FirebaseConstants.chatCreatedAt: FieldValue.serverTimestamp(),
    });

    return newChat.id;
  }

  @override
  Future<String> createGroupChat({
    required String creatorId,
    required String creatorName,
    required String groupName,
    required List<String> participantIds,
    required Map<String, String> participantNames,
  }) async {
    final newChat = await _chatsCollection.add({
      FirebaseConstants.chatParticipants: participantIds,
      FirebaseConstants.chatParticipantNames: participantNames,
      FirebaseConstants.chatIsGroupChat: true,
      FirebaseConstants.chatGroupName: groupName,
      FirebaseConstants.chatGroupAvatar: '',
      FirebaseConstants.chatAdminIds: [creatorId],
      FirebaseConstants.chatLastMessage: '$creatorName created this group',
      FirebaseConstants.chatLastMessageTime: FieldValue.serverTimestamp(),
      FirebaseConstants.chatLastMessageSenderId: creatorId,
      FirebaseConstants.chatCreatedAt: FieldValue.serverTimestamp(),
    });

    return newChat.id;
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String message,
    String messageType = AppConstants.messageTypeText,
  }) async {
    final batch = _firestore.batch();

    // Add message
    final messageRef = _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .doc();

    batch.set(messageRef, {
      FirebaseConstants.messageContent: message,
      FirebaseConstants.messageSender: senderId,
      FirebaseConstants.messageSenderName: senderName,
      FirebaseConstants.messageTimestamp: FieldValue.serverTimestamp(),
      FirebaseConstants.messageReadBy: [senderId],
      FirebaseConstants.messageType: messageType,
    });

    // Update chat with last message
    batch.update(_chatsCollection.doc(chatId), {
      FirebaseConstants.chatLastMessage: message,
      FirebaseConstants.chatLastMessageTime: FieldValue.serverTimestamp(),
      FirebaseConstants.chatLastMessageSenderId: senderId,
    });

    await batch.commit();
  }

  @override
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final messagesSnapshot = await _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      final readBy = (doc.data()[FirebaseConstants.messageReadBy] as List?)
              ?.cast<String>() ??
          [];
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          FirebaseConstants.messageReadBy: FieldValue.arrayUnion([userId]),
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<int> getUnreadCount(String chatId, String userId) async {
    final messagesSnapshot = await _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .get();

    int unreadCount = 0;
    for (var doc in messagesSnapshot.docs) {
      final readBy = (doc.data()[FirebaseConstants.messageReadBy] as List?)
              ?.cast<String>() ??
          [];
      if (!readBy.contains(userId)) {
        unreadCount++;
      }
    }
    return unreadCount;
  }

  @override
  Future<DocumentSnapshot?> getLastMessage(String chatId) async {
    final messagesSnapshot = await _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .orderBy(FirebaseConstants.messageTimestamp, descending: true)
        .limit(1)
        .get();

    if (messagesSnapshot.docs.isEmpty) return null;
    return messagesSnapshot.docs.first;
  }

  @override
  Future<void> updateTypingStatus({
    required String chatId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    await _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.typingSubcollection)
        .doc(userId)
        .set({
      FirebaseConstants.typingIsTyping: isTyping,
      FirebaseConstants.typingTimestamp: FieldValue.serverTimestamp(),
      FirebaseConstants.typingUserName: userName,
    });
  }

  @override
  Stream<QuerySnapshot> getTypingStatusStream(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.typingSubcollection)
        .snapshots();
  }

  @override
  Future<String?> findExistingChat(String userId1, String userId2) async {
    final query = await _chatsCollection
        .where(FirebaseConstants.chatParticipants, arrayContains: userId1)
        .where(FirebaseConstants.chatIsGroupChat, isEqualTo: false)
        .get();

    for (var doc in query.docs) {
      final participants =
          (doc.data()[FirebaseConstants.chatParticipants] as List)
              .cast<String>();
      if (participants.contains(userId2)) {
        return doc.id;
      }
    }
    return null;
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .doc(messageId)
        .delete();
  }

  @override
  Future<void> editMessage(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    await _chatsCollection
        .doc(chatId)
        .collection(FirebaseConstants.messagesSubcollection)
        .doc(messageId)
        .update({
      FirebaseConstants.messageContent: newContent,
      'editedAt': FieldValue.serverTimestamp(),
      'isEdited': true,
    });
  }
}
