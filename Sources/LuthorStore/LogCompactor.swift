import Foundation
import LuthorDomain

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

/// What a compaction did.
public struct LogCompaction: Equatable, Sendable {
  public let eventsBefore: Int
  public let eventsAfter: Int
  /// Where the old log files and a YAML copy of the library were put.
  public let backupFolder: URL

  public init(eventsBefore: Int, eventsAfter: Int, backupFolder: URL) {
    self.eventsBefore = eventsBefore
    self.eventsAfter = eventsAfter
    self.backupFolder = backupFolder
  }
}

/// Rebuilds the log from the library it holds: backs up the log files and a YAML copy, writes a log that
/// has one short run of events for each item, and replaces the old files with it. What a compaction may
/// forget is only the history of how the library came to be; the library itself, the plan of the days and
/// the daily review (time logged, reviewed days) are carried over. It refuses, and changes nothing, when
/// the log holds events this build cannot read, or when a log file changed while it was working.
/// Nothing is deleted before the backup is complete and the new log has been checked to hold the same state.
public enum LogCompactor {
  /// `stamp` names the backup folder, `compact-<stamp>`, under `backups` next to the log. `beforeSwap` runs
  /// once the new log is checked and backed up, just before the old files are replaced.
  @discardableResult
  public static func compact(
    configuration: LuthorConfiguration, ids: any IDGenerator, stamp: String,
    beforeSwap: () throws -> Void = {}
  ) throws(EventLogError) -> LogCompaction {
    let folder = configuration.syncDirectory ?? configuration.logURL.deletingLastPathComponent()
    let ownName =
      configuration.syncDirectory == nil
      ? configuration.logURL.lastPathComponent : DeviceFilesEventLog.fileName(for: configuration.deviceID)
    let oldFiles = try logFiles(configuration, in: folder)
    let sizesBefore = try sizes(of: oldFiles)
    let before = try configuration.makeEventLog().readAll()
    try refuseEventsOfANewerBuild(in: oldFiles)
    let export = LibraryState.replay(before).export()
    let yaml = try LibraryText.export(export)
    let after: [EventEnvelope]
    do {
      after = try Commands(deviceID: configuration.deviceID, ids: ids).importLibrary(
        export, log: [], startingAfter: before.map(\.lamport).max() ?? 0)
    } catch {
      throw .ioFailure("cannot rebuild the log: \(error)")
    }
    let rebuilt = after + carriedOver(from: before, after: after, configuration: configuration, ids: ids)
    let expected = LibraryState.replay(before)
    let actual = LibraryState.replay(rebuilt)
    if let difference = export.firstDifference(from: actual.export()) {
      throw .ioFailure("the rebuilt log does not hold the same library (\(difference)); nothing was changed")
    }
    if let difference = expected.firstDifferenceInPlanAndReview(from: actual) {
      throw .ioFailure("the rebuilt log does not hold the same plan and review (\(difference)); nothing was changed")
    }

    let backup = folder.appendingPathComponent("backups").appendingPathComponent("compact-\(stamp)")
    try back(up: oldFiles, yaml: yaml, into: backup)
    do {
      try beforeSwap()
    } catch {
      throw .ioFailure("compaction stopped, nothing was changed: \(error)")
    }
    try requireUnchanged(oldFiles, sizes: sizesBefore)
    try replace(oldFiles, ownName: ownName, in: folder, with: rebuilt, stamp: stamp)
    return LogCompaction(eventsBefore: before.count, eventsAfter: rebuilt.count, backupFolder: backup)
  }

  /// The events an export cannot hold (the plan of the days, the daily review), as they were, in replay order,
  /// with new IDs and Lamport counters that follow the rebuilt events.
  private static func carriedOver(
    from before: [EventEnvelope], after: [EventEnvelope], configuration: LuthorConfiguration,
    ids: any IDGenerator
  ) -> [EventEnvelope] {
    var next = (after.map(\.lamport).max() ?? before.map(\.lamport).max() ?? 0) + 1
    var seen = Set<EventID>()
    var carried: [EventEnvelope] = []
    for event in before.sorted(by: EventEnvelope.replayOrder)
    where event.payload.isBeyondExport && seen.insert(event.id).inserted {
      carried.append(
        EventEnvelope(
          id: EventID(ids.next()), deviceID: configuration.deviceID, lamport: next, payload: event.payload))
      next += 1
    }
    return carried
  }

