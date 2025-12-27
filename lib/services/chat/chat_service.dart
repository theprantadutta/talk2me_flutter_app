import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstract chat service interface.
abstract class ChatService {
  /// Get stream of chats for a user
  Stream<QuerySnapshot> getChatsStream(String userId);

  /// Get stream of messages for a chat
  Stream<QuerySnapshot> getMessagesStream(String chatId);

  /// Get a specific chat by ID
  Future<DocumentSnapshot> getChat(String chatId);

  /// Create a new 1-on-1 chat
  Future<String> createIndividualChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  });

  /// Create a new group chat
  Future<String> createGroupChat({
    required String creatorId,
    required String creatorName,
    required String groupName,
    required List<String> participantIds,
    required Map<String, String> participantNames,
  });

  /// Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String message,
    String messageType,
  });

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId);

  /// Get unread message count for a chat
  Future<int> getUnreadCount(String chatId, String userId);

  /// Get the last message for a chat
  Future<DocumentSnapshot?> getLastMessage(String chatId);

  /// Update typing status
  Future<void> updateTypingStatus({
    required String chatId,
    required String userId,
    required String userName,
    required bool isTyping,
  });

  /// Get typing status stream for a chat
  Stream<QuerySnapshot> getTypingStatusStream(String chatId);

  /// Find existing chat between two users
  Future<String?> findExistingChat(String userId1, String userId2);

  /// Delete a message
  Future<void> deleteMessage(String chatId, String messageId);

  /// Edit a message
  Future<void> editMessage(String chatId, String messageId, String newContent);
}
