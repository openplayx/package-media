import AVKit
import Flutter
import UIKit

/// Feeds the existing decoder to AVKit; never reopens the media or creates
/// a second player. CPU rendering keeps frames available in the background.
@available(iOS 15.0, *)
final class PictureInPictureOutput: NSObject, AVPictureInPictureControllerDelegate,
    AVPictureInPictureSampleBufferPlaybackDelegate {
  private let channel: FlutterMethodChannel
  private let manager: VideoOutputManager
  private var controller: AVPictureInPictureController?
  private let layer = AVSampleBufferDisplayLayer()
  private weak var output: VideoOutput?
  private var handle: Int64?
  private var pending: FlutterResult?
  private var possible: NSKeyValueObservation?
  private var timeout: DispatchWorkItem?
  private var timer: Timer?
  private var foreground: NSObjectProtocol?
  private var starting = false
  private var restoreRequested = false
  private var timebase: CMTimebase?
  private var pool: CVPixelBufferPool?
  private var poolSize = CGSize.zero
  private var lastFrame: CFTimeInterval = 0

  init(messenger: FlutterBinaryMessenger, manager: VideoOutputManager) {
    self.manager = manager
    channel = FlutterMethodChannel(name: "openplayx/picture_in_picture", binaryMessenger: messenger)
    super.init()
    layer.videoGravity = .resizeAspect
    CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault,
      sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
    layer.controlTimebase = timebase
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      switch call.method {
      case "isSupported": result(AVPictureInPictureController.isPictureInPictureSupported())
      case "enter": self.enter(call.arguments, result: result)
      case "exit":
        self.cancelPending()
        if let controller = self.controller, controller.isPictureInPictureActive {
          controller.stopPictureInPicture()
        } else { self.cleanup() }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    foreground = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self, self.controller == nil else { return }
      self.output?.setPictureInPictureFrames(nil)
      self.output = nil
    }
  }

  private var mpv: OpaquePointer? {
    guard output != nil, let handle = handle else { return nil }
    return OpaquePointer(bitPattern: Int(handle))
  }

  private func number(_ name: String) -> Double {
    guard let mpv = mpv else { return 0 }
    var value = 0.0
    mpv_get_property(mpv, name, MPV_FORMAT_DOUBLE, &value)
    return value
  }

  private func enter(_ arguments: Any?, result: @escaping FlutterResult) {
    guard pending == nil, controller == nil else {
      result(FlutterError(code: "pip_busy", message: "Picture in picture is already active", details: nil)); return
    }
    guard AVPictureInPictureController.isPictureInPictureSupported(),
      let args = arguments as? [String: Any], let raw = args["handle"] as? String,
      let handle = Int64(raw), let output = manager.output(for: handle),
      let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }),
      let host = window.rootViewController?.view else {
      result(FlutterError(code: "pip_unavailable", message: "Video output is not ready", details: nil)); return
    }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .moviePlayback)
      try session.setActive(true)
    } catch {
      result(FlutterError(code: "pip_audio", message: "Unable to activate playback audio", details: nil)); return
    }
    self.handle = handle
    self.output = output
    pending = result
    layer.frame = host.bounds
    host.layer.insertSublayer(layer, at: 0)
    let source = AVPictureInPictureController.ContentSource(
      sampleBufferDisplayLayer: layer, playbackDelegate: self)
    let controller = AVPictureInPictureController(contentSource: source)
    controller.delegate = self
    controller.requiresLinearPlayback = true
    self.controller = controller
    output.setPictureInPictureFrames { [weak self] buffer in self?.display(buffer) }
    possible = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
      [weak self] controller, _ in
      guard let self = self, controller.isPictureInPicturePossible,
            self.pending != nil, !self.starting else { return }
      self.starting = true
      controller.startPictureInPicture()
    }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, self.pending != nil else { return }
      let reply = self.pending; self.pending = nil
      self.cleanup()
      reply?(FlutterError(code: "pip_timeout", message: "Picture in picture did not become ready", details: nil))
    }
    self.timeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: timeout)
    timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.syncTime() }
  }

  private func syncTime() {
    guard let timebase = timebase, let controller = controller, mpv != nil else { return }
    CMTimebaseSetTime(timebase, time: CMTime(seconds: number("time-pos"), preferredTimescale: 600))
    CMTimebaseSetRate(timebase, rate: pictureInPictureControllerIsPlaybackPaused(controller)
      ? 0 : max(0.01, number("speed")))
    controller.invalidatePlaybackState()
  }

  private func display(_ source: CVPixelBuffer) {
    let now = CACurrentMediaTime()
    guard controller != nil, now - lastFrame >= 1.0 / 30.0 else { return }
    lastFrame = now
    // AVKit must own its buffers: the renderer reuses its triple buffer.
    let width = CVPixelBufferGetWidth(source), height = CVPixelBufferGetHeight(source)
    if pool == nil || poolSize != CGSize(width: width, height: height) {
      poolSize = CGSize(width: width, height: height)
      let attrs: [String: Any] = [
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
      CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
    }
    guard let pool = pool else { return }
    var target: CVPixelBuffer?
    let limits = [kCVPixelBufferPoolAllocationThresholdKey as String: 6] as CFDictionary
    guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, limits, &target) == kCVReturnSuccess,
          let target = target else { return }
    CVPixelBufferLockBaseAddress(source, .readOnly)
    CVPixelBufferLockBaseAddress(target, [])
    if let src = CVPixelBufferGetBaseAddress(source), let dst = CVPixelBufferGetBaseAddress(target) {
      for row in 0..<height {
        let destination = dst.advanced(by: row * CVPixelBufferGetBytesPerRow(target))
        memcpy(destination,
               src.advanced(by: row * CVPixelBufferGetBytesPerRow(source)), width * 4)
        // mpv's bgr0 output leaves the fourth byte unused; AVKit receives
        // BGRA, so supply opaque alpha rather than interpreting padding.
        for column in 0..<width {
          destination.storeBytes(of: UInt8.max, toByteOffset: column * 4 + 3, as: UInt8.self)
        }
      }
    }
    CVPixelBufferUnlockBaseAddress(target, [])
    CVPixelBufferUnlockBaseAddress(source, .readOnly)
    var format: CMVideoFormatDescription?
    guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
      imageBuffer: target, formatDescriptionOut: &format) == noErr, let format = format else { return }
    var timing = CMSampleTimingInfo(duration: .invalid,
      presentationTimeStamp: CMTime(seconds: number("time-pos"), preferredTimescale: 600), decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
      imageBuffer: target, formatDescription: format, sampleTiming: &timing,
      sampleBufferOut: &sample) == noErr, let sample = sample else { return }
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) {
      let values = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
      CFDictionarySetValue(values, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                           Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
    }
    if layer.status == .failed { layer.flush() }
    if layer.isReadyForMoreMediaData { layer.enqueue(sample) }
  }

  private func cancelPending() {
    let reply = pending; pending = nil
    reply?(FlutterError(code: "pip_cancelled", message: "Picture in picture cancelled", details: nil))
  }

  private func cleanup() {
    timeout?.cancel(); timeout = nil
    possible = nil
    timer?.invalidate(); timer = nil
    controller?.delegate = nil
    controller?.stopPictureInPicture()
    controller = nil
    starting = false
    output?.setPictureInPictureFrames(nil)
    if UIApplication.shared.applicationState == .active { output = nil }
    handle = nil
    layer.flushAndRemoveImage()
    layer.removeFromSuperlayer()
    pool = nil
    channel.invokeMethod(restoreRequested ? "restoring" : "closed", arguments: false)
    restoreRequested = false
  }

  func invalidate(handle: Int64) {
    guard self.handle == handle else { return }
    cancelPending()
    cleanup()
    output = nil
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    timeout?.cancel(); timeout = nil
    let reply = pending; pending = nil
    channel.invokeMethod("changed", arguments: true)
    reply?(true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) { cleanup() }

  func pictureInPictureController(_ controller: AVPictureInPictureController,
      failedToStartPictureInPictureWithError error: Error) {
    let reply = pending; pending = nil
    cleanup()
    reply?(FlutterError(code: "pip_failed", message: error.localizedDescription, details: nil))
  }

  func pictureInPictureController(_ controller: AVPictureInPictureController,
      restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completion: @escaping (Bool) -> Void) {
    restoreRequested = true
    completion(true) // The same mounted PlayerPage remains the restore target.
  }

  func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
    guard let mpv = mpv else { return }
    mpv_set_property_string(mpv, "pause", playing ? "no" : "yes")
    syncTime()
  }

  func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
    let duration = number("duration")
    return CMTimeRange(start: .zero, duration: duration > 0
      ? CMTime(seconds: duration, preferredTimescale: 600) : .positiveInfinity)
  }

  func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
    guard let mpv = mpv else { return true }
    var paused: Int32 = 1
    mpv_get_property(mpv, "pause", MPV_FORMAT_FLAG, &paused)
    return paused != 0
  }

  func pictureInPictureController(_ controller: AVPictureInPictureController,
      didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

  func pictureInPictureController(_ controller: AVPictureInPictureController,
      skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
    // Linear playback omits seek controls. Always complete even at teardown.
    completionHandler()
  }

  deinit {
    timer?.invalidate(); timeout?.cancel()
    if let foreground = foreground { NotificationCenter.default.removeObserver(foreground) }
  }
}
