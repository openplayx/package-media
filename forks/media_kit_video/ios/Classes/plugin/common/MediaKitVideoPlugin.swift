// @preconcurrency: Flutter's globals (FlutterMethodNotImplemented) and
// protocols (FlutterTextureRegistry) predate Swift concurrency annotations.
#if canImport(Flutter)
  @preconcurrency import Flutter
#elseif canImport(FlutterMacOS)
  @preconcurrency import FlutterMacOS
#endif

// Main-actor isolated: Flutter registers plugins and delivers method calls on
// the platform (main) thread. FlutterPlugin is not annotated, hence the
// @preconcurrency conformance.
@MainActor
public class MediaKitVideoPlugin: NSObject, @preconcurrency FlutterPlugin {
  private static let CHANNEL_NAME = "com.alexmercerind/media_kit_video"

  // Nonisolated because generated Swift registrants (macOS) call it from
  // nonisolated code; Flutter registers plugins on the platform (main) thread.
  nonisolated public static func register(with registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      registerOnMainActor(registrar)
    }
  }

  private static func registerOnMainActor(_ registrar: FlutterPluginRegistrar) {
    #if canImport(Flutter)
      let binaryMessenger = registrar.messenger()
      let registry = registrar.textures()
      let utils: UtilsProtocol? = nil
    #elseif canImport(FlutterMacOS)
      let binaryMessenger = registrar.messenger
      let registry = registrar.textures
      let utils: UtilsProtocol? = Utils(registrar)
    #endif

    let channel = FlutterMethodChannel(
      name: CHANNEL_NAME,
      binaryMessenger: binaryMessenger
    )
    let instance = MediaKitVideoPlugin(
      registry: registry,
      channel: channel,
      utils: utils
    )
    if #available(iOS 15.0, *) {
      instance.pictureInPicture = PictureInPictureOutput(
        messenger: binaryMessenger, manager: instance.videoOutputManager)
    }
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private let channel: FlutterMethodChannel
  private let videoOutputManager: VideoOutputManager
  private let utils: UtilsProtocol?
  private var pictureInPicture: AnyObject?

  init(
    registry: FlutterTextureRegistry,
    channel: FlutterMethodChannel,
    utils: UtilsProtocol?
  ) {
    self.channel = channel
    videoOutputManager = VideoOutputManager(
      registry: registry
    )
    self.utils = utils
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "VideoOutputManager.Create":
      handleCreateMethodCall(call.arguments, result)
    case "VideoOutputManager.SetSize":
      handleSetSizeMethodCall(call.arguments, result)
    case "VideoOutputManager.Dispose":
      handleDisposeMethodCall(call.arguments, result)
    case "Utils.EnterNativeFullscreen":
      handleEnterNativeFullscreenMethodCall(call.arguments, result)
    case "Utils.ExitNativeFullscreen":
      handleExitNativeFullscreenMethodCall(call.arguments, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleCreateMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    let args = arguments as? [String: Any]
    guard let handle = MediaKitVideoPlugin.parseHandle(args, result) else {
      return
    }
    let configDict = args?["configuration"] as? [String: Any] ?? [:]
    let configuration = VideoOutputConfiguration.fromDict(configDict)

    videoOutputManager.create(
      handle: handle,
      configuration: configuration,
      textureUpdateCallback: { (_ textureId: Int64, _ size: CGSize) in
        self.channel.invokeMethod(
          "VideoOutput.Resize",
          arguments: [
            "handle": handle,
            "id": textureId,
            "rect": [
              "top": 0,
              "left": 0,
              "width": size.width,
              "height": size.height,
            ],
          ] as [String: Any]
        )
      }
    )

    result(nil)
  }

  private func handleSetSizeMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    let args = arguments as? [String: Any]
    guard let handle = MediaKitVideoPlugin.parseHandle(args, result) else {
      return
    }
    let width: Int64? = (args?["width"] as? String).flatMap { Int64($0) }
    let height: Int64? = (args?["height"] as? String).flatMap { Int64($0) }

    self.videoOutputManager.setSize(
      handle: handle,
      width: width,
      height: height
    )

    result(nil)
  }

  private func handleDisposeMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    let args = arguments as? [String: Any]
    guard let handle = MediaKitVideoPlugin.parseHandle(args, result) else {
      return
    }

    if #available(iOS 15.0, *) {
      (pictureInPicture as? PictureInPictureOutput)?.invalidate(handle: handle)
    }
    videoOutputManager.destroy(
      handle: handle
    )

    result(nil)
  }

  /// Parses the `handle` argument (an Int64 sent as a String). Reports a
  /// FlutterError and returns nil when it is missing or malformed.
  private static func parseHandle(
    _ args: [String: Any]?,
    _ result: FlutterResult
  ) -> Int64? {
    guard let handleStr = args?["handle"] as? String,
          let handle = Int64(handleStr)
    else {
      result(FlutterError(
        code: "invalid-argument",
        message: "handle must be an Int64 string",
        details: nil
      ))
      return nil
    }
    return handle
  }

  private func handleEnterNativeFullscreenMethodCall(
    _: Any?,
    _ result: FlutterResult
  ) {
    if utils == nil {
      return result(FlutterMethodNotImplemented)
    }

    utils?.enterNativeFullscreen()
    result(nil)
  }

  private func handleExitNativeFullscreenMethodCall(
    _: Any?,
    _ result: FlutterResult
  ) {
    if utils == nil {
      return result(FlutterMethodNotImplemented)
    }

    utils?.exitNativeFullscreen()
    result(nil)
  }
}
