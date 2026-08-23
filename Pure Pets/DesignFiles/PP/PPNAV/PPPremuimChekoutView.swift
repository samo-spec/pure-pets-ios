//
//  PPPremuimChekoutView.swift
//  Pure Pets
//
//  Checkout Horizon — the persistent order decision surface shared by Cart
//  and Payment. Business state, validation, navigation, and payment ownership
//  remain in the Objective-C hosts.
//

import UIKit

// MARK: - Source-bound presentation

private enum PPCheckoutHorizonFont {
    static func medium(_ size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Medium", size: size, weight: .medium, textStyle: textStyle)
    }

    static func bold(_ size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Bold", size: size, weight: .bold, textStyle: textStyle)
    }

    private static func scaled(
        named name: String,
        size: CGFloat,
        weight: UIFont.Weight,
        textStyle: UIFont.TextStyle
    ) -> UIFont {
        let base = UIFont(name: name, size: size + 1)
            ?? UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}

private enum PPCheckoutHorizonColor {
    static var action: UIColor { .ppPrimary }
    static var pressedAction: UIColor { .ppPressedAction }
    static var actionText: UIColor { .white }
    static var surface: UIColor { .ppSurfaceElevated }
    static var secondarySurface: UIColor { .ppSurface }
    static var quietSurface: UIColor { .ppSurfaceOverlay }
    static var border: UIColor { .ppSurfaceBorder }
    static var primaryText: UIColor { .ppTextPrimary }
    static var secondaryText: UIColor { .ppTextSecondary }
    static var tertiaryText: UIColor { .ppTextTertiary }
    static var protectedState: UIColor { .ppSuccess }
}

private enum PPCheckoutHorizonGeometry {
    static let portraitSize: CGFloat = 68
    static let compactPortraitSize: CGFloat = 46
    static let maximumPortraits = 1
    static let regularPreviewHeight: CGFloat = 78
    static let accessibilityPreviewHeight: CGFloat = 132
    static let checkoutMinimumWidth: CGFloat = 190
    static let checkoutMaximumWidth: CGFloat = 226
    static let horizontalDecisionMinimumWidth: CGFloat = 350
    static let collapsedDecisionMinimumWidth: CGFloat = 410
    static let checkoutTapDebounce: TimeInterval = 0.45
    static let causalMotionDuration: TimeInterval = 0.20

    static var hairline: CGFloat {
        UIAccessibility.isDarkerSystemColorsEnabled
            ? 1
            : 1 / max(UIScreen.main.scale, 1)
    }
}

private enum PPCheckoutHorizonCurrency {
    static func format(_ value: CGFloat) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_QA")
        formatter.currencyCode = "QAR"
        formatter.currencySymbol = NSLocalizedString("Rials", comment: "")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(value)))
            ?? NSNumber(value: Double(value)).stringValue
    }
}

private func ppCheckoutHorizonSemantic() -> UISemanticContentAttribute {
    Language.semanticAttributeForCurrentLanguage()
}

private func ppCheckoutHorizonAlignment() -> NSTextAlignment {
    Language.alignmentForCurrentLanguage()
}

private func ppCheckoutHorizonIsRTL() -> Bool {
    ppCheckoutHorizonSemantic() == .forceRightToLeft
}

private func ppCheckoutHorizonLTRIsolate(_ value: String) -> String {
    "\u{2066}\(value)\u{2069}"
}

private func ppCheckoutHorizonItemCount(_ count: Int) -> String {
    let format = NSLocalizedString("checkout_horizon_item_count_format", comment: "")
    return String.localizedStringWithFormat(
        format,
        ppCheckoutHorizonLTRIsolate(String(max(count, 0)))
    )
}

private func ppCheckoutHorizonItemMetadata(quantity: Int, amount: CGFloat) -> String {
    let format = NSLocalizedString("checkout_horizon_item_meta_format", comment: "")
    let quantityToken = ppCheckoutHorizonLTRIsolate("×\(max(quantity, 1))")
    let amountToken = ppCheckoutHorizonLTRIsolate(PPCheckoutHorizonCurrency.format(amount))
    return String.localizedStringWithFormat(format, quantityToken, amountToken)
}

private func ppCheckoutHorizonProductMetadata(
    quantity: Int,
    itemsTotal: CGFloat,
    shippingFee: CGFloat
) -> String {
    let format = NSLocalizedString("checkout_horizon_product_meta_format", comment: "")
    return String.localizedStringWithFormat(
        format,
        ppCheckoutHorizonLTRIsolate(String(max(quantity, 0))),
        ppCheckoutHorizonLTRIsolate(PPCheckoutHorizonCurrency.format(itemsTotal)),
        ppCheckoutHorizonLTRIsolate(PPCheckoutHorizonCurrency.format(shippingFee))
    )
}

// MARK: - Live item identity

private final class PPCheckoutHorizonPortraitView: UIView {
    private let imageView = UIImageView()
    private var representedKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    deinit {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight
        layer.cornerCurve = .continuous
        layer.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = false
        imageView.semanticContentAttribute = .forceLeftToRight
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        refreshColors()
        configure(item: nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) * 0.28
    }

