import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:talk2me_flutter_app/screens/auth_screen.dart';

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
    // Used for searching users to start 1-on-1 chat or add to group
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
          await _firestore
              .collection('chats/$chatId/messages')
              // Optional: Ensure we are not counting our own messages as unread,
              // though 'readBy' logic should inherently handle this if sender is always in 'readBy'.
              // .where('sender', isNotEqualTo: widget.currentUserId)
              .get();

      // Firestore does not support "arrayDoesNotContain", so filter in Dart:
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
      return 0; // Return 0 in case of an error
    }
  }

  Future<void> _createOrNavigateToIndividualChat(
    String otherUserId,
    String otherUserName,
  ) async {
    // Check if chat already exists
    final existingChatQuery =
        await _firestore
            .collection('chats')
            .where('participants', arrayContains: widget.currentUserId)
            .where(
              'isGroupChat',
              isEqualTo: false,
            ) // Ensure it's not a group chat
            .get();

    String? chatId;

    for (var doc in existingChatQuery.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(otherUserId) && participants.length == 2) {
        chatId = doc.id;
        break;
      }
    }

    // Create new chat if it doesn't exist
    if (chatId == null) {
      final currentUserDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();
      if (!currentUserDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current user not found')),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group name and participants are required.'),
          ),
        );
      }
      return;
    }

    final currentUserDoc =
        await _firestore.collection('users').doc(widget.currentUserId).get();
    if (!currentUserDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Current user not found')));
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
      'participantNames':
          participantNames, // Storing names for potential future use (e.g., "X sent a message")
      'adminIds': [widget.currentUserId], // Current user is the first admin
      'lastMessage': 'Group created by $currentUserName',
      'lastMessageSenderId': widget.currentUserId, // Or a system message ID
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'isGroupChat': true,
      'groupAvatar': '', // Placeholder for group avatar URL
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

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading chats'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Color(0xFF718096),
                ),
                SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(color: Color(0xFF718096), fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Start a new conversation or group',
                  style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                ),
              ],
            ),
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
            // bool isOnlineStatusApplicable = !isGroupChat;
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
                // Fallback if other user somehow not found (should not happen in a 1v1 chat)
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
                    // For 1-on-1 chats, get the other user's online status
                    // For group chats, online status is not shown directly on the chat item
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
                      // For group chats, pass isOnline as false as it's not displayed at chat item level
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
    // This widget is now more generic. If onUserTap is provided, it's for selection mode.
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading users'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];
        final filteredUsers =
            users.where((doc) {
              final userData = doc.data() as Map<String, dynamic>;
              final userName =
                  userData['fullName'] ??
                  ''; // Ensure 'fullName' matches your Firestore field
              return userName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
            }).toList();

        if (filteredUsers.isEmpty) {
          return const Center(child: Text('No users found.'));
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
                    // Add other user data if needed by the callback
                  }, !isSelected);
                } else {
                  // Default action: navigate to 1-on-1 chat
                  _createOrNavigateToIndividualChat(
                    userDoc.id,
                    userData['fullName'] ?? 'Unknown User',
                  );
                  if (Navigator.canPop(context)) {
                    // If inside the modal sheet for new chat
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
      return DateFormat.Hm().format(date); // HH:mm format
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.EEEE().format(date); // Full day name
    } else {
      return DateFormat.yMd().format(date); // 01/MM/YYYY
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  _showSearchBar ? _buildSearchBar() : const SizedBox.shrink(),
            ),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewIndividualChatDialog, // Changed to be more specific
        backgroundColor: const Color(0xFF2D3748),
        elevation: 0,
        tooltip: 'New Chat',
        child: const Icon(Icons.message, size: 20, color: Colors.white),
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Talk2Me',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF2D3748),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ).animate().fadeIn(delay: 100.ms),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showSearchBar ? Icons.close : Icons.search,
                  color: const Color(0xFF718096),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ).animate().fadeIn(delay: 150.ms),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF718096),
                  size: 20,
                ),
                onPressed: _showOptionsMenu,
              ).animate().fadeIn(delay: 200.ms),
              StreamBuilder<DocumentSnapshot>(
                stream:
                    _firestore
                        .collection('users')
                        .doc(widget.currentUserId)
                        .snapshots(),
                builder: (context, snapshot) {
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  // Assuming 'avatarUrl' field exists, otherwise use initials
                  final avatarUrl = userData?['avatarUrl'] as String?;
                  final displayName = userData?['fullName'] as String? ?? "U";

                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2D3748),
                    backgroundImage:
                        avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                    child:
                        (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                              displayName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : null,
                  ).animate().fadeIn(delay: 250.ms);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Color(0xFF2D3748)),
        decoration: const InputDecoration(
          hintText: 'Search conversations or users...',
          hintStyle: TextStyle(color: Color(0xFFA0AEC0)),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Color(0xFF718096), size: 18),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    ).animate().fadeIn();
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              alignment: Alignment.center,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (!_showSearchBar) _buildTabBar(),
            Expanded(
              child: _showSearchBar ? _buildUsersList() : _buildChatList(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Conversations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D3748),
            ),
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: _getChatsStream(), // This already includes group chats
            builder: (context, snapshot) {
              final chatCount = snapshot.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Text(
                  '$chatCount active',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF718096),
                    fontWeight: FontWeight.w500,
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
    required bool
    isOnline, // Applicable for 1-on-1, ignored for group display here
    required bool isGroup,
    required String avatarLetter,
    required int index,
    required VoidCallback onTap,
  }) {
    final bool isUnread = unreadCount > 0;
    // Simplified: attachment icon based on a known prefix or content check.
    // This could be a field in your message data.
    final bool hasAttachment =
        lastMessage.startsWith("[Attachment:") || lastMessage.contains("📎");

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFF7FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isUnread
                  ? const Color(0xFF2D3748).withOpacity(0.1)
                  : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF2D3748),
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (!isGroup &&
                        isOnline) // Show online dot only for 1-on-1 and if user is online
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                fontSize: 15,
                                color: const Color(0xFF2D3748),
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              color:
                                  isUnread
                                      ? const Color(0xFF2D3748)
                                      : const Color(0xFF718096),
                              fontSize: 12,
                              fontWeight:
                                  isUnread
                                      ? FontWeight.w500
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
                              Icons.attach_file,
                              size: 12,
                              color: Color(0xFF718096),
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
                                        ? const Color(0xFF2D3748)
                                        : const Color(0xFF718096),
                                fontWeight:
                                    isUnread
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2D3748),
                                shape:
                                    BoxShape
                                        .circle, // Making it a circle for single digit, adjust if needed
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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
    ).animate().fadeIn(delay: (50 * index + 200).ms);
  }

  Widget _buildUserItem({
    required String userId,
    required String name,
    required bool isOnline,
    required String avatarLetter,
    required int index,
    required VoidCallback onTap,
    bool showCheckbox = false, // To indicate selection mode
    bool isSelected = false, // If in selection mode, is this user selected
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            isSelected
                ? const Color(0xFFE2E8F0)
                : Colors.white, // Highlight if selected
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF2D3748),
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color:
                              isOnline ? Colors.green : const Color(0xFF718096),
                          fontSize: 12,
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
                    }, // onTap will handle the logic
                    activeColor: const Color(0xFF2D3748),
                  )
                else // Show chat icon if not in selection mode
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Color(0xFF718096),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
      delay: (50 * index + (_showSearchBar ? 0 : 200)).ms,
    ); // Adjust delay if search bar is active
  }

  void _showNewIndividualChatDialog() {
    // Reset search query for the dialog
    _searchController.clear();
    _searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            // Added StatefulBuilder to manage search within dialog
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'New Chat with',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      // Search bar for the dialog
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller:
                            _searchController, // Use the class's search controller
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            // Use setModalState to update dialog's search
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _buildUsersList(),
                    ), // _buildUsersList will use _searchQuery
                  ],
                ),
              );
            },
          ),
    ).whenComplete(() {
      // Clear search when dialog is closed
      _searchController.clear();
      _searchQuery = '';
      // Potentially call setState for the main screen if search bar was visible there
      // and its state needs resetting, but here it's mainly for the dialog's search.
    });
  }

  void _showCreateGroupDialog() {
    Navigator.pop(context); // Close the options menu first
    showDialog(
      context: context,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.group_add_outlined,
                    color: Color(0xFF2D3748),
                  ),
                  title: const Text(
                    'New Group',
                    style: TextStyle(color: Color(0xFF2D3748)),
                  ),
                  onTap: _showCreateGroupDialog,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF2D3748),
                  ),
                  title: const Text(
                    'Settings',
                    style: TextStyle(color: Color(0xFF2D3748)),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to settings screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings (Not Implemented)'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_outlined,
                    color: Color(0xFFB91C1C),
                  ), // Red color for logout
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  onTap: () async {
                    Navigator.pop(context); // Close the modal
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
                        // Navigate to AuthScreen after sign out
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                          (Route<dynamic> route) =>
                              false, // Remove all previous routes
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
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
  final List<Map<String, dynamic>> _selectedUsersData =
      []; // Stores {'id': userId, 'name': userName}

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
      title: const Text('Create New Group'),
      contentPadding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        0,
      ), // Adjust padding
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              // Search bar for users within the dialog
              controller: _searchUserController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                hintText: 'Type to find users to add',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _userSearchQuery = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getDialogUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Text("Error loading users.");
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                    return const Center(child: Text("No users found."));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
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
                        title: Text(userName),
                        value: isSelected,
                        onChanged: (bool? value) {
                          _toggleUserSelection({
                            'id': userId,
                            'name': userName,
                          });
                        },
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFF2D3748),
                          child: Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        activeColor: const Color(0xFF2D3748),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF718096)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D3748),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (_groupNameController.text.isNotEmpty &&
                _selectedUsersData.isNotEmpty) {
              widget.onGroupCreated(
                _groupNameController.text,
                _selectedUsersData,
              );
              // Navigator.pop(context); // The onGroupCreated callback handles navigation
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please enter a group name and select at least one member.',
                  ),
                ),
              );
            }
          },
          child: const Text('Create Group'),
        ),
      ],
    );
  }
}
