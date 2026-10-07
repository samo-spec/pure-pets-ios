#if canImport(UIKit)
import CoreVideo
import ImageIO
import PureLensCore
import Vision

enum PureLensDetectorHealth: Equatable {
    case operational
    case degraded(message: String)
    case failed(message: String)
}

struct VisionLensAnalysis {
    let detections: [LensLocalDetection]
    let health: PureLensDetectorHealth
}

final class VisionLensDetector {
    private let sequenceHandler = VNSequenceRequestHandler()
    private let animalRequest = VNRecognizeAnimalsRequest()
    private let classificationRequest = VNClassifyImageRequest()
    private let barcodeRequest: VNDetectBarcodesRequest?
    private var capturesBarcodePayloads: Bool
    private let coreMLDetector: PureLensCoreMLDetector?
    private let minimumAnimalConfidence: Double

    init(
        coreMLDetector: PureLensCoreMLDetector?,
        minimumAnimalConfidence: Double,
        barcodeHandling: PureLensBarcodeHandling,
        capturesBarcodePayloads: Bool = false
    ) {
        self.coreMLDetector = coreMLDetector
        self.minimumAnimalConfidence = min(max(minimumAnimalConfidence, 0), 1)
        if #available(iOS 17.0, *) {
            classificationRequest.revision = VNClassifyImageRequestRevision2
        }
        switch barcodeHandling {
        case .disabled:
            barcodeRequest = nil
            self.capturesBarcodePayloads = false
        case .presenceOnly:
            barcodeRequest = VNDetectBarcodesRequest()
            self.capturesBarcodePayloads = false
        case .remotePayloadWithConsent:
            barcodeRequest = VNDetectBarcodesRequest()
            self.capturesBarcodePayloads = capturesBarcodePayloads
        }
    }

    var isBarcodePayloadCaptureEnabled: Bool {
        capturesBarcodePayloads
    }

    func setBarcodePayloadCaptureEnabled(_ enabled: Bool) {
        capturesBarcodePayloads = enabled && barcodeRequest != nil
    }

    func analyze(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> VisionLensAnalysis {
        let nativeRequests = makeNativeRequests()
        var requests = nativeRequests
        if let coreMLDetector {
            requests.append(coreMLDetector.visionRequest)
        }

        var includesCurrentCoreMLResults = false
        var health = PureLensDetectorHealth.operational
        do {
            try sequenceHandler.perform(
                requests,
                on: pixelBuffer,
                orientation: orientation
            )
            includesCurrentCoreMLResults = coreMLDetector != nil
        } catch {
            guard coreMLDetector != nil else {
                return VisionLensAnalysis(
                    detections: [],
                    health: .failed(message: error.localizedDescription)
                )
            }
            do {
                try sequenceHandler.perform(
                    nativeRequests,
                    on: pixelBuffer,
                    orientation: orientation
                )
                health = .degraded(message: error.localizedDescription)
            } catch {
                return VisionLensAnalysis(
                    detections: [],
                    health: .failed(message: error.localizedDescription)
                )
            }
        }

        let animals = (animalRequest.results ?? []).compactMap { observation -> LensLocalDetection? in
            guard let label = observation.labels.first else { return nil }
            let effectiveConfidence = LensObservationConfidence.effective(
                observation: Double(observation.confidence),
                label: Double(label.confidence)
            )
            return LensLocalDetection(
                id: "animal-\(observation.uuid.uuidString)",
                kind: .animal,
                label: label.identifier,
                confidence: effectiveConfidence,
                boundingBox: observation.boundingBox.lensNormalized
            )
        }

        let barcodes = (barcodeRequest?.results ?? []).map { observation in
            LensLocalDetection(
                id: "barcode-\(observation.uuid.uuidString)",
                kind: .barcode,
                label: "barcode",
                confidence: Double(observation.confidence),
                boundingBox: observation.boundingBox.lensNormalized,
                machineValue: capturesBarcodePayloads ? observation.payloadStringValue : nil
            )
        }

        let customAnalysis = includesCurrentCoreMLResults
            ? coreMLDetector?.currentAnalysis()
            : nil
        if let customAnalysis,
           customAnalysis.invalidResultCount > 0,
           case .operational = health {
            health = .degraded(
                message: "Breed model output must be object detections using the documented pet label contract."
            )
        }
        let customObjects = customAnalysis?.detections ?? []

        var classifiedAnimal: LensLocalDetection?
        let hasReliableObjectDetection = (animals + customObjects).contains {
            $0.confidence >= minimumAnimalConfidence
        }
        if !hasReliableObjectDetection {
            classifiedAnimal = makeClassifiedAnimalDetection()
        }

        let detections = (animals + [classifiedAnimal].compactMap { $0 } + barcodes + customObjects)
            .filter { $0.confidence >= 0.28 }
            .sorted { $0.confidence > $1.confidence }
        return VisionLensAnalysis(detections: detections, health: health)
    }

    private func makeNativeRequests() -> [VNRequest] {
        var requests: [VNRequest] = [animalRequest, classificationRequest]
        if let barcodeRequest {
            requests.append(barcodeRequest)
        }
        return requests
    }

    private func makeClassifiedAnimalDetection() -> LensLocalDetection? {
        let classifications = classificationRequest.results ?? []
        guard !classifications.isEmpty else { return nil }

        let animalClassifications = classifications.prefix(64).filter { observation in
            let id = observation.identifier.lowercased()
            return id == "animal" || LensAnimalClassificationTaxonomy.isAnimal(identifier: id)
        }

        guard !animalClassifications.isEmpty else { return nil }

        let genericAnimal = classifications.first(where: {
            $0.identifier.lowercased() == "animal"
        })

        let classifierThreshold = min(minimumAnimalConfidence, 0.20)
        var strongestBySpecies: [String: VNClassificationObservation] = [:]
        for observation in animalClassifications {
            guard Double(observation.confidence) >= classifierThreshold,
                  let species = LensAnimalClassificationTaxonomy.species(for: observation.identifier)
            else { continue }
            if let existing = strongestBySpecies[species],
               existing.confidence >= observation.confidence {
                continue
            }
            strongestBySpecies[species] = observation
        }

        let ranked = strongestBySpecies
            .map { (species: $0.key, observation: $0.value) }
            .sorted { $0.observation.confidence > $1.observation.confidence }

        let candidateSpecies: String
        let candidateConfidence: Double
        let topIdentifier: String?

        if let strongest = ranked.first,
           ranked.count == 1 || strongest.observation.confidence - ranked[1].observation.confidence >= 0.08 {
            candidateSpecies = strongest.species
            candidateConfidence = min(1.0, max(Double(strongest.observation.confidence) * 2.2, 0.45))
            topIdentifier = strongest.observation.identifier
        } else if let topAnimal = animalClassifications.first(where: { Double($0.confidence) >= classifierThreshold }) {
            topIdentifier = topAnimal.identifier
            if let specific = LensAnimalClassificationTaxonomy.species(for: topAnimal.identifier) {
                candidateSpecies = specific
            } else {
                candidateSpecies = "Animal"
            }
            candidateConfidence = min(1.0, max(Double(topAnimal.confidence) * 2.0, 0.42))
        } else if let genericAnimal, Double(genericAnimal.confidence) >= classifierThreshold {
            topIdentifier = genericAnimal.identifier
            candidateSpecies = "Animal"
            candidateConfidence = min(1.0, max(Double(genericAnimal.confidence) * 2.0, 0.40))
        } else {
            return nil
        }

        let labelToEmit: String
        if let topIdentifier, let specificAnimal = LensAnimalClassificationTaxonomy.specificAnimal(for: topIdentifier) {
            labelToEmit = specificAnimal
        } else {
            labelToEmit = candidateSpecies
        }

        let animalObservationBox = (animalRequest.results ?? []).first?.boundingBox.lensNormalized
        let box = animalObservationBox ?? LensNormalizedRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)

        return LensLocalDetection(
            id: "classified-animal-\(UUID().uuidString)",
            kind: .animal,
            label: labelToEmit,
            confidence: candidateConfidence,
            boundingBox: box
        )
    }
}

private extension CGRect {
    var lensNormalized: LensNormalizedRect {
        LensNormalizedRect(
            x: Double(origin.x),
            y: Double(origin.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }
}


#endif
