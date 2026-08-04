import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var island: IslandCenter

    @AppStorage("app.haptics") private var hapticsEnabled = true
    @AppStorage("app.sound") private var soundEnabled = true
    @AppStorage("app.island") private var islandEnabled = true
    @AppStorage("app.celebration") private var celebrationEnabled = true
    @AppStorage("app.notifications") private var notificationsEnabled = true
    @AppStorage("app.micMode") private var storedMicMode = MicMode.pushToTalk.rawValue

    @State private var showsResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                languageCard
                feedbackCard
                islandCard
                micCard
                resetButton
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Palette.background)
        .navigationTitle(lang.t(.setTitle))
        .navigationBarTitleDisplayMode(.inline)
        // Keep the island centre in step with the switches, since it reads
        // these flags on every post rather than observing them.
        .onChange(of: islandEnabled) { _, new in island.isEnabled = new }
        .onChange(of: celebrationEnabled) { _, new in island.celebrationsEnabled = new }
        .onAppear {
            island.isEnabled = islandEnabled
            island.celebrationsEnabled = celebrationEnabled
        }
        .confirmationDialog(lang.t(.setResetConfirm),
                            isPresented: $showsResetConfirm,
                            titleVisibility: .visible) {
            Button(lang.t(.setReset), role: .destructive, action: resetAll)
            Button(lang.t(.cancel), role: .cancel) {}
        }
    }

    // MARK: - Cards

    private var languageCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.setLanguage))

                HStack(spacing: Theme.Spacing.s) {
                    ForEach(AppLanguage.allCases) { candidate in
                        Button {
                            withAnimation(Theme.Motion.standard) { lang.language = candidate }
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 6) {
                                Text(candidate.flag)
                                Text(candidate.displayName).font(.iaCardTitle)
                            }
                            .foregroundStyle(lang.language == candidate ? .white
                                                                        : Theme.Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.m)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                 style: .continuous)
                                    .fill(lang.language == candidate ? Theme.Palette.accent
                                                                     : Theme.Palette.surfaceSunken)
                            }
                        }
                        .buttonStyle(.pushSubtle)
                    }
                }
            }
        }
    }

    private var feedbackCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                SectionHeader(lang.t(.setAppearance))

                ToggleRow(icon: "iphone.radiowaves.left.and.right",
                          title: lang.t(.setHaptics),
                          isOn: $hapticsEnabled)
                RowDivider()
                ToggleRow(icon: "speaker.wave.2.fill",
                          title: lang.t(.setSound),
                          isOn: $soundEnabled)
                RowDivider()
                ToggleRow(icon: "bell.fill",
                          title: lang.t(.setNotifications),
                          isOn: $notificationsEnabled)
            }
        }
    }

    private var islandCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                SectionHeader(lang.t(.setIsland))

                ToggleRow(icon: "capsule.fill",
                          title: lang.t(.setIsland),
                          subtitle: lang.t(.setIslandBody),
                          isOn: $islandEnabled)

                RowDivider()

                ToggleRow(icon: "sparkles",
                          title: lang.t(.setCelebration),
                          subtitle: lang.t(.setCelebrationBody),
                          isOn: $celebrationEnabled)
                    .disabled(!islandEnabled)
                    .opacity(islandEnabled ? 1 : 0.45)

                // Lets the user see exactly what the setting does without
                // waiting for a real gesture to fire.
                Button {
                    island.post(IslandEvent(kind: .milestone(streak: 3),
                                            title: lang.t(.islandStreak),
                                            detail: "3"))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill").font(.system(size: 12))
                        Text(lang.t(.autoTest)).font(.iaMicro)
                    }
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .background(Theme.Palette.accentWash, in: Capsule())
                }
                .buttonStyle(.pushSubtle)
                .disabled(!islandEnabled)
            }
        }
    }

    private var micCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionHeader(lang.t(.setMicMode))

                ForEach(MicMode.allCases) { mode in
                    Button {
                        storedMicMode = mode.rawValue
                        Haptics.selection()
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(storedMicMode == mode.rawValue
                                                 ? Theme.Palette.accent
                                                 : Theme.Palette.textTertiary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(lang.t(mode.label))
                                    .font(.iaBody)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(lang.t(mode.hint))
                                    .font(.iaCaption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            if storedMicMode == mode.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.s)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pushSubtle)
                }
            }
        }
    }

    private var resetButton: some View {
        SecondaryButton(title: lang.t(.setReset), icon: "arrow.counterclockwise", role: .destructive) {
            showsResetConfirm = true
        }
    }

    private func resetAll() {
        hapticsEnabled = true
        soundEnabled = true
        islandEnabled = true
        celebrationEnabled = true
        notificationsEnabled = true
        storedMicMode = MicMode.pushToTalk.rawValue
        island.isEnabled = true
        island.celebrationsEnabled = true
        Haptics.warning()
    }
}
