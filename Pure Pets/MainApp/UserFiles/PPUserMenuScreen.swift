//
//  PPUserMenuScreen.swift
//  Pure Pets
//
//  Created for PurePets Category-Defining iOS & iPadOS Experience.
//

import SwiftUI
import UIKit

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. STRICT TYPOGRAPHY MANDATE (100% BEIRUTI)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public enum PPUserMenuFont {
    public static func bold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: textStyle)
    }
    public static func medium(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: textStyle)
    }
    public static func regular(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: textStyle)
    }
    public static func black(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Black", size: size, relativeTo: textStyle)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. ACTION ENUM & PROTOCOL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@objc public enum PPUserMenuActionType: Int {
    case profile = 0
    case login
    case favorites
    case myAds
    case cart
    case purchased
    case orders
    case production
    case settings
    case support
    case logout
    case pureLens
    case toggleAppearance
    case switchLanguage
    case requestNotifications
    case requestLocation
}

@objc public protocol PPUserMenuHostingDelegate: AnyObject {
    func userMenuDidSelectAction(_ action: PPUserMenuActionType)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. OBSERVABLE STATE MODEL
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public final class PPUserMenuState: ObservableObject {
    @Published public var isLoggedIn: Bool = false
    @Published public var displayName: String = ""
    @Published public var metaInfo: String = ""
    @Published public var avatarURL: URL? = nil
    @Published public var cartCount: Int = 0
    @Published public var activeOrdersCount: Int = 0
    @Published public var favoritesCount: Int = 0
    @Published public var myAdsCount: Int = 0
    @Published public var isProductionActive: Bool = false
    
    // Quick Access Settings States
    @Published public var appearanceTitleKey: String = "DarkMode"
    @Published public var appearanceIcon: String = "moon.fill"
    @Published public var appearanceTint: Color = .indigo
    @Published public var isArabic: Bool = true
    @Published public var languageTitleKey: String = "English"
    @Published public var notificationsAuthorized: Bool = false
    @Published public var countryCode: String = "QA"
    @Published public var countryFlag: String = "🇶🇦"
    
    // Telemetry & States
    @Published public var isLoading: Bool = false
    @Published public var isOffline: Bool = false
    @Published public var recentOrderStep: Int = 2 // 0: Placed, 1: Confirmed, 2: Preparing, 3: In Transit, 4: Delivered
    @Published public var hasActiveInFlightOrder: Bool = true

    public init() {}
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. CARD INTERACTION BUTTON STYLE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPMenuCardButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.975
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 5. SHARED COMPONENTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Avatar view with concentric status rings and fallback initials
struct PPUserAvatarView: View {
    let url: URL?
    let name: String
    let isLoggedIn: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            // Concentric aura ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: isLoggedIn
                            ? [Color.ppPrimary.opacity(0.8), Color.ppPrimary.opacity(0.2)]
                            : [Color.ppWarning.opacity(0.6), Color.ppWarning.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .frame(width: size + 8, height: size + 8)

            // Inner image or fallback
            Group {
                if let url = url, !url.absoluteString.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            fallbackInitialsView
                        }
                    }
                } else {
                    fallbackInitialsView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            
            // Status dot pill
            Circle()
                .fill(isLoggedIn ? Color.ppSuccess : Color.ppWarning)
                .frame(width: max(10, size * 0.16), height: max(10, size * 0.16))
                .overlay(Circle().stroke(Color.ppSurfaceElevated, lineWidth: 2))
                .offset(x: size * 0.35, y: size * 0.35)
        }
    }

    private var fallbackInitialsView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ppPrimary.opacity(0.18), Color.ppPrimary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials(from: name))
                .font(PPUserMenuFont.bold(size: size * 0.38, relativeTo: .title3))
                .foregroundColor(Color.ppPrimary)
        }
    }

    private func initials(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "PP" }
        let components = trimmed.components(separatedBy: " ")
        if components.count >= 2, let first = components.first?.first, let second = components[1].first {
            return "\(first)\(second)"
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}

/// Tactile 2x2 Quick Access Sensory Tile
struct PPQuickAccessTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PPUserMenuFont.bold(size: 15, relativeTo: .subheadline))
                        .foregroundColor(Color.ppTextPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(PPUserMenuFont.medium(size: 12, relativeTo: .caption))
                        .foregroundColor(Color.ppTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ppSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(PPMenuCardButtonStyle())
    }
}

