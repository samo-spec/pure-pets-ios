import Foundation
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
    let isCommerce: Bool

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let topStroke = colorSchemeContrast == .increased
            ? PPAccessorySubviewBackground.chromeStroke
            : PPAccessorySubviewBackground.faintStroke

        surface
        .overlay {
            if isCommerce {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            PPAccessoryPalette.brand.opacity(
                                colorSchemeContrast == .increased ? 0.46 : 0.20
                            ),
                            topStroke.opacity(0.76),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
            } else {
                shape.stroke(topStroke.opacity(0.78), lineWidth: 0.8)
            }
        }
        .shadow(
            color: Color.black.opacity(
                colorScheme == .dark
                    ? (isCommerce ? 0.20 : 0.18)
                    : (isCommerce ? 0.09 : 0.08)
            ),
            radius: isCommerce ? 16 : 18,
            y: isCommerce ? 7 : 8
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isCommerce
                ? PPCorner.hero
                : PPBottomDecisionBarGeometry.surfaceRadius,
            style: .continuous
        )
    }

    @ViewBuilder
    private var surface: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), isCommerce, !reduceTransparency {
            shape
                .fill(Color.clear)
                .glassEffect(
                    .regular.tint(
                        PPAccessoryPalette.brand.opacity(
                            colorScheme == .dark ? 0.10 : 0.055
                        )
                    ),
                    in: shape
                )
                .overlay {
                    semanticCommerceTint
                }
        } else {
            fallbackSurface
        }
#else
        fallbackSurface
