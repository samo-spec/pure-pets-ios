//
//  PPHomeOrderStatusSwiftUI.swift
//  Pure Pets
//
//  SwiftUI presentation for PPHomeOrderStatusCell. Business state, Firebase,
//  status derivation, permissions, and navigation remain owned by UIKit.
//

import Combine
import SDWebImage
import SwiftUI

// MARK: - Objective-C host

@objc(PPHomeOrderStatusHostingView)
public final class PPHomeOrderStatusHostingView: UIView {
    @objc public var onTrackTap: (() -> Void)?
    @objc public var onHistoryTap: (() -> Void)?
    @objc public var onCollapseTap: (() -> Void)?

    private let store = PPHomeOrderStatusStore()
    private var hostingController: UIHostingController<PPHomeOrderStatusRootView>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpHostingController()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpHostingController()
    }

    private func setUpHostingController() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false

        let rootView = PPHomeOrderStatusRootView(
            store: store,
            onTrack: { [weak self] in self?.onTrackTap?() },
            onHistory: { [weak self] in self?.onHistoryTap?() },
            onToggleExpanded: { [weak self] in self?.onCollapseTap?() }
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

    @objc(configureWithOrderReference:orderKickerTitle:previewImageURLs:meta:statusTitle:statusHint:statusKey:progress:footerText:statusColor:statusIconName:actionTitle:historyTitle:loadingAccessibilityLabel:toggleAccessibilityLabel:toggleAccessibilityHint:expandedStateValue:collapsedStateValue:expanded:placeholder:animated:)
    public func configure(
        orderReference: String,
        orderKickerTitle: String,
        previewImageURLs: [String],
        meta: String,
        statusTitle: String,
        statusHint: String,
        statusKey: String,
        progress: Double,
        footerText: String,
        statusColor: UIColor,
        statusIconName: String,
        actionTitle: String,
        historyTitle: String,
        loadingAccessibilityLabel: String,
        toggleAccessibilityLabel: String,
        toggleAccessibilityHint: String,
        expandedStateValue: String,
        collapsedStateValue: String,
        expanded: Bool,
        placeholder: Bool,
        animated: Bool
    ) {
        let content = PPHomeOrderStatusContent(
            orderReference: orderReference,
            orderKickerTitle: orderKickerTitle,
            previewImageURLs: Array(previewImageURLs.prefix(3)),
            meta: meta,
            statusTitle: statusTitle,
            statusHint: statusHint,
            statusKey: statusKey,
            progress: progress.isFinite ? min(max(progress, 0), 1) : 0,
            footerText: footerText,
            statusColor: statusColor,
            statusIconName: statusIconName.isEmpty ? "shippingbox.circle.fill" : statusIconName,
            actionTitle: actionTitle,
            historyTitle: historyTitle,
            loadingAccessibilityLabel: loadingAccessibilityLabel,
            toggleAccessibilityLabel: toggleAccessibilityLabel,
            toggleAccessibilityHint: toggleAccessibilityHint,
            expandedStateValue: expandedStateValue,
            collapsedStateValue: collapsedStateValue,
            isExpanded: expanded
        )
        let model = PPHomeOrderStatusModel(
            presentation: placeholder ? .loading : .content,
            content: content,
            isHighlighted: false
        )
        store.update(model, animated: animated)
    }

    @objc(setExpanded:animated:)
    public func setExpanded(_ expanded: Bool, animated: Bool) {
        store.setExpanded(expanded, animated: animated)
    }

    @objc(setHighlighted:animated:)
    public func setHighlighted(_ highlighted: Bool, animated: Bool) {
        store.setHighlighted(highlighted, animated: animated)
    }

    @objc public func prepareForReuse() {
        store.resetForReuse()
    }

    @objc public func refreshForCurrentBounds() {
        setNeedsLayout()
        hostingController?.view.setNeedsLayout()
    }
}

// MARK: - State

private enum PPHomeOrderStatusPresentation {
    case loading
    case content
    case empty(title: String, message: String)
    case error(title: String, message: String, retryTitle: String)
}

