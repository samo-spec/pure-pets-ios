//
//  ModernSegmentedControl.swift
//  PurePets
//
//  Premium SwiftUI segmented control hosted from Objective-C.
//  Business contract mirrors PPModrenSegmrnted; this file owns presentation only.
//

import SwiftUI
import UIKit

// MARK: - Item Model

public struct ModernSegmentedItem: Identifiable, Hashable {
    public var id: String {
        "\(title)_\(iconName ?? "")_\(selectedIconName ?? "")"
    }

    public let title: String
    public let iconName: String?
    public let selectedIconName: String?

    public init(title: String, iconName: String? = nil, selectedIconName: String? = nil) {
        self.title = title
        self.iconName = iconName
        self.selectedIconName = selectedIconName
    }
}

public enum ModernSegmentedControlState: Equatable {
    case content
    case loading
    case empty
    case error(String?)

    fileprivate var animationKey: String {
        switch self {
        case .content:
            return "content"
        case .loading:
            return "loading"
        case .empty:
            return "empty"
        case .error(let message):
            return "error_\(message ?? "")"
        }
    }
}

// MARK: - Segmented Control

private enum ModernSegmentedStrings {
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private enum ModernSegmentedMetrics {
    static let outerInset: CGFloat = 3
    static let segmentSpacing: CGFloat = 3
    static let horizontalTextPadding: CGFloat = 6
    static let iconTextSpacing: CGFloat = 4
    static let selectionDotDiameter: CGFloat = 6
    static let selectionPillInset: CGFloat = 2
    static let containerCornerRadius: CGFloat = 16
    static let controlMinHeight: CGFloat = 44
    static let stateIconSize: CGFloat = 13
    static let focusRingOutset: CGFloat = 2
}

private struct SegmentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    let isSelected: Bool
    let alpha: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(effectiveAlpha(isPressed: configuration.isPressed))
            .scaleEffect(pressScale(isPressed: configuration.isPressed))
            .animation(
                reduceMotion ? nil : .easeOut(duration: configuration.isPressed ? 0.08 : 0.16),
                value: configuration.isPressed
            )
    }

    private func effectiveAlpha(isPressed: Bool) -> CGFloat {
        guard isEnabled else { return 0.34 }
        if isPressed {
            return isSelected ? 0.92 : min(alpha + 0.08, 0.86)
        }
        return alpha
    }

    private func pressScale(isPressed: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else { return 1 }
        return isSelected ? 0.972 : 0.965
    }
}

public struct ModernSegmentedControl: View {
    // 1) Environment
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    // 2) Let properties
    private let items: [ModernSegmentedItem]
    private let containerBackgroundColor: Color
    private let selectedSegmentColor: Color
    private let normalTextColor: Color
    private let selectedTextColor: Color
    private let normalFont: Font
    private let selectedFont: Font
    private let hidesContainerChrome: Bool
    private let hapticsEnabled: Bool
    private let state: ModernSegmentedControlState
    private let retryAction: (() -> Void)?

    // 3) State / Binding / Stored properties
    @Binding private var selectedIndex: Int
    @Namespace private var selectionNamespace
    @State private var isKeyboardFocused = false
    @State private var keyboardFocusToken = 0
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var stateTextSize: CGFloat = 12

    private struct SegmentItemWrapper: Identifiable {
        let index: Int
        let item: ModernSegmentedItem
        var id: String { "\(item.id)_\(index)" }
    }

    // 4) Computed Variables
    private var wrappedItems: [SegmentItemWrapper] {
        items.enumerated().map { SegmentItemWrapper(index: $0.offset, item: $0.element) }
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var accentColor: Color {
        selectedSegmentColor
    }

    private var effectiveCornerRadius: CGFloat {
        max(ModernSegmentedMetrics.containerCornerRadius, ModernSegmentedMetrics.controlMinHeight * 0.5)
    }

    private var selectionAnimation: Animation? {
        reduceMotion
            ? nil
            : .spring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.06)
    }

    private var stateTransitionAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var effectiveState: ModernSegmentedControlState {
        if state == .content && items.isEmpty {
            return .empty
        }
        return state
    }

    private var showsSegments: Bool {
        effectiveState == .content && !items.isEmpty
    }

    private var allowsSelection: Bool {
        isEnabled && showsSegments
    }

    private var shouldShowIcons: Bool {
        return false
    }

    private var rootAccessibilityValue: String {
        guard selectedIndex >= 0, selectedIndex < items.count else {
            return ModernSegmentedStrings.localized("modern_segmented_no_selection")
        }
        return items[selectedIndex].title
    }

