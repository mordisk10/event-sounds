import SwiftUI
import WidgetKit
import ActivityKit

/// Renders the session in the Dynamic Island and on the Lock Screen.
///
/// Four presentations are required and each has very different space:
/// - **minimal** — one glyph, when another activity shares the island.
/// - **compact leading/trailing** — the two slivers either side of the cutout.
/// - **expanded** — long press, the only place with room for detail.
/// - **Lock Screen banner** — a full-width card.
struct InstakaiLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            lockScreen(context.state, profile: context.attributes.profileName)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(accent)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.lastGestureIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accent)
                        .symbolEffect(.bounce, value: context.state.gestureCount)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(context.state.gestureCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("hareket")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.lastGesture)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        if context.state.streak > 0 {
                            Label("\(context.state.streak)", systemImage: "flame.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(accent)
                        }
                        Spacer()
                        if context.state.isListening {
                            Label("Dinliyor", systemImage: "waveform")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Text(context.attributes.profileName)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

            } compactLeading: {
                Image(systemName: context.state.isListening ? "waveform" : context.state.lastGestureIcon)
                    .foregroundStyle(accent)
                    .symbolEffect(.bounce, value: context.state.gestureCount)

            } compactTrailing: {
                // The celebration cue in the compact slot is a flame, not a
                // number: it has to read at a glance, at ~20pt wide.
                if context.state.isCelebrating {
                    Image(systemName: "flame.fill").foregroundStyle(accent)
                } else {
                    Text("\(context.state.gestureCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

            } minimal: {
                Image(systemName: "face.smiling")
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }

    private var accent: Color { Color(red: 1.0, green: 0.416, blue: 0.102) }

    private func lockScreen(_ state: SessionActivityAttributes.ContentState,
                            profile: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: state.lastGestureIcon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 46, height: 46)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14,
                                                                       style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.lastGesture)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(profile)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(state.gestureCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if state.streak > 0 {
                    Label("\(state.streak)", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(16)
    }
}

@main
struct InstakaiWidgetBundle: WidgetBundle {
    var body: some Widget {
        InstakaiLiveActivity()
    }
}
