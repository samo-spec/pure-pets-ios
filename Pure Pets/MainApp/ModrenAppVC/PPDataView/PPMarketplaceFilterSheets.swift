import SwiftUI

@available(iOS 15.0, *)
struct PPMarketplaceCategorySheet: View {
    @ObservedObject var store: PPMarketplaceDataViewStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .zIndex(2)

            ZStack(alignment: .bottom) {
                Color.ppMarketplaceCanvas
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: PPSpace.xl) {
                        categoryIdentity

                        PPMarketplaceCategoryChoiceGroup(
                            title: PPMarketplaceText.localized(
                                "marketplace_category_main_kind_title"
                            ),
                            icon: "pawprint.fill",
                            choices: store.mainKindChoices.map {
                                PPMarketplaceCategoryChoice(
                                    id: $0.id,
                                    title: $0.title
                                )
                            },
                            selectedID: store.categoryDraftMainKindID,
                            accent: store.accentColor,
                            select: { selected in
                                guard let choice = store.mainKindChoices.first(
                                    where: { $0.id == selected.id }
                                ) else {
                                    return
                                }
                                store.selectCategoryMainKind(choice)
                            }
                        )

                        PPMarketplaceCategoryChoiceGroup(
                            title: PPMarketplaceText.localized(
                                "marketplace_category_subkind_title"
                            ),
                            icon: "circle.hexagongrid.fill",
                            choices: store.categoryDraftSubKindChoices.map {
                                PPMarketplaceCategoryChoice(
                                    id: $0.id,
                                    title: $0.title
                                )
                            },
                            selectedID: store.categoryDraftSubKindID,
                            accent: store.accentColor,
                            select: { selected in
                                guard let choice = store.categoryDraftSubKindChoices.first(
                                    where: { $0.id == selected.id }
                                ) else {
                                    return
                                }
                                store.selectCategorySubKind(choice)
                            }
                        )

                        Color.clear
                            .frame(
                                height: dynamicTypeSize.isAccessibilitySize
                                    ? 196
                                    : 116
                            )
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.top, PPSpace.base)
                }

                categoryActionBar
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var navigationBar: some View {
        HStack(spacing: PPSpace.sm) {
            Button {
                store.cancelCategoryEditing()
            } label: {
                Text(PPMarketplaceText.localized("cancel"))
                    .font(HomeFont.bold(14))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Color.ppMarketplaceSurface,
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.35), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: PPSpace.xs)

            Text(PPMarketplaceText.localized("marketplace_category_title"))
                .font(HomeFont.bold(17))
                .foregroundStyle(Color.ppMarketplaceTextPrimary)
                .lineLimit(1)

            Spacer(minLength: PPSpace.xs)

            Color.clear
                .frame(width: 58, height: 36)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Color.ppMarketplaceSurface
                .ignoresSafeArea(edges: .top)
                .overlay(Divider(), alignment: .bottom)
        )
    }

    private var categoryIdentity: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(uiColor: store.accentColor))
                .frame(width: 44, height: 44)
                .background(
                    Color(uiColor: store.accentColor).opacity(0.11),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(
                    PPMarketplaceText.localized(
                        "marketplace_category_sheet_subtitle"
                    )
                )
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppMarketplaceTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    PPMarketplaceText.formatted(
                        "marketplace_category_main_kind_format",
                        categoryDraftMainKindTitle
                    )
                )
                .font(HomeFont.headline())
                .foregroundStyle(Color.ppMarketplaceTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    PPMarketplaceText.formatted(
                        "marketplace_category_subkind_format",
                        categoryDraftSubKindTitle
                    )
                )
                .font(HomeFont.footnote())
                .foregroundStyle(Color.ppMarketplaceTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    Color.ppMarketplaceSeparator.opacity(0.20),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var categoryActionBar: some View {
        VStack(spacing: PPSpace.sm) {
            Divider()

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: PPSpace.sm) {
                        clearCategoryButton
                        applyCategoryButton
                    }
                } else {
                    HStack(spacing: PPSpace.md) {
                        clearCategoryButton
                        applyCategoryButton
                    }
                }
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.bottom, PPSpace.sm)
        .background(.ultraThinMaterial)
    }

    private var clearCategoryButton: some View {
        Button(action: store.clearCategoryDraft) {
            Text(
                PPMarketplaceText.localized("marketplace_category_clear")
            )
            .font(HomeFont.bold(16))
            .foregroundStyle(Color(uiColor: store.accentColor))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                Color.ppMarketplaceSurface,
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
                .strokeBorder(
                    Color(uiColor: store.accentColor).opacity(0.34),
                    lineWidth: 1
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_clear_hint")
        )
    }

    private var applyCategoryButton: some View {
        Button(action: store.applyCategoryDraft) {
            Text(
                PPMarketplaceText.localized("marketplace_category_apply")
            )
            .font(HomeFont.bold(16))
            .foregroundStyle(store.accentPalette.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                store.accentPalette.fill,
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(
            PPMarketplaceText.localized("marketplace_category_apply_hint")
        )
    }

    private var categoryDraftMainKindTitle: String {
        store.mainKindChoices.first(where: {
            $0.id == store.categoryDraftMainKindID
        })?.title ?? store.currentMainKindTitle
    }

    private var categoryDraftSubKindTitle: String {
        store.categoryDraftSubKindChoices.first(where: {
            $0.id == store.categoryDraftSubKindID
        })?.title ?? store.currentSubKindTitle
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceCategoryChoice: Identifiable {
    let id: Int
    let title: String
}

@available(iOS 15.0, *)
private struct PPMarketplaceCategoryChoiceGroup: View {
    let title: String
    let icon: String
    let choices: [PPMarketplaceCategoryChoice]
    let selectedID: Int
    let accent: UIColor
    let select: (PPMarketplaceCategoryChoice) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Label {
                Text(title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(uiColor: accent))
            }
            .accessibilityAddTraits(.isHeader)

            if choices.isEmpty {
                Text(
                    PPMarketplaceText.localized(
                        "marketplace_category_no_subkinds"
                    )
                )
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppMarketplaceTextSecondary)
                .padding(PPSpace.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(
                    Color(uiColor: .tertiarySystemBackground),
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    )
                )
            } else {
                LazyVStack(spacing: PPSpace.sm) {
                    ForEach(choices) { choice in
                        choiceButton(choice)
                    }
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    Color.ppMarketplaceSeparator.opacity(0.18),
                    lineWidth: 1
                )
        }
    }

    private func choiceButton(
        _ choice: PPMarketplaceCategoryChoice
    ) -> some View {
        let selected = choice.id == selectedID
        return Button {
            select(choice)
        } label: {
            HStack(spacing: PPSpace.sm) {
                Text(choice.title)
                    .font(HomeFont.bold(15))
                    .foregroundStyle(
                        selected
                            ? Color(uiColor: accent)
                            : Color.ppMarketplaceTextPrimary
                    )
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: PPSpace.sm)

                Image(
                    systemName: selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(
                    selected
                        ? Color(uiColor: accent)
                        : Color.ppMarketplaceTextSecondary
                )
                .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, PPSpace.sm)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                selected
                    ? Color(uiColor: accent).opacity(0.10)
                    : Color(uiColor: .tertiarySystemBackground),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
                .strokeBorder(
                    selected
                        ? Color(uiColor: accent).opacity(0.50)
                        : Color.ppMarketplaceSeparator.opacity(0.16),
                    lineWidth: selected ? 1.5 : 1
                )
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .animation(
                selectionMotionIsDisabled
                    ? nil
                    : .easeOut(duration: 0.16),
                value: selected
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            PPMarketplaceText.localized(
                selected
                    ? "marketplace_selected"
                    : "marketplace_not_selected"
            )
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceFilterSheet: View {
    @ObservedObject var store: PPMarketplaceDataViewStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var activeDraftCount: Int {
        store.filterDraft?.activeFilterCount() ?? 0
    }

    private var isMotionDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            commandHorizonHeader
                .zIndex(3)

            ZStack(alignment: .bottom) {
                ambientCanvasBackground

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: PPSpace.base) {
                        refinementContextHero

                        if let draft = store.filterDraft {
                            ForEach(draft.groups, id: \.filterID) { group in
                                PPMarketplaceAdaptiveFilterGroupView(
                                    group: group,
                                    accent: store.accentColor,
                                    isRightToLeft: store.isRightToLeft,
                                    select: { value in
                                        store.selectFilterOption(
                                            groupID: group.filterID,
                                            value: value
                                        )
                                    }
                                )
                            }
                        }

                        Color.clear
                            .frame(
                                height: dynamicTypeSize.isAccessibilitySize ? 170 : 124
                            )
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.top, PPSpace.sm)
                }

                floatingApplyDeck
                    .zIndex(2)
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    // MARK: - Luminous Ambient Canvas
    private var ambientCanvasBackground: some View {
        ZStack {
            Color.ppMarketplaceCanvas
                .ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(
                        color: Color(uiColor: store.accentColor).opacity(
                            colorScheme == .dark ? 0.16 : 0.08
                        ),
                        location: 0
                    ),
                    .init(
                        color: Color(uiColor: store.accentColor).opacity(
                            colorScheme == .dark ? 0.04 : 0.02
                        ),
                        location: 0.35
                    ),
                    .init(
                        color: Color.clear,
                        location: 0.70
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Luminous Command Horizon (Unified Header)
    private var commandHorizonHeader: some View {
        HStack(spacing: PPSpace.sm) {
            // Dismiss Button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.cancelFilterEditing()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Color.ppMarketplaceSurface,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                Color.ppMarketplaceSeparator.opacity(colorScheme == .dark ? 0.32 : 0.22),
                                lineWidth: 0.8
                            )
                    }
            }
            .buttonStyle(PPMarketplaceScaleButtonStyle())
            .accessibilityLabel(PPMarketplaceText.localized("marketplace_dismiss"))

            Spacer(minLength: PPSpace.xs)

            // Center Refinement Scope Emblem
            HStack(spacing: 8) {
                Image(systemName: store.currentSectionDescriptor.iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(uiColor: store.accentColor))
                    .frame(width: 24, height: 24)
                    .background(
                        Color(uiColor: store.accentColor).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )

                Text(PPMarketplaceText.localized("marketplace_filters_title"))
                    .font(HomeFont.bold(16))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .lineLimit(1)

                if activeDraftCount > 0 {
                    Text(verbatim: "\(activeDraftCount)")
                        .font(HomeFont.bold(11))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Color(uiColor: store.accentColor),
                            in: Capsule(style: .continuous)
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Color.ppMarketplaceSurface.opacity(0.85),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        activeDraftCount > 0
                            ? Color(uiColor: store.accentColor).opacity(0.35)
                            : Color.ppMarketplaceSeparator.opacity(0.20),
                        lineWidth: activeDraftCount > 0 ? 1.2 : 0.8
                    )
            }
            .animation(isMotionDisabled ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: activeDraftCount)

            Spacer(minLength: PPSpace.xs)

            // Reset Action
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.resetFilterDraft()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text(PPMarketplaceText.localized("marketplace_reset"))
                        .font(HomeFont.bold(13))
                }
                .foregroundStyle(
                    activeDraftCount > 0
                        ? Color(uiColor: store.accentColor)
                        : Color.ppMarketplaceTextSecondary.opacity(0.40)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    activeDraftCount > 0
                        ? Color(uiColor: store.accentColor).opacity(0.12)
                        : Color.ppMarketplaceSurface,
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            activeDraftCount > 0
                                ? Color(uiColor: store.accentColor).opacity(0.35)
                                : Color.ppMarketplaceSeparator.opacity(0.25),
                            lineWidth: 0.8
                        )
                }
            }
            .buttonStyle(PPMarketplaceScaleButtonStyle())
            .disabled(activeDraftCount == 0)
            .animation(isMotionDisabled ? nil : .easeInOut(duration: 0.18), value: activeDraftCount)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Color.ppMarketplaceSurface
                .opacity(0.96)
                .ignoresSafeArea(edges: .top)
                .overlay(
                    Divider().opacity(colorScheme == .dark ? 0.35 : 0.20),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Refinement Context Hero
    private var refinementContextHero: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: store.accentColor).opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: store.currentSectionDescriptor.iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(uiColor: store.accentColor))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.contextAccessibilityLabel)
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)

                Text(
                    activeDraftCount > 0
                        ? (store.isRightToLeft
                            ? "\(activeDraftCount) فلاتر مفعّلة • تحديث فوري للمعاينة"
                            : "\(activeDraftCount) active filters • Live preview updated")
                        : PPMarketplaceText.localized("marketplace_filters_subtitle")
                )
                .font(HomeFont.footnote())
                .foregroundStyle(
                    activeDraftCount > 0
                        ? Color(uiColor: store.accentColor)
                        : Color.ppMarketplaceTextSecondary
                )
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            }

            Spacer(minLength: PPSpace.xs)

            if activeDraftCount > 0 {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(uiColor: store.accentColor))
                    .padding(8)
                    .background(
                        Color(uiColor: store.accentColor).opacity(0.12),
                        in: Circle()
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    activeDraftCount > 0
                        ? Color(uiColor: store.accentColor).opacity(0.30)
                        : Color.ppMarketplaceSeparator.opacity(0.16),
                    lineWidth: 1
                )
        }
        .shadow(
            color: activeDraftCount > 0
                ? Color(uiColor: store.accentColor).opacity(colorScheme == .dark ? 0.12 : 0.06)
                : Color.clear,
            radius: 8,
            y: 3
        )
        .animation(isMotionDisabled ? nil : .spring(response: 0.32, dampingFraction: 0.8), value: activeDraftCount)
    }

    // MARK: - Floating Refinement Apply Deck
    private var floatingApplyDeck: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(colorScheme == .dark ? 0.35 : 0.20)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.applyFilterDraft()
            } label: {
                HStack(spacing: PPSpace.sm) {
                    Text(PPMarketplaceText.localized("marketplace_apply_filters"))
                        .font(HomeFont.bold(17))

                    Spacer(minLength: PPSpace.sm)

                    // Live Result Count Pill
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(store.filterPreviewCountText)
                            .font(HomeFont.bold(13))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        store.accentPalette.onAccent.opacity(0.20),
                        in: Capsule(style: .continuous)
                    )
                    .id(store.filterPreviewCountText)
                    .transition(
                        isMotionDisabled
                            ? .opacity
                            : .scale(scale: 0.95).combined(with: .opacity)
                    )
                }
                .foregroundStyle(store.accentPalette.onAccent)
                .padding(.horizontal, PPSpace.base)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    store.accentPalette.fill,
                    in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(colorScheme == .dark ? 0.25 : 0.35),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: Color(uiColor: store.accentColor).opacity(colorScheme == .dark ? 0.40 : 0.28),
                    radius: 12,
                    y: 5
                )
            }
            .buttonStyle(PPMarketplaceScaleButtonStyle())
            .disabled(store.filterDraft == nil)
            .accessibilityHint(
                PPMarketplaceText.localized("marketplace_apply_filters_hint")
            )
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.sm)
            .padding(.bottom, PPSpace.sm)
        }
        .background(
            Color.ppMarketplaceSurface
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Adaptive Filter Group Router
@available(iOS 15.0, *)
private struct PPMarketplaceAdaptiveFilterGroupView: View {
    let group: PPFilterGroup
    let accent: UIColor
    let isRightToLeft: Bool
    let select: (Int) -> Void

    var body: some View {
        if group.filterID == PPFilterIDGender || group.filterID == "gender" {
            PPMarketplaceGenderSegmentedGroup(
                group: group,
                accent: accent,
                isRightToLeft: isRightToLeft,
                select: select
            )
        } else if group.filterID == PPFilterIDPrice || group.filterID == "price" {
            PPMarketplacePriceSpectrumGroup(
                group: group,
                accent: accent,
                isRightToLeft: isRightToLeft,
                select: select
            )
        } else if group.filterID == PPFilterIDSort || group.filterID == "sort" {
            PPMarketplaceSortVectorGroup(
                group: group,
                accent: accent,
                isRightToLeft: isRightToLeft,
                select: select
            )
        } else {
            PPMarketplaceGenericAdaptiveGroup(
                group: group,
                accent: accent,
                isRightToLeft: isRightToLeft,
                select: select
            )
        }
    }
}

// MARK: - Specialized Group 1: Gender Tactile Segmented Controller
@available(iOS 15.0, *)
private struct PPMarketplaceGenderSegmentedGroup: View {
    let group: PPFilterGroup
    let accent: UIColor
    let isRightToLeft: Bool
    let select: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var isMotionDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            // Header
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(uiColor: accent))
                    .accessibilityHidden(true)

                Text(group.title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: PPSpace.xs)

                if let selected = group.selectedOption() {
                    Text(selected.title)
                        .font(HomeFont.bold(12))
                        .foregroundStyle(Color(uiColor: accent))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Color(uiColor: accent).opacity(0.12),
                            in: Capsule(style: .continuous)
                        )
                }
            }

            // 2x2 Tactile Card Grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: PPSpace.sm),
                    GridItem(.flexible(), spacing: PPSpace.sm)
                ],
                spacing: PPSpace.sm
            ) {
                ForEach(group.options, id: \.value) { option in
                    let isSelected = option.value == group.selectedValue
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        select(option.value)
                    } label: {
                        HStack(spacing: 8) {
                            genderIcon(for: option.value, defaultName: option.iconName)
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected
                                        ? Color(uiColor: accent).opacity(0.18)
                                        : Color(uiColor: .tertiarySystemFill),
                                    in: Circle()
                                )

                            Text(option.title)
                                .font(HomeFont.bold(14))
                                .foregroundStyle(
                                    isSelected
                                        ? Color(uiColor: accent)
                                        : Color.ppMarketplaceTextPrimary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 2)

                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? Color(uiColor: accent)
                                    : Color.ppMarketplaceTextSecondary.opacity(0.50)
                            )
                            .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            isSelected
                                ? Color(uiColor: accent).opacity(colorScheme == .dark ? 0.20 : 0.11)
                                : Color(uiColor: .tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? Color(uiColor: accent).opacity(0.65)
                                        : Color.ppMarketplaceSeparator.opacity(0.18),
                                    lineWidth: isSelected ? 1.5 : 1.0
                                )
                        }
                    }
                    .buttonStyle(PPMarketplaceScaleButtonStyle())
                    .accessibilityValue(
                        isSelected
                            ? PPMarketplaceText.localized("marketplace_selected")
                            : PPMarketplaceText.localized("marketplace_not_selected")
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .animation(isMotionDisabled ? nil : .easeOut(duration: 0.15), value: isSelected)
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func genderIcon(for value: Int, defaultName: String?) -> some View {
        if value == 1, let img = UIImage(named: "male") {
            Image(uiImage: img)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color(uiColor: accent))
        } else if value == 2, let img = UIImage(named: "female") {
            Image(uiImage: img)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .foregroundStyle(Color(uiColor: accent))
        } else if value == 0 {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: accent))
        } else if let icon = defaultName, !icon.isEmpty {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: accent))
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: accent))
        }
    }
}

