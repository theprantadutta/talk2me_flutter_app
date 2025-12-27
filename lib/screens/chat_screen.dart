// // lib/chat_screen.dart
// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart'; // For mapEquals
// import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:intl/intl.dart';

// import '../models/chat_message.dart';
// // Assuming home_screen.dart is in the same directory or adjust path
// // For CreateGroupDialog, ensure it's accessible.
// import 'home_screen.dart'; // This makes CreateGroupDialog available
// // Removed: import '../app_colors.dart';

// class ChatScreen extends StatefulWidget {
//   final String userId;
//   final String chatId;
//   final String? chatName;
//   final bool isGroupChat;

//   const ChatScreen({
//     required this.userId,
//     required this.chatId,
//     this.chatName,
//     this.isGroupChat = false,
//     super.key,
//   });

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   Timer? _typingTimer;
//   bool _isOverallTyping = false;
//   final Map<String, bool> _usersTypingStatus = {};
//   Map<String, String> _participantDisplayNames = {};
//   String _resolvedChatName = '';
//   String _currentUserDisplayName = '';

//   String get _chatDocumentPath => 'chats/${widget.chatId}';
//   String get _messagesCollectionPath => '$_chatDocumentPath/messages';
//   String get _typingCollectionPath => '$_chatDocumentPath/typing';

//   @override
//   void initState() {
//     super.initState();
//     _resolvedChatName =
//         widget.chatName ?? (widget.isGroupChat ? 'Group' : 'Chat');
//     _loadCurrentUserData();
//     if (widget.isGroupChat) {
//       _fetchGroupChatDetails();
//     }
//     _listenToTypingStatus();
//     _markMessagesAsRead();
//   }

//   Future<void> _loadCurrentUserData() async {
//     try {
//       final userDoc =
//           await _firestore.collection('users').doc(widget.userId).get();
//       if (userDoc.exists && mounted) {
//         setState(() {
//           _currentUserDisplayName = userDoc.data()?['fullName'] ?? 'You';
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _currentUserDisplayName = 'You';
//         });
//       }
//       if (kDebugMode) {
//         print("Error loading current user's name: $e");
//       }
//     }
//   }

//   Future<void> _fetchGroupChatDetails() async {
//     try {
//       final chatDoc = await _firestore.doc(_chatDocumentPath).get();
//       if (chatDoc.exists && mounted) {
//         final data = chatDoc.data() as Map<String, dynamic>;
//         setState(() {
//           _participantDisplayNames = Map<String, String>.from(
//             data['participantNames'] ?? {},
//           );
//           if (data.containsKey('groupName') && data['groupName'] != null) {
//             _resolvedChatName = data['groupName'];
//           }
//         });
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print("Error fetching group details: $e");
//       }
//     }
//   }

//   Future<void> _markMessagesAsRead() async {
//     try {
//       final messagesSnapshot =
//           await _firestore.collection(_messagesCollectionPath).get();
//       if (messagesSnapshot.docs.isEmpty) return;

//       WriteBatch batch = _firestore.batch();
//       for (var doc in messagesSnapshot.docs) {
//         final data = doc.data();
//         final readBy = (data['readBy'] as List?)?.cast<String>() ?? [];
//         if (!readBy.contains(widget.userId)) {
//           batch.update(doc.reference, {
//             'readBy': FieldValue.arrayUnion([widget.userId]),
//           });
//         }
//       }
//       await batch.commit();
//     } catch (e) {
//       if (kDebugMode) {
//         print("Error marking messages as read: $e");
//       }
//     }
//   }

//   void _listenToTypingStatus() {
//     _firestore.collection(_typingCollectionPath).snapshots().listen((snapshot) {
//       if (!mounted) return;

//       Map<String, bool> newTypingUsers = {};
//       for (var doc in snapshot.docs) {
//         if (doc.id != widget.userId) {
//           final data = doc.data();
//           final isTyping = data['isTyping'] ?? false;
//           final timestamp =
//               (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
//           if (isTyping && DateTime.now().difference(timestamp).inSeconds < 5) {
//             newTypingUsers[doc.id] = true;
//           } else {
//             newTypingUsers[doc.id] = false;
//           }
//         }
//       }
//       newTypingUsers.removeWhere((key, value) => value == false);

