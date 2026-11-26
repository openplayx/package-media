#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

// This class avoids data race when called from a thread
public class SafeResizableTexture:
  NSObject,
  FlutterTexture,
  ResizableTextureProtocol
{
  private let lock = NSRecursiveLock()
  private var child: ResizableTextureProtocol?

  init(_ child: ResizableTextureProtocol) {
    self.child = child
  }

  public func resize(_ size: CGSize) {
    locked {
      child?.resize(size)
    }
  }

  public func render(_ size: CGSize) {
    locked {
      child?.render(size)
    }
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return locked { child?.copyPixelBuffer() }
  }

  /// Release mpv's old render context before creating its replacement. The
  /// registered Flutter texture stays the same throughout the transition.
  public func replace(_ make: () -> ResizableTextureProtocol) {
    locked {
      child?.disposeRenderContext()
      child = nil
      child = make()
    }
  }

  public func disposeRenderContext() {
    locked { child?.disposeRenderContext() }
  }

  private func locked<T>(do block: () -> T) -> T {
    lock.lock()
    defer {
      lock.unlock()
    }

    return block()
  }
}
