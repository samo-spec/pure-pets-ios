//
//  PPSectionHeaderSwiftUI.swift
//  Pure Pets
//
//  SwiftUI-owned home-feed section header.
//

import SwiftUI
import UIKit

private enum PPSectionHeaderMetrics {
    static let contentVerticalInset: CGFloat = 4
    static let accentWidth: CGFloat = 6
    static let accentHeight: CGFloat = 6
    static let actionHeight: CGFloat = 36
    static let actionMinWidth: CGFloat = 44
    static let actionMaxWidth: CGFloat = 196
    static let titleTouchHeight: CGFloat = 44
    static let contentSpacing: CGFloat = 10
    static let titleToActionSpacing: CGFloat = 12
    static let subtitleSpacing: CGFloat = 3
    static let cornerRadius: CGFloat = 14
}

private enum PPSectionHeaderPalette {
    static var accent: UIColor {
        UIColor(named: "AppPrimaryColor") ?? .systemTeal
    }
}

private struct PPSectionHeaderState {
    var subtitleVisible = false
    var showsAction = false
    var usesCirclePresentation = false
    var surfaceDecorationActive = true
    var rightToLeft = Language.isRTL()
    var pressed = false
    var expanded = false
}

private final class PPSectionHeaderStore: ObservableObject {
    @Published private(set) var state = PPSectionHeaderState()

    func configure(
        subtitleVisible: Bool,
        showsAction: Bool,
        usesCirclePresentation: Bool,
        surfaceDecorationActive: Bool,
        rightToLeft: Bool,
        animated: Bool
    ) {
        mutate(animated: animated) {
            state.subtitleVisible = subtitleVisible
            state.showsAction = showsAction
            state.usesCirclePresentation = usesCirclePresentation
            state.surfaceDecorationActive = surfaceDecorationActive
            state.rightToLeft = rightToLeft
        }
    }

    func setSurfaceDecorationActive(_ active: Bool, animated: Bool) {
        mutate(animated: animated) {
            state.surfaceDecorationActive = active
        }
    }

    func setRightToLeft(_ rightToLeft: Bool) {
        mutate(animated: false) {
            state.rightToLeft = rightToLeft
        }
    }

    func setPressed(_ pressed: Bool, animated: Bool) {
        mutate(animated: animated) {
            state.pressed = pressed
        }
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        mutate(animated: animated) {
            state.expanded = expanded
        }
    }

    private func mutate(animated: Bool, _ changes: () -> Void) {
        guard animated else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
            return
        }

        let animation: Animation = UIAccessibility.isReduceMotionEnabled
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.24, dampingFraction: 0.88, blendDuration: 0)
        withAnimation(animation, changes)
    }
}

private enum PPSectionHeaderHomeSectionRaw {
    static let mainKinds = 5
    static let accessories = 7
}

@objc(PPSectionHeaderSwiftUI)
public final class PPSectionHeaderSwiftUI: UICollectionReusableView, UIGestureRecognizerDelegate {
    @objc public var titleLabel: UILabel { swiftUIHostView.titleLabel }
    @objc public var subtitleLabel: UILabel { swiftUIHostView.subtitleLabel }
    @objc public var actionButton: UIButton { swiftUIHostView.actionButton }

    @objc public var onTap: (() -> Void)?
    @objc public var onTapMenu: ((Int, Any) -> Void)?

