import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a task or project is written with the day it was created")
struct CreatedOnLineTests {
  @Test("a TaskCaptured carries the day as text")
  func taskCapturedCarriesTheDay() throws {
    let line = try EventLine.encode(captured("t1", "buy milk", id: "e1", on: "2026-10-19", lamport: 1))

    #expect(
      line
        == #"{"data":{"createdOn":"2026-10-19","taskID":"t1","title":"buy milk","viewID":"default"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
    )
  }

  @Test("a ProjectCreated carries the day as text")
  func projectCreatedCarriesTheDay() throws {
    let line = try EventLine.encode(projectCreated("p1", "Holiday", id: "e2", on: "2026-10-18", lamport: 2))

    #expect(line.contains(#""createdOn":"2026-10-18""#))
  }

  @Test("without a day there is no createdOn field")
  func noDayNoField() throws {
    let line = try EventLine.encode(captured("t1", "buy milk", id: "e3", lamport: 3))

    #expect(!line.contains("createdOn"))
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      captured("t1", "buy milk", on: "2026-10-19"), captured("t2", "pay rent"),
      projectCreated("p1", "Holiday", on: "2026-10-18"), projectCreated("p2", "Taxes"),
    ])
  func decodesBack(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }

  @Test("a line written before the day was kept still decodes, with no day")
  func olderLineDecodes() throws {
    let line =
      #"{"data":{"taskID":"t1","title":"buy milk","viewID":"default"},"device":"mac","id":"e4","lamport":4,"type":"TaskCaptured"}"#

    #expect(try EventLine.decode(line) == captured("t1", "buy milk", id: "e4", lamport: 4))
  }
}
