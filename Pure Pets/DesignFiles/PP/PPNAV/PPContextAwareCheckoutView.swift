//
//  PPContextAwareCheckoutView.swift
//  Pure Pets
//
//  Context-aware checkout dock.
//  Cart: total + CTA only because cart items are already visible above.
//  Payment: compact order-review affordance + expandable live item list + CTA.
//
//  NOTE: PPPremuimChekoutView.swift is intentionally preserved unchanged.
//

import UIKit

@objc public enum PPContextAwareCheckoutMode: Int {
    case cart
    case payment
}

private enum PPContextCheckoutMetrics {
    static let outerInset: CGFloat = 16
    static let bottomBreathingRoom: CGFloat = 10
    static let surfaceRadius: CGFloat = 26
    static let panelRadius: CGFloat = 20
    static let controlRadius: CGFloat = 18
    static let actionHeight: CGFloat = 58
    static let reviewHeight: CGFloat = 62
    static let itemRowHeight: CGFloat = 66
    static let maxVisibleRows = 4
    static let animationDuration: TimeInterval = 0.24
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
    static var success: UIColor { .ppSuccess }
}

private enum PPContextCheckoutFont {
    static func medium(_ size: CGFloat, style: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Medium", size: size, weight: .medium, style: style)
    }

    static func bold(_ size: CGFloat, style: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Bold", size: size, weight: .bold, style: style)
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
    static var reviewOrder: String {
        ppContextIsRTL() ? "راجع طلبك" : "Review order"
    }

    static func reviewMeta(count: Int) -> String {
        let resolved = max(count, 0)
        return ppContextIsRTL()
            ? "\(resolved) عناصر · اضغط لعرض التفاصيل"
            : "\(resolved) items · Tap to view details"
    }

    static var securePayment: String {
        ppContextIsRTL() ? "دفع محمي وآمن" : "Protected & secure payment"
    }

    static var total: String {
        ppContextIsRTL() ? "الإجمالي" : "Total"
    }

    static var quantity: String {
        ppContextIsRTL() ? "الكمية" : "Qty"
    }

    static var fallbackItem: String {
        ppContextIsRTL() ? "منتج من PurePets" : "PurePets item"
    }

    static var expandHint: String {
        ppContextIsRTL() ? "اضغط لعرض عناصر الطلب" : "Tap to show order items"
    }

    static var collapseHint: String {
        ppContextIsRTL() ? "اضغط لإخفاء عناصر الطلب" : "Tap to hide order items"
    }
}

private enum PPContextCheckoutCurrency {
    static func format(_ value: CGFloat) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_QA")
        formatter.currencyCode = "QAR"
        formatter.currencySymbol = NSLocalizedString("Rials", comment: "")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
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

// MARK: - Action button

private final class PPContextCheckoutActionButton: UIButton {
    private var visibleTitle = ""
    private var visibleImage: UIImage?
    private var loading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "contextCheckout.primaryAction"
        layer.cornerCurve = .continuous
        configuration = .filled()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "contextCheckout.primaryAction"
        layer.cornerCurve = .continuous
        configuration = .filled()
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
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 13, bottom: 9, trailing: 13)
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

    public private(set) var presentationMode: PPContextAwareCheckoutMode = .cart

    private let surfaceView = UIView()
    private let contentStack = UIStackView()
    private let reviewControl = PPContextCheckoutReviewControl()
    private let itemsContainer = UIView()
    private let itemsTable = UITableView(frame: .zero, style: .plain)
    private let secureRow = UIStackView()
    private let secureIcon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
    private let secureLabel = UILabel()
    private let decisionPanel = UIView()
    private let decisionStack = UIStackView()
    private let totalStack = UIStackView()
    private let totalCaptionLabel = UILabel()
    private let totalLabel = UILabel()
    private let actionButton = PPContextCheckoutActionButton()

    private var itemsTableHeightConstraint: NSLayoutConstraint?
    private var checkoutItems: [CartItem] = []
    private var totalItemQuantity = 0
    private var reviewExpanded = false
    private var checkoutLoading = false
    private var checkoutTapGate = false
    private var checkoutTitle = NSLocalizedString("Checkout", comment: "")
    private var checkoutImage: UIImage?
    private var usesDefaultCheckoutTitle = true
    private var usesAutomaticCheckoutImage = true
    private var protectedStateIsActive = false
    private var stateAnimator: UIViewPropertyAnimator?

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

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 7
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

        secureRow.translatesAutoresizingMaskIntoConstraints = false
        secureRow.axis = .horizontal
        secureRow.alignment = .center
        secureRow.spacing = 6

        secureIcon.translatesAutoresizingMaskIntoConstraints = false
        secureIcon.contentMode = .scaleAspectFit
        secureIcon.isAccessibilityElement = false

        secureLabel.font = PPContextCheckoutFont.bold(10, style: .caption1)
        secureLabel.adjustsFontForContentSizeCategory = true
        secureLabel.numberOfLines = 1
        secureLabel.isAccessibilityElement = false

