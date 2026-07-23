//
//  PPCartFloatingBarView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Declarative SwiftUI component for the expanding and collapsing floating cart bar matching legacy `PPCartFloatingBarView`.
public struct PPCartFloatingBarView: View {
    public let state: PPCartFloatingBarState
    public let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    private var primaryColor: Color {
        Color(uiColor: UIColor(named: "AppPrimaryColor") ?? UIColor(red: 227/255, green: 6/255, blue: 83/255, alpha: 1.0))
    }
    
    public init(state: PPCartFloatingBarState, onTap: @escaping () -> Void) {
        self.state = state
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: onTap) {
            Group {
                if !state.isCollapsed {
                    // Expanded cart bar
                    HStack(spacing: 12) {
                        // Cart icon orb
                        ZStack {
                            Circle()
                                .fill(primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "cart.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(primaryColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Cart", value: "السلة", comment: ""))
                                .font(Font.ppBeirutiBold(size: 15))
                                .foregroundStyle(colorScheme == .dark ? .white : Color(white: 0.08))
                            
                            Text(state.subtitleText)
                                .font(Font.ppBeirutiMedium(size: 12))
                                .foregroundStyle(colorScheme == .dark ? Color(white: 0.82) : Color(white: 0.38))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        // CTA button capsule ("Review Cart" + Chevron)
                        HStack(spacing: 6) {
                            Text(NSLocalizedString("checkout_review_cart_action", value: "مراجعة السلة", comment: ""))
                                .font(Font.ppBeirutiBold(size: 13))
                                .foregroundStyle(primaryColor)
                            
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(primaryColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(primaryColor.opacity(colorScheme == .dark ? 0.20 : 0.12), in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                } else {
                    // Collapsed floating pill bar (Material container collapses perfectly)
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(primaryColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "cart.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(primaryColor)
                        }
                        
                        Text(state.badgeText)
                            .font(Font.ppBeirutiBold(size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(primaryColor, in: Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(height: 48)
                }
            }
            .background {
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
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.16), radius: state.isCollapsed ? 12 : 18, x: 0, y: 6)
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: state.isCollapsed)
        }
        .buttonStyle(PPCartButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("\(NSLocalizedString("Cart", value: "السلة", comment: "")). \(state.subtitleText)")
        .accessibilityHint(NSLocalizedString("a11y_btn_checkout_hint", value: "Double-tap to review your cart", comment: ""))
    }
}

private struct PPCartButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                isPressed = newValue
            }
    }
}
