import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When notes are read as bullet points")
struct NoteBulletsTests {
  @Test("each non-blank line is a bullet, trimmed")
  func linesAreBullets() {
    let bullets = NoteBullets.bullets(in: " oat, not soy \n\n  ask the shop\r\nlast")

    #expect(bullets == ["oat, not soy", "ask the shop", "last"])
  }

  @Test("no notes, or blank ones, are no bullets", arguments: [nil, "", "  \n "])
  func noBullets(notes: String?) {
    #expect(NoteBullets.bullets(in: notes) == [])
  }

  @Test("bullets are written back one to a line")
  func bulletsJoinIntoNotes() {
    #expect(NoteBullets.notes(from: ["a", "b"]) == "a\nb")
  }
}

@Suite("When a note is added to or deleted from an item by command")
struct NoteCommandTests {
  static let log = [captured("t1", "buy milk", lamport: 1)]

  @Test("a note added to an item with none becomes its notes")
  func firstNoteBecomesTheNotes() throws {
    let events = try makeCommands().appendNote(taskID: TaskID("t1"), " oat ", log: Self.log)

    #expect(events == [noted("t1", "oat", id: "id-1", lamport: 2)])
  }

  @Test("a note added to existing notes follows them as a new bullet")
  func noteFollowsTheOthers() throws {
    let log = Self.log + [noted("t1", "oat", lamport: 2)]

    let events = try makeCommands().appendNote(taskID: TaskID("t1"), "not soy", log: log)

    #expect(events == [noted("t1", "oat\nnot soy", id: "id-1", lamport: 3)])
  }

  @Test("text of several lines adds a bullet for each")
  func severalLinesAddSeveralBullets() throws {
    let events = try makeCommands().appendNote(taskID: TaskID("t1"), "oat\n\nnot soy", log: Self.log)

    #expect(events == [noted("t1", "oat\nnot soy", id: "id-1", lamport: 2)])
  }

  @Test("a blank note writes nothing", arguments: ["", "  ", "\n"])
  func blankNoteWritesNothing(text: String) throws {
    #expect(try makeCommands().appendNote(taskID: TaskID("t1"), text, log: Self.log) == [])
  }

  @Test("deleting a bullet keeps the others")
  func deletingABulletKeepsTheOthers() throws {
    let log = Self.log + [noted("t1", "oat\nnot soy\nsemi", lamport: 2)]

    let events = try makeCommands().deleteNote(taskID: TaskID("t1"), at: 1, log: log)

    #expect(events == [noted("t1", "oat\nsemi", id: "id-1", lamport: 3)])
  }

  @Test("deleting the only bullet clears the notes")
  func deletingTheOnlyBulletClearsTheNotes() throws {
    let log = Self.log + [noted("t1", "oat", lamport: 2)]

    let events = try makeCommands().deleteNote(taskID: TaskID("t1"), at: 0, log: log)

    #expect(events == [noted("t1", nil, id: "id-1", lamport: 3)])
  }

  @Test("deleting a bullet that is not there writes nothing", arguments: [-1, 1, 7])
  func missingBulletWritesNothing(position: Int) throws {
    let log = Self.log + [noted("t1", "oat", lamport: 2)]

    #expect(try makeCommands().deleteNote(taskID: TaskID("t1"), at: position, log: log) == [])
  }

  @Test("a project's notes are bullets too")
  func projectNotesAreBullets() throws {
    let log = [projectCreated("p1", "Garden", lamport: 1)]

    let events = try makeCommands().appendNote(taskID: TaskID("p1"), "buy seeds", log: log)

    #expect(events == [projectNoted("p1", "buy seeds", id: "id-1", lamport: 2)])
  }

  @Test("an item that is not open takes no note")
  func closedItemIsRefused() {
    let log = Self.log + [completed("t1", lamport: 2)]

    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().appendNote(taskID: TaskID("t1"), "x", log: log)
    }
    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().deleteNote(taskID: TaskID("t1"), at: 0, log: log)
    }
  }
}
