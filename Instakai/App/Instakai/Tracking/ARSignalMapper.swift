#if canImport(ARKit)
import ARKit
import simd
import InstakaiCore

/// Converts an `ARFaceAnchor` into a `SignalFrame`.
///
/// ARKit gives 52 blend shapes plus a head transform. We map the subset the rule
/// engine exposes, and split every signed axis (yaw/pitch/roll/gaze) into two
/// one-directional magnitudes so rules read naturally.
enum ARSignalMapper {

    /// Head rotation beyond this many radians reads as a full-strength signal.
    /// ~0.45 rad ≈ 26°, which is a deliberate head turn rather than drift.
    private static let headAngleRange: Float = 0.45

    static func makeFrame(from anchor: ARFaceAnchor, timestamp: TimeInterval) -> SignalFrame {
        var frame = SignalFrame(timestamp: timestamp)
        frame[.faceVisible] = anchor.isTracked ? 1 : 0

        guard anchor.isTracked else { return frame }

        let shapes = anchor.blendShapes
        func shape(_ location: ARFaceAnchor.BlendShapeLocation) -> Double {
            (shapes[location]?.doubleValue) ?? 0
        }

        frame[.tongueOut] = shape(.tongueOut)
        frame[.jawOpen] = shape(.jawOpen)
        frame[.mouthPucker] = shape(.mouthPucker)
        frame[.mouthFunnel] = shape(.mouthFunnel)
        frame[.mouthSmileLeft] = shape(.mouthSmileLeft)
        frame[.mouthSmileRight] = shape(.mouthSmileRight)
        frame[.cheekPuff] = shape(.cheekPuff)

        frame[.eyeBlinkLeft] = shape(.eyeBlinkLeft)
        frame[.eyeBlinkRight] = shape(.eyeBlinkRight)
        frame[.eyeSquintLeft] = shape(.eyeSquintLeft)
        frame[.eyeSquintRight] = shape(.eyeSquintRight)
        frame[.browInnerUp] = shape(.browInnerUp)
        frame[.browDownLeft] = shape(.browDownLeft)
        frame[.browDownRight] = shape(.browDownRight)

        // Gaze comes from the eye look blend shapes rather than the eye
        // transforms: the blend shapes are already normalised and far steadier.
        frame[.gazeLeft] = max(shape(.eyeLookOutLeft), shape(.eyeLookInRight))
        frame[.gazeRight] = max(shape(.eyeLookInLeft), shape(.eyeLookOutRight))
        frame[.gazeUp] = max(shape(.eyeLookUpLeft), shape(.eyeLookUpRight))
        frame[.gazeDown] = max(shape(.eyeLookDownLeft), shape(.eyeLookDownRight))

        let pose = eulerAngles(from: anchor.transform)
        frame[.headYawLeft] = normalise(-pose.yaw)
        frame[.headYawRight] = normalise(pose.yaw)
        frame[.headPitchUp] = normalise(pose.pitch)
        frame[.headPitchDown] = normalise(-pose.pitch)
        frame[.headRollLeft] = normalise(-pose.roll)
        frame[.headRollRight] = normalise(pose.roll)

        return frame
    }

    private static func normalise(_ radians: Float) -> Double {
        Double(min(max(radians / headAngleRange, 0), 1))
    }

    /// Roll of the head in radians, used to rotate the tongue direction vector
    /// into face space so "aşağı" means aşağı even with a tilted head.
    static func roll(of anchor: ARFaceAnchor) -> Float {
        eulerAngles(from: anchor.transform).roll
    }

    /// Extracts yaw/pitch/roll from the anchor transform.
    ///
    /// Note the sign convention: ARKit's face anchor looks *out of* the screen
    /// towards the user, so a positive yaw here is the user turning to their own
    /// right from the phone's point of view.
    private static func eulerAngles(from transform: simd_float4x4) -> (pitch: Float, yaw: Float, roll: Float) {
        let m = transform
        // Standard ZYX extraction from the rotation submatrix.
        let sy = sqrt(m.columns.0.x * m.columns.0.x + m.columns.1.x * m.columns.1.x)
        let isSingular = sy < 1e-6

        let pitch: Float
        let yaw: Float
        let roll: Float
        if isSingular {
            pitch = atan2(-m.columns.1.z, m.columns.1.y)
            yaw = atan2(-m.columns.2.x, sy)
            roll = 0
        } else {
            pitch = atan2(m.columns.2.y, m.columns.2.z)
            yaw = atan2(-m.columns.2.x, sy)
            roll = atan2(m.columns.1.x, m.columns.0.x)
        }
        return (pitch, yaw, roll)
    }
}
#endif
