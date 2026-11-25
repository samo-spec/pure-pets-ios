//
//  PPContextAwareCheckoutView.swift
//  Pure Pets
//
//  Context-aware checkout dock.
//  Cart: total + CTA only because cart items are already visible above.
//  Payment: compact order-review affordance + expandable live item list + CTA.
//
//  NOTE: PPPremuimChekoutView.swift remains source-compatible for legacy
//  callers. This dock is the context-specific presentation used by Cart and
//  Payment hosts.
//

import UIKit

@objc public enum PPContextAwareCheckoutMode: Int {
    case cart
    case payment
}

private enum PPContextCheckoutMetrics {
    static let outerInset: CGFloat = 16
    static let surfaceRadius: CGFloat = 26
    static let dockedSurfaceRadius: CGFloat = 28
    static let dockedTopInset: CGFloat = 14
    static let dockedHorizontalInset: CGFloat = 20
    static let dockedSafeAreaBreathingRoom: CGFloat = 10
    static let dockedBottomPaddingMinimum: CGFloat = 16
    static let dockedContentSpacing: CGFloat = 10
    static let floatingContentSpacing: CGFloat = 7
    static let panelRadius: CGFloat = 20
    static let controlRadius: CGFloat = 18
    static let actionHeight: CGFloat = 58
    static let reviewHeight: CGFloat = 62
    static let itemRowHeight: CGFloat = 66
    static let maxVisibleRows = 4
    static let maxAccessibilityVisibleRows = 2
    static let decisionHorizontalInset: CGFloat = 14
    static let decisionVerticalInset: CGFloat = 10
    static let dockedDecisionVerticalInset: CGFloat = 2
    static let decisionContentSpacing: CGFloat = 16
    static let breakdownHorizontalInset: CGFloat = 12
    static let breakdownVerticalSpacing: CGFloat = 8
    static let animationDuration: TimeInterval = 0.24
    static let pressSpringDuration: TimeInterval = 0.28
    static let pressSpringDamping: CGFloat = 0.88
    static let checkoutTapDebounce: TimeInterval = 0.45

    static var hairline: CGFloat {
        UIAccessibility.isDarkerSystemColorsEnabled
            ? 1
            : 1 / max(UIScreen.main.scale, 1)
    }
}

private enum PPContextCheckoutColors {
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
}

private enum PPContextCheckoutFont {
    static func medium(_ size: CGFloat, style: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Medium", size: size, weight: .medium, style: style)
    }

    static func bold(_ size: CGFloat, style: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Bold", size: size, weight: .bold, style: style)
    }

    static func monospacedBold(_ size: CGFloat, style: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: "Beiruti-Bold", size: size + 1)
            ?? UIFont.systemFont(ofSize: size, weight: .bold)
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
            ]]
        ])
        let tabular = UIFont(descriptor: descriptor, size: base.pointSize)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: tabular)
    }

    private static func scaled(
        named name: String,
        size: CGFloat,
        weight: UIFont.Weight,
        style: UIFont.TextStyle
    ) -> UIFont {
        let base = UIFont(name: name, size: size + 1)
            ?? UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}

private enum PPContextCheckoutCopy {
    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static var reviewOrder: String {
        localized("checkout_context_review_order")
    }

    static func reviewMeta(count: Int) -> String {
        String.localizedStringWithFormat(
            localized("checkout_context_review_meta_format"),
            max(count, 0)
        )
    }

    static var reviewPayment: String {
        localized("checkout_context_review_payment_hint")
    }

    static var total: String {
        localized("checkout_summary_total_label")
    }

    static var quantity: String {
        localized("checkout_context_quantity")
    }

    static var fallbackItem: String {
        localized("checkout_context_fallback_item")
    }

    static var expandHint: String {
        localized("checkout_context_expand_hint")
    }

    static var collapseHint: String {
        localized("checkout_context_collapse_hint")
    }
}

private enum PPContextCheckoutCurrency {
    private static let lock = NSLock()
    private static var cachedSymbol: String?
    private static var cachedFormatter: NumberFormatter?

    static func format(_ value: CGFloat) -> String {
        let symbol = NSLocalizedString("Rials", comment: "")
        lock.lock()
        defer { lock.unlock() }
        let formatter: NumberFormatter
        if let existing = cachedFormatter, cachedSymbol == symbol {
            formatter = existing
        } else {
            let created = NumberFormatter()
            created.numberStyle = .currency
            created.locale = Locale(identifier: "en_QA")
            created.currencyCode = "QAR"
            created.currencySymbol = symbol
            created.minimumFractionDigits = 2
            created.maximumFractionDigits = 2
            cachedFormatter = created
            cachedSymbol = symbol
            formatter = created
        }
        return formatter.string(from: NSNumber(value: Double(value)))
            ?? String(format: "%.2f", value)
    }
}

private func ppContextSemantic() -> UISemanticContentAttribute {
    Language.semanticAttributeForCurrentLanguage()
}

private func ppContextAlignment() -> NSTextAlignment {
    Language.alignmentForCurrentLanguage()
}

private func ppContextIsRTL() -> Bool {
    ppContextSemantic() == .forceRightToLeft
}

// MARK: - Live thumbnails

private final class PPContextCheckoutThumbnailView: UIView {
    private let imageView = UIImageView()
    private var representedKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = PPContextCheckoutMetrics.hairline

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .center
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

    func configure(item: CartItem?) {
        let itemID = (item?.itemID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL = (item?.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = item == nil ? "placeholder" : "\(itemID)|\(imageURL)"
        guard representedKey != key else { return }
        representedKey = key

        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        let placeholder = UIImage(
            systemName: item == nil ? "bag.fill" : "pawprint.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        )
        imageView.contentMode = .center
        imageView.image = placeholder
        imageView.tintColor = PPContextCheckoutColors.secondaryText

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
                      let image else { return }
                self.imageView.contentMode = .scaleAspectFit
                self.imageView.image = image.withRenderingMode(.alwaysOriginal)
            }
            Thread.isMainThread ? apply() : DispatchQueue.main.async(execute: apply)
        }
    }

    func prepareForReuse() {
        representedKey = ""
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        configure(item: nil)
    }

    func refreshColors() {
        backgroundColor = PPContextCheckoutColors.quietSurface
        layer.borderColor = PPContextCheckoutColors.border.cgColor
        if imageView.image?.renderingMode != .alwaysOriginal {
            imageView.tintColor = PPContextCheckoutColors.secondaryText
        }
    }
}

private final class PPContextCheckoutStackedPreview: UIView {
    private let first = PPContextCheckoutThumbnailView()
    private let second = PPContextCheckoutThumbnailView()
    private let third = PPContextCheckoutThumbnailView()
    private let countBadge = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight

        [third, second, first].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = PPContextCheckoutFont.bold(9, style: .caption2)
        countBadge.adjustsFontForContentSizeCategory = true
        countBadge.textAlignment = .center
        countBadge.layer.masksToBounds = true
        countBadge.layer.borderWidth = 2
        countBadge.isAccessibilityElement = false
        addSubview(countBadge)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 58),
            heightAnchor.constraint(equalToConstant: 44),