private struct PPHomeOrderStatusContent {
    var orderReference: String
    var orderKickerTitle: String
    var previewImageURLs: [String]
    var meta: String
    var statusTitle: String
    var statusHint: String
    var statusKey: String
    var progress: Double
    var footerText: String
    var statusColor: UIColor
    var statusIconName: String
    var actionTitle: String
    var historyTitle: String
    var loadingAccessibilityLabel: String
    var toggleAccessibilityLabel: String
    var toggleAccessibilityHint: String
    var expandedStateValue: String
    var collapsedStateValue: String
    var isExpanded: Bool

    static let placeholder = PPHomeOrderStatusContent(
        orderReference: "----",
        orderKickerTitle: "",
        previewImageURLs: [],
        meta: "------",
        statusTitle: "",
        statusHint: "",
        statusKey: "pending",
        progress: 0.22,
        footerText: "",
        statusColor: .systemGray,
        statusIconName: "clock.fill",
        actionTitle: "",
        historyTitle: "",
        loadingAccessibilityLabel: "",
        toggleAccessibilityLabel: "",
        toggleAccessibilityHint: "",
        expandedStateValue: "",
        collapsedStateValue: "",
        isExpanded: false
    )
}

private struct PPHomeOrderStatusModel {
    var presentation: PPHomeOrderStatusPresentation
    var content: PPHomeOrderStatusContent
    var isHighlighted: Bool

    static let placeholder = PPHomeOrderStatusModel(
        presentation: .loading,
        content: .placeholder,
        isHighlighted: false
    )
}

@MainActor
private final class PPHomeOrderStatusStore: ObservableObject {
    @Published private(set) var model: PPHomeOrderStatusModel

    init(model: PPHomeOrderStatusModel = .placeholder) {
        self.model = model
    }

    func update(_ nextModel: PPHomeOrderStatusModel, animated: Bool) {
        apply(animated ? PPHomeOrderMotion.status : nil) {
            model = nextModel
        }
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard model.content.isExpanded != expanded else { return }
        apply(animated ? PPHomeOrderMotion.expansion : nil) {
            model.content.isExpanded = expanded
        }
    }

    func setHighlighted(_ highlighted: Bool, animated: Bool) {
        guard model.isHighlighted != highlighted else { return }
        apply(animated ? PPHomeOrderMotion.press : nil) {
            model.isHighlighted = highlighted
        }
    }

    func resetForReuse() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model = .placeholder
        }
    }

    private func apply(_ animation: Animation?, changes: () -> Void) {
        if let animation {
            withAnimation(animation, changes)
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
        }
    }
}

// MARK: - Root presentation

private struct PPHomeOrderStatusRootView: View {
    @ObservedObject var store: PPHomeOrderStatusStore

    let onTrack: () -> Void
    let onHistory: () -> Void
    let onToggleExpanded: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        cardContent
            .padding(.horizontal, PPSpace.xxs)
            .padding(.vertical, PPSpace.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(reduceMotion ? 1 : (store.model.isHighlighted ? 0.992 : 1))
            .opacity(store.model.isHighlighted ? 0.97 : 1)
            .animation(reduceMotion ? nil : PPHomeOrderMotion.press, value: store.model.isHighlighted)
    }

