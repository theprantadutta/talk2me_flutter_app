import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:talk2me_flutter_app/screens/auth_screen.dart';

import '../app_colors.dart';
import 'chat_screen.dart';

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
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading chats',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: AppColors.icon,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Conversations Yet',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the + button to start a new chat or group.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
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
                        isOnline: false,
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
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading users',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
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
              style: const TextStyle(color: AppColors.textSecondary),
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
      return DateFormat.Hm().format(date);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.EEEE().format(date);
    } else {
      return DateFormat.yMd().format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
        backgroundColor: AppColors.fabBackground,
        elevation: 4,
        tooltip: 'New Chat',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(
          Icons.add_comment_outlined,
          size: 24,
          color: AppColors.fabIcon,
        ),
      ).animate().scale(
        delay: 300.ms,
        duration: 300.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: AppColors.appBarBackground,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ), // Adjusted padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5), // Softer radius
                child: Image.asset(
                  'assets/clean_logo.png',
                  width: 24,
                  height: 24,
                ).animate().fadeIn(delay: 50.ms),
              ),
              SizedBox(width: 8),
              Text(
                'Talk2Me',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  // Adjusted size
                  color: AppColors.primary, // Use primary color for branding
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
                  color: AppColors.icon,
                  size: 24, // Slightly larger
                ),
                tooltip: _showSearchBar ? "Close Search" : "Search Chats",
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                      // _searchQuery is already handled by listener
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
                    onTap: _showOptionsMenu, // Moved options to avatar tap
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20, // Slightly larger
                      backgroundColor: AppColors.avatarBackground.withOpacity(
                        0.2,
                      ),
                      backgroundImage:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                      child:
                          (avatarUrl == null || avatarUrl.isEmpty)
                              ? Text(
                                displayName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.avatarText,
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
    return Container(
      key: const ValueKey('searchBar'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), // Adjusted margin
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.searchBarBackground,
        borderRadius: BorderRadius.circular(12), // Softer radius
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search conversations or users...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
            fontSize: 14,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.icon,
            size: 20,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: AppColors.icon,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      // _searchQuery will be updated by listener
                    },
                  )
                  : null,
        ),
        // onChanged is handled by listener in initState
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainContentBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20), // Softer radius
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2), // Shadow for separation
          ),
        ],
      ),
      child: ClipRRect(
        // Ensures content respects border radius
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Column(
          children: [
            if (!_showSearchBar)
              _buildTabBar(), // Only show tab bar if not searching
            Expanded(
              // If search bar is shown, always show user list. Otherwise, show chat list.
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
    // This is more of a header for the chat list now
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), // Adjusted padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Conversations',
            style: TextStyle(
              fontSize: 20, // Slightly larger
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
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
                  color: AppColors.primary.withOpacity(
                    0.1,
                  ), // Use primary color with opacity
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$chatCount Active',
                  style: const TextStyle(
                    color: AppColors.primary, // Text color matches primary
                    fontWeight: FontWeight.w600, // Bolder
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
    final bool isUnread = unreadCount > 0;
    final bool hasAttachment =
        lastMessage.startsWith("[Attachment:") || lastMessage.contains("📎");

    return Container(
          margin: const EdgeInsets.only(bottom: 10), // Increased spacing
          decoration: BoxDecoration(
            color:
                isUnread
                    ? AppColors.primary.withOpacity(0.05)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(16), // Softer radius
            border: Border.all(
              color:
                  isUnread
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                          radius: 24, // Slightly larger
                          backgroundColor: AppColors.avatarBackground,
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              color: AppColors.avatarText,
                              fontWeight: FontWeight.bold, // Bolder
                              fontSize: 18, // Larger
                            ),
                          ),
                        ),
                        if (!isGroup && isOnline)
                          Positioned(
                            bottom: 1, // Adjusted position
                            right: 1, // Adjusted position
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.onlineIndicator,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
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
                                  style: TextStyle(
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600, // Bolder options
                                    fontSize: 16, // Larger
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                time,
                                style: TextStyle(
                                  color:
                                      isUnread
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                  fontSize: 12,
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
                                const Icon(
                                  Icons.attach_file_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              if (hasAttachment) const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        isUnread
                                            ? AppColors.textPrimary.withOpacity(
                                              0.9,
                                            )
                                            : AppColors.textSecondary,
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                    fontSize: 14, // Larger
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ), // Adjusted padding
                                  decoration: BoxDecoration(
                                    color: AppColors.unreadBadgeBackground,
                                    borderRadius: BorderRadius.circular(
                                      10,
                                    ), // Rounded rectangle
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: AppColors.unreadBadgeText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold, // Bolder
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
    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
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
                          backgroundColor: AppColors.avatarBackground,
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              color: AppColors.avatarText,
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
                                color: AppColors.onlineIndicator,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color:
                                  isOnline
                                      ? AppColors.onlineIndicator
                                      : AppColors.offlineIndicator,
                              fontSize: 13, // Slightly larger
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
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    else
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.icon,
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
    _searchController.clear();
    // _searchQuery is handled by listener
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // Make it transparent for custom shape
      builder:
          (context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                height:
                    MediaQuery.of(context).size.height *
                    0.85, // Increased height
                decoration: const BoxDecoration(
                  color: AppColors.dialogBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        20,
                        12,
                        12,
                      ), // Adjusted padding
                      child: Row(
                        children: [
                          const Text(
                            'Start New Chat',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.icon,
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
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.icon,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: AppColors.icon,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      // Listener will update _searchQuery and call setModalState
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor:
                              AppColors
                                  .background, // Lighter background for text field
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide.none, // No border, rely on fill
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        // onChanged handled by listener
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(child: _buildUsersList()),
                  ],
                ),
              );
            },
          ),
    ).whenComplete(() {
      _searchController
          .clear(); // Clear search for main screen if it was using the same controller
      // _searchQuery updated by listener
    });
  }

  void _showCreateGroupDialog() {
    Navigator.pop(context); // Close the options menu first
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismiss
      builder: (BuildContext context) {
        return CreateGroupDialog(
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.dialogBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ), // Adjusted padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Optional: Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border,
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
                    _showErrorSnackBar('Settings (Not Implemented)');
                  },
                ),
                const Divider(
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.border,
                ),
                _buildMenuListItem(
                  icon: Icons.logout_outlined,
                  title: 'Sign Out',
                  color: AppColors.error, // Red for sign out
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
                        // SnackBar for success can be added in AuthScreen or a wrapper
                      }
                    } catch (e) {
                      if (mounted) {
                        _showErrorSnackBar('Error signing out: $e');
                      }
                    }
                  },
                ),
                const SizedBox(height: 8), // Bottom padding
              ],
            ),
          ),
    );
  }

  Widget _buildMenuListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.icon, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 4,
      ), // Adjusted padding
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ), // Subtle shape for tap feedback
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
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ), // Softer radius
      title: const Text(
        'Create New Group',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: SizedBox(
        width: double.maxFinite, // Ensure it takes available width
        height:
            MediaQuery.of(context).size.height *
            0.6, // Fixed height for scrollable content
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'Enter group name',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchUserController,
              decoration: InputDecoration(
                labelText: 'Add Members',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'Search users to add',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.icon,
                ),
                suffixIcon:
                    _userSearchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: AppColors.icon,
                          ),
                          onPressed: () {
                            _searchUserController.clear();
                          },
                        )
                        : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
              // onChanged handled by listener
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getDialogUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Text(
                      "Error loading users.",
                      style: TextStyle(color: AppColors.error),
                    );
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
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
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true, // Important for Column layout
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
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
                          backgroundColor: AppColors.avatarBackground
                              .withOpacity(0.8),
                          child: Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.avatarText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        activeColor: AppColors.primary,
                        controlAffinity:
                            ListTileControlAffinity.leading, // Checkbox on left
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        tileColor:
                            isSelected
                                ? AppColors.primary.withOpacity(0.05)
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
            // Display selected users (optional)
            if (_selectedUsersData.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40, // Fixed height for the chip list
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
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    (user['name'] as String)
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.textOnPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                label: Text(
                                  user['name'] as String,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.15,
                                ),
                                onDeleted: () => _toggleUserSelection(user),
                                deleteIconColor: AppColors.primary.withOpacity(
                                  0.7,
                                ),
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
            const SizedBox(height: 16), // Space before actions
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16,
      ), // Adjusted padding
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.group_add_rounded, size: 18),
          label: const Text('Create Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
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
                  backgroundColor: AppColors.error,
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
