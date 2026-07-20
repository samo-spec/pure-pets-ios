//
//  PPUniversalCellSwiftUI.swift
//  Pure Pets
//
//  SwiftUI presentation for the shared marketplace card. UIKit remains the
//  navigation and business-logic coordinator through PPUniversalCellDelegate.
//

import AVKit
import SwiftUI
import UIKit

// MARK: - Public SwiftUI API

public enum PPUniversalCardContext: Equatable {
    case ads
    case homeAds
    case market
    case food
    case accessory
    case services
    case vets
    case adopt

    var isAdvertisement: Bool {
        self == .ads || self == .homeAds
    }

    var isServiceLike: Bool {
        self == .services || self == .vets
    }

    var isCatalogCommerce: Bool {
        self == .market || self == .food || self == .accessory
    }
}

public enum PPUniversalCardLayout: Equatable {
    case pinterest
    case vertical
    case market
    case fullWidth
    case horizontalRow

    var isHorizontal: Bool {
        self == .fullWidth || self == .horizontalRow
    }
}

public enum PPUniversalCardDiscountStyle: Equatable {
    case badge
    case inline
}

public enum PPUniversalCardGender: String, Equatable {
    case male
    case female
    case undefined
}

public struct PPUniversalCardPalette {
    public var primary: Color
    public var primaryDarker: Color
    public var primaryShiner: Color
    public var diffColor: Color
    public var accent: Color
    public var surface: Color
    public var cardColor: Color
    public var groupedSurface: Color
    public var ink: Color
    public var secondaryInk: Color
    public var success: Color
    public var warning: Color
    public var destructive: Color

    public init(
        primary: Color,
        primaryDarker: Color,
        primaryShiner: Color,
        diffColor: Color,
        accent: Color,
        surface: Color,
        cardColor: Color,
        groupedSurface: Color,
        ink: Color,
        secondaryInk: Color,
        success: Color,
        warning: Color,
        destructive: Color
    ) {
        self.primary = primary
        self.primaryDarker = primaryDarker
        self.primaryShiner = primaryShiner
        self.diffColor = diffColor
        self.accent = accent
        self.surface = surface
        self.cardColor = cardColor
        self.groupedSurface = groupedSurface
        self.ink = ink
        self.secondaryInk = secondaryInk
        self.success = success
        self.warning = warning
        self.destructive = destructive
    }

    public static let purePets = PPUniversalCardPalette(
        primary: Color(uiColor: UIColor(named: "AppPrimaryColor") ?? UIColor(red: 0.54, green: 0.08, blue: 0.22, alpha: 1)),
        primaryDarker: Color(uiColor: UIColor(named: "AppPrimaryColorDarker") ?? UIColor(red: 0.50, green: 0.17, blue: 0.24, alpha: 1)),
        primaryShiner: Color(uiColor: UIColor(named: "AppPrimaryColorShainer") ?? UIColor(red: 0.96, green: 0.25, blue: 0.42, alpha: 1)),
        diffColor: Color(uiColor: UIColor(named: "diffColor") ?? UIColor(red: 0.96, green: 0.25, blue: 0.42, alpha: 1)),
        accent: Color(uiColor: .systemTeal),
        surface: Color(uiColor: .secondarySystemGroupedBackground),
        cardColor: Color(uiColor: UIColor(named: "cardColor") ?? UIColor(red: 0.96, green: 0.25, blue: 0.42, alpha: 1)),
        groupedSurface: Color(uiColor: .tertiarySystemGroupedBackground),
        ink: Color(uiColor: .label),
        secondaryInk: Color(uiColor: .secondaryLabel),
        success: Color(uiColor: .systemGreen),
        warning: Color(uiColor: .systemOrange),
        destructive: Color(uiColor: .systemRed)
    )
}

public struct PPUniversalAvailability: Equatable {
    public enum Tone: Equatable {
        case neutral
        case available
        case limited
        case unavailable
        case used
    }

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
    public var gender: PPUniversalCardGender?
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
        gender: PPUniversalCardGender? = nil,
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
        self.gender = gender
        self.isFavorite = isFavorite
        self.isOwner = isOwner
        self.isPubliclyVisible = isPubliclyVisible
        self.isSkeleton = isSkeleton
        self.quantity = max(0, quantity)
        self.stock = stock.map { max(0, $0) }
        self.usesQuantityControl = usesQuantityControl
        self.prefersContainedImage = prefersContainedImage
        self.preferredAspectRatio = preferredAspectRatio
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

@available(iOS 16.0, *)
public struct PPUniversalCardView: View {
    @StateObject private var store: PPUniversalCardStore

    public init(
        model: PPUniversalCardModel,
        context: PPUniversalCardContext,
        layout: PPUniversalCardLayout,
        discountStyle: PPUniversalCardDiscountStyle = .badge,
        palette: PPUniversalCardPalette = .purePets,
        actions: PPUniversalCardActions = .init()
    ) {
        _store = StateObject(
            wrappedValue: PPUniversalCardStore(
                model: model,
                context: context,
                layout: layout,
                discountStyle: discountStyle,
                palette: palette,
                actions: actions
            )
        )
    }

    public var body: some View {
        PPUniversalCardRenderer(store: store)
            .frame(minHeight: minimumHeight)
    }

    private var minimumHeight: CGFloat {
        if store.layout.isHorizontal {
            return 184
        }
        if store.model.isSkeleton && store.context.isCatalogCommerce {
            return 292
        }
        return 340
    }
}

// MARK: - Stable State

private final class PPUniversalUIKitReferences {
    weak var imageView: UIImageView?
    weak var imageContainer: PPUniversalGradientView?
    weak var tapHaloLayer: CAGradientLayer?
}

@available(iOS 16.0, *)
@MainActor
private final class PPUniversalCardStore: ObservableObject {
    @Published var model: PPUniversalCardModel
    @Published var context: PPUniversalCardContext
    @Published var layout: PPUniversalCardLayout
    @Published var discountStyle: PPUniversalCardDiscountStyle
    @Published var quantity: Int
    @Published var isEditingQuantity = false
    @Published var isNotifyInFlight = false
    @Published var notifySucceeded = false
    @Published var isVideoPlaying = false
    @Published var player: AVPlayer?
    @Published var isHighlighted = false
    @Published var isSelected = false
    @Published var isRightToLeft: Bool
    @Published var isSuggestionsAd = false
    @Published var isNearbyAdsSection = false
    @Published var userBordersV2 = true
    @Published var isHomePresentation = false
    @Published var showsOwnerRow = false
    @Published var isContextFocused = false
    @Published var isSavedForLater = false

    let palette: PPUniversalCardPalette
    let uiReferences = PPUniversalUIKitReferences()

    weak var delegate: PPUniversalCellDelegate?
    var viewModel: PPUniversalCellViewModel?
    var imageLoader: PPImageLoader?
    var imagePlaceholder: UIImage?
    var imageSignature = ""
    var favoriteCollection = "favoritesAds"
    var showsFavorite = false
    var showsSaveForLater = false
    var showsOwnerMenu = false
    var cardTap: (() -> Void)?
    var actions: PPUniversalCardActions

    private static let nearbyAdsPPSectionRawValue = 5

    private var collapseTask: Task<Void, Never>?
    private var notifyItemID: String?

    init(
        model: PPUniversalCardModel,
        context: PPUniversalCardContext,
        layout: PPUniversalCardLayout,
        discountStyle: PPUniversalCardDiscountStyle,
        palette: PPUniversalCardPalette,
        actions: PPUniversalCardActions
    ) {
        self.model = model
        self.context = context
        self.layout = layout
        self.discountStyle = discountStyle
        self.palette = palette
        self.actions = actions
        self.quantity = model.quantity
        self.isRightToLeft = PPUniversalCellSwiftUIBridge.isRightToLeft()
    }

    deinit {
        collapseTask?.cancel()
    }

    func configure(
        viewModel: PPUniversalCellViewModel,
        context objcContext: PPCellContext,
        layout objcLayout: PPManagerCellLayoutMode,
        discountStyle objcDiscountStyle: PPDiscountStyle,
        imageLoader: PPImageLoader?,
        hideTopBadge: Bool,
        showsSubtitle: Bool,
        forceShowsOwnerMenuButton: Bool,
        dataViewPresentation: Bool
    ) {
        let previousID = model.id
        updatePresentationHost(delegate)
        let isAdLike = PPUniversalCellSwiftUIBridge.isAdvertisementViewModel(viewModel)
        let isSuggestions = PPUniversalCellSwiftUIBridge.isSuggestionsSection(for: viewModel, delegate: self.delegate)
        let isSuggestionsAd = isSuggestions && isAdLike
        self.isSuggestionsAd = isSuggestionsAd
        self.isNearbyAdsSection = viewModel.ppSection.rawValue == Self.nearbyAdsPPSectionRawValue

        let resolvedLayout = Self.resolvedLayout(
            objcLayout,
            viewModel: viewModel,
            dataViewPresentation: dataViewPresentation,
            isSuggestionsAd: isSuggestionsAd
        )
        let horizontal = resolvedLayout.isHorizontal
        let resolvedContext = Self.cardContext(objcContext)
        let stableID = viewModel.modelID?.isEmpty == false
            ? viewModel.modelID!
            : "model-\(Unmanaged.passUnretained(viewModel).toOpaque())"

        let usesQuantity =
            PPUniversalCellSwiftUIBridge.usesQuantityControl(for: viewModel)
        let stock = usesQuantity
            ? PPUniversalCellSwiftUIBridge.stockLimit(for: viewModel)
            : nil
        let cartQuantity = usesQuantity
            ? PPUniversalCellSwiftUIBridge.cartQuantity(for: viewModel)
            : 0
        let supportsDiscount =
            PPUniversalCellSwiftUIBridge.showsDiscountPresentation(for: viewModel)
        let finalPrice = viewModel.finalPrice?.decimalValue ?? viewModel.price?.decimalValue
        let basePrice = viewModel.price?.decimalValue
        let originalPrice =
            supportsDiscount && basePrice != finalPrice ? basePrice : nil
        let subtitle = PPUniversalCellSwiftUIBridge.displaySubtitle(
            for: viewModel,
            context: objcContext,
            horizontalLayout: horizontal,
            dataViewPresenter: dataViewPresentation,
            showsSubtitle: showsSubtitle
        )
        var resolvedSubtitle: String? = nil
        if dataViewPresentation {
            if isAdLike {
                let loc = viewModel.location ?? ""
                if !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resolvedSubtitle = loc
                } else {
                    resolvedSubtitle = Self.localized("ad_no_location_placeholder", fallback: "Location not specified")
                }
            } else {
                resolvedSubtitle = subtitle
            }
        }
        let availabilityText = PPUniversalCellSwiftUIBridge.availabilityText(
            for: viewModel,
            context: objcContext,
            horizontalLayout: horizontal,
            dataViewPresenter: dataViewPresentation
        )
        let tone = Self.availabilityTone(
            PPUniversalCellSwiftUIBridge.availabilityTone(
                for: viewModel,
                context: objcContext
            )
        )

        let metadata = PPUniversalCellSwiftUIBridge.metadataText(for: viewModel)
        let metadataIcon =
            PPUniversalCellSwiftUIBridge.metadataSystemImage(for: viewModel)
        let reason = viewModel.isOwner && !viewModel.isPubliclyVisible && !hideTopBadge
            ? Self.localized("listing_hidden_badge", fallback: "Hidden")
            : nil

        var resolvedMetadata = isAdLike ? nil : metadata
        var resolvedMetadataIcon = isAdLike ? nil : metadataIcon