//       bool newOverallTypingState = newTypingUsers.values.any(
//         (typing) => typing,
//       );
//       bool changed = false;

//       if (!mapEquals(newTypingUsers, _usersTypingStatus)) {
//         _usersTypingStatus.clear();
//         _usersTypingStatus.addAll(newTypingUsers);
//         changed = true;
//       }

//       if (_isOverallTyping != newOverallTypingState) {
//         _isOverallTyping = newOverallTypingState;
//         changed = true;
//       }

//       if (changed && mounted) {
//         setState(() {});
//       }
//     });
//   }

//   @override
//   void dispose() {
//     if (mounted) {
//       _stopTyping();
//     }
//     _messageController.dispose();
//     _scrollController.dispose();
//     _typingTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _sendMessage() async {
//     if (_messageController.text.trim().isEmpty) return;

//     final messageText = _messageController.text.trim();
//     _messageController.clear();
//     if (mounted) _stopTyping();

//     try {
//       await _firestore.collection(_messagesCollectionPath).add({
//         'message': messageText,
//         'sender': widget.userId,
//         'senderName': _currentUserDisplayName,
//         'timestamp': FieldValue.serverTimestamp(),
//         'readBy': [widget.userId],
//       });
//       await _firestore.doc(_chatDocumentPath).update({
//         'lastMessage': messageText,
//         'lastMessageTime': FieldValue.serverTimestamp(),
//         'lastMessageSenderId': widget.userId,
//       });

//       _scrollToBottom(isNewMessage: true);
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error sending message: $e');
//       }
//       if (mounted) {
//         _showErrorSnackBar('Failed to send message: ${e.toString()}');
//       }
//     }
//   }

//   void _handleTypingChange(String text) {
//     if (!mounted) return;
//     if (text.isNotEmpty) {
//       _startTyping();
//     } else {
//       _stopTyping();
//     }
//   }

//   void _startTyping() {
//     _firestore.collection(_typingCollectionPath).doc(widget.userId).set({
//       'isTyping': true,
//       'timestamp': FieldValue.serverTimestamp(),
//       'userName': _currentUserDisplayName,
//     });
//     _typingTimer?.cancel();
//     _typingTimer = Timer(const Duration(seconds: 3), () {
//       if (mounted) _stopTyping();
//     });
//   }

//   void _stopTyping() {
//     _typingTimer?.cancel();
//     _firestore.collection(_typingCollectionPath).doc(widget.userId).set({
//       'isTyping': false,
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//   }

//   void _scrollToBottom({bool isNewMessage = false}) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         if (isNewMessage || _scrollController.position.extentAfter < 200) {
//           _scrollController.animateTo(
//             _scrollController.position.maxScrollExtent,
//             duration: const Duration(milliseconds: 300),
//             curve: Curves.easeOut,
//           );
//         }
//       }
//     });
//   }

//   String _getAppBarTypingText() {
//     if (!_isOverallTyping || _usersTypingStatus.isEmpty) {
//       if (widget.isGroupChat) {
//         return '${_participantDisplayNames.isNotEmpty ? _participantDisplayNames.length : "..."} members';
//       } else {
//         return 'Online'; // Placeholder - consider fetching actual status
//       }
//     }

//     final typingDisplayNames =
//         _usersTypingStatus.keys
//             .map((userId) => _participantDisplayNames[userId] ?? 'Someone')
//             .where((name) => name != 'Someone')
//             .toList();

//     if (typingDisplayNames.isEmpty) {
//       return widget.isGroupChat
//           ? '${_participantDisplayNames.length} members'
//           : 'Online';
//     }
//     if (typingDisplayNames.length == 1) {
//       return "${typingDisplayNames[0]} is typing...";
//     }
//     if (typingDisplayNames.length == 2) {
//       return "${typingDisplayNames[0]} and ${typingDisplayNames[1]} are typing...";
//     }
//     return "${typingDisplayNames.length} people are typing...";
//   }

