#if canImport(UIKit)
import AVFoundation
import ImageIO
import SwiftUI
import UIKit

struct PureLensCameraPreview: UIViewRepresentable {
    let camera: PureLensCameraController

    func makeUIView(context: Context) -> LensPreviewView {
        let view = LensPreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onOrientationChange = { [weak camera = camera] orientation in
            camera?.updateImageOrientation(Self.imageOrientation(for: orientation))
        }
        view.onFocus = { [weak camera = camera, weak view] layerPoint in
            guard let view else { return }
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            camera?.focus(at: devicePoint)
        }
        return view
    }

    func updateUIView(_ uiView: LensPreviewView, context: Context) {
        if uiView.previewLayer.session !== camera.session {
            uiView.previewLayer.session = camera.session
        }
        uiView.updateOrientation()
    }

    private static func imageOrientation(
        for interfaceOrientation: UIInterfaceOrientation
    ) -> CGImagePropertyOrientation {
        switch interfaceOrientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .right
        }
    }
}

final class LensPreviewView: UIView {
    var onOrientationChange: ((UIInterfaceOrientation) -> Void)?
    var onFocus: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFocusTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFocusTap(_:)))
        addGestureRecognizer(tap)
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("LensPreviewView must use AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }

    @objc private func handleFocusTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onFocus?(recognizer.location(in: self))
    }

    func updateOrientation() {
        let orientation = window?.windowScene?.interfaceOrientation ?? .portrait
        onOrientationChange?(orientation)

        guard let connection = previewLayer.connection else { return }
        if #available(iOS 17.0, *) {
            let angle = rotationAngle(for: orientation)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation(for: orientation)
        }
    }

    @available(iOS 17.0, *)
    private func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        default:
            return 90
        }
    }

    @available(iOS, obsoleted: 17.0)
    private func videoOrientation(
        for orientation: UIInterfaceOrientation
    ) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .portrait
        }
    }
}


#endif