/// PureLens Vanguard AI Camera Portal Card
struct PPPureLensVanguardCard: View {
    let onLaunch: () -> Void

    @State private var pulseAura: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLaunch()
        }) {
            ZStack {
                // Background surface
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.ppSurfaceElevated,
                                Color.ppPrimary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.ppPrimary.opacity(pulseAura ? 0.45 : 0.20),
                                        Color.ppSurfaceBorder
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.ppPrimary.opacity(0.08), radius: 16, x: 0, y: 6)

                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        // AI Camera Scanner Icon Plate
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.ppPrimary, Color.ppPressedAction],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .shadow(color: Color.ppPrimary.opacity(0.35), radius: 8, x: 0, y: 4)

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(NSLocalizedString("pure_lens_account_title", comment: ""))
                                    .font(PPUserMenuFont.bold(size: 19, relativeTo: .title3))
                                    .foregroundColor(Color.ppTextPrimary)

                                Text(NSLocalizedString("pure_lens_account_live_vision", comment: ""))
                                    .font(PPUserMenuFont.bold(size: 9.5, relativeTo: .caption2))
                                    .foregroundColor(Color.ppPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.ppPrimary.opacity(0.12)))
                            }

                            Text(NSLocalizedString("home_pure_lens_subtitle", comment: ""))
                                .font(PPUserMenuFont.regular(size: 13, relativeTo: .footnote))
                                .foregroundColor(Color.ppTextSecondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color.ppPrimary)
                    }

                    // 3-step connected recognition pipeline
                    HStack(spacing: 8) {
                        stepPill(symbol: "camera.fill", titleKey: "pure_lens_account_camera", tint: Color.ppPrimary)
                        connectorLine
                        stepPill(symbol: "viewfinder", titleKey: "pure_lens_account_recognize", tint: Color.ppSuccess)
                        connectorLine
                        stepPill(symbol: "sparkles", titleKey: "pure_lens_account_discover", tint: Color.ppInfo)
                    }
                }
                .padding(18)
            }
        }
        .buttonStyle(PPMenuCardButtonStyle())
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    pulseAura = true
                }
            }
        }
    }

    private func stepPill(symbol: String, titleKey: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(PPUserMenuFont.medium(size: 11.5, relativeTo: .caption))
                .foregroundColor(Color.ppTextSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.ppSurfaceBase.opacity(0.85))
                .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.8))
        )
    }

    private var connectorLine: some View {
        Rectangle()
            .fill(Color.ppPrimary.opacity(0.2))
            .frame(height: 1.5)
            .frame(maxWidth: .infinity)
    }
}