    private let swiftUIHostView = PPSectionHeaderHostingView(frame: .zero)
    private var isExpanded = false
    private var actionButtonUsesCirclePresentation = false
    private var surfaceDecorationActive = true
    private var currentSubtitleVisible = false
    private var currentSectionRawValue = 0
    private var lastActionTimestamp: CFTimeInterval = 0
    private var actionAccessibilityTitle: String?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        buildUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
    }

    private func buildUI() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        preservesSuperviewLayoutMargins = true
        isAccessibilityElement = false

        swiftUIHostView.translatesAutoresizingMaskIntoConstraints = false
        swiftUIHostView.backgroundColor = .clear
        swiftUIHostView.isUserInteractionEnabled = true
        swiftUIHostView.clipsToBounds = false
        swiftUIHostView.layer.masksToBounds = false
        addSubview(swiftUIHostView)

        NSLayoutConstraint.activate([
            swiftUIHostView.leadingAnchor.constraint(equalTo: leadingAnchor),
            swiftUIHostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            swiftUIHostView.topAnchor.constraint(equalTo: topAnchor),
            swiftUIHostView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        prepareContractControls()
        installTapGesture()
        syncHost(animated: false)
    }

    private func prepareContractControls() {
        titleLabel.font = titleFont()
        titleLabel.textColor = titleColor()
        titleLabel.textAlignment = Language.alignmentForCurrentLanguage()
        titleLabel.numberOfLines = usesAccessibilityTextSize ? 2 : 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.allowsDefaultTighteningForTruncation = true
        titleLabel.accessibilityTraits = .header

        subtitleLabel.font = subtitleFont()
        subtitleLabel.textColor = subtitleColor()
        subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage()
        subtitleLabel.numberOfLines = 2
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.isHidden = true

        actionButton.isHidden = true
        actionButton.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        actionButton.clipsToBounds = true
        actionButton.layer.cornerRadius = PPSectionHeaderMetrics.actionHeight * 0.5
        actionButton.layer.cornerCurve = .continuous
        actionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        actionButton.titleLabel?.minimumScaleFactor = 0.88
        actionButton.accessibilityTraits = .button
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        actionButton.configuration = baseActionButtonConfiguration()
    }

    private func installTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(actionTapped))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    private var usesAccessibilityTextSize: Bool {
        traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    private func baseActionButtonConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
        config.imagePadding = 5
        config.imagePlacement = .trailing
        config.baseForegroundColor = actionForegroundColor()

        var background = UIBackgroundConfiguration.clear()
        background.cornerRadius = PPSectionHeaderMetrics.actionHeight * 0.5
        background.strokeWidth = 0
        background.strokeColor = .clear
        background.backgroundColor = .clear
        config.background = background

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 11.5, weight: .regular, scale: .medium)
        config.image = UIImage(systemName: "chevron.down", withConfiguration: symbolConfig)?
            .withTintColor(actionForegroundColor(), renderingMode: .alwaysTemplate)
        return config
    }

    private func actionButtonConfiguration(subtitleVisible: Bool) -> UIButton.Configuration {
        var config = baseActionButtonConfiguration()
        config.imagePlacement = .trailing
        config.imagePadding = subtitleVisible ? 0 : 5
        config.contentInsets = subtitleVisible
            ? NSDirectionalEdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 6)
            : NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)

        var background = config.background
        background.cornerRadius = PPSectionHeaderMetrics.actionHeight * 0.5
        background.strokeWidth = 0
        background.strokeColor = .clear
        background.backgroundColor = .clear
        config.background = background
        return config
    }

    private func refreshAppearance() {
        titleLabel.textColor = titleColor()
        subtitleLabel.textColor = subtitleColor()

        var config = actionButton.configuration ?? baseActionButtonConfiguration()
        var background = config.background
        background.cornerRadius = PPSectionHeaderMetrics.actionHeight * 0.5
        background.strokeWidth = 0
        background.strokeColor = .clear
        background.backgroundColor = .clear
        config.background = background
        config.cornerStyle = .capsule
        config.baseForegroundColor = actionForegroundColor()
        actionButton.configuration = config
        actionButton.layer.cornerRadius = PPSectionHeaderMetrics.actionHeight * 0.5
        actionButton.layer.cornerCurve = .continuous
        syncHost(animated: false)
    }

    private func actionForegroundColor() -> UIColor {
        .secondaryLabel
    }

    private func titleColor() -> UIColor {
        .label
    }

    private func subtitleColor() -> UIColor {
        UIColor(named: "SecondaryTextColor") ?? .secondaryLabel
    }

    private func titleFont() -> UIFont {
        let font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: font, maximumPointSize: 22)
    }

    private func subtitleFont() -> UIFont {
        let font = UIFont.systemFont(ofSize: 13, weight: .regular)
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: font, maximumPointSize: 19)
    }

    private func actionFont() -> UIFont {
        let font = UIFont.systemFont(ofSize: 12, weight: .medium)
        return UIFontMetrics(forTextStyle: .caption1).scaledFont(for: font, maximumPointSize: 16)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        swiftUIHostView.refreshForCurrentBounds()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        titleLabel.numberOfLines = usesAccessibilityTextSize ? 2 : 1
        titleLabel.font = titleFont()
        subtitleLabel.font = subtitleFont()
        applySemanticDirection()
        if let previousTraitCollection,
           traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshAppearance()
        } else {
            syncHost(animated: false)
        }
    }

    public override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard let attrs = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
            return layoutAttributes
        }
        if layoutAttributes.frame.size.height <= 45 {
            attrs.frame = layoutAttributes.frame
            return attrs
        }

        let size = systemLayoutSizeFitting(
            CGSize(width: attrs.size.width, height: UIView.noIntrinsicMetric),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        var frame = attrs.frame
        let fittingHeight = size.height.isFinite ? ceil(size.height) : 0
        frame.size.height = max(fittingHeight, layoutAttributes.frame.size.height)
        attrs.frame = frame
        return attrs
    }

    public override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        layer.zPosition = max(CGFloat(layoutAttributes.zIndex), 2)
        setNeedsLayout()
    }

    @objc public func hide() {
        actionButton.isHidden = true
        syncHost(animated: false)
        updateAccessibility()
    }

    @objc(setSurfaceDecorationActive:animated:)
    public func setSurfaceDecorationActive(_ active: Bool, animated: Bool) {
        let changed = surfaceDecorationActive != active
        surfaceDecorationActive = active
        swiftUIHostView.setSurfaceDecorationActive(active, animated: animated && changed)
    }

    @objc(configureWithTitle:actionTitle:iconName:menu:ppHomeSection:)
    public func configure(
        title: String?,
        actionTitle: String?,
        iconName: String?,
        menu: UIMenu?,
        ppHomeSection: PPHomeSection
    ) {
        configure(
            title: title,
            subtitle: nil,
            actionTitle: actionTitle,
            iconName: iconName,
            menu: menu,
            ppHomeSection: ppHomeSection
        )
    }

    @objc(configureWithTitle:subtitle:actionTitle:iconName:menu:ppHomeSection:)
    public func configure(
        title: String?,
        subtitle: String?,
        actionTitle: String?,
        iconName: String?,
        menu: UIMenu?,
        ppHomeSection: PPHomeSection
    ) {
        currentSectionRawValue = ppHomeSection.rawValue
        titleLabel.text = title

        let hasSubtitle = !(subtitle?.isEmpty ?? true)
        currentSubtitleVisible = hasSubtitle
        subtitleLabel.text = hasSubtitle ? subtitle : nil
        subtitleLabel.isHidden = !hasSubtitle

        if !isMainKindsSection {
            isExpanded = false
            actionButton.imageView?.transform = .identity
        }

        applySemanticDirection()
        actionButton.imageView?.transform = .identity
        applyActionButtonPresentation(
            actionTitle: actionTitle,
            iconName: iconName,
            menu: menu,
            sectionRawValue: currentSectionRawValue,
            subtitleVisible: hasSubtitle
        )
        configureMenu(menu)
        refreshAppearance()
        updateAccessibility()

        if isMainKindsSection {
            setExpanded(isExpanded, animated: false)
        }

        setNeedsLayout()
    }

    private var isMainKindsSection: Bool {
        currentSectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds
    }

    private func applyActionButtonPresentation(
        actionTitle: String?,
        iconName: String?,
        menu: UIMenu?,
        sectionRawValue: Int,
        subtitleVisible: Bool
    ) {
        actionButton.isHidden = false

        let forceTitleAction =
            sectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds ||
            sectionRawValue == PPSectionHeaderHomeSectionRaw.accessories
        let usesCirclePresentation = subtitleVisible && !forceTitleAction
        actionButtonUsesCirclePresentation = usesCirclePresentation

        let resolvedActionTitle = (actionTitle?.isEmpty == false)
            ? actionTitle!
            : (Language.get("ShowAll", alter: nil) ?? "Show All")
        var resolvedIconName = (iconName?.isEmpty == false) ? iconName! : "arrow.forward"
        if sectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds &&
            !usesCirclePresentation &&
            (iconName?.isEmpty ?? true) {
            resolvedIconName = isExpanded ? "chevron.up" : "chevron.down"
        }
        if usesCirclePresentation {
            resolvedIconName = "arrow.forward"
        }

        actionAccessibilityTitle = resolvedActionTitle

        var config = actionButtonConfiguration(subtitleVisible: usesCirclePresentation)
        applyIcon(
            named: resolvedIconName,
            to: &config,
            sectionRawValue: sectionRawValue,
            circlePresentation: usesCirclePresentation
        )

        if usesCirclePresentation {
            config.attributedTitle = nil
            config.title = nil
        } else {
            config.attributedTitle = nil
            config.title = resolvedActionTitle
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak self] incoming in
                var outgoing = incoming
                outgoing.font = self?.actionFont() ?? UIFont.systemFont(ofSize: 12, weight: .medium)
                outgoing.foregroundColor = self?.actionForegroundColor() ?? .secondaryLabel
                return outgoing
            }
        }

        actionButton.configuration = config
        actionButton.invalidateIntrinsicContentSize()
        actionButton.setNeedsUpdateConfiguration()
        actionButton.setNeedsLayout()
        syncHost(animated: false)
        _ = menu
    }

    private func applyIcon(
        named iconName: String?,
        to config: inout UIButton.Configuration,
        sectionRawValue: Int,
        circlePresentation: Bool
    ) {
        let pointSize: CGFloat = circlePresentation ? 12.5 : 11.5
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .medium)
        var image: UIImage?

        if let iconName, !iconName.isEmpty {
            image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        } else if sectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds {
            image = UIImage(systemName: "chevron.down", withConfiguration: symbolConfig)
        }

        config.image = image?.withTintColor(actionForegroundColor(), renderingMode: .alwaysTemplate)
        config.imagePadding = (image != nil && !circlePresentation) ? 5 : 0
        config.imagePlacement = .trailing

        let hasTitleText = !(config.title?.isEmpty ?? true) || config.attributedTitle != nil
        if !hasTitleText && image != nil {
            config.contentInsets = circlePresentation
                ? NSDirectionalEdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 6)
                : NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
        }
    }

    private func configureMenu(_ menu: UIMenu?) {
        actionButton.menu = menu
        actionButton.showsMenuAsPrimaryAction = menu != nil
    }

    private func applySemanticDirection() {
        let semantic = Language.semanticAttributeForCurrentLanguage()
        let alignment = Language.alignmentForCurrentLanguage()

        semanticContentAttribute = semantic
        swiftUIHostView.semanticContentAttribute = semantic
        actionButton.semanticContentAttribute = semantic
        titleLabel.textAlignment = alignment
        subtitleLabel.textAlignment = alignment
        swiftUIHostView.setRightToLeft(Language.isRTL())
    }

    private func syncHost(animated: Bool) {
        swiftUIHostView.configure(
            subtitleVisible: currentSubtitleVisible,
            showsAction: !actionButton.isHidden,
            usesCirclePresentation: actionButtonUsesCirclePresentation,
            surfaceDecorationActive: surfaceDecorationActive,
            rightToLeft: Language.isRTL(),
            animated: animated
        )
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = true
        currentSubtitleVisible = false
        actionButton.isHidden = true
        actionButton.menu = nil
        actionButton.showsMenuAsPrimaryAction = false
        actionButton.configuration = baseActionButtonConfiguration()
        actionButton.imageView?.transform = .identity
        actionButtonUsesCirclePresentation = false
        actionAccessibilityTitle = nil
        isExpanded = false
        surfaceDecorationActive = true
        onTap = nil
        onTapMenu = nil
        lastActionTimestamp = 0
        swiftUIHostView.setPressed(false, animated: false)
        swiftUIHostView.setExpanded(false, animated: false)
        syncHost(animated: false)
        refreshAppearance()
        updateAccessibility()
    }

    @objc private func actionTapped() {
        let now = CACurrentMediaTime()
        if now - lastActionTimestamp < 0.22 {
            return
        }
        lastActionTimestamp = now

        animatePressFeedback()

        guard isMainKindsSection else {
            onTap?()
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isExpanded.toggle()
        setExpanded(isExpanded, animated: true)
        onTap?()
    }

    private func animatePressFeedback() {
        swiftUIHostView.setPressed(true, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.swiftUIHostView.setPressed(false, animated: true)
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var hitView: UIView? = touch.view
        while let view = hitView {
            if view == actionButton {
                return false
            }
            hitView = view.superview
        }
        return true
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded

        guard isMainKindsSection else {
            actionButton.imageView?.transform = .identity
            swiftUIHostView.setExpanded(false, animated: animated)
            return
        }

        let angle = expanded ? CGFloat.pi : 0
        let updates: () -> Void = {
            if let imageView = self.actionButton.imageView {
                imageView.transform = CGAffineTransform(rotationAngle: angle)
            }
        }

        swiftUIHostView.setExpanded(expanded, animated: animated)
        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(
                withDuration: 0.34,
                delay: 0,
                usingSpringWithDamping: 0.76,
                initialSpringVelocity: 0.55,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: updates,
                completion: nil
            )
        } else {
            updates()
        }
    }

    private func updateAccessibility() {
        let title = titleLabel.text ?? ""
        let subtitle = subtitleLabel.isHidden ? "" : (subtitleLabel.text ?? "")
        let configuredActionTitle = actionButton.configuration?.title ?? ""
        let actionTitle = actionAccessibilityTitle?.isEmpty == false
            ? actionAccessibilityTitle!
            : configuredActionTitle

        titleLabel.accessibilityLabel = title
        subtitleLabel.accessibilityLabel = subtitle
        actionButton.accessibilityLabel = actionTitle.isEmpty ? title : actionTitle
        actionButton.accessibilityHint = nil

        if isMainKindsSection {
            actionButton.accessibilityTraits = .button
            actionButton.accessibilityValue = isExpanded
                ? Language.get("ShowLess", alter: nil)
                : Language.get("ShowAll", alter: nil)
        }
    }
}

