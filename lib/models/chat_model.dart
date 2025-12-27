import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firebase_constants.dart';

/// Chat model representing a conversation.
class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final bool isGroupChat;
  final String? groupName;
  final String? groupAvatar;
  final List<String>? adminIds;
  final DateTime? createdAt;

  const ChatModel({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.isGroupChat = false,
    this.groupName,
    this.groupAvatar,
    this.adminIds,
    this.createdAt,
  });

  /// Create ChatModel from Firestore document
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data[FirebaseConstants.chatParticipants] ?? []),
      participantNames: Map<String, String>.from(data[FirebaseConstants.chatParticipantNames] ?? {}),
      lastMessage: data[FirebaseConstants.chatLastMessage] ?? '',
      lastMessageTime: (data[FirebaseConstants.chatLastMessageTime] as Timestamp?)?.toDate(),
      lastMessageSenderId: data[FirebaseConstants.chatLastMessageSenderId] ?? '',
      isGroupChat: data[FirebaseConstants.chatIsGroupChat] ?? false,
      groupName: data[FirebaseConstants.chatGroupName],
      groupAvatar: data[FirebaseConstants.chatGroupAvatar],
      adminIds: data[FirebaseConstants.chatAdminIds] != null
          ? List<String>.from(data[FirebaseConstants.chatAdminIds])
          : null,
      createdAt: (data[FirebaseConstants.chatCreatedAt] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.chatParticipants: participants,
      FirebaseConstants.chatParticipantNames: participantNames,
      FirebaseConstants.chatLastMessage: lastMessage,
      FirebaseConstants.chatLastMessageTime: lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      FirebaseConstants.chatLastMessageSenderId: lastMessageSenderId,
      FirebaseConstants.chatIsGroupChat: isGroupChat,
      if (groupName != null) FirebaseConstants.chatGroupName: groupName,
      if (groupAvatar != null) FirebaseConstants.chatGroupAvatar: groupAvatar,
      if (adminIds != null) FirebaseConstants.chatAdminIds: adminIds,
      FirebaseConstants.chatCreatedAt: createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Get the display name for the chat
  String getDisplayName(String currentUserId) {
    if (isGroupChat) {
      return groupName ?? 'Group Chat';
    }
    // For 1-on-1 chats, return the other user's name
    for (var entry in participantNames.entries) {
      if (entry.key != currentUserId) {
        return entry.value;
      }
    }
    return 'Chat';
  }

  /// Get the other user's ID in a 1-on-1 chat
  String? getOtherUserId(String currentUserId) {
    if (isGroupChat) return null;
    for (var userId in participants) {
      if (userId != currentUserId) {
        return userId;
      }
    }
    return null;
  }

  /// Check if user is admin (for group chats)
  bool isAdmin(String userId) {
    if (!isGroupChat) return false;
    return adminIds?.contains(userId) ?? false;
  }

  ChatModel copyWith({
    String? id,
    List<String>? participants,
    Map<String, String>? participantNames,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    bool? isGroupChat,
    String? groupName,
    String? groupAvatar,
    List<String>? adminIds,
    DateTime? createdAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      groupName: groupName ?? this.groupName,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      adminIds: adminIds ?? this.adminIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ChatModel(id: $id, isGroup: $isGroupChat)';
}
