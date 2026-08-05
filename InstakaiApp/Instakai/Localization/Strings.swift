import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }

    var flag: String {
        switch self {
        case .turkish: return "🇹🇷"
        case .english: return "🇬🇧"
        }
    }
}

/// Every user-visible string in the app.
///
/// A plain enum plus a lookup table rather than `.strings` files: the app is
/// two-language and switchable at runtime, and `NSLocalizedString` resolves
/// against the *system* language, which would make an in-app language picker
/// fight the OS. This way the picker is authoritative.
enum S: String, CaseIterable {

    // Tabs
    case tabHome, tabAutomations, tabPlans, tabProfile

    // Auth
    case authWelcomeTitle, authWelcomeSubtitle
    case authSignIn, authSignUp, authEmail, authPassword, authPasswordAgain
    case authName, authForgot, authForgotTitle, authForgotBody, authSendLink
    case authNoAccount, authHaveAccount, authContinueWithApple, authOr
    case authTermsNotice, authSignOut, authSignOutConfirm, authSignOutMessage
    case authDeleteAccount, authDeleteConfirm, authDeleteMessage, authDeleteIrreversible
    case authInvalidEmail, authShortPassword, authPasswordMismatch, authLinkSent

    // Home
    case homeGreeting, homeSubtitle
    case homeMicIdlePush, homeMicIdleHold, homeMicListening, homeMicHoldHint
    case homeMicAccessibility
    case homeModePushToTalk, homeModeStayPut
    case homeModePushToTalkHint, homeModeStayPutHint
    case homeChatHint, homeChatTitle, homeChatPlaceholder, homeChatEmpty
    case homeWidgetsTitle, homeWidgetsSubtitle
    case homeSessionOn, homeSessionOff, homeStartSession, homeStopSession

    // Widgets on home
    case widgetScrollTitle, widgetScrollBody
    case widgetLikeTitle, widgetLikeBody
    case widgetVoiceTitle, widgetVoiceBody
    case widgetStreakTitle, widgetStreakBody

    // Automations
    case autoTitle, autoSubtitle, autoNew, autoEmpty, autoEmptyBody
    case autoActive, autoPaused, autoRuns, autoLastRun, autoNever
    case autoAskAI, autoAskAIPlaceholder, autoAskAIHint, autoGenerate, autoGenerating
    case autoSuggested, autoAccept, autoDiscard, autoRefine
    case autoTrigger, autoCondition, autoAction, autoAdvanced
    case autoName, autoDelete, autoDuplicate, autoTest, autoTestRunning
    case autoInfoTrigger, autoInfoCondition, autoInfoAction
    case autoInfoPriority, autoInfoCooldown, autoInfoExclusive
    case autoPriority, autoCooldown, autoExclusive
    case autoSimple, autoTechnical, autoShowTechnical, autoHideTechnical

    // Pricing
    case planTitle, planSubtitle, planMonthly, planYearly, planSave
    case planFreeName, planFreeBody, planProName, planProBody
    case planStudioName, planStudioBody
    case planCurrent, planChoose, planPopular, planPerMonth, planPerYear
    case planRestore, planCompare, planFeature

    // Profile
    case profileTitle, profileAccount, profileSettings, profileHelp
    case profileLegal, profileAbout, profileMember, profilePlan

    // Settings
    case setTitle, setLanguage, setAppearance, setHaptics, setSound
    case setIsland, setIslandBody, setCelebration, setCelebrationBody
    case setMicMode, setNotifications, setReset, setResetConfirm

    // Help & contact
    case helpTitle, helpSearch, helpFaq, helpContactUs, helpContactBody
    case helpSubject, helpMessage, helpSend, helpSent, helpAgentHours
    case helpChatWithAgent, helpEmailUs, helpStatus, helpStatusOk

    // FAQ
    case faqQ1, faqA1, faqQ2, faqA2, faqQ3, faqA3, faqQ4, faqA4

    // Legal
    case legalTitle, legalTerms, legalPrivacy, legalKvkk, legalLicenses
    case legalUpdated, legalContactData

    // Island / feedback
    case islandScrolled, islandLiked, islandSaved, islandStreak, islandListening

    // Generic
    case save, cancel, done, next, back, close, confirm, delete, edit
    case search, loading, error, retry, on, off, yes, no

