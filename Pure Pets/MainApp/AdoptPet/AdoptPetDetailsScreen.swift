//
//  AdoptPetDetailsScreen.swift
//  Pure Pets
//
//  Production SwiftUI Adopt Pet Details Experience.
//  Redesign: Companion Ledger — cover-to-contact adoption profile.
//

import SwiftUI
import UIKit
import SDWebImage

// MARK: - Screen

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

    @State private var currentImageIndex: Int = 0
    @State private var showingReportAlert: Bool = false
    @State private var reportReasonText: String = ""
    @State private var showingReportSuccess: Bool = false
    @State private var showingReportFailure: Bool = false
    @State private var reportFailureMessage: String = ""
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

    var body: some View {
        ZStack(alignment: .bottom) {
            detailAtmosphere
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroGallery

                    VStack(spacing: PPSpace.xl) {
                        identityOverview
                        factsSection
                        storySection
                        ownerSection
                        if !store.isOwner {
                            reportButton
                        }
                    }
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.top, -PPSpace.xl)

                    Spacer(minLength: store.isOwner ? PPSpace.xxxl : bottomDockClearance)
                }
            }

            topOverlayNavigationBar

            if !store.isOwner {
                bottomContactDock
            }
        }
        .navigationBarHidden(true)
        .alert(PPAdoptLang("adopt_detail_report_title"), isPresented: $showingReportAlert) {
            TextField(PPAdoptLang("adopt_detail_report_prompt"), text: $reportReasonText)
            Button(PPAdoptLang("adopt_detail_report_submit"), action: submitReport)
                .disabled(
                    reportReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || store.isReporting
                )
            Button(PPAdoptLang("Cancel"), role: .cancel) { }
        } message: {
            Text(PPAdoptLang("adopt_detail_report_explanation"))
        }
        .alert(PPAdoptLang("adopt_detail_report_success_title"), isPresented: $showingReportSuccess) {
            Button(PPAdoptLang("OK"), role: .cancel) { }
        } message: {
            Text(PPAdoptLang("adopt_detail_report_success_message"))
        }
        .alert(PPAdoptLang("adopt_detail_report_failed_title"), isPresented: $showingReportFailure) {
            Button(PPAdoptLang("OK"), role: .cancel) { }
        } message: {
            Text(reportFailureMessage)
        }
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.34)) {
                    hasAppeared = true
                }
            }
        }
    }

    private var detailAtmosphere: some View {
        ZStack {
            Color.ppBackground

            if colorSchemeContrast != .increased {
                RadialGradient(
                    colors: [
                        Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.10 : 0.07),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 18,
                    endRadius: 360
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Top Chrome

    private var topOverlayNavigationBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: PPSpace.sm) {
                Button(action: handleClose) {
                    Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            Color.ppSurface.opacity(0.92),
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.ppBorder.opacity(0.75), lineWidth: 0.8)
                        )
                        .shadow(
                            color: Color.black.opacity(0.08),
                            radius: 8,
                            y: 3
                        )
                }
                .buttonStyle(AdoptDetailsPressStyle())
                .accessibilityLabel(PPAdoptLang("Back"))

                Spacer(minLength: 0)

                HStack(spacing: PPSpace.sm) {
                    iconButton(symbol: "square.and.arrow.up", label: PPAdoptLang("Share")) {
                        store.sharePet(from: hostViewControllerProvider())
                    }

                    iconButton(
                        symbol: store.isFavorited ? "heart.fill" : "heart",
                        label: store.isFavorited ? PPAdoptLang("Unfavorite") : PPAdoptLang("Favorite")
                    ) {
                        store.toggleFavorite()
                    }
                    .foregroundStyle(store.isFavorited ? Color.ppPrimary : Color.ppTextPrimary)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.md)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    private func iconButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(
                    symbol == "heart.fill" ? Color.ppPrimary : Color.ppTextPrimary
                )
                .frame(width: 42, height: 42)
                .background(
                    Color.ppSurface.opacity(0.92),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.ppBorder.opacity(0.75), lineWidth: 0.8)
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 8,
                    y: 3
                )
        }
        .buttonStyle(AdoptDetailsPressStyle())
        .accessibilityLabel(label)
    }

    // MARK: - Hero Gallery

    private var heroHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 318
        }
        return horizontalSizeClass == .regular ? 456 : 390
    }

    private var bottomDockClearance: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 184 : 112
    }

    private var heroGallery: some View {
        let imageURLs = store.pet.imageURLs
        let hasImages = !imageURLs.isEmpty

        return ZStack(alignment: .bottom) {
            Group {
                if hasImages {
                    TabView(selection: $currentImageIndex) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                            AdoptPetRemoteImageView(urlString: url, allowsRetry: true)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .accessibilityLabel(PPAdoptLang("adopt_detail_gallery_label"))
                    .accessibilityValue(
                        String(
                            format: PPAdoptLang("adopt_detail_gallery_value_format"),
                            currentImageIndex + 1,
                            imageURLs.count
                        )
                    )
                } else {
                    ZStack {
                        PPGradient.softBrandField
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundStyle(Color.ppQuickActionAdoption.opacity(0.48))
                    }
                    .accessibilityLabel(PPAdoptLang("adopt_detail_media_unavailable"))
                }
            }
            .frame(maxWidth: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(colorScheme == .dark ? 0.62 : 0.42)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 128)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            HStack(alignment: .center, spacing: PPSpace.sm) {
                availabilityBadge

                Spacer(minLength: 0)

                if imageURLs.count > 1 {
                    Text(
                        String(
                            format: PPAdoptLang("adopt_detail_gallery_value_format"),
                            currentImageIndex + 1,
                            imageURLs.count
                        )
                    )
                    .font(PPFont.bold(12))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, PPSpace.sm)
                    .padding(.vertical, PPSpace.xs)
                    .background(Color.black.opacity(0.32), in: Capsule())
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.bottom, PPSpace.xxl)
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
    }

    private var availabilityBadge: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10, weight: .bold))
            Text(PPAdoptLang("adopt_detail_available_now"))
                .font(PPFont.bold(11))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .background(Color.ppQuickActionAdoption.opacity(0.96), in: Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Identity Overview

    private var identityOverview: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(store.pet.name.isEmpty ? PPAdoptLang("AdoptPet") : store.pet.name)
                .font(PPFont.title1())
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(0.84)
                .fixedSize(horizontal: false, vertical: true)

            let kind = store.pet.mKindName
            let breed = store.pet.mBreedName
            let city = store.pet.mCityName
            let subtitleParts = [breed, kind, city].filter { !$0.isEmpty && $0 != "-" }

            Text(subtitleParts.isEmpty ? PPAdoptLang("adopt_detail_available_now") : subtitleParts.joined(separator: "  •  "))
                .font(PPFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PPSpace.xs) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .bold))
                    .accessibilityHidden(true)
                Text(PPAdoptLang("adopt_detail_available_now"))
                    .font(PPFont.medium(12))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.ppQuickActionAdoption)
        }
        .padding(PPSpace.lg)
        .background(Color.ppElevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.8),
                    lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.8
                )
        )
        .shadow(
            color: colorSchemeContrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: 16,
            y: 6
        )
    }

    // MARK: - Facts

    private var factColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_section_facts"),
                symbol: "doc.text.magnifyingglass"
            )

            LazyVGrid(columns: factColumns, spacing: PPSpace.sm) {
                if !store.pet.gender.isEmpty {
                    factTile(
                        icon: "person.fill",
                        title: PPAdoptLang("Gender"),
                        value: PPAdoptGenderLabel(store.pet.gender)
                    )
                }

                if store.pet.ageMonths > 0 {
                    let ageText = String(format: PPAdoptLang("%ld Months"), store.pet.ageMonths)
                    factTile(icon: "calendar", title: PPAdoptLang("Age"), value: ageText)
                }

                if !store.pet.mCityName.isEmpty {
                    factTile(icon: "mappin.circle.fill", title: PPAdoptLang("City"), value: store.pet.mCityName)
                }

                let breed = store.pet.mBreedName
                if !breed.isEmpty && breed != "-" {
                    factTile(icon: "pawprint.fill", title: PPAdoptLang("Breed"), value: breed)
                }
            }
        }
    }

    private func sectionHeading(title: String, symbol: String) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .frame(width: 28, height: 28)
                .background(Color.ppQuickActionAdoption.opacity(0.11), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(PPFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
        }
    }

    private func factTile(icon: String, title: String, value: String) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .frame(width: 32, height: 32)
                .background(
                    Color.ppQuickActionAdoption.opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PPFont.caption1())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                Text(value)
                    .font(PPFont.bold(13))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .background(Color.ppSecondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Story

    private var storySection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_story_title"),
                symbol: "text.quote"
            )

            let details = store.pet.details.trimmingCharacters(in: .whitespacesAndNewlines)
            HStack(alignment: .top, spacing: PPSpace.md) {
                Capsule(style: .continuous)
                    .fill(Color.ppQuickActionAdoption)
                    .frame(width: 3)
                    .padding(.vertical, 2)
                    .accessibilityHidden(true)

                Text(details.isEmpty ? PPAdoptLang("adopt_detail_no_details") : details)
                    .font(PPFont.body())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PPSpace.base)
            .background(Color.ppSurface)
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
    }

    // MARK: - Listing Owner

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_owner_title"),
                symbol: "person.crop.circle"
            )

            HStack(alignment: .center, spacing: PPSpace.sm) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    if store.isLoadingOwner {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(PPAdoptLang("adopt_detail_owner_loading"))
                    }

                    Text(store.ownerUser?.bestDisplayName() ?? PPAdoptLang("adopt_detail_owner_fallback"))
                        .font(PPFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)

                    Text(
                        store.isOwnerContactUnavailable
                            ? PPAdoptLang("adopt_detail_contact_unavailable")
                            : PPAdoptLang("adopt_detail_owner_caption")
                    )
                        .font(PPFont.caption1())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                    if store.isOwnerContactUnavailable {
                        Button(PPAdoptLang("Retry")) {
                            store.retryOwnerLoading()
                        }
                        .font(PPFont.medium(13))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                        .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.98))
                        .accessibilityLabel(PPAdoptLang("Retry"))
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppSecondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
        // Keep recovery actionable in VoiceOver: combining this card would
        // swallow the Retry button into the owner summary.
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var avatar: some View {
        if let owner = store.ownerUser,
           let photoURL = owner.userImageUrl?.absoluteString,
           URL(string: photoURL) != nil {
            AdoptPetRemoteImageView(urlString: photoURL)
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color.ppSecondarySurface)
                    .frame(width: 52, height: 52)
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.ppTextTertiary)
            }
        }
    }

    // MARK: - Report Button

    private var reportButton: some View {
        Button(action: beginReport) {
            HStack(spacing: PPSpace.xs) {
                if store.isReporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(
                    store.isReporting
                        ? PPAdoptLang("adopt_detail_report_submitting")
                        : PPAdoptLang("adopt_detail_report_action")
                )
                    .font(PPFont.medium(14))
            }
            .foregroundStyle(Color.ppTextSecondary)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.99))
        .disabled(store.isReporting)
        .accessibilityLabel(PPAdoptLang("adopt_detail_report_action"))
    }

    // MARK: - Bottom Contact Dock

    private var bottomContactDock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(0.65))
                .frame(height: 0.5)
                .accessibilityHidden(true)

            contactActions
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.vertical, PPSpace.md)
            .background {
                if reduceTransparency {
                    Color.ppElevatedSurface
                } else {
                    Color.ppElevatedSurface
                        .opacity(colorScheme == .dark ? 0.9 : 0.96)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    @ViewBuilder
    private var contactActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                chatActionButton
                callActionButton
            }
        } else {
            HStack(spacing: PPSpace.sm) {
                callActionButton
                chatActionButton
            }
        }
    }

    private var callActionButton: some View {
        Button {
            store.contactOwnerByCall(from: hostViewControllerProvider())
        } label: {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .bold))
                if store.isLoadingOwner {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
                Text(
                    store.isLoadingOwner
                        ? PPAdoptLang("adopt_detail_contact_loading")
                        : PPAdoptLang("Call")
                )
                    .font(PPFont.bold(15))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, PPSpace.base)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(
                Color.ppSecondarySurface,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
            )
        }
        .buttonStyle(AdoptDetailsPressStyle())
        .disabled(!store.canCallOwner)
        .opacity(store.canCallOwner || store.isLoadingOwner ? 1 : 0.55)
        .accessibilityLabel(PPAdoptLang("Call"))
        .accessibilityHint(
            store.canCallOwner
                ? ""
                : (store.isLoadingOwner
                    ? PPAdoptLang("adopt_detail_contact_loading")
                    : PPAdoptLang("adopt_detail_contact_unavailable_message"))
        )
    }

    private var chatActionButton: some View {
        Button {
            store.contactOwnerByChat(from: hostViewControllerProvider())
        } label: {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 17, weight: .bold))
                if store.isLoadingOwner {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
                Text(
                    store.isLoadingOwner
                        ? PPAdoptLang("adopt_detail_contact_loading")
                        : PPAdoptLang("adopt_detail_contact_action")
                )
                    .font(PPFont.bold(15))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, PPSpace.sm)
            .background(
                PPGradient.hero,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .shadow(
                color: Color.ppPrimary.opacity(colorSchemeContrast == .increased ? 0 : 0.24),
                radius: 10,
                y: 4
            )
        }
        .buttonStyle(AdoptDetailsPressStyle())
        .disabled(!store.canChatOwner)
        .opacity(store.canChatOwner || store.isLoadingOwner ? 1 : 0.55)
        .accessibilityLabel(PPAdoptLang("adopt_detail_contact_action"))
        .accessibilityHint(
            store.canChatOwner
                ? ""
                : (store.isLoadingOwner
                    ? PPAdoptLang("adopt_detail_contact_loading")
                    : PPAdoptLang("adopt_detail_contact_unavailable_message"))
        )
    }

    // MARK: - Actions

    private func handleClose() {
        if let vc = hostViewControllerProvider() {
            if vc.navigationController != nil && vc.navigationController?.viewControllers.first != vc {
                vc.navigationController?.popViewController(animated: true)
            } else {
                vc.dismiss(animated: true)
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
        showingReportAlert = true
    }

    private func submitReport() {
        let reason = reportReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }

        store.reportPet(reason: reason) { result in
            switch result {
            case .success:
                reportReasonText = ""
                showingReportSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .failure:
                reportFailureMessage = PPAdoptLang("adopt_detail_report_failed_message")
                showingReportFailure = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Remote Image View Helper

struct AdoptPetRemoteImageView: View {
    let urlString: String
    var allowsRetry: Bool = false
    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var didFailToLoad = false
    @State private var activeRequestID = UUID()

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHidden(true)
            } else if didFailToLoad {
                if allowsRetry {
                    Button(action: retry) {
                        VStack(spacing: PPSpace.sm) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .semibold))
                            Text(PPAdoptLang("adopt_detail_media_retry"))
                                .font(PPFont.medium(13))
                        }
                        .foregroundStyle(Color.ppTextSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.ppSecondarySurface)
                    }
                    .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.98))
                    .accessibilityLabel(PPAdoptLang("adopt_detail_media_retry"))
                } else {
                    ZStack {
                        Color.ppSecondarySurface
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.ppTextTertiary)
                    }
                    .accessibilityHidden(true)
                }
            } else {
                ZStack {
                    Color.ppSecondarySurface
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .ppTextTertiary))
                }
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: urlString) { _ in
            loadedImage = nil
            isLoading = false
            didFailToLoad = false
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard loadedImage == nil, !isLoading, !didFailToLoad else { return }
        guard let url = URL(string: urlString) else {
            didFailToLoad = true
            return
        }

        let requestedURLString = urlString
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        SDWebImageManager.shared.loadImage(
            with: url,
            options: [.continueInBackground, .lowPriority],
            progress: nil
        ) { image, _, error, _, _, _ in
            DispatchQueue.main.async {
                guard requestedURLString == urlString,
                      activeRequestID == requestID else { return }
                isLoading = false
                if let image {
                    loadedImage = image
                    didFailToLoad = false
                } else {
                    didFailToLoad = error != nil || image == nil
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

// MARK: - Press Style

private struct AdoptDetailsPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : pressedScale
            )
            .opacity(
                !isEnabled
                    ? 0.46
                    : (configuration.isPressed ? 0.88 : 1)
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.22, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}
