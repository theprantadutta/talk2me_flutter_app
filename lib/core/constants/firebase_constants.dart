/// Firebase Firestore collection names and field keys.
abstract class FirebaseConstants {
  // Collection names
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesSubcollection = 'messages';
  static const String typingSubcollection = 'typing';

  // User document fields
  static const String userUid = 'uid';
  static const String userFullName = 'fullName';
  static const String userUsername = 'username';
  static const String userEmail = 'email';
  static const String userAvatarUrl = 'avatarUrl';
  static const String userIsOnline = 'isOnline';
  static const String userLastSeen = 'lastSeen';
  static const String userCreatedAt = 'createdAt';
  static const String userUpdatedAt = 'updatedAt';
  static const String userAuthProvider = 'authProvider';

  // Chat document fields
  static const String chatParticipants = 'participants';
  static const String chatParticipantNames = 'participantNames';
  static const String chatLastMessage = 'lastMessage';
  static const String chatLastMessageTime = 'lastMessageTime';
  static const String chatLastMessageSenderId = 'lastMessageSenderId';
  static const String chatIsGroupChat = 'isGroupChat';
  static const String chatGroupName = 'groupName';
  static const String chatGroupAvatar = 'groupAvatar';
  static const String chatAdminIds = 'adminIds';
  static const String chatCreatedAt = 'createdAt';

  // Message document fields
  static const String messageContent = 'message';
  static const String messageSender = 'sender';
  static const String messageSenderName = 'senderName';
  static const String messageTimestamp = 'timestamp';
  static const String messageReadBy = 'readBy';
  static const String messageType = 'type';
  static const String messageMediaUrl = 'mediaUrl';

  // Typing document fields
  static const String typingIsTyping = 'isTyping';
  static const String typingTimestamp = 'timestamp';
  static const String typingUserName = 'userName';
}
