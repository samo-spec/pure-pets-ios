import UIKit

private enum PPMainKindsCellMetrics {
    static let cornerRadius: CGFloat = PPCorner.hero
    static let contentInset: CGFloat = PPSpace.md
    static let imagePlateSize: CGFloat = 92
    static let compactImagePlateSize: CGFloat = 80
    static let maximumImagePlateSize: CGFloat = 92
    static let maximumCompactImagePlateSize: CGFloat = 80
    static let artworkSize: CGFloat = 76
    static let allArtworkSize: CGFloat = 36
    static let imageToTitleSpacing: CGFloat = PPSpace.xs
    // Temporary visual switch: selection semantics and motion stay active,
    // while the decorative bottom line remains hidden.
    static let showsBottomSelectionIndicator = false
    static let indicatorWidth: CGFloat = 30
    static let indicatorHeight: CGFloat = PPSpace.xs
    static let identitySpineWidth: CGFloat = PPSpace.xs
    static let identitySpineInset: CGFloat = PPSpace.sm
    static let selectedBorderWidth: CGFloat = 0.65
    static let regularBorderWidth: CGFloat = 0.65
    static let pressDuration: TimeInterval = 0.10
    static let releaseDuration: TimeInterval = 0.22
    static let selectionDuration: TimeInterval = 0.28
    static let restoredEntranceDuration: TimeInterval = 0.38
    static let selectionChangeDuration: TimeInterval = 0.28
    static let haloDuration: TimeInterval = 0.28
    static let identityRevealDuration: TimeInterval = 0.26
    static let identityTraceDuration: TimeInterval = 0.34
    static let commitDuration: TimeInterval = 0.22
}

private enum PPMainKindsCellAnimationKey {
    static let tapHalo = "pp.mainKinds.tapHalo"
    static let identityReveal = "pp.mainKinds.identityReveal"
    static let identityTrace = "pp.mainKinds.identityTrace"
}

private enum PPMainKindsCellPalette {
    static var brand: UIColor {
        UIColor(named: "AppPrimaryColor") ?? .systemPink
    }

    static var primaryText: UIColor {
        UIColor(named: "PrimaryTextColor") ?? .label
    }

    static var card: UIColor {
        UIColor(named: "AppCardColor") ?? .secondarySystemBackground
    }

    static var appSurface: UIColor {
        UIColor(named: "AppSurfColor") ?? UIColor(named: "AppCardColor") ?? .secondarySystemBackground
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
    private let identityFieldLayer = CAGradientLayer()
    private let identitySpineLayer = CAGradientLayer()
    private let captionFieldLayer = CAGradientLayer()
    private let bottomGlowLayer = CAGradientLayer()
    private let kindNameGlowLayer = CAGradientLayer()
    private let tapHaloLayer = CAGradientLayer()
    private let selectionIndicatorLayer = CAGradientLayer()

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
    private var interactionGeneration = 0
    private var isCommitInFlight = false

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
        tapButton.isExclusiveTouch = true
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

        identityFieldLayer.name = "PPMainKindsIdentityFieldLayer"
        identityFieldLayer.locations = [0, 0.44, 0.78, 1]
        materialView.layer.addSublayer(identityFieldLayer)

        identitySpineLayer.name = "PPMainKindsIdentitySpineLayer"
        identitySpineLayer.locations = [0, 0.5, 1]
        identitySpineLayer.startPoint = CGPoint(x: 0.5, y: 0)
        identitySpineLayer.endPoint = CGPoint(x: 0.5, y: 1)
        identitySpineLayer.masksToBounds = true
        materialView.layer.addSublayer(identitySpineLayer)

        captionFieldLayer.name = "PPMainKindsCaptionFieldLayer"
        captionFieldLayer.locations = [0, 0.48, 1]
        captionFieldLayer.startPoint = CGPoint(x: 0.5, y: 0)
        captionFieldLayer.endPoint = CGPoint(x: 0.5, y: 1)
        materialView.layer.addSublayer(captionFieldLayer)

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
        imagePlateView.backgroundColor = .clear
        imagePlateView.layer.masksToBounds = false
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
        selectionIndicatorView.isHidden = !PPMainKindsCellMetrics.showsBottomSelectionIndicator
        selectionIndicatorView.layer.cornerRadius = PPMainKindsCellMetrics.indicatorHeight / 2
        selectionIndicatorView.layer.masksToBounds = true
        surfaceView.addSubview(selectionIndicatorView)

        selectionIndicatorLayer.name = "PPMainKindsSelectionHorizonLayer"
        selectionIndicatorLayer.locations = [0, 0.5, 1]
        selectionIndicatorLayer.startPoint = CGPoint(x: 0, y: 0.5)
        selectionIndicatorLayer.endPoint = CGPoint(x: 1, y: 0.5)
        selectionIndicatorView.layer.addSublayer(selectionIndicatorLayer)

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
        let didSelectionChange = window != nil && wasSelected != selected
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

        if !sameBinding {
            interactionGeneration &+= 1
            isCommitInFlight = false
        }

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
        setNeedsLayout()
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
                pointSize: 25,
                weight: .semibold,
                scale: .medium
            )
            let image = UIImage(
                systemName: "square.grid.2x2.fill",
                withConfiguration: configuration
            ) ?? UIImage(named: "square-layout")
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
        let increasedContrast = traitCollection.accessibilityContrast == .high
        let darkMode = traitCollection.userInterfaceStyle == .dark

