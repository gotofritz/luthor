import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a completion is written with the day it was done")
struct CompletedOnLineTests {
  @Test("a TaskCompleted carries the day as text")
  func carriesTheDay() throws {
    let line = try EventLine.encode(completed("t1", id: "e1", on: "2026-10-19", lamport: 1))

    #expect(
      line
        == #"{"data":{"completedOn":"2026-10-19","taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskCompleted"}"#
    )
  }

  @Test("the line decodes back to the same event")
  func decodesBack() throws {
    let event = completed("t1", id: "e1", on: "2026-10-19", lamport: 1)

    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When a completion is dated afterwards")
struct CompletionDatedLineTests {
  @Test("CompletionDated is one sorted JSON object")
  func isOneSortedJSONObject() throws {
    let line = try EventLine.encode(completionDated("t1", on: "2026-10-19", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"completedOn":"2026-10-19","taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"CompletionDated"}"#
    )
  }
}
