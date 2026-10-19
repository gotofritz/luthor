import LuthorDomain
import LuthorStore
import Testing

@Suite("When the checked-in golden log is read")
struct GoldenLogTests {
  private func events() throws -> [EventEnvelope] {
    try GoldenLogFixture.lines.map { line in
      try #require(EventLine.decodeIfKnown(line))
    }
  }

  @Test("every line decodes")
  func everyLineDecodes() throws {
    #expect(try events().count == GoldenLogFixture.lines.count)
  }

  @Test("every event type has a line, so none is left unguarded")
  func everyTypeHasALine() throws {
    let used = Set(
      GoldenLogFixture.lines.compactMap { line in
        EventLine.knownTypes.first { line.hasSuffix("\"type\":\"" + $0 + "\"}") }
      })
    #expect(used == Set(EventLine.knownTypes))
  }

  @Test("each event writes back to a line that decodes to the same event")
  func eachEventRoundTrips() throws {
    for event in try events() {
      #expect(try EventLine.decode(EventLine.encode(event)) == event)
    }
  }

  @Test("it replays to the views, tasks and projects it describes")
  func replaysToTheDescribedState() throws {
    let state = LibraryState.replay(try events())

    #expect(state.view(named: "Work") != nil)
    #expect(state.view(named: "Home") != nil)
    #expect(state.view(named: "Private") == nil)
  }

  @Test("the same events in reverse order give the same state")
  func reversedOrderGivesTheSameState() throws {
    let all = try events()

    #expect(LibraryState.replay(all.reversed()) == LibraryState.replay(all))
  }

  @Test("the same events twice give the same state")
  func duplicatesGiveTheSameState() throws {
    let all = try events()

    #expect(LibraryState.replay(all + all) == LibraryState.replay(all))
  }

  @Test("an event of a type from the future changes nothing")
  func aFutureEventChangesNothing() throws {
    let future = #"{"data":{"taskID":"t1"},"device":"phone","id":"e99","lamport":99,"type":"TaskSnoozed"}"#
    let lines = GoldenLogFixture.lines + [future]
    let read = try lines.compactMap { try EventLine.decodeIfKnown($0) }

    #expect(LibraryState.replay(read) == LibraryState.replay(try events()))
  }
}
