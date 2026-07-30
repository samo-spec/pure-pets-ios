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
                loggedInAvatar
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sessionState.effectiveDisplayName)
    }

    private var loggedInAvatar: some View {
        let avatarSize: CGFloat = isSelected ? 26.0 : 24.0
        let ringWidth: CGFloat = isSelected ? 2.0 : 1.0

        return AppRemoteImage(
            url: sessionState.userImageUrl,
            displaySize: CGSize(width: avatarSize, height: avatarSize),
            contentMode: .fill,
            showsRetryAction: false
        ) {
            avatarPlaceholder(size: avatarSize)
        } failurePlaceholder: {
            avatarPlaceholder(size: avatarSize)
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(
                isSelected
                    ? Color(uiColor: .systemBlue)
                    : Color(uiColor: .secondaryLabel).opacity(0.28),
                lineWidth: ringWidth
            )
        }
        .frame(width: 32, height: 32)
    }

    private func avatarPlaceholder(size: CGFloat) -> some View {
        Image(uiImage: renderedPlaceholderAvatar(size: size))
            .resizable()
            .scaledToFill()
    }

    private func renderedPlaceholderAvatar(size: CGFloat) -> UIImage {
        var avatarImage: UIImage?
        let displayName = sessionState.effectiveDisplayName

        if let rendererClass = NSClassFromString(
            "PPModernAvatarRenderer"
        ) as? NSObject.Type {
            let selector = NSSelectorFromString(
                "avatarImageForName:size:style:"
            )
            if rendererClass.responds(to: selector),
               let unmanaged = rendererClass.perform(
                   selector,
                   with: displayName,
                   with: size
               ) {
                avatarImage = unmanaged.takeUnretainedValue() as? UIImage
            }
        }

        return avatarImage ?? defaultPlaceholderAvatar(
            displayName: displayName,
            size: size
        )
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
