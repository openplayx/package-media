/// OpenPlayX fork: no wakelock here. wakelock_plus has no Apple TV
/// implementation and flutter-tvos registers every plugin in the dependency
/// graph, so keeping the screen on during playback is left to the app.
class Wakelock {
  Wakelock();

  void enable() {}

  void disable() {}
}
