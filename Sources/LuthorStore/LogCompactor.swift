import Foundation
import LuthorDomain

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
/// has one short run of events for each item, and replaces the old files with it. History (time logged,
/// reviewed days, the plan's manual order) is dropped; tasks, projects, settings and project reviews stay.
/// Nothing is deleted before the backup is complete and the new log has been checked to hold the same library.
public enum LogCompactor {
  /// `stamp` names the backup folder, `compact-<stamp>`, under `backups` next to the log.
  public static func compact(
    configuration: LuthorConfiguration, ids: any IDGenerator, stamp: String
  ) throws(EventLogError) -> LogCompaction {
    let before = try configuration.makeEventLog().readAll()
    let export = LibraryState.replay(before).export()
    let yaml = try LibraryText.export(export)
    let after: [EventEnvelope]
    do {
      after = try Commands(deviceID: configuration.deviceID, ids: ids).importLibrary(export, log: [])
    } catch {
      throw .ioFailure("cannot rebuild the log: \(error)")
    }
    guard LibraryState.replay(after).export() == export else {
      throw .ioFailure("the rebuilt log does not hold the same library; nothing was changed")
    }

    let folder = configuration.syncDirectory ?? configuration.logURL.deletingLastPathComponent()
    let ownName =
      configuration.syncDirectory == nil
      ? configuration.logURL.lastPathComponent : DeviceFilesEventLog.fileName(for: configuration.deviceID)
    let backup = folder.appendingPathComponent("backups").appendingPathComponent("compact-\(stamp)")
    let oldFiles = try logFiles(configuration, in: folder)
    try back(up: oldFiles, yaml: yaml, into: backup)
    try replace(oldFiles, ownName: ownName, in: folder, with: after)
    return LogCompaction(eventsBefore: before.count, eventsAfter: after.count, backupFolder: backup)
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
  /// devices' files, which the backup holds.
  private static func replace(
    _ oldFiles: [URL], ownName: String, in folder: URL, with events: [EventEnvelope]
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
        _ = try FileManager.default.replaceItemAt(own, withItemAt: temporary)
      } else {
        try FileManager.default.moveItem(at: temporary, to: own)
      }
      for file in oldFiles where file.lastPathComponent != ownName {
        try FileManager.default.removeItem(at: file)
      }
    } catch {
      throw .ioFailure("cannot replace the log; the backup is in \(folder.path)/backups: \(error)")
    }
  }
}
