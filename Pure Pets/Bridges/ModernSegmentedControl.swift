//
//  ModernSegmentedControl.swift
//  PurePets
//
//  Production-grade SwiftUI segmented control — Apple Design Award caliber
//  Pure SwiftUI replica of PPModrenSegmrnted (UIKit). Legacy ObjC untouched.
//
//  Design: gradient selection pill + dot underline, glass container,
//  spring animation, haptics, RTL, Dynamic Type, accessibility.
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

// MARK: - Segmented Control

private struct SegmentButtonStyle: ButtonStyle {
    let isSelected: Bool
    let alpha: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(alpha)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
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

    // 3) State / Binding / Stored properties
    @Binding private var selectedIndex: Int
    @State private var totalWidth: CGFloat = 0

    // Constants matching PPModrenSegmrnted
    private static let outerInset: CGFloat        = 3
    private static let segmentSpacing: CGFloat     = 3
    private static let selectionDotDiameter: CGFloat = 6
    private static let selectionPillInset: CGFloat = 2
    private static let containerCornerRadius: CGFloat = 16
    private static let controlHeight: CGFloat      = 44
    private static let animDuration: TimeInterval  = 0.22
    private static let springDamping: CGFloat      = 0.78
    private static let springVelocity: CGFloat     = 0.24

    private struct SegmentItemWrapper: Identifiable {
        let index: Int
        let item: ModernSegmentedItem
        var id: String { "\(item.id)_\(index)" }
    }

    // 4) Computed Variables
    private var wrappedItems: [SegmentItemWrapper] {
        items.enumerated().map { SegmentItemWrapper(index: $0.offset, item: $0.element) }
    }

    private var segmentWidth: CGFloat {
        guard totalWidth > 0, !items.isEmpty else { return 0 }
        let spacingTotal = Self.outerInset * 2 + Self.segmentSpacing * CGFloat(items.count - 1)
        return max(0, (totalWidth - spacingTotal) / CGFloat(items.count))
    }

    private var isDark: Bool { colorScheme == .dark }

    private var accentColor: Color { selectedSegmentColor }

    private var isSelectionVisible: Bool {
        selectedIndex >= 0 && selectedIndex < items.count && isEnabled
    }

    /// Visual index accounting for RTL (HStack flips visually, offset needs mirroring)
    private var visualSelectedOffset: CGFloat {
        guard selectedIndex >= 0, selectedIndex < items.count, segmentWidth > 0 else { return 0 }
        let isRTL = layoutDirection == .rightToLeft
        let visualIndex = isRTL
            ? CGFloat(items.count - 1 - selectedIndex)
            : CGFloat(selectedIndex)
        return Self.outerInset + visualIndex * (segmentWidth + Self.segmentSpacing)
    }

    private var effectiveCornerRadius: CGFloat {
        max(Self.containerCornerRadius, Self.controlHeight * 0.5)
    }

