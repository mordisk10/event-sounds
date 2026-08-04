#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI
import InstakaiCore

/// Browse and edit macros. Built-ins are read-only but can be copied.
struct MacroListView: View {
    @EnvironmentObject private var session: SessionController
    @State private var editing: Macro?

    var body: some View {
        NavigationStack {
            List {
                Section("Bu profildeki makrolar") {
                    if session.profile.macros.isEmpty {
                        EmptyHint(title: "Özel makro yok",
                                  message: "Hazır bir makroyu kopyalayarak başlayın.",
                                  systemImage: "square.stack.3d.up")
                    }
                    ForEach(session.profile.macros) { macro in
                        MacroRow(macro: macro)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = macro }
                    }
                }

                Section {
                    ForEach(MacroLibrary.builtIns) { macro in
                        MacroRow(macro: macro)
                            .swipeActions {
                                Button("Kopyala") {
                                    var copy = macro
                                    copy.id = macro.id + "-kopya"
                                    copy.name = macro.name + " kopyası"
                                    copy.isBuiltIn = false
                                    session.upsert(macro: copy)
                                    editing = copy
                                }
                                .tint(.blue)
                            }
                    }
                } header: {
                    Text("Hazır makrolar")
                } footer: {
                    Text("Hazır makrolar değiştirilemez. Kopyalayıp düzenleyin; " +
                         "aynı kimliği kullanan bir kopya hazır olanın yerine geçer.")
                }
            }
            .navigationTitle("Makrolar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = Macro(id: "makro-\(UUID().uuidString.prefix(6))",
                                        name: "Yeni makro",
                                        actions: [.scroll(direction: .down,
                                                          amount: .screens(1),
                                                          animated: true)])
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { macro in
                MacroEditorView(macro: macro) { session.upsert(macro: $0) }
            }
        }
    }
}

private struct MacroRow: View {
    let macro: Macro

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(macro.name).font(.body.weight(.medium))
                if macro.isBuiltIn {
                    TagChip(text: "hazır", tint: .secondary)
                }
            }
            Text(macro.id)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(macro.actions.map(\.displayName).joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

private struct MacroEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionController
    @State private var draft: Macro
    private let onSave: (Macro) -> Void

    init(macro: Macro, onSave: @escaping (Macro) -> Void) {
        _draft = State(initialValue: macro)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kimlik") {
                    TextField("Ad", text: $draft.name)
                    TextField("Kimlik (id)", text: $draft.id)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Not", text: $draft.notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    ForEach(Array(draft.actions.enumerated()), id: \.offset) { index, action in
                        NavigationLink {
                            ActionEditorView(action: Binding(
                                get: { draft.actions[index] },
                                set: { draft.actions[index] = $0 }
                            ), availableMacros: session.profile.resolvedMacros())
                        } label: {
                            Text("\(index + 1). \(action.displayName)")
                        }
                    }
                    .onDelete { draft.actions.remove(atOffsets: $0) }
                    .onMove { draft.actions.move(fromOffsets: $0, toOffset: $1) }

                    Button("Adım ekle") {
                        draft.actions.append(.delay(seconds: 0.3))
                    }
                } header: {
                    Text("Adımlar")
                } footer: {
                    Text("Makrolar başka makroları çağırabilir. Döngüler kaydederken yakalanır.")
                }
            }
            .navigationTitle("Makro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.id.isEmpty || draft.actions.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
        }
    }
}
#endif
