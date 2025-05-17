import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'models/chat_message.dart';
import 'services/mqtt_service.dart';

class ChatPage extends StatefulWidget {
  final String userId;

  const ChatPage({required this.userId, super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  late MqttService _mqttService;
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingController;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _mqttService = MqttService(userId: widget.userId);
    _initMqtt();

    // Initialize typing animation controller
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _typingController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _typingController.forward();
      }
    });
    _typingController.forward();
  }

  Future<void> _initMqtt() async {
    await _mqttService.connect();
    _mqttService.subscribe('chat/demo', (message, sender) {
      if (widget.userId == sender) return;

      // Show typing indicator briefly
      setState(() {
        _isTyping = true;
      });

      // Add message with delay for typing effect
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(
              ChatMessage(
                message: message,
                sender: sender,
                timestamp: DateTime.now(),
                isMe: sender == widget.userId,
              ),
            );
          });
          _scrollToBottom();
        }
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final message = _messageController.text;
    setState(() {
      _messages.add(
        ChatMessage(
          message: message,
          sender: widget.userId,
          timestamp: DateTime.now(),
          isMe: true,
        ),
      );
    });

    await _mqttService.publish('chat/demo', message);
    _messageController.clear();
    _scrollToBottom();
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

  @override
  void dispose() {
    _mqttService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[600]!.withValues(alpha: 0.9),
                    Colors.blue[400]!.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'profile-${widget.userId}',
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                child: Text(
                  widget.userId.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MQTT Chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${_isTyping ? "Typing..." : "Online"} • ${widget.userId}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show options menu
            },
          ).animate().fadeIn(duration: 400.ms).scale(delay: 200.ms),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  image: const DecorationImage(
                    image: AssetImage('assets/chat_bg.png'),
                    fit: BoxFit.cover,
                    opacity: 0.05,
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show typing indicator as the last item when someone is typing
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }

                    final message = _messages[index];
                    return _buildMessageBubble(message, index);
                  },
                ),
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12, top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _typingController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      final value = _typingController.value;
                      final positionY =
                          sin((value * 2 * 3.14) + (delay * 3.14)) * 5;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          color: Colors.blue[400],
                          shape: BoxShape.circle,
                        ),
                        transform: Matrix4.translationValues(0, positionY, 0),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .moveY(begin: 10, end: 0, duration: 300.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isMe = message.isMe;
    final showSender =
        !isMe && (index == 0 || _messages[index - 1].sender != message.sender);
    final isLastMessageFromSender =
        index == _messages.length - 1 ||
        _messages[index + 1].sender != message.sender;

    final bubbleRadius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 18 : (showSender ? 4 : 18)),
      topRight: Radius.circular(
        isMe ? (index == 0 || _messages[index - 1].isMe != isMe ? 4 : 18) : 18,
      ),
      bottomLeft: Radius.circular(
        isMe ? 18 : (isLastMessageFromSender ? 18 : 4),
      ),
      bottomRight: Radius.circular(
        isMe ? (isLastMessageFromSender ? 18 : 4) : 18,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? 8 : 2,
        bottom: isLastMessageFromSender ? 5 : 2,
        left: 8,
        right: 8,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, bottom: 4),
                  child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.blueGrey[100],
                            child: Text(
                              message.sender.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Colors.blueGrey[800],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            message.sender,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: -10, end: 0, duration: 300.ms),
                ),
              Container(
                    decoration: BoxDecoration(
                      borderRadius: bubbleRadius,
                      gradient: LinearGradient(
                        colors:
                            isMe
                                ? [Colors.blue[600]!, Colors.blue[400]!]
                                : [Colors.white, Colors.grey[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isMe
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    margin: EdgeInsets.only(
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Text(
                      message.message,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.grey[800],
                        fontSize: 16,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 50.ms)
                  .moveX(
                    begin: isMe ? 20 : -20,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuad,
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0, right: 8, left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(message.timestamp),
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 12,
                        color: Colors.blue[400],
                      ).animate().fadeIn(delay: 500.ms, duration: 300.ms),
                    ],
                  ],
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: () {},
          ).animate().scale(delay: 100.ms, duration: 300.ms),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.amber[600],
                    ),
                    onPressed: () {
                      // Add emoji picker
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final hasText = value.text.isNotEmpty;
              return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            hasText
                                ? [Colors.blue[600]!, Colors.blue[400]!]
                                : [Colors.grey[400]!, Colors.grey[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow:
                          hasText
                              ? [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : null,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: hasText ? _sendMessage : null,
                    ),
                  )
                  .animate(target: hasText ? 1 : 0)
                  .shimmer(
                    duration: const Duration(milliseconds: 1200),
                    color: Colors.white.withValues(alpha: 0.5),
                  );
            },
          ),
        ],
      ),
    );
  }
}
