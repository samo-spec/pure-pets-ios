import UIKit
import SwiftUI

@objcMembers
public final class PPBlurHashBridge: NSObject {

    // MARK: - Decode BlurHash → UIImage

    public static func image(
        from blurHash: String,
        size: CGSize,
        punch: Float = 1,
        completion: @escaping (UIImage?) -> Void
    ) {
        Task.detached(priority: .utility) {
            let image = UIImage(
                blurHash: blurHash,
                size: size,
                punch: punch
            )

            await MainActor.run {
                completion(image)
            }
        }
    }
    
    @objc
    public static func imageFrom(
        _ blurHash: String,
        syncSize size: CGSize,
        punch: Float = 1
    ) -> UIImage? {
        UIImage(
            blurHash: blurHash,
            size: size,
            punch: punch
        )
    }

    // MARK: - Decode with fade into UIImageView

    public static func setImage(
        from blurHash: String,
        into imageView: UIImageView,
        size: CGSize,
        duration: TimeInterval = 0.25
    ) {
        image(from: blurHash, size: size) { image in
            guard let image else { return }

            UIView.transition(
                with: imageView,
                duration: duration,
                options: .transitionCrossDissolve,
                animations: {
                    imageView.image = image
                }
            )
        }
    }

    // MARK: - Generate BlurHash from UIImage (ENCODE)
    @objcMembers
    public final class PPBlurHashBridge: NSObject {

        @available(iOS 13.0, *)
        public static func generateBlurHash(
            from image: UIImage,
            completion: @escaping (String?) -> Void
        ) {
            Task.detached(priority: .utility) {

                // UnifiedImage == UIImage (NO conversion needed)
                let unifiedImage: UnifiedImage = image

                // ✅ THIS IS YOUR ENCODER
                let hash = await UnifiedBlurHash.getBlurHashString(
                    from: unifiedImage
                )

                await MainActor.run {
                    completion(hash)
                }
            }
        }
    }
    
    
    
    // MARK: - Average Color

    public static func averageColor(
        from blurHash: String,
        completion: @escaping (UIColor) -> Void
    ) {
        Task.detached(priority: .utility) {
            let color = decodeAverageColor(blurHash: blurHash)
            let uiColor = UIColor(color)

            await MainActor.run {
                completion(uiColor)
            }
        }
    }
}

// MARK: - Local scaling helper (no UIKit conflicts)

private extension UIImage {

    func pp_scaledTo(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }

        let ratio = maxDimension / maxSide
        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result ?? self
    }
}
