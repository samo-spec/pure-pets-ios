import UIKit

// MARK: - MainKindsCellV2 — Portrait Sanctuary Card
//
// Implements the approved first category-card direction: a compact editorial
// portrait card rather than a generic tile. Each category owns a quiet pastel
// habitat, a floating semantic badge, a portrait-dominant animal stage, and a
// softly curved porcelain title plate. Selection stays restrained: stronger
// outline, title weight and identity dash instead of a saturated full-card fill.
//
// HomeStore remains the single source of truth for selection, persistence,
// routing, and haptics. Animal artwork is never mirrored in RTL.

@objc(MainKindsCellV2)
public final class MainKindsCellV2: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "MainKindsCellV2" }

    @objc public var onSelect: ((NSObject?, Bool) -> Void)? {
        didSet {
            if onSelect == nil { stopAllMotion() }
            updateInteractionAvailability()
        }
    }
    @objc public var boundCellID: String?

    // MARK: - Subview Hierarchy

    private let actionButton = UIButton(type: .custom)
    private let pressureContainer = UIView()
    private let shadowHostView = UIView()
    private let capsuleView = UIView()
    private let cardBackgroundView = UIView()
    private let surfaceFillView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let stageBackdropGlow = UIView()
    private let stagePlinthView = UIView()
    private let borderLayer = CAShapeLayer()
    private let titlePlateLayer = CAShapeLayer()
    private let categoryBadgeView = UIView()
    private let categoryBadgeGlyphView = UIImageView()

    // Pet Stage
    private let stageView = UIView()
    private let portraitContainer = UIView()
    private let artworkView = UIImageView()
    private let allArtworkViews = (0..<3).map { _ in UIImageView() }
    private let allFallbackBadge = UIImageView()

    // Typography & Indicator
    private let typographyContainer = UIView()
    private let titleLabel = UILabel()
    private let activePipView = UIView()

    // MARK: - State & Model

    private var content: MainKindsV2Content?
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var hasConfigured = false
    private var primaryImageGeneration = 0
    private var primaryImageRequestView: UIImageView?
    private var allPreviewContents: [MainKindsV2Content] = []
    private var allPreviewGeneration = 0
    private var allPreviewRequestViews: [UIImageView?] = Array(repeating: nil, count: 3)
    private var observers: [NSObjectProtocol] = []

    // Animators
    private var pressureAnimator: UIViewPropertyAnimator?
    private var selectionAnimator: UIViewPropertyAnimator?
    private var activationAnimator: UIViewPropertyAnimator?
    private var pressureGeneration = 0
    private var selectionGeneration = 0
    private var activationGeneration = 0
    private var activationInFlight = false
    private var lastActivationTime: CFTimeInterval = 0

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private var usesExpandedTextLayout: Bool {
        let category = traitCollection.preferredContentSizeCategory
        return category.isAccessibilityCategory || category == .extraExtraExtraLarge
    }

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        buildViewGraph()
        registerForEnvironmentChanges()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("MainKindsCellV2 supports code-only UIKit.")
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        cancelPrimaryImageRequest()
        cancelAllPreviewRequests()
        pressureAnimator?.stopAnimation(true)
        selectionAnimator?.stopAnimation(true)
        activationAnimator?.stopAnimation(true)
    }

    // MARK: - Lifecycle & Reuse

    public override func prepareForReuse() {
        super.prepareForReuse()
        onSelect = nil
        cancelPrimaryImageRequest()
        resetAllPreview()
        stopAllMotion()
        content = nil
        boundCellID = nil
        hasConfigured = false
        isKindSelected = false
        usesRestoredSelectionAppearance = false
        lastActivationTime = 0
        artworkView.image = nil
        titleLabel.text = nil
        actionButton.accessibilityLabel = nil
        actionButton.accessibilityIdentifier = nil
        actionButton.largeContentTitle = nil
        actionButton.largeContentImage = nil
        updateTypography()
        updateAppearance(animated: false)
        applySelectionPose()
        updateInteractionAvailability()
        setNeedsLayout()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stopAllMotion() }
    }

    // MARK: - View Graph Construction

    private func buildViewGraph() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        isAccessibilityElement = false
        contentView.isAccessibilityElement = false

        // Action button captures all touches & accessibility events
        actionButton.isExclusiveTouch = true
        actionButton.isAccessibilityElement = true
        actionButton.showsLargeContentViewer = true
        actionButton.scalesLargeContentImage = true
        actionButton.addInteraction(UILargeContentViewerInteraction())
        actionButton.isPointerInteractionEnabled = true
        actionButton.addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        actionButton.addTarget(self, action: #selector(handleTouchRelease), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        actionButton.addTarget(self, action: #selector(handleActivation), for: .primaryActionTriggered)
        contentView.addSubview(actionButton)
        accessibilityElements = [actionButton]

        // Pressure container handles spring depression
        pressureContainer.isUserInteractionEnabled = false
        pressureContainer.backgroundColor = .clear
        actionButton.addSubview(pressureContainer)

        // Shadow host holds ambient elevation
        shadowHostView.isUserInteractionEnabled = false
        shadowHostView.backgroundColor = .clear
        pressureContainer.addSubview(shadowHostView)

        // Capsule view (continuous squircle)
        capsuleView.isUserInteractionEnabled = false
        capsuleView.backgroundColor = .clear
        capsuleView.layer.cornerCurve = .continuous
        capsuleView.layer.cornerRadius = MainKindsCellV2Layout.cardCornerRadius
        capsuleView.clipsToBounds = false // Allows pet head/ears to gently break upper shoulder
        pressureContainer.addSubview(capsuleView)

        // Clipped background container
        cardBackgroundView.isUserInteractionEnabled = false
        cardBackgroundView.backgroundColor = .clear
        cardBackgroundView.layer.cornerCurve = .continuous
        cardBackgroundView.layer.cornerRadius = MainKindsCellV2Layout.cardCornerRadius
        cardBackgroundView.clipsToBounds = true
        capsuleView.addSubview(cardBackgroundView)

        // Surface fills
        surfaceFillView.isUserInteractionEnabled = false
        cardBackgroundView.addSubview(surfaceFillView)

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        cardBackgroundView.layer.addSublayer(gradientLayer)

        stageBackdropGlow.isUserInteractionEnabled = false
        stageBackdropGlow.backgroundColor = .clear
        stageBackdropGlow.layer.cornerCurve = .continuous
        cardBackgroundView.addSubview(stageBackdropGlow)

        // Border layer
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineCap = .round
        capsuleView.layer.addSublayer(borderLayer)

        // Stage view & plinth
        stageView.isUserInteractionEnabled = false
        stageView.backgroundColor = .clear
        stageView.clipsToBounds = false
        cardBackgroundView.addSubview(stageView)

        stagePlinthView.isUserInteractionEnabled = false
        stagePlinthView.backgroundColor = UIColor.black.withAlphaComponent(0.025)
        stagePlinthView.layer.cornerCurve = .continuous
        stageView.addSubview(stagePlinthView)

        portraitContainer.isUserInteractionEnabled = false
        portraitContainer.backgroundColor = .clear
        portraitContainer.clipsToBounds = false
        stageView.addSubview(portraitContainer)

        // Artwork views (single + all ensemble)
        for view in [artworkView] + allArtworkViews.reversed() {
            view.contentMode = .scaleAspectFit
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
            view.accessibilityIgnoresInvertColors = true
            portraitContainer.addSubview(view)
        }
        allArtworkViews.forEach { $0.isHidden = true }

        allFallbackBadge.contentMode = .scaleAspectFit
        allFallbackBadge.isUserInteractionEnabled = false
        allFallbackBadge.isAccessibilityElement = false
        allFallbackBadge.image = UIImage(systemName: "pawprint.fill")
        allFallbackBadge.isHidden = true
        portraitContainer.addSubview(allFallbackBadge)

        // Curved porcelain title plate overlays the lower portrait edge.
        typographyContainer.isUserInteractionEnabled = false
        typographyContainer.backgroundColor = .clear
        cardBackgroundView.addSubview(typographyContainer)
        titlePlateLayer.fillColor = UIColor.clear.cgColor
        typographyContainer.layer.addSublayer(titlePlateLayer)

        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.adjustsFontForContentSizeCategory = true
        typographyContainer.addSubview(titleLabel)

        activePipView.layer.cornerRadius = 2.0
        activePipView.layer.cornerCurve = .continuous
        typographyContainer.addSubview(activePipView)

        // Floating category badge: intentionally decorative; VoiceOver reads the button.
        categoryBadgeView.isUserInteractionEnabled = false
        categoryBadgeView.isAccessibilityElement = false
        categoryBadgeView.layer.cornerCurve = .continuous
        categoryBadgeView.layer.shadowOffset = CGSize(width: 0, height: 2)
        categoryBadgeView.layer.shadowRadius = 5
        capsuleView.addSubview(categoryBadgeView)

        categoryBadgeGlyphView.contentMode = .scaleAspectFit
        categoryBadgeGlyphView.isUserInteractionEnabled = false
        categoryBadgeGlyphView.isAccessibilityElement = false
        categoryBadgeGlyphView.accessibilityIgnoresInvertColors = false
        categoryBadgeView.addSubview(categoryBadgeGlyphView)

        applyLayoutDirection()
        updateTypography()
        updateAppearance(animated: false)
        updateInteractionAvailability()
    }

    // MARK: - Layout Subviews

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard contentView.bounds.width > 0, contentView.bounds.height > 0 else { return }

        actionButton.frame = contentView.bounds
        pressureContainer.bounds = CGRect(origin: .zero, size: actionButton.bounds.size)
        pressureContainer.center = CGPoint(x: actionButton.bounds.midX, y: actionButton.bounds.midY)

        let geometry = MainKindsCellV2Layout(
            bounds: pressureContainer.bounds,
            title: titleLabel.text ?? "",
            fontSize: titleLabel.font.pointSize,
            expandedText: usesExpandedTextLayout
        )

        capsuleView.frame = geometry.cardFrame
        shadowHostView.frame = geometry.cardFrame
        cardBackgroundView.frame = capsuleView.bounds
        surfaceFillView.frame = cardBackgroundView.bounds
        stageBackdropGlow.frame = geometry.ambientFrame
        stageBackdropGlow.layer.cornerRadius = geometry.ambientFrame.height / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = cardBackgroundView.bounds
        let borderPath = UIBezierPath(
            roundedRect: capsuleView.bounds,
            cornerRadius: MainKindsCellV2Layout.cardCornerRadius
        )
        borderLayer.path = borderPath.cgPath
        borderLayer.frame = capsuleView.bounds

        // Ambient elevation shadow path
        shadowHostView.layer.shadowPath = borderPath.cgPath
        CATransaction.commit()

        // Portrait stage and soft contact shadow.
        stageView.frame = geometry.stageFrame
        stagePlinthView.frame = geometry.groundFrame
        stagePlinthView.layer.cornerRadius = geometry.groundFrame.height / 2

        portraitContainer.frame = geometry.portraitFrame

        if content?.isAll == true {
            layoutAllArtwork()
        } else {
            // Species-calibrated optical frame
            let opticalSide = max(0, min(portraitContainer.bounds.width, portraitContainer.bounds.height))
            let opticalCanvas = CGRect(
                x: (portraitContainer.bounds.width - opticalSide) / 2,
                y: (portraitContainer.bounds.height - opticalSide) / 2,
                width: opticalSide,
                height: opticalSide
            )
            let treatment = HomeSpeciesArtworkTreatment.resolved(for: content?.numericID ?? 0)
            let treated = treatment.frame(in: opticalCanvas)

            // Allow subtle upper shoulder break (3-4pt) for living 3D presence
            let room = CGRect(
                x: -PPSpace.xs,
                y: -PPSpace.sm,
                width: portraitContainer.bounds.width + PPSpace.sm,
                height: portraitContainer.bounds.height + PPSpace.sm
            )
            let scale = min(1.0, room.width / max(treated.width, 1), room.height / max(treated.height, 1))
            let size = CGSize(width: treated.width * scale, height: treated.height * scale)
            artworkView.frame = CGRect(
                x: min(max(treated.midX - size.width / 2, room.minX), room.maxX - size.width),
                y: min(max(treated.midY - size.height / 2, room.minY), room.maxY - size.height),
                width: size.width,
                height: size.height
            )
        }

        // Curved title plate, title and identity dash.
        typographyContainer.frame = geometry.titlePlateFrame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        titlePlateLayer.frame = typographyContainer.bounds
        titlePlateLayer.path = MainKindsCellV2Layout.titlePlatePath(in: typographyContainer.bounds).cgPath
        CATransaction.commit()

        titleLabel.frame = geometry.titleFrame.offsetBy(
            dx: -geometry.titlePlateFrame.minX,
            dy: -geometry.titlePlateFrame.minY
        )
        activePipView.frame = geometry.pipFrame.offsetBy(
            dx: -geometry.titlePlateFrame.minX,
            dy: -geometry.titlePlateFrame.minY
        )

        // Badge follows semantic leading while artwork itself remains biological LTR.
        let badgeBase = geometry.badgeFrame
        let isRTL = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        let badgeX = isRTL
            ? capsuleView.bounds.width - badgeBase.maxX
            : badgeBase.minX
        categoryBadgeView.frame = CGRect(
            x: badgeX,
            y: badgeBase.minY,
            width: badgeBase.width,
            height: badgeBase.height
        ).integral
        let glyphInset = max(7, categoryBadgeView.bounds.width * 0.27)
        categoryBadgeGlyphView.frame = categoryBadgeView.bounds.insetBy(dx: glyphInset, dy: glyphInset)
        categoryBadgeView.layer.cornerRadius = categoryBadgeView.bounds.height / 2
        categoryBadgeView.layer.shadowPath = UIBezierPath(ovalIn: categoryBadgeView.bounds).cgPath
    }

    private func layoutAllArtwork() {
        let canvas = portraitContainer.bounds
        let activeViews = allArtworkViews.filter { !$0.isHidden && $0.image != nil }

        if activeViews.count >= 2 {
            artworkView.isHidden = true
            allFallbackBadge.isHidden = true

            // Triad ensemble layout
            for (index, view) in activeViews.enumerated() {
                let norm: CGRect
                if activeViews.count == 2 {
                    norm = index == 0
                        ? CGRect(x: 0.04, y: 0.10, width: 0.62, height: 0.84)
                        : CGRect(x: 0.34, y: 0.04, width: 0.62, height: 0.84)
                } else {
                    switch index {
                    case 0: // Center/Foreground (Dog)
                        norm = CGRect(x: 0.16, y: 0.18, width: 0.68, height: 0.82)
                    case 1: // Midground Left (Cat)
                        norm = CGRect(x: 0.00, y: 0.02, width: 0.56, height: 0.74)
                    default: // Background Right (Falcon/Bird)
                        norm = CGRect(x: 0.44, y: 0.02, width: 0.56, height: 0.74)
                    }
                }
                view.frame = CGRect(
                    x: norm.minX * canvas.width,
                    y: norm.minY * canvas.height,
                    width: norm.width * canvas.width,
                    height: norm.height * canvas.height
                ).integral
            }
        } else {
            // Fallback or single icon
            let side = min(canvas.width, canvas.height) * 0.62
            let centerFrame = CGRect(
                x: (canvas.width - side) / 2,
                y: (canvas.height - side) / 2,
                width: side,
                height: side
            ).integral

            if artworkView.image != nil {
                artworkView.frame = centerFrame
                artworkView.isHidden = false
                allFallbackBadge.isHidden = true
            } else {
                allFallbackBadge.frame = centerFrame
                allFallbackBadge.isHidden = false
                artworkView.isHidden = true
            }
        }
    }

    // MARK: - Configuration Interface

    @objc(configureWithMainKind:isAll:selected:)
    public func configure(withMainKind kind: NSObject?, isAll: Bool, selected: Bool) {
        configure(withMainKind: kind, isAll: isAll, selected: selected, restoredSelectionAppearance: false)
    }

    @objc(configureWithMainKind:isAll:selected:restoredSelectionAppearance:)
    public func configure(
        withMainKind kind: NSObject?,
        isAll: Bool,
        selected: Bool,
        restoredSelectionAppearance: Bool
    ) {
        let next = MainKindsV2Content(kind: kind, isAll: isAll)
        let bindingChanged = boundCellID != next.cellID
        let artworkChanged = content.map { !$0.hasSameArtwork(as: next) } ?? true
        let selectionChanged = hasConfigured && isKindSelected != selected

        if bindingChanged {
            cancelPrimaryImageRequest()
            resetAllPreview()
            stopAllMotion()
            lastActivationTime = 0
        }

        content = next
        boundCellID = next.cellID
        isKindSelected = selected
        usesRestoredSelectionAppearance = selected && restoredSelectionAppearance
        hasConfigured = true

        applyLayoutDirection()
        updateTypography()
        updateContent()

        if bindingChanged || artworkChanged || artworkView.image == nil {
            configurePrimaryArtwork(for: next)
        }

        if selectionChanged && !bindingChanged && !restoredSelectionAppearance {
            animateSelection(restored: false)
        } else {
            stopSelectionMotion()
            updateAppearance(animated: false)
            applySelectionPose()
        }

        updateInteractionAvailability()
        setNeedsLayout()
    }

    public func configureAllPreview(withMainKinds kinds: [NSObject]) {
        guard content?.isAll == true else { return }
        var seen = Set<String>()
        let next = Array(
            kinds.map { MainKindsV2Content(kind: $0, isAll: false) }
                .filter { seen.insert($0.cellID).inserted }
                .prefix(allArtworkViews.count)
        )
        let unchanged = next.count == allPreviewContents.count
            && zip(next, allPreviewContents).allSatisfy { $0.hasSameArtwork(as: $1) }
        guard !unchanged else { return }

        resetAllPreview()
        allPreviewContents = next
        let generation = allPreviewGeneration
        let expectedCellID = boundCellID

        for (index, preview) in next.enumerated() {
            if let local = resolvedLocalArtwork(for: preview) {
                allArtworkViews[index].image = local.image.withRenderingMode(
                    local.isTemplate ? .alwaysTemplate : .alwaysOriginal
                )
            }
            guard !preview.imageURL.isEmpty else { continue }
            let expectedURL = preview.imageURL
            let requestView = UIImageView()
            allPreviewRequestViews[index] = requestView
            PPImageLoaderManager.shared().setImage(
                on: requestView,
                url: expectedURL,
                placeholder: nil,
                transitionStyle: .none
            ) { [weak self] image, _ in
                let applyResult = {
                    guard let self,
                          self.allPreviewGeneration == generation,
                          self.boundCellID == expectedCellID,
                          self.content?.isAll == true,
                          self.allPreviewContents.indices.contains(index),
                          self.allPreviewContents[index].imageURL == expectedURL else { return }
                    self.allPreviewRequestViews[index] = nil
                    guard let image else { return }
                    self.allArtworkViews[index].image = image.withRenderingMode(.alwaysOriginal)
                    self.updateAllArtworkVisibility()
                }
                if Thread.isMainThread { applyResult() }
                else { DispatchQueue.main.async(execute: applyResult) }
            }
        }
        updateAllArtworkVisibility()
    }

    @objc public func playRestoredSelectionAnimation() {
        guard window != nil, isKindSelected, usesRestoredSelectionAppearance else { return }
        animateSelection(restored: true)
    }

    @objc public func playSelectionChangeAnimation() {
        guard window != nil, isKindSelected, !usesRestoredSelectionAppearance else { return }
        animateSelection(restored: false)
    }

    // MARK: - Appearance & Palette

    private func updateContent() {
        guard let content else { return }
        titleLabel.text = content.title
        actionButton.accessibilityLabel = content.title
        actionButton.accessibilityIdentifier = content.isAll
            ? "home.mainKinds.all" : "home.mainKinds.\(content.numericID)"
        actionButton.largeContentTitle = content.title
        actionButton.largeContentImage = artworkView.image
        categoryBadgeGlyphView.image = resolvedBadgeImage(for: content)?.withRenderingMode(.alwaysTemplate)
        categoryBadgeGlyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 16,
            weight: .semibold
        )
    }

    private func updateTypography() {
        let baseFont = MainKindsCellV2Layout.captionFont(
            size: MainKindsCellV2Layout.captionPointSize,
            bold: isKindSelected || UIAccessibility.isBoldTextEnabled
        )
        titleLabel.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: baseFont,
            compatibleWith: traitCollection
        )
        titleLabel.numberOfLines = usesExpandedTextLayout ? 0 : 2
        titleLabel.lineBreakMode = usesExpandedTextLayout ? .byWordWrapping : .byTruncatingTail
    }

    private func updateAppearance(animated: Bool) {
        let palette = MainKindsV2Palette.resolve(
            accent: content?.accent ?? .ppPrimary,
            numericID: content?.numericID ?? 0,
            traits: traitCollection,
            isSelected: isKindSelected
        )

        let applyColors = { [weak self] in
            guard let self else { return }
            self.surfaceFillView.backgroundColor = palette.cardSurface
            self.stageBackdropGlow.backgroundColor = palette.ambientWash
            self.stagePlinthView.backgroundColor = palette.groundShadow
            self.titleLabel.textColor = palette.ink
            self.categoryBadgeView.backgroundColor = palette.badgeSurface
            self.categoryBadgeGlyphView.tintColor = palette.badgeInk
            self.categoryBadgeView.layer.borderColor = palette.badgeBorder.cgColor
            self.categoryBadgeView.layer.borderWidth = self.traitCollection.accessibilityContrast == .high ? 1.5 : 0.75
            self.categoryBadgeView.layer.shadowColor = UIColor.black.cgColor
            self.categoryBadgeView.layer.shadowOpacity = self.traitCollection.userInterfaceStyle == .dark ? 0.22 : 0.08

            self.titleLabel.shadowColor = nil
            self.titleLabel.shadowOffset = .zero

            self.activePipView.backgroundColor = palette.accent
            self.activePipView.alpha = self.isKindSelected ? 1.0 : 0.58
            self.activePipView.transform = self.isKindSelected
                ? CGAffineTransform(scaleX: 1.32, y: 1.0)
                : .identity

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.gradientLayer.opacity = 1.0
            self.gradientLayer.colors = [
                palette.gradientStart.cgColor,
                palette.gradientEnd.cgColor
            ]
            self.titlePlateLayer.fillColor = palette.titlePlate.cgColor
            self.borderLayer.strokeColor = (self.isKindSelected ? palette.selectedBorder : palette.restingBorder).cgColor
            self.borderLayer.lineWidth = self.traitCollection.accessibilityContrast == .high
                ? (self.isKindSelected ? 2.4 : 1.4)
                : (self.isKindSelected ? 1.8 : 0.7)

            self.shadowHostView.layer.shadowColor = palette.shadowColor.cgColor
            self.shadowHostView.layer.shadowOpacity = palette.shadowOpacity
            self.shadowHostView.layer.shadowRadius = self.isKindSelected ? 13.0 : 8.0
            self.shadowHostView.layer.shadowOffset = CGSize(width: 0, height: self.isKindSelected ? 6.0 : 3.0)
            CATransaction.commit()

            self.allFallbackBadge.tintColor = palette.badgeInk
        }

        if animated && !reduceMotion {
            UIView.animate(
                withDuration: 0.26,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction],
                animations: applyColors
            )
        } else {
            applyColors()
        }
    }

    private func applySelectionPose() {
        let lifted = isKindSelected && !reduceMotion
        let transform = lifted
            ? CGAffineTransform(translationX: 0, y: -2.0).scaledBy(x: 1.012, y: 1.012)
            : .identity
        capsuleView.transform = transform
        shadowHostView.transform = transform
    }

    private func updateInteractionAvailability() {
        actionButton.isEnabled = content != nil && onSelect != nil && !activationInFlight
        var traits: UIAccessibilityTraits = .button
        if isKindSelected { traits.insert(.selected) }
        if !actionButton.isEnabled { traits.insert(.notEnabled) }
        actionButton.accessibilityTraits = traits
        pressureContainer.alpha = content != nil && onSelect == nil ? 0.55 : 1.0
    }

    private func resolvedBadgeImage(for content: MainKindsV2Content) -> UIImage? {
        if content.isAll {
            return UIImage(named: "menugrid") ?? UIImage(systemName: "square.grid.2x2.fill")
        }
        if !content.iconName.isEmpty, let image = UIImage(named: content.iconName) {
            return image
        }
        if !content.iconName.isEmpty, let image = UIImage(systemName: content.iconName) {
            return image
        }
        switch content.numericID {
        case 1, 11:
            return UIImage(systemName: "feather") ?? UIImage(systemName: "pawprint.fill")
        default:
            return UIImage(systemName: "pawprint.fill")
        }
    }

    // MARK: - Artwork Loading & Caching

    private func configurePrimaryArtwork(for content: MainKindsV2Content) {
        cancelPrimaryImageRequest()
        let placeholder = resolvedPlaceholder(for: content)
        artworkView.image = placeholder.image?.withRenderingMode(placeholder.isTemplate ? .alwaysTemplate : .alwaysOriginal)
        actionButton.largeContentImage = artworkView.image

        guard !content.isAll, !content.imageURL.isEmpty else { return }
        let generation = primaryImageGeneration
        let expectedCellID = content.cellID
        let expectedURL = content.imageURL
        let requestView = UIImageView()
        primaryImageRequestView = requestView

        PPImageLoaderManager.shared().setImage(
            on: requestView,
            url: expectedURL,
            placeholder: nil,
            transitionStyle: .none
        ) { [weak self] image, _ in
            let applyResult = {
                guard let self,
                      self.primaryImageGeneration == generation,
                      self.boundCellID == expectedCellID,
                      self.content?.imageURL == expectedURL else { return }
                self.primaryImageRequestView = nil
                guard let image else { return }
                self.artworkView.image = image.withRenderingMode(.alwaysOriginal)
                self.actionButton.largeContentImage = self.artworkView.image
            }
            if Thread.isMainThread { applyResult() }
            else { DispatchQueue.main.async(execute: applyResult) }
        }
    }

    private func resolvedPlaceholder(for content: MainKindsV2Content) -> (image: UIImage?, isTemplate: Bool) {
        if content.isAll {
            return (UIImage(named: "menugrid") ?? UIImage(systemName: "pawprint.fill"), true)
        }
        if let local = resolvedLocalArtwork(for: content) {
            return (local.image, local.isTemplate)
        }
        return (UIImage(systemName: "pawprint.fill"), true)
    }

    private func resolvedLocalArtwork(for content: MainKindsV2Content) -> (image: UIImage, isTemplate: Bool)? {
        if let image = content.localImage { return (image, false) }
        if !content.assetName.isEmpty, let image = UIImage(named: content.assetName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(named: content.iconName) { return (image, false) }
        if !content.iconName.isEmpty, let image = UIImage(systemName: content.iconName) { return (image, true) }
        return nil
    }

    private func cancelPrimaryImageRequest() {
        primaryImageGeneration &+= 1
        if let view = primaryImageRequestView { PPImageLoaderManager.shared().cancelImageLoad(for: view) }
        primaryImageRequestView = nil
    }

    private func cancelAllPreviewRequests() {
        allPreviewGeneration &+= 1
        allPreviewRequestViews.compactMap { $0 }.forEach { PPImageLoaderManager.shared().cancelImageLoad(for: $0) }
        allPreviewRequestViews = Array(repeating: nil, count: allArtworkViews.count)
    }

    private func resetAllPreview() {
        cancelAllPreviewRequests()
        allPreviewContents.removeAll()
        allArtworkViews.forEach { $0.image = nil; $0.isHidden = true }
        allFallbackBadge.isHidden = true
        artworkView.isHidden = false
    }

    private func updateAllArtworkVisibility() {
        guard content?.isAll == true else { return }
        let hasEnsemble = allArtworkViews.filter { $0.image != nil }.count >= 2
        artworkView.isHidden = hasEnsemble
        allFallbackBadge.isHidden = hasEnsemble || artworkView.image != nil
        allArtworkViews.forEach { $0.isHidden = !hasEnsemble || $0.image == nil }
        setNeedsLayout()
    }

    // MARK: - Motion, Springs & Touch Mechanics

    @objc private func handleTouchDown() {
        guard !activationInFlight else { return }
        animatePressure(pressed: true)
    }

    @objc private func handleTouchRelease() {
        guard !activationInFlight else { return }
        animatePressure(pressed: false)
    }

    @objc private func handleActivation() {
        let now = CACurrentMediaTime()
        guard !activationInFlight,
              now - lastActivationTime >= 0.25,
              let content,
              let expectedCellID = boundCellID,
              onSelect != nil,
              window != nil else {
            if !activationInFlight { animatePressure(pressed: false) }
            return
        }
        lastActivationTime = now
        stopPressureMotion()

        guard !reduceMotion else {
            pressureContainer.transform = .identity
            onSelect?(content.kind, content.isAll)
            return
        }

        activationInFlight = true
        updateInteractionAvailability()
        activationGeneration &+= 1
        let generation = activationGeneration

        // Finite 200ms spring release before route
        let animator = UIViewPropertyAnimator(duration: 0.20, dampingRatio: 0.82) { [weak self] in
            self?.pressureContainer.transform = .identity
        }
        animator.addCompletion { [weak self] position in
            guard let self,
                  position == .end,
                  self.activationGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.window != nil else { return }
            self.activationAnimator = nil
            self.activationInFlight = false
            self.updateInteractionAvailability()
            self.onSelect?(content.kind, content.isAll)
        }
        activationAnimator = animator
        animator.startAnimation()
    }

    private func animatePressure(pressed: Bool) {
        stopPressureMotion()
        guard !reduceMotion, window != nil else {
            pressureContainer.transform = .identity
            return
        }
        pressureGeneration &+= 1
        let generation = pressureGeneration
        let animator = UIViewPropertyAnimator(
            duration: pressed ? 0.12 : 0.20,
            dampingRatio: 0.78
        ) { [weak self] in
            self?.pressureContainer.transform = pressed
                ? CGAffineTransform(translationX: 0, y: 2.0).scaledBy(x: 0.96, y: 0.96)
                : .identity
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.pressureGeneration == generation else { return }
            self.pressureAnimator = nil
        }
        pressureAnimator = animator
        animator.startAnimation()
    }

    private func animateSelection(restored: Bool) {
        stopSelectionMotion()
        guard !reduceMotion, window != nil else {
            updateAppearance(animated: false)
            applySelectionPose()
            return
        }
        selectionGeneration &+= 1
        let generation = selectionGeneration
        let animator = UIViewPropertyAnimator(
            duration: restored ? 0.18 : 0.28,
            dampingRatio: 0.82
        ) { [weak self] in
            self?.updateAppearance(animated: true)
            self?.applySelectionPose()
        }
        animator.addCompletion { [weak self] _ in
            guard let self, self.selectionGeneration == generation else { return }
            self.selectionAnimator = nil
        }
        selectionAnimator = animator
        animator.startAnimation()
    }

    private func stopPressureMotion() {
        pressureGeneration &+= 1
        pressureAnimator?.stopAnimation(false)
        pressureAnimator?.finishAnimation(at: .current)
        pressureAnimator = nil
    }

    private func stopSelectionMotion() {
        selectionGeneration &+= 1
        selectionAnimator?.stopAnimation(false)
        selectionAnimator?.finishAnimation(at: .current)
        selectionAnimator = nil
    }

    private func stopAllMotion() {
        activationGeneration &+= 1
        activationAnimator?.stopAnimation(true)
        activationAnimator = nil
        activationInFlight = false
        stopPressureMotion()
        stopSelectionMotion()
        pressureContainer.transform = .identity
        applySelectionPose()
        updateInteractionAvailability()
    }

    // MARK: - Bilingual RTL & Layout Direction

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        for view in [self, contentView, actionButton, pressureContainer, capsuleView, typographyContainer, categoryBadgeView] {
            view.semanticContentAttribute = semantic
        }
        // Pet biological silhouettes must NEVER be mirrored
        stageView.semanticContentAttribute = .forceLeftToRight
        portraitContainer.semanticContentAttribute = .forceLeftToRight
        ([artworkView] + allArtworkViews + [allFallbackBadge]).forEach {
            $0.semanticContentAttribute = .forceLeftToRight
        }
    }

    private func registerForEnvironmentChanges() {
        let center = NotificationCenter.default
        for name in [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIAccessibility.boldTextStatusDidChangeNotification,
            UIContentSizeCategory.didChangeNotification
        ] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.environmentDidChange(refreshLocalizedContent: false)
            })
        }
        for name in ["LanguageDidChangeNotification", "PPLanguageDidChangeNotification"] {
            observers.append(center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.environmentDidChange(refreshLocalizedContent: true)
            })
        }
        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stopAllMotion() })
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stopAllMotion() })
    }

    public override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.hasDifferentColorAppearance(comparedTo: traitCollection) == true
            || previous?.accessibilityContrast != traitCollection.accessibilityContrast
            || previous?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
            || previous?.layoutDirection != traitCollection.layoutDirection {
            environmentDidChange(refreshLocalizedContent: false)
        }
    }

    private func environmentDidChange(refreshLocalizedContent: Bool) {
        stopAllMotion()
        if refreshLocalizedContent, let current = content {
            content = MainKindsV2Content(kind: current.kind, isAll: current.isAll)
            boundCellID = content?.cellID
        }
        applyLayoutDirection()
        updateTypography()
        updateContent()
        updateAppearance(animated: false)
        applySelectionPose()
        setNeedsLayout()
    }
}