    /// `(turkish, english)` for every key.
    ///
    /// Split across several dictionaries and merged rather than written as one
    /// literal: a single 200-entry literal is exactly the shape that makes the
    /// Swift type checker crawl, even with an explicit annotation.
    private static let table: [S: (String, String)] = {
        var merged = tabsAndAuth
        for chunk in [home, automations, pricing, profileAndSettings, helpLegalAndGeneric] {
            merged.merge(chunk) { current, _ in current }
        }
        return merged
    }()

    private static let tabsAndAuth: [S: (String, String)] = [
        .tabHome: ("Ana", "Home"),
        .tabAutomations: ("Otomasyon", "Automations"),
        .tabPlans: ("Planlar", "Plans"),
        .tabProfile: ("Profil", "Profile"),

        .authWelcomeTitle: ("Instakai'ye hoş geldin", "Welcome to Instakai"),
        .authWelcomeSubtitle: ("Yüzünle ve sesinle kontrol et.", "Control it with your face and voice."),
        .authSignIn: ("Giriş yap", "Sign in"),
        .authSignUp: ("Hesap oluştur", "Create account"),
        .authEmail: ("E-posta", "Email"),
        .authPassword: ("Parola", "Password"),
        .authPasswordAgain: ("Parola (tekrar)", "Password (again)"),
        .authName: ("Ad", "Name"),
        .authForgot: ("Parolamı unuttum", "Forgot password"),
        .authForgotTitle: ("Parola sıfırlama", "Reset password"),
        .authForgotBody: ("E-posta adresini gir, sıfırlama bağlantısı gönderelim.",
                          "Enter your email and we'll send a reset link."),
        .authSendLink: ("Bağlantı gönder", "Send link"),
        .authNoAccount: ("Hesabın yok mu?", "No account yet?"),
        .authHaveAccount: ("Zaten hesabın var mı?", "Already have an account?"),
        .authContinueWithApple: ("Apple ile devam et", "Continue with Apple"),
        .authOr: ("veya", "or"),
        .authTermsNotice: ("Devam ederek Kullanım Koşulları'nı ve Gizlilik Politikası'nı kabul edersin.",
                           "By continuing you accept the Terms of Use and Privacy Policy."),
        .authSignOut: ("Çıkış yap", "Sign out"),
        .authSignOutConfirm: ("Çıkış yapılsın mı?", "Sign out?"),
        .authSignOutMessage: ("Otomasyonların cihazda kalır, tekrar giriş yapınca geri gelir.",
                              "Your automations stay on device and return when you sign back in."),
        .authDeleteAccount: ("Hesabı sil", "Delete account"),
        .authDeleteConfirm: ("Hesap silinsin mi?", "Delete account?"),
        .authDeleteMessage: ("Hesabın, otomasyonların ve aboneliğin kalıcı olarak silinir.",
                             "Your account, automations and subscription are permanently deleted."),
        .authDeleteIrreversible: ("Bu işlem geri alınamaz.", "This cannot be undone."),
        .authInvalidEmail: ("Geçerli bir e-posta gir.", "Enter a valid email."),
        .authShortPassword: ("Parola en az 8 karakter olmalı.", "Password must be at least 8 characters."),
        .authPasswordMismatch: ("Parolalar eşleşmiyor.", "Passwords don't match."),
        .authLinkSent: ("Bağlantı gönderildi.", "Link sent.")
    ]

