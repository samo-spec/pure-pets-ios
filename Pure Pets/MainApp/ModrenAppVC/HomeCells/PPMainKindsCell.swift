import UIKit

private enum PPMainKindsCellMetrics {
    static let cornerRadius: CGFloat = PPCorner.card
    static let titleInset: CGFloat = PPSpace.sm
    static let compactOuterInset: CGFloat = 6
    static let regularOuterInset: CGFloat = PPSpace.sm
    static let compactTopInset: CGFloat = PPSpace.sm
    static let regularTopInset: CGFloat = 10
    static let tallTopInset: CGFloat = PPSpace.xxl
    static let titleBottomInset: CGFloat = 10
    static let accessibilityTitleBottomInset: CGFloat = PPSpace.sm
    static let artworkToTitleMinimumSpacing: CGFloat = PPSpace.xs

    static let passiveBorderWidth: CGFloat = 1
    static let selectedBorderWidth: CGFloat = 1.5
    static let increasedContrastBorderWidth: CGFloat = 2

    static let pressScale: CGFloat = 0.976
    static let pressArtworkScale: CGFloat = 1.012
    static let commitArtworkPeakScale: CGFloat = 1.018
    static let pressDuration: TimeInterval = 0.09
    static let releaseDuration: TimeInterval = 0.16
    static let selectionDuration: TimeInterval = 0.20
    static let restoredSelectionDuration: TimeInterval = 0.18
    static let commitDuration: TimeInterval = 0.18
    static let previewRecoveryDelay: TimeInterval = 0.38
}

private enum PPMainKindsCellPalette {
    static var brand: UIColor { .ppPrimary }
    static var surface: UIColor { .ppSurfaceRaised }
    static var border: UIColor { .ppSurfaceBorder }
    static var primaryText: UIColor { .ppTextPrimary }
    static var secondaryText: UIColor { .ppTextSecondary }
}

