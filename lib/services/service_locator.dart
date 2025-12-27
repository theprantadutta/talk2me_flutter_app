import 'package:get_it/get_it.dart';

import 'auth/auth_service.dart';
import 'auth/firebase_auth_service.dart';
import 'chat/chat_service.dart';
import 'chat/firebase_chat_service.dart';
import 'user/user_service.dart';
import 'user/firebase_user_service.dart';

/// Global service locator instance.
final GetIt locator = GetIt.instance;

/// Setup all service dependencies.
/// Call this in main() before runApp().
void setupServiceLocator() {
  // Auth Service
  locator.registerLazySingleton<AuthService>(
    () => FirebaseAuthService(),
  );

  // User Service
  locator.registerLazySingleton<UserService>(
    () => FirebaseUserService(),
  );

  // Chat Service
  locator.registerLazySingleton<ChatService>(
    () => FirebaseChatService(),
  );
}
