import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a Mac asks the others to stop writing so the log can be compacted")
struct CompactionHandshakeTests {
  private func handshake(_ device: String, in dir: TemporaryDirectory) -> CompactionHandshake {
    CompactionHandshake(directory: dir.url, deviceID: DeviceID(device), now: { Self.fiveMinutesIn })
  }

  /// A clock a few minutes after the time the requests of these tests carry, so none has run out.
  private static let fiveMinutesIn = Date(timeIntervalSince1970: 1_792_425_900)

  private func writeEvents(_ count: Int, as device: String, in dir: TemporaryDirectory) throws {
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID(device))
    try log.append(
      (1...count).map {
        captured("\(device)\($0)", "task", id: "\(device)-e\($0)", device: device, lamport: UInt64($0))
      })
  }

  @Test("there is no open request until one is made")
  func noRequestAtFirst() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }

    #expect(try handshake("mac", in: dir).openRequest() == nil)
  }

  @Test("a request is open for every device, and the asker has stopped writing")
  func aRequestIsOpenForEveryone() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = handshake("mac", in: dir)

    let request = try mac.request(id: "r1", at: "2026-10-19T16:00:00Z")

    #expect(try handshake("laptop", in: dir).openRequest() == request)
    #expect(try mac.isPaused())
    #expect(try !handshake("laptop", in: dir).isPaused())
  }

  @Test("a second request is refused while one is open")
  func onlyOneRequestAtATime() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    _ = try handshake("mac", in: dir).request(id: "r1", at: "t")

    #expect(throws: EventLogError.self) { try handshake("laptop", in: dir).request(id: "r2", at: "t") }
  }

  @Test("the asker waits for a device that has not answered")
  func theAskerWaitsForSilentDevices() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try writeEvents(2, as: "mac", in: dir)
    try writeEvents(3, as: "laptop", in: dir)
    let mac = handshake("mac", in: dir)
    let request = try mac.request(id: "r1", at: "t")

    #expect(try mac.waitingFor(request) == ["laptop"])
  }

  @Test("an answer stops the other device writing, and counts once its events have arrived")
  func anAnswerCountsOnceItsEventsHaveArrived() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try writeEvents(2, as: "mac", in: dir)
    try writeEvents(1, as: "laptop", in: dir)
    let mac = handshake("mac", in: dir)
    let laptop = handshake("laptop", in: dir)
    let request = try mac.request(id: "r1", at: "t")

    // The laptop has 3 events by now, but only 1 has reached this folder.
    try laptop.acknowledge(request, events: 3, at: "t")
    #expect(try laptop.isPaused())
    #expect(try mac.waitingFor(request) == ["laptop"])

    try writeEvents(3, as: "laptop", in: dir)
    #expect(try mac.waitingFor(request).isEmpty)
  }

  @Test("finishing closes the request and lets every device write again")
  func finishingClosesTheRequest() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = handshake("mac", in: dir)
    let request = try mac.request(id: "r1", at: "t")

    try mac.finish(request, at: "t2")

    #expect(try mac.openRequest() == nil)
    #expect(try !mac.isPaused())
  }

  @Test("cancelling closes the request too, and a new one can follow")
  func cancellingClosesTheRequest() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = handshake("mac", in: dir)
    try mac.cancel(mac.request(id: "r1", at: "t"))

    #expect(try mac.openRequest() == nil)
    #expect(try mac.request(id: "r2", at: "t").id == "r2")
  }

  @Test("a paused device cannot append, and can again afterwards")
  func aPausedDeviceCannotAppend() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = handshake("mac", in: dir)
    let log = PausableEventLog(DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")), handshake: mac)
    try log.append([captured("t1", "before", id: "e1", device: "mac", lamport: 1)])
    let request = try mac.request(id: "r1", at: "t")

    #expect(throws: EventLogError.self) { try log.append([captured("t2", "during", id: "e2", lamport: 2)]) }
    try mac.finish(request, at: "t2")
    try log.append([captured("t3", "after", id: "e3", lamport: 3)])

    #expect(try log.readAll().count == 2)
  }

  @Test("a request nobody finished is given up after ten minutes, so it cannot pause the Macs for good")
  func anOldRequestExpires() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let asked = try #require(ISO8601DateFormatter().date(from: "2026-10-19T16:00:00Z"))
    let mac = CompactionHandshake(directory: dir.url, deviceID: DeviceID("mac"), now: { asked })
    _ = try mac.request(id: "r1", at: "2026-10-19T16:00:00Z")

    let early = CompactionHandshake(
      directory: dir.url, deviceID: DeviceID("laptop"), now: { asked.addingTimeInterval(599) })
    let late = CompactionHandshake(
      directory: dir.url, deviceID: DeviceID("laptop"), now: { asked.addingTimeInterval(601) })

    #expect(try early.openRequest() != nil)
    #expect(try late.openRequest() == nil)
    let asker = CompactionHandshake(
      directory: dir.url, deviceID: DeviceID("mac"), now: { asked.addingTimeInterval(601) })
    #expect(try !asker.isPaused())
  }

  @Test("an expired request does not stop a new one")
  func anExpiredRequestIsReplaced() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let asked = try #require(ISO8601DateFormatter().date(from: "2026-10-19T16:00:00Z"))
    _ = try CompactionHandshake(directory: dir.url, deviceID: DeviceID("mac"), now: { asked })
      .request(id: "r1", at: "2026-10-19T16:00:00Z")
    let laptop = CompactionHandshake(
      directory: dir.url, deviceID: DeviceID("laptop"), now: { asked.addingTimeInterval(3600) })

    let request = try laptop.request(id: "r2", at: "2026-10-19T17:00:00Z")

    #expect(try laptop.openRequest() == request)
  }

  @Test("a Mac that is refused says which Mac is compacting")
  func theRefusalNamesTheMac() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = handshake("mac", in: dir)
    _ = try mac.request(id: "r1", at: "t")
    let log = PausableEventLog(DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")), handshake: mac)

    do {
      try log.append([captured("t2", "during", id: "e2", lamport: 2)])
      Issue.record("the append should have been refused")
    } catch {
      #expect("\(error)".contains(mac.token))
    }
  }
}
