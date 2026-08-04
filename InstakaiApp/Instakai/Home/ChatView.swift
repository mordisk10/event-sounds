import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Author { case user, assistant }
    let id = UUID()
    var author: Author
    var text: String
}

/// The deliberately quiet entry point to chat.
///
/// Voice is the primary input, so chat gets a single low-contrast line under
/// the microphone rather than a tab or a floating button. It is discoverable
/// for anyone who looks, and invisible to anyone who does not.
struct ChatHint: View {
    @EnvironmentObject private var lang: LanguageManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12, weight: .medium))
                Text(lang.t(.homeChatHint))
                    .font(.iaCaption)
            }
            .foregroundStyle(Theme.Palette.textTertiary)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Palette.surfaceSunken.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.pushSubtle)
    }
}

/// Full chat, presented as a sheet from `ChatHint`.
struct ChatView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isThinking = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                composer
            }
            .background(Theme.Palette.background)
            .navigationTitle(lang.t(.homeChatTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.t(.close)) { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.m) {
                    if messages.isEmpty {
                        EmptyState(icon: "text.bubble",
                                   title: lang.t(.homeChatTitle),
                                   message: lang.t(.homeChatEmpty))
                            .padding(.top, Theme.Spacing.xl)
                    }

                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }

                    if isThinking {
                        HStack {
                            TypingDots()
                            Spacer()
                        }
                        .id("thinking")
                    }
                }
                .padding(Theme.Spacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages) { _, _ in
                guard let last = messages.last else { return }
                withAnimation(Theme.Motion.standard) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.author == .user { Spacer(minLength: Theme.Spacing.xl) }

            Text(message.text)
                .font(.iaBody)
                .foregroundStyle(message.author == .user ? .white : Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background {
                    if message.author == .user {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.Palette.accent)
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.Palette.surface)
                    }
                }

            if message.author == .assistant { Spacer(minLength: Theme.Spacing.xl) }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var composer: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField(lang.t(.homeChatPlaceholder), text: $draft, axis: .vertical)
                .font(.iaBody)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background(Theme.Palette.surfaceSunken, in: Capsule())

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.Palette.accent, in: Circle())
            }
            .buttonStyle(.push)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.surface)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        withAnimation(Theme.Motion.standard) {
            messages.append(ChatMessage(author: .user, text: text))
            draft = ""
            isThinking = true
        }
        Haptics.impact(.light)

        // Placeholder reply. Wiring this to a model is a later step; the shape
        // of the exchange is what the UI needs to be right about now.
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(Theme.Motion.standard) {
                isThinking = false
                messages.append(ChatMessage(
                    author: .assistant,
                    text: lang.language == .turkish
                        ? "Bunu bir otomasyona çevirebilirim. Otomasyonlar sekmesinden düzenleyebilirsin."
                        : "I can turn that into an automation. You can edit it from the Automations tab."
                ))
            }
        }
    }
}

/// Three dots that pulse while a reply is being prepared.
private struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.Palette.textTertiary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.35 : 0.85)
                    .opacity(phase == index ? 1 : 0.5)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s + 2)
        .background(Theme.Palette.surface, in: Capsule())
        .task {
            // A timer rather than a repeating animation so all three dots stay
            // in one cycle instead of drifting apart.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
