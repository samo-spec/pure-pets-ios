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
        if UIImage(named: "PuryV1") != nil {
            Image("PuryV1")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 38, height: 38)
        } else {
            PPLottieAnimationRepresentable(
                animationName: "Ncolored",
                animationSpeed: 0.6,
                loopAnimation: true
            )
            .frame(width: 38, height: 38)
        }
    }
}
