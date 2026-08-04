import Foundation

/// Which part of Instagram the user is currently looking at. Rules can be
/// scoped to a surface so that "dil aşağı" scrolls the feed but skips to the
/// next clip in Reels.
public enum Surface: String, Codable, CaseIterable, Sendable {
    case unknown
    case feed
    case reels
    case stories
    case explore
    case profile
    case directMessages
    case postDetail

    public var displayName: String {
        switch self {
        case .unknown: return "Bilinmiyor"
        case .feed: return "Akış"
        case .reels: return "Reels"
        case .stories: return "Hikâyeler"
        case .explore: return "Keşfet"
        case .profile: return "Profil"
        case .directMessages: return "Mesajlar"
        case .postDetail: return "Gönderi detayı"
        }
    }
}

public enum ScrollDirection: String, Codable, CaseIterable, Sendable {
    case up, down, left, right
}

/// How far a scroll goes. `screens` is resolution independent, which matters
/// because a Reel is exactly one viewport tall.
public enum ScrollAmount: Codable, Hashable, Sendable {
    case pixels(Double)
    case screens(Double)

    public var displayName: String {
        switch self {
        case .pixels(let value): return "\(Int(value)) px"
        case .screens(let value): return String(format: "%.2f ekran", value)
        }
    }
}

public enum HapticStyle: String, Codable, CaseIterable, Sendable {
    case light, medium, heavy, success, warning, error, selection
}

/// Where a synthetic tap should land.
public enum TapTarget: String, Codable, CaseIterable, Sendable {
    case likeButton
    case commentButton
    case shareButton
    case saveButton
    case followButton
    case audioToggle
    case profileAvatar
    case centerOfScreen
    case backButton

    public var displayName: String {
        switch self {
        case .likeButton: return "Beğen düğmesi"
        case .commentButton: return "Yorum düğmesi"
        case .shareButton: return "Paylaş düğmesi"
        case .saveButton: return "Kaydet düğmesi"
        case .followButton: return "Takip et düğmesi"
        case .audioToggle: return "Ses aç/kapa"
        case .profileAvatar: return "Profil resmi"
        case .centerOfScreen: return "Ekran ortası"
        case .backButton: return "Geri"
        }
    }
}

public enum Destination: String, Codable, CaseIterable, Sendable {
    case home, reels, explore, notifications, profile, directMessages, search, back

    public var displayName: String {
        switch self {
        case .home: return "Ana sayfa"
        case .reels: return "Reels"
        case .explore: return "Keşfet"
        case .notifications: return "Bildirimler"
        case .profile: return "Profil"
        case .directMessages: return "Mesajlar"
        case .search: return "Arama"
        case .back: return "Geri"
        }
    }
}

/// One step a macro can perform.
///
/// Actions are intentionally declarative — they say *what* should happen, never
/// *how*. The app-layer `MacroDispatcher` decides how to realise each one against
/// whichever surface is currently hosting Instagram, which keeps Core free of
/// UIKit/WebKit and unit testable.
public enum MacroAction: Hashable, Sendable {

    /// Scroll the current surface.
    case scroll(direction: ScrollDirection, amount: ScrollAmount, animated: Bool)
    /// Tap a recognised control.
    case tap(TapTarget)
    /// Like / unlike the focused post.
    case like
    case unlike
    /// Double-tap gesture on the media itself (Instagram's own "like" shortcut).
    case doubleTapLike
    case savePost
    case openComments
    /// Dismiss whatever sheet or overlay is open.
    case closeOverlay
    case navigate(Destination)
    case toggleMute
    case playPause
    /// Pause between steps so a macro can wait for an animation.
    case delay(seconds: TimeInterval)
    case haptic(HapticStyle)
    /// Speak text through the system voice — useful as an accessibility cue.
    case speak(String)
    /// Run another macro by id. Expanded by `MacroExpander` with a depth guard.
    case runMacro(id: String)
    /// Set or flip a user-defined flag that conditions can read. This is what
    /// makes stateful rule sets ("modes") possible without hard-coding them.
    case setFlag(name: String, value: Bool)
    case toggleFlag(name: String)
    /// Escape hatch: raw JavaScript evaluated against the hosted surface.
    case javascript(String)

    public var displayName: String {
        switch self {
        case .scroll(let direction, let amount, _):
            let arrow: String
            switch direction {
            case .up: arrow = "yukarı"
            case .down: arrow = "aşağı"
            case .left: arrow = "sola"
            case .right: arrow = "sağa"
            }
            return "Kaydır \(arrow) (\(amount.displayName))"
        case .tap(let target): return "Dokun: \(target.displayName)"
        case .like: return "Beğen"
        case .unlike: return "Beğeniyi geri al"
        case .doubleTapLike: return "Çift dokunup beğen"
        case .savePost: return "Gönderiyi kaydet"
        case .openComments: return "Yorumları aç"
        case .closeOverlay: return "Açık katmanı kapat"
        case .navigate(let destination): return "Git: \(destination.displayName)"
        case .toggleMute: return "Sesi aç/kapat"
        case .playPause: return "Oynat/duraklat"
        case .delay(let seconds): return String(format: "Bekle %.2f sn", seconds)
        case .haptic(let style): return "Titreşim (\(style.rawValue))"
        case .speak(let text): return "Seslendir: \(text)"
        case .runMacro(let id): return "Makro çalıştır: \(id)"
        case .setFlag(let name, let value): return "Bayrak \(name) = \(value)"
        case .toggleFlag(let name): return "Bayrak \(name) tersine çevir"
        case .javascript: return "JavaScript çalıştır"
        }
    }

