//
//  PPUniversalCellSwiftUI.swift
//  Pure Pets
//
//  SwiftUI-first universal marketplace card with a UIKit collection-view bridge.
//  Deployment target: iOS 16.0+
//

import SwiftUI
import AVKit
import UIKit

// MARK: - Public API

public enum PPUniversalCardContext: Equatable {
    case ads, homeAds, market, food, accessory, services, vets, adopt

    var isAdvertisement: Bool { self == .ads || self == .homeAds }
    var isServiceLike: Bool { self == .services || self == .vets }
}

public enum PPUniversalCardLayout: Equatable {
    case pinterest, market, fullWidth, horizontalRow
    var isHorizontal: Bool { self == .fullWidth || self == .horizontalRow }
}

public enum PPUniversalCardDiscountStyle: Equatable { case badge, inline }

public struct PPUniversalCardPalette {
    public var primary: Color
    public var primaryDark: Color
    public var accent: Color
    public var lightSurface: Color
    public var darkSurface: Color
    public var lightInk: Color
    public var darkInk: Color
    public var lightSecondaryInk: Color
    public var darkSecondaryInk: Color
    public var success: Color
    public var warning: Color
    public var destructive: Color

    public init(
        primary: Color,
        primaryDark: Color,
        accent: Color,
        lightSurface: Color,
        darkSurface: Color,
        lightInk: Color,
        darkInk: Color,
        lightSecondaryInk: Color,
        darkSecondaryInk: Color,
        success: Color,
        warning: Color,
        destructive: Color
    ) {
        self.primary = primary
        self.primaryDark = primaryDark
        self.accent = accent
        self.lightSurface = lightSurface
        self.darkSurface = darkSurface
        self.lightInk = lightInk
        self.darkInk = darkInk
        self.lightSecondaryInk = lightSecondaryInk
        self.darkSecondaryInk = darkSecondaryInk
        self.success = success
        self.warning = warning
        self.destructive = destructive
    }

    public static let purePets = PPUniversalCardPalette(
        primary: Color(hex: 0x8A1538),
        primaryDark: Color(hex: 0x5F0D27),
        accent: Color(hex: 0x8DD9BF),
        lightSurface: .white,
        darkSurface: Color(hex: 0x17201C),
        lightInk: Color(hex: 0x131614),
        darkInk: Color(hex: 0xF4F7F5),
        lightSecondaryInk: Color(hex: 0x68736D),
        darkSecondaryInk: Color(hex: 0xC4CEC8),
        success: Color(hex: 0x2F8F67),
        warning: Color(hex: 0xD18432),
        destructive: Color(hex: 0xC84D51)
    )
}

public struct PPUniversalAvailability: Equatable {
    public enum Tone: Equatable { case neutral, available, limited, unavailable, used }

    public var text: String
    public var tone: Tone
    public var metaText: String?
    public var metaSystemImage: String?

    public init(
        text: String,
        tone: Tone = .neutral,
        metaText: String? = nil,
        metaSystemImage: String? = nil
    ) {
        self.text = text
        self.tone = tone
        self.metaText = metaText
        self.metaSystemImage = metaSystemImage
    }
}

public struct PPUniversalCardModel: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var imageURL: URL?
    public var videoURL: URL?
    public var placeholderSystemImage: String
    public var price: Decimal?
    public var originalPrice: Decimal?
    public var priceText: String?
    public var currencyCode: String
    public var badgeText: String?
    public var reasonText: String?
    public var discountText: String?
    public var availability: PPUniversalAvailability?
    public var isFavorite: Bool
    public var isOwner: Bool
    public var isPubliclyVisible: Bool
    public var isSkeleton: Bool
    public var quantity: Int
    public var stock: Int?
    public var usesQuantityControl: Bool
    public var prefersContainedImage: Bool
    public var preferredAspectRatio: CGFloat

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        imageURL: URL? = nil,
        videoURL: URL? = nil,
        placeholderSystemImage: String = "pawprint.fill",
        price: Decimal? = nil,
        originalPrice: Decimal? = nil,
        priceText: String? = nil,
        currencyCode: String = "QAR",
        badgeText: String? = nil,
        reasonText: String? = nil,
        discountText: String? = nil,
        availability: PPUniversalAvailability? = nil,
        isFavorite: Bool = false,
        isOwner: Bool = false,
        isPubliclyVisible: Bool = true,
        isSkeleton: Bool = false,
        quantity: Int = 0,
        stock: Int? = nil,
        usesQuantityControl: Bool = false,
        prefersContainedImage: Bool = false,
        preferredAspectRatio: CGFloat = 0.82
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.placeholderSystemImage = placeholderSystemImage
        self.price = price
        self.originalPrice = originalPrice
        self.priceText = priceText
        self.currencyCode = currencyCode
        self.badgeText = badgeText
        self.reasonText = reasonText
        self.discountText = discountText
        self.availability = availability
        self.isFavorite = isFavorite
        self.isOwner = isOwner
        self.isPubliclyVisible = isPubliclyVisible
        self.isSkeleton = isSkeleton
        self.quantity = max(0, quantity)
        self.stock = stock.map { max(0, $0) }
        self.usesQuantityControl = usesQuantityControl
        self.prefersContainedImage = prefersContainedImage
        self.preferredAspectRatio = min(max(preferredAspectRatio, 0.68), 2.0)
    }
}

