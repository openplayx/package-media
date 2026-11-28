#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

// @unchecked Sendable: a FlutterTexture is used from several threads (worker,
// main, Flutter's raster thread). The frame buffers are guarded by
// SwappableObjectManager's lock, resize/render/copy go through the
// lock-protected SafeResizableTexture, `updateCallback` is immutable, and
// `renderContext` is set in initMPV before mpv can request the first render.
public class TextureSW: NSObject, FlutterTexture, ResizableTextureProtocol,
  @unchecked Sendable
{
  // Called from mpv's render thread or the main thread.
  public typealias UpdateCallback = @Sendable () -> Void

  private let handle: OpaquePointer
  private let updateCallback: UpdateCallback
  private var renderContext: OpaquePointer?
  private var textureContexts = SwappableObjectManager<TextureSWContext>(
    objects: [],
    skipCheckArgs: true
  )

  init(
    handle: OpaquePointer,
    updateCallback: @escaping UpdateCallback
  ) {
    self.handle = handle
    self.updateCallback = updateCallback

    super.init()

    self.initMPV()
  }

  deinit {
    disposePixelBuffer()
    disposeMPV()
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let textureContext = textureContexts.current else {
      return nil
    }

    return Unmanaged.passRetained(textureContext.pixelBuffer)
  }

  private func initMPV() {
    let api = UnsafeMutableRawPointer(
      mutating: (MPV_RENDER_API_TYPE_SW as NSString).utf8String
    )
    var params: [mpv_render_param] = [
      mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: api),
      mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
    ]

    MPVHelpers.checkError(
      mpv_render_context_create(&renderContext, handle, &params)
    )

    mpv_render_context_set_update_callback(
      renderContext,
      { (ctx) in
        let that = unsafeBitCast(ctx, to: TextureSW.self)
        DispatchQueue.main.async {
          that.updateCallback()
        }
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
  }

  private func disposeMPV() {
    guard let renderContext = renderContext else { return }
    mpv_render_context_set_update_callback(renderContext, nil, nil)
    mpv_render_context_free(renderContext)
    self.renderContext = nil
  }

  public func disposeRenderContext() { disposeMPV() }

  public func resize(_ size: CGSize) {
    if size.width == 0 || size.height == 0 {
      return
    }

    NSLog("TextureSW: resize: \(size.width)x\(size.height)")
    createPixelBuffer(size)
  }

  private func createPixelBuffer(_ size: CGSize) {
    disposePixelBuffer()

    textureContexts.reinit(
      objects: (0 ..< 3).compactMap { _ in TextureSWContext(size: size) },
      skipCheckArgs: true
    )
  }

  private func disposePixelBuffer() {
    textureContexts.reinit(objects: [], skipCheckArgs: true)
  }

  public func render(_ size: CGSize) {
    guard renderContext != nil else { return }
    guard let textureContext = textureContexts.nextAvailable() else {
      return
    }

    CVPixelBufferLockBaseAddress(
      textureContext.pixelBuffer,
      CVPixelBufferLockFlags(rawValue: 0)
    )
    defer {
      CVPixelBufferUnlockBaseAddress(
        textureContext.pixelBuffer,
        CVPixelBufferLockFlags(rawValue: 0)
      )
    }

    var ssize: [Int32] = [Int32(size.width), Int32(size.height)]
    let format: String = "bgr0"
    var pitch: Int = CVPixelBufferGetBytesPerRow(textureContext.pixelBuffer)
    let buffer = CVPixelBufferGetBaseAddress(textureContext.pixelBuffer)

    // Keep every temporary pointer in scope through the native render call.
    ssize.withUnsafeMutableBytes { sizeBytes in
      format.withCString { formatBytes in
        withUnsafeMutablePointer(to: &pitch) { pitchPointer in
          var params: [mpv_render_param] = [
            mpv_render_param(type: MPV_RENDER_PARAM_SW_SIZE, data: sizeBytes.baseAddress),
            mpv_render_param(type: MPV_RENDER_PARAM_SW_FORMAT,
                             data: UnsafeMutableRawPointer(mutating: formatBytes)),
            mpv_render_param(type: MPV_RENDER_PARAM_SW_STRIDE, data: pitchPointer),
            mpv_render_param(type: MPV_RENDER_PARAM_SW_POINTER, data: buffer),
            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
          ]
          mpv_render_context_render(renderContext, &params)
        }
      }
    }

    textureContexts.pushAsReady(textureContext)
  }
}
