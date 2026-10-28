import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a tag event is written to the log")
struct TagLineTests {
  @Test("a TagCreated is one sorted JSON object")
  func tagCreatedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(tagCreated("g1", "calls", view: "work", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"name":"calls","tagID":"g1","viewID":"work"},"device":"mac","id":"e1","lamport":1,"type":"TagCreated"}"#
    )
  }

  @Test("a TaskTagged and a TaskUntagged name the task and the tag")
  func taggedAndUntaggedNameTheTaskAndTheTag() throws {
    let taggedLine = try EventLine.encode(tagged("t1", with: "g1", id: "e2", lamport: 2))
    let untaggedLine = try EventLine.encode(untagged("t1", from: "g1", id: "e3", lamport: 3))

    #expect(
      taggedLine == #"{"data":{"tagID":"g1","taskID":"t1"},"device":"mac","id":"e2","lamport":2,"type":"TaskTagged"}"#)
    #expect(
      untaggedLine
        == #"{"data":{"tagID":"g1","taskID":"t1"},"device":"mac","id":"e3","lamport":3,"type":"TaskUntagged"}"#)
  }

  @Test(
    "each decodes back to the same event",
    arguments: [tagCreated("g1", "calls"), tagged("t1", with: "g1"), untagged("t1", from: "g1")])
  func tagLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When a TagDeleted event is written to the log")
struct TagDeletedLineTests {
  @Test("it names the tag")
  func itNamesTheTag() throws {
    let line = try EventLine.encode(tagDeleted("g1", id: "e1", lamport: 1))

    #expect(line == #"{"data":{"tagID":"g1"},"device":"mac","id":"e1","lamport":1,"type":"TagDeleted"}"#)
    #expect(try EventLine.decode(line) == tagDeleted("g1", id: "e1", lamport: 1))
  }
}
