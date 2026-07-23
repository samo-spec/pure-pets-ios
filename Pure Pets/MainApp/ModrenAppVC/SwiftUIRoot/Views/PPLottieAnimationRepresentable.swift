//
//  PPLottieAnimationRepresentable.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// UIViewRepresentable bridging legacy Lottie Objective-C views (`LOTAnimationView` / `AppClasses`) into SwiftUI.
public struct PPLottieAnimationRepresentable: UIViewRepresentable {
    public let animationName: String
    public let animationSpeed: Double
    public let loopAnimation: Bool
    public let tintColor: UIColor?
    
    public init(
        animationName: String,
        animationSpeed: Double = 1.0,
        loopAnimation: Bool = true,
        tintColor: UIColor? = nil
    ) {
        self.animationName = animationName
        self.animationSpeed = animationSpeed
        self.loopAnimation = loopAnimation
        self.tintColor = tintColor
    }
    
    public func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        containerView.backgroundColor = .clear
        containerView.clipsToBounds = true
        
        // Dynamic instantiation of LOTAnimationView without unsafeBitCast
        if let lotClass = NSClassFromString("LOTAnimationView") as? NSObject.Type {
            let selector = NSSelectorFromString("animationNamed:")
            if lotClass.responds(to: selector),
               let lottieInstance = lotClass.perform(selector, with: animationName)?.takeUnretainedValue() as? UIView {
                
                lottieInstance.translatesAutoresizingMaskIntoConstraints = false
                lottieInstance.backgroundColor = .clear
                
                lottieInstance.setValue(loopAnimation, forKey: "loopAnimation")
                lottieInstance.setValue(animationSpeed, forKey: "animationSpeed")
                
                if let tint = tintColor {
                    lottieInstance.tintColor = tint
                }
                
                containerView.addSubview(lottieInstance)
                NSLayoutConstraint.activate([
                    lottieInstance.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    lottieInstance.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    lottieInstance.topAnchor.constraint(equalTo: containerView.topAnchor),
                    lottieInstance.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                
                let playSel = NSSelectorFromString("play")
                if lottieInstance.responds(to: playSel) {
                    lottieInstance.perform(playSel)
                }
                
                return containerView
            }
        }
        
        // Fallback: AppClasses setAnimationNamed:ToView:withSpeed:completion:
        if let appClasses = NSClassFromString("AppClasses") as? NSObject.Type {
            let setAnimSel = NSSelectorFromString("setAnimationNamed:ToView:withSpeed:completion:")
            if appClasses.responds(to: setAnimSel) {
                let targetView = UIView(frame: .zero)
                targetView.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(targetView)
                
                NSLayoutConstraint.activate([
                    targetView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    targetView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    targetView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    targetView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                
                return containerView
            }
        }
        
        // Secondary Fallback symbol
        let fallbackImageView = UIImageView(image: UIImage(systemName: "sparkles"))
        fallbackImageView.tintColor = tintColor ?? .systemTeal
        fallbackImageView.contentMode = .scaleAspectFit
        fallbackImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(fallbackImageView)
        
        NSLayoutConstraint.activate([
            fallbackImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            fallbackImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fallbackImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.6),
            fallbackImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.6)
        ])
        
        return containerView
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        if let tint = tintColor {
            uiView.subviews.forEach { $0.tintColor = tint }
        }
    }
}