        updateMotionLayerPalette()
        let updates = {
            self.surfaceView.backgroundColor = .clear
            self.materialView.backgroundColor = PPMainKindsCellPalette.card.withAlphaComponent(
                reduceTransparency ? 1 : 0.94
            )

            let appSurface = PPMainKindsCellPalette.appSurface
            let selectedBorderColor = accent.blended(
                with: appSurface,
                ratio: increasedContrast ? 0.72 : 0.30,
                traitCollection: self.traitCollection
            )

            self.surfaceView.layer.borderColor = (
                self.usesRestoredSelectionAppearance && selected
                    ? UIColor.clear
                    : (selected
                        ? selectedBorderColor
                        : UIColor.ppBorder.withAlphaComponent(increasedContrast ? 1 : 0.76))
            ).resolvedColor(with: self.traitCollection).cgColor
            self.surfaceView.layer.borderWidth = self.usesRestoredSelectionAppearance && selected
                ? 0
                : (selected
                    ? (increasedContrast ? 1.0 : PPMainKindsCellMetrics.selectedBorderWidth)
                    : (increasedContrast ? 1.0 : PPMainKindsCellMetrics.regularBorderWidth))
            self.surfaceView.layer.shadowColor = UIColor.black.cgColor
            self.surfaceView.layer.shadowOpacity = darkMode ? 0.08 : 0.035
            self.surfaceView.layer.shadowRadius = 7
            self.surfaceView.layer.shadowOffset = CGSize(width: 0, height: 3)

            self.imagePlateView.backgroundColor = .clear
            self.imagePlateView.layer.borderWidth = 0
            self.imagePlateView.layer.shadowOpacity = 0
            self.titleLabel.textColor = PPMainKindsCellPalette.primaryText
            self.titleLabel.alpha = 1
            self.kindImageView.tintColor = self.resolvedImageViewTintColor(selected: selected)
            self.selectionIndicatorView.alpha = selected ? 1 : 0
            self.selectionIndicatorView.transform = selected ? .identity : CGAffineTransform(scaleX: 0.70, y: 1)
            self.selectionIndicatorView.layer.shadowColor = accent
                .resolvedColor(with: self.traitCollection)
                .cgColor
            self.selectionIndicatorView.layer.shadowOpacity = selected && !increasedContrast ? 0.22 : 0
            self.selectionIndicatorView.layer.shadowRadius = 4
            self.selectionIndicatorView.layer.shadowOffset = .zero
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
        let artworkSize = min(baseArtworkSize, plateSize - (accessibilityText ? 12 : 10))

        appliedPlateSize = plateSize
        imagePlateWidthConstraint.constant = plateSize
        imagePlateHeightConstraint.constant = plateSize
        artworkWidthConstraint.constant = artworkSize
        artworkHeightConstraint.constant = artworkSize
        imagePlateView.layer.cornerRadius = 0
        imagePlateView.layer.shadowPath = nil
    }

