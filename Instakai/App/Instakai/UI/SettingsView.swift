#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI
import UIKit
import InstakaiCore

struct SettingsView: View {
    @EnvironmentObject private var session: SessionController
    @State private var showsExport = false
    @State private var importText = ""
    @State private var showsImport = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                tuningSection
                engineSection
                calibrationSection
                transferSection
                aboutSection
            }
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $showsExport) {
                ExportSheet(json: session.exportActiveProfile())
            }
            .sheet(isPresented: $showsImport) {
                ImportSheet(text: $importText) {
                    session.importProfile(json: importText)
                    importText = ""
                }
            }
        }
    }

    private var profileSection: some View {
        Section("Profil") {
            Picker("Etkin profil", selection: Binding(
                get: { session.profile.id },
                set: { id in
                    if let match = session.profiles.first(where: { $0.id == id }) {
                        session.select(profile: match)
                    }
                }
            )) {
                ForEach(session.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }

            TextField("Profil adı", text: Binding(
                get: { session.profile.name },
                set: { name in session.updateProfile { $0.name = name } }
            ))

            Button("Profili çoğalt") { session.duplicateActiveProfile() }

            Button("Profili sil", role: .destructive) { session.deleteActiveProfile() }
                .disabled(session.profiles.count <= 1)
        }
    }

    private var tuningSection: some View {
        Section {
            SliderRow(title: "Yumuşatma",
                      value: Binding(
                        get: { session.profile.signalTuning.smoothing },
                        set: { value in session.updateProfile { $0.signalTuning.smoothing = value } }),
                      range: 0.05...1,
                      caption: "Yüksek = daha hızlı tepki, düşük = daha az titreşim")

            SliderRow(title: "Ölü bölge",
                      value: Binding(
                        get: { session.profile.signalTuning.deadzone },
                        set: { value in session.updateProfile { $0.signalTuning.deadzone = value } }),
                      range: 0...0.2,
                      caption: "Bu değerin altındaki okumalar sıfırlanır")

            SliderRow(title: "Dil kapısı",
                      value: Binding(
                        get: { session.profile.signalTuning.tongueGate },
                        set: { value in session.updateProfile { $0.signalTuning.tongueGate = value } }),
                      range: 0...0.8,
                      caption: "Dil bu kadar çıkmadan yön sinyalleri geçmez")

            SliderRow(title: "Güven kapısı",
                      value: Binding(
                        get: { session.profile.signalTuning.confidenceGate },
                        set: { value in session.updateProfile { $0.signalTuning.confidenceGate = value } }),
                      range: 0...0.9,
                      caption: "Yön tahmini bu güvenin altındaysa yok sayılır")
        } header: {
            Text("Sinyal ayarı")
        } footer: {
            Text("Yanlış tetikleme çoksa dil ve güven kapılarını yükseltin. " +
                 "Hareketler kaçıyorsa düşürün.")
        }
    }

    private var engineSection: some View {
        Section {
            SliderRow(title: "Genel bekleme (sn)",
                      value: Binding(
                        get: { session.profile.engineOptions.globalCooldown },
                        set: { value in session.updateProfile { $0.engineOptions.globalCooldown = value } }),
                      range: 0...1,
                      caption: "Tüm kurallar arasında en az bu kadar süre geçer")

            Stepper("Aynı anda en fazla \(session.profile.engineOptions.maximumConcurrentFirings) kural",
                    value: Binding(
                        get: { session.profile.engineOptions.maximumConcurrentFirings },
                        set: { value in
                            session.updateProfile { $0.engineOptions.maximumConcurrentFirings = value }
                        }),
                    in: 1...5)
        } header: {
            Text("Kural motoru")
        }
    }

    private var calibrationSection: some View {
        Section("Kalibrasyon") {
            NavigationLink {
                CalibrationView()
            } label: {
                HStack {
                    Text("Kalibrasyon sihirbazı")
                    Spacer()
                    Text("\(session.profile.calibration.count) sinyal")
                        .foregroundStyle(.secondary)
                }
            }

            if !session.profile.calibration.isEmpty {
                Button("Kalibrasyonu sıfırla", role: .destructive) {
                    session.updateProfile { $0.calibration = [:] }
                }
            }
        }
    }

    private var transferSection: some View {
        Section {
            Button("Profili dışa aktar (JSON)") { showsExport = true }
            Button("Profil içe aktar") { showsImport = true }
        } header: {
            Text("Aktarım")
        } footer: {
            Text("Dışa aktarılan JSON, kuralların tamamını taşır. " +
                 "Başka bir cihaza yapıştırdığınızda aynı şekilde çalışır.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Yüz takibi",
                           value: session.tracking.isSupported ? "destekleniyor" : "desteklenmiyor")
            LabeledContent("Köprü", value: session.surface.isBridgeReady ? "hazır" : "bekliyor")
            LabeledContent("Ekran", value: session.surface.currentSurface.displayName)
            if let error = session.surface.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        } header: {
            Text("Durum")
        } footer: {
            Text("Kamera görüntüsü cihazdan çıkmaz ve hiçbir yere kaydedilmez. " +
                 "Yalnızca yüz ölçümleri işlenir.")
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let json: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Dışa aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kopyala") { UIPasteboard.general.string = json }
                }
            }
        }
    }
}

private struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("JSON yapıştırın") {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("İçe aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aktar") {
                        onImport()
                        dismiss()
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}
#endif
