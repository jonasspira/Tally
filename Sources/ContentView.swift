import SwiftUI

struct ContentView: View {
    @StateObject private var store = SheetStore()
    @State private var renaming: String?
    @State private var renameText = ""

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { store.selected },
                                    set: { store.select($0) })) {
                ForEach(store.sheets, id: \.self) { name in
                    Label(name, systemImage: "doc.text")
                        .tag(name)
                        .contextMenu {
                            Button("Rename…") { renaming = name; renameText = name }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(name) }
                        }
                }
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 185)
        } detail: {
            EditorView(model: store.model)
        }
        .navigationTitle(store.selected ?? "Tally")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.newSheet() } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New sheet")
            }
        }
        .alert("Rename Sheet", isPresented: Binding(get: { renaming != nil },
                                                    set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let old = renaming { store.rename(old, to: renameText) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }
}