#endif
    }

    private var fallbackSurface: some View {
        ZStack {
            if reduceTransparency {
                shape.fill(
                    colorScheme == .dark
                        ? Color.ppElevatedSurface
                        : Color.ppSurface
                )
            } else if isCommerce {
                shape.fill(.regularMaterial)
            } else {
                shape.fill(.ultraThinMaterial)
            }

            shape.fill(
                isCommerce
                    ? Color.ppElevatedSurface.opacity(
                        reduceTransparency
                            ? 0
                            : (colorScheme == .dark ? 0.42 : 0.30)
                    )
                    : (colorScheme == .dark
                        ? Color.ppElevatedSurface.opacity(
                            reduceTransparency ? 0 : 0.46
                        )
                        : Color.ppForeground.opacity(
                            reduceTransparency ? 0 : 0.58
                        ))
            )

            if isCommerce {
                semanticCommerceTint
            }
        }
    }

    private var semanticCommerceTint: some View {
        shape.fill(
            LinearGradient(
                colors: [
                    PPAccessoryPalette.brand.opacity(
                        colorScheme == .dark ? 0.10 : 0.055
                    ),
                    Color.clear,
                    Color.ppElevatedSurface.opacity(
                        colorScheme == .dark ? 0.06 : 0.20
                    ),
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
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
        size: 30,
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
    static let subheadline = Font.custom(
        "Beiruti-Regular",
        size: 16,
        relativeTo: .subheadline
    )
    static let subheadlineBold = Font.custom(
        "Beiruti-Bold",
        size: 16,
        relativeTo: .subheadline
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
    static let caption2 = Font.custom(
        "Beiruti-Regular",
        size: 11,
        relativeTo: .caption2
    )
}

struct PPAccessoryPressStyle: ButtonStyle {
    let pressedScale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(pressedScale: CGFloat = 0.965) {
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion
                    ? pressedScale
                    : 1
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.16),
                value: configuration.isPressed
            )
    }
}

/// Accessory viewer's atmospheric canvas.
///
/// Overrides the shared `WorldGlassBackground` dominant tint with the adoption
/// quick-action accent (`ppQuickActionAdoption`) so the viewer's ambient glow
/// reads in the same warm terracotta-coral as the adoption surfaces it links to.
/// Companion environmental hues (teal, champagne, mist) are intentionally left
/// to the component defaults to preserve the layered, living-canvas depth.
struct PPHero: View {
    var body: some View {
        WorldGlassBackground(tint: .ppQuickActionAdoption)
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

            ZStack {
                if showsSmartTitle, let snapshot {
                    PPAccessoryViewerNavBarSmartPill(snapshot: snapshot)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(
                                    with: .scale(scale: 0.95).combined(with: .offset(y: 4))
                                )
                        )
                } else if let snapshot {
                    defaultTitleView(snapshot: snapshot)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(
                                    with: .scale(scale: 0.95).combined(with: .offset(y: -4))
                                )
                        )
                } else {
                    Spacer(minLength: PPSpace.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .layoutPriority(1)

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
    private func defaultTitleView(snapshot: PPAccessoryViewerSnapshot) -> some View {
        VStack(spacing: 1) {
            Text(firstRowText(snapshot: snapshot))
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            let subText = secondRowText(snapshot: snapshot)
            if !subText.isEmpty {
                Text(subText)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func firstRowText(snapshot: PPAccessoryViewerSnapshot) -> String {
        let cat = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            return cat
        }
        let type = snapshot.type.trimmingCharacters(in: .whitespacesAndNewlines)
        if !type.isEmpty {
            return type
        }
        return PPAccessoryViewerL10n.text("accessory_view_section_fallback")
    }

    private func secondRowText(snapshot: PPAccessoryViewerSnapshot) -> String {
        let accCategory = snapshot.accessoryCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let subCategory = snapshot.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !accCategory.isEmpty {
            parts.append(accCategory)
        }
        if !subCategory.isEmpty && subCategory != accCategory {
            parts.append(subCategory)
        }

        if parts.isEmpty {
            let cat = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cat.isEmpty {
                parts.append(cat)
            }
        }

        return parts.joined(separator: " · ")
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
                accessibilityLabel: displayTitle,
                cacheKey: firstMedia.id,
                displaySize: CGSize(width: 36, height: 36)
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
        Text(snapshot.price)
            .font(
                .custom(
                    "Beiruti-Bold",
                    size: 17,
                    relativeTo: .subheadline
                )
            )
            .fontWeight(.heavy)
            .foregroundStyle(Color.ppPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 6)
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
        VStack(spacing: showsGalleryRail ? PPSpace.sm : 0) {
            ZStack {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(galleryShape)

            if showsGalleryRail {
                galleryRail
                    .padding(.horizontal, compact ? PPSpace.sm : PPSpace.md)
                    .padding(.bottom, compact ? PPSpace.sm : PPSpace.md)
            }
        }
        .frame(height: height)
        .background(PPAccessorySubviewBackground.baseSurface)
        .clipShape(galleryShape)
        .overlay {
            galleryShape
                .stroke(PPAccessoryPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onChange(of: selection) { _ in
            PPAccessoryViewerLegacyBridge.playSelectionFeedback()
        }
        .onChange(of: snapshot.media.map(\.id)) { _ in
            selection = min(
                max(selection, 0),
                max(snapshot.media.count - 1, 0)
            )
        }
        // A colour switch replaces the product, so the gallery must return to that
        // colour's first image. Keyed on the document id, not on the media list, because
        // the clamp above must keep handling a same-product media edit without yanking
        // the customer off the image they were looking at.
        .onChange(of: snapshot.accessory.accessoryID) { _ in
            selection = 0
        }
        .fullScreenCover(isPresented: $showsMediaViewer) {
            PPMediaViewer(
                items: PPMediaItem.from(accessoryMedia: snapshot.media),
                selection: $selection,
                title: displayTitle,
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
                    contentMode: .fit,
                    accessibilityLabel: mediaLabel(index),
                    cacheKey: item.id
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
        return PPAccessoryViewerL10n.formatted(
            "accessory_view_media_count_format",
            PPAccessoryViewerL10n.integer(selection + 1),
            PPAccessoryViewerL10n.integer(snapshot.media.count)
        )
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
                            accessibilityLabel: mediaLabel(index),
                            cacheKey: item.id
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
                Text(
                    "+\(PPAccessoryViewerL10n.integer(snapshot.media.count - 6))"
                )
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
        PPAccessoryViewerL10n.formatted(
            "accessory_view_media_accessibility_format",
            displayTitle,
            PPAccessoryViewerL10n.integer(index + 1),
            PPAccessoryViewerL10n.integer(snapshot.media.count)
        )
    }

    private var displayTitle: String {
        let title = snapshot.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return title.isEmpty
            ? PPAccessoryViewerL10n.text(
                "accessory_view_product_fallback"
            )
            : title
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
            VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                productTitleRow
                    .padding(.trailing, favoriteButtonFootprint)
                priceRow
                    .padding(.trailing, favoriteButtonFootprint + PPSpace.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, compact ? 6 : 10)
        .padding(.bottom, compact ? 2 : 6)
        .overlay(alignment: .topTrailing) {
            favoriteButton
        }
        .accessibilityElement(children: .contain)
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
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            currentPrice

            if snapshot.hasDiscount {
                discountSummary
            }

            Spacer(minLength: PPSpace.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(2)
    }

    private var currentPrice: some View {
        Text(snapshot.price)
            .font(PPAccessoryTypography.price)
            .bold()
            .fontWeight(.heavy)
            .foregroundStyle(Color.ppPrimary)
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
        PPAccessoryViewerL10n.formatted(
            "accessory_view_discount_format",
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

}

@available(iOS 16.0, *)
struct PPAccessoryPetFitCard: View {
    let snapshot: PPAccessoryViewerSnapshot

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            petFitHeader

            if !visibleFacts.isEmpty {
                fitFacts
            }

            dataGapNote
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppAccessorySubviewBackground(
            petFitCardFill,
            in: RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            ),
            stroke: colorSchemeContrast == .increased
                ? PPAccessoryPalette.brand.opacity(0.72)
                : PPAccessoryPalette.brand.opacity(0.24),
            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
        )
        .overlay(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(PPAccessoryPalette.brand)
                .frame(width: 4)
                .padding(.vertical, PPSpace.lg)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.24),
            value: isExpanded
        )
    }

    private var fitMark: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
            .fill(PPAccessoryPalette.brand.opacity(0.11))

            Image("pawprint4")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(PPAccessoryPalette.brand)
                .accessibilityHidden(true)
        }
        .frame(width: 48, height: 48)
    }

    @ViewBuilder
    private var petFitHeader: some View {
        if canExpand {
            Button(action: toggleExpansion) {
                petFitHeaderContent(showsChevron: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.99))
            .accessibilityLabel(
                PPAccessoryViewerL10n.text(
                    "accessory_view_pet_fit_title"
                )
            )
            .accessibilityValue(
                PPAccessoryViewerL10n.text(
                    isExpanded
                        ? "accessory_view_expanded"
                        : "accessory_view_collapsed"
                )
            )
            .accessibilityHint(
                PPAccessoryViewerL10n.text(
                    "accessory_view_pet_fit_hint"
                )
            )
        } else {
            petFitHeaderContent(showsChevron: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func petFitHeaderContent(showsChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            fitMark

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_pet_fit_title"
                    )
                )
                .font(PPAccessoryTypography.headline)
                .foregroundStyle(PPAccessoryPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_pet_fit_subtitle"
                    )
                )
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: PPSpace.sm)

            if showsChevron {
                Image(
                    systemName: isExpanded
                        ? "chevron.up"
                        : "chevron.down"
                )
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PPAccessoryPalette.brand)
                .frame(width: 44, height: 44)
                .background(
                    PPAccessoryPalette.brand.opacity(0.09),
                    in: Circle()
                )
                .accessibilityHidden(true)
            }
        }
    }

    private var petFitCardFill: Color {
        colorScheme == .dark
            ? Color.ppElevatedSurface.opacity(0.92)
            : Color.ppForeground.opacity(0.92)
    }

    private var petFitFactFill: Color {
        colorScheme == .dark
            ? Color.ppSecondarySurface.opacity(0.76)
            : Color.ppSoftRose.opacity(0.52)
    }

    private var petFitFactStroke: Color {
        colorSchemeContrast == .increased
            ? PPAccessoryPalette.brand.opacity(0.55)
            : PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.20 : 0.16)
    }

    @ViewBuilder
    private var fitFacts: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                ForEach(visibleFacts) { fact in
                    factRow(fact)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: PPSpace.sm) {
                    ForEach(visibleFacts) { fact in
                        factTile(fact)
                    }
                }

                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    ForEach(visibleFacts) { fact in
                        factRow(fact)
                    }
                }
            }
        }
    }

    private func factTile(
        _ fact: PPAccessoryViewerDetailItem
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(alignment: .center, spacing: 4) {
                if fact.symbol == "pawprint.fill" || fact.symbol == "pawprint4" {
                    Image("pawprint4")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(PPAccessoryPalette.brand)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: fact.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PPAccessoryPalette.brand)
                        .accessibilityHidden(true)
                }

                Text(fact.title)
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
            }

            Text(fact.value)
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(isExpanded ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PPSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ppAccessorySubviewBackground(
            petFitFactFill,
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            ),
            stroke: petFitFactStroke,
            lineWidth: colorSchemeContrast == .increased ? 1.2 : 0.8
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.title): \(fact.value)")
    }

    private func factRow(
        _ fact: PPAccessoryViewerDetailItem
    ) -> some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Group {
                if fact.symbol == "pawprint.fill" || fact.symbol == "pawprint4" {
                    Image("pawprint4")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(PPAccessoryPalette.brand)
                } else {
                    Image(systemName: fact.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PPAccessoryPalette.brand)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                PPAccessoryPalette.brand.opacity(0.09),
                in: RoundedRectangle(
                    cornerRadius: PPSpace.sm,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(fact.title)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                Text(fact.value)
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(PPSpace.sm)
        .ppAccessorySubviewBackground(
            petFitFactFill,
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            ),
            stroke: petFitFactStroke,
            lineWidth: colorSchemeContrast == .increased ? 1.2 : 0.8
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.title): \(fact.value)")
    }

    private var dataGapNote: some View {
        HStack(alignment: .top, spacing: PPSpace.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .accessibilityHidden(true)

            Text(snapshot.petFitDataGapText)
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PPSpace.sm)
        .ppAccessorySubviewBackground(
            colorScheme == .dark
                ? Color.ppBackground.opacity(0.38)
                : Color.ppBackground.opacity(0.64),
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            ),
            stroke: PPAccessorySubviewBackground.faintStroke.opacity(0.72),
            lineWidth: colorSchemeContrast == .increased ? 1.2 : 0.8
        )
        .accessibilityElement(children: .combine)
    }

    private var visibleFacts: [PPAccessoryViewerDetailItem] {
        let limit = isExpanded ? filteredPetFitDetails.count : collapsedFactLimit
        return Array(filteredPetFitDetails.prefix(limit))
    }

    private var filteredPetFitDetails: [PPAccessoryViewerDetailItem] {
        snapshot.petFitDetails.filter { $0.id != "fit-product-group" }
    }

    private var collapsedFactLimit: Int {
        3
    }

    private var canExpand: Bool {
        filteredPetFitDetails.count > collapsedFactLimit
    }

    private func toggleExpansion() {
        guard canExpand else { return }
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.24)) {
                isExpanded.toggle()
            }
        }
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
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionTitle(
                PPAccessoryViewerL10n.text(
                    "accessory_view_fulfillment_trust_title"
                ),
                symbol: "checkmark.shield.fill"
            )

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
        }
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

        switch store.livePhase {
        case .current:
            break
        case .refreshing:
            result.append(
                PPAccessoryReadinessFact(
                    id: "live-refreshing",
                    symbol: "arrow.clockwise",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_inventory_status"
                    ),
                    value: PPAccessoryViewerL10n.text(
                        "accessory_view_refreshing"
                    ),
                    color: PPAccessoryPalette.sea
                )
            )
        case .stale:
            result.append(
                PPAccessoryReadinessFact(
                    id: "live-stale",
                    symbol: "wifi.exclamationmark",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_inventory_status"
                    ),
                    value: PPAccessoryViewerL10n.text(
                        "accessory_view_data_needs_refresh"
                    ),
                    color: PPAccessoryPalette.warning
                )
            )
        case .deleted:
            result.append(
                PPAccessoryReadinessFact(
                    id: "live-removed",
                    symbol: "xmark.octagon.fill",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_inventory_status"
                    ),
                    value: PPAccessoryViewerL10n.text(
                        "accessory_view_item_unavailable"
                    ),
                    color: PPAccessoryPalette.error
                )
            )
        }

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

        if let owner = store.owner, owner.isVerified {
            result.append(
                PPAccessoryReadinessFact(
                    id: "seller-verification",
                    symbol: "checkmark.seal.fill",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_seller_title"
                    ),
                    value: PPAccessoryViewerL10n.text(
                        "accessory_view_verified_seller"
                    ),
                    color: PPAccessoryPalette.success
                )
            )
        }

        /* TEMPORARY: Hidden provider rate view in seller card
        if let owner = store.owner, owner.hasRating {
            result.append(
                PPAccessoryReadinessFact(
                    id: "seller-rating",
                    symbol: "star.fill",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_seller_rating"
                    ),
                    value: PPAccessoryViewerL10n.formatted(
                        "accessory_view_seller_rating_format",
                        PPAccessoryViewerL10n.decimal(owner.ratingValue),
                        PPAccessoryViewerL10n.integer(owner.reviewCount)
                    ),
                    color: PPAccessoryPalette.warning
                )
            )
        }
        */

        if !snapshot.location.isEmpty {
            result.append(
                PPAccessoryReadinessFact(
                    id: "fulfillment-location",
                    symbol: "mappin.and.ellipse",
                    title: PPAccessoryViewerL10n.text("Location"),
                    value: snapshot.location,
                    color: PPAccessoryPalette.sea
                )
            )
        }

        if !snapshot.expiryDate.isEmpty &&
            (snapshot.isFood || snapshot.isMedicine) {
            result.append(
                PPAccessoryReadinessFact(
                    id: "fulfillment-expiry",
                    symbol: "calendar.badge.clock",
                    title: PPAccessoryViewerL10n.text("ExpiryDateTitle"),
                    value: snapshot.expiryDate,
                    color: PPAccessoryPalette.brandDarker
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
        switch self {
        case .sea:   return PPAccessoryPalette.accent
        case .sun:   return PPAccessoryPalette.warning
        case .coral: return PPAccessoryPalette.brand
        case .palm:  return PPAccessoryPalette.success
        case .ink:   return PPAccessoryPalette.inkSecondary
        }
    }
}

@available(iOS 16.0, *)
struct PPAccessoryDetailRail: View {
    let details: [PPAccessoryViewerDetailItem]
    let compactColumns: Bool
    var stockQuantity: Int? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var selectedDetailId: String? = nil
    @State private var appeared = false

    private let interCardSpacing: CGFloat = PPSpace.sm
    private let railInset: CGFloat = PPSpace.base
    private let fillColumnThreshold = 3

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionHeader
                .padding(.top, compactColumns ? PPSpace.md : PPSpace.lg)

            if railDetails.isEmpty {
                emptyState
            } else if dynamicTypeSize.isAccessibilitySize {
                accessibilityList
            } else if railDetails.count <= fillColumnThreshold {
                fillWidthRail
            } else {
                scrollingRail
            }

            if let selectedDetail = railDetails.first(where: { $0.id == selectedDetailId }) {
                specInsightBanner(selectedDetail)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                                removal: .opacity
                            )
                    )
            } else if !railDetails.isEmpty {
                explorationHint
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82), value: selectedDetailId)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Data

    private var railDetails: [PPAccessoryViewerDetailItem] {
        details.filter { detail in
            detail.id != "accessory-category" && detail.id != "listed"
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: PPSpace.sm + 2) {
            // Illuminated Spec Emblem
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.10 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.35 : 0.18),
                                lineWidth: 0.75
                            )
                    }

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.brand)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(PPAccessoryViewerL10n.text("accessory_view_details_title"))
                    .font(PPAccessoryTypography.headline)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .accessibilityAddTraits(.isHeader)

                Text(PPAccessoryViewerL10n.text("accessory_view_details_subtitle"))
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
            }

            Spacer(minLength: PPSpace.sm)

            // Certified Trust Pill
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.success)

                Text(PPAccessoryViewerL10n.text("accessory_view_details_verified_pill"))
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        PPAccessoryPalette.success.opacity(colorScheme == .dark ? 0.18 : 0.08)
                    )
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        PPAccessoryPalette.success.opacity(colorScheme == .dark ? 0.32 : 0.18),
                        lineWidth: 0.75
                    )
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Fill-Width Layout

    private var fillWidthRail: some View {
        HStack(alignment: .top, spacing: interCardSpacing) {
            ForEach(Array(railDetails.enumerated()), id: \.element.id) { index, detail in
                gemCard(detail, index: index, fillsWidth: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Scrolling Rail

    @ViewBuilder
    private var scrollingRail: some View {
        if #available(iOS 17.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: interCardSpacing) {
                    railCardList(fillsWidth: false)
                }
                .padding(.horizontal, railInset)
                .padding(.vertical, 4)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: interCardSpacing) {
                    railCardList(fillsWidth: false)
                }
                .padding(.horizontal, railInset)
                .padding(.vertical, 4)
            }
        }
    }

    private func railCardList(fillsWidth: Bool) -> some View {
        ForEach(Array(railDetails.enumerated()), id: \.element.id) { index, detail in
            gemCard(detail, index: index, fillsWidth: fillsWidth)
        }
    }

    // MARK: - Exploration Hint

    private var explorationHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PPAccessoryPalette.inkSecondary.opacity(0.65))

            Text(PPAccessoryViewerL10n.text("accessory_view_details_tap_hint"))
                .font(PPAccessoryTypography.caption2)
                .foregroundStyle(PPAccessoryPalette.inkSecondary.opacity(0.65))

            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }

    // MARK: - Interactive Spec Insight Banner

    private func specInsightBanner(_ detail: PPAccessoryViewerDetailItem) -> some View {
        let accent = detail.tone.accessoryAccentColor
        let isDark = colorScheme == .dark

        return HStack(alignment: .top, spacing: PPSpace.sm + 2) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isDark ? 0.24 : 0.12))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle()
                            .strokeBorder(accent.opacity(isDark ? 0.40 : 0.22), lineWidth: 0.75)
                    }

                detailIconView(detail, accent: accent, size: 14)
            }
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(insightTitle(for: detail))
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insightDescription(for: detail))
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: PPSpace.xs)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) {
                    selectedDetailId = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(PPAccessoryPalette.ink.opacity(isDark ? 0.15 : 0.06))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(PPAccessoryViewerL10n.text("close"))
        }
        .padding(PPSpace.md)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .fill(
                    accent.opacity(isDark ? 0.12 : 0.05)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(
                    accent.opacity(isDark ? 0.32 : 0.18),
                    lineWidth: 0.8
                )
        }
    }

    // MARK: - Detail Gem Card

    private func gemCard(
        _ detail: PPAccessoryViewerDetailItem,
        index: Int,
        fillsWidth: Bool
    ) -> some View {
        let isSelected = selectedDetailId == detail.id
        let accent = detail.tone.accessoryAccentColor
        let isDark = colorScheme == .dark

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                if selectedDetailId == detail.id {
                    selectedDetailId = nil
                } else {
                    selectedDetailId = detail.id
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top row: Gem Icon + Semantic Status Beacon
                HStack(alignment: .center, spacing: PPSpace.xs) {
                    // Sculpted Gem Icon Container
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(isDark ? 0.22 : 0.12),
                                        accent.opacity(isDark ? 0.12 : 0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(accent.opacity(isDark ? 0.35 : 0.20), lineWidth: 0.65)
                            }

                        detailIconView(detail, accent: accent, size: 15)
                    }

                    Spacer(minLength: 2)

                    // Semantic Status Beacon
                    specStatusBeacon(detail: detail, accent: accent)
                }

                Spacer(minLength: PPSpace.sm)

                // Value and Title Stack
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.value)
                        .font(PPAccessoryTypography.headline)
                        .foregroundStyle(PPAccessoryPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(detail.title)
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: PPSpace.sm)

                // Bottom Intelligent Indicator
                specBottomDescriptor(detail: detail, accent: accent)
            }
            .padding(.horizontal, PPSpace.sm + 2)
            .padding(.vertical, PPSpace.md)
            .frame(
                width: fillsWidth ? nil : 124,
                height: 122,
                alignment: .topLeading
            )
            .background(
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .fill(
                        isSelected
                            ? (isDark ? Color.ppElevatedSurface : Color.ppForeground)
                            : (isDark ? Color.ppElevatedSurface.opacity(0.85) : Color.ppForeground)
                    )
            )
            .overlay {
                // Outer stroke
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? accent.opacity(isDark ? 0.90 : 0.75)
                            : (colorSchemeContrast == .increased
                                ? accent.opacity(0.40)
                                : accent.opacity(isDark ? 0.22 : 0.12)),
                        lineWidth: isSelected ? 1.5 : (colorSchemeContrast == .increased ? 1.0 : 0.65)
                    )
            }
            .overlay(alignment: .top) {
                // Subtle top specular highlight filament
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                accent.opacity(isSelected ? 0.70 : 0.35),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                    .padding(0.5)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: isSelected
                    ? accent.opacity(isDark ? 0.25 : 0.12)
                    : Color.black.opacity(isDark ? 0.16 : 0.04),
                radius: isSelected ? 10 : 6,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.96))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(detail.title): \(detail.value)")
        .accessibilityHint(PPAccessoryViewerL10n.text("accessory_view_details_tap_hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.48, dampingFraction: 0.84)
                    .delay(Double(index) * 0.045),
            value: appeared
        )
    }

    // MARK: - Semantic Status Beacon

    @ViewBuilder
    private func specStatusBeacon(detail: PPAccessoryViewerDetailItem, accent: Color) -> some View {
        let isDark = colorScheme == .dark
        if detail.id == "condition" {
            HStack(spacing: 3) {
                Circle()
                    .fill(PPAccessoryPalette.success)
                    .frame(width: 5, height: 5)

                Text(PPAccessoryViewerL10n.text("accessory_view_spec_pristine_tag"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.success)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule(style: .continuous)
                    .fill(PPAccessoryPalette.success.opacity(isDark ? 0.18 : 0.09))
            )
        } else if detail.id == "remain-quantity" {
            let qty = resolvedQuantity(for: detail)
            let isLowStock = qty <= 5

            HStack(spacing: 3) {
                Circle()
                    .fill(isLowStock ? PPAccessoryPalette.warning : PPAccessoryPalette.success)
                    .frame(width: 5, height: 5)

                Text(PPAccessoryViewerL10n.text(isLowStock ? "accessory_view_spec_low_stock_tag" : "accessory_view_spec_in_stock_tag"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isLowStock ? PPAccessoryPalette.warning : PPAccessoryPalette.success)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule(style: .continuous)
                    .fill((isLowStock ? PPAccessoryPalette.warning : PPAccessoryPalette.success).opacity(isDark ? 0.18 : 0.09))
            )
        } else if detail.id == "accessory-kind" || detail.id == "subcategory" {
            Text(PPAccessoryViewerL10n.text("accessory_view_spec_category_tag"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(isDark ? 0.18 : 0.09))
                )
        } else {
            Circle()
                .fill(accent.opacity(0.50))
                .frame(width: 4, height: 4)
        }
    }

    // MARK: - Bottom Descriptor

    @ViewBuilder
    private func specBottomDescriptor(detail: PPAccessoryViewerDetailItem, accent: Color) -> some View {
        let isDark = colorScheme == .dark
        if detail.id == "remain-quantity" {
            let qty = resolvedQuantity(for: detail)
            let segments = min(max(qty, 1), 4)

            HStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { idx in
                    Capsule(style: .continuous)
                        .fill(
                            idx < segments
                                ? accent
                                : accent.opacity(isDark ? 0.20 : 0.12)
                        )
                        .frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        } else if detail.id == "condition" {
            Text(PPAccessoryViewerL10n.text("accessory_view_spec_pristine_sub"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PPAccessoryPalette.success)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if detail.id == "accessory-kind" || detail.id == "subcategory" {
            Text(PPAccessoryViewerL10n.text("accessory_view_spec_category_sub"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(PPAccessoryViewerL10n.text("accessory_view_spec_standard_sub"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Quantity Resolution

    private func resolvedQuantity(for detail: PPAccessoryViewerDetailItem) -> Int {
        if let stockQuantity, stockQuantity > 0 {
            return stockQuantity
        }
        let clean = detail.value
            .replacingOccurrences(of: "٠", with: "0")
            .replacingOccurrences(of: "١", with: "1")
            .replacingOccurrences(of: "٢", with: "2")
            .replacingOccurrences(of: "٣", with: "3")
            .replacingOccurrences(of: "٤", with: "4")
            .replacingOccurrences(of: "٥", with: "5")
            .replacingOccurrences(of: "٦", with: "6")
            .replacingOccurrences(of: "٧", with: "7")
            .replacingOccurrences(of: "٨", with: "8")
            .replacingOccurrences(of: "٩", with: "9")
            .filter { $0.isNumber }
        return Int(clean) ?? 4
    }

    // MARK: - Insight Texts

    private func insightTitle(for detail: PPAccessoryViewerDetailItem) -> String {
        switch detail.id {
        case "condition":
            return PPAccessoryViewerL10n.text("accessory_view_spec_condition_title")
        case "remain-quantity":
            return PPAccessoryViewerL10n.text("accessory_view_spec_stock_title")
        case "accessory-kind", "subcategory":
            return PPAccessoryViewerL10n.text("accessory_view_spec_kind_title")
        case "weight":
            return PPAccessoryViewerL10n.text("accessory_view_spec_weight_title")
        case "expiry":
            return PPAccessoryViewerL10n.text("accessory_view_spec_expiry_title")
        case "location":
            return PPAccessoryViewerL10n.text("accessory_view_spec_location_title")
        default:
            return detail.title
        }
    }

    private func insightDescription(for detail: PPAccessoryViewerDetailItem) -> String {
        switch detail.id {
        case "condition":
            return PPAccessoryViewerL10n.text("accessory_view_spec_condition_desc")
        case "remain-quantity":
            let qty = resolvedQuantity(for: detail)
            return PPAccessoryViewerL10n.text(
                qty <= 5
                    ? "accessory_view_spec_stock_desc"
                    : "accessory_view_spec_stock_desc_ample"
            )
        case "accessory-kind", "subcategory":
            return PPAccessoryViewerL10n.text("accessory_view_spec_kind_desc")
        case "weight":
            return PPAccessoryViewerL10n.text("accessory_view_spec_weight_desc")
        case "expiry":
            return PPAccessoryViewerL10n.text("accessory_view_spec_expiry_desc")
        case "location":
            return PPAccessoryViewerL10n.text("accessory_view_spec_location_desc")
        default:
            return "\(detail.title): \(detail.value)"
        }
    }

    // MARK: - Accessibility Layout

    private var accessibilityList: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            ForEach(Array(railDetails.enumerated()), id: \.element.id) { index, detail in
                accessibleSpecRow(detail, index: index)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func accessibleSpecRow(_ detail: PPAccessoryViewerDetailItem, index: Int) -> some View {
        let isSelected = selectedDetailId == detail.id
        let accent = detail.tone.accessoryAccentColor
        let isDark = colorScheme == .dark

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                selectedDetailId = (selectedDetailId == detail.id ? nil : detail.id)
            }
        } label: {
            HStack(alignment: .center, spacing: PPSpace.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(isDark ? 0.22 : 0.12))
                        .frame(width: 40, height: 40)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(accent.opacity(isDark ? 0.35 : 0.20), lineWidth: 0.75)
                        }

                    detailIconView(detail, accent: accent, size: 18)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.title)
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)

                    Text(detail.value)
                        .font(PPAccessoryTypography.headline)
                        .foregroundStyle(PPAccessoryPalette.ink)
                }

                Spacer(minLength: PPSpace.sm)

                specStatusBeacon(detail: detail, accent: accent)
            }
            .padding(PPSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .fill(Color.ppForeground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? accent.opacity(0.85)
                            : accent.opacity(isDark ? 0.24 : 0.14),
                        lineWidth: isSelected ? 1.5 : 0.65
                    )
            }
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.98))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(detail.title): \(detail.value)")
    }

    // MARK: - Icon

    @ViewBuilder
    private func detailIconView(
        _ detail: PPAccessoryViewerDetailItem,
        accent: Color,
        size: CGFloat = 15
    ) -> some View {
        if detail.symbol == "pawprint.fill" {
            Image("pawprint4")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: size,
                    height: size
                )
                .foregroundStyle(accent)
                .accessibilityHidden(true)
        } else {
            Image(systemName: detail.symbol)
                .font(.system(
                    size: size,
                    weight: .semibold
                ))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            ZStack {
                Circle()
                    .fill(PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.18 : 0.08))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.32 : 0.18),
                                lineWidth: 0.75
                            )
                    }

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PPAccessoryPalette.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(PPAccessoryViewerL10n.text("accessory_view_details_title"))
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(PPAccessoryPalette.ink)

                Text(PPAccessoryViewerL10n.text("accessory_view_details_empty"))
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .fill(Color.ppForeground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(
                    PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.28 : 0.14),
                    lineWidth: 0.75
                )
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

    /// Sized against the two-line name block beside it rather than as a hero
    /// element, and scaled with Dynamic Type so the pairing holds at every size.
    @ScaledMetric(relativeTo: .title3) private var sellerAvatarSize: CGFloat = 64

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
            sellerAvatar(owner, size: sellerAvatarSize)

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
                sellerAvatar(owner, size: sellerAvatarSize)
                sellerIdentityText(owner)
                    .layoutPriority(1)
            }

            profileCue
        }
    }

    private func sellerIdentityText(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        return VStack(alignment: .leading, spacing: 7) {
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

    /// True when the avatar is a brand mark rather than a photograph of a person.
    ///
    /// A logo is authored inside its own canvas with transparent margins, so
    /// filling a square frame with it crops the mark. A photograph is the
    /// opposite: it must fill, or it reads as a floating cut-out.
    private func sellerAvatarIsBrandMark(
        _ owner: PPAccessoryViewerOwner
    ) -> Bool {
        if owner.companyProfileImageURL != nil { return true }
        let url = owner.preferredAvatarURL?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        return url.hasPrefix("purepets://support-logo")
    }

    private func sellerAvatar(
        _ owner: PPAccessoryViewerOwner,
        size: CGFloat
    ) -> some View {
        let avatarShape = RoundedRectangle(
            cornerRadius: min(size * 0.28, 22),
            style: .continuous
        )
        let isBrandMark = sellerAvatarIsBrandMark(owner)
        // A brand mark is inset so the whole mark is visible inside the plate.
        let contentInset = isBrandMark ? max(size * 0.15, 8) : 0

        return ZStack(alignment: .bottomTrailing) {
            avatarShape
                .fill(avatarPlateFill)

            PPAccessoryRemoteImageView(
                urlString: owner.preferredAvatarURL,
                blurHash: nil,
                contentMode: isBrandMark ? .fit : .fill,
                accessibilityLabel: displayName(for: owner),
                isAvatar: true,
                fallbackInitials: displayName(for: owner),
                avatarFitsContent: isBrandMark
            )
            .frame(
                width: size - contentInset * 2,
                height: size - contentInset * 2
            )
            .padding(contentInset)

            if owner.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
                    .background(Circle().fill(Color.white))
                    .offset(x: 3, y: 3)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .clipShape(avatarShape)
        .shadow(color: Color.ppPrimary.opacity(0.14), radius: 8, x: 0, y: 4)
        .overlay(
            avatarShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.ppPrimary.opacity(0.32),
                            Color.white.opacity(0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .accessibilityHidden(true)
    }

    private func sellerMeta(_ owner: PPAccessoryViewerOwner) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PPSpace.sm) {
                sellerTrustCapsule(owner)
                // TEMPORARY: Hidden provider rate view in seller card
                // sellerRatingCapsule(owner)
                sellerLocationLabel
            }

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                sellerTrustCapsule(owner)
                // TEMPORARY: Hidden provider rate view in seller card
                // sellerRatingCapsule(owner)
                sellerLocationLabel
            }
        }
    }

    private func sellerRatingCapsule(
        _ owner: PPAccessoryViewerOwner
    ) -> some View {
        let rating = min(max(owner.ratingValue, 0), 5)
        let reviewCount = max(owner.reviewCount, 0)
        let hasRating = rating > 0 && reviewCount > 0

        return HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: Double(index) <= rating ? "star.fill" : "star")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(
                            Double(index) <= rating
                                ? PPAccessoryPalette.warning
                                : PPAccessoryPalette.inkSecondary.opacity(0.42)
                        )
                        .accessibilityHidden(true)
                }
            }

            Text(
                hasRating
                    ? PPAccessoryViewerL10n.formatted(
                        "accessory_view_seller_rating_format",
                        PPAccessoryViewerL10n.decimal(rating),
                        PPAccessoryViewerL10n.integer(reviewCount)
                    )
                    : PPAccessoryViewerL10n.text("provider_rating_no_reviews")
            )
            .font(PPAccessoryTypography.captionBold)
            .foregroundStyle(Color.ppPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.80)
        }
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, 6)
        .background(
            PPAccessoryPalette.warning.opacity(
                colorSchemeContrast == .increased ? 0.18 : 0.09
            ),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sellerRatingAccessibilityText(owner))
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
        let showChat = shouldShowChat(for: owner)
        let showCall = shouldShowCall(for: owner)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                if showChat {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("Chat"),
                        symbol: "message.fill",
                        style: .chat,
                        layout: .primaryPill,
                        enabled: true,
                        action: store.chatWithOwner
                    )
                }

                HStack(spacing: PPSpace.sm) {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("View_Profile"),
                        symbol: "storefront.fill",
                        style: .profile,
                        layout: .primaryPill,
                        enabled: true,
                        action: store.openSellerProfile
                    )

                    if showCall {
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
                if showChat {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("Chat"),
                        symbol: "message.fill",
                        style: .chat,
                        layout: .primaryPill,
                        enabled: true,
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
                } else {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("View_Profile"),
                        symbol: "storefront.fill",
                        style: .profile,
                        layout: .primaryPill,
                        enabled: true,
                        action: store.openSellerProfile
                    )
                    .layoutPriority(1)
                }

                if showCall {
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

    private func shouldShowChat(
        for owner: PPAccessoryViewerOwner
    ) -> Bool {
        guard !snapshot.isOwnItem && owner.isChatAllowed else { return false }
        return !isPurePetsOwner(owner)
    }

    private func isPurePetsOwner(_ owner: PPAccessoryViewerOwner) -> Bool {
        if owner.user.id == "PUIDPOFFICILAL20262214" { return true }
        if let avatar = owner.preferredAvatarURL, avatar.hasPrefix("purepets://support-logo") {
            return true
        }
        let trimmed = owner.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == PPAccessoryViewerL10n.text("accessory_view_store_name") ||
           trimmed.contains("بيوربتس") ||
           trimmed.contains("بيور بتس") ||
           trimmed.contains("Pure Pets") {
            return true
        }
        return false
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
                    RoundedRectangle(
                        cornerRadius: min(sellerAvatarSize * 0.28, 22),
                        style: .continuous
                    )
                    .fill(PPAccessoryPalette.ink.opacity(0.08))
                    .frame(width: sellerAvatarSize, height: sellerAvatarSize)

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
            .background {
                RoundedRectangle(
                    cornerRadius: PPCorner.hero,
                    style: .continuous
                )
                .fill(Color.ppElevatedSurface)
                .overlay {
                    sourceSurfaceShape.stroke(
                        sourceSurfaceStroke,
                        lineWidth:
                            colorSchemeContrast == .increased ? 1.5 : 1
                    )
                }
            }
            .clipShape(sourceSurfaceShape)
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark ? 0.18 : 0.05
                ),
                radius: 14,
                x: 0,
                y: 6
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
        Image("pawprint4")
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
            return colorScheme == .dark ? 0.12 : 0.02
        }
        return colorScheme == .dark ? 0.09 : 0.02
    }

    private var sellerPawTint: Color {
        colorScheme == .dark
            ? PPAccessoryPalette.accent
        : PPAccessoryPalette.deepSea.opacity(0.0)
    }

    private var avatarPlateFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.ppElevatedSurface,
                PPAccessoryPalette.appBackground
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
            sellerRatingAccessibilityText(owner),
            snapshot.location.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private func sellerRatingAccessibilityText(
        _ owner: PPAccessoryViewerOwner
    ) -> String {
        let rating = min(max(owner.ratingValue, 0), 5)
        let reviewCount = max(owner.reviewCount, 0)

        guard rating > 0 && reviewCount > 0 else {
            return PPAccessoryViewerL10n.text("provider_rating_no_reviews")
        }

        return String(
            format: PPAccessoryViewerL10n.text(
                "provider_rating_accessibility_format"
            ),
            rating,
            reviewCount
        )
    }
}

