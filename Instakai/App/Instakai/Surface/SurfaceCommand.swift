import Foundation
import InstakaiCore

/// A single instruction sent from native code to the hosted Instagram surface.
///
/// This is the whole native↔web contract. `MacroDispatcher` translates
/// `MacroAction` values into these; `instakai-bridge.js` executes them.
struct SurfaceCommand: Encodable {

    enum Kind: String, Encodable {
        case scroll, like, unlike, doubleTapLike, savePost, openComments
        case tap, closeOverlay, navigate, toggleMute, playPause
    }

    var kind: Kind
    /// Scroll delta in CSS pixels.
    var dx: Double?
    var dy: Double?
    var animated: Bool?
    var target: String?
    var destination: String?

    init(kind: Kind,
         dx: Double? = nil,
         dy: Double? = nil,
         animated: Bool? = nil,
         target: String? = nil,
         destination: String? = nil) {
        self.kind = kind
        self.dx = dx
        self.dy = dy
        self.animated = animated
        self.target = target
        self.destination = destination
    }

    /// JSON payload passed to `window.__instakai.perform`.
    func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }

    /// Translates a `MacroAction` into a command.
    ///
    /// Returns `nil` for actions the surface does not handle — haptics, speech
    /// and flags are performed natively.
    ///
    /// - Parameter viewportHeight: used to resolve `.screens` amounts into CSS
    ///   pixels, so a "one screen" scroll matches one Reel exactly.
    static func make(from action: MacroAction, viewportHeight: Double, viewportWidth: Double) -> SurfaceCommand? {
        switch action {
        case .scroll(let direction, let amount, let animated):
            let vertical = direction == .up || direction == .down
            let span = vertical ? viewportHeight : viewportWidth
            let magnitude: Double
            switch amount {
            case .pixels(let pixels): magnitude = pixels
            case .screens(let screens): magnitude = screens * span
            }
            switch direction {
            case .down:  return SurfaceCommand(kind: .scroll, dx: 0, dy: magnitude, animated: animated)
            case .up:    return SurfaceCommand(kind: .scroll, dx: 0, dy: -magnitude, animated: animated)
            case .right: return SurfaceCommand(kind: .scroll, dx: magnitude, dy: 0, animated: animated)
            case .left:  return SurfaceCommand(kind: .scroll, dx: -magnitude, dy: 0, animated: animated)
            }

        case .tap(let target):
            return SurfaceCommand(kind: .tap, target: target.rawValue)
        case .like:            return SurfaceCommand(kind: .like)
        case .unlike:          return SurfaceCommand(kind: .unlike)
        case .doubleTapLike:   return SurfaceCommand(kind: .doubleTapLike)
        case .savePost:        return SurfaceCommand(kind: .savePost)
        case .openComments:    return SurfaceCommand(kind: .openComments)
        case .closeOverlay:    return SurfaceCommand(kind: .closeOverlay)
        case .navigate(let destination):
            return SurfaceCommand(kind: .navigate, destination: destination.rawValue)
        case .toggleMute:      return SurfaceCommand(kind: .toggleMute)
        case .playPause:       return SurfaceCommand(kind: .playPause)

        case .delay, .haptic, .speak, .runMacro, .setFlag, .toggleFlag, .javascript:
            return nil
        }
    }
}

/// Messages coming back from the bridge.
enum SurfaceEvent {
    case ready(version: Int)
    case surfaceChanged(Surface)
    case commandResult(command: String, succeeded: Bool)
    case error(String)

    /// Parses the dictionary posted by `webkit.messageHandlers.instakai`.
    static func parse(_ body: Any) -> SurfaceEvent? {
        guard let dictionary = body as? [String: Any],
              let kind = dictionary["kind"] as? String else { return nil }

        switch kind {
        case "ready":
            return .ready(version: dictionary["version"] as? Int ?? 0)
        case "surface":
            let raw = dictionary["surface"] as? String ?? "unknown"
            return .surfaceChanged(Surface(rawValue: raw) ?? .unknown)
        case "result":
            return .commandResult(command: dictionary["command"] as? String ?? "?",
                                  succeeded: dictionary["ok"] as? Bool ?? false)
        case "error":
            return .error(dictionary["message"] as? String ?? "bilinmeyen hata")
        default:
            return nil
        }
    }
}