            third.widthAnchor.constraint(equalToConstant: 35),
            third.heightAnchor.constraint(equalToConstant: 35),
            third.leadingAnchor.constraint(equalTo: leadingAnchor),
            third.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -2),

            second.widthAnchor.constraint(equalToConstant: 35),
            second.heightAnchor.constraint(equalToConstant: 35),
            second.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            second.centerYAnchor.constraint(equalTo: centerYAnchor),

            first.widthAnchor.constraint(equalToConstant: 35),
            first.heightAnchor.constraint(equalToConstant: 35),
            first.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            first.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),

            countBadge.topAnchor.constraint(equalTo: topAnchor, constant: -2),
            countBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 19),
            countBadge.heightAnchor.constraint(equalToConstant: 19)
        ])
        refreshColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        countBadge.layer.cornerRadius = countBadge.bounds.height * 0.5
    }

    func configure(items: [CartItem]) {
        let views = [first, second, third]
        for (index, view) in views.enumerated() {
            view.configure(item: index < items.count ? items[index] : nil)
            view.isHidden = index >= items.count
        }
        let quantity = items.reduce(0) { $0 + max($1.quantity, 0) }
        countBadge.text = quantity > 0 ? "\(quantity)" : nil
        countBadge.isHidden = quantity <= 0
    }

    func refreshColors() {
        [first, second, third].forEach { $0.refreshColors() }
        countBadge.backgroundColor = PPContextCheckoutColors.action
        countBadge.textColor = PPContextCheckoutColors.actionText
        countBadge.layer.borderColor = PPContextCheckoutColors.surface.cgColor
    }
}

// MARK: - Payment review control

private final class PPContextCheckoutReviewControl: UIControl {
    private let preview = PPContextCheckoutStackedPreview()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let chevronPlate = UIView()
    private let chevron = UIImageView()

    override var isHighlighted: Bool {
        didSet { refreshColors() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        accessibilityIdentifier = "contextCheckout.reviewOrder"
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.borderWidth = PPContextCheckoutMetrics.hairline

        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.isUserInteractionEnabled = false
        addSubview(row)

        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 1
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleLabel.font = PPContextCheckoutFont.bold(14, style: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        titleLabel.isAccessibilityElement = false

        metaLabel.font = PPContextCheckoutFont.medium(11, style: .caption1)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.numberOfLines = 1
        metaLabel.lineBreakMode = .byTruncatingTail
        metaLabel.isAccessibilityElement = false

        chevronPlate.translatesAutoresizingMaskIntoConstraints = false
        chevronPlate.layer.cornerRadius = 15
        chevronPlate.layer.cornerCurve = .continuous
        chevronPlate.isAccessibilityElement = false

        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.contentMode = .scaleAspectFit
        chevron.isAccessibilityElement = false
        chevronPlate.addSubview(chevron)

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(metaLabel)
        row.addArrangedSubview(preview)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(chevronPlate)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: PPContextCheckoutMetrics.reviewHeight),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            chevronPlate.widthAnchor.constraint(equalToConstant: 30),
            chevronPlate.heightAnchor.constraint(equalToConstant: 30),
            chevron.centerXAnchor.constraint(equalTo: chevronPlate.centerXAnchor),
            chevron.centerYAnchor.constraint(equalTo: chevronPlate.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 13),
            chevron.heightAnchor.constraint(equalToConstant: 13)
        ])
        refreshLanguage()
        refreshColors()
    }

    func configure(items: [CartItem], expanded: Bool) {
        preview.configure(items: items)
        let quantity = items.reduce(0) { $0 + max($1.quantity, 0) }
        titleLabel.text = PPContextCheckoutCopy.reviewOrder
        metaLabel.text = PPContextCheckoutCopy.reviewMeta(count: quantity)
        chevron.image = UIImage(systemName: expanded ? "chevron.down" : "chevron.up")
        accessibilityLabel = PPContextCheckoutCopy.reviewOrder
        accessibilityValue = PPContextCheckoutCopy.reviewMeta(count: quantity)
        accessibilityHint = expanded
            ? PPContextCheckoutCopy.collapseHint
            : PPContextCheckoutCopy.expandHint
        refreshLanguage()
    }

    func refreshLanguage() {
        let semantic = ppContextSemantic()
        semanticContentAttribute = semantic
        textStack.semanticContentAttribute = semantic
        titleLabel.textAlignment = ppContextAlignment()
        metaLabel.textAlignment = ppContextAlignment()
    }

    func refreshColors() {
        backgroundColor = isHighlighted
            ? PPContextCheckoutColors.quietSurface
            : PPContextCheckoutColors.surface
        layer.borderColor = PPContextCheckoutColors.border.cgColor
        titleLabel.textColor = PPContextCheckoutColors.primaryText
        metaLabel.textColor = PPContextCheckoutColors.secondaryText
        chevronPlate.backgroundColor = PPContextCheckoutColors.quietSurface
        chevron.tintColor = PPContextCheckoutColors.secondaryText
        preview.refreshColors()
    }
}

// MARK: - Item table

private final class PPContextCheckoutItemCell: UITableViewCell {
    static let reuseIdentifier = "PPContextCheckoutItemCell"

    private let portrait = PPContextCheckoutThumbnailView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let amountLabel = UILabel()
    private let textStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = [.staticText]

        portrait.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 1

        nameLabel.font = PPContextCheckoutFont.bold(12, style: .subheadline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isAccessibilityElement = false

        metaLabel.font = PPContextCheckoutFont.medium(10, style: .caption1)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.numberOfLines = 1
        metaLabel.isAccessibilityElement = false

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = PPContextCheckoutFont.bold(11, style: .footnote)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.numberOfLines = 1
        amountLabel.semanticContentAttribute = .forceLeftToRight
        amountLabel.isAccessibilityElement = false
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(metaLabel)
        contentView.addSubview(portrait)
        contentView.addSubview(textStack)
        contentView.addSubview(amountLabel)

        NSLayoutConstraint.activate([
            portrait.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            portrait.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            portrait.widthAnchor.constraint(equalToConstant: 44),
            portrait.heightAnchor.constraint(equalToConstant: 44),

            textStack.leadingAnchor.constraint(equalTo: portrait.trailingAnchor, constant: 9),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: amountLabel.leadingAnchor, constant: -8),

            amountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            amountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        refreshLanguage()
        refreshColors()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        portrait.prepareForReuse()
        nameLabel.text = nil
        metaLabel.text = nil
        amountLabel.text = nil
        accessibilityLabel = nil
        accessibilityValue = nil
    }

    func configure(item: CartItem) {
        portrait.configure(item: item)
        let rawName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let name = rawName.isEmpty ? PPContextCheckoutCopy.fallbackItem : rawName
        let quantity = max(item.quantity, 1)
        let lineTotal = item.lineSubtotal > 0
            ? item.lineSubtotal
            : item.price * Double(quantity)

        nameLabel.text = name
        metaLabel.text = "\(PPContextCheckoutCopy.quantity) · \(quantity)"
        amountLabel.text = PPContextCheckoutCurrency.format(CGFloat(lineTotal))
        accessibilityLabel = name
        accessibilityValue = "\(metaLabel.text ?? ""), \(amountLabel.text ?? "")"
        refreshLanguage()
    }

    func refreshLanguage() {
        let semantic = ppContextSemantic()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        textStack.semanticContentAttribute = semantic
        nameLabel.textAlignment = ppContextAlignment()
        metaLabel.textAlignment = ppContextAlignment()
        amountLabel.textAlignment = ppContextAlignment()
    }

    func refreshColors() {
        portrait.refreshColors()
        nameLabel.textColor = PPContextCheckoutColors.primaryText
        metaLabel.textColor = PPContextCheckoutColors.secondaryText
        amountLabel.textColor = PPContextCheckoutColors.primaryText
    }
}

// MARK: - Expanded payment pricing

private final class PPContextCheckoutPricingRow: UIView {
    private let emphasized: Bool
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let contentStack = UIStackView()

