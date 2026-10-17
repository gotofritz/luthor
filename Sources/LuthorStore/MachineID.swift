/// The ID of this Mac, made once and kept on the Mac (never in the log or the shared folder), so two Macs
/// that share a host name still tell their files apart.
public enum MachineID {
  /// The ID saved earlier, or, with none, a new one from `make`, which is handed to `save`.
  public static func current(saved: String?, make: () -> String, save: (String) -> Void) -> String {
    if let saved, !saved.allSatisfy(\.isWhitespace) { return saved }
    let made = make()
    save(made)
    return made
  }
}
