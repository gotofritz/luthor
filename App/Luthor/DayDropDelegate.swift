import LuthorDomain
import LuthorViewModels
import SwiftUI

/// Follows a drag over the hour grid: a dragged task shows where it would land while the others make room, and
/// the drop keeps that.
struct DayDropDelegate: DropDelegate {
  let library: LibraryViewModel
  let firstHour: Int
  let hourHeight: CGFloat

  private func minute(at location: CGPoint) -> Int {
    max(firstHour * 60 + Int(location.y / hourHeight * 60), 0) / 15 * 15
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    if let dragged = library.draggedTaskID {
      library.dragPreview = (dragged, min(minute(at: info.location), library.dayLimit - 15))
    } else if let dragged = library.draggedBlockID {
      library.previewBlock(dragged, toStart: minute(at: info.location))
    } else if let dragged = library.draggedSessionID {
      library.previewSession(dragged, atMinute: minute(at: info.location))
    }
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    library.dragPreview = nil
    library.blockPreview = nil
    library.sessionPreview = nil
  }

  func performDrop(info: DropInfo) -> Bool {
    let minute = minute(at: info.location)
    library.dragPreview = nil
    library.blockPreview = nil
    library.draggedTaskID = nil
    library.draggedBlockID = nil
    library.sessionPreview = nil
    library.draggedSessionID = nil
    guard let provider = info.itemProviders(for: [.text]).first else { return false }
    _ = provider.loadObject(ofClass: NSString.self) { item, _ in
      guard let dropped = item as? String else { return }
      Task { @MainActor in
        if let blockID = DayBlockView.blockID(in: dropped) {
          library.moveBlock(blockID, toStart: minute)
        } else if let sessionID = SessionBlockView.sessionID(in: dropped) {
          library.placeSession(sessionID, atMinute: minute)
        } else {
          library.place(TaskID(dropped), atMinute: min(minute, library.dayLimit - 15))
        }
      }
    }
    return true
  }
}
