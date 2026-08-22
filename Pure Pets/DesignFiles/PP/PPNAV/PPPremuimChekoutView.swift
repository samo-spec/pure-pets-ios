//
//  PPPremuimChekoutView.swift
//  Pure Pets
//
//  Persistent checkout decision rail shared by Cart and Payment.
//  Business state, validation, navigation, and payment ownership remain in the hosts.
//

import UIKit

// MARK: - Typography and semantic appearance

private enum PPCheckoutDockFont {
    static func regular(_ size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Regular", size: size, weight: .regular, textStyle: textStyle)
    }

    static func medium(_ size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Medium", size: size, weight: .medium, textStyle: textStyle)
    }

    static func bold(_ size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        scaled(named: "Beiruti-Bold", size: size, weight: .bold, textStyle: textStyle)
    }

    private static func scaled(named name: String,
                               size: CGFloat,
                               weight: UIFont.Weight,
                               textStyle: UIFont.TextStyle) -> UIFont {
        let baseFont = UIFont(name: name, size: size + 1) ?? UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
    }
}

private enum PPCheckoutDockStyle {
    static var action: UIColor { .ppPrimary }
    static var actionPressed: UIColor { .ppPressedAction }
    // `ppAccentText` is rose in the light palette and disappears over
    // `ppPrimary`. Pure Pets' canonical primary button uses white foreground.
    static var actionText: UIColor { .white }
    static var surface: UIColor { .ppSurfaceElevated }
    static var secondarySurface: UIColor { .ppSurface }
    static var surfaceOverlay: UIColor { .ppSurfaceOverlay }
    static var border: UIColor { .ppSurfaceBorder }
    static var separator: UIColor { .ppSeparator }
    static var primaryText: UIColor { .ppTextPrimary }
    static var secondaryText: UIColor { .ppTextSecondary }
    static var tertiaryText: UIColor { .ppTextTertiary }
    static var success: UIColor { .ppSuccess }
}

private enum PPCheckoutDockGeometry {
    static let checkoutMinimumWidth: CGFloat = 204
    static let checkoutMaximumWidth: CGFloat = 224
    static let horizontalAmountMinimumWidth: CGFloat = 92
    static let regularPreviewHeight: CGFloat = 78
    static let accessibilityPreviewHeight: CGFloat = 132
    static let checkoutTapDebounce: TimeInterval = 0.45

    static var semanticStrokeWidth: CGFloat {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return 1
        }
        return 1 / max(UIScreen.main.scale, 1)
    }
}

private enum PPCheckoutDockCurrency {
    static func format(_ value: CGFloat) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "QAR"
        formatter.currencySymbol = "QAR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_QA")
        return formatter.string(from: NSNumber(value: Double(value)))
            ?? String(format: "QAR %.2f", Double(value))
    }
}

private func ppCheckoutDockLanguageSemantic() -> UISemanticContentAttribute {
    Language.semanticAttributeForCurrentLanguage()
}

private func ppCheckoutDockLanguageAlignment() -> NSTextAlignment {
    Language.alignmentForCurrentLanguage()
}

private func ppCheckoutDockIsRTL() -> Bool {
    ppCheckoutDockLanguageSemantic() == .forceRightToLeft
}

