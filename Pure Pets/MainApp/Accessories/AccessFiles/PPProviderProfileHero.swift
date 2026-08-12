//
//  PPProviderProfileHero.swift
//  Pure Pets Pro
//
//  World-Class Provider Profile Hero Component - SwiftUI Wrapper
//

import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct PPProviderProfileHero: View {
    @ObservedObject var store: PPProviderProfileHeroStore
    
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    @State private var heroResolved = false
    @State private var avatarResolved = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground
                .opacity(heroResolved ? 1 : 0)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.52), value: heroResolved)
            
            avatarStack
                .offset(y: avatarResolved ? 0 : -12)
                .opacity(avatarResolved ? 1 : 0)
                .animation(
                    reduceMotion
                        ? .none
                        : .spring(response: 0.44, dampingFraction: 0.86, blendDuration: 0.08),
                    value: avatarResolved
                )
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: PPSpace.sm) {
                    if let status = store.status, !status.isEmpty {
                        statusBadge(status)
                            .opacity(heroResolved ? 1 : 0)
                            .animation(
                                reduceMotion ? .none : .easeOut(duration: 0.32),
                                value: heroResolved
                            )
                    }
                    
                    Text(store.providerName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                        .accessibilityAddTraits(.isHeader)
                        .opacity(heroResolved ? 1 : 0)
                        .animation(
                            reduceMotion ? .none : .easeOut(duration: 0.36),
                            value: heroResolved
                        )
                    
                    if let subtitle = store.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                            .opacity(heroResolved ? 1 : 0)
                            .animation(
                                reduceMotion ? .none : .easeOut(duration: 0.40),
                                value: heroResolved
                            )
                    }
                    
                    if let description = store.description, !description.isEmpty {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(layoutDirection == .rightToLeft ? .trailing : .leading)
                            .padding(.horizontal, PPSpace.xxl)
                            .opacity(heroResolved ? 1 : 0)
                            .animation(
                                reduceMotion ? .none : .easeOut(duration: 0.44),
                                value: heroResolved
                            )
                    }
                    
                    VStack(spacing: PPSpace.md) {
                        messageButton
                        callButton
                        rateButton
                    }
                    .padding(.top, PPSpace.sm)
                    .opacity(heroResolved ? 1 : 0)
                    .animation(
                        reduceMotion ? .none : .easeOut(duration: 0.48),
                        value: heroResolved
                    )
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, safeAreaTop + PPSpace.xl)
            .padding(.bottom, PPSpace.xxxl)
        }
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            if reduceMotion {
                heroResolved = true
                avatarResolved = true
            } else {
                withAnimation(.easeOut(duration: 0.52)) {
                    heroResolved = true
                }
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    avatarResolved = true
                }
            }
        }
    }
    
    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }
    
    @ViewBuilder
    private var ambientBackground: some View {
        ZStack {
            Color.ppBackground
            
            if colorSchemeContrast != .increased {
                RadialGradient(
                    colors: [
                        Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.16 : 0.10),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 24,
                    endRadius: 420
                )
            }
        }
    }
    
    @ViewBuilder
    private var avatarStack: some View {
        VStack(spacing: 0) {
            ZStack {
                avatarBreathingHalo
                
                avatarShell
                
                avatarInner
            }
            
            Text(store.providerName)
                .font(.caption.bold())
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(1)
                .accessibilityHidden(true)
        }
        .frame(width: avatarDiameter, height: avatarDiameter + 20)
        .offset(y: -120)
    }
    
    private let avatarDiameter: CGFloat = 96
    
    @ViewBuilder
    private var avatarBreathingHalo: some View {
        Circle()
            .fill(Color.clear)
            .frame(width: avatarDiameter + 32, height: avatarDiameter + 32)
            .shadow(color: Color.ppPrimary.opacity(0.18), radius: 16, x: 0, y: 0)
            .opacity(store.isLive ? (reduceMotion ? 1 : 0.6) : 0)
            .animation(
                store.isLive && !reduceMotion
                    ? .easeOut(duration: 0.48).repeatForever(autoreversing: true)
                    : .none,
                value: store.isLive
            )
    }
    
    @ViewBuilder
    private var avatarShell: some View {
        Circle()
            .fill(Color.ppSurface)
            .frame(width: avatarDiameter + 8, height: avatarDiameter + 8)
            .overlay(
                Circle()
                    .strokeBorder(Color.ppBorder.opacity(0.42), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.12), radius: 14, x: 0, y: 7)
    }
    
    @ViewBuilder
    private var avatarInner: some View {
        Circle()
            .trim(from: 0, to: 0.99)
            .stroke(Color.ppSecondarySurface, lineWidth: 1.5)
            .frame(width: avatarDiameter, height: avatarDiameter)
            .overlay {
                Group {
                    if let url = store.avatarURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: avatarDiameter * 0.5, weight: .semibold))
                            .foregroundStyle(Color.ppTextTertiary)
                    }
                }
                .frame(width: avatarDiameter, height: avatarDiameter)
                .clipShape(Circle())
            }
    }
    
    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        HStack(spacing: PPSpace.xs) {
            Circle()
                .fill(Color.ppSuccess)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            
            Text(status)
                .font(.caption.medium)
                .foregroundStyle(Color.ppSuccess)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status)
    }
    
    @ViewBuilder
    private var messageButton: some View {
        Button {
            store.onMessage()
        } label: {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "message.fill")
                    .font(.system(size: 18, weight: .bold))
                Text(store.location == .phone ? "Message" : "Contact")
                    .font(.headline.bold())
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.ppPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color.ppPrimary.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .opacity(store.canMessage ? 1 : 0.55)
        .accessibilityLabel(store.location == .phone ? "Message Provider" : "Contact Provider")
    }
    
    @ViewBuilder
    private var callButton: some View {
        Button {
            store.onCall()
        } label: {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: store.location == .phone ? "phone.fill" : "video.phone")
                    .font(.system(size: 18, weight: .bold))
                Text(store.location == .phone ? "Call" : "Video Call")
                    .font(.headline.bold())
            }
            .foregroundStyle(Color.ppPrimary)
            .padding(.horizontal, PPSpace.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.ppSecondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.ppPrimary.opacity(0.6), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .opacity(store.canCall ? 1 : 0.55)
        .accessibilityLabel(store.location == .phone ? "Call Provider" : "Video Call Provider")
    }
    
    @ViewBuilder
    private var rateButton: some View {
        Button {
            store.onRate()
        } label: {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.ppWarning)
                Text("Rate Provider")
                    .font(.headline.bold())
                    .foregroundStyle(Color.ppWarning)
            }
            .padding(.horizontal, PPSpace.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.ppWarning.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.ppWarning.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(store.canRate ? 1 : 0.4)
        .accessibilityLabel("Rate Provider")
    }
}