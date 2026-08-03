//
//  PPSectionHeaderSwiftUI.swift
//  Pure Pets
//
//  SwiftUI-owned home-feed section header.
//

import SwiftUI
import UIKit

private enum PPSectionHeaderMetrics {
    static let contentVerticalInset: CGFloat = 2
    static let horizontalInset: CGFloat = 6
    static let identityMarkWidth: CGFloat = 24
    static let identityMarkHeight: CGFloat = 8
    static let identityCoreWidth: CGFloat = 8
    static let identityExpandedWidth: CGFloat = 15
    static let identitySpacing: CGFloat = 8
    static let titleUnderlineWidth: CGFloat = 34
    static let titleUnderlineExpandedWidth: CGFloat = 52
    static let titleUnderlineHeight: CGFloat = 3
    static let actionHeight: CGFloat = 44
    static let actionMinWidth: CGFloat = 44
    static let actionMaxWidth: CGFloat = 160
    static let actionTitleMinimumScale: CGFloat = 0.76
    static let mainKindsHorizontalInset: CGFloat = 11
    static let mainKindsActionMaxWidth: CGFloat = 160
    static let mainKindsActionImagePadding: CGFloat = 3
    static let mainKindsActionTitleMinimumScale: CGFloat = 0.68
    static let titleTouchHeight: CGFloat = 44
    static let titleToActionSpacing: CGFloat = 8
    static let mainKindsTitleToActionSpacing: CGFloat = 6
    static let subtitleSpacing: CGFloat = 3
    static let cornerRadius: CGFloat = 14
}

private enum PPSectionHeaderPalette {
    static var accent: UIColor {
        UIColor(named: "AppPrimaryColor") ?? .systemTeal
    }

    static var title: UIColor {
        UIColor(named: "PrimaryTextColor") ?? .label
    }

    static var subtitle: UIColor {
        UIColor(named: "SecondaryTextColor") ?? .secondaryLabel
    }
}

private enum PPSectionHeaderTypography {
    static func title() -> UIFont {
        scaledBrandFont(
            named: "Beiruti-Bold",
            size: 16,
            fallbackWeight: .bold,
            textStyle: .headline,
            maximumPointSize: 22
        )
    }

    static func subtitle() -> UIFont {
        scaledBrandFont(
            named: "Beiruti-Medium",
            size: 13,
            fallbackWeight: .medium,
            textStyle: .subheadline,
            maximumPointSize: 19
        )
    }

    static func action() -> UIFont {
        scaledBrandFont(
            named: "Beiruti-Bold",
            size: 13,
            fallbackWeight: .semibold,
            textStyle: .subheadline,
            maximumPointSize: 18
        )
    }

    private static func scaledBrandFont(
        named fontName: String,
        size: CGFloat,
        fallbackWeight: UIFont.Weight,
        textStyle: UIFont.TextStyle,
        maximumPointSize: CGFloat
    ) -> UIFont {
        let baseFont = UIFont(name: fontName, size: size + 1)
            ?? UIFont.systemFont(ofSize: size, weight: fallbackWeight)
        return UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(for: baseFont, maximumPointSize: maximumPointSize)
    }
}

private struct PPSectionHeaderState {
    var subtitleVisible = false
    var showsAction = false
    var usesCirclePresentation = false
    var usesMainKindsPresentation = false
    var surfaceDecorationActive = true
    var headingAccentColor = PPSectionHeaderPalette.accent
    var rightToLeft = Language.isRTL()
    var pressed = false
    var expanded = false
}

private final class PPSectionHeaderStore: ObservableObject {
    @Published private(set) var state = PPSectionHeaderState()
    private var pendingState: PPSectionHeaderState?
    private var pendingAnimated = false
    private var publicationScheduled = false

    func configure(
        subtitleVisible: Bool,
        showsAction: Bool,
        usesCirclePresentation: Bool,
        usesMainKindsPresentation: Bool,
        surfaceDecorationActive: Bool,
        headingAccentColor: UIColor,
        rightToLeft: Bool,
        animated: Bool
    ) {
        mutate(animated: animated) { nextState in
            nextState.subtitleVisible = subtitleVisible
            nextState.showsAction = showsAction
            nextState.usesCirclePresentation = usesCirclePresentation
            nextState.usesMainKindsPresentation = usesMainKindsPresentation
            nextState.surfaceDecorationActive = surfaceDecorationActive
            nextState.headingAccentColor = headingAccentColor
            nextState.rightToLeft = rightToLeft
        }
    }

