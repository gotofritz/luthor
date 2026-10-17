import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a task is edited by command")
struct TaskCardCommandTests {
  static let log = [captured("t1", "buy milk", lamport: 1)]

  @Test("renaming writes one TaskRenamed, with the title trimmed")
  func renameWritesTaskRenamed() throws {
    let events = try makeCommands().rename(taskID: TaskID("t1"), to: "  buy oat milk ", log: Self.log)

    #expect(events == [renamed("t1", to: "buy oat milk", id: "id-1", lamport: 2)])
  }

  @Test("renaming to a blank title is refused", arguments: ["", "  ", "\n"])
  func blankRenameIsRefused(title: String) {
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().rename(taskID: TaskID("t1"), to: title, log: Self.log)
    }
  }

  @Test("renaming to the title it has writes nothing")
  func sameTitleWritesNothing() throws {
    #expect(try makeCommands().rename(taskID: TaskID("t1"), to: "buy milk", log: Self.log) == [])
  }

  @Test("a task that is not open cannot be renamed or noted")
  func closedTaskIsRefused() {
    let log = Self.log + [completed("t1", lamport: 2)]

    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().rename(taskID: TaskID("t1"), to: "x", log: log)
    }
    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().setNotes(taskID: TaskID("t1"), to: "x", log: log)
    }
  }

  @Test("setting notes writes one TaskNoted, trimmed")
  func notesWriteTaskNoted() throws {
    let events = try makeCommands().setNotes(taskID: TaskID("t1"), to: "\n oat, not soy \n", log: Self.log)

    #expect(events == [noted("t1", "oat, not soy", id: "id-1", lamport: 2)])
  }

  @Test("blank notes clear them", arguments: ["", "  \n "])
  func blankNotesClear(notes: String) throws {
    let log = Self.log + [noted("t1", "oat", lamport: 2)]

    let events = try makeCommands().setNotes(taskID: TaskID("t1"), to: notes, log: log)

    #expect(events == [noted("t1", nil, id: "id-1", lamport: 3)])
  }

  @Test("notes it already has, or none on a task with none, write nothing")
  func unchangedNotesWriteNothing() throws {
    let log = Self.log + [noted("t1", "oat", lamport: 2)]

    #expect(try makeCommands().setNotes(taskID: TaskID("t1"), to: " oat ", log: log) == [])
    #expect(try makeCommands().setNotes(taskID: TaskID("t1"), to: "", log: Self.log) == [])
  }
}

@Suite("When a project is edited by command")
struct ProjectCardCommandTests {
  static let log = [projectCreated("p1", "Holiday", lamport: 1)]

  @Test("renaming writes one ProjectRenamed, with the title trimmed")
  func renameWritesProjectRenamed() throws {
    let events = try makeCommands().renameProject(ProjectID("p1"), to: " Summer ", log: Self.log)

    #expect(events == [projectRenamed("p1", to: "Summer", id: "id-1", lamport: 2)])
  }

  @Test("renaming to a blank title is refused")
  func blankRenameIsRefused() {
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().renameProject(ProjectID("p1"), to: " ", log: Self.log)
    }
  }

  @Test("renaming to the title it has writes nothing")
  func sameTitleWritesNothing() throws {
    #expect(try makeCommands().renameProject(ProjectID("p1"), to: "Holiday", log: Self.log) == [])
  }

  @Test("changing the kind writes one ProjectKindChanged")
  func kindWritesProjectKindChanged() throws {
    let events = try makeCommands().setKind(of: ProjectID("p1"), to: .sequential, log: Self.log)

    #expect(events == [kindChanged("p1", to: .sequential, id: "id-1", lamport: 2)])
  }

  @Test("changing the kind to the one it has writes nothing")
  func sameKindWritesNothing() throws {
    #expect(try makeCommands().setKind(of: ProjectID("p1"), to: .parallel, log: Self.log) == [])
  }

  @Test("setting notes writes one ProjectNoted, trimmed; blank notes clear them")
  func notesWriteProjectNoted() throws {
    let set = try makeCommands().setNotes(ofProject: ProjectID("p1"), to: " see https://example.com ", log: Self.log)
    let cleared = try makeCommands().setNotes(
      ofProject: ProjectID("p1"), to: " ", log: Self.log + [projectNoted("p1", "x", lamport: 2)])

    #expect(set == [projectNoted("p1", "see https://example.com", id: "id-1", lamport: 2)])
    #expect(cleared == [projectNoted("p1", nil, id: "id-1", lamport: 3)])
  }

  @Test("a project that is not active is refused")
  func completedProjectIsRefused() {
    let log = Self.log + [projectCompleted("p1", lamport: 2)]

    #expect(throws: CommandError.noActiveProject(ProjectID("p1"))) {
      try makeCommands().renameProject(ProjectID("p1"), to: "x", log: log)
    }
    #expect(throws: CommandError.noActiveProject(ProjectID("p1"))) {
      try makeCommands().setKind(of: ProjectID("p1"), to: .sequential, log: log)
    }
    #expect(throws: CommandError.noActiveProject(ProjectID("p1"))) {
      try makeCommands().setNotes(ofProject: ProjectID("p1"), to: "x", log: log)
    }
  }
}
