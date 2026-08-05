//
//  AdoptPetDetailsScreen.swift
//  Pure Pets
//
//  Production SwiftUI Adopt Pet Details Experience.
//  Redesign: Gentle Match Studio — adoption-detail card system.
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var hostViewControllerProvider: () -> UIViewController?

    @State private var currentImageIndex: Int = 0
    @State private var showingReportAlert: Bool = false
    @State private var reportReasonText: String = ""
    @State private var showingReportSuccess: Bool = false
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
            Color.ppBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: PPSpace.base) {
                    heroGallery

                    VStack(spacing: PPSpace.base) {
                        identityCard
                        factsCard
                        storyCard
                        ownerCard
                        reportButton
                    }
                    .padding(.horizontal, PPSpace.screenMargin)

                    Spacer(minLength: PPSpace.xxxl)
                }
                .padding(.top, PPSpace.screenMargin)
            }

            topOverlayNavigationBar

            if !store.isOwner {
                bottomContactDock
            }
        }
        .navigationBarHidden(true)
        .alert(PPAdoptLang("Report Ad"), isPresented: $showingReportAlert) {
            TextField(PPAdoptLang("Reason for report"), text: $reportReasonText)
            Button(PPAdoptLang("Submit"), action: submitReport)
            Button(PPAdoptLang("Cancel"), role: .cancel) { }
        } message: {
            Text(PPAdoptLang("Please specify why you want to report this adoption post."))
        }
        .alert(PPAdoptLang("Thank You"), isPresented: $showingReportSuccess) {
            Button(PPAdoptLang("OK"), role: .cancel) { }
        } message: {
            Text(PPAdoptLang("Your report has been submitted successfully."))
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

    // MARK: - Top Chrome

    private var topOverlayNavigationBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: PPSpace.sm) {
                Button(action: handleClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
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
                .accessibilityLabel(PPAdoptLang("Close"))

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

    private var heroGallery: some View {
        let imageURLs = store.pet.imageURLs
        let hasImages = !imageURLs.isEmpty

        return ZStack(alignment: .bottom) {
            Group {
                if hasImages {
                    TabView(selection: $currentImageIndex) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                            AdoptPetRemoteImageView(urlString: url)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                } else {
                    ZStack {
                        PPGradient.softBrandField
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundStyle(Color.ppQuickActionAdoption.opacity(0.48))
                    }
                }
            }
            .frame(height: 360)
            .frame(maxWidth: .infinity)
            .clipShape(
                RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                    .strokeBorder(
                        Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.7),
                        lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.8
                    )
            )
            .padding(.horizontal, PPSpace.screenMargin)

            if imageURLs.count > 1 {
                PageControl(
                    count: imageURLs.count,
                    currentIndex: currentImageIndex
                )
                .padding(.bottom, PPSpace.base)
                .accessibilityHidden(true)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(store.pet.name.isEmpty ? PPAdoptLang("AdoptPet") : store.pet.name)
                        .font(PPFont.title1())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .minimumScaleFactor(0.84)
                        .fixedSize(horizontal: false, vertical: true)

                    let kind = MainKindsModel.kindName(forID: store.pet.kindID) ?? ""
                    let breed = store.pet.subKindModel.subKindName
                    let city = store.pet.mCityName
                    let subtitleParts = [breed, kind, city].filter { !$0.isEmpty && $0 != "-" }

                    Text(subtitleParts.isEmpty ? PPAdoptLang("adopt_detail_available_now") : subtitleParts.joined(separator: "  •  "))
                        .font(PPFont.subheadline())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: PPSpace.xs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(PPAdoptLang("adopt_detail_available_now"))
                        .font(PPFont.bold(11))
                }
                .foregroundStyle(Color.ppSuccess)
                .padding(.horizontal, PPSpace.sm)
                .padding(.vertical, PPSpace.xs)
                .background(
                    Color.ppSuccess.opacity(0.12),
                    in: Capsule()
                )
                .lineLimit(1)
                .layoutPriority(1)
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppCard)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
        .shadow(
            color: colorSchemeContrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: 16,
            y: 6
        )
    }

    // MARK: - Facts Card

    private var factsCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .accessibilityHidden(true)

                Text(PPAdoptLang("adopt_detail_section_facts"))
                    .font(PPFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PPSpace.sm) {
                if !store.pet.gender.isEmpty {
                    factTile(
                        icon: "person.fill",
                        title: PPAdoptLang("Gender"),
                        value: PPAdoptLang(store.pet.gender)
                    )
                }

                if store.pet.ageMonths > 0 {
                    let ageText = String(format: PPAdoptLang("%ld Months"), store.pet.ageMonths)
                    factTile(icon: "calendar", title: PPAdoptLang("Age"), value: ageText)
                }

                if !store.pet.mCityName.isEmpty {
                    factTile(icon: "mappin.circle.fill", title: PPAdoptLang("City"), value: store.pet.mCityName)
                }

                let breed = store.pet.subKindModel.subKindName
                if !breed.isEmpty {
                    factTile(icon: "pawprint.fill", title: PPAdoptLang("Breed"), value: breed)
                }
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppCard)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
    }

    private func factTile(icon: String, title: String, value: String) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .frame(width: 34, height: 34)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(PPSpace.sm)
        .background(Color.ppSecondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Story Card

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "text.quote")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .accessibilityHidden(true)

                Text(PPAdoptLang("adopt_detail_story_title"))
                    .font(PPFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
            }

            let details = store.pet.details.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(details.isEmpty ? PPAdoptLang("adopt_detail_no_details") : details)
                .font(PPFont.body())
                .foregroundStyle(Color.ppTextPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PPSpace.base)
        .background(Color.ppCard)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
    }

    // MARK: - Owner Card

    private var ownerCard: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(PPAdoptLang("Posted By"))
                .font(PPFont.headline())
                .foregroundStyle(Color.ppTextPrimary)

            HStack(alignment: .center, spacing: PPSpace.sm) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.ownerUser?.bestDisplayName() ?? PPAdoptLang("Pet Owner"))
                        .font(PPFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)

                    Text(PPAdoptLang("PurePets Verified Advertiser"))
                        .font(PPFont.caption1())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if !store.isOwner {
                    HStack(spacing: PPSpace.sm) {
                        Button {
                            store.contactOwnerByCall(from: hostViewControllerProvider())
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.ppQuickActionAdoption)
                                .frame(width: 44, height: 44)
                                .background(
                                    Color.ppQuickActionAdoption.opacity(0.12),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(AdoptDetailsPressStyle())
                        .accessibilityLabel(PPAdoptLang("Call"))

                        Button {
                            store.contactOwnerByChat(from: hostViewControllerProvider())
                        } label: {
                            Image(systemName: "message.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Color.ppQuickActionAdoption,
                                    in: Circle()
                                )
                        }
                        .buttonStyle(AdoptDetailsPressStyle())
                        .accessibilityLabel(PPAdoptLang("Chat"))
                    }
                }
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppCard)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
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
        Button(action: {
            showingReportAlert = true
        }) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                Text(PPAdoptLang("Report Ad"))
                    .font(PPFont.medium(14))
            }
            .foregroundStyle(Color.ppTextSecondary)
            .padding(.vertical, PPSpace.sm)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AdoptDetailsPressStyle(pressedScale: 0.99))
        .accessibilityLabel(PPAdoptLang("Report Ad"))
    }

    // MARK: - Bottom Contact Dock

    private var bottomContactDock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(0.65))
                .frame(height: 0.5)
                .accessibilityHidden(true)

            HStack(spacing: PPSpace.sm) {
                Button {
                    store.contactOwnerByCall(from: hostViewControllerProvider())
                } label: {
                    HStack(spacing: PPSpace.sm) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(PPAdoptLang("Call"))
                            .font(PPFont.bold(15))
                    }
                    .foregroundStyle(Color.ppTextPrimary)
                    .padding(.horizontal, PPSpace.base)
                    .frame(height: 52)
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
                .accessibilityLabel(PPAdoptLang("Call"))

                Button {
                    store.contactOwnerByChat(from: hostViewControllerProvider())
                } label: {
                    HStack(spacing: PPSpace.sm) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text(PPAdoptLang("Contact for Adoption"))
                            .font(PPFont.bold(15))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
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
                .accessibilityLabel(PPAdoptLang("Contact for Adoption"))
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.vertical, PPSpace.md)
            .background(
                Color.ppElevatedSurface.opacity(colorScheme == .dark ? 0.9 : 0.96)
                    .background(.ultraThinMaterial)
            )
        }
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

    private func submitReport() {
        let reason = reportReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }

        store.reportPet(reason: reason) { success in
            if success {
                reportReasonText = ""
                showingReportSuccess = true
            }
        }
    }
}

// MARK: - Page Control

private struct PageControl: View {
    let count: Int
    let currentIndex: Int

    private var items: [PageControlDot] {
        (0..<count).map { PageControlDot(index: $0) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { dot in
                Capsule(style: .continuous)
                    .fill(dot.index == currentIndex ? Color.white : Color.white.opacity(0.45))
                    .frame(
                        width: dot.index == currentIndex ? 18 : 6,
                        height: 6
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.36))
        .clipShape(Capsule())
    }
}

private struct PageControlDot: Identifiable {
    let id: String
    let index: Int

    init(index: Int) {
        self.id = "page-control-dot-\(index)"
        self.index = index
    }
}

// MARK: - Remote Image View Helper

struct AdoptPetRemoteImageView: View {
    let urlString: String
    @State private var loadedImage: UIImage? = nil

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.ppSecondarySurface
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .ppTextTertiary))
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { _ in
            loadedImage = nil
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = URL(string: urlString) else { return }
        SDWebImageManager.shared.loadImage(
            with: url,
            options: [.continueInBackground, .lowPriority],
            progress: nil
        ) { image, _, _, _, _, _ in
            if let img = image {
                self.loadedImage = img
            }
        }
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
