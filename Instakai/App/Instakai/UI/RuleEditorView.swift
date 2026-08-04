#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI
import InstakaiCore

/// Edits one `RuleBlueprint`.
///
/// The editor works on blueprints, never on compiled rules. That is what keeps
/// the generator honest: whatever the user builds here can be re-generated,
/// exported and imported, and re-tuned centrally later.
struct RuleEditorView: View {
    @EnvironmentObject private var session: SessionController
    @Environment(\.dismiss) private var dismiss

    @State private var draft: RuleBlueprint
    @State private var showsAdvanced = false
    private let onSave: (RuleBlueprint) -> Void

    init(blueprint: RuleBlueprint, onSave: @escaping (RuleBlueprint) -> Void) {
        _draft = State(initialValue: blueprint)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                gestureSection
                livePreviewSection
                conditionSection
                actionSection
                if showsAdvanced { advancedSection }
                Section {
                    Toggle("Gelişmiş ayarlar", isOn: $showsAdvanced.animation())
                }
            }
            .navigationTitle("Kural")
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
                    .disabled(draft.actions.isEmpty || draft.name.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Ad") {
            TextField("Kural adı", text: $draft.name)
            Toggle("Etkin", isOn: $draft.isEnabled)
        }
    }

    private var gestureSection: some View {
        Section {
            Picker("Hareket", selection: $draft.gesture) {
                ForEach(GesturePreset.groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.presets, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                }
            }

            Picker("Hassasiyet", selection: $draft.sensitivity) {
                ForEach(Sensitivity.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
        } header: {
            Text("Hareket")
        } footer: {
            Text(generatedTrigger.summary)
                .font(.caption.monospaced())
        }
    }

    /// Shows the watched signal against the generated threshold in real time, so
    /// hassasiyet can be chosen by trying the gesture rather than by guessing.
    private var livePreviewSection: some View {
        Section("Canlı önizleme") {
            SignalMeter(signal: draft.gesture.signal,
                        value: session.frame[draft.gesture.signal],
                        threshold: generatedTrigger.threshold)
                .padding(.vertical, 4)

            if !session.isRunning {
                Text("Önizleme için Oturum sekmesinden takibi başlatın.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var conditionSection: some View {
        Section {
            Picker("Ekran", selection: Binding(
                get: { draft.surface ?? .unknown },
                set: { draft.surface = $0 == .unknown ? nil : $0 }
            )) {
                Text("Hepsi").tag(Surface.unknown)
                ForEach(Surface.allCases.filter { $0 != .unknown }, id: \.self) { surface in
                    Text(surface.displayName).tag(surface)
                }
            }

            ForEach(Array(draft.extraConditions.enumerated()), id: \.offset) { index, condition in
                NavigationLink {
                    ConditionEditorView(condition: Binding(
                        get: { draft.extraConditions[index] },
                        set: { draft.extraConditions[index] = $0 }
                    ))
                } label: {
                    Text(describe(condition))
                        .font(.callout)
                        .lineLimit(2)
                }
            }
            .onDelete { draft.extraConditions.remove(atOffsets: $0) }

            Menu("Koşul ekle") {
                Button("Sinyal karşılaştırması") {
                    draft.extraConditions.append(.signal(.jawOpen, .greaterThan, 0.5))
                }
                Button("Bayrak") {
                    draft.extraConditions.append(.flag(name: "gezinme", equals: true))
                }
                Button("Saat aralığı") {
                    draft.extraConditions.append(.timeOfDay(startMinute: 22 * 60, endMinute: 7 * 60))
                }
                Button("Ekran (birden fazla)") {
                    draft.extraConditions.append(.any([.surface(.feed), .surface(.reels)]))
                }
                Button("DEĞİL grubu") {
                    draft.extraConditions.append(.not(.surface(.directMessages)))
                }
            }
        } header: {
            Text("Eğer")
        } footer: {
            Text("Buradaki koşulların hepsi aynı anda sağlanmalı (VE). " +
                 "Bir koşul içinde HERHANGİ BİRİ grubu kullanarak VEYA kurabilirsiniz.")
        }
    }

    private var actionSection: some View {
        Section {
            if draft.actions.isEmpty {
                Text("En az bir eylem gerekli.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(Array(draft.actions.enumerated()), id: \.offset) { index, action in
                NavigationLink {
                    ActionEditorView(action: Binding(
                        get: { draft.actions[index] },
                        set: { draft.actions[index] = $0 }
                    ), availableMacros: session.profile.resolvedMacros())
                } label: {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(action.displayName)
                    }
                }
            }
            .onDelete { draft.actions.remove(atOffsets: $0) }
            .onMove { draft.actions.move(fromOffsets: $0, toOffset: $1) }

            Menu("Eylem ekle") {
                Button("Makro çalıştır") { draft.actions.append(.runMacro(id: "scroll-next")) }
                Button("Kaydır") {
                    draft.actions.append(.scroll(direction: .down, amount: .screens(1), animated: true))
                }
                Button("Beğen") { draft.actions.append(.like) }
                Button("Kaydet") { draft.actions.append(.savePost) }
                Button("Git") { draft.actions.append(.navigate(.reels)) }
                Button("Ses aç/kapat") { draft.actions.append(.toggleMute) }
                Button("Bekle") { draft.actions.append(.delay(seconds: 0.3)) }
                Button("Titreşim") { draft.actions.append(.haptic(.light)) }
                Button("Bayrak değiştir") { draft.actions.append(.toggleFlag(name: "gezinme")) }
            }
        } header: {
            Text("O zaman")
        } footer: {
            Text("Eylemler sırayla çalışır. “Bekle” aradaki animasyonun bitmesini sağlar.")
        }
    }

    private var advancedSection: some View {
        Section {
            Stepper("Öncelik: \(draft.priority)", value: $draft.priority, in: -100...100, step: 5)

            Toggle("Yalnızca bu (düşük öncelikli kuralları bastır)", isOn: $draft.isExclusive)

            VStack(alignment: .leading) {
                Text("Bekleme süresi çarpanı: \(String(format: "%.2f", draft.cooldownScale))×")
                    .font(.caption)
                Slider(value: $draft.cooldownScale, in: 0.25...4, step: 0.25)
                Text("Üretilen bekleme: \(String(format: "%.2f", generatedRule.cooldown)) sn")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TextField("Not", text: $draft.notes, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("Gelişmiş")
        } footer: {
            Text("Aynı hareketi paylaşan kurallarda yüksek öncelikli olan kazanır.")
        }
    }

    // MARK: - Derived

    private var generatedTrigger: GestureTrigger {
        RuleGenerator.makeTrigger(for: draft)
    }

    private var generatedRule: Rule {
        RuleGenerator.makeRule(from: draft)
    }

    private func describe(_ condition: Condition) -> String {
        switch condition {
        case .all(let children):
            return children.map(describe).joined(separator: " VE ")
        case .any(let children):
            return children.map(describe).joined(separator: " VEYA ")
        case .not(let child):
            return "DEĞİL (\(describe(child)))"
        default:
            return condition.displayName
        }
    }
}
#endif
