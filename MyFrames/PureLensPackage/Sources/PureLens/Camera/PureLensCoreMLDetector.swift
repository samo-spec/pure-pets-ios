#if canImport(UIKit)
import CoreML
import PureLensCore
import Vision

struct PureLensCoreMLAnalysis {
    let detections: [LensLocalDetection]
    let invalidResultCount: Int
}

/// Optional adapter for a Pure Pets object-detection `.mlmodel`.
/// The request is reused and executed on the package's serial camera frame queue.
public final class PureLensCoreMLDetector {
    let visionRequest: VNCoreMLRequest
    private let minimumConfidence: Double

    public init(
        model: MLModel,
        minimumConfidence: Float = 0.45,
        cropAndScaleOption: VNImageCropAndScaleOption = .scaleFill
    ) throws {
        let visionModel = try VNCoreMLModel(for: model)
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = cropAndScaleOption
        visionRequest = request
        self.minimumConfidence = min(max(Double(minimumConfidence), 0), 1)
    }

    func currentAnalysis() -> PureLensCoreMLAnalysis {
        var detections: [LensLocalDetection] = []
        var invalidResultCount = 0

        for result in visionRequest.results ?? [] {
            guard let observation = result as? VNRecognizedObjectObservation,
                  let label = observation.labels.first
            else {
                invalidResultCount += 1
                continue
            }
            let effectiveConfidence = LensObservationConfidence.effective(
                observation: Double(observation.confidence),
                label: Double(label.confidence)
            )
            guard effectiveConfidence >= minimumConfidence else { continue }

            let detection = LensLocalDetection(
                id: "object-\(observation.uuid.uuidString)",
                kind: .object,
                label: label.identifier,
                confidence: effectiveConfidence,
                boundingBox: LensNormalizedRect(
                    x: Double(observation.boundingBox.origin.x),
                    y: Double(observation.boundingBox.origin.y),
                    width: Double(observation.boundingBox.width),
                    height: Double(observation.boundingBox.height)
                )
            )
            // Reject arbitrary object-detector labels. A supported breed model
            // must emit the documented pet label contract.
            guard LensPetRecognition.parse(detection) != nil else {
                invalidResultCount += 1
                continue
            }
            detections.append(detection)
        }

        return PureLensCoreMLAnalysis(
            detections: detections,
            invalidResultCount: invalidResultCount
        )
    }
}


#endif