// MARK: - Measured Geometry Layout Engine

public struct MainKindsCellV2Layout {
    public static let captionPointSize: CGFloat = 17
    public static let cardCornerRadius: CGFloat = PPCorner.card - 4

    public let cardFrame: CGRect
    public let stageFrame: CGRect
    public let portraitFrame: CGRect
    public let ambientFrame: CGRect
    public let groundFrame: CGRect
    public let titlePlateFrame: CGRect
    public let titleFrame: CGRect
    public let pipFrame: CGRect
    public let badgeFrame: CGRect

    public init(bounds: CGRect, title: String, fontSize: CGFloat, expandedText: Bool) {
        let width = max(0, bounds.width)
        let height = max(0, bounds.height)
        let horizontalMargin: CGFloat = PPSpace.xxs
        let verticalMargin: CGFloat = 3

        cardFrame = CGRect(
            x: horizontalMargin,
            y: verticalMargin,
            width: max(0, width - horizontalMargin * 2),
            height: max(0, height - verticalMargin * 2)
        )

        let textPadding = PPSpace.md
        let availableTextWidth = max(1, cardFrame.width - textPadding * 2)
        let font = Self.captionFont(size: fontSize, bold: true)
        let textHeight = Self.measureTextHeight(
            title: title,
            width: availableTextWidth,
            font: font,
            expandedText: expandedText
        )

        let dashHeight: CGFloat = 3
        let dashWidth: CGFloat = max(18, min(26, cardFrame.width * 0.20))
        let plateTopBreathingRoom: CGFloat = expandedText ? PPSpace.base : PPSpace.md
        let titleToDashGap = PPSpace.sm
        let bottomPadding = PPSpace.md
        let plateHeight = max(
            54,
            plateTopBreathingRoom + textHeight + titleToDashGap + dashHeight + bottomPadding
        )

        titlePlateFrame = CGRect(
            x: 0,
            y: max(0, cardFrame.height - plateHeight),
            width: cardFrame.width,
            height: min(cardFrame.height, plateHeight)
        )

        titleFrame = CGRect(
            x: textPadding,
            y: titlePlateFrame.minY + plateTopBreathingRoom,
            width: availableTextWidth,
            height: textHeight
        )
        pipFrame = CGRect(
            x: (cardFrame.width - dashWidth) / 2,
            y: min(cardFrame.height - bottomPadding - dashHeight, titleFrame.maxY + titleToDashGap),
            width: dashWidth,
            height: dashHeight
        )

        // The portrait is intentionally dominant and slips behind the title plate.
        let stageOverlap: CGFloat = 18
        let stageBottom = min(cardFrame.height, titlePlateFrame.minY + stageOverlap)
        stageFrame = CGRect(
            x: 0,
            y: 0,
            width: cardFrame.width,
            height: max(0, stageBottom)
        )
        portraitFrame = CGRect(
            x: PPSpace.xxs,
            y: PPSpace.xs,
            width: max(0, stageFrame.width - PPSpace.xs),
            height: max(0, stageFrame.height - PPSpace.xs)
        )

        let ambientSide = min(cardFrame.width * 1.10, max(0, stageFrame.height * 0.92))
        ambientFrame = CGRect(
            x: (cardFrame.width - ambientSide) / 2,
            y: max(PPSpace.xs, stageFrame.height * 0.08),
            width: ambientSide,
            height: ambientSide
        )

        let groundWidth = max(34, cardFrame.width * 0.68)
        let groundHeight = max(8, min(13, stageFrame.height * 0.08))
        groundFrame = CGRect(
            x: (stageFrame.width - groundWidth) / 2,
            y: max(0, stageFrame.height - stageOverlap - groundHeight * 0.65),
            width: groundWidth,
            height: groundHeight
        )

        let badgeSide = min(34, max(28, cardFrame.width * 0.27))
        badgeFrame = CGRect(
            x: PPSpace.md,
            y: PPSpace.md,
            width: badgeSide,
            height: badgeSide
        )
    }