        if objcContext == .forServices {
            if resolvedMetadata == nil || resolvedMetadata!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedMetadata = "0.0"
            }
            if resolvedMetadataIcon == nil || resolvedMetadataIcon!.isEmpty {
                resolvedMetadataIcon = "star.fill"
            }
        }

        let hasAvailabilityText = availabilityText?.isEmpty == false
        let hasMetadata = resolvedMetadata?.isEmpty == false

        let availability = (hasAvailabilityText || hasMetadata)
            ? PPUniversalAvailability(
                text: availabilityText ?? "",
                tone: tone,
                metaText: resolvedMetadata,
                metaSystemImage: resolvedMetadataIcon
            )
            : nil
        let gender = resolvedContext.isAdvertisement
            ? Self.cardGender(
                PPUniversalCellSwiftUIBridge
                    .advertisementGenderValue(for: viewModel)
            )
            : nil

        self.viewModel = viewModel
        self.context = resolvedContext
        self.layout = resolvedLayout
        self.discountStyle = objcDiscountStyle == .plain ? .inline : .badge
        self.imageLoader = imageLoader
        self.imagePlaceholder =
            viewModel.placeholder ?? UIImage(named: "placeholder")
        self.imageSignature = [
            stableID,
            viewModel.imageURL ?? "",
            viewModel.blurHash
        ].joined(separator: "|")
        self.favoriteCollection =
            PPUniversalCellSwiftUIBridge.favoritesCollection(for: objcContext)
        let showsLeadingAction = !viewModel.isOwner && !stableID.isEmpty
        self.showsSaveForLater =
            showsLeadingAction && resolvedContext == .market
        self.showsFavorite =
            showsLeadingAction && resolvedContext != .market
        self.showsOwnerMenu =
            viewModel.isOwner && forceShowsOwnerMenuButton

        let imageURL = viewModel.imageURL.flatMap(URL.init(string:))
        let videoURL = viewModel.isVideoMedia
            ? viewModel.videoURL.flatMap(URL.init(string:))
            : nil
        let discountText = supportsDiscount && !viewModel.discountText.isEmpty
            ? viewModel.discountText
            : nil

        model = PPUniversalCardModel(
            id: stableID,
            title: viewModel.title,
            subtitle: resolvedSubtitle?.isEmpty == false ? resolvedSubtitle : nil,
            imageURL: imageURL,
            videoURL: videoURL,
            placeholderSystemImage: "pawprint.fill",
            price: resolvedContext == .adopt ? nil : finalPrice,
            originalPrice: resolvedContext == .adopt ? nil : originalPrice,
            priceText: resolvedContext == .adopt || viewModel.priceText.isEmpty
                ? nil
                : viewModel.priceText,
            currencyCode: viewModel.currencyCode.isEmpty
                ? "QAR"
                : viewModel.currencyCode,
            badgeText: nil,
            reasonText: reason,
            discountText: discountText,
            availability: availability,
            gender: gender,
            isFavorite: false,
            isOwner: viewModel.isOwner,
            isPubliclyVisible: viewModel.isPubliclyVisible,
            isSkeleton: viewModel.isSkeleton,
            quantity: cartQuantity,
            stock: stock,
            usesQuantityControl: usesQuantity,
            prefersContainedImage:
                PPUniversalCellSwiftUIBridge.prefersContainedImage(for: viewModel),
            preferredAspectRatio: {
                if viewModel.imageSize.width > 0 && viewModel.imageSize.height > 0 {
                    return viewModel.imageSize.height / viewModel.imageSize.width
                } else if viewModel.preferredAspectRatio > 0 {
                    return CGFloat(viewModel.preferredAspectRatio)
                } else {
                    return 0.82
                }
            }()
        )
        refreshSavedForLaterState()

        if stableID != previousID {
            resetTransientState(quantity: cartQuantity)
        } else {
            quantity = min(max(0, cartQuantity), stock ?? Int.max)
        }

        if isAdLike && resolvedLayout == .pinterest {
            isEditingQuantity = false
        }
        isRightToLeft = PPUniversalCellSwiftUIBridge.isRightToLeft()
    }

    func resetForReuse() {
        collapseTask?.cancel()
        collapseTask = nil
        stopMediaPlayback()
        delegate = nil
        viewModel = nil
        imageLoader = nil
        imagePlaceholder = nil
        imageSignature = ""
        cardTap = nil
        showsFavorite = false
        showsSaveForLater = false
        showsOwnerMenu = false
        isSavedForLater = false
        notifyItemID = nil
        model = PPUniversalCardModel(
            id: "reusable-placeholder",
            title: "",
            isSkeleton: true
        )
        resetTransientState(quantity: 0)
        isNearbyAdsSection = false
        isSuggestionsAd = false
        isHomePresentation = false
        showsOwnerRow = false
        isContextFocused = false
        uiReferences.imageView?.image = nil
    }

    func updatePresentationHost(_ delegate: PPUniversalCellDelegate?) {
        self.delegate = delegate
        guard let delegate,
              let object = delegate as? NSObject,
              let homeClass = NSClassFromString("PPHomeViewController") else {
            isHomePresentation = false
            return
        }
        isHomePresentation = object.isKind(of: homeClass)
    }

    func refreshCartQuantity() {
        guard let viewModel, model.usesQuantityControl else {
            return
        }
        let refreshed =
            PPUniversalCellSwiftUIBridge.cartQuantity(for: viewModel)
        setQuantity(refreshed, animated: false, notifyDelegate: false)
    }

    func refreshSavedForLaterState() {
        guard showsSaveForLater,
              !model.isSkeleton,
              !model.id.isEmpty else {
            isSavedForLater = false
            return
        }
        isSavedForLater =
            PPSaveForLaterManager.shared().isItemSaved(model.id)
    }

    func refreshEnvironment() {
        isRightToLeft = PPUniversalCellSwiftUIBridge.isRightToLeft()
        objectWillChange.send()
    }

    func tapCard() {
        guard !model.isSkeleton else {
            return
        }
        pp_performTapHaloBurst()
        cardTap?()
        if let viewModel {
            delegate?.ppUniversalCell_tapCard?(viewModel)
        } else {
            actions.onTap?(currentModel)
        }
    }

    func tapShare() {
        guard !model.isSkeleton else {
            return
        }
        if let viewModel {
            delegate?.ppUniversalCell_tapShare?(viewModel)
        } else {
            actions.onShare?(currentModel)
        }
    }

    func tapFavorite() {
        guard !model.isSkeleton else {
            return
        }
        if let viewModel {
            delegate?.ppUniversalCell_tapFavorite?(viewModel)
        } else {
            var next = model
            next.isFavorite.toggle()
            model = next
            actions.onFavorite?(next, next.isFavorite)
        }
    }

    func tapSaveForLater() {
        guard !model.isSkeleton, let viewModel else {
            return
        }
        delegate?.ppUniversalCell_tapSave?(forLater: viewModel)
        refreshSavedForLaterState()
    }

    private func pp_performTapHaloBurst() {
        guard !UIAccessibility.isReduceMotionEnabled,
              let container = uiReferences.imageContainer,
              let haloLayer = uiReferences.tapHaloLayer else {
            return
        }

        let accent = UIColor(named: "diffColor") ?? UIColor(red: 0.96, green: 0.25, blue: 0.42, alpha: 1)
        haloLayer.colors = [
            accent.withAlphaComponent(0.30).cgColor,
            accent.withAlphaComponent(0.10).cgColor,
            accent.withAlphaComponent(0.0).cgColor,
        ]

        let bounds = container.bounds
        let diameter = max(bounds.width, bounds.height) * 1.66
        let haloX = (bounds.width - diameter) * 0.5
        let haloY = bounds.height - (diameter * 0.74)
        haloLayer.frame = CGRect(x: haloX, y: haloY, width: diameter, height: diameter)
        haloLayer.cornerRadius = diameter * 0.5

        haloLayer.removeAnimation(forKey: "pp.universalCell.tapHalo")
        haloLayer.opacity = 0.0

        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.values = [0.0, 0.42, 0.0]
        opacityAnimation.keyTimes = [0.0, 0.22, 1.0]

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.72
        scaleAnimation.toValue = 1.18

        let group = CAAnimationGroup()
        group.animations = [opacityAnimation, scaleAnimation]
        group.duration = 0.40
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = true

        haloLayer.add(group, forKey: "pp.universalCell.tapHalo")
    }

    func tapEdit() {
        guard requireAuthentication(), let viewModel else {
            return
        }
        delegate?.ppUniversalCell_tapEdit?(viewModel)
    }

    func tapVisibility() {
        guard requireAuthentication(), let viewModel else {
            return
        }
        delegate?.ppUniversalCell_tapVisibilityToggle?(viewModel)
    }

    func tapDelete() {
        guard requireAuthentication(), let viewModel else {
            return
        }
        delegate?.ppUniversalCell_tapDelete?(viewModel)
    }

    func handlePrimaryAction() {
        if !model.usesQuantityControl {
            tapCard()
            return
        }
        guard requireAuthentication() else {
            return
        }
        if isOutOfStock {
            registerStockNotification()
            return
        }
        if quantity > 0 {
            setStepperExpanded(true)
            restartCollapseTimer()
            return
        }
        setQuantity(1, animated: true, notifyDelegate: true)
        setStepperExpanded(true)
        restartCollapseTimer()
    }

    func changeQuantity(by delta: Int) {
        guard requireAuthentication() else {
            return
        }
        setQuantity(quantity + delta, animated: true, notifyDelegate: true)
        restartCollapseTimer()
    }

    func setQuantity(
        _ proposedQuantity: Int,
        animated: Bool,
        notifyDelegate: Bool
    ) {
        let clamped = min(max(0, proposedQuantity), model.stock ?? Int.max)
        let updates = {
            self.quantity = clamped
            if clamped == 0 {
                self.isEditingQuantity = false
            }
        }
        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                updates()
            }
        } else {
            updates()
        }

        guard notifyDelegate else {
            return
        }
        if let viewModel {
            delegate?.ppUniversalCell_changeQuantity?(
                viewModel,
                quantity: clamped
            )
        } else {
            actions.onQuantityChange?(currentModel, clamped)
        }
    }

    func collapseStepper(animated: Bool) {
        collapseTask?.cancel()
        collapseTask = nil
        setStepperExpanded(false, animated: animated)
    }

    func toggleVideo() {
        guard let url = model.videoURL else {
            return
        }
        if isVideoPlaying {
            player?.pause()
            isVideoPlaying = false
            return
        }

        if player == nil ||
            (player?.currentItem?.asset as? AVURLAsset)?.url != url {
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player?.isMuted = true
        }
        player?.play()
        isVideoPlaying = true
    }

    func tapVideo() {
        guard !model.isSkeleton, model.videoURL != nil else {
            return
        }

        if let viewModel, delegateResponds(to: "PPUniversalCell_tapVideo:") {
            stopMediaPlayback()
            delegate?.ppUniversalCell_tapVideo?(viewModel)
            return
        }

        if let viewModel, delegateResponds(to: "PPUniversalCell_tapCard:") {
            stopMediaPlayback()
            delegate?.ppUniversalCell_tapCard?(viewModel)
            return
        }

        if actions.onTap != nil {
            stopMediaPlayback()
            actions.onTap?(currentModel)
            return
        }

        toggleVideo()
    }

    func stopMediaPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isVideoPlaying = false
    }

    var isOutOfStock: Bool {
        model.usesQuantityControl && (model.stock ?? 0) <= 0
    }

    var canIncreaseQuantity: Bool {
        model.stock.map { quantity < $0 } ?? true
    }

    private func delegateResponds(to selectorName: String) -> Bool {
        guard let object = delegate as? NSObjectProtocol else {
            return false
        }
        return object.responds(to: NSSelectorFromString(selectorName))
    }

    var currentModel: PPUniversalCardModel {
        var copy = model
        copy.quantity = quantity
        return copy
    }

    private func registerStockNotification() {
        guard !isNotifyInFlight else {
            return
        }
        guard let viewModel else {
            if let notify = actions.onNotifyWhenAvailable {
                isNotifyInFlight = true
                Task { @MainActor in
                    let succeeded = await notify(currentModel)
                    self.isNotifyInFlight = false
                    self.notifySucceeded = succeeded
                }
            }
            return
        }

        let itemID = model.id
        notifyItemID = itemID
        isNotifyInFlight = true
        PPUniversalCellSwiftUIBridge.registerStockNotification(
            for: viewModel
        ) { [weak self] succeeded in
            Task { @MainActor [weak self] in
                guard let self, self.notifyItemID == itemID else {
                    return
                }
                self.isNotifyInFlight = false
                self.notifySucceeded = succeeded
            }
        }
    }

    private func requireAuthentication() -> Bool {
        guard viewModel != nil else {
            return true
        }
        guard PPUniversalCellSwiftUIBridge.isUserLoggedIn() else {
            PPUniversalCellSwiftUIBridge.showLoginPrompt()
            return false
        }
        return true
    }

    private func restartCollapseTimer() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.setStepperExpanded(false)
        }
    }

    private func setStepperExpanded(
        _ expanded: Bool,
        animated: Bool = true
    ) {
        let updates = {
            self.isEditingQuantity = expanded
        }
        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func resetTransientState(quantity: Int) {
        collapseTask?.cancel()
        collapseTask = nil
        stopMediaPlayback()
        self.quantity = max(0, quantity)
        isEditingQuantity = false
        isNotifyInFlight = false
        notifySucceeded = false
        notifyItemID = nil
    }

    private static func resolvedLayout(
        _ layout: PPManagerCellLayoutMode,
        viewModel: PPUniversalCellViewModel,
        dataViewPresentation: Bool,
        isSuggestionsAd: Bool = false
    ) -> PPUniversalCardLayout {
        if isSuggestionsAd {
            return .market
        }
        if layout == .cellLayoutModeHorizontalRow && !dataViewPresentation {
            if PPUniversalCellSwiftUIBridge.isAccessoryViewModel(viewModel) {
                return .market
            }
            if PPUniversalCellSwiftUIBridge.isServiceLike(viewModel) {
                return .market
            }
            if PPUniversalCellSwiftUIBridge.isAdvertisementViewModel(viewModel) {
                return .market
            }
        }

        switch layout {
        case .cellLayoutModePinterest:
            return dataViewPresentation ? .pinterest : .market
        case .cellLayoutModeFullWidth:
            return .fullWidth
        case .cellLayoutModeHorizontalRow:
            return .horizontalRow
        case .cellLayoutModeVertical:
            return dataViewPresentation ? .vertical : .market
        case .cellLayoutModeMarket:
            return .market
        default:
            return .market
        }
    }

    private static func cardContext(
        _ context: PPCellContext
    ) -> PPUniversalCardContext {
        switch context {
        case .forAds:
            return .ads
        case .forHomeAds:
            return .homeAds
        case .forMarket:
            return .market
        case .forContextAccessory:
            return .accessory
        case .forFood:
            return .food
        case .forServices:
            return .services
        case .forVets:
            return .vets
        case .forAdopt:
            return .adopt
        default:
            return .market
        }
    }

    private static func availabilityTone(
        _ tone: PPUniversalAvailabilityTone
    ) -> PPUniversalAvailability.Tone {
        switch tone.rawValue {
        case 1:
            return .available
        case 2:
            return .limited
        case 3:
            return .unavailable
        case 4:
            return .used
        default:
            return .neutral
        }
    }

    private static func cardGender(
        _ value: String?
    ) -> PPUniversalCardGender? {
        guard let value else {
            return nil
        }
        return PPUniversalCardGender(rawValue: value)
    }

    static func localized(_ key: String, fallback: String) -> String {
        PPUniversalCellSwiftUIBridge.localizedString(
            forKey: key,
            fallback: fallback
        )
    }
}

