import Foundation

/// Tracks the live state of one `GestureTrigger` across frames.
///
/// The state machine is the piece that turns a continuous, noisy signal into
/// discrete gesture events. It owns four concerns that are easy to get wrong if
/// they are scattered across the engine:
///
/// 1. **Hysteresis** — separate rise/fall thresholds.
/// 2. **Hold** — the signal must stay active for `minimumHold` before counting,
///    and (optionally) be released before `maximumHold`.
/// 3. **Repeats** — N gestures inside `repeatWindow` for double/triple taps.
/// 4. **Fire mode** — edge, auto-repeat while held, or fire-on-release.
public final class TriggerStateMachine {

    /// Where the machine currently is.
    public enum Phase: String, Sendable {
        /// Signal below the release threshold.
        case idle
        /// Signal above threshold but `minimumHold` not yet elapsed.
        case arming
        /// Hold satisfied; the gesture is considered active.
        case active
        /// Held past `maximumHold`, so this repetition can no longer count.
        case expired
    }

    public private(set) var phase: Phase = .idle

    /// Timestamp the signal first crossed the threshold in the current cycle.
    private var risingEdge: TimeInterval?
    /// Timestamp of the last emitted fire, used for `.repeating`.
    private var lastFire: TimeInterval?
    /// Completed repetitions and when the streak started.
    private var repetitions: Int = 0
    private var streakStart: TimeInterval?
    /// True once the current activation has produced its edge fire.
    private var didFireThisActivation = false

    public init() {}

    public func reset() {
        phase = .idle
        risingEdge = nil
        lastFire = nil
        repetitions = 0
        streakStart = nil
        didFireThisActivation = false
    }

    /// Feeds one frame in and reports whether the trigger fired.
    ///
    /// - Returns: `true` on the frames where the gesture should produce actions.
    public func update(trigger: GestureTrigger, frame: SignalFrame) -> Bool {
        let now = frame.timestamp
        let value = frame[trigger.signal]

        // Losing the face aborts anything in flight rather than leaving a
        // gesture stuck "held" forever.
        guard frame.hasFace else {
            reset()
            return false
        }

        expireStaleStreak(now: now, window: trigger.repeatWindow)

        let isAbove = value >= trigger.threshold
        let isBelow = value <= trigger.releaseThreshold

        switch phase {
        case .idle:
            guard isAbove else { return false }
            phase = .arming
            risingEdge = now
            didFireThisActivation = false
            // Fall through to the arming check in the same frame, so a trigger
            // with no hold requirement fires on the frame it crosses.
            return evaluateArming(trigger: trigger, now: now, isBelow: isBelow)

        case .arming:
            return evaluateArming(trigger: trigger, now: now, isBelow: isBelow)

        case .active:
            if isBelow {
                let held = risingEdge.map { now - $0 } ?? 0
                phase = .idle
                risingEdge = nil
                return handleRelease(trigger: trigger, now: now, held: held)
            }
            if let maximum = trigger.maximumHold,
               let start = risingEdge,
               now - start > maximum {
                // Held too long for a "tap" style trigger.
                phase = .expired
                return false
            }
            return handleRepeat(trigger: trigger, now: now)

        case .expired:
            if isBelow {
                phase = .idle
                risingEdge = nil
                didFireThisActivation = false
            }
            return false
        }
    }

    // MARK: - Phase helpers

    /// Shared arming logic: bail if released early, wait for `minimumHold`,
    /// otherwise promote to `.active` and let the fire mode decide.
    private func evaluateArming(trigger: GestureTrigger,
                                now: TimeInterval,
                                isBelow: Bool) -> Bool {
        if isBelow {
            // Released before the hold completed: not a gesture.
            phase = .idle
            risingEdge = nil
            return false
        }
        guard let start = risingEdge, now - start >= trigger.minimumHold else {
            return false
        }
        phase = .active
        return activate(trigger: trigger, now: now)
    }

    /// Called the moment the hold requirement is met.
    private func activate(trigger: GestureTrigger, now: TimeInterval) -> Bool {
        switch trigger.fireMode {
        case .release:
            // Nothing to emit yet; wait for the falling edge.
            return false
        case .edge, .repeating:
            return countRepetitionAndMaybeFire(trigger: trigger, now: now)
        }
    }

    private func handleRelease(trigger: GestureTrigger, now: TimeInterval, held: TimeInterval) -> Bool {
        guard case .release = trigger.fireMode else {
            didFireThisActivation = false
            return false
        }
        if let maximum = trigger.maximumHold, held > maximum { return false }
        guard held >= trigger.minimumHold else { return false }
        return countRepetitionAndMaybeFire(trigger: trigger, now: now)
    }

    private func handleRepeat(trigger: GestureTrigger, now: TimeInterval) -> Bool {
        guard case .repeating(let interval) = trigger.fireMode else { return false }
        guard didFireThisActivation else { return false }
        guard let last = lastFire, now - last >= max(interval, 0.03) else { return false }
        lastFire = now
        return true
    }

    /// Records one repetition and fires once `repeatCount` is reached.
    private func countRepetitionAndMaybeFire(trigger: GestureTrigger, now: TimeInterval) -> Bool {
        if streakStart == nil { streakStart = now }
        repetitions += 1

        guard repetitions >= trigger.repeatCount else { return false }

        repetitions = 0
        streakStart = nil
        lastFire = now
        didFireThisActivation = true
        return true
    }

    /// Drops a partial repeat streak once its window has passed.
    private func expireStaleStreak(now: TimeInterval, window: TimeInterval) {
        guard let start = streakStart, now - start > window else { return }
        repetitions = 0
        streakStart = nil
    }
}
