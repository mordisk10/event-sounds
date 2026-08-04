import SwiftUI

/// The signed-out experience: welcome, sign in, sign up and password reset.
///
/// One screen with a segmented mode rather than a navigation stack — swapping
/// between "sign in" and "sign up" is the single most common action here, and a
/// push transition makes it feel like progress when it is really a toggle.
struct AuthFlowView: View {
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var lang: LanguageManager

    private enum Mode: Hashable { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordAgain = ""
    @State private var showsReset = false
    @State private var didAttemptSubmit = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header
                modePicker
                fields
                submitButton
                appleSection
                footer
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Palette.background)
        .sheet(isPresented: $showsReset) {
            PasswordResetView()
                .presentationDetents([.height(320)])
                .presentationCornerRadius(Theme.Radius.sheet)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Palette.accent, Theme.Palette.accentDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 74, height: 74)
                Image(systemName: "face.smiling")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.Palette.accent.opacity(0.32), radius: 20, y: 10)
            .padding(.top, Theme.Spacing.xxl)

            Text(lang.t(.authWelcomeTitle))
                .font(.iaTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(lang.t(.authWelcomeSubtitle))
                .font(.iaBody)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .multilineTextAlignment(.center)
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeTab(.signIn, title: lang.t(.authSignIn))
            modeTab(.signUp, title: lang.t(.authSignUp))
        }
        .padding(4)
        .background(Theme.Palette.surfaceSunken, in: Capsule())
    }

    private func modeTab(_ target: Mode, title: String) -> some View {
        Button {
            withAnimation(Theme.Motion.standard) {
                mode = target
                didAttemptSubmit = false
            }
        } label: {
            Text(title)
                .font(.iaCardTitle)
                .foregroundStyle(mode == target ? .white : Theme.Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background {
                    if mode == target {
                        Capsule().fill(Theme.Palette.accent)
                    }
                }
        }
        .buttonStyle(.pushSubtle)
    }

    private var fields: some View {
        VStack(spacing: Theme.Spacing.m) {
            if mode == .signUp {
                InputField(title: lang.t(.authName),
                           icon: "person",
                           textContentType: .name,
                           text: $name)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            InputField(title: lang.t(.authEmail),
                       icon: "envelope",
                       keyboard: .emailAddress,
                       textContentType: .emailAddress,
                       errorText: emailError,
                       text: $email)

            InputField(title: lang.t(.authPassword),
                       icon: "lock",
                       isSecure: true,
                       textContentType: mode == .signUp ? .newPassword : .password,
                       errorText: passwordError,
                       text: $password)

            if mode == .signUp {
                InputField(title: lang.t(.authPasswordAgain),
                           icon: "lock.rotation",
                           isSecure: true,
                           textContentType: .newPassword,
                           errorText: repeatError,
                           text: $passwordAgain)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if mode == .signIn {
                HStack {
                    Spacer()
                    Button(lang.t(.authForgot)) { showsReset = true }
                        .font(.iaCaption)
                        .foregroundStyle(Theme.Palette.accent)
                        .buttonStyle(.pushSubtle)
                }
            }
        }
        .animation(Theme.Motion.standard, value: mode)
    }

    private var submitButton: some View {
        PrimaryButton(title: mode == .signIn ? lang.t(.authSignIn) : lang.t(.authSignUp),
                      isLoading: auth.isWorking,
                      isEnabled: true) {
            didAttemptSubmit = true
            guard isFormValid else {
                Haptics.warning()
                return
            }
            Task {
                if mode == .signIn {
                    await auth.signIn(email: email, password: password)
                } else {
                    await auth.signUp(name: name, email: email, password: password)
                }
            }
        }
    }

    private var appleSection: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                line
                Text(lang.t(.authOr))
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                line
            }

            Button {
                Task { await auth.continueWithApple() }
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "apple.logo")
                    Text(lang.t(.authContinueWithApple)).font(.iaCardTitle)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.m + 2)
                .background(Color.black,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.control,
                                                 style: .continuous))
            }
            .buttonStyle(.push)
        }
    }

    private var line: some View {
        Rectangle().fill(Theme.Palette.separator).frame(height: 1)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button {
                withAnimation(Theme.Motion.standard) {
                    mode = mode == .signIn ? .signUp : .signIn
                    didAttemptSubmit = false
                }
            } label: {
                Text(mode == .signIn ? lang.t(.authNoAccount) : lang.t(.authHaveAccount))
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .buttonStyle(.pushSubtle)

            Text(lang.t(.authTermsNotice))
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
        }
    }

    // MARK: - Validation
    //
    // Errors only appear after the first submit attempt: showing "invalid
    // email" while somebody is still typing the third character is noise.

    private var emailError: String? {
        guard didAttemptSubmit, !AuthController.isValidEmail(email) else { return nil }
        return lang.t(.authInvalidEmail)
    }

    private var passwordError: String? {
        guard didAttemptSubmit, !AuthController.isValidPassword(password) else { return nil }
        return lang.t(.authShortPassword)
    }

    private var repeatError: String? {
        guard didAttemptSubmit, mode == .signUp, password != passwordAgain else { return nil }
        return lang.t(.authPasswordMismatch)
    }

    private var isFormValid: Bool {
        guard AuthController.isValidEmail(email), AuthController.isValidPassword(password) else {
            return false
        }
        if mode == .signUp {
            return password == passwordAgain && !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
}

/// Password reset, presented as a short sheet from the sign-in screen.
struct PasswordResetView: View {
    @EnvironmentObject private var auth: AuthController
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var didSend = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lang.t(.authForgotTitle))
                    .font(.iaHeadline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(lang.t(.authForgotBody))
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            InputField(title: lang.t(.authEmail),
                       icon: "envelope",
                       keyboard: .emailAddress,
                       textContentType: .emailAddress,
                       text: $email)

            if didSend {
                Label(lang.t(.authLinkSent), systemImage: "checkmark.circle.fill")
                    .font(.iaCaption)
                    .foregroundStyle(Theme.Palette.success)
                    .transition(.opacity)
            }

            PrimaryButton(title: lang.t(.authSendLink),
                          isLoading: auth.isWorking,
                          isEnabled: AuthController.isValidEmail(email)) {
                Task {
                    if await auth.sendResetLink(email: email) {
                        withAnimation(Theme.Motion.standard) { didSend = true }
                        Haptics.success()
                        try? await Task.sleep(for: .seconds(1.2))
                        dismiss()
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.screen)
        .background(Theme.Palette.background)
    }
}
