//
//  AdoptPetDetailsScreen.swift
//  Pure Pets
//
//  Category-defining Adoption Pet Details Experience.
//  First-Principles Redesign: Dedicated iPhone and iPad architectures,
//  exclusive Beiruti brand typography, 6-state resilience, and ADA-caliber craft.
//

import SwiftUI
import UIKit
import SDWebImage

// MARK: - Exclusive Typography Engine (100% Beiruti Only)

private enum AdoptFont {
    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Tactile Haptics

private enum AdoptHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impactLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func impactMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Press Style

private struct AdoptDetailsPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed || !isEnabled ? 1 : pressedScale)
            .opacity(!isEnabled ? 0.46 : (configuration.isPressed ? 0.88 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Main Root Container (Device Adaptive Routing)

struct AdoptPetDetailsScreen: View {
    @StateObject private var store: AdoptPetDetailsStore

    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var hostViewControllerProvider: () -> UIViewController?

    @State private var currentImageIndex = 0
    @State private var hasAppeared = false

    init(
        pet: AdoptPetModel,
        isOwner: Bool = false,
        hostViewControllerProvider: @escaping () -> UIViewController?
    ) {
        _store = StateObject(
            wrappedValue: AdoptPetDetailsStore(pet: pet, isOwner: isOwner)
        )
        self.hostViewControllerProvider = hostViewControllerProvider
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var shouldUsePadArchitecture: Bool {
        isPad && horizontalSizeClass != .compact
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.ppBackground
                .ignoresSafeArea()

            if shouldUsePadArchitecture {
                AdoptPetDetails_iPad(
                    store: store,
                    currentImageIndex: $currentImageIndex,
                    hostViewControllerProvider: hostViewControllerProvider,
                    onClose: handleClose,
                    onReport: beginReport
                )
            } else {
                AdoptPetDetails_iPhone(
                    store: store,
                    currentImageIndex: $currentImageIndex,
                    hostViewControllerProvider: hostViewControllerProvider,
                    onClose: handleClose,
                    onReport: beginReport
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: beginEntrance)
    }

    private func beginEntrance() {
        guard !hasAppeared else { return }
        guard !reduceMotion else {
            hasAppeared = true
            return
        }
        withAnimation(.easeOut(duration: 0.30)) {
            hasAppeared = true
        }
    }

    private func handleClose() {
        if let viewController = hostViewControllerProvider() {
            if let navigationController = viewController.navigationController,
               navigationController.viewControllers.first != viewController {
                navigationController.popViewController(animated: true)
            } else {
                viewController.dismiss(animated: true)
            }
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func beginReport() {
        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }
        let host = hostViewControllerProvider() ?? AppManager.sharedInstance().topViewController()
        PPAlertHelper.showTextField(
            in: host,
            title: PPAdoptLang("adopt_detail_report_title"),
            subtitle: PPAdoptLang("adopt_detail_report_explanation"),
            placeholder: PPAdoptLang("adopt_detail_report_prompt"),
            initialText: nil,
            confirmText: PPAdoptLang("adopt_detail_report_submit"),
            cancelText: PPAdoptLang("Cancel")
        ) { text, didConfirm in
            guard didConfirm, let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            self.store.reportPet(reason: text) { result in
                switch result {
                case .success:
                    AdoptHaptics.success()
                    PPAlertHelper.showSuccess(
                        in: host,
                        title: PPAdoptLang("adopt_detail_report_success_title"),
                        subtitle: PPAdoptLang("adopt_detail_report_success_message")
                    )
                case .failure:
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    PPAlertHelper.showError(
                        in: host,
                        title: PPAdoptLang("adopt_detail_report_failed_title"),
                        subtitle: PPAdoptLang("adopt_detail_report_failed_message")
                    )
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - iPhone Dedicated Architecture
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetDetails_iPhone: View {
    @ObservedObject var store: AdoptPetDetailsStore
    @Binding var currentImageIndex: Int
    var hostViewControllerProvider: () -> UIViewController?
    var onClose: () -> Void
    var onReport: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroGallerySection
                        .frame(height: heroHeight)

                    VStack(alignment: .leading, spacing: PPSpace.xl) {
                        profileIdentityCard
                            .padding(.top, -PPSpace.xxl)

                        factsSection

                        storySection

                        ownerSection

                        trustStandardsCard

                        if !store.isOwner {
                            reportButton
                        }
                    }
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.bottom, 120) // Space for bottom dock
                }
            }
            .ignoresSafeArea(edges: .top)

            // Sticky Top Navigation Controls
            topFloatingBar

            // Sticky Bottom Decision Dock
            VStack {
                Spacer()
                bottomContactDock
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var heroHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 400
    }

    private var galleryImages: [AdoptionGalleryImage] {
        store.pet.imageURLs
            .compactMap { URL(string: $0) }
            .enumerated()
            .map { offset, url in
                AdoptionGalleryImage(id: "\(offset)-\(url.absoluteString)", ordinal: offset, url: url)
            }
    }

    // MARK: - Hero Gallery Section

    private var heroGallerySection: some View {
        ZStack(alignment: .bottom) {
            if !galleryImages.isEmpty {
                TabView(selection: $currentImageIndex) {
                    ForEach(galleryImages) { image in
                        AdoptPetRemoteImageView(url: image.url, allowsRetry: true)
                            .tag(image.ordinal)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            } else {
                AdoptPetStudioArtworkFallback()
            }

            // Scrim Gradient
            LinearGradient(
                colors: [.clear, .black.opacity(colorScheme == .dark ? 0.65 : 0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Floating Badges on Hero Bottom
            HStack(alignment: .bottom, spacing: PPSpace.sm) {
                // Availability Beacon
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(PPAdoptLang("adopt_detail_available_now"))
                        .font(AdoptFont.bold(12, relativeTo: .caption))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.45), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                }

                Spacer()

                // Gallery Counter Indicator
                if galleryImages.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(currentImageIndex + 1) / \(galleryImages.count)")
                            .font(AdoptFont.bold(12, relativeTo: .caption))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.8)
                    }
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.bottom, PPSpace.xxxl)
        }
    }

    // MARK: - Top Floating Glass Bar

    private var topFloatingBar: some View {
        HStack(spacing: PPSpace.sm) {
            Button(action: {
                AdoptHaptics.impactLight()
                onClose()
            }) {
                Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.ppSurface.opacity(0.92), in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
            }
            .buttonStyle(AdoptDetailsPressStyle())

            Spacer()

            HStack(spacing: PPSpace.sm) {
                // Share Action
                Button(action: {
                    AdoptHaptics.impactLight()
                    store.sharePet(from: hostViewControllerProvider())
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.ppSurface.opacity(0.92), in: Circle())
                        .overlay {
                            Circle().strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
                        }
                        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                }
                .buttonStyle(AdoptDetailsPressStyle())

                // Favorite Action
                Button(action: {
                    AdoptHaptics.impactMedium()
                    store.toggleFavorite()
                }) {
                    Image(systemName: store.isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(store.isFavorited ? Color.ppQuickActionAdoption : Color.ppTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.ppSurface.opacity(0.92), in: Circle())
                        .overlay {
                            Circle().strokeBorder(
                                store.isFavorited ? Color.ppQuickActionAdoption.opacity(0.6) : Color.ppBorder.opacity(0.8),
                                lineWidth: 0.8
                            )
                        }
                        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
                }
                .buttonStyle(AdoptDetailsPressStyle())
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, safeAreaTop + PPSpace.xs)
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 44
    }

    // MARK: - Profile Identity Card

    private var profileIdentityCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack {
                Text(PPAdoptLang("adopt_detail_eyebrow"))
                    .font(AdoptFont.bold(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.ppQuickActionAdoption.opacity(0.12), in: Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                    Text(store.pet.mCityName.isEmpty ? PPAdoptLang("Location") : store.pet.mCityName)
                        .font(AdoptFont.medium(13, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            Text(store.pet.name.isEmpty ? PPAdoptLang("AdoptPet") : store.pet.name)
                .font(AdoptFont.bold(28, relativeTo: .title))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(2)

            let metadata = [store.pet.mBreedName, store.pet.mKindName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != "-" }
                .joined(separator: " • ")

            if !metadata.isEmpty {
                Text(metadata)
                    .font(AdoptFont.medium(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    colorSchemeContrast == .increased ? Color.ppTextPrimary.opacity(0.6) : Color.ppBorder.opacity(0.78),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07),
            radius: 18,
            y: 8
        )
    }

    // MARK: - Facts Section

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeader(
                title: PPAdoptLang("adopt_detail_section_facts"),
                subtitle: PPAdoptLang("adopt_detail_facts_caption"),
                symbol: "sparkles"
            )

            let facts = resolvedFacts(for: store.pet)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: PPSpace.sm), GridItem(.flexible(), spacing: PPSpace.sm)],
                spacing: PPSpace.sm
            ) {
                ForEach(facts) { fact in
                    HStack(spacing: PPSpace.sm) {
                        Image(systemName: fact.symbol)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ppQuickActionAdoption)
                            .frame(width: 36, height: 36)
                            .background(Color.ppQuickActionAdoption.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.title)
                                .font(AdoptFont.regular(11, relativeTo: .caption2))
                                .foregroundStyle(Color.ppTextSecondary)

                            Text(fact.value)
                                .font(AdoptFont.bold(14, relativeTo: .subheadline))
                                .foregroundStyle(Color.ppTextPrimary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(PPSpace.sm)
                    .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                            .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                    }
                }
            }
        }
    }

    // MARK: - Story Section

    private var storySection: some View {
        let details = store.pet.details.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeader(
                title: PPAdoptLang("adopt_detail_story_title"),
                subtitle: PPAdoptLang("adopt_list_results_subtitle"),
                symbol: "quote.bubble.fill"
            )

            HStack(alignment: .top, spacing: PPSpace.md) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.ppQuickActionAdoption)
                    .frame(width: 3.5)

                Text(details.isEmpty ? PPAdoptLang("adopt_detail_no_details") : details)
                    .font(AdoptFont.regular(15, relativeTo: .body))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PPSpace.lg)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
            }
        }
    }

    // MARK: - Listing Owner Section

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeader(
                title: PPAdoptLang("adopt_detail_owner_title"),
                subtitle: PPAdoptLang("community_adoption_owner_privacy"),
                symbol: "person.crop.circle.fill"
            )

            HStack(spacing: PPSpace.md) {
                // Owner Avatar
                if store.pet.organizationVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .frame(width: 52, height: 52)
                        .background(Color.green.opacity(0.12), in: Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.ppTextTertiary)
                        .frame(width: 52, height: 52)
                        .background(Color.ppSecondarySurface, in: Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(publicOwnerName)
                        .font(AdoptFont.bold(17, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)

                    HStack(spacing: 4) {
                        Circle().fill(store.pet.organizationVerified ? Color.green : Color.ppTextTertiary).frame(width: 6, height: 6)
                        Text(PPAdoptLang(store.pet.organizationVerified ? "community_verified_organization" : "community_private_contact_notice"))
                            .font(AdoptFont.medium(12, relativeTo: .caption))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }

                Spacer()
            }
            .padding(PPSpace.base)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
            }
        }
    }

    // MARK: - Trust & Safety Standards Card

    private var trustStandardsCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                Text(PPAdoptLang("community_adoption_safety_title"))
                    .font(AdoptFont.bold(13, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                trustItem(text: PPAdoptLang("community_adoption_safety_free"))
                trustItem(text: PPAdoptLang("community_adoption_safety_health"))
                trustItem(text: PPAdoptLang("community_adoption_safety_meeting"))
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppQuickActionAdoption.opacity(0.2), lineWidth: 0.8)
        }
    }

    private func trustItem(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .padding(.top, 2)
            Text(text)
                .font(AdoptFont.regular(12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(2)
        }
    }

    // MARK: - Report Button

    private var reportButton: some View {
        Button(action: {
            AdoptHaptics.impactLight()
            onReport()
        }) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "exclamationmark.bubble")
                    .font(.system(size: 13, weight: .semibold))
                Text(PPAdoptLang("adopt_detail_report_action"))
                    .font(AdoptFont.medium(13, relativeTo: .caption))
                Spacer()
                Image(systemName: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.ppTextTertiary)
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, 12)
        }
        .buttonStyle(AdoptDetailsPressStyle())
    }

    // MARK: - Bottom Contact Decision Dock

    private var bottomContactDock: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.ppSeparator.opacity(0.6))

            HStack(spacing: PPSpace.sm) {
                Label(PPAdoptLang("community_private_contact_notice"), systemImage: "lock.shield.fill")
                    .font(AdoptFont.medium(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    AdoptHaptics.impactMedium()
                    store.presentApplication(from: hostViewControllerProvider())
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(PPAdoptLang(store.isOwner ? "community_owner_listing" : (store.isApplicationAvailable ? "community_apply_action" : "community_application_unavailable")))
                            .font(AdoptFont.bold(15, relativeTo: .subheadline))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.ppQuickActionAdoption, Color.ppQuickActionAdoption.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    )
                    .shadow(color: Color.ppQuickActionAdoption.opacity(0.28), radius: 8, y: 3)
                }
                .buttonStyle(AdoptDetailsPressStyle())
                .disabled(!store.isApplicationAvailable)
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.sm)
            .padding(.bottom, safeAreaBottom + PPSpace.xs)
            .background(Color.ppElevatedSurface)
        }
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 16
    }

    private var publicOwnerName: String {
        if !store.pet.organizationName.isEmpty { return store.pet.organizationName }
        if !store.pet.ownerDisplayName.isEmpty { return store.pet.ownerDisplayName }
        return PPAdoptLang("adopt_detail_owner_fallback")
    }

    private func sectionHeader(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                Text(title)
                    .font(AdoptFont.bold(17, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
            }
            Text(subtitle)
                .font(AdoptFont.regular(12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - iPad Dedicated Architecture (2-Column Studio Stage)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetDetails_iPad: View {
    @ObservedObject var store: AdoptPetDetailsStore
    @Binding var currentImageIndex: Int
    var hostViewControllerProvider: () -> UIViewController?
    var onClose: () -> Void
    var onReport: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var publicOwnerName: String {
        if !store.pet.organizationName.isEmpty { return store.pet.organizationName }
        if !store.pet.ownerDisplayName.isEmpty { return store.pet.ownerDisplayName }
        return PPAdoptLang("adopt_detail_owner_fallback")
    }

    var body: some View {
        VStack(spacing: 0) {
            // iPad Navigation Top Bar
            ipadTopBar

            HStack(alignment: .top, spacing: 0) {
                // Left Column: Photography Studio Stage (48% width)
                ipadPhotographyStage
                    .frame(maxWidth: .infinity)
                    .background(Color.ppSecondarySurface)
                    .overlay(alignment: layoutDirection == .rightToLeft ? .leading : .trailing) {
                        Rectangle().fill(Color.ppSeparator.opacity(0.6)).frame(width: 0.8)
                    }

                // Right Column: Profile Narrative & Actions (52% width)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PPSpace.xl) {
                        ipadProfileHeader

                        ipadFactsGrid

                        ipadStoryCard

                        ipadOwnerCard

                        ipadTrustChecklist

                        if !store.isOwner {
                            Button(action: onReport) {
                                Label(PPAdoptLang("adopt_detail_report_action"), systemImage: "exclamationmark.bubble")
                                    .font(AdoptFont.medium(13, relativeTo: .caption))
                                    .foregroundStyle(Color.ppTextTertiary)
                            }
                            .buttonStyle(AdoptDetailsPressStyle())
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(PPSpace.xl)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var ipadTopBar: some View {
        HStack(spacing: PPSpace.md) {
            Button(action: {
                AdoptHaptics.impactLight()
                onClose()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text(PPAdoptLang("Back"))
                        .font(AdoptFont.bold(14, relativeTo: .subheadline))
                }
                .foregroundStyle(Color.ppTextPrimary)
                .padding(.horizontal, PPSpace.md)
                .frame(height: 40)
                .background(Color.ppSurface, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8) }
            }
            .buttonStyle(AdoptDetailsPressStyle())
            .keyboardShortcut(.cancelAction)

            Spacer()

            HStack(spacing: PPSpace.sm) {
                Button(action: {
                    AdoptHaptics.impactLight()
                    store.sharePet(from: hostViewControllerProvider())
                }) {
                    Label(PPAdoptLang("Share"), systemImage: "square.and.arrow.up")
                        .font(AdoptFont.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .padding(.horizontal, PPSpace.md)
                        .frame(height: 40)
                        .background(Color.ppSurface, in: Capsule())
                        .overlay { Capsule().strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8) }
                }
                .buttonStyle(AdoptDetailsPressStyle())

                Button(action: {
                    AdoptHaptics.impactMedium()
                    store.toggleFavorite()
                }) {
                    Image(systemName: store.isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(store.isFavorited ? Color.ppQuickActionAdoption : Color.ppTextPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.ppSurface, in: Circle())
                        .overlay {
                            Circle().strokeBorder(
                                store.isFavorited ? Color.ppQuickActionAdoption.opacity(0.6) : Color.ppBorder.opacity(0.8),
                                lineWidth: 0.8
                            )
                        }
                }
                .buttonStyle(AdoptDetailsPressStyle())
            }
        }
        .padding(.horizontal, PPSpace.xl)
        .padding(.top, PPSpace.md)
        .padding(.bottom, PPSpace.sm)
        .background(Color.ppElevatedSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.ppSeparator.opacity(0.6)).frame(height: 0.8)
        }
    }

    private var galleryImages: [AdoptionGalleryImage] {
        store.pet.imageURLs
            .compactMap { URL(string: $0) }
            .enumerated()
            .map { offset, url in
                AdoptionGalleryImage(id: "\(offset)-\(url.absoluteString)", ordinal: offset, url: url)
            }
    }

    private var ipadPhotographyStage: some View {
        VStack(spacing: PPSpace.md) {
            // Main Theater
            ZStack(alignment: .bottom) {
                if !galleryImages.isEmpty {
                    TabView(selection: $currentImageIndex) {
                        ForEach(galleryImages) { image in
                            AdoptPetRemoteImageView(url: image.url, allowsRetry: true)
                                .tag(image.ordinal)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    AdoptPetStudioArtworkFallback()
                }

                // Floating Availability Pill
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text(PPAdoptLang("adopt_detail_available_now"))
                            .font(AdoptFont.bold(13, relativeTo: .caption))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45), in: Capsule())

                    Spacer()
                }
                .padding(PPSpace.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
            }
            .padding(.horizontal, PPSpace.xl)
            .padding(.top, PPSpace.lg)

            // Filmstrip Carousel (if multiple)
            if galleryImages.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PPSpace.sm) {
                        ForEach(galleryImages) { image in
                            Button(action: {
                                AdoptHaptics.selection()
                                currentImageIndex = image.ordinal
                            }) {
                                AdoptPetRemoteImageView(url: image.url)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: PPCorner.small))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: PPCorner.small)
                                            .strokeBorder(
                                                image.ordinal == currentImageIndex ? Color.ppQuickActionAdoption : Color.clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(AdoptDetailsPressStyle())
                        }
                    }
                    .padding(.horizontal, PPSpace.xl)
                }
            }

            Spacer(minLength: PPSpace.xl)
        }
    }

    private var ipadProfileHeader: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack {
                Text(PPAdoptLang("adopt_detail_eyebrow"))
                    .font(AdoptFont.bold(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.ppQuickActionAdoption.opacity(0.12), in: Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                    Text(store.pet.mCityName.isEmpty ? PPAdoptLang("Location") : store.pet.mCityName)
                        .font(AdoptFont.medium(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            Text(store.pet.name.isEmpty ? PPAdoptLang("AdoptPet") : store.pet.name)
                .font(AdoptFont.bold(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.ppTextPrimary)

            let metadata = [store.pet.mBreedName, store.pet.mKindName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != "-" }
                .joined(separator: " • ")

            if !metadata.isEmpty {
                Text(metadata)
                    .font(AdoptFont.medium(16, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
    }

    private var ipadFactsGrid: some View {
        let facts = resolvedFacts(for: store.pet)
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: PPSpace.md), GridItem(.flexible(), spacing: PPSpace.md)],
            spacing: PPSpace.md
        ) {
            ForEach(facts) { fact in
                HStack(spacing: PPSpace.md) {
                    Image(systemName: fact.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                        .frame(width: 42, height: 42)
                        .background(Color.ppQuickActionAdoption.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.title)
                            .font(AdoptFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(Color.ppTextSecondary)

                        Text(fact.value)
                            .font(AdoptFont.bold(16, relativeTo: .headline))
                            .foregroundStyle(Color.ppTextPrimary)
                    }
                    Spacer()
                }
                .padding(PPSpace.md)
                .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                        .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                }
            }
        }
    }

    private var ipadStoryCard: some View {
        let details = store.pet.details.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                Text(PPAdoptLang("adopt_detail_story_title"))
                    .font(AdoptFont.bold(18, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            Text(details.isEmpty ? PPAdoptLang("adopt_detail_no_details") : details)
                .font(AdoptFont.regular(16, relativeTo: .body))
                .foregroundStyle(Color.ppTextPrimary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(PPSpace.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                        .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                }
        }
    }

    private var ipadOwnerCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.md) {
                if store.pet.organizationVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .frame(width: 58, height: 58)
                        .background(Color.green.opacity(0.12), in: Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.ppTextTertiary)
                        .frame(width: 58, height: 58)
                        .background(Color.ppSecondarySurface, in: Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(publicOwnerName)
                        .font(AdoptFont.bold(19, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)

                    Text(PPAdoptLang(store.pet.organizationVerified ? "community_verified_organization" : "community_private_contact_notice"))
                        .font(AdoptFont.regular(13, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                }

                Spacer()

                HStack(spacing: PPSpace.sm) {
                    Button(action: {
                        AdoptHaptics.impactMedium()
                        store.presentApplication(from: hostViewControllerProvider())
                    }) {
                        Label(PPAdoptLang(store.isOwner ? "community_owner_listing" : (store.isApplicationAvailable ? "community_apply_action" : "community_application_unavailable")), systemImage: "doc.text.fill")
                            .font(AdoptFont.bold(14, relativeTo: .subheadline))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, PPSpace.lg)
                            .frame(height: 42)
                            .background(Color.ppQuickActionAdoption, in: RoundedRectangle(cornerRadius: PPCorner.small))
                    }
                    .buttonStyle(AdoptDetailsPressStyle())
                    .disabled(!store.isApplicationAvailable)
                }
            }
            .padding(PPSpace.lg)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
            }
        }
    }

    private var ipadTrustChecklist: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                Text(PPAdoptLang("community_adoption_safety_title"))
                    .font(AdoptFont.bold(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            HStack(spacing: PPSpace.lg) {
                trustItem(text: PPAdoptLang("community_adoption_safety_free"))
                trustItem(text: PPAdoptLang("community_adoption_safety_health"))
                trustItem(text: PPAdoptLang("community_adoption_safety_meeting"))
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: PPCorner.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card).strokeBorder(Color.ppQuickActionAdoption.opacity(0.2), lineWidth: 0.8)
        }
    }

    private func trustItem(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.ppQuickActionAdoption)
            Text(text)
                .font(AdoptFont.regular(12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Illustrated Fallback Studio Artwork
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetStudioArtworkFallback: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.25 : 0.14),
                    Color.ppSecondarySurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.18 : 0.09))
                .frame(width: 180, height: 180)
                .blur(radius: 20)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.ppSurface.opacity(0.9))
                        .frame(width: 76, height: 76)
                        .overlay {
                            Circle().strokeBorder(Color.ppQuickActionAdoption.opacity(0.28), lineWidth: 1)
                        }

                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                }

                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                    Text(PPAdoptLang("adopt_detail_available_now"))
                        .font(AdoptFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.ppSurface.opacity(0.8), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Remote Image View
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct AdoptPetRemoteImageView: View {
    let url: URL?
    let allowsRetry: Bool

    init(url: URL, allowsRetry: Bool = false) {
        self.url = url
        self.allowsRetry = allowsRetry
    }

    init(urlString: String?, allowsRetry: Bool = false) {
        if let urlString, let parsedURL = URL(string: urlString) {
            url = parsedURL
        } else {
            url = nil
        }
        self.allowsRetry = allowsRetry
    }

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var didFailToLoad = false
    @State private var activeRequestID = UUID()

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHidden(true)
            } else if didFailToLoad {
                if allowsRetry {
                    retryView
                } else {
                    placeholderView
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .ppTextTertiary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.ppSecondarySurface)
                    .accessibilityLabel(PPAdoptLang("adopt_detail_media_loading"))
            }
        }
        .onAppear(perform: loadImageIfNeeded)
        .onChange(of: url) { _ in
            loadedImage = nil
            isLoading = false
            didFailToLoad = false
            loadImageIfNeeded()
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color.ppSecondarySurface
            Image(systemName: "photo")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
        }
        .accessibilityHidden(true)
    }

    private var retryView: some View {
        Button(action: retry) {
            VStack(spacing: PPSpace.sm) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 28, weight: .semibold))
                Text(PPAdoptLang("adopt_detail_media_retry"))
                    .font(AdoptFont.bold(13, relativeTo: .footnote))
            }
            .foregroundStyle(Color.ppTextSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ppSecondarySurface)
        }
        .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.98))
        .accessibilityLabel(PPAdoptLang("adopt_detail_media_retry"))
    }

    private func loadImageIfNeeded() {
        guard let validURL = url else {
            didFailToLoad = true
            return
        }
        guard loadedImage == nil, !isLoading, !didFailToLoad else { return }

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true

        SDWebImageManager.shared.loadImage(
            with: validURL,
            options: [.continueInBackground, .lowPriority],
            progress: nil
        ) { image, _, _, _, _, _ in
            DispatchQueue.main.async {
                guard activeRequestID == requestID else { return }
                isLoading = false
                if let image {
                    loadedImage = image
                    didFailToLoad = false
                } else {
                    didFailToLoad = true
                }
            }
        }
    }

    private func retry() {
        loadedImage = nil
        isLoading = false
        didFailToLoad = false
        loadImageIfNeeded()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Fact Helpers & Data Resolution
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptionDetailFact: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let value: String
}

