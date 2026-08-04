import SwiftUI

/// A horizontally scrolling row whose cards sit on a curved, receding wall.
///
/// The effect is built from four transforms driven by one value — each card's
/// distance from the centre of the viewport, normalised to `-1…1`:
///
/// | distance | rotation | scale | offset | opacity |
/// |---|---|---|---|---|
/// | centre (0) | none | full | none | full |
/// | edge (±1) | turned away | shrunk | pulled back | faded |
///
/// Rotating around the Y axis with perspective is what sells the panorama: the
/// far edge of a side card is genuinely further away, so cards read as panels
/// wrapped around the viewer rather than as flat rectangles that got smaller.
struct PanoramaSlider<Item: Identifiable, Content: View>: View {

    let items: [Item]

    /// Width of one card. The container pads by half the leftover width so the
    /// first and last cards can reach dead centre.
    var cardWidth: CGFloat = 250
    var cardHeight: CGFloat = 190
    var spacing: CGFloat = Theme.Spacing.m

    /// How far an edge card turns. Beyond ~40° the text on side cards becomes
    /// hard to read, which defeats the purpose of showing neighbours at all.
    var maxRotation: Double = 34
    /// How much an edge card shrinks. Together with the rotation this carries
    /// the depth cue — SwiftUI has no Z translation on iOS, so scale stands in
    /// for distance.
    var maxScaleDrop: Double = 0.2

    /// Index the slider has settled on, published so a caller can mirror it in
    /// a page indicator.
    @Binding var focusedIndex: Int

    /// Trailing so call sites can use closure syntax.
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        GeometryReader { container in
            let sideInset = max((container.size.width - cardWidth) / 2, Theme.Spacing.screen)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        content(item)
                            .frame(width: cardWidth, height: cardHeight)
                            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                                effect
                                    .rotation3DEffect(
                                        .degrees(phase.value * -maxRotation),
                                        axis: (x: 0, y: 1, z: 0),
                                        // A tighter perspective exaggerates the
                                        // curve; 0.55 keeps side cards legible.
                                        perspective: 0.55
                                    )
                                    .scaleEffect(1 - abs(phase.value) * maxScaleDrop)
                                    .opacity(1 - abs(phase.value) * 0.35)
                                    // A touch of blur on the far cards finishes
                                    // the depth illusion that scale starts.
                                    .blur(radius: abs(phase.value) * 1.5)
                            }
                            // Centre card must paint over its neighbours,
                            // otherwise the rotated edges clip through it.
                            .zIndex(index == focusedIndex ? 1 : 0)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sideInset)
                // Depth needs headroom: without it the rotated corners are
                // clipped by the ScrollView's bounds.
                .padding(.vertical, Theme.Spacing.l)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { Optional(focusedIndex) },
                set: { if let new = $0 { focusedIndex = new } }
            ))
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: focusedIndex)
        }
        .frame(height: cardHeight + Theme.Spacing.xl)
    }
}

/// Dots under a panorama, showing which card is centred.
struct PanoramaIndicator: View {
    let count: Int
    let focused: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == focused ? Theme.Palette.accent : Theme.Palette.separator)
                    .frame(width: index == focused ? 18 : 6, height: 6)
                    .animation(Theme.Motion.standard, value: focused)
            }
        }
    }
}

// MARK: - Card used inside the panorama

/// One widget-style tile: a stat with an icon, a headline number and a caption.
struct PanoramaCard: View {
    let icon: String
    let title: String
    let value: String
    let caption: String
    var tint: Color = Theme.Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11,
                                                                         style: .continuous))
                Spacer()
            }

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
                .contentTransition(.numericText())

            Text(title)
                .font(.iaCardTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            Text(caption)
                .font(.iaCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(2)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.Palette.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.panorama, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.panorama, style: .continuous)
                .stroke(tint.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 10)
    }
}
