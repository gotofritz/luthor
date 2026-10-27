import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a log tells whether it changed")
struct ChangeTokenTests {
  @Test("a file log's token stays while unread and moves with an append")
  func fileTokenFollowsAppends() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = JSONLinesEventLog(fileURL: dir.url.appendingPathComponent("events.jsonl"))
    let missing = log.changeToken()

    try log.append([captured("t1", "buy milk")])
    let one = log.changeToken()
    let sameAgain = log.changeToken()
    try log.append([captured("t2", "call mum", lamport: 2)])

    #expect(missing != one)
    #expect(one == sameAgain)
    #expect(log.changeToken() != one)
  }

  @Test("a shared folder's token moves when another device writes")
  func folderTokenFollowsOtherDevices() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    let air = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
    try mac.append([captured("t1", "buy milk")])
    let before = mac.changeToken()

    try air.append([captured("t2", "call mum", device: "air", lamport: 2)])

    #expect(mac.changeToken() != before)
  }

  @Test("a log that cannot tell gives no token")
  func noTokenByDefault() {
    struct Silent: EventLog {
      func readAll() throws(EventLogError) -> [EventEnvelope] { [] }
      func append(_ events: [EventEnvelope]) throws(EventLogError) {}
    }

    #expect(Silent().changeToken() == nil)
  }
}