// MARK: - Specialized Group 2: Price Spectrum Tiers
@available(iOS 15.0, *)
private struct PPMarketplacePriceSpectrumGroup: View {
    let group: PPFilterGroup
    let accent: UIColor
    let isRightToLeft: Bool
    let select: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var isMotionDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            // Header
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(uiColor: accent))
                    .accessibilityHidden(true)

                Text(group.title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: PPSpace.xs)

                if let selected = group.selectedOption() {
                    Text(selected.title)
                        .font(HomeFont.bold(12))
                        .foregroundStyle(Color(uiColor: accent))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Color(uiColor: accent).opacity(0.12),
                            in: Capsule(style: .continuous)
                        )
                }
            }

            // 2x2 Price Tier Cards
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: PPSpace.sm),
                    GridItem(.flexible(), spacing: PPSpace.sm)
                ],
                spacing: PPSpace.sm
            ) {
                ForEach(group.options, id: \.value) { option in
                    let isSelected = option.value == group.selectedValue
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        select(option.value)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: priceTierIcon(for: option.value))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(uiColor: accent))
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected
                                        ? Color(uiColor: accent).opacity(0.18)
                                        : Color(uiColor: .tertiarySystemFill),
                                    in: Circle()
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.title)
                                    .font(HomeFont.bold(14))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color(uiColor: accent)
                                            : Color.ppMarketplaceTextPrimary
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(priceTierSubtitle(for: option.value))
                                    .font(HomeFont.caption2())
                                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 2)

                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? Color(uiColor: accent)
                                    : Color.ppMarketplaceTextSecondary.opacity(0.50)
                            )
                            .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            isSelected
                                ? Color(uiColor: accent).opacity(colorScheme == .dark ? 0.20 : 0.11)
                                : Color(uiColor: .tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? Color(uiColor: accent).opacity(0.65)
                                        : Color.ppMarketplaceSeparator.opacity(0.18),
                                    lineWidth: isSelected ? 1.5 : 1.0
                                )
                        }
                    }
                    .buttonStyle(PPMarketplaceScaleButtonStyle())
                    .accessibilityValue(
                        isSelected
                            ? PPMarketplaceText.localized("marketplace_selected")
                            : PPMarketplaceText.localized("marketplace_not_selected")
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .animation(isMotionDisabled ? nil : .easeOut(duration: 0.15), value: isSelected)
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.18), lineWidth: 1)
        }
    }

    private func priceTierIcon(for value: Int) -> String {
        switch value {
        case 0: return "sparkles"
        case 1: return "arrow.down.forward"
        case 2: return "equal"
        case 3: return "crown.fill"
        default: return "tag.fill"
        }
    }

    private func priceTierSubtitle(for value: Int) -> String {
        switch value {
        case 0: return isRightToLeft ? "كامل النطاق" : "Full range"
        case 1: return isRightToLeft ? "اقتصادي" : "Budget"
        case 2: return isRightToLeft ? "متوسط" : "Mid-tier"
        case 3: return isRightToLeft ? "مميز" : "Premium"
        default: return ""
        }
    }
}

