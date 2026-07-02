import Foundation
import AppKit

/// Sheets are plain .txt files in ~/Library/Application Support/Tally/Sheets.
/// The current sheet autosaves half a second after the last keystroke.
final class SheetStore: ObservableObject {
    @Published private(set) var sheets: [String] = []
    @Published private(set) var selected: String?
    let model = SheetModel()

    private var saveWork: DispatchWorkItem?

    private var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tally/Sheets", isDirectory: true)
    }
    private func url(_ name: String) -> URL {
        dir.appendingPathComponent(name).appendingPathExtension("txt")
    }

    init() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        reloadList()
        if sheets.isEmpty {
            try? "".write(to: url("Notes"), atomically: true, encoding: .utf8)
            reloadList()
        }
        let last = UserDefaults.standard.string(forKey: "lastSheet")
        open(last.flatMap { sheets.contains($0) ? $0 : nil } ?? sheets.first)

        model.onChange = { [weak self] in self?.scheduleSave() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.saveNow() }
    }

    private func reloadList() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        sheets = files.filter { $0.hasSuffix(".txt") }
            .map { String($0.dropLast(4)) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func open(_ name: String?) {
        guard let name else { return }
        let text = (try? String(contentsOf: url(name), encoding: .utf8)) ?? ""
        model.load(text)
        selected = name
        UserDefaults.standard.set(name, forKey: "lastSheet")
    }

    func select(_ name: String?) {
        guard name != selected else { return }
        saveWork?.cancel()
        saveNow()
        open(name)
    }

    func newSheet() {
        var name = "Untitled"
        var n = 2
        while sheets.contains(name) { name = "Untitled \(n)"; n += 1 }
        try? "".write(to: url(name), atomically: true, encoding: .utf8)
        reloadList()
        select(name)
    }

    func rename(_ name: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != name, !sheets.contains(trimmed) else { return }
        if selected == name { saveNow() }
        try? FileManager.default.moveItem(at: url(name), to: url(trimmed))
        reloadList()
        if selected == name {
            selected = trimmed
            UserDefaults.standard.set(trimmed, forKey: "lastSheet")
        }
    }

    func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
        reloadList()
        if selected == name {
            selected = nil
            open(sheets.first)
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        guard let selected else { return }
        try? model.fullText.write(to: url(selected), atomically: true, encoding: .utf8)
    }
}
