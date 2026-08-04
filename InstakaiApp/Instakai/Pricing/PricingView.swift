import SwiftUI

enum PlanTier: String, CaseIterable, Identifiable, Codable {
    case free, pro, studio

    var id: String { rawValue }

    func name(_ lang: LanguageManager) -> String {
        switch self {
        case .free: return lang.t(.planFreeName)
        case .pro: return lang.t(.planProName)
        case .studio: return lang.t(.planStudioName)
        }
    }

    func summary(_ lang: LanguageManager) -> String {
        switch self {
        case .free: return lang.t(.planFreeBody)
        case .pro: return lang.t(.planProBody)
        case .studio: return lang.t(.planStudioBody)
        }
    }

    /// Placeholder pricing — confirm before shipping. Real values must come
    /// from StoreKit products, not from a hard-coded table.
    var monthlyPrice: Double {
        switch self {
        case .free: return 0
        case .pro: return 4.99
        case .studio: return 9.99
        }
    }

    var yearlyPrice: Double { monthlyPrice * 10 }

    var isHighlighted: Bool { self == .pro }

    func features(_ lang: LanguageManager) -> [String] {
        let turkish = lang.language == .turkish
        switch self {
        case .free:
            return turkish
                ? ["3 otomasyon", "Temel hareketler", "Bas-konuş mikrofon"]
                : ["3 automations", "Core gestures", "Push-to-talk mic"]
        case .pro:
            return turkish
                ? ["Sınırsız otomasyon", "Tüm hareketler", "Yapay zekâ ile kurulum",
                   "Dynamic Island geri bildirimi", "Sabit mikrofon modu"]
                : ["Unlimited automations", "All gestures", "AI setup",
                   "Dynamic Island feedback", "Stay-put mic mode"]
        case .studio:
            return turkish
                ? ["Pro'daki her şey", "Öncelikli destek", "Erken erişim özellikleri",
                   "Otomasyon dışa/içe aktarma"]
                : ["Everything in Pro", "Priority support", "Early access features",
                   "Automation import/export"]
        }
    }
}

/// The Plans tab.
struct PricingView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var auth: AuthController

    private enum Cycle { case monthly, yearly }

    @State private var cycle: Cycle = .yearly
    @State private var focusedPlan = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                cyclePicker
                planCarousel
                PanoramaIndicator(count: PlanTier.allCases.count, focused: focusedPlan)
                    .frame(maxWidth: .infinity)
                comparison
                restoreButton
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Palette.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lang.t(.planTitle))
                .font(.iaTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(lang.t(.planSubtitle))
                .font(.iaBody)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, Theme.Spacing.s)
    }

    private var cyclePicker: some View {
        HStack(spacing: 4) {
            cycleTab(.monthly, title: lang.t(.planMonthly), badge: nil)
            cycleTab(.yearly, title: lang.t(.planYearly), badge: lang.t(.planSave))
        }
        .padding(4)
        .background(Theme.Palette.surfaceSunken, in: Capsule())
        .padding(.horizontal, Theme.Spacing.screen)
    }

    private func cycleTab(_ target: Cycle, title: String, badge: String?) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) { cycle = target }
            Haptics.selection()
        } label: {
            HStack(spacing: 6) {
                Text(title).font(.iaCardTitle)
                if let badge, cycle == target {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.25), in: Capsule())
                }
            }
            .foregroundStyle(cycle == target ? .white : Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s + 2)
            .background { if cycle == target { Capsule().fill(Theme.Palette.accent) } }
        }
        .buttonStyle(.pushSubtle)
    }

    /// The plans reuse the panoramic slider, so pricing feels like the rest of
    /// the app rather than a separate paywall screen.
    private var planCarousel: some View {
        PanoramaSlider(items: PlanTier.allCases,
                       cardWidth: 272,
                       cardHeight: 330,
                       focusedIndex: $focusedPlan) { tier in
            planCard(tier)
        }
    }

    private func planCard(_ tier: PlanTier) -> some View {
        let isCurrent = auth.account?.plan == tier

        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text(tier.name(lang))
                    .font(.iaHeadline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if tier.isHighlighted {
                    Chip(text: lang.t(.planPopular), icon: "star.fill", filled: true)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(priceText(for: tier))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                if tier != .free {
                    Text(lang.t(cycle == .monthly ? .planPerMonth : .planPerYear))
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }

            Text(tier.summary(lang))
                .font(.iaCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.features(lang), id: \.self) { feature in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.accent)
                        Text(feature)
                            .font(.iaCaption)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                auth.updatePlan(tier)
                Haptics.success()
            } label: {
                Text(lang.t(isCurrent ? .planCurrent : .planChoose))
                    .font(.iaCardTitle)
                    .foregroundStyle(isCurrent ? Theme.Palette.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.m)
                    .background {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .fill(Theme.Palette.surfaceSunken)
                        } else {
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .fill(LinearGradient(colors: [Theme.Palette.accent,
                                                              Theme.Palette.accentDeep],
                                                     startPoint: .top, endPoint: .bottom))
                        }
                    }
            }
            .buttonStyle(.push)
            .disabled(isCurrent)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.Palette.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.panorama, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.panorama, style: .continuous)
                .stroke(tier.isHighlighted ? Theme.Palette.accent.opacity(0.4)
                                           : Theme.Palette.separator,
                        lineWidth: tier.isHighlighted ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
    }

    private func priceText(for tier: PlanTier) -> String {
        guard tier != .free else { return lang.language == .turkish ? "Ücretsiz" : "Free" }
        let amount = cycle == .monthly ? tier.monthlyPrice : tier.yearlyPrice
        return String(format: "$%.2f", amount)
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(lang.t(.planCompare))
                .padding(.horizontal, Theme.Spacing.screen)

            Card {
                VStack(spacing: 0) {
                    ForEach(Array(PlanTier.allCases.enumerated()), id: \.element.id) { index, tier in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tier.name(lang))
                                    .font(.iaBody)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text("\(tier.features(lang).count) \(lang.t(.planFeature))")
                                    .font(.iaCaption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer()
                            Text(priceText(for: tier))
                                .font(.iaNumeric)
                                .foregroundStyle(Theme.Palette.accent)
                        }
                        .padding(.vertical, Theme.Spacing.s + 2)

                        if index < PlanTier.allCases.count - 1 {
                            Rectangle()
                                .fill(Theme.Palette.separator)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
        }
    }

    private var restoreButton: some View {
        Button(lang.t(.planRestore)) {
            Haptics.impact(.light)
        }
        .font(.iaCaption)
        .foregroundStyle(Theme.Palette.textSecondary)
        .frame(maxWidth: .infinity)
        .buttonStyle(.pushSubtle)
    }
}