    // 5) Init
    public init(
        items: [ModernSegmentedItem],
        selectedIndex: Binding<Int>,
        containerBackgroundColor: Color? = nil,
        selectedSegmentColor: Color? = nil,
        normalTextColor: Color? = nil,
        selectedTextColor: Color? = nil,
        normalFont: Font? = nil,
        selectedFont: Font? = nil,
        hidesContainerChrome: Bool = false,
        hapticsEnabled: Bool = true,
        state: ModernSegmentedControlState = .content,
        retryAction: (() -> Void)? = nil
    ) {
        self.items = items
        self._selectedIndex = selectedIndex

        let fallbackSurface = Color(uiColor: UIColor(named: "AppForegroundColor")
                                    ?? .secondarySystemBackground)
        let fallbackAccent = Color(uiColor: UIColor(named: "AppPrimaryColor")
                                   ?? .systemBlue)
        let fallbackPrimaryText = Color(uiColor: UIColor(named: "PrimaryTextColor")
                                        ?? .label)

        self.containerBackgroundColor = containerBackgroundColor ?? fallbackSurface
        self.selectedSegmentColor = selectedSegmentColor ?? fallbackAccent
        self.normalTextColor = normalTextColor ?? Color(uiColor: .secondaryLabel)
        self.selectedTextColor = selectedTextColor ?? fallbackPrimaryText
        self.normalFont = normalFont ?? .system(.caption, design: .rounded).weight(.medium)
        self.selectedFont = selectedFont ?? .system(.caption, design: .rounded).weight(.semibold)
        self.hidesContainerChrome = hidesContainerChrome
        self.hapticsEnabled = hapticsEnabled
        self.state = state
        self.retryAction = retryAction
    }

    public init(
        titles: [String],
        selectedIndex: Binding<Int>,
        containerBackgroundColor: Color? = nil,
        selectedSegmentColor: Color? = nil,
        normalTextColor: Color? = nil,
        selectedTextColor: Color? = nil,
        normalFont: Font? = nil,
        selectedFont: Font? = nil,
        hidesContainerChrome: Bool = false,
        hapticsEnabled: Bool = true,
        state: ModernSegmentedControlState = .content,
        retryAction: (() -> Void)? = nil
    ) {
        self.init(
            items: titles.map { ModernSegmentedItem(title: $0) },
            selectedIndex: selectedIndex,
            containerBackgroundColor: containerBackgroundColor,
            selectedSegmentColor: selectedSegmentColor,
            normalTextColor: normalTextColor,
            selectedTextColor: selectedTextColor,
            normalFont: normalFont,
            selectedFont: selectedFont,
            hidesContainerChrome: hidesContainerChrome,
            hapticsEnabled: hapticsEnabled,
            state: state,
            retryAction: retryAction
        )
    }

    // 6) Body
    public var body: some View {
        ZStack {
            if !hidesContainerChrome {
                containerView
            }

            Group {
                if showsSegments {
                    segmentsView
                        .transition(.opacity)
                } else {
                    stateView(for: effectiveState)
                        .transition(.opacity)
                }
            }
            .animation(stateTransitionAnimation, value: effectiveState.animationKey)
        }
        .frame(minHeight: ModernSegmentedMetrics.controlMinHeight)
        .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
        .overlay(focusRingView)
        .background(keyboardCommandBridge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ModernSegmentedStrings.localized("modern_segmented_accessibility_label"))
        .accessibilityValue(rootAccessibilityValue)
        .accessibilityAdjustableAction(handleAccessibilityAdjustment)
    }

    // 7) View Builders / Helpers
    @ViewBuilder
    private var containerView: some View {
        let radius = effectiveCornerRadius

        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(containerBackgroundColor.opacity(isDark ? 0.30 : 0.16))
            .shadow(
                color: Color.black.opacity(isDark ? 0.16 : 0.08),
                radius: 14,
                x: 0,
                y: 8
            )
    }

