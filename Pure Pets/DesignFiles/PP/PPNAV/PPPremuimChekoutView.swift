//
//  PPPremuimChekoutView.swift
//  Pure Pets
//
//  Swift UIKit checkout summary surface used by Cart and Payment screens.
//

import UIKit

private enum PPPremiumCheckoutFont {
    static func regular(_ size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
        scaled(named: "Beiruti-Regular", size: size, weight: .regular, textStyle: textStyle)
    }

    static func medium(_ size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
        scaled(named: "Beiruti-Medium", size: size, weight: .medium, textStyle: textStyle)
    }

    static func bold(_ size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
        scaled(named: "Beiruti-Bold", size: size, weight: .bold, textStyle: textStyle)
    }

    static func black(_ size: CGFloat, textStyle: UIFont.TextStyle = .body) -> UIFont {
        scaled(
            named: "Beiruti-Black",
            size: size,
            weight: .black,
            textStyle: textStyle
        )
    }

    private static func scaled(named name: String,
                               size: CGFloat,
                               weight: UIFont.Weight,
                               textStyle: UIFont.TextStyle) -> UIFont {
        let baseFont = UIFont(name: name, size: size + 1) ?? UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
    }
}

private final class PPPremiumCheckoutButton: UIControl {
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !reduceMotion else {
                transform = .identity
                return
            }
            UIView.animate(
                withDuration: isHighlighted ? 0.10 : 0.20,
                delay: 0,
                usingSpringWithDamping: isHighlighted ? 1.0 : 0.74,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.974, y: 0.974)
                    : .identity
            }
        }
    }

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.78
            refreshColors()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        clipsToBounds = false
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.shadowOffset = .zero

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8
        stackView.isUserInteractionEnabled = false
        addSubview(stackView)

        titleLabel.font = UIFont(name: "GM BlackFont", size: 18) ?? PPPremiumCheckoutFont.bold(18, textStyle: .headline)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.minimumScaleFactor = 0.72
        titleLabel.numberOfLines = 1

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.color = .white

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(iconView)
        addSubview(spinner)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        refreshColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    func configure(title: String, image: UIImage?) {
        titleLabel.text = title
        iconView.image = image?.withRenderingMode(.alwaysTemplate)
        iconView.isHidden = image == nil
        accessibilityLabel = title
    }

    func setLoading(_ loading: Bool) {
        isEnabled = !loading
        stackView.alpha = loading ? 0.0 : 1.0
        if loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    func refreshColors() {
        let brand = PPPremiumCheckoutStyle.brand
        backgroundColor = isEnabled ? brand : brand.withAlphaComponent(0.55)
        layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        layer.shadowColor = UIColor.clear.cgColor
        layer.shadowOpacity = 0
    }
}

private enum PPPremiumCheckoutStyle {
    static let brand = UIColor(named: "AppPrimaryColor") ?? UIColor(red: 0.86, green: 0.17, blue: 0.38, alpha: 1.0)

    static let surface = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.128, green: 0.120, blue: 0.128, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 1.0)
    }

    static let surfaceAlt = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.045)
            : PPPremiumCheckoutStyle.brand.withAlphaComponent(0.045)
    }

    static let glassTint = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.clear
            : UIColor.clear
    }

    static let softPink = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? PPPremiumCheckoutStyle.brand.withAlphaComponent(0.16)
            : PPPremiumCheckoutStyle.brand.withAlphaComponent(0.075)
    }

    static let mutedFill = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.030)
    }

    static let stroke = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.070)
    }

    static let divider = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.075)
            : UIColor.black.withAlphaComponent(0.055)
    }
}

private final class PPPremiumCheckoutPreviewCell: UICollectionViewCell {
    static let reuseID = "PPPremiumCheckoutPreviewCell"

    private let iconShell = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.masksToBounds = true

