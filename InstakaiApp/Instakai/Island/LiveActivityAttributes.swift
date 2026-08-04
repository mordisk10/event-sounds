import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shape of the Live Activity that puts Instakai in the real Dynamic Island.
///
/// Shared between the app (which starts and updates the activity) and the
/// widget extension (which renders it), so it lives in its own file with no
/// SwiftUI imports.
struct SessionActivityAttributes: Codable, Hashable {

    /// Set once when the activity starts.
    var profileName: String

    /// Everything that changes while the session runs.
    struct ContentState: Codable, Hashable {
        /// Label for the most recent recognised gesture, e.g. "Kaydırıldı".
        var lastGesture: String
        /// SF Symbol matching that gesture.
        var lastGestureIcon: String
        /// Gestures recognised in this session.
        var gestureCount: Int
        /// Consecutive-day streak, shown in the expanded view.
        var streak: Int
        /// True while the microphone is open.
        var isListening: Bool
        /// Set for one update when a milestone is hit, so the widget can show
        /// its celebratory variant.
        var isCelebrating: Bool
    }
}

#if canImport(ActivityKit)
extension SessionActivityAttributes: ActivityAttributes {}
#endif

/// Starts, updates and ends the Live Activity.
///
/// Every call is a no-op when Live Activities are unavailable — the simulator,
/// an unsupported device, or a user who turned them off — so callers never have
/// to guard.
@MainActor
final class LiveActivityController {

    #if canImport(ActivityKit)
    private var activity: Activity<SessionActivityAttributes>?
    #endif

    var isEnabled = true

    func start(profileName: String) {
        #if canImport(ActivityKit)
        guard isEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              activity == nil else { return }

        let initial = SessionActivityAttributes.ContentState(
            lastGesture: "—",
            lastGestureIcon: "face.smiling",
            gestureCount: 0,
            streak: 0,
            isListening: false,
            isCelebrating: false
        )

        activity = try? Activity.request(
            attributes: SessionActivityAttributes(profileName: profileName),
            content: .init(state: initial, staleDate: nil)
        )
        #endif
    }

    func update(_ state: SessionActivityAttributes.ContentState) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        #endif
    }

    func stop() {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }
}