        secureRow.addArrangedSubview(secureIcon)
        secureRow.addArrangedSubview(secureLabel)
        itemsContainer.addSubview(secureRow)

        decisionPanel.translatesAutoresizingMaskIntoConstraints = false
        decisionPanel.layer.cornerRadius = PPContextCheckoutMetrics.panelRadius
        decisionPanel.layer.cornerCurve = .continuous
        decisionPanel.layer.masksToBounds = true

        decisionStack.translatesAutoresizingMaskIntoConstraints = false
        decisionStack.axis = .horizontal
        decisionStack.alignment = .center
        decisionStack.distribution = .fill
        decisionStack.spacing = 8
        decisionPanel.addSubview(decisionStack)

        totalStack.axis = .vertical
        totalStack.alignment = .fill
        totalStack.spacing = 0
        totalStack.isAccessibilityElement = true
        totalStack.accessibilityIdentifier = "contextCheckout.total"
        totalStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        totalCaptionLabel.font = PPContextCheckoutFont.medium(11, style: .caption1)
        totalCaptionLabel.adjustsFontForContentSizeCategory = true
        totalCaptionLabel.numberOfLines = 1
        totalCaptionLabel.isAccessibilityElement = false

        totalLabel.font = PPContextCheckoutFont.bold(22, style: .title2)
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
        contentStack.addArrangedSubview(decisionPanel)

        let tableHeight = itemsTable.heightAnchor.constraint(equalToConstant: PPContextCheckoutMetrics.itemRowHeight)
        itemsTableHeightConstraint = tableHeight