//   void _showErrorSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Theme.of(context).colorScheme.error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         margin: const EdgeInsets.all(10),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Scaffold(
//       backgroundColor: theme.colorScheme.surface,
//       appBar: _buildAppBar(),
//       body: Container(
//         // Using BoxDecoration for background image, color is ignored if image is present
//         decoration: BoxDecoration(
//           color: theme.colorScheme.surface, // Fallback color
//           image: DecorationImage(
//             image: const AssetImage(
//               'assets/chat_bg.png',
//             ), // Ensure this asset exists
//             fit: BoxFit.cover,
//             colorFilter: ColorFilter.mode(
//               theme.brightness == Brightness.dark
//                   ? Colors.black.withValues(alpha:0.5)
//                   : Colors.white.withValues(alpha:0.3), // Adjust opacity for theme
//               BlendMode.dstATop,
//             ),
//           ),
//         ),
//         child: Column(
//           children: [
//             Expanded(child: _buildMessagesList()),
//             _buildMessageInputArea(),
//           ],
//         ),
//       ),
//     );
//   }

//   PreferredSizeWidget _buildAppBar() {
//     final theme = Theme.of(context);
//     return AppBar(
//       elevation: 0.5,
//       backgroundColor:
//           theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
//       leading: IconButton(
//         icon: Icon(
//           Icons.arrow_back_ios_new_rounded,
//           color: theme.iconTheme.color,
//           size: 22,
//         ),
//         onPressed: () => Navigator.pop(context),
//         tooltip: "Back",
//       ),
//       titleSpacing: 0,
//       title: Row(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: theme.colorScheme.primaryContainer,
//             child: Text(
//               _resolvedChatName.isNotEmpty
//                   ? _resolvedChatName.substring(0, 1).toUpperCase()
//                   : "?",
//               style: TextStyle(
//                 color: theme.colorScheme.onPrimaryContainer,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   _resolvedChatName,
//                   overflow: TextOverflow.ellipsis,
//                   style: theme.textTheme.titleMedium?.copyWith(
//                     color: theme.colorScheme.onSurface,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 Text(
//                   _getAppBarTypingText(),
//                   overflow: TextOverflow.ellipsis,
//                   style: theme.textTheme.bodySmall?.copyWith(
//                     color: theme.hintColor,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       actions: [
//         PopupMenuButton<String>(
//           icon: Icon(
//             Icons.more_vert_rounded,
//             color: theme.iconTheme.color,
//             size: 24,
//           ),
//           tooltip: "More options",
//           color: theme.colorScheme.surfaceContainerHighest, // Menu background
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           onSelected: (value) {
//             if (value == 'create_group') {
//               _showCreateGroupDialogFromChat();
//             } else if (value == 'group_info') {
//               _showErrorSnackBar('Group Info (Not Implemented)');
//             } else if (value == 'view_contact') {
//               _showErrorSnackBar('View Contact (Not Implemented)');
//             } else if (value == 'clear_chat') {
//               _showErrorSnackBar('Clear Chat (Not Implemented)');
//             }
//           },
//           itemBuilder:
//               (BuildContext context) => <PopupMenuEntry<String>>[
//                 if (widget.isGroupChat)
//                   PopupMenuItem<String>(
//                     value: 'group_info',
//                     child: Text(
//                       'Group Info',
//                       style: TextStyle(
//                         color: theme.colorScheme.onSurfaceVariant,
//                       ),
//                     ),
//                   )
//                 else
//                   PopupMenuItem<String>(
//                     value: 'view_contact',
//                     child: Text(
//                       'View Contact',
//                       style: TextStyle(
//                         color: theme.colorScheme.onSurfaceVariant,
//                       ),
//                     ),
//                   ),
//                 const PopupMenuDivider(height: 1),
//                 PopupMenuItem<String>(
//                   value: 'clear_chat',
//                   child: Text(
//                     'Clear Chat',
//                     style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
//                   ),
//                 ),
//                 PopupMenuItem<String>(
//                   value: 'create_group',
//                   child: Text(
//                     'Create New Group',
//                     style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
//                   ),
//                 ),
//               ],
//         ),
//         const SizedBox(width: 4),
//       ],
//     );
//   }

//   void _showCreateGroupDialogFromChat() {
//     // Assuming CreateGroupDialog is defined in home_screen.dart and imported
//     // and that CreateGroupDialog itself uses Theme.of(context) for its styling.
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return CreateGroupDialog(
//           currentUserId: widget.userId,
//           firestore: _firestore,
//           onGroupCreated: (groupName, selectedUsersData) async {
//             if (groupName.isEmpty || selectedUsersData.isEmpty) {
//               _showErrorSnackBar("Group name and members are required.");
//               return;
//             }
//             final currentUserDoc =
//                 await _firestore.collection('users').doc(widget.userId).get();
//             final String currentUserName =
//                 currentUserDoc.data()?['fullName'] ?? 'Unknown User';

//             List<String> participantIds = [
//               widget.userId,
//               ...selectedUsersData.map((userData) => userData['id'] as String),
//             ];
//             Map<String, String> participantNamesMap = {
//               widget.userId: currentUserName,
//             };
//             for (var userData in selectedUsersData) {
//               participantNamesMap[userData['id'] as String] =
//                   userData['name'] as String;
//             }

//             final newChatRef = await _firestore.collection('chats').add({
//               'groupName': groupName,
//               'participants': participantIds,
//               'participantNames': participantNamesMap,
//               'adminIds': [widget.userId],
//               'lastMessage': 'Group created by $currentUserName',
//               'lastMessageSenderId': widget.userId,
//               'lastMessageTime': FieldValue.serverTimestamp(),
//               'createdAt': FieldValue.serverTimestamp(),
//               'isGroupChat': true,
//               'groupAvatar': '',
//             });

//             Navigator.of(context).pop(); // Close the dialog

//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder:
//                     (context) => ChatScreen(
//                       userId: widget.userId,
//                       chatId: newChatRef.id,
//                       chatName: groupName,
//                       isGroupChat: true,
//                     ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildMessagesList() {
//     final theme = Theme.of(context);
//     return StreamBuilder<QuerySnapshot>(
//       stream:
//           _firestore
//               .collection(_messagesCollectionPath)
//               .orderBy('timestamp', descending: false)
//               .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return Center(
//             child: Text(
//               'Error loading messages.',
//               style: TextStyle(color: theme.hintColor),
//             ),
//           );
//         }
//         if (!snapshot.hasData &&
//             snapshot.connectionState == ConnectionState.waiting) {
//           return Center(
//             child: CircularProgressIndicator(color: theme.colorScheme.primary),
//           );
//         }
//         final messages = snapshot.data?.docs ?? [];

//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           if (messages.isNotEmpty) {
//             _markMessagesAsRead();
//           }
//           _scrollToBottom();
//         });

//         return ListView.builder(
//           controller: _scrollController,
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//           itemCount:
//               messages.length +
//               (_isOverallTyping &&
//                       !_usersTypingStatus.containsKey(widget.userId)
//                   ? 1
//                   : 0),
//           itemBuilder: (context, index) {
//             if (index == messages.length &&
//                 _isOverallTyping &&
//                 !_usersTypingStatus.containsKey(widget.userId)) {
//               return _buildTypingIndicatorBubble();
//             }
//             if (index >= messages.length) return const SizedBox.shrink();

//             final messageDoc = messages[index];
//             final messageData = messageDoc.data() as Map<String, dynamic>;
//             final message = ChatMessage(
//               message: messageData['message'] ?? '',
//               sender: messageData['sender'] ?? '',
//               senderName:
//                   messageData['senderName'] ??
//                   _participantDisplayNames[messageData['sender']] ??
//                   'Unknown',
//               timestamp:
//                   (messageData['timestamp'] as Timestamp?)?.toDate() ??
//                   DateTime.now(),
//               isMe: messageData['sender'] == widget.userId,
//             );
//             return _buildMessageBubble(message, index);
//           },
//         );
//       },
//     );
//   }

//   Widget _buildTypingIndicatorBubble() {
//     final theme = Theme.of(context);
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 12, top: 4, left: 4),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//         decoration: BoxDecoration(
//           color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:
//             0.8,
//           ), // Slightly transparent
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(18),
//             topRight: Radius.circular(18),
//             bottomLeft: Radius.circular(4),
//             bottomRight: Radius.circular(18),
//           ),
//           border: Border.all(color: theme.dividerColor.withValues(alpha:0.7)),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: List.generate(3, (dotIndex) {
//             return Container(
//                   margin: const EdgeInsets.symmetric(horizontal: 2.5),
//                   width: 7,
//                   height: 7,
//                   decoration: BoxDecoration(
//                     color: theme.hintColor,
//                     shape: BoxShape.circle,
//                   ),
//                 )
//                 .animate(
//                   onPlay: (controller) => controller.repeat(reverse: true),
//                 )
//                 .scaleXY(end: 0.6, duration: 350.ms, delay: (dotIndex * 120).ms)
//                 .then(delay: (700 - (dotIndex * 240)).ms);
//           }),
//         ),
//       ),
//     ).animate().fadeIn(duration: 200.ms);
//   }

//   Widget _buildMessageBubble(ChatMessage message, int index) {
//     final theme = Theme.of(context);
//     final isMe = message.isMe;
//     return Column(
//           crossAxisAlignment:
//               isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//           children: [
//             if (widget.isGroupChat && !isMe)
//               Padding(
//                 padding: EdgeInsets.only(
//                   left: isMe ? 0 : 16.0,
//                   bottom: 3,
//                   right: isMe ? 16 : 0,
//                 ),
//                 child: Text(
//                   message.senderName,
//                   style: theme.textTheme.labelSmall?.copyWith(
//                     color: theme.hintColor,
//                   ),
//                 ),
//               ),
//             Container(
//               margin: EdgeInsets.only(
//                 bottom: 10,
//                 top: widget.isGroupChat && !isMe ? 0 : 4,
//               ),
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//               constraints: BoxConstraints(
//                 maxWidth: MediaQuery.of(context).size.width * 0.78,
//               ),
//               decoration: BoxDecoration(
//                 color:
//                     isMe
//                         ? theme.colorScheme.primaryContainer
//                         : theme.colorScheme.surfaceContainerHighest.withValues(alpha:
//                           0.85,
//                         ), // Slightly transparent for received
//                 borderRadius: BorderRadius.only(
//                   topLeft: const Radius.circular(18),
//                   topRight: const Radius.circular(18),
//                   bottomLeft: Radius.circular(isMe ? 18 : 4),
//                   bottomRight: Radius.circular(isMe ? 4 : 18),
//                 ),
//                 border:
//                     isMe
//                         ? null
//                         : Border.all(
//                           color: theme.dividerColor.withValues(alpha:0.2),
//                         ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha:0.04),
//                     spreadRadius: 1,
//                     blurRadius: 3,
//                     offset: const Offset(0, 1),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment:
//                     isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     message.message,
//                     style: theme.textTheme.bodyMedium?.copyWith(
//                       color:
//                           isMe
//                               ? theme.colorScheme.onPrimaryContainer
//                               : theme.colorScheme.onSurfaceVariant,
//                     ),
//                   ),
//                   const SizedBox(height: 5),
//                   Text(
//                     DateFormat('HH:mm').format(message.timestamp),
//                     style: theme.textTheme.labelSmall?.copyWith(
//                       color: (isMe
//                               ? theme.colorScheme.onPrimaryContainer
//                               : theme.colorScheme.onSurfaceVariant)
//                           .withValues(alpha:0.7),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         )
//         .animate()
//         .fadeIn(duration: 250.ms, delay: (20).ms)
//         .slideX(begin: isMe ? 0.05 : -0.05, curve: Curves.easeOutCubic);
//   }

//   Widget _buildMessageInputArea() {
//     final theme = Theme.of(context);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: BoxDecoration(
//         color: theme.colorScheme.surface, // Input area background
//         border: Border(
//           top: BorderSide(
//             color: theme.dividerColor.withValues(alpha: 0.5),
//             width: 0.5,
//           ),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha:0.04),
//             spreadRadius: 0,
//             blurRadius: 8,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             Expanded(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 decoration: BoxDecoration(
//                   color:
//                       theme.inputDecorationTheme.fillColor ??
//                       theme.colorScheme.surfaceContainerHighest,
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(
//                     color: theme.dividerColor.withValues(alpha:0.2),
//                   ),
//                 ),
//                 child: TextField(
//                   controller: _messageController,
//                   style: theme.textTheme.bodyLarge?.copyWith(
//                     color: theme.colorScheme.onSurfaceVariant,
//                   ),
//                   decoration: InputDecoration(
//                     hintText: 'Type a message...',
//                     hintStyle:
//                         theme.inputDecorationTheme.hintStyle ??
//                         TextStyle(color: theme.hintColor.withValues(alpha:0.8)),
//                     border: InputBorder.none,
//                     contentPadding: const EdgeInsets.symmetric(
//                       vertical: 12,
//                       horizontal: 0,
//                     ),
//                   ),
//                   keyboardType: TextInputType.multiline,
//                   minLines: 1,
//                   maxLines: 5,
//                   textCapitalization: TextCapitalization.sentences,
//                   onChanged: _handleTypingChange,
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             Material(
//               color: theme.colorScheme.primary,
//               shape: const CircleBorder(),
//               clipBehavior: Clip.antiAlias,
//               child: InkWell(
//                 splashColor: theme.colorScheme.primaryContainer.withValues(alpha:
//                   0.5,
//                 ),
//                 onTap: _sendMessage,
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: Icon(
//                     Icons.send_rounded,
//                     color: theme.colorScheme.onPrimary,
//                     size: 22,
//                   ),
//                 ),
//               ),
//             ).animate().scale(delay: 100.ms, duration: 200.ms),
//           ],
//         ),
//       ),
//     ).animate().fadeIn(duration: 200.ms);
//   }
// }

// lib/screens/chat_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For mapEquals
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
// Assuming home_screen.dart is in the same directory or adjust path
// For CreateGroupDialog, ensure it's accessible.
import 'home_screen.dart'; // This makes CreateGroupDialog available
// Removed: import '../app_colors.dart'; // Already removed in previous step

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
  String _otherUserId = ''; // For 1-on-1 chat, to fetch contact info

  // For message search
  bool _isSearching = false;
  final TextEditingController _searchControllerAppBar = TextEditingController();
  String _messageSearchQuery = '';

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

    _searchControllerAppBar.addListener(() {
      if (mounted) {
        setState(() {
          _messageSearchQuery = _searchControllerAppBar.text;
        });
      }
    });
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
        if (mounted) {
          setState(() {
            _otherUserId = participants.firstWhere(
              (id) => id != widget.userId,
              orElse: () => '',
            );
            // Also update participant display names for 1-on-1 if not already done
            _participantDisplayNames = Map<String, String>.from(
              chatDoc.data()?['participantNames'] ?? {},
            );
            if (_resolvedChatName == 'Chat' && _otherUserId.isNotEmpty) {
              _resolvedChatName =
                  _participantDisplayNames[_otherUserId] ?? 'Chat User';
            }
          });
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
            // Increased to 7s
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
    _searchControllerAppBar.dispose();
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
        _showErrorSnackBar('Failed to send message: ${e.toString()}');
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
      // Increased duration
      if (mounted) _stopTyping();
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _firestore.collection(_typingCollectionPath).doc(widget.userId).set({
      'isTyping': false,
      'timestamp': FieldValue.serverTimestamp(), // Update timestamp on stop
    });
  }

  void _scrollToBottom({bool isNewMessage = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (isNewMessage || _scrollController.position.extentAfter < 300) {
          // Increased threshold
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
      if (widget.isGroupChat) {
        return '${_participantDisplayNames.isNotEmpty ? _participantDisplayNames.length : "..."} members';
      } else {
        // For 1-on-1 chat, you might fetch the other user's actual online status here
        // For now, it's a placeholder or could show last seen from a fetched userDoc.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isSearching) _buildMessageSearchBar(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                image: DecorationImage(
                  image: const AssetImage('assets/chat_bg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    theme.brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.2),
                    BlendMode.dstATop,
                  ),
                ),
              ),
              child: _buildMessagesList(),
            ),
          ),
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      elevation:
          _isSearching ? 0 : 0.5, // No elevation when search bar is shown
      backgroundColor:
          theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: theme.iconTheme.color,
          size: 22,
        ),
        onPressed: () => Navigator.pop(context),
        tooltip: "Back",
      ),
      titleSpacing: 0,
      title:
          _isSearching
              ? null // Hide title when search bar is active (search bar is below appbar)
              : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _resolvedChatName.isNotEmpty
                          ? _resolvedChatName.substring(0, 1).toUpperCase()
                          : "?",
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _getAppBarTypingText(),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: theme.iconTheme.color,
            size: 24,
          ),
          tooltip: _isSearching ? "Close Search" : "Search Messages",
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchControllerAppBar.clear(); // Clears text and query
              }
            });
          },
        ),
        if (!_isSearching) // Only show popup menu if not searching
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.iconTheme.color,
              size: 24,
            ),
            tooltip: "More options",
            color: theme.colorScheme.surfaceContainerHighest, // Updated for M3
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'create_group') {
                _showCreateGroupDialogFromChat();
              } else if (value == 'group_info') {
                _showErrorSnackBar(
                  'Group Info (Not Implemented)',
                ); // Placeholder
              } else if (value == 'view_contact') {
                _showViewContactDialog();
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  if (widget.isGroupChat)
                    PopupMenuItem<String>(
                      value: 'group_info',
                      child: Text(
                        'Group Info',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    PopupMenuItem<String>(
                      value: 'view_contact',
                      child: Text(
                        'View Contact',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'create_group',
                    child: Text(
                      'Create New Group',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessageSearchBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: TextField(
        controller: _searchControllerAppBar,
        autofocus: true,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search in chat...',
          hintStyle: TextStyle(color: theme.hintColor),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search,
            color: theme.iconTheme.color?.withValues(alpha: 0.7),
          ),
          suffixIcon:
              _messageSearchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: theme.iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      _searchControllerAppBar.clear();
                    },
                  )
                  : null,
        ),
      ),
    );
  }

  void _showCreateGroupDialogFromChat() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CreateGroupDialog(
          // This widget is defined in home_screen.dart
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
              'groupAvatar': '', // Placeholder for group avatar URL
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

  Future<void> _showViewContactDialog() async {
    if (widget.isGroupChat || _otherUserId.isEmpty) return;

    final theme = Theme.of(context);
    try {
      final userDoc =
          await _firestore.collection('users').doc(_otherUserId).get();
      if (!userDoc.exists || !mounted) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final String name = userData['fullName'] ?? 'Unknown User';
      final String email = userData['email'] ?? 'No email';
      final String avatarUrl = userData['avatarUrl'] ?? '';
      final bool isOnline = userData['isOnline'] ?? false;
      final Timestamp? lastSeenTimestamp = userData['lastSeen'] as Timestamp?;
      String status = isOnline ? 'Online' : 'Offline';
      if (!isOnline && lastSeenTimestamp != null) {
        status =
            'Last seen: ${DateFormat.yMd().add_Hm().format(lastSeenTimestamp.toDate())}';
      }

      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child:
                      avatarUrl.isEmpty
                          ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 30,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                          : null,
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOnline ? Colors.green : theme.hintColor,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text(
                  'Close',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) _showErrorSnackBar('Could not load contact details.');
      if (kDebugMode) print("Error showing contact dialog: $e");
    }
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
              'Error loading messages.',
              style: TextStyle(color: theme.hintColor),
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
            // Only mark as read if not searching to avoid issues with filtered list
            _markMessagesAsRead();
          }
          if (!_isSearching) {
            _scrollToBottom(); // Only auto-scroll if not searching
          }
        });

        if (messages.isEmpty && _messageSearchQuery.isNotEmpty) {
          return Center(
            child: Text(
              'No messages found for "$_messageSearchQuery".',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }
        if (messages.isEmpty && !_isOverallTyping) {
          return Center(
            child: Text(
              'No messages yet. Start the conversation!',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, top: 4, left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.8,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (dotIndex) {
            return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: theme.hintColor,
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
    final theme = Theme.of(context);
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            Container(
              margin: EdgeInsets.only(
                bottom: 10,
                top: widget.isGroupChat && !isMe ? 0 : 4,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.85,
                        ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border:
                    isMe
                        ? null
                        : Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isMe
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: (isMe
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant)
                          .withValues(alpha: 0.7),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      theme.inputDecorationTheme.fillColor ??
                      theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.8),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle:
                        theme.inputDecorationTheme.hintStyle ??
                        TextStyle(
                          color: theme.hintColor.withValues(alpha: 0.8),
                        ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 0,
                    ),
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
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                splashColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                onTap: _sendMessage,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.send_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 22,
                  ),
                ),
              ),
            ).animate().scale(delay: 100.ms, duration: 200.ms),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