    private var selectionPillView: some View {
        let radius = max(8, effectiveCornerRadius - ModernSegmentedMetrics.outerInset - ModernSegmentedMetrics.selectionPillInset)
        let accent = accentColor

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(isDark ? 0.36 : 0.20),
                        accent.opacity(isDark ? 0.21 : 0.10),
                        Color.white.opacity(isDark ? 0.05 : 0.28)
                    ],
                    startPoint: .init(x: 0.16, y: 0.00),
                    endPoint: .init(x: 0.88, y: 1.00)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(accent.opacity(isDark ? 0.12 : 0.08), lineWidth: 1.05)
            )
            .shadow(
                color: (isDark ? accent : Color.black).opacity(isDark ? 0.18 : 0.10),
                radius: 10,
                x: 0,
                y: 4
            )
    }

    private var selectionDotView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.62),
                        accentColor,
                        accentColor.opacity(0.62)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(
                width: ModernSegmentedMetrics.selectionDotDiameter,
                height: ModernSegmentedMetrics.selectionDotDiameter
            )
            .shadow(
                color: accentColor.opacity(isDark ? 0.24 : 0.20),
                radius: 5,
                x: 0,
                y: 2
            )
    }

    private var segmentsView: some View {
        HStack(spacing: ModernSegmentedMetrics.segmentSpacing) {
            ForEach(wrappedItems) { wrapper in
                segmentButton(for: wrapper.index, item: wrapper.item)
            }
        }
        .padding(ModernSegmentedMetrics.outerInset)
        .animation(selectionAnimation, value: selectedIndex)
    }

    private func segmentButton(for index: Int, item: ModernSegmentedItem) -> some View {
        let isSelected = index == selectedIndex
        let alpha = segmentAlpha(isSelected: isSelected)

        return Button(action: { selectSegment(at: index) }) {
            ZStack {
                if isSelected && allowsSelection {
                    selectionPillView
                        .matchedGeometryEffect(id: "modern.segmented.selectionPill", in: selectionNamespace)
                        .padding(ModernSegmentedMetrics.selectionPillInset)
                        .transition(.opacity)

                    selectionDotView
                        .matchedGeometryEffect(id: "modern.segmented.selectionDot", in: selectionNamespace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 3)
                        .transition(.opacity)
                }

                SegmentLabel(
                    item: item,
                    isSelected: isSelected,
                    showsIcon: shouldShowIcons,
                    iconSize: min(max(iconSize, 12), 17),
                    textColor: textColor(for: index),
                    normalFont: normalFont,
                    selectedFont: selectedFont
                )
                .padding(.horizontal, ModernSegmentedMetrics.horizontalTextPadding)
            }
            .frame(maxWidth: .infinity, minHeight: ModernSegmentedMetrics.controlMinHeight - ModernSegmentedMetrics.outerInset * 2)
            .contentShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
        }
        .buttonStyle(SegmentButtonStyle(isSelected: isSelected, alpha: alpha))
        .disabled(!allowsSelection)
        .accessibilityLabel(item.title)
        .accessibilityHint(
            isSelected
                ? ""
                : ModernSegmentedStrings.localized("modern_segmented_select_hint")
        )
        .accessibilityValue(
            isSelected
                ? ModernSegmentedStrings.localized("modern_segmented_selected")
                : ModernSegmentedStrings.localized("modern_segmented_not_selected")
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("modern.segmented.segment.\(index)")
    }

    @ViewBuilder
    private func stateView(for state: ModernSegmentedControlState) -> some View {
        switch state {
        case .content:
            EmptyView()
        case .loading:
            loadingStateView
        case .empty:
            compactStateView(
                iconName: "line.3.horizontal.decrease.circle",
                title: ModernSegmentedStrings.localized("modern_segmented_empty_title"),
                titleColor: normalTextColor,
                retryAction: nil
            )
        case .error(let message):
            compactStateView(
                iconName: "exclamationmark.triangle.fill",
                title: message?.isEmpty == false
                    ? (message ?? "")
                    : ModernSegmentedStrings.localized("modern_segmented_error_title"),
                titleColor: Color(uiColor: .systemRed),
                retryAction: retryAction
            )
        }
    }

    private var loadingStateView: some View {
        HStack(spacing: ModernSegmentedMetrics.segmentSpacing) {
            ForEach(0..<placeholderCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(placeholderGradient(index: index))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
        }
        .padding(ModernSegmentedMetrics.outerInset)
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ModernSegmentedStrings.localized("modern_segmented_loading_title"))
    }

    private func compactStateView(
        iconName: String,
        title: String,
        titleColor: Color,
        retryAction: (() -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: ModernSegmentedMetrics.stateIconSize, weight: .semibold))
                .foregroundStyle(titleColor.opacity(isEnabled ? 0.90 : 0.40))
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: stateTextSize, weight: .semibold, design: .rounded))
                .foregroundStyle(titleColor.opacity(isEnabled ? 0.88 : 0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(accentColor.opacity(isEnabled ? 1 : 0.36))
                .disabled(!isEnabled)
                .accessibilityLabel(ModernSegmentedStrings.localized("modern_segmented_retry"))
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: ModernSegmentedMetrics.controlMinHeight)
    }

    private var focusRingView: some View {
        RoundedRectangle(
            cornerRadius: effectiveCornerRadius + ModernSegmentedMetrics.focusRingOutset,
            style: .continuous
        )
        .stroke(
            isKeyboardFocused && allowsSelection
                ? accentColor.opacity(isDark ? 0.62 : 0.42)
                : Color.clear,
            lineWidth: 0
        )
        .padding(-ModernSegmentedMetrics.focusRingOutset)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isKeyboardFocused)
    }

    private var keyboardCommandBridge: some View {
        SegmentKeyboardCommandBridge(
            isEnabled: allowsSelection,
            focusToken: keyboardFocusToken,
            onLeft: {
                moveSelectionBy(layoutDirection == .rightToLeft ? 1 : -1)
            },
            onRight: {
                moveSelectionBy(layoutDirection == .rightToLeft ? -1 : 1)
            },
            onFocusChange: { isFocused in
                isKeyboardFocused = isFocused
            }
        )
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var placeholderCount: Int {
        if items.isEmpty {
            return 3
        }
        return max(2, min(items.count, 4))
    }

    private func placeholderGradient(index: Int) -> LinearGradient {
        let baseOpacity = isDark ? 0.18 : 0.12
        let liftOpacity = isDark ? 0.10 : 0.20
        return LinearGradient(
            colors: [
                normalTextColor.opacity(baseOpacity),
                Color.white.opacity(liftOpacity),
                normalTextColor.opacity(baseOpacity * 0.72)
            ],
            startPoint: index.isMultiple(of: 2) ? .topLeading : .bottomLeading,
            endPoint: .bottomTrailing
        )
    }

    private func segmentAlpha(isSelected: Bool) -> CGFloat {
        guard isEnabled else { return 0.34 }
        return isSelected ? 1.0 : 0.70
    }

    private func textColor(for index: Int) -> Color {
        guard isEnabled else { return normalTextColor.opacity(0.34) }
        return index == selectedIndex ? selectedTextColor : normalTextColor
    }

    private func clampedSelectionIndex(_ index: Int) -> Int {
        guard !items.isEmpty else { return -1 }
        return max(0, min(index, items.count - 1))
    }

    // 8) Interaction Methods
    private func selectSegment(at index: Int) {
        guard allowsSelection else { return }
        requestKeyboardFocus()
        let resolvedIndex = clampedSelectionIndex(index)
        guard resolvedIndex != selectedIndex else { return }

        triggerSelectionFeedback()
        withAnimation(selectionAnimation) {
            selectedIndex = resolvedIndex
        }
    }

    private func triggerSelectionFeedback() {
        guard hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    private func requestKeyboardFocus() {
        keyboardFocusToken += 1
    }

    private func handleAccessibilityAdjustment(_ direction: AccessibilityAdjustmentDirection) {
        guard allowsSelection else { return }

        switch direction {
        case .increment:
            moveSelectionBy(1)
        case .decrement:
            moveSelectionBy(-1)
        @unknown default:
            break
        }
    }

    private func moveSelectionBy(_ delta: Int) {
        guard !items.isEmpty else { return }

        let currentIndex = selectedIndex >= 0 ? clampedSelectionIndex(selectedIndex) : 0
        let nextIndex = clampedSelectionIndex(currentIndex + delta)
        selectSegment(at: nextIndex)
    }
}

// MARK: - Keyboard Commands

private struct SegmentKeyboardCommandBridge: UIViewRepresentable {
    let isEnabled: Bool
    let focusToken: Int
    let onLeft: () -> Void
    let onRight: () -> Void
    let onFocusChange: (Bool) -> Void

    func makeUIView(context: Context) -> SegmentKeyboardCommandView {
        let view = SegmentKeyboardCommandView()
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: SegmentKeyboardCommandView, context: Context) {
        view.isCommandEnabled = isEnabled
        view.onLeft = onLeft
        view.onRight = onRight
        view.onFocusChange = onFocusChange

        if !isEnabled {
            _ = view.resignFirstResponder()
            return
        }

        if view.focusToken != focusToken {
            view.focusToken = focusToken
            DispatchQueue.main.async { [weak view] in
                _ = view?.becomeFirstResponder()
            }
        }
    }
}

private final class SegmentKeyboardCommandView: UIView {
    var isCommandEnabled = false {
        didSet {
            if !isCommandEnabled {
                _ = resignFirstResponder()
            }
        }
    }
    var focusToken = 0
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    override var canBecomeFirstResponder: Bool {
        isCommandEnabled
    }

    override var keyCommands: [UIKeyCommand]? {
        guard isCommandEnabled else { return [] }
        return [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleLeftArrow)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleRightArrow))
        ]
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            onFocusChange?(true)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            onFocusChange?(false)
        }
        return didResignFirstResponder
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            onFocusChange?(false)
        }
    }

    @objc private func handleLeftArrow() {
        onLeft?()
    }

    @objc private func handleRightArrow() {
        onRight?()
    }
}

