import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/animation_constants.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/extensions.dart';
import '../models/chat_message.dart';
import '../widgets/common/app_avatar.dart';
import '../widgets/dialogs/create_group_dialog.dart';
import '../widgets/glass/glass_container.dart';

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _messageFocusNode = FocusNode();

  Timer? _typingTimer;
  bool _isOverallTyping = false;
  final Map<String, bool> _usersTypingStatus = {};
  Map<String, String> _participantDisplayNames = {};
  String _resolvedChatName = '';
  String _currentUserDisplayName = '';
  String _otherUserId = '';
  String? _otherUserPhotoUrl;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _messageSearchQuery = '';

  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

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
    } else {
      _getOtherUserId();
    }
    _listenToTypingStatus();
    _markMessagesAsRead();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _messageSearchQuery = _searchController.text;
        });
      }
    });

    _sendButtonController = AnimationController(
      duration: AnimationConstants.fast,
      vsync: this,
    );
    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );
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

  Future<void> _getOtherUserId() async {
    if (widget.isGroupChat) return;
    try {
      final chatDoc = await _firestore.doc(_chatDocumentPath).get();
      if (chatDoc.exists) {
        final participants = List<String>.from(
          chatDoc.data()?['participants'] ?? [],
        );
        final otherUserId = participants.firstWhere(
          (id) => id != widget.userId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          final userDoc =
              await _firestore.collection('users').doc(otherUserId).get();
          if (mounted) {
            setState(() {
              _otherUserId = otherUserId;
              _participantDisplayNames = Map<String, String>.from(
                chatDoc.data()?['participantNames'] ?? {},
              );
              if (_resolvedChatName == 'Chat' && _otherUserId.isNotEmpty) {
                _resolvedChatName =
                    _participantDisplayNames[_otherUserId] ?? 'Chat User';
              }
              if (userDoc.exists) {
                _otherUserPhotoUrl = userDoc.data()?['photoURL'];
              }
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting other user ID: $e");
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
          if (isTyping && DateTime.now().difference(timestamp).inSeconds < 7) {
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
    _searchController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _sendButtonController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    _sendButtonController.forward().then((_) => _sendButtonController.reverse());

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
        _showErrorSnackBar('Failed to send message');
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
    _typingTimer = Timer(const Duration(seconds: 5), () {
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
        if (isNewMessage || _scrollController.position.extentAfter < 300) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: AnimationConstants.medium,
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  String _getAppBarSubtitle() {
    if (!_isOverallTyping || _usersTypingStatus.isEmpty) {
      if (widget.isGroupChat) {
        return '${_participantDisplayNames.isNotEmpty ? _participantDisplayNames.length : "..."} members';
      } else {
        return 'Online';
      }
    }

    final typingDisplayNames =
        _usersTypingStatus.keys
            .map((userId) => _participantDisplayNames[userId] ?? 'Someone')
            .where((name) => name != 'Someone')
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
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f0f23),
                  ]
                : [
                    const Color(0xFFe8f4f8),
                    const Color(0xFFd4e9ed),
                    const Color(0xFFf0f4f8),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildGlassAppBar(),
              if (_isSearching) _buildSearchBar(),
              Expanded(child: _buildMessagesList()),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
              ),
              AppAvatar(
                imageUrl: widget.isGroupChat ? null : _otherUserPhotoUrl,
                name: _resolvedChatName,
                size: 40,
                isOnline: !widget.isGroupChat,
                showOnlineIndicator: !widget.isGroupChat,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolvedChatName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    AnimatedSwitcher(
                      duration: AnimationConstants.fast,
                      child: Text(
                        _getAppBarSubtitle(),
                        key: ValueKey(_getAppBarSubtitle()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isOverallTyping
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                    }
                  });
                },
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search_rounded,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.colorScheme.onSurface,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
                color: isDark
                    ? Colors.grey[900]
                    : Colors.white,
                onSelected: (value) {
                  if (value == 'create_group') {
                    _showCreateGroupDialog();
                  } else if (value == 'view_contact') {
                    _showViewContactDialog();
                  }
                },
                itemBuilder: (context) => [
                  if (!widget.isGroupChat)
                    PopupMenuItem(
                      value: 'view_contact',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              color: theme.colorScheme.onSurface),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('View Contact'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'create_group',
                    child: Row(
                      children: [
                        Icon(Icons.group_add_outlined,
                            color: theme.colorScheme.onSurface),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Create Group'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: GlassContainer(
        blur: 10,
        opacity: isDark ? 0.15 : 0.7,
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search messages...',
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            suffixIcon: _messageSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    final theme = Theme.of(context);

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
              'Error loading messages',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        var messages = snapshot.data?.docs ?? [];

        if (_messageSearchQuery.isNotEmpty) {
          messages =
              messages.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final messageText =
                    data['message']?.toString().toLowerCase() ?? '';
                return messageText.contains(_messageSearchQuery.toLowerCase());
              }).toList();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (messages.isNotEmpty && !_isSearching) {
            _markMessagesAsRead();
          }
          if (!_isSearching) {
            _scrollToBottom();
          }
        });

        if (messages.isEmpty && _messageSearchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No messages found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        if (messages.isEmpty && !_isOverallTyping) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Start the conversation!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Send a message to begin',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          itemCount:
              messages.length +
              (_isOverallTyping &&
                      !_usersTypingStatus.containsKey(widget.userId) &&
                      !_isSearching
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            if (index == messages.length &&
                _isOverallTyping &&
                !_usersTypingStatus.containsKey(widget.userId) &&
                !_isSearching) {
              return _buildTypingIndicator();
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

            // Check if we need to show date separator
            Widget? dateSeparator;
            if (index == 0 ||
                !_isSameDay(
                  message.timestamp,
                  ((messages[index - 1].data() as Map<String, dynamic>)['timestamp']
                          as Timestamp?)
                      ?.toDate(),
                )) {
              dateSeparator = _buildDateSeparator(message.timestamp);
            }

            return Column(
              children: [
                if (dateSeparator != null) dateSeparator,
                _buildMessageBubble(message, index),
              ],
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime date1, DateTime? date2) {
    if (date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: AppRadius.xl,
          ),
          child: Text(
            date.dateLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: 60,
        bottom: AppSpacing.md,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: _TypingDots(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMe = message.isMe;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : AppSpacing.xs,
        right: isMe ? AppSpacing.xs : 60,
        bottom: AppSpacing.sm,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.isGroupChat && !isMe)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.xxs,
                ),
                child: Text(
                  message.senderName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isMe ? 0 : 10,
                  sigmaY: isMe ? 0 : 10,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    gradient: isMe
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.85),
                              theme.colorScheme.secondary.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: isMe
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.85)),
                    border: isMe
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isMe
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: (isMe ? Colors.white : theme.colorScheme.onSurface)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: GlassContainer(
                  blur: 10,
                  opacity: isDark ? 0.15 : 0.6,
                  borderRadius: AppRadius.xl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _handleTypingChange,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedBuilder(
                animation: _sendButtonScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _sendButtonScale.value,
                    child: child,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: AppRadius.xl,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppRadius.xl,
                      onTap: _sendMessage,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.send_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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

            if (mounted) {
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
            }
          },
        );
      },
    );
  }

  Future<void> _showViewContactDialog() async {
    if (widget.isGroupChat || _otherUserId.isEmpty) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    try {
      final userDoc =
          await _firestore.collection('users').doc(_otherUserId).get();
      if (!userDoc.exists || !mounted) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final String name = userData['fullName'] ?? 'Unknown User';
      final String email = userData['email'] ?? 'No email';
      final String avatarUrl = userData['photoURL'] ?? '';
      final bool isOnline = userData['isOnline'] ?? false;

      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: AppRadius.xl,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.xl,
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.9),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAvatar(
                        imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                        name: name,
                        size: 80,
                        isOnline: isOnline,
                        showOnlineIndicator: true,
                        showGlow: true,
                        glowColor: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: AppRadius.xl,
                        ),
                        child: Text(
                          isOnline ? 'Online' : 'Offline',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isOnline ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Close',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) _showErrorSnackBar('Could not load contact details.');
      if (kDebugMode) print("Error showing contact dialog: $e");
    }
  }
}

/// Animated typing dots
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final bounce = (value < 0.5 ? value : 1.0 - value) * 2;

            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              transform: Matrix4.translationValues(0, -4 * bounce, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.3 + (0.5 * bounce),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
