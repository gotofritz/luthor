import LuthorDomain

// The properties of the place models, forwarded: the models hold the state, so a view reads one place's state
// without being told of another's, and these keep every caller as it was. In their own file (SwiftLint
// type_body_length) rather than suppressed.
extension LibraryViewModel {
  public internal(set) var today: CalendarDate {
    get { dayModel.today }
    set { dayModel.today = newValue }
  }
  public internal(set) var planDate: CalendarDate {
    get { dayModel.planDate }
    set { dayModel.planDate = newValue }
  }
  public internal(set) var plan: DayPlan {
    get { dayModel.plan }
    set { dayModel.plan = newValue }
  }
  public internal(set) var waiting: [WaitingItem] {
    get { dayModel.waiting }
    set { dayModel.waiting = newValue }
  }
  public internal(set) var review: DayReview {
    get { dayModel.review }
    set { dayModel.review = newValue }
  }
  public internal(set) var carryOver: [CarryOverEntry] {
    get { dayModel.carryOver }
    set { dayModel.carryOver = newValue }
  }
  public internal(set) var calendarDays: [CalendarDay] {
    get { dayModel.calendarDays }
    set { dayModel.calendarDays = newValue }
  }
  public internal(set) var calendarDate: CalendarDate? {
    get { dayModel.calendarDate }
    set { dayModel.calendarDate = newValue }
  }
  public internal(set) var calendarEntries: [CalendarEntry] {
    get { dayModel.calendarEntries }
    set { dayModel.calendarEntries = newValue }
  }
  public var draggedTaskID: TaskID? {
    get { dayModel.draggedTaskID }
    set { dayModel.draggedTaskID = newValue }
  }
  public var draggedBlockID: BlockID? {
    get { dayModel.draggedBlockID }
    set { dayModel.draggedBlockID = newValue }
  }
  public var draggedSessionID: SessionID? {
    get { dayModel.draggedSessionID }
    set { dayModel.draggedSessionID = newValue }
  }
  public var sessionPreview: (sessionID: SessionID, minute: Int)? {
    get { dayModel.sessionPreview }
    set { dayModel.sessionPreview = newValue }
  }
  public var blockPreview: DayBlock? {
    get { dayModel.blockPreview }
    set { dayModel.blockPreview = newValue }
  }
  public var dragPreview: (taskID: TaskID, minute: Int)? {
    get { dayModel.dragPreview }
    set { dayModel.dragPreview = newValue }
  }
  public internal(set) var tags: [TagItem] {
    get { tagsModel.tags }
    set { tagsModel.tags = newValue }
  }
  public internal(set) var tagTaskCounts: [TagID: Int] {
    get { tagsModel.tagTaskCounts }
    set { tagsModel.tagTaskCounts = newValue }
  }
  public internal(set) var selectedTagID: TagID? {
    get { tagsModel.selectedTagID }
    set { tagsModel.selectedTagID = newValue }
  }
  public internal(set) var projectReview: [ProjectReviewItem] {
    get { reviewModel.projectReview }
    set { reviewModel.projectReview = newValue }
  }
  public internal(set) var reviewProjectID: TaskID? {
    get { reviewModel.reviewProjectID }
    set { reviewModel.reviewProjectID = newValue }
  }
  public internal(set) var reviewDefault: ReviewInterval {
    get { reviewModel.reviewDefault }
    set { reviewModel.reviewDefault = newValue }
  }
}