// MARK: - Specialized Group 3: Directional Sort Vectors
@available(iOS 15.0, *)
private struct PPMarketplaceSortVectorGroup: View {
    let group: PPFilterGroup
    let accent: UIColor
    let isRightToLeft: Bool
    let select: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var isMotionDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            // Header
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(uiColor: accent))
                    .accessibilityHidden(true)

                Text(group.title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: PPSpace.xs)

                if let selected = group.selectedOption() {
                    Text(selected.title)
                        .font(HomeFont.bold(12))
                        .foregroundStyle(Color(uiColor: accent))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Color(uiColor: accent).opacity(0.12),
                            in: Capsule(style: .continuous)
                        )
                }
            }

            // 2x2 Sort Cards
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: PPSpace.sm),
                    GridItem(.flexible(), spacing: PPSpace.sm)
                ],
                spacing: PPSpace.sm
            ) {
                ForEach(group.options, id: \.value) { option in
                    let isSelected = option.value == group.selectedValue
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        select(option.value)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sortIcon(for: option.value))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(uiColor: accent))
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected
                                        ? Color(uiColor: accent).opacity(0.18)
                                        : Color(uiColor: .tertiarySystemFill),
                                    in: Circle()
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.title)
                                    .font(HomeFont.bold(14))
                                    .foregroundStyle(
                                        isSelected
                                            ? Color(uiColor: accent)
                                            : Color.ppMarketplaceTextPrimary
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(sortSubtitle(for: option.value))
                                    .font(HomeFont.caption2())
                                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 2)

                            Image(
                                systemName: isSelected
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? Color(uiColor: accent)
                                    : Color.ppMarketplaceTextSecondary.opacity(0.50)
                            )
                            .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            isSelected
                                ? Color(uiColor: accent).opacity(colorScheme == .dark ? 0.20 : 0.11)
                                : Color(uiColor: .tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? Color(uiColor: accent).opacity(0.65)
                                        : Color.ppMarketplaceSeparator.opacity(0.18),
                                    lineWidth: isSelected ? 1.5 : 1.0
                                )
                        }
                    }
                    .buttonStyle(PPMarketplaceScaleButtonStyle())
                    .accessibilityValue(
                        isSelected
                            ? PPMarketplaceText.localized("marketplace_selected")
                            : PPMarketplaceText.localized("marketplace_not_selected")
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .animation(isMotionDisabled ? nil : .easeOut(duration: 0.15), value: isSelected)
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.18), lineWidth: 1)
        }
    }

    private func sortIcon(for value: Int) -> String {
        switch value {
        case 0: return "sparkles"
        case 1: return "chart.line.uptrend.xyaxis"
        case 2: return "chart.line.downtrend.xyaxis"
        default: return "clock.arrow.circlepath"
        }
    }

    private func sortSubtitle(for value: Int) -> String {
        switch value {
        case 0: return isRightToLeft ? "تطابق ذكي" : "Best match"
        case 1: return isRightToLeft ? "تصاعدياً" : "Ascending"
        case 2: return isRightToLeft ? "تنازلياً" : "Descending"
        default: return isRightToLeft ? "أحدث العروض" : "Newest first"
        }
    }
}

