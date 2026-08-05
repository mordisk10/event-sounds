import SwiftUI

/// Index of the legal documents, each opening as a scrollable text screen.
struct LegalView: View {
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Card(padding: Theme.Spacing.s) {
                    VStack(spacing: 0) {
                        legalLink(.legalTerms, icon: "doc.text", document: .terms)
                        RowDivider()
                        legalLink(.legalPrivacy, icon: "hand.raised", document: .privacy)
                        RowDivider()
                        legalLink(.legalKvkk, icon: "checkmark.shield", document: .dataProtection)
                        RowDivider()
                        legalLink(.legalLicenses, icon: "shippingbox", document: .licences)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }

                Text("\(lang.t(.legalUpdated)): 2026-08-04")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Palette.background)
        .navigationTitle(lang.t(.legalTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalLink(_ title: S, icon: String, document: LegalDocument) -> some View {
        NavigationLink {
            LegalDocumentView(document: document)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 30, height: 30)
                    .background(Theme.Palette.accentWash,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(lang.t(title))
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
        .buttonStyle(.pushSubtle)
    }
}

/// Which document to render.
enum LegalDocument: Identifiable {
    case terms, privacy, dataProtection, licences

    var id: String {
        switch self {
        case .terms: return "terms"
        case .privacy: return "privacy"
        case .dataProtection: return "kvkk"
        case .licences: return "licences"
        }
    }

    var titleKey: S {
        switch self {
        case .terms: return .legalTerms
        case .privacy: return .legalPrivacy
        case .dataProtection: return .legalKvkk
        case .licences: return .legalLicenses
        }
    }
}

/// Renders a document as headed sections.
///
/// The bodies below are **placeholder copy for layout only**. Shipping legal
/// text has to be written or reviewed by a lawyer — see `docs/OPEN-QUESTIONS.md`.
struct LegalDocumentView: View {
    @EnvironmentObject private var lang: LanguageManager
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                placeholderNotice

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            Text(section.heading)
                                .font(.iaCardTitle)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(section.body)
                                .font(.iaCaption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Palette.background)
        .navigationTitle(lang.t(document.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholderNotice: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Palette.warning)
            Text(lang.language == .turkish
                 ? "Bu metin yalnızca yerleşim içindir. Yayına çıkmadan önce hukukçu tarafından yazılmalıdır."
                 : "This copy is layout placeholder only. It must be written by a lawyer before release.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.warning.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    private var sections: [(heading: String, body: String)] {
        let turkish = lang.language == .turkish
        switch document {
        case .terms:
            return turkish
                ? [("Hizmetin kapsamı", "Instakai, yüz ve ses hareketlerini uygulama içi eylemlere bağlayan bir yardımcı araçtır."),
                   ("Hesap sorumluluğu", "Hesabınızın güvenliğinden ve hesabınız altında yapılan işlemlerden siz sorumlusunuz."),
                   ("Kabul edilebilir kullanım", "Uygulamayı üçüncü tarafların kullanım şartlarını ihlal edecek biçimde kullanamazsınız."),
                   ("Abonelik ve iptal", "Abonelikler dönem sonunda otomatik yenilenir; App Store üzerinden iptal edilebilir."),
                   ("Sorumluluğun sınırı", "Hizmet olduğu gibi sunulur; kesintisiz veya hatasız çalışacağı garanti edilmez.")]
                : [("Scope of service", "Instakai is an assistive tool that maps face and voice gestures to in-app actions."),
                   ("Account responsibility", "You are responsible for your account's security and for activity under it."),
                   ("Acceptable use", "You may not use the app in ways that breach a third party's terms of service."),
                   ("Subscriptions", "Subscriptions renew automatically and can be cancelled through the App Store."),
                   ("Limitation of liability", "The service is provided as is, with no guarantee of uninterrupted operation.")]

        case .privacy:
            return turkish
                ? [("Toplanan veriler", "Hesap bilgileriniz (ad, e-posta) ve otomasyon adlarınız saklanır."),
                   ("Kamera", "Kamera görüntüsü cihazdan çıkmaz, kaydedilmez ve sunucuya gönderilmez."),
                   ("Mikrofon", "Ses yalnızca komut tanıma sırasında işlenir ve işlem bitince silinir."),
                   ("Üçüncü taraflar", "Ödemeler Apple tarafından yürütülür; kart bilgileriniz bize ulaşmaz."),
                   ("Haklarınız", "Verilerinize erişme, düzeltme ve silme hakkınız vardır.")]
                : [("What we collect", "Your account details (name, email) and your automation names."),
                   ("Camera", "Camera frames never leave the device, are not recorded and are not uploaded."),
                   ("Microphone", "Audio is processed only during recognition and discarded afterwards."),
                   ("Third parties", "Payments are handled by Apple; card details never reach us."),
                   ("Your rights", "You can access, correct and delete your data.")]

        case .dataProtection:
            return turkish
                ? [("Veri sorumlusu", "Veri sorumlusu bilgileri yayın öncesi doldurulacaktır."),
                   ("İşleme amacı", "Kişisel verileriniz hesabınızın yönetilmesi ve destek sağlanması amacıyla işlenir."),
                   ("Hukuki sebep", "Sözleşmenin kurulması ve ifası ile meşru menfaat."),
                   ("Saklama süresi", "Hesabınız silindiğinde verileriniz de silinir."),
                   ("Başvuru", "Talepleriniz için Yardım ve destek bölümündeki iletişim formunu kullanabilirsiniz.")]
                : [("Data controller", "Controller details to be completed before release."),
                   ("Purpose", "Data is processed to operate your account and provide support."),
                   ("Legal basis", "Performance of a contract and legitimate interest."),
                   ("Retention", "Your data is deleted when your account is deleted."),
                   ("Requests", "Use the contact form under Help & support to reach us.")]

        case .licences:
            return [("SF Symbols", "© Apple Inc. Used under the SF Symbols licence."),
                    ("Swift & SwiftUI", "© Apple Inc."),
                    ("Instakai", "© 2026 Instakai. All rights reserved.")]
        }
    }
}
