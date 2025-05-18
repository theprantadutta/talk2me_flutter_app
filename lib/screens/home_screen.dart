import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/chat_user.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<ChatUser> _dummyUsers = [
    ChatUser(
      id: '1',
      name: 'Sarah Johnson',
      avatar: 'https://i.pravatar.cc/150?img=1',
      lastMessage: 'Hey, are we still meeting tomorrow?',
      time: '10:30 AM',
      unreadCount: 2,
      isOnline: true,
    ),
    ChatUser(
      id: '2',
      name: 'Mike Chen',
      avatar: 'https://i.pravatar.cc/150?img=11',
      lastMessage: 'Sent you the design files 📎',
      time: 'Yesterday',
      unreadCount: 0,
      isOnline: false,
    ),
    ChatUser(
      id: '3',
      name: 'Emma Wilson',
      avatar: 'https://i.pravatar.cc/150?img=5',
      lastMessage: 'Thanks for your help!',
      time: 'Yesterday',
      unreadCount: 3,
      isOnline: false,
    ),
    ChatUser(
      id: '4',
      name: 'David Kim',
      avatar: 'https://i.pravatar.cc/150?img=7',
      lastMessage: 'Let me know when you arrive',
      time: 'Monday',
      unreadCount: 0,
      isOnline: true,
    ),
    ChatUser(
      id: '5',
      name: 'Team Talk2Me',
      avatar: 'https://i.pravatar.cc/150?img=60',
      lastMessage: 'Meeting at 3 PM today',
      time: 'Sunday',
      unreadCount: 5,
      isOnline: false,
    ),
    // Adding more users to demonstrate scrolling
    ChatUser(
      id: '6',
      name: 'Alex Thompson',
      avatar: 'https://i.pravatar.cc/150?img=20',
      lastMessage: 'Did you see that new movie?',
      time: 'Friday',
      unreadCount: 1,
      isOnline: true,
    ),
    ChatUser(
      id: '7',
      name: 'Olivia Parker',
      avatar: 'https://i.pravatar.cc/150?img=25',
      lastMessage: 'Let\'s grab coffee next week',
      time: 'Thursday',
      unreadCount: 0,
      isOnline: true,
    ),
    ChatUser(
      id: '8',
      name: 'Ethan Miller',
      avatar: 'https://i.pravatar.cc/150?img=30',
      lastMessage: 'Thanks for the recommendation!',
      time: 'Wednesday',
      unreadCount: 0,
      isOnline: false,
    ),
  ];

  late final AnimationController _backgroundAnimController;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _backgroundAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _backgroundAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _backgroundAnimController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.purple, Colors.blue],
                    transform: GradientRotation(
                      _backgroundAnimController.value * 2 * math.pi,
                    ),
                  ),
                ),
              );
            },
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar (Fixed)
                _buildAppBar(),

                // Search Bar (conditional)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      _showSearchBar
                          ? _buildSearchBar()
                          : const SizedBox.shrink(),
                ),

                // Conversations with Sliver implementation
                Expanded(child: _buildSliverContent()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
            onPressed: () {},
            backgroundColor: Colors.purple,
            elevation: 8,
            child: const Icon(Icons.message, size: 25, color: Colors.white),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: 2000.ms,
            curve: Curves.easeInOut,
          )
          .animate()
          .fadeIn(delay: 500.ms),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Talk2Me',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showSearchBar ? Icons.close : Icons.search,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showSearchBar = !_showSearchBar;
                    if (!_showSearchBar) {
                      _searchController.clear();
                    }
                  });
                },
              ).animate().fadeIn(delay: 200.ms),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {},
              ).animate().fadeIn(delay: 300.ms),
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=3',
                ),
              ).animate().fadeIn(delay: 400.ms).scale(),
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
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white70, size: 18),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildSliverContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: CustomScrollView(
          slivers: [
            // Top Tab Indicator
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                alignment: Alignment.center,
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            // Stories Section (disappears when scrolling)
            SliverToBoxAdapter(
              child: _buildStoriesSection().animate().fadeIn(delay: 200.ms),
            ),

            // Fixed "Conversations" Header
            SliverPersistentHeader(
              pinned: true,
              delegate: _ConversationsHeaderDelegate(
                dummyUsersLength: _dummyUsers.length,
              ),
            ),

            // Chat List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final user = _dummyUsers[index];
                  return _buildChatItem(user, index);
                }, childCount: _dummyUsers.length),
              ),
            ),

            // Bottom padding for better scrolling experience
            // const SliverToBoxAdapter(
            //   child: SizedBox(height: 80), // Additional padding at the bottom
            // ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStoriesSection() {
    return Container(
      height: 130,
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dummyUsers.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildMyStatus();
          }
          return _buildUserStatus(_dummyUsers[index - 1], index - 1);
        },
      ),
    );
  }

  Widget _buildMyStatus() {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150?img=3',
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Story',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2);
  }

  Widget _buildUserStatus(ChatUser user, int index) {
    final bool hasUnreadStory =
        index % 2 == 0; // Simulating some users with unread stories

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      hasUnreadStory
                          ? const LinearGradient(
                            colors: [Colors.purple, Colors.blue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  border:
                      hasUnreadStory
                          ? null
                          : Border.all(
                            color: Colors.grey.withOpacity(0.5),
                            width: 2,
                          ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(user.avatar),
                ),
              ),
              if (user.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            user.name.split(' ')[0],
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(delay: (150 + index * 50).ms).slideY(begin: 0.2);
  }

  Widget _buildChatItem(ChatUser user, int index) {
    final bool hasAttachment = user.lastMessage.contains('📎');
    final bool isUnread = user.unreadCount > 0;

    return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isUnread ? Colors.purple.withOpacity(0.05) : Colors.white,
            border: Border.all(color: Colors.purple.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      final randomUser = 'user_${math.Random().nextInt(10000)}';
                      // For a one-on-one chat
                      return ChatScreen(
                        userId: randomUser,
                        chatId: "recipientUser456",
                        isGroupChat: false,
                      );

                      // For a group chat
                      // ChatScreen(
                      //   userId: "currentUser123",
                      //   chatId: "groupId789",
                      //   chatName: "Flutter Developers",
                      //   isGroupChat: true,
                      //   participants: ["currentUser123", "user456", "user789"],
                      // );
                    },
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Hero(
                      tag: 'avatar-${user.id}',
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: NetworkImage(user.avatar),
                            ),
                          ),
                          if (user.isOnline) // Simulating online status
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  fontWeight:
                                      isUnread
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                user.time,
                                style: TextStyle(
                                  color: isUnread ? Colors.purple : Colors.grey,
                                  fontSize: 12,
                                  fontWeight:
                                      isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (hasAttachment)
                                const Icon(
                                  Icons.attach_file,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                              if (hasAttachment) const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  user.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        isUnread
                                            ? Colors.black
                                            : Colors.grey[600],
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.purple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    user.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
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
        .fadeIn(delay: (100 * index + 400).ms)
        .slideX(begin: 0.1)
        .animate(
          onPlay:
              isUnread
                  ? (controller) => controller.repeat(reverse: true)
                  : null,
          autoPlay: isUnread,
        )
        .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.2))
        .animate();
  }
}

// Custom delegate for persistent header
class _ConversationsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int dummyUsersLength;

  _ConversationsHeaderDelegate({required this.dummyUsersLength});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Calculate opacity for the background based on scroll amount
    final double opacity = shrinkOffset > 0 ? 1.0 : 0.9;

    return Container(
      color: Colors.white.withOpacity(opacity),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Text(
              'Conversations',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Text(
                '$dummyUsersLength active',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60;

  @override
  double get minExtent => 60;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
