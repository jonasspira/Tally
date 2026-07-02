import Foundation
import Combine

struct Line: Identifiable, Equatable {
    let id: UUID
    var text: String
    init(_ text: String = "") {
        self.id = UUID()
        self.text = text
    }
}

/// The document: an ordered list of lines plus their evaluated answers.
/// Splitting/merging lines rewrites "lineN" reference tokens so they keep
/// pointing at the same line when line numbers shift.
final class SheetModel: ObservableObject {
    @Published private(set) var lines: [Line] = [Line()]
    @Published private(set) var results: [Value?] = [nil]
    var onChange: (() -> Void)?

    var fullText: String { lines.map(\.text).joined(separator: "\n") }

    func load(_ text: String) {
        let parts = text.components(separatedBy: "\n")
        lines = parts.isEmpty ? [Line()] : parts.map { Line($0) }
        recalc(notify: false)
    }

    func index(of id: UUID) -> Int? {
        lines.firstIndex { $0.id == id }
    }

    func setText(_ text: String, for id: UUID) {
        guard let i = index(of: id), lines[i].text != text else { return }
        lines[i].text = text
        recalc()
    }

    /// Split a line at a cursor offset (Return key). The focused line KEEPS its
    /// identity and holds the text after the cursor, while the text before the
    /// cursor moves to a fresh line above. That way the field with keyboard
    /// focus never changes, so keystrokes right after Return can't get lost.
    func split(_ id: UUID, at offset: Int) -> Bool {
        guard let i = index(of: id) else { return false }
        renumberRefs { $0 > i + 1 ? $0 + 1 : $0 }
        let text = lines[i].text
        let cut = text.index(text.startIndex, offsetBy: min(offset, text.count))
        lines[i].text = String(text[cut...])
        lines.insert(Line(String(text[..<cut])), at: i)
        recalc()
        return true
    }

    /// Backspace at line start: absorb the previous line into the focused one
    /// (again keeping the focused line's identity). Returns the cursor position
    /// at the join, or nil if there is no previous line.
    func mergeWithPrevious(_ id: UUID) -> Int? {
        guard let i = index(of: id), i > 0 else { return nil }
        renumberRefs { old in
            old >= i + 1 ? old - 1 : old   // refs to either joined line → merged line
        }
        let prefix = lines[i - 1].text
        lines[i].text = prefix + lines[i].text
        lines.remove(at: i - 1)
        recalc()
        return prefix.count
    }

    func recalc(notify: Bool = true) {
        results = TallyEngine.evaluate(lines.map(\.text))
        if notify { onChange?() }
    }

    private func renumberRefs(_ map: (Int) -> Int) {
        let regex = try! NSRegularExpression(pattern: "\\bline([0-9]+)\\b")
        for i in lines.indices {
            var text = lines[i].text
            guard text.contains("line") else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for m in matches.reversed() {
                guard let numRange = Range(m.range(at: 1), in: text),
                      let old = Int(text[numRange]),
                      let fullRange = Range(m.range, in: text) else { continue }
                text.replaceSubrange(fullRange, with: "line\(map(old))")
            }
            lines[i].text = text
        }
    }
}