private func ppCheckoutDockTrustCopy() -> String {
    NSLocalizedString("Securecheckout", comment: "")
        .replacingOccurrences(of: "🔒", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Primary action

private final class PPCheckoutDockActionButton: UIControl {
    private let contentStack = UIStackView()
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var feedbackAnimator: UIViewPropertyAnimator?
    private var loading = false
    private var reduceMotion: Bool {
        guard !UIAccessibility.isReduceMotionEnabled else { return true }
        return false
    }

    override var isHighlighted: Bool {
        didSet { refreshColors() }
    }

    override var isEnabled: Bool {
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

    deinit {
        stopMotion()
    }

    private func buildView() {
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        accessibilityIdentifier = "checkoutDock.primaryAction"

        layer.cornerRadius = PPBottomDecisionBarGeometry.controlRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 0
        clipsToBounds = true

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = PPSpace.sm
        contentStack.isUserInteractionEnabled = false

        titleLabel.font = PPCheckoutDockFont.bold(16, textStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.isAccessibilityElement = false

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(iconView)
        addSubview(contentStack)
        addSubview(spinner)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PPSpace.md),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -PPSpace.md),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: PPSpace.sm),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -PPSpace.sm),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        refreshColors()
    }

    func configure(title: String, image: UIImage?) {
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleTitle = resolvedTitle.isEmpty ? NSLocalizedString("Checkout", comment: "") : title
        titleLabel.text = visibleTitle
        iconView.image = image?.withRenderingMode(.alwaysTemplate)
        iconView.isHidden = image == nil
        accessibilityLabel = visibleTitle
        invalidateIntrinsicContentSize()
    }

    func applyLanguage(_ semantic: UISemanticContentAttribute) {
        semanticContentAttribute = semantic
        contentStack.semanticContentAttribute = semantic
    }

    func setLoading(_ loading: Bool) {
        self.loading = loading
        isEnabled = !loading
        contentStack.alpha = loading ? 0 : 1
        accessibilityValue = loading ? NSLocalizedString("Loading", comment: "") : nil

        if loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    func acknowledgePaymentMethodChange(accentColor: UIColor?) {
        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()

        stopMotion()
        guard !reduceMotion,
              UIView.areAnimationsEnabled,
              window != nil else {
            refreshColors()
            return
        }

        layer.borderWidth = 2
        layer.borderColor = (accentColor ?? PPCheckoutDockStyle.action).cgColor
        let animator = UIViewPropertyAnimator(duration: 0.22, curve: .easeOut) {
            self.layer.borderWidth = 0
            self.layer.borderColor = UIColor.clear.cgColor
        }
        animator.addCompletion { [weak self] _ in
            self?.feedbackAnimator = nil
            self?.refreshColors()
        }
        feedbackAnimator = animator
        animator.startAnimation()
    }

    func refreshColors() {
        backgroundColor = isHighlighted ? PPCheckoutDockStyle.actionPressed : PPCheckoutDockStyle.action
        titleLabel.textColor = PPCheckoutDockStyle.actionText
        iconView.tintColor = PPCheckoutDockStyle.actionText
        spinner.color = PPCheckoutDockStyle.actionText
        layer.borderColor = UIColor.clear.cgColor
        alpha = isEnabled || loading ? 1 : 0.58
        accessibilityTraits = isEnabled ? [.button] : [.button, .notEnabled]
    }

    func stopMotion() {
        feedbackAnimator?.stopAnimation(true)
        feedbackAnimator = nil
        layer.removeAllAnimations()
        refreshColors()
    }
}

// MARK: - Disclosure control

private final class PPCheckoutDockSummaryToggle: UIControl {
    private let iconStack = UIStackView()
    private let bagIcon = UIImageView(image: UIImage(systemName: "bag.fill"))
    private let chevronIcon = UIImageView(image: UIImage(systemName: "chevron.up"))
    private let countLabel = UILabel()

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
        accessibilityIdentifier = "checkoutDock.summaryToggle.compact"
        layer.cornerRadius = PPBottomDecisionBarGeometry.controlRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = PPCheckoutDockGeometry.semanticStrokeWidth
        clipsToBounds = false

        iconStack.translatesAutoresizingMaskIntoConstraints = false
        iconStack.axis = .horizontal
        iconStack.alignment = .center
        iconStack.spacing = PPSpace.xxs
        iconStack.isUserInteractionEnabled = false

        bagIcon.translatesAutoresizingMaskIntoConstraints = false
        bagIcon.contentMode = .scaleAspectFit
        bagIcon.isAccessibilityElement = false

        chevronIcon.translatesAutoresizingMaskIntoConstraints = false
        chevronIcon.contentMode = .scaleAspectFit
        chevronIcon.isAccessibilityElement = false

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = PPCheckoutDockFont.bold(10, textStyle: .caption2)
        countLabel.textAlignment = .center
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.layer.masksToBounds = true
        countLabel.isAccessibilityElement = false
        countLabel.isHidden = true

        iconStack.addArrangedSubview(bagIcon)
        iconStack.addArrangedSubview(chevronIcon)
        addSubview(iconStack)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PPBottomDecisionBarGeometry.utilityControlSize),
            heightAnchor.constraint(equalToConstant: PPBottomDecisionBarGeometry.utilityControlSize),
            iconStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            bagIcon.widthAnchor.constraint(equalToConstant: 19),
            bagIcon.heightAnchor.constraint(equalToConstant: 19),
            chevronIcon.widthAnchor.constraint(equalToConstant: 9),
            chevronIcon.heightAnchor.constraint(equalToConstant: 9),
            countLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            countLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 18)
        ])

        refreshColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        countLabel.layer.cornerRadius = countLabel.bounds.height * 0.5
    }

    func setCount(_ count: Int) {
        countLabel.text = count > 0 ? "\(count)" : nil
        countLabel.isHidden = count <= 0
    }

    func refreshColors() {
        backgroundColor = isHighlighted
            ? PPCheckoutDockStyle.surfaceOverlay
            : PPCheckoutDockStyle.surface
        layer.borderColor = PPCheckoutDockStyle.border.cgColor
        layer.borderWidth = PPCheckoutDockGeometry.semanticStrokeWidth
        bagIcon.tintColor = PPCheckoutDockStyle.primaryText
        chevronIcon.tintColor = PPCheckoutDockStyle.secondaryText
        countLabel.backgroundColor = PPCheckoutDockStyle.action
        countLabel.textColor = PPCheckoutDockStyle.actionText
    }
}

// MARK: - Receipt rows

private final class PPCheckoutDockMetricRow: UIView {
    private let valueStack = UIStackView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private var localizedTitle: String

    init(title: String) {
        localizedTitle = title
        super.init(frame: .zero)
        buildView()
    }

    required init?(coder: NSCoder) {
        localizedTitle = ""
        super.init(coder: coder)
        buildView()
    }

    private func buildView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true

        valueStack.translatesAutoresizingMaskIntoConstraints = false
        valueStack.axis = .horizontal
        valueStack.alignment = .center
        valueStack.distribution = .fill
        valueStack.spacing = PPSpace.sm

        titleLabel.font = PPCheckoutDockFont.medium(14, textStyle: .body)
        titleLabel.textColor = PPCheckoutDockStyle.secondaryText
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        valueLabel.font = PPCheckoutDockFont.bold(14, textStyle: .body)
        valueLabel.textColor = PPCheckoutDockStyle.primaryText
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.numberOfLines = 0
        valueLabel.semanticContentAttribute = .forceLeftToRight
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueStack.addArrangedSubview(titleLabel)
        valueStack.addArrangedSubview(valueLabel)
        addSubview(valueStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            valueStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueStack.topAnchor.constraint(equalTo: topAnchor, constant: PPSpace.xs),
            valueStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -PPSpace.xs)
        ])

        setTitle(localizedTitle)
        applyLanguage()
    }

    func setTitle(_ title: String) {
        localizedTitle = title
        titleLabel.text = title
        accessibilityLabel = title
    }

    func setValue(_ value: String) {
        valueLabel.text = value
        accessibilityValue = value
    }

    func setAccessibilityLayout(_ accessibilityLayout: Bool) {
        valueStack.axis = accessibilityLayout ? .vertical : .horizontal
        valueStack.alignment = .fill
        valueStack.spacing = accessibilityLayout ? PPSpace.xxs : PPSpace.md
        applyLanguage()
    }

    func applyLanguage() {
        let semantic = ppCheckoutDockLanguageSemantic()
        semanticContentAttribute = semantic
        valueStack.semanticContentAttribute = semantic
        titleLabel.textAlignment = ppCheckoutDockLanguageAlignment()
        valueLabel.textAlignment = valueStack.axis == .vertical
            ? ppCheckoutDockLanguageAlignment()
            : (ppCheckoutDockIsRTL() ? .left : .right)
    }
}

// MARK: - Item preview

private final class PPCheckoutDockPreviewCell: UICollectionViewCell {
    static let reuseIdentifier = "PPCheckoutDockPreviewCell"

    private let iconView = UIImageView(image: UIImage(systemName: "bag.fill"))
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
        contentView.layer.cornerRadius = PPCorner.medium
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 0
        contentView.layer.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.isAccessibilityElement = false

        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = PPSpace.xxs

