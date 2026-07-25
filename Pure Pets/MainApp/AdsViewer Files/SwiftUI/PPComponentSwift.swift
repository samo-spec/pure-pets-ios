import UIKit
import SwiftUI

@objc(PPComponentSwift)
public final class PPComponentSwift: NSObject {

    @objc
    public static var PPStatusBarHeight: CGFloat {
        if #available(iOS 15.0, *) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            if let topInset = window?.safeAreaInsets.top, topInset > 0 {
                return topInset
            }
        }
        let legacyHeight = UIApplication.shared.statusBarFrame.height
        return legacyHeight > 0 ? legacyHeight : 44.0
    }

    @objc
    public static func pp_circleButtonWithIcon(
        _ iconName: String,
        tint: UIColor = .white,
        action: @escaping () -> Void = {}
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 26.0, *) {
            // iOS 26+ Glass style
            var config = UIButton.Configuration.glass()
            config.cornerStyle = .capsule
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = tint
            
            if let image = UIImage(named: iconName) {
                config.image = image
            } else if let systemImage = UIImage(systemName: iconName) {
                config.image = systemImage
            }
            button.configuration = config
        } else if #available(iOS 15.0, *) {
            // iOS 15 - 25 fallback: filled translucent configuration with clear background
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = tint
            
            if let image = UIImage(named: iconName) {
                config.image = image
            } else if let systemImage = UIImage(systemName: iconName) {
                config.image = systemImage
            }
            button.configuration = config
        } else {
            // Pre-iOS 15 fallback
            button.backgroundColor = .clear
            button.layer.cornerRadius = 22
            button.clipsToBounds = true
            button.tintColor = tint
            
            if let image = UIImage(named: iconName) {
                button.setImage(image, for: .normal)
            } else if let systemImage = UIImage(systemName: iconName) {
                button.setImage(systemImage, for: .normal)
            }
        }

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])

        return button
    }

    public static func pp_circleButtonWithIcon(
        _ iconName: String,
        tint: Color = .white,
        action: @escaping () -> Void = {}
    ) -> PPCircleGlassButton {
        PPCircleGlassButton(
            iconName: iconName,
            tint: tint,
            action: action
        )
    }
}




public struct PPCircleGlassButton: View {
    let iconName: String
    let tint: Color
    let action: () -> Void

    public init(
        iconName: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if let image = UIImage(named: iconName) {
                    Image(uiImage: image)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .ppGlassSurface(
            in: Circle(),
            tint: Color.black.opacity(0.16),
            fallback: Color.black.opacity(0.86),
            stroke: Color.white.opacity(0.20)
        )
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.88))
    }
}