    private static let home: [S: (String, String)] = [
        .homeGreeting: ("Selam", "Hey"),
        .homeMicAccessibility: ("Mikrofon", "Microphone"),
        .homeSubtitle: ("Konuşarak ya da yazarak başla.", "Start by speaking or typing."),
        .homeMicIdlePush: ("Konuşmak için basılı tut", "Hold to talk"),
        .homeMicIdleHold: ("Başlatmak için dokun", "Tap to start"),
        .homeMicListening: ("Dinliyorum…", "Listening…"),
        .homeMicHoldHint: ("Bırakınca gönderilir", "Releases when you let go"),
        .homeModePushToTalk: ("Bas-konuş", "Push to talk"),
        .homeModeStayPut: ("Sabit", "Stay put"),
        .homeModePushToTalkHint: ("Parmağını basılı tuttuğun sürece dinler.",
                                  "Listens while your finger stays down."),
        .homeModeStayPutHint: ("Bir kez dokun, açık kalır. Tekrar dokununca durur.",
                               "Tap once and it stays on. Tap again to stop."),
        .homeChatHint: ("Yazarak da anlatabilirsin", "You can type instead"),
        .homeChatTitle: ("Sohbet", "Chat"),
        .homeChatPlaceholder: ("Bir şey yaz…", "Type something…"),
        .homeChatEmpty: ("Ne yapmak istediğini yaz, otomasyona çevirelim.",
                         "Describe what you want and we'll turn it into an automation."),
        .homeWidgetsTitle: ("Bugün", "Today"),
        .homeWidgetsSubtitle: ("Kaydırarak gez", "Swipe to browse"),
        .homeSessionOn: ("Oturum açık", "Session on"),
        .homeSessionOff: ("Oturum kapalı", "Session off"),
        .homeStartSession: ("Oturumu başlat", "Start session"),
        .homeStopSession: ("Oturumu durdur", "Stop session"),

        .widgetScrollTitle: ("Kaydırma", "Scrolling"),
        .widgetScrollBody: ("Bugün 128 kaydırma", "128 scrolls today"),
        .widgetLikeTitle: ("Beğeni", "Likes"),
        .widgetLikeBody: ("Hareketle 12 beğeni", "12 likes by gesture"),
        .widgetVoiceTitle: ("Ses komutu", "Voice commands"),
        .widgetVoiceBody: ("9 komut çalıştı", "9 commands ran"),
        .widgetStreakTitle: ("Seri", "Streak"),
        .widgetStreakBody: ("4 gündür kesintisiz", "4 days unbroken")
    ]

    private static let automations: [S: (String, String)] = [
        .autoTitle: ("Otomasyonlar", "Automations"),
        .autoSubtitle: ("Hareket ve komutlarını buradan kurarsın.",
                        "Set up your gestures and commands here."),
        .autoNew: ("Yeni otomasyon", "New automation"),
        .autoEmpty: ("Henüz otomasyon yok", "No automations yet"),
        .autoEmptyBody: ("Aşağıdaki kutuya ne istediğini yaz, senin için kuralım.",
                         "Describe what you want in the box below and we'll build it."),
        .autoActive: ("Açık", "Active"),
        .autoPaused: ("Duraklatıldı", "Paused"),
        .autoRuns: ("çalışma", "runs"),
        .autoLastRun: ("Son çalışma", "Last run"),
        .autoNever: ("hiç", "never"),
        .autoAskAI: ("Yapay zekâya anlat", "Describe it to AI"),
        .autoAskAIPlaceholder: ("örn. dilimi aşağı uzatınca kaydır",
                                "e.g. scroll when I point my tongue down"),
        .autoAskAIHint: ("Normal cümleyle yaz; tetikleyici, koşul ve eylemi ayırırız.",
                         "Write it plainly; we'll split out the trigger, condition and action."),
        .autoGenerate: ("Oluştur", "Generate"),
        .autoGenerating: ("Hazırlanıyor…", "Preparing…"),
        .autoSuggested: ("Önerilen otomasyon", "Suggested automation"),
        .autoAccept: ("Ekle", "Add"),
        .autoDiscard: ("Vazgeç", "Discard"),
        .autoRefine: ("Değiştir", "Adjust"),
        .autoTrigger: ("Tetikleyici", "Trigger"),
        .autoCondition: ("Koşul", "Condition"),
        .autoAction: ("Eylem", "Action"),
        .autoAdvanced: ("Gelişmiş", "Advanced"),
        .autoName: ("Ad", "Name"),
        .autoDelete: ("Otomasyonu sil", "Delete automation"),
        .autoDuplicate: ("Çoğalt", "Duplicate"),
        .autoTest: ("Dene", "Test"),
        .autoTestRunning: ("Deneniyor…", "Testing…"),
        .autoInfoTrigger: ("Otomasyonu başlatan hareket ya da komut. Örneğin dili aşağı uzatmak.",
                           "The gesture or command that starts it — for example pointing your tongue down."),
        .autoInfoCondition: ("Hareket yeterli değilse ek şart. Örneğin yalnızca Reels'teyken.",
                             "An extra requirement on top of the gesture — for example only while in Reels."),
        .autoInfoAction: ("Şartlar sağlanınca yapılacak iş. Birden fazla adım ekleyebilirsin.",
                          "What happens once the conditions hold. You can chain several steps."),
        .autoInfoPriority: ("Aynı anda birden fazla otomasyon uyarsa yüksek öncelikli olan kazanır.",
                            "If several automations match at once, the higher priority one wins."),
        .autoInfoCooldown: ("Aynı otomasyonun tekrar çalışması için beklemesi gereken süre.",
                            "How long this automation waits before it can run again."),
        .autoInfoExclusive: ("Açıkken bu otomasyon çalıştığında daha düşük öncelikliler susar.",
                             "When on, running this automation silences lower-priority ones."),
        .autoPriority: ("Öncelik", "Priority"),
        .autoCooldown: ("Bekleme", "Cooldown"),
        .autoExclusive: ("Yalnızca bu", "Exclusive"),
        .autoSimple: ("Basit", "Simple"),
        .autoTechnical: ("Teknik", "Technical"),
        .autoShowTechnical: ("Teknik ayarları göster", "Show technical settings"),
        .autoHideTechnical: ("Teknik ayarları gizle", "Hide technical settings")
    ]

