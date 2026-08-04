import XCTest
@testable import InstakaiCore

final class RuleGeneratorTests: XCTestCase {

    func testSensitivityMovesThresholdInBothDirections() {
        let base = RuleBlueprint(name: "x", gesture: .tongueDown, sensitivity: .medium, actions: [.like])
        var low = base; low.sensitivity = .low
        var high = base; high.sensitivity = .high

        let lowTrigger = RuleGenerator.makeTrigger(for: low)
        let mediumTrigger = RuleGenerator.makeTrigger(for: base)
        let highTrigger = RuleGenerator.makeTrigger(for: high)

        XCTAssertGreaterThan(lowTrigger.threshold, mediumTrigger.threshold)
        XCTAssertLessThan(highTrigger.threshold, mediumTrigger.threshold)
    }

    func testReleaseThresholdAlwaysStaysBelowThreshold() {
        // Hysteresis inverting would make a gesture impossible to release.
        for gesture in GesturePreset.allCases {
            for sensitivity in Sensitivity.allCases {
                let blueprint = RuleBlueprint(name: "x", gesture: gesture,
                                              sensitivity: sensitivity, actions: [.like])
                let trigger = RuleGenerator.makeTrigger(for: blueprint)
                XCTAssertLessThan(trigger.releaseThreshold, trigger.threshold,
                                  "\(gesture)/\(sensitivity) hysteresis ters dönmüş")
                XCTAssertGreaterThan(trigger.releaseThreshold, 0)
            }
        }
    }

    func testSurfaceAndExtraConditionsAreCombinedWithAnd() {
        let blueprint = RuleBlueprint(name: "x",
                                      gesture: .tongueDown,
                                      surface: .reels,
                                      extraConditions: [.flag(name: "gezinme", equals: true)],
                                      actions: [.like])
        guard case .all(let clauses) = RuleGenerator.makeCondition(for: blueprint) else {
            return XCTFail("Beklenen: .all")
        }
        XCTAssertEqual(clauses.count, 2)
    }

    func testNoConditionsProducesAlways() {
        let blueprint = RuleBlueprint(name: "x", gesture: .tongueDown, actions: [.like])
        XCTAssertEqual(RuleGenerator.makeCondition(for: blueprint), .always)
    }

    func testCompiledRuleKeepsBlueprintIdentity() {
        let blueprint = RuleBlueprint(name: "x", gesture: .tongueDown, actions: [.like])
        XCTAssertEqual(RuleGenerator.makeRule(from: blueprint).id, blueprint.id)
    }

    func testValidationFlagsMissingMacroAndEmptyActions() {
        let blueprints = [
            RuleBlueprint(name: "Boş", gesture: .tongueDown, actions: []),
            RuleBlueprint(name: "Kayıp makro", gesture: .tongueUp, actions: [.runMacro(id: "yok")])
        ]
        let warnings = RuleGenerator.validate(blueprints: blueprints, macros: [])
        XCTAssertTrue(warnings.contains { $0.message.contains("hiç eylemi yok") })
        XCTAssertTrue(warnings.contains { $0.message.contains("eksik makroya") })
    }

    func testValidationFlagsConflictingGestures() {
        let blueprints = [
            RuleBlueprint(name: "A", gesture: .tongueDown, surface: .reels, actions: [.like]),
            RuleBlueprint(name: "B", gesture: .tongueDown, surface: .reels, actions: [.savePost])
        ]
        let warnings = RuleGenerator.validate(blueprints: blueprints, macros: [])
        XCTAssertTrue(warnings.contains { $0.message.contains("aynı hareketi aynı ekranda") })
    }
}

final class MacroExpanderTests: XCTestCase {

    func testNestedMacrosFlattenWithAccumulatedOffsets() throws {
        let inner = Macro(id: "inner", name: "inner",
                          actions: [.like, .delay(seconds: 0.2), .savePost])
        let outer = Macro(id: "outer", name: "outer",
                          actions: [.delay(seconds: 0.5), .runMacro(id: "inner"), .playPause])
        let index = [inner.id: inner, outer.id: outer]

        let schedule = try MacroExpander.expand([.runMacro(id: "outer")], macros: index)
        XCTAssertEqual(schedule.map(\.offset), [0.5, 0.7, 0.7])
        XCTAssertEqual(schedule.map(\.action), [.like, .savePost, .playPause])
    }

    func testDirectRecursionIsRejected() {
        let macro = Macro(id: "loop", name: "loop", actions: [.runMacro(id: "loop")])
        XCTAssertThrowsError(try MacroExpander.expand([.runMacro(id: "loop")],
                                                      macros: [macro.id: macro]))
    }

    func testMutualRecursionIsRejected() {
        let a = Macro(id: "a", name: "a", actions: [.runMacro(id: "b")])
        let b = Macro(id: "b", name: "b", actions: [.runMacro(id: "a")])
        XCTAssertThrowsError(try MacroExpander.expand([.runMacro(id: "a")],
                                                      macros: ["a": a, "b": b]))
    }

    func testUnknownMacroIsRejected() {
        XCTAssertThrowsError(try MacroExpander.expand([.runMacro(id: "yok")], macros: [:]))
    }
}

final class SignalProcessorTests: XCTestCase {

