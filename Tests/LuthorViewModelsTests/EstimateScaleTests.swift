import LuthorViewModels
import Testing

@Suite("When an estimate is picked on the slider")
struct EstimateScaleTests {
  @Test("the left end is 5 minutes and the right end is one week")
  func ends() {
    #expect(EstimateScale.minutes(at: 0) == 5)
    #expect(EstimateScale.minutes(at: 1) == 10_080)
  }

  @Test("positions outside the slider are held to its ends")
  func clamps() {
    #expect(EstimateScale.minutes(at: -1) == 5)
    #expect(EstimateScale.minutes(at: 2) == 10_080)
  }

  @Test("the scale is logarithmic, so the middle is the geometric mean of the ends")
  func middle() {
    let middle = EstimateScale.minutes(at: 0.5)
    #expect(middle >= 200 && middle <= 240)
  }

  @Test("each position gives a larger estimate than the one before")
  func increasing() {
    let values = stride(from: 0.0, through: 1.0, by: 0.05).map { EstimateScale.minutes(at: $0) }
    #expect(values == values.sorted())
  }

  @Test(
    "an estimate has a position that gives it back, to the step of its size",
    arguments: [5, 15, 30, 60, 90, 480, 2_880, 10_080])
  func roundTrip(minutes: Int) {
    #expect(EstimateScale.minutes(at: EstimateScale.position(of: minutes)) == minutes)
  }

  @Test("an estimate beyond the ends sits at the nearest end")
  func positionClamps() {
    #expect(EstimateScale.position(of: 1) == 0)
    #expect(EstimateScale.position(of: 100_000) == 1)
  }

  @Test(
    "minutes read as minutes, hours, days and weeks",
    arguments: [
      (5, "5m"), (45, "45m"), (60, "1h"), (150, "2h 30m"), (1_440, "1d"), (1_680, "1d 4h"), (10_080, "1w"),
    ])
  func labels(minutes: Int, text: String) {
    #expect(EstimateScale.label(minutes) == text)
  }
}
