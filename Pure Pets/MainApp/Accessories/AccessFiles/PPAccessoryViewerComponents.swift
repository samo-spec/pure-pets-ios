import SwiftUI
import UIKit

enum PPAccessoryPalette {
    static let appBackground = Color.ppBackground
    static let shell = Color.ppBackground
    static let ink = Color.ppTextPrimary
    static let inkSecondary = Color.ppTextSecondary

    static let brand = Color.ppPrimary
    static let brandDarker = Color.ppPrimaryDarker
    static let brandShine = Color.ppPrimaryShiner
    static let accent = Color.ppAccent
    static let success = Color.ppSuccess
    static let warning = Color.ppWarning
    static let error = Color.ppError

    static let sea = Color.ppAccent
    static let deepSea = Color.ppTextPrimary
    static let sand = Color.ppBackground
}

enum PPAccessorySubviewBackground {
    static let clear = Color.clear
    static let baseSurface = Color.ppForeground
    static let basePage = Color.ppBackground

    static let chromeFill = Color.ppForeground.opacity(0.78)
    static let quietFill = Color.ppForeground.opacity(0.58)
    static let mediaFill = Color.ppForeground.opacity(0.42)
    static let iconFill = Color.ppForeground.opacity(0.64)
    static let bottomBarFill = Color.ppForeground.opacity(0.62)
    static let dangerFill = Color.ppError.opacity(0.08)
    static let fullScreenChromeFill = Color.ppBackground.opacity(0.86)
    static let videoChromeFill = Color.black.opacity(0.66)

    static let faintStroke = Color.ppSeparator.opacity(0.40)
    static let controlStroke = Color.ppSeparator.opacity(0.60)
    static let chromeStroke = Color.ppSeparator.opacity(0.80)
    static let divider = Color.ppSeparator
}

extension View {
    func ppAccessorySubviewBackground<S: Shape>(
        _ fill: Color = PPAccessorySubviewBackground.quietFill,
        in shape: S,
        stroke: Color? = PPAccessorySubviewBackground.faintStroke,
        lineWidth: CGFloat = 1
    ) -> some View {
        background(fill, in: shape)
            .overlay {
                if let stroke {
                    shape.stroke(stroke, lineWidth: lineWidth)
                }
            }
    }
}

private struct PPAccessoryBottomFaceSurface: View {
    var body: some View {
        PPHeroApexGlowCornerSurface(
            accentStyle: .solid,
            solidColor: .ppElevatedSurface
        )
    }
}

enum PPAccessoryTypography {
    static let hero = Font.custom(
        "Beiruti-Bold",
        size: 28,
        relativeTo: .title
    )
    static let title = Font.custom(
        "Beiruti-Bold",
        size: 21,
        relativeTo: .title3
    )
    static let price = Font.custom(
        "Beiruti-Bold",
        size: 27,
        relativeTo: .title
    )
    static let headline = Font.custom(
        "Beiruti-Bold",
        size: 18,
        relativeTo: .headline
    )
    static let body = Font.custom(
        "Beiruti-Regular",
        size: 17,
        relativeTo: .body
    )
    static let bodyBold = Font.custom(
        "Beiruti-Bold",
        size: 17,
        relativeTo: .body
    )
    static let callout = Font.custom(
        "Beiruti-Regular",
        size: 15,
        relativeTo: .callout
    )
    static let calloutBold = Font.custom(
        "Beiruti-Bold",
        size: 15,
        relativeTo: .callout
    )
    static let caption = Font.custom(
        "Beiruti-Regular",
        size: 13,
        relativeTo: .caption
    )
    static let captionBold = Font.custom(
        "Beiruti-Bold",
        size: 13,
        relativeTo: .caption
    )
}

struct PPAccessoryPressStyle: ButtonStyle {
    let pressedScale: CGFloat

    init(pressedScale: CGFloat = 0.965) {
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                .spring(response: 0.20, dampingFraction: 0.82),
                value: configuration.isPressed
            )
    }
}

struct PPAccessoryBeachCanvas: View {
    var body: some View {
        PPHero()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct PPAccessoryViewerTopBar: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot?
    let showsSmartTitle: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PPSpace.md) {
            chromeButton(
                symbol: PPAccessoryViewerLegacyBridge.isRTL()
                    ? "chevron.right"
                    : "chevron.left",
                label: PPAccessoryViewerL10n.text("Back"),
                action: store.close
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(
                PPAccessoryViewerL10n.text("Back")
            )

            if showsSmartTitle, let snapshot {
                PPAccessoryViewerNavBarSmartPill(snapshot: snapshot)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 0.95).combined(with: .offset(y: 4))
                            )
                    )
            } else {
                Spacer(minLength: PPSpace.sm)
            }

            chromeButton(
                symbol: "square.and.arrow.up",
                label: PPAccessoryViewerL10n.text("Share"),
                action: store.share
            )
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.bottom, 8)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.30, dampingFraction: 0.88),
            value: showsSmartTitle
        )
    }

    @ViewBuilder
    private func chromeButton(
        symbol: String,
        label: String,
        tint: Color = PPAccessoryPalette.ink,
        action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 26.0, *) {
            PPAccessoryGlassButtonRepresentable(
                symbol: symbol,
                tint: tint,
                action: action
            )
            .frame(width: 44, height: 44)
            .accessibilityLabel(label)
        } else {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .ppAccessorySubviewBackground(
                        PPAccessorySubviewBackground.chromeFill,
                        in: Circle(),
                        stroke: PPAccessorySubviewBackground.chromeStroke,
                        lineWidth: 0.8
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.90))
            .accessibilityLabel(label)
        }
    }
}