// MARK: - Card Renderer

@available(iOS 16.0, *)
private struct PPUniversalHomeCardGridMetrics {
    let mediaHeight: CGFloat
    let titleHeight: CGFloat
    let subtitleHeight: CGFloat
    let priceHeight: CGFloat
    let actionHeight: CGFloat
    let metadataHeight: CGFloat
    let titleToPriceSpacing: CGFloat
    let priceToActionSpacing: CGFloat
    let actionToMetadataSpacing: CGFloat
}

@available(iOS 16.0, *)
private struct PPUniversalCardRenderer: View {
    @ObservedObject var store: PPUniversalCardStore
    @State private var ownerName: String? = nil
    @State private var ownerAvatarURL: String? = nil
    @State private var ownerRating: Double = 0.0
    @State private var hasFetchedOwner = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let cardRadius: CGFloat = 23
    private let mediaBottomRadius: CGFloat = 8

    init(store: PPUniversalCardStore) {
        self.store = store
    }

    private let mediaTopRadius: CGFloat = 21.5

    var body: some View {
        Group {
            if store.model.isSkeleton {
                PPUniversalSkeletonCard(
                    horizontal: store.layout.isHorizontal,
                    catalog: store.context.isCatalogCommerce,
                    cardRadius: cardRadius,
                    mediaTopRadius: mediaTopRadius,
                    mediaBottomRadius: mediaBottomRadius
                )
            } else {
                VStack(spacing: 8) {
                    if store.showsOwnerRow {
                        ownerDetailsRow
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .top)
                                        .combined(with: .opacity)
                                        .combined(with: .offset(y: -6)),
                                    removal: .scale(scale: 0.94, anchor: .top)
                                        .combined(with: .opacity)
                                        .combined(with: .offset(y: -4))
                                )
                            )
                    }

                    GeometryReader { proxy in
                        cardLayout(size: proxy.size)
                    }
                }
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.08),
                    value: store.showsOwnerRow
                )
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.08),
                    value: store.isContextFocused
                )
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .onDisappear {
            store.collapseStepper(animated: false)
        }
        .onAppear {
            fetchOwnerIfNeeded()
        }
    }

    @ViewBuilder
    private func cardLayout(size: CGSize) -> some View {
        let card = Group {
            if store.layout.isHorizontal {
                HStack(spacing: 11) {
                    media
                        .frame(
                            width: min(
                                store.layout == .fullWidth ? 148 : 134,
                                max(112, size.width * 0.35)
                            )
                        )
                    information
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(9)
            } else {
                let metrics = homeGridMetrics(for: size)
                VStack(spacing: 0) {
                    media
                        .frame(
                            maxWidth: .infinity,
                            minHeight: store.isHomePresentation && !store.isContextFocused ? metrics.mediaHeight : nil,
                            maxHeight: store.isHomePresentation && !store.isContextFocused ? metrics.mediaHeight : .infinity
                        )
                    if store.isHomePresentation {
                        homeVerticalInformationGrid(metrics: metrics)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: store.isContextFocused ? nil : .infinity,
                                alignment: .top
                            )
                            .padding(.horizontal, 11)
                            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 12 : 10)
                            .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 12 : 10)
                    } else {
                        bottomAnchoredInformation
                            .layoutPriority(1)
                            .padding(.horizontal, 9)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }
                }
                .padding(4)
            }
        }

        card
            .frame(width: size.width, height: size.height)
            .background(cardBackground)
            .clipShape(cardShape)
            .overlay(cardBorder)
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.14 : 0.045),
                radius: colorScheme == .dark ? 9 : 7,
                y: colorScheme == .dark ? 4 : 3
            )
            .scaleEffect(
                store.isHighlighted && !reduceMotion ? 0.98 : 1
            )
            .opacity(store.isHighlighted ? 0.96 : 1)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.26, dampingFraction: 0.84),
                value: store.isHighlighted
            )
            .contentShape(cardShape)
            .onTapGesture {
                store.tapCard()
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(store.model.title)
            .accessibilityAddTraits(
                store.isSelected ? [.isSelected] : []
            )
    }

    private var media: some View {
        ZStack {
            if store.model.imageURL == nil && store.model.videoURL == nil {
                emptyMedia
            } else {
                PPUniversalImageRepresentable(
                    references: store.uiReferences,
                    signature: store.imageSignature,
                    imageURL: store.model.imageURL?.absoluteString,
                    placeholder: store.imagePlaceholder,
                    placeholderSystemImage: store.model.placeholderSystemImage,
                    topCornerRadius: mediaTopRadius,
                    bottomCornerRadius: mediaBottomRadius,
                    contained:
                        store.model.prefersContainedImage &&
                        !shouldFillMediaImage,
                    fillsEmptyAreaWithImageBackground:
                        store.model.prefersContainedImage &&
                        !shouldFillMediaImage,
                    imageLoader: store.imageLoader
                )
                .padding(mediaContentInset)
            }

            if store.isVideoPlaying, let player = store.player {
                VideoPlayer(player: player)
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.08 : 0.025)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            mediaOverlay
        }
        .background(store.palette.groupedSurface)
        .clipShape(imageShape)
        .overlay(
            imageShape.stroke(
                colorScheme == .dark ? store.palette.diffColor.opacity(0.12) : Color.clear,
                lineWidth: 0.75
            )
        )
        .clipped()
        .accessibilityElement(children: .contain)
    }

    private var emptyMedia: some View {
        ZStack {
            store.palette.groupedSurface

            Image(systemName: store.model.placeholderSystemImage)
                .font(.system(size: 28, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(store.palette.primary.opacity(0.48))
                .accessibilityHidden(true)
        }
    }

    private var mediaOverlay: some View {
        ZStack {
            VStack {
                HStack(alignment: .top, spacing: 6) {
                    if store.showsSaveForLater {
                        saveForLaterControl
                    } else if store.showsFavorite {
                        favoriteControl
                    }
                    Spacer(minLength: 0)
                    if store.showsOwnerMenu {
                        ownerMenu
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 6) {
                    if let reason = store.model.reasonText,
                       !reason.isEmpty {
                        PPUniversalPill(
                            text: reason,
                            systemImage: "eye.slash.fill",
                            foreground: .white,
                            background: .black.opacity(0.66),
                            border: store.palette.diffColor.opacity(0.22)
                        )
                    }
                    Spacer(minLength: 0)
                    if store.discountStyle == .badge,
                       let discount = store.model.discountText,
                       !discount.isEmpty {
                        PPUniversalPill(
                            text: discount,
                            foreground: .white,
                            background: store.palette.destructive,
                            border: .clear
                        )
                    }
                }
            }
            .padding(6)

            if store.model.videoURL != nil && !store.isVideoPlaying {
                Button {
                    PPUniversalHaptics.medium()
                    store.tapVideo()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle().stroke(.white.opacity(0.28), lineWidth: 0.75)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    PPUniversalCardStore.localized(
                        "play_video",
                        fallback: "Play video"
                    )
                )
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 6)
            titleContent
            subtitleContent

            if hasPrice {
                priceRow
                    .padding(.top, store.model.subtitle == nil ? 4 : 2)
            }

            Spacer(minLength: store.layout.isHorizontal ? 6 : 5)

            if store.model.usesQuantityControl || store.context.isAdvertisement || store.context.isServiceLike {
                if !store.isNearbyAdsSection && !store.isContextFocused {
                    bottomCTA
                }

                if hasBottomBadges {
                    bottomBadgesRow
                        .padding(.top, 9)
                }
            } else {
                detailsFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomAnchoredInformation: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleContent
            subtitleContent

            if hasPrice {
                priceRow
                    .padding(.top, store.model.subtitle == nil ? 5 : 3)
            }

            if showsBottomCTA && !store.isContextFocused {
                bottomCTA
                    .padding(.top, hasPrice ? 8 : 10)
            }

            if hasBottomBadges {
                bottomBadgesRow
                    .padding(.top, showsBottomCTA && !store.isContextFocused ? 8 : 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder
    private func homeVerticalInformationGrid(
        metrics: PPUniversalHomeCardGridMetrics
    ) -> some View {
        switch store.context {
        case .market, .food, .accessory:
            commerceInformationGrid(metrics: metrics)
        case .adopt:
            adoptionInformationGrid(metrics: metrics)
        case .services, .vets:
            serviceInformationGrid(metrics: metrics)
        case .ads, .homeAds:
            adoptionListingInformationGrid(metrics: metrics)
        }
    }

    private func commerceInformationGrid(
        metrics: PPUniversalHomeCardGridMetrics
    ) -> some View {
        stableHomeInformationGrid(
            metrics: metrics,
            reservesPriceRow: true
        )
    }

    private func adoptionInformationGrid(
        metrics: PPUniversalHomeCardGridMetrics
    ) -> some View {
        stableHomeInformationGrid(
            metrics: metrics,
            reservesPriceRow: false
        )
    }

    private func adoptionListingInformationGrid(
        metrics: PPUniversalHomeCardGridMetrics
    ) -> some View {
        stableHomeInformationGrid(
            metrics: metrics,
            reservesPriceRow: true
        )
    }

    private func serviceInformationGrid(
        metrics: PPUniversalHomeCardGridMetrics
    ) -> some View {
        stableHomeInformationGrid(
            metrics: metrics,
            reservesPriceRow: true
        )
    }

    private func stableHomeInformationGrid(
        metrics: PPUniversalHomeCardGridMetrics,
        reservesPriceRow: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titleContent
                .frame(
                    maxWidth: .infinity,
                    minHeight: metrics.titleHeight,
                    maxHeight: metrics.titleHeight,
                    alignment: .leading
                )

            if metrics.subtitleHeight > 0 {
                subtitleContent
                    .frame(
                        maxWidth: .infinity,
                        minHeight: metrics.subtitleHeight,
                        maxHeight: metrics.subtitleHeight,
                        alignment: .topLeading
                    )
            }

            Color.clear
                .frame(height: metrics.titleToPriceSpacing)

            Group {
                if reservesPriceRow && hasPrice {
                    priceRow
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: reservesPriceRow ? metrics.priceHeight : 0,
                maxHeight: reservesPriceRow ? metrics.priceHeight : 0,
                alignment: .topLeading
            )

            Color.clear
                .frame(height: store.isContextFocused ? 0 : metrics.priceToActionSpacing)

            Group {
                if showsBottomCTA && !store.isContextFocused {
                    bottomCTA
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: store.isContextFocused ? 0 : metrics.actionHeight,
                maxHeight: store.isContextFocused ? 0 : metrics.actionHeight
            )

            Color.clear
                .frame(height: store.isContextFocused ? 0 : metrics.actionToMetadataSpacing)

            Group {
                if hasBottomBadges {
                    bottomBadgesRow
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: metrics.metadataHeight,
                maxHeight: metrics.metadataHeight,
                alignment: .center
            )
        }
    }

    private var titleContent: some View {
        Text(store.model.title)
            .font(
                .custom(
                    "Beiruti-Bold",
                    size: store.layout.isHorizontal ? 17 : 15.5,
                    relativeTo: .headline
                )
            )
            .foregroundStyle(store.palette.ink)
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(store.model.title)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var subtitleContent: some View {
        if let subtitle = store.model.subtitle,
           !subtitle.isEmpty,
           !usesCompressedAccessibilityLayout {
            if store.context.isAdvertisement || store.isSuggestionsAd {
                let isPlaceholder = (subtitle == PPUniversalCardStore.localized("ad_no_location_placeholder", fallback: "Location not specified"))
                HStack(spacing: 4) {
                    Image(systemName: isPlaceholder ? "mappin.slash" : "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isPlaceholder ? Color(uiColor: .secondaryLabel) : store.palette.accent)

                    Text("\(PPUniversalCardStore.localized("location", fallback: "Location")): \(subtitle)")
                        .font(
                            .custom(
                                "Beiruti-Medium",
                                size: store.layout.isHorizontal ? 13 : 12,
                                relativeTo: .subheadline
                            )
                        )
                        .foregroundColor(isPlaceholder ? Color(uiColor: .secondaryLabel) : store.palette.secondaryInk)
                        .lineLimit(store.layout.isHorizontal ? 2 : 1)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
            } else {
                Text(subtitle)
                    .font(
                        .custom(
                            "Beiruti-Medium",
                            size: store.layout.isHorizontal ? 14 : 13,
                            relativeTo: .subheadline
                        )
                    )
                    .foregroundStyle(store.palette.secondaryInk)
                    .lineLimit(store.layout.isHorizontal ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 5)
            }
        }
    }

    private var priceRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let price = store.model.price {
                Text(formattedNumber(price))
                    .font(
                        .custom(
                            "Beiruti-Black",
                            size: priceFontSize,
                            relativeTo: .title3
                        )
                    )
                    .foregroundStyle(store.palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)

                Text(normalizedCurrency)
                    .font(
                        .custom(
                            "Beiruti-Bold",
                            size: 11.5,
                            relativeTo: .caption
                        )
                    )
                    .foregroundStyle(store.palette.primary.opacity(0.82))
                    .lineLimit(1)
            } else {
                Text(displayPrice)
                    .font(
                        .custom(
                            "Beiruti-Black",
                            size: priceFontSize,
                            relativeTo: .title3
                        )
                    )
                    .foregroundStyle(store.palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }

            if let originalPrice = store.model.originalPrice {
                Text(formattedPrice(originalPrice))
                    .font(
                        .custom(
                            "Beiruti-Medium",
                            size: 17,
                            relativeTo: .caption
                        )
                    )
                    .strikethrough()
                    .foregroundStyle(store.palette.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            if store.discountStyle == .inline,
               let discount = store.model.discountText,
               !discount.isEmpty {
                Text(discount)
                    .font(
                        .custom(
                            "Beiruti-Bold",
                            size: 12,
                            relativeTo: .caption
                        )
                    )
                    .foregroundStyle(store.palette.destructive)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var priceFontSize: CGFloat {
        let baseSize: CGFloat = store.layout.isHorizontal ? 24 : 22
        return (store.context.isAdvertisement || store.isSuggestionsAd) ? (baseSize + 4) : baseSize
    }

    private var detailsFooter: some View {
        HStack(spacing: detailsFooterSpacing) {
            if let availability = store.model.availability,
               !usesCompressedAccessibilityLayout {
                compactMetadata(availability)
            }

            detailsFooterGap

            if store.isSuggestionsAd {
                let location = store.viewModel?.location ?? ""
                if !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .semibold))
                        Text(location)
                            .font(
                                .custom(
                                    "Beiruti-Bold",
                                    size: 12.5,
                                    relativeTo: .callout
                                )
                            )
                            .lineLimit(1)
                    }
                    .foregroundStyle(store.palette.secondaryInk)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 11, weight: .semibold))
                        Text(PPUniversalCardStore.localized("ad_no_location_placeholder", fallback: "Location not specified"))
                            .font(
                                .custom(
                                    "Beiruti-Bold",
                                    size: 12.5,
                                    relativeTo: .callout
                                )
                            )
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            } else {
                detailsAction
            }
        }
        .frame(minHeight: 34)
    }

    @ViewBuilder
    private var bottomCTA: some View {
        if usesPrimaryActionForBottomStack {
            if !store.isNearbyAdsSection {
                primaryAction
            }
        } else {
            detailsAction
        }
    }

    private var showsBottomCTA: Bool {
        usesPrimaryActionForBottomStack
            ? !store.isNearbyAdsSection
            : true
    }

    private var usesPrimaryActionForBottomStack: Bool {
        store.model.usesQuantityControl ||
            store.context.isAdvertisement ||
            store.isSuggestionsAd
    }

    private var detailsAction: some View {
        Button {
            PPUniversalHaptics.light()
            store.handlePrimaryAction()
        } label: {
            Group {
                if store.context.isServiceLike || store.context == .adopt {
                    HStack(spacing: 7) {
                        Text(primaryActionTitle)
                            .font(
                                .custom(
                                    "Beiruti-Bold",
                                    size: 14,
                                    relativeTo: .callout
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        
                        detailsArrow
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: standardActionHeight)
                    .background(adsModeCTAGradient, in: actionShape)
                    .overlay(
                        actionShape.stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.12), lineWidth: 0.75)
                    )
                } else if store.layout.isHorizontal {
                    HStack(spacing: 5) {
                        Text(primaryActionTitle)
                            .font(
                                .custom(
                                    "Beiruti-Bold",
                                    size: 12.5,
                                    relativeTo: .callout
                                )
                            )
                            .lineLimit(1)

                        detailsArrow
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(
                        store.palette.primary.opacity(
                            colorScheme == .dark ? 0.16 : 0.075
                        ),
                        in: Capsule()
                    )
                } else {
                    detailsArrow
                        .frame(width: 34, height: 34)
                        .background(
                            store.palette.primary.opacity(
                                colorScheme == .dark ? 0.16 : 0.075
                            ),
                            in: Circle()
                        )
                }
            }
            .foregroundStyle(detailsActionForeground)
        }
        .buttonStyle(PPUniversalScaleButtonStyle())
        .accessibilityLabel(primaryActionTitle)
    }

    private var detailsActionForeground: Color {
        store.context.isServiceLike ? .white : store.palette.primary
    }

    @ViewBuilder
    private var detailsFooterGap: some View {
        if store.context.isAdvertisement || store.isSuggestionsAd {
            Color.clear.frame(width: 2)
        } else {
            Spacer(minLength: 4)
        }
    }

    private var detailsFooterSpacing: CGFloat {
        store.context.isAdvertisement || store.isSuggestionsAd ? 4 : 7
    }

    private var detailsArrow: some View {
        Image(
            systemName: store.isRightToLeft
                ? "arrow.up.left"
                : "arrow.up.right"
        )
        .font(.system(size: 10.5, weight: .bold))
    }

    private func compactMetadata(
        _ availability: PPUniversalAvailability
    ) -> some View {
        let metadata = availability.metaText.flatMap {
            $0.isEmpty ? nil : $0
        }
        let text = metadata ?? availability.text
        let foreground = metadata != nil
            ? metaForeground(availability)
            : availabilityForeground(availability.tone)

        return PPUniversalPill(
            text: text,
            systemImage: metadata != nil
                ? availability.metaSystemImage
                : nil,
            foreground: foreground,
            background: foreground.opacity(
                colorScheme == .dark ? 0.16 : 0.09
            ),
            border: foreground.opacity(0.14)
        )
    }

    @ViewBuilder
    private var primaryAction: some View {
        if store.model.usesQuantityControl &&
            store.isEditingQuantity &&
            store.quantity > 0 {
            quantityStepper
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            Button {
                PPUniversalHaptics.medium()
                store.handlePrimaryAction()
            } label: {
                HStack(spacing: 7) {
                    if store.isNotifyInFlight {
                        ProgressView()
                            .controlSize(.small)
                            .tint(primaryActionForeground)
                    } else {
                        Image(systemName: primaryActionIcon)
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(primaryActionTitle)
                        .font(
                            .custom(
                                "Beiruti-Bold",
                                size: 14,
                                relativeTo: .callout
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .foregroundStyle(primaryActionForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: standardActionHeight)
                .background(
                    primaryActionBackground
                        .clipShape(actionShape)
                )
                .overlay(
                    actionShape.stroke(primaryActionBorder, lineWidth: 0.75)
                )
            }
            .buttonStyle(PPUniversalScaleButtonStyle())
            .disabled(store.isNotifyInFlight)
            .accessibilityLabel(primaryActionTitle)
        }
    }

    private var quantityStepper: some View {
        HStack(spacing: 8) {
            stepperButton(
                systemName: store.quantity == 1 ? "trash" : "minus",
                enabled: store.quantity > 0
            ) {
                store.changeQuantity(by: -1)
            }

            Spacer(minLength: 0)

            Text(String(format: "%d", locale: Locale(identifier: "en"), store.quantity))
                .font(
                    .custom(
                        "Beiruti-Black",
                        size: 18,
                        relativeTo: .headline
                    )
                )
                .foregroundStyle(store.palette.primary)
                .monospacedDigit()
                .accessibilityLabel(
                    PPUniversalCardStore.localized(
                        "quantity",
                        fallback: "Quantity"
                    )
                )
                .accessibilityValue("\(store.quantity)")

            Spacer(minLength: 0)

            stepperButton(
                systemName: "plus",
                enabled: store.canIncreaseQuantity
            ) {
                store.changeQuantity(by: 1)
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 42)
        .background(
            store.palette.primary.opacity(colorScheme == .dark ? 0.18 : 0.08),
            in: actionShape
        )
        .overlay(
            actionShape.stroke(
                store.palette.primary.opacity(0.18),
                lineWidth: 0.75
            )
        )
    }

    private func stepperButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            PPUniversalHaptics.light()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(
                    systemName == "trash"
                        ? store.palette.destructive
                        : store.palette.primary
                )
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(PPUniversalScaleButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.32)
    }

    private var hasBottomBadges: Bool {
        let availability = store.model.availability
        let hasAvailability =
            availability?.text.isEmpty == false ||
            availability?.metaText?.isEmpty == false
        return store.model.gender != nil ||
            (hasAvailability && !usesCompressedAccessibilityLayout)
    }

    private var bottomBadgesRow: some View {
        let availability = store.model.availability
        let hasMeta =
            !usesCompressedAccessibilityLayout &&
            availability?.metaText?.isEmpty == false
        let hasText =
            !usesCompressedAccessibilityLayout &&
            availability?.text.isEmpty == false
        let hasGender = store.model.gender != nil
        let activeBadgeCount =
            (hasMeta ? 1 : 0) +
            (hasText ? 1 : 0) +
            (hasGender ? 1 : 0)
        let fillsAvailableWidth = hasText && (hasMeta || hasGender)

        return HStack(spacing: 6) {
            if hasMeta,
               let meta = availability?.metaText,
               !meta.isEmpty,
               let availability {
                PPUniversalPill(
                    text: meta,
                    systemImage: availability.metaSystemImage,
                    foreground: metaForeground(availability),
                    background: metaForeground(availability).opacity(
                        colorScheme == .dark ? 0.16 : 0.10
                    ),
                    border: metaForeground(availability).opacity(0.18),
                    fillWidth: hasText
                )
            }

            if hasText, let availability, !availability.text.isEmpty {
                PPUniversalPill(
                    text: availability.text,
                    foreground: availabilityForeground(availability.tone),
                    background: availabilityForeground(availability.tone).opacity(
                        colorScheme == .dark ? 0.16 : 0.10
                    ),
                    border: availabilityForeground(availability.tone).opacity(0.18),
                    fillWidth: fillsAvailableWidth
                )
            }

            if let gender = store.model.gender {
                PPUniversalPill(
                    text: genderTitle(gender),
                    foreground: genderForeground(gender),
                    background: genderForeground(gender).opacity(
                        colorScheme == .dark ? 0.18 : 0.11
                    ),
                    border: genderForeground(gender).opacity(0.22)
                )
            }

            if activeBadgeCount < 2 {
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func genderTitle(_ gender: PPUniversalCardGender) -> String {
        switch gender {
        case .male:
            return PPUniversalCardStore.localized("Male", fallback: "Male")
        case .female:
            return PPUniversalCardStore.localized("Female", fallback: "Female")
        case .undefined:
            return PPUniversalCardStore.localized(
                "no_value",
                fallback: "Undefined"
            )
        }
    }

    private func genderForeground(
        _ gender: PPUniversalCardGender
    ) -> Color {
        switch gender {
        case .male:
            return Color(uiColor: .systemBlue)
        case .female:
            return Color(uiColor: .systemPink)
        case .undefined:
            return Color(uiColor: .secondaryLabel)
        }
    }

    @ViewBuilder
    private var favoriteControl: some View {
        if store.viewModel != nil {
            PPUniversalFavoriteRepresentable(
                itemID: store.model.id,
                collection: store.favoriteCollection,
                isRightToLeft: store.isRightToLeft
            )
            .frame(
                width: store.isHomePresentation ? 44 : 40,
                height: store.isHomePresentation ? 44 : 40
            )
        } else {
            Button {
                var next = store.model
                next.isFavorite.toggle()
                store.model = next
                store.actions.onFavorite?(next, next.isFavorite)
            } label: {
                Image(
                    systemName: store.model.isFavorite
                        ? "heart.fill"
                        : "heart"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    store.model.isFavorite
                        ? store.palette.destructive
                        : store.palette.ink
                )
                .frame(
                    width: store.isHomePresentation ? 44 : 40,
                    height: store.isHomePresentation ? 44 : 40
                )
                .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(PPUniversalScaleButtonStyle())
        }
    }

    private var saveForLaterControl: some View {
        Button {
            store.tapSaveForLater()
        } label: {
            Image(systemName: saveForLaterSystemImage)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(saveForLaterIconColor)
                .frame(
                    width: store.isHomePresentation ? 44 : 40,
                    height: store.isHomePresentation ? 44 : 40
                )
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(
                            Color.white.opacity(
                                colorScheme == .dark ? 0.18 : 0.42
                            ),
                            lineWidth: 0.75
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(PPUniversalScaleButtonStyle())
        .animation(
            .spring(response: 0.24, dampingFraction: 0.82),
            value: store.isSavedForLater
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PPUniversalCardStore.localized(
                "saved_for_later",
                fallback: "Save for later"
            )
        )
        .accessibilityAddTraits(
            store.isSavedForLater ? [.isButton, .isSelected] : .isButton
        )
    }

    private var saveForLaterSystemImage: String {
        store.isSavedForLater ? "bookmark.fill" : "bookmark"
    }

    private var saveForLaterIconColor: Color {
        if store.isSavedForLater {
            return Color(
                uiColor: UIColor(named: "AppPrimaryColor") ??
                    UIColor(red: 0.54, green: 0.08, blue: 0.22, alpha: 1)
            )
        }
        return Color(
            uiColor: UIColor(named: "SecondaryTextColor") ??
                UIColor.secondaryLabel
        )
    }

    private var ownerMenu: some View {
        Menu {
            Button {
                store.tapEdit()
            } label: {
                Label(
                    PPUniversalCardStore.localized("Edit", fallback: "Edit"),
                    systemImage: "square.and.pencil"
                )
            }
            Button {
                store.tapVisibility()
            } label: {
                Label(
                    store.model.isPubliclyVisible
                        ? PPUniversalCardStore.localized(
                            "listing_hide_action",
                            fallback: "Hide"
                        )
                        : PPUniversalCardStore.localized(
                            "listing_show_action",
                            fallback: "Show"
                        ),
                    systemImage: store.model.isPubliclyVisible
                        ? "eye.slash"
                        : "eye"
                )
            }
            Button(role: .destructive) {
                store.tapDelete()
            } label: {
                Label(
                    PPUniversalCardStore.localized(
                        "Delete",
                        fallback: "Delete"
                    ),
                    systemImage: "trash"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(store.palette.ink)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(.white.opacity(0.20), lineWidth: 0.75)
                )
        }
        .accessibilityLabel(
            PPUniversalCardStore.localized(
                "item_options",
                fallback: "Item options"
            )
        )
    }

    private var cardBackground: some View {
        store.palette.cardColor.opacity(
            reduceTransparency || colorScheme == .dark ? 0.98 : 1.0
        )
    }

    private var cardBorder: some View {
        cardShape.stroke(
            colorScheme == .dark && store.userBordersV2
                ? (store.isSelected
                    ? store.palette.primary.opacity(0.12)
                   : store.palette.diffColor.opacity(0.08))
                : Color.clear,
            lineWidth: store.isSelected ? 0.75 : 0.75
        )
    }

    private var ownerID: String? {
        guard let modelObject = store.viewModel?.modelObject else { return nil }
        if let petAd = modelObject as? PetAd {
            return petAd.ownerID
        }
        if let accessory = modelObject as? PetAccessory {
            return accessory.ownerID
        }
        if let nsObject = modelObject as? NSObject {
            if nsObject.responds(to: NSSelectorFromString("ownerID")) {
                return nsObject.value(forKey: "ownerID") as? String
            }
            if nsObject.responds(to: NSSelectorFromString("serviceOwnerID")) {
                return nsObject.value(forKey: "serviceOwnerID") as? String
            }
            if nsObject.responds(to: NSSelectorFromString("userID")) {
                return nsObject.value(forKey: "userID") as? String
            }
        }
        return nil
    }

    private func fetchOwnerIfNeeded() {
        guard !hasFetchedOwner, let uid = ownerID, let vm = store.viewModel else { return }
        hasFetchedOwner = true
        PPUniversalCellSwiftUIBridge.fetchOwnerProfile(forUID: uid, viewModel: vm) { name, avatarURL, rating in
            DispatchQueue.main.async {
                self.ownerName = name
                self.ownerAvatarURL = avatarURL
                self.ownerRating = rating
            }
        }
    }

    @ViewBuilder
    private var ownerDetailsRow: some View {
        if let name = ownerName {
            HStack(spacing: 8) {
                if let avatarString = ownerAvatarURL,
                   let url = URL(string: avatarString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.gray.opacity(0.3))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.custom("Beiruti-Medium", size: 13))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(1)

                    if ownerRating > 0.0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.yellow)
                            Text(String(format: "%.1f", ownerRating))
                                .font(.custom("Beiruti-Medium", size: 12))
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    PPUniversalHaptics.light()
                    store.delegate?.ppUniversalCell_tapChat?(store.viewModel!)
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(store.palette.primary)
                        .frame(width: 24, height: 24)
                        .background(store.palette.primary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
    }

    private func verticalMediaHeight(for size: CGSize) -> CGFloat {
        if store.layout == .vertical {
            return max(112, size.width - 8)
        }

        let maximumFraction: CGFloat
        let preferredRatio: CGFloat

        if store.context.isAdvertisement {
            maximumFraction = 0.44
            preferredRatio = min(
                max(store.model.preferredAspectRatio, 0.78),
                0.92
            )
        } else if store.context == .adopt {
            maximumFraction = 0.46
            preferredRatio = 0.88
        } else if store.context.isServiceLike {
            maximumFraction = 0.43
            preferredRatio = 0.72
        } else {
            maximumFraction = 0.43
            preferredRatio = min(
                max(store.model.preferredAspectRatio, 0.70),
                0.82
            )
        }

        let preferred = max(112, (size.width - 8) * preferredRatio)
        let maximum = max(112, size.height * maximumFraction)
        return min(preferred, maximum)
    }

    private func homeGridMetrics(
        for size: CGSize
    ) -> PPUniversalHomeCardGridMetrics {
        let accessibility = dynamicTypeSize.isAccessibilitySize
        let hasSubtitle =
            store.model.subtitle?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty == false
        let reservesPriceRow: Bool
        switch store.context {
        case .adopt:
            reservesPriceRow = false
        default:
            reservesPriceRow = true
        }

        let titleHeight: CGFloat = accessibility ? 34 : 24
        let subtitleHeight: CGFloat = hasSubtitle
            ? (accessibility ? 44 : 28)
            : 0
        let priceHeight: CGFloat = reservesPriceRow
            ? (accessibility ? 40 : 30)
            : 0
        let actionHeight: CGFloat = accessibility ? 52 : 44
        let metadataHeight: CGFloat = accessibility ? 36 : 28
        let titleToPriceSpacing: CGFloat = accessibility ? 6 : 4
        let priceToActionSpacing: CGFloat = accessibility ? 10 : 8
        let actionToMetadataSpacing: CGFloat = accessibility ? 10 : 8
        let informationVerticalInset: CGFloat = accessibility ? 24 : 20
        let reservedInformationHeight =
            titleHeight +
            subtitleHeight +
            priceHeight +
            actionHeight +
            metadataHeight +
            titleToPriceSpacing +
            priceToActionSpacing +
            actionToMetadataSpacing +
            informationVerticalInset
        let availableMediaHeight = max(
            accessibility ? 132 : 126,
            size.height - 8 - reservedInformationHeight
        )
        let maximumMediaHeight = max(126, size.width - 8)

        return PPUniversalHomeCardGridMetrics(
            mediaHeight: min(availableMediaHeight, maximumMediaHeight),
            titleHeight: titleHeight,
            subtitleHeight: subtitleHeight,
            priceHeight: priceHeight,
            actionHeight: actionHeight,
            metadataHeight: metadataHeight,
            titleToPriceSpacing: titleToPriceSpacing,
            priceToActionSpacing: priceToActionSpacing,
            actionToMetadataSpacing: actionToMetadataSpacing
        )
    }

    private var mediaContentInset: CGFloat {
        // No inset for market cards – they should fill the container edge‑to‑edge.
        if store.context == .market {
            return 0
        }
        guard store.model.prefersContainedImage,
              !shouldFillMediaImage else {
            return 0
        }
        return 9
    }

    private var shouldFillMediaImage: Bool {
        if store.model.prefersContainedImage {
            return false
        }
        return true
    }

    private var hasPrice: Bool {
        store.context != .adopt &&
            (store.model.price != nil ||
             store.model.priceText?.isEmpty == false)
    }

    private var displayPrice: String {
        if let price = store.model.price {
            return formattedPrice(price)
        }
        if let priceText = store.model.priceText,
           !priceText.isEmpty {
            return priceText
        }
        return ""
    }

    private func formattedPrice(_ value: Decimal) -> String {
        let number = formattedNumber(value)
        return store.isRightToLeft
            ? "\(number) \(normalizedCurrency)"
            : "\(normalizedCurrency) \(number)"
    }

    private func formattedNumber(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_QA")
        formatter.maximumFractionDigits = 2
        let decimalNumber = NSDecimalNumber(decimal: value)
        formatter.minimumFractionDigits =
            decimalNumber.doubleValue.truncatingRemainder(dividingBy: 1) == 0
            ? 0
            : 2
        return formatter.string(from: decimalNumber) ??
            decimalNumber.stringValue
    }

    private var normalizedCurrency: String {
        let raw = store.model.currencyCode.uppercased()
        if raw.contains("QAR") || raw.contains("RIAL") {
            return "QAR"
        }
        if raw.contains("EGP") || raw.contains("POUND") {
            return "EGP"
        }
        if raw.contains("SAR") {
            return "SAR"
        }
        if raw.contains("AED") {
            return "AED"
        }
        return raw.isEmpty ? "QAR" : raw
    }

    private var primaryActionTitle: String {
        guard store.model.usesQuantityControl else {
            return PPUniversalCardStore.localized(
                "Details",
                fallback: "Details"
            )
        }
        if store.isOutOfStock {
            if store.isNotifyInFlight {
                return PPUniversalCardStore.localized(
                    "notify_me_loading",
                    fallback: "Saving alert"
                )
            }
            if store.notifySucceeded {
                return PPUniversalCardStore.localized(
                    "stock_notify_already_registered",
                    fallback: "Alert saved"
                )
            }
            return PPUniversalCardStore.localized(
                "notify_me",
                fallback: "Notify me"
            )
        }
        if store.quantity > 0 {
            return "\(PPUniversalCardStore.localized("InCart", fallback: "In cart")) • \(store.quantity)"
        }
        return PPUniversalCardStore.localized(
            "addToCart",
            fallback: "Add to cart"
        )
    }

    private var primaryActionIcon: String {
        guard store.model.usesQuantityControl else {
            if isAdAction {
                return "megaphone.fill"
            }
            return store.isRightToLeft ? "arrow.up.left" : "arrow.up.right"
        }
        if store.isOutOfStock {
            return store.notifySucceeded
                ? "checkmark.circle.fill"
                : "bell.badge.fill"
        }
        return store.quantity > 0 ? "cart.fill" : "plus.cart.fill"
    }

    private var primaryActionForeground: Color {
        if isAdAction {
            return .white
        }
        if store.model.usesQuantityControl &&
            store.quantity > 0 &&
            !store.isOutOfStock {
            return store.palette.primary
        }
        return .white
    }

    @ViewBuilder
    private var primaryActionBackground: some View {
        if store.isOutOfStock {
            Color(uiColor: .secondaryLabel)
        } else if usesAdsModeCTAGradient {
            adsModeCTAGradient
        } else if store.model.usesQuantityControl && store.quantity > 0 {
            store.palette.primary.opacity(
                colorScheme == .dark ? 0.18 : 0.09
            )
        } else {
            store.palette.primary
        }
    }

    private var primaryActionBorder: Color {
        if isAdAction {
            return .clear
        }
        if store.model.usesQuantityControl && store.quantity > 0 {
            return store.palette.primary.opacity(0.20)
        }
        return .clear
    }

    private var isAdAction: Bool {
        (store.context.isAdvertisement || store.isSuggestionsAd) &&
            !store.model.usesQuantityControl
    }

    private var usesAdsModeCTAGradient: Bool {
        (store.context.isAdvertisement || store.isSuggestionsAd) && !store.model.usesQuantityControl
    }

    private var adsModeCTAGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                store.palette.primary,
                store.palette.primary
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func availabilityForeground(
        _ tone: PPUniversalAvailability.Tone
    ) -> Color {
        switch tone {
        case .available:
            return store.palette.success
        case .limited:
            return store.palette.warning
        case .unavailable:
            return store.palette.destructive
        case .used:
            return store.palette.accent
        case .neutral:
            return store.palette.secondaryInk
        }
    }

    private func metaForeground(
        _ availability: PPUniversalAvailability
    ) -> Color {
        if store.context.isAdvertisement || store.isSuggestionsAd {
            return Color(red: 0.816, green: 0.142, blue: 0.349)
        }
        if availability.metaSystemImage == "star.fill" {
            return Color(uiColor: .systemYellow)
        } else if availability.metaSystemImage == "mappin.slash" {
            return Color(uiColor: .secondaryLabel)
        } else {
            return store.palette.accent
        }
    }

    private var usesCompressedAccessibilityLayout: Bool {
        !store.isHomePresentation && dynamicTypeSize >= .accessibility2
    }

    private var standardActionHeight: CGFloat {
        guard store.isHomePresentation else {
            return 42
        }
        return dynamicTypeSize.isAccessibilitySize ? 52 : 44
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    }

    private var imageShape: PPUniversalMediaRoundedShape {
        PPUniversalMediaRoundedShape(
            topRadius: mediaTopRadius,
            bottomRadius: mediaBottomRadius
        )
    }

    private var actionShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
    }
}

// MARK: - UIKit-backed Media and Favorite Controls

@available(iOS 16.0, *)
private final class PPUniversalMirroredImageView: UIImageView {
    weak var mirroredBackgroundImageView: UIImageView?

    override var image: UIImage? {
        didSet {
            guard let mirroredBackgroundImageView else { return }
            let duration: TimeInterval = image == nil ? 0.0 : 0.25
            UIView.transition(
                with: mirroredBackgroundImageView,
                duration: duration,
                options: .transitionCrossDissolve,
                animations: {
                    mirroredBackgroundImageView.image = self.image
                },
                completion: nil
            )
        }
    }
}

@available(iOS 16.0, *)
private final class PPUniversalMediaContainerView: PPUniversalGradientView {
    var topCornerRadius: CGFloat = 20 {
        didSet { setNeedsLayout() }
    }

    var bottomCornerRadius: CGFloat = 8 {
        didSet { setNeedsLayout() }
    }

    weak var primaryImageView: UIView?
    weak var backgroundImageView: UIView?
    weak var washView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()
        ppUniversalApplyMediaCornerMask(
            to: self,
            topRadius: topCornerRadius,
            bottomRadius: bottomCornerRadius
        )
        if let backgroundImageView {
            ppUniversalApplyMediaCornerMask(
                to: backgroundImageView,
                topRadius: topCornerRadius,
                bottomRadius: bottomCornerRadius
            )
        }
        if let washView {
            ppUniversalApplyMediaCornerMask(
                to: washView,
                topRadius: topCornerRadius,
                bottomRadius: bottomCornerRadius
            )
        }
        if let primaryImageView {
            ppUniversalApplyMediaCornerMask(
                to: primaryImageView,
                topRadius: topCornerRadius,
                bottomRadius: bottomCornerRadius
            )
        }
    }
}

private func ppUniversalApplyMediaCornerMask(
    to view: UIView,
    topRadius: CGFloat,
    bottomRadius: CGFloat
) {
    view.clipsToBounds = true
    guard !view.bounds.isEmpty else {
        return
    }

    let maskLayer: CAShapeLayer
    if let existing = view.layer.mask as? CAShapeLayer {
        maskLayer = existing
    } else {
        maskLayer = CAShapeLayer()
        maskLayer.contentsScale = UIScreen.main.scale
        view.layer.mask = maskLayer
    }

    maskLayer.frame = view.bounds
    maskLayer.path = ppUniversalMediaCornerPath(
        in: view.bounds,
        topRadius: topRadius,
        bottomRadius: bottomRadius
    )
}

private func ppUniversalMediaCornerPath(
    in rect: CGRect,
    topRadius: CGFloat,
    bottomRadius: CGFloat
) -> CGPath {
    guard rect.width > 0, rect.height > 0 else {
        return UIBezierPath(rect: rect).cgPath
    }

    let maximumRadius = min(rect.width, rect.height) * 0.5
    let top = min(max(0, topRadius), maximumRadius)
    let bottom = min(max(0, bottomRadius), maximumRadius)
    let path = UIBezierPath()

    path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
    path.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: rect.minY + top),
        controlPoint: CGPoint(x: rect.maxX, y: rect.minY)
    )
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
    path.addQuadCurve(
        to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
        controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
    )
    path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
    path.addQuadCurve(
        to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
        controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
    )
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
    path.addQuadCurve(
        to: CGPoint(x: rect.minX + top, y: rect.minY),
        controlPoint: CGPoint(x: rect.minX, y: rect.minY)
    )
    path.close()
    return path.cgPath
}

@available(iOS 16.0, *)
private struct PPUniversalImageRepresentable: UIViewRepresentable {
    let references: PPUniversalUIKitReferences
    let signature: String
    let imageURL: String?
    let placeholder: UIImage?
    let placeholderSystemImage: String
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let contained: Bool
    let fillsEmptyAreaWithImageBackground: Bool
    let imageLoader: PPImageLoader?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PPUniversalGradientView {
        let container = PPUniversalMediaContainerView()
        container.topCornerRadius = topCornerRadius
        container.bottomCornerRadius = bottomCornerRadius
        container.translatesAutoresizingMaskIntoConstraints = true
        container.backgroundColor = .clear
        container.clipsToBounds = true
        container.isAccessibilityElement = false

        let backgroundImageView = UIImageView()
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.clipsToBounds = true
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.alpha = 0
        backgroundImageView.isHidden = true
        backgroundImageView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        container.addSubview(backgroundImageView)

        let washView = UIView()
        washView.translatesAutoresizingMaskIntoConstraints = false
        washView.isUserInteractionEnabled = false
        washView.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.18)
                : UIColor.white.withAlphaComponent(0.38)
        }
        washView.alpha = 0
        washView.isHidden = true
        container.addSubview(washView)

        let imageView = PPUniversalMirroredImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.mirroredBackgroundImageView = backgroundImageView
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: container.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            washView.topAnchor.constraint(equalTo: container.topAnchor),
            washView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            washView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            washView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let haloLayer = CAGradientLayer()
        haloLayer.name = "PPUniversalTapHaloLayer"
        haloLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        haloLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        haloLayer.locations = [0.0, 0.48, 1.0]
        haloLayer.opacity = 0.0
        if #available(iOS 12.0, *) {
            haloLayer.type = .radial
        }
        container.layer.addSublayer(haloLayer)
        references.tapHaloLayer = haloLayer

        context.coordinator.backgroundImageView = backgroundImageView
        context.coordinator.washView = washView
        context.coordinator.imageView = imageView
        container.backgroundImageView = backgroundImageView
        container.washView = washView
        container.primaryImageView = imageView
        references.imageContainer = container
        references.imageView = imageView
        return container
    }

    func updateUIView(
        _ container: PPUniversalGradientView,
        context: Context
    ) {
        guard let imageView = context.coordinator.imageView ?? references.imageView else {
            return
        }
        if let mediaContainer = container as? PPUniversalMediaContainerView {
            mediaContainer.topCornerRadius = topCornerRadius
            mediaContainer.bottomCornerRadius = bottomCornerRadius
            mediaContainer.backgroundImageView =
                context.coordinator.backgroundImageView
            mediaContainer.washView = context.coordinator.washView
            mediaContainer.primaryImageView = imageView
            mediaContainer.setNeedsLayout()
        }
        let fillsEmptyArea =
            contained && fillsEmptyAreaWithImageBackground
        imageView.contentMode = .scaleAspectFill
        context.coordinator.setImageBackgroundVisible(fillsEmptyArea)

        guard context.coordinator.signature != signature else {
            return
        }
        context.coordinator.signature = signature
        context.coordinator.task?.cancel()
        context.coordinator.task = nil
        imageView.image =
            placeholder ??
            UIImage(systemName: placeholderSystemImage)

        if let imageLoader {
            imageLoader(imageView, imageURL, placeholder, container)
            imageView.contentMode = .scaleAspectFill
            context.coordinator.setImageBackgroundVisible(fillsEmptyArea)
            return
        }

        guard let imageURL,
              let url = URL(string: imageURL) else {
            return
        }
        context.coordinator.task = URLSession.shared.dataTask(
            with: url
        ) { data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                return
            }
            DispatchQueue.main.async {
                guard context.coordinator.signature == signature else {
                    return
                }
                UIView.transition(
                    with: imageView,
                    duration: 0.2,
                    options: [.transitionCrossDissolve, .allowAnimatedContent]
                ) {
                    imageView.image = image
                }
            }
        }
        context.coordinator.task?.resume()
    }

    static func dismantleUIView(
        _ uiView: PPUniversalGradientView,
        coordinator: Coordinator
    ) {
        coordinator.task?.cancel()
    }

    final class Coordinator {
        var signature = ""
        var task: URLSessionDataTask?
        weak var imageView: UIImageView?
        weak var backgroundImageView: UIImageView?
        weak var washView: UIView?

        func setImageBackgroundVisible(_ visible: Bool) {
            backgroundImageView?.isHidden = !visible
            washView?.isHidden = !visible
            backgroundImageView?.alpha = visible ? 0.24 : 0
            washView?.alpha = visible ? 1 : 0
            if visible {
                backgroundImageView?.image = imageView?.image
            } else {
                backgroundImageView?.image = nil
            }
        }
    }
}

@available(iOS 16.0, *)
private struct PPUniversalFavoriteRepresentable: UIViewRepresentable {
    let itemID: String
    let collection: String
    let isRightToLeft: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> FavoriteFloatingButton {
        let button = FavoriteFloatingButton(type: .custom)
        button.hidesBackground = false
        return button
    }

    func updateUIView(
        _ button: FavoriteFloatingButton,
        context: Context
    ) {
        button.semanticContentAttribute =
            isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        let signature = "\(collection)|\(itemID)"
        guard signature != context.coordinator.signature else {
            return
        }
        context.coordinator.signature = signature
        button.adID = itemID
        button.collection = collection
        button.initValue()
    }

    final class Coordinator {
        var signature = ""
    }
}

// MARK: - Supporting Views

@available(iOS 16.0, *)
private struct PPUniversalPill: View {
    let text: String
    var systemImage: String? = nil
    let foreground: Color
    let background: Color
    let border: Color
    var fillWidth = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage, !systemImage.isEmpty {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .bold))
            }
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(
            .custom(
                "Beiruti-Bold",
                size: 12,
                relativeTo: .caption
            )
        )
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .frame(minHeight: 26)
        .frame(maxWidth: fillWidth ? .infinity : nil)
        .background(background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(border, lineWidth: 0.75))
    }
}

@available(iOS 16.0, *)
private struct PPUniversalScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.96 : 1
            )
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.06)
                    : .spring(response: 0.22, dampingFraction: 0.80),
                value: configuration.isPressed
            )
    }
}

@available(iOS 16.0, *)
private struct PPUniversalSkeletonCard: View {
    let horizontal: Bool
    let catalog: Bool
    let cardRadius: CGFloat
    let mediaTopRadius: CGFloat
    let mediaBottomRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if horizontal {
                HStack(spacing: 14) {
                    skeletonMedia
                        .frame(width: 138)
                    horizontalSkeletonBody
                }
                .padding(12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    skeletonMedia
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(5)

                    verticalSkeletonBody
                        .layoutPriority(1)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            }
        }
        .background(
            RoundedRectangle(
                cornerRadius: cardRadius,
                style: .continuous
            )
            .fill(
                Color(uiColor: .secondarySystemGroupedBackground)
                    .opacity(colorScheme == .dark ? 0.58 : 0.42)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: cardRadius,
                style: .continuous
            )
            .stroke(
                Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.045),
                lineWidth: 0.6
            )
        )
        .modifier(PPUniversalShimmer(enabled: !reduceMotion))
        .accessibilityHidden(true)
    }

    private var skeletonMedia: some View {
        let shape = PPUniversalMediaRoundedShape(
            topRadius: mediaTopRadius,
            bottomRadius: mediaBottomRadius
        )
        return shape
            .fill(
                LinearGradient(
                    colors: [
                        skeletonColor.opacity(0.58),
                        skeletonColor.opacity(0.92),
                        skeletonColor.opacity(0.62)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                shape
                    .stroke(Color.primary.opacity(0.035), lineWidth: 0.5)
            )
            .frame(maxHeight: .infinity)
    }

    private var verticalSkeletonBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            skeletonBar(width: catalog ? 0.70 : 0.76, height: 12)
            skeletonBar(width: catalog ? 0.48 : 0.54, height: 9)
            skeletonBar(width: catalog ? 0.44 : 0.50, height: 16)
                .padding(.top, 2)
            skeletonBar(width: 0.92, height: catalog ? 30 : 34)
                .padding(.top, 3)

            HStack(spacing: 6) {
                Capsule()
                    .fill(skeletonColor)
                    .frame(width: catalog ? 58 : 74, height: 16)
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }

    private var horizontalSkeletonBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            skeletonBar(width: 0.85, height: 14)
            skeletonBar(width: 0.60, height: 11)

            Spacer(minLength: 4)

            HStack {
                Capsule()
                    .fill(skeletonColor)
                    .frame(width: 64, height: 16)
                Spacer()
                Capsule()
                    .fill(skeletonColor)
                    .frame(width: 34, height: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func skeletonBar(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(skeletonColor)
                .frame(width: proxy.size.width * width, height: height)
        }
        .frame(height: height)
    }

    private var skeletonColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.075)
            : .black.opacity(0.036)
    }
}

@available(iOS 16.0, *)
private struct PPUniversalShimmer: ViewModifier {
    let enabled: Bool
    @State private var phase: CGFloat = -1.1

    func body(content: Content) -> some View {
        content
            .overlay {
                if enabled {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.12),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width * 0.44)
                        .rotationEffect(.degrees(12))
                        .offset(x: proxy.size.width * phase)
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard enabled else {
                    return
                }
                withAnimation(
                    .linear(duration: 1.45)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }
}

private enum PPUniversalHaptics {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.68)
    }

    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.78)
    }
}

// MARK: - UICollectionView Bridge

@available(iOS 16.0, *)
private enum PPUniversalCardContextActionKind {
    case viewDetails
    case favorite
    case share
    case addToCart
    case visibility
    case report
    case saveForLater
}

@available(iOS 16.0, *)
private struct PPUniversalCardContextAction {
    let kind: PPUniversalCardContextActionKind
    let title: String
    let systemImage: String
    var attributes: UIMenuElement.Attributes = []
}

@available(iOS 16.0, *)
@objc(PPUniversalCardHostingCell)
public final class PPUniversalCardHostingCell: UICollectionViewCell, UIContextMenuInteractionDelegate {
    @objc public static let bridgeReuseIdentifier = "PPUniversalCell"

    private let store: PPUniversalCardStore
    private var bridgeViewModel: PPUniversalCellViewModel?
    private var bridgeImageLoader: PPImageLoader?
    private let fallbackImageView = UIImageView()
    private let fallbackImageContainer = PPUniversalGradientView()
    private var contextMenuInteraction: UIContextMenuInteraction?
    private var observers: [NSObjectProtocol] = []

    @objc public weak var delegate: PPUniversalCellDelegate? {
        didSet {
            store.updatePresentationHost(delegate)
        }
    }

    @objc public var indexPath: IndexPath? {
        didSet {
            bridgeViewModel?.indexPath = indexPath
        }
    }

    @objc public var context: PPCellContext = .forAds
    @objc public var layoutMode: PPManagerCellLayoutMode = .cellLayoutModeNil
    @objc public var discountStyle: PPDiscountStyle = .badge

    @objc public var onTap: (() -> Void)? {
        didSet {
            store.cardTap = onTap
        }
    }

    @objc public var hideTopBadge = false {
        didSet {
            reconfigureIfNeeded()
        }
    }

    @objc public var showsSubtitle = false {
        didSet {
            reconfigureIfNeeded()
        }
    }

    @objc public var forceShowsOwnerMenuButton = false {
        didSet {
            reconfigureIfNeeded()
        }
    }

    @objc public var userBordersV2 = true {
        didSet {
            store.userBordersV2 = userBordersV2
        }
    }

    /// PPDataViewVC sets this explicitly because layout normalization differs
    /// from embedded carousels that reuse the same Objective-C API.
    @objc public var dataViewPresentation = false {
        didSet {
            reconfigureIfNeeded()
        }
    }

    @objc public var quantity: Int {
        store.quantity
    }

    @objc public var imageView: UIImageView {
        get {
            store.uiReferences.imageView  ?? fallbackImageView
        }
        set {
            fallbackImageView.image = newValue.image
        }
    }

    @objc public var imageContainer: PPUniversalGradientView {
        get {
            store.uiReferences.imageContainer ?? fallbackImageContainer
        }
        set {
            fallbackImageContainer.backgroundColor = newValue.backgroundColor
        }
    }

    public override init(frame: CGRect) {
        let initialModel = PPUniversalCardModel(
            id: "initial-placeholder",
            title: "",
            isSkeleton: true
        )
        let initialStore = PPUniversalCardStore(
            model: initialModel,
            context: .market,
            layout: .market,
            discountStyle: .badge,
            palette: .purePets,
            actions: .init()
        )
        store = initialStore
        super.init(frame: frame)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
        isAccessibilityElement = false

        contentConfiguration = UIHostingConfiguration {
            PPUniversalCardRenderer(store: initialStore)
        }
        .margins(.all, 0)

        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .clear
        backgroundConfiguration = background

        installObservers()
        installFocusPreviewInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError(
            "PPUniversalCardHostingCell must be created programmatically."
        )
    }

    deinit {
        clearObservers()
    }

    @objc public static func reuseIdentifier() -> String {
        bridgeReuseIdentifier
    }

    @objc public func stopMediaPlayback() {
        store.stopMediaPlayback()
    }

    @objc public func refreshThemeAppearance() {
        semanticContentAttribute =
            PPUniversalCellSwiftUIBridge.isRightToLeft()
                ? .forceRightToLeft
                : .forceLeftToRight
        store.refreshEnvironment()
    }

    @objc public func setQuantity(
        _ quantity: Int,
        animated: Bool
    ) {
        store.setQuantity(
            quantity,
            animated: animated,
            notifyDelegate: false
        )
    }

    @objc public func collapseStepper(_ animated: Bool) {
        store.collapseStepper(animated: animated)
    }

    @objc(
        applyViewModel:context:layoutMode:discountMode:imageLoader:
    )
    public func applyViewModel(
        _ viewModel: PPUniversalCellViewModel,
        context: PPCellContext,
        layoutMode: PPManagerCellLayoutMode,
        discountMode: PPDiscountStyle,
        imageLoader: PPImageLoader?
    ) {
        bridgeViewModel = viewModel
        bridgeImageLoader = imageLoader
        self.context = context
        self.layoutMode = layoutMode
        self.discountStyle = discountMode
        indexPath = viewModel.indexPath
        store.delegate = delegate
        store.cardTap = onTap
        configureStore()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        clearObservers()
        bridgeViewModel = nil
        bridgeImageLoader = nil
        delegate = nil
        indexPath = nil
        onTap = nil
        context = .forAds
        layoutMode = .cellLayoutModeNil
        discountStyle = .badge
        hideTopBadge = false
        showsSubtitle = false
        forceShowsOwnerMenuButton = false
        userBordersV2 = true
        dataViewPresentation = false
        transform = .identity
        alpha = 1
        contentView.transform = .identity
        accessibilityCustomActions = nil
        contentView.accessibilityCustomActions = nil
        store.resetForReuse()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            store.stopMediaPlayback()
        }
    }

    public override var isHighlighted: Bool {
        didSet {
            store.isHighlighted = isHighlighted
        }
    }

    public override var isSelected: Bool {
        didSet {
            store.isSelected = isSelected
        }
    }

    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.hasDifferentColorAppearance(
            comparedTo: traitCollection
        ) == true {
            refreshThemeAppearance()
        }
    }

    private func reconfigureIfNeeded() {
        guard bridgeViewModel != nil else {
            return
        }
        configureStore()
    }

    private func configureStore() {
        guard let bridgeViewModel else {
            return
        }
        clearObservers()
        installObservers()
        store.configure(
            viewModel: bridgeViewModel,
            context: context,
            layout: layoutMode,
            discountStyle: discountStyle,
            imageLoader: bridgeImageLoader,
            hideTopBadge: hideTopBadge,
            showsSubtitle: showsSubtitle,
            forceShowsOwnerMenuButton: forceShowsOwnerMenuButton,
            dataViewPresentation: dataViewPresentation
        )
        updateAccessibilityContextActions()
    }

    private func installFocusPreviewInteraction() {
        let interaction = UIContextMenuInteraction(delegate: self)
        addInteraction(interaction)
        contextMenuInteraction = interaction
    }

    private func contextActions() -> [PPUniversalCardContextAction] {
        guard bridgeViewModel != nil, !store.model.isSkeleton else {
            return []
        }

        var items: [PPUniversalCardContextAction] = [
            PPUniversalCardContextAction(
                kind: .viewDetails,
                title: PPUniversalCardStore.localized(
                    "Details",
                    fallback: "Details"
                ),
                systemImage: "arrow.up.right.square"
            )
        ]

        if store.showsFavorite && delegateResponds(to: "PPUniversalCell_tapFavorite:") {
            items.append(
                PPUniversalCardContextAction(
                    kind: .favorite,
                    title: PPUniversalCardStore.localized(
                        "showfav",
                        fallback: "Favorite"
                    ),
                    systemImage: "heart"
                )
            )
        }

        if delegateResponds(to: "PPUniversalCell_tapShare:") {
            items.append(
                PPUniversalCardContextAction(
                    kind: .share,
                    title: PPUniversalCardStore.localized(
                        "Share",
                        fallback: "Share"
                    ),
                    systemImage: "square.and.arrow.up"
                )
            )
        }

        if store.model.usesQuantityControl &&
            !store.isOutOfStock &&
            delegateResponds(to: "PPUniversalCell_changeQuantity:quantity:") {
            items.append(
                PPUniversalCardContextAction(
                    kind: .addToCart,
                    title: PPUniversalCardStore.localized(
                        "addToCart",
                        fallback: "Add to Cart"
                    ),
                    systemImage: "cart.badge.plus"
                )
            )
        }

        if store.model.isOwner &&
            delegateResponds(to: "PPUniversalCell_tapVisibilityToggle:") {
            let hidesListing = store.model.isPubliclyVisible
            items.append(
                PPUniversalCardContextAction(
                    kind: .visibility,
                    title: PPUniversalCardStore.localized(
                        hidesListing
                            ? "listing_hide_action"
                            : "listing_show_action",
                        fallback: hidesListing ? "Hide" : "Show"
                    ),
                    systemImage: hidesListing ? "eye.slash" : "eye"
                )
            )
        }

        items.append(
            PPUniversalCardContextAction(
                kind: .saveForLater,
                title: PPUniversalCardStore.localized(
                    "saved_for_later",
                    fallback: "Save for later"
                ),
                systemImage: "bookmark"
            )
        )

        items.append(
            PPUniversalCardContextAction(
                kind: .report,
                title: PPUniversalCardStore.localized(
                    "report",
                    fallback: "Report"
                ),
                systemImage: "flag",
                attributes: .destructive
            )
        )

        return items
    }

    private func delegateResponds(to selectorName: String) -> Bool {
        guard let object = delegate as? NSObjectProtocol else {
            return false
        }
        return object.responds(to: NSSelectorFromString(selectorName))
    }

    private func performContextAction(_ kind: PPUniversalCardContextActionKind) {
        PPUniversalHaptics.light()
        switch kind {
        case .viewDetails:
            store.tapCard()
        case .favorite:
            store.tapFavorite()
        case .share:
            store.tapShare()
        case .addToCart:
            store.handlePrimaryAction()
        case .visibility:
            store.tapVisibility()
        case .report:
            if let vm = bridgeViewModel {
                delegate?.ppUniversalCell_tapReport?(vm)
            }
        case .saveForLater:
            if let vm = bridgeViewModel {
                delegate?.ppUniversalCell_tapSave?(forLater: vm)
            }
        }
    }

    private func updateAccessibilityContextActions() {
        let actions = contextActions()
        let customActions = actions.map { action in
            UIAccessibilityCustomAction(name: action.title) { [weak self] _ in
                self?.performContextAction(action.kind)
                return true
            }
        }
        accessibilityCustomActions = customActions
        contentView.accessibilityCustomActions = customActions
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        let actions = contextActions()
        guard !actions.isEmpty else {
            return nil
        }

        store.showsOwnerRow = true
        store.isContextFocused = true

        return UIContextMenuConfiguration(
            identifier: bridgeViewModel?.modelID as NSString?,
            previewProvider: nil
        ) { [weak self] _ in
            guard let self else {
                return nil
            }
            let menuActions = actions.map { item in
                let action = UIAction(
                    title: item.title,
                    image: UIImage(systemName: item.systemImage),
                    attributes: item.attributes
                ) { [weak self] _ in
                    self?.performContextAction(item.kind)
                }
                if #available(iOS 16.0, *) {
                    if let customFont = UIFont(name: "Beiruti-Medium", size: 16.0) {
                        let attrString = NSAttributedString(
                             string: item.title,
                             attributes: [.font: customFont]
                        )
                        action.setValue(attrString, forKey: "attributedTitle")
                    }
                }
                return action
            }
            return UIMenu(title: "", options: .displayInline, children: menuActions)
        }
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        contextMenuTargetedPreview()
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        contextMenuTargetedPreview()
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        PPUniversalHaptics.medium()
        store.isContextFocused = true
        guard !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        animator?.addAnimations { [weak self] in
            self?.contentView.transform = CGAffineTransform(scaleX: 1.018, y: 1.018)
        }
    }

    public func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        animator?.addAnimations { [weak self] in
            self?.contentView.transform = .identity
            self?.store.isContextFocused = false
        }
        animator?.addCompletion { [weak self] in
            self?.store.showsOwnerRow = false
        }
    }

    private func contextMenuTargetedPreview() -> UITargetedPreview {
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: contentView.bounds,
            cornerRadius: 18
        )
        return UITargetedPreview(
            view: contentView,
            parameters: parameters
        )
    }

    private func clearObservers() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        observers.removeAll()
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: Notification.Name("CartUpdated"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.store.refreshCartQuantity()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.store.stopMediaPlayback()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: Notification.Name("PPSaveForLaterUpdatedNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.store.refreshSavedForLaterState()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: Notification.Name("PPLanguageDidChangeNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshThemeAppearance()
                self?.reconfigureIfNeeded()
            }
        )
    }
}

private struct PPUniversalMediaRoundedShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else {
            return Path(CGRect.zero)
        }

        let maximumRadius = min(rect.width, rect.height) * 0.5
        let top = min(max(0, topRadius), maximumRadius)
        let bottom = min(max(0, bottomRadius), maximumRadius)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + top),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct PPUniversalTopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: [.topLeft, .topRight],
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}

extension View {
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
}