struct PPAccessoryDescriptionAccentLine: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(PPAccessoryPalette.brand)
            .frame(width: 4)
            .accessibilityHidden(true)
    }
}

struct PPAccessoryEditorialDescription: View {
    let text: String
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    if reduceMotion {
                        expanded.toggle()
                    } else {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            expanded.toggle()
                        }
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var suggestionCardHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 508 : 336
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(store.suggestions) { suggestion in
                            universalSuggestionCard(suggestion)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
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
        let cellContext: PPCellContext = suggestion.accessory.isFood ? .forFood : .forMarket
        let viewModel = PPUniversalCellViewModel(
            model: suggestion.accessory,
            context: cellContext
        )

        return PPUniversalCardView(
            viewModel: viewModel,
            delegate: nil,
            context: cellContext,
            layoutMode: .cellLayoutModeVertical,
            discountMode: .plain,
            imageLoader: nil,
            hideTopBadge: false,
            showsSubtitle: true,
            onTap: {
                store.openSuggestion(suggestion)
            }
        )
        .frame(width: compact ? 172 : 195, height: suggestionCardHeight)
        .accessibilityElement(children: .combine)
    }

    private var suggestionSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(["skeleton-0", "skeleton-1", "skeleton-2"], id: \.self) { itemID in
                    skeletonCard(itemID)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .accessibilityLabel(
            PPAccessoryViewerL10n.text(
                "accessory_view_loading_suggestions"
            )
        )
    }