    public static func titlePlatePath(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let crest = min(16, max(10, bounds.height * 0.24))
        path.move(to: CGPoint(x: 0, y: crest))
        path.addCurve(
            to: CGPoint(x: bounds.width, y: crest * 0.42),
            controlPoint1: CGPoint(x: bounds.width * 0.30, y: -crest * 0.20),
            controlPoint2: CGPoint(x: bounds.width * 0.72, y: crest * 0.72)
        )
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        path.addLine(to: CGPoint(x: 0, y: bounds.height))
        path.close()
        return path
    }

    public static func captionFont(size: CGFloat, bold: Bool = true) -> UIFont {
        let fontName = bold ? "Beiruti-Bold" : "Beiruti-Regular"
        if let font = UIFont(name: fontName, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: bold ? .bold : .medium)
    }

    public static func preferredHeight(
        width: CGFloat,
        titles: [String],
        fontSize: CGFloat,
        expandedText: Bool
    ) -> CGFloat {
        let cardWidth = max(1, width - PPSpace.xs)
        let availableTextWidth = max(1, cardWidth - PPSpace.xl)
        let font = captionFont(size: fontSize, bold: true)
        let maxTextHeight = titles.reduce(font.lineHeight) { current, title in
            max(
                current,
                measureTextHeight(
                    title: title,
                    width: availableTextWidth,
                    font: font,
                    expandedText: expandedText
                )
            )
        }
        let singleLineHeight = ceil(font.lineHeight)
        let textGrowth = max(0, maxTextHeight - singleLineHeight)
        let portraitCardHeight = max(150, cardWidth * 1.50)
        return ceil(portraitCardHeight + textGrowth + (expandedText ? PPSpace.sm : 0))
    }