    @ViewBuilder
    private var cardContent: some View {
        ZStack {
            PPHomeOrderCardMaterial(
                accent: Color(uiColor: store.model.content.statusColor),
                reduceTransparency: reduceTransparency,
                highContrast: colorSchemeContrast == .increased
            )

            switch store.model.presentation {
            case .loading:
                PPHomeOrderLoadingView(
                    isExpanded: store.model.content.isExpanded,
                    accessibilityLabel: store.model.content.loadingAccessibilityLabel
                )
                    .transition(.opacity)
            case .content:
                contentView
                    .transition(contentTransition)
            case let .empty(title, message):
                PPHomeOrderUnavailableView(
                    symbolName: "shippingbox",
                    title: title,
                    message: message,
                    actionTitle: nil,
                    action: nil
                )
                .transition(.opacity)
            case let .error(title, message, retryTitle):
                PPHomeOrderUnavailableView(
                    symbolName: "exclamationmark.arrow.triangle.2.circlepath",
                    title: title,
                    message: message,
                    actionTitle: retryTitle,
                    action: nil
                )
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    Color(uiColor: .separator).opacity(colorSchemeContrast == .increased ? 0.55 : 0.24),
                    lineWidth: colorSchemeContrast == .increased ? 1.25 : 0.5
                )
        }
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.26) : PPShadow.card.color,
            radius: colorScheme == .dark ? 14 : PPShadow.card.radius,
            x: PPShadow.card.x,
            y: colorScheme == .dark ? 8 : PPShadow.card.y
        )
        .animation(reduceMotion ? nil : PPHomeOrderMotion.status, value: store.model.content.statusKey)
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity.combined(with: .scale(scale: 0.992))
        )
    }

    @ViewBuilder
    private var contentView: some View {
        if store.model.content.isExpanded {
            PPHomeOrderExpandedView(
                content: store.model.content,
                usesAccessibilityLayout: dynamicTypeSize.isAccessibilitySize,
                onTrack: onTrack,
                onHistory: onHistory,
                onCollapse: onToggleExpanded
            )
        } else {
            PPHomeOrderCollapsedView(
                content: store.model.content,
                usesAccessibilityLayout: dynamicTypeSize.isAccessibilitySize,
                onExpand: onToggleExpanded
            )
        }
    }
}

// MARK: - Card material