        iconShell.translatesAutoresizingMaskIntoConstraints = false
        iconShell.layer.cornerRadius = 15
        iconShell.layer.cornerCurve = .continuous
        iconShell.layer.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = PPPremiumCheckoutStyle.brand
        iconView.image = UIImage(systemName: "bag.fill")
        iconShell.addSubview(iconView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = PPPremiumCheckoutFont.medium(11, textStyle: .caption1)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .natural
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.lineBreakMode = .byTruncatingTail

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = PPPremiumCheckoutFont.bold(10.5, textStyle: .caption2)
        metaLabel.textColor = .secondaryLabel
        metaLabel.textAlignment = .natural
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.lineBreakMode = .byTruncatingTail

        contentView.addSubview(iconShell)
        contentView.addSubview(nameLabel)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            iconShell.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            iconShell.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconShell.widthAnchor.constraint(equalToConstant: 30),
            iconShell.heightAnchor.constraint(equalToConstant: 30),

            iconView.centerXAnchor.constraint(equalTo: iconShell.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconShell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),

            nameLabel.leadingAnchor.constraint(equalTo: iconShell.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            metaLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -9)
        ])

        refreshColors()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.alpha = 1
        contentView.transform = .identity
        nameLabel.text = nil
        metaLabel.text = nil
    }

    func configure(item: CartItem) {
        let trimmedName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        nameLabel.text = trimmedName.isEmpty ? NSLocalizedString("Cart", comment: "") : trimmedName
        let quantity = max(item.quantity, 1)
        let lineTotal = item.lineSubtotal > 0 ? item.lineSubtotal : item.price * Double(quantity)
        metaLabel.text = "x\(quantity)  \(PPPremiumCheckoutCurrency.format(CGFloat(lineTotal)))"
    }

    func refreshColors() {
        contentView.backgroundColor = PPPremiumCheckoutStyle.mutedFill
        contentView.layer.borderColor = PPPremiumCheckoutStyle.stroke.cgColor
        iconShell.backgroundColor = PPPremiumCheckoutStyle.softPink
        iconView.tintColor = PPPremiumCheckoutStyle.brand
    }
}

