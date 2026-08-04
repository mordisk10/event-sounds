#if canImport(WebKit)
import WebKit
import SwiftUI
import Combine
import InstakaiCore

/// Hosts instagram.com in a web view and executes surface commands against it.
///
/// ### Why a web view
/// iOS does not let one app synthesise touches in another. There is no public
/// API — accessibility or otherwise — that lets Instakai drive the Instagram
/// app. Hosting the web client is the only way a third-party app can both watch
/// the user's face and act on Instagram in the same process. `docs/LIMITATIONS.md`
/// spells this out, including what would change on a jailbroken device or under
/// Switch Control.
final class InstagramSurfaceController: NSObject, ObservableObject {

    @Published private(set) var currentSurface: Surface = .unknown
    @Published private(set) var isBridgeReady = false
    @Published private(set) var lastError: String?
    /// Rolling log of executed commands, shown in the debug panel.
    @Published private(set) var recentEvents: [String] = []

    /// Viewport size in CSS pixels, needed to resolve `.screens` scroll amounts.
    private var viewportSize = CGSize(width: 390, height: 844)

    private(set) lazy var webView: WKWebView = makeWebView()

    private static let homeURL = URL(string: "https://www.instagram.com/")!

    // MARK: - Setup

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(self, name: "instakai")
        if let script = Self.loadBridgeScript() {
            controller.addUserScript(WKUserScript(source: script,
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: true))
        }
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // A desktop UA gets the layout that keeps the like/save controls in the
        // DOM; the mobile web client hides several of them behind app prompts.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
                                  "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        return webView
    }

    private static func loadBridgeScript() -> String? {
        guard let url = Bundle.main.url(forResource: "instakai-bridge", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("instakai-bridge.js uygulama paketine eklenmemiş")
            return nil
        }
        return source
    }

    func loadHome() {
        webView.load(URLRequest(url: Self.homeURL))
    }

    func updateViewport(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        viewportSize = size
    }

    // MARK: - Command execution

    /// Performs an action against the surface. Actions the surface does not own
    /// (haptics, speech) return `false` so the dispatcher can handle them.
    @discardableResult
    func perform(_ action: MacroAction) -> Bool {
        if case .javascript(let source) = action {
            evaluate(source)
            return true
        }

        guard let command = SurfaceCommand.make(from: action,
                                                viewportHeight: Double(viewportSize.height),
                                                viewportWidth: Double(viewportSize.width)) else {
            return false
        }
        guard let json = try? command.jsonString() else { return false }

        // The JSON is embedded as a quoted JS string literal; escaping the
        // backslashes and quotes keeps a value like an aria-label with an
        // apostrophe from breaking out of the expression.
        let escaped = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        evaluate("window.__instakai && window.__instakai.perform(\"\(escaped)\")")
        return true
    }

    private func evaluate(_ source: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(source) { _, error in
                guard let error else { return }
                self?.record("JS hatası: \(error.localizedDescription)")
            }
        }
    }

    private func record(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.recentEvents.insert(message, at: 0)
            if self.recentEvents.count > 40 {
                self.recentEvents.removeLast(self.recentEvents.count - 40)
            }
        }
    }
}

// MARK: - Bridge messages

extension InstagramSurfaceController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "instakai", let event = SurfaceEvent.parse(message.body) else { return }

        switch event {
        case .ready(let version):
            isBridgeReady = true
            record("Köprü hazır (v\(version))")
        case .surfaceChanged(let surface):
            currentSurface = surface
            record("Ekran: \(surface.displayName)")
        case .commandResult(let command, let succeeded):
            record("\(command): \(succeeded ? "tamam" : "başarısız")")
        case .error(let message):
            lastError = message
            record("Hata: \(message)")
        }
    }
}

// MARK: - Navigation

extension InstagramSurfaceController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // A full navigation tears down the injected globals; the user script
        // re-runs at document start, but the ready flag needs resetting so the
        // UI does not claim the bridge is live during the gap.
        isBridgeReady = false
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        lastError = error.localizedDescription
    }
}

// MARK: - SwiftUI wrapper

struct InstagramSurfaceView: UIViewRepresentable {
    let controller: InstagramSurfaceController

    func makeUIView(context: Context) -> WKWebView {
        let webView = controller.webView
        if webView.url == nil { controller.loadHome() }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        controller.updateViewport(size: webView.bounds.size)
    }
}
#endif