private struct PPHomeOrderCardMaterial: View {
    let accent: Color
    let reduceTransparency: Bool
    let highContrast: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        ZStack {
            if reduceTransparency {
                shape.fill(Color.ppCard)
            } else {
                shape.fill(.thinMaterial)
                shape.fill(Color.ppCard.opacity(0.72))
            }

            LinearGradient(
                colors: [accent.opacity(highContrast ? 0.13 : 0.09), .clear, accent.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            RadialGradient(
                colors: [Color.white.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 180
            )
            .blendMode(.softLight)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Collapsed state

private struct PPHomeOrderCollapsedView: View {
    let content: PPHomeOrderStatusContent
    let usesAccessibilityLayout: Bool
    let onExpand: () -> Void

    var body: some View {
        Group {
            if usesAccessibilityLayout {
                accessibleLayout
            } else {
                standardLayout
            }
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var standardLayout: some View {
        HStack(spacing: PPSpace.md) {
            PPHomeOrderPreviewCluster(content: content)

            PPHomeOrderIdentity(content: content, compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            PPHomeOrderStatusBadge(content: content, compact: true)

            PPHomeOrderExpandButton(content: content, isExpanded: false, action: onExpand)
        }
    }

    private var accessibleLayout: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                PPHomeOrderPreviewCluster(content: content)
                PPHomeOrderIdentity(content: content, compact: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PPHomeOrderExpandButton(content: content, isExpanded: false, action: onExpand)
            }
            PPHomeOrderStatusBadge(content: content, compact: false)
        }
    }
}

// MARK: - Expanded state

private struct PPHomeOrderExpandedView: View {
    let content: PPHomeOrderStatusContent
    let usesAccessibilityLayout: Bool
    let onTrack: () -> Void
    let onHistory: () -> Void
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: PPSpace.sm) {
                PPHomeOrderStatusBadge(content: content, compact: false)
                Spacer(minLength: PPSpace.sm)
                PPHomeOrderExpandButton(content: content, isExpanded: true, action: onCollapse)
            }

            PPHomeOrderIdentity(content: content, compact: false)
                .padding(.top, PPSpace.sm)

            if !content.statusHint.isEmpty {
                Text(content.statusHint)
                    .font(.ppHomeOrderBody)
                    .foregroundStyle(.primary)
                    .lineLimit(usesAccessibilityLayout ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, PPSpace.xs)
            }

            Spacer(minLength: PPSpace.xs)

            PPHomeOrderProgressView(content: content)

            PPHomeOrderActions(
                content: content,
                vertical: usesAccessibilityLayout,
                onTrack: onTrack,
                onHistory: onHistory
            )
            .padding(.top, PPSpace.sm)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Shared content

private struct PPHomeOrderIdentity: View {
    let content: PPHomeOrderStatusContent
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? PPSpace.xxs : PPSpace.xs) {
            if !content.orderKickerTitle.isEmpty {
                Text(content.orderKickerTitle)
                    .font(.ppHomeOrderCaption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }

            if compact {
                Text(content.orderReference)
                    .font(.ppHomeOrderCollapsedTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if !collapsedSummary.isEmpty {
                    Text(collapsedSummary)
                        .font(.ppHomeOrderFootnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                    Text(content.orderReference)
                        .font(.ppHomeOrderTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: PPSpace.sm)

                    if !content.meta.isEmpty {
                        Text(content.meta)
                            .font(.ppHomeOrderFootnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var collapsedSummary: String {
        [content.meta, content.footerText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

private struct PPHomeOrderStatusBadge: View {
    let content: PPHomeOrderStatusContent
    let compact: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label {
            Text(content.statusTitle)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.82)
        } icon: {
            Image(systemName: content.statusIconName)
                .symbolRenderingMode(.hierarchical)
        }
        .font(.ppHomeOrderBadge)
        .foregroundStyle(accent)
        .padding(.horizontal, compact ? PPSpace.sm : PPSpace.md)
        .frame(minHeight: 30)
        .background(accent.opacity(colorScheme == .dark ? 0.20 : 0.11))
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(accent.opacity(0.30), lineWidth: 0.75)
        }
        .id(content.statusKey)
        .accessibilityLabel(content.statusTitle)
    }

    private var accent: Color { Color(uiColor: content.statusColor) }
}

private struct PPHomeOrderProgressView: View {
    let content: PPHomeOrderStatusContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                if !content.footerText.isEmpty {
                    Text(content.footerText)
                        .font(.ppHomeOrderFootnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: PPSpace.sm)
                Text(percentText)
                    .font(.ppHomeOrderData)
                    .foregroundStyle(accent)
                    .monospacedDigit()
            }

            ZStack {
                Capsule()
                    .fill(Color(uiColor: .systemFill))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.72), accent, accent.opacity(0.84)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(
                        x: CGFloat(max(content.progress, 0.025)),
                        y: 1,
                        anchor: layoutDirection == .rightToLeft ? .trailing : .leading
                    )
                    .animation(reduceMotion ? nil : PPHomeOrderMotion.progress, value: content.progress)
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(content.statusTitle)
            .accessibilityValue(percentText)
        }
    }

    private var accent: Color { Color(uiColor: content.statusColor) }

    private var percentText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: content.progress)) ?? ""
    }
}

private struct PPHomeOrderActions: View {
    let content: PPHomeOrderStatusContent
    let vertical: Bool
    let onTrack: () -> Void
    let onHistory: () -> Void

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: PPSpace.sm) {
                    trackButton
                    historyButton
                }
            } else {
                HStack(spacing: PPSpace.sm) {
                    trackButton
                    historyButton
                }
            }
        }
    }

    private var trackButton: some View {
        PPHomeOrderActionButton(
            title: content.actionTitle,
            symbolName: "location.fill",
            accent: content.statusColor,
            isPrimary: true,
            action: onTrack
        )
    }

    private var historyButton: some View {
        PPHomeOrderActionButton(
            title: content.historyTitle,
            symbolName: "clock.fill",
            accent: content.statusColor,
            isPrimary: false,
            action: onHistory
        )
    }
}

private struct PPHomeOrderActionButton: View {
    let title: String
    let symbolName: String
    let accent: UIColor
    let isPrimary: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.ppHomeOrderButton)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.horizontal, PPSpace.md)
                .foregroundStyle(isPrimary ? primaryForeground : accentColor)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                        .strokeBorder(isPrimary ? .clear : accentColor.opacity(0.28), lineWidth: 0.75)
                }
        }
        .buttonStyle(PPHomeOrderPressButtonStyle())
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isPrimary {
            LinearGradient(
                colors: [accentColor.opacity(0.88), accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            accentColor.opacity(colorScheme == .dark ? 0.16 : 0.09)
        }
    }

    private var accentColor: Color { Color(uiColor: accent) }

    private var primaryForeground: Color {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let resolved = accent.resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        return luminance > 0.64 ? .black.opacity(0.82) : .white
    }
}

private struct PPHomeOrderExpandButton: View {
    let content: PPHomeOrderStatusContent
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(uiColor: content.statusColor))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 36, height: 36)
                .background(Color(uiColor: content.statusColor).opacity(0.10))
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color(uiColor: content.statusColor).opacity(0.24), lineWidth: 0.75)
                }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PPHomeOrderPressButtonStyle())
        .accessibilityLabel(content.toggleAccessibilityLabel)
        .accessibilityValue(isExpanded ? content.expandedStateValue : content.collapsedStateValue)
        .accessibilityHint(content.toggleAccessibilityHint)
    }
}

