import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let bulkLog = [
  projectCreated("p1", "Holiday", lamport: 1),
  captured("t1", "book flights", lamport: 2), captured("t2", "pack", lamport: 3),
  captured("t3", "call bank", lamport: 4),
  tagCreated("calls", "calls", lamport: 5), tagCreated("home", "home", lamport: 5),
  tagged("t1", with: "calls", lamport: 6), tagged("t2", with: "calls", lamport: 6),
  tagged("t2", with: "home", lamport: 7),
]

@MainActor
@Suite("When more than one task is selected")
struct LibraryBulkSelectionTests {
  @Test("selectedIDs holds them all, and no single task is selected")
  func selectedIDsHoldsThemAll() {
    let (library, _) = makeInbox(bulkLog)

    library.setSelection([TaskID("t1"), TaskID("t3")])

    #expect(library.selectedIDs == [TaskID("t1"), TaskID("t3")])
    #expect(library.selection == nil)
    #expect(library.isBulkSelection)
  }

  @Test("picking one task is the ordinary selection")
  func oneIsTheOrdinarySelection() {
    let (library, _) = makeInbox(bulkLog)

    library.setSelection([TaskID("t1")])

    #expect(library.selection == TaskID("t1"))
    #expect(library.selectedIDs == [TaskID("t1")])
    #expect(!library.isBulkSelection)
  }

  @Test("selecting a task on its own ends the bulk selection")
  func selectingOneEndsIt() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t3")])

    library.selection = TaskID("t2")

    #expect(library.selectedIDs == [TaskID("t2")])
  }

  @Test("a task that leaves the list leaves the selection")
  func leavingTheListLeavesTheSelection() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t3")])

    library.dropTask(TaskID("t1"))

    #expect(library.selectedIDs == [TaskID("t3")])
  }
}

@MainActor
@Suite("When the selected tasks are edited together")
struct LibraryBulkEditTests {
  @Test("the card shows the tags all of them carry, apart from the ones only some carry")
  func cardSplitsCommonTags() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t2")])

    let card = library.bulkCard

    #expect(card?.count == 2)
    #expect(card?.commonTags.map(\.name) == ["calls"])
    #expect(card?.partialTags.map(\.name) == ["home"])
  }

  @Test("a value shows only where all agree")
  func valueShowsWhereAllAgree() {
    let (library, _) = makeInbox(bulkLog)
    library.prioritize(TaskID("t1"), as: .critical)
    library.prioritize(TaskID("t2"), as: .critical)
    library.setSelection([TaskID("t1"), TaskID("t2"), TaskID("t3")])
    #expect(library.bulkCard?.priority == .mixed)

    library.setSelection([TaskID("t1"), TaskID("t2")])
    #expect(library.bulkCard?.priority == .same(.critical))
  }

  @Test("the project, due date and tags are applied to every task, and Undo is one step")
  func appliesEveryFieldAsOneStep() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t3")])
    let day = date("2026-11-01")

    library.applyBulk(
      BulkEdit(
        estimate: .set(45), due: .set(DueDate(date: day, isHard: true)), project: .set(TaskID("p1")),
        addTags: ["errands"], removeTags: [TagID("calls")]))

    #expect(library.bulkCard?.estimate == .same(45))
    #expect(library.bulkCard?.due == .same(DueDate(date: day, isHard: true)))
    #expect(library.bulkCard?.project == .same(TaskID("p1")))
    #expect(library.bulkCard?.commonTags.map(\.name) == ["errands"])
    #expect(library.tagItems(of: TaskID("t1")).map(\.name) == ["errands"])

    library.undo()
    #expect(library.bulkCard?.estimate == .same(nil))
    #expect(library.bulkCard?.project == .same(nil))
    #expect(library.tagItems(of: TaskID("t1")).map(\.name) == ["calls"])
  }

  @Test("removing a tag takes it off the tasks that carry it")
  func removesATag() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t2"), TaskID("t3")])

    library.untagSelected(TagID("calls"))

    #expect(library.tagItems(of: TaskID("t1")).isEmpty)
    #expect(library.tagItems(of: TaskID("t2")).map(\.name) == ["home"])
  }

  @Test("with fewer than two tasks selected there is no bulk card")
  func noBulkCardForOne() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1")])

    #expect(library.bulkCard == nil)
  }

  @Test("the scheduled day, repeat and a note are applied to every task, and Undo is one step")
  func appliesScheduleRepeatAndNote() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t3")])
    let day = date("2026-10-20")
    let rule = RepeatRule(every: 1, unit: .week, afterCompletion: true)

    library.applyBulk(BulkEdit(scheduled: .set(day), repeatRule: .set(rule), addNote: "bring the form"))

    #expect(library.bulkCard?.scheduled == .same(day))
    #expect(library.bulkCard?.repeatRule == .same(rule))
    #expect(library.bulkCard?.notes == .same("bring the form"))

    library.undo()
    #expect(library.bulkCard?.scheduled == .same(nil))
    #expect(library.bulkCard?.repeatRule == .same(nil))
    #expect(library.bulkCard?.notes == .same(nil))
  }

  @Test("a repeat set on tasks with no due date counts from when they are done")
  func repeatWithoutDueCountsFromCompletion() {
    let (library, _) = makeInbox(bulkLog)
    library.setSelection([TaskID("t1"), TaskID("t3")])

    library.applyBulk(BulkEdit(repeatRule: .set(RepeatRule(every: 2, unit: .day))))

    #expect(library.bulkCard?.repeatRule == .same(RepeatRule(every: 2, unit: .day, afterCompletion: true)))
  }
}