    func testDirectionalTongueSignalsAreGatedByProtrusion() {
        let processor = SignalProcessor(tuning: SignalTuning(smoothing: 1.0, deadzone: 0,
                                                             tongueGate: 0.3, confidenceGate: 0.3))
        // Direction is confident, but the tongue is not actually out.
        let closed = SignalFrame(timestamp: 0, values: [
            .faceVisible: 1, .tongueOut: 0.05, .tongueDown: 0.9, .tongueConfidence: 0.9
        ])
        XCTAssertEqual(processor.process(closed)[.tongueDown], 0)

        let open = SignalFrame(timestamp: 1, values: [
            .faceVisible: 1, .tongueOut: 0.8, .tongueDown: 0.9, .tongueConfidence: 0.9
        ])
        XCTAssertGreaterThan(processor.process(open)[.tongueDown], 0.8)
    }

    func testLowConfidenceSuppressesDirection() {
        let processor = SignalProcessor(tuning: SignalTuning(smoothing: 1.0, deadzone: 0,
                                                             tongueGate: 0.3, confidenceGate: 0.5))
        let frame = SignalFrame(timestamp: 0, values: [
            .faceVisible: 1, .tongueOut: 0.9, .tongueDown: 0.9, .tongueConfidence: 0.2
        ])
        XCTAssertEqual(processor.process(frame)[.tongueDown], 0)
    }

    func testCalibrationRescalesRawValues() {
        let processor = SignalProcessor(
            tuning: SignalTuning(smoothing: 1.0, deadzone: 0, tongueGate: 0, confidenceGate: 0),
            calibration: [.jawOpen: CalibrationRange(neutral: 0.2, maximum: 0.6)])
        let frame = SignalFrame(timestamp: 0, values: [.faceVisible: 1, .jawOpen: 0.4])
        // Halfway between the user's neutral and their maximum.
        XCTAssertEqual(processor.process(frame)[.jawOpen], 0.5, accuracy: 0.01)
    }

    func testLosingFaceClearsSmoothingHistory() {
        let processor = SignalProcessor(tuning: SignalTuning(smoothing: 0.5, deadzone: 0,
                                                             tongueGate: 0, confidenceGate: 0))
        _ = processor.process(SignalFrame(timestamp: 0, values: [.faceVisible: 1, .jawOpen: 1.0]))
        _ = processor.process(SignalFrame.lost(at: 0.1))
        // Without a reset the smoothed value would still be carrying ~0.5.
        let next = processor.process(SignalFrame(timestamp: 0.2, values: [.faceVisible: 1, .jawOpen: 0.0]))
        XCTAssertEqual(next[.jawOpen], 0, accuracy: 0.0001)
    }
}

final class ProfileSerialisationTests: XCTestCase {

    func testPresetProfilesRoundTripThroughJSON() throws {
        for profile in PresetLibrary.all {
            let data = try ProfileStore.encode(profile)
            let decoded = try ProfileStore.decode(data)
            XCTAssertEqual(decoded, profile, "\(profile.name) JSON turunda değişti")
        }
    }

    func testPresetProfilesCompileWithoutWarnings() {
        for profile in PresetLibrary.all {
            XCTAssertTrue(profile.warnings.isEmpty,
                          "\(profile.name): \(profile.warnings.map(\.message))")
        }
    }

    func testEveryPresetRuleCompilesToARule() {
        for profile in PresetLibrary.all {
            XCTAssertEqual(profile.compiledRules.count, profile.blueprints.count)
        }
    }

    func testConditionTreeRoundTrips() throws {
        let condition = Condition.all([
            .surface(.reels),
            .not(.flag(name: "gezinme", equals: true)),
            .any([.signal(.jawOpen, .greaterThan, 0.4), .timeOfDay(startMinute: 1320, endMinute: 420)])
        ])
        let data = try JSONEncoder().encode(condition)
        XCTAssertEqual(try JSONDecoder().decode(Condition.self, from: data), condition)
    }

    func testEveryMacroActionRoundTrips() throws {
        let actions: [MacroAction] = [
            .scroll(direction: .down, amount: .screens(1.0), animated: true),
            .scroll(direction: .up, amount: .pixels(320), animated: false),
            .tap(.likeButton), .like, .unlike, .doubleTapLike, .savePost,
            .openComments, .closeOverlay, .navigate(.reels), .toggleMute,
            .playPause, .delay(seconds: 0.25), .haptic(.success), .speak("merhaba"),
            .runMacro(id: "scroll-next"), .setFlag(name: "gezinme", value: true),
            .toggleFlag(name: "gezinme"), .javascript("window.scrollBy(0, 100)")
        ]
        let data = try JSONEncoder().encode(actions)
        XCTAssertEqual(try JSONDecoder().decode([MacroAction].self, from: data), actions)
    }

    func testTimeOfDayWrapsAroundMidnight() {
        let overnight = Condition.timeOfDay(startMinute: 22 * 60, endMinute: 7 * 60)
        let frame = SignalFrame(timestamp: 0, values: [.faceVisible: 1])

        XCTAssertTrue(overnight.evaluate(frame: frame,
                                         context: EvaluationContext(minuteOfDay: 23 * 60)))
        XCTAssertTrue(overnight.evaluate(frame: frame,
                                         context: EvaluationContext(minuteOfDay: 3 * 60)))
        XCTAssertFalse(overnight.evaluate(frame: frame,
                                          context: EvaluationContext(minuteOfDay: 12 * 60)))
    }
}