    private static func measureTextHeight(
        title: String,
        width: CGFloat,
        font: UIFont,
        expandedText: Bool
    ) -> CGFloat {
        guard !title.isEmpty else { return ceil(font.lineHeight) }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .center
        let measured = ceil((title as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        ).height)
        return expandedText ? measured : min(measured, ceil(font.lineHeight) * 2)
    }
}

// MARK: - Presentation Content Model

private struct MainKindsV2Content {
    let kind: NSObject?
    let isAll: Bool
    let numericID: Int
    let title: String
    let imageURL: String
    let localImage: UIImage?
    let assetName: String
    let iconName: String
    let accent: UIColor
    let cellID: String

    init(kind: NSObject?, isAll: Bool) {
        self.kind = kind
        self.isAll = isAll
        if isAll {
            numericID = 0
            title = Language.get("all", alter: "All") ?? "All"
            imageURL = ""
            localImage = nil
            assetName = ""
            iconName = ""
            accent = .ppPrimary
            cellID = "pp-main-kind-all"
            return
        }
        let presentation = kind.map { PPHomeDataBridge.categoryPresentation(for: $0) } ?? [:]
        let model = kind as? MainKindsModel
        numericID = (presentation["numericID"] as? NSNumber)?.intValue ?? model?.id ?? 0
        title = (presentation["title"] as? String) ?? model?.kindName ?? ""
        imageURL = (presentation["imageURL"] as? String) ?? model?.kindImageUrl ?? ""
        localImage = presentation["localImage"] as? UIImage
        assetName = model?.kindImageNamed ?? ""
        iconName = model?.kindIconName ?? ""
        accent = (presentation["accent"] as? UIColor) ?? .ppPrimary
        let documentID = presentation["id"] as? String ?? ""
        let stableIdentity = documentID.isEmpty ? "main-kind-\(numericID)" : documentID
        cellID = [stableIdentity, imageURL].joined(separator: "|")
    }

