import LuthorDomain
import LuthorTestSupport
import Testing

@testable import LuthorViewModels

@MainActor
@Suite("When the state of a place is made on its own")
struct PlaceModelsTests {
  @Test("the day shown starts on the day given, with an empty plan and no drag")
  func theDayShownStartsEmpty() {
    let model = DayModel(view: .default, day: date("2026-10-19"))

    #expect(model.today == date("2026-10-19"))
    #expect(model.planDate == date("2026-10-19"))
    #expect(model.plan.entries.isEmpty)
    #expect(model.review.notDone.isEmpty)
    #expect(model.dragPreview == nil)
    #expect(model.calendarDays.isEmpty)
  }

  @Test("the tags place starts with no tag picked")
  func theTagsPlaceStartsWithNoTagPicked() {
    let model = TagsModel()

    #expect(model.tags.isEmpty)
    #expect(model.selectedTagID == nil)
  }

  @Test("the weekly review starts weekly, with no project picked")
  func theWeeklyReviewStartsWeekly() {
    let model = WeeklyReviewModel()

    #expect(model.projectReview.isEmpty)
    #expect(model.reviewProjectID == nil)
    #expect(model.reviewDefault == .weekly)
  }

  @Test("the settings start with the built-in values and the default view")
  func theSettingsStartWithTheBuiltInValues() {
    let model = SettingsModel()

    #expect(model.views.isEmpty)
    #expect(model.defaultViewID == .default)
    #expect(model.viewBeingEdited == nil)
    #expect(model.globalSettings == LibraryState.replay([]).globalSettings)
  }

  @Test("the project browser starts with no project shown")
  func theBrowserStartsWithNoProjectShown() {
    let model = BrowserModel()

    #expect(model.columns.isEmpty)
    #expect(model.path.isEmpty)
    #expect(model.shownProject == nil)
    #expect(model.listSorts.isEmpty)
  }

  @Test("the list starts with no task, and none completed, dropped or reopenable")
  func theListStartsEmpty() {
    let model = ListedModel()

    #expect(model.tasks.isEmpty)
    #expect(model.nextActions.isEmpty)
    #expect(model.completedTaskIDs.isEmpty)
    #expect(model.reopenableProjectIDs.isEmpty)
  }

  @Test("nothing is selected, edited or being added at the start")
  func nothingIsSelectedAtTheStart() {
    let model = SelectionModel()

    #expect(model.selection == nil)
    #expect(model.multiSelection.isEmpty)
    #expect(model.editingCard == nil)
    #expect(model.newItem == nil)
    #expect(!model.projectCardOpen)
  }
}
