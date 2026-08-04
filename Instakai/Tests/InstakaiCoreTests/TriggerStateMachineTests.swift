import XCTest
@testable import InstakaiCore

/// Builds a frame with a face present and one signal set.
private func frame(_ signal: Signal, _ value: Double, at time: TimeInterval) -> SignalFrame {
    SignalFrame(timestamp: time, values: [.faceVisible: 1, signal: value])
}

final class TriggerStateMachineTests: XCTestCase {

    func testDoesNotFireBeforeMinimumHold() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueDown, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.2)

        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.8, at: 0.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.8, at: 0.1)))
        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.8, at: 0.25)))
    }

    func testHysteresisPreventsRetriggerWithoutRelease() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueDown, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.0)

        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.6, at: 0.0)))
        // Dips between release and threshold: still "held", must not re-fire.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.4, at: 0.1)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.6, at: 0.2)))
        // Full release, then a new gesture.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.1, at: 0.3)))
        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.6, at: 0.4)))
    }

    func testRepeatingModeFiresOnInterval() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueDown, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.0,
                                     fireMode: .repeating(interval: 0.5))

        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.3)))
        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.55)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.8)))
        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 1.1)))
    }

    func testDoubleGestureRequiresTwoRepetitionsInWindow() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueOut, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.0,
                                     maximumHold: 0.4, repeatCount: 2,
                                     repeatWindow: 1.0, fireMode: .release)

        // First tap: press + release, no fire yet.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 0.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.1, at: 0.15)))
        // Second tap inside the window: fires on release.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 0.35)))
        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.1, at: 0.5)))
    }

    func testStaleRepeatStreakExpires() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueOut, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.0,
                                     maximumHold: 0.4, repeatCount: 2,
                                     repeatWindow: 0.5, fireMode: .release)

        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 0.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.1, at: 0.1)))
        // Second tap arrives after the window: counts as a new first tap.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 2.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.1, at: 2.1)))
    }

    func testMaximumHoldRejectsLongPress() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueOut, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.05,
                                     maximumHold: 0.3, fireMode: .release)

        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 0.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 0.1)))
        // Past the max hold, the activation expires.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.8, at: 0.5)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueOut, 0.1, at: 0.6)))
    }

    func testLosingFaceResetsGesture() {
        let machine = TriggerStateMachine()
        let trigger = GestureTrigger(signal: .tongueDown, threshold: 0.5,
                                     releaseThreshold: 0.3, minimumHold: 0.2)

        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.0)))
        XCTAssertFalse(machine.update(trigger: trigger, frame: SignalFrame.lost(at: 0.1)))
        XCTAssertEqual(machine.phase, .idle)
        // The hold clock restarts rather than completing from the pre-loss frame.
        XCTAssertFalse(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.25)))
        XCTAssertTrue(machine.update(trigger: trigger, frame: frame(.tongueDown, 0.9, at: 0.5)))
    }
}
