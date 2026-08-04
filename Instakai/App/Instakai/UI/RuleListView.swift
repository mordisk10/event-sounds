#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI
import InstakaiCore

/// The rule library for the active profile.
struct RuleListView: View {
    @EnvironmentObject private var session: SessionController
    @State private var editing: RuleBlueprint?
    @State private var showsPresetPicker = false

    var body: some View {
        NavigationStack {
            List {
                if !session.warnings.isEmpty {
                    Section("Uyarılar") {
                        ForEach(session.warnings) { warning in
                            WarningRow(message: warning.message)
                        }
                    }
                }

                Section {
                    if session.profile.blueprints.isEmpty {
                        EmptyHint(title: "Henüz kural yok",
                                  message: "Sağ üstteki + ile bir hareket seçip eylem atayın.",
                                  systemImage: "wand.and.stars")
                    }
                    ForEach(session.profile.blueprints) { blueprint in
                        RuleRow(blueprint: blueprint)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = blueprint }
                    }
                    .onDelete { session.deleteBlueprints(at: $0) }
                    .onMove { session.moveBlueprints(from: $0, to: $1) }
                } header: {
                    Text("\(session.profile.name) — \(session.profile.blueprints.count) kural")
                } footer: {
                    Text("Sıralama görsel; hangi kuralın kazanacağını öncelik belirler.")
                }
            }
            .navigationTitle("Kurallar")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showsPresetPicker = true } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .accessibilityLabel("Hazır kurallar")

                    Button {
                        editing = RuleBlueprint(name: "Yeni kural",
                                                gesture: .tongueDown,
                                                actions: [.runMacro(id: "scroll-next")])
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Kural ekle")
                }
            }
            .sheet(item: $editing) { blueprint in
                RuleEditorView(blueprint: blueprint) { updated in
                    session.upsert(blueprint: updated)
                }
            }
            .sheet(isPresented: $showsPresetPicker) {
                PresetPickerView()
            }
        }
    }
}

private struct RuleRow: View {
    @EnvironmentObject private var session: SessionController
    let blueprint: RuleBlueprint

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { blueprint.isEnabled },
                set: { session.setBlueprint(blueprint.id, enabled: $0) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 5) {
                Text(blueprint.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(blueprint.isEnabled ? .primary : .secondary)

                Text("\(blueprint.gesture.displayName) → \(actionSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let surface = blueprint.surface {
                        TagChip(text: surface.displayName, systemImage: "rectangle.on.rectangle")
                    }
                    if !blueprint.extraConditions.isEmpty {
                        TagChip(text: "eğer ×\(blueprint.extraConditions.count)",
                                systemImage: "arrow.triangle.branch", tint: .purple)
                    }
                    if blueprint.isExclusive {
                        TagChip(text: "yalnızca bu", systemImage: "exclamationmark.octagon", tint: .orange)
                    }
                    if blueprint.priority != 0 {
                        TagChip(text: "öncelik \(blueprint.priority)", tint: .blue)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var actionSummary: String {
        guard let first = blueprint.actions.first else { return "eylem yok" }
        let extra = blueprint.actions.count > 1 ? " +\(blueprint.actions.count - 1)" : ""
        return first.displayName + extra
    }
}

/// Replaces the active profile's rules with one of the shipped presets.
private struct PresetPickerView: View {
    @EnvironmentObject private var session: SessionController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(PresetLibrary.catalogue.enumerated()), id: \.offset) { _, entry in
                        Button {
                            let preset = entry.make()
                            session.updateProfile { profile in
                                profile.blueprints = preset.blueprints
                                profile.macros = preset.macros
                                profile.flags = preset.flags
                                profile.modes = preset.modes
                                profile.defaultMode = preset.defaultMode
                            }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name).font(.body.weight(.medium))
                                Text(entry.notes).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Hazır bir set yüklemek bu profildeki mevcut kuralların yerini alır.")
                }
            }
            .navigationTitle("Hazır kurallar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}
#endif