    func configure(item: CartItem?) {
        let itemID = (item?.itemID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL = (item?.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = item == nil ? "checkout-placeholder" : "\(itemID)|\(imageURL)"
        guard representedKey != key else { return }
        representedKey = key

        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        let symbolName = item == nil ? "bag.fill" : "pawprint.fill"
        let configuration = UIImage.SymbolConfiguration(
            pointSize: item == nil ? 18 : 17,
            weight: .semibold,
            scale: .medium
        )
        let placeholder = UIImage(systemName: symbolName, withConfiguration: configuration)
        imageView.contentMode = .center
        imageView.image = placeholder
        imageView.tintColor = PPCheckoutHorizonColor.secondaryText

        guard !imageURL.isEmpty else { return }
        let expectedKey = key
        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: imageURL,
            placeholder: placeholder,
            transitionStyle: .none
        ) { [weak self] image, _ in
            let apply = {
                guard let self,
                      self.representedKey == expectedKey,
                      let image else {
                    return
                }
                self.imageView.contentMode = .scaleAspectFit
                self.imageView.image = image.withRenderingMode(.alwaysOriginal)
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }
    }

    func prepareForReuse() {
        representedKey = ""
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        configure(item: nil)
    }

    func refreshColors() {
        backgroundColor = PPCheckoutHorizonColor.quietSurface
        layer.borderColor = PPCheckoutHorizonColor.border.cgColor
        layer.borderWidth = PPCheckoutHorizonGeometry.hairline
        imageView.backgroundColor = .clear
        if imageView.image?.renderingMode != .alwaysOriginal {
            imageView.tintColor = PPCheckoutHorizonColor.secondaryText
        }
    }
}

private final class PPCheckoutHorizonPortraitCluster: UIView {
    private let stack = UIStackView()
    private let countBadge = UILabel()
    private let portraits: [PPCheckoutHorizonPortraitView] = (0..<PPCheckoutHorizonGeometry.maximumPortraits)
        .map { _ in PPCheckoutHorizonPortraitView() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 0
        stack.semanticContentAttribute = .forceLeftToRight
        stack.isUserInteractionEnabled = false

        portraits.forEach { portrait in
            stack.addArrangedSubview(portrait)
            NSLayoutConstraint.activate([
                portrait.widthAnchor.constraint(equalToConstant: PPCheckoutHorizonGeometry.portraitSize),
                portrait.heightAnchor.constraint(equalToConstant: PPCheckoutHorizonGeometry.portraitSize)
            ])
        }
        addSubview(stack)

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = PPCheckoutHorizonFont.bold(10, textStyle: .caption2)
        countBadge.adjustsFontForContentSizeCategory = true
        countBadge.textAlignment = .center
        countBadge.semanticContentAttribute = .forceLeftToRight
        countBadge.layer.masksToBounds = true
        countBadge.isAccessibilityElement = false
        addSubview(countBadge)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PPCheckoutHorizonGeometry.portraitSize),
            heightAnchor.constraint(equalToConstant: PPCheckoutHorizonGeometry.portraitSize),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            countBadge.topAnchor.constraint(equalTo: topAnchor, constant: -PPSpace.xxs),
            countBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: PPSpace.xxs),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 22),
            countBadge.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        countBadge.layer.cornerRadius = countBadge.bounds.height * 0.5
    }

    func configure(items: [CartItem]) {
        let visibleCount = max(1, min(items.count, PPCheckoutHorizonGeometry.maximumPortraits))
        for (index, portrait) in portraits.enumerated() {
            let visible = index < visibleCount
            portrait.isHidden = !visible
            portrait.configure(item: index < items.count ? items[index] : nil)
        }
        let quantity = items.reduce(0) { $0 + max($1.quantity, 0) }
        countBadge.text = quantity > 0 ? "\(quantity)" : nil
        countBadge.isHidden = quantity <= 0
    }

    func refreshColors() {
        portraits.forEach { $0.refreshColors() }
        countBadge.backgroundColor = PPCheckoutHorizonColor.action
        countBadge.textColor = PPCheckoutHorizonColor.actionText
    }
}

// MARK: - Order disclosure

private final class PPCheckoutHorizonHeaderControl: UIControl {
    private let contentStack = UIStackView()
    private let portraitCluster = PPCheckoutHorizonPortraitCluster()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let chevronPlate = UIView()
    private let chevronView = UIImageView()
    private var collapsible = false

    override var isHighlighted: Bool {
        didSet { refreshColors() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityIdentifier = "checkoutHorizon.orderSummary"
        layer.cornerRadius = PPCorner.medium
        layer.cornerCurve = .continuous

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = PPSpace.md
        contentStack.isUserInteractionEnabled = false

        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = PPSpace.xxs
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleLabel.font = PPCheckoutHorizonFont.bold(19, textStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.isAccessibilityElement = false

        metaLabel.font = PPCheckoutHorizonFont.medium(12, textStyle: .caption1)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.numberOfLines = 2
        metaLabel.isAccessibilityElement = false

        chevronPlate.translatesAutoresizingMaskIntoConstraints = false
        chevronPlate.layer.cornerRadius = PPBottomDecisionBarGeometry.utilityControlSize * 0.34
        chevronPlate.layer.cornerCurve = .continuous
        chevronPlate.isAccessibilityElement = false

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.contentMode = .scaleAspectFit
        chevronView.isAccessibilityElement = false
        chevronPlate.addSubview(chevronView)

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(metaLabel)
        contentStack.addArrangedSubview(portraitCluster)
        contentStack.addArrangedSubview(textStack)
        contentStack.addArrangedSubview(chevronPlate)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 78),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            chevronPlate.widthAnchor.constraint(equalToConstant: PPBottomDecisionBarGeometry.utilityControlSize),
            chevronPlate.heightAnchor.constraint(equalToConstant: PPBottomDecisionBarGeometry.utilityControlSize),
            chevronView.centerXAnchor.constraint(equalTo: chevronPlate.centerXAnchor),
            chevronView.centerYAnchor.constraint(equalTo: chevronPlate.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 16),
            chevronView.heightAnchor.constraint(equalToConstant: 16)
        ])

        refreshColors()
    }

    func configure(items: [CartItem], title: String, metadata: String) {
        portraitCluster.configure(items: items)
        titleLabel.text = title
        metaLabel.text = metadata
        accessibilityLabel = title
        accessibilityValue = metadata
        refreshLanguage()
    }

    func setDisclosure(collapsible: Bool, collapsed: Bool) {
        self.collapsible = collapsible
        isUserInteractionEnabled = collapsible
        accessibilityTraits = collapsible ? [.button] : [.staticText]
        chevronPlate.isHidden = !collapsible
        chevronView.image = UIImage(systemName: collapsed ? "chevron.up" : "chevron.down")
        refreshColors()
    }

    func refreshLanguage() {
        let semantic = ppCheckoutHorizonSemantic()
        semanticContentAttribute = semantic
        contentStack.semanticContentAttribute = semantic
        textStack.semanticContentAttribute = semantic
        titleLabel.textAlignment = ppCheckoutHorizonAlignment()
        metaLabel.textAlignment = ppCheckoutHorizonAlignment()
    }

    func refreshColors() {
        backgroundColor = isHighlighted && collapsible
            ? PPCheckoutHorizonColor.quietSurface
            : .clear
        portraitCluster.refreshColors()
        titleLabel.textColor = PPCheckoutHorizonColor.primaryText
        metaLabel.textColor = PPCheckoutHorizonColor.secondaryText
        chevronPlate.backgroundColor = PPCheckoutHorizonColor.quietSurface
        chevronPlate.layer.borderColor = PPCheckoutHorizonColor.border.cgColor
        chevronPlate.layer.borderWidth = PPCheckoutHorizonGeometry.hairline
        chevronView.tintColor = PPCheckoutHorizonColor.secondaryText
    }
}

private final class PPCheckoutHorizonCompactToggle: UIControl {
    private let portrait = PPCheckoutHorizonPortraitView()
    private let countBadge = UILabel()
    private let chevronPlate = UIView()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.up"))

