/// Identifies one event in the log. Unique across all devices.
public struct EventID: Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public static func < (lhs: EventID, rhs: EventID) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// Identifies the device that wrote an event.
public struct DeviceID: Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public static func < (lhs: DeviceID, rhs: DeviceID) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// Identifies an item: a task, or a project, which is a task that holds others.
public struct TaskID: Hashable, Codable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  /// The ID of the task that repeats `previous`, worked out from it so that two devices completing the same
  /// task write the same next one. It is a fixed-length hash, so a long series of tasks does not grow the IDs.
  public static func recurring(after previous: TaskID) -> TaskID {
    var low: UInt64 = 0xcbf2_9ce4_8422_2325
    var high: UInt64 = 0x8422_2325_cbf2_9ce4
    for byte in previous.rawValue.utf8 {
      low = (low ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
      high = (high &+ UInt64(byte)) &* 0x0000_0100_0000_01b3 ^ (high >> 29)
    }
    return TaskID("r" + hex(high) + hex(low))
  }

  private static func hex(_ value: UInt64) -> String {
    let digits = String(value, radix: 16)
    return String(repeating: "0", count: 16 - digits.count) + digits
  }
}

/// Identifies a tag, a label such as `@calls` that belongs to one view.
public struct TagID: Hashable, Codable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

/// Identifies a view, a separate space such as Work or Private that every task and project belongs to.
public struct ViewID: Hashable, Codable, Sendable {
  /// The view replay always creates; it holds everything written before views existed.
  public static let `default` = ViewID("default")

  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

extension EventID {
  public init(from decoder: any Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension DeviceID {
  public init(from decoder: any Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension TaskID {
  public init(from decoder: any Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension ViewID {
  public init(from decoder: any Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension TagID {
  public init(from decoder: any Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