public struct PPUniversalCardActions {
    public var onTap: ((PPUniversalCardModel) -> Void)?
    public var onShare: ((PPUniversalCardModel) -> Void)?
    public var onFavorite: ((PPUniversalCardModel, Bool) -> Void)?
    public var onEdit: ((PPUniversalCardModel) -> Void)?
    public var onVisibilityToggle: ((PPUniversalCardModel) -> Void)?
    public var onDelete: ((PPUniversalCardModel) -> Void)?
    public var onQuantityChange: ((PPUniversalCardModel, Int) -> Void)?
    public var onNotifyWhenAvailable: ((PPUniversalCardModel) async -> Bool)?

    public init(
        onTap: ((PPUniversalCardModel) -> Void)? = nil,
        onShare: ((PPUniversalCardModel) -> Void)? = nil,
        onFavorite: ((PPUniversalCardModel, Bool) -> Void)? = nil,
        onEdit: ((PPUniversalCardModel) -> Void)? = nil,
        onVisibilityToggle: ((PPUniversalCardModel) -> Void)? = nil,
        onDelete: ((PPUniversalCardModel) -> Void)? = nil,
        onQuantityChange: ((PPUniversalCardModel, Int) -> Void)? = nil,
        onNotifyWhenAvailable: ((PPUniversalCardModel) async -> Bool)? = nil
    ) {
        self.onTap = onTap
        self.onShare = onShare
        self.onFavorite = onFavorite
        self.onEdit = onEdit
        self.onVisibilityToggle = onVisibilityToggle
        self.onDelete = onDelete
        self.onQuantityChange = onQuantityChange
        self.onNotifyWhenAvailable = onNotifyWhenAvailable
    }
}

// MARK: - Main View

@available(iOS 16.0, *)
public struct PPUniversalCardView: View {
    public let model: PPUniversalCardModel
    public let context: PPUniversalCardContext
    public let layout: PPUniversalCardLayout
    public let discountStyle: PPUniversalCardDiscountStyle
    public let palette: PPUniversalCardPalette
    public let actions: PPUniversalCardActions

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ScaledMetric(relativeTo: .body) private var cardRadius: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var imageRadius: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var outerInset: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var actionHeight: CGFloat = 38

    @State private var quantity: Int
    @State private var isFavorite: Bool
    @State private var isEditingQuantity = false
    @State private var isPressed = false
    @State private var isPlayingVideo = false
    @State private var notifyInFlight = false
    @State private var notifySucceeded = false
    @State private var collapseTask: Task<Void, Never>?

    public init(
        model: PPUniversalCardModel,
        context: PPUniversalCardContext,
        layout: PPUniversalCardLayout,
        discountStyle: PPUniversalCardDiscountStyle = .badge,
        palette: PPUniversalCardPalette = .purePets,
        actions: PPUniversalCardActions = .init()
    ) {
        self.model = model
        self.context = context
        self.layout = layout
        self.discountStyle = discountStyle
        self.palette = palette
        self.actions = actions
        _quantity = State(initialValue: max(0, model.quantity))
        _isFavorite = State(initialValue: model.isFavorite)
    }

    public var body: some View {
        Group {
            if model.isSkeleton {
                PPUniversalSkeletonCard(layout: layout, cardRadius: resolvedCardRadius, imageRadius: imageRadius)
            } else {
                cardContent
            }
        }
        .onChange(of: model.id) { _ in resetTransientState() }
        .onDisappear {
            collapseTask?.cancel()
            collapseTask = nil
            isPlayingVideo = false
        }
    }