    override var isHighlighted: Bool {
        didSet { refreshColors() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        accessibilityIdentifier = "checkoutHorizon.compactSummary"
        layer.cornerRadius = PPBottomDecisionBarGeometry.controlRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = PPCheckoutHorizonGeometry.hairline

        addSubview(portrait)
        portrait.translatesAutoresizingMaskIntoConstraints = false

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = PPCheckoutHorizonFont.bold(10, textStyle: .caption2)
        countBadge.adjustsFontForContentSizeCategory = true
        countBadge.textAlignment = .center
        countBadge.layer.masksToBounds = true
        countBadge.isAccessibilityElement = false
        addSubview(countBadge)

        chevronPlate.translatesAutoresizingMaskIntoConstraints = false
        chevronPlate.layer.masksToBounds = true
        chevronPlate.isAccessibilityElement = false
        addSubview(chevronPlate)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.contentMode = .scaleAspectFit
        chevronView.isAccessibilityElement = false
        chevronPlate.addSubview(chevronView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PPBottomDecisionBarGeometry.utilityControlSize),
            heightAnchor.constraint(equalToConstant: PPBottomDecisionBarGeometry.utilityControlSize),
            portrait.centerXAnchor.constraint(equalTo: centerXAnchor),
            portrait.centerYAnchor.constraint(equalTo: centerYAnchor),
            portrait.widthAnchor.constraint(equalToConstant: PPCheckoutHorizonGeometry.compactPortraitSize),
            portrait.heightAnchor.constraint(equalToConstant: PPCheckoutHorizonGeometry.compactPortraitSize),
            countBadge.topAnchor.constraint(equalTo: topAnchor, constant: -PPSpace.xxs),
            countBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: PPSpace.xxs),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            countBadge.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            chevronPlate.bottomAnchor.constraint(equalTo: bottomAnchor, constant: PPSpace.xxs),
            chevronPlate.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -PPSpace.xxs),
            chevronPlate.widthAnchor.constraint(equalToConstant: 20),
            chevronPlate.heightAnchor.constraint(equalToConstant: 20),
            chevronView.centerXAnchor.constraint(equalTo: chevronPlate.centerXAnchor),
            chevronView.centerYAnchor.constraint(equalTo: chevronPlate.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 9),
            chevronView.heightAnchor.constraint(equalToConstant: 9)
        ])

        refreshColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        countBadge.layer.cornerRadius = countBadge.bounds.height * 0.5
        chevronPlate.layer.cornerRadius = chevronPlate.bounds.height * 0.5
    }

    func configure(item: CartItem?, count: Int) {
        portrait.configure(item: item)
        countBadge.text = count > 0 ? "\(count)" : nil
        countBadge.isHidden = count <= 0
    }

    func refreshColors() {
        backgroundColor = isHighlighted
            ? PPCheckoutHorizonColor.quietSurface
            : PPCheckoutHorizonColor.secondarySurface
        layer.borderColor = PPCheckoutHorizonColor.border.cgColor
        layer.borderWidth = PPCheckoutHorizonGeometry.hairline
        portrait.refreshColors()
        countBadge.backgroundColor = PPCheckoutHorizonColor.action
        countBadge.textColor = PPCheckoutHorizonColor.actionText
        chevronPlate.backgroundColor = PPCheckoutHorizonColor.surface
        chevronView.tintColor = PPCheckoutHorizonColor.secondaryText
    }
}

// MARK: - Optional multi-item preview

private final class PPCheckoutHorizonItemCell: UICollectionViewCell {
    static let reuseIdentifier = "PPCheckoutHorizonItemCell"

    private let portrait = PPCheckoutHorizonPortraitView()
    private let textStack = UIStackView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    private func buildView() {
        isAccessibilityElement = true
        accessibilityTraits = [.staticText]
        contentView.layer.cornerRadius = PPCorner.medium
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true

        portrait.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = PPSpace.xxs

        nameLabel.font = PPCheckoutHorizonFont.medium(14, textStyle: .subheadline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail

        metaLabel.font = PPCheckoutHorizonFont.bold(13, textStyle: .footnote)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.numberOfLines = 2

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(metaLabel)
        contentView.addSubview(portrait)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            portrait.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: PPSpace.sm),
            portrait.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            portrait.widthAnchor.constraint(equalToConstant: 54),
            portrait.heightAnchor.constraint(equalToConstant: 54),
            textStack.leadingAnchor.constraint(equalTo: portrait.trailingAnchor, constant: PPSpace.sm),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -PPSpace.md),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: PPSpace.sm),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -PPSpace.sm),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        refreshLanguage()
        refreshColors()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        portrait.prepareForReuse()
        nameLabel.text = nil
        metaLabel.text = nil
        accessibilityLabel = nil
        accessibilityValue = nil
    }

    func configure(item: CartItem) {
        portrait.configure(item: item)
        let rawName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = rawName.isEmpty
            ? NSLocalizedString("checkout_item_fallback", comment: "")
            : rawName
        let quantity = max(item.quantity, 1)
        let lineTotal = item.lineSubtotal > 0
            ? item.lineSubtotal
            : item.price * Double(quantity)
        let metadata = ppCheckoutHorizonItemMetadata(
            quantity: quantity,
            amount: CGFloat(lineTotal)
        )

        nameLabel.text = name
        metaLabel.text = metadata
        accessibilityLabel = name
        accessibilityValue = metadata
        refreshLanguage()
    }

    func refreshLanguage() {
        let semantic = ppCheckoutHorizonSemantic()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        textStack.semanticContentAttribute = semantic
        nameLabel.textAlignment = ppCheckoutHorizonAlignment()
        metaLabel.textAlignment = ppCheckoutHorizonAlignment()
    }

    func refreshColors() {
        contentView.backgroundColor = PPCheckoutHorizonColor.quietSurface
        contentView.layer.borderColor = PPCheckoutHorizonColor.border.cgColor
        contentView.layer.borderWidth = UIAccessibility.isDarkerSystemColorsEnabled
            ? PPCheckoutHorizonGeometry.hairline
            : 0
        portrait.refreshColors()
        nameLabel.textColor = PPCheckoutHorizonColor.primaryText
        metaLabel.textColor = PPCheckoutHorizonColor.secondaryText
    }
}

// MARK: - Primary decision

