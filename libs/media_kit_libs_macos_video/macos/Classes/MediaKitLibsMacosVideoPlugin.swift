import Cocoa
import FlutterMacOS

/// Carries the native libraries only; media_kit itself loads libmpv.
public class MediaKitLibsMacosVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}
}