    func setSurfaceDecorationActive(_ active: Bool, animated: Bool) {
        mutate(animated: animated) { nextState in
            nextState.surfaceDecorationActive = active
        }
    }

    func setRightToLeft(_ rightToLeft: Bool) {
        mutate(animated: false) { nextState in
            nextState.rightToLeft = rightToLeft
        }
    }

    func setPressed(_ pressed: Bool, animated: Bool) {
        mutate(animated: animated) { nextState in
            nextState.pressed = pressed
        }
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        mutate(animated: animated) { nextState in
            nextState.expanded = expanded
        }
    }

    private func mutate(
        animated: Bool,
        _ changes: (inout PPSectionHeaderState) -> Void
    ) {
        var nextState = pendingState ?? state
        changes(&nextState)

        guard !statesMatch(nextState, state) else {
            pendingState = nil
            pendingAnimated = false
            return
        }

        pendingState = nextState
        pendingAnimated = pendingAnimated || animated
        guard !publicationScheduled else { return }

        // The UIKit header is also driven by UIViewRepresentable.updateUIView.
        // Publish after that render transaction and coalesce duplicate syncs.
        publicationScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.publishPendingState()
        }
    }

    private func publishPendingState() {
        publicationScheduled = false
        guard let nextState = pendingState else { return }

        let animated = pendingAnimated
        pendingState = nil
        pendingAnimated = false
        guard !statesMatch(nextState, state) else { return }

        let changes = { [weak self] in
            self?.state = nextState
        }
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

    private func statesMatch(
        _ lhs: PPSectionHeaderState,
        _ rhs: PPSectionHeaderState
    ) -> Bool {
        lhs.subtitleVisible == rhs.subtitleVisible &&
        lhs.showsAction == rhs.showsAction &&
        lhs.usesCirclePresentation == rhs.usesCirclePresentation &&
        lhs.usesMainKindsPresentation == rhs.usesMainKindsPresentation &&
        lhs.surfaceDecorationActive == rhs.surfaceDecorationActive &&
        lhs.headingAccentColor.isEqual(rhs.headingAccentColor) &&
        lhs.rightToLeft == rhs.rightToLeft &&
        lhs.pressed == rhs.pressed &&
        lhs.expanded == rhs.expanded
    }
}

private enum PPSectionHeaderHomeSectionRaw {
    static let mainKinds = 5
    static let accessories = 7
}