private final class PPCheckoutHorizonActionButton: UIButton {
    private var visibleTitle = ""
    private var visibleImage: UIImage?
    private var loading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildView()
    }

    deinit {
        stopMotion()
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "checkoutHorizon.primaryAction"
        adjustsImageSizeForAccessibilityContentSizeCategory = true
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontForContentSizeCategory = true
        layer.cornerRadius = PPBottomDecisionBarGeometry.controlRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        configuration = .filled()
        configure(title: NSLocalizedString("Checkout", comment: ""), image: nil)
    }

    override func updateConfiguration() {
        super.updateConfiguration()
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = PPBottomDecisionBarGeometry.controlRadius
        configuration.baseBackgroundColor = isHighlighted
            ? PPCheckoutHorizonColor.pressedAction
            : PPCheckoutHorizonColor.action
        configuration.baseForegroundColor = PPCheckoutHorizonColor.actionText
        configuration.imagePlacement = .trailing
        configuration.imagePadding = PPSpace.sm
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: PPSpace.sm,
            leading: PPSpace.md,
            bottom: PPSpace.sm,
            trailing: PPSpace.md
        )
        configuration.showsActivityIndicator = loading
        configuration.activityIndicatorColorTransformer = UIConfigurationColorTransformer { _ in
            PPCheckoutHorizonColor.actionText
        }

        if !loading {
            var attributes = AttributeContainer()
            attributes.font = PPCheckoutHorizonFont.bold(16, textStyle: .headline)
            attributes.foregroundColor = PPCheckoutHorizonColor.actionText
            configuration.attributedTitle = AttributedString(visibleTitle, attributes: attributes)
            configuration.image = visibleImage?.withRenderingMode(.alwaysTemplate)
        }

        self.configuration = configuration
        alpha = isEnabled || loading ? 1 : 0.58
    }

    func configure(title: String, image: UIImage?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        visibleTitle = trimmed.isEmpty ? NSLocalizedString("Checkout", comment: "") : title
        visibleImage = image
        accessibilityLabel = visibleTitle
        setNeedsUpdateConfiguration()
        invalidateIntrinsicContentSize()
    }

    func setLoading(_ loading: Bool) {
        self.loading = loading
        isEnabled = !loading
        accessibilityValue = loading ? NSLocalizedString("Loading", comment: "") : nil
        accessibilityTraits = isEnabled ? [.button] : [.button, .notEnabled]
        setNeedsUpdateConfiguration()
    }

    private var feedbackAnimator: UIViewPropertyAnimator?

    func acknowledgeSelection(accentColor: UIColor?) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()

        stopMotion()
        let resolvedAccent = accentColor ?? PPCheckoutHorizonColor.action
        layer.borderWidth = 2
        layer.borderColor = resolvedAccent.cgColor

        guard !UIAccessibility.isReduceMotionEnabled else {
            layer.borderWidth = 0
            layer.borderColor = UIColor.clear.cgColor
            return
        }
        guard window != nil, UIView.areAnimationsEnabled else {
            layer.borderWidth = 0
            layer.borderColor = UIColor.clear.cgColor
            return
        }

        let animator = UIViewPropertyAnimator(
            duration: PPCheckoutHorizonGeometry.causalMotionDuration,
            curve: .easeOut
        ) {
            self.layer.borderColor = UIColor.clear.cgColor
        }
        animator.addCompletion { [weak self] _ in
            guard let self else { return }
            self.feedbackAnimator = nil
            self.layer.borderWidth = 0
            self.layer.borderColor = UIColor.clear.cgColor
        }
        feedbackAnimator = animator
        animator.startAnimation()
    }

    func stopMotion() {
        feedbackAnimator?.stopAnimation(true)
        feedbackAnimator = nil
        layer.removeAllAnimations()
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
    }
}

// MARK: - Checkout Horizon

