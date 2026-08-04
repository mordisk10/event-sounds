#if canImport(SwiftUI) && canImport(ARKit)
import SwiftUI
import InstakaiCore

/// Guided capture of each user's personal neutral and maximum for the signals
/// that matter most.
///
/// Everyone's face reports different raw values — some people rest at
/// `tongueOut = 0.2`, others can only reach `0.5` at full effort. Without this
/// step, a single global threshold is either unreachable or fires constantly.
struct CalibrationView: View {
    @EnvironmentObject private var session: SessionController
    @Environment(\.dismiss) private var dismiss

    /// The signals worth calibrating. Directional tongue signals are derived
    /// from the estimator, so calibrating `tongueOut` covers them.
    private let steps: [Signal] = [.tongueOut, .jawOpen, .browInnerUp, .cheekPuff]

    @State private var index = 0
    @State private var neutral: Double?
    @State private var maximum: Double?
    @State private var captured: [Signal: CalibrationRange] = [:]

    private var signal: Signal { steps[min(index, steps.count - 1)] }
    private var isFinished: Bool { index >= steps.count }

    var body: some View {
        VStack(spacing: 20) {
            if isFinished {
                summary
            } else {
                stepContent
            }
        }
        .padding()
        .navigationTitle("Kalibrasyon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            captured = session.profile.calibration
            if !session.isRunning { session.start() }
        }
    }

    // MARK: - Steps

    private var stepContent: some View {
        VStack(spacing: 18) {
            ProgressView(value: Double(index), total: Double(steps.count))

            Text(signal.displayName)
                .font(.title2.weight(.semibold))

            Text(instruction)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            SignalMeter(signal: signal, value: rawValue)

            HStack(spacing: 12) {
                captureButton(title: "Nötr yakala", value: neutral) {
                    neutral = rawValue
                }
                captureButton(title: "En yüksek yakala", value: maximum) {
                    maximum = rawValue
                }
            }

            if let warning {
                WarningRow(message: warning)
            }

            Spacer()

            HStack {
                Button("Atla") { advance(saving: false) }
                    .buttonStyle(.bordered)

                Button("İleri") { advance(saving: true) }
                    .buttonStyle(.borderedProminent)
                    .disabled(neutral == nil || maximum == nil || warning != nil)
            }
        }
    }

    private func captureButton(title: String, value: Double?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.caption)
                Text(value.map { String(format: "%.2f", $0) } ?? "—")
                    .font(.headline.monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Kalibrasyon tamam")
                .font(.title3.weight(.semibold))
            Text("\(captured.count) sinyal kaydedildi. Eşikler artık sizin " +
                 "ifade aralığınıza göre ölçekleniyor.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Kaydet ve bitir") {
                let result = captured
                session.updateProfile { $0.calibration = result }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Logic

    /// Calibration reads the *raw* frame: the processor's own calibration is
    /// what we are trying to measure, so feeding it back would compound.
    private var rawValue: Double {
        session.tracking.latestRawFrame[signal]
    }

    private var instruction: String {
        switch signal {
        case .tongueOut:
            return "Önce yüzünüzü rahat bırakın ve “Nötr yakala”ya dokunun. " +
                   "Sonra dilinizi olabildiğince çıkarıp “En yüksek yakala”ya dokunun."
        case .jawOpen:
            return "Ağzınız kapalıyken nötr, sonuna kadar açıkken en yüksek değeri yakalayın."
        case .browInnerUp:
            return "Kaşlarınız normalken nötr, kaldırdığınızda en yüksek değeri yakalayın."
        case .cheekPuff:
            return "Yanaklarınız normalken nötr, şişirdiğinizde en yüksek değeri yakalayın."
        default:
            return "Nötr ve en yüksek değerleri yakalayın."
        }
    }

    private var warning: String? {
        guard let neutral, let maximum else { return nil }
        guard maximum - neutral > 0.05 else {
            return "Nötr ve en yüksek değerler çok yakın. Hareketi daha belirgin yapıp tekrar deneyin."
        }
        return nil
    }

    private func advance(saving: Bool) {
        if saving, let neutral, let maximum {
            captured[signal] = CalibrationRange(neutral: neutral, maximum: maximum)
        }
        neutral = nil
        maximum = nil
        index += 1
    }
}
#endif
