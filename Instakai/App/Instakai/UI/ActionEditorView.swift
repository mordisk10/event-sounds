#if canImport(SwiftUI)
import SwiftUI
import InstakaiCore

/// Editor for one `MacroAction`.
struct ActionEditorView: View {
    @Binding var action: MacroAction
    let availableMacros: [Macro]

    var body: some View {
        Form {
            Section("Eylem türü") {
                Picker("Tür", selection: Binding(
                    get: { ActionKind(action) },
                    set: { action = $0.makeDefault() }
                )) {
                    ForEach(ActionKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }
            detailSection
        }
        .navigationTitle("Eylem")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var detailSection: some View {
        switch action {
        case .scroll(let direction, let amount, let animated):
            Section("Kaydırma") {
                Picker("Yön", selection: Binding(
                    get: { direction },
                    set: { action = .scroll(direction: $0, amount: amount, animated: animated) }
                )) {
                    Text("Aşağı").tag(ScrollDirection.down)
                    Text("Yukarı").tag(ScrollDirection.up)
                    Text("Sola").tag(ScrollDirection.left)
                    Text("Sağa").tag(ScrollDirection.right)
                }
                .pickerStyle(.segmented)

                ScrollAmountEditor(amount: Binding(
                    get: { amount },
                    set: { action = .scroll(direction: direction, amount: $0, animated: animated) }
                ))

                Toggle("Yumuşak kaydırma", isOn: Binding(
                    get: { animated },
                    set: { action = .scroll(direction: direction, amount: amount, animated: $0) }
                ))
            }

        case .tap(let target):
            Section("Hedef") {
                Picker("Hedef", selection: Binding(
                    get: { target },
                    set: { action = .tap($0) }
                )) {
                    ForEach(TapTarget.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

        case .navigate(let destination):
            Section("Hedef ekran") {
                Picker("Ekran", selection: Binding(
                    get: { destination },
                    set: { action = .navigate($0) }
                )) {
                    ForEach(Destination.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }

        case .delay(let seconds):
            Section("Bekleme") {
                VStack(alignment: .leading) {
                    Text("\(String(format: "%.2f", seconds)) saniye").font(.caption)
                    Slider(value: Binding(
                        get: { seconds },
                        set: { action = .delay(seconds: $0) }
                    ), in: 0.05...3, step: 0.05)
                }
            }

        case .haptic(let style):
            Section("Titreşim") {
                Picker("Stil", selection: Binding(
                    get: { style },
                    set: { action = .haptic($0) }
                )) {
                    ForEach(HapticStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }

        case .speak(let text):
            Section("Seslendirilecek metin") {
                TextField("Metin", text: Binding(
                    get: { text },
                    set: { action = .speak($0) }
                ))
            }

        case .runMacro(let id):
            Section("Makro") {
                Picker("Makro", selection: Binding(
                    get: { id },
                    set: { action = .runMacro(id: $0) }
                )) {
                    ForEach(availableMacros) { macro in
                        Text(macro.name).tag(macro.id)
                    }
                }
                if let macro = availableMacros.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(macro.actions.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

        case .setFlag(let name, let value):
            Section("Bayrak") {
                TextField("Ad", text: Binding(
                    get: { name },
                    set: { action = .setFlag(name: $0, value: value) }
                ))
                Toggle("Değer", isOn: Binding(
                    get: { value },
                    set: { action = .setFlag(name: name, value: $0) }
                ))
            }

        case .toggleFlag(let name):
            Section("Bayrak") {
                TextField("Ad", text: Binding(
                    get: { name },
                    set: { action = .toggleFlag(name: $0) }
                ))
            }

        case .javascript(let script):
            Section {
                TextField("JavaScript", text: Binding(
                    get: { script },
                    set: { action = .javascript($0) }
                ), axis: .vertical)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(3...10)
            } header: {
                Text("Ham JavaScript")
            } footer: {
                Text("Barındırılan Instagram sayfasında çalışır. Kaçış kapısı — " +
                     "arayüz değişirse ilk bozulacak yer burasıdır.")
            }

        case .like, .unlike, .doubleTapLike, .savePost, .openComments, .closeOverlay,
             .toggleMute, .playPause:
            Section {
                Text(action.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ScrollAmountEditor: View {
    @Binding var amount: ScrollAmount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Birim", selection: Binding(
                get: { isScreens },
                set: { useScreens in
                    amount = useScreens ? .screens(1) : .pixels(400)
                }
            )) {
                Text("Ekran").tag(true)
                Text("Piksel").tag(false)
            }
            .pickerStyle(.segmented)

            switch amount {
            case .screens(let value):
                Text("\(String(format: "%.2f", value)) ekran").font(.caption)
                Slider(value: Binding(
                    get: { value },
                    set: { amount = .screens($0) }
                ), in: 0.1...2, step: 0.05)
            case .pixels(let value):
                Text("\(Int(value)) px").font(.caption)
                Slider(value: Binding(
                    get: { value },
                    set: { amount = .pixels($0.rounded()) }
                ), in: 50...1500, step: 10)
            }
        }
    }

    private var isScreens: Bool {
        if case .screens = amount { return true }
        return false
    }
}

private enum ActionKind: CaseIterable {
    case scroll, tap, like, unlike, doubleTapLike, savePost, openComments
    case closeOverlay, navigate, toggleMute, playPause, delay, haptic
    case speak, runMacro, setFlag, toggleFlag, javascript

    init(_ action: MacroAction) {
        switch action {
        case .scroll: self = .scroll
        case .tap: self = .tap
        case .like: self = .like
        case .unlike: self = .unlike
        case .doubleTapLike: self = .doubleTapLike
        case .savePost: self = .savePost
        case .openComments: self = .openComments
        case .closeOverlay: self = .closeOverlay
        case .navigate: self = .navigate
        case .toggleMute: self = .toggleMute
        case .playPause: self = .playPause
        case .delay: self = .delay
        case .haptic: self = .haptic
        case .speak: self = .speak
        case .runMacro: self = .runMacro
        case .setFlag: self = .setFlag
        case .toggleFlag: self = .toggleFlag
        case .javascript: self = .javascript
        }
    }

    var displayName: String {
        switch self {
        case .scroll: return "Kaydır"
        case .tap: return "Dokun"
        case .like: return "Beğen"
        case .unlike: return "Beğeniyi geri al"
        case .doubleTapLike: return "Çift dokunup beğen"
        case .savePost: return "Kaydet"
        case .openComments: return "Yorumları aç"
        case .closeOverlay: return "Katmanı kapat"
        case .navigate: return "Ekrana git"
        case .toggleMute: return "Sesi aç/kapat"
        case .playPause: return "Oynat/duraklat"
        case .delay: return "Bekle"
        case .haptic: return "Titreşim"
        case .speak: return "Seslendir"
        case .runMacro: return "Makro çalıştır"
        case .setFlag: return "Bayrak ata"
        case .toggleFlag: return "Bayrak değiştir"
        case .javascript: return "JavaScript"
        }
    }

    func makeDefault() -> MacroAction {
        switch self {
        case .scroll: return .scroll(direction: .down, amount: .screens(1), animated: true)
        case .tap: return .tap(.likeButton)
        case .like: return .like
        case .unlike: return .unlike
        case .doubleTapLike: return .doubleTapLike
        case .savePost: return .savePost
        case .openComments: return .openComments
        case .closeOverlay: return .closeOverlay
        case .navigate: return .navigate(.reels)
        case .toggleMute: return .toggleMute
        case .playPause: return .playPause
        case .delay: return .delay(seconds: 0.3)
        case .haptic: return .haptic(.light)
        case .speak: return .speak("merhaba")
        case .runMacro: return .runMacro(id: "scroll-next")
        case .setFlag: return .setFlag(name: "gezinme", value: true)
        case .toggleFlag: return .toggleFlag(name: "gezinme")
        case .javascript: return .javascript("window.scrollBy(0, 400)")
        }
    }
}
#endif