private enum PPPremiumCheckoutCurrency {
    static func format(_ value: CGFloat) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "QAR"
        formatter.currencySymbol = "QAR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_QA")
        return formatter.string(from: NSNumber(value: Double(value))) ?? String(format: "QAR %.2f", Double(value))
    }
}

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

    private let glowContainerView = UIView()
    private let primaryGlowView = UIView()
    private let secondaryGlowView = UIView()
    private let cardView = UIView()
    private let glassMaterialView = UIVisualEffectView(effect: nil)
    private let glassTintView = UIView()
    private let contentStack = UIStackView()
    private let headerRow = UIStackView()
    private let iconShell = UIView()
    private let iconView = UIImageView()
    private let headerTextStack = UIStackView()
    private let titleLabel = UILabel()
    private let headerMetaLabel = UILabel()
    private let countLabel = UILabel()
    private let amountRow = UIStackView()
    private let amountStack = UIStackView()
    private let amountCaptionLabel = UILabel()
    private let amountLabel = UILabel()
    private let ctaButton = PPPremiumCheckoutButton()
    private let separator = UIView()
    private let detailsStack = UIStackView()
    private let itemsValueLabel = UILabel()
    private let shippingValueLabel = UILabel()
    private let previewCollection: UICollectionView
    private let trustPill = UIView()
    private let trustIcon = UIImageView()
    private let trustLabel = UILabel()

    private var didRunEntrance = false
    private var liveEffectsRunning = false
    private var wantsTrustAccent = false
    private var showsItemsPreview = false
    private var previewItems: [CartItem] = []
    private var checkoutLoading = false
    private var checkoutTitle = NSLocalizedString("Checkout", comment: "")
    private var checkoutImage: UIImage? = UIImage(systemName: "arrow.forward")
    private weak var activeAmountTransitionLabel: UILabel?
    private var amountChangeAnimator: UIViewPropertyAnimator?

    @objc public override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        previewCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        commonInit()
    }

    @objc public required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        previewCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        stopLivingEffects()
        removeTrustPulse()
        NotificationCenter.default.removeObserver(self)
    }

    private func commonInit() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        semanticContentAttribute = .unspecified

        buildView()
        buildLayout()
        updateTotalsWithItems(0, shipping: 0, showTitle: true)
        updatePreviewItems(nil)
        setCheckoutBTNTitle(checkoutTitle, image: checkoutImage)
        updateVisibility(animated: false)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopLivingEffects()
            removeTrustPulse()
        } else {
            startLivingEffectsIfNeeded()
            if wantsTrustAccent { pp_startTrustBannerShimmer() }
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        glassMaterialView.layer.cornerRadius = cardView.layer.cornerRadius
        glowContainerView.layer.cornerRadius = cardView.layer.cornerRadius
        primaryGlowView.layer.cornerRadius = primaryGlowView.bounds.width * 0.5
        secondaryGlowView.layer.cornerRadius = secondaryGlowView.bounds.width * 0.5
        updateTopOuterShadowPath()

        if !didRunEntrance, cardView.bounds.height > 0 {
            didRunEntrance = true
            runEntranceIfNeeded()
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            super.traitCollectionDidChange(previousTraitCollection)
        }
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        refreshColors()
    }

    private func buildView() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = PPPremiumCheckoutStyle.surface
        cardView.clipsToBounds = false
        cardView.layer.cornerRadius = 34
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.shadowOpacity = 0.10
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: -8)
        addSubview(cardView)

        glassMaterialView.translatesAutoresizingMaskIntoConstraints = false
        glassMaterialView.isUserInteractionEnabled = false
        glassMaterialView.clipsToBounds = true
        glassMaterialView.layer.cornerRadius = cardView.layer.cornerRadius
        glassMaterialView.layer.cornerCurve = .continuous
        cardView.addSubview(glassMaterialView)

        glassTintView.translatesAutoresizingMaskIntoConstraints = false
        glassTintView.isUserInteractionEnabled = false
        glassMaterialView.contentView.addSubview(glassTintView)

        glowContainerView.translatesAutoresizingMaskIntoConstraints = false
        glowContainerView.isUserInteractionEnabled = false
        glowContainerView.clipsToBounds = true
        cardView.addSubview(glowContainerView)

        primaryGlowView.translatesAutoresizingMaskIntoConstraints = false
        primaryGlowView.isUserInteractionEnabled = false
        primaryGlowView.isHidden = false
        primaryGlowView.alpha = 1
        primaryGlowView.layer.shadowRadius = 0
        primaryGlowView.layer.shadowOffset = .zero
        glowContainerView.addSubview(primaryGlowView)

        secondaryGlowView.translatesAutoresizingMaskIntoConstraints = false
        secondaryGlowView.isUserInteractionEnabled = false
        secondaryGlowView.isHidden = false
        secondaryGlowView.alpha = 1
        secondaryGlowView.layer.shadowRadius = 0
        secondaryGlowView.layer.shadowOffset = .zero
        glowContainerView.addSubview(secondaryGlowView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 13
        cardView.addSubview(contentStack)

        buildHeader()
        buildAmountRow()
        buildDetails()
        buildPreview()
        buildTrustPill()
        refreshColors()
    }

    private func buildHeader() {
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 10

        iconShell.translatesAutoresizingMaskIntoConstraints = false
        iconShell.layer.cornerRadius = 19
        iconShell.layer.cornerCurve = .continuous
        iconShell.layer.borderWidth = 1
        iconShell.layer.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: "bag.fill")
        iconShell.addSubview(iconView)

        titleLabel.font = PPPremiumCheckoutFont.bold(17, textStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .natural
        titleLabel.text = NSLocalizedString("cartTitle", comment: "")
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.minimumScaleFactor = 0.78

        headerMetaLabel.font = PPPremiumCheckoutFont.medium(11.5, textStyle: .caption1)
        headerMetaLabel.textColor = .secondaryLabel
        headerMetaLabel.textAlignment = .natural
        headerMetaLabel.text = NSLocalizedString("Subtotal", comment: "")
        headerMetaLabel.adjustsFontSizeToFitWidth = true
        headerMetaLabel.adjustsFontForContentSizeCategory = true
        headerMetaLabel.minimumScaleFactor = 0.74
        headerMetaLabel.numberOfLines = 1

        headerTextStack.axis = .vertical
        headerTextStack.alignment = .fill
        headerTextStack.spacing = 1
        headerTextStack.addArrangedSubview(titleLabel)
        headerTextStack.addArrangedSubview(headerMetaLabel)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        countLabel.font = PPPremiumCheckoutFont.bold(13, textStyle: .caption1)
        countLabel.textAlignment = .center
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.layer.cornerRadius = 15
        countLabel.layer.cornerCurve = .continuous
        countLabel.layer.borderWidth = 1
        countLabel.layer.masksToBounds = true
        countLabel.isHidden = true

        headerRow.addArrangedSubview(iconShell)
        headerRow.addArrangedSubview(headerTextStack)
        headerRow.addArrangedSubview(spacer)
        headerRow.addArrangedSubview(countLabel)
        contentStack.addArrangedSubview(headerRow)
    }

    private func buildAmountRow() {
        amountRow.axis = .horizontal
        amountRow.alignment = .center
        amountRow.spacing = 12

        amountStack.axis = .vertical
        amountStack.alignment = .fill
        amountStack.spacing = 1

        amountCaptionLabel.font = PPPremiumCheckoutFont.medium(12, textStyle: .subheadline)
        amountCaptionLabel.textColor = .secondaryLabel
        amountCaptionLabel.textAlignment = .natural
        amountCaptionLabel.adjustsFontForContentSizeCategory = true
        amountCaptionLabel.text = NSLocalizedString("Subtotal", comment: "")

        amountLabel.font = UIFont(name: "GM BlackFont", size: 38) ?? PPPremiumCheckoutFont.black(34, textStyle: .largeTitle)
        amountLabel.textColor = .label
        amountLabel.textAlignment = .natural
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.adjustsFontForContentSizeCategory = true
        amountLabel.minimumScaleFactor = 0.52
        amountLabel.numberOfLines = 1
        amountLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        amountStack.addArrangedSubview(amountCaptionLabel)
        amountStack.addArrangedSubview(amountLabel)

        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.addTarget(self, action: #selector(didTapCheckout), for: .touchUpInside)
        ctaButton.setContentHuggingPriority(.required, for: .horizontal)
        ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        amountRow.addArrangedSubview(amountStack)
        amountRow.addArrangedSubview(ctaButton)
        contentStack.addArrangedSubview(amountRow)

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.layer.cornerRadius = 0.5
        separator.layer.cornerCurve = .continuous
        contentStack.addArrangedSubview(separator)
    }

    private func buildDetails() {
        detailsStack.axis = .vertical
        detailsStack.alignment = .fill
        detailsStack.spacing = 8
        detailsStack.addArrangedSubview(detailRow(title: NSLocalizedString("Selected Items", comment: ""), valueLabel: itemsValueLabel))
        detailsStack.addArrangedSubview(detailRow(title: NSLocalizedString("Shipping Fee", comment: ""), valueLabel: shippingValueLabel))
        contentStack.addArrangedSubview(detailsStack)
    }

    private func detailRow(title: String, valueLabel: UILabel) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.layer.cornerRadius = 18
        row.layer.cornerCurve = .continuous
        row.layer.borderWidth = 1
        row.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.font = PPPremiumCheckoutFont.medium(13, textStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .natural
        titleLabel.text = title
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.minimumScaleFactor = 0.74

        valueLabel.font = PPPremiumCheckoutFont.bold(13.5, textStyle: .subheadline)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .natural
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.minimumScaleFactor = 0.72
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        row.addSubview(stack)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: row.topAnchor),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
        return row
    }

    private func buildPreview() {
        previewCollection.translatesAutoresizingMaskIntoConstraints = false
        previewCollection.backgroundColor = .clear
        previewCollection.showsHorizontalScrollIndicator = false
        previewCollection.dataSource = self
        previewCollection.delegate = self
        previewCollection.clipsToBounds = false
        previewCollection.register(PPPremiumCheckoutPreviewCell.self, forCellWithReuseIdentifier: PPPremiumCheckoutPreviewCell.reuseID)
        contentStack.addArrangedSubview(previewCollection)
    }

    private func buildTrustPill() {
        trustPill.translatesAutoresizingMaskIntoConstraints = false
        trustPill.layer.cornerRadius = 18
        trustPill.layer.cornerCurve = .continuous
        trustPill.layer.borderWidth = 1
        trustPill.layer.masksToBounds = true

        trustIcon.translatesAutoresizingMaskIntoConstraints = false
        trustIcon.contentMode = .scaleAspectFit
        trustIcon.image = UIImage(systemName: "checkmark.shield.fill")

        trustLabel.translatesAutoresizingMaskIntoConstraints = false
        trustLabel.font = PPPremiumCheckoutFont.medium(12.5, textStyle: .footnote)
        trustLabel.textColor = .secondaryLabel
        trustLabel.textAlignment = .natural
        trustLabel.adjustsFontSizeToFitWidth = true
        trustLabel.adjustsFontForContentSizeCategory = true
        trustLabel.minimumScaleFactor = 0.72
        trustLabel.numberOfLines = 1
        trustLabel.text = NSLocalizedString("Securecheckout", comment: "")

        trustPill.addSubview(trustIcon)
        trustPill.addSubview(trustLabel)
        contentStack.addArrangedSubview(trustPill)
    }

    private func buildLayout() {
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            glassMaterialView.topAnchor.constraint(equalTo: cardView.topAnchor),
            glassMaterialView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            glassMaterialView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            glassMaterialView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            glassTintView.topAnchor.constraint(equalTo: glassMaterialView.contentView.topAnchor),
            glassTintView.leadingAnchor.constraint(equalTo: glassMaterialView.contentView.leadingAnchor),
            glassTintView.trailingAnchor.constraint(equalTo: glassMaterialView.contentView.trailingAnchor),
            glassTintView.bottomAnchor.constraint(equalTo: glassMaterialView.contentView.bottomAnchor),

            glowContainerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            glowContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            glowContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            glowContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            primaryGlowView.widthAnchor.constraint(equalToConstant: 118),
            primaryGlowView.heightAnchor.constraint(equalTo: primaryGlowView.widthAnchor),
            primaryGlowView.topAnchor.constraint(equalTo: glowContainerView.topAnchor, constant: -34),
            primaryGlowView.trailingAnchor.constraint(equalTo: glowContainerView.trailingAnchor, constant: 34),

            secondaryGlowView.widthAnchor.constraint(equalToConstant: 104),
            secondaryGlowView.heightAnchor.constraint(equalTo: secondaryGlowView.widthAnchor),
            secondaryGlowView.bottomAnchor.constraint(equalTo: glowContainerView.bottomAnchor, constant: 32),
            secondaryGlowView.leadingAnchor.constraint(equalTo: glowContainerView.leadingAnchor, constant: -32),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -30),

            iconShell.widthAnchor.constraint(equalToConstant: 38),
            iconShell.heightAnchor.constraint(equalToConstant: 38),
            iconView.centerXAnchor.constraint(equalTo: iconShell.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconShell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 46),
            countLabel.heightAnchor.constraint(equalToConstant: 30),

            ctaButton.heightAnchor.constraint(equalToConstant: 54),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 148),
            ctaButton.widthAnchor.constraint(lessThanOrEqualToConstant: 218),

            separator.heightAnchor.constraint(equalToConstant: 0.75),
            previewCollection.heightAnchor.constraint(equalToConstant: 66),

            trustPill.heightAnchor.constraint(equalToConstant: 36),
            trustIcon.leadingAnchor.constraint(equalTo: trustPill.leadingAnchor, constant: 13),
            trustIcon.centerYAnchor.constraint(equalTo: trustPill.centerYAnchor),
            trustIcon.widthAnchor.constraint(equalToConstant: 18),
            trustIcon.heightAnchor.constraint(equalToConstant: 18),
            trustLabel.leadingAnchor.constraint(equalTo: trustIcon.trailingAnchor, constant: 9),
            trustLabel.trailingAnchor.constraint(equalTo: trustPill.trailingAnchor, constant: -13),
            trustLabel.topAnchor.constraint(equalTo: trustPill.topAnchor),
            trustLabel.bottomAnchor.constraint(equalTo: trustPill.bottomAnchor)
        ])
    }

    private func refreshColors() {
        let brand = PPPremiumCheckoutStyle.brand
        cardView.backgroundColor = PPPremiumCheckoutStyle.surface
        cardView.layer.borderColor = PPPremiumCheckoutStyle.stroke.cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.26 : 0.10
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: -8)

        glassMaterialView.effect = nil
        glassTintView.backgroundColor = PPPremiumCheckoutStyle.glassTint

        let isDark = traitCollection.userInterfaceStyle == .dark
        glowContainerView.backgroundColor = .clear
        primaryGlowView.isHidden = false
        primaryGlowView.alpha = 1
        primaryGlowView.backgroundColor = brand.withAlphaComponent(isDark ? 0.16 : 0.10)
        primaryGlowView.layer.shadowColor = UIColor.clear.cgColor
        primaryGlowView.layer.shadowOpacity = 0
        primaryGlowView.layer.shadowRadius = 0
        primaryGlowView.layer.shadowOffset = .zero

        secondaryGlowView.isHidden = false
        secondaryGlowView.alpha = 0.95
        secondaryGlowView.backgroundColor = brand.withAlphaComponent(isDark ? 0.13 : 0.08)
        secondaryGlowView.layer.shadowColor = UIColor.clear.cgColor
        secondaryGlowView.layer.shadowOpacity = 0
        secondaryGlowView.layer.shadowRadius = 0
        secondaryGlowView.layer.shadowOffset = .zero

        iconShell.backgroundColor = PPPremiumCheckoutStyle.softPink
        iconShell.layer.borderColor = brand.withAlphaComponent(0.14).cgColor
        iconView.tintColor = brand

        countLabel.textColor = brand
        countLabel.backgroundColor = PPPremiumCheckoutStyle.softPink
        countLabel.layer.borderColor = brand.withAlphaComponent(0.18).cgColor

        separator.backgroundColor = PPPremiumCheckoutStyle.divider
        for row in detailsStack.arrangedSubviews {
            row.backgroundColor = PPPremiumCheckoutStyle.mutedFill
            row.layer.borderColor = PPPremiumCheckoutStyle.stroke.cgColor
        }

        trustPill.backgroundColor = PPPremiumCheckoutStyle.softPink
        trustPill.layer.borderColor = brand.withAlphaComponent(0.18).cgColor
        trustIcon.tintColor = brand

        ctaButton.refreshColors()
        previewCollection.visibleCells.forEach { cell in
            (cell as? PPPremiumCheckoutPreviewCell)?.refreshColors()
        }
    }

    private func updateTopOuterShadowPath() {
        guard cardView.bounds.width > 0 else {
            cardView.layer.shadowPath = nil
            return
        }

        let shadowWidth = max(cardView.bounds.width - 56, 0)
        let shadowX = (cardView.bounds.width - shadowWidth) * 0.5
        let shadowRect = CGRect(x: shadowX, y: -1, width: shadowWidth, height: 2)
        cardView.layer.shadowPath = UIBezierPath(roundedRect: shadowRect, cornerRadius: 1).cgPath
    }

    @objc(updateTotalsWithItems:shipping:showTitle:)
    func updateTotalsWithItems(_ itemsTotal: CGFloat, shipping shippingFee: CGFloat, showTitle _: Bool) {
        let previousSubtotal = self.subtotal
        let oldText = amountLabel.text

        self.itemsTotal = itemsTotal
        self.shippingFee = shippingFee
        self.subtotal = itemsTotal + shippingFee

        itemsValueLabel.text = PPPremiumCheckoutCurrency.format(itemsTotal)
        shippingValueLabel.text = PPPremiumCheckoutCurrency.format(shippingFee)
        amountCaptionLabel.isHidden = false

        let newText = PPPremiumCheckoutCurrency.format(subtotal)
        if let oldText = oldText, oldText != newText {
            animateAmountChange(
                from: oldText,
                to: newText,
                increasing: subtotal >= previousSubtotal
            )
        } else {
            amountLabel.text = newText
        }

        updateVisibility(animated: window != nil)
    }

    private func animateAmountChange(from oldText: String, to newText: String, increasing: Bool) {
        amountChangeAnimator?.stopAnimation(true)
        amountChangeAnimator = nil
        activeAmountTransitionLabel?.removeFromSuperview()
        activeAmountTransitionLabel = nil
        amountLabel.layer.removeAllAnimations()

        guard window != nil, !UIAccessibility.isReduceMotionEnabled else {
            amountLabel.text = newText
            amountLabel.alpha = 1
            amountLabel.transform = .identity
            return
        }

        amountStack.layoutIfNeeded()

        let oldValueLabel = UILabel()
        oldValueLabel.translatesAutoresizingMaskIntoConstraints = false
        oldValueLabel.font = amountLabel.font
        oldValueLabel.textColor = amountLabel.textColor
        oldValueLabel.textAlignment = amountLabel.textAlignment
        oldValueLabel.adjustsFontSizeToFitWidth = amountLabel.adjustsFontSizeToFitWidth
        oldValueLabel.adjustsFontForContentSizeCategory = amountLabel.adjustsFontForContentSizeCategory
        oldValueLabel.minimumScaleFactor = amountLabel.minimumScaleFactor
        oldValueLabel.numberOfLines = amountLabel.numberOfLines
        oldValueLabel.text = oldText
        oldValueLabel.isAccessibilityElement = false
        amountStack.addSubview(oldValueLabel)
        NSLayoutConstraint.activate([
            oldValueLabel.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor),
            oldValueLabel.trailingAnchor.constraint(equalTo: amountLabel.trailingAnchor),
            oldValueLabel.topAnchor.constraint(equalTo: amountLabel.topAnchor),
            oldValueLabel.bottomAnchor.constraint(equalTo: amountLabel.bottomAnchor)
        ])
        activeAmountTransitionLabel = oldValueLabel

        let travel: CGFloat = 13
        let oldExitY = increasing ? -travel : travel
        let newEntryY = increasing ? travel : -travel
        let originalColor = amountLabel.textColor ?? .label

        amountLabel.text = newText
        amountLabel.alpha = 0
        amountLabel.transform = CGAffineTransform(translationX: 0, y: newEntryY)
            .scaledBy(x: 0.992, y: 0.992)

        UIView.animate(
            withDuration: 0.11,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
            animations: {
                self.amountLabel.textColor = PPPremiumCheckoutStyle.brand
                self.amountCaptionLabel.textColor = PPPremiumCheckoutStyle.brand
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.24,
                    delay: 0.06,
                    options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
                    animations: {
                        self.amountLabel.textColor = originalColor
                        self.amountCaptionLabel.textColor = .secondaryLabel
                    },
                    completion: nil
                )
            }
        )

        let animator = UIViewPropertyAnimator(duration: 0.30, dampingRatio: 0.82) {
            oldValueLabel.alpha = 0
            oldValueLabel.transform = CGAffineTransform(translationX: 0, y: oldExitY)
                .scaledBy(x: 0.992, y: 0.992)
            self.amountLabel.alpha = 1
            self.amountLabel.transform = .identity
        }
        animator.addCompletion { [weak self, weak oldValueLabel] _ in
            oldValueLabel?.removeFromSuperview()
            guard let self = self else { return }
            self.activeAmountTransitionLabel = nil
            self.amountChangeAnimator = nil
            self.amountLabel.alpha = 1
            self.amountLabel.transform = .identity
            self.amountLabel.textColor = originalColor
            self.amountCaptionLabel.textColor = .secondaryLabel
        }
        amountChangeAnimator = animator
        animator.startAnimation()
    }

    @objc(setShowsItemsPreview:)
    func setShowsItemsPreview(_ showsItemsPreview: Bool) {
        self.showsItemsPreview = showsItemsPreview
        updateVisibility(animated: window != nil)
    }

    @objc(updatePreviewItems:)
    func updatePreviewItems(_ items: [CartItem]?) {
        previewItems = items ?? []
        let totalQuantity = previewItems.reduce(0) { $0 + max($1.quantity, 0) }
        countLabel.text = "\(totalQuantity)"
        countLabel.isHidden = totalQuantity <= 0
        previewCollection.reloadData()
        updateVisibility(animated: window != nil)
    }

    @objc(setCardBackgroundImage:)
    func setCardBackgroundImage(_ image: UIImage?) {
        setNeedsLayout()
    }

    @objc(setCheckoutBTNTitle:image:)
    func setCheckoutBTNTitle(_ title: String?, image: UIImage?) {
        checkoutTitle = (title?.isEmpty == false) ? title! : NSLocalizedString("Checkout", comment: "")
        checkoutImage = image ?? UIImage(systemName: effectiveUserInterfaceLayoutDirection == .rightToLeft ? "arrow.left" : "arrow.right")
        ctaButton.configure(title: checkoutTitle, image: checkoutImage)
    }

    @objc(setCheckoutLoading:)
    func setCheckoutLoading(_ loading: Bool) {
        checkoutLoading = loading
        ctaButton.setLoading(loading)
    }

    @objc(skipCardEntranceAnimation)
    func skipCardEntranceAnimation() {
        didRunEntrance = true
        cardView.alpha = 1
        cardView.transform = .identity
    }

    @objc(pp_startTrustBannerShimmer)
    func pp_startTrustBannerShimmer() {
        wantsTrustAccent = true
        startTrustPulseIfNeeded()
    }

    @objc(pp_stopTrustBannerShimmer)
    func pp_stopTrustBannerShimmer() {
        wantsTrustAccent = false
        removeTrustPulse()
    }

    private func startTrustPulseIfNeeded() {
        guard window != nil, !UIAccessibility.isReduceMotionEnabled else {
            trustIcon.transform = .identity
            trustPill.alpha = 1
            return
        }

        trustIcon.layer.removeAnimation(forKey: "pp_checkout_trust_icon_breath")
        trustPill.layer.removeAnimation(forKey: "pp_checkout_trust_pill_breath")

        let iconPulse = CABasicAnimation(keyPath: "transform.scale")
        iconPulse.fromValue = 0.98
        iconPulse.toValue = 1.08
        iconPulse.duration = 3.8
        iconPulse.autoreverses = true
        iconPulse.repeatCount = .greatestFiniteMagnitude
        iconPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        trustIcon.layer.add(iconPulse, forKey: "pp_checkout_trust_icon_breath")

        let pillPulse = CABasicAnimation(keyPath: "opacity")
        pillPulse.fromValue = 0.88
        pillPulse.toValue = 1.0
        pillPulse.duration = 4.2
        pillPulse.autoreverses = true
        pillPulse.repeatCount = .greatestFiniteMagnitude
        pillPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        trustPill.layer.add(pillPulse, forKey: "pp_checkout_trust_pill_breath")
    }

    private func removeTrustPulse() {
        trustIcon.layer.removeAnimation(forKey: "pp_checkout_trust_icon_breath")
        trustPill.layer.removeAnimation(forKey: "pp_checkout_trust_pill_breath")
        trustIcon.transform = .identity
        trustPill.alpha = 1
    }

    private func updateVisibility(animated: Bool) {
        let shouldShowPreview = showsItemsPreview && !previewItems.isEmpty
        let shouldShowDetails = showDetails && !shouldShowPreview
        let shouldShowTrust = !previewItems.isEmpty || subtotal > 0.009

        if shouldShowPreview { previewCollection.isHidden = false }
        if shouldShowDetails { detailsStack.isHidden = false }
        if shouldShowTrust { trustPill.isHidden = false }

        let changes = {
            self.previewCollection.alpha = shouldShowPreview ? 1 : 0
            self.detailsStack.alpha = shouldShowDetails ? 1 : 0
            self.trustPill.alpha = shouldShowTrust ? 1 : 0
            self.previewCollection.transform = shouldShowPreview ? .identity : CGAffineTransform(translationX: 0, y: 6)
            self.detailsStack.transform = shouldShowDetails ? .identity : CGAffineTransform(translationX: 0, y: -4)
            self.separator.alpha = (shouldShowPreview || shouldShowDetails) ? 0.70 : 0.20
            self.layoutIfNeeded()
        }

        let completion = {
            self.previewCollection.isHidden = !shouldShowPreview
            self.detailsStack.isHidden = !shouldShowDetails
            self.trustPill.isHidden = !shouldShowTrust
            self.previewCollection.transform = .identity
            self.detailsStack.transform = .identity
        }

        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            changes()
            completion()
            return
        }

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes
        ) { _ in
            completion()
        }
    }

    private func runEntranceIfNeeded() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            cardView.alpha = 1
            cardView.transform = .identity
            return
        }

        cardView.alpha = 0
        cardView.transform = CGAffineTransform(translationX: 0, y: 22).scaledBy(x: 0.985, y: 0.985)
        UIView.animate(
            withDuration: 0.56,
            delay: 0.04,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    private func startGlowBreathingIfNeeded() {
        primaryGlowView.layer.removeAnimation(forKey: "pp_checkout_primary_glow_breath")
        secondaryGlowView.layer.removeAnimation(forKey: "pp_checkout_secondary_glow_breath")

        let primaryPulse = CABasicAnimation(keyPath: "opacity")
        primaryPulse.fromValue = 0.82
        primaryPulse.toValue = 1.0
        primaryPulse.duration = 5.8
        primaryPulse.autoreverses = true
        primaryPulse.repeatCount = .greatestFiniteMagnitude
        primaryPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        primaryGlowView.layer.add(primaryPulse, forKey: "pp_checkout_primary_glow_breath")

        let secondaryPulse = CABasicAnimation(keyPath: "opacity")
        secondaryPulse.fromValue = 0.68
        secondaryPulse.toValue = 0.95
        secondaryPulse.duration = 6.6
        secondaryPulse.autoreverses = true
        secondaryPulse.repeatCount = .greatestFiniteMagnitude
        secondaryPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        secondaryGlowView.layer.add(secondaryPulse, forKey: "pp_checkout_secondary_glow_breath")
    }

    private func startLivingEffectsIfNeeded() {
        guard window != nil, !liveEffectsRunning else { return }
        primaryGlowView.isHidden = false
        secondaryGlowView.isHidden = false
        primaryGlowView.alpha = 1
        secondaryGlowView.alpha = 0.95
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        liveEffectsRunning = true
        startGlowBreathingIfNeeded()
        if wantsTrustAccent {
            startTrustPulseIfNeeded()
        }
    }

    private func stopLivingEffects() {
        liveEffectsRunning = false
        [primaryGlowView, secondaryGlowView].forEach { view in
            view.layer.removeAllAnimations()
            view.transform = .identity
            view.isHidden = false
        }
        primaryGlowView.alpha = 1
        secondaryGlowView.alpha = 0.95
        removeTrustPulse()
    }

    @objc private func didTapCheckout() {
        guard !checkoutLoading else { return }
        if !UIAccessibility.isReduceMotionEnabled {
            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.prepare()
            feedback.impactOccurred()
        }
        onTapCheckOut?()
    }

    @objc private func reduceMotionDidChange() {
        if UIAccessibility.isReduceMotionEnabled {
            stopLivingEffects()
            removeTrustPulse()
            cardView.transform = .identity
            ctaButton.transform = .identity
        } else {
            startLivingEffectsIfNeeded()
            if wantsTrustAccent { pp_startTrustBannerShimmer() }
        }
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        previewItems.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PPPremiumCheckoutPreviewCell.reuseID,
            for: indexPath
        ) as? PPPremiumCheckoutPreviewCell
        guard let cell, indexPath.item < previewItems.count else {
            return UICollectionViewCell()
        }
        cell.configure(item: previewItems[indexPath.item])
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: min(170, max(128, collectionView.bounds.width * 0.44)), height: 62)
    }

    public func collectionView(_ collectionView: UICollectionView,
                               willDisplay cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            cell.contentView.alpha = 1
            cell.contentView.transform = .identity
            return
        }
        cell.contentView.alpha = 0
        cell.contentView.transform = CGAffineTransform(translationX: 0, y: 7).scaledBy(x: 0.97, y: 0.97)
        UIView.animate(
            withDuration: 0.32,
            delay: min(Double(indexPath.item), 5) * 0.032,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            cell.contentView.alpha = 1
            cell.contentView.transform = .identity
        }
    }
}
