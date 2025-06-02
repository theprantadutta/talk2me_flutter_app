import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For mapEquals
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:talk2me_flutter_app/screens/home_screen.dart';

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
  bool _isOverallTyping = false; // Overall typing status for the chat
  final Map<String, bool> _usersTypingStatus = {}; // Tracks individual typers
  Map<String, String> _participantDisplayNames =
      {}; // For group chat sender names
  String _resolvedChatName = '';
  String _currentUserDisplayName = ''; // Current user's display name

  // Corrected Paths
  String get _chatDocumentPath => 'chats/${widget.chatId}';
  String get _messagesCollectionPath => '$_chatDocumentPath/messages';
  String get _typingCollectionPath => '$_chatDocumentPath/typing';

  @override
  void initState() {
    super.initState();
    _resolvedChatName =
        widget.chatName ?? (widget.isGroupChat ? 'Group' : 'Chat');
    _loadCurrentUserData();
    if (widget.isGroupChat) {
      _fetchGroupChatDetails();
    }
    _listenToTypingStatus();
    _markMessagesAsRead();

    // Listen to scroll events to mark more messages as read if needed (advanced)
    // _scrollController.addListener(_onScroll);
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserDisplayName = userDoc.data()?['fullName'] ?? 'You';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentUserDisplayName = 'You';
        });
      }
      print("Error loading current user's name: $e");
    }
  }

  Future<void> _fetchGroupChatDetails() async {
    try {
      final chatDoc = await _firestore.doc(_chatDocumentPath).get();
      if (chatDoc.exists && mounted) {
        final data = chatDoc.data() as Map<String, dynamic>;
        setState(() {
          _participantDisplayNames = Map<String, String>.from(
            data['participantNames'] ?? {},
          );
          if (data.containsKey('groupName') && data['groupName'] != null) {
            _resolvedChatName = data['groupName'];
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching group details: $e");
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final messagesSnapshot =
          await _firestore.collection(_messagesCollectionPath).get();
      if (messagesSnapshot.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        final readBy = (data['readBy'] as List?) ?? [];
        if (!readBy.contains(widget.userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([widget.userId]),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print("Error marking messages as read: $e");
      }
    }
  }

  void _listenToTypingStatus() {
    _firestore.collection(_typingCollectionPath).snapshots().listen((snapshot) {
      if (!mounted) return;

      Map<String, bool> newTypingUsers = {};
      for (var doc in snapshot.docs) {
        if (doc.id != widget.userId) {
          // Don't show self as typing
          final data = doc.data();
          // Check if user is actively typing and timestamp is recent (e.g., within last 5 seconds)
          final isTyping = data['isTyping'] ?? false;
          final timestamp =
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          if (isTyping && DateTime.now().difference(timestamp).inSeconds < 5) {
            newTypingUsers[doc.id] = true;
          } else {
            // Ensure user is removed if not typing or timestamp is old
            newTypingUsers[doc.id] = false;
          }
        }
      }
      // Filter out those explicitly set to false
      newTypingUsers.removeWhere((key, value) => value == false);

      bool newOverallTypingState = newTypingUsers.values.any(
        (typing) => typing,
      );
      bool changed = false;

      if (!mapEquals(newTypingUsers, _usersTypingStatus.cast<String, bool>())) {
        _usersTypingStatus.clear();
        _usersTypingStatus.addAll(newTypingUsers);
        changed = true;
      }

      if (_isOverallTyping != newOverallTypingState) {
        _isOverallTyping = newOverallTypingState;
        changed = true;
      }

      if (changed) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    // _scrollController.removeListener(_onScroll);
    if (mounted) {
      _stopTyping(); // Ensure typing is stopped when screen is disposed
    }
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    if (mounted) _stopTyping();

    try {
      await _firestore.collection(_messagesCollectionPath).add({
        'message': messageText,
        'sender': widget.userId,
        'senderName': _currentUserDisplayName, // Store sender's name
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [widget.userId], // Sender has read it
      });
      // Update last message time on the chat document itself for ordering in HomeScreen
      await _firestore.doc(_chatDocumentPath).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': widget.userId,
      });

      _scrollToBottom(isNewMessage: true);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      // Optionally, show a SnackBar to the user
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _handleTypingChange(String text) {
    if (!mounted) return;
    if (text.isNotEmpty) {
      _startTyping();
    } else {
      _stopTyping();
    }
  }

  void _startTyping() {
    _firestore.collection(_typingCollectionPath).doc(widget.userId).set({
      'isTyping': true,
      'timestamp':
          FieldValue.serverTimestamp(), // Keep timestamp to prune old typing indicators
      'userName':
          _currentUserDisplayName, // Store name for group chat typing indicator
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      // Increased duration a bit
      if (mounted) _stopTyping();
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _firestore.collection(_typingCollectionPath).doc(widget.userId).set({
      'isTyping': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _scrollToBottom({bool isNewMessage = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (isNewMessage || _scrollController.position.extentAfter < 200) {
          // Only autoscroll if near bottom or new message
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  String _getAppBarTypingText() {
    if (!_isOverallTyping || _usersTypingStatus.isEmpty) {
      return widget.isGroupChat
          ? '${_participantDisplayNames.length} members'
          : 'Online'; // Or last seen
    }

    final typingDisplayNames =
        _usersTypingStatus.keys
            .map(
              (userId) =>
                  _participantDisplayNames[userId] ??
                  _usersTypingStatus[userId] ??
                  'Someone',
            )
            .where(
              (name) =>
                  name != 'Someone' &&
                  _usersTypingStatus[_usersTypingStatus.keys.firstWhere(
                        (id) =>
                            (_participantDisplayNames[id] ?? 'Someone') == name,
                        orElse: () => '',
                      )] ==
                      true,
            )
            .toList();

    if (typingDisplayNames.isEmpty) {
      return widget.isGroupChat
          ? '${_participantDisplayNames.length} members'
          : 'Online';
    }
    if (typingDisplayNames.length == 1) {
      return "${typingDisplayNames[0]} is typing...";
    }
    if (typingDisplayNames.length == 2) {
      return "${typingDisplayNames[0]} and ${typingDisplayNames[1]} are typing...";
    }
    return "${typingDisplayNames.length} people are typing...";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Page background
      appBar: _buildAppBar(),
      body: Container(
        // Added a container to give messages list a white background
        color: Colors.white, // Background for the messages area
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            _buildMessageInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0.5, // Subtle elevation
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Color(0xFF2D3748),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2D3748),
            child: Text(
              _resolvedChatName.isNotEmpty
                  ? _resolvedChatName.substring(0, 1).toUpperCase()
                  : "?",
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _resolvedChatName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2D3748),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getAppBarTypingText(),
                  overflow: TextOverflow.ellipsis,
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
        // IconButton( // Example for video call
        //   icon: const Icon(Icons.videocam_outlined, color: Color(0xFF718096)),
        //   onPressed: () { /* TODO: Implement */ },
        // ),
        // IconButton( // Example for audio call
        //   icon: const Icon(Icons.call_outlined, color: Color(0xFF718096)),
        //   onPressed: () { /* TODO: Implement */ },
        // ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF718096)),
          onSelected: (value) {
            if (value == 'create_group') {
              _showCreateGroupDialogFromChat();
            } else if (value == 'group_info') {
              // TODO: Navigate to Group Info Screen or show dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group Info (Not Implemented)')),
              );
            } else if (value == 'view_contact') {
              // TODO: Navigate to Contact Info Screen or show dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('View Contact (Not Implemented)')),
              );
            }
          },
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<String>>[
                if (widget.isGroupChat)
                  const PopupMenuItem<String>(
                    value: 'group_info',
                    child: Text('Group Info'),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'view_contact',
                    child: Text('View Contact'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'create_group',
                  child: Text('Create New Group'),
                ),
              ],
        ),
      ],
    );
  }

  void _showCreateGroupDialogFromChat() {
    // This uses the CreateGroupDialog from home_screen.dart
    // Ensure it's either imported or moved to a shared location.
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CreateGroupDialog(
          // Assuming CreateGroupDialog is accessible
          currentUserId: widget.userId,
          firestore: _firestore,
          onGroupCreated: (groupName, selectedUsersData) async {
            // Copied from HomeScreen's _createGroupChat and adapted
            if (groupName.isEmpty || selectedUsersData.isEmpty) return;
            final currentUserDoc =
                await _firestore.collection('users').doc(widget.userId).get();
            final String currentUserName =
                currentUserDoc.data()?['fullName'] ?? 'Unknown User';

            List<String> participantIds = [
              widget.userId,
              ...selectedUsersData.map((userData) => userData['id'] as String),
            ];
            Map<String, String> participantNamesMap = {
              widget.userId: currentUserName,
            };
            for (var userData in selectedUsersData) {
              participantNamesMap[userData['id'] as String] =
                  userData['name'] as String;
            }

            final newChatRef = await _firestore.collection('chats').add({
              'groupName': groupName,
              'participants': participantIds,
              'participantNames': participantNamesMap,
              'adminIds': [widget.userId],
              'lastMessage': 'Group created by $currentUserName',
              'lastMessageSenderId': widget.userId,
              'lastMessageTime': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'isGroupChat': true,
              'groupAvatar': '',
            });

            Navigator.of(context).pop(); // Close the dialog

            // Navigate to the new group chat
            Navigator.pushReplacement(
              // Use pushReplacement if you don't want to return to the current chat after creating new group from here
              context,
              MaterialPageRoute(
                builder:
                    (context) => ChatScreen(
                      userId: widget.userId,
                      chatId: newChatRef.id,
                      chatName: groupName,
                      isGroupChat: true,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection(_messagesCollectionPath)
              .orderBy('timestamp', descending: false)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading messages.'));
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2D3748)),
          );
        }
        final messages = snapshot.data?.docs ?? [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (messages.isNotEmpty) {
            _markMessagesAsRead(); // Mark newly loaded messages as read
          }
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount:
              messages.length +
              (_isOverallTyping &&
                      !_usersTypingStatus.containsKey(widget.userId)
                  ? 1
                  : 0), // Add space for typing indicator
          itemBuilder: (context, index) {
            if (index == messages.length &&
                _isOverallTyping &&
                !_usersTypingStatus.containsKey(widget.userId)) {
              return _buildTypingIndicatorBubble();
            }
            if (index >= messages.length) {
              return const SizedBox.shrink(); // Should not happen
            }

            final messageDoc = messages[index];
            final messageData = messageDoc.data() as Map<String, dynamic>;
            final message = ChatMessage(
              // Using your ChatMessage model
              message: messageData['message'] ?? '',
              sender: messageData['sender'] ?? '',
              senderName: messageData['senderName'] ?? 'Unknown',
              timestamp:
                  (messageData['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              isMe: messageData['sender'] == widget.userId,
              // readBy: List<String>.from(messageData['readBy'] ?? []), // If needed by model
            );
            return _buildMessageBubble(message, index);
          },
        );
      },
    );
  }

  Widget _buildTypingIndicatorBubble() {
    // Similar to a message bubble but for typing
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (dotIndex) {
            return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF718096),
                    shape: BoxShape.circle,
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scaleXY(end: 0.7, duration: 300.ms, delay: (dotIndex * 100).ms)
                .then(
                  delay: 600.ms - (dotIndex * 200).ms,
                ); // Staggered pulsating effect
          }),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isMe = message.isMe;
    return Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.isGroupChat && !isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12.0, bottom: 2),
                child: Text(
                  message.senderName, // Use senderName from message data
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF2D3748) : const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 18),
                ),
                border:
                    isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF2D3748),
                      fontSize: 15,
                    ), // Slightly smaller text
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : const Color(0xFF718096),
                      fontSize: 10,
                    ), // Slightly smaller time
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(
          duration: 250.ms,
          delay: (50).ms,
        ) // Simplified animation trigger
        .slideX(begin: isMe ? 0.1 : -0.1, curve: Curves.easeOutQuart);
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, // Input area background
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        // Ensures input field is not obscured by system UI (e.g. home bar)
        child: Row(
          children: [
            // IconButton( // Optional: Attachment button
            //   icon: Icon(Icons.attach_file, color: Color(0xFF718096)),
            //   onPressed: () { /* TODO: Implement attachment */ },
            // ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ), // Padding inside the text field container
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFF7FAFC,
                  ), // Light grey for text field background
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(
                    color: Color(0xFF2D3748),
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Color(0xFFA0AEC0),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ), // Adjust internal padding
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5, // Allow multiple lines
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _handleTypingChange,
                  // onSubmitted: (_) => _sendMessage(), // Send on submit if desired (usually for physical keyboards)
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              // Send button with InkWell for ripple
              color: const Color(0xFF2D3748),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                splashColor: Colors.white24,
                onTap: _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(
                    12.0,
                  ), // Increased padding for easier tap
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
