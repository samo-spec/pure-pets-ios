//
//  PPBlurHashGenerator.swift
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/01/2026.
//


import UIKit

@objc(PPBlurHashGenerator)
public final class PPBlurHashGenerator: NSObject {

    /// Generates BlurHash from UIImage
    /// ⚠️ Call on background thread
    @objc
    public static func generate(from image: UIImage) -> String? {
        // Best practice: 4x4 (Facebook / Airbnb standard)
        return image.blurHash(numberOfComponents: (4, 4))
    }
    
    @objc
    public static func generateBlurHashFromImage(
        _ image: UIImage,
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            let hash = generate(from: image)
            DispatchQueue.main.async {
                completion(hash)
            }
        }
    }
    
    
    
}

@objc(PPBlurFastHashGenerator)
public final class PPBlurFastHashGenerator: NSObject {

    private static let cache = NSCache<NSString, NSString>()

    /// FAST BlurHash for chat (recommended)
    @objc
    static func generateFast(from image: UIImage) -> String? {

        let cacheKey =
            "\(Int(image.size.width))x\(Int(image.size.height))" as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached as String
        }

        // 🔥 Downscale HARD (speed win)
        let targetSize = CGSize(width: 64, height: 64)

        guard let resized = image.pp_resizeFast(to: targetSize),
              resized.cgImage != nil
        else { return nil }

        // 🔥 Low components = FAST
        let hash = resized.blurHash(numberOfComponents: (3, 2))

        if let hash {
            cache.setObject(hash as NSString, forKey: cacheKey)
        }

        return hash
    }
}


private extension UIImage {

    func pp_resizeFast(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        draw(in: CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