    private static let pricing: [S: (String, String)] = [
        .planTitle: ("Planlar", "Plans"),
        .planSubtitle: ("İstediğin zaman değiştir ya da iptal et.", "Change or cancel any time."),
        .planMonthly: ("Aylık", "Monthly"),
        .planYearly: ("Yıllık", "Yearly"),
        .planSave: ("2 ay bedava", "2 months free"),
        .planFreeName: ("Başlangıç", "Starter"),
        .planFreeBody: ("3 otomasyon, temel hareketler", "3 automations, core gestures"),
        .planProName: ("Pro", "Pro"),
        .planProBody: ("Sınırsız otomasyon, yapay zekâ kurulumu, Dynamic Island",
                       "Unlimited automations, AI setup, Dynamic Island"),
        .planStudioName: ("Studio", "Studio"),
        .planStudioBody: ("Pro'daki her şey, öncelikli destek, erken özellikler",
                          "Everything in Pro, priority support, early features"),
        .planCurrent: ("Mevcut plan", "Current plan"),
        .planChoose: ("Bu planı seç", "Choose this plan"),
        .planPopular: ("En çok seçilen", "Most popular"),
        .planPerMonth: ("/ay", "/mo"),
        .planPerYear: ("/yıl", "/yr"),
        .planRestore: ("Satın alımları geri yükle", "Restore purchases"),
        .planCompare: ("Planları karşılaştır", "Compare plans"),
        .planFeature: ("Özellik", "Feature")
    ]

    private static let profileAndSettings: [S: (String, String)] = [
        .profileTitle: ("Profil", "Profile"),
        .profileAccount: ("Hesap", "Account"),
        .profileSettings: ("Ayarlar", "Settings"),
        .profileHelp: ("Yardım ve destek", "Help & support"),
        .profileLegal: ("Yasal", "Legal"),
        .profileAbout: ("Hakkında", "About"),
        .profileMember: ("Üyelik", "Membership"),
        .profilePlan: ("Plan", "Plan"),

        .setTitle: ("Ayarlar", "Settings"),
        .setLanguage: ("Dil", "Language"),
        .setAppearance: ("Görünüm", "Appearance"),
        .setHaptics: ("Titreşim", "Haptics"),
        .setSound: ("Ses", "Sound"),
        .setIsland: ("Dynamic Island", "Dynamic Island"),
        .setIslandBody: ("Hareket tanındığında ekranın üstünde geri bildirim göster.",
                         "Show feedback at the top of the screen when a gesture is recognised."),
        .setCelebration: ("Kutlama efekti", "Celebration effect"),
        .setCelebrationBody: ("Seri ve kilometre taşlarında parçacık patlaması.",
                              "A particle burst on streaks and milestones."),
        .setMicMode: ("Varsayılan mikrofon modu", "Default microphone mode"),
        .setNotifications: ("Bildirimler", "Notifications"),
        .setReset: ("Ayarları sıfırla", "Reset settings"),
        .setResetConfirm: ("Tüm ayarlar varsayılana dönsün mü?", "Reset all settings to default?")
    ]