@available(iOS 15.0, *)
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
    private var headingAccentColor = PPSectionHeaderPalette.accent
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
        actionButton.layer.cornerRadius = PPSectionHeaderMetrics.cornerRadius
        actionButton.layer.cornerCurve = .continuous
        actionButton.titleLabel?.numberOfLines = 1
        actionButton.titleLabel?.lineBreakMode = .byTruncatingTail
        actionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        actionButton.titleLabel?.minimumScaleFactor = PPSectionHeaderMetrics.actionTitleMinimumScale
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
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 7,
            leading: 12,
            bottom: 7,
            trailing: 8
        )
        config.imagePadding = 8
        config.imagePlacement = .trailing
        config.baseForegroundColor = actionForegroundColor()
        config.background = actionBackgroundConfiguration(circlePresentation: false)

        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: 13,
            weight: .semibold,
            scale: .medium
        )
        config.image = UIImage(
            systemName: "arrow.forward.circle.fill",
            withConfiguration: symbolConfig
        )?
            .withTintColor(actionForegroundColor(), renderingMode: .alwaysTemplate)
        return config
    }

    private func actionButtonConfiguration(circlePresentation: Bool) -> UIButton.Configuration {
        var config = baseActionButtonConfiguration()
        config.imagePlacement = .trailing
        config.imagePadding = circlePresentation ? 0 : 8
        config.contentInsets = circlePresentation
            ? NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            : NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 8)
        config.background = actionBackgroundConfiguration(
            circlePresentation: circlePresentation
        )
        return config
    }

    private func actionBackgroundConfiguration(circlePresentation: Bool) -> UIBackgroundConfiguration {
        let accent = actionForegroundColor()
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let increasedContrast =
            traitCollection.accessibilityContrast == .high
        var background = UIBackgroundConfiguration.clear()
        background.cornerRadius = PPSectionHeaderMetrics.cornerRadius
        background.strokeWidth = increasedContrast ? 1.5 : 1
        if increasedContrast {
            background.strokeColor = UIColor.ppTextPrimary.withAlphaComponent(0.62)
        } else {
            background.strokeColor = circlePresentation
                ? accent.withAlphaComponent(darkMode ? 0.28 : 0.20)
                : UIColor.ppBorder.withAlphaComponent(darkMode ? 0.82 : 0.92)
        }
        background.backgroundColor = circlePresentation
            ? accent.withAlphaComponent(darkMode ? 0.18 : 0.12)
            : UIColor.ppElevatedSurface.withAlphaComponent(
                increasedContrast ? 1 : (darkMode ? 0.96 : 0.98)
            )
        return background
    }

    private func refreshAppearance() {
        titleLabel.textColor = titleColor()
        subtitleLabel.textColor = subtitleColor()

        var config = actionButton.configuration ?? baseActionButtonConfiguration()
        config.background = actionBackgroundConfiguration(
            circlePresentation: actionButtonUsesCirclePresentation
        )
        config.cornerStyle = .fixed
        config.baseForegroundColor = actionForegroundColor()
        actionButton.configuration = config
        actionButton.layer.cornerRadius = PPSectionHeaderMetrics.cornerRadius
        actionButton.layer.cornerCurve = .continuous
        syncHost(animated: false)
    }

    private func actionForegroundColor() -> UIColor {
        isMainKindsSection
            ? headingAccentColor
            : PPSectionHeaderPalette.accent
    }

    private func actionTitleColor() -> UIColor {
        isMainKindsSection ? headingAccentColor : titleColor()
    }

    private func titleColor() -> UIColor {
        PPSectionHeaderPalette.title
    }

    private func subtitleColor() -> UIColor {
        PPSectionHeaderPalette.subtitle
    }

    private func titleFont() -> UIFont {
        PPSectionHeaderTypography.title()
    }

    private func subtitleFont() -> UIFont {
        PPSectionHeaderTypography.subtitle()
    }

    private func actionFont() -> UIFont {
        PPSectionHeaderTypography.action()
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

    func setHeadingAccentColor(_ color: UIColor?) {
        headingAccentColor = color ?? PPSectionHeaderPalette.accent
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
            sectionRawValue: currentSectionRawValue
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
        sectionRawValue: Int
    ) {
        actionButton.isHidden = false

        let usesCirclePresentation = false
        actionButtonUsesCirclePresentation = usesCirclePresentation

        let resolvedActionTitle = (actionTitle?.isEmpty == false)
            ? actionTitle!
            : (Language.get("ShowAll", alter: nil) ?? "Show All")
        var resolvedIconName: String
        if let iconName, !iconName.isEmpty {
            resolvedIconName = iconName
        } else if menu != nil {
            resolvedIconName = "chevron.down"
        } else {
            resolvedIconName = "arrow.forward.circle.fill"
        }
        if sectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds &&
            !usesCirclePresentation &&
            (iconName?.isEmpty ?? true) {
            resolvedIconName = mainKindsLayoutIconName(expanded: isExpanded)
        }
        if usesCirclePresentation {
            resolvedIconName = "arrow.forward"
        }

        actionAccessibilityTitle = resolvedActionTitle

        var config = actionButtonConfiguration(
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
                outgoing.font = self?.actionFont()
                    ?? UIFont.systemFont(ofSize: 13, weight: .semibold)
                outgoing.foregroundColor = self?.actionTitleColor() ?? .label
                return outgoing
            }
        }

        applyIcon(
            named: resolvedIconName,
            to: &config,
            sectionRawValue: sectionRawValue,
            circlePresentation: usesCirclePresentation
        )

        let usesMainKindsPresentation =
            sectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds &&
            !usesCirclePresentation
        if usesMainKindsPresentation {
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 7,
                leading: 10,
                bottom: 7,
                trailing: 8
            )
            config.imagePadding = config.image == nil
                ? 0
                : PPSectionHeaderMetrics.mainKindsActionImagePadding
            actionButton.titleLabel?.minimumScaleFactor = PPSectionHeaderMetrics.mainKindsActionTitleMinimumScale
        } else {
            actionButton.titleLabel?.minimumScaleFactor = PPSectionHeaderMetrics.actionTitleMinimumScale
        }

        actionButton.configuration = config
        actionButton.invalidateIntrinsicContentSize()
        actionButton.setNeedsUpdateConfiguration()
        actionButton.setNeedsLayout()
        syncHost(animated: false)
    }

    private func applyIcon(
        named iconName: String?,
        to config: inout UIButton.Configuration,
        sectionRawValue: Int,
        circlePresentation: Bool
    ) {
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: 13,
            weight: .semibold,
            scale: .medium
        )
        var image: UIImage?

        if let iconName, !iconName.isEmpty {
            image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        } else if sectionRawValue == PPSectionHeaderHomeSectionRaw.mainKinds {
            image = UIImage(systemName: "chevron.down", withConfiguration: symbolConfig)
        }

        config.image = image?.withTintColor(actionForegroundColor(), renderingMode: .alwaysTemplate)
        config.imagePadding = (image != nil && !circlePresentation) ? 8 : 0
        config.imagePlacement = .trailing

        let hasTitleText = !(config.title?.isEmpty ?? true) || config.attributedTitle != nil
        if !hasTitleText && image != nil {
            config.contentInsets = circlePresentation
                ? NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                : NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        }
    }

    private func mainKindsLayoutIconName(expanded: Bool) -> String {
        let candidates = expanded
            ? [
                "rectangle.split.3x1.fill",
                "rectangle.split.3x1",
                "rectangle.grid.1x2.fill",
                "chevron.up",
            ]
            : ["square.grid.2x2.fill", "square.grid.2x2", "chevron.down"]
        return candidates.first(where: { UIImage(systemName: $0) != nil })
            ?? (expanded ? "chevron.up" : "chevron.down")
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
            usesMainKindsPresentation: isMainKindsSection && !actionButtonUsesCirclePresentation,
            surfaceDecorationActive: surfaceDecorationActive,
            headingAccentColor: headingAccentColor,
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
        currentSectionRawValue = 0
        actionButton.isHidden = true
        actionButton.menu = nil
        actionButton.showsMenuAsPrimaryAction = false
        actionButton.configuration = baseActionButtonConfiguration()
        actionButton.imageView?.transform = .identity
        actionButtonUsesCirclePresentation = false
        actionAccessibilityTitle = nil
        isExpanded = false
        surfaceDecorationActive = true
        headingAccentColor = PPSectionHeaderPalette.accent
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
        guard !actionButton.isHidden, onTap != nil else {
            return
        }

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
        setExpanded(!isExpanded, animated: true)
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

    fileprivate func setExpanded(_ expanded: Bool, animated: Bool) {
        let changed = isExpanded != expanded
        isExpanded = expanded

        guard isMainKindsSection else {
            actionButton.imageView?.transform = .identity
            swiftUIHostView.setExpanded(false, animated: animated)
            updateAccessibility()
            return
        }

        let updates: () -> Void = {
            var config = self.actionButton.configuration
                ?? self.baseActionButtonConfiguration()
            self.applyIcon(
                named: self.mainKindsLayoutIconName(expanded: expanded),
                to: &config,
                sectionRawValue: PPSectionHeaderHomeSectionRaw.mainKinds,
                circlePresentation: false
            )
            self.actionButton.configuration = config
            self.actionButton.imageView?.transform = .identity
        }

        swiftUIHostView.setExpanded(expanded, animated: animated)
        if animated && changed && !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(
                with: actionButton,
                duration: 0.22,
                options: [
                    .transitionCrossDissolve,
                    .allowAnimatedContent,
                    .allowUserInteraction,
                    .beginFromCurrentState,
                ],
                animations: updates
            )
        } else {
            updates()
        }
        updateAccessibility()
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
            actionButton.accessibilityIdentifier = "home.mainKinds.layoutToggle"
            actionButton.accessibilityTraits = .button
            actionButton.accessibilityValue = isExpanded
                ? Language.get("ShowLess", alter: nil)
                : Language.get("ShowAll", alter: nil)
        } else {
            actionButton.accessibilityIdentifier = nil
            actionButton.accessibilityValue = nil
        }
    }
}

