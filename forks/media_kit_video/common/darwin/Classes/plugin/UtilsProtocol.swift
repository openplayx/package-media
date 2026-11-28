// Main-actor isolated: called from MediaKitVideoPlugin's method-call handler
// and drives AppKit windows.
@MainActor
public protocol UtilsProtocol: NSObject {
  func enterNativeFullscreen()
  func exitNativeFullscreen()
}
