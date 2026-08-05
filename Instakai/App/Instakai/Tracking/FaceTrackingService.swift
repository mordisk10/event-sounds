#if canImport(ARKit)
import ARKit
import AVFoundation
import Combine
import InstakaiCore

/// Owns the ARKit session and publishes processed `SignalFrame` values.
///
/// Pipeline per ARKit frame:
/// `ARFaceAnchor → ARSignalMapper → TongueDirectionEstimator → SignalProcessor`.
/// The camera image never leaves the device and is never written to disk.
final class FaceTrackingService: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case unsupported
        case permissionDenied
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// Latest processed frame, published on the main queue for the UI.
    @Published private(set) var latestFrame: SignalFrame = SignalFrame.lost(at: 0)

    /// Frames delivered to the engine, on the ARKit queue. Kept separate from
    /// `latestFrame` so engine evaluation is not throttled to UI updates.
    let frames = PassthroughSubject<SignalFrame, Never>()

    let session = ARSession()
    private let processor: SignalProcessor
    private let tongueEstimator = TongueDirectionEstimator()

    /// Raw (uncalibrated) frame, used by the calibration wizard which must see
    /// values before normalisation.
    @Published private(set) var latestRawFrame: SignalFrame = SignalFrame.lost(at: 0)

    init(processor: SignalProcessor = SignalProcessor()) {
        self.processor = processor
        super.init()
        session.delegate = self
    }

    var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    func apply(tuning: SignalTuning) {
        processor.update(tuning: tuning)
    }

    func apply(calibration: [Signal: CalibrationRange]) {
        processor.update(calibration: calibration)
    }

    func start() {
        guard isSupported else {
            state = .unsupported
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.state = .permissionDenied
                    return
                }
                let configuration = ARFaceTrackingConfiguration()
                configuration.maximumNumberOfTrackedFaces = 1
                configuration.isLightEstimationEnabled = false
                self.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                self.state = .running
            }
        }
    }

    func stop() {
        session.pause()
        processor.reset()
        tongueEstimator.reset()
        state = .idle
        latestFrame = SignalFrame.lost(at: latestFrame.timestamp)
    }
}

extension FaceTrackingService: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let anchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            emit(SignalFrame.lost(at: frame.timestamp), raw: SignalFrame.lost(at: frame.timestamp))
            return
        }

        // Direction estimation is asynchronous; this call returns immediately
        // and the result is folded into a later frame.
        tongueEstimator.submit(pixelBuffer: frame.capturedImage,
                               headRoll: ARSignalMapper.roll(of: anchor))

        let mapped = ARSignalMapper.makeFrame(from: anchor, timestamp: frame.timestamp)
        let withDirection = tongueEstimator.decorate(mapped)
        emit(processor.process(withDirection), raw: withDirection)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.state = .failed(error.localizedDescription)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        emit(SignalFrame.lost(at: 0), raw: SignalFrame.lost(at: 0))
    }

    private func emit(_ frame: SignalFrame, raw: SignalFrame) {
        frames.send(frame)
        DispatchQueue.main.async { [weak self] in
            self?.latestFrame = frame
            self?.latestRawFrame = raw
        }
    }
}
#endif