// MARK: - Specialized Group 4: Generic Category / Service Adaptive Group
@available(iOS 15.0, *)
private struct PPMarketplaceGenericAdaptiveGroup: View {
    let group: PPFilterGroup
    let accent: UIColor
    let isRightToLeft: Bool
    let select: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var isMotionDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                if let icon = group.chipIconName, !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(uiColor: accent))
                        .accessibilityHidden(true)
                }
                Text(group.title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                if let selected = group.selectedOption() {
                    Text(selected.title)
                        .font(HomeFont.bold(12))
                        .foregroundStyle(Color(uiColor: accent))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Color(uiColor: accent).opacity(0.12),
                            in: Capsule(style: .continuous)
                        )
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    optionViews
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 132), spacing: PPSpace.sm)
                    ],
                    spacing: PPSpace.sm
                ) {
                    optionViews
                }
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var optionViews: some View {
        ForEach(group.options, id: \.value) { option in
            let selected = option.value == group.selectedValue
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                select(option.value)
            } label: {
                HStack(spacing: PPSpace.sm) {
                    if let icon = option.iconName, !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(
                                selected
                                    ? Color(uiColor: accent)
                                    : Color.ppMarketplaceTextSecondary
                            )
                            .accessibilityHidden(true)
                    }
                    Text(option.title)
                        .font(HomeFont.bold(14))
                        .foregroundStyle(
                            selected
                                ? Color(uiColor: accent)
                                : Color.ppMarketplaceTextPrimary
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: PPSpace.xs)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            selected
                                ? Color(uiColor: accent)
                                : Color.ppMarketplaceTextSecondary.opacity(0.50)
                        )
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, PPSpace.md)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    selected
                        ? Color(uiColor: accent).opacity(colorScheme == .dark ? 0.20 : 0.11)
                        : Color(uiColor: .tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        .strokeBorder(
                            selected
                                ? Color(uiColor: accent).opacity(0.65)
                                : Color.ppMarketplaceSeparator.opacity(0.18),
                            lineWidth: selected ? 1.5 : 1.0
                        )
                }
            }
            .buttonStyle(PPMarketplaceScaleButtonStyle())
            .accessibilityValue(
                selected
                    ? PPMarketplaceText.localized("marketplace_selected")
                    : PPMarketplaceText.localized("marketplace_not_selected")
            )
            .accessibilityAddTraits(selected ? .isSelected : [])
            .animation(isMotionDisabled ? nil : .easeOut(duration: 0.15), value: selected)
        }
    }
}

