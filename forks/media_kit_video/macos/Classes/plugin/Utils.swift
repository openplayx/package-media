import FlutterMacOS

@MainActor
public class Utils: NSObject, UtilsProtocol {
  private let registrar: FlutterPluginRegistrar

  init(_ registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  private var window: NSWindow? {
    registrar.view?.window
  }

  public func enterNativeFullscreen() {
    guard let window = window else {
      return printWarning()
    }

    FullScreenGuard.shared.request(window, fullScreen: true)
  }

  public func exitNativeFullscreen() {
    guard let window = window else {
      return printWarning()
    }

    FullScreenGuard.shared.request(window, fullScreen: false)
  }

  private func printWarning() {
    NSLog("Utils: warning: unable to find the window")
  }
}

/// Serializes native full-screen changes. AppKit throws from
/// -[NSWindow _reallySetFrame:] when toggleFullScreen is called while a
/// full-screen transition is already running, so a request made mid-transition
/// is deferred until the transition finishes (the latest request wins).
/// Main-actor isolated, like the AppKit window APIs it drives.
@MainActor
final class FullScreenGuard {
  static let shared = FullScreenGuard()

  /// Windows between will{Enter,Exit}FullScreen and did{Enter,Exit}FullScreen,
  /// mapped to a generation that expires a stuck flag.
  private var transitioning: [ObjectIdentifier: Int] = [:]
  private var pending: [ObjectIdentifier: Bool] = [:]
  private var generation = 0
  private var observers: [NSObjectProtocol] = []

  private init() {
    let starts = [
      NSWindow.willEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification,
    ]
    let ends = [
      NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
    ]
    for name in starts + ends {
      let isStart = starts.contains(name)
      observers.append(
        NotificationCenter.default.addObserver(
          forName: name,
          object: nil,
          queue: .main
        ) { [weak self] note in
          let window = note.object as? NSWindow
          // Delivered on the main queue (queue: .main).
          MainActor.assumeIsolated {
            guard let self = self, let window = window else {
              return
            }
            if isStart {
              self.began(window)
            } else {
              self.ended(window)
            }
          }
        }
      )
    }
  }

  /// Applies the full-screen state now, or once the running transition has
  /// finished. Returns false when the request was deferred.
  @discardableResult
  func request(_ window: NSWindow, fullScreen wanted: Bool) -> Bool {
    let id = ObjectIdentifier(window)
    if transitioning[id] != nil {
      pending[id] = wanted
      return false
    }
    pending[id] = nil
    if wanted != window.styleMask.contains(.fullScreen) {
      window.toggleFullScreen(nil)
    }
    return true
  }

  private func began(_ window: NSWindow) {
    let id = ObjectIdentifier(window)
    generation &+= 1
    let mine = generation
    transitioning[id] = mine
    // A failed transition only reaches the window delegate, not a
    // notification; never leave requests blocked for good.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self = self, self.transitioning[id] == mine else { return }
      self.transitioning[id] = nil
    }
  }

  private func ended(_ window: NSWindow) {
    let id = ObjectIdentifier(window)
    transitioning[id] = nil
    guard let wanted = pending.removeValue(forKey: id) else { return }
    // Next run-loop turn: AppKit is still unwinding the transition.
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self = self, let window = window else { return }
      self.request(window, fullScreen: wanted)
    }
  }
}
