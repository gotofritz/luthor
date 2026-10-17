import Foundation
import LuthorStore
import Testing

@Suite("When a UUIDGenerator makes IDs")
struct UUIDGeneratorTests {
  @Test("each ID is a lowercase UUID")
  func nextIsALowercaseUUID() throws {
    let id = UUIDGenerator().next()

    let uuid = try #require(UUID(uuidString: id))
    #expect(id == uuid.uuidString.lowercased())
  }

  @Test("no two IDs are the same")
  func nextNeverRepeats() {
    let generator = UUIDGenerator()

    let ids = (0..<100).map { _ in generator.next() }

    #expect(Set(ids).count == ids.count)
  }
}