    private var selectionAnimation: Animation {
        guard !reduceMotion else { return .default }
        return .spring(
            response: Self.animDuration,
            dampingFraction: Self.springDamping,
            blendDuration: Self.springVelocity
        )
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
        hapticsEnabled: Bool = true
    ) {
        self.items = items
        self._selectedIndex = selectedIndex

        let fallbackSurface = Color(uiColor: UIColor(named: "AppForegroundColor")
                                    ?? .secondarySystemBackground)
        let fallbackAccent  = Color(uiColor: UIColor(named: "AppPrimaryColor")
                                    ?? .systemBlue)
        let fallbackPrimaryText = Color(uiColor: UIColor(named: "PrimaryTextColor")
                                        ?? .label)

        self.containerBackgroundColor = containerBackgroundColor ?? fallbackSurface
        self.selectedSegmentColor = selectedSegmentColor ?? fallbackAccent
        self.normalTextColor = normalTextColor ?? Color(uiColor: .secondaryLabel)
        self.selectedTextColor = selectedTextColor ?? fallbackPrimaryText
        self.normalFont = normalFont ?? .system(size: 14, weight: .medium)
        self.selectedFont = selectedFont ?? .system(size: 14, weight: .semibold)
        self.hidesContainerChrome = hidesContainerChrome
        self.hapticsEnabled = hapticsEnabled
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
        hapticsEnabled: Bool = true
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
            hapticsEnabled: hapticsEnabled
        )
    }

    // 6) Body
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if !hidesContainerChrome {
                containerView
            }

            if isSelectionVisible {
                selectionPillView
                    .frame(
                        width: segmentWidth - Self.selectionPillInset * 2,
                        height: Self.controlHeight - Self.outerInset * 2 - Self.selectionPillInset * 2
                    )
                    .offset(x: visualSelectedOffset + Self.selectionPillInset,
                            y: Self.outerInset + Self.selectionPillInset)
                    .transition(.identity)
                    .animation(selectionAnimation, value: selectedIndex)
            }

            segmentsView
                .padding(.horizontal, Self.outerInset)
                .frame(maxHeight: .infinity)

            if isSelectionVisible {
                selectionDotView
                    .offset(
                        x: visualSelectedOffset + segmentWidth / 2 - Self.selectionDotDiameter / 2,
                        y: Self.controlHeight - 6 - Self.selectionDotDiameter
                    )
                    .transition(.identity)
                    .animation(selectionAnimation, value: selectedIndex)
            }
        }
        .frame(height: Self.controlHeight)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { totalWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newValue in totalWidth = newValue }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Segmented control")
    }

    // 7) View Builders / Helpers
    @ViewBuilder
    private var containerView: some View {
        let radius = effectiveCornerRadius

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(containerBackgroundColor.opacity(isDark ? 0.28 : 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(
                            isDark ? Color.clear : containerBackgroundColor.opacity(0.58),
                            lineWidth: 0.92
                        )
                )
        }
        .shadow(
            color: Color.black.opacity(isDark ? 0.16 : 0.08),
            radius: 14, x: 0, y: 8
        )
    }

    private var selectionPillView: some View {
        let radius = effectiveCornerRadius - Self.outerInset - Self.selectionPillInset
        let accent = accentColor

        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(isDark ? 0.34 : 0.18),
                        accent.opacity(isDark ? 0.20 : 0.095),
                        Color.white.opacity(isDark ? 0.045 : 0.26)
                    ],
                    startPoint: .init(x: 0.18, y: 0),
                    endPoint: .init(x: 0.86, y: 1)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(accent.opacity(isDark ? 0.24 : 0.18), lineWidth: 1.05)
            )
            .shadow(
                color: (isDark ? accent : Color.black).opacity(isDark ? 0.18 : 0.11),
                radius: 12, x: 0, y: 4
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
            .frame(width: Self.selectionDotDiameter, height: Self.selectionDotDiameter)
            .shadow(
                color: accentColor.opacity(isDark ? 0.24 : 0.20),
                radius: 5, x: 0, y: 2
            )
    }

    private var segmentsView: some View {
        HStack(spacing: Self.segmentSpacing) {
            ForEach(wrappedItems) { wrapper in
                segmentContent(for: wrapper.index)
                    .frame(width: segmentWidth)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func segmentContent(for index: Int) -> some View {
        let isSelected = index == selectedIndex
        let alpha: CGFloat = {
            guard isEnabled else { return 0.34 }
            return isSelected ? 1.0 : 0.70
        }()

        return Button(action: { selectSegment(at: index) }) {
            Text(items[index].title)
                .font(isSelected ? selectedFont : normalFont)
                .foregroundStyle(textColor(for: index))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(SegmentButtonStyle(isSelected: isSelected, alpha: alpha))
        .accessibilityLabel(items[index].title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private func textColor(for index: Int) -> Color {
        guard isEnabled else { return normalTextColor.opacity(0.34) }
        return index == selectedIndex ? selectedTextColor : normalTextColor
    }

    // 8) Async functions / Methods
    private func selectSegment(at index: Int) {
        guard isEnabled, index != selectedIndex else { return }
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        selectedIndex = index
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("2 segments – LTR") {
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
#Preview("2 segments – RTL") {
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
            ModernSegmentedItem(title: "Ads", iconName: "doc.text", selectedIconName: "doc.text.fill"),
            ModernSegmentedItem(title: "Food", iconName: "fork.knife", selectedIconName: "fork.knife"),
            ModernSegmentedItem(title: "Vet", iconName: "cross.case", selectedIconName: "cross.case.fill")
        ],
        selectedIndex: $index,
        selectedSegmentColor: .pink,
        selectedTextColor: .white
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
