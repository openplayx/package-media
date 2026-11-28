public class VideoOutputConfiguration {
  public let width: Int64?
  public let height: Int64?
  public let enableHardwareAcceleration: Bool

  init(
    width: Int64?,
    height: Int64?,
    enableHardwareAcceleration: Bool
  ) {
    self.width = width
    self.height = height
    self.enableHardwareAcceleration = enableHardwareAcceleration
  }

  public static func fromDict(_ dict: [String: Any])
    -> VideoOutputConfiguration
  {
    // Missing or malformed values fall back to the Dart-side defaults
    // (no fixed size, hardware acceleration on).
    let width: Int64? = (dict["width"] as? String).flatMap { Int64($0) }
    let height: Int64? = (dict["height"] as? String).flatMap { Int64($0) }
    let enableHardwareAcceleration =
      dict["enableHardwareAcceleration"] as? Bool ?? true

    return VideoOutputConfiguration(
      width: width,
      height: height,
      enableHardwareAcceleration: enableHardwareAcceleration
    )
  }
}
