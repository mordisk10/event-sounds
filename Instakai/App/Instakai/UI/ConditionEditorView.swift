#if canImport(SwiftUI)
import SwiftUI
import InstakaiCore

/// Recursive editor for one `Condition` node.
///
/// Group nodes (`all` / `any` / `not`) render their children as navigation links
/// back into this same view, so an arbitrarily nested "eğer" tree can be built
/// without a bespoke screen per depth.
struct ConditionEditorView: View {
    @Binding var condition: Condition

    var body: some View {
        Form {
            Section("Koşul türü") {
                Picker("Tür", selection: Binding(
                    get: { ConditionKind(condition) },
                    set: { condition = $0.makeDefault(from: condition) }
                )) {
                    ForEach(ConditionKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }

            detailSection
        }
        .navigationTitle("Koşul")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var detailSection: some View {
        switch condition {
        case .always:
            Section {
                Text("Bu koşul her zaman sağlanır.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .signal(let signal, let op, let value):
            Section("Sinyal") {
                Picker("Sinyal", selection: Binding(
                    get: { signal },
                    set: { condition = .signal($0, op, value) }
                )) {
                    ForEach(Signal.groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.signals, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    }
                }

                Picker("Karşılaştırma", selection: Binding(
                    get: { op },
                    set: { condition = .signal(signal, $0, value) }
                )) {
                    ForEach(ComparisonOperator.allCases, id: \.self) { Text($0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading) {
                    Text("Eşik: \(String(format: "%.2f", value))").font(.caption)
                    Slider(value: Binding(
                        get: { value },
                        set: { condition = .signal(signal, op, $0) }
                    ), in: 0...1, step: 0.01)
                }
            }

        case .surface(let surface):
            Section("Ekran") {
                Picker("Ekran", selection: Binding(
                    get: { surface },
                    set: { condition = .surface($0) }
                )) {
                    ForEach(Surface.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

        case .flag(let name, let equals):
            Section("Bayrak") {
                TextField("Bayrak adı", text: Binding(
                    get: { name },
                    set: { condition = .flag(name: $0, equals: equals) }
                ))
                Toggle("Açık olmalı", isOn: Binding(
                    get: { equals },
                    set: { condition = .flag(name: name, equals: $0) }
                ))
            }

        case .mode(let name):
            Section("Mod") {
                TextField("Mod adı", text: Binding(
                    get: { name },
                    set: { condition = .mode($0) }
                ))
            }

        case .timeOfDay(let start, let end):
            Section("Saat aralığı") {
                TimeStepper(title: "Başlangıç", minute: Binding(
                    get: { start },
                    set: { condition = .timeOfDay(startMinute: $0, endMinute: end) }
                ))
                TimeStepper(title: "Bitiş", minute: Binding(
                    get: { end },
                    set: { condition = .timeOfDay(startMinute: start, endMinute: $0) }
                ))
                Text("Başlangıç bitişten büyükse aralık gece yarısını aşar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .not(let child):
            Section("DEĞİL") {
                NavigationLink {
                    ConditionEditorView(condition: Binding(
                        get: { child },
                        set: { condition = .not($0) }
                    ))
                } label: {
                    Text(child.displayName)
                }
            }

        case .all(let children), .any(let children):
            Section(condition.isAnyGroup ? "Herhangi biri (VEYA)" : "Tümü (VE)") {
                ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                    NavigationLink {
                        ConditionEditorView(condition: Binding(
                            get: { children.indices.contains(index) ? children[index] : .always },
                            set: { updated in
                                var copy = children
                                guard copy.indices.contains(index) else { return }
                                copy[index] = updated
                                condition = condition.isAnyGroup ? .any(copy) : .all(copy)
                            }
                        ))
                    } label: {
                        Text(child.displayName)
                    }
                }
                .onDelete { offsets in
                    var copy = children
                    copy.remove(atOffsets: offsets)
                    condition = condition.isAnyGroup ? .any(copy) : .all(copy)
                }

                Button("Alt koşul ekle") {
                    var copy = children
                    copy.append(.signal(.jawOpen, .greaterThan, 0.5))
                    condition = condition.isAnyGroup ? .any(copy) : .all(copy)
                }
            }
        }
    }
}

private struct TimeStepper: View {
    let title: String
    @Binding var minute: Int

    var body: some View {
        Stepper(value: $minute, in: 0...(24 * 60 - 15), step: 15) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%02d:%02d", minute / 60, minute % 60))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Flattened tag for the type picker.
private enum ConditionKind: CaseIterable {
    case always, signal, surface, flag, mode, timeOfDay, all, any, not

    init(_ condition: Condition) {
        switch condition {
        case .always: self = .always
        case .signal: self = .signal
        case .surface: self = .surface
        case .flag: self = .flag
        case .mode: self = .mode
        case .timeOfDay: self = .timeOfDay
        case .all: self = .all
        case .any: self = .any
        case .not: self = .not
        }
    }

    var displayName: String {
        switch self {
        case .always: return "Her zaman"
        case .signal: return "Sinyal karşılaştırması"
        case .surface: return "Ekran"
        case .flag: return "Bayrak"
        case .mode: return "Mod"
        case .timeOfDay: return "Saat aralığı"
        case .all: return "Tümü (VE)"
        case .any: return "Herhangi biri (VEYA)"
        case .not: return "DEĞİL"
        }
    }

    /// Builds a default node of this kind, reusing the previous node as a child
    /// where that makes sense so switching to a group does not discard work.
    func makeDefault(from previous: Condition) -> Condition {
        switch self {
        case .always: return .always
        case .signal: return .signal(.jawOpen, .greaterThan, 0.5)
        case .surface: return .surface(.reels)
        case .flag: return .flag(name: "gezinme", equals: true)
        case .mode: return .mode("varsayilan")
        case .timeOfDay: return .timeOfDay(startMinute: 22 * 60, endMinute: 7 * 60)
        case .all: return .all(previous.isGroup ? previous.children : [previous])
        case .any: return .any(previous.isGroup ? previous.children : [previous])
        case .not: return .not(previous.isGroup ? .always : previous)
        }
    }
}

private extension Condition {
    var isAnyGroup: Bool {
        if case .any = self { return true }
        return false
    }
}
#endif
