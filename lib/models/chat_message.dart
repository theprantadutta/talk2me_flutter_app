class ChatMessage {
  final String message;
  final String sender;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.message,
    required this.sender,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
  });
}