        nameLabel.font = PPCheckoutDockFont.medium(14, textStyle: .subheadline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail

        metaLabel.font = PPCheckoutDockFont.bold(13, textStyle: .footnote)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.numberOfLines = 1
        metaLabel.semanticContentAttribute = .forceLeftToRight

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(metaLabel)
        contentView.addSubview(iconView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: PPSpace.md),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: PPSpace.sm),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -PPSpace.md),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: PPSpace.sm),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -PPSpace.sm),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        applyLanguage()
        refreshColors()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        metaLabel.text = nil
        accessibilityLabel = nil
        accessibilityValue = nil
        contentView.alpha = 1
        contentView.transform = .identity
    }

    func configure(item: CartItem) {
        let trimmedName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? NSLocalizedString("Cart", comment: "") : trimmedName
        let quantity = max(item.quantity, 1)
        let lineTotal = item.lineSubtotal > 0 ? item.lineSubtotal : item.price * Double(quantity)
        let meta = "×\(quantity)  \(PPCheckoutDockCurrency.format(CGFloat(lineTotal)))"

        nameLabel.text = resolvedName
        metaLabel.text = meta
        accessibilityLabel = resolvedName
        accessibilityValue = meta
        applyLanguage()
    }

    func applyLanguage() {
        let semantic = ppCheckoutDockLanguageSemantic()
        semanticContentAttribute = semantic
        contentView.semanticContentAttribute = semantic
        textStack.semanticContentAttribute = semantic
        nameLabel.textAlignment = ppCheckoutDockLanguageAlignment()
        metaLabel.textAlignment = ppCheckoutDockLanguageAlignment()
    }

    func refreshColors() {
        contentView.backgroundColor = PPCheckoutDockStyle.surfaceOverlay
        contentView.layer.borderColor = UIColor.clear.cgColor
        iconView.tintColor = PPCheckoutDockStyle.primaryText
        nameLabel.textColor = PPCheckoutDockStyle.primaryText
        metaLabel.textColor = PPCheckoutDockStyle.secondaryText
    }
}

// MARK: - Persistent checkout dock

