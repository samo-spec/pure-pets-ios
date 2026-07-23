//
//  PPRootNovaLottieView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// SwiftUI component rendering Nova AI Lottie animation matching legacy `Ncolored.json` at 0.6x speed.
public struct PPRootNovaLottieView: View {
    public var body: some View {
        PPLottieAnimationRepresentable(
            animationName: "Ncolored",
            animationSpeed: 0.6,
            loopAnimation: true
        )
        .frame(width: 38, height: 38)
    }
}
