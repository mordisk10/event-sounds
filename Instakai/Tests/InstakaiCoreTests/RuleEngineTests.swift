import XCTest
@testable import InstakaiCore

private func frame(_ values: [Signal: Double], at time: TimeInterval) -> SignalFrame {
    var merged = values
    merged[.faceVisible] = 1
    return SignalFrame(timestamp: time, values: merged)
}

/// A trigger that fires the instant the signal crosses, so tests can focus on
/// engine behaviour rather than gesture timing.
private func instantTrigger(_ signal: Signal) -> GestureTrigger {
    GestureTrigger(signal: signal, threshold: 0.5, releaseThreshold: 0.3, minimumHold: 0)
}

final class RuleEngineTests: XCTestCase {

    func testConditionGatesFiring() {
        let rule = Rule(name: "Reels'te kaydır",
                        trigger: instantTrigger(.tongueDown),
                        condition: .surface(.reels),
                        actions: [.scroll(direction: .down, amount: .screens(1), animated: true)],
                        cooldown: 0)
        let engine = RuleEngine(rules: [rule], options: .init(globalCooldown: 0))

        let feed = EvaluationContext(surface: .feed)
        XCTAssertTrue(engine.update(frame: frame([.tongueDown: 0.9], at: 0), context: feed).isEmpty)

        // Release, then repeat the gesture on the correct surface.
        _ = engine.update(frame: frame([.tongueDown: 0.0], at: 0.1), context: feed)
        let reels = EvaluationContext(surface: .reels)
        XCTAssertEqual(engine.update(frame: frame([.tongueDown: 0.9], at: 0.2), context: reels).count, 1)
    }

    func testCooldownSuppressesRapidRefiring() {
        let rule = Rule(name: "Kaydır",
                        trigger: instantTrigger(.tongueDown),
                        actions: [.like],
                        cooldown: 1.0)
        let engine = RuleEngine(rules: [rule], options: .init(globalCooldown: 0))
        let context = EvaluationContext()

        XCTAssertEqual(engine.update(frame: frame([.tongueDown: 0.9], at: 0), context: context).count, 1)
        _ = engine.update(frame: frame([.tongueDown: 0.0], at: 0.1), context: context)
        // Inside the cooldown: gesture recognised, but suppressed.
        XCTAssertTrue(engine.update(frame: frame([.tongueDown: 0.9], at: 0.3), context: context).isEmpty)
        _ = engine.update(frame: frame([.tongueDown: 0.0], at: 0.4), context: context)
        XCTAssertEqual(engine.update(frame: frame([.tongueDown: 0.9], at: 1.5), context: context).count, 1)
    }

    func testExclusiveRuleSuppressesLowerPriority() {
        let plain = Rule(name: "Tek dil",
                         trigger: instantTrigger(.tongueDown),
                         actions: [.scroll(direction: .down, amount: .screens(1), animated: true)],
                         cooldown: 0,
                         priority: 0)
        let combo = Rule(name: "Dil + ağız",
                         trigger: instantTrigger(.tongueDown),
                         condition: .signal(.jawOpen, .greaterThan, 0.5),
                         actions: [.like],
                         cooldown: 0,
                         priority: 10,
                         isExclusive: true)
        let engine = RuleEngine(rules: [plain, combo], options: .init(globalCooldown: 0))
        let context = EvaluationContext()

        let firings = engine.update(frame: frame([.tongueDown: 0.9, .jawOpen: 0.8], at: 0),
                                    context: context)
        XCTAssertEqual(firings.map(\.ruleName), ["Dil + ağız"])
    }