struct PPAccessoryViewerNavBarSmartPill: View {
    let snapshot: PPAccessoryViewerSnapshot

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            mediaAvatar

            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle)
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                let subText = subtitleText
                if !subText.isEmpty {
                    Text(subText)
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: PPSpace.xs)

            priceBlock
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .ppGlassSurface(
            in: Capsule(),
            tint: Color.ppCard.opacity(0.85),
            fallback: Color(uiColor: .systemBackground).opacity(0.95),
            stroke: Color.white.opacity(0.24),
            lineWidth: 0.5
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 4,
            x: 0,
            y: 2
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var mediaAvatar: some View {
        if let firstMedia = snapshot.media.first {
            PPAccessoryRemoteImageView(
                urlString: firstMedia.imageURL,
                blurHash: firstMedia.blurHash,
                contentMode: .fill,
                accessibilityLabel: displayTitle
            )
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
        } else {
            ZStack {
                Color.ppPrimary.opacity(0.12)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.ppPrimary.opacity(0.2), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var priceBlock: some View {
        let pc = priceAndCurrency
        if pc.currency.isEmpty {
            Text(pc.price)
                .font(.custom("Beiruti-Bold", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 6)
        } else {
            VStack(alignment: .center, spacing: -2) {
                Text(pc.price)
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(pc.currency)
                    .font(.custom("Beiruti-Regular", size: 9, relativeTo: .caption2))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
        }
    }

    private var displayTitle: String {
        let title = snapshot.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if title.isEmpty {
            return PPAccessoryViewerL10n.text("accessory_view_product_fallback")
        }
        return title
    }

    private var subtitleText: String {
        let parts = [
            snapshot.accessoryCategory,
            snapshot.subcategory,
            snapshot.category
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return parts.prefix(2).joined(separator: " · ")
    }

    private var priceAndCurrency: (price: String, currency: String) {
        let components = snapshot.price.components(separatedBy: .whitespaces)
        guard components.count >= 2 else {
            return (snapshot.price, "")
        }

        let first = components[0]
        let last = components[components.count - 1]

        let hasDigits = first.rangeOfCharacter(from: .decimalDigits) != nil
        if hasDigits {
            let value = components.dropLast().joined(separator: " ")
            return (value, last)
        } else {
            let lastHasDigits = last.rangeOfCharacter(from: .decimalDigits) != nil
            if lastHasDigits {
                let value = components.dropFirst().joined(separator: " ")
                return (value, first)
            }
        }
        return (snapshot.price, "")
    }

    private var accessibilitySummary: String {
        let priceLabel = PPAccessoryViewerL10n.text("price")
        return [
            displayTitle,
            subtitleText,
            snapshot.price.isEmpty ? "" : "\(priceLabel) \(snapshot.price)"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}

struct PPAccessoryGlassButtonRepresentable: UIViewRepresentable {
    let symbol: String
    let tint: Color
    let action: () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.cornerStyle = .capsule
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = UIColor(tint)
            config.image = UIImage(systemName: symbol)
            button.configuration = config
        }
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        if #available(iOS 26.0, *) {
            var config = uiView.configuration ?? UIButton.Configuration.glass()
            config.baseForegroundColor = UIColor(tint)
            config.image = UIImage(systemName: symbol)
            uiView.configuration = config
        }
    }
}

struct PPAccessoryViewerInlineBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PPAccessoryPalette.error)
            Text(message)
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(PPAccessoryViewerL10n.text("Close"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.dangerFill,
            in: Capsule(),
            stroke: PPAccessoryPalette.error.opacity(0.20)
        )
        .accessibilityElement(children: .contain)
    }
}

struct PPAccessoryShorelineGallery: View {
    let snapshot: PPAccessoryViewerSnapshot
    let height: CGFloat
    let compact: Bool
    let onShare: () -> Void

    @State private var selection = 0
    @State private var showsMediaViewer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            gallerySurface

            ZStack {
                if snapshot.media.isEmpty {
                    emptyMedia
                } else {
                    TabView(selection: $selection) {
                        ForEach(
                            Array(snapshot.media.enumerated()),
                            id: \.element.id
                        ) { index, item in
                            mediaPage(item, index: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .clipShape(galleryShape)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    availabilitySeal
                    Spacer(minLength: 8)
                    mediaCountSeal
                }
                .padding(.horizontal, compact ? 14 : 18)
                .padding(.top, compact ? 14 : 18)
                .allowsHitTesting(false)

                Spacer(minLength: 0)
            }

            if showsGalleryRail {
                galleryRail
                    .padding(.leading, compact ? 12 : 16)
                    .padding(.bottom, compact ? 12 : 16)
            }
        }
        .frame(height: height)
        .clipShape(galleryShape)
        .overlay {
            galleryShape
                .stroke(PPAccessoryPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onChange(of: selection) { _ in
            PPAccessoryViewerLegacyBridge.playSelectionFeedback()
        }
        .fullScreenCover(isPresented: $showsMediaViewer) {
            PPAccessoryFullScreenMediaViewer(
                items: snapshot.media,
                selection: $selection,
                onDismiss: { showsMediaViewer = false },
                onShare: onShare
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var galleryShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: compact ? 28 : 34,
            style: .continuous
        )
    }

    private var showsGalleryRail: Bool {
        snapshot.media.count > 1
    }

    private var mediaHeight: CGFloat {
        height
    }

    private var gallerySurface: some View {
        Color.clear
            .clipShape(galleryShape)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mediaPage(
        _ item: PPAccessoryViewerMediaItem,
        index: Int
    ) -> some View {
        Button {
            showsMediaViewer = true
        } label: {
            ZStack {
                PPAccessoryRemoteImageView(
                    urlString: item.imageURL,
                    blurHash: item.blurHash,
                    contentMode: .fill,
                    accessibilityLabel: mediaLabel(index)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if item.isVideo {
                    Circle()
                        .fill(PPAccessorySubviewBackground.fullScreenChromeFill)
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(PPAccessoryPalette.ink)
                                .offset(x: 2)
                        }
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mediaLabel(index))
        .accessibilityHint(
            PPAccessoryViewerL10n.text(
                "accessory_view_open_gallery"
            )
        )
    }

    private var availabilitySeal: some View {
        HStack(spacing: 7) {
            Image(
                systemName: snapshot.quantity > 0 && !snapshot.isUnavailable
                    ? "checkmark.seal.fill"
                    : "xmark.seal.fill"
            )
            .font(.system(size: 13, weight: .bold))
            Text(snapshot.stock)
                .font(PPAccessoryTypography.captionBold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(
            snapshot.quantity > 0 && !snapshot.isUnavailable
                ? PPAccessoryPalette.success
                : PPAccessoryPalette.error
        )
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.chromeFill,
            in: Capsule(),
            stroke: PPAccessorySubviewBackground.chromeStroke,
            lineWidth: 0.8
        )
        .accessibilityElement(children: .combine)
    }

    private var mediaCountSeal: some View {
        HStack(spacing: 6) {
            Image(systemName: snapshot.media.isEmpty ? "photo" : "photo.stack")
                .font(.system(size: 12, weight: .bold))
            Text(mediaCountText)
                .font(PPAccessoryTypography.captionBold)
                .monospacedDigit()
        }
        .foregroundStyle(PPAccessoryPalette.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.chromeFill,
            in: Capsule(),
            stroke: PPAccessorySubviewBackground.chromeStroke,
            lineWidth: 0.8
        )
        .accessibilityElement(children: .combine)
    }

    private var mediaCountText: String {
        if snapshot.media.isEmpty {
            return PPAccessoryViewerL10n.text("Photo")
        }
        return "\(selection + 1)/\(snapshot.media.count)"
    }

    private var emptyMedia: some View {
        ZStack {
            PPAccessorySubviewBackground.mediaFill

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(PPAccessorySubviewBackground.iconFill)
                        .frame(width: 108, height: 108)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(PPAccessoryPalette.accent)
                }
                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_no_media"
                    )
                )
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.ink)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var galleryRail: some View {
        HStack(spacing: 8) {
            ForEach(
                Array(snapshot.media.prefix(6).enumerated()),
                id: \.element.id
            ) { index, item in
                Button {
                    withAnimation(
                        reduceMotion
                            ? nil
                            : .spring(
                                response: 0.28,
                                dampingFraction: 0.82
                            )
                    ) {
                        selection = index
                    }
                } label: {
                    ZStack {
                        PPAccessoryRemoteImageView(
                            urlString: item.imageURL,
                            blurHash: item.blurHash,
                            contentMode: .fill,
                            accessibilityLabel: mediaLabel(index)
                        )
                        if item.isVideo {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(
                        width: selection == index ? 52 : 42,
                        height: selection == index ? 52 : 42
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: compact ? 11 : 13,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: compact ? 11 : 13,
                            style: .continuous
                        )
                        .stroke(
                            selection == index
                                ? PPAccessoryPalette.accent
                                : PPAccessoryPalette.ink.opacity(0.12),
                            lineWidth: selection == index ? 2 : 1
                        )
                    }
                }
                .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.92))
                .accessibilityLabel(mediaLabel(index))
                .accessibilityAddTraits(
                    selection == index ? .isSelected : []
                )
            }

            if snapshot.media.count > 6 {
                Text("+\(snapshot.media.count - 6)")
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .frame(width: 42, height: 42)
                    .ppAccessorySubviewBackground(
                        PPAccessorySubviewBackground.quietFill,
                        in: Circle(),
                        stroke: PPAccessorySubviewBackground.controlStroke
                    )
            }
        }
        .padding(6)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.chromeFill,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            stroke: PPAccessorySubviewBackground.controlStroke,
            lineWidth: 0.8
        )
    }

    private func mediaLabel(_ index: Int) -> String {
        "\(PPAccessoryViewerL10n.text("Photo")) \(index + 1) \(PPAccessoryViewerL10n.text("of")) \(snapshot.media.count)"
    }
}

@available(iOS 16.0, *)
struct PPAccessoryProductIdentity: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot
    let compact: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            if let categoryContext {
                categoryOverline(categoryContext)
                    .padding(.trailing, favoriteButtonFootprint)
            }

            VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                productTitleRow
                    .padding(.trailing, favoriteButtonFootprint)
                priceRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, compact ? 6 : 10)
        .padding(.bottom, compact ? 16 : 20)
        .overlay(alignment: .topTrailing) {
            favoriteButton
        }
        .accessibilityElement(children: .contain)
    }

    private func categoryOverline(_ category: String) -> some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(PPAccessoryPalette.brand)
                .frame(width: 22, height: 3)
                .accessibilityHidden(true)

            Text(category)
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(PPAccessoryPalette.brandDarker)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var productTitleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(displayTitle)
                .font(
                    compact
                        ? PPAccessoryTypography.title
                        : PPAccessoryTypography.hero
                )
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(3)
        }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if store.favoritePhase == .loading {
            ProgressView()
                .tint(PPAccessoryPalette.ink)
                .frame(width: 40, height: 40)
                .ppAccessorySubviewBackground(
                    PPAccessorySubviewBackground.chromeFill,
                    in: Circle(),
                    stroke: PPAccessorySubviewBackground.chromeStroke,
                    lineWidth: 0.8
                )
                .accessibilityLabel(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_updating_favorite"
                    )
                )
        } else {
            Button(action: store.toggleFavorite) {
                Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(
                        store.isFavorite
                            ? PPAccessoryPalette.error
                            : PPAccessoryPalette.ink
                    )
                    .frame(width: 40, height: 40)
                    .ppAccessorySubviewBackground(
                        PPAccessorySubviewBackground.quietFill,
                        in: Circle(),
                        stroke: PPAccessorySubviewBackground.faintStroke,
                        lineWidth: 0.8
                    )
            }
            .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.88))
            .accessibilityLabel(
                store.isFavorite
                    ? PPAccessoryViewerL10n.text("a11y_btn_unfavorite")
                    : PPAccessoryViewerL10n.text("a11y_btn_favorite")
            )
            .accessibilityValue(
                store.isFavorite
                    ? PPAccessoryViewerL10n.text("a11y_btn_unfavorite")
                    : PPAccessoryViewerL10n.text("a11y_btn_favorite")
            )
        }
    }

    private var priceRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                currentPrice

                if let ratingValue = providerRatingValue {
                    Spacer(minLength: 8)
                    providerRatingPill(ratingValue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if snapshot.hasDiscount {
                discountSummary
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(2)
    }

    private var currentPrice: some View {
        Text(snapshot.price)
            .font(PPAccessoryTypography.price)
            .bold()
            .fontWeight(.bold)
            .foregroundStyle(PPAccessoryPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .layoutPriority(2)
            .contentTransition(.numericText())
            .priceHaloTransition(pulseToken: store.pricePulseToken)
    }

    private var discountSummary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(snapshot.originalPrice)
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .strikethrough()
                .lineLimit(1)

            if let percentage = snapshot.discountPercent, percentage > 0 {
                Text(discountText(percentage))
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(PPAccessoryPalette.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        PPAccessoryPalette.success.opacity(0.12),
                        in: Capsule()
                    )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func discountText(_ percentage: Double) -> String {
        String(
            format: PPAccessoryViewerL10n.text(
                "accessory_view_discount_format"
            ),
            locale: .current,
            percentage
        )
    }

    private var favoriteButtonFootprint: CGFloat {
        52
    }

    private var displayTitle: String {
        let title = snapshot.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if title.isEmpty {
            return PPAccessoryViewerL10n.text(
                "accessory_view_product_fallback"
            )
        }
        return title
    }

    private var categoryContext: String? {
        [
            snapshot.accessoryCategory,
            snapshot.subcategory,
            snapshot.category
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    private var providerRatingValue: Double? {
        snapshot.testingRatingValue
    }

    private func providerRatingPill(_ ratingValue: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        Double(index) <= ratingValue
                            ? PPAccessoryPalette.warning
                            : PPAccessoryPalette.inkSecondary.opacity(0.24)
                    )
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.baseSurface,
            in: Capsule(),
            stroke: PPAccessorySubviewBackground.controlStroke,
            lineWidth: 0.8
        )
    }
}

private struct PPAccessoryReadinessFact: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let value: String
    let color: Color
}

@available(iOS 16.0, *)
struct PPAccessoryDecisionRibbon: View {
    let snapshot: PPAccessoryViewerSnapshot

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalFacts
            } else {
                ViewThatFits(in: .horizontal) {
                    horizontalFacts
                    verticalFacts
                }
            }
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.quietFill,
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            ),
            stroke: colorSchemeContrast == .increased
                ? PPAccessorySubviewBackground.chromeStroke
                : PPAccessorySubviewBackground.controlStroke,
            lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.8
        )
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
    }

    private var horizontalFacts: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                factView(fact)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index < facts.count - 1 {
                    Divider()
                        .frame(height: 34)
                        .padding(.horizontal, PPSpace.sm)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalFacts: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                factView(fact)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index < facts.count - 1 {
                    Divider()
                        .padding(.vertical, PPSpace.sm)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func factView(_ fact: PPAccessoryReadinessFact) -> some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
                .fill(
                    fact.color.opacity(
                        colorSchemeContrast == .increased ? 0.24 : 0.14
                    )
                )

                Image(systemName: fact.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(fact.color)
                    .accessibilityHidden(true)
            }
            .frame(width: factIconSize, height: factIconSize)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(fact.title)
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)

                Text(fact.value)
                    .font(PPAccessoryTypography.calloutBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.title): \(fact.value)")
    }

    private var facts: [PPAccessoryReadinessFact] {
        var result: [PPAccessoryReadinessFact] = []

        if !snapshot.stock.isEmpty {
            result.append(
                PPAccessoryReadinessFact(
                    id: "availability",
                    symbol: availabilitySymbol,
                    title: PPAccessoryViewerL10n.text("Availability"),
                    value: snapshot.stock,
                    color: availabilityColor
                )
            )
        }

        if !snapshot.condition.isEmpty {
            result.append(
                PPAccessoryReadinessFact(
                    id: "condition",
                    symbol: "checkmark.seal",
                    title: PPAccessoryViewerL10n.text("Condition"),
                    value: snapshot.condition,
                    color: PPAccessoryPalette.brandDarker
                )
            )
        }

        if !snapshot.createdDate.isEmpty {
            result.append(
                PPAccessoryReadinessFact(
                    id: "listed",
                    symbol: "calendar",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_listed_on"
                    ),
                    value: snapshot.createdDate,
                    color: PPAccessoryPalette.sea
                )
            )
        }

        return result
    }

    private var availabilitySymbol: String {
        if snapshot.isUnavailable || snapshot.quantity <= 0 {
            return "xmark.octagon.fill"
        }
        if snapshot.quantity <= 5 {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }

    private var availabilityColor: Color {
        if snapshot.isUnavailable || snapshot.quantity <= 0 {
            return PPAccessoryPalette.error
        }
        if snapshot.quantity <= 5 {
            return PPAccessoryPalette.warning
        }
        return PPAccessoryPalette.success
    }

    private var factIconSize: CGFloat {
        PPSpace.xxl + PPSpace.xs
    }
}

