import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of message content
enum MessageType {
  text,
  image,
  video,
  audio,
  document,
}

/// Media attachment information
class MediaAttachment {
  final String url;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int? width;
  final int? height;
  final int? duration; // For audio/video in seconds
  final String? thumbnailUrl;

  const MediaAttachment({
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.width,
    this.height,
    this.duration,
    this.thumbnailUrl,
  });

  factory MediaAttachment.fromMap(Map<String, dynamic> map) {
    return MediaAttachment(
      url: map['url'] ?? '',
      storagePath: map['storagePath'] ?? '',
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      mimeType: map['mimeType'] ?? '',
      width: map['width'],
      height: map['height'],
      duration: map['duration'],
      thumbnailUrl: map['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'storagePath': storagePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }

  /// Get human-readable file size
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get formatted duration for audio/video
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

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
  final MessageType messageType;
  final MediaAttachment? media;

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
    this.messageType = MessageType.text,
    this.media,
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

    // Parse message type
    MessageType messageType = MessageType.text;
    final typeStr = data['messageType'] as String?;
    if (typeStr != null) {
      messageType = MessageType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => MessageType.text,
      );
    }

    // Parse media attachment
    MediaAttachment? media;
    final mediaData = data['media'] as Map<String, dynamic>?;
    if (mediaData != null) {
      media = MediaAttachment.fromMap(mediaData);
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
      messageType: messageType,
      media: media,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'sender': sender,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': isEdited,
      'messageType': messageType.name,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToMessage != null) 'replyToMessage': replyToMessage,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (media != null) 'media': media!.toMap(),
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
    MessageType? messageType,
    MediaAttachment? media,
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
      messageType: messageType ?? this.messageType,
      media: media ?? this.media,
    );
  }

  /// Check if message is a media message
  bool get isMedia => messageType != MessageType.text;

  /// Check if message is an image
  bool get isImage => messageType == MessageType.image;

  /// Check if message is a video
  bool get isVideo => messageType == MessageType.video;

  /// Check if message is an audio/voice message
  bool get isAudio => messageType == MessageType.audio;

  /// Check if message is a document
  bool get isDocument => messageType == MessageType.document;

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
