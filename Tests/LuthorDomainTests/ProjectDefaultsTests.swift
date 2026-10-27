import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

/// Home (A, 30m) holds Kitchen (nothing), which holds Tap; Garden has nothing at all.
private let tree = [
  projectCreated("home", "Home", lamport: 1),
  prioritized("home", as: .critical, lamport: 2),
  estimated("home", as: 30, lamport: 3),
  projectCreated("kitchen", "Kitchen", under: "home", lamport: 4),
  captured("tap", "replace tap", under: "kitchen", lamport: 5),
  projectCreated("garden", "Garden", lamport: 6),
]

@Suite("When no project default was ever set")
struct NoProjectDefaultsTests {
  @Test("a new top-level project has neither a priority nor an estimate")
  func aTopLevelProjectHasNone() {
    let settings = LibraryState.replay([]).settings(for: .default)

    #expect(settings.defaultProjectPriority == nil)
    #expect(settings.defaultProjectEstimate == nil)
  }
}

@Suite("When the default priority and estimate of top-level projects are set")
struct ProjectDefaultSettingsTests {
  @Test("every view resolves to them")
  func everyViewResolvesToThem() {
    let state = LibraryState.replay([
      viewCreated("work", "Work", lamport: 1),
      settingChanged(.defaultProjectPriority, to: "B", lamport: 2),
      settingChanged(.defaultProjectEstimateMinutes, to: "60", lamport: 3),
    ])

    #expect(state.settings(for: ViewID("work")).defaultProjectPriority == .important)
    #expect(state.globalSettings.defaultProjectEstimate == 60)
  }

  @Test("a view can have its own")
  func aViewCanHaveItsOwn() {
    let state = LibraryState.replay([
      viewCreated("work", "Work", lamport: 1),
      settingChanged(.defaultProjectPriority, to: "B", lamport: 2),
      settingChanged(.defaultProjectPriority, to: "A", view: "work", lamport: 3),
    ])

    #expect(state.settings(for: ViewID("work")).defaultProjectPriority == .critical)
    #expect(state.settings(for: .default).defaultProjectPriority == .important)
  }

  @Test("clearing them goes back to none")
  func clearingGoesBackToNone() {
    let state = LibraryState.replay([
      settingChanged(.defaultProjectPriority, to: "B", lamport: 1),
      settingChanged(.defaultProjectEstimateMinutes, to: "60", lamport: 2),
      settingChanged(.defaultProjectPriority, to: nil, lamport: 3),
      settingChanged(.defaultProjectEstimateMinutes, to: nil, lamport: 4),
    ])

    #expect(state.globalSettings.defaultProjectPriority == nil)
    #expect(state.globalSettings.defaultProjectEstimate == nil)
  }

  @Test("a value that means nothing, or is not a duration, is ignored")
  func nonsenseIsIgnored() {
    let state = LibraryState.replay([
      settingChanged(.defaultProjectPriority, to: "urgent", lamport: 1),
      settingChanged(.defaultProjectEstimateMinutes, to: "0", lamport: 2),
    ])

    #expect(state.globalSettings.defaultProjectPriority == nil)
    #expect(state.globalSettings.defaultProjectEstimate == nil)
  }
}

@Suite("When the defaults of a new task are looked for")
struct InheritedTaskDefaultsTests {
  @Test("a task in a project starts with the project's priority and estimate")
  func aTaskTakesItsParents() {
    let defaults = LibraryState.replay(tree).defaults(forNewTaskUnder: TaskID("home"))

    #expect(defaults == ItemDefaults(priority: .critical, estimate: 30))
  }

  @Test("a project with nothing set hands the question to its parent, up to the root project")
  func nothingSetAsksTheParent() {
    let defaults = LibraryState.replay(tree).defaults(forNewTaskUnder: TaskID("kitchen"))

    #expect(defaults == ItemDefaults(priority: .critical, estimate: 30))
  }

  @Test("the nearest project with a priority and the nearest with an estimate are found apart")
  func priorityAndEstimateAreFoundApart() {
    let log =
      tree + [prioritized("kitchen", as: .optional, lamport: 7), estimated("kitchen", as: 5, lamport: 8)]
      + [estimated("kitchen", as: nil, lamport: 9)]

    let defaults = LibraryState.replay(log).defaults(forNewTaskUnder: TaskID("kitchen"))

    #expect(defaults == ItemDefaults(priority: .optional, estimate: 30))
  }