private extension PPAccessoryViewerDetailTone {
    var accessoryAccentColor: Color {
        return PPAccessoryPalette.inkSecondary
    }
}

struct PPAccessorySpecReef: View {
    let details: [PPAccessoryViewerDetailItem]
    let compactColumns: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionTitle(
                PPAccessoryViewerL10n.text("accessory_view_details_title"),
                symbol: "list.bullet.rectangle"
            )
            .padding(.top, compactColumns ? 12 : 16)

            if railDetails.isEmpty {
                emptyDetails
            } else {
                detailsRail
            }
        }
    }

    @ViewBuilder
    private var detailsRail: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                ForEach(railDetails) { detail in
                    detailRow(detail, fillsWidth: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityElement(children: .contain)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: detailRailSpacing) {
                    ForEach(railDetails) { detail in
                        detailRow(detail, fillsWidth: false)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var detailRailSpacing: CGFloat {
        PPSpace.sm
    }

    private var detailIconSize: CGFloat {
        PPSpace.xxl + PPSpace.xs
    }

    private var railDetails: [PPAccessoryViewerDetailItem] {
        details.filter { detail in
            detail.id != "accessory-category" && detail.id != "listed"
        }
    }

    private func detailRow(
        _ detail: PPAccessoryViewerDetailItem,
        fillsWidth: Bool
    ) -> some View {
        let accent = detail.tone.accessoryAccentColor

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
                .fill(
                    accent.opacity(
                        colorSchemeContrast == .increased ? 0.20 : 0.11
                    )
                )

                Image(systemName: detail.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
            .frame(width: detailIconSize, height: detailIconSize)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(detail.title)
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .lineLimit(fillsWidth ? nil : 1)
                    .fixedSize(horizontal: !fillsWidth, vertical: true)

                Text(detail.value)
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .lineLimit(
                        fillsWidth || dynamicTypeSize.isAccessibilitySize
                            ? nil
                            : 1
                    )
                    .fixedSize(horizontal: !fillsWidth, vertical: true)
            }

            if fillsWidth {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, PPSpace.md)
        .padding(.trailing, PPSpace.xl)
        .padding(.vertical, PPSpace.sm)
        .frame(
            maxWidth: fillsWidth ? .infinity : nil,
            alignment: .topLeading
        )
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.baseSurface,
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            ),
            stroke: accent.opacity(
                colorSchemeContrast == .increased ? 0.44 : 0.20
            ),
            lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.8
        )
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(
                    accent.opacity(
                        colorSchemeContrast == .increased ? 0.70 : 0.44
                    )
                )
                .frame(width: 3)
                .padding(.vertical, PPSpace.sm)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(detail.title): \(detail.value)")
    }

    private var emptyDetails: some View {
        let accent = PPAccessoryPalette.brandDarker

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
                .fill(
                    accent.opacity(
                        colorSchemeContrast == .increased ? 0.20 : 0.11
                    )
                )

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
            .frame(width: PPSpace.xxxl, height: PPSpace.xxxl)

            Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_details_empty"
                )
            )
            .font(PPAccessoryTypography.body)
            .foregroundStyle(PPAccessoryPalette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.baseSurface,
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            ),
            stroke: accent.opacity(
                colorSchemeContrast == .increased ? 0.44 : 0.20
            ),
            lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.8
        )
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(
                    accent.opacity(
                        colorSchemeContrast == .increased ? 0.70 : 0.44
                    )
                )
                .frame(width: 3)
                .padding(.vertical, PPSpace.md)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

private enum PPAccessorySourceActionStyle {
    case neutral
    case chat
    case profile
}

private enum PPAccessorySourceActionLayout: Equatable {
    case flexibleTile
    case primaryPill
    case squareIcon
}

