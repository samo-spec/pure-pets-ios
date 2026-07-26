import SwiftUI
import UIKit

enum PPAccessoryPalette {
    static let appBackground = Color.clear
    static let shell = Color.clear
    static let ink =
        Color(UIColor(named: "PrimaryTextColor") ?? .label)
    static let inkSecondary =
        Color(UIColor(named: "SecondaryTextColor") ?? .secondaryLabel)

    static let brand =
        Color(UIColor(named: "AppPrimaryColor") ?? .systemPink)
    static let brandDarker =
        Color(
            UIColor(named: "AppPrimaryColorDarker") ??
                UIColor(named: "AppPrimaryColor") ??
                .systemPink
        )
    static let brandShine =
        Color(
            UIColor(named: "AppPrimaryColorShainer") ??
                UIColor(named: "AppPrimaryColor") ??
                .systemPink
        )
    static let accent = brand
    static let success =
        Color(UIColor(named: "SuccessColor") ?? .systemGreen)
    static let warning =
        Color(UIColor(named: "WarningColor") ?? .systemOrange)
    static let error =
        Color(UIColor(named: "ErrorColor") ?? .systemRed)

    static let sea = accent
    static let deepSea = ink
    static let sand = appBackground
}

enum PPAccessorySubviewBackground {
    static let clear = Color.clear
    static let baseSurface =
        Color(UIColor(named: "AppForegroundColor") ?? .secondarySystemBackground)
    static let basePage =
        Color(UIColor(named: "AppBackgroundColor") ?? .systemBackground)

    static let chromeFill = baseSurface.opacity(0.78)
    static let quietFill = baseSurface.opacity(0.58)
    static let mediaFill = baseSurface.opacity(0.42)
    static let iconFill = baseSurface.opacity(0.64)
    static let bottomBarFill = baseSurface.opacity(0.86)
    static let dangerFill = PPAccessoryPalette.error.opacity(0.08)
    static let fullScreenChromeFill = basePage.opacity(0.86)
    static let videoChromeFill = Color.black.opacity(0.66)

