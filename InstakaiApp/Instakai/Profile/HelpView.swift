import SwiftUI

/// Help, FAQ and the contact form, in that order.
///
/// Self-service first: the FAQ is above the contact form because most questions
/// are answered there, and burying it under a form guarantees tickets nobody
/// needed to file.
struct HelpView: View {
    @EnvironmentObject private var lang: LanguageManager

    @State private var query = ""
    @State private var expandedQuestion: Int?
    @State private var showsContact = false

    private var faq: [(question: S, answer: S)] {
        [(.faqQ1, .faqA1), (.faqQ2, .faqA2), (.faqQ3, .faqA3), (.faqQ4, .faqA4)]
    }

    private var filteredFaq: [(index: Int, question: S, answer: S)] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        return faq.enumerated().compactMap { index, entry in
            guard trimmed.isEmpty
                    || lang.t(entry.question).lowercased().contains(trimmed)
                    || lang.t(entry.answer).lowercased().contains(trimmed) else { return nil }
            return (index, entry.question, entry.answer)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                statusCard
                searchField
                faqCard
                contactCard
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Palette.background)
        .navigationTitle(lang.t(.helpTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsContact) {
            ContactView()
        }
    }

    private var statusCard: some View {
        Card(padding: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Circle()
                    .fill(Theme.Palette.success)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lang.t(.helpStatus))
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(lang.t(.helpStatusOk))
                        .font(.iaCardTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textTertiary)
            TextField(lang.t(.helpSearch), text: $query)
                .font(.iaBody)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .buttonStyle(.pushSubtle)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(lang.t(.helpFaq))

            if filteredFaq.isEmpty {
                Card {
                    EmptyState(icon: "magnifyingglass",
                               title: lang.t(.helpSearch),
                               message: lang.t(.helpContactBody))
                }
            } else {
                Card(padding: Theme.Spacing.s) {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredFaq.enumerated()), id: \.element.index) { position, entry in
                            faqRow(index: entry.index,
                                   question: entry.question,
                                   answer: entry.answer)
                            if position < filteredFaq.count - 1 {
                                Rectangle()
                                    .fill(Theme.Palette.separator)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func faqRow(index: Int, question: S, answer: S) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button {
                withAnimation(Theme.Motion.standard) {
                    expandedQuestion = expandedQuestion == index ? nil : index
                }
            } label: {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Text(lang.t(question))
                        .font(.iaBody)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Theme.Spacing.s)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .rotationEffect(.degrees(expandedQuestion == index ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pushSubtle)

            if expandedQuestion == index {
                Text(lang.t(answer))
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.m)
    }

    private var contactCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.helpContactUs), subtitle: lang.t(.helpContactBody))

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(lang.t(.helpAgentHours))
                        .font(.iaCaption)
                }
                .foregroundStyle(Theme.Palette.textTertiary)

                PrimaryButton(title: lang.t(.helpChatWithAgent), icon: "headphones") {
                    showsContact = true
                }

                SecondaryButton(title: lang.t(.helpEmailUs), icon: "envelope") {
                    showsContact = true
                }
            }
        }
    }
}

/// The contact form.
struct ContactView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var auth: AuthController
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var message = ""
    @State private var didSend = false
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if didSend {
                        sentState
                    } else {
                        form
                    }
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.Palette.background)
            .navigationTitle(lang.t(.helpContactUs))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t(.close)) { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    // Prefilled and locked: support needs a reachable address,
                    // and the account already has one.
                    HStack {
                        Text(lang.t(.authEmail))
                            .font(.iaCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                        Text(auth.account?.email ?? "")
                            .font(.iaCaption)
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }

                    RowDivider()

                    InputField(title: lang.t(.helpSubject), icon: "text.alignleft", text: $subject)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t(.helpMessage))
                            .font(.iaCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        TextEditor(text: $message)
                            .font(.iaBody)
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.s)
                            .background(Theme.Palette.surfaceSunken,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                             style: .continuous))
                    }
                }
            }

            PrimaryButton(title: lang.t(.helpSend),
                          icon: "paperplane.fill",
                          isLoading: isSending,
                          isEnabled: !subject.isEmpty && message.count >= 10) {
                send()
            }
        }
    }

    private var sentState: some View {
        Card {
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.Palette.success)
                Text(lang.t(.helpSent))
                    .font(.iaBody)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                SecondaryButton(title: lang.t(.close)) { dismiss() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.l)
        }
    }

    private func send() {
        isSending = true
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            isSending = false
            withAnimation(Theme.Motion.standard) { didSend = true }
            Haptics.success()
        }
    }
}