    private func skeletonCard(_ itemID: String) -> some View {
        let skeletonVM = PPUniversalCellViewModel(model: nil, context: .forMarket)
        skeletonVM.isSkeleton = true
        return PPUniversalCardView(
            viewModel: skeletonVM,
            delegate: nil,
            context: .forMarket,
            layoutMode: .cellLayoutModeVertical,
            discountMode: .plain,
            showsSubtitle: true
        )
        .frame(width: compact ? 172 : 195, height: suggestionCardHeight)
    }
}

private struct PPAccessoryRecoveryAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let isPrimary: Bool
    let isEnabled: Bool
    let showsProgress: Bool
    let handler: () -> Void
}

@available(iOS 16.0, *)
struct PPAccessoryPersistentDecisionBar: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot
    let compact: Bool
    let bottomInset: CGFloat

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
        .padding(childOwnsSurface ? 0 : PPBottomDecisionBarGeometry.contentPadding)
        .background {
            if !childOwnsSurface {
                PPAccessoryBottomFaceSurface(isCommerce: false)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(
            .horizontal,
            childOwnsSurface
                ? 16
                : (compact
                    ? PPBottomDecisionBarGeometry.compactScreenInset
                    : PPBottomDecisionBarGeometry.regularScreenInset)
        )
        .padding(.top, PPSpace.sm)
        .padding(
            .bottom,
            snapshot.showsCart
                ? PPSpace.base
                : max(bottomInset, PPSpace.base)
        )
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
    }

    private var cartBar: some View {
        Group {
            if store.checkoutPhase == .routeFailed {
                checkoutRouteRecoveryBar
            } else if showsCommerceCartHolder {
                commerceCartHolder
            } else {
                unavailableRecoveryBar
            }
        }
    }

    /// The bottom cart. A viewer-owned dock rather than the shared holder, because
    /// the decision it hosts is product specific: how many of *this* sellable unit,
    /// at *this* live total, against *this* remaining stock.
    private var commerceCartHolder: some View {
        PPAccessoryCommerceDock(
            store: store,
            snapshot: snapshot,
            compact: compact
        )
        .accessibilityIdentifier("pp.accessory.commerce.holder")
        .disabled(store.switchingVariantProductId != nil)
    }

    private var checkoutRouteRecoveryBar: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.success)
                    .frame(width: 44, height: 44)
                    .background(
                        PPAccessoryPalette.success.opacity(0.11),
                        in: RoundedRectangle(
                            cornerRadius: PPCorner.small,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    Text(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_checkout_ready_title"
                        )
                    )
                    .font(PPAccessoryTypography.headline)
                    .foregroundStyle(PPAccessoryPalette.ink)

                    Text(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_checkout_ready_message"
                        )
                    )
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            checkoutRouteRecoveryActions
        }
    }

    @ViewBuilder
    private var checkoutRouteRecoveryActions: some View {
        let actions = checkoutRouteRecoveryActionModels
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                ForEach(actions) { action in
                    recoveryButton(action)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: PPSpace.sm) {
                    ForEach(actions) { action in
                        recoveryButton(action)
                    }
                }
                VStack(spacing: PPSpace.sm) {
                    ForEach(actions) { action in
                        recoveryButton(action)
                    }
                }
            }
        }
    }

    private var checkoutRouteRecoveryActionModels:
        [PPAccessoryRecoveryAction] {
        [
            PPAccessoryRecoveryAction(
                id: "continue-payment",
                title: PPAccessoryViewerL10n.text(
                    "accessory_view_continue_to_payment"
                ),
                symbol: "creditcard.fill",
                isPrimary: true,
                isEnabled: true,
                showsProgress: false,
                handler: store.payNow
            ),
            PPAccessoryRecoveryAction(
                id: "open-cart",
                title: PPAccessoryViewerL10n.text(
                    "accessory_view_open_cart"
                ),
                symbol: "cart.fill",
                isPrimary: false,
                isEnabled: true,
                showsProgress: false,
                handler: store.openCart
            ),
        ]
    }

    private var unavailableRecoveryBar: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: recoverySymbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(recoveryColor)
                    .frame(width: 44, height: 44)
                    .background(
                        recoveryColor.opacity(0.11),
                        in: RoundedRectangle(
                            cornerRadius: PPCorner.small,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    Text(recoveryTitle)
                        .font(PPAccessoryTypography.headline)
                        .foregroundStyle(PPAccessoryPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(recoveryMessage)
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            recoveryActions
        }
    }

    @ViewBuilder
    private var recoveryActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                ForEach(recoveryActionModels) { action in
                    recoveryButton(action)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: PPSpace.sm) {
                    ForEach(recoveryActionModels) { action in
                        recoveryButton(action)
                    }
                }

                VStack(spacing: PPSpace.sm) {
                    ForEach(recoveryActionModels) { action in
                        recoveryButton(action)
                    }
                }
            }
        }
    }

    private func recoveryButton(
        _ action: PPAccessoryRecoveryAction
    ) -> some View {
        Button(action: action.handler) {
            HStack(spacing: PPSpace.sm) {
                if action.showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(action.isPrimary ? .white : recoveryColor)
                } else {
                    Image(systemName: action.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .accessibilityHidden(true)
                }

                Text(action.title)
                    .font(PPAccessoryTypography.bodyBold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(
                action.isPrimary ? Color.white : recoveryColor
            )
            .padding(.horizontal, PPSpace.md)
            .frame(
                maxWidth: .infinity,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .background(
                action.isPrimary
                    ? recoveryColor
                    : PPAccessorySubviewBackground.baseSurface,
                in: RoundedRectangle(
                    cornerRadius:
                        PPBottomDecisionBarGeometry.controlRadius,
                    style: .continuous
                )
            )
            .overlay {
                if !action.isPrimary {
                    RoundedRectangle(
                        cornerRadius:
                            PPBottomDecisionBarGeometry.controlRadius,
                        style: .continuous
                    )
                    .stroke(recoveryColor.opacity(0.24), lineWidth: 1)
                }
            }
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .disabled(!action.isEnabled)
        .opacity(action.isEnabled ? 1 : 0.58)
        .accessibilityLabel(action.title)
    }

    private var recoveryActionModels: [PPAccessoryRecoveryAction] {
        var result: [PPAccessoryRecoveryAction] = []

        if store.livePhase == .stale ||
            store.livePhase == .refreshing {
            result.append(
                PPAccessoryRecoveryAction(
                    id: "refresh",
                    title: PPAccessoryViewerL10n.text(
                        store.livePhase == .refreshing
                            ? "accessory_view_refreshing"
                            : "accessory_view_refresh_product"
                    ),
                    symbol: "arrow.clockwise",
                    isPrimary: true,
                    isEnabled: store.livePhase == .stale,
                    showsProgress: store.livePhase == .refreshing,
                    handler: store.retryLiveUpdates
                )
            )
        } else if snapshot.canRequestStockNotification &&
            store.livePhase != .deleted {
            result.append(
                PPAccessoryRecoveryAction(
                    id: "notify",
                    title: stockNotificationTitle,
                    symbol: store.stockNotificationPhase == .success
                        ? "checkmark.circle.fill"
                        : "bell.badge.fill",
                    isPrimary: true,
                    isEnabled:
                        store.stockNotificationPhase != .processing &&
                        store.stockNotificationPhase != .success,
                    showsProgress:
                        store.stockNotificationPhase == .processing,
                    handler: store.registerStockNotification
                )
            )
        }

        if store.hasSimilarAlternatives {
            result.append(
                PPAccessoryRecoveryAction(
                    id: "alternatives",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_show_alternatives"
                    ),
                    symbol: "square.grid.2x2.fill",
                    isPrimary: result.isEmpty,
                    isEnabled: true,
                    showsProgress: false,
                    handler: store.showSimilarAlternatives
                )
            )
        }

        if store.canAskSeller {
            result.append(
                PPAccessoryRecoveryAction(
                    id: "ask-seller",
                    title: PPAccessoryViewerL10n.text(
                        "accessory_view_ask_seller"
                    ),
                    symbol: "message.fill",
                    isPrimary: result.isEmpty,
                    isEnabled: true,
                    showsProgress: false,
                    handler: store.chatWithOwner
                )
            )
        }

        if result.isEmpty {
            result.append(
                PPAccessoryRecoveryAction(
                    id: "support",
                    title: PPAccessoryViewerL10n.text("Support"),
                    symbol: "lifepreserver.fill",
                    isPrimary: true,
                    isEnabled: true,
                    showsProgress: false,
                    handler: store.openSupport
                )
            )
        }

        return result
    }

    private var stockNotificationTitle: String {
        switch store.stockNotificationPhase {
        case .idle, .failed:
            return PPAccessoryViewerL10n.text("notify_me")
        case .processing:
            return PPAccessoryViewerL10n.text("notify_me_loading")
        case .success:
            return PPAccessoryViewerL10n.text(
                "stock_notify_already_registered"
            )
        }
    }

    private var recoveryTitle: String {
        switch store.livePhase {
        case .stale, .refreshing:
            return PPAccessoryViewerL10n.text(
                "accessory_view_live_data_title"
            )
        case .deleted:
            return PPAccessoryViewerL10n.text(
                "accessory_view_unavailable_title"
            )
        case .current:
            return snapshot.quantity <= 0
                ? PPAccessoryViewerL10n.text("Out of stock")
                : PPAccessoryViewerL10n.text(
                    "accessory_view_item_unavailable"
                )
        }
    }

    private var recoveryMessage: String {
        switch store.livePhase {
        case .stale, .refreshing:
            return PPAccessoryViewerL10n.text(
                "accessory_view_live_data_stale"
            )
        case .deleted:
            return PPAccessoryViewerL10n.text(
                "accessory_view_live_product_removed"
            )
        case .current:
            return snapshot.quantity <= 0
                ? PPAccessoryViewerL10n.text(
                    "accessory_view_out_of_stock_recovery"
                )
                : PPAccessoryViewerL10n.text(
                    "accessory_view_unavailable_recovery"
                )
        }
    }

    private var recoverySymbol: String {
        switch store.livePhase {
        case .stale, .refreshing:
            return "wifi.exclamationmark"
        case .deleted:
            return "xmark.octagon.fill"
        case .current:
            return snapshot.quantity <= 0
                ? "shippingbox.and.arrow.backward.fill"
                : "exclamationmark.triangle.fill"
        }
    }

    private var recoveryColor: Color {
        store.livePhase == .stale ||
            store.livePhase == .refreshing
            ? PPAccessoryPalette.warning
            : PPAccessoryPalette.brand
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
                .fontWeight(.heavy)
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

    private var allOptionsSelected: Bool {
        store.hasResolvedVariantOptions
    }

    private var hasPurchasableStock: Bool {
        !snapshot.isUnavailable &&
            store.remainingStock > 0 &&
            store.isPurchaseDataCurrent &&
            store.checkoutPreviewCanCommit &&
            allOptionsSelected
    }

    private var showsCommerceCartHolder: Bool {
        hasPurchasableStock || store.cartQuantity > 0
    }

    /// Only the commerce dock draws its own bottom face. Every other state is a
    /// bare layout that still needs the shared surface and content padding.
    private var childOwnsSurface: Bool {
        snapshot.showsCart &&
            store.checkoutPhase != .routeFailed &&
            showsCommerceCartHolder
    }

    private var remainingText: String {
        PPAccessoryViewerL10n.formatted(
            "accessory_view_remaining_text_format",
            PPAccessoryViewerL10n.integer(store.remainingStock)
        )
    }

    private var decisionStateIdentity: String {
        if snapshot.showsCart {
            if store.checkoutPhase == .routeFailed {
                return "cart-checkout-route-failed"
            }
            if showsCommerceCartHolder {
                return "cart-commerce-holder"
            }
            return "cart-unavailable-\(String(describing: store.livePhase))"
        }
        return "contact-\(String(describing: store.ownerPhase))"
    }
}

struct PPAccessoryPersistentDecisionBarLoading: View {
    let compact: Bool
    let bottomInset: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: PPSpace.sm) {
            summarySkeleton
            actionRowSkeleton
        }
        .padding(PPSpace.md)
        .background(
            Color.ppSurface,
            in: RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.surfaceRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.surfaceRadius,
                style: .continuous
            )
            .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1)
        }
        .shadow(
            color: PPShadow.card.color,
            radius: PPShadow.card.radius,
            x: PPShadow.card.x,
            y: PPShadow.card.y
        )
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, -PPSpace.sm)
        .padding(
            .horizontal,
            compact
                ? PPBottomDecisionBarGeometry.compactScreenInset
                : PPBottomDecisionBarGeometry.regularScreenInset
        )
        .padding(.top, PPSpace.sm)
        .padding(
            .bottom,
            0
        )
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
        HStack(spacing: PPSpace.sm) {
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .fill(Color.ppSurfaceBorder.opacity(0.78))
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                RoundedRectangle(cornerRadius: PPSpace.xs)
                    .fill(PPAccessoryPalette.ink.opacity(0.12))
                    .frame(maxWidth: 150)
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: PPSpace.xs)
                    .fill(PPAccessoryPalette.ink.opacity(0.08))
                    .frame(maxWidth: 112)
                    .frame(height: 10)
            }

            Spacer(minLength: PPSpace.sm)

            RoundedRectangle(cornerRadius: PPSpace.xs)
                .fill(PPAccessoryPalette.brand.opacity(0.18))
                .frame(width: 64, height: 18)
        }
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, PPSpace.xs)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            Color.ppSecondarySurface.opacity(0.58),
            in: RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
                style: .continuous
            )
            .strokeBorder(Color.ppSurfaceBorder.opacity(0.72), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var actionRowSkeleton: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                quantitySkeleton
                paymentSkeleton
            }
        } else {
            GeometryReader { proxy in
                HStack(spacing: PPSpace.sm) {
                    quantitySkeleton
                        .frame(width: proxy.size.width * 0.44)
                    paymentSkeleton
                }
            }
            .frame(height: 50)
        }
    }

    private var quantitySkeleton: some View {
        RoundedRectangle(
            cornerRadius: PPCorner.small,
            style: .continuous
        )
        .fill(Color.ppSecondarySurface)
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(0.72), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }

    private var paymentSkeleton: some View {
        RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )
        .fill(PPAccessoryPalette.brand.opacity(0.20))
        .frame(maxWidth: .infinity)
        .frame(height: 50)
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
                (compact ? 164 : 148) + PPSpace.base
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