    private static let helpLegalAndGeneric: [S: (String, String)] = [
        .helpTitle: ("Yardım ve destek", "Help & support"),
        .helpSearch: ("Yardımda ara", "Search help"),
        .helpFaq: ("Sık sorulanlar", "Frequently asked"),
        .helpContactUs: ("Bize ulaş", "Contact us"),
        .helpContactBody: ("Cevap veremediğimiz soru kalmasın.", "Let's not leave a question unanswered."),
        .helpSubject: ("Konu", "Subject"),
        .helpMessage: ("Mesajın", "Your message"),
        .helpSend: ("Gönder", "Send"),
        .helpSent: ("Mesajın alındı. En geç 24 saat içinde döneriz.",
                    "We got your message. We'll reply within 24 hours."),
        .helpAgentHours: ("Hafta içi 09:00–18:00", "Weekdays 09:00–18:00"),
        .helpChatWithAgent: ("Temsilciyle görüş", "Chat with an agent"),
        .helpEmailUs: ("E-posta gönder", "Email us"),
        .helpStatus: ("Sistem durumu", "System status"),
        .helpStatusOk: ("Tüm sistemler çalışıyor", "All systems operational"),

        .faqQ1: ("Hareketler neden bazen tanınmıyor?", "Why is a gesture sometimes missed?"),
        .faqA1: ("Işık az olduğunda kamera yüzü daha zor okur. Ayarlar'dan hassasiyeti yükseltmeyi dene.",
                 "In low light the camera reads your face less reliably. Try raising sensitivity in Settings."),
        .faqQ2: ("Aboneliğimi nasıl iptal ederim?", "How do I cancel my subscription?"),
        .faqA2: ("Planlar sekmesinden ya da iPhone Ayarlar → Apple Kimliği → Abonelikler yolundan iptal edebilirsin.",
                 "From the Plans tab, or via iPhone Settings → Apple ID → Subscriptions."),
        .faqQ3: ("Verilerim nereye gidiyor?", "Where does my data go?"),
        .faqA3: ("Kamera görüntüsü cihazdan çıkmaz. Yalnızca hesap bilgin ve otomasyon adların sunucuda tutulur.",
                 "Camera frames never leave the device. Only your account details and automation names are stored."),
        .faqQ4: ("Bir otomasyonu nasıl geçici olarak kapatırım?", "How do I pause an automation?"),
        .faqA4: ("Otomasyonlar sekmesinde satırdaki anahtarı kapat. Silmene gerek yok.",
                 "Flip the switch on its row in the Automations tab. No need to delete it."),

        .legalTitle: ("Yasal", "Legal"),
        .legalTerms: ("Kullanım Koşulları", "Terms of Use"),
        .legalPrivacy: ("Gizlilik Politikası", "Privacy Policy"),
        .legalKvkk: ("KVKK Aydınlatma Metni", "Data Protection Notice"),
        .legalLicenses: ("Açık kaynak lisansları", "Open source licences"),
        .legalUpdated: ("Son güncelleme", "Last updated"),
        .legalContactData: ("Veri sorumlusuna başvuru", "Contact the data controller"),

        .islandScrolled: ("Kaydırıldı", "Scrolled"),
        .islandLiked: ("Beğenildi", "Liked"),
        .islandSaved: ("Kaydedildi", "Saved"),
        .islandStreak: ("Seri sürüyor", "Streak going"),
        .islandListening: ("Dinliyor", "Listening"),

        .save: ("Kaydet", "Save"),
        .cancel: ("Vazgeç", "Cancel"),
        .done: ("Bitti", "Done"),
        .next: ("İleri", "Next"),
        .back: ("Geri", "Back"),
        .close: ("Kapat", "Close"),
        .confirm: ("Onayla", "Confirm"),
        .delete: ("Sil", "Delete"),
        .edit: ("Düzenle", "Edit"),
        .search: ("Ara", "Search"),
        .loading: ("Yükleniyor…", "Loading…"),
        .error: ("Bir şeyler ters gitti", "Something went wrong"),
        .retry: ("Tekrar dene", "Try again"),
        .on: ("Açık", "On"),
        .off: ("Kapalı", "Off"),
        .yes: ("Evet", "Yes"),
        .no: ("Hayır", "No")
    ]

    func value(for language: AppLanguage) -> String {
        guard let entry = S.table[self] else {
            // Missing entries must be loud in debug and harmless in release.
            assertionFailure("Eksik çeviri / missing translation: \(rawValue)")
            return rawValue
        }
        return language == .turkish ? entry.0 : entry.1
    }
}
