import SwiftUI

/// One piece of feedback surfaced at the top of the screen.
struct IslandEvent: Identifiable, Equatable {
    enum Kind: Equatable {
        case gesture(String)
        case listening
        case milestone(streak: Int)

        var icon: String {
            switch self {
            case .gesture: return "arrow.down.circle.fill"
            case .listening: return "waveform"
            case .milestone: return "flame.fill"
            }
        }

        /// Milestones get the particle burst; routine feedback does not, or the
        /// celebration stops meaning anything.
        var celebrates: Bool {
            if case .milestone = self { return true }
            return false
        }
    }

    let id = UUID()
    var kind: Kind
    var title: String
    var detail: String?
}

/// Drives the top-of-screen feedback and, on a real device, the Live Activity.
///
/// In-app the pill is drawn by `IslandFeedbackOverlay`, anchored under the
/// physical Dynamic Island so the animation reads as the island itself
/// expanding. When the app is backgrounded the same events go to the Live
/// Activity in `Widget/`, which is what puts them in the real island.
@MainActor
final class IslandCenter: ObservableObject {

    @Published private(set) var current: IslandEvent?
    @Published private(set) var celebrationTrigger = 0

    /// Mirrors the Settings switches.
    var isEnabled = true
    var celebrationsEnabled = true

    private var dismissTask: Task<Void, Never>?

    /// Shows an event, replacing whatever is on screen.
    func post(_ event: IslandEvent, duration: TimeInterval = 1.8) {
        guard isEnabled else { return }

        dismissTask?.cancel()
        withAnimation(Theme.Motion.showcase) {
            current = event
        }

        if event.kind.celebrates && celebrationsEnabled {
            celebrationTrigger += 1
            Haptics.success()
        } else {
            Haptics.impact(.light)
        }

        // `.listening` stays until explicitly cleared — it reflects a state,
        // not a moment.
        guard event.kind != .listening else { return }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.clear()
        }
    }

    func clear() {
        dismissTask?.cancel()
        withAnimation(Theme.Motion.showcase) {
            current = nil
        }
    }
}

/// The pill that grows out of the Dynamic Island area.
///
/// Placed at the very top of the root view as an overlay so it floats over
/// every tab without any screen needing to know it exists.
struct IslandFeedbackOverlay: View {
    @ObservedObject var center: IslandCenter

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if let event = center.current {
                    pill(for: event)
                        .transition(.asymmetric(
                            // Grows downward out of the island and shrinks back
                            // into it, rather than sliding in from off-screen.
                            insertion: .scale(scale: 0.3, anchor: .top)
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.4, anchor: .top)
                                .combined(with: .opacity)
                        ))
                }

                CelebrationBurst(trigger: center.celebrationTrigger)
                    .allowsHitTesting(false)
            }
            Spacer()
        }
        .padding(.top, 4)
        .animation(Theme.Motion.showcase, value: center.current)
    }

    private func pill(for event: IslandEvent) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: event.kind.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Palette.accent)
                .symbolEffect(.bounce, value: event.id)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let detail = event.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            if case .listening = event.kind {
                ListeningBars()
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s + 2)
        // Black so it reads as a continuation of the island cutout.
        .background(Color.black, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
}

/// Three bars that rise and fall while the mic is open.
private struct ListeningBars: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Theme.Palette.accent)
                    .frame(width: 2.5, height: height(for: index))
            }
        }
        .frame(height: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let base: [CGFloat] = [6, 12, 8]
        let peak: [CGFloat] = [12, 5, 13]
        return base[index] + (peak[index] - base[index]) * phase
    }
}

/// The celebration: small accent-coloured shards thrown outward and downward
/// from the island, then falling away.
///
/// Deliberately not classic multi-colour paper confetti — it stays inside the
/// app's orange family so a milestone still looks like Instakai.
struct CelebrationBurst: View {
    let trigger: Int

    private struct Shard: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: Color
        let spin: Double
        let delay: Double
    }

    @State private var shards: [Shard] = []
    @State private var isFlying = false

    var body: some View {
        ZStack {
            ForEach(shards) { shard in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(shard.color)
                    .frame(width: shard.size, height: shard.size * 1.8)
                    .rotationEffect(.degrees(isFlying ? shard.spin : 0))
                    .offset(
                        x: isFlying ? cos(shard.angle) * shard.distance : 0,
                        y: isFlying ? sin(shard.angle) * shard.distance + 60 : 0
                    )
                    .opacity(isFlying ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.9).delay(shard.delay),
                        value: isFlying
                    )
            }
        }
        .frame(height: 1)
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            fire()
        }
    }

    private func fire() {
        shards = (0..<18).map { _ in
            Shard(
                // Biased towards the lower half so shards spray out and down,
                // matching where gravity would take them.
                angle: Double.random(in: -0.35...(.pi + 0.35)),
                distance: CGFloat.random(in: 60...150),
                size: CGFloat.random(in: 4...7),
                color: Theme.Palette.celebration.randomElement() ?? Theme.Palette.accent,
                spin: Double.random(in: -320...320),
                delay: Double.random(in: 0...0.08)
            )
        }
        isFlying = false
        // One frame at rest so the animation has a starting state to leave.
        DispatchQueue.main.async {
            isFlying = true
        }
    }
}
