import Flutter
import OpenGLES

public class TextureHW: NSObject, FlutterTexture, ResizableTextureProtocol {
  // Called on the main thread, after a hop from mpv's render thread.
  public typealias UpdateCallback = @Sendable () -> Void

  private let handle: OpaquePointer
  private let updateCallback: UpdateCallback
  private let context: EAGLContext
  private let textureCache: CVOpenGLESTextureCache
  private var renderContext: OpaquePointer?
  private var disposed = false
  private var textureContexts = SwappableObjectManager<TextureGLESContext>(
    objects: [],
    skipCheckArgs: true
  )

  /// Fails when the OpenGL ES context or texture cache cannot be created;
  /// `VideoOutput` then falls back to software rendering.
  init?(
    handle: OpaquePointer,
    updateCallback: @escaping UpdateCallback
  ) {
    guard let context = OpenGLESHelpers.createContext(),
          let textureCache = OpenGLESHelpers.createTextureCache(context)
    else {
      return nil
    }
    self.handle = handle
    self.updateCallback = updateCallback
    self.context = context
    self.textureCache = textureCache

    super.init()

    self.initMPV()
  }

  deinit {
    disposeRenderContext()
  }

  public func disposeRenderContext() {
    guard !disposed else { return }
    disposed = true
    disposePixelBuffer()
    disposeMPV()
    OpenGLESHelpers.deleteTextureCache(textureCache)

    // Deleting the context may cause potential RAM or VRAM memory leaks, as it
    // is used in the `deinit` method of the `TextureGLESContext`.
    // Potential fix: use a counter, and delete it only when the counter reaches
    // zero
    OpenGLESHelpers.deleteContext(context)
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let textureContext = textureContexts.current else {
      return nil
    }

    return Unmanaged.passRetained(textureContext.pixelBuffer)
  }

  private func initMPV() {
    EAGLContext.setCurrent(context)
    defer {
      OpenGLESHelpers.checkError("initMPV")
      EAGLContext.setCurrent(nil)
    }

    let api = UnsafeMutableRawPointer(
      mutating: (MPV_RENDER_API_TYPE_OPENGL as NSString).utf8String
    )
    var procAddress = mpv_opengl_init_params(
      get_proc_address: {
        (ctx, name) in
        return TextureHW.getProcAddress(ctx, name)
      },
      get_proc_address_ctx: nil
    )

    var params: [mpv_render_param] = withUnsafeMutableBytes(of: &procAddress) {
      procAddress in
      return [
        mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: api),
        mpv_render_param(
          type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
          data: procAddress.baseAddress.map {
            UnsafeMutableRawPointer($0)
          }
        ),
        mpv_render_param(),
      ]
    }

    MPVHelpers.checkError(
      mpv_render_context_create(&renderContext, handle, &params)
    )

    mpv_render_context_set_update_callback(
      renderContext,
      { (ctx) in
        let that = unsafeBitCast(ctx, to: TextureHW.self)
        // Hop with the immutable callback only, not with the texture itself.
        let updateCallback = that.updateCallback
        DispatchQueue.main.async {
          updateCallback()
        }
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
  }

  private func disposeMPV() {
    guard let renderContext = renderContext else { return }
    EAGLContext.setCurrent(context)
    defer {
      OpenGLESHelpers.checkError("disposeMPV")
      EAGLContext.setCurrent(nil)
    }

    mpv_render_context_set_update_callback(renderContext, nil, nil)
    mpv_render_context_free(renderContext)
    self.renderContext = nil
  }

  public func resize(_ size: CGSize) {
    if size.width == 0 || size.height == 0 {
      return
    }

    NSLog("TextureGL: resize: \(size.width)x\(size.height)")
    createPixelBuffer(size)
  }

  private func createPixelBuffer(_ size: CGSize) {
    disposePixelBuffer()

    textureContexts.reinit(
      objects: (0 ..< 3).compactMap { _ in
        TextureGLESContext(
          context: context,
          textureCache: textureCache,
          size: size
        )
      },
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

    EAGLContext.setCurrent(context)
    defer {
      OpenGLESHelpers.checkError("render")
      EAGLContext.setCurrent(nil)
    }

    glBindFramebuffer(GLenum(GL_FRAMEBUFFER), textureContext.frameBuffer)
    defer {
      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
    }

    var fbo = mpv_opengl_fbo(
      fbo: Int32(textureContext.frameBuffer),
      w: Int32(size.width),
      h: Int32(size.height),
      internal_format: 0
    )
    let fboPtr = withUnsafeMutablePointer(to: &fbo) { $0 }

    var params: [mpv_render_param] = [
      mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
      mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
    ]

    mpv_render_context_render(renderContext, &params)

    glFlush()

    textureContexts.pushAsReady(textureContext)
  }

  static private func getProcAddress(
    _ ctx: UnsafeMutableRawPointer?,
    _ name: UnsafePointer<Int8>?
  ) -> UnsafeMutableRawPointer? {
    let symbol: CFString = CFStringCreateWithCString(
      kCFAllocatorDefault,
      name,
      kCFStringEncodingASCII
    )
    let indentifier = CFBundleGetBundleWithIdentifier(
      "com.apple.opengles" as CFString
    )
    let addr = CFBundleGetFunctionPointerForName(indentifier, symbol)

    if addr == nil {
      NSLog("Cannot get OpenGLES function pointer!")
    }
    return addr
  }
}
