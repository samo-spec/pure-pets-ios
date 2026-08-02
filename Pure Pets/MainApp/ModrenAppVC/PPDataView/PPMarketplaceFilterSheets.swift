import SwiftUI

@available(iOS 15.0, *)
struct PPMarketplaceCategorySheet: View {
    @ObservedObject var store: PPMarketplaceDataViewStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationContent
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationDragIndicator(.visible)
            } else {
                navigationContent
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var navigationContent: some View {
        NavigationView {
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
            .navigationTitle(
                PPMarketplaceText.localized("marketplace_category_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPMarketplaceText.localized("cancel")) {
                        store.cancelCategoryEditing()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
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

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationContent
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                navigationContent
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var navigationContent: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.ppMarketplaceCanvas
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: PPSpace.xl) {
                        filterIdentity

                        if let draft = store.filterDraft {
                            ForEach(draft.groups, id: \.filterID) { group in
                                PPMarketplaceFilterGroupView(
                                    group: group,
                                    accent: store.accentColor,
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
                            .frame(height: dynamicTypeSize.isAccessibilitySize ? 150 : 112)
                    }
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.top, PPSpace.base)
                }

                applyBar
            }
            .navigationTitle(PPMarketplaceText.localized("marketplace_filters_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPMarketplaceText.localized("cancel")) {
                        store.cancelFilterEditing()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(PPMarketplaceText.localized("marketplace_reset")) {
                        store.resetFilterDraft()
                    }
                    .disabled(store.filterDraft == nil)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var filterIdentity: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: store.currentSectionDescriptor.iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(uiColor: store.accentColor))
                .frame(width: 44, height: 44)
                .background(
                    Color(uiColor: store.accentColor).opacity(0.11),
                    in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(store.contextAccessibilityLabel)
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.ppMarketplaceTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PPMarketplaceText.localized("marketplace_filters_subtitle"))
                    .font(HomeFont.subheadline())
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.ppMarketplaceSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppMarketplaceSeparator.opacity(0.20), lineWidth: 1)
        }
    }

    private var applyBar: some View {
        VStack(spacing: PPSpace.sm) {
            Divider()
            Button {
                store.applyFilterDraft()
            } label: {
                HStack(spacing: PPSpace.sm) {
                    Text(PPMarketplaceText.localized("marketplace_apply_filters"))
                        .font(HomeFont.bold(17))
                    Spacer(minLength: PPSpace.sm)
                    Text(
                        PPMarketplaceText.formatted(
                            "marketplace_preview_count_format",
                            store.filterPreviewCount
                        )
                    )
                    .font(HomeFont.bold(14))
                    .padding(.horizontal, PPSpace.sm)
                    .padding(.vertical, PPSpace.xs)
                    .background(
                        store.accentPalette.onAccent.opacity(0.16),
                        in: Capsule()
                    )
                }
                .foregroundStyle(store.accentPalette.onAccent)
                .padding(.horizontal, PPSpace.base)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    store.accentPalette.fill,
                    in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.filterDraft == nil)
            .accessibilityHint(
                PPMarketplaceText.localized("marketplace_apply_filters_hint")
            )
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.bottom, PPSpace.sm)
        .background(.ultraThinMaterial)
    }
}

@available(iOS 15.0, *)
private struct PPMarketplaceFilterGroupView: View {
    let group: PPFilterGroup
    let accent: UIColor
    let select: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    .accessibilityAddTraits(.isHeader)
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
                select(option.value)
            } label: {
                HStack(spacing: PPSpace.sm) {
                    if let icon = option.iconName, !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(option.title)
                        .font(HomeFont.bold(14))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: PPSpace.xs)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(
                    selected
                        ? Color(uiColor: accent)
                        : Color.ppMarketplaceTextPrimary
                )
                .padding(.horizontal, PPSpace.md)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    selected
                        ? Color(uiColor: accent).opacity(0.10)
                        : Color(uiColor: .tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        .strokeBorder(
                            selected
                                ? Color(uiColor: accent).opacity(0.55)
                                : Color.ppMarketplaceSeparator.opacity(0.18),
                            lineWidth: selected ? 1.5 : 1
                        )
                }
                .contentShape(
                    RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                )
                .animation(selectionMotionIsDisabled ? nil : .easeOut(duration: 0.16), value: selected)
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                selected
                    ? PPMarketplaceText.localized("marketplace_selected")
                    : PPMarketplaceText.localized("marketplace_not_selected")
            )
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private var selectionMotionIsDisabled: Bool {
        reduceMotion || switchControlEnabled || voiceOverEnabled
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceProviderSheet: View {
    @ObservedObject var store: PPMarketplaceDataViewStore

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                navigationContent
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                navigationContent
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var navigationContent: some View {
        NavigationView {
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
            .navigationTitle(PPMarketplaceText.localized("marketplace_providers_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPMarketplaceText.localized("Done")) {
                        store.dismissActiveSheet()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
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
                        .lineLimit(2)
                    Text(
                        PPMarketplaceText.formatted(
                            "marketplace_provider_items_format",
                            itemCount
                        )
                    )
                    .font(HomeFont.footnote())
                    .foregroundStyle(Color.ppMarketplaceTextSecondary)
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
                            ? Color(uiColor: store.accentColor).opacity(0.50)
                            : Color.ppMarketplaceSeparator.opacity(0.18),
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
