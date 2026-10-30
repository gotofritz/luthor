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
  public internal(set) var views: [ViewItem] {
    get { settingsModel.views }
    set { settingsModel.views = newValue }
  }
  public internal(set) var viewBeingEdited: ViewID? {
    get { settingsModel.viewBeingEdited }
    set { settingsModel.viewBeingEdited = newValue }
  }
  public internal(set) var globalSettings: Settings {
    get { settingsModel.globalSettings }
    set { settingsModel.globalSettings = newValue }
  }
  public internal(set) var viewSettings: Settings {
    get { settingsModel.viewSettings }
    set { settingsModel.viewSettings = newValue }
  }
  public internal(set) var settingsByView: [ViewID: Settings] {
    get { settingsModel.settingsByView }
    set { settingsModel.settingsByView = newValue }
  }
  public internal(set) var overriddenKeysByView: [ViewID: Set<SettingKey>] {
    get { settingsModel.overriddenKeysByView }
    set { settingsModel.overriddenKeysByView = newValue }
  }
  public internal(set) var defaultViewID: ViewID {
    get { settingsModel.defaultViewID }
    set { settingsModel.defaultViewID = newValue }
  }
  public internal(set) var projects: [Project] {
    get { browserModel.projects }
    set { browserModel.projects = newValue }
  }
  public internal(set) var knownProjects: [Project] {
    get { browserModel.knownProjects }
    set { browserModel.knownProjects = newValue }
  }
  public internal(set) var shownProject: Project? {
    get { browserModel.shownProject }
    set { browserModel.shownProject = newValue }
  }
  public internal(set) var columns: [ProjectColumn] {
    get { browserModel.columns }
    set { browserModel.columns = newValue }
  }
  public internal(set) var path: [TaskID] {
    get { browserModel.path }
    set { browserModel.path = newValue }
  }
  public internal(set) var listSorts: [String: ListSort] {
    get { browserModel.listSorts }
    set { browserModel.listSorts = newValue }
  }
  public internal(set) var listColumns: [String: Set<ListColumn>] {
    get { browserModel.listColumns }
    set { browserModel.listColumns = newValue }
  }
  public internal(set) var columnWidths: [String: [String: Double]] {
    get { browserModel.columnWidths }
    set { browserModel.columnWidths = newValue }
  }
  public internal(set) var tasks: [TaskItem] {
    get { listedModel.tasks }
    set { listedModel.tasks = newValue }
  }
  public internal(set) var nextActions: Set<TaskID> {
    get { listedModel.nextActions }
    set { listedModel.nextActions = newValue }
  }
  public internal(set) var completedTaskIDs: Set<TaskID> {
    get { listedModel.completedTaskIDs }
    set { listedModel.completedTaskIDs = newValue }
  }
  public internal(set) var completedProjectIDs: Set<TaskID> {
    get { listedModel.completedProjectIDs }
    set { listedModel.completedProjectIDs = newValue }
  }
  public internal(set) var droppedTaskIDs: Set<TaskID> {
    get { listedModel.droppedTaskIDs }
    set { listedModel.droppedTaskIDs = newValue }
  }
  public internal(set) var droppedProjectIDs: Set<TaskID> {
    get { listedModel.droppedProjectIDs }
    set { listedModel.droppedProjectIDs = newValue }
  }
  public internal(set) var reopenableTaskIDs: Set<TaskID> {
    get { listedModel.reopenableTaskIDs }
    set { listedModel.reopenableTaskIDs = newValue }
  }
  public internal(set) var reopenableProjectIDs: Set<TaskID> {
    get { listedModel.reopenableProjectIDs }
    set { listedModel.reopenableProjectIDs = newValue }
  }
  public internal(set) var multiSelection: Set<TaskID> {
    get { selectionModel.multiSelection }
    set { selectionModel.multiSelection = newValue }
  }
  public internal(set) var projectCardOpen: Bool {
    get { selectionModel.projectCardOpen }
    set { selectionModel.projectCardOpen = newValue }
  }
  public internal(set) var editingCard: CardTarget? {
    get { selectionModel.editingCard }
    set { selectionModel.editingCard = newValue }
  }
  public internal(set) var newItem: NewItemDraft? {
    get { selectionModel.newItem }
    set { selectionModel.newItem = newValue }
  }
  var newItemsStarted: Int {
    get { selectionModel.newItemsStarted }
    set { selectionModel.newItemsStarted = newValue }
  }
  public var delegatingTaskID: TaskID? {
    get { selectionModel.delegatingTaskID }
    set { selectionModel.delegatingTaskID = newValue }
  }
  /// The task picked, whose card is shown. Picking another closes the card being edited and the item being added,
  /// and picking one closes the project card and the tasks picked together.
  public var selection: TaskID? {
    get { selectionModel.selection }
    set {
      let before = selectionModel.selection
      selectionModel.selection = newValue
      if newValue != before {
        editingCard = nil
        newItem = nil
      }
      if newValue != nil {
        projectCardOpen = false
        multiSelection = []
      }
    }
  }
}