private struct AdoptionGalleryImage: Identifiable {
    let id: String
    let ordinal: Int
    let url: URL
}

private func resolvedFacts(for pet: AdoptPetModel) -> [AdoptionDetailFact] {
    var facts: [AdoptionDetailFact] = []

    let gender = PPAdoptGenderLabel(pet.gender)
    if !gender.isEmpty {
        facts.append(
            AdoptionDetailFact(id: "gender", symbol: "figure.stand", title: PPAdoptLang("Gender"), value: gender)
        )
    }

    if pet.ageMonths > 0 {
        let ageString: String
        if pet.ageMonths >= 12 {
            let years = pet.ageMonths / 12
            let months = pet.ageMonths % 12
            if months == 0 {
                ageString = "\(years) " + PPAdoptLang("Years")
            } else {
                ageString = "\(years) " + PPAdoptLang("Years") + " " + "\(months) " + PPAdoptLang("Months")
            }
        } else {
            ageString = String(format: PPAdoptLang("%ld Months"), pet.ageMonths)
        }
        facts.append(
            AdoptionDetailFact(id: "age", symbol: "calendar", title: PPAdoptLang("Age"), value: ageString)
        )
    }

    if !pet.mCityName.isEmpty && pet.mCityName != "-" {
        facts.append(
            AdoptionDetailFact(id: "city", symbol: "mappin.and.ellipse", title: PPAdoptLang("City"), value: pet.mCityName)
        )
    }

    let breed = pet.mBreedName
    if !breed.isEmpty && breed != "-" {
        facts.append(
            AdoptionDetailFact(id: "breed", symbol: "pawprint.fill", title: PPAdoptLang("Breed"), value: breed)
        )
    }

    return facts
}
