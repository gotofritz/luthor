import LuthorDomain
import Yams

/// The tasks and projects as YAML text, for a copy that does not depend on the app, and the way back in.
///
/// ```
/// format: 1
/// views: [{id: default, name: Default}]
/// tags: []
/// items:
///   - id: t1
///     title: Buy milk
///     view: default
///     status: open
/// ```
public enum LibraryText {
  public static func export(_ library: LibraryExport) throws(EventLogError) -> String {
    do {
      return try YAMLEncoder(options: .init(sortKeys: true)).encode(library)
    } catch {
      throw .ioFailure("cannot write the export: \(error)")
    }
  }

  /// A text of a newer format, or one that is not an export, is an error.
  public static func library(from text: String) throws(EventLogError) -> LibraryExport {
    let library: LibraryExport
    do {
      library = try YAMLDecoder().decode(LibraryExport.self, from: text)
    } catch {
      throw .ioFailure("not a readable export: \(error)")
    }
    guard library.format == LibraryExport.formatVersion else {
      throw .ioFailure(
        "export format \(library.format) is not supported; this build reads format \(LibraryExport.formatVersion)")
    }
    return library
  }
}
