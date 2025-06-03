import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../models/chat_message.dart';
import 'home_screen.dart';

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
  bool _isOverallTyping = false;
  final Map<String, bool> _usersTypingStatus = {};
  Map<String, String> _participantDisplayNames = {};
  String _resolvedChatName = '';
  String _currentUserDisplayName = '';

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
      if (kDebugMode) {
        print("Error loading current user's name: $e");
      }
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
        final readBy = (data['readBy'] as List?)?.cast<String>() ?? [];
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
          final data = doc.data();
          final isTyping = data['isTyping'] ?? false;
          final timestamp =
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          if (isTyping && DateTime.now().difference(timestamp).inSeconds < 5) {
            newTypingUsers[doc.id] = true;
          } else {
            newTypingUsers[doc.id] = false;
          }
        }
      }
      newTypingUsers.removeWhere((key, value) => value == false);

      bool newOverallTypingState = newTypingUsers.values.any(
        (typing) => typing,
      );
      bool changed = false;

      if (!mapEquals(newTypingUsers, _usersTypingStatus)) {
        _usersTypingStatus.clear();
        _usersTypingStatus.addAll(newTypingUsers);
        changed = true;
      }

      if (_isOverallTyping != newOverallTypingState) {
        _isOverallTyping = newOverallTypingState;
        changed = true;
      }

      if (changed && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    if (mounted) {
      _stopTyping();
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
        'senderName': _currentUserDisplayName,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [widget.userId],
      });
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
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
      'timestamp': FieldValue.serverTimestamp(),
      'userName': _currentUserDisplayName,
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
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
      // Fetch participant count for group chat subtitle if not typing
      if (widget.isGroupChat) {
        // This requires fetching participant count or storing it on the chat document
        // For simplicity, using _participantDisplayNames.length which might not be fully updated initially
        // A better approach would be to have a 'memberCount' field on the chat document.
        return '${_participantDisplayNames.isNotEmpty ? _participantDisplayNames.length : "..."} members';
      } else {
        // For 1-on-1 chat, you might want to show online status or last seen
        // This would require fetching the other user's status.
        // For now, keeping it simple or you can add a StreamBuilder for the other user's status.
        return 'Online'; // Placeholder
      }
    }

    final typingDisplayNames =
        _usersTypingStatus.keys
            .map((userId) => _participantDisplayNames[userId] ?? 'Someone')
            .where((name) => name != 'Someone') // Filter out unresolved names
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Page background
      appBar: _buildAppBar(),
      body: Container(
        color: AppColors.surface, // Background for the messages area
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
      elevation: 0.5,
      backgroundColor: AppColors.surface, // Use surface color for AppBar
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.icon,
          size: 22,
        ),
        onPressed: () => Navigator.pop(context),
        tooltip: "Back",
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.avatarBackground,
            child: Text(
              _resolvedChatName.isNotEmpty
                  ? _resolvedChatName.substring(0, 1).toUpperCase()
                  : "?",
              style: const TextStyle(
                color: AppColors.avatarText,
                fontWeight: FontWeight.bold,
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
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                // StreamBuilder for typing/subtitle for better real-time updates
                // For simplicity, using the existing _getAppBarTypingText which updates via setState
                Text(
                  _getAppBarTypingText(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Example actions - customize as needed
        // IconButton(
        //   icon: const Icon(Icons.call_outlined, color: AppColors.icon, size: 22),
        //   onPressed: () { _showErrorSnackBar('Call feature not implemented.'); },
        //   tooltip: "Call",
        // ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.icon,
            size: 24,
          ),
          tooltip: "More options",
          color: AppColors.surface, // Menu background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'create_group') {
              _showCreateGroupDialogFromChat();
            } else if (value == 'group_info') {
              _showErrorSnackBar('Group Info (Not Implemented)');
            } else if (value == 'view_contact') {
              _showErrorSnackBar('View Contact (Not Implemented)');
            } else if (value == 'clear_chat') {
              _showErrorSnackBar('Clear Chat (Not Implemented)');
            }
          },
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<String>>[
                if (widget.isGroupChat)
                  PopupMenuItem<String>(
                    value: 'group_info',
                    child: Text(
                      'Group Info',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  )
                else
                  PopupMenuItem<String>(
                    value: 'view_contact',
                    child: Text(
                      'View Contact',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem<String>(
                  value: 'clear_chat',
                  child: Text(
                    'Clear Chat',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                const PopupMenuItem<String>(
                  // Kept for consistency with home screen
                  value: 'create_group',
                  child: Text(
                    'Create New Group',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
        ),
        const SizedBox(width: 4), // Add some padding to the right of actions
      ],
    );
  }

  void _showCreateGroupDialogFromChat() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Assuming CreateGroupDialog is defined in home_screen.dart and imported,
        // or moved to a shared location.
        return CreateGroupDialog(
          currentUserId: widget.userId,
          firestore: _firestore,
          onGroupCreated: (groupName, selectedUsersData) async {
            if (groupName.isEmpty || selectedUsersData.isEmpty) {
              _showErrorSnackBar("Group name and members are required.");
              return;
            }
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

            Navigator.pushReplacement(
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
          return Center(
            child: Text(
              'Error loading messages.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final messages = snapshot.data?.docs ?? [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (messages.isNotEmpty) {
            _markMessagesAsRead();
          }
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ), // Adjusted padding
          itemCount:
              messages.length +
              (_isOverallTyping &&
                      !_usersTypingStatus.containsKey(widget.userId)
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            if (index == messages.length &&
                _isOverallTyping &&
                !_usersTypingStatus.containsKey(widget.userId)) {
              return _buildTypingIndicatorBubble();
            }
            if (index >= messages.length) return const SizedBox.shrink();

            final messageDoc = messages[index];
            final messageData = messageDoc.data() as Map<String, dynamic>;
            final message = ChatMessage(
              message: messageData['message'] ?? '',
              sender: messageData['sender'] ?? '',
              senderName:
                  messageData['senderName'] ??
                  _participantDisplayNames[messageData['sender']] ??
                  'Unknown',
              timestamp:
                  (messageData['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              isMe: messageData['sender'] == widget.userId,
            );
            return _buildMessageBubble(message, index);
          },
        );
      },
    );
  }

  Widget _buildTypingIndicatorBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 12,
          top: 4,
          left: 4,
        ), // Adjusted margin
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ), // Adjusted padding
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant, // Use surface variant
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.border.withOpacity(0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (dotIndex) {
            return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2.5,
                  ), // Adjusted spacing
                  width: 7,
                  height: 7, // Slightly smaller
                  decoration: const BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scaleXY(end: 0.6, duration: 350.ms, delay: (dotIndex * 120).ms)
                .then(delay: (700 - (dotIndex * 240)).ms);
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
                padding: EdgeInsets.only(
                  left: isMe ? 0 : 16.0,
                  bottom: 3,
                  right: isMe ? 16 : 0,
                ),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Container(
              margin: EdgeInsets.only(
                bottom: 10,
                top: widget.isGroupChat && !isMe ? 0 : 4,
              ), // Adjusted top margin
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ), // Adjusted padding
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ), // Slightly wider
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                    isMe ? 18 : 4,
                  ), // Pointed for received
                  bottomRight: Radius.circular(
                    isMe ? 4 : 18,
                  ), // Pointed for sent
                ),
                border:
                    isMe
                        ? null
                        : Border.all(color: AppColors.border.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04), // Softer shadow
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
                      color:
                          isMe
                              ? AppColors.textOnPrimary
                              : AppColors.textOnSurface,
                      fontSize: 15.5,
                    ), // Slightly larger
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color:
                          isMe
                              ? AppColors.textOnPrimary.withOpacity(0.7)
                              : AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 250.ms, delay: (20).ms)
        .slideX(begin: isMe ? 0.05 : -0.05, curve: Curves.easeOutCubic);
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ), // Adjusted padding
      decoration: BoxDecoration(
        color: AppColors.surface, // Input area background
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Softer shadow
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end, // Align items to bottom for multiline
          children: [
            // IconButton(
            //   icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.icon, size: 26),
            //   onPressed: () { _showErrorSnackBar('Attachments not implemented.'); },
            //   tooltip: "Attach file",
            // ),
            // SizedBox(width: 4),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      AppColors
                          .background, // Lighter grey for text field background
                  borderRadius: BorderRadius.circular(24), // More rounded
                  border: Border.all(color: AppColors.border.withOpacity(0.8)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.8),
                      fontSize: 15.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 0,
                    ), // Adjusted internal padding
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _handleTypingChange,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                splashColor: AppColors.primaryVariant.withOpacity(0.5),
                onTap: _sendMessage,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.send_rounded,
                    color: AppColors.textOnPrimary,
                    size: 22,
                  ),
                ),
              ),
            ).animate().scale(
              delay: 100.ms,
              duration: 200.ms,
            ), // Subtle animation for send button
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
