import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a task or project is created on a day")
struct CreatedOnReplayTests {
  @Test("the task carries the day")
  func taskCarriesTheDay() {
    let log = [captured("t1", "buy milk", on: "2026-10-19", lamport: 1)]

    #expect(LibraryState.replay(log).view(.default).openTasks == [item("t1", "buy milk", createdOn: "2026-10-19")])
  }

  @Test("the project carries the day")
  func projectCarriesTheDay() {
    let log = [projectCreated("p1", "Holiday", on: "2026-10-18", lamport: 1)]

    #expect(
      LibraryState.replay(log).view(.default).projects == [project("p1", "Holiday", createdOn: "2026-10-18")])
  }

  @Test("one created before cards showed the day has none")
  func olderItemsHaveNoDay() {
    let log = [captured("t1", "buy milk", lamport: 1), projectCreated("p1", "Holiday", lamport: 2)]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.openTasks.map(\.createdOn) == [nil])
    #expect(view.projects.map(\.createdOn) == [nil])
  }

  @Test("a task keeps its day when filed, completed and reopened")
  func taskKeepsItsDay() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "buy milk", on: "2026-10-19", lamport: 2),
      moved("t1", to: "p1", lamport: 3), completed("t1", lamport: 4), reopened("t1", lamport: 5),
    ]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.openTasks.map(\.createdOn) == [date("2026-10-19")])
  }

  @Test("a project keeps its day when completed and reopened")
  func projectKeepsItsDay() {
    let log = [
      projectCreated("p1", "Holiday", on: "2026-10-18", lamport: 1), projectCompleted("p1", lamport: 2),
      projectReopened("p1", lamport: 3),
    ]

    #expect(LibraryState.replay(log).view(.default).projects.map(\.createdOn) == [date("2026-10-18")])
  }
}

@Suite("When a command is given the day it is")
struct CreatedOnCommandTests {
  static let today = date("2026-10-19")

  @Test("capturing writes a TaskCaptured with that day")
  func captureWritesTheDay() throws {
    let events = try makeCommands().capture(title: "buy milk", in: .default, today: Self.today, log: [])

    #expect(events == [captured("id-2", "buy milk", id: "id-1", on: "2026-10-19", lamport: 1)])
  }

  @Test("capturing into a project writes the day too")
  func captureIntoAProjectWritesTheDay() throws {
    let log = [projectCreated("p1", "Holiday", lamport: 1)]

    let events = try makeCommands().capture(title: "pack", into: TaskID("p1"), today: Self.today, log: log)

    #expect(events.first == captured("id-2", "pack", id: "id-1", on: "2026-10-19", under: "p1", lamport: 2))
  }

  @Test("creating a project writes a TaskCaptured with that day")
  func createProjectWritesTheDay() throws {
    let events = try makeCommands().createProject(
      title: "Holiday", kind: .parallel, in: .default, today: Self.today, log: [])

    #expect(events == [projectCreated("id-2", "Holiday", id: "id-1", on: "2026-10-19", lamport: 1)])
  }

  @Test("so does creating a sub-project")
  func createSubProjectWritesTheDay() throws {
    let log = [projectCreated("p1", "Holiday", lamport: 1)]

    let events = try makeCommands().createProject(
      title: "Flights", kind: .parallel, under: TaskID("p1"), today: Self.today, log: log)

    #expect(events == [projectCreated("id-2", "Flights", under: "p1", id: "id-1", on: "2026-10-19", lamport: 2)])
  }
}