// MARK: - Tactical Button Style
@available(iOS 15.0, *)
private struct PPMarketplaceScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.97 : 1.0
            )
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceProviderSheet: View {
    @ObservedObject var store: PPMarketplaceDataViewStore

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
                .zIndex(2)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: PPSpace.sm) {
                    providerRow(
                        id: nil,
                        title: PPMarketplaceText.localized("marketplace_all_providers"),
                        photoURL: nil,
                        itemCount: store.unfilteredResultCount,
                        icon: "square.grid.2x2.fill"
                    )

                    ForEach(store.providerOptions, id: \.providerID) { provider in
                        providerRow(
                            id: provider.providerID,
                            title: provider.title,
                            photoURL: provider.photoURL,
                            itemCount: provider.itemCount,
                            icon: "storefront.fill"
                        )
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, PPSpace.base)
            }
            .background(Color.ppMarketplaceCanvas.ignoresSafeArea())
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var navigationBar: some View {
        HStack(spacing: PPSpace.sm) {
            Button {
                store.dismissActiveSheet()
            } label: {
                Text(PPMarketplaceText.localized("Done"))
                    .font(HomeFont.bold(14))
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Color.ppMarketplaceSurface,
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.35), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)

            Spacer(minLength: PPSpace.xs)

            Text(PPMarketplaceText.localized("marketplace_providers_title"))
                .font(HomeFont.bold(17))
                .foregroundStyle(Color.ppMarketplaceTextPrimary)
                .lineLimit(1)

            Spacer(minLength: PPSpace.xs)

            Color.clear
                .frame(width: 58, height: 36)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Color.ppMarketplaceSurface
                .ignoresSafeArea(edges: .top)
                .overlay(Divider(), alignment: .bottom)
        )
    }

    private func providerRow(
        id: String?,
        title: String,
        photoURL: String?,
        itemCount: Int,
        icon: String
    ) -> some View {
        let selected = store.selectedProviderID == id
        return Button {
            store.selectProvider(id)
        } label: {
            HStack(spacing: PPSpace.md) {
                providerAvatar(title: title, photoURL: photoURL, icon: icon)

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(title)
                        .font(HomeFont.headline())
                        .foregroundStyle(Color.ppMarketplaceTextPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                    Text(
                        PPMarketplaceText.formatted(
                            "marketplace_provider_items_format",
                            itemCount
                        )
                    )
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: PPSpace.sm)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        selected
                            ? Color(uiColor: store.accentColor)
                            : Color.ppMarketplaceTextSecondary
                    )
                    .accessibilityHidden(true)
            }
            .padding(PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                selected
                    ? Color(uiColor: store.accentColor).opacity(0.08)
                    : Color.ppMarketplaceSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .strokeBorder(
                        selected
                            ? Color(uiColor: store.accentColor).opacity(0.68)
                            : Color.ppMarketplaceSeparator.opacity(0.32),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .contentShape(
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            selected
                ? PPMarketplaceText.localized("marketplace_selected")
                : PPMarketplaceText.localized("marketplace_not_selected")
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func providerAvatar(
        title: String,
        photoURL: String?,
        icon: String
    ) -> some View {
        ZStack {
            Color(uiColor: store.accentColor).opacity(0.10)
            if let photoURL, !photoURL.isEmpty {
                AppRemoteImage(
                    urlString: photoURL,
                    cacheKey: "pp.marketplace.provider.\(photoURL)",
                    displaySize: CGSize(width: 96, height: 96),
                    contentMode: .fill,
                    showsRetryAction: false
                )
            } else {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(uiColor: store.accentColor))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.16), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