@available(iOS 16.0, *)
struct PPAccessorySourceIsland: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        stateContent
            .padding(.top, PPSpace.xs)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.32, dampingFraction: 0.88),
                value: store.ownerPhase
            )
    }

    @ViewBuilder
    private var stateContent: some View {
        switch store.ownerPhase {
        case .idle, .loading:
            ownerSkeleton
        case .loaded:
            if let owner = store.owner {
                ownerContent(owner)
            } else {
                fallbackContent
            }
        case .empty:
            fallbackContent
        case let .failed(message):
            recoveryContent(message: message)
        }
    }

    private func ownerContent(_ owner: PPAccessoryViewerOwner) -> some View {
        sourceSurface {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                ownerIdentityButton(owner)
                sellerActionRunway(owner)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func ownerIdentityButton(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        Button(action: store.openSellerProfile) {
            ViewThatFits(in: .horizontal) {
                ownerIdentityHorizontal(owner)
                ownerIdentityVertical(owner)
            }
            .contentShape(sourceSurfaceShape)
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ownerAccessibilitySummary(owner))
        .accessibilityHint(PPAccessoryViewerL10n.text("View_Profile"))
    }

    private func ownerIdentityHorizontal(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            sellerAvatar(owner, size: 80)

            sellerIdentityText(owner)
                .layoutPriority(1)

            profileCue
                .layoutPriority(0)
        }
    }

    private func ownerIdentityVertical(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                sellerAvatar(owner, size: 76)
                sellerIdentityText(owner)
                    .layoutPriority(1)
            }

            profileCue
        }
    }

    private func sellerIdentityText(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(sectionTitle)
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                Text(displayName(for: owner))
                    .font(PPAccessoryTypography.title)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if owner.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PPAccessoryPalette.success)
                        .accessibilityLabel(
                            PPAccessoryViewerL10n.text(
                                "accessory_view_verified_seller"
                            )
                        )
                }
            }

            sellerMeta(owner)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sellerAvatar(
        _ owner: PPAccessoryViewerOwner,
        size: CGFloat
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(avatarPlateFill)

            PPAccessoryRemoteImageView(
                urlString: owner.preferredAvatarURL,
                blurHash: nil,
                contentMode: .fill,
                accessibilityLabel: displayName(for: owner),
                isAvatar: true,
                fallbackInitials: displayName(for: owner)
            )
            .padding(5)
            .frame(width: max(size - 10, 0), height: max(size - 10, 0))
            .clipShape(Circle())

            if owner.isVerified {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 22, height: 22)
                    .background(PPAccessoryPalette.success, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.ppBackground.opacity(0.92), lineWidth: 2)
                    )
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(
                    colorSchemeContrast == .increased
                        ? PPAccessoryPalette.ink.opacity(0.34)
                        : PPAccessorySubviewBackground.faintStroke,
                    lineWidth: colorSchemeContrast == .increased ? 1.4 : 1
                )
        )
        .accessibilityHidden(true)
    }

    private func sellerMeta(_ owner: PPAccessoryViewerOwner) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PPSpace.sm) {
                sellerTrustCapsule(owner)
                sellerLocationLabel
            }

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                sellerTrustCapsule(owner)
                sellerLocationLabel
            }
        }
    }

    private func sellerTrustCapsule(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        HStack(spacing: 6) {
            Image(
                systemName: owner.isVerified
                    ? "checkmark.seal.fill"
                    : (snapshot.isProviderMarketplace
                        ? "storefront.fill"
                        : "person.crop.circle.fill")
            )
            .font(.system(size: 11, weight: .bold))

            Text(ownerStatusText(owner))
                .font(PPAccessoryTypography.captionBold)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .foregroundStyle(
            owner.isVerified
                ? PPAccessoryPalette.success
                : PPAccessoryPalette.inkSecondary
        )
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, 6)
        .background(
            owner.isVerified
                ? PPAccessoryPalette.success.opacity(
                    colorSchemeContrast == .increased ? 0.18 : 0.10
                )
                : PPAccessorySubviewBackground.quietFill,
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var sellerLocationLabel: some View {
        let location = snapshot.location.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !location.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)

                Text(location)
                    .font(PPAccessoryTypography.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(PPAccessoryPalette.inkSecondary)
            .padding(.trailing, PPSpace.xs)
        }
    }

    private var profileCue: some View {
        HStack(spacing: PPSpace.xs) {
            Text(PPAccessoryViewerL10n.text("View_Profile"))
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Image(systemName: "chevron.forward")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(PPAccessoryPalette.brand)
                .frame(width: 30, height: 30)
                .background(
                    PPAccessoryPalette.brand.opacity(
                        colorSchemeContrast == .increased ? 0.16 : 0.08
                    ),
                    in: Circle()
                )
                .accessibilityHidden(true)
        }
        .padding(.leading, PPSpace.xs)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func sellerActionRunway(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                sourceAction(
                    title: PPAccessoryViewerL10n.text("Chat"),
                    symbol: "message.fill",
                    style: .chat,
                    layout: .primaryPill,
                    enabled: owner.isChatAllowed,
                    disabledValue: PPAccessoryViewerL10n.text(
                        "accessory_view_contact_unavailable"
                    ),
                    action: store.chatWithOwner
                )

                HStack(spacing: PPSpace.sm) {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("View_Profile"),
                        symbol: "storefront.fill",
                        style: .profile,
                        layout: .primaryPill,
                        enabled: true,
                        action: store.openSellerProfile
                    )

                    if shouldShowCall(for: owner) {
                        sourceAction(
                            title: PPAccessoryViewerL10n.text("Call"),
                            symbol: "phone.fill",
                            layout: .squareIcon,
                            enabled: true,
                            action: store.callOwner
                        )
                    }
                }
            }
        } else {
            HStack(spacing: PPSpace.sm) {
                sourceAction(
                    title: PPAccessoryViewerL10n.text("Chat"),
                    symbol: "message.fill",
                    style: .chat,
                    layout: .primaryPill,
                    enabled: owner.isChatAllowed,
                    disabledValue: PPAccessoryViewerL10n.text(
                        "accessory_view_contact_unavailable"
                    ),
                    action: store.chatWithOwner
                )
                .layoutPriority(1)

                sourceAction(
                    title: PPAccessoryViewerL10n.text("View_Profile"),
                    symbol: "storefront.fill",
                    style: .profile,
                    layout: .squareIcon,
                    enabled: true,
                    action: store.openSellerProfile
                )

                if shouldShowCall(for: owner) {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("Call"),
                        symbol: "phone.fill",
                        layout: .squareIcon,
                        enabled: true,
                        action: store.callOwner
                    )
                }
            }
        }
    }

    private func shouldShowCall(
        for owner: PPAccessoryViewerOwner
    ) -> Bool {
        !snapshot.isOwnItem && owner.phoneNumber != nil
    }

    private var fallbackContent: some View {
        sourceFallbackSurface(
            symbol: "person.crop.circle.badge.questionmark",
            title: PPAccessoryViewerL10n.text(
                "accessory_view_contact_unavailable"
            ),
            message: PPAccessoryViewerL10n.text(
                "accessory_view_seller_empty_message"
            ),
            buttonTitle: PPAccessoryViewerL10n.text("Support"),
            buttonSymbol: "message.badge.fill",
            action: store.openSupport
        )
    }

    private var ownerSkeleton: some View {
        sourceSurface {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                HStack(spacing: PPSpace.md) {
                    Circle()
                        .fill(PPAccessoryPalette.ink.opacity(0.08))
                        .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 9) {
                        Capsule()
                            .fill(PPAccessoryPalette.ink.opacity(0.08))
                            .frame(width: 78, height: 11)
                        Capsule()
                            .fill(PPAccessoryPalette.ink.opacity(0.11))
                            .frame(width: 168, height: 21)
                        Capsule()
                            .fill(PPAccessoryPalette.ink.opacity(0.07))
                            .frame(width: 126, height: 18)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: PPSpace.sm) {
                    Capsule()
                        .fill(PPAccessoryPalette.ink.opacity(0.08))
                        .frame(height: sourceActionControlSize)
                    Circle()
                        .fill(PPAccessoryPalette.ink.opacity(0.07))
                        .frame(
                            width: sourceActionControlSize,
                            height: sourceActionControlSize
                        )
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_seller_pending")
        )
    }

    private func recoveryContent(message: String) -> some View {
        sourceFallbackSurface(
            symbol: "wifi.exclamationmark",
            title: PPAccessoryViewerL10n.text("accessory_view_owner_failed"),
            message: message,
            buttonTitle: PPAccessoryViewerL10n.text("Retry"),
            buttonSymbol: "arrow.clockwise",
            action: store.retryOwner
        )
    }

    private func sourceFallbackSurface(
        symbol: String,
        title: String,
        message: String,
        buttonTitle: String,
        buttonSymbol: String,
        action: @escaping () -> Void
    ) -> some View {
        sourceSurface {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                HStack(alignment: .top, spacing: PPSpace.md) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PPAccessoryPalette.warning)
                        .frame(width: 58, height: 58)
                        .background(
                            PPAccessoryPalette.warning.opacity(
                                colorSchemeContrast == .increased ? 0.16 : 0.09
                            ),
                            in: Circle()
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(PPAccessoryTypography.headline)
                            .foregroundStyle(PPAccessoryPalette.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(PPAccessoryTypography.callout)
                            .foregroundStyle(PPAccessoryPalette.inkSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                sourceAction(
                    title: buttonTitle,
                    symbol: buttonSymbol,
                    layout: .primaryPill,
                    enabled: true,
                    action: action
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func sourceAction(
        title: String,
        symbol: String,
        style: PPAccessorySourceActionStyle = .neutral,
        layout: PPAccessorySourceActionLayout = .flexibleTile,
        enabled: Bool,
        disabledValue: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let shape =
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        let isSquare = layout == .squareIcon

        return Button(action: action) {
            Group {
                switch layout {
                case .squareIcon:
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                case .primaryPill:
                    HStack(spacing: PPSpace.sm) {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .bold))
                            .accessibilityHidden(true)
                        Text(title)
                            .font(PPAccessoryTypography.bodyBold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: PPSpace.xs)
                        if !enabled {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, PPSpace.md)
                case .flexibleTile:
                    VStack(spacing: 6) {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(title)
                            .font(PPAccessoryTypography.captionBold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                    }
                }
            }
            .foregroundStyle(
                sourceActionForeground(enabled: enabled, style: style)
            )
            .frame(
                width: isSquare ? sourceActionControlSize : nil,
                height: isSquare ? sourceActionControlSize : nil
            )
            .frame(maxWidth: isSquare ? nil : .infinity)
            .frame(minHeight: sourceActionControlSize)
            .ppAccessorySubviewBackground(
                sourceActionBackground(enabled: enabled, style: style),
                in: shape,
                stroke: sourceActionStroke(enabled: enabled, style: style),
                lineWidth: sourceActionLineWidth(enabled: enabled, style: style)
            )
            .contentShape(shape)
        }
        .buttonStyle(PPAccessoryPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
        .accessibilityLabel(title)
        .accessibilityValue(enabled ? "" : (disabledValue ?? ""))
    }

    private var sourceActionControlSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 60 : 56
    }

    private func sourceActionForeground(
        enabled: Bool,
        style: PPAccessorySourceActionStyle
    ) -> Color {
        switch style {
        case .neutral:
            return PPAccessoryPalette.ink
        case .chat:
            return enabled
                ? PPAccessoryPalette.brand
                : PPAccessoryPalette.inkSecondary
        case .profile:
            return enabled
                ? PPAccessoryPalette.ink
                : PPAccessoryPalette.inkSecondary
        }
    }

    private func sourceActionBackground(
        enabled: Bool,
        style: PPAccessorySourceActionStyle
    ) -> Color {
        switch style {
        case .neutral:
            return enabled
                ? PPAccessorySubviewBackground.quietFill
                : PPAccessorySubviewBackground.quietFill.opacity(0.54)
        case .chat:
            return enabled
                ? PPAccessoryPalette.brand.opacity(
                    colorSchemeContrast == .increased ? 0.18 : 0.10
                )
                : PPAccessorySubviewBackground.quietFill.opacity(0.54)
        case .profile:
            return enabled
                ? PPAccessorySubviewBackground.baseSurface.opacity(0.76)
                : PPAccessorySubviewBackground.quietFill.opacity(0.54)
        }
    }

    private func sourceActionStroke(
        enabled: Bool,
        style: PPAccessorySourceActionStyle
    ) -> Color {
        switch style {
        case .neutral:
            return PPAccessorySubviewBackground.faintStroke.opacity(
                enabled ? 1 : 0.56
            )
        case .chat:
            return PPAccessoryPalette.brand.opacity(
                enabled
                    ? (colorSchemeContrast == .increased ? 0.68 : 0.36)
                    : 0.14
            )
        case .profile:
            return PPAccessoryPalette.brand.opacity(
                enabled
                    ? (colorSchemeContrast == .increased ? 0.42 : 0.18)
                    : 0.10
            )
        }
    }

    private func sourceActionLineWidth(
        enabled: Bool,
        style: PPAccessorySourceActionStyle
    ) -> CGFloat {
        switch style {
        case .neutral:
            return 1
        case .chat:
            return enabled && colorSchemeContrast == .increased ? 1.4 : 1
        case .profile:
            return enabled && colorSchemeContrast == .increased ? 1.25 : 1
        }
    }

    private func sourceSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .topTrailing) {
                sellerPawPeek
                    .offset(
                        x: PPAccessoryViewerLegacyBridge.isRTL()
                            ? -PPSpace.sm
                            : PPSpace.sm,
                        y: -PPSpace.sm
                    )
            }
            .ppAccessorySubviewBackground(
                sourceSurfaceFill,
                in: sourceSurfaceShape,
                stroke: sourceSurfaceStroke,
                lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.8
            )
            .clipShape(sourceSurfaceShape)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.045),
                radius: 16,
                x: 0,
                y: 8
            )
    }

    private var sourceSurfaceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
    }

    private var sourceSurfaceFill: Color {
        colorSchemeContrast == .increased
            ? PPAccessorySubviewBackground.baseSurface.opacity(0.96)
            : PPAccessorySubviewBackground.baseSurface.opacity(
                colorScheme == .dark ? 0.72 : 0.84
            )
    }

    private var sourceSurfaceStroke: Color {
        colorSchemeContrast == .increased
            ? PPAccessoryPalette.ink.opacity(0.32)
            : PPAccessorySubviewBackground.faintStroke.opacity(
                colorScheme == .dark ? 0.88 : 0.70
            )
    }

    private var sellerPawPeek: some View {
        Image("peekingPaw")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(sellerPawTint)
            .frame(width: sellerPawSize, height: sellerPawSize)
            .rotationEffect(
                .degrees(PPAccessoryViewerLegacyBridge.isRTL() ? -9 : 9)
            )
            .opacity(sellerPawOpacity)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var sellerPawSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 108 : 88
    }

    private var sellerPawOpacity: Double {
        if colorSchemeContrast == .increased {
            return colorScheme == .dark ? 0.12 : 0.08
        }
        return colorScheme == .dark ? 0.09 : 0.06
    }

    private var sellerPawTint: Color {
        colorScheme == .dark
            ? PPAccessoryPalette.accent
        : UIColor.lightGray
    }

    private var avatarPlateFill: LinearGradient {
        LinearGradient(
            colors: [
                PPAccessoryPalette.brand.opacity(
                    colorSchemeContrast == .increased ? 0.20 : 0.12
                ),
                PPAccessoryPalette.accent.opacity(
                    colorSchemeContrast == .increased ? 0.14 : 0.08
                ),
                PPAccessorySubviewBackground.baseSurface.opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sectionTitle: String {
        PPAccessoryViewerL10n.text(
            snapshot.isProviderMarketplace
                ? "accessory_view_sold_by"
                : "accessory_view_seller_title"
        )
    }

    private func displayName(
        for owner: PPAccessoryViewerOwner
    ) -> String {
        let name = owner.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        return PPAccessoryViewerL10n.text("accessory_view_store_name")
    }

    private func ownerStatusText(
        _ owner: PPAccessoryViewerOwner
    ) -> String {
        if owner.isVerified {
            return PPAccessoryViewerL10n.text("accessory_view_verified_seller")
        }
        return snapshot.isProviderMarketplace
            ? PPAccessoryViewerL10n.text("accessory_view_market_badge")
            : PPAccessoryViewerL10n.text("accessory_view_private_seller")
    }

    private func ownerAccessibilitySummary(
        _ owner: PPAccessoryViewerOwner
    ) -> String {
        [
            sectionTitle,
            displayName(for: owner),
            ownerStatusText(owner),
            snapshot.location.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}

struct PPAccessoryDescriptionAccentLine: View {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(PPAccessoryPalette.brand)
            .frame(width: 4)
            .scaleEffect(y: phase, anchor: .top)
            .opacity(reduceMotion ? 1.0 : (0.4 + (phase * 0.6)))
            .onAppear {
                if reduceMotion {
                    phase = 1.0
                } else {
                    phase = 0.2
                    withAnimation(
                        .easeInOut(duration: 2.2)
                        .repeatForever(autoreverses: true)
                    ) {
                        phase = 1.0
                    }
                }
            }
    }
}

struct PPAccessoryEditorialDescription: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionTitle(
                PPAccessoryViewerL10n.text("Description"),
                symbol: "text.alignleft"
            )

            HStack(alignment: .top, spacing: 14) {
                PPAccessoryDescriptionAccentLine()

                Text(
                    text.isEmpty
                        ? PPAccessoryViewerL10n.text(
                            "accessory_view_no_description"
                        )
                        : text
                )
                .font(PPAccessoryTypography.body)
                .foregroundStyle(
                    text.isEmpty
                        ? PPAccessoryPalette.inkSecondary
                        : PPAccessoryPalette.ink
                )
                .lineSpacing(5)
                .lineLimit(expanded ? nil : 7)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !text.isEmpty && text.count > 280 {
                Button {
                    withAnimation(
                        .spring(response: 0.30, dampingFraction: 0.88)
                    ) {
                        expanded.toggle()
                    }
                } label: {
                    Label(
                        PPAccessoryViewerL10n.text(
                            expanded
                                ? "accessory_view_read_less"
                                : "accessory_view_read_more"
                        ),
                        systemImage: expanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(PPAccessoryTypography.calloutBold)
                    .foregroundStyle(PPAccessoryPalette.sea)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

@available(iOS 16.0, *)
struct PPAccessorySuggestionShore: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                PPAccessoryViewerL10n.text(
                    store.suggestionsFromSameProvider
                        ? "accessory_view_more_from_provider"
                        : "SimilarAaccess"
                ),
                symbol: "sparkles"
            )

            switch store.suggestionsPhase {
            case .idle, .loading:
                suggestionSkeleton
            case .loaded:
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(store.suggestions) { suggestion in
                            universalSuggestionCard(suggestion)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.bottom, 8)
                }
            case .empty:
                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_empty_suggestions"
                    )
                )
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .padding(.vertical, 12)
            case let .failed(message):
                HStack(spacing: 12) {
                    Text(message)
                        .font(PPAccessoryTypography.callout)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    Spacer()
                    Button(
                        PPAccessoryViewerL10n.text("Retry"),
                        action: store.retrySuggestions
                    )
                    .font(PPAccessoryTypography.calloutBold)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func universalSuggestionCard(
        _ suggestion: PPAccessoryViewerSuggestion
    ) -> some View {
        PPUniversalCardView(
            model: universalModel(for: suggestion),
            context: .market,
            layout: .vertical,
            discountStyle: .inline,
            palette: universalPalette,
            actions: PPUniversalCardActions(
                onTap: { _ in
                    store.openSuggestion(suggestion)
                }
            )
        )
        .frame(width: compact ? 172 : 195)
        .accessibilityElement(children: .combine)
    }

    private func universalModel(
        for suggestion: PPAccessoryViewerSuggestion
    ) -> PPUniversalCardModel {
        let accessory = suggestion.accessory
        let quantity = max(accessory.quantity, 0)
        let unavailable =
            PPAccessoryViewerLegacyBridge.isUnavailable(accessory)
        let availabilityTone: PPUniversalAvailability.Tone = {
            if unavailable || quantity <= 0 {
                return .unavailable
            }
            return quantity <= 5 ? .limited : .available
        }()

        return PPUniversalCardModel(
            id: suggestion.id,
            title: suggestion.title,
            subtitle: suggestion.subtitle,
            imageURL: suggestion.imageURL.flatMap(URL.init(string:)),
            placeholderImageName: "PawPlaceholderCell",
            placeholderSystemImage: "pawprint.fill",
            priceText: suggestion.price,
            currencyCode: "QAR",
            availability: PPUniversalAvailability(
                text: PPAccessoryViewerLegacyBridge.stockText(for: accessory),
                tone: availabilityTone
            ),
            isOwner: PPAccessoryViewerLegacyBridge.isOwn(accessory),
            isPubliclyVisible: !unavailable,
            stock: quantity,
            usesQuantityControl: false,
            prefersEdgeToEdgeMedia: true,
            preferredAspectRatio: 0.82
        )
    }

    private var universalPalette: PPUniversalCardPalette {
        PPUniversalCardPalette(
            primary: PPAccessoryPalette.ink,
            primaryDarker: PPAccessoryPalette.ink,
            primaryShiner: PPAccessoryPalette.inkSecondary,
            diffColor: PPAccessoryPalette.inkSecondary,
            accent: PPAccessoryPalette.ink,
            surface: PPAccessorySubviewBackground.quietFill,
            cardColor: PPAccessorySubviewBackground.quietFill,
            groupedSurface: PPAccessorySubviewBackground.clear,
            ink: PPAccessoryPalette.ink,
            secondaryInk: PPAccessoryPalette.inkSecondary,
            success: PPAccessoryPalette.success,
            warning: PPAccessoryPalette.warning,
            destructive: PPAccessoryPalette.error
        )
    }

    private var suggestionSkeleton: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                PPUniversalCardView(
                    model: PPUniversalCardModel(
                        id: "skeleton-\(index)",
                        title: "",
                        isSkeleton: true,
                        prefersEdgeToEdgeMedia: true,
                        preferredAspectRatio: 0.82
                    ),
                    context: .market,
                    layout: .vertical,
                    discountStyle: .inline,
                    palette: universalPalette
                )
                .frame(width: compact ? 172 : 195)
            }
        }
        .accessibilityLabel(
            PPAccessoryViewerL10n.text(
                "accessory_view_loading_suggestions"
            )
        )
    }
}

@available(iOS 16.0, *)
struct PPAccessoryPersistentDecisionBar: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot
    let compact: Bool
    let bottomInset: CGFloat

    @State private var addConfirmationPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if snapshot.showsCart {
                cartBar
            } else {
                contactBar
            }
        }
        .id(decisionStateIdentity)
        .transition(
            reduceMotion
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.992))
        )
        .padding(PPBottomDecisionBarGeometry.contentPadding)
        .background {
            PPAccessoryBottomFaceSurface()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(
            .horizontal,
            compact
                ? PPBottomDecisionBarGeometry.compactScreenInset
                : PPBottomDecisionBarGeometry.regularScreenInset
        )
        .padding(.top, PPSpace.sm)
        .padding(.bottom, 16)
        .ignoresSafeArea(.container, edges: .bottom)
        .animation(
            reduceMotion
                ? nil
                : .spring(
                    response: 0.34,
                    dampingFraction: 0.90,
                    blendDuration: 0.04
                ),
            value: decisionStateIdentity
        )
        .transaction { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
        .onChange(of: store.tideSuccessToken) { _ in
            animateAddConfirmation()
        }
    }

    private var cartBar: some View {
        VStack(spacing: PPSpace.md) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    stockIndicator
                    if canAdd {
                        quantityControl
                    }
                    animatedCartButton
                }
            } else {
                if compact {
                    HStack(
                        alignment: .center,
                        spacing: PPBottomDecisionBarGeometry.controlSpacing
                    ) {
                        stockIndicator
                        Spacer()
                        if canAdd {
                            quantityControl
                        }
                    }
                    animatedCartButton
                } else {
                    HStack(
                        alignment: .center,
                        spacing: PPBottomDecisionBarGeometry.controlSpacing
                    ) {
                        stockIndicator
                        Spacer()
                        if canAdd {
                            quantityControl
                        }
                        animatedCartButton
                            .frame(maxWidth: 340)
                    }
                }
            }
        }
    }

    private var animatedCartButton: some View {
        AnimatedAddToCartButton(
            cartCount: Binding(
                get: { store.cartItemsCount },
                set: { _ in }
            ),
            title: LocalizedStringKey(
                PPAccessoryViewerL10n.text("accessory_view_add_to_cart")
            ),
            addingTitle: LocalizedStringKey(
                PPAccessoryViewerL10n.text("accessory_view_adding_to_cart")
            ),
            addedTitle: LocalizedStringKey(
                PPAccessoryViewerL10n.text("AddedToCart")
            ),
            retryTitle: LocalizedStringKey(
                PPAccessoryViewerL10n.text("Retry")
            ),
            tint: PPAccessoryPalette.brand,
            itemSymbol: "shippingbox.fill",
            isEnabled: canAdd,
            onCartTap: {
                store.openCart()
            }
        ) {
            try await store.addToCartAsync()
        }
    }


    @ViewBuilder
    private var contactBar: some View {
        switch store.ownerPhase {
        case .idle, .loading:
            contactLoadingBar
        case .loaded:
            if store.owner != nil {
                contactReadyBar
            } else {
                contactRecoveryBar(
                    symbol: "person.crop.circle.badge.questionmark",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_contact_unavailable"
                    ),
                    message: PPAccessoryViewerL10n.text(
                        "accessory_view_owner_failed"
                    )
                )
            }
        case .empty:
            contactRecoveryBar(
                symbol: "person.crop.circle.badge.questionmark",
                title: PPAccessoryViewerL10n.text(
                    "accessory_view_contact_unavailable"
                ),
                message: PPAccessoryViewerL10n.text(
                    "accessory_view_owner_failed"
                )
            )
        case let .failed(message):
            contactRecoveryBar(
                symbol: "person.crop.circle.badge.exclamationmark",
                title: PPAccessoryViewerL10n.text(
                    "accessory_view_contact_unavailable"
                ),
                message: message
            )
        }
    }

    private var contactReadyBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    contactPriceSummary
                    VStack(spacing: PPSpace.sm) {
                        if !snapshot.isOwnItem, store.owner?.phoneNumber != nil {
                            callButton
                        }
                        chatButton
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(
                        spacing: PPBottomDecisionBarGeometry.controlSpacing
                    ) {
                        contactPriceSummary
                        Spacer(minLength: PPSpace.sm)
                        HStack(spacing: PPBottomDecisionBarGeometry.controlSpacing) {
                            if !snapshot.isOwnItem, store.owner?.phoneNumber != nil {
                                callButton
                            }
                            chatButton
                                .frame(minWidth: 132, maxWidth: 176)
                        }
                    }

                    VStack(alignment: .leading, spacing: PPSpace.md) {
                        contactPriceSummary
                        HStack(spacing: PPBottomDecisionBarGeometry.controlSpacing) {
                            if !snapshot.isOwnItem, store.owner?.phoneNumber != nil {
                                callButton.frame(maxWidth: .infinity)
                            }
                            chatButton.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var chatButton: some View {
        Button(action: store.chatWithOwner) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "message.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PPAccessorySubviewBackground.baseSurface)
                    .accessibilityHidden(true)
                Text(PPAccessoryViewerL10n.text("Chat"))
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, PPSpace.base)
            .frame(
                maxWidth: .infinity,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .background(
                PPAccessoryPalette.brand,
                in: RoundedRectangle(
                    cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .accessibilityLabel(PPAccessoryViewerL10n.text("Chat"))
    }

    private var callButton: some View {
        Button(action: store.callOwner) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 16, weight: .bold))
                    .accessibilityHidden(true)
                Text(PPAccessoryViewerL10n.text("Call"))
                    .font(PPAccessoryTypography.bodyBold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(PPAccessoryPalette.brand)
            .padding(.horizontal, PPSpace.sm)
            .frame(
                maxWidth: .infinity,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .background(
                PPAccessorySubviewBackground.baseSurface,
                in: RoundedRectangle(
                    cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .accessibilityLabel(PPAccessoryViewerL10n.text("Call"))
    }

    private var contactPriceSummary: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(snapshot.price)
                .font(PPAccessoryTypography.price)
                .bold()
                .fontWeight(.bold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_contact_for_used"
                )
            )
            .font(PPAccessoryTypography.caption)
            .foregroundStyle(PPAccessoryPalette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var contactLoadingBar: some View {
        HStack(spacing: PPSpace.md) {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                RoundedRectangle(cornerRadius: PPSpace.xs)
                    .fill(PPAccessoryPalette.ink.opacity(0.12))
                    .frame(width: 92, height: 17)
                RoundedRectangle(cornerRadius: PPSpace.xs)
                    .fill(PPAccessoryPalette.ink.opacity(0.08))
                    .frame(width: 150, height: 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                style: .continuous
            )
            .fill(PPAccessoryPalette.ink.opacity(0.10))
            .frame(
                width: 132,
                height: PPBottomDecisionBarGeometry.controlHeight
            )
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text(
                "accessory_view_loading_seller"
            )
        )
    }

    private func contactRecoveryBar(
        symbol: String,
        title: String,
        message: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    contactRecoveryLabel(
                        symbol: symbol,
                        title: title,
                        message: message
                    )
                    contactPrimaryButton(
                        title: PPAccessoryViewerL10n.text("Retry"),
                        symbol: "arrow.clockwise",
                        action: store.retryOwner
                    )
                }
            } else {
                HStack(spacing: PPSpace.md) {
                    contactRecoveryLabel(
                        symbol: symbol,
                        title: title,
                        message: message
                    )
                    contactPrimaryButton(
                        title: PPAccessoryViewerL10n.text("Retry"),
                        symbol: "arrow.clockwise",
                        action: store.retryOwner
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private func contactRecoveryLabel(
        symbol: String,
        title: String,
        message: String
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PPAccessoryPalette.warning)
                .frame(width: 42, height: 42)
                .background(
                    PPAccessoryPalette.warning.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(title)
                    .font(PPAccessoryTypography.calloutBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .lineLimit(
                        dynamicTypeSize.isAccessibilitySize ? nil : 2
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func contactPrimaryButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(PPAccessoryTypography.bodyBold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, PPSpace.base)
            .frame(
                maxWidth: .infinity,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .background(
                PPAccessoryPalette.brand,
                in: RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .accessibilityLabel(title)
    }

    private var stockIndicator: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(store.totalPriceText)
                .font(PPAccessoryTypography.price)
                .bold()
                .fontWeight(.bold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .contentTransition(.numericText())
                .priceHaloTransition(pulseToken: store.pricePulseToken)
                .id(store.totalPriceText)
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(
                            response: 0.28,
                            dampingFraction: 0.82,
                            blendDuration: 0.04
                        ),
                    value: store.totalPriceText
                )

            Text(canAdd ? remainingText : snapshot.stock)
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(
                    canAdd
                        ? PPAccessoryPalette.inkSecondary
                        : PPAccessoryPalette.error
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var quantityControl: some View {
        HStack(spacing: PPSpace.xs) {
            quantityButton(
                symbol: "minus",
                enabled: store.quantity > 1,
                action: store.decrementQuantity
            )
            Text(String(format: "%d", store.quantity))
                .font(PPAccessoryTypography.bodyBold)
                .monospacedDigit()
                .environment(\.locale, Locale(identifier: "en_US"))
                .foregroundStyle(PPAccessoryPalette.ink)
                .frame(minWidth: 34, alignment: .center)
                .accessibilityLabel(
                    String.localizedStringWithFormat(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_quantity_format"
                        ),
                        store.quantity
                    )
                )
            quantityButton(
                symbol: "plus",
                enabled: store.quantity < store.remainingStock,
                action: store.incrementQuantity
            )
        }
        .padding(PPSpace.xs)
        .background(
            PPAccessorySubviewBackground.quietFill,
            in: RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                style: .continuous
            )
        )
    }

    private func quantityButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PPAccessoryPalette.ink)
                .frame(width: 40, height: 40)
                .background(
                    PPAccessorySubviewBackground.baseSurface,
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(PPBottomDecisionPressStyle(pressedScale: 0.92))
        .disabled(!enabled || store.cartPhase == .processing)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text(
                symbol == "plus"
                    ? "accessory_view_increase_quantity"
                    : "accessory_view_decrease_quantity"
            )
        )
    }

    private var addButton: some View {
        Button(action: store.addToCart) {
            ZStack {
                RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
                .fill(addButtonFill)

                HStack(spacing: 8) {
                    buttonIcon
                    Text(buttonTitle)
                        .font(PPAccessoryTypography.bodyBold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.86)

                    if canAdd && store.cartPhase == .ready {
                        Text("•").accessibilityHidden(true)
                        Text(snapshot.price)
                            .font(PPAccessoryTypography.bodyBold)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .scaleEffect(addConfirmationPulse ? 1.012 : 1)
        .shadow(
            color: addButtonFill.opacity(
                addConfirmationPulse ? 0.28 : 0
            ),
            radius: addConfirmationPulse ? 14 : 0,
            y: 4
        )
        .buttonStyle(PPBottomDecisionPressStyle())
        .disabled(
            !canAdd ||
                store.cartPhase == .processing ||
                store.cartPhase == .success
        )
        .accessibilityLabel(
            String(
                format: PPAccessoryViewerL10n.text(
                    "accessory_view_add_accessibility_format"
                ),
                buttonTitle,
                snapshot.price
            )
        )
        .accessibilityValue(
            canAdd
                ? String.localizedStringWithFormat(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_cart_selection_format"
                    ),
                    store.quantity,
                    store.remainingStock
                )
                : snapshot.stock
        )
        .accessibilityHint(
            PPAccessoryViewerL10n.text(
                "accessory_view_add_to_cart_hint"
            )
        )
    }

    private var addButtonFill: Color {
        guard canAdd else {
            return PPAccessoryPalette.inkSecondary.opacity(0.34)
        }

        switch store.cartPhase {
        case .ready, .processing:
            return PPAccessoryPalette.brand
        case .success:
            return PPAccessoryPalette.success
        case .failed:
            return PPAccessoryPalette.error
        }
    }

    @ViewBuilder
    private var buttonIcon: some View {
        Group {
            switch store.cartPhase {
            case .processing:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
            case .failed:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
            case .ready:
                Image(
                    systemName:
                        canAdd
                        ? "bag.badge.plus"
                        : "xmark"
                )
                .font(.system(size: 17, weight: .bold))
            }
        }
        .frame(width: 22, height: 22)
        .id(String(describing: store.cartPhase))
        .transition(
            reduceMotion
                ? .opacity
                : .opacity.combined(with: .scale(scale: 0.82))
        )
        .accessibilityHidden(true)
    }

    private var buttonTitle: String {
        if snapshot.isUnavailable {
            return PPAccessoryViewerL10n.text("accessory_view_item_unavailable")
        }
        if store.remainingStock <= 0 {
            return PPAccessoryViewerL10n.text("Out of stock")
        }
        switch store.cartPhase {
        case .processing: return PPAccessoryViewerL10n.text("accessory_view_adding_to_cart")
        case .success: return PPAccessoryViewerL10n.text("AddedToCart")
        case .failed: return PPAccessoryViewerL10n.text("accessory_view_add_failed")
        case .ready: return PPAccessoryViewerL10n.text("accessory_view_add_to_cart")
        }
    }

    private var canAdd: Bool {
        !snapshot.isUnavailable && store.remainingStock > 0
    }

    private var remainingText: String {
        String.localizedStringWithFormat(
            PPAccessoryViewerL10n.text("accessory_view_remaining_format"),
            store.remainingStock
        )
    }

    private var cartButton: some View {
        Button(action: store.openCart) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .frame(
                        width:
                            PPBottomDecisionBarGeometry.utilityControlSize,
                        height:
                            PPBottomDecisionBarGeometry.utilityControlSize
                    )
                    .background(
                        PPAccessorySubviewBackground.quietFill,
                        in: RoundedRectangle(
                            cornerRadius:
                                PPBottomDecisionBarGeometry.controlRadius,
                            style: .continuous
                        )
                    )

                if store.cartItemsCount > 0 {
                    Text("\(store.cartItemsCount)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(PPAccessoryPalette.brandDarker, in: Capsule())
                        .offset(x: 5, y: -5)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(PPBottomDecisionPressStyle(pressedScale: 0.94))
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_open_cart")
        )
        .accessibilityValue(
            String.localizedStringWithFormat(
                PPAccessoryViewerL10n.text(
                    "accessory_view_cart_count_format"
                ),
                store.cartItemsCount
            )
        )
    }

    private func animateAddConfirmation() {
        addConfirmationPulse = false
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
            addConfirmationPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.16)) {
                addConfirmationPulse = false
            }
        }
    }

    private var decisionStateIdentity: String {
        if snapshot.showsCart {
            return "cart-\(String(describing: store.cartPhase))-\(canAdd)"
        }
        return "contact-\(String(describing: store.ownerPhase))"
    }
}

struct PPAccessoryPersistentDecisionBarLoading: View {
    let compact: Bool
    let bottomInset: CGFloat

    var body: some View {
        Group {
            if compact {
                VStack(spacing: PPSpace.md) {
                    HStack {
                        summarySkeleton
                        Spacer()
                        quantitySkeleton
                    }
                    HStack(
                        spacing: PPBottomDecisionBarGeometry.controlSpacing
                    ) {
                        actionSkeleton
                        utilitySkeleton
                    }
                }
            } else {
                HStack(
                    spacing: PPBottomDecisionBarGeometry.controlSpacing
                ) {
                    summarySkeleton
                    Spacer()
                    quantitySkeleton
                    actionSkeleton.frame(maxWidth: 340)
                    utilitySkeleton
                }
            }
        }
        .padding(PPBottomDecisionBarGeometry.contentPadding)
        .background {
            PPAccessoryBottomFaceSurface()
        }
        .padding(
            .horizontal,
            compact
                ? PPBottomDecisionBarGeometry.compactScreenInset
                : PPBottomDecisionBarGeometry.regularScreenInset
        )
        .padding(.top, PPSpace.sm)
        .padding(.bottom, 16)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text(
                "accessory_view_loading_cart_actions"
            )
        )
    }

    private var summarySkeleton: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            RoundedRectangle(cornerRadius: PPSpace.xs)
                .fill(PPAccessoryPalette.ink.opacity(0.12))
                .frame(width: 94, height: 18)
            RoundedRectangle(cornerRadius: PPSpace.xs)
                .fill(PPAccessoryPalette.ink.opacity(0.08))
                .frame(width: 112, height: 10)
        }
    }

    private var quantitySkeleton: some View {
        RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )
        .fill(PPAccessoryPalette.ink.opacity(0.08))
        .frame(width: 126, height: 48)
    }

    private var actionSkeleton: some View {
        RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )
        .fill(PPAccessoryPalette.ink.opacity(0.11))
        .frame(
            maxWidth: .infinity,
            minHeight: PPBottomDecisionBarGeometry.controlHeight
        )
    }

    private var utilitySkeleton: some View {
        RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )
        .fill(PPAccessoryPalette.ink.opacity(0.09))
        .frame(
            width: PPBottomDecisionBarGeometry.utilityControlSize,
            height: PPBottomDecisionBarGeometry.utilityControlSize
        )
    }
}

struct PPAccessoryViewerLoadingState: View {
    let topInset: CGFloat
    let compact: Bool
    let bottomInset: CGFloat

    var body: some View {
        ScrollView {
            VStack(spacing: compact ? 22 : 30) {
                heroSkeleton
                    .padding(.horizontal, compact ? 16 : 34)
                    .padding(.top, topInset + 70)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Capsule()
                            .fill(PPAccessoryPalette.ink.opacity(0.08))
                            .frame(width: 92, height: 32)
                        Capsule()
                            .fill(PPAccessoryPalette.ink.opacity(0.07))
                            .frame(width: 118, height: 24)
                        Spacer(minLength: 0)
                    }

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PPAccessoryPalette.ink.opacity(0.09))
                        .frame(height: 42)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PPAccessoryPalette.ink.opacity(0.07))
                        .frame(width: 190, height: 30)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(PPAccessoryPalette.ink.opacity(0.06))
                        .frame(height: compact ? 88 : 70)
                }
                .padding(24)
                .ppAccessorySubviewBackground(
                    PPAccessorySubviewBackground.quietFill,
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
                .padding(.horizontal, compact ? 16 : 34)
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .padding(
                .bottom,
                (compact ? 154 : 96) + bottomInset + PPSpace.xl
            )
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_loading_product")
        )
        .overlay(alignment: .bottom) {
            PPAccessoryPersistentDecisionBarLoading(
                compact: compact,
                bottomInset: bottomInset
            )
        }
    }

    private var heroSkeleton: some View {
        RoundedRectangle(
            cornerRadius: compact ? 34 : 42,
            style: .continuous
        )
        .fill(PPAccessorySubviewBackground.mediaFill)
        .frame(height: compact ? 340 : 440)
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(PPAccessorySubviewBackground.chromeFill)
                .frame(width: compact ? 132 : 180, height: 48)
                .padding(.bottom, compact ? 18 : 24)
        }
    }
}

struct PPAccessoryViewerErrorState: View {
    let message: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        ZStack {
            PPAccessoryBeachCanvas()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(PPAccessorySubviewBackground.dangerFill)
                        .frame(width: 112, height: 112)
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(PPAccessoryPalette.error)
                }
                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_unavailable_title"
                    )
                )
                .font(PPAccessoryTypography.title)
                .foregroundStyle(PPAccessoryPalette.ink)
                .multilineTextAlignment(.center)
                Text(message)
                    .font(PPAccessoryTypography.body)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: close) {
                        Text(PPAccessoryViewerL10n.text("Back"))
                            .font(PPAccessoryTypography.bodyBold)
                            .foregroundStyle(PPAccessoryPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .ppAccessorySubviewBackground(
                                PPAccessorySubviewBackground.quietFill,
                                in: Capsule(),
                                stroke: PPAccessorySubviewBackground.controlStroke
                            )
                    }
                    Button(action: retry) {
                        Text(PPAccessoryViewerL10n.text("Retry"))
                            .font(PPAccessoryTypography.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .ppAccessorySubviewBackground(
                                PPAccessoryPalette.brand,
                                in: Capsule(),
                                stroke: nil
                            )
                    }
                }
            }
            .padding(26)
            .frame(maxWidth: 520)
        }
        .padding(24)
    }
}