  @Test("a root project with nothing set gives nothing")
  func aBareRootGivesNothing() {
    let defaults = LibraryState.replay(tree).defaults(forNewTaskUnder: TaskID("garden"))

    #expect(defaults == ItemDefaults(priority: nil, estimate: nil))
  }

  @Test("a task in no project, in the inbox, gets nothing")
  func theInboxGetsNothing() {
    let defaults = LibraryState.replay(tree).defaults(forNewTaskUnder: nil)

    #expect(defaults == ItemDefaults(priority: nil, estimate: nil))
  }
}

@Suite("When the defaults of a new project are looked for")
struct NewProjectDefaultsTests {
  private let settings = [
    settingChanged(.defaultProjectPriority, to: "B", lamport: 10),
    settingChanged(.defaultProjectEstimateMinutes, to: "60", lamport: 11),
  ]

  @Test("a top-level project gets the ones set in settings")
  func aTopLevelProjectGetsTheSettings() {
    let defaults = LibraryState.replay(tree + settings).defaults(forNewProjectUnder: nil, in: .default)

    #expect(defaults == ItemDefaults(priority: .important, estimate: 60))
  }

  @Test("a sub-project gets nothing")
  func aSubProjectGetsNothing() {
    let defaults = LibraryState.replay(tree + settings).defaults(forNewProjectUnder: TaskID("home"), in: .default)

    #expect(defaults == ItemDefaults(priority: nil, estimate: nil))
  }
}

@Suite("When items are created by command with defaults in force")
struct CreateWithDefaultsCommandTests {
  private let settings = [
    settingChanged(.defaultProjectPriority, to: "B", lamport: 10),
    settingChanged(.defaultProjectEstimateMinutes, to: "60", lamport: 11),
  ]

  @Test("a top-level project is given the priority and estimate set in settings")
  func aTopLevelProjectIsGivenThem() throws {
    let log = tree + settings
    let events = try makeCommands().createProject(title: "Taxes", kind: .parallel, in: .default, log: log)

    let state = LibraryState.replay(log + events)
    let taxes = try #require(state.view(.default).projects.first { $0.title == "Taxes" })
    #expect(taxes.priority == .important)
    #expect(taxes.estimate == 60)
  }

  @Test("a sub-project is given nothing")
  func aSubProjectIsGivenNothing() throws {
    let log = tree + settings
    let events = try makeCommands().createProject(
      title: "Attic", kind: .parallel, under: TaskID("home"), log: log)

    #expect(events.count == 1)
  }

  @Test("a task captured into a project is given the project's priority and estimate")
  func aTaskIsGivenItsParents() throws {
    let events = try makeCommands().capture(title: "oil hinges", into: TaskID("kitchen"), log: tree)

    let state = LibraryState.replay(tree + events)
    let hinges = try #require(state.view(.default).openTasks.first { $0.title == "oil hinges" })
    #expect(hinges.priority == .critical)
    #expect(hinges.estimate == 30)
  }

  @Test("the quick-capture syntax beats the inherited ones")
  func quickCaptureBeatsInheritance() throws {
    let events = try makeCommands().capture(title: "oil hinges !c 15m", into: TaskID("kitchen"), log: tree)

    let state = LibraryState.replay(tree + events)
    let hinges = try #require(state.view(.default).openTasks.first { $0.title == "oil hinges" })
    #expect(hinges.priority == .optional)
    #expect(hinges.estimate == 15)
  }

  @Test("a task captured into the inbox is given nothing")
  func theInboxGivesNothing() throws {
    let events = try makeCommands().capture(title: "buy milk", in: .default, log: tree + settings)

    #expect(events.count == 1)
  }

  @Test("a task captured into a project with nothing set is given nothing")
  func aBareProjectGivesNothing() throws {
    let events = try makeCommands().capture(title: "mow", into: TaskID("garden"), log: tree)

    #expect(events.count == 1)
  }
}