@available(iOS 15.0, *)
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
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = PPSectionHeaderMetrics.actionTitleMinimumScale
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
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
        usesMainKindsPresentation: Bool,
        surfaceDecorationActive: Bool,
        headingAccentColor: UIColor,
        rightToLeft: Bool,
        animated: Bool
    ) {
        semanticContentAttribute = rightToLeft ? .forceRightToLeft : .forceLeftToRight
        store.configure(
            subtitleVisible: subtitleVisible,
            showsAction: showsAction,
            usesCirclePresentation: usesCirclePresentation,
            usesMainKindsPresentation: usesMainKindsPresentation,
            surfaceDecorationActive: surfaceDecorationActive,
            headingAccentColor: headingAccentColor,
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

@available(iOS 15.0, *)
private struct PPSectionHeaderRootView: View {
    @ObservedObject var store: PPSectionHeaderStore
    let titleLabel: UILabel
    let subtitleLabel: UILabel
    let actionButton: UIButton

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: store.state.rightToLeft ? .trailing : .leading,
               spacing: store.state.subtitleVisible ? PPSectionHeaderMetrics.subtitleSpacing : 0) {
            titleRow

            if store.state.subtitleVisible {
                PPSectionHeaderLabelRepresentable(label: subtitleLabel)
                    .frame(maxWidth: .infinity,
                           alignment: store.state.rightToLeft ? .trailing : .leading)
                    .padding(store.state.rightToLeft ? .trailing : .leading,
                             PPSectionHeaderMetrics.identityMarkWidth + PPSectionHeaderMetrics.identitySpacing)
                    .transition(.opacity)
                    .accessibilitySortPriority(0)
            }
        }
        .padding(.vertical, PPSectionHeaderMetrics.contentVerticalInset)
        .padding(.horizontal, visibleEdgeInset)
        .frame(maxWidth: .infinity, alignment: store.state.rightToLeft ? .trailing : .leading)
        .background(pressHighlight)
        .scaleEffect(reduceMotion ? 1 : (store.state.pressed ? 0.988 : 1))
        .environment(\.layoutDirection, store.state.rightToLeft ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .contain)
    }

    private var visibleEdgeInset: CGFloat {
        guard store.state.showsAction && !store.state.usesCirclePresentation else {
            return 0
        }

        return store.state.usesMainKindsPresentation
            ? PPSectionHeaderMetrics.mainKindsHorizontalInset
            : PPSectionHeaderMetrics.horizontalInset
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: titleToActionSpacing) {
            titleCluster
                .layoutPriority(1)

            if store.state.showsAction {
                PPSectionHeaderButtonRepresentable(
                    button: actionButton,
                    minimumScaleFactor: actionTitleMinimumScale
                )
                .layoutPriority(2)
                .frame(minHeight: PPSectionHeaderMetrics.actionHeight)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.vertical, 3)
                .transition(.opacity)
                .accessibilitySortPriority(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: store.state.rightToLeft ? .trailing : .leading)
        .frame(minHeight: PPSectionHeaderMetrics.titleTouchHeight)
        .overlay(alignment: .bottom) {
            if store.state.surfaceDecorationActive {
                titleUnderline
                    .padding(store.state.rightToLeft ? .trailing : .leading,
                             PPSectionHeaderMetrics.identityMarkWidth + PPSectionHeaderMetrics.identitySpacing)
                    .transition(.opacity)
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .center, spacing: PPSectionHeaderMetrics.identitySpacing) {
            sectionMark

            PPSectionHeaderLabelRepresentable(label: titleLabel)
                .frame(maxWidth: .infinity,
                       minHeight: PPSectionHeaderMetrics.titleTouchHeight,
                       alignment: store.state.rightToLeft ? .trailing : .leading)
                .layoutPriority(1)
                .accessibilitySortPriority(2)
        }
        .frame(maxWidth: .infinity,
               alignment: store.state.rightToLeft ? .trailing : .leading)
    }

    private var sectionMark: some View {
        ZStack(alignment: store.state.rightToLeft ? .trailing : .leading) {
            Capsule(style: .continuous)
                .fill(Color(uiColor: store.state.headingAccentColor)
                    .opacity(store.state.surfaceDecorationActive ? 0.16 : 0.10))
                .frame(width: PPSectionHeaderMetrics.identityMarkWidth,
                       height: PPSectionHeaderMetrics.identityMarkHeight)

            Capsule(style: .continuous)
                .fill(Color(uiColor: store.state.headingAccentColor)
                    .opacity(store.state.surfaceDecorationActive ? 0.88 : 0.58))
                .frame(width: store.state.expanded
                        ? PPSectionHeaderMetrics.identityExpandedWidth
                        : PPSectionHeaderMetrics.identityCoreWidth,
                       height: PPSectionHeaderMetrics.identityMarkHeight)
        }
        .frame(width: PPSectionHeaderMetrics.identityMarkWidth,
               height: PPSectionHeaderMetrics.titleTouchHeight)
        .accessibilityHidden(true)
    }

    private var titleUnderline: some View {
        HStack {
            Capsule(style: .continuous)
                .fill(Color(uiColor: store.state.headingAccentColor)
                    .opacity(store.state.surfaceDecorationActive ? 0.72 : 0.42))
                .frame(width: store.state.expanded
                        ? PPSectionHeaderMetrics.titleUnderlineExpandedWidth
                        : PPSectionHeaderMetrics.titleUnderlineWidth,
                       height: PPSectionHeaderMetrics.titleUnderlineHeight)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var titleToActionSpacing: CGFloat {
        store.state.usesMainKindsPresentation
            ? PPSectionHeaderMetrics.mainKindsTitleToActionSpacing
            : PPSectionHeaderMetrics.titleToActionSpacing
    }

    private var actionMaxWidth: CGFloat {
        store.state.usesMainKindsPresentation
            ? PPSectionHeaderMetrics.mainKindsActionMaxWidth
            : PPSectionHeaderMetrics.actionMaxWidth
    }

    private var actionTitleMinimumScale: CGFloat {
        store.state.usesMainKindsPresentation
            ? PPSectionHeaderMetrics.mainKindsActionTitleMinimumScale
            : PPSectionHeaderMetrics.actionTitleMinimumScale
    }

    private var pressHighlight: some View {
        Capsule(style: .continuous)
            .fill(Color(uiColor: store.state.headingAccentColor)
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

@available(iOS 15.0, *)
private struct PPSectionHeaderButtonRepresentable: UIViewRepresentable {
    let button: UIButton
    let minimumScaleFactor: CGFloat

    func makeUIView(context: Context) -> UIButton {
        button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
        uiView.titleLabel?.numberOfLines = 1
        uiView.titleLabel?.lineBreakMode = .byTruncatingTail
        uiView.titleLabel?.adjustsFontSizeToFitWidth = true
        uiView.titleLabel?.minimumScaleFactor = minimumScaleFactor
        uiView.setContentCompressionResistancePriority(.required, for: .horizontal)
        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        let fitting = uiView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required
        )
        let minW = PPSectionHeaderMetrics.actionMinWidth
        let maxW = PPSectionHeaderMetrics.actionMaxWidth
        let width = min(maxW, max(minW, ceil(fitting.width)))
        return CGSize(width: width, height: PPSectionHeaderMetrics.actionHeight)
    }
}

@available(iOS 15.0, *)
public struct PPSectionHeaderSwiftUIRepresentable: UIViewRepresentable {
    public let title: String
    public let subtitle: String?
    public let actionTitle: String?
    public let action: (() -> Void)?
    public let sectionRawValue: Int
    public let showsAction: Bool
    public let headingAccentColor: UIColor?
    public let isExpanded: Bool?

    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        sectionRawValue: Int = 7,
        showsAction: Bool = true,
        headingAccentColor: UIColor? = nil,
        isExpanded: Bool? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
        self.sectionRawValue = sectionRawValue
        self.showsAction = showsAction
        self.headingAccentColor = headingAccentColor
        self.isExpanded = isExpanded
    }

    public func makeUIView(context: Context) -> PPSectionHeaderSwiftUI {
        let view = PPSectionHeaderSwiftUI(frame: .zero)
        return view
    }

    public func updateUIView(_ uiView: PPSectionHeaderSwiftUI, context: Context) {
        let section = PPHomeSection(rawValue: sectionRawValue) ?? .accessories
        uiView.setHeadingAccentColor(headingAccentColor)
        uiView.configure(
            title: title,
            subtitle: subtitle,
            actionTitle: actionTitle,
            iconName: nil,
            menu: nil,
            ppHomeSection: section
        )
        uiView.onTap = showsAction ? action : nil
        if !showsAction {
            uiView.hide()
        }
        if let isExpanded {
            let shouldAnimate = context.transaction.animation != nil &&
                !context.transaction.disablesAnimations
            uiView.setExpanded(isExpanded, animated: shouldAnimate)
        }
    }

    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: PPSectionHeaderSwiftUI, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? max(uiView.bounds.width, 1)
        let fittingSize = uiView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.noIntrinsicMetric),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let height = max(44, fittingSize.height)
        return CGSize(width: targetWidth, height: height)
    }
}
