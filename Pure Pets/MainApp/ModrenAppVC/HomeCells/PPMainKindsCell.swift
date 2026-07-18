import UIKit

private enum PPMainKindsCellMetrics {
    static let cornerRadius: CGFloat = 18
    static let contentInset: CGFloat = 8
    static let imagePlateSize: CGFloat = 72
    static let compactImagePlateSize: CGFloat = 64
    static let artworkSize: CGFloat = 58
    static let allArtworkSize: CGFloat = 28
    static let imageToTitleSpacing: CGFloat = 6
    static let indicatorWidth: CGFloat = 28
    static let indicatorHeight: CGFloat = 3
    static let selectedBorderWidth: CGFloat = 1.5
    static let regularBorderWidth: CGFloat = 1 / UIScreen.main.scale
    static let pressDuration: TimeInterval = 0.10
    static let releaseDuration: TimeInterval = 0.22
    static let selectionDuration: TimeInterval = 0.24
    static let routeDelay: TimeInterval = 0.055
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

    static var plate: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        }
    }

    static var border: UIColor {
        UIColor.separator.withAlphaComponent(0.28)
    }
}

@objc(PPMainKindsCell)
public final class PPMainKindsCell: UICollectionViewCell {
    @objc public class var reuseIdentifier: String { "PPMainKindsCell" }

    @objc public var onSelect: ((NSObject?, Bool) -> Void)?
    @objc public var boundCellID: String?

    private let tapButton = UIButton(type: .custom)
    private let surfaceView = UIView()
    private let imagePlateView = UIView()
    private let kindImageView = UIImageView()
    private let titleLabel = UILabel()
    private let selectionIndicatorView = UIView()

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

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
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

        imagePlateView.translatesAutoresizingMaskIntoConstraints = false
        imagePlateView.isUserInteractionEnabled = false
        imagePlateView.layer.masksToBounds = true
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
        let shouldAnimateSelection = sameBinding && window != nil && isKindSelected != selected
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
            kindImageView.tintColor = currentAccentColor
        }

        applyAppearance(animated: shouldAnimateSelection)
    }

    private func configureImage(for kind: NSObject?, isAll: Bool) {
        PPImageLoaderManager.shared().cancelImageLoad(for: kindImageView)

        if isAll {
            let configuration = UIImage.SymbolConfiguration(
                pointSize: 24,
                weight: .semibold,
                scale: .medium
            )
            let image = UIImage(named: "square-layout")
                ?? UIImage(systemName: "square.grid.2x2.fill", withConfiguration: configuration)
            kindImageView.image = image?.withRenderingMode(.alwaysTemplate)
            kindImageView.tintColor = currentAccentColor
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

        kindImageView.tintColor = currentAccentColor
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

        let updates = {
            self.surfaceView.backgroundColor = selected
                ? accent.withAlphaComponent(reduceTransparency ? 0.16 : 0.10)
                : PPMainKindsCellPalette.card
            self.surfaceView.layer.borderColor = (
                selected ? accent.withAlphaComponent(0.72) : PPMainKindsCellPalette.border
            ).resolvedColor(with: self.traitCollection).cgColor
            self.surfaceView.layer.borderWidth = self.usesRestoredSelectionAppearance && selected
                ? PPMainKindsCellMetrics.regularBorderWidth
                : (selected
                    ? PPMainKindsCellMetrics.selectedBorderWidth
                    : PPMainKindsCellMetrics.regularBorderWidth)
            self.surfaceView.layer.shadowColor = UIColor.black.cgColor
            self.surfaceView.layer.shadowOpacity = selected ? 0.055 : 0.025
            self.surfaceView.layer.shadowRadius = selected ? 10 : 7
            self.surfaceView.layer.shadowOffset = CGSize(width: 0, height: selected ? 4 : 2)
            self.imagePlateView.backgroundColor = selected
                ? accent.withAlphaComponent(reduceTransparency ? 0.18 : 0.11)
                : PPMainKindsCellPalette.plate
            self.titleLabel.textColor = selected ? accent : PPMainKindsCellPalette.primaryText
            self.selectionIndicatorView.backgroundColor = accent
            self.selectionIndicatorView.alpha = selected ? 1 : 0
            self.tapButton.transform = .identity
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
        let plateSize = accessibilityText
            ? PPMainKindsCellMetrics.compactImagePlateSize
            : PPMainKindsCellMetrics.imagePlateSize
        let baseArtworkSize = isAllOption
            ? PPMainKindsCellMetrics.allArtworkSize
            : PPMainKindsCellMetrics.artworkSize
        let artworkSize = accessibilityText ? min(baseArtworkSize, plateSize - 12) : baseArtworkSize

        imagePlateWidthConstraint.constant = plateSize
        imagePlateHeightConstraint.constant = plateSize
        artworkWidthConstraint.constant = artworkSize
        artworkHeightConstraint.constant = artworkSize
        imagePlateView.layer.cornerRadius = plateSize / 2
    }

    @objc private func handleTouchDown() {
        applyPressed(true)
    }

    @objc private func handleTouchUp() {
        applyPressed(false)
    }

    private func applyPressed(_ pressed: Bool) {
        guard !reduceMotion else {
            tapButton.transform = .identity
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
                    ? CGAffineTransform(scaleX: 0.975, y: 0.975)
                    : .identity
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

        if reduceMotion {
            selection(kind, isAll)
            return
        }

        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.imagePlateView.transform = CGAffineTransform(scaleX: 1.035, y: 1.035)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.18,
                    delay: 0,
                    options: [.allowUserInteraction, .beginFromCurrentState],
                    animations: {
                        self.imagePlateView.transform = .identity
                    }
                )
            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + PPMainKindsCellMetrics.routeDelay) {
            selection(kind, isAll)
        }
    }

    @objc public func playRestoredSelectionAnimation() {
        guard window != nil, isKindSelected, !reduceMotion else { return }

        selectionIndicatorView.transform = CGAffineTransform(scaleX: 0.72, y: 1)
        surfaceView.transform = CGAffineTransform(scaleX: 0.992, y: 0.992)
        UIView.animate(
            withDuration: 0.34,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.20,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.selectionIndicatorView.transform = .identity
                self.surfaceView.transform = .identity
            }
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPMainKindsCellMetrics.cornerRadius
        ).cgPath
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
        titleLabel.text = nil
        kindImageView.image = nil
        tapButton.accessibilityLabel = nil
        tapButton.accessibilityIdentifier = nil
        tapButton.accessibilityTraits = .button
        tapButton.transform = .identity
        imagePlateView.transform = .identity
        selectionIndicatorView.transform = .identity
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
}
