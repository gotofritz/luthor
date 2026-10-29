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
}
