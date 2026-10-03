import Foundation

/// Keeps completed recognition windows while allowing corrections within the current window.
public struct DictationTranscript {
    public private(set) var completed = ""
    public private(set) var partial = ""
    private var segmentStart: Double?
    public init() {}
    public var text: String { [completed, partial].filter { !$0.isEmpty }.joined(separator: " ") }
    public mutating func update(_ value: String, segmentStart: Double?) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let old = self.segmentStart, let next = segmentStart, next > old + 0.5, !partial.isEmpty, !clean.lowercased().hasPrefix(partial.lowercased()) {
            commit()
        }
        self.segmentStart = segmentStart
        partial = clean
    }
    public mutating func commit() {
        completed = text
        partial = ""
        segmentStart = nil
    }
}
