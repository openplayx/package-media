public class TextureGLContext {
  private let context: CGLContextObj
  private let renderBuffer: GLuint
  public let frameBuffer: GLuint
  public let texture: CVOpenGLTexture
  public let pixelBuffer: CVPixelBuffer

  /// Fails when the pixel buffer or its texture cannot be created; the caller
  /// then renders with fewer buffers instead of crashing.
  init?(
    context: CGLContextObj,
    textureCache: CVOpenGLTextureCache,
    size: CGSize
  ) {
    self.context = context

    guard let pixelBuffer = OpenGLHelpers.createPixelBuffer(size),
          let texture = OpenGLHelpers.createTexture(textureCache, pixelBuffer)
    else {
      NSLog("TextureGLContext: init: unable to create a pixel buffer texture")
      return nil
    }
    self.pixelBuffer = pixelBuffer
    self.texture = texture

    self.renderBuffer = OpenGLHelpers.createRenderBuffer(
      context,
      size
    )

    self.frameBuffer = OpenGLHelpers.createFrameBuffer(
      context: context,
      renderBuffer: renderBuffer,
      texture: texture,
      size: size
    )
  }

  deinit {
    OpenGLHelpers.deletePixeBuffer(context, pixelBuffer)
    OpenGLHelpers.deleteTexture(context, texture)
    OpenGLHelpers.deleteRenderBuffer(context, renderBuffer)
    OpenGLHelpers.deleteFrameBuffer(context, frameBuffer)
  }
}
