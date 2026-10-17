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

public struct TaskID: Hashable, Codable, Sendable {
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