/// The production MainKinds card used by HomeCategoryRail.
///
/// The card deliberately owns only presentation and its bounded tap feedback.
/// Home remains the owner of ordering, selection state, persistence, and routing.
@objc(PPMainKindsCell)
public final class PPMainKindsCell: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "PPMainKindsCell" }

    @objc public var onSelect: ((NSObject?, Bool) -> Void)?
    @objc public var boundCellID: String?

    private let tapButton = UIButton(type: .custom)
    private let surfaceView = UIView()
    private let canvasView = UIView()
    private let habitatFieldView = UIView()
    private let kindImageView = UIImageView()
    private let titleLabel = UILabel()
    private let habitatLayer = CAGradientLayer()

    private var habitatTopConstraint: NSLayoutConstraint!
    private var habitatWidthConstraint: NSLayoutConstraint!
    private var habitatHeightConstraint: NSLayoutConstraint!
    private var artworkWidthConstraint: NSLayoutConstraint!
    private var artworkHeightConstraint: NSLayoutConstraint!
    private var titleMinimumTopConstraint: NSLayoutConstraint!
    private var titleAdjacentTopConstraint: NSLayoutConstraint!
    private var titleBottomConstraint: NSLayoutConstraint!
    private var titleBottomLimitConstraint: NSLayoutConstraint!

    private var currentKind: NSObject?
    private var currentImageURL: String?
    private var currentAccentColor = PPMainKindsCellPalette.brand
    private var isAllOption = false
    private var isKindSelected = false
    private var usesRestoredSelectionAppearance = false
    private var isPressing = false
    private var isPreviewingSelection = false
    private var appliedLayoutSize = CGSize.zero
    private var appliedAccessibilityCategory = false
    private var interactionGeneration = 0
    private var isCommitInFlight = false
    private var pendingCommitWorkItem: DispatchWorkItem?
    private var pendingPreviewRecoveryWorkItem: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    private var rendersSelectedAppearance: Bool {
        isKindSelected || isPreviewingSelection
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
        registerForEnvironmentChanges()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("PPMainKindsCell supports code-only UIKit.")
    }

    deinit {
        pendingCommitWorkItem?.cancel()
        pendingPreviewRecoveryWorkItem?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        PPImageLoaderManager.shared().cancelImageLoad(for: kindImageView)
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
        tapButton.adjustsImageWhenHighlighted = false
        tapButton.accessibilityTraits = .button
        tapButton.addTarget(
            self,
            action: #selector(handleTouchDown),
            for: [.touchDown, .touchDragEnter]
        )
        tapButton.addTarget(
            self,
            action: #selector(handleTouchUp),
            for: [.touchUpOutside, .touchCancel, .touchDragExit]
        )
        tapButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        contentView.addSubview(tapButton)

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.isUserInteractionEnabled = false
        surfaceView.layer.cornerRadius = PPMainKindsCellMetrics.cornerRadius
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.layer.masksToBounds = false
        tapButton.addSubview(surfaceView)

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.isUserInteractionEnabled = false
        canvasView.clipsToBounds = true
        canvasView.layer.cornerRadius = PPMainKindsCellMetrics.cornerRadius
        canvasView.layer.cornerCurve = .continuous
        surfaceView.addSubview(canvasView)

        habitatFieldView.translatesAutoresizingMaskIntoConstraints = false
        habitatFieldView.isUserInteractionEnabled = false
        habitatFieldView.clipsToBounds = true
        habitatFieldView.isAccessibilityElement = false
        canvasView.addSubview(habitatFieldView)

        habitatLayer.name = "PPMainKindsHabitatField"
        habitatLayer.type = .radial
        habitatLayer.startPoint = CGPoint(x: 0.5, y: 0.46)
        habitatLayer.endPoint = CGPoint(x: 1, y: 1)
        habitatLayer.locations = [0, 0.58, 1]
        habitatFieldView.layer.addSublayer(habitatLayer)

        kindImageView.translatesAutoresizingMaskIntoConstraints = false
        kindImageView.contentMode = .scaleAspectFit
        kindImageView.clipsToBounds = false
        kindImageView.isAccessibilityElement = false
        canvasView.addSubview(kindImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.allowsDefaultTighteningForTruncation = true
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.isAccessibilityElement = false
        canvasView.addSubview(titleLabel)

        habitatTopConstraint = habitatFieldView.topAnchor.constraint(
            equalTo: canvasView.topAnchor,
            constant: PPMainKindsCellMetrics.regularTopInset
        )
        habitatWidthConstraint = habitatFieldView.widthAnchor.constraint(equalToConstant: 86)
        habitatHeightConstraint = habitatFieldView.heightAnchor.constraint(equalToConstant: 62)
        artworkWidthConstraint = kindImageView.widthAnchor.constraint(equalToConstant: 56)
        artworkHeightConstraint = kindImageView.heightAnchor.constraint(equalToConstant: 56)
        titleMinimumTopConstraint = titleLabel.topAnchor.constraint(
            greaterThanOrEqualTo: habitatFieldView.bottomAnchor,
            constant: PPMainKindsCellMetrics.artworkToTitleMinimumSpacing
        )
        titleAdjacentTopConstraint = titleLabel.topAnchor.constraint(
            equalTo: habitatFieldView.bottomAnchor,
            constant: PPSpace.sm
        )
        titleBottomConstraint = titleLabel.bottomAnchor.constraint(
            equalTo: canvasView.bottomAnchor,
            constant: -PPMainKindsCellMetrics.titleBottomInset
        )
        titleBottomLimitConstraint = titleLabel.bottomAnchor.constraint(
            lessThanOrEqualTo: canvasView.bottomAnchor,
            constant: -PPMainKindsCellMetrics.titleBottomInset
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

            canvasView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),

            habitatTopConstraint,
            habitatFieldView.centerXAnchor.constraint(equalTo: canvasView.centerXAnchor),
            habitatWidthConstraint,
            habitatHeightConstraint,

            kindImageView.centerXAnchor.constraint(equalTo: habitatFieldView.centerXAnchor),
            kindImageView.centerYAnchor.constraint(equalTo: habitatFieldView.centerYAnchor),
            artworkWidthConstraint,
            artworkHeightConstraint,

            titleMinimumTopConstraint,
            titleLabel.leadingAnchor.constraint(
                equalTo: canvasView.leadingAnchor,
                constant: PPMainKindsCellMetrics.titleInset
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: canvasView.trailingAnchor,
                constant: -PPMainKindsCellMetrics.titleInset
            ),
            titleBottomConstraint
        ])

        updateTypographyAndMetrics(force: true)
        applyAppearance(animated: false)
    }

    private func registerForEnvironmentChanges() {
        let center = NotificationCenter.default
        let accessibilityNames: [Notification.Name] = [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIContentSizeCategory.didChangeNotification
        ]

        accessibilityNames.forEach { name in
            observers.append(
                center.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    if self.reduceMotion {
                        self.stopVisualMotionAndSettle()
                    }
                    self.updateTypographyAndMetrics(force: true)
                    self.applyAppearance(animated: false)
                    self.setNeedsLayout()
                }
            )
        }

        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.cancelPendingInteraction(clearPreview: true)
            }
        )
    }

    @objc(configureWithMainKind:isAll:selected:)
    public func configure(
        withMainKind kind: NSObject?,
        isAll: Bool,
        selected: Bool
    ) {
        configure(
            withMainKind: kind,
            isAll: isAll,
            selected: selected,
            restoredSelectionAppearance: false
        )
    }

    @objc(configureWithMainKind:isAll:selected:restoredSelectionAppearance:)
    public func configure(
        withMainKind kind: NSObject?,
        isAll: Bool,
        selected: Bool,
        restoredSelectionAppearance: Bool
    ) {
        let nextCellID = cellID(for: kind, isAll: isAll)
        let sameBinding = boundCellID == nextCellID
        let wasSelected = isKindSelected
        let wasPreviewingSelection = isPreviewingSelection
        let didSelectionChange = window != nil && wasSelected != selected
        let shouldPlaySelectionMotion = didSelectionChange
            && selected
            && !wasPreviewingSelection
            && !restoredSelectionAppearance
        let shouldAnimateDeselection = didSelectionChange
            && wasSelected
            && !selected
            && !restoredSelectionAppearance
        let nextURL = stringValue(forKey: "KindImageUrl", in: kind)
        let shouldRefreshImage = !sameBinding
            || kindImageView.image == nil
            || currentImageURL != nextURL

        if !sameBinding {
            interactionGeneration &+= 1
            pendingCommitWorkItem?.cancel()
            pendingCommitWorkItem = nil
            pendingPreviewRecoveryWorkItem?.cancel()
            pendingPreviewRecoveryWorkItem = nil
            isCommitInFlight = false
            stopVisualMotionAndSettle()
        }

        boundCellID = nextCellID
        currentKind = kind
        currentImageURL = nextURL
        isAllOption = isAll
        isKindSelected = selected
        usesRestoredSelectionAppearance = selected && restoredSelectionAppearance
        currentAccentColor = accentColor(for: kind, isAll: isAll)
        isPreviewingSelection = false
        applyLayoutDirection()

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

        updateTypographyAndMetrics(force: true)
        if shouldRefreshImage {
            configureImage(for: kind, isAll: isAll)
        } else if isAll {
            kindImageView.tintColor = resolvedImageTintColor(selected: selected)
        }

        if shouldPlaySelectionMotion {
            applyAppearance(animated: false)
            playSelectionChangeAnimation()
        } else {
            applyAppearance(animated: shouldAnimateDeselection)
        }
        setNeedsLayout()
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
            kindImageView.tintColor = resolvedImageTintColor(selected: isKindSelected)
            tapButton.largeContentImage = kindImageView.image
            return
        }

        let placeholder = resolvedPlaceholderImage(for: kind)
        kindImageView.tintColor = resolvedImageTintColor(selected: isKindSelected)
        kindImageView.image = placeholder.image?.withRenderingMode(
            placeholder.isTemplate ? .alwaysTemplate : .alwaysOriginal
        )
        tapButton.largeContentImage = kindImageView.image

        guard let currentImageURL, !currentImageURL.isEmpty else { return }
        let expectedCellID = boundCellID
        let expectedURL = currentImageURL
        PPImageLoaderManager.shared().setImage(
            on: kindImageView,
            url: currentImageURL,
            placeholder: kindImageView.image,
            transitionStyle: .none
        ) { [weak self] image, _ in
            guard let self,
                  self.boundCellID == expectedCellID,
                  self.currentImageURL == expectedURL,
                  let image else {
                return
            }
            self.kindImageView.image = image.withRenderingMode(.alwaysOriginal)
            self.tapButton.largeContentImage = image
        }
    }

    private func resolvedPlaceholderImage(
        for kind: NSObject?
    ) -> (image: UIImage?, isTemplate: Bool) {
        if let image = imageValue(forKey: "KindImageFile", in: kind) {
            return (image, false)
        }

        let imageName = stringValue(forKey: "KindImageNamed", in: kind)
        if !imageName.isEmpty, let image = UIImage(named: imageName) {
            return (image, false)
        }

        let iconName = stringValue(forKey: "KindIconName", in: kind)
        if !iconName.isEmpty, let image = UIImage(named: iconName) {
            return (image, false)
        }
        if !iconName.isEmpty, let image = UIImage(systemName: iconName) {
            return (image, true)
        }
        return (UIImage(systemName: "pawprint.fill"), true)
    }

    private func applyAppearance(animated: Bool) {
        updateHabitatPalette()
        let selectedAppearance = rendersSelectedAppearance
        let increasedContrast = traitCollection.accessibilityContrast == .high
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let borderWidth = selectedAppearance
            ? (increasedContrast
                ? PPMainKindsCellMetrics.increasedContrastBorderWidth
                : PPMainKindsCellMetrics.selectedBorderWidth)
            : PPMainKindsCellMetrics.passiveBorderWidth
        let accent = presentationAccentColor
        let borderColor = selectedAppearance
            ? accent.withAlphaComponent(increasedContrast ? 1 : (darkMode ? 0.86 : 0.72))
            : PPMainKindsCellPalette.border.withAlphaComponent(increasedContrast ? 1 : 0.82)
        let surfaceColor = resolvedSurfaceColor(
            accent: accent,
            selected: selectedAppearance,
            increasedContrast: increasedContrast
        )

        let updates = {
            self.canvasView.backgroundColor = surfaceColor
            self.surfaceView.layer.borderColor = borderColor
                .resolvedColor(with: self.traitCollection)
                .cgColor
            self.surfaceView.layer.borderWidth = borderWidth
            self.habitatFieldView.alpha = selectedAppearance ? 1 : 0
            self.titleLabel.textColor = PPMainKindsCellPalette.primaryText
            self.kindImageView.tintColor = self.resolvedImageTintColor(
                selected: selectedAppearance
            )
        }

        updateShadow(darkMode: darkMode, increasedContrast: increasedContrast)
        guard animated, !reduceMotion, window != nil else {
            updates()
            tapButton.transform = isPressing
                ? CGAffineTransform(
                    scaleX: PPMainKindsCellMetrics.pressScale,
                    y: PPMainKindsCellMetrics.pressScale
                )
                : .identity
            return
        }

        UIView.animate(
            withDuration: PPMainKindsCellMetrics.selectionDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut],
            animations: updates
        )
    }

    private func updateHabitatPalette() {
        let accent = presentationAccentColor.resolvedColor(with: traitCollection)
        let surface = PPMainKindsCellPalette.surface.resolvedColor(with: traitCollection)
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let increasedContrast = traitCollection.accessibilityContrast == .high

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if UIAccessibility.isReduceTransparencyEnabled {
            habitatLayer.isHidden = true
            habitatFieldView.backgroundColor = accent.blended(
                with: surface,
                ratio: increasedContrast ? 0.30 : (darkMode ? 0.24 : 0.18),
                traitCollection: traitCollection
            )
        } else {
            habitatLayer.isHidden = false
            habitatFieldView.backgroundColor = .clear
            let centerAlpha: CGFloat = increasedContrast
                ? 0.54
                : (darkMode ? 0.42 : 0.32)
            habitatLayer.colors = [
                accent.withAlphaComponent(centerAlpha).cgColor,
                accent.withAlphaComponent(centerAlpha * 0.46).cgColor,
                accent.withAlphaComponent(0).cgColor
            ]
        }
        CATransaction.commit()
    }

    private func resolvedSurfaceColor(
        accent: UIColor,
        selected: Bool,
        increasedContrast: Bool
    ) -> UIColor {
        let surface = PPMainKindsCellPalette.surface
        guard selected else { return surface }
        return accent.blended(
            with: surface,
            ratio: increasedContrast ? 0.075 : 0.045,
            traitCollection: traitCollection
        )
    }

    private func updateShadow(darkMode: Bool, increasedContrast: Bool) {
        surfaceView.layer.shadowColor = UIColor.black.cgColor
        surfaceView.layer.shadowOpacity = increasedContrast
            ? 0
            : (darkMode ? 0.12 : 0.055)
        surfaceView.layer.shadowRadius = darkMode ? 8 : 10
        surfaceView.layer.shadowOffset = CGSize(width: 0, height: darkMode ? 3 : 5)
    }

    private func applyLayoutDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        tapButton.semanticContentAttribute = semantic
        surfaceView.semanticContentAttribute = semantic
        canvasView.semanticContentAttribute = semantic
        titleLabel.semanticContentAttribute = semantic
    }

    private func updateTypographyAndMetrics(force: Bool) {
        titleLabel.font = resolvedTitleFont()

        let availableSize = CGSize(
            width: contentView.bounds.width > 1 ? contentView.bounds.width : bounds.width,
            height: contentView.bounds.height > 1 ? contentView.bounds.height : bounds.height
        )
        let accessibilityCategory = usesExpandedTextLayout
        guard force
                || availableSize != appliedLayoutSize
                || accessibilityCategory != appliedAccessibilityCategory else {
            return
        }

        appliedLayoutSize = availableSize
        appliedAccessibilityCategory = accessibilityCategory

        let width = max(availableSize.width, 1)
        let height = max(availableSize.height, 1)
        let veryCompact = width < 96
        let tallCard = height >= 164
        let outerInset = veryCompact
            ? PPMainKindsCellMetrics.compactOuterInset
            : PPMainKindsCellMetrics.regularOuterInset
        let maximumFieldWidth: CGFloat = tallCard ? 96 : 86
        let fieldWidth = min(
            maximumFieldWidth,
            max(56, width - (outerInset * 2))
        )

        let desiredFieldHeight: CGFloat
        if accessibilityCategory {
            desiredFieldHeight = 48
        } else if tallCard {
            desiredFieldHeight = 76
        } else {
            desiredFieldHeight = 62
        }
        let fieldHeight = min(desiredFieldHeight, fieldWidth * 0.76)

        let artworkSize: CGFloat
        if isAllOption {
            artworkSize = min(
                accessibilityCategory ? 26 : (tallCard ? 34 : 29),
                fieldWidth - PPSpace.base
            )
        } else if accessibilityCategory {
            artworkSize = min(42, fieldWidth - PPSpace.md)
        } else if tallCard {
            artworkSize = min(70, fieldWidth - PPSpace.md)
        } else {
            artworkSize = min(56, fieldWidth - PPSpace.md)
        }

        habitatTopConstraint.constant = accessibilityCategory
            ? PPMainKindsCellMetrics.compactTopInset
            : (tallCard
                ? PPMainKindsCellMetrics.tallTopInset
                : PPMainKindsCellMetrics.regularTopInset)
        habitatWidthConstraint.constant = fieldWidth
        habitatHeightConstraint.constant = fieldHeight
        artworkWidthConstraint.constant = artworkSize
        artworkHeightConstraint.constant = artworkSize
        titleBottomConstraint.constant = -(accessibilityCategory
            ? PPMainKindsCellMetrics.accessibilityTitleBottomInset
            : PPMainKindsCellMetrics.titleBottomInset)
        titleLabel.numberOfLines = accessibilityCategory ? 3 : 2

        if tallCard {
            if titleMinimumTopConstraint.isActive {
                NSLayoutConstraint.deactivate([
                    titleMinimumTopConstraint,
                    titleBottomConstraint
                ])
                NSLayoutConstraint.activate([
                    titleAdjacentTopConstraint,
                    titleBottomLimitConstraint
                ])
            }
        } else if titleAdjacentTopConstraint.isActive {
            NSLayoutConstraint.deactivate([
                titleAdjacentTopConstraint,
                titleBottomLimitConstraint
            ])
            NSLayoutConstraint.activate([
                titleMinimumTopConstraint,
                titleBottomConstraint
            ])
        }
    }

    private func resolvedTitleFont() -> UIFont {
        let selectedAppearance = rendersSelectedAppearance
        let fontName = selectedAppearance ? "Beiruti-Bold" : "Beiruti-Medium"
        let baseFont = UIFont(name: fontName, size: 15)
            ?? UIFont.systemFont(
                ofSize: 15,
                weight: selectedAppearance ? .bold : .semibold
            )
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: baseFont,
            maximumPointSize: 24
        )
    }

    private var usesExpandedTextLayout: Bool {
        let category = traitCollection.preferredContentSizeCategory
        return category.isAccessibilityCategory || category == .extraExtraExtraLarge
    }

    private func resolvedImageTintColor(selected: Bool) -> UIColor {
        if isAllOption, !selected {
            return PPMainKindsCellPalette.secondaryText
        }
        return presentationAccentColor
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
            canvasView.alpha = pressed ? 0.86 : 1
            return
        }

        UIView.animate(
            withDuration: pressed
                ? PPMainKindsCellMetrics.pressDuration
                : PPMainKindsCellMetrics.releaseDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut],
            animations: {
                self.tapButton.transform = pressed
                    ? CGAffineTransform(
                        scaleX: PPMainKindsCellMetrics.pressScale,
                        y: PPMainKindsCellMetrics.pressScale
                    )
                    : .identity
                self.kindImageView.transform = pressed
                    ? CGAffineTransform(
                        scaleX: PPMainKindsCellMetrics.pressArtworkScale,
                        y: PPMainKindsCellMetrics.pressArtworkScale
                    )
                    : .identity
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
        isPreviewingSelection = true
        updateTypographyAndMetrics(force: true)
        applyAppearance(animated: false)
        performSignatureCommitMotion()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingCommitWorkItem = nil
            self.isCommitInFlight = false
            guard self.interactionGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.window != nil,
                  self.onSelect != nil else {
                return
            }

            selection(kind, isAll)
            guard self.interactionGeneration == generation,
                  self.window != nil else {
                return
            }
            self.schedulePreviewRecovery(
                expectedCellID: expectedCellID,
                generation: generation
            )
        }
        pendingCommitWorkItem?.cancel()
        pendingCommitWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PPMainKindsCellMetrics.commitDuration,
            execute: workItem
        )
    }

    private func schedulePreviewRecovery(
        expectedCellID: String?,
        generation: Int
    ) {
        let recovery = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingPreviewRecoveryWorkItem = nil
            guard self.interactionGeneration == generation,
                  self.boundCellID == expectedCellID,
                  self.isPreviewingSelection,
                  !self.isKindSelected else {
                return
            }
            self.isPreviewingSelection = false
            self.updateTypographyAndMetrics(force: true)
            self.applyAppearance(animated: true)
        }
        pendingPreviewRecoveryWorkItem?.cancel()
        pendingPreviewRecoveryWorkItem = recovery
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PPMainKindsCellMetrics.previewRecoveryDelay,
            execute: recovery
        )
    }

    private func performSignatureCommitMotion() {
        guard !reduceMotion else {
            stopVisualMotionAndSettle()
            return
        }
        stopViewAnimations(settle: false)
        let habitatStartAlpha: CGFloat = isKindSelected ? 0.68 : 0
        habitatFieldView.alpha = habitatStartAlpha
        kindImageView.transform = CGAffineTransform(scaleX: 0.986, y: 0.986)

        UIView.animateKeyframes(
            withDuration: PPMainKindsCellMetrics.commitDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.58) {
                    self.tapButton.transform = .identity
                    self.habitatFieldView.alpha = 1
                    self.kindImageView.transform = CGAffineTransform(
                        scaleX: PPMainKindsCellMetrics.commitArtworkPeakScale,
                        y: PPMainKindsCellMetrics.commitArtworkPeakScale
                    )
                }
                UIView.addKeyframe(withRelativeStartTime: 0.58, relativeDuration: 0.42) {
                    self.kindImageView.transform = .identity
                }
            }
        )
    }

    @objc public func playRestoredSelectionAnimation() {
        guard window != nil,
              isKindSelected,
              usesRestoredSelectionAppearance else {
            return
        }
        guard !reduceMotion else {
            applyAppearance(animated: false)
            return
        }

        stopViewAnimations(settle: false)
        habitatFieldView.alpha = 0.36
        kindImageView.transform = CGAffineTransform(scaleX: 0.99, y: 0.99)
        UIView.animate(
            withDuration: PPMainKindsCellMetrics.restoredSelectionDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut],
            animations: {
                self.habitatFieldView.alpha = 1
                self.kindImageView.transform = .identity
            }
        )
    }

    @objc public func playSelectionChangeAnimation() {
        guard window != nil,
              isKindSelected,
              !usesRestoredSelectionAppearance else {
            return
        }
        guard !reduceMotion else {
            applyAppearance(animated: false)
            return
        }

        stopViewAnimations(settle: false)
        habitatFieldView.alpha = 0
        kindImageView.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
        UIView.animateKeyframes(
            withDuration: PPMainKindsCellMetrics.selectionDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.62) {
                    self.habitatFieldView.alpha = 1
                    self.kindImageView.transform = CGAffineTransform(scaleX: 1.014, y: 1.014)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.62, relativeDuration: 0.38) {
                    self.kindImageView.transform = .identity
                }
            }
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateTypographyAndMetrics(force: false)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        habitatFieldView.layer.cornerRadius = habitatFieldView.bounds.height / 2
        habitatFieldView.layer.cornerCurve = .continuous
        habitatLayer.frame = habitatFieldView.bounds
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPMainKindsCellMetrics.cornerRadius
        ).cgPath
        CATransaction.commit()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelPendingInteraction(clearPreview: true)
        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        PPImageLoaderManager.shared().cancelImageLoad(for: kindImageView)

        pendingCommitWorkItem?.cancel()
        pendingCommitWorkItem = nil
        pendingPreviewRecoveryWorkItem?.cancel()
        pendingPreviewRecoveryWorkItem = nil
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
        isPreviewingSelection = false
        titleLabel.text = nil
        kindImageView.image = nil
        tapButton.largeContentTitle = nil
        tapButton.largeContentImage = nil
        tapButton.accessibilityLabel = nil
        tapButton.accessibilityIdentifier = nil
        tapButton.accessibilityTraits = .button
        stopVisualMotionAndSettle()
        updateTypographyAndMetrics(force: true)
        applyAppearance(animated: false)
    }

    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory {
            updateTypographyAndMetrics(force: true)
        }
        if previousTraitCollection?.hasDifferentColorAppearance(
            comparedTo: traitCollection
        ) == true || previousTraitCollection?.accessibilityContrast
            != traitCollection.accessibilityContrast {
            applyAppearance(animated: false)
        }
        applyLayoutDirection()
        setNeedsLayout()
    }

    private func stopVisualMotionAndSettle() {
        stopViewAnimations(settle: true)
    }

    private func cancelPendingInteraction(clearPreview: Bool) {
        pendingCommitWorkItem?.cancel()
        pendingCommitWorkItem = nil
        pendingPreviewRecoveryWorkItem?.cancel()
        pendingPreviewRecoveryWorkItem = nil
        isCommitInFlight = false
        interactionGeneration &+= 1
        if clearPreview {
            isPreviewingSelection = false
            updateTypographyAndMetrics(force: true)
        }
        stopVisualMotionAndSettle()
        if clearPreview {
            applyAppearance(animated: false)
        }
    }

    private func stopViewAnimations(settle: Bool) {
        tapButton.layer.removeAllAnimations()
        surfaceView.layer.removeAllAnimations()
        canvasView.layer.removeAllAnimations()
        habitatFieldView.layer.removeAllAnimations()
        habitatLayer.removeAllAnimations()
        kindImageView.layer.removeAllAnimations()
        titleLabel.layer.removeAllAnimations()

        guard settle else { return }
        isPressing = false
        tapButton.transform = .identity
        surfaceView.transform = .identity
        canvasView.transform = .identity
        canvasView.alpha = 1
        kindImageView.transform = .identity
        titleLabel.transform = .identity
        habitatFieldView.alpha = rendersSelectedAppearance ? 1 : 0
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

    private var presentationAccentColor: UIColor {
        let candidate = currentAccentColor.resolvedColor(with: traitCollection)
        let surface = PPMainKindsCellPalette.surface.resolvedColor(with: traitCollection)
        let text = PPMainKindsCellPalette.primaryText.resolvedColor(with: traitCollection)
        let requiredContrast: CGFloat = traitCollection.accessibilityContrast == .high ? 4.5 : 3

        guard let opaqueCandidate = candidate.ppOpaqueColor else {
            return PPMainKindsCellPalette.brand
        }
        if opaqueCandidate.ppContrastRatio(against: surface) >= requiredContrast {
            return opaqueCandidate
        }

        let strengthened = opaqueCandidate.blended(
            with: text,
            ratio: 0.62,
            traitCollection: traitCollection
        )
        if strengthened.ppContrastRatio(against: surface) >= requiredContrast {
            return strengthened
        }

        let brand = PPMainKindsCellPalette.brand.resolvedColor(with: traitCollection)
        if brand.ppContrastRatio(against: surface) >= requiredContrast {
            return brand
        }
        let strengthenedBrand = brand.blended(
            with: text,
            ratio: 0.58,
            traitCollection: traitCollection
        )
        return strengthenedBrand.ppContrastRatio(against: surface) >= requiredContrast
            ? strengthenedBrand
            : text
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
}

private extension UIColor {
    var ppOpaqueColor: UIColor? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            guard alpha >= 0.12 else { return nil }
            return UIColor(white: white, alpha: 1)
        }
        return nil
    }

    func ppContrastRatio(against other: UIColor) -> CGFloat {
        let lighter = max(ppRelativeLuminance, other.ppRelativeLuminance)
        let darker = min(ppRelativeLuminance, other.ppRelativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var ppRelativeLuminance: CGFloat {
        guard let opaque = ppOpaqueColor else { return 0 }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard opaque.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0
        }

        func linear(_ component: CGFloat) -> CGFloat {
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear(red))
            + (0.7152 * linear(green))
            + (0.0722 * linear(blue))
    }

    func blended(
        with color: UIColor,
        ratio: CGFloat,
        traitCollection: UITraitCollection
    ) -> UIColor {
        let first = resolvedColor(with: traitCollection)
        let second = color.resolvedColor(with: traitCollection)

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return first
        }

        let amount = max(0, min(1, ratio))
        return UIColor(
            red: (r1 * amount) + (r2 * (1 - amount)),
            green: (g1 * amount) + (g2 * (1 - amount)),
            blue: (b1 * amount) + (b2 * (1 - amount)),
            alpha: (a1 * amount) + (a2 * (1 - amount))
        )
    }
}