    private var cardContent: some View {
        Group {
            if layout.isHorizontal {
                HStack(alignment: .center, spacing: 14) {
                    media
                        .frame(width: layout == .fullWidth ? 148 : 136)
                        .aspectRatio(1, contentMode: .fit)
                    information.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    media.aspectRatio(resolvedImageAspectRatio, contentMode: .fit)
                    information
                }
            }
        }
        .padding(outerInset)
        .background(cardBackground)
        .clipShape(cardShape)
        .overlay(cardBorder)
        .overlay(innerHighlight)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.26 : 0.11), radius: colorScheme == .dark ? 22 : 28, y: colorScheme == .dark ? 12 : 16)
        .scaleEffect(isPressed && !reduceMotion ? 0.975 : 1)
        .offset(y: isPressed && !reduceMotion ? 1.5 : 0)
        .opacity(isPressed ? 0.97 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.30, dampingFraction: 0.84), value: isPressed)
        .contentShape(cardShape)
        .onTapGesture {
            guard actions.onTap != nil else { return }
            haptic(.light)
            actions.onTap?(currentModel)
        }
        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 24, pressing: { isPressed = $0 }, perform: {})
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.title)
    }

    private var media: some View {
        ZStack {
            PPUniversalRemoteImage(
                url: model.imageURL,
                placeholderSystemImage: model.placeholderSystemImage,
                contentMode: model.prefersContainedImage ? .fit : .fill
            )
            .padding(model.prefersContainedImage ? 10 : 0)

            if isPlayingVideo, let videoURL = model.videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }

            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.04 : 0.10),
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.12 : 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            mediaBadges

            if let videoURL = model.videoURL, !isPlayingVideo {
                Button {
                    guard !videoURL.absoluteString.isEmpty else { return }
                    haptic(.medium)
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { isPlayingVideo = true }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.black.opacity(0.30), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                        .shadow(color: .black.opacity(0.20), radius: 12, y: 7)
                }
                .buttonStyle(PPScaleButtonStyle())
                .accessibilityLabel("Play video")
            }
        }
        .background(imageSurface)
        .clipShape(RoundedRectangle(cornerRadius: imageRadius, style: .continuous))
        .overlay(imageBorder)
        .clipped()
    }

    private var mediaBadges: some View {
        ZStack {
            VStack {
                HStack(alignment: .top, spacing: 7) {
                    if !model.isOwner { favoriteButton }
                    if actions.onShare != nil { shareButton }
                    Spacer(minLength: 8)
                    if model.isOwner { ownerMenu }
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 7) {
                    if let reason = model.reasonText, !reason.isEmpty {
                        PPBadge(text: reason, foreground: .white, background: .black.opacity(0.62), border: palette.warning.opacity(0.35))
                    }
                    Spacer()
                    if discountStyle == .badge, let discount = model.discountText, !discount.isEmpty {
                        PPBadge(text: discount, foreground: .white, background: palette.destructive.opacity(0.96), border: .clear)
                    }
                }
            }
            .padding(9)

            if let badge = model.badgeText, !badge.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        PPBadge(text: badge, foreground: ink, background: surface.opacity(0.92), border: .white.opacity(colorScheme == .dark ? 0.10 : 0.45))
                        Spacer()
                    }
                }
                .padding(9)
            }
        }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.title)
                .font(.system(size: layout.isHorizontal ? 16 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(layout.isHorizontal || layout == .pinterest ? 2 : 1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            if let subtitle = model.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: layout.isHorizontal ? 12.5 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(layout.isHorizontal ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasPrice { priceRow.padding(.top, model.subtitle?.isEmpty == false ? 7 : 8) }
            primaryAction.padding(.top, hasPrice ? 7 : 10)
            availabilityRow.padding(.top, shouldShowAvailability ? 9 : 0)
        }
    }

    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            premiumPrice
            Spacer(minLength: 4)
            if let original = model.originalPrice, let current = model.price, original > current {
                Text(formattedPrice(original))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryInk.opacity(0.80))
                    .strikethrough(true, color: secondaryInk.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var premiumPrice: some View {
        if let explicit = model.priceText, !explicit.isEmpty, model.price == nil {
            Text(explicit)
                .font(.system(size: layout.isHorizontal ? 21 : 24, weight: .black, design: .rounded))
                .foregroundStyle(palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        } else if let price = model.price {
            let pieces = pricePieces(price)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if layoutDirection == .leftToRight {
                    Text(displayCurrency).font(.system(size: 10, weight: .bold, design: .rounded)).baselineOffset(8)
                }
                Text(pieces.integer).font(.system(size: layout.isHorizontal ? 21 : 25, weight: .black, design: .rounded))
                Text(pieces.fraction).font(.system(size: 11, weight: .bold, design: .rounded)).baselineOffset(9)
                if layoutDirection == .rightToLeft {
                    Text(displayCurrency).font(.system(size: 10, weight: .bold, design: .rounded)).baselineOffset(8)
                }
            }
            .foregroundStyle(palette.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(formattedPrice(price))
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if model.usesQuantityControl, isEditingQuantity, quantity > 0 {
            quantityStepper.transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Button(action: handlePrimaryAction) {
                HStack(spacing: 7) {
                    if notifyInFlight {
                        ProgressView().tint(primaryActionForeground).controlSize(.small)
                    } else if let icon = primaryActionIcon {
                        Image(systemName: icon).font(.system(size: 13, weight: .bold))
                    }
                    Text(primaryActionTitle)
                        .font(.system(size: layout.isHorizontal ? 12.5 : 13.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .foregroundStyle(primaryActionForeground)
                .frame(maxWidth: .infinity)
                .frame(height: actionHeight)
                .background(primaryActionBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(primaryActionBorder, lineWidth: 1))
                .shadow(color: primaryActionShadow, radius: 10, y: 5)
            }
            .buttonStyle(PPScaleButtonStyle())
            .disabled(notifyInFlight)
            .accessibilityLabel(primaryActionTitle)
        }
    }

    private var quantityStepper: some View {
        HStack(spacing: 10) {
            stepperButton(systemName: "minus", enabled: quantity > 0) { setQuantity(max(0, quantity - 1)) }
            Spacer(minLength: 0)
            Text("\(quantity)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(palette.primary)
                .monospacedDigit()
            Spacer(minLength: 0)
            stepperButton(systemName: "plus", enabled: canIncreaseQuantity) { setQuantity(quantity + 1) }
        }
        .padding(.horizontal, 3)
        .frame(height: actionHeight)
        .background(palette.primary.opacity(colorScheme == .dark ? 0.15 : 0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(palette.primary.opacity(0.20), lineWidth: 1))
    }

    private func stepperButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            haptic(.light)
            action()
            restartStepperCollapseTimer()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(palette.primary)
                .frame(width: 31, height: 31)
                .background(surface.opacity(colorScheme == .dark ? 0.90 : 0.96), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 0.7))
        }
        .buttonStyle(PPScaleButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.40)
    }

    @ViewBuilder
    private var availabilityRow: some View {
        if let availability = model.availability, !availability.text.isEmpty {
            HStack(spacing: 8) {
                if let meta = availability.metaText, !meta.isEmpty {
                    PPMetadataPill(
                        text: meta,
                        systemImage: availability.metaSystemImage,
                        foreground: availabilityForeground(availability.tone),
                        background: availabilityBackground(availability.tone),
                        border: availabilityForeground(availability.tone).opacity(0.18)
                    )
                }
                PPBadge(
                    text: availability.text,
                    foreground: availabilityForeground(availability.tone),
                    background: availabilityBackground(availability.tone),
                    border: availabilityForeground(availability.tone).opacity(0.17)
                )
                Spacer(minLength: 0)
            }
        }
    }

    private var favoriteButton: some View {
        Button {
            isFavorite.toggle()
            haptic(.light)
            actions.onFavorite?(currentModel, isFavorite)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isFavorite ? palette.destructive : palette.primary)
                .frame(width: 34, height: 34)
                .background(floatingControlBackground, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.12), radius: 9, y: 4)
        }
        .buttonStyle(PPScaleButtonStyle())
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }

    private var shareButton: some View {
        Button {
            haptic(.light)
            actions.onShare?(currentModel)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: 34, height: 34)
                .background(floatingControlBackground, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.10), radius: 9, y: 4)
        }
        .buttonStyle(PPScaleButtonStyle())
        .accessibilityLabel("Share")
    }

    private var ownerMenu: some View {
        Menu {
            Button { actions.onEdit?(currentModel) } label: { Label("Edit", systemImage: "square.and.pencil") }
            Button { actions.onVisibilityToggle?(currentModel) } label: {
                Label(model.isPubliclyVisible ? "Hide" : "Show", systemImage: model.isPubliclyVisible ? "eye.slash" : "eye")
            }
            Button(role: .destructive) { actions.onDelete?(currentModel) } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 34, height: 34)
                .background(floatingControlBackground, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.10), radius: 9, y: 4)
        }
        .accessibilityLabel("Item options")
    }

    // MARK: Actions

    private func handlePrimaryAction() {
        haptic(.medium)

        guard model.usesQuantityControl else {
            actions.onTap?(currentModel)
            return
        }

        if isOutOfStock {
            guard !notifyInFlight, let notify = actions.onNotifyWhenAvailable else { return }
            notifyInFlight = true
            Task { @MainActor in
                let succeeded = await notify(currentModel)
                notifyInFlight = false
                notifySucceeded = succeeded
                haptic(succeeded ? .success : .warning)
            }
            return
        }

        if quantity > 0 {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) { isEditingQuantity = true }
            restartStepperCollapseTimer()
            return
        }

        setQuantity(1)
        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) { isEditingQuantity = true }
        restartStepperCollapseTimer()
    }

    private func setQuantity(_ proposed: Int) {
        let upperBound = model.stock ?? Int.max
        let clamped = min(max(0, proposed), upperBound)
        quantity = clamped
        if clamped == 0 {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) { isEditingQuantity = false }
        }
        actions.onQuantityChange?(currentModel, clamped)
    }

    private func restartStepperCollapseTimer() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) { isEditingQuantity = false }
        }
    }

    private func resetTransientState() {
        quantity = max(0, model.quantity)
        isFavorite = model.isFavorite
        isEditingQuantity = false
        isPlayingVideo = false
        notifyInFlight = false
        notifySucceeded = false
    }

    // MARK: Visual tokens

    private var currentModel: PPUniversalCardModel {
        var copy = model
        copy.quantity = quantity
        copy.isFavorite = isFavorite
        return copy
    }

    private var resolvedCardRadius: CGFloat { layout == .horizontalRow ? 30 : cardRadius }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: resolvedCardRadius, style: .continuous) }

    private var cardBackground: some View {
        ZStack {
            (reduceTransparency ? surface : surface.opacity(colorScheme == .dark ? 0.86 : 0.82))
            RadialGradient(colors: [palette.primary.opacity(colorScheme == .dark ? 0.12 : 0.065), .clear], center: .bottomLeading, startRadius: 0, endRadius: 260)
            RadialGradient(colors: [palette.accent.opacity(colorScheme == .dark ? 0.10 : 0.05), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 220)
            LinearGradient(
                colors: [.white.opacity(colorScheme == .dark ? 0.045 : 0.34), .white.opacity(0), palette.primary.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBorder: some View {
        cardShape.stroke(
            AngularGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.30 : 0.90),
                    .white.opacity(colorScheme == .dark ? 0.08 : 0.26),
                    palette.primary.opacity(colorScheme == .dark ? 0.10 : 0.06),
                    .white.opacity(colorScheme == .dark ? 0.15 : 0.48),
                    .white.opacity(colorScheme == .dark ? 0.07 : 0.22)
                ],
                center: .center
            ),
            lineWidth: 1.05
        )
    }

    private var innerHighlight: some View {
        cardShape
            .inset(by: 1.2)
            .stroke(
                LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.05 : 0.32), .clear], startPoint: .top, endPoint: .bottom),
                lineWidth: 0.7
            )
            .allowsHitTesting(false)
    }

    private var imageBorder: some View {
        RoundedRectangle(cornerRadius: imageRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(colorScheme == .dark ? 0.34 : 0.94),
                        .white.opacity(colorScheme == .dark ? 0.08 : 0.28),
                        palette.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                        .white.opacity(colorScheme == .dark ? 0.16 : 0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
    }

    private var imageSurface: Color {
        colorScheme == .dark ? .white.opacity(model.prefersContainedImage ? 0.055 : 0.035) : Color(hex: 0xF7F7F5).opacity(model.prefersContainedImage ? 0.92 : 0.45)
    }
    private var surface: Color { colorScheme == .dark ? palette.darkSurface : palette.lightSurface }
    private var ink: Color { colorScheme == .dark ? palette.darkInk : palette.lightInk }
    private var secondaryInk: Color { colorScheme == .dark ? palette.darkSecondaryInk : palette.lightSecondaryInk }
    private var floatingControlBackground: Color { colorScheme == .dark ? Color(hex: 0x242A27).opacity(0.95) : .white.opacity(0.91) }

    private var resolvedImageAspectRatio: CGFloat {
        if layout == .pinterest { return min(max(model.preferredAspectRatio, 1), 2) }
        if context == .adopt { return 1.12 }
        if context.isAdvertisement { return 0.98 }
        if context.isServiceLike { return 0.74 }
        if model.usesQuantityControl { return 0.78 }
        return model.preferredAspectRatio
    }

    private var hasPrice: Bool { context != .adopt && (model.price != nil || model.priceText?.isEmpty == false) }
    private var shouldShowAvailability: Bool { model.availability?.text.isEmpty == false }
    private var isOutOfStock: Bool { model.usesQuantityControl && (model.stock ?? 0) <= 0 }
    private var canIncreaseQuantity: Bool { model.stock.map { quantity < $0 } ?? true }

    private var primaryActionTitle: String {
        guard model.usesQuantityControl else { return "Details" }
        if isOutOfStock {
            if notifyInFlight { return "Saving alert" }
            if notifySucceeded { return "Alert saved" }
            return "Notify me"
        }
        return quantity > 0 ? "In cart • \(quantity)" : "Add to cart"
    }

    private var primaryActionIcon: String? {
        guard !notifyInFlight else { return nil }
        guard model.usesQuantityControl else { return context.isServiceLike ? "sparkles" : "arrow.up.right" }
        if isOutOfStock { return notifySucceeded ? "checkmark.circle.fill" : "bell.badge.fill" }
        return quantity > 0 ? "cart.fill" : "plus.cart.fill"
    }

    private var primaryActionForeground: Color { model.usesQuantityControl && quantity > 0 && !isOutOfStock ? palette.primary : .white }
    private var primaryActionBackground: Color {
        if isOutOfStock { return palette.primaryDark }
        if model.usesQuantityControl && quantity > 0 { return palette.primary.opacity(colorScheme == .dark ? 0.17 : 0.09) }
        return palette.primary
    }
    private var primaryActionBorder: Color {
        if isOutOfStock { return palette.primary.opacity(0.45) }
        if model.usesQuantityControl && quantity > 0 { return palette.primary.opacity(0.20) }
        return .clear
    }
    private var primaryActionShadow: Color { model.usesQuantityControl && quantity > 0 ? .clear : palette.primary.opacity(colorScheme == .dark ? 0.20 : 0.14) }

    private var displayCurrency: String {
        let normalized = normalizedCurrency(model.currencyCode.uppercased())
        guard layoutDirection == .rightToLeft else { return normalized }
        switch normalized {
        case "QAR": return "ر.ق"
        case "EGP": return "ج.م"
        case "SAR": return "ر.س"
        case "AED": return "د.إ"
        default: return normalized
        }
    }

    private func normalizedCurrency(_ raw: String) -> String {
        if raw.contains("QAR") || raw.contains("RIAL") { return "QAR" }
        if raw.contains("EGP") || raw.contains("POUND") { return "EGP" }
        if raw.contains("SAR") { return "SAR" }
        if raw.contains("AED") { return "AED" }
        return raw.isEmpty ? "QAR" : raw
    }

    private func pricePieces(_ amount: Decimal) -> (integer: String, fraction: String) {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        let formatted = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0.00"
        let split = formatted.split(separator: ".", omittingEmptySubsequences: false)
        return (split.first.map(String.init) ?? "0", split.count > 1 ? String(split[1]) : "00")
    }

    private func formattedPrice(_ amount: Decimal) -> String {
        let pieces = pricePieces(amount)
        let number = "\(pieces.integer).\(pieces.fraction)"
        return layoutDirection == .rightToLeft ? "\(number) \(displayCurrency)" : "\(displayCurrency) \(number)"
    }

    private func availabilityForeground(_ tone: PPUniversalAvailability.Tone) -> Color {
        switch tone {
        case .available: return palette.success
        case .limited: return palette.warning
        case .unavailable: return palette.destructive
        case .used: return colorScheme == .dark ? Color(hex: 0xB7E8E0) : Color(hex: 0x295C61)
        case .neutral: return secondaryInk
        }
    }

    private func availabilityBackground(_ tone: PPUniversalAvailability.Tone) -> Color {
        availabilityForeground(tone).opacity(colorScheme == .dark ? 0.14 : 0.10)
    }

    private enum PPHaptic { case light, medium, success, warning }
    private func haptic(_ kind: PPHaptic) {
        switch kind {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.72)
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.82)
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

// MARK: - Supporting Views

@available(iOS 16.0, *)
private struct PPUniversalRemoteImage: View {
    let url: URL?
    let placeholderSystemImage: String
    let contentMode: ContentMode

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.28))) { phase in
                switch phase {
                case .empty:
                    placeholder.overlay { ProgressView().controlSize(.small).tint(.secondary) }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [.primary.opacity(0.035), .primary.opacity(0.075)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: placeholderSystemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.55))
        }
    }
}

