import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String? id;
  final String message;
  final String sender;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final bool isEdited;
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToSenderName;
  final List<String> readBy;
  final MessageStatus status;

  ChatMessage({
    this.id,
    required this.message,
    required this.sender,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
    this.isEdited = false,
    this.replyToId,
    this.replyToMessage,
    this.replyToSenderName,
    this.readBy = const [],
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>;
    final senderId = data['sender'] ?? '';
    final readByList = (data['readBy'] as List?)?.cast<String>() ?? [];

    MessageStatus status = MessageStatus.sent;
    if (senderId == currentUserId) {
      if (readByList.length > 1) {
        status = MessageStatus.read;
      } else if (readByList.isNotEmpty) {
        status = MessageStatus.delivered;
      }
    }

    return ChatMessage(
      id: doc.id,
      message: data['message'] ?? '',
      sender: senderId,
      senderName: data['senderName'] ?? 'Unknown',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: senderId == currentUserId,
      isEdited: data['isEdited'] ?? false,
      replyToId: data['replyToId'],
      replyToMessage: data['replyToMessage'],
      replyToSenderName: data['replyToSenderName'],
      readBy: readByList,
      status: status,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'sender': sender,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': isEdited,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToMessage != null) 'replyToMessage': replyToMessage,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      'readBy': readBy,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? message,
    String? sender,
    String? senderName,
    DateTime? timestamp,
    bool? isMe,
    bool? isEdited,
    String? replyToId,
    String? replyToMessage,
    String? replyToSenderName,
    List<String>? readBy,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      sender: sender ?? this.sender,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      isEdited: isEdited ?? this.isEdited,
      replyToId: replyToId ?? this.replyToId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      readBy: readBy ?? this.readBy,
      status: status ?? this.status,
    );
  }

  /// Check if message can be edited (within 15 minutes)
  bool get canEdit {
    if (!isMe) return false;
    final diff = DateTime.now().difference(timestamp);
    return diff.inMinutes < 15;
  }

  /// Check if message can be deleted for everyone (within 1 hour)
  bool get canDeleteForEveryone {
    if (!isMe) return false;
    final diff = DateTime.now().difference(timestamp);
    return diff.inHours < 1;
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}
