#if canImport(SwiftUI)
import SwiftUI
import InstakaiCore

/// A live bar for one signal, with the rule threshold marked on it.
///
/// The threshold marker is the point of this view: tuning a gesture is guesswork
/// without seeing how close your face actually gets to the line.
struct SignalMeter: View {
    let signal: Signal
    let value: Double
    var threshold: Double?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !compact {
                HStack {
                    Text(signal.displayName)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", value))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))

                    Capsule()
                        .fill(isOverThreshold ? Color.green : Color.accentColor)
                        .frame(width: geometry.size.width * clamped)

                    if let threshold {
                        Rectangle()
                            .fill(Color.primary.opacity(0.55))
                            .frame(width: 2)
                            .offset(x: geometry.size.width * min(max(threshold, 0), 1) - 1)
                    }
                }
            }
            .frame(height: compact ? 6 : 10)
        }
    }

    private var clamped: Double { min(max(value, 0), 1) }

    private var isOverThreshold: Bool {
        guard let threshold else { return false }
        return value >= threshold
    }
}

/// Coloured pill used for surfaces, modes and states.
struct TagChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: Capsule())
        .foregroundStyle(tint)
    }
}

/// Inline warning row for generator validation output.
struct WarningRow: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Empty-state placeholder.
struct EmptyHint: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
#endif