@available(iOS 16.0, *)
private struct PPBadge: View {
    let text: String
    let foreground: Color
    let background: Color
    let border: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10.8, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 0.8))
    }
}

@available(iOS 16.0, *)
private struct PPMetadataPill: View {
    let text: String
    let systemImage: String?
    let foreground: Color
    let background: Color
    let border: Color

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage, !systemImage.isEmpty {
                Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
            }
            Text(text).lineLimit(1).minimumScaleFactor(0.82)
        }
        .font(.system(size: 10.8, weight: .bold, design: .rounded))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background, in: Capsule())
        .overlay(Capsule().stroke(border, lineWidth: 0.8))
    }
}

@available(iOS 16.0, *)
private struct PPScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.06) : .spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

@available(iOS 16.0, *)
private struct PPUniversalSkeletonCard: View {
    let layout: PPUniversalCardLayout
    let cardRadius: CGFloat
    let imageRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if layout.isHorizontal {
                HStack(spacing: 14) {
                    skeletonMedia.frame(width: layout == .fullWidth ? 148 : 136)
                    skeletonBody
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    skeletonMedia.aspectRatio(layout == .pinterest ? 1.24 : 0.82, contentMode: .fit)
                    skeletonBody
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: cardRadius, style: .continuous).fill(colorScheme == .dark ? Color(hex: 0x17201C) : .white))
        .overlay(RoundedRectangle(cornerRadius: cardRadius, style: .continuous).stroke(.white.opacity(colorScheme == .dark ? 0.10 : 0.55), lineWidth: 1))
        .modifier(PPShimmer())
        .accessibilityHidden(true)
    }

    private var skeletonMedia: some View {
        RoundedRectangle(cornerRadius: imageRadius, style: .continuous)
            .fill(skeletonColor)
            .aspectRatio(1, contentMode: .fit)
    }

    private var skeletonBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonBar(width: 0.46, height: 18)
            skeletonBar(width: 0.92, height: 16)
            skeletonBar(width: 0.66, height: 14)
            Spacer(minLength: 2)
            skeletonBar(width: 0.55, height: 24)
            skeletonBar(width: 1, height: 38)
            skeletonBar(width: 0.48, height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule().fill(skeletonColor).frame(width: proxy.size.width * width, height: height)
        }
        .frame(height: height)
    }

    private var skeletonColor: Color { colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.065) }
}