    static let faintStroke = PPAccessoryPalette.ink.opacity(0.08)
    static let controlStroke = PPAccessoryPalette.ink.opacity(0.12)
    static let chromeStroke = PPAccessoryPalette.ink.opacity(0.14)
    static let divider = PPAccessoryPalette.ink.opacity(0.07)
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

enum PPAccessoryTypography {
    static let hero = Font.custom(
        "Beiruti-Bold",
        size: 34,
        relativeTo: .largeTitle
    )
    static let title = Font.custom(
        "Beiruti-Bold",
        size: 25,
        relativeTo: .title2
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

    var body: some View {
        HStack(spacing: 12) {
            glassButton(
                symbol: PPAccessoryViewerLegacyBridge.isRTL()
                    ? "chevron.right"
                    : "chevron.left",
                label: PPAccessoryViewerL10n.text("Back"),
                action: store.close
            )

            Spacer()

            if store.favoritePhase == .loading {
                ProgressView()
                    .tint(PPAccessoryPalette.ink)
                    .frame(width: 48, height: 48)
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
                glassButton(
                    symbol: store.isFavorite ? "heart.fill" : "heart",
                    label: store.isFavorite
                        ? PPAccessoryViewerL10n.text("a11y_btn_unfavorite")
                        : PPAccessoryViewerL10n.text("a11y_btn_favorite"),
                    tint: store.isFavorite
                        ? PPAccessoryPalette.error
                        : PPAccessoryPalette.ink,
                    action: store.toggleFavorite
                )
            }

            glassButton(
                symbol: "square.and.arrow.up",
                label: PPAccessoryViewerL10n.text("Share"),
                action: store.share
            )
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func glassButton(
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
            .frame(width: 48, height: 48)
            .accessibilityLabel(label)
        } else {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
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
        VStack(spacing: showsGalleryRail ? (compact ? 10 : 12) : 0) {
            ZStack(alignment: .bottom) {
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
            }
            .frame(height: mediaHeight)
            .clipShape(galleryShape)
            .overlay {
                galleryShape
                    .stroke(PPAccessoryPalette.ink.opacity(0.08), lineWidth: 1)
            }

            if showsGalleryRail {
                galleryRail
            }
        }
        .frame(height: height)
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
        height - (showsGalleryRail ? (compact ? 62 : 68) : 0)
    }

    private var gallerySurface: some View {
        PPAccessorySubviewBackground.mediaFill
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
    let snapshot: PPAccessoryViewerSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                title
                Spacer(minLength: 10)
                price
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, compact ? 4 : 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PPAccessorySubviewBackground.divider)
                .frame(height: 1)
                .offset(y: compact ? 10 : 13)
        }
        .accessibilityElement(children: .contain)
    }

    private var title: some View {
        Text(snapshot.title)
            .font(compact ? PPAccessoryTypography.title : PPAccessoryTypography.hero)
            .foregroundStyle(PPAccessoryPalette.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.84)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var price: some View {
        VStack(alignment: .leading, spacing: 2) {
            if snapshot.hasDiscount {
                Text(snapshot.originalPrice)
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.brandDarker)
                    .strikethrough()
            }
            Text(snapshot.price)
                .font(PPAccessoryTypography.price)
                .foregroundStyle(PPAccessoryPalette.brandDarker)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .accessibilityElement(children: .combine)
    }

    private var stockColor: Color {
        if snapshot.quantity <= 0 || snapshot.isUnavailable {
            return PPAccessoryPalette.error
        }
        if snapshot.quantity <= 5 {
            return PPAccessoryPalette.warning
        }
        return PPAccessoryPalette.success
    }
}

struct PPAccessoryDecisionRibbon: View {
    let snapshot: PPAccessoryViewerSnapshot
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    accessibleRibbonItem(
                        symbol: "checkmark.seal.fill",
                        title: PPAccessoryViewerL10n.text("Condition"),
                        value: snapshot.condition,
                        color: PPAccessoryPalette.success
                    )
                    horizontalDivider
                    accessibleRibbonItem(
                        symbol: "shippingbox.fill",
                        title: PPAccessoryViewerL10n.text("Availability"),
                        value: snapshot.stock,
                        color: snapshot.quantity > 0
                            ? PPAccessoryPalette.success
                            : PPAccessoryPalette.error
                    )
                    if !snapshot.location.isEmpty {
                        horizontalDivider
                        accessibleRibbonItem(
                            symbol: "mappin.and.ellipse",
                            title: PPAccessoryViewerL10n.text("Location"),
                            value: snapshot.location,
                            color: PPAccessoryPalette.error
                        )
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ribbonItem(
                        symbol: "checkmark.seal.fill",
                        title: PPAccessoryViewerL10n.text("Condition"),
                        value: snapshot.condition,
                        color: PPAccessoryPalette.success
                    )

                    divider

                    ribbonItem(
                        symbol: "shippingbox.fill",
                        title: PPAccessoryViewerL10n.text("Availability"),
                        value: snapshot.stock,
                        color: snapshot.quantity > 0
                            ? PPAccessoryPalette.success
                            : PPAccessoryPalette.error
                    )

                    if !snapshot.location.isEmpty {
                        divider
                        ribbonItem(
                            symbol: "mappin.and.ellipse",
                            title: PPAccessoryViewerL10n.text("Location"),
                            value: snapshot.location,
                            color: PPAccessoryPalette.error
                        )
                    }
                }
            }
        }
        .padding(.vertical, 13)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.quietFill,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            stroke: PPAccessorySubviewBackground.controlStroke
        )
        .accessibilityElement(children: .contain)
    }

    private func accessibleRibbonItem(
        symbol: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.brandDarker)
                Text(value)
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func ribbonItem(
        symbol: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(PPAccessoryPalette.brandDarker)
                .lineLimit(1)
            Text(value)
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 5)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(PPAccessorySubviewBackground.faintStroke)
            .frame(width: 1, height: 52)
            .accessibilityHidden(true)
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(PPAccessorySubviewBackground.faintStroke)
            .frame(height: 1)
            .padding(.horizontal, 14)
            .accessibilityHidden(true)
    }
}

