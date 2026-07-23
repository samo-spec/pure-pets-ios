//
//  PPRootGuestProfileLottieView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// SwiftUI component rendering guest profile Lottie animation matching legacy `Profile.lottie` with dynamic tinting.
public struct PPRootGuestProfileLottieView: View {
    public let isSelected: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }
    
    public var body: some View {
        PPLottieAnimationRepresentable(
            animationName: "Profile.lottie",
            animationSpeed: 0.85,
            loopAnimation: true,
            tintColor: isSelected ? .systemPink : .secondaryLabel
        )
        .frame(width: isSelected ? 34 : 32, height: isSelected ? 34 : 32)
    }
}
