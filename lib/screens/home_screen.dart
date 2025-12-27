import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'auth_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String currentUserId;

  const HomeScreen({required this.currentUserId, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    // Update user's online status
    await _firestore.collection('users').doc(widget.currentUserId).set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> _getChatsStream() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: widget.currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _getUsersStream() {
    return _firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: widget.currentUserId)
        .snapshots();
  }

  Future<Map<String, dynamic>?> _getLastMessage(String chatId) async {
    final lastMessageQuery =
        await _firestore
            .collection('chats/$chatId/messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

    if (lastMessageQuery.docs.isNotEmpty) {
      return lastMessageQuery.docs.first.data();
    }
    return null;
  }

  Future<int> _getUnreadCount(String chatId) async {
    try {
      final unreadQuerySnapshot =
          await _firestore.collection('chats/$chatId/messages').get();

      final unreadDocs =
          unreadQuerySnapshot.docs.where((doc) {
            final readBy = List<String>.from(doc['readBy'] ?? []);
            return !readBy.contains(widget.currentUserId);
          }).toList();

      return unreadDocs.length;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting unread count for chat $chatId: $e');
      }
      return 0;
    }
  }

  Future<void> _createOrNavigateToIndividualChat(
    String otherUserId,
    String otherUserName,
  ) async {
    final existingChatQuery =
        await _firestore
            .collection('chats')
            .where('participants', arrayContains: widget.currentUserId)
            .where('isGroupChat', isEqualTo: false)
            .get();

    String? chatId;

    for (var doc in existingChatQuery.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(otherUserId) && participants.length == 2) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final currentUserDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();
      if (!currentUserDoc.exists) {
        if (mounted) {
          _showErrorSnackBar('Current user not found');
        }
        return;
      }
      final newChat = await _firestore.collection('chats').add({
        'participants': [widget.currentUserId, otherUserId],
        'participantNames': {
          widget.currentUserId:
              currentUserDoc.data()?['fullName'] ?? 'Unknown User',
          otherUserId: otherUserName,
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isGroupChat': false,
      });
      chatId = newChat.id;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                userId: widget.currentUserId,
                chatId: chatId!,
                chatName: otherUserName,
                isGroupChat: false,
              ),
        ),
      );
    }
  }

  Future<void> _createGroupChat(
    String groupName,
    List<Map<String, dynamic>> selectedUsersData,
  ) async {
    if (groupName.isEmpty || selectedUsersData.isEmpty) {
      if (mounted) {
        _showErrorSnackBar('Group name and participants are required.');
      }
      return;
    }

    final currentUserDoc =
        await _firestore.collection('users').doc(widget.currentUserId).get();
    if (!currentUserDoc.exists) {
      if (mounted) {
        _showErrorSnackBar('Current user not found');
      }
      return;
    }
    final String currentUserName =
        currentUserDoc.data()?['fullName'] ?? 'Unknown User';

    List<String> participantIds = [
      widget.currentUserId,
      ...selectedUsersData.map((userData) => userData['id'] as String),
    ];

    Map<String, String> participantNames = {
      widget.currentUserId: currentUserName,
    };
    for (var userData in selectedUsersData) {
      participantNames[userData['id'] as String] = userData['name'] as String;
    }

    final newChat = await _firestore.collection('chats').add({
      'groupName': groupName,
      'participants': participantIds,
      'participantNames': participantNames,
      'adminIds': [widget.currentUserId],
      'lastMessage': 'Group created by $currentUserName',
      'lastMessageSenderId': widget.currentUserId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'isGroupChat': true,
      'groupAvatar': '',
    });

    if (mounted) {
      Navigator.pop(context); // Close the create group dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChatScreen(
                userId: widget.currentUserId,
                chatId: newChat.id,
                chatName: groupName,
                isGroupChat: true,
              ),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Widget _buildChatList() {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _getChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading chats',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: theme.iconTheme.color?.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Conversations Yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to start a new chat or group.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final bool isGroupChat = chatData['isGroupChat'] ?? false;

            String chatDisplayName;
            String avatarLetter = '?';

            if (isGroupChat) {
              chatDisplayName = chatData['groupName'] ?? 'Group Chat';
              if (chatDisplayName.isNotEmpty) {
                avatarLetter = chatDisplayName.substring(0, 1).toUpperCase();
              }
            } else {
              final participants = List<String>.from(chatData['participants']);
              final participantNames = Map<String, String>.from(
                chatData['participantNames'] ?? {},
              );
              final otherUserId = participants.firstWhere(
                (id) => id != widget.currentUserId,
                orElse: () => '',
              );

              if (otherUserId.isNotEmpty) {
                chatDisplayName =
                    participantNames[otherUserId] ?? 'Unknown User';
                if (chatDisplayName.isNotEmpty) {
                  avatarLetter = chatDisplayName.substring(0, 1).toUpperCase();
                }
              } else {
                chatDisplayName = 'Chat';
                avatarLetter = 'C';
              }
            }

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getLastMessage(chatDoc.id),
              builder: (context, messageSnapshot) {
                return FutureBuilder<int>(
                  future: _getUnreadCount(chatDoc.id),
                  builder: (context, unreadSnapshot) {
                    if (!isGroupChat) {
                      final participants = List<String>.from(
                        chatData['participants'],
                      );
                      final otherUserId = participants.firstWhere(
                        (id) => id != widget.currentUserId,
                        orElse: () => '',
                      );

                      return StreamBuilder<DocumentSnapshot>(
                        stream:
                            _firestore
                                .collection('users')
                                .doc(otherUserId)
                                .snapshots(),
                        builder: (context, userSnapshot) {
                          final userData =
                              userSnapshot.data?.data()
                                  as Map<String, dynamic>?;
                          final isOnline = userData?['isOnline'] ?? false;

                          return _buildChatItemInternal(
                            chatDoc: chatDoc,
                            chatData: chatData,
                            messageSnapshot: messageSnapshot,
                            unreadSnapshot: unreadSnapshot,
                            isGroupChat: isGroupChat,
                            chatDisplayName: chatDisplayName,
                            avatarLetter: avatarLetter,
                            isOnline: isOnline,
                            index: index,
                          );
                        },
                      );
                    } else {
                      return _buildChatItemInternal(
                        chatDoc: chatDoc,
                        chatData: chatData,
                        messageSnapshot: messageSnapshot,
                        unreadSnapshot: unreadSnapshot,
                        isGroupChat: isGroupChat,
                        chatDisplayName: chatDisplayName,
                        avatarLetter: avatarLetter,
                        isOnline:
                            false, // Groups don't have a single online status like this
                        index: index,
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatItemInternal({
    required DocumentSnapshot chatDoc,
    required Map<String, dynamic> chatData,
    required AsyncSnapshot<Map<String, dynamic>?> messageSnapshot,
    required AsyncSnapshot<int> unreadSnapshot,
    required bool isGroupChat,
    required String chatDisplayName,
    required String avatarLetter,
    required bool isOnline,
    required int index,
  }) {
    final lastMessageData = messageSnapshot.data;
    final lastMessageContent =
        lastMessageData?['message'] ??
        (isGroupChat ? 'Group created' : 'No messages yet');
    final lastMessageTime = lastMessageData?['timestamp'] as Timestamp?;
    final unreadCount = unreadSnapshot.data ?? 0;

    return _buildChatItem(
      chatId: chatDoc.id,
      name: chatDisplayName,
      lastMessage: lastMessageContent,
      time: _formatTime(lastMessageTime),
      unreadCount: unreadCount,
      isOnline: isOnline,
      isGroup: isGroupChat,
      avatarLetter: avatarLetter,
      index: index,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  userId: widget.currentUserId,
                  chatId: chatDoc.id,
                  chatName: chatDisplayName,
                  isGroupChat: isGroupChat,
                ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList({
    Function(Map<String, dynamic> userData, bool isSelected)? onUserTap,
    List<String>? initiallySelectedUserIds,
  }) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        final users = snapshot.data?.docs ?? [];
        final filteredUsers =
            users.where((doc) {
              final userData = doc.data() as Map<String, dynamic>;
              final userName = userData['fullName'] ?? '';
              return userName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
            }).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'No other users found.'
                  : 'No users match "$_searchQuery"',
              style: TextStyle(color: theme.hintColor),
            ),
          ).animate().fadeIn();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final bool isSelected =
                initiallySelectedUserIds?.contains(userDoc.id) ?? false;

            return _buildUserItem(
              userId: userDoc.id,
              name: userData['fullName'] ?? 'Unknown User',
              isOnline: userData['isOnline'] ?? false,
              avatarLetter:
                  (userData['fullName'] ?? 'U').substring(0, 1).toUpperCase(),
              index: index,
              showCheckbox: onUserTap != null,
              isSelected: isSelected,
              onTap: () {
                if (onUserTap != null) {
                  onUserTap({
                    'id': userDoc.id,
                    'name': userData['fullName'] ?? 'Unknown User',
                  }, !isSelected);
                } else {
                  _createOrNavigateToIndividualChat(
                    userDoc.id,
                    userData['fullName'] ?? 'Unknown User',
                  );
                  if (Navigator.canPop(context)) {
                    // Close bottom sheet if open
                    Navigator.pop(context);
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat.Hm().format(date); // e.g., 14:30
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.EEEE().format(date); // e.g., Tuesday
    } else {
      return DateFormat.yMd().format(date); // e.g., 25/05/2023
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: child,
                );
              },
              child:
                  _showSearchBar
                      ? _buildSearchBar()
                      : const SizedBox.shrink(key: ValueKey('emptySearchBar')),
            ),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewIndividualChatDialog,
        backgroundColor: theme.colorScheme.primary,
        elevation: 4,
        tooltip: 'New Chat',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(
          Icons.add_comment_outlined,
          size: 24,
          color: theme.colorScheme.onPrimary,
        ),
      ).animate().scale(
        delay: 300.ms,
        duration: 300.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  // Assuming you have a logo, otherwise use an Icon
                  'assets/clean_logo.png', // Make sure this asset exists
                  width: 24,
                  height: 24,
                  errorBuilder:
                      (context, error, stackTrace) => Icon(
                        Icons.chat_bubble_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                ).animate().fadeIn(delay: 50.ms),
              ),
              const SizedBox(width: 8),
              Text(
                'Talk2Me', // Your App Name
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showSearchBar ? Icons.close_rounded : Icons.search_rounded,
                  color: theme.iconTheme.color,
                  size: 24,
                ),
                tooltip: _showSearchBar ? "Close Search" : "Search Chats",
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                    }
                  });
                },
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(width: 4),
              StreamBuilder<DocumentSnapshot>(
                stream:
                    _firestore
                        .collection('users')
                        .doc(widget.currentUserId)
                        .snapshots(),
                builder: (context, snapshot) {
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  final avatarUrl = userData?['avatarUrl'] as String?;
                  final displayName = userData?['fullName'] as String? ?? "U";

                  return InkWell(
                    onTap: _showOptionsMenu,
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      backgroundImage:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                      child:
                          (avatarUrl == null || avatarUrl.isEmpty)
                              ? Text(
                                displayName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                              : null,
                    ),
                  );
                },
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('searchBar'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color:
            theme.inputDecorationTheme.fillColor ??
            theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search conversations or users...',
          hintStyle: TextStyle(
            color: theme.hintColor.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.iconTheme.color,
            size: 20,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: theme.iconTheme.color,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                  : null,
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildMainContent() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Main content area background
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Column(
          children: [
            if (!_showSearchBar) _buildTabBar(),
            Expanded(
              child: _showSearchBar ? _buildUsersList() : _buildChatList(),
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: 0.02,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Conversations',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _getChatsStream(),
            builder: (context, snapshot) {
              final chatCount = snapshot.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$chatCount Active',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildChatItem({
    required String chatId,
    required String name,
    required String lastMessage,
    required String time,
    required int unreadCount,
    required bool isOnline,
    required bool isGroup,
    required String avatarLetter,
    required int index,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final bool isUnread = unreadCount > 0;
    final bool hasAttachment =
        lastMessage.startsWith("[Attachment:") || lastMessage.contains("📎");

    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
                isUnread
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isUnread
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.dividerColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            avatarLetter,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (!isGroup && isOnline)
                          Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    Colors.green, // Semantic color for online
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                time,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      isUnread
                                          ? theme.colorScheme.primary
                                          : theme.hintColor,
                                  fontWeight:
                                      isUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (hasAttachment)
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 14,
                                  color: theme.hintColor,
                                ),
                              if (hasAttachment) const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        isUnread
                                            ? theme.colorScheme.onSurface
                                                .withValues(alpha: 0.9)
                                            : theme.hintColor,
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (50 * index + 200).ms, duration: 250.ms)
        .slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildUserItem({
    required String userId,
    required String name,
    required bool isOnline,
    required String avatarLetter,
    required int index,
    required VoidCallback onTap,
    bool showCheckbox = false,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            avatarLetter,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    Colors.green, // Semantic color for online
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color:
                                  isOnline ? Colors.green : theme.disabledColor,
                              fontSize: 13,
                              fontWeight:
                                  isOnline
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showCheckbox)
                      Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          onTap();
                        },
                        activeColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: theme.iconTheme.color?.withValues(alpha: 0.7),
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (50 * index).ms, duration: 250.ms)
        .slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }

  void _showNewIndividualChatDialog() {
    final theme = Theme.of(context);
    _searchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        children: [
                          Text(
                            'Start New Chat',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: theme.iconTheme.color,
                            ),
                            tooltip: "Close",
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: theme.iconTheme.color,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: theme.iconTheme.color,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor:
                              theme.inputDecorationTheme.fillColor ??
                              theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    Expanded(child: _buildUsersList()),
                  ],
                ),
              );
            },
          ),
    ).whenComplete(() {
      _searchController.clear();
    });
  }

  void _showCreateGroupDialog() {
    Navigator.pop(context); // Close the options menu first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CreateGroupDialog(
          // This widget itself will use Theme.of(context) internally
          currentUserId: widget.currentUserId,
          firestore: _firestore,
          onGroupCreated: (groupName, selectedUsers) {
            _createGroupChat(groupName, selectedUsers);
          },
        );
      },
    );
  }

  void _showOptionsMenu() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildMenuListItem(
                  icon: Icons.group_add_outlined,
                  title: 'New Group',
                  onTap: _showCreateGroupDialog,
                ),
                _buildMenuListItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                Divider(indent: 16, endIndent: 16, color: theme.dividerColor),
                _buildMenuListItem(
                  icon: Icons.logout_outlined,
                  title: 'Sign Out',
                  color: theme.colorScheme.error,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await _firestore
                          .collection('users')
                          .doc(widget.currentUserId)
                          .set({
                            'isOnline': false,
                            'lastSeen': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        _showErrorSnackBar('Error signing out: $e');
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _buildMenuListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color, // Allow overriding color for specific items like "Sign Out"
  }) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: itemColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// Dialog for Creating a Group
class CreateGroupDialog extends StatefulWidget {
  final String currentUserId;
  final FirebaseFirestore firestore;
  final Function(String groupName, List<Map<String, dynamic>> selectedUsersData)
  onGroupCreated;

  const CreateGroupDialog({
    super.key,
    required this.currentUserId,
    required this.firestore,
    required this.onGroupCreated,
  });

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _groupNameController = TextEditingController();
  final _searchUserController = TextEditingController();
  String _userSearchQuery = '';
  final List<Map<String, dynamic>> _selectedUsersData = [];

  @override
  void initState() {
    super.initState();
    _searchUserController.addListener(() {
      if (mounted) {
        setState(() {
          _userSearchQuery = _searchUserController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchUserController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getDialogUsersStream() {
    return widget.firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: widget.currentUserId)
        .snapshots();
  }

  void _toggleUserSelection(Map<String, dynamic> userData) {
    setState(() {
      final existingIndex = _selectedUsersData.indexWhere(
        (user) => user['id'] == userData['id'],
      );
      if (existingIndex >= 0) {
        _selectedUsersData.removeAt(existingIndex);
      } else {
        _selectedUsersData.add(userData);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Create New Group',
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(color: theme.hintColor),
                hintText: 'Enter group name',
                hintStyle: TextStyle(
                  color: theme.hintColor.withValues(alpha: 0.7),
                ),
                filled: true,
                fillColor:
                    theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchUserController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Add Members',
                labelStyle: TextStyle(color: theme.hintColor),
                hintText: 'Search users to add',
                hintStyle: TextStyle(
                  color: theme.hintColor.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.iconTheme.color,
                ),
                suffixIcon:
                    _userSearchQuery.isNotEmpty
                        ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: theme.iconTheme.color,
                          ),
                          onPressed: () {
                            _searchUserController.clear();
                          },
                        )
                        : null,
                filled: true,
                fillColor:
                    theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getDialogUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      "Error loading users.",
                      style: TextStyle(color: theme.colorScheme.error),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }
                  final users = snapshot.data?.docs ?? [];
                  final filteredUsers =
                      users.where((doc) {
                        final userData = doc.data() as Map<String, dynamic>;
                        final userName =
                            userData['fullName']?.toString().toLowerCase() ??
                            '';
                        return userName.contains(
                          _userSearchQuery.toLowerCase(),
                        );
                      }).toList();

                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Text(
                        _userSearchQuery.isEmpty
                            ? "No users to add."
                            : "No users match '$_userSearchQuery'",
                        style: TextStyle(color: theme.hintColor),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final userDoc = filteredUsers[index];
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final userName = userData['fullName'] ?? 'Unknown User';
                      final userId = userDoc.id;
                      final isSelected = _selectedUsersData.any(
                        (user) => user['id'] == userId,
                      );

                      return CheckboxListTile(
                        title: Text(
                          userName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          _toggleUserSelection({
                            'id': userId,
                            'name': userName,
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        activeColor: theme.colorScheme.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        tileColor:
                            isSelected
                                ? theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.2,
                                )
                                : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_selectedUsersData.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      _selectedUsersData
                          .map(
                            (user) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary,
                                  child: Text(
                                    (user['name'] as String)
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                label: Text(
                                  user['name'] as String,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: theme
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                onDeleted: () => _toggleUserSelection(user),
                                deleteIconColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.7),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.group_add_rounded, size: 18),
          label: const Text('Create Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            if (_groupNameController.text.trim().isNotEmpty &&
                _selectedUsersData.isNotEmpty) {
              widget.onGroupCreated(
                _groupNameController.text.trim(),
                _selectedUsersData,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Please enter a group name and select at least one member.',
                  ),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(10),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