struct PPAccessorySpecReef: View {
    let details: [PPAccessoryViewerDetailItem]
    let compactColumns: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                PPAccessoryViewerL10n.text("accessory_view_details_title"),
                symbol: "water.waves"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(details) { detail in
                        detailPill(detail)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 4)
            }
        }
    }

    private func detailPill(
        _ detail: PPAccessoryViewerDetailItem
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: detail.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color(for: detail.tone))
                .frame(width: 32, height: 32)
                .ppAccessorySubviewBackground(
                    PPAccessorySubviewBackground.iconFill,
                    in: Circle(),
                    stroke: nil
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .lineLimit(1)
                Text(detail.value)
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .ppAccessorySubviewBackground(
            PPAccessorySubviewBackground.quietFill,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func color(for tone: PPAccessoryViewerDetailTone) -> Color {
        switch tone {
        case .sea: return PPAccessoryPalette.accent
        case .sun: return PPAccessoryPalette.warning
        case .coral: return PPAccessoryPalette.error
        case .palm: return PPAccessoryPalette.success
        case .ink: return PPAccessoryPalette.ink
        }
    }
}

struct PPAccessorySourceIsland: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let snapshot: PPAccessoryViewerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                Text(
                    PPAccessoryViewerL10n.text(
                        snapshot.isProviderMarketplace
                            ? "accessory_view_sold_by"
                            : "accessory_view_seller_title"
                    )
                )
                .font(PPAccessoryTypography.headline)
                .foregroundStyle(PPAccessoryPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }

            switch store.ownerPhase {
            case .idle, .loading:
                ownerSkeleton
            case .loaded:
                if let owner = store.owner {
                    ownerContent(owner)
                }
            case .empty:
                fallbackContent
            case let .failed(message):
                inlineRecovery(
                    message: message,
                    action: store.retryOwner
                )
            }
        }
        .padding(.top, 18)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PPAccessorySubviewBackground.divider)
                .frame(height: 1)
        }
    }

    private func ownerContent(_ owner: PPAccessoryViewerOwner) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                PPAccessoryRemoteImageView(
                    urlString: owner.avatarURL,
                    blurHash: nil,
                    contentMode: .fill,
                    accessibilityLabel: owner.name
                )
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(
                        PPAccessoryPalette.ink.opacity(0.10),
                        lineWidth: 1
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(owner.name)
                            .font(PPAccessoryTypography.headline)
                            .foregroundStyle(PPAccessoryPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if owner.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(PPAccessoryPalette.success)
                                .accessibilityLabel(
                                    PPAccessoryViewerL10n.text(
                                        "accessory_view_verified_seller"
                                    )
                                )
                        }
                    }
                    Text(
                        snapshot.isProviderMarketplace
                            ? PPAccessoryViewerL10n.text(
                                "accessory_view_market_badge"
                            )
                            : PPAccessoryViewerL10n.text(
                                "accessory_view_private_seller"
                            )
                    )
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                }

                Spacer(minLength: 0)
            }

            Button(action: store.openSellerProfile) {
                HStack {
                    Label(
                        PPAccessoryViewerL10n.text("View_Profile"),
                        systemImage: "storefront.fill"
                    )
                    .font(PPAccessoryTypography.bodyBold)
                    Spacer()
                    Image(
                        systemName: PPAccessoryViewerLegacyBridge.isRTL()
                            ? "arrow.left"
                            : "arrow.right"
                    )
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(minHeight: 52)
                .ppAccessorySubviewBackground(
                    PPAccessoryPalette.brand,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(PPAccessoryPressStyle())

            HStack(spacing: 10) {
                sourceAction(
                    title: PPAccessoryViewerL10n.text("Chat"),
                    symbol: "message.fill",
                    enabled: owner.isChatAllowed,
                    action: store.chatWithOwner
                )
                if !snapshot.isOwnItem, owner.phoneNumber != nil {
                    sourceAction(
                        title: PPAccessoryViewerL10n.text("Call"),
                        symbol: "phone.fill",
                        enabled: true,
                        action: store.callOwner
                    )
                }
                sourceAction(
                    title: PPAccessoryViewerL10n.text("Share"),
                    symbol: "square.and.arrow.up",
                    enabled: true,
                    action: store.share
                )
            }
        }
    }

    private var fallbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_store_support"
                )
            )
            .font(PPAccessoryTypography.body)
            .foregroundStyle(PPAccessoryPalette.inkSecondary)

            HStack(spacing: 10) {
                sourceAction(
                    title: PPAccessoryViewerL10n.text("Support"),
                    symbol: "message.badge.fill",
                    enabled: true,
                    action: store.openSupport
                )
                sourceAction(
                    title: PPAccessoryViewerL10n.text("Share"),
                    symbol: "square.and.arrow.up",
                    enabled: true,
                    action: store.share
                )
            }
        }
    }

    private var ownerSkeleton: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(PPAccessoryPalette.ink.opacity(0.07))
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 9) {
                Capsule()
                    .fill(PPAccessoryPalette.ink.opacity(0.09))
                    .frame(width: 150, height: 17)
                Capsule()
                    .fill(PPAccessoryPalette.ink.opacity(0.06))
                    .frame(width: 108, height: 13)
            }
            Spacer()
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel(
            PPAccessoryViewerL10n.text("accessory_view_seller_pending")
        )
    }

    private func sourceAction(
        title: String,
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(PPAccessoryTypography.captionBold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .foregroundStyle(PPAccessoryPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 58)
            .ppAccessorySubviewBackground(
                enabled
                    ? PPAccessorySubviewBackground.quietFill
                    : PPAccessorySubviewBackground.quietFill.opacity(0.54),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                stroke: PPAccessoryPalette.ink.opacity(enabled ? 0.08 : 0.04)
            )
        }
        .buttonStyle(PPAccessoryPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.52)
    }

    private func inlineRecovery(
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(PPAccessoryPalette.warning)
            Text(message)
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
            Spacer()
            Button(PPAccessoryViewerL10n.text("Retry"), action: action)
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(PPAccessoryPalette.accent)
                .frame(minHeight: 44)
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
            placeholderSystemImage: "shippingbox.fill",
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
        .ppBottomDecisionBarSurface()
        .fixedSize(horizontal: false, vertical: true)
        .padding(
            .horizontal,
            compact
                ? PPBottomDecisionBarGeometry.compactScreenInset
                : PPBottomDecisionBarGeometry.regularScreenInset
        )
        .padding(.top, PPSpace.sm)
        .padding(
            .bottom,
            max(
                bottomInset,
                PPBottomDecisionBarGeometry.bottomBreathingRoom
            )
        )
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
                    HStack(spacing: PPBottomDecisionBarGeometry.controlSpacing) {
                        addButton
                        cartButton
                    }
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
                    HStack(spacing: PPBottomDecisionBarGeometry.controlSpacing) {
                        addButton
                        cartButton
                    }
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
                        addButton
                            .frame(maxWidth: 340)
                        cartButton
                    }
                }
            }
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
                    .foregroundStyle(Color("AppForegroundColor"))
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
                Color("AppForegroundColor"),
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
            Text(snapshot.price)
                .font(PPAccessoryTypography.price)
                .foregroundStyle(PPAccessoryPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

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
            Text("\(store.quantity)")
                .font(PPAccessoryTypography.bodyBold)
                .monospacedDigit()
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
        .ppBottomDecisionBarSurface()
        .padding(
            .horizontal,
            compact
                ? PPBottomDecisionBarGeometry.compactScreenInset
                : PPBottomDecisionBarGeometry.regularScreenInset
        )
        .padding(.top, PPSpace.sm)
        .padding(
            .bottom,
            max(
                bottomInset,
                PPBottomDecisionBarGeometry.bottomBreathingRoom
            )
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
