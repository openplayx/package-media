import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Without an active CoreAudio stream (e.g. mpv ao=null, libVLC --aout=afile,
  // or video-only media), macOS App Nap coalesces timers after ~30-40 s of no
  // user input and causes frame drops in batched runs (ALL-371).
  private var activity: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .latencyCritical],
      reason: "Disable App Nap and timer coalescing during video playback tests"
    )
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
