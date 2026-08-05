import SwiftUI
import UIKit

// MARK: - Containers

/// The standard white card. Every grouped block in the app uses this so
/// elevation stays consistent.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.l
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card,
                                                                    style: .continuous))
            .modifier(CardShadow())
    }
}

private struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

/// Title + optional subtitle + optional trailing control, above a block.
struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    /// Explains the section without adding another line of body copy.
    var info: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.iaHeadline).foregroundStyle(Theme.Palette.textPrimary)
                    if let info { InfoTip(text: info) }
                }
                if let subtitle {
                    Text(subtitle).font(.iaCaption).foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            trailing
        }
    }
}

extension SectionHeader {
    /// Unlabelled title plus a trailing control:
    /// `SectionHeader("Kurallar") { Button(...) }`
    init(_ title: String,
         subtitle: String? = nil,
         info: String? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, subtitle: subtitle, info: info, trailing: trailing)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, info: String? = nil) {
        self.init(title: title, subtitle: subtitle, info: info) { EmptyView() }
    }
}

// MARK: - Info tip

/// A small ⓘ that reveals one sentence of explanation on tap.
///
/// This is how the technical screens stay approachable: the jargon stays on
/// screen because power users need it, but the definition is one tap away
/// instead of occupying a permanent paragraph.
struct InfoTip: View {
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .buttonStyle(.pushSubtle)
        .accessibilityLabel(text)
        .popover(isPresented: $isPresented) {
            Text(text)
                .font(.iaCaption)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.leading)
                .padding(Theme.Spacing.m)
                .frame(maxWidth: 260)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var icon: String?
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title).font(.iaCardTitle)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m + 2)
            .background(
                LinearGradient(colors: [Theme.Palette.accent, Theme.Palette.accentDeep],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .opacity(isEnabled && !isLoading ? 1 : 0.45)
        }
        .buttonStyle(.push)
        .disabled(!isEnabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String?
    var role: ButtonRole?
    let action: () -> Void

    private var tint: Color {
        role == .destructive ? Theme.Palette.danger : Theme.Palette.accent
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.iaCardTitle)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.m)
            .background(tint.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.push)
    }
}

// MARK: - Small pieces

struct Chip: View {
    let text: String
    var icon: String?
    var tint: Color = Theme.Palette.accent
    var filled = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.iaMicro)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(filled ? .white : tint)
        .background(filled ? tint : tint.opacity(0.12), in: Capsule())
    }
}

/// A labelled switch row, with an optional explanation underneath.
struct ToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var tint: Color = Theme.Palette.accent
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.iaBody).foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Palette.accent)
        }
    }
}

/// Thin hairline used between rows inside a card.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.separator)
            .frame(height: 1)
            .padding(.leading, 30 + Theme.Spacing.m)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.Palette.accent.opacity(0.55))
            Text(title).font(.iaCardTitle).foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .font(.iaCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

// MARK: - Fields

struct InputField: View {
    let title: String
    var icon: String?
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var errorText: String?
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.Spacing.s) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isFocused ? Theme.Palette.accent : Theme.Palette.textTertiary)
                        .frame(width: 18)
                }
                Group {
                    if isSecure {
                        SecureField(title, text: $text)
                    } else {
                        TextField(title, text: $text)
                    }
                }
                .font(.iaBody)
                .focused($isFocused)
                .keyboardType(keyboard)
                .textContentType(textContentType)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.m)
            .background(Theme.Palette.surfaceSunken,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .animation(Theme.Motion.standard, value: isFocused)

            if let errorText {
                Text(errorText)
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.danger)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var borderColor: Color {
        if errorText != nil { return Theme.Palette.danger.opacity(0.6) }
        return isFocused ? Theme.Palette.accent.opacity(0.7) : .clear
    }
}