    init(emphasized: Bool) {
        self.emphasized = emphasized
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.emphasized = false
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .firstBaseline
        contentStack.distribution = .fill
        contentStack.spacing = PPContextCheckoutMetrics.breakdownVerticalSpacing
        addSubview(contentStack)

        titleLabel.font = emphasized
            ? PPContextCheckoutFont.bold(13, style: .headline)
            : PPContextCheckoutFont.medium(12, style: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.isAccessibilityElement = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        amountLabel.font = emphasized
            ? PPContextCheckoutFont.monospacedBold(16, style: .headline)
            : PPContextCheckoutFont.monospacedBold(13, style: .footnote)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.numberOfLines = 1
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.82
        amountLabel.semanticContentAttribute = .forceLeftToRight
        amountLabel.isAccessibilityElement = false
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(amountLabel)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        applyLanguage()
        refreshColors()
    }

    func configure(title: String, amount: String) {
        titleLabel.text = title
        amountLabel.text = amount
        accessibilityLabel = title
        accessibilityValue = amount
    }

    func applyLanguage() {
        let semantic = ppContextSemantic()
        semanticContentAttribute = semantic
        contentStack.semanticContentAttribute = semantic
        titleLabel.textAlignment = ppContextAlignment()
        amountLabel.textAlignment = ppContextAlignment()
    }

    func refreshColors() {
        titleLabel.textColor = emphasized
            ? PPContextCheckoutColors.primaryText
            : PPContextCheckoutColors.secondaryText
        amountLabel.textColor = PPContextCheckoutColors.primaryText
    }
}

// MARK: - Action button

private final class PPContextCheckoutActionButton: UIButton {
    private var visibleTitle = ""
    private var visibleImage: UIImage?
    private var loading = false

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            setNeedsUpdateConfiguration()
            animatePressState(highlighted: isHighlighted)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonButtonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonButtonInit()
    }

    private func commonButtonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "contextCheckout.primaryAction"
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        configuration = .filled()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !bounds.isEmpty {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: PPContextCheckoutMetrics.controlRadius
            ).cgPath
        }
    }

    override func updateConfiguration() {
        super.updateConfiguration()
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.background.cornerRadius = PPContextCheckoutMetrics.controlRadius
        config.baseBackgroundColor = isHighlighted
            ? PPContextCheckoutColors.pressedAction
            : PPContextCheckoutColors.action
        config.baseForegroundColor = PPContextCheckoutColors.actionText
        config.imagePlacement = .trailing
        config.imagePadding = 7
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        config.showsActivityIndicator = loading
        config.activityIndicatorColorTransformer = UIConfigurationColorTransformer { _ in
            PPContextCheckoutColors.actionText
        }

        if !loading {
            var attributes = AttributeContainer()
            attributes.font = PPContextCheckoutFont.bold(15, style: .headline)
            attributes.foregroundColor = PPContextCheckoutColors.actionText
            config.attributedTitle = AttributedString(visibleTitle, attributes: attributes)
            config.image = visibleImage?.withRenderingMode(.alwaysTemplate)
        }
        configuration = config
        alpha = isEnabled || loading ? 1 : 0.58

        let showBrandElevation = isEnabled && !loading
        layer.shadowColor = PPContextCheckoutColors.action.cgColor
        layer.shadowOpacity = showBrandElevation ? (traitCollection.userInterfaceStyle == .dark ? 0.34 : 0.22) : 0
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)
    }

    private func animatePressState(highlighted: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled, UIView.areAnimationsEnabled else {
            transform = .identity
            return
        }
        let targetScale: CGFloat = highlighted ? 0.975 : 1.0
        UIView.animate(
            withDuration: highlighted ? 0.10 : PPContextCheckoutMetrics.pressSpringDuration,
            delay: 0,
            usingSpringWithDamping: highlighted ? 1.0 : PPContextCheckoutMetrics.pressSpringDamping,
            initialSpringVelocity: highlighted ? 0 : 0.2,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                self.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
            }
        )
    }

    func configure(title: String, image: UIImage?) {
        visibleTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? NSLocalizedString("Checkout", comment: "")
            : title
        visibleImage = image
        accessibilityLabel = visibleTitle
        setNeedsUpdateConfiguration()
    }

    func setLoading(_ loading: Bool) {
        self.loading = loading
        isEnabled = !loading
        accessibilityValue = loading ? NSLocalizedString("Loading", comment: "") : nil
        setNeedsUpdateConfiguration()
    }

    func acknowledgeSelection(accentColor: UIColor?) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let color = accentColor ?? PPContextCheckoutColors.action
        layer.borderColor = color.cgColor
        layer.borderWidth = 2
        UIView.animate(withDuration: 0.18, animations: {
            self.layer.borderColor = UIColor.clear.cgColor
        }, completion: { _ in
            self.layer.borderWidth = 0
        })
    }
}

// MARK: - Context-aware dock

@objc(PPContextAwareCheckoutView)
@objcMembers
public final class PPContextAwareCheckoutView: UIView, UITableViewDataSource, UITableViewDelegate {
    public var itemsTotal: CGFloat = 0
    public var shippingFee: CGFloat = 0
    public private(set) var subtotal: CGFloat = 0

    /// Compatibility with PPPremuimChekoutView host code. Context decides actual visibility.
    public var showDetails: Bool = true
    /// Compatibility with PPPremuimChekoutView host code. Payment review is always reachable.
    public var showsItemsPreview: Bool = false

    public var onTapCheckOut: (() -> Void)?

    public var presentationMode: PPContextAwareCheckoutMode = .cart {
        didSet {
            guard oldValue != presentationMode else {
                applyPresentationChrome()
                refreshColors()
                updateContextVisibility(animated: false)
                return
            }
            reviewExpanded = false
            lastAdaptiveLayoutWidth = 0
            applyPresentationChrome()
            refreshColors()
            if presentationMode == .payment && needsHiddenTableReload {
                needsHiddenTableReload = false
                itemsTable.reloadData()
                updateTableHeight()
            }
            updateContextVisibility(animated: window != nil)
        }
    }

    private let surfaceView = UIView()
    private let surfaceBackdropClipView = UIView()
    private let dockedBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let dockedTintOverlay = UIView()
    private let dockedTopRimLayer = CAShapeLayer()
    private let contentStack = UIStackView()
    private let reviewControl = PPContextCheckoutReviewControl()
    private let itemsContainer = UIView()
    private let itemsTable = UITableView(frame: .zero, style: .plain)
    private let reviewHintRow = UIStackView()
    private let reviewHintIcon = UIImageView(image: UIImage(systemName: "list.bullet.rectangle"))
    private let reviewHintLabel = UILabel()
    private let pricingBreakdownStack = UIStackView()
    private let deliveryPricingRow = PPContextCheckoutPricingRow(emphasized: false)
    private let pricingDivider = UIView()
    private let itemsPricingRow = PPContextCheckoutPricingRow(emphasized: true)
    private let decisionPanel = UIView()
    private let decisionStack = UIStackView()
    private let totalStack = UIStackView()
    private let totalCaptionLabel = UILabel()
    private let totalLabel = UILabel()
    private let actionButton = PPContextCheckoutActionButton()