    private func resolvedImageViewTintColor(selected: Bool) -> UIColor {
        if isAllOption, !selected {
            return .secondaryLabel
        }
        return currentAccentColor
    }

    private func resolvedImagePlateSize(accessibilityText: Bool) -> CGFloat {
        let preferredSize = accessibilityText
            ? PPMainKindsCellMetrics.compactImagePlateSize
            : PPMainKindsCellMetrics.imagePlateSize
        let maximumSize = accessibilityText
            ? PPMainKindsCellMetrics.maximumCompactImagePlateSize
            : PPMainKindsCellMetrics.maximumImagePlateSize
        let inset = PPMainKindsCellMetrics.contentInset
        let availableWidth = contentView.bounds.width > 1
            ? contentView.bounds.width
            : bounds.width
        let availableHeight = contentView.bounds.height > 1
            ? contentView.bounds.height
            : bounds.height
        let widthMatchedSize = availableWidth > 1
            ? max(PPMainKindsCellMetrics.compactImagePlateSize, availableWidth - (inset * 2))
            : preferredSize
        let reservedTitleHeight: CGFloat = accessibilityText ? 44 : 36
        let heightMatchedSize = availableHeight > 1
            ? max(
                PPMainKindsCellMetrics.compactImagePlateSize,
                availableHeight - (inset * 2) -
                    PPMainKindsCellMetrics.imageToTitleSpacing - reservedTitleHeight
            )
            : preferredSize
        return min(maximumSize, min(widthMatchedSize, heightMatchedSize))
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
                    ? CGAffineTransform(translationX: 0, y: -1.5)
                        .scaledBy(x: 1.035, y: 1.035)
                    : .identity
                self.kindImageView.transform = pressed
                    ? CGAffineTransform(translationX: 0, y: -2)
                        .scaledBy(x: 1.025, y: 1.025)
                    : .identity
                self.titleLabel.transform = pressed
                    ? CGAffineTransform(translationX: 0, y: 0.5)
                    : .identity
                self.selectionIndicatorView.transform = pressed
                    ? (self.isKindSelected ? CGAffineTransform(scaleX: 0.92, y: 1) : CGAffineTransform(scaleX: 0.65, y: 1))
                    : (self.isKindSelected ? .identity : CGAffineTransform(scaleX: 0.70, y: 1))
                let glowSelected = self.rendersSelectedGlow
                self.bottomGlowLayer.opacity = pressed
                    ? self.pressedGlowOpacity(selected: glowSelected)
                    : self.restingGlowOpacity(selected: glowSelected)
                self.kindNameGlowLayer.opacity = self.kindNameGlowOpacity(
                    selected: glowSelected,
                    pressing: pressed
                )
                self.tapHaloLayer.opacity = pressed ? 0.10 : 0
            }
        )
    }

    @objc private func handleTap() {
        applyPressed(false)

        guard !isCommitInFlight else { return }

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        feedback.impactOccurred(intensity: 0.88)

        let selection = onSelect
        let kind = currentKind
        let isAll = isAllOption
        let expectedCellID = boundCellID
        let generation = interactionGeneration
        guard let selection else { return }

        if reduceMotion {
            selection(kind, isAll)
            return
        }

        isCommitInFlight = true
        isPreviewingSelectedGlow = true
        updateMotionLayerPalette()
        layoutMotionLayers()
        performSignatureCommitMotion { [weak self] in
            guard let self else { return }
            self.isCommitInFlight = false
            guard self.interactionGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.window != nil,
                  self.onSelect != nil else {
                return
            }
            selection(kind, isAll)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
                guard let self,
                      self.interactionGeneration == generation,
                      self.isPreviewingSelectedGlow,
                      !self.isKindSelected else {
                    return
                }
                self.isPreviewingSelectedGlow = false
                self.applyAppearance(animated: true)
                self.setNeedsLayout()
            }
        }
    }

    @objc public func playRestoredSelectionAnimation() {
        guard window != nil, isKindSelected, usesRestoredSelectionAppearance else { return }
        guard !reduceMotion else {
            applyAppearance(animated: false)
            return
        }

        updateMotionLayerPalette()
        layoutMotionLayers()
        performIdentityRevealMotion()
        let finalBottomGlow = restingGlowOpacity(selected: true)
        let finalNameGlow = kindNameGlowOpacity(selected: true, pressing: false)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surfaceView.transform = CGAffineTransform(scaleX: 0.986, y: 0.986)
        imagePlateView.transform = CGAffineTransform(scaleX: 0.982, y: 0.982)
        kindImageView.transform = CGAffineTransform(scaleX: 0.976, y: 0.976)
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 0.5)
        selectionIndicatorView.alpha = 0
        selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.70, y: 1)
        bottomGlowLayer.opacity = max(0, finalBottomGlow - 0.14)
        kindNameGlowLayer.opacity = max(0, finalNameGlow - 0.12)
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
        performIdentityRevealMotion()
        let finalBottomGlow = restingGlowOpacity(selected: true)
        let finalNameGlow = kindNameGlowOpacity(selected: true, pressing: false)

        selectionIndicatorView.alpha = 0
        selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.70, y: 1)

        UIView.animateKeyframes(
            withDuration: PPMainKindsCellMetrics.selectionChangeDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.40) {
                    self.tapButton.transform = CGAffineTransform(scaleX: 1.018, y: 1.018)
                    self.imagePlateView.transform = CGAffineTransform(scaleX: 1.07, y: 1.07)
                    self.kindImageView.transform = CGAffineTransform(translationX: 0, y: -2)
                        .scaledBy(x: 1.045, y: 1.045)
                    self.selectionIndicatorView.transform = .identity
                    self.selectionIndicatorView.alpha = 1
                    self.bottomGlowLayer.opacity = min(1, finalBottomGlow + 0.06)
                    self.kindNameGlowLayer.opacity = min(1, finalNameGlow + 0.05)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.40, relativeDuration: 0.60) {
                    self.tapButton.transform = self.restingTapTransform
                    self.imagePlateView.transform = .identity
                    self.kindImageView.transform = .identity
                    self.titleLabel.transform = .identity
                    self.selectionIndicatorView.transform = .identity
                    self.selectionIndicatorView.alpha = 1
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
                self.selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.70, y: 1)
                self.bottomGlowLayer.opacity = finalBottomGlow
                self.kindNameGlowLayer.opacity = finalNameGlow
                self.tapHaloLayer.opacity = 0
            },
            completion: { _ in
                self.selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.70, y: 1)
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

        updateMotionLayerPalette()
        let materialBounds = materialView.bounds
        let selectedGlow = rendersSelectedGlow
        let glowSelected = selectedGlow
        let isRightToLeft =
            UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        bottomGlowLayer.opacity = isPressing
            ? pressedGlowOpacity(selected: glowSelected)
            : restingGlowOpacity(selected: glowSelected)
        kindNameGlowLayer.opacity = kindNameGlowOpacity(
            selected: glowSelected,
            pressing: isPressing
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        identityFieldLayer.frame = materialBounds
        identityFieldLayer.startPoint = CGPoint(x: isRightToLeft ? 0.92 : 0.08, y: 0)
        identityFieldLayer.endPoint = CGPoint(x: isRightToLeft ? 0.08 : 0.92, y: 1)

        let spineHeight = min(58, max(46, materialBounds.height * 0.43))
        let spineX = isRightToLeft
            ? materialBounds.width - PPMainKindsCellMetrics.identitySpineInset -
                PPMainKindsCellMetrics.identitySpineWidth
            : PPMainKindsCellMetrics.identitySpineInset
        identitySpineLayer.frame = CGRect(
            x: spineX,
            y: (materialBounds.height - spineHeight) / 2,
            width: PPMainKindsCellMetrics.identitySpineWidth,
            height: spineHeight
        ).integral
        identitySpineLayer.cornerRadius = PPMainKindsCellMetrics.identitySpineWidth / 2

        let captionY = max(0, materialBounds.height * 0.58)
        captionFieldLayer.frame = CGRect(
            x: 0,
            y: captionY,
            width: materialBounds.width,
            height: materialBounds.height - captionY
        )

        let glowDiameter = selectedGlow
            ? min(174, max(136, max(materialBounds.width, materialBounds.height) * 1.34))
            : min(116, max(86, materialBounds.height * 0.90))
        let glowX = selectedGlow
            ? (isRightToLeft
                ? materialBounds.width - (glowDiameter * 0.66)
                : -glowDiameter * 0.34)
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

        selectionIndicatorLayer.frame = selectionIndicatorView.bounds
        selectionIndicatorLayer.cornerRadius = PPMainKindsCellMetrics.indicatorHeight / 2
        let plateFrame = imagePlateView.frame
        let plateCenterY = plateFrame.midY > 0 ? plateFrame.midY : (materialBounds.height * 0.38)
        let plateCenterX = plateFrame.midX > 0 ? plateFrame.midX : (materialBounds.width * 0.5)
        let haloDiameter = max(materialBounds.width, materialBounds.height) * 2.6
        tapHaloLayer.frame = CGRect(
            x: plateCenterX - (haloDiameter / 2),
            y: plateCenterY - (haloDiameter / 2),
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

        interactionGeneration &+= 1
        isCommitInFlight = false
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
        if previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true ||
            previousTraitCollection?.accessibilityContrast != traitCollection.accessibilityContrast {
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
        return PPMainKindsCellPalette.brand
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
        .identity
    }

    private var pressedTapTransform: CGAffineTransform {
        let scale: CGFloat = isKindSelected ? 0.976 : 0.962
        return CGAffineTransform(scaleX: scale, y: scale)
    }

    private func restingGlowOpacity(selected: Bool) -> Float {
        guard selected else { return 0 }
        return isAllOption ? 0.035 : 0.045
    }

    private func pressedGlowOpacity(selected: Bool) -> Float {
        min(1, restingGlowOpacity(selected: selected) + (selected ? 0.06 : 0.02))
    }

    private func kindNameGlowOpacity(selected: Bool, pressing: Bool) -> Float {
        if selected {
            return pressing ? 0.055 : 0.045
        }
        return pressing ? 0.025 : 0
    }

    private func updateMotionLayerPalette() {
        let accent = currentAccentColor.resolvedColor(with: traitCollection)
        let surface = PPMainKindsCellPalette.card.resolvedColor(with: traitCollection)
        let isAll = isAllOption
        let selected = rendersSelectedGlow
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let increasedContrast = traitCollection.accessibilityContrast == .high
        let identityTopAlpha: CGFloat = increasedContrast
            ? 0.36
            : (isAll ? (darkMode ? 0.20 : 0.14) : (darkMode ? 0.22 : 0.16))
        let identityMiddleAlpha = identityTopAlpha * 0.48
        let identityLowAlpha = identityTopAlpha * 0.10
        let spineAlpha: CGFloat = increasedContrast ? 1 : 0.78
        let leadingGlowAlpha: CGFloat = selected
            ? (isAll ? 0.14 : 0.16)
            : 0
        let trailingGlowAlpha: CGFloat = selected
            ? (isAll ? 0.05 : 0.07)
            : 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        identityFieldLayer.colors = [
            accent.withAlphaComponent(identityTopAlpha).cgColor,
            accent.withAlphaComponent(identityMiddleAlpha).cgColor,
            accent.withAlphaComponent(identityLowAlpha).cgColor,
            accent.withAlphaComponent(0).cgColor,
        ]
        identityFieldLayer.opacity = selected ? 1 : 0
        identitySpineLayer.colors = [
            accent.withAlphaComponent(spineAlpha * 0.50).cgColor,
            accent.withAlphaComponent(spineAlpha).cgColor,
            accent.withAlphaComponent(spineAlpha * 0.72).cgColor,
        ]
        identitySpineLayer.opacity = selected ? 1 : 0
        captionFieldLayer.colors = [
            surface.withAlphaComponent(0).cgColor,
            surface.withAlphaComponent(darkMode ? 0.84 : 0.90).cgColor,
            surface.withAlphaComponent(1).cgColor,
        ]
        bottomGlowLayer.colors = [
            accent.withAlphaComponent(leadingGlowAlpha).cgColor,
            accent.withAlphaComponent(trailingGlowAlpha).cgColor,
            accent.withAlphaComponent(0).cgColor,
        ]
        kindNameGlowLayer.colors = [
            accent.withAlphaComponent(isAll ? 0.16 : 0.18).cgColor,
            accent.withAlphaComponent(isAll ? 0.10 : 0.11).cgColor,
            accent.withAlphaComponent(0).cgColor,
        ]
        tapHaloLayer.colors = [
            accent.withAlphaComponent(0.28).cgColor,
            accent.withAlphaComponent(0.12).cgColor,
            accent.withAlphaComponent(0).cgColor,
        ]
        selectionIndicatorLayer.colors = [
            accent.withAlphaComponent(0.12).cgColor,
            accent.withAlphaComponent(increasedContrast ? 1 : 0.96).cgColor,
            accent.withAlphaComponent(0.12).cgColor,
        ]
        CATransaction.commit()
    }

    private func performSignatureCommitMotion(completion: @escaping () -> Void) {
        performHaloBurstMotion()
        performIdentityRevealMotion()

        UIView.animateKeyframes(
            withDuration: PPMainKindsCellMetrics.commitDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.42) {
                    self.tapButton.transform = CGAffineTransform(scaleX: 0.982, y: 0.982)
                    self.imagePlateView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                    self.kindImageView.transform = CGAffineTransform(translationX: 0, y: -2)
                        .scaledBy(x: 1.04, y: 1.04)
                    self.selectionIndicatorView.transform = .identity
                }
                UIView.addKeyframe(withRelativeStartTime: 0.42, relativeDuration: 0.58) {
                    self.tapButton.transform = self.restingTapTransform
                    self.imagePlateView.transform = .identity
                    self.kindImageView.transform = .identity
                    self.titleLabel.transform = .identity
                    self.selectionIndicatorView.transform = .identity
                }
            }
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + PPMainKindsCellMetrics.commitDuration,
            execute: completion
        )
    }

    private func performIdentityRevealMotion() {
        identitySpineLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.identityReveal)
        identitySpineLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.identityTrace)
        identityFieldLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.identityReveal)

        let spineScale = CABasicAnimation(keyPath: "transform.scale.y")
        spineScale.fromValue = 0.14
        spineScale.toValue = 1

        let spineSlide = CABasicAnimation(keyPath: "position.y")
        spineSlide.fromValue = identitySpineLayer.position.y - min(14, identitySpineLayer.bounds.height * 0.22)
        spineSlide.toValue = identitySpineLayer.position.y

        let spineOpacity = CABasicAnimation(keyPath: "opacity")
        spineOpacity.fromValue = 0
        spineOpacity.toValue = 1

        let spineGroup = CAAnimationGroup()
        spineGroup.animations = [spineScale, spineSlide, spineOpacity]
        spineGroup.duration = PPMainKindsCellMetrics.identityRevealDuration
        spineGroup.timingFunction = CAMediaTimingFunction(
            controlPoints: 0.23,
            1,
            0.32,
            1
        )
        spineGroup.isRemovedOnCompletion = true
        identitySpineLayer.add(spineGroup, forKey: PPMainKindsCellAnimationKey.identityReveal)

        let traceLocations: [[NSNumber]] = [
            [0, 0.08, 0.24],
            [0.12, 0.42, 0.72],
            [0.54, 0.82, 1],
            [0, 0.5, 1],
        ]
        let spineTrace = CAKeyframeAnimation(keyPath: "locations")
        spineTrace.values = traceLocations
        spineTrace.keyTimes = [0, 0.34, 0.72, 1]
        spineTrace.duration = PPMainKindsCellMetrics.identityTraceDuration
        spineTrace.timingFunction = CAMediaTimingFunction(
            controlPoints: 0.23,
            1,
            0.32,
            1
        )
        spineTrace.isRemovedOnCompletion = true
        identitySpineLayer.add(spineTrace, forKey: PPMainKindsCellAnimationKey.identityTrace)

        let fieldReveal = CABasicAnimation(keyPath: "opacity")
        fieldReveal.fromValue = 0.32
        fieldReveal.toValue = 1
        fieldReveal.duration = PPMainKindsCellMetrics.haloDuration
        fieldReveal.timingFunction = CAMediaTimingFunction(
            controlPoints: 0.23,
            1,
            0.32,
            1
        )
        identityFieldLayer.add(fieldReveal, forKey: PPMainKindsCellAnimationKey.identityReveal)
    }

    private func performHaloBurstMotion() {
        tapHaloLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.tapHalo)
        tapHaloLayer.opacity = 0

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.58, 0]
        opacity.keyTimes = [0, 0.28, 1]

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.72
        scale.toValue = 1.86

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = PPMainKindsCellMetrics.haloDuration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = true
        tapHaloLayer.add(group, forKey: PPMainKindsCellAnimationKey.tapHalo)
    }

    private func resetTransientMotion() {
        tapHaloLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.tapHalo)
        identitySpineLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.identityReveal)
        identitySpineLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.identityTrace)
        identityFieldLayer.removeAnimation(forKey: PPMainKindsCellAnimationKey.identityReveal)
        isPressing = false
        tapButton.transform = restingTapTransform
        imagePlateView.transform = .identity
        kindImageView.transform = .identity
        titleLabel.transform = .identity
        selectionIndicatorView.transform = rendersSelectedGlow ? .identity : CGAffineTransform(scaleX: 0.70, y: 1)
        selectionIndicatorView.alpha = rendersSelectedGlow ? 1 : 0
        tapHaloLayer.opacity = 0
        bottomGlowLayer.opacity = restingGlowOpacity(selected: rendersSelectedGlow)
        kindNameGlowLayer.opacity = kindNameGlowOpacity(
            selected: rendersSelectedGlow,
            pressing: false
        )
    }
}

private extension UIColor {
    func blended(with color: UIColor, ratio: CGFloat, traitCollection: UITraitCollection) -> UIColor {
        let c1 = self.resolvedColor(with: traitCollection)
        let c2 = color.resolvedColor(with: traitCollection)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        guard c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return c1
        }

        let clampedRatio = max(0, min(1, ratio))
        let r = r1 * clampedRatio + r2 * (1 - clampedRatio)
        let g = g1 * clampedRatio + g2 * (1 - clampedRatio)
        let b = b1 * clampedRatio + b2 * (1 - clampedRatio)
        let a = a1 * clampedRatio + a2 * (1 - clampedRatio)

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