/// High-Craft Interactive Activity Card
struct PPActivityMenuRow: View {
    let icon: String
    let titleKey: String
    let subtitleKey: String
    let tint: Color
    var badgeCount: Int = 0
    var badgeText: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: isDestructive ? .medium : .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                // Icon Plate
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(isDestructive ? 0.12 : 0.13))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(tint)
                }

                // Title & Subtitle Stack
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString(titleKey, comment: ""))
                        .font(PPUserMenuFont.bold(size: 16, relativeTo: .headline))
                        .foregroundColor(isDestructive ? Color.ppError : Color.ppTextPrimary)
                        .lineLimit(1)

                    Text(NSLocalizedString(subtitleKey, comment: ""))
                        .font(PPUserMenuFont.regular(size: 12.5, relativeTo: .footnote))
                        .foregroundColor(isDestructive ? Color.ppError.opacity(0.7) : Color.ppTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Optional Telemetry Badge
                if let badgeText = badgeText, !badgeText.isEmpty {
                    Text(badgeText)
                        .font(PPUserMenuFont.bold(size: 11.5, relativeTo: .caption))
                        .foregroundColor(tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule().fill(tint.opacity(0.12))
                        )
                } else if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(PPUserMenuFont.bold(size: 12, relativeTo: .caption))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule().fill(tint)
                        )
                }

                // Directional Chevron
                if !isDestructive {
                    Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.ppTextTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.ppSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isDestructive ? Color.ppError.opacity(0.2) : Color.ppSurfaceBorder, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.035), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(PPMenuCardButtonStyle())
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 6. DEDICATED IPHONE ARCHITECTURE (THUMB-ZONE)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPUserMenuPhoneView: View {
    @ObservedObject var state: PPUserMenuState
    let onAction: (PPUserMenuActionType) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Offline Notice Pill if applicable
                if state.isOffline {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 13, weight: .semibold))
                        Text(NSLocalizedString("user_menu_offline_pill", comment: ""))
                            .font(PPUserMenuFont.medium(size: 12.5, relativeTo: .caption))
                        Spacer()
                        Button(action: { onAction(.profile) }) {
                            Text(NSLocalizedString("user_menu_retry_action", comment: ""))
                                .font(PPUserMenuFont.bold(size: 12, relativeTo: .caption))
                                .underline()
                        }
                    }
                    .foregroundColor(Color.ppWarning)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.ppWarning.opacity(0.12))
                    )
                    .padding(.horizontal, 20)
                }

                // 1. Hero Identity Vitrine Card
                heroProfileVitrine

                // 2. Tactical Command Matrix (Quick Access 2x2)
                quickAccessMatrix

                // 3. PureLens Vanguard AI Portal
                PPPureLensVanguardCard(onLaunch: {
                    onAction(.pureLens)
                })
                .padding(.horizontal, 20)

                // 4. Activity Ecosystem Section
                activitySection

                // 5. Tools & Account Safety Section
                toolsSection

                // Bottom safe inset padding
                Spacer(minLength: 36)
            }
            .padding(.top, 10)
        }
        .background(Color.ppBackground.ignoresSafeArea())
    }

    // Hero Profile Vitrine
    private var heroProfileVitrine: some View {
        ZStack {
            // High-Craft Glass Container
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.ppSurfaceElevated,
                            Color.ppWarmPorcelain.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1.0)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 7)

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Interactive Avatar
                    PPUserAvatarView(
                        url: state.avatarURL,
                        name: state.displayName,
                        isLoggedIn: state.isLoggedIn,
                        size: 74
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        // Eyebrow & Member Status Chip
                        HStack(spacing: 6) {
                            Text(state.isLoggedIn
                                 ? NSLocalizedString("user_menu_signed_in_eyebrow", comment: "")
                                 : NSLocalizedString("user_menu_guest_eyebrow", comment: ""))
                                .font(PPUserMenuFont.bold(size: 11.5, relativeTo: .caption))
                                .foregroundColor(Color.ppTextSecondary)

                            Text(state.isLoggedIn
                                 ? NSLocalizedString("user_menu_member_verified", comment: "")
                                 : NSLocalizedString("user_menu_member_guest", comment: ""))
                                .font(PPUserMenuFont.bold(size: 10, relativeTo: .caption2))
                                .foregroundColor(state.isLoggedIn ? Color.ppPrimary : Color.ppWarning)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(
                                        (state.isLoggedIn ? Color.ppPrimary : Color.ppWarning).opacity(0.12)
                                    )
                                )
                        }

                        // Display Name
                        Text(state.displayName.isEmpty ? "PurePets" : state.displayName)
                            .font(PPUserMenuFont.bold(size: 22, relativeTo: .title2))
                            .foregroundColor(Color.ppTextPrimary)
                            .lineLimit(1)

                        // Meta subtitle
                        Text(state.metaInfo.isEmpty
                             ? (state.isLoggedIn
                                ? NSLocalizedString("user_menu_subtitle", comment: "")
                                : NSLocalizedString("user_menu_guest_subtitle", comment: ""))
                             : state.metaInfo)
                            .font(PPUserMenuFont.regular(size: 12.5, relativeTo: .footnote))
                            .foregroundColor(Color.ppTextSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }

                Divider()
                    .background(Color.ppSurfaceBorder)

                // Primary Action Button (Edit Profile or Login)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAction(state.isLoggedIn ? .profile : .login)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: state.isLoggedIn ? "square.and.pencil" : "person.crop.circle.badge.plus")
                            .font(.system(size: 15, weight: .bold))

                        Text(state.isLoggedIn
                             ? NSLocalizedString("user_menu_profile_action", comment: "")
                             : NSLocalizedString("user_menu_login_action", comment: ""))
                            .font(PPUserMenuFont.bold(size: 15, relativeTo: .subheadline))

                        Spacer()

                        Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.ppPrimary, Color.ppPressedAction],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.ppPrimary.opacity(0.28), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PPMenuCardButtonStyle())
            }
            .padding(18)
        }
        .padding(.horizontal, 20)
    }

    // Quick Access 2x2 Matrix
    private var quickAccessMatrix: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("user_menu_quick_access_title", comment: ""))
                .font(PPUserMenuFont.bold(size: 14, relativeTo: .footnote))
                .foregroundColor(Color.ppTextSecondary)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                // Appearance Tile
                PPQuickAccessTile(
                    icon: state.appearanceIcon,
                    title: NSLocalizedString(state.appearanceTitleKey, comment: ""),
                    subtitle: NSLocalizedString("quick_access_desc_appearance", comment: ""),
                    tint: state.appearanceTint
                ) {
                    onAction(.toggleAppearance)
                }

                // Language Tile
                PPQuickAccessTile(
                    icon: "globe.central.south.asia",
                    title: NSLocalizedString(state.languageTitleKey, comment: ""),
                    subtitle: NSLocalizedString("quick_access_desc_language", comment: ""),
                    tint: state.isArabic ? Color.ppInfo : Color.ppSuccess
                ) {
                    onAction(.switchLanguage)
                }

                // Notifications Tile
                PPQuickAccessTile(
                    icon: "bell.fill",
                    title: NSLocalizedString("Allow Alerts", comment: ""),
                    subtitle: NSLocalizedString("quick_access_desc_notifications", comment: ""),
                    tint: Color.ppError
                ) {
                    onAction(.requestNotifications)
                }

                // Location Tile
                PPQuickAccessTile(
                    icon: "location.fill",
                    title: "\(state.countryFlag) \(state.countryCode)",
                    subtitle: NSLocalizedString("quick_access_desc_location", comment: ""),
                    tint: Color.ppCareAccent
                ) {
                    onAction(.requestLocation)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // Activity Section
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("user_menu_activity_section", comment: ""))
                .font(PPUserMenuFont.bold(size: 14, relativeTo: .footnote))
                .foregroundColor(Color.ppTextSecondary)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                // Cart
                PPActivityMenuRow(
                    icon: "cart.fill",
                    titleKey: "Cart",
                    subtitleKey: "user_menu_cart_subtitle",
                    tint: Color.ppSuccess,
                    badgeCount: state.cartCount
                ) {
                    onAction(.cart)
                }

                // Order History
                PPActivityMenuRow(
                    icon: "bag.fill",
                    titleKey: "OrderHistory",
                    subtitleKey: "user_menu_orders_subtitle",
                    tint: Color.ppPrimary,
                    badgeCount: state.activeOrdersCount
                ) {
                    onAction(.orders)
                }

                // Favorites
                PPActivityMenuRow(
                    icon: "star.fill",
                    titleKey: "showfav",
                    subtitleKey: "user_menu_favorites_subtitle",
                    tint: Color.ppWarning,
                    badgeCount: state.favoritesCount
                ) {
                    onAction(.favorites)
                }

                // My Ads
                PPActivityMenuRow(
                    icon: "circle.hexagonpath.fill",
                    titleKey: "myadsTitle",
                    subtitleKey: "user_menu_ads_subtitle",
                    tint: Color.purple,
                    badgeCount: state.myAdsCount
                ) {
                    onAction(.myAds)
                }

                // Purchased Items
                PPActivityMenuRow(
                    icon: "bag.badge.plus",
                    titleKey: "purchased_profile_menu_title",
                    subtitleKey: "user_menu_purchased_subtitle",
                    tint: Color.ppInfo
                ) {
                    onAction(.purchased)
                }

                // Production (if active)
                if state.isProductionActive {
                    PPActivityMenuRow(
                        icon: "doc.on.doc.fill",
                        titleKey: "showProdection",
                        subtitleKey: "user_menu_production_subtitle",
                        tint: Color.orange
                    ) {
                        onAction(.production)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // Tools & Security Section
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("user_menu_tools_section", comment: ""))
                .font(PPUserMenuFont.bold(size: 14, relativeTo: .footnote))
                .foregroundColor(Color.ppTextSecondary)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                // Settings
                PPActivityMenuRow(
                    icon: "gearshape.fill",
                    titleKey: "Setting",
                    subtitleKey: "user_menu_settings_subtitle",
                    tint: Color.gray
                ) {
                    onAction(.settings)
                }

                // Support & Location
                PPActivityMenuRow(
                    icon: "person.crop.circle.badge.questionmark",
                    titleKey: "supprot",
                    subtitleKey: "user_menu_support_subtitle",
                    tint: Color.ppCareAccent
                ) {
                    onAction(.support)
                }

                // Logout (if logged in)
                if state.isLoggedIn {
                    PPActivityMenuRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        titleKey: "logout",
                        subtitleKey: "user_menu_logout_subtitle",
                        tint: Color.ppError,
                        isDestructive: true
                    ) {
                        onAction(.logout)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 7. DEDICATED IPADOS ARCHITECTURE (SPATIAL WORKBENCH)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPUserMenuPadView: View {
    @ObservedObject var state: PPUserMenuState
    let onAction: (PPUserMenuActionType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 1. LEADING COMMAND COLUMN (380pt)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Master Profile Vitrine
                    padProfileVitrine

                    // PureLens Vanguard AI Hub
                    PPPureLensVanguardCard(onLaunch: {
                        onAction(.pureLens)
                    })
                    .hoverEffect(.lift)

                    // Quick Access Sensory Matrix (4 Tiles)
                    padQuickAccessMatrix

                    // Pinned Tools & Safe Logout
                    padToolsCard

                    Spacer(minLength: 24)
                }
                .padding(24)
            }
            .frame(width: 380)
            .background(Color.ppSurfaceBase.ignoresSafeArea())
            .overlay(
                Rectangle()
                    .fill(Color.ppSurfaceBorder)
                    .frame(width: 1),
                alignment: Language.isRTL() ? .leading : .trailing
            )

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 2. TRAILING SPATIAL WORKSPACE (FLUID)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("user_menu_ipad_dashboard_title", comment: ""))
                                .font(PPUserMenuFont.bold(size: 28, relativeTo: .title))
                                .foregroundColor(Color.ppTextPrimary)

                            Text(NSLocalizedString("user_menu_ipad_dashboard_subtitle", comment: ""))
                                .font(PPUserMenuFont.regular(size: 14, relativeTo: .subheadline))
                                .foregroundColor(Color.ppTextSecondary)
                        }
                        Spacer()

                        // Live Status Pill
                        HStack(spacing: 6) {
                            Circle()
                                .fill(state.isOffline ? Color.ppWarning : Color.ppSuccess)
                                .frame(width: 8, height: 8)
                            Text(state.isOffline
                                 ? NSLocalizedString("user_menu_offline_pill", comment: "")
                                 : NSLocalizedString("user_menu_profile_status_ready", comment: ""))
                                .font(PPUserMenuFont.medium(size: 12, relativeTo: .caption))
                                .foregroundColor(Color.ppTextSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.ppSurfaceElevated))
                    }

                    // 1. Metric Telemetry Cards Deck (4 in a row)
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        padMetricCard(titleKey: "user_menu_stat_orders", count: state.activeOrdersCount, icon: "bag.fill", tint: Color.ppPrimary) {
                            onAction(.orders)
                        }
                        padMetricCard(titleKey: "user_menu_stat_cart", count: state.cartCount, icon: "cart.fill", tint: Color.ppSuccess) {
                            onAction(.cart)
                        }
                        padMetricCard(titleKey: "user_menu_stat_favorites", count: state.favoritesCount, icon: "star.fill", tint: Color.ppWarning) {
                            onAction(.favorites)
                        }
                        padMetricCard(titleKey: "user_menu_stat_ads", count: state.myAdsCount, icon: "circle.hexagonpath.fill", tint: Color.purple) {
                            onAction(.myAds)
                        }
                    }

                    // 2. Active In-Flight Order Live Tracker Banner
                    padOrderTrackerBanner

                    // 3. Marketplace & Activity Navigation Deck (2-Column Grid)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(NSLocalizedString("user_menu_activity_section", comment: ""))
                            .font(PPUserMenuFont.bold(size: 18, relativeTo: .headline))
                            .foregroundColor(Color.ppTextPrimary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                            padActivityTile(
                                icon: "cart.fill",
                                titleKey: "Cart",
                                subtitleKey: "user_menu_cart_subtitle",
                                tint: Color.ppSuccess,
                                count: state.cartCount
                            ) {
                                onAction(.cart)
                            }

                            padActivityTile(
                                icon: "bag.fill",
                                titleKey: "OrderHistory",
                                subtitleKey: "user_menu_orders_subtitle",
                                tint: Color.ppPrimary,
                                count: state.activeOrdersCount
                            ) {
                                onAction(.orders)
                            }

                            padActivityTile(
                                icon: "star.fill",
                                titleKey: "showfav",
                                subtitleKey: "user_menu_favorites_subtitle",
                                tint: Color.ppWarning,
                                count: state.favoritesCount
                            ) {
                                onAction(.favorites)
                            }

                            padActivityTile(
                                icon: "circle.hexagonpath.fill",
                                titleKey: "myadsTitle",
                                subtitleKey: "user_menu_ads_subtitle",
                                tint: Color.purple,
                                count: state.myAdsCount
                            ) {
                                onAction(.myAds)
                            }

                            padActivityTile(
                                icon: "bag.badge.plus",
                                titleKey: "purchased_profile_menu_title",
                                subtitleKey: "user_menu_purchased_subtitle",
                                tint: Color.ppInfo
                            ) {
                                onAction(.purchased)
                            }

                            if state.isProductionActive {
                                padActivityTile(
                                    icon: "doc.on.doc.fill",
                                    titleKey: "showProdection",
                                    subtitleKey: "user_menu_production_subtitle",
                                    tint: Color.orange
                                ) {
                                    onAction(.production)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(28)
            }
            .background(Color.ppBackground.ignoresSafeArea())
        }
    }

    // iPad Master Profile Vitrine
    private var padProfileVitrine: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.ppSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 5)

            VStack(spacing: 16) {
                PPUserAvatarView(
                    url: state.avatarURL,
                    name: state.displayName,
                    isLoggedIn: state.isLoggedIn,
                    size: 88
                )

                VStack(spacing: 4) {
                    Text(state.displayName.isEmpty ? "PurePets" : state.displayName)
                        .font(PPUserMenuFont.bold(size: 22, relativeTo: .title2))
                        .foregroundColor(Color.ppTextPrimary)
                        .multilineTextAlignment(.center)

                    Text(state.isLoggedIn
                         ? NSLocalizedString("user_menu_member_verified", comment: "")
                         : NSLocalizedString("user_menu_member_guest", comment: ""))
                        .font(PPUserMenuFont.bold(size: 11, relativeTo: .caption))
                        .foregroundColor(state.isLoggedIn ? Color.ppPrimary : Color.ppWarning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill((state.isLoggedIn ? Color.ppPrimary : Color.ppWarning).opacity(0.12))
                        )

                    Text(state.metaInfo.isEmpty
                         ? (state.isLoggedIn
                            ? NSLocalizedString("user_menu_subtitle", comment: "")
                            : NSLocalizedString("user_menu_guest_subtitle", comment: ""))
                         : state.metaInfo)
                        .font(PPUserMenuFont.regular(size: 12.5, relativeTo: .footnote))
                        .foregroundColor(Color.ppTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAction(state.isLoggedIn ? .profile : .login)
                }) {
                    HStack {
                        Image(systemName: state.isLoggedIn ? "square.and.pencil" : "person.crop.circle.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                        Text(state.isLoggedIn
                             ? NSLocalizedString("user_menu_profile_action", comment: "")
                             : NSLocalizedString("user_menu_login_action", comment: ""))
                            .font(PPUserMenuFont.bold(size: 14, relativeTo: .subheadline))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color.ppPrimary, Color.ppPressedAction],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PPMenuCardButtonStyle())
                .hoverEffect(.lift)
            }
            .padding(20)
        }
    }

    // iPad Quick Access Matrix
    private var padQuickAccessMatrix: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("user_menu_quick_access_title", comment: ""))
                .font(PPUserMenuFont.bold(size: 13, relativeTo: .footnote))
                .foregroundColor(Color.ppTextSecondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                PPQuickAccessTile(
                    icon: state.appearanceIcon,
                    title: NSLocalizedString(state.appearanceTitleKey, comment: ""),
                    subtitle: NSLocalizedString("quick_access_desc_appearance", comment: ""),
                    tint: state.appearanceTint
                ) {
                    onAction(.toggleAppearance)
                }
                .hoverEffect(.highlight)

                PPQuickAccessTile(
                    icon: "globe.central.south.asia",
                    title: NSLocalizedString(state.languageTitleKey, comment: ""),
                    subtitle: NSLocalizedString("quick_access_desc_language", comment: ""),
                    tint: state.isArabic ? Color.ppInfo : Color.ppSuccess
                ) {
                    onAction(.switchLanguage)
                }
                .hoverEffect(.highlight)

                PPQuickAccessTile(
                    icon: "bell.fill",
                    title: NSLocalizedString("Allow Alerts", comment: ""),
                    subtitle: NSLocalizedString("quick_access_desc_notifications", comment: ""),
                    tint: Color.ppError
                ) {
                    onAction(.requestNotifications)
                }
                .hoverEffect(.highlight)

                PPQuickAccessTile(
                    icon: "location.fill",
                    title: "\(state.countryFlag) \(state.countryCode)",
                    subtitle: NSLocalizedString("quick_access_desc_location", comment: ""),
                    tint: Color.ppCareAccent
                ) {
                    onAction(.requestLocation)
                }
                .hoverEffect(.highlight)
            }
        }
    }

    // iPad Pinned Tools Card
    private var padToolsCard: some View {
        VStack(spacing: 8) {
            PPActivityMenuRow(
                icon: "gearshape.fill",
                titleKey: "Setting",
                subtitleKey: "user_menu_settings_subtitle",
                tint: Color.gray
            ) {
                onAction(.settings)
            }
            .hoverEffect(.highlight)

            PPActivityMenuRow(
                icon: "person.crop.circle.badge.questionmark",
                titleKey: "supprot",
                subtitleKey: "user_menu_support_subtitle",
                tint: Color.ppCareAccent
            ) {
                onAction(.support)
            }
            .hoverEffect(.highlight)

            if state.isLoggedIn {
                PPActivityMenuRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    titleKey: "logout",
                    subtitleKey: "user_menu_logout_subtitle",
                    tint: Color.ppError,
                    isDestructive: true
                ) {
                    onAction(.logout)
                }
                .hoverEffect(.highlight)
            }
        }
    }

    // iPad Metric Card
    private func padMetricCard(titleKey: String, count: Int, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(tint)
                    }
                    Spacer()
                    Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.ppTextTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(PPUserMenuFont.bold(size: 26, relativeTo: .title))
                        .foregroundColor(Color.ppTextPrimary)

                    Text(NSLocalizedString(titleKey, comment: ""))
                        .font(PPUserMenuFont.medium(size: 13, relativeTo: .footnote))
                        .foregroundColor(Color.ppTextSecondary)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.ppSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(PPMenuCardButtonStyle())
        .hoverEffect(.lift)
    }

    // iPad Live Order Tracker
    private var padOrderTrackerBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ppSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.ppPrimary)

                        Text(NSLocalizedString("user_menu_order_tracker_title", comment: ""))
                            .font(PPUserMenuFont.bold(size: 17, relativeTo: .headline))
                            .foregroundColor(Color.ppTextPrimary)
                    }

                    Spacer()

                    Button(action: { onAction(.orders) }) {
                        Text(NSLocalizedString("user_menu_orders_subtitle", comment: ""))
                            .font(PPUserMenuFont.medium(size: 12.5, relativeTo: .footnote))
                            .foregroundColor(Color.ppPrimary)
                    }
                }

                if state.hasActiveInFlightOrder {
                    // Milestone Stepper
                    HStack(spacing: 0) {
                        stepperNode(titleKey: "user_menu_order_step_placed", step: 0, current: state.recentOrderStep)
                        stepperConnector(step: 0, current: state.recentOrderStep)
                        stepperNode(titleKey: "user_menu_order_step_confirmed", step: 1, current: state.recentOrderStep)
                        stepperConnector(step: 1, current: state.recentOrderStep)
                        stepperNode(titleKey: "user_menu_order_step_preparing", step: 2, current: state.recentOrderStep)
                        stepperConnector(step: 2, current: state.recentOrderStep)
                        stepperNode(titleKey: "user_menu_order_step_in_transit", step: 3, current: state.recentOrderStep)
                        stepperConnector(step: 3, current: state.recentOrderStep)
                        stepperNode(titleKey: "user_menu_order_step_delivered", step: 4, current: state.recentOrderStep)
                    }
                } else {
                    HStack {
                        Text(NSLocalizedString("user_menu_order_tracker_empty", comment: ""))
                            .font(PPUserMenuFont.regular(size: 13, relativeTo: .footnote))
                            .foregroundColor(Color.ppTextSecondary)
                        Spacer()
                    }
                }
            }
            .padding(20)
        }
    }

    private func stepperNode(titleKey: String, step: Int, current: Int) -> some View {
        let isDone = step <= current
        let isCurrent = step == current
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.ppPrimary : Color.ppSurfaceBase)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(isCurrent ? Color.ppPrimary.opacity(0.35) : Color.clear, lineWidth: 4))

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text(NSLocalizedString(titleKey, comment: ""))
                .font(PPUserMenuFont.medium(size: 11, relativeTo: .caption2))
                .foregroundColor(isDone ? Color.ppTextPrimary : Color.ppTextTertiary)
        }
    }

    private func stepperConnector(step: Int, current: Int) -> some View {
        Rectangle()
            .fill(step < current ? Color.ppPrimary : Color.ppSurfaceBorder)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
    }

    // iPad Activity Tile (Rich Grid Item)
    private func padActivityTile(icon: String, titleKey: String, subtitleKey: String, tint: Color, count: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString(titleKey, comment: ""))
                        .font(PPUserMenuFont.bold(size: 17, relativeTo: .headline))
                        .foregroundColor(Color.ppTextPrimary)

                    Text(NSLocalizedString(subtitleKey, comment: ""))
                        .font(PPUserMenuFont.regular(size: 13, relativeTo: .footnote))
                        .foregroundColor(Color.ppTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(PPUserMenuFont.bold(size: 13, relativeTo: .caption))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(tint))
                }

                Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.ppTextTertiary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.ppSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(PPMenuCardButtonStyle())
        .hoverEffect(.lift)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 8. ROOT ADAPTIVE SCREEN CONTAINER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public struct PPUserMenuRootView: View {
    @ObservedObject public var state: PPUserMenuState
    public let onAction: (PPUserMenuActionType) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(state: PPUserMenuState, onAction: @escaping (PPUserMenuActionType) -> Void) {
        self.state = state
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                PPUserMenuPadView(state: state, onAction: onAction)
            } else {
                PPUserMenuPhoneView(state: state, onAction: onAction)
            }
        }
        .environment(\.layoutDirection, state.isArabic ? .rightToLeft : .leftToRight)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 9. UIKIT HOSTING CONTROLLER BRIDGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@objc(PPUserMenuHostingController)
