import SwiftUI
import AppKit

/// Shared focus/cursor state between the SwiftUI editor and the AppKit fields.
final class EditorState: ObservableObject {
    @Published var focusRequest: FocusRequest?
    var focusedLineID: UUID?
    weak var activeEditor: NSTextView?
}

struct FocusRequest: Equatable {
    let id: UUID
    let cursor: Int
}

/// The notepad: one text field per line on the left, live answers on the right.
/// Return/Backspace/arrow keys hop between rows so it feels like one document.
struct EditorView: View {
    @ObservedObject var model: SheetModel
    @StateObject private var state = EditorState()
    @State private var copiedIndex: Int?

    private let answerWidth: CGFloat = 150

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                    row(index: index, line: line)
                }
                // Clicking the empty space below puts the cursor on the last line.
                Color.clear
                    .frame(height: 260)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let last = model.lines.last {
                            state.focusRequest = FocusRequest(id: last.id, cursor: last.text.count)
                        }
                    }
            }
            .padding(.top, 14)
        }
        .background(TallyTheme.bg)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(TallyTheme.divider)
                .frame(width: 1)
                .padding(.trailing, answerWidth + 24)
        }
    }

    private func row(index: Int, line: Line) -> some View {
        HStack(alignment: .center, spacing: 16) {
            LineTextField(lineID: line.id, model: model, state: state)
                .frame(maxWidth: .infinity)
            answerView(index: index)
                .frame(width: answerWidth, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func answerView(index: Int) -> some View {
        if index < model.results.count, let value = model.results[index] {
            Text(copiedIndex == index ? "Copied" : value.formatted)
                .font(TallyTheme.answerFont)
                .foregroundStyle(copiedIndex == index ? TallyTheme.subtle : TallyTheme.answer)
                .lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture { tapAnswer(index: index, value: value) }
                .help("Click to copy — or to insert into the line you're editing")
        } else {
            Text("")
        }
    }

    /// Clicking an answer inserts a live reference if another (later) line is
    /// being edited; otherwise it copies the answer.
    private func tapAnswer(index: Int, value: Value) {
        if let focusID = state.focusedLineID,
           let focusIndex = model.index(of: focusID),
           index < focusIndex,
           let editor = state.activeEditor,
           editor.window?.firstResponder === editor {
            editor.insertText("line\(index + 1)", replacementRange: editor.selectedRange())
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value.formatted, forType: .string)
        copiedIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if copiedIndex == index { copiedIndex = nil }
        }
    }
}

// MARK: - One line of the document (AppKit text field)

struct LineTextField: NSViewRepresentable {
    let lineID: UUID
    @ObservedObject var model: SheetModel
    @ObservedObject var state: EditorState

    func makeNSView(context: Context) -> FocusAwareTextField {
        let tf = FocusAwareTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = .systemFont(ofSize: 15)
        tf.textColor = NSColor(TallyTheme.text)
        tf.lineBreakMode = .byClipping
        tf.cell?.usesSingleLineMode = true
        tf.delegate = context.coordinator
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.onFocus = { [weak tf] in
            context.coordinator.parent.state.focusedLineID = context.coordinator.parent.lineID
            DispatchQueue.main.async {
                context.coordinator.parent.state.activeEditor = tf?.currentEditor() as? NSTextView
            }
        }
        return tf
    }

    func updateNSView(_ tf: FocusAwareTextField, context: Context) {
        context.coordinator.parent = self
        let text = model.lines.first { $0.id == lineID }?.text ?? ""
        if tf.stringValue != text { tf.stringValue = text }

        if let req = state.focusRequest, req.id == lineID {
            let state = self.state
            DispatchQueue.main.async {
                guard state.focusRequest == req else { return }
                state.focusRequest = nil
                tf.window?.makeFirstResponder(tf)
                if let editor = tf.currentEditor() {
                    editor.selectedRange = NSRange(location: min(req.cursor, tf.stringValue.count),
                                                   length: 0)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: LineTextField
        init(_ parent: LineTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.model.setText(tf.stringValue, for: parent.lineID)
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            let model = parent.model
            let state = parent.state
            let id = parent.lineID
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                // The focused field becomes the new (lower) line synchronously,
                // so keystrokes typed right after Return land correctly.
                guard let tf = control as? NSTextField else { return true }
                let full = tf.stringValue
                let cursor = min(textView.selectedRange().location, full.count)
                if model.split(id, at: cursor) {
                    let cut = full.index(full.startIndex, offsetBy: cursor)
                    tf.stringValue = String(full[cut...])
                    textView.setSelectedRange(NSRange(location: 0, length: 0))
                }
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                if textView.selectedRange() == NSRange(location: 0, length: 0),
                   let tf = control as? NSTextField,
                   let cursor = model.mergeWithPrevious(id) {
                    if let i = model.index(of: id) {
                        tf.stringValue = model.lines[i].text
                    }
                    textView.setSelectedRange(NSRange(location: cursor, length: 0))
                    return true
                }
                return false
            case #selector(NSResponder.moveUp(_:)):
                if let i = model.index(of: id), i > 0 {
                    state.focusRequest = FocusRequest(id: model.lines[i - 1].id,
                                                      cursor: textView.selectedRange().location)
                }
                return true
            case #selector(NSResponder.moveDown(_:)):
                if let i = model.index(of: id), i < model.lines.count - 1 {
                    state.focusRequest = FocusRequest(id: model.lines[i + 1].id,
                                                      cursor: textView.selectedRange().location)
                }
                return true
            default:
                return false
            }
        }
    }
}

/// NSTextField that reports when it gains keyboard focus, and collapses the
/// automatic select-all so typing appends instead of replacing the line.
final class FocusAwareTextField: NSTextField {
    var onFocus: (() -> Void)?
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            onFocus?()
            DispatchQueue.main.async { [weak self] in
                guard let self, let editor = self.currentEditor() else { return }
                let len = self.stringValue.count
                if len > 0, editor.selectedRange == NSRange(location: 0, length: len) {
                    editor.selectedRange = NSRange(location: len, length: 0)
                }
            }
        }
        return ok
    }
}
