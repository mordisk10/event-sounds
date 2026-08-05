import SwiftUI

/// The technical tab, kept approachable.
///
/// Three deliberate choices keep it from overwhelming:
/// 1. The AI composer is at the top, so the easiest path is the first one.
/// 2. Rows read as a sentence — trigger → action — not as a settings dump.
/// 3. Every piece of jargon carries an ⓘ instead of a paragraph of body copy.
struct AutomationsView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var store: AutomationStore

    @State private var prompt = ""
    @State private var editing: Automation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                composer
                if let suggestion = store.suggestion {
                    suggestionCard(suggestion)
                }
                list
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Palette.background)
        .sheet(item: $editing) { automation in
            AutomationEditorView(automation: automation) { store.upsert($0) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lang.t(.autoTitle))
                .font(.iaTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(lang.t(.autoSubtitle))
                .font(.iaBody)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - AI composer

    private var composer: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.autoAskAI),
                              subtitle: lang.t(.autoAskAIHint),
                              info: lang.t(.autoInfoTrigger))

                HStack(spacing: Theme.Spacing.s) {
                    TextField(lang.t(.autoAskAIPlaceholder), text: $prompt, axis: .vertical)
                        .font(.iaBody)
                        .lineLimit(1...3)
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, Theme.Spacing.s + 2)
                        .background(Theme.Palette.surfaceSunken,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                         style: .continuous))

                    Button {
                        let text = prompt
                        prompt = ""
                        Task { await store.generate(from: text, lang: lang) }
                    } label: {
                        Group {
                            if store.isGenerating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Theme.Palette.accent,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                         style: .continuous))
                    }
                    .buttonStyle(.push)
                    .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || store.isGenerating)
                    .opacity(prompt.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                }
            }
        }
    }

    private func suggestionCard(_ automation: Automation) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack {
                    Chip(text: lang.t(.autoSuggested), icon: "sparkles", filled: true)
                    Spacer()
                }

                AutomationSentence(automation: automation)

                HStack(spacing: Theme.Spacing.s) {
                    Button {
                        store.acceptSuggestion()
                    } label: {
                        Text(lang.t(.autoAccept))
                            .font(.iaCardTitle)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s + 4)
                            .background(Theme.Palette.accent,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                             style: .continuous))
                    }
                    .buttonStyle(.push)

                    Button {
                        editing = automation
                        store.discardSuggestion()
                    } label: {
                        Text(lang.t(.autoRefine))
                            .font(.iaCardTitle)
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s + 4)
                            .background(Theme.Palette.accentWash,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                             style: .continuous))
                    }
                    .buttonStyle(.push)

                    Button {
                        store.discardSuggestion()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .frame(width: 46, height: 46)
                            .background(Theme.Palette.surfaceSunken,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                             style: .continuous))
                    }
                    .buttonStyle(.pushSubtle)
                    .accessibilityLabel(lang.t(.autoDiscard))
                }
            }
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .animation(Theme.Motion.standard, value: store.suggestion)
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(lang.t(.autoTitle)) {
                Button {
                    editing = Automation(name: lang.t(.autoNew),
                                         trigger: .tongueDown,
                                         actions: [.scrollNext])
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(width: 32, height: 32)
                        .background(Theme.Palette.accentWash, in: Circle())
                }
                .buttonStyle(.pushSubtle)
                .accessibilityLabel(lang.t(.autoNew))
            }

            if store.automations.isEmpty {
                Card {
                    EmptyState(icon: "wand.and.stars",
                               title: lang.t(.autoEmpty),
                               message: lang.t(.autoEmptyBody))
                }
            } else {
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(store.automations) { automation in
                        AutomationRow(automation: automation) {
                            editing = automation
                        }
                    }
                }
            }
        }
    }
}

/// Renders an automation as a readable sentence with chips.
struct AutomationSentence: View {
    @EnvironmentObject private var lang: LanguageManager
    let automation: Automation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                Chip(text: automation.trigger.name(lang),
                     icon: automation.trigger.icon,
                     tint: Theme.Palette.accent)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Palette.textTertiary)

                ForEach(automation.actions) { action in
                    Chip(text: action.name(lang), icon: action.icon, tint: Theme.Palette.success)
                }
            }

            if automation.condition != .always {
                Chip(text: automation.condition.name(lang),
                     icon: "line.3.horizontal.decrease.circle",
                     tint: Theme.Palette.warning)
            }
        }
    }
}

private struct AutomationRow: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var store: AutomationStore
    let automation: Automation
    let onEdit: () -> Void

    var body: some View {
        Card(padding: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(automation.name)
                            .font(.iaCardTitle)
                            .foregroundStyle(automation.isEnabled ? Theme.Palette.textPrimary
                                                                  : Theme.Palette.textTertiary)
                        Text("\(automation.runCount) \(lang.t(.autoRuns))")
                            .font(.iaCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { automation.isEnabled },
                        set: { store.setEnabled(automation.id, $0) }
                    ))
                    .labelsHidden()
                    .tint(Theme.Palette.accent)
                }

                AutomationSentence(automation: automation)
                    .opacity(automation.isEnabled ? 1 : 0.5)

                HStack(spacing: Theme.Spacing.s) {
                    if automation.isExclusive {
                        Chip(text: lang.t(.autoExclusive),
                             icon: "exclamationmark.octagon.fill",
                             tint: Theme.Palette.danger)
                    }
                    if automation.priority != 0 {
                        Chip(text: "\(lang.t(.autoPriority)) \(automation.priority)",
                             tint: Theme.Palette.textSecondary)
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Text(lang.t(.edit))
                            .font(.iaMicro)
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    .buttonStyle(.pushSubtle)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button(lang.t(.autoDuplicate), systemImage: "plus.square.on.square") {
                store.duplicate(automation)
            }
            Button(lang.t(.autoDelete), systemImage: "trash", role: .destructive) {
                store.delete(automation)
            }
        }
    }
}
