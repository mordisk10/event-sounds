import SwiftUI

/// A tile shown in the panoramic slider.
struct HomeWidget: Identifiable {
    let id = UUID()
    let icon: String
    let titleKey: S
    let value: String
    let captionKey: S
    let tint: Color
}

/// The home screen: session state, the microphone, the quiet chat entry point,
/// and a panoramic row of stat widgets.
struct HomeView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var island: IslandCenter

    @AppStorage("app.micMode") private var storedMicMode = MicMode.pushToTalk.rawValue

    @State private var micMode: MicMode = .pushToTalk
    @State private var isListening = false
    @State private var isSessionOn = false
    @State private var showsChat = false
    @State private var focusedWidget = 0

    private var widgets: [HomeWidget] {
        [
            HomeWidget(icon: "arrow.down.circle.fill", titleKey: .widgetScrollTitle,
                       value: "128", captionKey: .widgetScrollBody, tint: Theme.Palette.accent),
            HomeWidget(icon: "heart.fill", titleKey: .widgetLikeTitle,
                       value: "12", captionKey: .widgetLikeBody, tint: Theme.Palette.danger),
            HomeWidget(icon: "waveform", titleKey: .widgetVoiceTitle,
                       value: "9", captionKey: .widgetVoiceBody, tint: Theme.Palette.success),
            HomeWidget(icon: "flame.fill", titleKey: .widgetStreakTitle,
                       value: "4", captionKey: .widgetStreakBody, tint: Theme.Palette.warning)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                greeting
                sessionCard
                micSection
                widgetSection
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Palette.background)
        .sheet(isPresented: $showsChat) { ChatView() }
        .onAppear { micMode = MicMode(rawValue: storedMicMode) ?? .pushToTalk }
        .onChange(of: micMode) { _, new in storedMicMode = new.rawValue }
    }

    // MARK: - Sections

    /// First name only — a full name pushes the greeting onto two lines.
    private var firstName: String {
        guard let name = auth.account?.name,
              let first = name.split(separator: " ").first else { return "" }
        return String(first)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(lang.t(.homeGreeting)), \(firstName)")
                .font(.iaTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(lang.t(.homeSubtitle))
                .font(.iaBody)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, Theme.Spacing.s)
    }

    private var sessionCard: some View {
        Card(padding: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                ZStack {
                    Circle()
                        .fill(isSessionOn ? Theme.Palette.success.opacity(0.15)
                                          : Theme.Palette.surfaceSunken)
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(isSessionOn ? Theme.Palette.success : Theme.Palette.textTertiary)
                        .frame(width: 10, height: 10)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(lang.t(isSessionOn ? .homeSessionOn : .homeSessionOff))
                        .font(.iaCardTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(auth.account?.plan.name(lang) ?? "")
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation(Theme.Motion.standard) { isSessionOn.toggle() }
                    Haptics.impact(.medium)
                    if isSessionOn {
                        island.post(IslandEvent(kind: .gesture("start"),
                                                title: lang.t(.homeSessionOn),
                                                detail: nil))
                    } else {
                        island.clear()
                    }
                } label: {
                    Text(lang.t(isSessionOn ? .homeStopSession : .homeStartSession))
                        .font(.iaMicro)
                        .foregroundStyle(isSessionOn ? Theme.Palette.danger : .white)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.s)
                        .background {
                            if isSessionOn {
                                Capsule().fill(Theme.Palette.danger.opacity(0.12))
                            } else {
                                Capsule().fill(Theme.Palette.accent)
                            }
                        }
                }
                .buttonStyle(.pushSubtle)
            }
        }
        .padding(.horizontal, Theme.Spacing.screen)
    }

    private var micSection: some View {
        VStack(spacing: Theme.Spacing.m) {
            MicButton(mode: $micMode, isListening: $isListening) {
                island.post(IslandEvent(kind: .listening,
                                        title: lang.t(.islandListening),
                                        detail: lang.t(micMode.label)))
            } onStop: {
                island.clear()
                // Stand-in for a recognised command. Every fifth one is treated
                // as a milestone so the celebration path is exercised.
                bumpDemoCounter()
            }

            Text(lang.t(isListening ? .homeMicListening
                                    : (micMode == .pushToTalk ? .homeMicIdlePush : .homeMicIdleHold)))
                .font(.iaCaption)
                .foregroundStyle(isListening ? Theme.Palette.accent : Theme.Palette.textSecondary)
                .animation(Theme.Motion.standard, value: isListening)

            ChatHint { showsChat = true }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.screen)
    }

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(lang.t(.homeWidgetsTitle), subtitle: lang.t(.homeWidgetsSubtitle))
                .padding(.horizontal, Theme.Spacing.screen)

            PanoramaSlider(items: widgets, focusedIndex: $focusedWidget) { widget in
                PanoramaCard(icon: widget.icon,
                             title: lang.t(widget.titleKey),
                             value: widget.value,
                             caption: lang.t(widget.captionKey),
                             tint: widget.tint)
            }

            PanoramaIndicator(count: widgets.count, focused: focusedWidget)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Demo feedback

    @AppStorage("demo.gestureCount") private var demoCount = 0

    private func bumpDemoCounter() {
        demoCount += 1
        if demoCount % 5 == 0 {
            island.post(IslandEvent(kind: .milestone(streak: demoCount / 5),
                                    title: lang.t(.islandStreak),
                                    detail: "\(demoCount)"))
        } else {
            island.post(IslandEvent(kind: .gesture("scroll"),
                                    title: lang.t(.islandScrolled),
                                    detail: "\(demoCount)"))
        }
    }
}
