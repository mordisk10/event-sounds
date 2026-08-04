import SwiftUI

/// The four destinations. Deliberately four: everything else lives one level
/// down under Profile, so the bar stays readable at any text size.
enum Tab: String, CaseIterable, Identifiable {
    case home, automations, plans, profile

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .automations: return "wand.and.stars"
        case .plans: return "creditcard"
        case .profile: return "person"
        }
    }

    var filledIcon: String {
        switch self {
        case .home: return "house.fill"
        case .automations: return "wand.and.stars.inverse"
        case .plans: return "creditcard.fill"
        case .profile: return "person.fill"
        }
    }

    var label: S {
        switch self {
        case .home: return .tabHome
        case .automations: return .tabAutomations
        case .plans: return .tabPlans
        case .profile: return .tabProfile
        }
    }
}

/// The signed-in shell: content, custom tab bar, and the island overlay on top
/// of both.
struct RootView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var island: IslandCenter

    @State private var tab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $tab)
        }
        .background(Theme.Palette.background)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // The island overlay sits above everything, including the tab bar, and
        // never intercepts touches.
        .overlay(alignment: .top) {
            IslandFeedbackOverlay(center: island)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home:
            HomeView()
        case .automations:
            AutomationsView()
        case .plans:
            PricingView()
        case .profile:
            ProfileView()
        }
    }
}

/// A hand-built tab bar rather than `TabView`.
///
/// Two reasons: the selected tab needs the accent pill behind it, and the bar
/// has to float above a scrolling background with a blurred capsule shape.
/// `TabView`'s appearance API cannot produce either.
struct TabBar: View {
    @EnvironmentObject private var lang: LanguageManager
    @Binding var selection: Tab

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    guard tab != selection else { return }
                    withAnimation(Theme.Motion.standard) { selection = tab }
                    Haptics.selection()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: selection == tab ? tab.filledIcon : tab.icon)
                            .font(.system(size: 18, weight: .medium))
                            .contentTransition(.symbolEffect(.replace))
                        Text(lang.t(tab.label))
                            .font(.iaMicro)
                    }
                    .foregroundStyle(selection == tab ? Theme.Palette.accent
                                                      : Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.Palette.accentWash)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pushSubtle)
                .accessibilityLabel(lang.t(tab.label))
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.s)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.Palette.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.bottom, Theme.Spacing.s)
    }
}
