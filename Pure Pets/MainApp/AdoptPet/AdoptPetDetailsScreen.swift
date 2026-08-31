//
//  AdoptPetDetailsScreen.swift
//  Pure Pets
//
//  Adoption profile viewer. Presentation only: navigation, live data,
//  favorites, contact, sharing, and reporting remain owned by their
//  existing UIKit and store seams.
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

    var body: some View {
        ZStack(alignment: .top) {
            adoptionAtmosphere
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    heroGallery
                        .frame(height: heroHeight)

                    VStack(alignment: .leading, spacing: PPSpace.xl) {
                        profileIdentity
                            .padding(.top, -PPSpace.xxxl)

                        factsSection
                        storySection
                        ownerSection

                        if !store.isOwner {
                            reportButton
                        }
                    }
                    .padding(.horizontal, pageInset)
                    .padding(.bottom, PPSpace.xxxl)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !store.isOwner {
                    bottomContactDock
                }
            }

            topOverlayNavigationBar
        }
        .navigationBarHidden(true)
        .onAppear(perform: beginEntrance)
    }

    // MARK: - Layout and semantic content

    private var pageInset: CGFloat {
        horizontalSizeClass == .regular ? PPSpace.xxxl : PPSpace.screenMargin
    }

    private var heroHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 286
        }
        return horizontalSizeClass == .regular ? 500 : 416
    }

    private var galleryImages: [AdoptionGalleryImage] {
        store.pet.imageURLs
            .compactMap { URL(string: $0) }
            .enumerated()
            .map { offset, url in
                AdoptionGalleryImage(
                    id: "\(offset)-\(url.absoluteString)",
                    ordinal: offset,
                    url: url
                )
            }
    }

    private var metadataLine: String {
        [store.pet.mBreedName, store.pet.mKindName, store.pet.mCityName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "-" }
            .joined(separator: "  •  ")
    }

    private var adoptionFacts: [AdoptionDetailFact] {
        var facts: [AdoptionDetailFact] = []

        if !store.pet.gender.isEmpty {
            facts.append(
                AdoptionDetailFact(
                    id: "gender",
                    symbol: "person.fill",
                    title: PPAdoptLang("Gender"),
                    value: PPAdoptGenderLabel(store.pet.gender)
                )
            )
        }

        if store.pet.ageMonths > 0 {
            facts.append(
                AdoptionDetailFact(
                    id: "age",
                    symbol: "calendar",
                    title: PPAdoptLang("Age"),
                    value: String(format: PPAdoptLang("%ld Months"), store.pet.ageMonths)
                )
            )
        }

        if !store.pet.mCityName.isEmpty {
            facts.append(
                AdoptionDetailFact(
                    id: "city",
                    symbol: "mappin.and.ellipse",
                    title: PPAdoptLang("City"),
                    value: store.pet.mCityName
                )
            )
        }

        let breed = store.pet.mBreedName
        if !breed.isEmpty && breed != "-" {
            facts.append(
                AdoptionDetailFact(
                    id: "breed",
                    symbol: "pawprint.fill",
                    title: PPAdoptLang("Breed"),
                    value: breed
                )
            )
        }

        return facts
    }

    // MARK: - Surface

    private var adoptionAtmosphere: some View {
        ZStack {
            Color.ppBackground

            if colorSchemeContrast != .increased {
                RadialGradient(
                    colors: [
                        Color.ppPrimary.opacity(colorScheme == .dark ? 0.13 : 0.09),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 24,
                    endRadius: 420
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Top chrome

    private var topOverlayNavigationBar: some View {
        HStack(spacing: PPSpace.sm) {
            navigationAction(
                symbol: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left",
                label: PPAdoptLang("Back"),
                hint: PPAdoptLang("adopt_detail_back_hint"),
                action: handleClose
            )

            Spacer(minLength: 0)

            HStack(spacing: PPSpace.sm) {
                navigationAction(
                    symbol: "square.and.arrow.up",
                    label: PPAdoptLang("Share"),
                    hint: PPAdoptLang("adopt_detail_share_hint"),
                    action: { store.sharePet(from: hostViewControllerProvider()) }
                )

                navigationAction(
                    symbol: store.isFavorited ? "heart.fill" : "heart",
                    label: store.isFavorited
                        ? PPAdoptLang("Unfavorite")
                        : PPAdoptLang("Favorite"),
                    hint: store.isFavorited
                        ? PPAdoptLang("adopt_detail_favorite_remove_hint")
                        : PPAdoptLang("adopt_detail_favorite_add_hint"),
                    action: store.toggleFavorite,
                    isHighlighted: store.isFavorited
                )
                .accessibilityValue(
                    store.isFavorited
                        ? PPAdoptLang("adopt_detail_favorite_saved")
                        : PPAdoptLang("adopt_detail_favorite_unsaved")
                )
            }
        }
        .padding(.horizontal, pageInset)
        .padding(.top, PPSpace.sm)
        .accessibilityElement(children: .contain)
    }

    private func navigationAction(
        symbol: String,
        label: String,
        hint: String,
        action: @escaping () -> Void,
        isHighlighted: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isHighlighted ? Color.ppPrimary : Color.ppTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ppSurface.opacity(reduceTransparency ? 1 : 0.94), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.74),
                            lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.8
                        )
                }
                .shadow(
                    color: colorSchemeContrast == .increased ? .clear : Color.black.opacity(0.10),
                    radius: 8,
                    y: 3
                )
        }
        .buttonStyle(AdoptDetailsPressStyle())
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    // MARK: - Gallery

    private var heroGallery: some View {
        let hasImages = !galleryImages.isEmpty

        return ZStack(alignment: .bottom) {
            Group {
                if hasImages {
                    TabView(selection: $currentImageIndex) {
                        ForEach(galleryImages) { image in
                            AdoptPetRemoteImageView(url: image.url, allowsRetry: true)
                                .tag(image.ordinal)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    noMediaHero
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(colorScheme == .dark ? 0.64 : 0.46)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: PPSpace.sm) {
                availabilityBadge

                Spacer(minLength: PPSpace.md)

                if hasImages && galleryImages.count > 1 {
                    galleryIndicator
                }
            }
            .padding(.horizontal, pageInset)
            .padding(.bottom, PPSpace.xxxl + PPSpace.xs)
        }
        .opacity(hasAppeared || reduceMotion ? 1 : 0.01)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.32),
            value: hasAppeared
        )
        .accessibilityElement(children: hasImages ? .contain : .ignore)
        .accessibilityLabel(
            hasImages
                ? PPAdoptLang("adopt_detail_gallery_label")
                : PPAdoptLang("adopt_detail_media_unavailable")
        )
        .accessibilityValue(
            hasImages
                ? String(
                    format: PPAdoptLang("adopt_detail_gallery_value_format"),
                    currentImageIndex + 1,
                    galleryImages.count
                )
                : ""
        )
        .accessibilityHint(
            hasImages && galleryImages.count > 1
                ? PPAdoptLang("adopt_detail_gallery_adjust_hint")
                : ""
        )
        .accessibilityAdjustableAction { direction in
            guard galleryImages.count > 1 else { return }
            switch direction {
            case .increment:
                currentImageIndex = min(currentImageIndex + 1, galleryImages.count - 1)
            case .decrement:
                currentImageIndex = max(currentImageIndex - 1, 0)
            @unknown default:
                break
            }
        }
    }

    private var noMediaHero: some View {
        ZStack {
            Color.ppSecondarySurface
            Circle()
                .fill(Color.ppPrimary.opacity(colorScheme == .dark ? 0.20 : 0.14))
                .frame(width: 132, height: 132)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
        }
        .accessibilityHidden(true)
    }

    private var availabilityBadge: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
            Text(PPAdoptLang("adopt_detail_available_now"))
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .background(Color.ppPrimary, in: Capsule())
        .accessibilityHidden(true)
    }

    private var galleryIndicator: some View {
        VStack(alignment: .trailing, spacing: PPSpace.xs) {
            Text(
                String(
                    format: PPAdoptLang("adopt_detail_gallery_value_format"),
                    currentImageIndex + 1,
                    galleryImages.count
                )
            )
            .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))

            HStack(spacing: 4) {
                ForEach(galleryImages) { image in
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(image.ordinal == currentImageIndex ? 1 : 0.42))
                        .frame(width: image.ordinal == currentImageIndex ? 18 : 5, height: 5)
                }
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.xs)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: - Adoption profile

    private var profileIdentity: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            identityStatusRow

            Text(store.pet.name.isEmpty ? PPAdoptLang("AdoptPet") : store.pet.name)
                .font(.custom("Beiruti-Bold", size: 30, relativeTo: .title))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !metadataLine.isEmpty {
                Text(metadataLine)
                    .font(.custom("Beiruti-Regular", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, PPSpace.lg)
        .padding(.vertical, PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.78),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(
            color: colorSchemeContrast == .increased ? .clear : Color.black.opacity(colorScheme == .dark ? 0.18 : 0.09),
            radius: 22,
            y: 10
        )
        .opacity(hasAppeared || reduceMotion ? 1 : 0.01)
        .offset(y: hasAppeared || reduceMotion ? 0 : 8)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.30).delay(0.04),
            value: hasAppeared
        )
    }

    @ViewBuilder
    private var identityStatusRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                adoptionEyebrow
                availabilityLine
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
                adoptionEyebrow
                Spacer(minLength: PPSpace.sm)
                availabilityLine
            }
        }
    }

    private var adoptionEyebrow: some View {
        Text(PPAdoptLang("adopt_detail_eyebrow"))
            .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
            .foregroundStyle(Color.ppAccentText)
    }

    private var availabilityLine: some View {
        HStack(spacing: PPSpace.xs) {
            Circle()
                .fill(Color.ppSuccess)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(PPAdoptLang("adopt_detail_available_now"))
                .font(.custom("Beiruti-Medium", size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPAdoptLang("adopt_detail_available_now"))
        .accessibilityHint(PPAdoptLang("adopt_detail_availability_hint"))
    }

    // MARK: - Facts

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_section_facts"),
                subtitle: PPAdoptLang("adopt_detail_facts_caption"),
                systemImage: "sparkle.magnifyingglass"
            )

            if adoptionFacts.isEmpty {
                Text(PPAdoptLang("adopt_detail_facts_unavailable"))
                    .font(.custom("Beiruti-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .padding(PPSpace.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adoptionSectionSurface()
            } else if dynamicTypeSize.isAccessibilitySize {
                factList
                    .adoptionSectionSurface()
            } else {
                factGrid(columns: horizontalSizeClass == .regular ? 4 : 2)
                    .adoptionSectionSurface()
            }
        }
    }

    private func factGrid(columns: Int) -> some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 0), count: columns)
        return LazyVGrid(columns: grid, alignment: .leading, spacing: PPSpace.md) {
            ForEach(adoptionFacts) { fact in
                factMeasure(fact)
            }
        }
        .padding(PPSpace.lg)
    }

    private var factList: some View {
        VStack(spacing: 0) {
            ForEach(Array(adoptionFacts.enumerated()), id: \.element.id) { index, fact in
                factRow(fact)
                if index < adoptionFacts.count - 1 {
                    Divider()
                        .overlay(Color.ppSeparator)
                }
            }
        }
        .padding(.horizontal, PPSpace.lg)
    }

    private func factMeasure(_ fact: AdoptionDetailFact) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Image(systemName: fact.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 32, height: 32)
                .background(Color.ppPrimary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(fact.title)
                .font(.custom("Beiruti-Regular", size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.ppTextSecondary)

            Text(fact.value)
                .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(factAccessibilityLabel(fact))
    }

    private func factRow(_ fact: AdoptionDetailFact) -> some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: fact.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 36, height: 36)
                .background(Color.ppPrimary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(fact.title)
                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)

            Spacer(minLength: PPSpace.sm)

            Text(fact.value)
                .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        }
        .padding(.vertical, PPSpace.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(factAccessibilityLabel(fact))
    }

    // MARK: - Story

    private var storySection: some View {
        let details = store.pet.details.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_story_title"),
                subtitle: PPAdoptLang("adopt_detail_story_caption"),
                systemImage: "quote.opening"
            )

            HStack(alignment: .top, spacing: PPSpace.md) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.ppPrimary)
                    .frame(width: 4)
                    .accessibilityHidden(true)

                Text(details.isEmpty ? PPAdoptLang("adopt_detail_no_details") : details)
                    .font(.custom("Beiruti-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PPSpace.lg)
            .adoptionSectionSurface()
        }
    }

    // MARK: - Listing owner

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_owner_title"),
                subtitle: PPAdoptLang("adopt_detail_owner_caption"),
                systemImage: "person.crop.circle"
            )

            HStack(alignment: .center, spacing: PPSpace.md) {
                ownerAvatar

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    if store.isLoadingOwner {
                        HStack(spacing: PPSpace.xs) {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityHidden(true)
                            Text(PPAdoptLang("adopt_detail_owner_loading"))
                                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Text(store.ownerUser?.bestDisplayName() ?? PPAdoptLang("adopt_detail_owner_fallback"))
                        .font(.custom("Beiruti-Bold", size: 18, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                    if store.isOwnerContactUnavailable {
                        Text(PPAdoptLang("adopt_detail_contact_unavailable"))
                            .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Color.ppTextSecondary)

                        Button(PPAdoptLang("Retry")) {
                            store.retryOwnerLoading()
                        }
                        .buttonStyle(AdoptionQuietButtonStyle())
                        .accessibilityHint(PPAdoptLang("adopt_detail_owner_retry_hint"))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(PPSpace.lg)
            .adoptionSectionSurface()
        }
    }

    @ViewBuilder
    private var ownerAvatar: some View {
        if let owner = store.ownerUser,
           let photoURLString = owner.userImageUrl?.absoluteString,
           !photoURLString.isEmpty {
            AdoptPetRemoteImageView(urlString: photoURLString)
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.ppBorder.opacity(0.74), lineWidth: 0.8)
                }
                .accessibilityHidden(true)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
                .frame(width: 58, height: 58)
                .background(Color.ppSecondarySurface, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.ppBorder.opacity(0.62), lineWidth: 0.8)
                }
                .accessibilityHidden(true)
        }
    }

    // MARK: - Report

    private var reportButton: some View {
        Button(action: beginReport) {
            HStack(spacing: PPSpace.sm) {
                if store.isReporting {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityHidden(true)
                }

                Text(
                    store.isReporting
                        ? PPAdoptLang("adopt_detail_report_submitting")
                        : PPAdoptLang("adopt_detail_report_action")
                )
                .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))

                Spacer(minLength: 0)

                Image(systemName: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ppTextSecondary)
            .frame(minHeight: 48)
            .padding(.horizontal, PPSpace.md)
        }
        .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.98))
        .disabled(store.isReporting)
        .accessibilityLabel(PPAdoptLang("adopt_detail_report_action"))
        .accessibilityHint(PPAdoptLang("adopt_detail_report_hint"))
    }

    // MARK: - Contact dock

    private var bottomContactDock: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.ppSeparator.opacity(0.8))

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                if let contactStateMessage {
                    contactStatus(message: contactStateMessage)
                }

                contactActions
            }
            .padding(.horizontal, pageInset)
            .padding(.top, PPSpace.sm)
            .padding(.bottom, PPSpace.sm)
            .background(dockSurface)
        }
        .frame(maxWidth: .infinity)
    }

    private var dockSurface: Color {
        Color.ppElevatedSurface
    }

    private var contactStateMessage: String? {
        if store.isLoadingOwner {
            return PPAdoptLang("adopt_detail_contact_loading")
        }
        if !store.canCallOwner && !store.canChatOwner {
            return PPAdoptLang("adopt_detail_contact_unavailable_message")
        }
        return nil
    }

    private func contactStatus(message: String) -> some View {
        HStack(spacing: PPSpace.xs) {
            if store.isLoadingOwner {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(message)
                .font(.custom("Beiruti-Regular", size: 13, relativeTo: .footnote))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
            Label(PPAdoptLang("Call"), systemImage: "phone.fill")
                .font(.custom("Beiruti-Bold", size: 16, relativeTo: .body))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: PPBottomDecisionBarGeometry.controlHeight)
                .padding(.horizontal, PPSpace.md)
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                        .strokeBorder(
                            Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.82),
                            lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.8
                        )
                }
        }
        .buttonStyle(AdoptDetailsPressStyle())
        .disabled(!store.canCallOwner)
        .accessibilityLabel(PPAdoptLang("Call"))
        .accessibilityHint(
            store.canCallOwner
                ? PPAdoptLang("adopt_detail_call_hint")
                : PPAdoptLang("adopt_detail_contact_unavailable_message")
        )
    }

    private var chatActionButton: some View {
        Button {
            store.contactOwnerByChat(from: hostViewControllerProvider())
        } label: {
            Label(PPAdoptLang("adopt_detail_contact_action"), systemImage: "message.fill")
                .font(.custom("Beiruti-Bold", size: 16, relativeTo: .body))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: PPBottomDecisionBarGeometry.controlHeight)
                .padding(.horizontal, PPSpace.md)
                .background(PPGradient.hero, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                .shadow(
                    color: colorSchemeContrast == .increased ? .clear : Color.ppPrimary.opacity(0.25),
                    radius: 10,
                    y: 4
                )
        }
        .buttonStyle(AdoptDetailsPressStyle())
        .disabled(!store.canChatOwner)
        .accessibilityLabel(PPAdoptLang("adopt_detail_contact_action"))
        .accessibilityHint(
            store.canChatOwner
                ? PPAdoptLang("adopt_detail_chat_hint")
                : PPAdoptLang("adopt_detail_contact_unavailable_message")
        )
    }

    // MARK: - Shared pieces

    private func sectionHeading(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.ppPrimary.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                Text(title)
                    .font(.custom("Beiruti-Bold", size: 21, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(subtitle)
                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func factAccessibilityLabel(_ fact: AdoptionDetailFact) -> String {
        String(
            format: PPAdoptLang("adopt_detail_fact_accessibility_format"),
            fact.title,
            fact.value
        )
    }

    private func beginEntrance() {
        guard !hasAppeared else { return }
        guard !reduceMotion else {
            hasAppeared = true
            return
        }
        withAnimation(.easeOut(duration: 0.32)) {
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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

private struct AdoptionSectionSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        content
            .background(Color.ppSurface, in: shape)
            .overlay {
                shape.strokeBorder(
                    Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.76),
                    lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.8
                )
            }
            .shadow(
                color: colorSchemeContrast == .increased ? .clear : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.045),
                radius: 14,
                y: 5
            )
    }
}

private extension View {
    func adoptionSectionSurface() -> some View {
        modifier(AdoptionSectionSurface())
    }
}

// MARK: - Remote image view

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
                allowsRetry ? AnyView(retryView) : AnyView(placeholderView)
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
                    .font(.custom("Beiruti-Bold", size: 13, relativeTo: .footnote))
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

// MARK: - Interaction styles

private struct AdoptDetailsPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed || !isEnabled ? 1 : pressedScale)
            .opacity(!isEnabled ? 0.46 : (configuration.isPressed ? 0.88 : 1))
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}

private struct AdoptionQuietButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
            .foregroundStyle(Color.ppAccentText)
            .padding(.top, PPSpace.xs)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