private final class PPSectionHeaderHostingView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.isOpaque = false
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        label.allowsDefaultTighteningForTruncation = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        label.accessibilityTraits = .header
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.isOpaque = false
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .clear
        button.isOpaque = false
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.88
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.accessibilityTraits = .button
        return button
    }()

    private let store = PPSectionHeaderStore()
    private var hostingController: UIHostingController<PPSectionHeaderRootView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpHostingController()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpHostingController()
    }

    private func setUpHostingController() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false
        isAccessibilityElement = false

        let rootView = PPSectionHeaderRootView(
            store: store,
            titleLabel: titleLabel,
            subtitleLabel: subtitleLabel,
            actionButton: actionButton
        )
        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.clipsToBounds = false
        controller.view.preservesSuperviewLayoutMargins = false
        controller.view.insetsLayoutMarginsFromSafeArea = false
        addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingController = controller
    }

    func configure(
        subtitleVisible: Bool,
        showsAction: Bool,
        usesCirclePresentation: Bool,
        surfaceDecorationActive: Bool,
        rightToLeft: Bool,
        animated: Bool
    ) {
        semanticContentAttribute = rightToLeft ? .forceRightToLeft : .forceLeftToRight
        store.configure(
            subtitleVisible: subtitleVisible,
            showsAction: showsAction,
            usesCirclePresentation: usesCirclePresentation,
            surfaceDecorationActive: surfaceDecorationActive,
            rightToLeft: rightToLeft,
            animated: animated
        )
    }

    func setSurfaceDecorationActive(_ active: Bool, animated: Bool) {
        store.setSurfaceDecorationActive(active, animated: animated)
    }

    func setRightToLeft(_ rightToLeft: Bool) {
        semanticContentAttribute = rightToLeft ? .forceRightToLeft : .forceLeftToRight
        store.setRightToLeft(rightToLeft)
    }

    func setPressed(_ pressed: Bool, animated: Bool) {
        store.setPressed(pressed, animated: animated)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        store.setExpanded(expanded, animated: animated)
    }

    func refreshForCurrentBounds() {
        setNeedsLayout()
        hostingController?.view.setNeedsLayout()
    }
}

