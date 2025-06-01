import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String chatId;
  final String? chatName;
  final bool isGroupChat;

  const ChatScreen({
    required this.userId,
    required this.chatId,
    this.chatName,
    this.isGroupChat = false,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _typingTimer;
  bool _isTyping = false;
  final Map<String, bool> _usersTyping = {};

  @override
  void initState() {
    super.initState();
    _listenToTypingStatus();
  }

  @override
  void dispose() {
    _stopTyping();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  String get _chatPath => widget.isGroupChat ? 'group_chats' : 'chats';
  String get _messagesPath => '$_chatPath/${widget.chatId}/messages';
  String get _typingPath => '$_chatPath/${widget.chatId}/typing';

  void _listenToTypingStatus() {
    _firestore.collection(_typingPath).snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _usersTyping.clear();
          for (var doc in snapshot.docs) {
            if (doc.id != widget.userId) {
              _usersTyping[doc.id] = doc.data()['isTyping'] ?? false;
            }
          }
          _isTyping = _usersTyping.values.any((typing) => typing);
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    _stopTyping();

    try {
      await _firestore.collection(_messagesPath).add({
        'message': message,
        'sender': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
        'isMe': true,
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void _handleTyping(String text) {
    if (text.isNotEmpty) {
      _startTyping();
    } else {
      _stopTyping();
    }
  }

  void _startTyping() {
    _firestore.collection(_typingPath).doc(widget.userId).set({
      'isTyping': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    _firestore.collection(_typingPath).doc(widget.userId).set({
      'isTyping': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _typingTimer?.cancel();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getChatName() {
    if (widget.isGroupChat) {
      return widget.chatName ?? 'Group Chat';
    } else {
      return widget.chatName ?? 'Unknown User';
    }
  }

  String _getTypingText() {
    if (!_isTyping) return "Online";

    if (widget.isGroupChat) {
      final typingUsers =
          _usersTyping.entries
              .where((entry) => entry.value && entry.key != widget.userId)
              .map((entry) => entry.key)
              .toList();

      if (typingUsers.isEmpty) return "Online";
      if (typingUsers.length == 1) return "${typingUsers[0]} is typing...";
      if (typingUsers.length == 2) {
        return "${typingUsers[0]} and ${typingUsers[1]} are typing...";
      }
      return "${typingUsers.length} people are typing...";
    } else {
      return "Typing...";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: Column(
        children: [Expanded(child: _buildMessagesList()), _buildMessageInput()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2D3748),
            child: Text(
              _getChatName().substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getChatName(),
                  style: const TextStyle(
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getTypingText(),
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Color(0xFF718096)),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Container(
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection(_messagesPath)
                .orderBy('timestamp', descending: false)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data?.docs ?? [];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && _isTyping) {
                return _buildTypingIndicator();
              }

              final messageDoc = messages[index];
              final messageData = messageDoc.data() as Map<String, dynamic>;

              final message = ChatMessage(
                message: messageData['message'] ?? '',
                sender: messageData['sender'] ?? '',
                timestamp:
                    (messageData['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                isMe: messageData['sender'] == widget.userId,
              );

              return _buildMessageBubble(message, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF718096),
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .fade(duration: 600.ms, delay: (index * 200).ms);
          }),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF2D3748) : const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isGroupChat && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.sender,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Text(
                  message.message,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF2D3748),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : const Color(0xFF718096),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: (index * 50).ms)
          .slideX(
            begin: isMe ? 0.3 : -0.3,
            duration: 300.ms,
            curve: Curves.easeOutQuad,
          ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFFA0AEC0)),
                  border: InputBorder.none,
                ),
                maxLines: null,
                onChanged: _handleTyping,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2D3748),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
