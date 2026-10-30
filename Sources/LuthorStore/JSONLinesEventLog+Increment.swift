import Foundation
import LuthorDomain

/// How far a reading of a log got: for each file, the bytes and lines taken in whole, and a checksum of the
/// last bytes taken, so a file replaced by another one is noticed. Opaque; a log makes it and reads on from it.
public struct LogCursor: Equatable, Sendable {
  var files: [String: FileCursor] = [:]
}

struct FileCursor: Equatable, Sendable {
  var offset = 0
  var lines = 0
  var tailSum: UInt64 = 0

  /// Bytes before `offset` that the checksum covers.
  static let tailLength = 32

  static func checksum(_ bytes: some Sequence<UInt8>) -> UInt64 {
    bytes.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
  }
}

// Reading a log file whole or from where a cursor left off. Split from the type (SwiftLint file_length).
extension JSONLinesEventLog {
  func readLines() throws(EventLogError) -> [Substring] {
    try checkSize()
    do {
      return try String(contentsOf: fileURL, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
    } catch {
      throw .ioFailure("cannot read \(fileURL.path): \(error)")
    }
  }

  /// Throws if the file is larger than `maxBytes`.
  func checkSize() throws(EventLogError) {
    let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
    if size > maxBytes { throw .ioFailure("\(fileURL.path) is larger than \(maxBytes) bytes; not reading it") }
  }

  public func readReportingProblems(skippingIncompleteTail: Bool) throws(EventLogError) -> LogReading {
    var reading = LogReading()
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return reading }
    guard
      let (part, file) = try scan(
        from: FileCursor(), includingTail: true, skippingIncompleteTail: skippingIncompleteTail)
    else { return reading }
    reading = part
    reading.cursor = LogCursor(files: [fileURL.lastPathComponent: file])
    return reading
  }

  /// What was appended after `cursor` for this file: the whole lines past its offset, and the new cursor.
  /// `nil` if the file is shorter than the cursor says, or its bytes before the offset are not the ones read.
  func readIncrement(from cursor: FileCursor) throws(EventLogError) -> (LogReading, FileCursor)? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    return try scan(from: cursor, includingTail: false, skippingIncompleteTail: true)
  }

  /// Reads from the cursor to the end, decoding the whole lines (and with `includingTail`, a last line with no
  /// newline yet if it decodes; if not, it is a problem unless `skippingIncompleteTail`). The cursor given back
  /// stops after the last newline, so a tail is read again once it is finished.
  func scan(
    from cursor: FileCursor, includingTail: Bool, skippingIncompleteTail: Bool
  ) throws(EventLogError) -> (LogReading, FileCursor)? {
    let data: Data
    let precedingBytes: [UInt8]
    do {
      let handle = try FileHandle(forReadingFrom: fileURL)
      defer { try? handle.close() }
      let size = Int(try handle.seekToEnd())
      guard size >= cursor.offset else { return nil }
      guard size - cursor.offset <= maxBytes else {
        throw EventLogError.ioFailure("\(fileURL.path) is larger than \(maxBytes) bytes; not reading it")
      }
      let covered = min(FileCursor.tailLength, cursor.offset)
      try handle.seek(toOffset: UInt64(cursor.offset - covered))
      precedingBytes = [UInt8](try handle.read(upToCount: covered) ?? Data())
      guard cursor.offset == 0 || FileCursor.checksum(precedingBytes) == cursor.tailSum else { return nil }
      data = try handle.readToEnd() ?? Data()
    } catch {
      throw .ioFailure("cannot read \(fileURL.path): \(error)")
    }
    var reading = LogReading()
    var next = cursor
    var start = data.startIndex
    var lineNumber = cursor.lines
    func take(_ bytes: Data.SubSequence, isTail: Bool) {
      lineNumber += 1
      guard !bytes.allSatisfy({ $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }) else { return }
      do {
        guard let text = String(bytes: bytes, encoding: .utf8) else { throw EventLogError.unreadableLine(0) }
        if let event = try EventLine.decodeIfKnown(text) {
          if let acceptsDevice, !acceptsDevice(event.deviceID) { throw EventLogError.unreadableLine(0) }
          reading.events.append(event)
        }
      } catch {
        if isTail && skippingIncompleteTail { return }
        reading.problems.append(LogProblem(file: fileURL.lastPathComponent, line: lineNumber))
      }
    }
    while let newline = data[start...].firstIndex(of: 0x0A) {
      take(data[start..<newline], isTail: false)
      start = data.index(after: newline)
    }
    let consumed = start - data.startIndex
    if consumed > 0 {
      let whole = precedingBytes + data[data.startIndex..<start]
      next = FileCursor(
        offset: cursor.offset + consumed, lines: lineNumber,
        tailSum: FileCursor.checksum(whole.suffix(FileCursor.tailLength)))
    }
    if includingTail, start < data.endIndex { take(data[start...], isTail: true) }
    return (reading, next)
  }
}
