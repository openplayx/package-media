public class TextureSWContext {
  public let pixelBuffer: CVPixelBuffer

  /// Fails when the pixel buffer cannot be allocated; the caller then renders
  /// with fewer (or no) buffers instead of crashing.
  init?(size: CGSize) {
    guard let pixelBuffer = TextureSWContext.createPixelBuffer(size) else {
      return nil
    }
    self.pixelBuffer = pixelBuffer
  }

  deinit {
    TextureSWContext.disposePixelBuffer(pixelBuffer)
  }

  private static func createPixelBuffer(_ size: CGSize) -> CVPixelBuffer? {
    let attrs =
      [
        kCVPixelBufferMetalCompatibilityKey: true
      ] as CFDictionary

    var pixelBuffer: CVPixelBuffer?
    let cvret = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(size.width),
      Int(size.height),
      kCVPixelFormatType_32BGRA,
      attrs,
      &pixelBuffer
    )
    assert(cvret == kCVReturnSuccess, "CVPixelBufferCreate")
    if cvret != kCVReturnSuccess {
      NSLog("TextureSWContext: CVPixelBufferCreate failed: \(cvret)")
    }

    return pixelBuffer
  }

  private static func disposePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
    // 'CVPixelBufferRelease' is unavailable: Core Foundation objects are
    // automatically memory managed
  }
}
