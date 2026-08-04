import SwiftUI

@main
struct InstakaiApp: App {

    @StateObject private var lang = LanguageManager()
    @StateObject private var auth = AuthController()
    @StateObject private var automations = AutomationStore()
    @StateObject private var island = IslandCenter()

    var body: some Scene {
        WindowGroup {
            AppGate()
                .environmentObject(lang)
                .environmentObject(auth)
                .environmentObject(automations)
                .environmentObject(island)
                // The design is built for a light, white surface; dark mode is
                // a separate piece of work rather than a free inversion.
                .preferredColorScheme(.light)
                .tint(Theme.Palette.accent)
        }
    }
}

/// Chooses between the auth flow and the signed-in shell.
///
/// A crossfade rather than a sheet or a push: signing in replaces the whole app,
/// it is not a step inside it.
struct AppGate: View {
    @EnvironmentObject private var auth: AuthController

    var body: some View {
        ZStack {
            if auth.isSignedIn {
                RootView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                AuthFlowView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.showcase, value: auth.isSignedIn)
    }
}