// MARK: - Product Options

/// The product configuration console.
///
/// Choosing an option here is not filtering a list: it changes which sellable
/// product the entire screen describes, so price, stock, media, fit and the cart
/// target all follow from it. The console therefore behaves as one instrument
/// rather than a loose group of controls, and it always answers three questions
/// in place: what is being configured, what is still open, and what the current
/// choice actually resolves to.
///
/// The Store owns both the confirmed product and the in-flight request;
/// presentation never keeps a second draft selection.
@available(iOS 16.0, *)
struct PPAccessoryVariantSelectorSection: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot
    let compact: Bool
    var showsDeliveryContext = true

    @State private var showsCombinations = false
    @State private var combinationQuery = ""
    @State private var sweepScale: CGFloat = 0.12
    @State private var sweepOpacity: Double = 0
    @FocusState private var combinationSearchFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch store.variantsPhase {
        case .idle, .empty:
            EmptyView()
        case .loading:
            if !(snapshot.accessory.productFamilyId ?? "").isEmpty {
                console { skeleton }
            }
        case .loaded:
            // A family that resolved with neither axes nor siblings has nothing to
            // configure; the console would be an empty instrument.
            if store.optionDefinitions.isEmpty && store.variants.isEmpty {
                EmptyView()
            } else {
                console { configuration }
            }
        case let .failed(message):
            console {
                recovery(message, action: store.retryVariants)
            }
        }
    }

    // MARK: Console shell

    /// One physical surface. Everything about the configuration lives inside it,
    /// full width, so no control is left floating in dead space.
    private func console<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )

        return content()
            .padding(.horizontal, compact ? PPSpace.base : PPSpace.lg)
            .padding(.top, compact ? PPSpace.sm : PPSpace.md)
            .padding(.bottom, compact ? PPSpace.sm : PPSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(consoleFill, in: shape)
            .overlay {
                shape.strokeBorder(
                    consoleStroke,
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
            }
            .overlay(alignment: .top) { reconfigureSweep }
            .clipShape(shape)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05),
                radius: 14,
                y: 6
            )
            .padding(.vertical, PPSpace.xxs)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                PPAccessoryViewerL10n.text("accessory_view_options_console_label")
            )
            .accessibilityIdentifier("pp.accessory.options.studio")
    }

    private var consoleFill: Color {
        colorScheme == .dark
            ? Color.ppElevatedSurface.opacity(0.92)
            : Color.ppForeground.opacity(0.94)
    }

    private var consoleStroke: Color {
        colorSchemeContrast == .increased
            ? PPAccessoryPalette.brand.opacity(0.66)
            : PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.26 : 0.18)
    }

    /// A single brand sweep across the console's top edge the moment a different
    /// product finishes resolving. It is the one motion cue that the surrounding
    /// screen just re-described itself, so it is never decorative.
    private var reconfigureSweep: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        PPAccessoryPalette.brand.opacity(0.9),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .scaleEffect(x: sweepScale, y: 1, anchor: .center)
            .opacity(sweepOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func runReconfigureSweep() {
        guard !reduceMotion else { return }
        sweepScale = 0.12
        sweepOpacity = 0.9
        withAnimation(.easeOut(duration: 0.55)) {
            sweepScale = 1.0
            sweepOpacity = 0.0
        }
    }

    // MARK: Configuration body

    private var configuration: some View {
        VStack(alignment: .leading, spacing: compact ? PPSpace.sm : PPSpace.md) {
            if store.optionDefinitions.isEmpty {
                if !store.variants.isEmpty {
                    combinationsList
                }
            } else {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    ForEach(
                        Array(store.optionDefinitions.enumerated()),
                        id: \.element.id
                    ) { index, option in
                        if index > 0 { axisSeparator }

                        PPAccessoryOptionGroup(
                            store: store,
                            option: option,
                            compact: compact
                        )
                    }
                }
            }

            PPAccessoryVariantResolutionBar(
                store: store,
                snapshot: snapshot,
                compact: compact
            )

            combinationsAffordance
        }
        .onChange(of: showsCombinations) { expanded in
            if !expanded {
                combinationQuery = ""
                combinationSearchFocused = false
            }
        }
        .onChange(of: snapshot.id) { _ in
            runReconfigureSweep()
        }
    }

    private var axisSeparator: some View {
        Rectangle()
            .fill(PPAccessorySubviewBackground.faintStroke)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }

    // MARK: Full combination browser

    private var hasBrowsableCombinations: Bool {
        store.optionDefinitions.count > 1 && store.variants.count > 1
    }

    @ViewBuilder
    private var combinationsAffordance: some View {
        if !store.optionDefinitions.isEmpty, !store.variants.isEmpty {
            if !store.hasResolvedVariantOptions {
                // Recovery, not decoration: when no complete combination is
                // resolved the direct list is the fastest way back to a
                // buyable product, so it is open by default.
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    Text(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_selection_needed"
                        )
                    )
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                    combinationsList
                }
            } else if hasBrowsableCombinations {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    combinationsDisclosure

                    if showsCombinations {
                        combinationsList
                    }
                }
            }
        }
    }

    private var combinationsDisclosure: some View {
        Button {
            showsCombinations.toggle()
        } label: {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.brand)
                    .accessibilityHidden(true)

                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_all_combinations_short"
                    )
                )
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

                Text(PPAccessoryViewerL10n.integer(store.variants.count))
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        PPAccessorySubviewBackground.quietFill,
                        in: Capsule(style: .continuous)
                    )

                Spacer(minLength: PPSpace.sm)

                Image(
                    systemName: showsCombinations ? "chevron.up" : "chevron.down"
                )
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .accessibilityHidden(true)
            }
            .frame(minHeight: compact ? 32 : 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_all_combinations")
        )
        .accessibilityValue(
            PPAccessoryViewerL10n.text(
                showsCombinations
                    ? "accessory_view_options_expanded"
                    : "accessory_view_options_collapsed"
            )
        )
        .accessibilityHint(
            PPAccessoryViewerL10n.text("accessory_view_combinations_hint")
        )
        .accessibilityIdentifier("pp.accessory.options.combinations")
    }

    private var matchingVariants: [PPAccessoryViewerVariant] {
        let query = combinationQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else { return store.variants }

        return store.variants.filter { variant in
            store.optionSummary(for: variant).localizedStandardContains(query) ||
                variant.sku.localizedStandardContains(query) ||
                store.optionDefinitions.contains { option in
                    guard let value = option.values.first(where: {
                        $0.id == variant.selectedOptions[option.id]
                    }) else { return false }
                    return value.matches(query)
                }
        }
    }

    private var combinationsList: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            if store.variants.count > 8 {
                TextField(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_search_combinations"
                    ),
                    text: $combinationQuery
                )
                .textFieldStyle(.roundedBorder)
                .font(PPAccessoryTypography.body)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .focused($combinationSearchFocused)
                .onSubmit { combinationSearchFocused = false }
            }

            if matchingVariants.isEmpty {
                Text(
                    PPAccessoryViewerL10n.text(
                        "accessory_view_options_no_results"
                    )
                )
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

                clearCombinationSearch
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(matchingVariants, id: \.productId) { variant in
                        combinationRow(variant)
                    }
                }
                .background(
                    PPAccessorySubviewBackground.quietFill,
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )

                if !combinationQuery.isEmpty { clearCombinationSearch }
            }
        }
    }

    private func combinationRow(
        _ variant: PPAccessoryViewerVariant
    ) -> some View {
        let isSelected = variant.productId == snapshot.id
        let isPending = store.switchingVariantProductId == variant.productId

        return Button {
            combinationSearchFocused = false
            store.selectVariant(variant)
        } label: {
            PPAccessoryOptionChoiceLabel(
                title: store.optionSummary(for: variant),
                detail: variant.isArchived
                    ? PPAccessoryViewerL10n.text(
                        "accessory_view_option_unavailable"
                    )
                    : nil,
                unit: nil,
                swatch: variant.swatchComponents,
                selected: isSelected,
                pending: isPending,
                unavailable: variant.isArchived,
                adjusts: false
            )
            .padding(.horizontal, PPSpace.md)
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.985))
        .disabled(!store.canChangeVariant || isSelected || variant.isArchived)
        .accessibilityLabel(store.optionSummary(for: variant))
        .accessibilityValue(
            combinationAccessibilityValue(
                selected: isSelected,
                variant: variant
            )
        )
        .accessibilityAddTraits(
            isSelected ? [.isButton, .isSelected] : .isButton
        )
        .accessibilityIdentifier("pp.accessory.variant.\(variant.productId)")
    }

    private var clearCombinationSearch: some View {
        Button(
            PPAccessoryViewerL10n.text("accessory_view_options_clear_search")
        ) {
            combinationQuery = ""
            combinationSearchFocused = false
        }
        .font(PPAccessoryTypography.calloutBold)
        .foregroundStyle(PPAccessoryPalette.brand)
        .frame(minHeight: 44)
        .buttonStyle(.plain)
    }

    private func combinationAccessibilityValue(
        selected: Bool,
        variant: PPAccessoryViewerVariant
    ) -> String {
        if store.switchingVariantProductId == variant.productId {
            return PPAccessoryViewerL10n.text("accessory_view_options_loading")
        }
        if selected { return PPAccessoryViewerL10n.text("Selected") }
        return variant.isArchived
            ? PPAccessoryViewerL10n.text("accessory_view_option_unavailable")
            : ""
    }

    // MARK: Pending / failure

    private func recovery(
        _ message: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(message)
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button(
                PPAccessoryViewerL10n.text("accessory_view_colors_retry"),
                action: action
            )
            .font(PPAccessoryTypography.calloutBold)
            .foregroundStyle(PPAccessoryPalette.brand)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .disabled(
                store.switchingVariantProductId != nil ||
                    store.isCheckoutProcessing ||
                    store.cartPhase == .processing
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Loading keeps the console's exact anatomy so nothing shifts on arrival.
    private var skeleton: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            Capsule().fill(PPAccessoryPalette.ink.opacity(0.08))
                .frame(width: 48, height: 16)

            HStack(spacing: PPSpace.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                    .fill(PPAccessoryPalette.ink.opacity(0.07))
                    .frame(width: 68, height: 36)
                }
            }
        }
        .frame(height: 48)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_options_loading")
        )
    }
}

