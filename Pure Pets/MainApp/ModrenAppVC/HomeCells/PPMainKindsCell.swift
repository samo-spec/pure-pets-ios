import UIKit

private enum PPMainKindsCellMetrics {
    static let cornerRadius: CGFloat = 22
    static let contentInset: CGFloat = 11
    static let imagePlateSize: CGFloat = 92
    static let compactImagePlateSize: CGFloat = 76
    static let artworkSize: CGFloat = 62
    static let allArtworkSize: CGFloat = 32
    static let imageToTitleSpacing: CGFloat = 6
    static let indicatorWidth: CGFloat = 30
    static let indicatorHeight: CGFloat = 3
    static let selectedBorderWidth: CGFloat = 1.1
    static let regularBorderWidth: CGFloat = 1 / UIScreen.main.scale
    static let pressDuration: TimeInterval = 0.10
    static let releaseDuration: TimeInterval = 0.22
    static let selectionDuration: TimeInterval = 0.24
    static let restoredEntranceDuration: TimeInterval = 0.38
    static let selectionChangeDuration: TimeInterval = 0.34
    static let haloDuration: TimeInterval = 0.40
    static let glowCommitDuration: TimeInterval = 0.36
}

private enum PPMainKindsCellAnimationKey {
    static let tapHalo = "pp.mainKinds.tapHalo"
    static let glowCommit = "pp.mainKinds.glowCommit"
}

private enum PPMainKindsCellPalette {
    static var brand: UIColor {
        UIColor(named: "AppPrimaryColor") ?? .systemPink
    }

    static var primaryText: UIColor {
        UIColor(named: "PrimaryTextColor") ?? .label
    }

    static var SeconerdText: UIColor {
        UIColor(named: "PrimaryTextColor") ?? .label
    }

    static var card: UIColor {
        UIColor(named: "AppCardColor") ?? .secondarySystemBackground
    }

    static var appBackColor: UIColor {
        UIColor(named: "AppBackgroundColor") ?? .secondarySystemBackground
    }

    static var plate: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
            :  appBackColor.withAlphaComponent(1.00)
        }
    }

    static var border: UIColor {
        UIColor.diff.withAlphaComponent(0.22)
    }
}

