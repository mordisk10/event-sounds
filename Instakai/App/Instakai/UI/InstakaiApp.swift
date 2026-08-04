#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI

@main
struct InstakaiApp: App {
    @StateObject private var session = SessionController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var session: SessionController

    var body: some View {
        TabView {
            SessionView()
                .tabItem { Label("Oturum", systemImage: "camera.viewfinder") }

            RuleListView()
                .tabItem { Label("Kurallar", systemImage: "slider.horizontal.3") }

            MacroListView()
                .tabItem { Label("Makrolar", systemImage: "square.stack.3d.up") }

            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
        .tint(.pink)
    }
}
#endif