// MARK: - Segment Label

private struct SegmentLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: ModernSegmentedItem
    let isSelected: Bool
    let showsIcon: Bool
    let iconSize: CGFloat
    let textColor: Color
    let normalFont: Font
    let selectedFont: Font

    private var iconName: String? {
        if isSelected, let selectedIconName = item.selectedIconName, !selectedIconName.isEmpty {
            return selectedIconName
        }
        if let iconName = item.iconName, !iconName.isEmpty {
            return iconName
        }
        return nil
    }

    var body: some View {
        HStack(spacing: showsIcon ? ModernSegmentedMetrics.iconTextSpacing : 0) {
            if showsIcon, let iconName = iconName {
                SegmentIcon(name: iconName)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(textColor)
                    .scaleEffect(isSelected && !reduceMotion ? 1.04 : 1.0)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .accessibilityHidden(true)
            }

            Text(item.title)
                .font(isSelected ? selectedFont : normalFont)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isSelected
        )
    }
}

private struct SegmentIcon: View {
    let name: String

    var body: some View {
        if let image = UIImage(systemName: name) ?? UIImage(named: name) {
            Image(uiImage: image.withRenderingMode(.alwaysTemplate))
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("2 segments - LTR") {
    @Previewable @State var index = 0
    ModernSegmentedControl(
        items: [
            ModernSegmentedItem(title: "Female"),
            ModernSegmentedItem(title: "Male")
        ],
        selectedIndex: $index,
        selectedSegmentColor: .blue,
        selectedTextColor: .white
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
}

@available(iOS 17.0, *)
#Preview("2 segments - RTL") {
    @Previewable @State var index = 0
    ModernSegmentedControl(
        items: [
            ModernSegmentedItem(title: "أنثى"),
            ModernSegmentedItem(title: "ذكر")
        ],
        selectedIndex: $index,
        selectedSegmentColor: .pink,
        selectedTextColor: .white
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
    .environment(\.layoutDirection, .rightToLeft)
}

@available(iOS 17.0, *)
#Preview("Multi segments with icons") {
    @Previewable @State var index = 0
    ModernSegmentedControl(
        items: [
            ModernSegmentedItem(title: "Ads", iconName: "megaphone", selectedIconName: "megaphone.fill"),
            ModernSegmentedItem(title: "Food", iconName: "cart", selectedIconName: "cart.fill"),
            ModernSegmentedItem(title: "Vet", iconName: "cross.case", selectedIconName: "cross.case.fill")
        ],
        selectedIndex: $index,
        selectedSegmentColor: .pink
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
}

@available(iOS 17.0, *)
#Preview("Hidden chrome") {
    @Previewable @State var index = 0
    ModernSegmentedControl(
        titles: ["Option A", "Option B", "Option C"],
        selectedIndex: $index,
        hidesContainerChrome: true
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
}

@available(iOS 17.0, *)
#Preview("Loading") {
    @Previewable @State var index = 1
    ModernSegmentedControl(
        titles: ["One", "Two", "Three"],
        selectedIndex: $index,
        state: .loading
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
}

@available(iOS 17.0, *)
#Preview("Empty") {
    @Previewable @State var index = -1
    ModernSegmentedControl(
        titles: [],
        selectedIndex: $index
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
}

@available(iOS 17.0, *)
#Preview("Error") {
    @Previewable @State var index = 1
    ModernSegmentedControl(
        titles: ["One", "Two", "Three"],
        selectedIndex: $index,
        state: .error(nil),
        retryAction: {}
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
}

@available(iOS 17.0, *)
#Preview("Disabled") {
    @Previewable @State var index = 1
    ModernSegmentedControl(
        titles: ["One", "Two", "Three"],
        selectedIndex: $index
    )
    .padding(.horizontal, 16)
    .frame(height: 50)
    .disabled(true)
}