public final class PPUserMenuHostingController: UIViewController {
    @objc public weak var delegate: PPUserMenuHostingDelegate?
    public let state = PPUserMenuState()
    private var hostingController: UIHostingController<PPUserMenuRootView>?

    @objc public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let rootView = PPUserMenuRootView(state: state) { [weak self] action in
            self?.delegate?.userMenuDidSelectAction(action)
        }

        let hosting = UIHostingController(rootView: rootView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hosting)
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        self.hostingController = hosting

        refreshState()
    }

    @objc public func refreshState() {
        // Sync with UserManager
        let user = UserManager.shared().currentUser
        let loggedIn = (user != nil)
        state.isLoggedIn = loggedIn

        if let user = user {
            let bestName = user.ppBestDisplayName()
            state.displayName = !bestName.isEmpty ? bestName : "PurePets"
            state.avatarURL = user.userImageUrl
            let email = user.userEmail
            state.metaInfo = !email.isEmpty ? email : (user.mobileNo ?? "")
            state.isProductionActive = (user.prodectionStatus.lowercased() == "active")
        } else {
            state.displayName = "PurePets"
            state.avatarURL = nil
            state.metaInfo = ""
            state.isProductionActive = false
        }

        // Cart Count
        state.cartCount = PPHomeDataBridge.currentCartItemCount()

        // Appearance Mode
        let currentTheme = PPThemeManager.shared().loadUserInterfaceStyle()
        let visualStyle = traitCollection.userInterfaceStyle
        let isDark = (visualStyle == .dark)

        if isDark {
            state.appearanceTitleKey = "LightMode"
            state.appearanceIcon = "sun.max.fill"
            state.appearanceTint = .yellow
        } else if currentTheme == .light {
            state.appearanceTitleKey = "SystemMode"
            state.appearanceIcon = "iphone"
            state.appearanceTint = .blue
        } else {
            state.appearanceTitleKey = "DarkMode"
            state.appearanceIcon = "moon.fill"
            state.appearanceTint = .indigo
        }

        // Language
        state.isArabic = Language.isRTL()
        state.languageTitleKey = state.isArabic ? "English" : "Arabic"

        // Country
        if let code = CountryModel.safeCurrentCountryISOCode(), !code.isEmpty {
            state.countryCode = code.uppercased()
            state.countryFlag = (state.countryCode == "QA") ? "🇶🇦" : "📍"
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshState()
    }
}