private struct PPSectionHeaderRootView: View {
    @ObservedObject var store: PPSectionHeaderStore
    let titleLabel: UILabel
    let subtitleLabel: UILabel
    let actionButton: UIButton

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: PPSectionHeaderMetrics.contentSpacing) {
            accentRail

            VStack(alignment: store.state.rightToLeft ? .trailing : .leading,
                   spacing: store.state.subtitleVisible ? PPSectionHeaderMetrics.subtitleSpacing : 0) {
                titleRow

                if store.state.subtitleVisible {
                    PPSectionHeaderLabelRepresentable(label: subtitleLabel)
                        .frame(maxWidth: .infinity,
                               alignment: store.state.rightToLeft ? .trailing : .leading)
                        .transition(.opacity)
                        .accessibilitySortPriority(0)
                }
            }
            .layoutPriority(1)
        }
        .padding(.vertical, PPSectionHeaderMetrics.contentVerticalInset)
        .background(pressHighlight)
        .scaleEffect(reduceMotion ? 1 : (store.state.pressed ? 0.988 : 1))
        .environment(\.layoutDirection, store.state.rightToLeft ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .contain)
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: PPSectionHeaderMetrics.titleToActionSpacing) {
            PPSectionHeaderLabelRepresentable(label: titleLabel)
                .frame(maxWidth: .infinity,
                       minHeight: PPSectionHeaderMetrics.titleTouchHeight,
                       alignment: store.state.rightToLeft ? .trailing : .leading)
                .layoutPriority(1)
                .accessibilitySortPriority(2)

            if store.state.showsAction {
                PPSectionHeaderButtonRepresentable(button: actionButton)
                    .fixedSize(horizontal: !store.state.usesCirclePresentation, vertical: true)
                    .frame(
                        minWidth: store.state.usesCirclePresentation
                            ? PPSectionHeaderMetrics.actionHeight
                            : PPSectionHeaderMetrics.actionMinWidth,
                        idealWidth: store.state.usesCirclePresentation
                            ? PPSectionHeaderMetrics.actionHeight
                            : nil,
                        maxWidth: store.state.usesCirclePresentation
                            ? PPSectionHeaderMetrics.actionHeight
                            : PPSectionHeaderMetrics.actionMaxWidth,
                        minHeight: PPSectionHeaderMetrics.actionHeight,
                        idealHeight: PPSectionHeaderMetrics.actionHeight,
                        maxHeight: PPSectionHeaderMetrics.actionHeight
                    )
                    .padding(.vertical, 4)
                    .transition(.opacity)
                    .accessibilitySortPriority(1)
            }
        }
        .frame(minHeight: PPSectionHeaderMetrics.titleTouchHeight)
    }

    private var accentRail: some View {
        Capsule(style: .continuous)
            .fill(Color(uiColor: PPSectionHeaderPalette.accent)
                .opacity(store.state.surfaceDecorationActive ? 0.56 : 0.46))
            .frame(width: PPSectionHeaderMetrics.accentWidth,
                   height: store.state.expanded
                        ? PPSectionHeaderMetrics.accentHeight * 1.14
                        : PPSectionHeaderMetrics.accentHeight)
            .opacity(store.state.surfaceDecorationActive ? 1 : 0.82)
            .accessibilityHidden(true)
    }

    private var pressHighlight: some View {
        RoundedRectangle(cornerRadius: PPSectionHeaderMetrics.cornerRadius, style: .continuous)
            .fill(Color(uiColor: PPSectionHeaderPalette.accent)
                .opacity(store.state.pressed ? (reduceMotion ? 0.04 : 0.06) : 0))
            .accessibilityHidden(true)
    }
}

private struct PPSectionHeaderLabelRepresentable: UIViewRepresentable {
    let label: UILabel

    func makeUIView(context: Context) -> UILabel {
        label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
    }
}

private struct PPSectionHeaderButtonRepresentable: UIViewRepresentable {
    let button: UIButton

    func makeUIView(context: Context) -> UIButton {
        button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
        uiView.setContentCompressionResistancePriority(.required, for: .horizontal)
        uiView.setContentHuggingPriority(.required, for: .horizontal)
    }
}