@objc(PPPremuimChekoutView)
@objcMembers
public final class PPPremuimChekoutView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public var itemsTotal: CGFloat = 0
    public var shippingFee: CGFloat = 0
    public private(set) var subtotal: CGFloat = 0
    public var showDetails: Bool = true {
        didSet { updateVisibility(animated: window != nil) }
    }
    public var onTapCheckOut: (() -> Void)?

    private let cardView = UIView()
    private let topContourLayer = CAShapeLayer()
    private let contentStack = UIStackView()
    private let disclosureStack = UIStackView()

    private let headerRow = UIStackView()
    private let headerIcon = UIImageView(image: UIImage(systemName: "bag.fill"))
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let collapseButton = UIButton(type: .system)

    private let receiptStack = UIStackView()
    private let itemsRow = PPCheckoutDockMetricRow(title: NSLocalizedString("Selected Items", comment: ""))
    private let shippingRow = PPCheckoutDockMetricRow(title: NSLocalizedString("Shipping Fee", comment: ""))
    private let receiptSeparator = UIView()

    private let previewCollection: UICollectionView
    private var previewHeightConstraint: NSLayoutConstraint?

    private let trustRow = UIStackView()
    private let trustIcon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
    private let trustLabel = UILabel()
    private let disclosureSeparator = UIView()

    private let decisionStack = UIStackView()
    private let amountControlRow = UIStackView()
    private let compactDisclosureButton = PPCheckoutDockSummaryToggle()
    private let amountStack = UIStackView()
    private let amountCaptionLabel = UILabel()
    private let amountLabel = UILabel()
    private let ctaButton = PPCheckoutDockActionButton()

    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomConstraint: NSLayoutConstraint?
    private var ctaMinimumWidthConstraint: NSLayoutConstraint?
    private var ctaMaximumWidthConstraint: NSLayoutConstraint?

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
    private var wantsTrustAccent = false
    private var lastVisibilitySignature = -1
    private var usesStackedDecisionLayout = false
    private var usesAccessibilityReceiptLayout = false
    private var didResolveEntrance = false

    private var summaryStateAnimator: UIViewPropertyAnimator?
    private var amountChangeAnimator: UIViewPropertyAnimator?
    private var entranceAnimator: UIViewPropertyAnimator?
    private weak var activeAmountTransitionLabel: UILabel?
    private var reduceMotion: Bool {
        guard !UIAccessibility.isReduceMotionEnabled else { return true }
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
        cancelMotion(settleToCurrentState: false)
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        shouldGroupAccessibilityChildren = true
        accessibilityIdentifier = "checkoutDock"

        buildView()
        buildLayout()
        applyLanguage()
        refreshColors()
        updateTotalsWithItems(0, shipping: 0, showTitle: true)
        updatePreviewItems(nil)
        setCheckoutBTNTitle(nil, image: nil)
        updateVisibility(animated: false)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contrastDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: Notification.Name("LanguageDidChangeNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: Notification.Name("PPLanguageDidChangeNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private func buildView() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = PPBottomDecisionBarGeometry.surfaceRadius
        cardView.layer.cornerCurve = .continuous
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.layer.borderWidth = 0
        cardView.clipsToBounds = false
        topContourLayer.fillColor = UIColor.clear.cgColor
        topContourLayer.lineCap = .round
        topContourLayer.contentsScale = UIScreen.main.scale
        topContourLayer.isHidden = false
        topContourLayer.actions = [
            "frame": NSNull(),
            "path": NSNull(),
            "strokeColor": NSNull(),
            "lineWidth": NSNull()
        ]
        cardView.layer.addSublayer(topContourLayer)
        addSubview(cardView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = PPSpace.sm
        cardView.addSubview(contentStack)

        buildDisclosureContent()
        buildDecisionRail()

        contentStack.addArrangedSubview(disclosureStack)
        contentStack.addArrangedSubview(decisionStack)
    }

    private func buildDisclosureContent() {
        disclosureStack.axis = .vertical
        disclosureStack.alignment = .fill
        disclosureStack.spacing = PPSpace.sm

        buildHeader()
        buildReceipt()
        buildPreview()
        buildTrustRow()

        disclosureSeparator.translatesAutoresizingMaskIntoConstraints = false
        disclosureSeparator.isAccessibilityElement = false
        disclosureSeparator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        disclosureStack.addArrangedSubview(headerRow)
        disclosureStack.addArrangedSubview(receiptStack)
        disclosureStack.addArrangedSubview(previewCollection)
        disclosureStack.addArrangedSubview(trustRow)
        disclosureStack.addArrangedSubview(disclosureSeparator)
    }

    private func buildHeader() {
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = PPSpace.md
        headerRow.isAccessibilityElement = false

        headerIcon.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.contentMode = .scaleAspectFit
        headerIcon.isAccessibilityElement = false

        titleLabel.font = PPCheckoutDockFont.bold(18, textStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.isAccessibilityElement = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        countLabel.font = PPCheckoutDockFont.bold(15, textStyle: .subheadline)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textAlignment = .center
        countLabel.isAccessibilityElement = false
        countLabel.isHidden = true
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        collapseButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        collapseButton.imageView?.contentMode = .scaleAspectFit
        collapseButton.layer.cornerRadius = 22
        collapseButton.layer.cornerCurve = .continuous
        collapseButton.layer.borderWidth = 0
        collapseButton.accessibilityIdentifier = "checkoutDock.summaryToggle.expanded"
        collapseButton.addTarget(self, action: #selector(didTapSummaryDisclosure), for: .touchUpInside)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        headerRow.addArrangedSubview(headerIcon)
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(spacer)
        headerRow.addArrangedSubview(countLabel)
        headerRow.addArrangedSubview(collapseButton)

        NSLayoutConstraint.activate([
            headerRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            headerIcon.widthAnchor.constraint(equalToConstant: 22),
            headerIcon.heightAnchor.constraint(equalToConstant: 22),
            collapseButton.widthAnchor.constraint(equalToConstant: 44),
            collapseButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func buildReceipt() {
        receiptStack.axis = .horizontal
        receiptStack.alignment = .fill
        receiptStack.distribution = .fillEqually
        receiptStack.spacing = PPSpace.md

        receiptStack.addArrangedSubview(itemsRow)
        receiptStack.addArrangedSubview(shippingRow)
        itemsRow.accessibilityIdentifier = "checkoutDock.selectedItems"
        shippingRow.accessibilityIdentifier = "checkoutDock.shippingFee"
    }

    private func buildPreview() {
        previewCollection.translatesAutoresizingMaskIntoConstraints = false
        previewCollection.backgroundColor = .clear
        previewCollection.showsHorizontalScrollIndicator = false
        previewCollection.alwaysBounceHorizontal = true
        previewCollection.dataSource = self
        previewCollection.delegate = self
        previewCollection.clipsToBounds = false
        previewCollection.register(
            PPCheckoutDockPreviewCell.self,
            forCellWithReuseIdentifier: PPCheckoutDockPreviewCell.reuseIdentifier
        )
        previewHeightConstraint = previewCollection.heightAnchor.constraint(
            equalToConstant: PPCheckoutDockGeometry.regularPreviewHeight
        )
        previewHeightConstraint?.isActive = true
    }

    private func buildTrustRow() {
        trustRow.axis = .horizontal
        trustRow.alignment = .center
        trustRow.spacing = PPSpace.sm
        trustRow.isAccessibilityElement = true

        trustIcon.translatesAutoresizingMaskIntoConstraints = false
        trustIcon.contentMode = .scaleAspectFit
        trustIcon.isAccessibilityElement = false
        trustIcon.setContentHuggingPriority(.required, for: .horizontal)
        trustIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        trustLabel.font = PPCheckoutDockFont.regular(13, textStyle: .footnote)
        trustLabel.adjustsFontForContentSizeCategory = true
        trustLabel.numberOfLines = 0
        trustLabel.isAccessibilityElement = false

        trustRow.addArrangedSubview(trustIcon)
        trustRow.addArrangedSubview(trustLabel)

        NSLayoutConstraint.activate([
            trustRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            trustIcon.widthAnchor.constraint(equalToConstant: 17),
            trustIcon.heightAnchor.constraint(equalToConstant: 17)
        ])
    }

    private func buildDecisionRail() {
        decisionStack.axis = .horizontal
        decisionStack.alignment = .center
        decisionStack.distribution = .fill
        decisionStack.spacing = PPBottomDecisionBarGeometry.controlSpacing
        decisionStack.isLayoutMarginsRelativeArrangement = true
        decisionStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: PPSpace.xs,
            leading: PPSpace.xs,
            bottom: PPSpace.xs,
            trailing: PPSpace.xs
        )
        decisionStack.layer.cornerRadius = PPCorner.card
        decisionStack.layer.cornerCurve = .continuous
        decisionStack.layer.borderWidth = PPCheckoutDockGeometry.semanticStrokeWidth
        decisionStack.layer.masksToBounds = true

        amountControlRow.axis = .horizontal
        amountControlRow.alignment = .center
        amountControlRow.distribution = .fill
        amountControlRow.spacing = PPBottomDecisionBarGeometry.controlSpacing
        amountControlRow.setContentHuggingPriority(.defaultLow, for: .horizontal)
        amountControlRow.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        compactDisclosureButton.addTarget(self, action: #selector(didTapSummaryDisclosure), for: .touchUpInside)
        compactDisclosureButton.isHidden = true

        amountStack.axis = .vertical
        amountStack.alignment = .fill
        amountStack.spacing = 0
        amountStack.isAccessibilityElement = true
        amountStack.accessibilityIdentifier = "checkoutDock.subtotal"
        amountStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        amountCaptionLabel.font = PPCheckoutDockFont.medium(12, textStyle: .caption1)
        amountCaptionLabel.adjustsFontForContentSizeCategory = true
        amountCaptionLabel.numberOfLines = 1
        amountCaptionLabel.isAccessibilityElement = false

        amountLabel.font = PPCheckoutDockFont.bold(23, textStyle: .title3)
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.numberOfLines = 0
        amountLabel.lineBreakMode = .byWordWrapping
        amountLabel.semanticContentAttribute = .forceLeftToRight
        amountLabel.isAccessibilityElement = false
        amountLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        amountStack.addArrangedSubview(amountCaptionLabel)
        amountStack.addArrangedSubview(amountLabel)
        amountControlRow.addArrangedSubview(compactDisclosureButton)
        amountControlRow.addArrangedSubview(amountStack)

        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.addTarget(self, action: #selector(didTapCheckout), for: .touchUpInside)
        ctaButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        ctaButton.setContentCompressionResistancePriority(UILayoutPriority(999), for: .horizontal)

        decisionStack.addArrangedSubview(amountControlRow)
        decisionStack.addArrangedSubview(ctaButton)

        let minimumWidth = ctaButton.widthAnchor.constraint(
            greaterThanOrEqualToConstant: PPCheckoutDockGeometry.checkoutMinimumWidth
        )
        minimumWidth.priority = UILayoutPriority(999)
        let maximumWidth = ctaButton.widthAnchor.constraint(
            lessThanOrEqualToConstant: PPCheckoutDockGeometry.checkoutMaximumWidth
        )
        ctaMinimumWidthConstraint = minimumWidth
        ctaMaximumWidthConstraint = maximumWidth

        NSLayoutConstraint.activate([
            ctaButton.heightAnchor.constraint(greaterThanOrEqualToConstant: PPBottomDecisionBarGeometry.controlHeight),
            minimumWidth,
            maximumWidth
        ])
    }

    private func buildLayout() {
        let topConstraint = contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: PPSpace.sm)
        let bottomConstraint = contentStack.bottomAnchor.constraint(
            equalTo: cardView.bottomAnchor,
            constant: -resolvedBottomPadding
        )
        contentTopConstraint = topConstraint
        contentBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            topConstraint,
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: PPBottomDecisionBarGeometry.contentPadding),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -PPBottomDecisionBarGeometry.contentPadding),
            bottomConstraint
        ])
    }

    private var resolvedBottomPadding: CGFloat {
        max(PPSpace.sm, safeAreaInsets.bottom + PPSpace.xs)
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelMotion(settleToCurrentState: true)
        }
    }

    public override func layoutSubviews() {
        updateAdaptiveLayout(for: bounds.width)
        super.layoutSubviews()
        updateShadowPath()

        if !didResolveEntrance, cardView.bounds.height > 0 {
            didResolveEntrance = true
            runEntranceIfNeeded()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            super.traitCollectionDidChange(previousTraitCollection)
        }

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshColors()
        }

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            cancelMotion(settleToCurrentState: true)
            updateAdaptiveLayout(for: bounds.width)
            previewCollection.collectionViewLayout.invalidateLayout()
            invalidateIntrinsicContentSize()
            superview?.setNeedsLayout()
        }
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        contentBottomConstraint?.constant = -resolvedBottomPadding
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    public override var intrinsicContentSize: CGSize {
        let resolvedWidth = bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight(for: resolvedWidth))
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        let resolvedWidth = targetSize.width > 1
            ? targetSize.width
            : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: resolvedWidth, height: measuredHeight(for: resolvedWidth))
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let resolvedWidth = targetSize.width > 1
            ? targetSize.width
            : (bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width)
        return CGSize(width: resolvedWidth, height: measuredHeight(for: resolvedWidth))
    }

    private func measuredHeight(for width: CGFloat) -> CGFloat {
        let resolvedWidth = max(width, 1)
        updateAdaptiveLayout(for: resolvedWidth)
        let contentWidth = max(resolvedWidth - (PPBottomDecisionBarGeometry.contentPadding * 2), 1)
        let contentSize = contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let topPadding = PPSpace.sm
        return ceil(contentSize.height + topPadding + resolvedBottomPadding)
    }

    private func updateAdaptiveLayout(for width: CGFloat) {
        guard width > 1 else { return }
        let accessibilityRows = traitCollection.preferredContentSizeCategory.isAccessibilityCategory

        // Decide against the rail's usable content width, not the device width.
        // This keeps the regular 13 Pro Max composition compact while allowing
        // long prices, Arabic copy, and Dynamic Type to stack without squeezing.
        let decisionContentWidth = max(
            width
                - (PPBottomDecisionBarGeometry.contentPadding * 2)
                - decisionStack.layoutMargins.left
                - decisionStack.layoutMargins.right,
            0
        )
        let compactUtilityWidth = collapsible && summaryCollapsed
            ? PPBottomDecisionBarGeometry.utilityControlSize
                + PPBottomDecisionBarGeometry.controlSpacing
            : 0
        let availableAmountWidth = decisionContentWidth
            - PPCheckoutDockGeometry.checkoutMinimumWidth
            - PPBottomDecisionBarGeometry.controlSpacing
            - compactUtilityWidth
        let shouldStack = accessibilityRows
            || availableAmountWidth < PPCheckoutDockGeometry.horizontalAmountMinimumWidth
        amountLabel.numberOfLines = shouldStack ? 0 : 1

        if accessibilityRows != usesAccessibilityReceiptLayout {
            usesAccessibilityReceiptLayout = accessibilityRows
            itemsRow.setAccessibilityLayout(accessibilityRows)
            shippingRow.setAccessibilityLayout(accessibilityRows)
            receiptStack.axis = accessibilityRows ? .vertical : .horizontal
            receiptStack.distribution = accessibilityRows ? .fill : .fillEqually
            receiptStack.spacing = accessibilityRows ? PPSpace.xxs : PPSpace.md
            previewHeightConstraint?.constant = accessibilityRows
                ? PPCheckoutDockGeometry.accessibilityPreviewHeight
                : PPCheckoutDockGeometry.regularPreviewHeight
        }

        guard shouldStack != usesStackedDecisionLayout else { return }
        usesStackedDecisionLayout = shouldStack
        decisionStack.axis = shouldStack ? .vertical : .horizontal
        decisionStack.alignment = .fill
        decisionStack.spacing = shouldStack ? PPSpace.sm : PPBottomDecisionBarGeometry.controlSpacing
        ctaMinimumWidthConstraint?.isActive = !shouldStack
        ctaMaximumWidthConstraint?.isActive = !shouldStack
        invalidateIntrinsicContentSize()
    }

    // MARK: Appearance and localization

    private func refreshColors() {
        cardView.backgroundColor = PPCheckoutDockStyle.surface
        topContourLayer.strokeColor = PPCheckoutDockStyle.border.cgColor
        topContourLayer.lineWidth = PPCheckoutDockGeometry.semanticStrokeWidth
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.16 : 0.06
        cardView.layer.shadowRadius = 12
        cardView.layer.shadowOffset = CGSize(width: 0, height: -3)

        decisionStack.backgroundColor = PPCheckoutDockStyle.secondarySurface
        decisionStack.layer.borderColor = PPCheckoutDockStyle.border.cgColor
        decisionStack.layer.borderWidth = PPCheckoutDockGeometry.semanticStrokeWidth

        headerIcon.tintColor = PPCheckoutDockStyle.primaryText
        titleLabel.textColor = PPCheckoutDockStyle.primaryText
        countLabel.textColor = PPCheckoutDockStyle.secondaryText
        collapseButton.tintColor = PPCheckoutDockStyle.secondaryText
        collapseButton.backgroundColor = PPCheckoutDockStyle.surfaceOverlay
        collapseButton.layer.borderColor = PPCheckoutDockStyle.border.cgColor
        collapseButton.layer.borderWidth = PPCheckoutDockGeometry.semanticStrokeWidth

        receiptSeparator.backgroundColor = PPCheckoutDockStyle.separator
        disclosureSeparator.backgroundColor = PPCheckoutDockStyle.separator
        amountCaptionLabel.textColor = PPCheckoutDockStyle.secondaryText
        amountLabel.textColor = PPCheckoutDockStyle.primaryText
        trustLabel.textColor = PPCheckoutDockStyle.secondaryText
        refreshTrustAppearance()

        compactDisclosureButton.refreshColors()
        ctaButton.refreshColors()
        previewCollection.visibleCells.forEach { cell in
            (cell as? PPCheckoutDockPreviewCell)?.refreshColors()
        }
        setNeedsLayout()
    }

    private func refreshTrustAppearance() {
        trustIcon.tintColor = wantsTrustAccent ? PPCheckoutDockStyle.success : PPCheckoutDockStyle.tertiaryText
    }

    private func updateShadowPath() {
        guard cardView.bounds.width > 0 else {
            cardView.layer.shadowPath = nil
            topContourLayer.path = nil
            return
        }

        topContourLayer.frame = cardView.bounds
        let contourInset = topContourLayer.lineWidth * 0.5
        let contourRadius = max(cardView.layer.cornerRadius - contourInset, 0)
        let contour = UIBezierPath()
        contour.move(to: CGPoint(x: contourInset, y: cardView.layer.cornerRadius))
        contour.addArc(
            withCenter: CGPoint(x: cardView.layer.cornerRadius, y: cardView.layer.cornerRadius),
            radius: contourRadius,
            startAngle: .pi,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        contour.addLine(to: CGPoint(x: cardView.bounds.width - cardView.layer.cornerRadius, y: contourInset))
        contour.addArc(
            withCenter: CGPoint(
                x: cardView.bounds.width - cardView.layer.cornerRadius,
                y: cardView.layer.cornerRadius
            ),
            radius: contourRadius,
            startAngle: .pi * 1.5,
            endAngle: 0,
            clockwise: true
        )
        topContourLayer.path = contour.cgPath

        let pathRect = CGRect(x: 12, y: -2, width: max(cardView.bounds.width - 24, 0), height: 4)
        cardView.layer.shadowPath = UIBezierPath(roundedRect: pathRect, cornerRadius: 2).cgPath
    }

    private func applyLanguage() {
        let semantic = ppCheckoutDockLanguageSemantic()
        semanticContentAttribute = semantic
        contentStack.semanticContentAttribute = semantic
        disclosureStack.semanticContentAttribute = semantic
        headerRow.semanticContentAttribute = semantic
        receiptStack.semanticContentAttribute = semantic
        trustRow.semanticContentAttribute = semantic
        decisionStack.semanticContentAttribute = semantic
        amountControlRow.semanticContentAttribute = semantic
        ctaButton.applyLanguage(semantic)

        titleLabel.text = NSLocalizedString("cartTitle", comment: "")
        titleLabel.textAlignment = ppCheckoutDockLanguageAlignment()
        amountCaptionLabel.text = NSLocalizedString("Subtotal", comment: "")
        amountCaptionLabel.textAlignment = ppCheckoutDockLanguageAlignment()
        amountLabel.textAlignment = ppCheckoutDockLanguageAlignment()
        trustLabel.text = ppCheckoutDockTrustCopy()
        trustLabel.textAlignment = ppCheckoutDockLanguageAlignment()
        trustRow.accessibilityLabel = trustLabel.text

        itemsRow.setTitle(NSLocalizedString("Selected Items", comment: ""))
        shippingRow.setTitle(NSLocalizedString("Shipping Fee", comment: ""))
        itemsRow.applyLanguage()
        shippingRow.applyLanguage()

        previewCollection.semanticContentAttribute = semantic
        previewCollection.visibleCells.forEach { cell in
            (cell as? PPCheckoutDockPreviewCell)?.applyLanguage()
        }

        if usesDefaultCheckoutTitle {
            checkoutTitle = NSLocalizedString("Checkout", comment: "")
        }
        if usesAutomaticCheckoutImage {
            checkoutImage = UIImage(systemName: ppCheckoutDockIsRTL() ? "arrow.left" : "arrow.right")
        }
        ctaButton.configure(title: checkoutTitle, image: checkoutImage)
        updateCollapseAccessibility()
    }

    // MARK: Public Objective-C contract

    @objc(updateTotalsWithItems:shipping:showTitle:)
    func updateTotalsWithItems(_ itemsTotal: CGFloat, shipping shippingFee: CGFloat, showTitle _: Bool) {
        let oldAmount = amountLabel.text
        self.itemsTotal = itemsTotal
        self.shippingFee = shippingFee
        subtotal = itemsTotal + shippingFee

        let itemsText = PPCheckoutDockCurrency.format(itemsTotal)
        let shippingText = PPCheckoutDockCurrency.format(shippingFee)
        let subtotalText = PPCheckoutDockCurrency.format(subtotal)
        itemsRow.setValue(itemsText)
        shippingRow.setValue(shippingText)
        amountStack.accessibilityLabel = amountCaptionLabel.text
        amountStack.accessibilityValue = subtotalText

        if let oldAmount, oldAmount != subtotalText {
            animateAmountChange(from: oldAmount, to: subtotalText)
        } else {
            amountLabel.text = subtotalText
        }

        updateCollapseAccessibility()
        updateVisibility(animated: window != nil)
    }

    @objc(setShowsItemsPreview:)
    func setShowsItemsPreview(_ showsItemsPreview: Bool) {
        let becameVisible = showsItemsPreview && !self.showsItemsPreview
        self.showsItemsPreview = showsItemsPreview
        if becameVisible {
            previewCollection.reloadData()
        }
        updateVisibility(animated: window != nil)
    }

    @objc(updatePreviewItems:)
    func updatePreviewItems(_ items: [CartItem]?) {
        previewItems = items ?? []
        totalItemQuantity = previewItems.reduce(0) { $0 + max($1.quantity, 0) }
        countLabel.text = totalItemQuantity > 0 ? "\(totalItemQuantity)" : nil
        countLabel.isHidden = totalItemQuantity <= 0
        compactDisclosureButton.setCount(totalItemQuantity)
        previewCollection.reloadData()
        updateCollapseAccessibility()
        updateVisibility(animated: window != nil)
    }

    @objc(setCardBackgroundImage:)
    func setCardBackgroundImage(_ image: UIImage?) {
        _ = image
        setNeedsLayout()
    }

    @objc(setCheckoutBTNTitle:image:)
    func setCheckoutBTNTitle(_ title: String?, image: UIImage?) {
        if let title, !title.isEmpty {
            checkoutTitle = title
            usesDefaultCheckoutTitle = false
        } else {
            checkoutTitle = NSLocalizedString("Checkout", comment: "")
            usesDefaultCheckoutTitle = true
        }

        usesAutomaticCheckoutImage = image == nil
        checkoutImage = image ?? UIImage(systemName: ppCheckoutDockIsRTL() ? "arrow.left" : "arrow.right")
        ctaButton.configure(title: checkoutTitle, image: checkoutImage)
    }

    @objc(triggerPaymentMethodChangeFeedbackWithAccent:)
    public func triggerPaymentMethodChangeFeedback(accentColor: UIColor?) {
        ctaButton.acknowledgePaymentMethodChange(accentColor: accentColor)
    }

    @objc(triggerPaymentMethodChangeFeedback)
    public func triggerPaymentMethodChangeFeedback() {
        triggerPaymentMethodChangeFeedback(accentColor: nil)
    }

    @objc(setCheckoutLoading:)
    func setCheckoutLoading(_ loading: Bool) {
        checkoutLoading = loading
        if !loading {
            checkoutTapGate = false
        }
        ctaButton.setLoading(loading)
    }

    @objc(skipCardEntranceAnimation)
    func skipCardEntranceAnimation() {
        didResolveEntrance = true
        entranceAnimator?.stopAnimation(true)
        entranceAnimator = nil
        cardView.alpha = 1
        cardView.transform = .identity
    }

    @objc(pp_startTrustBannerShimmer)
    func pp_startTrustBannerShimmer() {
        wantsTrustAccent = true
        refreshTrustAppearance()
    }

    @objc(pp_stopTrustBannerShimmer)
    func pp_stopTrustBannerShimmer() {
        wantsTrustAccent = false
        refreshTrustAppearance()
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

    // MARK: State presentation

    private func updateCollapseAccessibility() {
        let action = summaryCollapsed
            ? NSLocalizedString("cart_summary_expand", comment: "")
            : NSLocalizedString("cart_summary_collapse", comment: "")
        let values = [
            totalItemQuantity > 0 ? "\(totalItemQuantity)" : nil,
            amountLabel.text
        ].compactMap { $0 }.joined(separator: ", ")

        collapseButton.isHidden = !collapsible
        collapseButton.accessibilityLabel = titleLabel.text
        collapseButton.accessibilityValue = values
        collapseButton.accessibilityHint = action
        collapseButton.accessibilityTraits = [.button]

        compactDisclosureButton.accessibilityLabel = titleLabel.text
        compactDisclosureButton.accessibilityValue = values
        compactDisclosureButton.accessibilityHint = action

        headerRow.isAccessibilityElement = !collapsible
        headerRow.accessibilityLabel = titleLabel.text
        headerRow.accessibilityValue = values
    }

    private func updateVisibility(animated: Bool) {
        let hasContent = !previewItems.isEmpty || subtotal > 0.009
        let collapsed = collapsible && summaryCollapsed
        let showPreview = !collapsed && showsItemsPreview && !previewItems.isEmpty
        let showReceipt = !collapsed && showDetails && !showPreview
        let showTrust = !collapsed && hasContent

        let signature = (collapsed ? 1 : 0)
            | (showPreview ? 2 : 0)
            | (showReceipt ? 4 : 0)
            | (showTrust ? 8 : 0)
            | (collapsible ? 16 : 0)
        let stateChanged = signature != lastVisibilitySignature
        let collapseChanged = lastVisibilitySignature >= 0 && (lastVisibilitySignature & 1) != (signature & 1)
        let shouldAnimate = animated
            && UIView.areAnimationsEnabled
            && !UIAccessibility.isReduceMotionEnabled
            && stateChanged
            && window != nil
        lastVisibilitySignature = signature

        summaryStateAnimator?.stopAnimation(false)
        summaryStateAnimator?.finishAnimation(at: .current)
        summaryStateAnimator = nil

        let applyFinalState = { [weak self] in
            guard let self else { return }
            disclosureStack.isHidden = collapsed
            disclosureStack.accessibilityElementsHidden = collapsed
            receiptStack.isHidden = !showReceipt
            previewCollection.isHidden = !showPreview
            trustRow.isHidden = !showTrust
            compactDisclosureButton.isHidden = !collapsed
            compactDisclosureButton.alpha = collapsed ? 1 : 0
            contentTopConstraint?.constant = PPSpace.sm
            disclosureStack.alpha = collapsed ? 0 : 1
            disclosureStack.transform = .identity
            receiptStack.alpha = showReceipt ? 1 : 0
            previewCollection.alpha = showPreview ? 1 : 0
            trustRow.alpha = showTrust ? 1 : 0
            invalidateIntrinsicContentSize()
            layoutIfNeeded()
            superview?.layoutIfNeeded()
        }

        let complete = { [weak self] in
            guard let self else { return }
            applyFinalState()
            superview?.setNeedsLayout()
            updateShadowPath()
            updateCollapseAccessibility()
            if collapseChanged && UIAccessibility.isVoiceOverRunning {
                let focusTarget: Any = collapsed ? compactDisclosureButton : collapseButton
                UIAccessibility.post(notification: .layoutChanged, argument: focusTarget)
            }
        }

        guard shouldAnimate, !reduceMotion else {
            applyFinalState()
            complete()
            return
        }

        superview?.layoutIfNeeded()
        if !collapsed {
            disclosureStack.isHidden = false
            disclosureStack.accessibilityElementsHidden = true
            disclosureStack.alpha = 0
            disclosureStack.transform = CGAffineTransform(translationX: 0, y: 8)
        }
        if showReceipt { receiptStack.isHidden = false }
        if showPreview { previewCollection.isHidden = false }
        if showTrust { trustRow.isHidden = false }
        if collapsed {
            compactDisclosureButton.isHidden = false
            compactDisclosureButton.alpha = 0
        }

        let animator = UIViewPropertyAnimator(duration: 0.24, curve: .easeOut, animations: applyFinalState)
        animator.addCompletion { [weak self] position in
            guard let self else { return }
            self.summaryStateAnimator = nil
            guard position == .end else { return }
            complete()
        }
        summaryStateAnimator = animator
        animator.startAnimation()
    }

    private func animateAmountChange(from oldText: String, to newText: String) {
        amountChangeAnimator?.stopAnimation(true)
        amountChangeAnimator = nil
        activeAmountTransitionLabel?.removeFromSuperview()
        activeAmountTransitionLabel = nil
        amountLabel.alpha = 1

        guard window != nil,
              UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled else {
            amountLabel.text = newText
            return
        }

        amountStack.layoutIfNeeded()
        let outgoingLabel = UILabel()
        outgoingLabel.translatesAutoresizingMaskIntoConstraints = false
        outgoingLabel.font = amountLabel.font
        outgoingLabel.textColor = amountLabel.textColor
        outgoingLabel.textAlignment = amountLabel.textAlignment
        outgoingLabel.adjustsFontForContentSizeCategory = true
        outgoingLabel.numberOfLines = amountLabel.numberOfLines
        outgoingLabel.semanticContentAttribute = .forceLeftToRight
        outgoingLabel.text = oldText
        outgoingLabel.isAccessibilityElement = false
        amountStack.addSubview(outgoingLabel)
        NSLayoutConstraint.activate([
            outgoingLabel.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor),
            outgoingLabel.trailingAnchor.constraint(equalTo: amountLabel.trailingAnchor),
            outgoingLabel.topAnchor.constraint(equalTo: amountLabel.topAnchor),
            outgoingLabel.bottomAnchor.constraint(equalTo: amountLabel.bottomAnchor)
        ])

        activeAmountTransitionLabel = outgoingLabel
        amountLabel.text = newText
        amountLabel.alpha = 0

        guard !reduceMotion else {
            outgoingLabel.removeFromSuperview()
            activeAmountTransitionLabel = nil
            amountLabel.alpha = 1
            return
        }

        let animator = UIViewPropertyAnimator(duration: 0.18, curve: .easeOut) {
            outgoingLabel.alpha = 0
            self.amountLabel.alpha = 1
        }
        animator.addCompletion { [weak self, weak outgoingLabel] _ in
            outgoingLabel?.removeFromSuperview()
            guard let self else { return }
            self.activeAmountTransitionLabel = nil
            self.amountChangeAnimator = nil
            self.amountLabel.alpha = 1
        }
        amountChangeAnimator = animator
        animator.startAnimation()
    }

    private func runEntranceIfNeeded() {
        guard window != nil,
              UIView.areAnimationsEnabled,
              !UIAccessibility.isReduceMotionEnabled else {
            cardView.alpha = 1
            cardView.transform = .identity
            return
        }

        cardView.alpha = 0
        cardView.transform = CGAffineTransform(translationX: 0, y: 8)
        guard !reduceMotion else {
            cardView.alpha = 1
            cardView.transform = .identity
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.22, curve: .easeOut) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
        animator.addCompletion { [weak self] _ in
            self?.entranceAnimator = nil
        }
        entranceAnimator = animator
        animator.startAnimation()
    }

    private func cancelMotion(settleToCurrentState: Bool) {
        summaryStateAnimator?.stopAnimation(true)
        summaryStateAnimator = nil
        amountChangeAnimator?.stopAnimation(true)
        amountChangeAnimator = nil
        entranceAnimator?.stopAnimation(true)
        entranceAnimator = nil
        ctaButton.stopMotion()
        activeAmountTransitionLabel?.removeFromSuperview()
        activeAmountTransitionLabel = nil

        amountLabel.alpha = 1
        cardView.alpha = 1
        cardView.transform = .identity
        disclosureStack.transform = .identity
        if settleToCurrentState {
            lastVisibilitySignature = -1
            updateVisibility(animated: false)
        }
    }

    // MARK: Actions and notifications

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
        DispatchQueue.main.asyncAfter(deadline: .now() + PPCheckoutDockGeometry.checkoutTapDebounce) { [weak self] in
            guard let self, !self.checkoutLoading else { return }
            self.checkoutTapGate = false
        }
    }

    @objc private func reduceMotionDidChange() {
        cancelMotion(settleToCurrentState: true)
    }

    @objc private func contrastDidChange() {
        refreshColors()
    }

    @objc private func languageDidChange() {
        cancelMotion(settleToCurrentState: true)
        applyLanguage()
        previewCollection.reloadData()
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    @objc private func applicationDidEnterBackground() {
        cancelMotion(settleToCurrentState: true)
    }

    // MARK: Collection view

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        previewItems.count
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard indexPath.item < previewItems.count,
              let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PPCheckoutDockPreviewCell.reuseIdentifier,
                for: indexPath
              ) as? PPCheckoutDockPreviewCell else {
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
        let widthFraction: CGFloat = accessibilityLayout ? 0.86 : 0.58
        let width = min(
            accessibilityLayout ? 340 : 230,
            max(accessibilityLayout ? 250 : 170, collectionView.bounds.width * widthFraction)
        )
        return CGSize(
            width: width,
            height: accessibilityLayout
                ? PPCheckoutDockGeometry.accessibilityPreviewHeight
                : PPCheckoutDockGeometry.regularPreviewHeight
        )
    }
}