@ViewBuilder
func sectionTitle(
    _ title: String,
    symbol: String
) -> some View {
    HStack(spacing: 10) {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(PPAccessoryPalette.accent)
        Text(title)
            .font(PPAccessoryTypography.headline)
            .foregroundStyle(PPAccessoryPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 0)
    }
}

struct PPAccessoryPriceHaloView: ViewModifier {
    let pulseToken: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var haloScale: CGFloat = 1.0
    @State private var haloOpacity: Double = 0.0
    @State private var haloBlur: CGFloat = 0.0

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    PPAccessoryPalette.brand.opacity(0.38),
                                    PPAccessoryPalette.accent.opacity(0.30),
                                    PPAccessoryPalette.brand.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(haloScale)
                        .opacity(haloOpacity)
                        .blur(radius: haloBlur)
                }
                .padding(-8)
            )
            .onChange(of: pulseToken) { value in
                triggerHaloPulse(token: value)
            }
    }

    private func triggerHaloPulse(token: Int) {
        guard token > 0 else { return }
        if reduceMotion {
            haloScale = 1.0
            haloOpacity = 0.45
            withAnimation(.easeInOut(duration: 0.28)) {
                haloOpacity = 0.0
            }
            return
        }

        haloScale = 0.88
        haloOpacity = 0.80
        haloBlur = 3.0
        withAnimation(.easeOut(duration: 0.38)) {
            haloScale = 1.30
            haloOpacity = 0.0
            haloBlur = 12.0
        }
    }
}

extension View {
    func priceHaloTransition(pulseToken: Int) -> some View {
        modifier(PPAccessoryPriceHaloView(pulseToken: pulseToken))
    }
}
