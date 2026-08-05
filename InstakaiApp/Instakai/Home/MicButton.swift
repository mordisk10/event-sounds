import SwiftUI

/// How the microphone is operated.
enum MicMode: String, CaseIterable, Identifiable, Codable {
    /// Listens only while the finger stays down.
    case pushToTalk
    /// One tap opens the mic, a second closes it.
    case stayPut

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pushToTalk: return "hand.tap.fill"
        case .stayPut: return "pin.fill"
        }
    }

    var label: S {
        switch self {
        case .pushToTalk: return .homeModePushToTalk
        case .stayPut: return .homeModeStayPut
        }
    }

    var hint: S {
        switch self {
        case .pushToTalk: return .homeModePushToTalkHint
        case .stayPut: return .homeModeStayPutHint
        }
    }
}

/// The primary control on the home screen: a large round microphone with the
/// mode selector to its right.
///
/// The two modes need genuinely different gestures, which is why this is not a
/// `Button`:
/// - **push-to-talk** needs press and release as separate events, so it uses a
///   zero-distance `DragGesture` (`onLongPressGesture` cannot report release
///   before its minimum duration elapses).
/// - **stay put** is a plain toggle on tap.
struct MicButton: View {
    @Binding var mode: MicMode
    @Binding var isListening: Bool
    @EnvironmentObject private var lang: LanguageManager

    /// Fired when a capture starts and ends, so the parent can drive the island.
    var onStart: () -> Void
    var onStop: () -> Void

    @State private var isPressed = false
    @State private var haloPhase: CGFloat = 0

    private let diameter: CGFloat = 116

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.l) {
            micCircle
            modeSelector
        }
    }

    // MARK: - The button itself

    private var micCircle: some View {
        ZStack {
            // Two halo rings that breathe while listening. They sit behind the
            // button and never intercept touches.
            if isListening {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(Theme.Palette.accent.opacity(0.35 - Double(index) * 0.15),
                                lineWidth: 2)
                        .frame(width: diameter, height: diameter)
                        .scaleEffect(1 + haloPhase * (0.28 + CGFloat(index) * 0.18))
                        .opacity(1 - haloPhase)
                }
            }

            Circle()
                .fill(LinearGradient(
                    colors: isListening
                        ? [Theme.Palette.accentDeep, Theme.Palette.accent]
                        : [Theme.Palette.accent, Theme.Palette.accentDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: diameter, height: diameter)
                .shadow(color: Theme.Palette.accent.opacity(isListening ? 0.5 : 0.3),
                        radius: isListening ? 28 : 18, y: 10)

            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .pushEffect(isPressed: isPressed, intensity: .pronounced)
        .contentShape(Circle())
        .gesture(gesture)
        .accessibilityLabel(lang.t(.homeMicAccessibility))
        .accessibilityValue(lang.t(mode.label))
        .accessibilityHint(lang.t(mode.hint))
        .accessibilityAddTraits(.isButton)
        .onChange(of: isListening) { _, listening in
            guard listening else {
                haloPhase = 0
                return
            }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                haloPhase = 1
            }
        }
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                if mode == .pushToTalk {
                    start()
                }
            }
            .onEnded { _ in
                isPressed = false
                switch mode {
                case .pushToTalk:
                    stop()
                case .stayPut:
                    isListening ? stop() : start()
                }
            }
    }

    private func start() {
        withAnimation(Theme.Motion.standard) { isListening = true }
        Haptics.impact(.heavy)
        onStart()
    }

    private func stop() {
        withAnimation(Theme.Motion.standard) { isListening = false }
        Haptics.impact(.light)
        onStop()
    }

    // MARK: - Mode selector, to the right of the button

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(MicMode.allCases) { candidate in
                Button {
                    guard candidate != mode else { return }
                    // Switching modes mid-capture would leave the mic open with
                    // no gesture able to close it.
                    if isListening { stop() }
                    withAnimation(Theme.Motion.standard) { mode = candidate }
                    Haptics.selection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: candidate.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(lang.t(candidate.label))
                            .font(.iaMicro)
                    }
                    .foregroundStyle(mode == candidate ? .white : Theme.Palette.textSecondary)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if mode == candidate {
                            Capsule().fill(Theme.Palette.accent)
                        } else {
                            Capsule().fill(Theme.Palette.surfaceSunken)
                        }
                    }
                }
                .buttonStyle(.pushSubtle)
            }

            Text(lang.t(mode.hint))
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
                .id(mode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Theme.Motion.standard, value: mode)
    }
}