    /// Actions the engine resolves itself instead of handing to the dispatcher.
    public var mutatesFlags: Bool {
        switch self {
        case .setFlag, .toggleFlag: return true
        default: return false
        }
    }
}

// MARK: - Codable

extension MacroAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, direction, amount, unit, animated, target, destination
        case seconds, style, text, id, name, value, script
    }

    private enum Kind: String {
        case scroll, tap, like, unlike, doubleTapLike, savePost, openComments
        case closeOverlay, navigate, toggleMute, playPause, delay, haptic
        case speak, runMacro, setFlag, toggleFlag, javascript
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: rawType) else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Bilinmeyen eylem: \(rawType)")
        }

        switch kind {
        case .scroll:
            let direction = try container.decode(ScrollDirection.self, forKey: .direction)
            let magnitude = try container.decode(Double.self, forKey: .amount)
            let unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "screens"
            let animated = try container.decodeIfPresent(Bool.self, forKey: .animated) ?? true
            let amount: ScrollAmount = unit == "pixels" ? .pixels(magnitude) : .screens(magnitude)
            self = .scroll(direction: direction, amount: amount, animated: animated)
        case .tap:
            self = .tap(try container.decode(TapTarget.self, forKey: .target))
        case .like: self = .like
        case .unlike: self = .unlike
        case .doubleTapLike: self = .doubleTapLike
        case .savePost: self = .savePost
        case .openComments: self = .openComments
        case .closeOverlay: self = .closeOverlay
        case .navigate:
            self = .navigate(try container.decode(Destination.self, forKey: .destination))
        case .toggleMute: self = .toggleMute
        case .playPause: self = .playPause
        case .delay:
            self = .delay(seconds: try container.decode(TimeInterval.self, forKey: .seconds))
        case .haptic:
            self = .haptic(try container.decode(HapticStyle.self, forKey: .style))
        case .speak:
            self = .speak(try container.decode(String.self, forKey: .text))
        case .runMacro:
            self = .runMacro(id: try container.decode(String.self, forKey: .id))
        case .setFlag:
            self = .setFlag(name: try container.decode(String.self, forKey: .name),
                            value: try container.decode(Bool.self, forKey: .value))
        case .toggleFlag:
            self = .toggleFlag(name: try container.decode(String.self, forKey: .name))
        case .javascript:
            self = .javascript(try container.decode(String.self, forKey: .script))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .scroll(let direction, let amount, let animated):
            try container.encode(Kind.scroll.rawValue, forKey: .type)
            try container.encode(direction, forKey: .direction)
            switch amount {
            case .pixels(let value):
                try container.encode(value, forKey: .amount)
                try container.encode("pixels", forKey: .unit)
            case .screens(let value):
                try container.encode(value, forKey: .amount)
                try container.encode("screens", forKey: .unit)
            }
            try container.encode(animated, forKey: .animated)
        case .tap(let target):
            try container.encode(Kind.tap.rawValue, forKey: .type)
            try container.encode(target, forKey: .target)
        case .like: try container.encode(Kind.like.rawValue, forKey: .type)
        case .unlike: try container.encode(Kind.unlike.rawValue, forKey: .type)
        case .doubleTapLike: try container.encode(Kind.doubleTapLike.rawValue, forKey: .type)
        case .savePost: try container.encode(Kind.savePost.rawValue, forKey: .type)
        case .openComments: try container.encode(Kind.openComments.rawValue, forKey: .type)
        case .closeOverlay: try container.encode(Kind.closeOverlay.rawValue, forKey: .type)
        case .navigate(let destination):
            try container.encode(Kind.navigate.rawValue, forKey: .type)
            try container.encode(destination, forKey: .destination)
        case .toggleMute: try container.encode(Kind.toggleMute.rawValue, forKey: .type)
        case .playPause: try container.encode(Kind.playPause.rawValue, forKey: .type)
        case .delay(let seconds):
            try container.encode(Kind.delay.rawValue, forKey: .type)
            try container.encode(seconds, forKey: .seconds)
        case .haptic(let style):
            try container.encode(Kind.haptic.rawValue, forKey: .type)
            try container.encode(style, forKey: .style)
        case .speak(let text):
            try container.encode(Kind.speak.rawValue, forKey: .type)
            try container.encode(text, forKey: .text)
        case .runMacro(let id):
            try container.encode(Kind.runMacro.rawValue, forKey: .type)
            try container.encode(id, forKey: .id)
        case .setFlag(let name, let value):
            try container.encode(Kind.setFlag.rawValue, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(value, forKey: .value)
        case .toggleFlag(let name):
            try container.encode(Kind.toggleFlag.rawValue, forKey: .type)
            try container.encode(name, forKey: .name)
        case .javascript(let script):
            try container.encode(Kind.javascript.rawValue, forKey: .type)
            try container.encode(script, forKey: .script)
        }
    }
}

// MARK: - ScrollAmount Codable

extension ScrollAmount {
    private enum CodingKeys: String, CodingKey { case unit, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Double.self, forKey: .value)
        let unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "screens"
        self = unit == "pixels" ? .pixels(value) : .screens(value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pixels(let value):
            try container.encode("pixels", forKey: .unit)
            try container.encode(value, forKey: .value)
        case .screens(let value):
            try container.encode("screens", forKey: .unit)
            try container.encode(value, forKey: .value)
        }
    }
}
