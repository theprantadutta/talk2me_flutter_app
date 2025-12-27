import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/animation_constants.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/common/app_avatar.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/gradient_background.dart';
import '../widgets/common/loading_shimmer.dart';
import '../widgets/glass/glass_app_bar.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_container.dart';
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

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

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

    _fabAnimationController = AnimationController(
      duration: AnimationConstants.normal,
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    Future.delayed(AnimationConstants.slow, () {
      if (mounted) _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
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

  // Chat action methods
  Future<void> _togglePinChat(String chatId, bool currentlyPinned) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'pinnedBy': currentlyPinned
            ? FieldValue.arrayRemove([widget.currentUserId])
            : FieldValue.arrayUnion([widget.currentUserId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyPinned ? 'Chat unpinned' : 'Chat pinned'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to update chat');
    }
  }

  Future<void> _toggleMuteChat(String chatId, bool currentlyMuted) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'mutedBy': currentlyMuted
            ? FieldValue.arrayRemove([widget.currentUserId])
            : FieldValue.arrayUnion([widget.currentUserId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyMuted
                ? 'Notifications enabled'
                : 'Notifications muted'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to update chat');
    }
  }

  Future<void> _archiveChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'archivedBy': FieldValue.arrayUnion([widget.currentUserId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat archived'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _unarchiveChat(chatId),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to archive chat');
    }
  }

  Future<void> _unarchiveChat(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'archivedBy': FieldValue.arrayRemove([widget.currentUserId]),
      });
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to restore chat');
    }
  }

  Stream<QuerySnapshot> _getUsersStream() {
    return _firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: widget.currentUserId)
        .snapshots();
  }

  Future<int> _getUnreadCount(String chatId) async {
    try {
      final unreadQuerySnapshot =
          await _firestore.collection('chats/$chatId/messages').get();

      final unreadDocs = unreadQuerySnapshot.docs.where((doc) {
        final readBy = List<String>.from(doc['readBy'] ?? []);
        return !readBy.contains(widget.currentUserId);
      }).toList();

      return unreadDocs.length;
    } catch (e) {
      if (kDebugMode) print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> _createOrNavigateToIndividualChat(
    String otherUserId,
    String otherUserName,
  ) async {
    final existingChatQuery = await _firestore
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
        if (mounted) _showErrorSnackBar('Current user not found');
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
          builder: (context) => ChatScreen(
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
      if (mounted) _showErrorSnackBar('Current user not found');
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
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
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

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat.jm().format(dateTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat.E().format(dateTime);
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientScaffold(
      gradientStyle: GradientStyle.mesh,
      appBar: GlassAppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                'assets/clean_logo.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.chat_bubble_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Talk2Me',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.close_rounded : Icons.search_rounded,
            ),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) _searchController.clear();
              });
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final avatarUrl = userData?['avatarUrl'] as String?;
              final displayName = userData?['fullName'] as String? ?? 'U';

              return GestureDetector(
                onTap: _showOptionsMenu,
                child: AppAvatar(
                  imageUrl: avatarUrl,
                  name: displayName,
                  size: 36,
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: GlassFab(
          icon: Icons.add_comment_outlined,
          onPressed: _showNewChatOptions,
          tooltip: 'New Chat',
          showGlow: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            AnimatedSize(
              duration: AnimationConstants.fast,
              child: _showSearchBar ? _buildSearchBar() : const SizedBox.shrink(),
            ),
            // Main content
            Expanded(
              child: _showSearchBar ? _buildUsersList() : _buildChatList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: GlassContainer(
        blur: 12,
        opacity: isDark ? 0.1 : 0.6,
        borderRadius: AppRadius.lg,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search conversations or users...',
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState.error(
            message: 'Error loading chats',
            onRetry: () => setState(() {}),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 5,
            itemBuilder: (context, index) => const ChatListShimmer(),
          );
        }

        final chats = snapshot.data?.docs ?? [];

        if (chats.isEmpty) {
          return EmptyState.noChats(
            onStartChat: _showNewChatOptions,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chatDoc = chats[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            return _buildChatTile(chatDoc.id, chatData, index);
          },
        );
      },
    );
  }

  Widget _buildChatTile(String chatId, Map<String, dynamic> chatData, int index) {
    final theme = Theme.of(context);
    final bool isGroupChat = chatData['isGroupChat'] ?? false;

    // Check pinned/muted status
    final pinnedBy = List<String>.from(chatData['pinnedBy'] ?? []);
    final mutedBy = List<String>.from(chatData['mutedBy'] ?? []);
    final archivedBy = List<String>.from(chatData['archivedBy'] ?? []);
    final isPinned = pinnedBy.contains(widget.currentUserId);
    final isMuted = mutedBy.contains(widget.currentUserId);
    final isArchived = archivedBy.contains(widget.currentUserId);

    // Skip archived chats in main list
    if (isArchived) return const SizedBox.shrink();

    String chatDisplayName;
    if (isGroupChat) {
      chatDisplayName = chatData['groupName'] ?? 'Group Chat';
    } else {
      final participants = List<String>.from(chatData['participants']);
      final participantNames =
          Map<String, String>.from(chatData['participantNames'] ?? {});
      final otherUserId = participants.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => '',
      );
      chatDisplayName = participantNames[otherUserId] ?? 'Unknown User';
    }

    final lastMessage = chatData['lastMessage'] ?? '';
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    final timeString = _formatTime(lastMessageTime);

    return FutureBuilder<int>(
      future: _getUnreadCount(chatId),
      builder: (context, unreadSnapshot) {
        final unreadCount = unreadSnapshot.data ?? 0;
        final hasUnread = unreadCount > 0;

        Widget tile = GestureDetector(
          onLongPress: () {
            _showChatOptions(
              chatId: chatId,
              chatName: chatDisplayName,
              isPinned: isPinned,
              isMuted: isMuted,
            );
          },
          child: AnimatedContainer(
            duration: AnimationConstants.fast,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              blur: 10,
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      userId: widget.currentUserId,
                      chatId: chatId,
                      chatName: chatDisplayName,
                      isGroupChat: isGroupChat,
                    ),
                  ),
                );
              },
            child: Row(
              children: [
                // Avatar
                if (isGroupChat)
                  AppAvatar(
                    name: chatDisplayName,
                    size: 52,
                    backgroundColor:
                        theme.colorScheme.secondary.withValues(alpha: 0.3),
                  )
                else
                  _buildUserAvatar(chatData, chatDisplayName),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Row(
                        children: [
                          if (isGroupChat)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.group_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              chatDisplayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight:
                                    hasUnread ? FontWeight.w700 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.push_pin_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          Text(
                            timeString,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: hasUnread
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // Message row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty
                                  ? 'No messages yet'
                                  : lastMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: hasUnread
                                    ? theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8)
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                fontWeight:
                                    hasUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMuted)
                            Padding(
                              padding: const EdgeInsets.only(left: AppSpacing.xs),
                              child: Icon(
                                Icons.volume_off_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          if (hasUnread)
                            Container(
                              margin: const EdgeInsets.only(left: AppSpacing.sm),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
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
        );

        // Add stagger animation
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: tile,
        );
      },
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> chatData, String displayName) {
    final participants = List<String>.from(chatData['participants']);
    final otherUserId = participants.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      return AppAvatar(name: displayName, size: 52);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(otherUserId).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final avatarUrl = userData?['avatarUrl'] as String?;
        final isOnline = userData?['isOnline'] ?? false;

        return AppAvatar(
          imageUrl: avatarUrl,
          name: displayName,
          size: 52,
          isOnline: isOnline,
          showOnlineIndicator: true,
        );
      },
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState.error(message: 'Error loading users');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var users = snapshot.data?.docs ?? [];

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          users = users.where((doc) {
            final userData = doc.data() as Map<String, dynamic>;
            final fullName =
                (userData['fullName'] ?? '').toString().toLowerCase();
            final username =
                (userData['username'] ?? '').toString().toLowerCase();
            final email = (userData['email'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return fullName.contains(query) ||
                username.contains(query) ||
                email.contains(query);
          }).toList();
        }

        if (users.isEmpty) {
          return EmptyState.noUsers();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final userId = userDoc.id;
            final fullName = userData['fullName'] ?? 'Unknown User';
            final username = userData['username'] ?? '';
            final avatarUrl = userData['avatarUrl'] as String?;
            final isOnline = userData['isOnline'] ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassCard(
                blur: 10,
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () => _createOrNavigateToIndividualChat(userId, fullName),
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: avatarUrl,
                      name: fullName,
                      size: 48,
                      isOnline: isOnline,
                      showOnlineIndicator: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNewChatOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: AppRadius.bottomSheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.bottomSheetRadius,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Start a Conversation',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () {
                      Navigator.pop(context);
                      _showNewIndividualChatDialog();
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.md,
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Chat',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Start a one-on-one conversation',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateGroupDialog();
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.md,
                          ),
                          child: Icon(
                            Icons.group_add_outlined,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Group',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Create a group with multiple people',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNewIndividualChatDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: AppRadius.bottomSheetRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.bottomSheetRadius,
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Text(
                          'Select a User',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _getUsersStream(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final users = snapshot.data?.docs ?? [];

                            if (users.isEmpty) {
                              return EmptyState.noUsers();
                            }

                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final userDoc = users[index];
                                final userData =
                                    userDoc.data() as Map<String, dynamic>;
                                final userId = userDoc.id;
                                final fullName =
                                    userData['fullName'] ?? 'Unknown User';
                                final avatarUrl = userData['avatarUrl'] as String?;
                                final isOnline = userData['isOnline'] ?? false;

                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: GlassCard(
                                    blur: 8,
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _createOrNavigateToIndividualChat(
                                        userId,
                                        fullName,
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        AppAvatar(
                                          imageUrl: avatarUrl,
                                          name: fullName,
                                          size: 44,
                                          isOnline: isOnline,
                                          showOnlineIndicator: true,
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Text(
                                            fullName,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupNameController = TextEditingController();
    final List<Map<String, dynamic>> selectedUsers = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return ClipRRect(
                  borderRadius: AppRadius.bottomSheetRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.bottomSheetRadius,
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin:
                                const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: Column(
                              children: [
                                Text(
                                  'Create Group',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GlassContainer(
                                  blur: 10,
                                  opacity: isDark ? 0.1 : 0.6,
                                  borderRadius: AppRadius.md,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  child: TextField(
                                    controller: groupNameController,
                                    decoration: const InputDecoration(
                                      hintText: 'Group Name',
                                      border: InputBorder.none,
                                      prefixIcon:
                                          Icon(Icons.group_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (selectedUsers.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: selectedUsers.map((user) {
                                      return Chip(
                                        label: Text(user['name']),
                                        deleteIcon:
                                            const Icon(Icons.close, size: 16),
                                        onDeleted: () {
                                          setSheetState(() {
                                            selectedUsers.remove(user);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Select Members',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _getUsersStream(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                final users = snapshot.data?.docs ?? [];

                                return ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final userDoc = users[index];
                                    final userData =
                                        userDoc.data() as Map<String, dynamic>;
                                    final userId = userDoc.id;
                                    final fullName =
                                        userData['fullName'] ?? 'Unknown User';
                                    final avatarUrl =
                                        userData['avatarUrl'] as String?;
                                    final isSelected = selectedUsers.any(
                                        (u) => u['id'] == userId);

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AppSpacing.sm),
                                      child: GlassCard(
                                        blur: 8,
                                        padding:
                                            const EdgeInsets.all(AppSpacing.md),
                                        showGlow: isSelected,
                                        glowColor: theme.colorScheme.primary,
                                        onTap: () {
                                          setSheetState(() {
                                            if (isSelected) {
                                              selectedUsers.removeWhere(
                                                  (u) => u['id'] == userId);
                                            } else {
                                              selectedUsers.add({
                                                'id': userId,
                                                'name': fullName,
                                              });
                                            }
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            AppAvatar(
                                              imageUrl: avatarUrl,
                                              name: fullName,
                                              size: 40,
                                            ),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Text(
                                                fullName,
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: theme.colorScheme.primary,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.lg,
                              right: AppSpacing.lg,
                              bottom:
                                  MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                            ),
                            child: GlassButton(
                              text: 'Create Group',
                              onPressed: selectedUsers.isEmpty
                                  ? null
                                  : () {
                                      final groupName =
                                          groupNameController.text.trim();
                                      if (groupName.isEmpty) {
                                        _showErrorSnackBar(
                                            'Please enter a group name');
                                        return;
                                      }
                                      _createGroupChat(groupName, selectedUsers);
                                    },
                              fullWidth: true,
                              showGlow: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showOptionsMenu() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: AppRadius.bottomSheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.bottomSheetRadius,
                color: isDark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.9),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOptionItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    isDestructive: true,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      await _firestore
                          .collection('users')
                          .doc(widget.currentUserId)
                          .update({
                        'isOnline': false,
                        'lastSeen': FieldValue.serverTimestamp(),
                      });
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + AppSpacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isDestructive
              ? theme.colorScheme.error
              : theme.colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
    );
  }

  void _showChatOptions({
    required String chatId,
    required String chatName,
    required bool isPinned,
    required bool isMuted,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: AppRadius.bottomSheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.bottomSheetRadius,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Pin option
                  _buildChatOptionItem(
                    icon: isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    title: isPinned ? 'Unpin Chat' : 'Pin Chat',
                    subtitle: isPinned
                        ? 'Remove from top of chat list'
                        : 'Keep this chat at the top',
                    onTap: () {
                      Navigator.pop(context);
                      _togglePinChat(chatId, isPinned);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Mute option
                  _buildChatOptionItem(
                    icon: isMuted
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    title: isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                    subtitle: isMuted
                        ? 'Enable notifications for this chat'
                        : 'Stop receiving notifications',
                    onTap: () {
                      Navigator.pop(context);
                      _toggleMuteChat(chatId, isMuted);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Archive option
                  _buildChatOptionItem(
                    icon: Icons.archive_outlined,
                    title: 'Archive Chat',
                    subtitle: 'Move chat to archived folder',
                    onTap: () {
                      Navigator.pop(context);
                      _archiveChat(chatId);
                    },
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDestructive
                  ? theme.colorScheme.error.withValues(alpha: 0.1)
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.md,
            ),
            child: Icon(
              icon,
              color: isDestructive
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDestructive ? theme.colorScheme.error : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
