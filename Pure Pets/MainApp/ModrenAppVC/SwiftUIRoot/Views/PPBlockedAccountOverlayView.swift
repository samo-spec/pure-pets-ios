//
//  PPBlockedAccountOverlayView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Full-screen glassmorphism overlay presented when a user account is suspended or blocked matching legacy `blockedOverlayView`.
public struct PPBlockedAccountOverlayView: View {
    @ObservedObject public var store: PPRootStore
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(store: PPRootStore) {
        self.store = store
    }
    
    public var body: some View {
        ZStack {
            // Ultra-thin material glass backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Background ambient glow spots
            VStack {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.20))
                        .frame(width: 308, height: 308)
                        .blur(radius: 48)
                        .offset(x: -84, y: -58)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.purple.opacity(0.14))
                        .frame(width: 288, height: 288)
                        .blur(radius: 44)
                        .offset(x: 74, y: 54)
                }
            }
            .ignoresSafeArea()
            
            // Content Card Stack
            VStack(spacing: 16) {
                // Brand pill
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.blue)
                    }
                    
                    Text(store.blockedState.brandName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.96))
                }
                .padding(.leading, 8)
                .padding(.trailing, 14)
                .frame(height: 40)
                .background(Color.white.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .padding(.bottom, 6)
                
                // Animation Plate Container
                ZStack {
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .fill(Color(uiColor: UIColor.systemBackground).opacity(0.78))
                        .frame(width: 172, height: 172)
                        .overlay(
                            RoundedRectangle(cornerRadius: 42, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 20)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(Color.blue)
                }
                .padding(.bottom, 2)
                
                // Title
                Text(NSLocalizedString("auth_account_blocked_title", value: "Account Suspended", comment: ""))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(uiColor: UIColor.label))
                    .multilineTextAlignment(.center)
                
                // Message
                Text(NSLocalizedString("auth_account_blocked_message", value: "Your account has been temporarily restricted. Please contact customer support.", comment: ""))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(uiColor: UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                
                // Actions Stack
                VStack(spacing: 12) {
                    // Contact Support Button
                    Button {
                        store.handleBlockedContactSupportCall()
                    } label: {
                        Text(NSLocalizedString("order_support_button", value: "Contact Customer Support", comment: ""))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.24), radius: 18, x: 0, y: 12)
                    }
                    
                    // Logout Button
                    Button {
                        store.handleBlockedSignOut()
                    } label: {
                        Text(NSLocalizedString("logout", value: "Sign Out", comment: ""))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                Color(
                                    uiColor: UIColor.secondarySystemBackground
                                )
                                .opacity(0.88),
                                in: RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.red.opacity(0.22), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 430)
        }
        .accessibilityAddTraits(.isModal)
    }
}