// MARK: - Preview images

private struct PPHomeOrderPreviewCluster: View {
    let content: PPHomeOrderStatusContent

    var body: some View {
        Group {
            if content.previewImageURLs.isEmpty {
                Image(systemName: content.statusIconName)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(uiColor: content.statusColor))
                    .frame(width: 54, height: 54)
                    .background(Color(uiColor: content.statusColor).opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                HStack(spacing: -22) {
                    ForEach(Array(content.previewImageURLs.enumerated()), id: \.offset) { index, urlString in
                        PPHomeOrderRemoteImage(urlString: urlString)
                            .frame(width: 44, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2)
                            }
                            .zIndex(Double(content.previewImageURLs.count - index))
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .frame(minWidth: 54, minHeight: 54)
    }
}

private final class PPHomeOrderImageView: UIImageView {
    var representedURLString = ""
}

private struct PPHomeOrderRemoteImage: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> PPHomeOrderImageView {
        let imageView = PPHomeOrderImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemFill
        imageView.isAccessibilityElement = false
        return imageView
    }

    func updateUIView(_ imageView: PPHomeOrderImageView, context: Context) {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageView.representedURLString != trimmedURLString else { return }

        imageView.sd_cancelCurrentImageLoad()
        imageView.representedURLString = trimmedURLString
        let placeholder = UIImage(named: "placeholder")
        imageView.image = placeholder

        guard let url = URL(string: trimmedURLString) else { return }
        imageView.sd_setImage(
            with: url,
            placeholderImage: placeholder,
            options: [.retryFailed, .scaleDownLargeImages]
        )
    }

    static func dismantleUIView(_ imageView: PPHomeOrderImageView, coordinator: Void) {
        imageView.sd_cancelCurrentImageLoad()
        imageView.representedURLString = ""
    }
}

// MARK: - Loading / empty / error

private struct PPHomeOrderLoadingView: View {
    let isExpanded: Bool
    let accessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.md) {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .fill(Color(uiColor: .systemFill))
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    PPHomeOrderSkeleton(width: 86, height: 10)
                    PPHomeOrderSkeleton(width: 150, height: 18)
                    PPHomeOrderSkeleton(width: 116, height: 11)
                }
                Spacer()
                Circle()
                    .fill(Color(uiColor: .systemFill))
                    .frame(width: 36, height: 36)
            }

            if isExpanded {
                PPHomeOrderSkeleton(width: nil, height: 13)
                PPHomeOrderSkeleton(width: nil, height: 6)
                HStack(spacing: PPSpace.sm) {
                    PPHomeOrderSkeleton(width: nil, height: 44)
                    PPHomeOrderSkeleton(width: nil, height: 44)
                }
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PPHomeOrderSkeleton: View {
    let width: CGFloat?
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: min(height / 2, 8), style: .continuous)
            .fill(Color(uiColor: .systemFill))
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width, height: height)
    }
}