// MARK: - Axis

/// One option axis rendered as a spec row: what it is, what is chosen, and the
/// values that can actually be bought. Values the seller never produced are moved
/// out of the primary rail instead of being struck through in place, because a
/// rail of crossed-out controls is noise, not information.
@available(iOS 16.0, *)
private struct PPAccessoryOptionGroup: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let option: PPAccessoryViewerOptionDefinition
    let compact: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct OptionEntry: Identifiable {
        let value: PPAccessoryViewerOptionValue
        let status: PPAccessoryViewerOptionValueStatus

        var id: String { value.id }
    }

    private var entries: [OptionEntry] {
        option.values.map { value in
            OptionEntry(
                value: value,
                status: store.status(forOptionValue: value, inOption: option)
            )
        }
    }

    private var rail: [OptionEntry] {
        entries.filter { $0.status.belongsOnPrimaryRail }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityRailView
            } else {
                standardRailView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(railIsBusyElsewhere ? 0.55 : 1)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.20),
            value: railIsBusyElsewhere
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var accessibilityRailView: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(option.localizedName)
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    if rail.isEmpty {
                        emptyRail(hasAnyValue: !option.values.isEmpty)
                    } else {
                        ForEach(rail) { entry in
                            choice(entry.value, status: entry.status)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(minHeight: 48)
    }

    @ViewBuilder
    private var standardRailView: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            Text(option.localizedName)
                .font(PPAccessoryTypography.bodyBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 44, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    if rail.isEmpty {
                        emptyRail(hasAnyValue: !option.values.isEmpty)
                    } else {
                        ForEach(rail) { entry in
                            choice(entry.value, status: entry.status)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 48)
    }

    private var selectedValue: PPAccessoryViewerOptionValue? {
        option.values.first { $0.id == store.selectedOptions[option.id] }
    }

    private var railIsBusyElsewhere: Bool {
        store.cartPhase == .processing || store.isCheckoutProcessing
    }

    @ViewBuilder
    private func emptyRail(hasAnyValue: Bool) -> some View {
        HStack(spacing: PPSpace.xs) {
            Text(PPAccessoryViewerL10n.text("accessory_view_options_empty_axis"))
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)

            if !hasAnyValue {
                Button(PPAccessoryViewerL10n.text("accessory_view_colors_retry")) {
                    store.retryVariants()
                }
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(PPAccessoryPalette.brand)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .disabled(!store.canChangeVariant)
            }
        }
    }

    // MARK: Choice control

    private func choice(
        _ value: PPAccessoryViewerOptionValue,
        status: PPAccessoryViewerOptionValueStatus
    ) -> some View {
        let isSelected = status == .selected
        let isPending = !isSelected &&
            store.pendingVariant?.selectedOptions[option.id] == value.id
        let isEnabled = store.canChangeVariant && status.isActionable

        return Button {
            store.selectOptionValue(optionId: option.id, valueId: value.id)
        } label: {
            chip(value: value, status: status, isSelected: isSelected, isPending: isPending)
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.97))
        .disabled(!isEnabled)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityLabel(for: value, status: status))
        .accessibilityValue(
            accessibilityValue(for: status, pending: isPending)
        )
        .accessibilityHint(accessibilityHint(for: status))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(
            "pp.accessory.option.\(option.id).\(value.id)"
        )
    }

    @ViewBuilder
    private func chip(
        value: PPAccessoryViewerOptionValue,
        status: PPAccessoryViewerOptionValueStatus,
        isSelected: Bool,
        isPending: Bool
    ) -> some View {
        let isColor = option.isColor && value.swatchComponents != nil
        let shape = RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)

        HStack(spacing: PPSpace.xs) {
            if isColor, let swatch = value.swatchComponents {
                Circle()
                    .fill(Color(red: swatch.red, green: swatch.green, blue: swatch.blue))
                    .frame(width: 16, height: 16)
                    .overlay {
                        Circle().strokeBorder(
                            PPAccessoryPalette.ink.opacity(0.18),
                            lineWidth: 0.5
                        )
                    }
                    .accessibilityHidden(true)
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.brand)
                    .accessibilityHidden(true)
            } else if isPending {
                ProgressView()
                    .controlSize(.mini)
                    .tint(PPAccessoryPalette.brand)
            }

            Text(PPAccessoryViewerL10n.isolated(value.displayName))
                .font(
                    isSelected
                        ? PPAccessoryTypography.captionBold
                        : PPAccessoryTypography.caption
                )
                .foregroundStyle(
                    status == .notOffered
                        ? PPAccessoryPalette.inkSecondary
                        : (isSelected
                            ? PPAccessoryPalette.brand
                            : PPAccessoryPalette.ink)
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if let unit = value.unitLabel {
                Text(PPAccessoryViewerL10n.isolated(unit))
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .lineLimit(1)
            }

            if let detail = detailText(for: status) {
                Text(detail)
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(
                        status == .outOfStock
                            ? PPAccessoryPalette.warning
                            : PPAccessoryPalette.inkSecondary
                    )
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, PPSpace.sm)
        .frame(height: 36)
        .background(
            isSelected
                ? PPAccessoryPalette.brand.opacity(colorSchemeContrast == .increased ? 0.20 : 0.10)
                : PPAccessorySubviewBackground.quietFill,
            in: shape
        )
        .overlay {
            shape.strokeBorder(
                isSelected
                    ? PPAccessoryPalette.brand
                    : (status == .incompatible
                        ? PPAccessoryPalette.warning.opacity(0.6)
                        : PPAccessorySubviewBackground.faintStroke),
                style: StrokeStyle(
                    lineWidth: isSelected ? 1.5 : 1.0,
                    dash: status == .incompatible ? [3, 2] : []
                )
            )
        }
        .opacity(status == .notOffered ? 0.50 : 1.0)
    }

    /// Short consequence text shown on the control itself, so the customer learns
    /// what a tap will do before making it.
    private func detailText(
        for status: PPAccessoryViewerOptionValueStatus
    ) -> String? {
        switch status {
        case .selected, .available:
            return nil
        case .outOfStock:
            return PPAccessoryViewerL10n.text(
                "accessory_view_option_out_of_stock"
            )
        case .incompatible:
            return PPAccessoryViewerL10n.text("accessory_view_option_adjusts")
        case .notOffered:
            return PPAccessoryViewerL10n.text(
                "accessory_view_option_not_offered"
            )
        }
    }

    private func accessibilityLabel(
        for value: PPAccessoryViewerOptionValue,
        status: PPAccessoryViewerOptionValueStatus
    ) -> String {
        let base = PPAccessoryViewerL10n.formatted(
            "accessory_view_option_value_format",
            option.localizedName,
            PPAccessoryViewerL10n.isolated(value.accessibilityName)
        )

        switch status {
        case .selected:
            return base
        case .available:
            return base
        case .outOfStock:
            return base + PPAccessoryViewerL10n.listSeparator +
                PPAccessoryViewerL10n.text(
                    "accessory_view_option_out_of_stock"
                )
        case .incompatible:
            return base + PPAccessoryViewerL10n.listSeparator +
                PPAccessoryViewerL10n.text("accessory_view_option_adjusts")
        case .notOffered:
            return base + PPAccessoryViewerL10n.listSeparator +
                PPAccessoryViewerL10n.text(
                    "accessory_view_option_not_offered"
                )
        }
    }

    private func accessibilityValue(
        for status: PPAccessoryViewerOptionValueStatus,
        pending: Bool
    ) -> String {
        if pending {
            return PPAccessoryViewerL10n.text("accessory_view_options_loading")
        }
        return status == .selected
            ? PPAccessoryViewerL10n.text("Selected")
            : ""
    }

    private func accessibilityHint(
        for status: PPAccessoryViewerOptionValueStatus
    ) -> String {
        switch status {
        case .incompatible:
            return PPAccessoryViewerL10n.text(
                "accessory_view_option_adjusts_hint"
            )
        case .notOffered:
            return PPAccessoryViewerL10n.text(
                "accessory_view_options_not_offered_caption"
            )
        case .selected, .available, .outOfStock:
            return ""
        }
    }
}

// MARK: - Colour cell

/// A colour is judged by eye, so the sample is the control. The ring carries
/// state and the sample's geometry never changes, which keeps a rail of colours
/// visually still while selection moves through it.
@available(iOS 16.0, *)
private struct PPAccessoryOptionGemCell: View {
    let value: PPAccessoryViewerOptionValue
    let swatch: (red: Double, green: Double, blue: Double)
    let status: PPAccessoryViewerOptionValueStatus
    let pending: Bool
    let detail: String?

    private var isSelected: Bool { status == .selected }

    var body: some View {
        VStack(spacing: PPSpace.xs) {
            PPAccessoryOptionSwatch(
                components: swatch,
                selected: isSelected,
                pending: pending,
                unavailable: status == .notOffered,
                adjusts: status == .incompatible
            )

            Text(PPAccessoryViewerL10n.isolated(value.displayName))
                .font(
                    isSelected
                        ? PPAccessoryTypography.captionBold
                        : PPAccessoryTypography.caption
                )
                .foregroundStyle(
                    isSelected
                        ? PPAccessoryPalette.ink
                        : PPAccessoryPalette.inkSecondary
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(
                        status == .outOfStock
                            ? PPAccessoryPalette.warning
                            : PPAccessoryPalette.inkSecondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, PPSpace.xxs)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .opacity(status == .notOffered ? 0.55 : 1)
        .contentShape(Rectangle())
    }
}

/// The sample's geometry never changes with selection; the ring carries state.
@available(iOS 16.0, *)
private struct PPAccessoryOptionSwatch: View {
    let components: (red: Double, green: Double, blue: Double)
    let selected: Bool
    let pending: Bool
    let unavailable: Bool
    var adjusts: Bool = false
    var diameter: CGFloat = 44

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        Color(red: components.red, green: components.green, blue: components.blue)
    }

    /// Perceptual luminance, so a near-white or near-black sample keeps a visible
    /// edge against the console surface instead of dissolving into it.
    private var luminance: Double {
        0.2126 * components.red +
            0.7152 * components.green +
            0.0722 * components.blue
    }

    private var edge: Color {
        if colorSchemeContrast == .increased {
            return PPAccessoryPalette.ink.opacity(luminance > 0.5 ? 0.55 : 0.35)
        }
        if luminance > 0.78 { return PPAccessoryPalette.ink.opacity(0.26) }
        if luminance < 0.10 { return Color.white.opacity(0.24) }
        return PPAccessoryPalette.ink.opacity(0.12)
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(PPAccessoryPalette.brand, lineWidth: 2)
                .opacity(selected ? 1 : 0)
                .scaleEffect(selected ? 1 : 0.84)

            sample

            if unavailable {
                Circle()
                    .fill(
                        PPAccessorySubviewBackground.baseSurface.opacity(0.55)
                    )
                    .padding(5)

                Image(systemName: "slash.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
            }

            if pending {
                Circle()
                    .fill(
                        PPAccessorySubviewBackground.baseSurface.opacity(0.72)
                    )
                    .padding(5)

                ProgressView()
                    .controlSize(.small)
                    .tint(PPAccessoryPalette.brand)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .bottomTrailing) {
            if selected {
                badge(
                    symbol: "checkmark",
                    tint: PPAccessoryPalette.brand,
                    weight: .black
                )
            } else if adjusts {
                badge(
                    symbol: "arrow.triangle.2.circlepath",
                    tint: PPAccessoryPalette.inkSecondary,
                    weight: .bold
                )
            }
        }
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.32, dampingFraction: 0.74),
            value: selected
        )
        .accessibilityHidden(true)
    }

    private var sample: some View {
        Circle()
            .fill(color)
            .overlay {
                // A single light source from the top keeps the sample readable as
                // a physical object without tinting the colour itself.
                Circle().fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.clear,
                            Color.black.opacity(0.07)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                Circle().strokeBorder(edge, lineWidth: 1)
            }
            .padding(5)
    }