@objc(PPMainKindsCell)
public final class PPMainKindsCell: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "PPMainKindsCell" }

    @objc public var onSelect: ((NSObject?, Bool) -> Void)?
    @objc public var boundCellID: String?

    private let tapButton = UIButton(type: .custom)
    private let surfaceView = UIView()
    private let materialView = UIView()
    private let imagePlateView = UIView()
    private let kindImageView = UIImageView()
    private let titleLabel = UILabel()
    private let selectionIndicatorView = UIView()
    private let bottomGlowLayer = CAGradientLayer()
    private let kindNameGlowLayer = CAGradientLayer()
    private let tapHaloLayer = CAGradientLayer()

    private var imagePlateWidthConstraint: NSLayoutConstraint!
    private var imagePlateHeightConstraint: NSLayoutConstraint!
    private var artworkWidthConstraint: NSLayoutConstraint!
    private var artworkHeightConstraint: NSLayoutConstraint!

    private var currentKind: NSObject?
    private var currentImageURL: String?
    private var currentAccentColor = PPMainKindsCellPalette.brand
    private var isAllOption = false
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var isPressing = false
    private var isPreviewingSelectedGlow = false
    private var appliedPlateSize: CGFloat = 0

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    private var rendersSelectedGlow: Bool {
        isKindSelected || isPreviewingSelectedGlow
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("PPMainKindsCell supports code-only UIKit.")
    }

    private func buildUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        applyLayoutDirection()

        tapButton.translatesAutoresizingMaskIntoConstraints = false
        tapButton.backgroundColor = .clear
        tapButton.accessibilityTraits = .button
        tapButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        tapButton.addTarget(self, action: #selector(handleTouchDown), for: [.touchDown, .touchDragEnter])
        tapButton.addTarget(self, action: #selector(handleTouchUp), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        contentView.addSubview(tapButton)

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.isUserInteractionEnabled = false
        surfaceView.layer.cornerRadius = PPMainKindsCellMetrics.cornerRadius
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.layer.masksToBounds = false
        tapButton.addSubview(surfaceView)

        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialView.isUserInteractionEnabled = false
        materialView.clipsToBounds = true
        materialView.layer.cornerRadius = PPMainKindsCellMetrics.cornerRadius
        materialView.layer.cornerCurve = .continuous
        surfaceView.addSubview(materialView)

        bottomGlowLayer.name = "PPMainKindsBottomGlowCircleLayer"
        bottomGlowLayer.type = .radial
        bottomGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        bottomGlowLayer.endPoint = CGPoint(x: 1, y: 1)
        bottomGlowLayer.locations = [0, 0.56, 1]
        bottomGlowLayer.opacity = 0
        materialView.layer.addSublayer(bottomGlowLayer)

        kindNameGlowLayer.name = "PPMainKindsKindNameGlowLayer"
        kindNameGlowLayer.type = .radial
        kindNameGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        kindNameGlowLayer.endPoint = CGPoint(x: 1, y: 1)
        kindNameGlowLayer.locations = [0, 0.52, 1]
        kindNameGlowLayer.opacity = 0
        materialView.layer.addSublayer(kindNameGlowLayer)

        tapHaloLayer.name = "PPMainKindsTapHaloLayer"
        tapHaloLayer.type = .radial
        tapHaloLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        tapHaloLayer.endPoint = CGPoint(x: 1, y: 1)
        tapHaloLayer.locations = [0, 0.48, 1]
        tapHaloLayer.opacity = 0
        materialView.layer.addSublayer(tapHaloLayer)

        imagePlateView.translatesAutoresizingMaskIntoConstraints = false
        imagePlateView.isUserInteractionEnabled = false
        imagePlateView.layer.masksToBounds = false
        imagePlateView.layer.shadowColor = UIColor.black.cgColor
        imagePlateView.layer.shadowOpacity = 0.085
        imagePlateView.layer.shadowRadius = 8
        imagePlateView.layer.shadowOffset = CGSize(width: 0, height: 3.5)
        surfaceView.addSubview(imagePlateView)

        kindImageView.translatesAutoresizingMaskIntoConstraints = false
        kindImageView.contentMode = .scaleAspectFit
        kindImageView.clipsToBounds = false
        kindImageView.isAccessibilityElement = false
        imagePlateView.addSubview(kindImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.isAccessibilityElement = false
        surfaceView.addSubview(titleLabel)

        selectionIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        selectionIndicatorView.isUserInteractionEnabled = false
        selectionIndicatorView.layer.cornerRadius = PPMainKindsCellMetrics.indicatorHeight / 2
        selectionIndicatorView.layer.masksToBounds = true
        surfaceView.addSubview(selectionIndicatorView)

        imagePlateWidthConstraint = imagePlateView.widthAnchor.constraint(
            equalToConstant: PPMainKindsCellMetrics.imagePlateSize
        )
        imagePlateHeightConstraint = imagePlateView.heightAnchor.constraint(
            equalToConstant: PPMainKindsCellMetrics.imagePlateSize
        )
        artworkWidthConstraint = kindImageView.widthAnchor.constraint(
            equalToConstant: PPMainKindsCellMetrics.artworkSize
        )
        artworkHeightConstraint = kindImageView.heightAnchor.constraint(
            equalToConstant: PPMainKindsCellMetrics.artworkSize
        )

        NSLayoutConstraint.activate([
            tapButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            tapButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tapButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tapButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            surfaceView.topAnchor.constraint(equalTo: tapButton.topAnchor),
            surfaceView.leadingAnchor.constraint(equalTo: tapButton.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: tapButton.trailingAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: tapButton.bottomAnchor),

            materialView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            materialView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),

            imagePlateView.topAnchor.constraint(
                equalTo: surfaceView.topAnchor,
                constant: PPMainKindsCellMetrics.contentInset
            ),
            imagePlateView.centerXAnchor.constraint(equalTo: surfaceView.centerXAnchor),
            imagePlateWidthConstraint,
            imagePlateHeightConstraint,

            kindImageView.centerXAnchor.constraint(equalTo: imagePlateView.centerXAnchor),
            kindImageView.centerYAnchor.constraint(equalTo: imagePlateView.centerYAnchor),
            artworkWidthConstraint,
            artworkHeightConstraint,

            titleLabel.topAnchor.constraint(
                greaterThanOrEqualTo: imagePlateView.bottomAnchor,
                constant: PPMainKindsCellMetrics.imageToTitleSpacing
            ),
            titleLabel.leadingAnchor.constraint(
                equalTo: surfaceView.leadingAnchor,
                constant: PPMainKindsCellMetrics.contentInset
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: surfaceView.trailingAnchor,
                constant: -PPMainKindsCellMetrics.contentInset
            ),
            titleLabel.bottomAnchor.constraint(
                equalTo: surfaceView.bottomAnchor,
                constant: -PPMainKindsCellMetrics.contentInset
            ),

            selectionIndicatorView.centerXAnchor.constraint(equalTo: surfaceView.centerXAnchor),
            selectionIndicatorView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -4),
            selectionIndicatorView.widthAnchor.constraint(equalToConstant: PPMainKindsCellMetrics.indicatorWidth),
            selectionIndicatorView.heightAnchor.constraint(equalToConstant: PPMainKindsCellMetrics.indicatorHeight)
        ])

        updateTypographyAndMetrics()
        applyAppearance(animated: false)
    }

    @objc(configureWithMainKind:isAll:selected:)
    public func configure(withMainKind kind: NSObject?,
                          isAll: Bool,
                          selected: Bool) {
        configure(
            withMainKind: kind,
            isAll: isAll,
            selected: selected,
            restoredSelectionAppearance: false
        )
    }

    @objc(configureWithMainKind:isAll:selected:restoredSelectionAppearance:)
    public func configure(withMainKind kind: NSObject?,
                          isAll: Bool,
                          selected: Bool,
                          restoredSelectionAppearance: Bool) {
        let nextCellID = cellID(for: kind, isAll: isAll)
        let sameBinding = boundCellID == nextCellID
        let wasSelected = isKindSelected
        let wasPreviewingSelectedGlow = isPreviewingSelectedGlow
        let didSelectionChange = sameBinding && window != nil && wasSelected != selected
        let shouldAnimateSelection = didSelectionChange && !restoredSelectionAppearance
        let shouldPlayChangeMotion = didSelectionChange &&
            selected &&
            !wasPreviewingSelectedGlow &&
            !restoredSelectionAppearance
        let shouldPlayDeselectionMotion = didSelectionChange &&
            wasSelected &&
            !selected &&
            !restoredSelectionAppearance
        let nextURL = stringValue(forKey: "KindImageUrl", in: kind)
        let shouldRefreshImage = !sameBinding || kindImageView.image == nil || currentImageURL != nextURL

        boundCellID = nextCellID
        currentKind = kind
        currentImageURL = nextURL
        isAllOption = isAll
        isKindSelected = selected
        usesRestoredSelectionAppearance = selected && restoredSelectionAppearance
        currentAccentColor = accentColor(for: kind, isAll: isAll)
        applyLayoutDirection()
        isPreviewingSelectedGlow = false

        let title = isAll
            ? localized("all", fallback: "all")
            : stringValue(forKey: "KindName", in: kind)
        titleLabel.text = title
        tapButton.accessibilityLabel = title
        tapButton.accessibilityTraits = selected ? [.button, .selected] : .button
        tapButton.accessibilityIdentifier = isAll
            ? "home.mainKinds.all"
            : "home.mainKinds.\(integerValue(forKey: "ID", in: kind))"
        tapButton.largeContentTitle = title
        tapButton.showsLargeContentViewer = true

        updateArtworkMetrics()
        if shouldRefreshImage {
            configureImage(for: kind, isAll: isAll)
        } else if isAll {
            kindImageView.tintColor = resolvedImageViewTintColor(selected: isKindSelected)
        }

        applyAppearance(animated: shouldAnimateSelection)
        if shouldPlayChangeMotion {
            playSelectionChangeAnimation()
        } else if shouldPlayDeselectionMotion {
            playDeselectionChangeAnimation()
        }
    }

    private func configureImage(for kind: NSObject?, isAll: Bool) {
        PPImageLoaderManager.shared().cancelImageLoad(for: kindImageView)

        if isAll {
            let configuration = UIImage.SymbolConfiguration(
                pointSize: 24,
                weight: .semibold,
                scale: .medium
            )
            let image = UIImage(named: "pawprint")
                ?? UIImage(systemName: "square.grid.2x2.fill", withConfiguration: configuration)
            kindImageView.image = image?.withRenderingMode(.alwaysTemplate)
            kindImageView.tintColor = resolvedImageViewTintColor(selected: isKindSelected)
            return
        }

        var placeholder = imageValue(forKey: "KindImageFile", in: kind)
        let imageName = stringValue(forKey: "KindImageNamed", in: kind)
        if placeholder == nil, !imageName.isEmpty {
            placeholder = UIImage(named: imageName)
        }

        let iconName = stringValue(forKey: "KindIconName", in: kind)
        if placeholder == nil, !iconName.isEmpty {
            placeholder = UIImage(named: iconName)
        }

        var templatePlaceholder = false
        if placeholder == nil, !iconName.isEmpty {
            placeholder = UIImage(systemName: iconName)
            templatePlaceholder = placeholder != nil
        }
        if placeholder == nil {
            placeholder = UIImage(systemName: "pawprint.fill")
            templatePlaceholder = true
        }

        kindImageView.tintColor = resolvedImageViewTintColor(selected: isKindSelected)
        kindImageView.image = templatePlaceholder
            ? placeholder?.withRenderingMode(.alwaysTemplate)
            : placeholder?.withRenderingMode(.alwaysOriginal)

        guard let currentImageURL, !currentImageURL.isEmpty else { return }
        PPImageLoaderManager.shared().setImage(
            on: kindImageView,
            url: currentImageURL,
            placeholder: kindImageView.image,
            transitionStyle: .none,
            completion: nil
        )
    }

    private func applyAppearance(animated: Bool) {
        let accent = currentAccentColor
        let selected = isKindSelected
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled

        updateMotionLayerPalette()
        let updates = {
            self.surfaceView.backgroundColor = .clear
            self.materialView.backgroundColor = selected
                ? PPMainKindsCellPalette.card
                : PPMainKindsCellPalette.card.withAlphaComponent(reduceTransparency ? 0.46 : 0.60)
            
            self.surfaceView.layer.borderColor = (
                self.usesRestoredSelectionAppearance && selected
                    ? UIColor.clear
                    : (selected ? accent.withAlphaComponent(0.42) : PPMainKindsCellPalette.border)
            ).resolvedColor(with: self.traitCollection).cgColor
            self.surfaceView.layer.borderWidth = self.usesRestoredSelectionAppearance && selected
                ? 0
                : (selected
                    ? PPMainKindsCellMetrics.selectedBorderWidth
                    : PPMainKindsCellMetrics.regularBorderWidth)
            self.surfaceView.layer.shadowColor = UIColor.black.cgColor
            self.surfaceView.layer.shadowOpacity = selected ? 0.055 : 0.025
            self.surfaceView.layer.shadowRadius = selected ? 10 : 7
            self.surfaceView.layer.shadowOffset = CGSize(width: 0, height: selected ? 4 : 2)
            let normalAlpha = reduceTransparency ? 0.18 : 0.31
            let finalAlpha = self.isAllOption ? (normalAlpha * 0.2) : normalAlpha
            self.imagePlateView.backgroundColor = selected
                ? accent.withAlphaComponent(finalAlpha)
                : PPMainKindsCellPalette.plate
            self.imagePlateView.layer.shadowOpacity = selected ? 0.0 : 0.085
            self.titleLabel.textColor = selected ? accent : PPMainKindsCellPalette.primaryText
            self.kindImageView.tintColor = self.resolvedImageViewTintColor(selected: selected)
            self.selectionIndicatorView.backgroundColor = accent
            self.selectionIndicatorView.alpha = selected ? 1 : 0
            let glowSelected = self.rendersSelectedGlow
            self.bottomGlowLayer.opacity = self.isPressing
                ? self.pressedGlowOpacity(selected: glowSelected)
                : self.restingGlowOpacity(selected: glowSelected)
            self.kindNameGlowLayer.opacity = self.kindNameGlowOpacity(
                selected: glowSelected,
                pressing: self.isPressing
            )
            self.tapButton.transform = self.isPressing
                ? self.pressedTapTransform
                : self.restingTapTransform
        }

        guard animated, !reduceMotion else {
            UIView.performWithoutAnimation(updates)
            return
        }

        UIView.animate(
            withDuration: PPMainKindsCellMetrics.selectionDuration,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.18,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: updates
        )
    }

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        tapButton.semanticContentAttribute = semantic
    }

    private func updateTypographyAndMetrics() {
        let baseFont = UIFont(name: "Beiruti-Bold", size: 15)
            ?? UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: baseFont,
            maximumPointSize: 21
        )
        updateArtworkMetrics()
    }

    private func updateArtworkMetrics() {
        let accessibilityText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let plateSize = resolvedImagePlateSize(accessibilityText: accessibilityText)
        let baseArtworkSize = isAllOption
            ? PPMainKindsCellMetrics.allArtworkSize
            : PPMainKindsCellMetrics.artworkSize
        let artworkSize = accessibilityText ? min(baseArtworkSize, plateSize - 12) : baseArtworkSize

        appliedPlateSize = plateSize
        imagePlateWidthConstraint.constant = plateSize
        imagePlateHeightConstraint.constant = plateSize
        artworkWidthConstraint.constant = artworkSize
        artworkHeightConstraint.constant = artworkSize
        imagePlateView.layer.cornerRadius = plateSize / 2

        let shadowBounds = CGRect(x: 0, y: 0, width: plateSize, height: plateSize)
        imagePlateView.layer.shadowPath = UIBezierPath(roundedRect: shadowBounds, cornerRadius: plateSize / 2).cgPath
    }

    private func resolvedImageViewTintColor(selected: Bool) -> UIColor {
        if isAllOption {
            if #available(iOS 13.0, *) {
                return selected ? currentAccentColor : UIColor.systemGray
            } else {
                return selected ? currentAccentColor : UIColor.gray
            }
        } else {
            return currentAccentColor
        }
    }

    private func resolvedImagePlateSize(accessibilityText: Bool) -> CGFloat {
        let baseSize = accessibilityText
            ? PPMainKindsCellMetrics.compactImagePlateSize
            : PPMainKindsCellMetrics.imagePlateSize
        let inset = PPMainKindsCellMetrics.contentInset
        let availableWidth = contentView.bounds.width > 1
            ? contentView.bounds.width
            : bounds.width
        let widthMatchedSize = availableWidth > 1
            ? max(PPMainKindsCellMetrics.compactImagePlateSize, availableWidth - (inset * 2))
            : baseSize
        return min(baseSize, widthMatchedSize)
    }

    @objc private func handleTouchDown() {
        applyPressed(true)
    }

    @objc private func handleTouchUp() {
        applyPressed(false)
    }

    private func applyPressed(_ pressed: Bool) {
        isPressing = pressed
        guard !reduceMotion else {
            if !pressed {
                resetTransientMotion()
            }
            return
        }

        UIView.animate(
            withDuration: pressed
                ? PPMainKindsCellMetrics.pressDuration
                : PPMainKindsCellMetrics.releaseDuration,
            delay: 0,
            usingSpringWithDamping: pressed ? 1 : 0.82,
            initialSpringVelocity: pressed ? 0 : 0.28,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.tapButton.transform = pressed
                    ? self.pressedTapTransform
                    : self.restingTapTransform
                self.imagePlateView.transform = pressed
                    ? CGAffineTransform(scaleX: 0.91, y: 0.91)
                    : .identity
                self.kindImageView.transform = pressed
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
                self.titleLabel.transform = pressed
                    ? CGAffineTransform(translationX: 0, y: 0.5)
                    : .identity
                self.selectionIndicatorView.transform = pressed
                    ? CGAffineTransform(scaleX: 0.84, y: 1)
                    : .identity
                let glowSelected = self.rendersSelectedGlow
                self.bottomGlowLayer.opacity = pressed
                    ? self.pressedGlowOpacity(selected: glowSelected)
                    : self.restingGlowOpacity(selected: glowSelected)
                self.kindNameGlowLayer.opacity = self.kindNameGlowOpacity(
                    selected: glowSelected,
                    pressing: pressed
                )
                self.tapHaloLayer.opacity = pressed ? 0.20 : 0
            }
        )
    }

    @objc private func handleTap() {
        applyPressed(false)

        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred(intensity: 0.62)

        let selection = onSelect
        let kind = currentKind
        let isAll = isAllOption
        guard let selection else { return }

        if !reduceMotion {
            updateMotionLayerPalette()
            layoutMotionLayers()
            performHaloBurstMotion()
        }

        selection(kind, isAll)
    }

    @objc public func playRestoredSelectionAnimation() {
        guard window != nil, isKindSelected, usesRestoredSelectionAppearance else { return }
        guard !reduceMotion else {
            applyAppearance(animated: false)
            return
        }

        updateMotionLayerPalette()
        layoutMotionLayers()
        let finalBottomGlow = restingGlowOpacity(selected: true)
        let finalNameGlow = kindNameGlowOpacity(selected: true, pressing: false)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surfaceView.transform = CGAffineTransform(scaleX: 0.986, y: 0.986)
        imagePlateView.transform = CGAffineTransform(scaleX: 0.982, y: 0.982)
        kindImageView.transform = CGAffineTransform(scaleX: 0.976, y: 0.976)
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 0.5)
        selectionIndicatorView.alpha = 0
        selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.46, y: 1)
        bottomGlowLayer.opacity = max(0, finalBottomGlow - 0.28)
        kindNameGlowLayer.opacity = max(0, finalNameGlow - 0.24)
        tapHaloLayer.opacity = 0
        CATransaction.commit()

        UIView.animate(
            withDuration: PPMainKindsCellMetrics.restoredEntranceDuration,
            delay: 0,
            usingSpringWithDamping: 0.84,
            initialSpringVelocity: 0.18,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.tapButton.transform = self.restingTapTransform
                self.selectionIndicatorView.transform = .identity
                self.selectionIndicatorView.alpha = 1
                self.surfaceView.transform = .identity
                self.imagePlateView.transform = .identity
                self.kindImageView.transform = .identity
                self.titleLabel.transform = .identity
                self.bottomGlowLayer.opacity = finalBottomGlow
                self.kindNameGlowLayer.opacity = finalNameGlow
            }
        )
    }

    @objc public func playSelectionChangeAnimation() {
        guard window != nil, isKindSelected, !usesRestoredSelectionAppearance else { return }
        guard !reduceMotion else {
            applyAppearance(animated: false)
            return
        }

        updateMotionLayerPalette()
        layoutMotionLayers()
        performHaloBurstMotion()
        let finalBottomGlow = restingGlowOpacity(selected: true)
        let finalNameGlow = kindNameGlowOpacity(selected: true, pressing: false)

        UIView.animateKeyframes(
            withDuration: PPMainKindsCellMetrics.selectionChangeDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.34) {
                    self.tapButton.transform = CGAffineTransform(scaleX: 1.018, y: 1.018)
                    self.imagePlateView.transform = CGAffineTransform(scaleX: 1.045, y: 1.045)
                    self.kindImageView.transform = CGAffineTransform(scaleX: 1.022, y: 1.022)
                    self.selectionIndicatorView.transform = CGAffineTransform(scaleX: 1.22, y: 1)
                    self.bottomGlowLayer.opacity = min(1, finalBottomGlow + 0.12)
                    self.kindNameGlowLayer.opacity = min(1, finalNameGlow + 0.10)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.34, relativeDuration: 0.66) {
                    self.tapButton.transform = self.restingTapTransform
                    self.imagePlateView.transform = .identity
                    self.kindImageView.transform = .identity
                    self.titleLabel.transform = .identity
                    self.selectionIndicatorView.transform = .identity
                    self.bottomGlowLayer.opacity = finalBottomGlow
                    self.kindNameGlowLayer.opacity = finalNameGlow
                    self.tapHaloLayer.opacity = 0
                }
            }
        )
    }

    private func playDeselectionChangeAnimation() {
        guard window != nil, !isKindSelected else { return }
        guard !reduceMotion else {
            resetTransientMotion()
            applyAppearance(animated: false)
            return
        }

        isPreviewingSelectedGlow = false
        updateMotionLayerPalette()
        layoutMotionLayers()
        let finalBottomGlow = restingGlowOpacity(selected: false)
        let finalNameGlow = kindNameGlowOpacity(selected: false, pressing: false)

        UIView.animate(
            withDuration: PPMainKindsCellMetrics.selectionChangeDuration,
            delay: 0,
            usingSpringWithDamping: 0.90,
            initialSpringVelocity: 0.14,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.tapButton.transform = self.restingTapTransform
                self.imagePlateView.transform = .identity
                self.kindImageView.transform = .identity
                self.titleLabel.transform = .identity
                self.selectionIndicatorView.alpha = 0
                self.selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.62, y: 1)
                self.bottomGlowLayer.opacity = finalBottomGlow
                self.kindNameGlowLayer.opacity = finalNameGlow
                self.tapHaloLayer.opacity = 0
            },
            completion: { _ in
                self.selectionIndicatorView.transform = .identity
                self.applyAppearance(animated: false)
            }
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutMotionLayers()
    }

    private func layoutMotionLayers() {
        guard !materialView.bounds.isEmpty else { return }

        let accessibilityText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let plateSize = resolvedImagePlateSize(accessibilityText: accessibilityText)
        if abs(plateSize - appliedPlateSize) > 0.5 {
            updateArtworkMetrics()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let materialBounds = materialView.bounds
        let selectedGlow = rendersSelectedGlow
        let glowDiameter = selectedGlow
            ? min(174, max(136, max(materialBounds.width, materialBounds.height) * 1.34))
            : min(116, max(86, materialBounds.height * 0.90))
        let isRightToLeft =
            UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        let glowX = selectedGlow
            ? -glowDiameter * 0.34
            : (isRightToLeft
                ? materialBounds.width - glowDiameter + 24
                : -24)
        let glowY = selectedGlow
            ? -glowDiameter * 0.34
            : materialBounds.height - glowDiameter + 40
        bottomGlowLayer.frame = CGRect(
            x: glowX,
            y: glowY,
            width: glowDiameter,
            height: glowDiameter
        ).integral
        bottomGlowLayer.cornerRadius = glowDiameter / 2

        let titleGlowWidth = min(materialBounds.width - 12, max(92, titleLabel.bounds.width + 48))
        let titleGlowHeight = min(78, max(58, titleLabel.bounds.height + 34))
        kindNameGlowLayer.frame = CGRect(
            x: (materialBounds.width - titleGlowWidth) / 2,
            y: min(
                materialBounds.height - titleGlowHeight + 8,
                titleLabel.frame.midY - (titleGlowHeight / 2)
            ),
            width: titleGlowWidth,
            height: titleGlowHeight
        ).integral
        kindNameGlowLayer.cornerRadius = titleGlowHeight / 2

        let haloDiameter = max(materialBounds.width, materialBounds.height) * 1.66
        tapHaloLayer.frame = CGRect(
            x: (materialBounds.width - haloDiameter) / 2,
            y: materialBounds.height - (haloDiameter * 0.74),
            width: haloDiameter,
            height: haloDiameter
        ).integral
        tapHaloLayer.cornerRadius = haloDiameter / 2
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPMainKindsCellMetrics.cornerRadius
        ).cgPath
        CATransaction.commit()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        PPImageLoaderManager.shared().cancelImageLoad(for: kindImageView)

        onSelect = nil
        boundCellID = nil
        currentKind = nil
        currentImageURL = nil
        currentAccentColor = PPMainKindsCellPalette.brand
        isAllOption = false
        isKindSelected = false
        usesRestoredSelectionAppearance = false
        isPressing = false
        isPreviewingSelectedGlow = false
        titleLabel.text = nil
        kindImageView.image = nil
        tapButton.accessibilityLabel = nil
        tapButton.accessibilityIdentifier = nil
        tapButton.accessibilityTraits = .button
        resetTransientMotion()
        surfaceView.transform = .identity
        applyAppearance(animated: false)
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateTypographyAndMetrics()
            setNeedsLayout()
        }
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true {
            applyAppearance(animated: false)
            setNeedsLayout()
        }
        applyLayoutDirection()
    }

    private func cellID(for kind: NSObject?, isAll: Bool) -> String {
        guard !isAll else { return "pp-main-kind-all" }
        return [
            String(integerValue(forKey: "ID", in: kind)),
            stringValue(forKey: "KindName", in: kind),
            stringValue(forKey: "KindImageUrl", in: kind)
        ].joined(separator: "|")
    }

    private func accentColor(for kind: NSObject?, isAll: Bool) -> UIColor {
        guard !isAll, let kind else { return PPMainKindsCellPalette.brand }
        let selector = NSSelectorFromString("kindColor")
        if kind.responds(to: selector),
           let color = kind.perform(selector)?.takeUnretainedValue() as? UIColor {
            return color
        }
        return UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.72, green: 0.75, blue: 0.80, alpha: 1)
                : UIColor(red: 0.38, green: 0.42, blue: 0.48, alpha: 1)
        }
    }

    private func localized(_ key: String, fallback: String) -> String {
        let value = Language.get(key, alter: fallback)
        return value?.isEmpty == false ? value! : fallback
    }

    private func stringValue(forKey key: String, in kind: NSObject?) -> String {
        (kind?.value(forKey: key) as? String) ?? ""
    }

    private func integerValue(forKey key: String, in kind: NSObject?) -> Int {
        (kind?.value(forKey: key) as? NSNumber)?.intValue ?? 0
    }

    private func imageValue(forKey key: String, in kind: NSObject?) -> UIImage? {
        kind?.value(forKey: key) as? UIImage
    }

    private var restingTapTransform: CGAffineTransform {
        isKindSelected
            ? CGAffineTransform(scaleX: 1.008, y: 1.008)
            : .identity
    }

    private var pressedTapTransform: CGAffineTransform {
        let scale: CGFloat = isKindSelected ? 0.976 : 0.962
        return CGAffineTransform(scaleX: scale, y: scale)
    }

    private func restingGlowOpacity(selected: Bool) -> Float {
        if selected {
            return isAllOption ? 0.70 : 0.84
        }
        return isAllOption ? 0.08 : 0.14
    }

    private func pressedGlowOpacity(selected: Bool) -> Float {
        min(1, restingGlowOpacity(selected: selected) + (selected ? 0.14 : 0.08))
    }

    private func kindNameGlowOpacity(selected: Bool, pressing: Bool) -> Float {
        if selected {
            return pressing ? 0.96 : 0.86
        }
        return pressing ? 0.58 : 0.18
    }

    private func updateMotionLayerPalette() {
        let accent = currentAccentColor.resolvedColor(with: traitCollection)
        let isAll = isAllOption
        let selected = rendersSelectedGlow
        let leadingGlowAlpha: CGFloat = selected
            ? (isAll ? 0.34 : 0.42)
            : (isAll ? 0.18 : 0.25)
        let trailingGlowAlpha: CGFloat = selected
            ? (isAll ? 0.20 : 0.27)
            : (isAll ? 0.10 : 0.16)
        bottomGlowLayer.colors = [
            accent.withAlphaComponent(leadingGlowAlpha).cgColor,
            accent.withAlphaComponent(trailingGlowAlpha).cgColor,
            accent.withAlphaComponent(0).cgColor
        ]
        kindNameGlowLayer.colors = [
            accent.withAlphaComponent(isAll ? 0.24 : 0.30).cgColor,
            accent.withAlphaComponent(isAll ? 0.11 : 0.16).cgColor,
            accent.withAlphaComponent(0).cgColor
        ]
        tapHaloLayer.colors = [
            accent.withAlphaComponent(0.28).cgColor,
            accent.withAlphaComponent(0.09).cgColor,
            accent.withAlphaComponent(0).cgColor
        ]
    }

    private func performTapCommitMotion() {
        isPreviewingSelectedGlow = true
        updateMotionLayerPalette()
        layoutMotionLayers()
        performHaloBurstMotion()

        let restingGlow = restingGlowOpacity(selected: true)
        let glowAnimation = CABasicAnimation(keyPath: "opacity")
        glowAnimation.fromValue = min(1, restingGlow + 0.18)
        glowAnimation.toValue = restingGlow
        glowAnimation.duration = PPMainKindsCellMetrics.glowCommitDuration
        glowAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        bottomGlowLayer.opacity = restingGlow
        bottomGlowLayer.add(
            glowAnimation,
            forKey: PPMainKindsCellAnimationKey.glowCommit
        )

        let nameGlowAnimation = CABasicAnimation(keyPath: "opacity")
        nameGlowAnimation.fromValue = 0.92
        nameGlowAnimation.toValue = kindNameGlowOpacity(selected: true, pressing: false)
        nameGlowAnimation.duration = PPMainKindsCellMetrics.glowCommitDuration
        nameGlowAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        kindNameGlowLayer.opacity = kindNameGlowOpacity(selected: true, pressing: false)
        kindNameGlowLayer.add(
            nameGlowAnimation,
            forKey: PPMainKindsCellAnimationKey.glowCommit
        )

        UIView.animateKeyframes(
            withDuration: 0.42,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.32) {
                    let liftScale: CGFloat = self.isKindSelected ? 1.032 : 1.024
                    self.tapButton.transform = CGAffineTransform(scaleX: liftScale, y: liftScale)
                    self.imagePlateView.transform = CGAffineTransform(scaleX: 1.07, y: 1.07)
                    self.kindImageView.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
                    self.selectionIndicatorView.transform = CGAffineTransform(scaleX: 1.32, y: 1)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.32, relativeDuration: 0.68) {
                    self.tapButton.transform = self.restingTapTransform
                    self.imagePlateView.transform = .identity
                    self.kindImageView.transform = .identity
                    self.titleLabel.transform = .identity
                    self.selectionIndicatorView.transform = .identity
                    self.tapHaloLayer.opacity = 0
                }
            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + PPMainKindsCellMetrics.glowCommitDuration) { [weak self] in
            guard let self, self.isPreviewingSelectedGlow, !self.isKindSelected else { return }
            self.isPreviewingSelectedGlow = false
            self.applyAppearance(animated: true)
            self.setNeedsLayout()
        }
    }

    private func performHaloBurstMotion() {
        tapHaloLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.tapHalo)
        tapHaloLayer.opacity = 0

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.36, 0]
        opacity.keyTimes = [0, 0.22, 1]

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.72
        scale.toValue = 1.16

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = PPMainKindsCellMetrics.haloDuration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = true
        tapHaloLayer.add(group, forKey: PPMainKindsCellAnimationKey.tapHalo)
    }

    private func resetTransientMotion() {
        tapHaloLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.tapHalo)
        bottomGlowLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.glowCommit)
        kindNameGlowLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.glowCommit)
        isPressing = false
        tapButton.transform = restingTapTransform
        imagePlateView.transform = .identity
        kindImageView.transform = .identity
        titleLabel.transform = .identity
        selectionIndicatorView.transform = .identity
        tapHaloLayer.opacity = 0
        bottomGlowLayer.opacity = restingGlowOpacity(selected: rendersSelectedGlow)
        kindNameGlowLayer.opacity = kindNameGlowOpacity(
            selected: rendersSelectedGlow,
            pressing: false
        )
    }
}
