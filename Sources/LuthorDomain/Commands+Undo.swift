extension Commands {
  /// Writes `payloads` as new events, in order, after the log: what an undo or a redo appends. Nothing already
  /// written is touched.
  public func append(_ payloads: [EventPayload], log: [EventEnvelope]) -> [EventEnvelope] {
    var written: [EventEnvelope] = []
    for payload in payloads {
      written.append(envelope(EventID(ids.next()), payload, log: log + written))
    }
    return written
  }
}