  /// Compacting writes the library back from what this build understands, so a line it skipped would be lost.
  private static func refuseEventsOfANewerBuild(in files: [URL]) throws(EventLogError) {
    for file in files {
      let text: String
      do {
        text = try String(contentsOf: file, encoding: .utf8)
      } catch {
        throw .ioFailure("cannot read \(file.path): \(error)")
      }
      for line in text.split(separator: "\n") where !line.allSatisfy(\.isWhitespace) {
        let known: EventEnvelope?
        do {
          known = try EventLine.decodeIfKnown(String(line))
        } catch {
          continue  // A damaged line, or a tail still syncing; reading the log has reported it.
        }
        if known == nil {
          throw .ioFailure(
            "\(file.lastPathComponent) holds events written by a newer version of Luthor, "
              + "which compacting would delete. Update Luthor first; nothing was changed.")
        }
      }
    }
  }

  private static func sizes(of files: [URL]) throws(EventLogError) -> [URL: UInt64] {
    var sizes: [URL: UInt64] = [:]
    for file in files {
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        sizes[file] = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
      } catch {
        throw .ioFailure("cannot look at \(file.path): \(error)")
      }
    }
    return sizes
  }

  /// A file that grew since the log was read holds events the new log lacks; replacing it would lose them.
  private static func requireUnchanged(_ files: [URL], sizes expected: [URL: UInt64]) throws(EventLogError) {
    let now = try sizes(of: files)
    if let changed = files.first(where: { now[$0] != expected[$0] }) {
      throw .ioFailure("\(changed.lastPathComponent) changed while compacting; nothing was changed. Try again.")
    }
  }

  private static func logFiles(_ configuration: LuthorConfiguration, in folder: URL) throws(EventLogError) -> [URL] {
    guard configuration.syncDirectory != nil else {
      return FileManager.default.fileExists(atPath: configuration.logURL.path) ? [configuration.logURL] : []
    }
    do {
      return try FileManager.default.contentsOfDirectory(atPath: folder.path)
        .filter(DeviceFilesEventLog.isDeviceLog(named:)).sorted().map { folder.appendingPathComponent($0) }
    } catch {
      throw .ioFailure("cannot list \(folder.path): \(error)")
    }
  }

  private static func back(up files: [URL], yaml: String, into backup: URL) throws(EventLogError) {
    do {
      try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
      for file in files {
        try FileManager.default.copyItem(at: file, to: backup.appendingPathComponent(file.lastPathComponent))
      }
      try yaml.write(to: backup.appendingPathComponent("library.yml"), atomically: true, encoding: .utf8)
    } catch {
      throw .ioFailure("cannot back up the log, nothing was changed: \(error)")
    }
  }

  /// Writes the new log beside the old one and swaps it in for this device's file, then removes the other
  /// devices' files aside as `<name>.compacted-<stamp>`, which no reader takes for a device's log. They are not
  /// deleted: a device that missed the handshake may have written to its file after the checks.
  private static func replace(
    _ oldFiles: [URL], ownName: String, in folder: URL, with events: [EventEnvelope], stamp: String
  ) throws(EventLogError) {
    let own = folder.appendingPathComponent(ownName)
    let temporary = folder.appendingPathComponent(ownName + ".new")
    do {
      if FileManager.default.fileExists(atPath: temporary.path) {
        try FileManager.default.removeItem(at: temporary)
      }
      try Data().write(to: temporary)
    } catch {
      throw .ioFailure("cannot write the new log, nothing was changed: \(error)")
    }
    try JSONLinesEventLog(fileURL: temporary).append(events)
    do {
      if FileManager.default.fileExists(atPath: own.path) {
        // rename(2) replaces atomically on every platform; Foundation's replaceItemAt fails on Linux.
        guard rename(temporary.path, own.path) == 0 else {
          throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
        }
      } else {
        try FileManager.default.moveItem(at: temporary, to: own)
      }
      for file in oldFiles where file.lastPathComponent != ownName {
        let aside = file.deletingLastPathComponent().appendingPathComponent(
          file.lastPathComponent + ".compacted-" + stamp)
        if FileManager.default.fileExists(atPath: aside.path) { try FileManager.default.removeItem(at: aside) }
        try FileManager.default.moveItem(at: file, to: aside)
      }
    } catch {
      throw .ioFailure("cannot replace the log; the backup is in \(folder.path)/backups: \(error)")
    }
  }
}