    private var surfaceTopConstraint: NSLayoutConstraint?
    private var surfaceLeadingConstraint: NSLayoutConstraint?
    private var surfaceTrailingConstraint: NSLayoutConstraint?
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var decisionTopConstraint: NSLayoutConstraint?
    private var decisionLeadingConstraint: NSLayoutConstraint?
    private var decisionTrailingConstraint: NSLayoutConstraint?
    private var decisionBottomConstraint: NSLayoutConstraint?
    private var itemsTableHeightConstraint: NSLayoutConstraint?
    private var actionMinimumWidthConstraint: NSLayoutConstraint?
    private var actionMaximumWidthConstraint: NSLayoutConstraint?
    private var checkoutItems: [CartItem] = []
    private var totalItemQuantity = 0
    private var reviewExpanded = false
    private var checkoutLoading = false
    private var checkoutTapGate = false
    private var checkoutTitle = NSLocalizedString("Checkout", comment: "")
    private var checkoutImage: UIImage?
    private var usesDefaultCheckoutTitle = true
    private var usesAutomaticCheckoutImage = true
    private var stateAnimator: UIViewPropertyAnimator?
    private var lastAdaptiveLayoutWidth: CGFloat = 0
    private var lastAdaptiveContentSizeCategory: UIContentSizeCategory?
    private var lastAdaptiveTotalText: String?
    private var needsHiddenTableReload = false

    private var isDockedCartStyle: Bool {
        presentationMode == .cart
    }

    @objc public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        stateAnimator?.stopAnimation(true)
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        clipsToBounds = false
        shouldGroupAccessibilityChildren = true
        accessibilityIdentifier = "contextCheckout"

