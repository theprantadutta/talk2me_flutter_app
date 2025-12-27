/// Animation duration and curve constants.
abstract class AnimationConstants {
  // Durations
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 700);

  // Page transitions
  static const Duration pageTransition = Duration(milliseconds: 300);

  // Stagger delays
  static const Duration staggerDelay = Duration(milliseconds: 50);
  static const Duration listItemDelay = Duration(milliseconds: 30);

  // Typing indicator
  static const Duration typingDot = Duration(milliseconds: 400);

  // Pull to refresh
  static const Duration pullToRefresh = Duration(milliseconds: 300);
}