    private func badge(
        symbol: String,
        tint: Color,
        weight: Font.Weight
    ) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 8, weight: weight))
            .foregroundStyle(tint)
            .frame(width: 16, height: 16)
            .background(
                PPAccessorySubviewBackground.baseSurface,
                in: Circle()
            )
            .overlay {
                Circle().strokeBorder(tint.opacity(0.35), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Spec tile

/// A non-colour value is read, not seen, so the value itself is the hero and the
/// unit sits under it. The viewer used to print the value and its unit together
/// as "250g (g)"; the unit now appears only when the value is a bare quantity.
@available(iOS 16.0, *)
private struct PPAccessoryOptionSpecTile: View {
    let value: PPAccessoryViewerOptionValue
    let status: PPAccessoryViewerOptionValueStatus
    let pending: Bool
    let detail: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSelected: Bool { status == .selected }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                Text(PPAccessoryViewerL10n.isolated(value.displayName))
                    .font(
                        isSelected
                            ? PPAccessoryTypography.bodyBold
                            : PPAccessoryTypography.body
                    )
                    .foregroundStyle(
                        status == .notOffered
                            ? PPAccessoryPalette.inkSecondary
                            : PPAccessoryPalette.ink
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                glyph
            }

            if let unit = value.unitLabel {
                Text(PPAccessoryViewerL10n.isolated(unit))
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .lineLimit(1)
            }

            if let detail {
                Text(detail)
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(
                        status == .outOfStock
                            ? PPAccessoryPalette.warning
                            : PPAccessoryPalette.inkSecondary
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 56, alignment: .leading)
        .background(fill, in: shape)
        .overlay {
            shape.strokeBorder(stroke, style: strokeStyle)
        }
        .shadow(
            color: isSelected
                ? PPAccessoryPalette.brand.opacity(0.16)
                : Color.clear,
            radius: isSelected ? 9 : 0,
            y: isSelected ? 4 : 0
        )
        .contentShape(shape)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.30, dampingFraction: 0.86),
            value: isSelected
        )
    }

    @ViewBuilder
    private var glyph: some View {
        ZStack {
            if pending {
                ProgressView()
                    .controlSize(.mini)
                    .tint(PPAccessoryPalette.brand)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(PPAccessoryPalette.brand)
            } else if status == .incompatible {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        if isSelected {
            return PPAccessoryPalette.brand.opacity(
                colorScheme == .dark ? 0.20 : 0.09
            )
        }
        if status == .notOffered {
            return Color.clear
        }
        return PPAccessorySubviewBackground.quietFill
    }

    private var stroke: Color {
        if isSelected { return PPAccessoryPalette.brand }
        if colorSchemeContrast == .increased {
            return PPAccessoryPalette.inkSecondary
        }
        return PPAccessorySubviewBackground.controlStroke
    }

    private var strokeStyle: StrokeStyle {
        if status == .incompatible {
            return StrokeStyle(lineWidth: 1, dash: [4, 3])
        }
        return StrokeStyle(lineWidth: isSelected ? 1.5 : 1)
    }
}

// MARK: - List row

/// Quiet list anatomy for full combinations and accessibility text sizes.
@available(iOS 16.0, *)
private struct PPAccessoryOptionChoiceLabel: View {
    let title: String
    let detail: String?
    var unit: String? = nil
    let swatch: (red: Double, green: Double, blue: Double)?
    let selected: Bool
    let pending: Bool
    let unavailable: Bool
    var adjusts: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            if let swatch {
                PPAccessoryOptionSwatch(
                    components: swatch,
                    selected: selected,
                    pending: pending,
                    unavailable: unavailable,
                    adjusts: adjusts,
                    diameter: 40
                )
            }

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(title)
                    .font(
                        selected
                            ? PPAccessoryTypography.calloutBold
                            : PPAccessoryTypography.callout
                    )
                    .foregroundStyle(
                        unavailable
                            ? PPAccessoryPalette.inkSecondary
                            : PPAccessoryPalette.ink
                    )
                    .fixedSize(horizontal: false, vertical: true)

                if let unit {
                    Text(PPAccessoryViewerL10n.isolated(unit))
                        .font(PPAccessoryTypography.caption2)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)
                }

                if let detail {
                    Text(detail)
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if swatch == nil {
                ZStack {
                    if pending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PPAccessoryPalette.brand)
                    } else if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(PPAccessoryPalette.brand)
                    } else if adjusts {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    }
                }
                .frame(width: 24)
                .accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, PPSpace.sm)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PPAccessorySubviewBackground.faintStroke)
                .frame(height: 0.5)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Resolution bar

/// The receipt of the configuration: which sellable product the current choices
/// resolve to, whether it can be bought, and how the customer recovers when a
/// choice fails. Pending and failure states render here rather than as floating
/// text, so feedback always appears where identity is stated.
@available(iOS 16.0, *)
private struct PPAccessoryVariantResolutionBar: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot
    var compact: Bool = true

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            receipt

            if let pending = store.pendingVariant {
                pendingRow(pending)
            }

            if let message = store.variantSelectionError {
                failureRow(message)
            }
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, compact ? PPSpace.sm : PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PPAccessorySubviewBackground.quietFill,
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .strokeBorder(
                    PPAccessorySubviewBackground.faintStroke,
                    lineWidth: 1
                )
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.24),
            value: store.switchingVariantProductId
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: Receipt

    @ViewBuilder
    private var receipt: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                receiptIdentity
                availabilityBadge
            }
        } else {
            HStack(alignment: .center, spacing: PPSpace.sm) {
                receiptIdentity
                Spacer(minLength: PPSpace.sm)
                availabilityBadge
            }
        }
    }

    private var receiptIdentity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_options_resolved_label"
                )
            )
            .font(PPAccessoryTypography.caption2)
            .foregroundStyle(PPAccessoryPalette.inkSecondary)

            Text(summaryText)
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let sku = store.currentVariant?.sku, !sku.isEmpty {
                Text(
                    PPAccessoryViewerL10n.formatted(
                        "accessory_view_option_sku_format",
                        PPAccessoryViewerL10n.isolated(sku)
                    )
                )
                .font(PPAccessoryTypography.caption2)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_option_details")
        )
        .accessibilityValue(summaryText)
    }

    private var summaryText: String {
        if let current = store.currentVariant {
            return store.optionSummary(for: current)
        }
        return snapshot.title.isEmpty
            ? PPAccessoryViewerL10n.text("accessory_view_option_unnamed")
            : PPAccessoryViewerL10n.isolated(snapshot.title)
    }

    // MARK: Availability

    private var availabilityBadge: some View {
        let state = availabilityState

        return HStack(spacing: 5) {
            Image(systemName: state.symbol)
                .font(.system(size: 11, weight: .bold))
                .accessibilityHidden(true)

            Text(state.text)
                .font(PPAccessoryTypography.captionBold)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(state.tone)
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, 5)
        .background(
            state.tone.opacity(colorSchemeContrast == .increased ? 0.20 : 0.11),
            in: Capsule(style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private struct AvailabilityState {
        let text: String
        let symbol: String
        let tone: Color
    }

    /// Only the loaded product's live snapshot can describe availability.
    private var availabilityState: AvailabilityState {
        if store.livePhase == .stale || store.livePhase == .refreshing {
            return AvailabilityState(
                text: PPAccessoryViewerL10n.text(
                    "accessory_view_options_check_availability"
                ),
                symbol: "arrow.triangle.2.circlepath",
                tone: PPAccessoryPalette.warning
            )
        }
        if store.livePhase == .deleted ||
            snapshot.isUnavailable ||
            snapshot.accessory.variantIsArchived ||
            store.currentVariant?.isArchived == true {
            return AvailabilityState(
                text: PPAccessoryViewerL10n.text(
                    "accessory_view_item_unavailable"
                ),
                symbol: "xmark.octagon.fill",
                tone: PPAccessoryPalette.error
            )
        }
        if snapshot.quantity <= 0 {
            return AvailabilityState(
                text: PPAccessoryViewerL10n.text(
                    "accessory_view_option_out_of_stock"
                ),
                symbol: "exclamationmark.triangle.fill",
                tone: PPAccessoryPalette.error
            )
        }

        let remaining = store.remainingStock
        return AvailabilityState(
            text: PPAccessoryViewerL10n.formatted(
                "accessory_view_remaining_text_format",
                PPAccessoryViewerL10n.integer(remaining)
            ),
            symbol: remaining <= 3
                ? "exclamationmark.circle.fill"
                : "checkmark.circle.fill",
            tone: remaining <= 3
                ? PPAccessoryPalette.warning
                : PPAccessoryPalette.success
        )
    }

    // MARK: In-flight and failure

    private func pendingRow(
        _ pending: PPAccessoryViewerVariant
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(alignment: .top, spacing: PPSpace.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(PPAccessoryPalette.brand)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_options_resolving_label"
                        )
                    )
                    .font(PPAccessoryTypography.caption2)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)

                    Text(store.optionSummary(for: pending))
                        .font(PPAccessoryTypography.calloutBold)
                        .foregroundStyle(PPAccessoryPalette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(
                PPAccessoryViewerL10n.text("accessory_view_keep_selection")
            ) {
                store.cancelVariantSelection()
            }
            .font(PPAccessoryTypography.calloutBold)
            .foregroundStyle(PPAccessoryPalette.brand)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
        }
        .padding(.top, PPSpace.xs)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PPAccessorySubviewBackground.faintStroke)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private func failureRow(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(alignment: .top, spacing: PPSpace.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.warning)
                    .accessibilityHidden(true)

                Text(message)
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: PPSpace.lg) {
                Button(
                    PPAccessoryViewerL10n.text("accessory_view_colors_retry")
                ) {
                    store.retryVariantSelection()
                }
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.brand)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .disabled(!store.canChangeVariant)

                Button(
                    PPAccessoryViewerL10n.text("accessory_view_keep_selection")
                ) {
                    store.cancelVariantSelection()
                }
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }
        }
        .padding(.top, PPSpace.xs)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PPAccessorySubviewBackground.faintStroke)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Content-sized wrapping keeps short sizes compact and long labels readable.
/// SwiftUI mirrors Layout placement in RTL; these offsets must not mirror twice.
@available(iOS 16.0, *)
private struct PPAccessoryChoiceFlowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    private struct Placement {
        let size: CGSize
        let leading: CGFloat
        let top: CGFloat
    }

    private func placements(width: CGFloat, subviews: Subviews) -> [Placement] {
        let available = max(width, 1)
        var result: [Placement] = []
        var leading: CGFloat = 0
        var top: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let size = subview.sizeThatFits(ProposedViewSize(width: min(ideal.width, available), height: nil))
            if leading > 0 && leading + size.width > available {
                leading = 0
                top += rowHeight + rowSpacing
                rowHeight = 0
            }
            result.append(Placement(size: size, leading: leading, top: top))
            leading += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let idealWidth = subviews.reduce(CGFloat.zero) { $0 + $1.sizeThatFits(.unspecified).width }
            + CGFloat(max(0, subviews.count - 1)) * spacing
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        let items = placements(width: width, subviews: subviews)
        return CGSize(width: max(width, 0), height: items.map { $0.top + $0.size.height }.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let items = placements(width: bounds.width, subviews: subviews)
        for (index, item) in items.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + item.leading, y: bounds.minY + item.top), anchor: .topLeading,
                proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
            )
        }
    }
}

/// Backwards-compatible entry point; the Store remains the selection owner.
@available(iOS 16.0, *)
typealias PPAccessoryColorRail = PPAccessoryVariantSelectorSection



// MARK: - Commerce dock

