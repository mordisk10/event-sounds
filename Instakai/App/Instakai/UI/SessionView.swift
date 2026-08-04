#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI
import InstakaiCore

/// The main screen: Instagram on top, live gesture state and controls below.
struct SessionView: View {
    @EnvironmentObject private var session: SessionController
    @State private var showsInspector = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                surfaceArea
                controlBar
                if showsInspector {
                    SignalInspectorView()
                        .frame(maxHeight: 260)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Instakai")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TagChip(text: session.surface.currentSurface.displayName,
                            systemImage: "rectangle.on.rectangle",
                            tint: session.surface.isBridgeReady ? .green : .secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showsInspector.toggle() }
                    } label: {
                        Image(systemName: showsInspector ? "waveform.circle.fill" : "waveform.circle")
                    }
                    .accessibilityLabel("Sinyal göstergesi")
                }
            }
        }
    }

    // MARK: - Surface

    @ViewBuilder
    private var surfaceArea: some View {
        ZStack(alignment: .topTrailing) {
            InstagramSurfaceView(controller: session.surface)

            if session.isRunning {
                trackingBadge
                    .padding(12)
            }
        }
    }

    private var trackingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.frame.hasFace ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(session.frame.hasFace ? "Yüz izleniyor" : "Yüz görünmüyor")
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Controls

    private var controlBar: some View {
        VStack(spacing: 10) {
            if let message = trackingProblem {
                WarningRow(message: message)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button {
                    session.isRunning ? session.stop() : session.start()
                } label: {
                    Label(session.isRunning ? "Durdur" : "Başlat",
                          systemImage: session.isRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(session.isRunning ? .orange : .pink)

                Button(role: .destructive) {
                    session.panicStop()
                } label: {
                    Label("Acil dur", systemImage: "hand.raised.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!session.isRunning && !session.dispatcher.isArmed)
            }
            .padding(.horizontal)

            if session.profile.modes.count > 1 {
                Picker("Mod", selection: $session.mode) {
                    ForEach(session.profile.modes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            activityLog
        }
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var trackingProblem: String? {
        switch session.tracking.state {
        case .unsupported:
            return "Bu cihaz yüz takibini desteklemiyor. TrueDepth kameralı bir iPhone gerekiyor."
        case .permissionDenied:
            return "Kamera izni verilmedi. Ayarlar → Instakai → Kamera'dan açın."
        case .failed(let message):
            return "Takip hatası: \(message)"
        case .idle, .running:
            return session.storeError
        }
    }

    @ViewBuilder
    private var activityLog: some View {
        if let entry = session.dispatcher.log.first {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                Text(entry.ruleName).font(.caption.weight(.semibold))
                Text("→ \(entry.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal)
        }
    }
}

/// Live signal bars plus the flags each rule can read. This is the screen a user
/// opens when a gesture "does not work" — it shows immediately whether the
/// signal never reaches the threshold, or reaches it and gets gated elsewhere.
struct SignalInspectorView: View {
    @EnvironmentObject private var session: SessionController

    private let watched: [Signal] = [
        .tongueOut, .tongueDown, .tongueUp, .tongueLeft, .tongueRight,
        .tongueConfidence, .jawOpen, .browInnerUp, .cheekPuff
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(watched, id: \.self) { signal in
                    SignalMeter(signal: signal,
                                value: session.frame[signal],
                                threshold: threshold(for: signal))
                }

                if !session.flagSnapshot.isEmpty {
                    Divider()
                    Text("Bayraklar").font(.caption.weight(.semibold))
                    HStack {
                        ForEach(session.flagSnapshot.sorted(by: { $0.key < $1.key }), id: \.key) { name, value in
                            TagChip(text: "\(name): \(value ? "açık" : "kapalı")",
                                    tint: value ? .green : .secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }

    /// The lowest threshold any enabled rule uses for this signal — the point at
    /// which *something* starts happening.
    private func threshold(for signal: Signal) -> Double? {
        session.profile.compiledRules
            .filter { $0.isEnabled && $0.trigger.signal == signal }
            .map(\.trigger.threshold)
            .min()
    }
}
#endif
