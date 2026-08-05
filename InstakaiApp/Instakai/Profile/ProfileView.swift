import SwiftUI

/// The fourth tab. Holds everything that did not earn its own tab: account,
/// settings, help and legal.
struct ProfileView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var auth: AuthController

    @State private var showsSignOutConfirm = false
    @State private var showsDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    accountCard
                    membershipCard
                    navigationCard
                    sessionActions
                    versionFooter
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.tabBarClearance)
            }
            .background(Theme.Palette.background)
            .navigationTitle(lang.t(.profileTitle))
            .confirmationDialog(lang.t(.authSignOutConfirm),
                                isPresented: $showsSignOutConfirm,
                                titleVisibility: .visible) {
                Button(lang.t(.authSignOut), role: .destructive) { auth.signOut() }
                Button(lang.t(.cancel), role: .cancel) {}
            } message: {
                Text(lang.t(.authSignOutMessage))
            }
            .confirmationDialog(lang.t(.authDeleteConfirm),
                                isPresented: $showsDeleteConfirm,
                                titleVisibility: .visible) {
                Button(lang.t(.authDeleteAccount), role: .destructive) { auth.deleteAccount() }
                Button(lang.t(.cancel), role: .cancel) {}
            } message: {
                Text("\(lang.t(.authDeleteMessage)) \(lang.t(.authDeleteIrreversible))")
            }
        }
    }

    // MARK: - Cards

    private var accountCard: some View {
        Card {
            HStack(spacing: Theme.Spacing.m) {
                Text(auth.account?.initials ?? "?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [Theme.Palette.accent, Theme.Palette.accentDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.account?.name ?? "")
                        .font(.iaHeadline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(auth.account?.email ?? "")
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    private var membershipCard: some View {
        Card(padding: Theme.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(.profileMember))
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(auth.account?.plan.name(lang) ?? "")
                        .font(.iaCardTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
                if let since = auth.account?.memberSince {
                    Text(since.formatted(date: .abbreviated, time: .omitted))
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
    }

    private var navigationCard: some View {
        Card(padding: Theme.Spacing.s) {
            VStack(spacing: 0) {
                NavigationLink {
                    SettingsView()
                } label: {
                    navRowLabel(icon: "gearshape.fill", title: lang.t(.profileSettings))
                }
                .buttonStyle(.pushSubtle)

                RowDivider()

                NavigationLink {
                    HelpView()
                } label: {
                    navRowLabel(icon: "questionmark.circle.fill", title: lang.t(.profileHelp))
                }
                .buttonStyle(.pushSubtle)

                RowDivider()

                NavigationLink {
                    LegalView()
                } label: {
                    navRowLabel(icon: "doc.text.fill", title: lang.t(.profileLegal))
                }
                .buttonStyle(.pushSubtle)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    /// `NavigationLink` cannot take `NavRow` directly (that is a Button), so the
    /// row body is shared through this helper instead.
    private func navRowLabel(icon: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 30, height: 30)
                .background(Theme.Palette.accentWash,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(.iaBody)
                .foregroundStyle(Theme.Palette.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.m)
        .contentShape(Rectangle())
    }

    private var sessionActions: some View {
        VStack(spacing: Theme.Spacing.m) {
            SecondaryButton(title: lang.t(.authSignOut), icon: "rectangle.portrait.and.arrow.right") {
                showsSignOutConfirm = true
            }

            Button {
                showsDeleteConfirm = true
            } label: {
                Text(lang.t(.authDeleteAccount))
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.danger)
            }
            .buttonStyle(.pushSubtle)
        }
    }

    private var versionFooter: some View {
        Text("Instakai 1.0 (1)")
            .font(.system(size: 11))
            .foregroundStyle(Theme.Palette.textTertiary)
            .frame(maxWidth: .infinity)
    }
}
