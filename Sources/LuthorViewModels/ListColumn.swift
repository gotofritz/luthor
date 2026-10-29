/// A column of the rows of a list that its header can turn on and off.
public enum ListColumn: String, CaseIterable, Codable, Sendable {
  case status
  case duration
  case priority
  /// The day a task is scheduled for, else its due date.
  case when

  public var label: String {
    switch self {
    case .status: "Done"
    case .duration: "Duration"
    case .priority: "Priority"
    case .when: "When"
    }
  }
}