        buildHierarchy()
        buildLayout()
        installObservers()
        applyLanguage()
        applyPresentationChrome()
        refreshColors()
        updateTotalsWithItems(0, shipping: 0, showTitle: false)
        updatePreviewItems(nil)
        setCheckoutBTNTitle(nil, image: nil)
        updateContextVisibility(animated: false)
    }

    private func buildHierarchy() {
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.layer.cornerRadius = PPContextCheckoutMetrics.surfaceRadius
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.layer.masksToBounds = false
        addSubview(surfaceView)

        surfaceBackdropClipView.translatesAutoresizingMaskIntoConstraints = false
        surfaceBackdropClipView.backgroundColor = .clear
        surfaceBackdropClipView.isUserInteractionEnabled = false
        surfaceBackdropClipView.layer.cornerCurve = .continuous
        surfaceBackdropClipView.layer.masksToBounds = true
        surfaceView.addSubview(surfaceBackdropClipView)

        dockedBlurView.translatesAutoresizingMaskIntoConstraints = false
        dockedBlurView.isUserInteractionEnabled = false
        surfaceBackdropClipView.addSubview(dockedBlurView)

        dockedTintOverlay.translatesAutoresizingMaskIntoConstraints = false
        dockedTintOverlay.isUserInteractionEnabled = false
        surfaceBackdropClipView.addSubview(dockedTintOverlay)

        dockedTopRimLayer.fillColor = nil
        dockedTopRimLayer.lineCap = .round
        surfaceBackdropClipView.layer.addSublayer(dockedTopRimLayer)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = PPContextCheckoutMetrics.floatingContentSpacing
        surfaceView.addSubview(contentStack)

        reviewControl.addTarget(self, action: #selector(didTapReviewOrder), for: .touchUpInside)

        itemsContainer.translatesAutoresizingMaskIntoConstraints = false
        itemsContainer.layer.cornerRadius = PPContextCheckoutMetrics.panelRadius
        itemsContainer.layer.cornerCurve = .continuous
        itemsContainer.layer.masksToBounds = true

        itemsTable.translatesAutoresizingMaskIntoConstraints = false
        itemsTable.backgroundColor = .clear
        itemsTable.separatorStyle = .singleLine
        itemsTable.separatorInset = UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 8)
        itemsTable.rowHeight = PPContextCheckoutMetrics.itemRowHeight
        itemsTable.estimatedRowHeight = PPContextCheckoutMetrics.itemRowHeight
        itemsTable.dataSource = self
        itemsTable.delegate = self
        itemsTable.showsVerticalScrollIndicator = true
        itemsTable.alwaysBounceVertical = false
        itemsTable.register(PPContextCheckoutItemCell.self, forCellReuseIdentifier: PPContextCheckoutItemCell.reuseIdentifier)
        itemsContainer.addSubview(itemsTable)

        reviewHintRow.translatesAutoresizingMaskIntoConstraints = false
        reviewHintRow.axis = .horizontal
        reviewHintRow.alignment = .center
        reviewHintRow.spacing = 6

        reviewHintIcon.translatesAutoresizingMaskIntoConstraints = false
        reviewHintIcon.contentMode = .scaleAspectFit
        reviewHintIcon.isAccessibilityElement = false

        reviewHintLabel.font = PPContextCheckoutFont.bold(10, style: .caption1)
        reviewHintLabel.adjustsFontForContentSizeCategory = true
        reviewHintLabel.numberOfLines = 1
        reviewHintLabel.isAccessibilityElement = false

        reviewHintRow.addArrangedSubview(reviewHintIcon)
        reviewHintRow.addArrangedSubview(reviewHintLabel)
        itemsContainer.addSubview(reviewHintRow)

        pricingBreakdownStack.translatesAutoresizingMaskIntoConstraints = false
        pricingBreakdownStack.axis = .vertical
        pricingBreakdownStack.alignment = .fill
        pricingBreakdownStack.spacing = PPContextCheckoutMetrics.breakdownVerticalSpacing
        pricingBreakdownStack.accessibilityIdentifier = "contextCheckout.expandedPricing"

        pricingDivider.translatesAutoresizingMaskIntoConstraints = false
        pricingDivider.isAccessibilityElement = false

        deliveryPricingRow.accessibilityIdentifier = "contextCheckout.delivery"
        itemsPricingRow.accessibilityIdentifier = "contextCheckout.itemsBreakdown"

        // The bill stays visible in Cart and Checkout; item disclosure only hides items.
        pricingBreakdownStack.addArrangedSubview(itemsPricingRow)
        pricingBreakdownStack.addArrangedSubview(deliveryPricingRow)
        pricingBreakdownStack.addArrangedSubview(pricingDivider)
        pricingBreakdownStack.isLayoutMarginsRelativeArrangement = true
        pricingBreakdownStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 4, leading: PPContextCheckoutMetrics.breakdownHorizontalInset,
            bottom: 4, trailing: PPContextCheckoutMetrics.breakdownHorizontalInset
        )

        decisionPanel.translatesAutoresizingMaskIntoConstraints = false
        decisionPanel.layer.cornerRadius = PPContextCheckoutMetrics.panelRadius
        decisionPanel.layer.cornerCurve = .continuous
        decisionPanel.layer.masksToBounds = true

        decisionStack.translatesAutoresizingMaskIntoConstraints = false
        decisionStack.axis = .horizontal
        decisionStack.alignment = .center
        decisionStack.distribution = .fill
        decisionStack.spacing = PPContextCheckoutMetrics.decisionContentSpacing
        decisionPanel.addSubview(decisionStack)

        totalStack.axis = .vertical
        totalStack.alignment = .fill
        totalStack.spacing = 1
        totalStack.isLayoutMarginsRelativeArrangement = true
        totalStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        totalStack.isAccessibilityElement = true
        totalStack.accessibilityIdentifier = "contextCheckout.total"
        totalStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        totalCaptionLabel.font = PPContextCheckoutFont.medium(12, style: .caption1)
        totalCaptionLabel.adjustsFontForContentSizeCategory = true
        totalCaptionLabel.numberOfLines = 1
        totalCaptionLabel.isAccessibilityElement = false

        totalLabel.font = PPContextCheckoutFont.monospacedBold(25, style: .title2)
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.numberOfLines = 1
        totalLabel.adjustsFontSizeToFitWidth = true
        totalLabel.minimumScaleFactor = 0.78
        totalLabel.semanticContentAttribute = .forceLeftToRight
        totalLabel.isAccessibilityElement = false

        totalStack.addArrangedSubview(totalCaptionLabel)
        totalStack.addArrangedSubview(totalLabel)

        actionButton.addTarget(self, action: #selector(didTapCheckout), for: .touchUpInside)
        actionButton.setContentCompressionResistancePriority(UILayoutPriority(999), for: .horizontal)
        actionButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        decisionStack.addArrangedSubview(totalStack)
        decisionStack.addArrangedSubview(actionButton)

        contentStack.addArrangedSubview(reviewControl)
        contentStack.addArrangedSubview(itemsContainer)
        contentStack.addArrangedSubview(pricingBreakdownStack)
        contentStack.addArrangedSubview(decisionPanel)

        let tableHeight = itemsTable.heightAnchor.constraint(equalToConstant: PPContextCheckoutMetrics.itemRowHeight)
        itemsTableHeightConstraint = tableHeight

        let dTop = decisionStack.topAnchor.constraint(
            equalTo: decisionPanel.topAnchor,
            constant: PPContextCheckoutMetrics.decisionVerticalInset
        )
        let dLeading = decisionStack.leadingAnchor.constraint(
            equalTo: decisionPanel.leadingAnchor,
            constant: PPContextCheckoutMetrics.decisionHorizontalInset
        )
        let dTrailing = decisionStack.trailingAnchor.constraint(
            equalTo: decisionPanel.trailingAnchor,
            constant: -PPContextCheckoutMetrics.decisionHorizontalInset
        )
        let dBottom = decisionStack.bottomAnchor.constraint(
            equalTo: decisionPanel.bottomAnchor,
            constant: -PPContextCheckoutMetrics.decisionVerticalInset
        )
        decisionTopConstraint = dTop
        decisionLeadingConstraint = dLeading
        decisionTrailingConstraint = dTrailing
        decisionBottomConstraint = dBottom

        NSLayoutConstraint.activate([
            itemsTable.topAnchor.constraint(equalTo: itemsContainer.topAnchor, constant: 4),
            itemsTable.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor, constant: 4),
            itemsTable.trailingAnchor.constraint(equalTo: itemsContainer.trailingAnchor, constant: -4),
            tableHeight,

            pricingDivider.heightAnchor.constraint(equalToConstant: PPContextCheckoutMetrics.hairline),
            reviewHintRow.topAnchor.constraint(
                equalTo: itemsTable.bottomAnchor,
                constant: PPContextCheckoutMetrics.breakdownVerticalSpacing
            ),
            reviewHintRow.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor, constant: 12),
            reviewHintRow.trailingAnchor.constraint(lessThanOrEqualTo: itemsContainer.trailingAnchor, constant: -12),
            reviewHintRow.bottomAnchor.constraint(equalTo: itemsContainer.bottomAnchor, constant: -8),
            reviewHintIcon.widthAnchor.constraint(equalToConstant: 13),
            reviewHintIcon.heightAnchor.constraint(equalToConstant: 13),

            dTop,
            dLeading,
            dTrailing,
            dBottom,
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: PPContextCheckoutMetrics.actionHeight)
        ])
        actionMinimumWidthConstraint = actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 178)
        actionMaximumWidthConstraint = actionButton.widthAnchor.constraint(lessThanOrEqualToConstant: 226)
        actionMinimumWidthConstraint?.isActive = true
        actionMaximumWidthConstraint?.isActive = true
    }

    private func buildLayout() {
        let sTop = surfaceView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
        let sLeading = surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0)
        let sTrailing = surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0)
        surfaceTopConstraint = sTop
        surfaceLeadingConstraint = sLeading
        surfaceTrailingConstraint = sTrailing

        let cTop = contentStack.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: PPContextCheckoutMetrics.dockedTopInset)
        let cLeading = contentStack.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: PPContextCheckoutMetrics.dockedHorizontalInset)
        let cTrailing = contentStack.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -PPContextCheckoutMetrics.dockedHorizontalInset)
        let cBottom = contentStack.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -effectiveBottomContentInset())
        contentTopConstraint = cTop
        contentLeadingConstraint = cLeading
        contentTrailingConstraint = cTrailing
        contentBottomConstraint = cBottom

        NSLayoutConstraint.activate([
            sTop,
            sLeading,
            sTrailing,
            surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),

            surfaceBackdropClipView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            surfaceBackdropClipView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            surfaceBackdropClipView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            surfaceBackdropClipView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),

            dockedBlurView.topAnchor.constraint(equalTo: surfaceBackdropClipView.topAnchor),
            dockedBlurView.leadingAnchor.constraint(equalTo: surfaceBackdropClipView.leadingAnchor),
            dockedBlurView.trailingAnchor.constraint(equalTo: surfaceBackdropClipView.trailingAnchor),
            dockedBlurView.bottomAnchor.constraint(equalTo: surfaceBackdropClipView.bottomAnchor),

            dockedTintOverlay.topAnchor.constraint(equalTo: surfaceBackdropClipView.topAnchor),
            dockedTintOverlay.leadingAnchor.constraint(equalTo: surfaceBackdropClipView.leadingAnchor),
            dockedTintOverlay.trailingAnchor.constraint(equalTo: surfaceBackdropClipView.trailingAnchor),
            dockedTintOverlay.bottomAnchor.constraint(equalTo: surfaceBackdropClipView.bottomAnchor),

            cTop,
            cLeading,
            cTrailing,
            cBottom
        ])
    }

    private func installObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(languageDidChange), name: Notification.Name("LanguageDidChangeNotification"), object: nil)
        center.addObserver(self, selector: #selector(languageDidChange), name: Notification.Name("PPLanguageDidChangeNotification"), object: nil)
        center.addObserver(self, selector: #selector(appearanceDidChange), name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(appearanceDidChange), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(reduceMotionDidChange), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    private func effectiveBottomContentInset() -> CGFloat {
        guard isDockedCartStyle else { return 7 }
        return max(
            safeAreaInsets.bottom + PPContextCheckoutMetrics.dockedSafeAreaBreathingRoom,
            PPContextCheckoutMetrics.dockedBottomPaddingMinimum
        )
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        guard isDockedCartStyle else { return }
        contentBottomConstraint?.constant = -effectiveBottomContentInset()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    // MARK: Sizing

    public override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight(for: width))
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let width = targetSize.width > 1 ? targetSize.width : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: measuredHeight(for: width))
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let width = targetSize.width > 1 ? targetSize.width : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: width, height: measuredHeight(for: width))
    }

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        let surfaceHorizontalInset = isDockedCartStyle ? 0 : (PPContextCheckoutMetrics.outerInset * 2)
        let contentHorizontalInset = isDockedCartStyle
            ? (PPContextCheckoutMetrics.dockedHorizontalInset * 2)
            : 14
        let surfaceTopInset: CGFloat = isDockedCartStyle ? 0 : 4
        let contentTopInset = isDockedCartStyle ? PPContextCheckoutMetrics.dockedTopInset : 7
        let contentBottomInset = effectiveBottomContentInset()

        let contentWidth = max(width - surfaceHorizontalInset - contentHorizontalInset, 1)
        let size = contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(surfaceTopInset + contentTopInset + size.height + contentBottomInset)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
        updateDockedTopRimPath()
        updateAdaptiveDecisionLayout()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            super.traitCollectionDidChange(previousTraitCollection)
        }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshColors()
        }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateTableHeight()
            updateAdaptiveDecisionLayout()
            invalidateIntrinsicContentSize()
        }
    }

    private func updateAdaptiveDecisionLayout() {
        // During destination construction this view has no resolved width yet.
        guard bounds.width.isFinite, bounds.width > 1 else { return }
        let currentCategory = traitCollection.preferredContentSizeCategory
        let currentTotalText = totalLabel.text ?? ""
        if abs(bounds.width - lastAdaptiveLayoutWidth) <= 0.5,
           lastAdaptiveContentSizeCategory == currentCategory,
           lastAdaptiveTotalText == currentTotalText {
            return
        }
        lastAdaptiveLayoutWidth = bounds.width
        lastAdaptiveContentSizeCategory = currentCategory
        lastAdaptiveTotalText = currentTotalText

        let accessibility = currentCategory.isAccessibilityCategory
        let availableWidth: CGFloat
        if isDockedCartStyle {
            availableWidth = max(0, bounds.width - PPContextCheckoutMetrics.dockedHorizontalInset * 2)
        } else {
            availableWidth = max(0, bounds.width - PPContextCheckoutMetrics.outerInset * 2 - 14
                                     - PPContextCheckoutMetrics.decisionHorizontalInset * 2)
        }
        // Measure the unwrapped text, not the label's current wrapped geometry.
        // Otherwise changing the axis can change the next axis decision itself.
        let totalText = totalLabel.attributedText ?? NSAttributedString(
            string: currentTotalText,
            attributes: [.font: totalLabel.font ?? UIFont.preferredFont(forTextStyle: .title2)]
        )
        let requiredWidth = ceil(totalText.size().width) + 178 + PPContextCheckoutMetrics.decisionContentSpacing + 8
        let shouldStack = accessibility || bounds.width < 350 || requiredWidth > availableWidth
        let nextAxis: NSLayoutConstraint.Axis = shouldStack ? .vertical : .horizontal
        guard decisionStack.axis != nextAxis else { return }
        actionMinimumWidthConstraint?.isActive = false
        actionMaximumWidthConstraint?.isActive = false
        decisionStack.axis = nextAxis
        decisionStack.alignment = .fill
        totalLabel.numberOfLines = shouldStack ? 0 : 1
        actionMinimumWidthConstraint?.isActive = !shouldStack
        actionMaximumWidthConstraint?.isActive = !shouldStack
        invalidateIntrinsicContentSize()
    }

    private func updateShadowPath() {
        guard !surfaceView.bounds.isEmpty else { return }
        let radius = isDockedCartStyle
            ? PPContextCheckoutMetrics.dockedSurfaceRadius
            : PPContextCheckoutMetrics.surfaceRadius
        let corners: UIRectCorner = isDockedCartStyle ? [.topLeft, .topRight] : .allCorners
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath
    }

    private func updateDockedTopRimPath() {
        guard isDockedCartStyle, !surfaceBackdropClipView.bounds.isEmpty else {
            dockedTopRimLayer.path = nil
            return
        }
        let w = surfaceBackdropClipView.bounds.width
        let h = surfaceBackdropClipView.bounds.height
        let r = min(PPContextCheckoutMetrics.dockedSurfaceRadius, w * 0.5, h * 0.5)
        let lineWidth = PPContextCheckoutMetrics.hairline
        let inset = lineWidth * 0.5

        let path = UIBezierPath()
        path.move(to: CGPoint(x: inset, y: r))
        path.addArc(
            withCenter: CGPoint(x: r, y: r),
            radius: max(r - inset, 0),
            startAngle: .pi,
            endAngle: -.pi * 0.5,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: max(w - r, r), y: inset))
        path.addArc(
            withCenter: CGPoint(x: w - r, y: r),
            radius: max(r - inset, 0),
            startAngle: -.pi * 0.5,
            endAngle: 0,
            clockwise: true
        )

        dockedTopRimLayer.frame = surfaceBackdropClipView.bounds
        dockedTopRimLayer.lineWidth = lineWidth
        dockedTopRimLayer.path = path.cgPath
    }

    private func applyPresentationChrome() {
        let docked = isDockedCartStyle
        surfaceTopConstraint?.constant = docked ? 0 : 4
        surfaceLeadingConstraint?.constant = docked ? 0 : PPContextCheckoutMetrics.outerInset
        surfaceTrailingConstraint?.constant = docked ? 0 : -PPContextCheckoutMetrics.outerInset

        contentStack.spacing = docked
            ? PPContextCheckoutMetrics.dockedContentSpacing
            : PPContextCheckoutMetrics.floatingContentSpacing
        contentTopConstraint?.constant = docked ? PPContextCheckoutMetrics.dockedTopInset : 7
        contentLeadingConstraint?.constant = docked ? PPContextCheckoutMetrics.dockedHorizontalInset : 7
        contentTrailingConstraint?.constant = docked ? -PPContextCheckoutMetrics.dockedHorizontalInset : -7
        contentBottomConstraint?.constant = -effectiveBottomContentInset()

        pricingBreakdownStack.directionalLayoutMargins = docked
            ? NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 2)
            : NSDirectionalEdgeInsets(
                top: 4, leading: PPContextCheckoutMetrics.breakdownHorizontalInset,
                bottom: 4, trailing: PPContextCheckoutMetrics.breakdownHorizontalInset
            )

        decisionTopConstraint?.constant = docked
            ? PPContextCheckoutMetrics.dockedDecisionVerticalInset
            : PPContextCheckoutMetrics.decisionVerticalInset
        decisionLeadingConstraint?.constant = docked ? 0 : PPContextCheckoutMetrics.decisionHorizontalInset
        decisionTrailingConstraint?.constant = docked ? 0 : -PPContextCheckoutMetrics.decisionHorizontalInset
        decisionBottomConstraint?.constant = docked ? 0 : -PPContextCheckoutMetrics.decisionVerticalInset

        let radius = docked
            ? PPContextCheckoutMetrics.dockedSurfaceRadius
            : PPContextCheckoutMetrics.surfaceRadius
        let maskedCorners: CACornerMask = docked
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        surfaceView.layer.cornerRadius = radius
        surfaceView.layer.maskedCorners = maskedCorners
        surfaceBackdropClipView.isHidden = !docked
        surfaceBackdropClipView.layer.cornerRadius = radius
        surfaceBackdropClipView.layer.maskedCorners = maskedCorners
        dockedTopRimLayer.isHidden = !docked

        decisionPanel.layer.cornerRadius = docked ? 0 : PPContextCheckoutMetrics.panelRadius
        decisionPanel.layer.masksToBounds = !docked
        invalidateIntrinsicContentSize()
    }

    // MARK: Public host contract

    @nonobjc
    public func setPresentationMode(_ mode: PPContextAwareCheckoutMode) {
        presentationMode = mode
    }

    @objc(updateTotalsWithItems:shipping:showTitle:)
    public func updateTotalsWithItems(_ itemsTotal: CGFloat, shipping shippingFee: CGFloat, showTitle _: Bool) {
        self.itemsTotal = itemsTotal
        self.shippingFee = shippingFee
        subtotal = itemsTotal + shippingFee
        let formatted = PPContextCheckoutCurrency.format(subtotal)
        totalLabel.text = formatted
        totalStack.accessibilityValue = formatted
        updatePricingBreakdown()
        invalidateIntrinsicContentSize()
    }

    @objc(updatePreviewItems:)
    public func updatePreviewItems(_ items: [CartItem]?) {
        checkoutItems = items ?? []
        totalItemQuantity = checkoutItems.reduce(0) { $0 + max($1.quantity, 0) }
        reviewControl.configure(items: checkoutItems, expanded: reviewExpanded)
        if presentationMode == .payment && reviewExpanded {
            needsHiddenTableReload = false
            itemsTable.reloadData()
            updateTableHeight()
        } else {
            needsHiddenTableReload = true
        }
        updateContextVisibility(animated: false)
    }

    @objc(setCheckoutBTNTitle:image:)
    public func setCheckoutBTNTitle(_ title: String?, image: UIImage?) {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            checkoutTitle = title
            usesDefaultCheckoutTitle = false
        } else {
            checkoutTitle = NSLocalizedString("Checkout", comment: "")
            usesDefaultCheckoutTitle = true
        }
        usesAutomaticCheckoutImage = image == nil
        checkoutImage = image ?? automaticActionImage()
        actionButton.configure(title: checkoutTitle, image: checkoutImage)
    }

    @objc(setCheckoutLoading:)
    public func setCheckoutLoading(_ loading: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.setCheckoutLoading(loading) }
            return
        }
        checkoutLoading = loading
        if !loading { checkoutTapGate = false }
        actionButton.setLoading(loading)
    }

    /// Cart hosts already present their localized alert or authentication prompt
    /// for these states. Keep the legacy selectors so their feedback remains
    /// available to VoiceOver without adding a second, competing Cart surface.
    @objc(setCheckoutSurfaceState:title:subtitle:)
    public func setCheckoutSurfaceState(_ rawState: String?, title: String?, subtitle: String?) {
        _ = rawState
        let hint = [title, subtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        actionButton.accessibilityHint = hint.isEmpty ? nil : hint
    }

    @objc(clearCheckoutSurfaceState)
    public func clearCheckoutSurfaceState() {
        actionButton.accessibilityHint = nil
    }

    @objc(setCollapsible:initiallyCollapsed:)
    public func setCollapsible(_ enabled: Bool, initiallyCollapsed collapsed: Bool) {
        // Compatibility selector. Cart is intentionally always compact.
        // Payment review is the only disclosure surface.
        guard presentationMode == .payment, enabled else { return }
        setSummaryCollapsed(collapsed, animated: false)
    }

    @objc(setSummaryCollapsed:animated:)
    public func setSummaryCollapsed(_ collapsed: Bool, animated: Bool) {
        guard presentationMode == .payment else { return }
        setReviewExpanded(!collapsed, animated: animated)
    }

    @objc(skipCardEntranceAnimation)
    public func skipCardEntranceAnimation() {
        surfaceView.layer.removeAllAnimations()
        surfaceView.alpha = 1
        surfaceView.transform = .identity
    }

    @objc(pp_startTrustBannerShimmer)
    public func pp_startTrustBannerShimmer() {
        // Legacy selector retained for callers. This dock must not imply that
        // payment protection has been confirmed before checkout preflight.
        refreshColors()
    }

    @objc(pp_stopTrustBannerShimmer)
    public func pp_stopTrustBannerShimmer() {
        refreshColors()
    }

    @objc(triggerPaymentMethodChangeFeedbackWithAccent:)
    public func triggerPaymentMethodChangeFeedback(accentColor: UIColor?) {
        actionButton.acknowledgeSelection(accentColor: accentColor)
    }

    @objc(triggerPaymentMethodChangeFeedback)
    public func triggerPaymentMethodChangeFeedback() {
        triggerPaymentMethodChangeFeedback(accentColor: nil)
    }

    // MARK: Presentation

    private func updateContextVisibility(animated: Bool) {
        let payment = presentationMode == .payment
        let hasItems = !checkoutItems.isEmpty
        let showReviewControl = payment && hasItems
        let showItems = showReviewControl && reviewExpanded

        reviewControl.configure(items: checkoutItems, expanded: reviewExpanded)
        let visibilityChanged =
            reviewControl.isHidden != !showReviewControl ||
            pricingBreakdownStack.isHidden != !hasItems ||
            itemsContainer.isHidden != !showItems

        guard visibilityChanged else {
            return
        }

        let changes = {
            self.reviewControl.isHidden = !showReviewControl
            self.reviewControl.accessibilityElementsHidden = !showReviewControl
            self.pricingBreakdownStack.isHidden = !hasItems
            self.itemsContainer.isHidden = !showItems
            self.itemsContainer.accessibilityElementsHidden = !showItems
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
            self.superview?.setNeedsLayout()
        }

        stateAnimator?.stopAnimation(true)
        stateAnimator = nil

        guard animated,
              window != nil,
              !bounds.isEmpty,
              UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }

        let layoutRoot = superview ?? self
        let animator = UIViewPropertyAnimator(
            duration: PPContextCheckoutMetrics.animationDuration,
            curve: .easeOut,
            animations: {
                changes()
                layoutRoot.layoutIfNeeded()
            }
        )
        animator.addCompletion { [weak self] _ in
            self?.stateAnimator = nil
            self?.invalidateIntrinsicContentSize()
            self?.superview?.setNeedsLayout()
        }
        stateAnimator = animator
        animator.startAnimation()
    }

    private func setReviewExpanded(_ expanded: Bool, animated: Bool) {
        guard presentationMode == .payment, !checkoutItems.isEmpty, reviewExpanded != expanded else { return }
        reviewExpanded = expanded
        if expanded && needsHiddenTableReload {
            needsHiddenTableReload = false
            itemsTable.reloadData()
            updateTableHeight()
        }
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
        updateContextVisibility(animated: animated)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: expanded ? itemsTable : reviewControl)
        }
    }

    private func updateTableHeight() {
        let isAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let maximumRows = isAccessibilityLayout
            ? PPContextCheckoutMetrics.maxAccessibilityVisibleRows
            : PPContextCheckoutMetrics.maxVisibleRows
        let visibleRows = min(max(checkoutItems.count, 1), maximumRows)
        let accessibilityMultiplier: CGFloat = isAccessibilityLayout ? 1.35 : 1
        let rowHeight = PPContextCheckoutMetrics.itemRowHeight * accessibilityMultiplier
        itemsTable.rowHeight = rowHeight
        itemsTableHeightConstraint?.constant = CGFloat(visibleRows) * rowHeight
        itemsTable.isScrollEnabled = checkoutItems.count > maximumRows
        invalidateIntrinsicContentSize()
    }

    private func updatePricingBreakdown() {
        deliveryPricingRow.configure(
            title: NSLocalizedString("checkout_summary_delivery_label", comment: ""),
            amount: PPContextCheckoutCurrency.format(shippingFee)
        )
        itemsPricingRow.configure(
            title: NSLocalizedString("checkout_summary_items_label", comment: ""),
            amount: PPContextCheckoutCurrency.format(itemsTotal)
        )
    }

    // MARK: Language / appearance

    private func applyLanguage() {
        let semantic = ppContextSemantic()
        semanticContentAttribute = semantic
        surfaceView.semanticContentAttribute = semantic
        contentStack.semanticContentAttribute = semantic
        decisionPanel.semanticContentAttribute = semantic
        decisionStack.semanticContentAttribute = semantic
        totalStack.semanticContentAttribute = semantic
        reviewHintRow.semanticContentAttribute = semantic
        itemsTable.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic

        totalCaptionLabel.text = PPContextCheckoutCopy.total
        totalCaptionLabel.textAlignment = ppContextAlignment()
        totalLabel.textAlignment = ppContextAlignment()
        reviewHintLabel.text = PPContextCheckoutCopy.reviewPayment
        reviewHintLabel.textAlignment = ppContextAlignment()
        totalStack.accessibilityLabel = PPContextCheckoutCopy.total
        pricingBreakdownStack.semanticContentAttribute = semantic
        deliveryPricingRow.applyLanguage()
        itemsPricingRow.applyLanguage()
        updatePricingBreakdown()

        if usesDefaultCheckoutTitle {
            checkoutTitle = presentationMode == .payment
                ? NSLocalizedString("payment_pay_now", comment: "")
                : NSLocalizedString("Checkout", comment: "")
        }
        if usesAutomaticCheckoutImage {
            checkoutImage = automaticActionImage()
        }
        actionButton.configure(title: checkoutTitle, image: checkoutImage)
        reviewControl.configure(items: checkoutItems, expanded: reviewExpanded)
        itemsTable.visibleCells.forEach { ($0 as? PPContextCheckoutItemCell)?.refreshLanguage() }
    }

    private func automaticActionImage() -> UIImage? {
        if presentationMode == .payment {
            return UIImage(systemName: "creditcard.fill")
        }
        return UIImage(systemName: ppContextIsRTL() ? "arrow.left" : "arrow.right")
    }

    private func refreshColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        let darkerColors = UIAccessibility.isDarkerSystemColorsEnabled

        if isDockedCartStyle {
            surfaceView.backgroundColor = .clear
            surfaceView.layer.borderWidth = 0
            surfaceView.layer.shadowColor = UIColor.black.cgColor
            surfaceView.layer.shadowOpacity = isDark ? 0.24 : 0.06
            surfaceView.layer.shadowRadius = 22
            surfaceView.layer.shadowOffset = CGSize(width: 0, height: -8)

            dockedBlurView.isHidden = reduceTransparency
            dockedTintOverlay.backgroundColor = reduceTransparency
                ? PPContextCheckoutColors.surface
                : PPContextCheckoutColors.surface.withAlphaComponent(isDark ? 0.88 : 0.84)
            let rimColor: UIColor = darkerColors
                ? PPContextCheckoutColors.border
                : (isDark
                    ? UIColor.white.withAlphaComponent(0.14)
                    : UIColor.white.withAlphaComponent(0.86))
            dockedTopRimLayer.strokeColor = rimColor.cgColor

            decisionPanel.backgroundColor = .clear
            decisionPanel.layer.borderWidth = 0
        } else {
            surfaceView.backgroundColor = PPContextCheckoutColors.surface
            surfaceView.layer.borderColor = PPContextCheckoutColors.border.cgColor
            surfaceView.layer.borderWidth = PPContextCheckoutMetrics.hairline
            surfaceView.layer.shadowColor = UIColor.black.cgColor
            surfaceView.layer.shadowOpacity = isDark ? 0.16 : 0.07
            surfaceView.layer.shadowRadius = 18
            surfaceView.layer.shadowOffset = CGSize(width: 0, height: 6)

            decisionPanel.backgroundColor = PPContextCheckoutColors.quietSurface
            decisionPanel.layer.borderColor = PPContextCheckoutColors.border.cgColor
            decisionPanel.layer.borderWidth = darkerColors
                ? PPContextCheckoutMetrics.hairline
                : 0
        }

        reviewControl.refreshColors()
        itemsContainer.backgroundColor = PPContextCheckoutColors.secondarySurface
        itemsContainer.layer.borderColor = PPContextCheckoutColors.border.cgColor
        itemsContainer.layer.borderWidth = PPContextCheckoutMetrics.hairline
        itemsTable.separatorColor = PPContextCheckoutColors.border.withAlphaComponent(0.72)
        itemsTable.visibleCells.forEach { ($0 as? PPContextCheckoutItemCell)?.refreshColors() }

        pricingDivider.backgroundColor = PPContextCheckoutColors.border.withAlphaComponent(isDockedCartStyle ? 0.82 : 1.0)
        deliveryPricingRow.refreshColors()
        itemsPricingRow.refreshColors()

        reviewHintIcon.tintColor = PPContextCheckoutColors.tertiaryText
        reviewHintLabel.textColor = PPContextCheckoutColors.secondaryText

        totalCaptionLabel.textColor = PPContextCheckoutColors.secondaryText
        totalLabel.textColor = PPContextCheckoutColors.primaryText
        actionButton.setNeedsUpdateConfiguration()
        setNeedsLayout()
    }

    // MARK: Actions

    @objc private func didTapReviewOrder() {
        setReviewExpanded(!reviewExpanded, animated: true)
    }

    @objc private func didTapCheckout() {
        guard !checkoutLoading, !checkoutTapGate else { return }
        checkoutTapGate = true
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        feedback.impactOccurred()
        onTapCheckOut?()
        DispatchQueue.main.asyncAfter(deadline: .now() + PPContextCheckoutMetrics.checkoutTapDebounce) { [weak self] in
            guard let self, !self.checkoutLoading else { return }
            self.checkoutTapGate = false
        }
    }

    @objc private func languageDidChange() {
        applyLanguage()
        itemsTable.reloadData()
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    @objc private func appearanceDidChange() {
        refreshColors()
    }

    @objc private func reduceMotionDidChange() {
        stateAnimator?.stopAnimation(true)
        stateAnimator = nil
        updateContextVisibility(animated: false)
    }

    // MARK: UITableViewDataSource

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        checkoutItems.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < checkoutItems.count,
              let cell = tableView.dequeueReusableCell(
                withIdentifier: PPContextCheckoutItemCell.reuseIdentifier,
                for: indexPath
              ) as? PPContextCheckoutItemCell else {
            return UITableViewCell()
        }
        cell.configure(item: checkoutItems[indexPath.row])
        return cell
    }
}