    func testFlagWrittenByOneRuleIsVisibleToAnother() {
        let toggler = Rule(name: "Modu aç",
                           trigger: instantTrigger(.tongueRight),
                           actions: [.setFlag(name: "gezinme", value: true)],
                           cooldown: 0,
                           priority: 100)
        let gated = Rule(name: "Gezinme kuralı",
                         trigger: instantTrigger(.tongueRight),
                         condition: .flag(name: "gezinme", equals: true),
                         actions: [.navigate(.reels)],
                         cooldown: 0,
                         priority: 50)
        let engine = RuleEngine(rules: [toggler, gated],
                                options: .init(globalCooldown: 0, maximumConcurrentFirings: 4))
        let flags = FlagRegistry(["gezinme": false])
        let context = EvaluationContext(flags: flags)

        // Both triggers fire on the same frame. Conditions are evaluated before
        // any flag writes, so the gated rule does not sneak in on frame one.
        let first = engine.update(frame: frame([.tongueRight: 0.9], at: 0), context: context)
        XCTAssertEqual(first.map(\.ruleName), ["Modu aç"])
        XCTAssertTrue(flags.value(for: "gezinme"))

        _ = engine.update(frame: frame([.tongueRight: 0.0], at: 0.1), context: context)
        let second = engine.update(frame: frame([.tongueRight: 0.9], at: 0.2), context: context)
        XCTAssertEqual(second.map(\.ruleName), ["Modu aç", "Gezinme kuralı"])
    }

    func testDisabledRuleNeverFires() {
        let rule = Rule(name: "Kapalı",
                        isEnabled: false,
                        trigger: instantTrigger(.tongueDown),
                        actions: [.like],
                        cooldown: 0)
        let engine = RuleEngine(rules: [rule], options: .init(globalCooldown: 0))
        XCTAssertTrue(engine.update(frame: frame([.tongueDown: 0.9], at: 0),
                                    context: EvaluationContext()).isEmpty)
    }

    func testMacroReferencesAreExpandedIntoSchedule() {
        let macro = Macro(id: "beğen-geç",
                          name: "Beğen ve geç",
                          actions: [.like, .delay(seconds: 0.4),
                                    .scroll(direction: .down, amount: .screens(1), animated: true)])
        let rule = Rule(name: "Çift dil",
                        trigger: instantTrigger(.tongueOut),
                        actions: [.runMacro(id: "beğen-geç")],
                        cooldown: 0)
        let engine = RuleEngine(rules: [rule], macros: [macro], options: .init(globalCooldown: 0))

        let firings = engine.update(frame: frame([.tongueOut: 0.9], at: 0),
                                    context: EvaluationContext())
        XCTAssertEqual(firings.count, 1)
        let schedule = firings[0].schedule
        XCTAssertEqual(schedule.count, 2)
        XCTAssertEqual(schedule[0].offset, 0, accuracy: 0.0001)
        XCTAssertEqual(schedule[1].offset, 0.4, accuracy: 0.0001)
    }

    func testGlobalCooldownRateLimitsEverything() {
        let a = Rule(name: "A", trigger: instantTrigger(.tongueDown), actions: [.like], cooldown: 0)
        let b = Rule(name: "B", trigger: instantTrigger(.jawOpen), actions: [.savePost], cooldown: 0)
        let engine = RuleEngine(rules: [a, b], options: .init(globalCooldown: 0.5))
        let context = EvaluationContext()

        XCTAssertEqual(engine.update(frame: frame([.tongueDown: 0.9], at: 0), context: context).count, 1)
        // Different rule, but inside the global window.
        XCTAssertTrue(engine.update(frame: frame([.jawOpen: 0.9], at: 0.2), context: context).isEmpty)
    }

    func testReplacingRulesKeepsStateForSurvivingRules() {
        var rule = Rule(name: "Kaydır",
                        trigger: instantTrigger(.tongueDown),
                        actions: [.like],
                        cooldown: 5)
        let engine = RuleEngine(rules: [rule], options: .init(globalCooldown: 0))
        let context = EvaluationContext()

        XCTAssertEqual(engine.update(frame: frame([.tongueDown: 0.9], at: 0), context: context).count, 1)

        // Editing the rule's name must not clear its cooldown.
        rule.name = "Kaydır (düzenlendi)"
        engine.replace(rules: [rule])
        _ = engine.update(frame: frame([.tongueDown: 0.0], at: 0.1), context: context)
        XCTAssertTrue(engine.update(frame: frame([.tongueDown: 0.9], at: 0.2), context: context).isEmpty)
    }
}
