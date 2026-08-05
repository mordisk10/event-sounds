import SwiftUI

/// Edits one automation.
///
/// Split into a **Simple** section that is always visible and a **Technical**
/// section behind a disclosure. Priority, cooldown and exclusivity are the three
/// settings that confuse people, so they live behind the toggle and each carries
/// its own ⓘ.
struct AutomationEditorView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var store: AutomationStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Automation
    @State private var showsTechnical = false
    @State private var isTesting = false
    @State private var showsDeleteConfirm = false

    private let onSave: (Automation) -> Void

    init(automation: Automation, onSave: @escaping (Automation) -> Void) {
        _draft = State(initialValue: automation)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    preview
                    nameCard
                    triggerCard
                    conditionCard
                    actionCard
                    technicalSection
                    dangerZone
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.Palette.background)
            .navigationTitle(lang.t(.autoTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.t(.cancel)) { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t(.save)) {
                        onSave(draft)
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.accent)
                    .disabled(draft.actions.isEmpty || draft.name.isEmpty)
                }
            }
            .confirmationDialog(lang.t(.autoDelete),
                                isPresented: $showsDeleteConfirm,
                                titleVisibility: .visible) {
                Button(lang.t(.delete), role: .destructive) {
                    store.delete(draft)
                    dismiss()
                }
                Button(lang.t(.cancel), role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    /// A live sentence of what the automation currently does, so the effect of
    /// each change is visible without leaving the screen.
    private var preview: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                AutomationSentence(automation: draft)

                Button {
                    runTest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isTesting ? "circle.dotted" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(lang.t(isTesting ? .autoTestRunning : .autoTest))
                            .font(.iaMicro)
                    }
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Palette.accentWash, in: Capsule())
                }
                .buttonStyle(.pushSubtle)
                .disabled(isTesting)
            }
        }
    }

    private var nameCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(lang.t(.autoName))
                InputField(title: lang.t(.autoName), text: $draft.name)
            }
        }
    }

    private var triggerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.autoTrigger), info: lang.t(.autoInfoTrigger))
                FlowPicker(items: AutomationTrigger.allCases,
                           selection: $draft.trigger,
                           label: { $0.name(lang) },
                           icon: { $0.icon })
            }
        }
    }

    private var conditionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.autoCondition), info: lang.t(.autoInfoCondition))
                FlowPicker(items: AutomationCondition.allCases,
                           selection: $draft.condition,
                           label: { $0.name(lang) },
                           icon: { _ in nil },
                           tint: Theme.Palette.warning)
            }
        }
    }

    private var actionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.autoAction), info: lang.t(.autoInfoAction))

                // Actions are multi-select and ordered, so this is a toggle grid
                // rather than the single-choice FlowPicker above.
                FlowLayout(spacing: Theme.Spacing.s) {
                    ForEach(AutomationAction.allCases) { action in
                        let isOn = draft.actions.contains(action)
                        Button {
                            withAnimation(Theme.Motion.standard) {
                                if isOn {
                                    draft.actions.removeAll { $0 == action }
                                } else {
                                    draft.actions.append(action)
                                }
                            }
                            Haptics.selection()
                        } label: {
                            Chip(text: action.name(lang),
                                 icon: action.icon,
                                 tint: Theme.Palette.success,
                                 filled: isOn)
                        }
                        .buttonStyle(.pushSubtle)
                    }
                }

                if draft.actions.count > 1 {
                    Text(draft.actions.enumerated()
                        .map { "\($0.offset + 1). \($0.element.name(lang))" }
                        .joined(separator: "  →  "))
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private var technicalSection: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button {
                withAnimation(Theme.Motion.standard) { showsTechnical.toggle() }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                    Text(lang.t(showsTechnical ? .autoHideTechnical : .autoShowTechnical))
                        .font(.iaCaption)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(showsTechnical ? 180 : 0))
                }
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.m)
                .background(Theme.Palette.surfaceSunken,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                 style: .continuous))
            }
            .buttonStyle(.pushSubtle)

            if showsTechnical {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack(spacing: 6) {
                                Text(lang.t(.autoPriority)).font(.iaBody)
                                InfoTip(text: lang.t(.autoInfoPriority))
                                Spacer()
                                Text("\(draft.priority)")
                                    .font(.iaNumeric)
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                            Slider(value: Binding(
                                get: { Double(draft.priority) },
                                set: { draft.priority = Int($0) }
                            ), in: -50...50, step: 5)
                            .tint(Theme.Palette.accent)
                        }

                        RowDivider()

                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack(spacing: 6) {
                                Text(lang.t(.autoCooldown)).font(.iaBody)
                                InfoTip(text: lang.t(.autoInfoCooldown))
                                Spacer()
                                Text(String(format: "%.2f sn", draft.cooldown))
                                    .font(.iaNumeric)
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                            Slider(value: $draft.cooldown, in: 0.1...3, step: 0.05)
                                .tint(Theme.Palette.accent)
                        }

                        RowDivider()

                        HStack(spacing: 6) {
                            ToggleRow(icon: "exclamationmark.octagon",
                                      title: lang.t(.autoExclusive),
                                      tint: Theme.Palette.danger,
                                      isOn: $draft.isExclusive)
                            InfoTip(text: lang.t(.autoInfoExclusive))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var dangerZone: some View {
        SecondaryButton(title: lang.t(.autoDelete),
                        icon: "trash",
                        role: .destructive) {
            showsDeleteConfirm = true
        }
    }

    private func runTest() {
        isTesting = true
        Haptics.impact(.medium)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            isTesting = false
            Haptics.success()
        }
    }
}

// MARK: - Pickers

/// Single-choice chip grid.
struct FlowPicker<Item: Identifiable & Equatable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String
    let icon: (Item) -> String?
    var tint: Color = Theme.Palette.accent

    var body: some View {
        FlowLayout(spacing: Theme.Spacing.s) {
            ForEach(items) { item in
                Button {
                    withAnimation(Theme.Motion.standard) { selection = item }
                    Haptics.selection()
                } label: {
                    Chip(text: label(item),
                         icon: icon(item),
                         tint: tint,
                         filled: selection == item)
                }
                .buttonStyle(.pushSubtle)
            }
        }
    }
}

/// Wraps its children onto as many lines as needed.
///
/// `LazyVGrid` cannot do this: chips have wildly different widths and a fixed
/// column count would leave ragged gaps.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