@objc(PPPremuimChekoutView)
@objcMembers
public final class PPPremuimChekoutView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public var itemsTotal: CGFloat = 0
    public var shippingFee: CGFloat = 0
    public private(set) var subtotal: CGFloat = 0
    public var showDetails: Bool = true {
        didSet {
            updateOrderIdentity()
            updateVisibility(animated: window != nil)
        }
    }
    public var onTapCheckOut: (() -> Void)?

    private let surfaceView = UIView()
    private let chromeView = UIView()
    private let backgroundArtworkView = UIImageView()
    private let contentStack = UIStackView()

    private let headerControl = PPCheckoutHorizonHeaderControl()
    private let detailStack = UIStackView()

    private let previewCollection: UICollectionView
    private var previewHeightConstraint: NSLayoutConstraint?

    private let decisionPanel = UIView()
    private let decisionStack = UIStackView()
    private let totalControlRow = UIStackView()
    private let compactToggle = PPCheckoutHorizonCompactToggle()
    private let totalStack = UIStackView()
    private let totalCaptionRow = UIStackView()
    private let totalProtectedIcon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
    private let totalCaptionLabel = UILabel()
    private let totalLabel = UILabel()
    private let actionButton = PPCheckoutHorizonActionButton()

    private var contentBottomConstraint: NSLayoutConstraint?
    private var actionMinimumWidthConstraint: NSLayoutConstraint?
    private var actionMaximumWidthConstraint: NSLayoutConstraint?

    private var showsItemsPreview = false
    private var previewItems: [CartItem] = []
    private var totalItemQuantity = 0
    private var checkoutLoading = false
    private var checkoutTapGate = false
    private var checkoutTitle = NSLocalizedString("Checkout", comment: "")
    private var checkoutImage: UIImage?
    private var usesDefaultCheckoutTitle = true
    private var usesAutomaticCheckoutImage = true
    private var collapsible = false
    private var summaryCollapsed = false
    private var protectedStateIsActive = false
    private var lastVisibilitySignature = -1
    private var usesStackedDecisionLayout = false

    private var stateAnimator: UIViewPropertyAnimator?
    private var amountAnimator: UIViewPropertyAnimator?
    private weak var outgoingAmountLabel: UILabel?

    private var reduceMotionIsEnabled: Bool {
        if UIAccessibility.isReduceMotionEnabled { return true }
        return false
    }

    @objc public override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = PPSpace.sm
        layout.minimumInteritemSpacing = PPSpace.sm
        layout.sectionInset = .zero
        previewCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        commonInit()
    }

    @objc public required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = PPSpace.sm
        layout.minimumInteritemSpacing = PPSpace.sm
        layout.sectionInset = .zero
        previewCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        stopMotion(settle: false)
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        clipsToBounds = false
        shouldGroupAccessibilityChildren = true
        accessibilityIdentifier = "checkoutHorizon"

        buildHierarchy()
        buildLayout()
        installObservers()
        applyLanguage()
        refreshColors()
        updateTotalsWithItems(0, shipping: 0, showTitle: true)
        updatePreviewItems(nil)
        setCheckoutBTNTitle(nil, image: nil)
        updateVisibility(animated: false)
    }

    private func buildHierarchy() {
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.layer.cornerRadius = PPBottomDecisionBarGeometry.surfaceRadius
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.clipsToBounds = false
        addSubview(surfaceView)

        chromeView.translatesAutoresizingMaskIntoConstraints = false
        chromeView.layer.cornerRadius = PPBottomDecisionBarGeometry.surfaceRadius
        chromeView.layer.cornerCurve = .continuous
        chromeView.layer.masksToBounds = true
        surfaceView.addSubview(chromeView)

        backgroundArtworkView.translatesAutoresizingMaskIntoConstraints = false
        backgroundArtworkView.contentMode = .scaleAspectFill
        backgroundArtworkView.semanticContentAttribute = .forceLeftToRight
        backgroundArtworkView.isAccessibilityElement = false
        backgroundArtworkView.isHidden = true
        chromeView.addSubview(backgroundArtworkView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = PPSpace.sm
        chromeView.addSubview(contentStack)

        buildHeaderAndDetails()
        buildDecisionPanel()

        contentStack.addArrangedSubview(headerControl)
        contentStack.addArrangedSubview(detailStack)
        contentStack.addArrangedSubview(decisionPanel)
    }

    private func buildHeaderAndDetails() {
        headerControl.addTarget(self, action: #selector(didTapSummaryDisclosure), for: .touchUpInside)

        detailStack.axis = .vertical
        detailStack.alignment = .fill
        detailStack.spacing = PPSpace.sm

        previewCollection.translatesAutoresizingMaskIntoConstraints = false
        previewCollection.backgroundColor = .clear
        previewCollection.showsHorizontalScrollIndicator = false
        previewCollection.alwaysBounceHorizontal = false
        previewCollection.dataSource = self
        previewCollection.delegate = self
        previewCollection.clipsToBounds = false
        previewCollection.register(
            PPCheckoutHorizonItemCell.self,
            forCellWithReuseIdentifier: PPCheckoutHorizonItemCell.reuseIdentifier
        )
        let previewHeight = previewCollection.heightAnchor.constraint(
            equalToConstant: PPCheckoutHorizonGeometry.regularPreviewHeight
        )
        previewHeightConstraint = previewHeight
        previewHeight.isActive = true

        detailStack.addArrangedSubview(previewCollection)
    }

    private func buildDecisionPanel() {
        decisionPanel.translatesAutoresizingMaskIntoConstraints = false
        decisionPanel.layer.cornerRadius = PPCorner.card
        decisionPanel.layer.cornerCurve = .continuous
        decisionPanel.layer.masksToBounds = true

        decisionStack.translatesAutoresizingMaskIntoConstraints = false
        decisionStack.axis = .horizontal
        decisionStack.alignment = .center
        decisionStack.distribution = .fill
        decisionStack.spacing = PPBottomDecisionBarGeometry.controlSpacing
        decisionPanel.addSubview(decisionStack)

        totalControlRow.axis = .horizontal
        totalControlRow.alignment = .center
        totalControlRow.distribution = .fill
        totalControlRow.spacing = PPBottomDecisionBarGeometry.controlSpacing
        totalControlRow.setContentHuggingPriority(.defaultLow, for: .horizontal)
        totalControlRow.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        compactToggle.addTarget(self, action: #selector(didTapSummaryDisclosure), for: .touchUpInside)
        compactToggle.isHidden = true

        totalStack.axis = .vertical
        totalStack.alignment = .fill
        totalStack.spacing = 0
        totalStack.isAccessibilityElement = true
        totalStack.accessibilityIdentifier = "checkoutHorizon.total"
        totalStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        totalCaptionRow.axis = .horizontal
        totalCaptionRow.alignment = .center
        totalCaptionRow.spacing = PPSpace.xs
        totalCaptionRow.isAccessibilityElement = false

        totalProtectedIcon.translatesAutoresizingMaskIntoConstraints = false
        totalProtectedIcon.contentMode = .scaleAspectFit
        totalProtectedIcon.isAccessibilityElement = false
        totalProtectedIcon.setContentHuggingPriority(.required, for: .horizontal)

        totalCaptionLabel.font = PPCheckoutHorizonFont.medium(12, textStyle: .caption1)
        totalCaptionLabel.adjustsFontForContentSizeCategory = true
        totalCaptionLabel.numberOfLines = 1
        totalCaptionLabel.isAccessibilityElement = false
        totalCaptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        totalLabel.font = PPCheckoutHorizonFont.bold(24, textStyle: .title2)
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.numberOfLines = 0
        totalLabel.lineBreakMode = .byWordWrapping
        totalLabel.semanticContentAttribute = .forceLeftToRight
        totalLabel.isAccessibilityElement = false
        totalLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        totalCaptionRow.addArrangedSubview(totalProtectedIcon)
        totalCaptionRow.addArrangedSubview(totalCaptionLabel)
        totalStack.addArrangedSubview(totalCaptionRow)
        totalStack.addArrangedSubview(totalLabel)
        totalControlRow.addArrangedSubview(compactToggle)
        totalControlRow.addArrangedSubview(totalStack)

        actionButton.addTarget(self, action: #selector(didTapCheckout), for: .touchUpInside)
        actionButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        actionButton.setContentCompressionResistancePriority(UILayoutPriority(999), for: .horizontal)

        decisionStack.addArrangedSubview(totalControlRow)
        decisionStack.addArrangedSubview(actionButton)

        let minimumWidth = actionButton.widthAnchor.constraint(
            greaterThanOrEqualToConstant: PPCheckoutHorizonGeometry.checkoutMinimumWidth
        )
        minimumWidth.priority = UILayoutPriority(999)
        let maximumWidth = actionButton.widthAnchor.constraint(
            lessThanOrEqualToConstant: PPCheckoutHorizonGeometry.checkoutMaximumWidth
        )
        actionMinimumWidthConstraint = minimumWidth
        actionMaximumWidthConstraint = maximumWidth

        NSLayoutConstraint.activate([
            decisionStack.topAnchor.constraint(equalTo: decisionPanel.topAnchor, constant: PPSpace.xs),
            decisionStack.leadingAnchor.constraint(equalTo: decisionPanel.leadingAnchor, constant: PPSpace.xs),
            decisionStack.trailingAnchor.constraint(equalTo: decisionPanel.trailingAnchor, constant: -PPSpace.xs),
            decisionStack.bottomAnchor.constraint(equalTo: decisionPanel.bottomAnchor, constant: -PPSpace.xs),
            actionButton.heightAnchor.constraint(
                greaterThanOrEqualToConstant: PPBottomDecisionBarGeometry.controlHeight
            ),
            totalProtectedIcon.widthAnchor.constraint(equalToConstant: 14),
            totalProtectedIcon.heightAnchor.constraint(equalToConstant: 14),
            minimumWidth,
            maximumWidth
        ])
    }

    private func buildLayout() {
        let bottom = contentStack.bottomAnchor.constraint(
            equalTo: chromeView.bottomAnchor,
            constant: -resolvedBottomPadding
        )
        contentBottomConstraint = bottom

        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: topAnchor, constant: PPSpace.xs),
            surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PPSpace.md),
            surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PPSpace.md),
            surfaceView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -PPBottomDecisionBarGeometry.bottomBreathingRoom
            ),

            chromeView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            chromeView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            chromeView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),

            backgroundArtworkView.topAnchor.constraint(equalTo: chromeView.topAnchor),
            backgroundArtworkView.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor),
            backgroundArtworkView.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor),
            backgroundArtworkView.bottomAnchor.constraint(equalTo: chromeView.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: chromeView.topAnchor, constant: PPSpace.sm),
            contentStack.leadingAnchor.constraint(
                equalTo: chromeView.leadingAnchor,
                constant: PPBottomDecisionBarGeometry.contentPadding
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: chromeView.trailingAnchor,
                constant: -PPBottomDecisionBarGeometry.contentPadding
            ),
            bottom
        ])
    }

    private func installObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(appearancePreferenceDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(appearancePreferenceDidChange),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: Notification.Name("LanguageDidChangeNotification"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: Notification.Name("PPLanguageDidChangeNotification"),
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private var resolvedBottomPadding: CGFloat {
        PPSpace.md
    }

    // MARK: Lifecycle and sizing

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopMotion(settle: true)
        }
    }

    public override func layoutSubviews() {
        updateAdaptiveLayout(for: bounds.width)
        super.layoutSubviews()
        updateShadowPath()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            super.traitCollectionDidChange(previousTraitCollection)
        }

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshColors()
        }

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            stopMotion(settle: true)
            updateAdaptiveLayout(for: bounds.width)
            previewCollection.collectionViewLayout.invalidateLayout()
            invalidateIntrinsicContentSize()
            superview?.setNeedsLayout()
        }
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    public override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight(for: width))
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let width = targetSize.width > 1
            ? targetSize.width
            : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: measuredHeight(for: width))
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let width = targetSize.width > 1
            ? targetSize.width
            : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: measuredHeight(for: width))
    }

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        let resolvedWidth = max(width, 1)
        updateAdaptiveLayout(for: resolvedWidth)
        let contentWidth = max(
            resolvedWidth - (PPBottomDecisionBarGeometry.contentPadding * 2),
            1
        )
        let contentSize = contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let exteriorHeight = PPSpace.xs
            + safeAreaInsets.bottom
            + PPBottomDecisionBarGeometry.bottomBreathingRoom
        return ceil(contentSize.height + PPSpace.sm + resolvedBottomPadding + exteriorHeight)
    }

    private func updateAdaptiveLayout(for width: CGFloat) {
        guard width > 1 else { return }
        let accessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let collapseWidth = collapsible && summaryCollapsed
            ? PPCheckoutHorizonGeometry.collapsedDecisionMinimumWidth
            : PPCheckoutHorizonGeometry.horizontalDecisionMinimumWidth
        let shouldStackDecision = accessibilityLayout || width < collapseWidth

        if shouldStackDecision != usesStackedDecisionLayout {
            usesStackedDecisionLayout = shouldStackDecision
            decisionStack.axis = shouldStackDecision ? .vertical : .horizontal
            decisionStack.alignment = .fill
            decisionStack.spacing = shouldStackDecision
                ? PPSpace.sm
                : PPBottomDecisionBarGeometry.controlSpacing
            actionMinimumWidthConstraint?.isActive = !shouldStackDecision
            actionMaximumWidthConstraint?.isActive = !shouldStackDecision
            totalLabel.numberOfLines = shouldStackDecision ? 0 : 1
            invalidateIntrinsicContentSize()
        }

        previewHeightConstraint?.constant = accessibilityLayout
            ? PPCheckoutHorizonGeometry.accessibilityPreviewHeight
            : PPCheckoutHorizonGeometry.regularPreviewHeight
    }

    // MARK: Appearance and language

    private func updateShadowPath() {
        guard surfaceView.bounds.width > 0, surfaceView.bounds.height > 0 else {
            surfaceView.layer.shadowPath = nil
            return
        }
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPBottomDecisionBarGeometry.surfaceRadius
        ).cgPath
    }

    private func refreshColors() {
        chromeView.backgroundColor = PPCheckoutHorizonColor.surface
        chromeView.layer.borderColor = PPCheckoutHorizonColor.border.cgColor
        chromeView.layer.borderWidth = PPCheckoutHorizonGeometry.hairline

        surfaceView.layer.shadowColor = UIColor.black.cgColor
        surfaceView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.20 : 0.08
        surfaceView.layer.shadowRadius = 20
        surfaceView.layer.shadowOffset = CGSize(width: 0, height: 6)

        headerControl.refreshColors()

        decisionPanel.backgroundColor = PPCheckoutHorizonColor.quietSurface
        decisionPanel.layer.borderColor = PPCheckoutHorizonColor.border.cgColor
        decisionPanel.layer.borderWidth = UIAccessibility.isDarkerSystemColorsEnabled
            ? PPCheckoutHorizonGeometry.hairline
            : 0
        totalCaptionLabel.textColor = PPCheckoutHorizonColor.secondaryText
        totalProtectedIcon.tintColor = protectedStateIsActive
            ? PPCheckoutHorizonColor.protectedState
            : PPCheckoutHorizonColor.tertiaryText
        totalLabel.textColor = PPCheckoutHorizonColor.primaryText
        compactToggle.refreshColors()

        backgroundArtworkView.alpha = UIAccessibility.isReduceTransparencyEnabled ? 0.04 : 0.08
        previewCollection.visibleCells.forEach { cell in
            (cell as? PPCheckoutHorizonItemCell)?.refreshColors()
        }
        actionButton.setNeedsUpdateConfiguration()
        setNeedsLayout()
    }

    private func applyLanguage() {
        let semantic = ppCheckoutHorizonSemantic()
        semanticContentAttribute = semantic
        chromeView.semanticContentAttribute = semantic
        contentStack.semanticContentAttribute = semantic
        detailStack.semanticContentAttribute = semantic
        decisionPanel.semanticContentAttribute = semantic
        decisionStack.semanticContentAttribute = semantic
        totalControlRow.semanticContentAttribute = semantic
        totalStack.semanticContentAttribute = semantic
        totalCaptionRow.semanticContentAttribute = semantic
        compactToggle.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic

        totalCaptionLabel.text = NSLocalizedString("checkout_horizon_total_protected", comment: "")
        totalCaptionLabel.textAlignment = ppCheckoutHorizonAlignment()
        totalLabel.textAlignment = ppCheckoutHorizonAlignment()
        totalStack.accessibilityLabel = totalCaptionLabel.text

        if usesDefaultCheckoutTitle {
            checkoutTitle = NSLocalizedString("Checkout", comment: "")
        }
        if usesAutomaticCheckoutImage {
            checkoutImage = UIImage(
                systemName: ppCheckoutHorizonIsRTL() ? "arrow.left" : "arrow.right"
            )
        }
        actionButton.configure(title: checkoutTitle, image: checkoutImage)

        previewCollection.semanticContentAttribute = semantic
        previewCollection.visibleCells.forEach { cell in
            (cell as? PPCheckoutHorizonItemCell)?.refreshLanguage()
        }
        updateOrderIdentity()
        updateCollapseAccessibility()
    }

    private func updateOrderIdentity() {
        let hasContent = !previewItems.isEmpty || subtotal > 0.009
        let firstName = (previewItems.first?.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String
        if !firstName.isEmpty {
            title = firstName
        } else if hasContent {
            title = NSLocalizedString("checkout_item_fallback", comment: "")
        } else {
            title = NSLocalizedString("cartTitle", comment: "")
        }
        let metadata: String
        if !hasContent {
            metadata = NSLocalizedString("Cart", comment: "")
        } else if showDetails {
            metadata = ppCheckoutHorizonProductMetadata(
                quantity: totalItemQuantity,
                itemsTotal: itemsTotal,
                shippingFee: shippingFee
            )
        } else {
            metadata = ppCheckoutHorizonItemCount(totalItemQuantity)
        }
        headerControl.configure(items: previewItems, title: title, metadata: metadata)
        compactToggle.configure(item: previewItems.first, count: totalItemQuantity)
    }

    // MARK: Public Objective-C contract

    @objc(updateTotalsWithItems:shipping:showTitle:)
    func updateTotalsWithItems(_ itemsTotal: CGFloat, shipping shippingFee: CGFloat, showTitle _: Bool) {
        let oldAmount = totalLabel.text
        self.itemsTotal = itemsTotal
        self.shippingFee = shippingFee
        subtotal = itemsTotal + shippingFee

        let totalText = PPCheckoutHorizonCurrency.format(subtotal)
        totalStack.accessibilityValue = totalText

        if let oldAmount, oldAmount != totalText {
            animateAmountChange(from: oldAmount, to: totalText)
        } else {
            totalLabel.text = totalText
        }

        updateOrderIdentity()
        updateCollapseAccessibility()
        updateVisibility(animated: window != nil)
    }

    @objc(setShowsItemsPreview:)
    func setShowsItemsPreview(_ showsItemsPreview: Bool) {
        self.showsItemsPreview = showsItemsPreview
        previewCollection.reloadData()
        updateVisibility(animated: window != nil)
    }

    @objc(updatePreviewItems:)
    func updatePreviewItems(_ items: [CartItem]?) {
        previewItems = items ?? []
        totalItemQuantity = previewItems.reduce(0) { partial, item in
            partial + max(item.quantity, 0)
        }
        previewCollection.alwaysBounceHorizontal = previewItems.count > 1
        previewCollection.reloadData()
        updateOrderIdentity()
        updateCollapseAccessibility()
        updateVisibility(animated: window != nil)
    }

    @objc(setCardBackgroundImage:)
    func setCardBackgroundImage(_ image: UIImage?) {
        backgroundArtworkView.image = image
        backgroundArtworkView.isHidden = image == nil
        refreshColors()
    }

    @objc(setCheckoutBTNTitle:image:)
    func setCheckoutBTNTitle(_ title: String?, image: UIImage?) {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            checkoutTitle = title
            usesDefaultCheckoutTitle = false
        } else {
            checkoutTitle = NSLocalizedString("Checkout", comment: "")
            usesDefaultCheckoutTitle = true
        }

        usesAutomaticCheckoutImage = image == nil
        checkoutImage = image ?? UIImage(
            systemName: ppCheckoutHorizonIsRTL() ? "arrow.left" : "arrow.right"
        )
        actionButton.configure(title: checkoutTitle, image: checkoutImage)
    }

    @objc(triggerPaymentMethodChangeFeedbackWithAccent:)
    public func triggerPaymentMethodChangeFeedback(accentColor: UIColor?) {
        actionButton.acknowledgeSelection(accentColor: accentColor)
    }

    @objc(triggerPaymentMethodChangeFeedback)
    public func triggerPaymentMethodChangeFeedback() {
        triggerPaymentMethodChangeFeedback(accentColor: nil)
    }

    @objc(setCheckoutLoading:)
    func setCheckoutLoading(_ loading: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setCheckoutLoading(loading)
            }
            return
        }
        checkoutLoading = loading
        if !loading {
            checkoutTapGate = false
        }
        actionButton.setLoading(loading)
    }

    @objc(skipCardEntranceAnimation)
    func skipCardEntranceAnimation() {
        // Both production hosts own their route entrance. The rebuilt dock has
        // no competing entrance animation, but this selector remains stable.
        surfaceView.layer.removeAllAnimations()
        surfaceView.alpha = 1
        surfaceView.transform = .identity
    }

    @objc(pp_startTrustBannerShimmer)
    func pp_startTrustBannerShimmer() {
        // The legacy selector now resolves to a static verified-state accent.
        // No perpetual shimmer or continuous rendering work is introduced.
        protectedStateIsActive = true
        refreshColors()
    }

    @objc(pp_stopTrustBannerShimmer)
    func pp_stopTrustBannerShimmer() {
        protectedStateIsActive = false
        refreshColors()
    }

    @objc(setCollapsible:initiallyCollapsed:)
    public func setCollapsible(_ enabled: Bool, initiallyCollapsed collapsed: Bool) {
        collapsible = enabled
        summaryCollapsed = enabled && collapsed
        lastVisibilitySignature = -1
        updateCollapseAccessibility()
        updateVisibility(animated: false)
    }

    @objc(setSummaryCollapsed:animated:)
    public func setSummaryCollapsed(_ collapsed: Bool, animated: Bool) {
        guard collapsible, summaryCollapsed != collapsed else { return }
        summaryCollapsed = collapsed
        updateCollapseAccessibility()
        updateVisibility(animated: animated)
    }

    // MARK: Reachable state presentation

    private func updateCollapseAccessibility() {
        let amount = totalLabel.text ?? ""
        let metadata = totalItemQuantity > 0
            ? ppCheckoutHorizonItemCount(totalItemQuantity)
            : NSLocalizedString("Cart", comment: "")
        let value = [metadata, amount].filter { !$0.isEmpty }.joined(separator: ", ")
        let hint = summaryCollapsed
            ? NSLocalizedString("cart_summary_expand", comment: "")
            : NSLocalizedString("cart_summary_collapse", comment: "")

        headerControl.setDisclosure(collapsible: collapsible, collapsed: summaryCollapsed)
        headerControl.accessibilityValue = value
        headerControl.accessibilityHint = collapsible ? hint : nil

        compactToggle.accessibilityLabel = headerControl.accessibilityLabel
        compactToggle.accessibilityValue = value
        compactToggle.accessibilityHint = NSLocalizedString("cart_summary_expand", comment: "")
    }

    private func updateVisibility(animated: Bool) {
        let collapsed = collapsible && summaryCollapsed
        let showPreview = !collapsed && showsItemsPreview && !previewItems.isEmpty
        let showDetailsRegion = showPreview

        let signature = (collapsed ? 1 : 0)
            | (showPreview ? 2 : 0)
            | (collapsible ? 16 : 0)
        let stateChanged = signature != lastVisibilitySignature
        let collapseChanged = lastVisibilitySignature >= 0
            && (lastVisibilitySignature & 1) != (signature & 1)
        let reduceMotion = reduceMotionIsEnabled
        let shouldAnimate = animated
            && stateChanged
            && window != nil
            && UIView.areAnimationsEnabled
            && !reduceMotion
        lastVisibilitySignature = signature

        stateAnimator?.stopAnimation(true)
        stateAnimator = nil

        let applyFinalState = { [weak self] in
            guard let self else { return }
            headerControl.isHidden = collapsed
            headerControl.accessibilityElementsHidden = collapsed
            detailStack.isHidden = !showDetailsRegion
            detailStack.accessibilityElementsHidden = !showDetailsRegion
            previewCollection.isHidden = !showPreview
            compactToggle.isHidden = !collapsed
            headerControl.alpha = collapsed ? 0 : 1
            detailStack.alpha = showDetailsRegion ? 1 : 0
            previewCollection.alpha = showPreview ? 1 : 0
            compactToggle.alpha = collapsed ? 1 : 0
            invalidateIntrinsicContentSize()
            layoutIfNeeded()
            superview?.layoutIfNeeded()
        }

        let complete = { [weak self] in
            guard let self else { return }
            applyFinalState()
            self.stateAnimator = nil
            superview?.setNeedsLayout()
            updateShadowPath()
            updateCollapseAccessibility()
            if collapseChanged, UIAccessibility.isVoiceOverRunning {
                let target: Any = collapsed ? compactToggle : headerControl
                UIAccessibility.post(notification: .layoutChanged, argument: target)
            }
        }

        guard shouldAnimate else {
            applyFinalState()
            complete()
            return
        }
        guard !UIAccessibility.isReduceMotionEnabled else {
            applyFinalState()
            complete()
            return
        }

        superview?.layoutIfNeeded()
        if !collapsed {
            headerControl.isHidden = false
            headerControl.accessibilityElementsHidden = true
            headerControl.alpha = 0
            if showDetailsRegion {
                detailStack.isHidden = false
                detailStack.accessibilityElementsHidden = true
                detailStack.alpha = 0
            }
        }
        if collapsed {
            compactToggle.isHidden = false
            compactToggle.alpha = 0
        }
        if showPreview { previewCollection.isHidden = false }

        let animator = UIViewPropertyAnimator(
            duration: PPCheckoutHorizonGeometry.causalMotionDuration,
            curve: .easeOut,
            animations: applyFinalState
        )
        animator.addCompletion { [weak self] position in
            guard let self else { return }
            self.stateAnimator = nil
            if position == .end {
                complete()
            } else {
                applyFinalState()
            }
        }
        stateAnimator = animator
        animator.startAnimation()
    }

    private func animateAmountChange(from oldText: String, to newText: String) {
        amountAnimator?.stopAnimation(true)
        amountAnimator = nil
        outgoingAmountLabel?.removeFromSuperview()
        outgoingAmountLabel = nil
        totalLabel.alpha = 1

        guard !UIAccessibility.isReduceMotionEnabled else {
            totalLabel.text = newText
            return
        }
        guard window != nil, UIView.areAnimationsEnabled else {
            totalLabel.text = newText
            return
        }

        totalStack.layoutIfNeeded()
        let outgoing = UILabel()
        outgoing.translatesAutoresizingMaskIntoConstraints = false
        outgoing.font = totalLabel.font
        outgoing.textColor = totalLabel.textColor
        outgoing.textAlignment = totalLabel.textAlignment
        outgoing.adjustsFontForContentSizeCategory = true
        outgoing.numberOfLines = totalLabel.numberOfLines
        outgoing.semanticContentAttribute = .forceLeftToRight
        outgoing.text = oldText
        outgoing.isAccessibilityElement = false
        totalStack.addSubview(outgoing)
        NSLayoutConstraint.activate([
            outgoing.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            outgoing.trailingAnchor.constraint(equalTo: totalLabel.trailingAnchor),
            outgoing.topAnchor.constraint(equalTo: totalLabel.topAnchor),
            outgoing.bottomAnchor.constraint(equalTo: totalLabel.bottomAnchor)
        ])

        outgoingAmountLabel = outgoing
        totalLabel.text = newText
        totalLabel.alpha = 0

        let animator = UIViewPropertyAnimator(
            duration: PPCheckoutHorizonGeometry.causalMotionDuration,
            curve: .easeOut
        ) {
            outgoing.alpha = 0
            self.totalLabel.alpha = 1
        }
        animator.addCompletion { [weak self, weak outgoing] _ in
            outgoing?.removeFromSuperview()
            guard let self else { return }
            self.outgoingAmountLabel = nil
            self.amountAnimator = nil
            self.totalLabel.alpha = 1
        }
        amountAnimator = animator
        animator.startAnimation()
    }

    private func stopMotion(settle: Bool) {
        stateAnimator?.stopAnimation(true)
        stateAnimator = nil
        amountAnimator?.stopAnimation(true)
        amountAnimator = nil
        actionButton.stopMotion()
        outgoingAmountLabel?.removeFromSuperview()
        outgoingAmountLabel = nil
        totalLabel.alpha = 1
        headerControl.alpha = 1
        detailStack.alpha = 1
        compactToggle.alpha = 1
        if settle {
            lastVisibilitySignature = -1
            updateVisibility(animated: false)
        }
    }

    // MARK: Actions and environment updates

    @objc private func didTapSummaryDisclosure() {
        guard collapsible else { return }
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
        setSummaryCollapsed(!summaryCollapsed, animated: true)
    }

    @objc private func didTapCheckout() {
        guard !checkoutLoading, !checkoutTapGate else { return }
        checkoutTapGate = true
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()
        onTapCheckOut?()
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PPCheckoutHorizonGeometry.checkoutTapDebounce
        ) { [weak self] in
            guard let self, !self.checkoutLoading else { return }
            self.checkoutTapGate = false
        }
    }

    @objc private func reduceMotionDidChange() {
        stopMotion(settle: true)
    }

    @objc private func appearancePreferenceDidChange() {
        refreshColors()
    }

    @objc private func languageDidChange() {
        stopMotion(settle: true)
        applyLanguage()
        previewCollection.reloadData()
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    @objc private func applicationDidEnterBackground() {
        stopMotion(settle: true)
    }

    // MARK: Collection view

    public func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        previewItems.count
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard indexPath.item < previewItems.count,
              let cell = collectionView.dequeueReusableCell(
                  withReuseIdentifier: PPCheckoutHorizonItemCell.reuseIdentifier,
                  for: indexPath
              ) as? PPCheckoutHorizonItemCell else {
            return UICollectionViewCell()
        }
        cell.configure(item: previewItems[indexPath.item])
        return cell
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let accessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let widthFraction: CGFloat = accessibilityLayout ? 0.88 : 0.61
        let width = min(
            accessibilityLayout ? 350 : 242,
            max(accessibilityLayout ? 260 : 188, collectionView.bounds.width * widthFraction)
        )
        return CGSize(
            width: width,
            height: accessibilityLayout
                ? PPCheckoutHorizonGeometry.accessibilityPreviewHeight
                : PPCheckoutHorizonGeometry.regularPreviewHeight
        )
    }
}