    func hasSameArtwork(as other: Self) -> Bool {
        cellID == other.cellID && assetName == other.assetName
            && iconName == other.iconName && localImage === other.localImage
    }
}

// MARK: - Adaptive Color & Contrast Palette

private enum MainKindsV2Palette {
    struct Resolved {
        let accent: UIColor
        let cardSurface: UIColor
        let gradientStart: UIColor
        let gradientEnd: UIColor
        let ambientWash: UIColor
        let titlePlate: UIColor
        let badgeSurface: UIColor
        let badgeBorder: UIColor
        let badgeInk: UIColor
        let groundShadow: UIColor
        let restingBorder: UIColor
        let selectedBorder: UIColor
        let ink: UIColor
        let shadowColor: UIColor
        let shadowOpacity: Float
    }

    static func resolve(
        accent: UIColor,
        numericID: Int,
        traits: UITraitCollection,
        isSelected: Bool
    ) -> Resolved {
        let isDark = traits.userInterfaceStyle == .dark
        let isHighContrast = traits.accessibilityContrast == .high
        let resolvedAccent = accent.resolvedColor(with: traits)
        let porcelain = UIColor.ppWarmPorcelain.resolvedColor(with: traits)
        let elevated = UIColor.ppElevatedSurface.resolvedColor(with: traits)
        let text = UIColor.ppTextPrimary.resolvedColor(with: traits)

        let identityColor: UIColor
        let surfaceAmount: CGFloat
        switch numericID {
        case 5: // Cats — blush habitat from the approved concept.
            identityColor = UIColor.ppSoftRose.resolvedColor(with: traits)
            surfaceAmount = isDark ? 0.42 : 0.72
        case 1: // Birds — quiet botanical/sage signal.
            identityColor = UIColor.ppQuickActionServices.resolvedColor(with: traits)
            surfaceAmount = isDark ? 0.18 : 0.14
        case 11: // Falcons — mineral/desert warmth.
            identityColor = UIColor.ppMineralBeige.resolvedColor(with: traits)
            surfaceAmount = isDark ? 0.46 : 0.74
        case 0: // All — neutral Pure Pets porcelain with a faint brand wash.
            identityColor = UIColor.ppPrimary.resolvedColor(with: traits)
            surfaceAmount = isDark ? 0.10 : 0.06
        default:
            identityColor = resolvedAccent
            surfaceAmount = isDark ? 0.13 : 0.09
        }

        let cardSurface = blend(identityColor, over: porcelain, amount: surfaceAmount)
        let ambientSource: UIColor = numericID == 5 || numericID == 11 ? resolvedAccent : identityColor
        let ambientWash = ambientSource.withAlphaComponent(isDark ? 0.12 : 0.095)
        let titlePlate = blend(elevated, over: cardSurface, amount: isDark ? 0.72 : 0.88)
        let badgeSurface = blend(elevated, over: cardSurface, amount: isDark ? 0.82 : 0.94)
        let restingBorder = isHighContrast
            ? text.withAlphaComponent(0.50)
            : UIColor.ppSurfaceBorder.resolvedColor(with: traits).withAlphaComponent(isDark ? 0.88 : 0.78)
        let selectedBorder = isHighContrast ? text : resolvedAccent.withAlphaComponent(0.82)
        let badgeBorder = isHighContrast ? text.withAlphaComponent(0.58) : UIColor.white.withAlphaComponent(isDark ? 0.14 : 0.72)
        let badgeInk = isHighContrast ? text : resolvedAccent
        let groundShadow = text.withAlphaComponent(isDark ? 0.12 : 0.055)

        return Resolved(
            accent: resolvedAccent,
            cardSurface: cardSurface,
            gradientStart: ambientSource.withAlphaComponent(isSelected ? (isDark ? 0.16 : 0.12) : (isDark ? 0.10 : 0.075)),
            gradientEnd: ambientSource.withAlphaComponent(0.0),
            ambientWash: ambientWash,
            titlePlate: titlePlate,
            badgeSurface: badgeSurface,
            badgeBorder: badgeBorder,
            badgeInk: badgeInk,
            groundShadow: groundShadow,
            restingBorder: restingBorder,
            selectedBorder: selectedBorder,
            ink: text,
            shadowColor: UIColor.black,
            shadowOpacity: isSelected ? (isDark ? 0.34 : 0.12) : (isDark ? 0.22 : 0.07)
        )
    }

    private static func blend(_ foreground: UIColor, over background: UIColor, amount: CGFloat) -> UIColor {
        let clamped = min(max(amount, 0), 1)
        var fr: CGFloat = 0
        var fg: CGFloat = 0
        var fb: CGFloat = 0
        var fa: CGFloat = 0
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        guard foreground.getRed(&fr, green: &fg, blue: &fb, alpha: &fa),
              background.getRed(&br, green: &bg, blue: &bb, alpha: &ba) else {
            return background
        }
        return UIColor(
            red: br + (fr - br) * clamped,
            green: bg + (fg - bg) * clamped,
            blue: bb + (fb - bb) * clamped,
            alpha: ba + (fa - ba) * clamped
        )
    }
}
