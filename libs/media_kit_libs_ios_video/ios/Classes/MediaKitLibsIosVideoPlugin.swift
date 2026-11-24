import Flutter

/// Carries the native libraries only; media_kit itself loads libmpv.
public class MediaKitLibsIosVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}
}
