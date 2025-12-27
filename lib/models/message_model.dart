import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firebase_constants.dart';

/// Message model representing a chat message.
class MessageModel {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime? timestamp;
  final List<String> readBy;
  final String messageType;
  final String? mediaUrl;
  final bool isEdited;
  final DateTime? editedAt;

  const MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.timestamp,
    this.readBy = const [],
    this.messageType = AppConstants.messageTypeText,
    this.mediaUrl,
    this.isEdited = false,
    this.editedAt,
  });

  /// Create MessageModel from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      content: data[FirebaseConstants.messageContent] ?? '',
      senderId: data[FirebaseConstants.messageSender] ?? '',
      senderName: data[FirebaseConstants.messageSenderName] ?? '',
      timestamp: (data[FirebaseConstants.messageTimestamp] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data[FirebaseConstants.messageReadBy] ?? []),
      messageType: data[FirebaseConstants.messageType] ?? AppConstants.messageTypeText,
      mediaUrl: data[FirebaseConstants.messageMediaUrl],
      isEdited: data['isEdited'] ?? false,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.messageContent: content,
      FirebaseConstants.messageSender: senderId,
      FirebaseConstants.messageSenderName: senderName,
      FirebaseConstants.messageTimestamp: timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
      FirebaseConstants.messageReadBy: readBy,
      FirebaseConstants.messageType: messageType,
      if (mediaUrl != null) FirebaseConstants.messageMediaUrl: mediaUrl,
      'isEdited': isEdited,
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
    };
  }

  /// Check if message is from a specific user
  bool isFromUser(String userId) => senderId == userId;

  /// Check if message has been read by a specific user
  bool isReadBy(String userId) => readBy.contains(userId);

  /// Check if message is a media message
  bool get isMediaMessage =>
      messageType != AppConstants.messageTypeText && mediaUrl != null;

  /// Check if message is an image
  bool get isImage => messageType == AppConstants.messageTypeImage;

  /// Check if message is a video
  bool get isVideo => messageType == AppConstants.messageTypeVideo;

  /// Check if message is an audio/voice message
  bool get isAudio => messageType == AppConstants.messageTypeAudio;

  /// Check if message is a file
  bool get isFile => messageType == AppConstants.messageTypeFile;

  MessageModel copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    List<String>? readBy,
    String? messageType,
    String? mediaUrl,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MessageModel(id: $id, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...)';
}
