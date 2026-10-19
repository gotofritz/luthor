import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a Mac asks the others to stop writing so the log can be compacted")
struct CompactionHandshakeTests {
  private func handshake(_ device: String, in dir: TemporaryDirectory) -> CompactionHandshake {
    CompactionHandshake(directory: dir.url, deviceID: DeviceID(device))
  }

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
}