private struct PPHomeOrderUnavailableView: View {
    let symbolName: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.sm) {
            Image(systemName: symbolName)
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.ppHomeOrderCollapsedTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.ppHomeOrderFootnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Typography, motion, and interaction tokens

private extension Font {
    static let ppHomeOrderTitle = Font.custom("Beiruti-Bold", size: 21, relativeTo: .title3)
    static let ppHomeOrderCollapsedTitle = Font.custom("Beiruti-Bold", size: 16, relativeTo: .headline)
    static let ppHomeOrderBody = Font.custom("Beiruti-Medium", size: 14, relativeTo: .subheadline)
    static let ppHomeOrderBadge = Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption)
    static let ppHomeOrderButton = Font.custom("Beiruti-Bold", size: 13, relativeTo: .subheadline)
    static let ppHomeOrderCaption = Font.custom("Beiruti-Medium", size: 11, relativeTo: .caption2)
    static let ppHomeOrderFootnote = Font.custom("Beiruti-Medium", size: 12, relativeTo: .footnote)
    static let ppHomeOrderData = Font.system(.footnote, design: .rounded).weight(.semibold)
}

private enum PPHomeOrderMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let status = Animation.easeOut(duration: 0.22)
    static let progress = Animation.easeOut(duration: 0.26)
    static let expansion = Animation.interpolatingSpring(stiffness: 310, damping: 34)
}

private struct PPHomeOrderPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : PPHomeOrderMotion.press, value: configuration.isPressed)
    }
}

// MARK: - Deterministic state previews

#if DEBUG
private struct PPHomeOrderStatusPreviewHarness: View {
    @StateObject private var store: PPHomeOrderStatusStore

    init(model: PPHomeOrderStatusModel) {
        _store = StateObject(wrappedValue: PPHomeOrderStatusStore(model: model))
    }

    var body: some View {
        PPHomeOrderStatusRootView(store: store, onTrack: {}, onHistory: {}, onToggleExpanded: {})
            .frame(height: store.model.content.isExpanded ? 238 : 93)
            .padding()
            .background(Color.ppBackground)
    }
}

private enum PPHomeOrderStatusPreviewFixtures {
    static let content = PPHomeOrderStatusContent(
        orderReference: "PP-240731",
        orderKickerTitle: "Current order",
        previewImageURLs: [],
        meta: "3 items · QAR 184",
        statusTitle: "On the way",
        statusHint: "Your courier is already on the way.",
        statusKey: "on_the_way",
        progress: 0.86,
        footerText: "Expected 2:30 PM",
        statusColor: .systemBlue,
        statusIconName: "truck.box.fill",
        actionTitle: "Track order",
        historyTitle: "Order history",
        loadingAccessibilityLabel: "Loading",
        toggleAccessibilityLabel: "Order timeline",
        toggleAccessibilityHint: "Expands or collapses the order progress timeline.",
        expandedStateValue: "Expanded",
        collapsedStateValue: "Collapsed",
        isExpanded: false
    )
}

private struct PPHomeOrderStatusSwiftUIPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            PPHomeOrderStatusPreviewHarness(
                model: PPHomeOrderStatusModel(
                    presentation: .content,
                    content: PPHomeOrderStatusPreviewFixtures.content,
                    isHighlighted: false
                )
            )
            .previewDisplayName("Collapsed · Light")

            PPHomeOrderStatusPreviewHarness(
                model: PPHomeOrderStatusModel(
                    presentation: .content,
                    content: expandedContent,
                    isHighlighted: false
                )
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Expanded · Dark")

            PPHomeOrderStatusPreviewHarness(model: .placeholder)
                .previewDisplayName("Loading")

            PPHomeOrderStatusPreviewHarness(
                model: PPHomeOrderStatusModel(
                    presentation: .empty(title: "No active orders", message: "Your next active order will appear here."),
                    content: PPHomeOrderStatusPreviewFixtures.content,
                    isHighlighted: false
                )
            )
            .previewDisplayName("Empty")

            PPHomeOrderStatusPreviewHarness(
                model: PPHomeOrderStatusModel(
                    presentation: .error(title: "Unable to load", message: "Check your connection and try again.", retryTitle: "Retry"),
                    content: PPHomeOrderStatusPreviewFixtures.content,
                    isHighlighted: false
                )
            )
            .previewDisplayName("Error")
        }
        .previewLayout(.sizeThatFits)
    }

    private static var expandedContent: PPHomeOrderStatusContent {
        var content = PPHomeOrderStatusPreviewFixtures.content
        content.isExpanded = true
        return content
    }
}
#endif
