//
//  PPRootNovaButton.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Floating Nova AI Action Button component with glass background effects and Lottie animation.
public struct PPRootNovaButton: View {
    public let state: PPRootNovaState
    public let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    public init(state: PPRootNovaState, action: @escaping () -> Void) {
        self.state = state
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                // Glass background capsule
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 12, x: 0, y: 6)
                
                // Real Nova Lottie Animation (Ncolored.json)
                PPRootNovaLottieView()
            }
            .frame(width: 58, height: 58)
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PPRootNovaButtonStyle(isPressed: $isPressed))
        .accessibilityLabel(NSLocalizedString("nova_chat_accessibility", value: "Chat with Nova AI", comment: ""))
        .accessibilityHint(NSLocalizedString("a11y_btn_nova_hint", value: "Open Nova AI assistant for instant pet help", comment: ""))
    }
}

private struct PPRootNovaButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}
