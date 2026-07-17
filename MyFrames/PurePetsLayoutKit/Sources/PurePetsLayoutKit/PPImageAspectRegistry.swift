import CoreGraphics
import Foundation

/// Main-actor store for image dimensions discovered after asynchronous loading.
/// Updating a ratio republishes layout state without replacing business models.
@MainActor
public final class PPImageAspectRegistry: ObservableObject {
    @Published public private(set) var ratios: [String: CGFloat] = [:]

    public init() {}

    public func ratio(for id: String, fallback: CGFloat? = nil) -> CGFloat? {
        ratios[id] ?? fallback
    }

    public func update(id: String, pixelSize: CGSize) {
        guard pixelSize.width.isFinite,
              pixelSize.height.isFinite,
              pixelSize.width > 0,
              pixelSize.height > 0 else { return }
        update(id: id, ratio: pixelSize.height / pixelSize.width)
    }

    public func update(id: String, ratio: CGFloat) {
        guard ratio.isFinite, ratio > 0.02, ratio < 50 else { return }
        guard ratios[id] != ratio else { return }
        ratios[id] = ratio
    }

    public func removeAll() {
        ratios.removeAll(keepingCapacity: true)
    }
}
