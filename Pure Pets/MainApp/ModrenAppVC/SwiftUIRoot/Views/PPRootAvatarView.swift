//
//  PPRootAvatarView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// SwiftUI component for profile tab avatar rendering matching legacy `PPModernAvatarRenderer` and guest Lottie behavior.
public struct PPRootAvatarView: View {
    public let sessionState: PPRootSessionState
    public let isSelected: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(sessionState: PPRootSessionState, isSelected: Bool) {
        self.sessionState = sessionState
        self.isSelected = isSelected
    }
    
    public var body: some View {
        ZStack {
            if sessionState.isGuest {
                // Real Guest Profile Lottie Animation (Profile.lottie) with dynamic tinting
                PPRootGuestProfileLottieView(isSelected: isSelected)
            } else {
                // Logged-in user avatar with dynamic ring
                let avatarImage = renderAvatarImage()
                Image(uiImage: avatarImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sessionState.effectiveDisplayName)
    }
    
    private func renderAvatarImage() -> UIImage {
        let size: CGFloat = 32.0
        let avatarSize: CGFloat = isSelected ? 28.0 : 26.0
        let avatarRect = CGRect(
            x: (size - avatarSize) * 0.5,
            y: (size - avatarSize) * 0.5,
            width: avatarSize,
            height: avatarSize
        )
        
        var avatarImage: UIImage? = nil
        let displayName = sessionState.effectiveDisplayName
        
        // Typed invocation bridge for PPModernAvatarRenderer when linked via bridging header
        if let rendererClass = NSClassFromString("PPModernAvatarRenderer") as? NSObject.Type {
            let sel = NSSelectorFromString("avatarImageForName:size:style:")
            if rendererClass.responds(to: sel) {
                // Safe ObjC message dispatch via perform without unsafeBitCast
                if let unmanaged = rendererClass.perform(sel, with: displayName, with: avatarSize) {
                    avatarImage = unmanaged.takeUnretainedValue() as? UIImage
                }
            }
        }
        
        // SDWebImage memory cache fallback check
        if let url = sessionState.userImageUrl {
            if let cacheClass = NSClassFromString("SDImageCache") as? NSObject.Type {
                let sharedSel = NSSelectorFromString("sharedImageCache")
                if cacheClass.responds(to: sharedSel),
                   let cache = cacheClass.perform(sharedSel)?.takeUnretainedValue() as? NSObject {
                    let key = url.absoluteString
                    let memSel = NSSelectorFromString("imageFromMemoryCacheForKey:")
                    if cache.responds(to: memSel),
                       let img = cache.perform(memSel, with: key)?.takeUnretainedValue() as? UIImage {
                        avatarImage = img
                    }
                }
            }
        }
        
        let finalAvatar = avatarImage ?? defaultPlaceholderAvatar(displayName: displayName, size: avatarSize)
        
        let brandColor = UIColor.systemBlue
        let ringColor = isSelected ? brandColor : UIColor.secondaryLabel.withAlphaComponent(0.28)
        let ringWidth: CGFloat = isSelected ? 2.0 : 1.0
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.saveGState()
            let clipPath = UIBezierPath(ovalIn: avatarRect)
            clipPath.addClip()
            finalAvatar.draw(in: avatarRect)
            ctx.restoreGState()
            
            let ringPath = UIBezierPath(ovalIn: avatarRect.insetBy(dx: -ringWidth * 0.45, dy: -ringWidth * 0.45))
            ringPath.lineWidth = ringWidth
            ringColor.setStroke()
            ringPath.stroke()
        }
    }
    
    private func defaultPlaceholderAvatar(displayName: String, size: CGFloat) -> UIImage {
        let initial = String(displayName.first ?? "P").uppercased()
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            UIColor.systemGroupedBackground.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: size * 0.42),
                .foregroundColor: UIColor.label
            ]
            let string = NSString(string: initial)
            let strSize = string.size(withAttributes: attributes)
            let rect = CGRect(
                x: (size - strSize.width) * 0.5,
                y: (size - strSize.height) * 0.5,
                width: strSize.width,
                height: strSize.height
            )
            string.draw(in: rect, withAttributes: attributes)
        }
    }
}
