import SwiftUI

/// The signed-in user.
struct Account: Codable, Equatable {
    var name: String
    var email: String
    var plan: PlanTier
    var memberSince: Date

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

/// Owns session state and the validation rules the auth screens share.
///
/// This is a UI-layer stand-in: there is no network call yet, and the
/// "authentication" simply validates input and persists a session locally. The
/// screens talk only to this object, so swapping in a real backend later means
/// changing the four `async` methods below and nothing else.
@MainActor
final class AuthController: ObservableObject {

    enum State: Equatable {
        case signedOut
        case signedIn(Account)
    }

    @Published private(set) var state: State = .signedOut
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let storageKey = "app.account"

    init() {
        restoreSession()
    }

    var account: Account? {
        if case .signedIn(let account) = state { return account }
        return nil
    }

    var isSignedIn: Bool { account != nil }

    // MARK: - Validation
    //
    // Kept here rather than in the views so sign-in, sign-up and password reset
    // all agree on what "valid" means.

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        // Deliberately loose: one @, at least one dot after it, no spaces.
        // Anything stricter rejects addresses that are actually deliverable.
        guard !trimmed.contains(" "), trimmed.count >= 6 else { return false }
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        return parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    // MARK: - Actions

    func signIn(email: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        try? await Task.sleep(for: .milliseconds(600))

        let account = Account(
            name: Self.displayName(from: email),
            email: email.trimmingCharacters(in: .whitespaces),
            plan: .free,
            memberSince: Date()
        )
        persist(account)
        state = .signedIn(account)
        Haptics.success()
    }

    func signUp(name: String, email: String, password: String) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        try? await Task.sleep(for: .milliseconds(700))

        let account = Account(
            name: name.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            plan: .free,
            memberSince: Date()
        )
        persist(account)
        state = .signedIn(account)
        Haptics.success()
    }

    func continueWithApple() async {
        isWorking = true
        defer { isWorking = false }
        try? await Task.sleep(for: .milliseconds(500))

        // A real integration goes through `AuthenticationServices` and may
        // return a private relay address with no name on repeat sign-ins.
        let account = Account(name: "Instakai", email: "gizli@privaterelay.appleid.com",
                              plan: .free, memberSince: Date())
        persist(account)
        state = .signedIn(account)
        Haptics.success()
    }

    func sendResetLink(email: String) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        try? await Task.sleep(for: .milliseconds(500))
        return Self.isValidEmail(email)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        state = .signedOut
        Haptics.warning()
    }

    /// Removes the account and every local trace of it.
    func deleteAccount() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        state = .signedOut
        Haptics.warning()
    }

    func updatePlan(_ plan: PlanTier) {
        guard var account = self.account else { return }
        account.plan = plan
        persist(account)
        state = .signedIn(account)
    }

    // MARK: - Persistence

    private func persist(_ account: Account) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let account = try? JSONDecoder().decode(Account.self, from: data) else { return }
        state = .signedIn(account)
    }

    /// Turns `ada.yilmaz@example.com` into `Ada Yilmaz` for the greeting.
    private static func displayName(from email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "Instakai"
        return local
            .split(whereSeparator: { ".-_".contains($0) })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