        NSLayoutConstraint.activate([
            itemsTable.topAnchor.constraint(equalTo: itemsContainer.topAnchor, constant: 4),
            itemsTable.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor, constant: 4),
            itemsTable.trailingAnchor.constraint(equalTo: itemsContainer.trailingAnchor, constant: -4),
            tableHeight,

            secureRow.topAnchor.constraint(equalTo: itemsTable.bottomAnchor, constant: 5),
            secureRow.leadingAnchor.constraint(equalTo: itemsContainer.leadingAnchor, constant: 12),
            secureRow.trailingAnchor.constraint(lessThanOrEqualTo: itemsContainer.trailingAnchor, constant: -12),
            secureRow.bottomAnchor.constraint(equalTo: itemsContainer.bottomAnchor, constant: -8),
            secureIcon.widthAnchor.constraint(equalToConstant: 13),
            secureIcon.heightAnchor.constraint(equalToConstant: 13),

            decisionStack.topAnchor.constraint(equalTo: decisionPanel.topAnchor, constant: 6),
            decisionStack.leadingAnchor.constraint(equalTo: decisionPanel.leadingAnchor, constant: 6),
            decisionStack.trailingAnchor.constraint(equalTo: decisionPanel.trailingAnchor, constant: -6),
            decisionStack.bottomAnchor.constraint(equalTo: decisionPanel.bottomAnchor, constant: -6),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: PPContextCheckoutMetrics.actionHeight),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 178),
            actionButton.widthAnchor.constraint(lessThanOrEqualToConstant: 226)
        ])
    }

    private func buildLayout() {
        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PPContextCheckoutMetrics.outerInset),
            surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PPContextCheckoutMetrics.outerInset),
            surfaceView.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -PPContextCheckoutMetrics.bottomBreathingRoom
            ),

            contentStack.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: 7),
            contentStack.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: 7),
            contentStack.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -7),
            contentStack.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -7)
        ])
    }

    private func installObservers() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(languageDidChange), name: Notification.Name("LanguageDidChangeNotification"), object: nil)
        center.addObserver(self, selector: #selector(languageDidChange), name: Notification.Name("PPLanguageDidChangeNotification"), object: nil)
        center.addObserver(self, selector: #selector(appearanceDidChange), name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(reduceMotionDidChange), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
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
        let contentWidth = max(width - (PPContextCheckoutMetrics.outerInset * 2) - 14, 1)
        let size = contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(4 + 7 + size.height + 7 + safeAreaInsets.bottom + PPContextCheckoutMetrics.bottomBreathingRoom)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateShadowPath()
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
        let accessibility = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let shouldStack = accessibility || bounds.width < 350
        let nextAxis: NSLayoutConstraint.Axis = shouldStack ? .vertical : .horizontal
        guard decisionStack.axis != nextAxis else { return }
        decisionStack.axis = nextAxis
        decisionStack.alignment = .fill
        totalLabel.numberOfLines = shouldStack ? 0 : 1
        invalidateIntrinsicContentSize()
    }

    private func updateShadowPath() {
        guard !surfaceView.bounds.isEmpty else { return }
        surfaceView.layer.shadowPath = UIBezierPath(
            roundedRect: surfaceView.bounds,
            cornerRadius: PPContextCheckoutMetrics.surfaceRadius
        ).cgPath
    }

    // MARK: Public host contract

    @objc(setPresentationMode:)
    public func setPresentationMode(_ mode: PPContextAwareCheckoutMode) {
        guard presentationMode != mode else {
            updateContextVisibility(animated: false)
            return
        }
        presentationMode = mode
        reviewExpanded = false
        updateContextVisibility(animated: window != nil)
    }

    @objc(updateTotalsWithItems:shipping:showTitle:)
    public func updateTotalsWithItems(_ itemsTotal: CGFloat, shipping shippingFee: CGFloat, showTitle _: Bool) {
        self.itemsTotal = itemsTotal
        self.shippingFee = shippingFee
        subtotal = itemsTotal + shippingFee
        let formatted = PPContextCheckoutCurrency.format(subtotal)
        totalLabel.text = formatted
        totalStack.accessibilityValue = formatted
        invalidateIntrinsicContentSize()
    }

    @objc(updatePreviewItems:)
    public func updatePreviewItems(_ items: [CartItem]?) {
        checkoutItems = items ?? []
        totalItemQuantity = checkoutItems.reduce(0) { $0 + max($1.quantity, 0) }
        itemsTable.reloadData()
        reviewControl.configure(items: checkoutItems, expanded: reviewExpanded)
        updateTableHeight()
        updateContextVisibility(animated: window != nil)
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
        protectedStateIsActive = true
        refreshColors()
    }

    @objc(pp_stopTrustBannerShimmer)
    public func pp_stopTrustBannerShimmer() {
        protectedStateIsActive = false
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

        let changes = {
            self.reviewControl.isHidden = !showReviewControl
            self.reviewControl.accessibilityElementsHidden = !showReviewControl
            self.itemsContainer.isHidden = !showItems
            self.itemsContainer.accessibilityElementsHidden = !showItems
            self.reviewControl.configure(items: self.checkoutItems, expanded: self.reviewExpanded)
            self.invalidateIntrinsicContentSize()
            self.superview?.setNeedsLayout()
            self.layoutIfNeeded()
            self.superview?.layoutIfNeeded()
        }

        stateAnimator?.stopAnimation(true)
        stateAnimator = nil

        guard animated,
              window != nil,
              UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }

        let animator = UIViewPropertyAnimator(
            duration: PPContextCheckoutMetrics.animationDuration,
            curve: .easeOut,
            animations: changes
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
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
        updateContextVisibility(animated: animated)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: expanded ? itemsTable : reviewControl)
        }
    }

    private func updateTableHeight() {
        let visibleRows = min(max(checkoutItems.count, 1), PPContextCheckoutMetrics.maxVisibleRows)
        let accessibilityMultiplier: CGFloat = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 1.35 : 1
        let rowHeight = PPContextCheckoutMetrics.itemRowHeight * accessibilityMultiplier
        itemsTable.rowHeight = rowHeight
        itemsTableHeightConstraint?.constant = CGFloat(visibleRows) * rowHeight
        itemsTable.isScrollEnabled = checkoutItems.count > PPContextCheckoutMetrics.maxVisibleRows
        invalidateIntrinsicContentSize()
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
        secureRow.semanticContentAttribute = semantic
        itemsTable.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic

        totalCaptionLabel.text = PPContextCheckoutCopy.total
        totalCaptionLabel.textAlignment = ppContextAlignment()
        totalLabel.textAlignment = ppContextAlignment()
        secureLabel.text = PPContextCheckoutCopy.securePayment
        secureLabel.textAlignment = ppContextAlignment()
        totalStack.accessibilityLabel = PPContextCheckoutCopy.total

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
        surfaceView.backgroundColor = PPContextCheckoutColors.surface
        surfaceView.layer.borderColor = PPContextCheckoutColors.border.cgColor
        surfaceView.layer.borderWidth = PPContextCheckoutMetrics.hairline
        surfaceView.layer.shadowColor = UIColor.black.cgColor
        surfaceView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.16 : 0.07
        surfaceView.layer.shadowRadius = 18
        surfaceView.layer.shadowOffset = CGSize(width: 0, height: 6)

        reviewControl.refreshColors()
        itemsContainer.backgroundColor = PPContextCheckoutColors.secondarySurface
        itemsContainer.layer.borderColor = PPContextCheckoutColors.border.cgColor
        itemsContainer.layer.borderWidth = PPContextCheckoutMetrics.hairline
        itemsTable.separatorColor = PPContextCheckoutColors.border.withAlphaComponent(0.72)
        itemsTable.visibleCells.forEach { ($0 as? PPContextCheckoutItemCell)?.refreshColors() }

        secureIcon.tintColor = protectedStateIsActive
            ? PPContextCheckoutColors.success
            : PPContextCheckoutColors.tertiaryText
        secureLabel.textColor = protectedStateIsActive
            ? PPContextCheckoutColors.success
            : PPContextCheckoutColors.secondaryText

        decisionPanel.backgroundColor = PPContextCheckoutColors.quietSurface
        decisionPanel.layer.borderColor = PPContextCheckoutColors.border.cgColor
        decisionPanel.layer.borderWidth = UIAccessibility.isDarkerSystemColorsEnabled
            ? PPContextCheckoutMetrics.hairline
            : 0
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
