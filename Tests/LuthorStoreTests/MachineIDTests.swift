import LuthorStore
import Testing

@Suite("When the app asks for this Mac's ID")
struct MachineIDTests {
  @Test("the one saved earlier is used, and nothing new is made or saved")
  func savedIDIsReused() {
    var saved: [String] = []

    let id = MachineID.current(saved: "3f9a2c1b-0000", make: { "new" }, save: { saved.append($0) })

    #expect(id == "3f9a2c1b-0000")
    #expect(saved.isEmpty)
  }

  @Test("with none saved, a new one is made and saved", arguments: [nil, "", "  "])
  func newIDIsMadeAndSaved(earlier: String?) {
    var saved: [String] = []

    let id = MachineID.current(saved: earlier, make: { "7b1d9e44-1111" }, save: { saved.append($0) })

    #expect(id == "7b1d9e44-1111")
    #expect(saved == ["7b1d9e44-1111"])
  }
}