/// The bottom cart.
///
/// The old dock restated what the screen already said — thumbnail, title, unit
/// price — and then offered two competing full-width buttons while the one control
/// the decision actually needs, quantity, was missing entirely. This is built the
/// other way round: one rail that holds *adjust*, *commit* and *shortcut* in a
/// single line of reading, where the number on the commit control is the number the
/// customer is about to spend. A second line appears only when there is something
/// true to say about it.
///
/// The Store remains the only owner of cart and checkout state; this view owns
/// nothing but the presentation of its own in-flight commit.
@available(iOS 16.0, *)
private struct PPAccessoryCommerceDock: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot
    let compact: Bool

    private enum CommitPhase: Equatable {
        case idle
        case working
        case succeeded
        case failed
    }

    @State private var commitPhase: CommitPhase = .idle
    @State private var commitTask: Task<Void, Never>?
    @State private var retryAction: (() -> Void)?
    @State private var failureMessage: String?
    @State private var floodScale: CGFloat = 0.62
    @State private var floodOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Mode

    /// Once a line exists in the cart the stepper stops meaning "how many to add"
    /// and starts meaning "how many I have". Two readings of one control is a
    /// usability defect, so the whole dock switches mode and says which it is.
    private var editsCartLine: Bool {
        store.cartQuantity > 0
    }

    private var quantity: Int {
        editsCartLine ? store.cartQuantity : store.quantity
    }

    private var maximumQuantity: Int {
        editsCartLine
            ? store.cartQuantity + store.remainingStock
            : max(store.remainingStock, 1)
    }

    private var isInteractive: Bool {
        store.switchingVariantProductId == nil &&
            store.cartPhase != .processing &&
            !store.isCheckoutProcessing &&
            commitPhase != .working
    }

    private var canIncrease: Bool {
        isInteractive && quantity < maximumQuantity
    }

    private var canDecrease: Bool {
        isInteractive && quantity > 1
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            rail

            if let ribbon = ribbonState {
                ribbonRow(ribbon)
            }
        }
        .padding(PPBottomDecisionBarGeometry.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { PPAccessoryBottomFaceSurface(isCommerce: true) }
        .animation(
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.90),
            value: ribbonState
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88),
            value: commitPhase
        )
        .onDisappear { commitTask?.cancel() }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var rail: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: PPSpace.sm) {
                stepper
                    .frame(maxWidth: .infinity)
                commitControl
                if showsShortcut {
                    shortcutControl(expanded: true)
                }
            }
        } else {
            HStack(spacing: PPBottomDecisionBarGeometry.controlSpacing) {
                stepper
                commitControl
                    .frame(maxWidth: .infinity)
                if showsShortcut {
                    shortcutControl(expanded: false)
                }
            }
        }
    }

    // MARK: Stepper

    /// Adjust. A capsule, deliberately a different shape language from the commit
    /// control, so the hand learns the difference without reading.
    private var stepper: some View {
        HStack(spacing: 0) {
            stepperButton(
                symbol: "minus",
                enabled: canDecrease,
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_decrease_quantity"
                )
            ) {
                change(by: -1)
            }

            Text(PPAccessoryViewerL10n.integer(quantity))
                .font(PPAccessoryTypography.bodyBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 26)
                .accessibilityHidden(true)

            stepperButton(
                symbol: "plus",
                enabled: canIncrease,
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_increase_quantity"
                )
            ) {
                change(by: 1)
            }
        }
        .frame(height: PPBottomDecisionBarGeometry.controlHeight)
        .background(
            PPAccessorySubviewBackground.baseSurface,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous).strokeBorder(
                colorSchemeContrast == .increased
                    ? PPAccessoryPalette.brand.opacity(0.55)
                    : PPAccessoryPalette.brand.opacity(0.20),
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            PPAccessoryViewerL10n.formatted(
                "accessory_view_option_value_format",
                PPAccessoryViewerL10n.text(
                    editsCartLine ? "InCart" : "accessory_view_quantity"
                ),
                PPAccessoryViewerL10n.integer(quantity)
            )
        )
        .accessibilityIdentifier("pp.accessory.dock.stepper")
    }

    private func stepperButton(
        symbol: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(
                    enabled
                        ? PPAccessoryPalette.brand
                        : PPAccessoryPalette.inkSecondary.opacity(0.45)
                )
                .frame(width: 42, height: PPBottomDecisionBarGeometry.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.88))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func change(by delta: Int) {
        guard isInteractive else { return }
        let target = quantity + delta
        guard target >= 1, target <= maximumQuantity else { return }

        if editsCartLine {
            runCartLineUpdate(to: target)
            return
        }

        withAnimation(
            reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.86)
        ) {
            if delta > 0 {
                store.incrementQuantity()
            } else {
                store.decrementQuantity()
            }
        }
    }

    // MARK: Commit

    /// Commit. Carries the live total for the current quantity, so the amount on
    /// the control is the amount being committed to.
    private var commitControl: some View {
        let shape = RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )
        let enabled = commitIsEnabled

        return Button(action: primaryAction) {
            HStack(spacing: PPSpace.sm) {
                commitGlyph

                VStack(alignment: .leading, spacing: 0) {
                    Text(commitTitle)
                        .font(PPAccessoryTypography.bodyBold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    if let detail = commitDetail {
                        Text(detail)
                            .font(PPAccessoryTypography.caption)
                            .opacity(0.92)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .priceHaloTransition(
                                pulseToken: store.pricePulseToken
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.base)
            .frame(
                maxWidth: .infinity,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .background(commitTone, in: shape)
            .overlay {
                // One-shot flood confirming the write landed. Never decorative:
                // it is the only non-textual signal that the cart changed.
                shape
                    .fill(PPAccessoryPalette.success)
                    .scaleEffect(floodScale)
                    .opacity(floodOpacity)
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityLabel(commitAccessibilityLabel)
        .accessibilityHint(
            PPAccessoryViewerL10n.text(
                editsCartLine
                    ? "accessory_view_dock_cart_hint"
                    : "accessory_view_dock_commit_hint"
            )
        )
        .accessibilityIdentifier("pp.accessory.dock.commit")
    }

    @ViewBuilder
    private var commitGlyph: some View {
        ZStack {
            switch commitPhase {
            case .working:
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.white)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .black))
            case .failed:
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .black))
            case .idle:
                Image(
                    systemName: editsCartLine ? "cart.fill" : "cart.badge.plus"
                )
                .font(.system(size: 16, weight: .bold))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }

    private var commitTitle: String {
        switch commitPhase {
        case .working:
            return PPAccessoryViewerL10n.text(
                editsCartLine
                    ? "accessory_view_updating_cart_quantity"
                    : "accessory_view_adding_to_cart"
            )
        case .succeeded:
            return PPAccessoryViewerL10n.text("AddedToCart")
        case .failed:
            return PPAccessoryViewerL10n.text("Retry")
        case .idle:
            return PPAccessoryViewerL10n.text(
                editsCartLine
                    ? "accessory_view_open_cart"
                    : "accessory_view_add_to_cart"
            )
        }
    }

    private var commitDetail: String? {
        guard commitPhase == .idle else { return nil }
        let value = editsCartLine
            ? store.checkoutCartSubtotalText
            : store.totalPriceText
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : PPAccessoryViewerL10n.isolated(clean)
    }

    private var commitTone: Color {
        switch commitPhase {
        case .succeeded:
            return PPAccessoryPalette.success
        case .failed:
            return PPAccessoryPalette.error
        case .idle, .working:
            return PPAccessoryPalette.brand
        }
    }

    private var commitAccessibilityLabel: String {
        guard let detail = commitDetail else { return commitTitle }
        return commitTitle + PPAccessoryViewerL10n.listSeparator + detail
    }

    private var commitIsEnabled: Bool {
        guard isInteractive || commitPhase == .failed else { return false }
        if editsCartLine { return true }
        return store.remainingStock > 0 &&
            store.hasResolvedVariantOptions &&
            store.checkoutPreviewCanCommit &&
            store.isPurchaseDataCurrent &&
            !snapshot.isUnavailable
    }

    private func primaryAction() {
        if commitPhase == .failed {
            let retry = retryAction
            commitPhase = .idle
            failureMessage = nil
            retry?()
            return
        }

        guard isInteractive else { return }

        if editsCartLine {
            store.openCart()
            return
        }

        runAddToCart()
    }

    // MARK: Shortcut

    /// Direct payment stays available but stops competing for attention: the
    /// customer's primary intent on a product screen is the cart.
    private var showsShortcut: Bool {
        store.remainingStock > 0 || store.isCheckoutProcessing
    }

    private var shortcutIsEnabled: Bool {
        isInteractive &&
            store.remainingStock > 0 &&
            store.hasResolvedVariantOptions &&
            store.checkoutPreviewCanCommit &&
            store.isPurchaseDataCurrent &&
            !snapshot.isUnavailable
    }

    private func shortcutControl(expanded: Bool) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PPBottomDecisionBarGeometry.controlRadius,
            style: .continuous
        )

        return Button(action: store.payNow) {
            HStack(spacing: PPSpace.sm) {
                ZStack {
                    if store.isCheckoutProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PPAccessoryPalette.brand)
                    } else {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

                if expanded {
                    Text(PPAccessoryViewerL10n.text("accessory_view_buy_now"))
                        .font(PPAccessoryTypography.bodyBold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(PPAccessoryPalette.brand)
            .padding(.horizontal, expanded ? PPSpace.base : 0)
            .frame(
                minWidth: expanded
                    ? nil
                    : PPBottomDecisionBarGeometry.utilityControlSize,
                maxWidth: expanded ? .infinity : nil,
                minHeight: PPBottomDecisionBarGeometry.controlHeight
            )
            .background(
                PPAccessorySubviewBackground.baseSurface,
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    PPAccessoryPalette.brand.opacity(
                        colorSchemeContrast == .increased ? 0.60 : 0.26
                    ),
                    lineWidth: 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(PPBottomDecisionPressStyle())
        .disabled(!shortcutIsEnabled)
        .opacity(shortcutIsEnabled ? 1 : 0.5)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text(
                store.isCheckoutProcessing
                    ? "accessory_view_opening_payment"
                    : "accessory_view_buy_now"
            )
        )
        .accessibilityIdentifier("pp.accessory.dock.buynow")
    }

    // MARK: Ribbon

    private struct RibbonState: Equatable {
        enum Tone: Equatable {
            case failure
            case caution
            case quiet
        }

        let id: String
        let symbol: String
        let text: String
        let tone: Tone
        let opensCart: Bool
    }

    /// One line at a time, highest-stakes first. Silence is the default so the dock
    /// stays a single row whenever it has nothing to add.
    private var ribbonState: RibbonState? {
        if let failureMessage, commitPhase == .failed {
            return RibbonState(
                id: "failure",
                symbol: "exclamationmark.triangle.fill",
                text: failureMessage,
                tone: .failure,
                opensCart: false
            )
        }

        if !editsCartLine, let reason = blockedReason {
            return RibbonState(
                id: "blocked",
                symbol: "info.circle.fill",
                text: reason,
                tone: .caution,
                opensCart: false
            )
        }

        if quantity >= maximumQuantity, maximumQuantity > 1 {
            return RibbonState(
                id: "max",
                symbol: "tray.full.fill",
                text: PPAccessoryViewerL10n.text(
                    "accessory_view_dock_max_reached"
                ),
                tone: .caution,
                opensCart: false
            )
        }

        if editsCartLine {
            return RibbonState(
                id: "cart",
                symbol: "cart.fill",
                text: PPAccessoryViewerL10n.formatted(
                    "accessory_view_cart_items_format",
                    PPAccessoryViewerL10n.integer(
                        max(store.cartItemsCount, store.cartQuantity)
                    )
                ),
                tone: .quiet,
                opensCart: true
            )
        }

        if store.remainingStock > 0 {
            return RibbonState(
                id: "remaining",
                symbol: "shippingbox.fill",
                text: PPAccessoryViewerL10n.formatted(
                    "accessory_view_remaining_text_format",
                    PPAccessoryViewerL10n.integer(store.remainingStock)
                ),
                tone: .quiet,
                opensCart: false
            )
        }

        return nil
    }

    private var blockedReason: String? {
        if !store.hasResolvedVariantOptions {
            return PPAccessoryViewerL10n.text(
                "accessory_view_selection_needed"
            )
        }
        if store.remainingStock <= 0 {
            return PPAccessoryViewerL10n.text(
                "accessory_view_option_out_of_stock"
            )
        }
        if !store.isPurchaseDataCurrent {
            return PPAccessoryViewerL10n.text(
                "accessory_view_options_check_availability"
            )
        }
        return nil
    }

    @ViewBuilder
    private func ribbonRow(_ state: RibbonState) -> some View {
        let tone = ribbonTone(state.tone)

        HStack(spacing: PPSpace.xs) {
            Image(systemName: state.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tone)
                .accessibilityHidden(true)

            Text(state.text)
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(
                    state.tone == .quiet
                        ? PPAccessoryPalette.inkSecondary
                        : tone
                )
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: PPSpace.xs)

            if state.opensCart {
                Button(action: store.openCart) {
                    HStack(spacing: 3) {
                        Text(
                            PPAccessoryViewerL10n.text(
                                "accessory_view_open_cart"
                            )
                        )
                        .font(PPAccessoryTypography.captionBold)

                        Image(systemName: "chevron.forward")
                            .font(.system(size: 9, weight: .black))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(PPAccessoryPalette.brand)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    PPAccessoryViewerL10n.text("accessory_view_open_cart")
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(
            reduceMotion
                ? .opacity
                : .opacity.combined(with: .move(edge: .bottom))
        )
        .accessibilityElement(children: .contain)
    }

    private func ribbonTone(_ tone: RibbonState.Tone) -> Color {
        switch tone {
        case .failure:
            return PPAccessoryPalette.error
        case .caution:
            return PPAccessoryPalette.warning
        case .quiet:
            return PPAccessoryPalette.inkSecondary
        }
    }

    // MARK: Mutations

    private func runAddToCart() {
        commitTask?.cancel()
        failureMessage = nil
        commitPhase = .working

        commitTask = Task { @MainActor in
            do {
                _ = try await store.addToCartAsync()
                if Task.isCancelled { return }
                commitPhase = .succeeded
                runFlood()
                try? await Task.sleep(nanoseconds: 1_250_000_000)
                if Task.isCancelled { return }
                commitPhase = .idle
            } catch {
                if Task.isCancelled { return }
                failureMessage = PPAccessoryViewerL10n.text(
                    "accessory_view_add_failed"
                )
                retryAction = runAddToCart
                commitPhase = .failed
            }
        }
    }

    private func runCartLineUpdate(to target: Int) {
        commitTask?.cancel()
        failureMessage = nil
        commitPhase = .working

        commitTask = Task { @MainActor in
            do {
                _ = try await store.updateCartQuantity(target)
                if Task.isCancelled { return }
                commitPhase = .idle
            } catch {
                if Task.isCancelled { return }
                failureMessage = PPAccessoryViewerL10n.text(
                    "accessory_view_cart_quantity_update_failed"
                )
                retryAction = { runCartLineUpdate(to: target) }
                commitPhase = .failed
            }
        }
    }

    private func runFlood() {
        guard !reduceMotion else { return }
        floodScale = 0.62
        floodOpacity = 0.58
        withAnimation(.easeOut(duration: 0.52)) {
            floodScale = 1.08
            floodOpacity = 0.0
        }
    }
}