@available(iOS 16.0, *)
private struct PPShimmer: ViewModifier {
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(colors: [.clear, .white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(width: proxy.size.width * 0.48)
                        .rotationEffect(.degrees(14))
                        .offset(x: proxy.size.width * phase)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) { phase = 2 }
            }
    }
}

// MARK: - UIKit Collection View Bridge

@available(iOS 16.0, *)
@objc public final class PPUniversalCardHostingCell: UICollectionViewCell {
    @objc public static let bridgeReuseIdentifier = "PPUniversalCell"

    private weak var bridgeDelegate: PPUniversalCellDelegate?
    private var bridgeViewModel: PPUniversalCellViewModel?
    private var bridgeContext: PPCellContext = PPCellForAds
    private var bridgeLayout: PPUniversalCardLayout = .market
    private var bridgeDiscountStyle: PPUniversalCardDiscountStyle = .badge

    @objc public var hideTopBadge: Bool = false
    @objc public var showsSubtitle: Bool = false
    @objc public var forceShowsOwnerMenuButton: Bool = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPUniversalCardHostingCell must be created programmatically.")
    }

    @objc public static func reuseIdentifier() -> String {
        return "PPUniversalCell"
    }

    @objc public func stopMediaPlayback() { }

    @objc public func refreshThemeAppearance() {
        setNeedsUpdateConfiguration()
    }

    @objc public func setQuantity(_ quantity: Int, animated: Bool) { }

    @objc public func collapseStepper(_ animated: Bool) { }

    @objc public func applyViewModel(
        _ vm: PPUniversalCellViewModel,
        context: PPCellContext,
        layoutMode: PPManagerCellLayoutMode,
        discountStyle: PPDiscountStyle,
        imageLoader: PPImageLoader?
    ) {
        bridgeViewModel = vm
        bridgeContext = context
        bridgeDiscountStyle = discountStyle == PPDiscountStyleInline ? .inline : .badge

        switch layoutMode {
        case PPCellLayoutModePinterest: bridgeLayout = .pinterest
        case PPCellLayoutModeMarket: bridgeLayout = .market
        case PPCellLayoutModeFullWidth: bridgeLayout = .fullWidth
        case PPCellLayoutModeHorizontalRow: bridgeLayout = .horizontalRow
        default: bridgeLayout = .market
        }

        contentConfiguration = UIHostingConfiguration {
            PPUniversalCardView(
                model: Self.bridgeModel(from: vm),
                context: Self.bridgeContext(from: context),
                layout: bridgeLayout,
                discountStyle: bridgeDiscountStyle,
                palette: .purePets,
                actions: Self.bridgeActions(viewModel: vm, delegate: bridgeDelegate)
            )
        }
        .margins(.all, 0)

        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .clear
        backgroundConfiguration = background
    }

    @objc public func setDelegate(_ delegate: PPUniversalCellDelegate?) {
        bridgeDelegate = delegate
    }

    @objc public weak var delegate: PPUniversalCellDelegate? {
        get { bridgeDelegate }
        set { setDelegate(newValue) }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        contentConfiguration = nil
        backgroundConfiguration = .clear()
        bridgeViewModel = nil
        bridgeDelegate = nil
        hideTopBadge = false
        showsSubtitle = false
        forceShowsOwnerMenuButton = false
    }

    // MARK: - Bridge Converters

    private static func bridgeContext(from objc: PPCellContext) -> PPUniversalCardContext {
        switch objc {
        case PPCellForAds: return .ads
        case PPCellForHomeAds: return .homeAds
        case PPCellForMarket, PPCellForContextAccessory: return .market
        case PPCellForFood: return .food
        case PPCellForServices: return .services
        case PPCellForVets: return .vets
        case PPCellForAdopt: return .adopt
        default: return .ads
        }
    }

    private static func bridgeModel(from vm: PPUniversalCellViewModel) -> PPUniversalCardModel {
        let price: Decimal? = vm.finalPrice?.decimalValue ?? vm.price?.decimalValue
        let originalPrice: Decimal? = vm.price?.decimalValue

        let imageURL: URL? = {
            guard let urlStr = vm.imageURL, !urlStr.isEmpty else { return nil }
            return URL(string: urlStr)
        }()

        let videoURL: URL? = {
            guard vm.isVideoMedia, let urlStr = vm.videoURL, !urlStr.isEmpty else { return nil }
            return URL(string: urlStr)
        }()

        let availability: PPUniversalAvailability? = {
            if vm.availabilityText.isEmpty { return nil }
            let lower = vm.availabilityText.lowercased()
            let tone: PPUniversalAvailability.Tone
            if lower.contains("out") || lower.contains("sold") || lower.contains("نف") || lower.contains("غير") {
                tone = .unavailable
            } else if lower.contains("only") || lower.contains("متبقي") {
                tone = .limited
            } else {
                tone = .available
            }
            return PPUniversalAvailability(text: vm.availabilityText, tone: tone)
        }()

        let prefersContained = vm.modelObject is PetAccessory ||
                               vm.cellSection == CellSectionAccessories ||
                               vm.cellSection == CellSectionFood

        return PPUniversalCardModel(
            id: vm.modelID ?? UUID().uuidString,
            title: vm.title,
            subtitle: vm.subtitle.isEmpty ? nil : vm.subtitle,
            imageURL: imageURL,
            videoURL: videoURL,
            placeholderSystemImage: "pawprint.fill",
            price: price,
            originalPrice: (originalPrice != nil && originalPrice != price) ? originalPrice : nil,
            priceText: vm.priceText.isEmpty ? nil : vm.priceText,
            currencyCode: vm.currencyCode.isEmpty ? "QAR" : vm.currencyCode,
            badgeText: vm.badgeText.isEmpty ? nil : vm.badgeText,
            reasonText: vm.contextualReasonText?.isEmpty == false ? vm.contextualReasonText : nil,
            discountText: vm.discountText.isEmpty ? nil : vm.discountText,
            availability: availability,
            isFavorite: false,
            isOwner: vm.isOwner,
            isPubliclyVisible: vm.isPubliclyVisible,
            isSkeleton: vm.isSkeleton,
            quantity: max(0, vm.itemQuantitiy),
            stock: nil,
            usesQuantityControl: vm.modelObject is PetAccessory,
            prefersContainedImage: prefersContained,
            preferredAspectRatio: CGFloat(vm.preferredAspectRatio)
        )
    }

    private static func bridgeActions(
        viewModel: PPUniversalCellViewModel,
        delegate: PPUniversalCellDelegate?
    ) -> PPUniversalCardActions {
        PPUniversalCardActions(
            onTap: { _ in
                delegate?.PPUniversalCell_tapCard?(viewModel)
            },
            onShare: { _ in
                delegate?.PPUniversalCell_tapShare?(viewModel)
            },
            onFavorite: { _, _ in
                delegate?.PPUniversalCell_tapFavorite?(viewModel)
            },
            onEdit: { _ in
                delegate?.PPUniversalCell_tapEdit?(viewModel)
            },
            onVisibilityToggle: { _ in
                delegate?.PPUniversalCell_tapVisibilityToggle?(viewModel)
            },
            onDelete: { _ in
                delegate?.PPUniversalCell_tapDelete?(viewModel)
            },
            onQuantityChange: { _, qty in
                delegate?.PPUniversalCell_changeQuantity?(viewModel, quantity: qty)
            },
            onNotifyWhenAvailable: { _ in
                false
            }
        )
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Preview

@available(iOS 16.0, *)
#Preview("Premium Marketplace Card") {
    ScrollView {
        VStack(spacing: 24) {
            PPUniversalCardView(
                model: PPUniversalCardModel(
                    id: "sample-food",
                    title: "Premium Grain-Free Cat Food",
                    subtitle: "Natural ingredients • Indoor adult cats",
                    imageURL: URL(string: "https://images.unsplash.com/photo-1574158622682-e40e69881006"),
                    price: 149,
                    originalPrice: 179,
                    discountText: "-17%",
                    availability: PPUniversalAvailability(text: "Available", tone: .available, metaText: "2.5 kg", metaSystemImage: "scalemass.fill"),
                    quantity: 2,
                    stock: 8,
                    usesQuantityControl: true,
                    prefersContainedImage: true
                ),
                context: .food,
                layout: .market
            )

            PPUniversalCardView(
                model: PPUniversalCardModel(
                    id: "sample-ad",
                    title: "British Shorthair Kitten",
                    subtitle: "Calm, vaccinated and ready for a loving home.",
                    imageURL: URL(string: "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba"),
                    price: 2200,
                    reasonText: "Featured",
                    availability: PPUniversalAvailability(text: "Doha • Male • 4 months")
                ),
                context: .ads,
                layout: .horizontalRow
            )

            PPUniversalCardView(
                model: PPUniversalCardModel(id: "skeleton", title: "", isSkeleton: true),
                context: .market,
                layout: .market
            )
        }
        .padding(18)
    }
    .background(Color(hex: 0xF5F3F4))
}
