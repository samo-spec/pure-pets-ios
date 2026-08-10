//
//  AdoptPetDetailsScreen.swift
//  Pure Pets
//
//  Production SwiftUI Adopt Pet Details Experience.
//  Redesign: Cover-to-Contact Adoption Profile — World-Class UI/UX.
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
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                detailAtmosphere
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroGallery
                            .frame(minHeight: heroHeight(geometry: geometry))

                        VStack(spacing: PPSpace.xxl) {
                            identityOverview
                            factsSection
                            storySection
                            ownerSection
                            if !store.isOwner {
                                reportButton
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.horizontal, PPSpace.screenMargin)
                        .padding(.top, -PPSpace.xl)

                        Spacer(minLength: store.isOwner ? PPSpace.xxxl : bottomDockClearance)
                    }
                }
                .background(Color.ppBackground.ignoresSafeArea())

                topOverlayNavigationBar
                    .zIndex(1)

                if !store.isOwner {
                    bottomContactDock
                        .background(Color.clear)
                }
            }
            .navigationBarHidden(true)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.34), value: hasAppeared)
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.34)) {
                        hasAppeared = true
                    }
                }
            }
            .alert(PPAdoptLang("adopt_detail_report_title"), isPresented: $showingReportAlert) {
                TextField(PPAdoptLang("adopt_detail_report_prompt"), text: $reportReasonText)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                Button(PPAdoptLang("adopt_detail_report_submit"), action: submitReport)
                    .disabled(
                        reportReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || store.isReporting
                    )
                Button(PPAdoptLang("Cancel"), role: .cancel) { }
            } message: {
                Text(PPAdoptLang("adopt_detail_report_explanation"))
                    .font(.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .padding(.vertical, PPSpace.xs)
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
        }
    }

    private var detailAtmosphere: some View {
        ZStack {
            Color.ppBackground

            if colorSchemeContrast != .increased {
                RadialGradient(
                    colors: [
                        Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.12 : 0.08),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 16,
                    endRadius: 360
                )
                .ignoresSafeArea()
            }
        }
        .accessibilityHidden(true)
        .id("atmosphere")
    }

    // MARK: - Top Chrome

    private var topOverlayNavigationBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: PPSpace.sm) {
                Button(action: handleClose) {
                    HStack(spacing: PPSpace.xs) {
                        Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text(PPAdoptLang("Back"))
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.ppSurface.opacity(0.92), in: Circle())
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
                    iconAction(
                        symbol: "square.and.arrow.up",
                        label: PPAdoptLang("Share"),
                        action: { store.sharePet(from: hostViewControllerProvider()) }
                    )

                    iconAction(
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
            .padding(.bottom, PPSpace.xs)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func iconAction(symbol: String, label: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ppSurface.opacity(0.92), in: Circle())
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

    private func heroHeight(geometry: GeometryProxy) -> CGFloat {
        let baseHeight: CGFloat = horizontalSizeClass == .regular ? 456 : 390
        let dynamicTypeAdjustment: CGFloat = dynamicTypeSize.isAccessibilitySize ? 318 : baseHeight
        let safeAreaPadding = geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        return max(dynamicTypeAdjustment - safeAreaPadding * 0.5, 280)
    }

    private var bottomDockClearance: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 184 : 112
    }

    private var imageURLs: [URL] {
        store.pet.imageURLs.compactMap { URL(string: $0) }
    }

    private var heroGallery: some View {
        let hasImages = !imageURLs.isEmpty

        return ZStack(alignment: .bottom) {
            Group {
                if hasImages {
                    TabView(selection: $currentImageIndex) {
                        ForEach(imageURLs.indices, id: \.self) { index in
                            AdoptPetRemoteImageView(url: imageURLs[index])
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
                        Color.ppSecondarySurface
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(Color.ppQuickActionAdoption.opacity(0.48))
                    }
                    .accessibilityLabel(PPAdoptLang("adopt_detail_media_unavailable"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 20)

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
                if hasImages {
                    availabilityBadge
                }

                Spacer(minLength: 0)

                if hasImages && imageURLs.count > 1 {
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
        .frame(maxWidth: .infinity)
    }

    private var availabilityBadge: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.ppSuccess)
                .accessibility(hidden: true)
            Text(PPAdoptLang("adopt_detail_available_now"))
                .font(PPFont.medium(11))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .background(Color.ppQuickActionAdoption.opacity(0.96), in: Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Identity Overview

    private var identityOverview: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(store.pet.name.isEmpty ? PPAdoptLang("AdoptPet") : store.pet.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            let kind = store.pet.mKindName
            let breed = store.pet.mBreedName
            let city = store.pet.mCityName
            let subtitleParts = [breed, kind, city].filter { !$0.isEmpty && $0 != "-" }

            Text(subtitleParts.isEmpty ? PPAdoptLang("adopt_detail_available_now") : subtitleParts.joined(separator: "  •  "))
                .font(.subheadline)
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PPSpace.xs) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.ppSuccess)
                    .accessibility(hidden: true)
                Text(PPAdoptLang("adopt_detail_available_now"))
                    .font(.caption.bold())
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(PPAdoptLang("adopt_detail_available_now")): \(PPAdoptLang("adopt_detail_available_now"))")
        }
        .padding(PPSpace.base)
        .padding(.top, PPSpace.lg)
        .background(Color.ppSurface)
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
        .padding(.horizontal, PPSpace.screenMargin)
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
                systemImage: "doc.text.magnifyingglass"
            )

            LazyVGrid(columns: factColumns, spacing: PPSpace.sm) {
                if !store.pet.gender.isEmpty {
                    factTile(
                        systemImage: "person.fill",
                        title: PPAdoptLang("Gender"),
                        value: PPAdoptGenderLabel(store.pet.gender)
                    )
                }

                if store.pet.ageMonths > 0 {
                    let ageText = String(format: PPAdoptLang("%ld Months"), store.pet.ageMonths)
                    factTile(
                        systemImage: "calendar",
                        title: PPAdoptLang("Age"),
                        value: ageText
                    )
                }

                if !store.pet.mCityName.isEmpty {
                    factTile(
                        systemImage: "mappin.circle.fill",
                        title: PPAdoptLang("City"),
                        value: store.pet.mCityName
                    )
                }

                let breed = store.pet.mBreedName
                if !breed.isEmpty && breed != "-" {
                    factTile(
                        systemImage: "pawprint.fill",
                        title: PPAdoptLang("Breed"),
                        value: breed
                    )
                }
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
    }

    private func sectionHeading(title: String, systemImage: String) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .frame(width: 32, height: 32)
                .background(Color.ppQuickActionAdoption.opacity(0.11), in: Circle())
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ppTextPrimary)
        }
    }

    private func factTile(systemImage: String, title: String, value: String) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .frame(width: 36, height: 36)
                .background(Color.ppQuickActionAdoption.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)

                Text(value)
                    .font(.body.bold())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(PPSpace.base)
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
                systemImage: "text.quote"
            )

            let details = store.pet.details.trimmingCharacters(in: .whitespacesAndNewlines)
            VStack(alignment: .leading, spacing: 0) {
                Capsule(style: .continuous)
                    .fill(Color.ppQuickActionAdoption)
                    .frame(width: 6, height: 44)
                    .accessibilityHidden(true)

                Text(details.isEmpty ? PPAdoptLang("adopt_detail_no_details") : details)
                    .font(.body)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PPSpace.base)
            .background(Color.ppSurface)
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .padding(.horizontal, PPSpace.screenMargin)
    }

    // MARK: - Listing Owner

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeading(
                title: PPAdoptLang("adopt_detail_owner_title"),
                systemImage: "person.crop.circle"
            )

            HStack(alignment: .center, spacing: PPSpace.md) {
                avatarView

                VStack(alignment: .leading, spacing: 2) {
                    if store.isLoadingOwner {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(PPAdoptLang("adopt_detail_owner_loading"))
                    }

                    Text(store.ownerUser?.bestDisplayName() ?? PPAdoptLang("adopt_detail_owner_fallback"))
                        .font(.headline)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)

                    Text(
                        store.isOwnerContactUnavailable
                            ? PPAdoptLang("adopt_detail_contact_unavailable")
                            : PPAdoptLang("adopt_detail_owner_caption")
                    )
                    .font(.caption)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                    if store.isOwnerContactUnavailable {
                        Button(PPAdoptLang("Retry")) {
                            store.retryOwnerLoading()
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.ppQuickActionAdoption)
                        .buttonStyle(PPSimpleButtonStroke())
                        .accessibilityLabel(PPAdoptLang("Retry"))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, PPSpace.base)
            .accessibilityElement(children: .contain)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .background(Color.ppSecondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let owner = store.ownerUser,
           let photoURLString = owner.userImageUrl?.absoluteString,
           !photoURLString.isEmpty {
            AdoptPetRemoteImageView(urlString: photoURLString)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        } else {
            ZStack {
                Color.ppSecondarySurface
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.ppTextTertiary)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.ppBorder.opacity(0.5), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Report Button

    private var reportButton: some View {
        Button(action: beginReport) {
            HStack(spacing: PPSpace.xs) {
                if store.isReporting {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(
                    store.isReporting
                        ? PPAdoptLang("adopt_detail_report_submitting")
                        : PPAdoptLang("adopt_detail_report_action")
                )
                .font(.body.bold())
            }
            .foregroundStyle(Color.ppTextSecondary)
            .frame(minHeight: 52.0)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PPSpace.base)
            .background(Color.ppSecondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.6), lineWidth: 0.5)
            )
        }
        .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.98))
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
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var contactActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                chatActionButton
                callActionButton
            }
        } else {
            HStack(spacing: PPSpace.md) {
                callActionButton
                Spacer()
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
                    .font(.system(size: 18, weight: .bold))
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
                .font(.body.bold())
                .lineLimit(1)
            }
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, PPSpace.base)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
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
                    .font(.system(size: 20, weight: .bold))
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
                .font(.body.bold())
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.lg)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(PPGradient.hero, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
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

// MARK: - Remote Image View

struct AdoptPetRemoteImageView: View {
    let url: URL?
    let allowsRetry: Bool

    init(url: URL, allowsRetry: Bool = false) {
        self.url = url
        self.allowsRetry = allowsRetry
    }

    init(urlString: String?, allowsRetry: Bool = false) {
        if let urlString = urlString, let parsedURL = URL(string: urlString) {
            self.url = parsedURL
        } else {
            self.url = nil
        }
        self.allowsRetry = allowsRetry
    }

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
                    retryView
                } else {
                    placeholderView
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .ppTextTertiary))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.ppSecondarySurface)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: url) { _ in
            loadedImage = nil
            isLoading = false
            didFailToLoad = false
            loadImageIfNeeded()
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        ZStack {
            Color.ppSecondarySurface
            Image(systemName: "photo")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var retryView: some View {
        Button(action: retry) {
            VStack(spacing: PPSpace.sm) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 28, weight: .semibold))
                Text(PPAdoptLang("adopt_detail_media_retry"))
                    .font(.caption.bold())
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

        let requestedURLString = validURL.absoluteString
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true

        SDWebImageManager.shared.loadImage(
            with: validURL,
            options: [.continueInBackground, .lowPriority],
            progress: nil
        ) { image, _, error, _, _, _ in
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

// MARK: - Simple Button Stroke

struct PPSimpleButtonStroke: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .foregroundStyle(Color.ppQuickActionAdoption)
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : pressedScale
            )
            .opacity(
                !isEnabled
                    ? 0.46
                    : (configuration.isPressed ? 0.8 : 1)
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.22, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}
