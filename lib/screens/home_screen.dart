import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final unreadQuery =
        await _firestore
            .collection('chats/$chatId/messages')
            .where('sender', isNotEqualTo: widget.currentUserId)
            .where('isRead', isEqualTo: false)
            .get();

    return unreadQuery.docs.length;
  }

  Future<void> _createOrNavigateToChat(
    String otherUserId,
    String otherUserName,
  ) async {
    // Check if chat already exists
    final existingChatQuery =
        await _firestore
            .collection('chats')
            .where('participants', arrayContains: widget.currentUserId)
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
      print('Current User Doc: ${currentUserDoc.data()}');
      if (!currentUserDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Current user not found')));
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
                  'Start a new conversation',
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
            final participants = List<String>.from(chatData['participants']);
            final participantNames = Map<String, String>.from(
              chatData['participantNames'] ?? {},
            );

            // Get the other participant's info
            final otherUserId = participants.firstWhere(
              (id) => id != widget.currentUserId,
            );
            final otherUserName =
                participantNames[otherUserId] ?? 'Unknown User';

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getLastMessage(chatDoc.id),
              builder: (context, messageSnapshot) {
                return FutureBuilder<int>(
                  future: _getUnreadCount(chatDoc.id),
                  builder: (context, unreadSnapshot) {
                    return StreamBuilder<DocumentSnapshot>(
                      stream:
                          _firestore
                              .collection('users')
                              .doc(otherUserId)
                              .snapshots(),
                      builder: (context, userSnapshot) {
                        final userData =
                            userSnapshot.data?.data() as Map<String, dynamic>?;
                        final isOnline = userData?['isOnline'] ?? false;
                        final lastMessage =
                            messageSnapshot.data?['message'] ??
                            'No messages yet';
                        final lastMessageTime =
                            messageSnapshot.data?['timestamp'] as Timestamp?;
                        final unreadCount = unreadSnapshot.data ?? 0;

                        return _buildChatItem(
                          chatId: chatDoc.id,
                          name: otherUserName,
                          lastMessage: lastMessage,
                          time: _formatTime(lastMessageTime),
                          unreadCount: unreadCount,
                          isOnline: isOnline,
                          index: index,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUsersList() {
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
              final userName = userData['name'] ?? '';
              return userName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
            }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userDoc = filteredUsers[index];
            final userData = userDoc.data() as Map<String, dynamic>;

            return _buildUserItem(
              userId: userDoc.id,
              name: userData['fullName'] ?? 'Unknown User',
              isOnline: userData['isOnline'] ?? false,
              avatar:
                  userData['avatar'] ??
                  'https://i.pravatar.cc/150?img=${index + 1}',
              index: index,
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
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            _buildAppBar(),

            // Search Bar (conditional)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  _showSearchBar ? _buildSearchBar() : const SizedBox.shrink(),
            ),

            // Main Content
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: const Color(0xFF2D3748),
        elevation: 0,
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
                  final avatar =
                      userData?['avatar'] ?? 'https://i.pravatar.cc/150?img=3';

                  return CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(avatar),
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
            // Top indicator
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

            // Tab bar
            if (!_showSearchBar) _buildTabBar(),

            // Content
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
            stream: _getChatsStream(),
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
    required bool isOnline,
    required int index,
  }) {
    final bool isUnread = unreadCount > 0;
    final bool hasAttachment = lastMessage.contains('📎');

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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ChatScreen(
                      userId: widget.currentUserId,
                      chatId: chatId,
                      chatName: name,
                      isGroupChat: false,
                    ),
              ),
            );
          },
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
                        name.substring(0, 1).toUpperCase(),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight:
                                  isUnread ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 15,
                              color: const Color(0xFF2D3748),
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
                                shape: BoxShape.circle,
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
    required String avatar,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _createOrNavigateToChat(userId, name),
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
                        name.substring(0, 1).toUpperCase(),
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
    ).animate().fadeIn(delay: (50 * index + 200).ms);
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
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
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'New Chat',
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
                const Divider(height: 1),
                Expanded(child: _buildUsersList()),
              ],
            ),
          ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () async {
                    // Update user offline status
                    await _firestore
                        .collection('users')
                        .doc(widget.currentUserId)
                        .set({
                          'isOnline': false,
                          'lastSeen': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                    try {
                      final auth = FirebaseAuth.instance;
                      await auth.signOut();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out successfully'),
                          ),
                        );
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(),
                        );
                      }
                    } catch (e) {
                      // Handle sign out error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error signing out: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }
}
