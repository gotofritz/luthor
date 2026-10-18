import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// Monday 2026-10-19 is the day the window is launched on.

@MainActor
@Suite("Given tasks, when I tag them on their cards")
struct TagCardFlowTests {
  @Test("the Tags place lists the tag and its tasks, and a relaunch still has them")
  func theTagsPlaceListsTheTagAndItsTasks() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("call bank")
    library.capture("call mum")
    library.capture("write report")
    let bank = try library.task("call bank")
    let mum = try library.task("call mum")
    for task in [bank, mum] {
      library.selection = task
      library.editCard(.task(task))
      let title = try #require(library.selectedTask).title
      library.saveCard(
        ofTask: task, TaskCardDraft(title: title, priority: nil, estimate: nil, due: nil, notes: "", tags: ["calls"]))
    }

    let relaunched = launchApp(on: url)
    relaunched.show(.tags)
    #expect(relaunched.tags.map(\.name) == ["calls"])
    #expect(relaunched.tasks.isEmpty)

    relaunched.showTag(try #require(relaunched.tags.first).id)
    #expect(relaunched.tasks.map(\.title) == ["call bank", "call mum"])
  }

  @Test("taking a tag off a card takes the task off the tag's list")
  func takingATagOffACardTakesTheTaskOffTheList() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("call bank")
    let bank = try library.task("call bank")
    library.tagTask(bank, named: "calls")
    library.show(.tags)
    library.showTag(try #require(library.tags.first).id)
    #expect(library.tasks.map(\.title) == ["call bank"])

    library.selection = bank
    library.editCard(.task(bank))
    library.saveCard(ofTask: bank, TaskCardDraft(title: "call bank", priority: nil, estimate: nil, due: nil, notes: ""))

    #expect(library.tasks.isEmpty)
    #expect(library.tags.map(\.name) == ["calls"])
    #expect(library.tagTaskCounts.values.allSatisfy { $0 == 0 })
  }
}

@MainActor
@Suite("Given two views, when each has a tag of the same name")
struct TagViewFlowTests {
  @Test("they are different tags, each listing only its own view's tasks")
  func theyAreDifferentTags() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("call bank")
    library.tagTask(try library.task("call bank"), named: "calls")
    let home = ViewID.default
    let work = try library.createView("Work")
    library.capture("call client")
    library.tagTask(try library.task("call client"), named: "calls")

    library.show(.tags)
    library.showTag(try #require(library.tags.first).id)
    #expect(library.tasks.map(\.title) == ["call client"])

    library.showView(home)
    library.show(.tags)
    library.showTag(try #require(library.tags.first).id)
    #expect(library.tasks.map(\.title) == ["call bank"])
    #expect(library.tags.count == 1)

    let relaunched = launchApp(on: url, view: work)
    relaunched.show(.tags)
    #expect(relaunched.tags.map(\.name) == ["calls"])
  }

  @Test("taking a task to the other view leaves its tag behind")
  func takingATaskToTheOtherViewLeavesItsTagBehind() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("call bank")
    let bank = try library.task("call bank")
    library.tagTask(bank, named: "calls")
    let work = try library.createView("Work")
    library.showView(.default)

    library.move(bank, toView: work)
    library.show(.tags)
    library.showTag(try #require(library.tags.first).id)

    #expect(library.tasks.isEmpty)
    library.showView(work)
    #expect(try library.task("call bank") == bank)
    #expect(library.tagItems(of: bank).isEmpty)
  }
}

@MainActor
@Suite("Given Today's candidates, when I filter them by tag")
struct CandidateFilterFlowTests {
  @Test("only the candidates with the tag stay, and the filter is gone after a relaunch")
  func onlyTheCandidatesWithTheTagStay() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("call bank !a")
    library.capture("write report !b")
    library.tagTask(try library.task("call bank"), named: "calls")
    library.show(.today)
    #expect(library.plan.candidates.map(\.task.title) == ["call bank", "write report"])
    let calls = try #require(library.tags.first).id

    library.candidateFilter = TaskFilter(tags: [calls])

    #expect(library.plan.candidates.map(\.task.title) == ["call bank"])
    let relaunched = launchApp(on: url)
    relaunched.show(.today)
    #expect(relaunched.plan.candidates.map(\.task.title) == ["call bank", "write report"])
  }

  @Test("a priority or a project narrows them too")
  func aPriorityOrAProjectNarrowsThemToo() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let taxes = try library.createProject("taxes", kind: .parallel)
    library.capture("call bank !a")
    library.capture("write report !b")
    library.file(try library.task("write report"), into: taxes)
    library.show(.today)

    library.candidateFilter = TaskFilter(priority: .critical)
    #expect(library.plan.candidates.map(\.task.title) == ["call bank"])

    library.candidateFilter = TaskFilter(projectID: taxes)
    #expect(library.plan.candidates.map(\.task.title) == ["write report"])
  }
}
