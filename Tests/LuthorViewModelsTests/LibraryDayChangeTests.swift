import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let utc = TimeZone(identifier: "UTC") ?? .current

/// An instant on a Gregorian day in UTC, however the system's calendar counts years.
private func instant(_ day: String, _ hour: Int, _ minute: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = utc
  let parts = day.split(separator: "-").compactMap { Int($0) }
  return calendar.date(
    from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour, minute: minute)) ?? Date()
}

/// A clock a test can move.
private final class Instant: @unchecked Sendable {
  var value: Date
  init(_ value: Date) { self.value = value }
}

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = [], at moment: Instant) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: InMemoryEventLog(events), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    instant: { moment.value }, timeZone: utc)
  library.reload()
  library.show(.today)
  return library
}

@Suite("When the day is worked out from an instant")
struct DayOfInstantTests {
  @Test("before the day changes it is still the day before")
  func beforeTheDayChangesItIsStillYesterday() {
    let day = CalendarDate.today(at: instant("2026-10-12", 1, 30), in: utc, dayChangesAt: 4 * 60)

    #expect(day == date("2026-10-11"))
  }

  @Test("at the minute the day changes it is the new day")
  func atTheMinuteTheDayChangesItIsToday() {
    let day = CalendarDate.today(at: instant("2026-10-12", 4, 0), in: utc, dayChangesAt: 4 * 60)

    #expect(day == date("2026-10-12"))
  }

  @Test("the minutes count from the start of that day, so 01:30 is 25:30")
  func minutesCountFromTheDayStart() {
    let minutes = minutesSinceDayStart(at: instant("2026-10-12", 1, 30), in: utc, dayChangesAt: 4 * 60)

    #expect(minutes == 25 * 60 + 30)
  }

  @Test("in the afternoon the minutes are the usual ones")
  func afternoonMinutesAreTheUsualOnes() {
    let minutes = minutesSinceDayStart(at: instant("2026-10-12", 15, 5), in: utc, dayChangesAt: 4 * 60)

    #expect(minutes == 15 * 60 + 5)
  }

  @Test("the year is the Gregorian one whatever calendar the system uses")
  func theYearIsGregorian() {
    let day = CalendarDate.today(at: instant("2026-10-12", 12, 0), in: utc, dayChangesAt: 0)

    #expect(day == date("2026-10-12"))
  }
}

@MainActor
@Suite("When the window runs on the system clock")
struct SystemDayViewModelTests {
  @Test("at 01:30 with the day changing at 04:00 today is still the day before")
  func todayIsStillYesterdayBeforeTheChange() {
    let library = makeLibrary(at: Instant(instant("2026-10-12", 1, 30)))

    #expect(library.today == date("2026-10-11"))
    #expect(library.minuteOfDay == 25 * 60 + 30)
  }

  @Test("changing the setting moves the day at once")
  func changingTheSettingMovesTheDay() {
    let library = makeLibrary(at: Instant(instant("2026-10-12", 1, 30)))

    library.changeGlobalDayChangesAt(0)

    #expect(library.today == date("2026-10-12"))
    #expect(library.minuteOfDay == 90)
  }

  @Test("a day shown as today moves on when the day changes")
  func theDayShownMovesOn() {
    let moment = Instant(instant("2026-10-12", 23, 0))
    let library = makeLibrary(
      [captured("t1", "write report", lamport: 1), scheduled("t1", on: "2026-10-12", lamport: 2)], at: moment)
    #expect(library.planDate == date("2026-10-12"))

    moment.value = instant("2026-10-13", 4, 0)
    library.reload()

    #expect(library.today == date("2026-10-13"))
    #expect(library.planDate == date("2026-10-13"))
    #expect(library.carryOver.map(\.entry.task.title) == ["write report"])
  }

  @Test("a day looked at on purpose stays when the day changes")
  func aDayLookedAtStays() {
    let moment = Instant(instant("2026-10-12", 23, 0))
    let library = makeLibrary(at: moment)
    library.showDay(date("2026-10-20"))

    moment.value = instant("2026-10-13", 4, 0)
    library.reload()

    #expect(library.planDate == date("2026-10-20"))
  }
}
