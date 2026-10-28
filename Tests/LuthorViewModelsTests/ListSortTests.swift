import LuthorDomain
import LuthorTestSupport
import LuthorViewModels
import Testing

private func fields(
  _ title: String, created: String? = nil, due: String? = nil, estimate: Int? = nil,
  priority: Priority? = nil
) -> SortFields {
  SortFields(
    title: title, created: created.map(date), due: due.map(date), estimate: estimate, priority: priority)
}

private let rows = [
  fields("banana", created: "2026-10-02", due: "2026-11-01", estimate: 30, priority: .optional),
  fields("Cherry", created: "2026-10-01", estimate: 5, priority: .critical),
  fields("apple", due: "2026-10-30", priority: .someday),
  fields("date", created: "2026-10-03", due: "2026-12-01", estimate: 60),
]

private func titles(_ key: ListSortKey, ascending: Bool = true) -> [String] {
  ListSort(key: key, ascending: ascending).sorted(rows, by: { $0 }).map(\.title)
}

@Suite("When a list is sorted by the header")
struct ListSortTests {
  @Test("manual keeps the order the list has")
  func manualKeepsTheOrder() {
    #expect(titles(.manual) == ["banana", "Cherry", "apple", "date"])
    #expect(titles(.manual, ascending: false) == ["banana", "Cherry", "apple", "date"])
  }

  @Test("by title, ignoring case, either way")
  func byTitle() {
    #expect(titles(.title) == ["apple", "banana", "Cherry", "date"])
    #expect(titles(.title, ascending: false) == ["date", "Cherry", "banana", "apple"])
  }

  @Test("by created, oldest first, with those that have no day last either way")
  func byCreated() {
    #expect(titles(.created) == ["Cherry", "banana", "date", "apple"])
    #expect(titles(.created, ascending: false) == ["date", "banana", "Cherry", "apple"])
  }

  @Test("by due date, soonest first, with those that have none last either way")
  func byDue() {
    #expect(titles(.due) == ["apple", "banana", "date", "Cherry"])
    #expect(titles(.due, ascending: false) == ["date", "banana", "apple", "Cherry"])
  }

  @Test("by duration, shortest first, with those that have none last either way")
  func byDuration() {
    #expect(titles(.duration) == ["Cherry", "banana", "date", "apple"])
    #expect(titles(.duration, ascending: false) == ["date", "banana", "Cherry", "apple"])
  }

  @Test("by priority, A first, someday last, with those that have none after C")
  func byPriority() {
    #expect(titles(.priority) == ["Cherry", "banana", "date", "apple"])
    #expect(titles(.priority, ascending: false) == ["apple", "date", "banana", "Cherry"])
  }

  @Test("each key has the label of its header cell")
  func labels() {
    #expect(ListSortKey.allCases.map(\.label) == ["Manual", "Title", "Created", "Due", "Duration", "Priority"])
  }
}
