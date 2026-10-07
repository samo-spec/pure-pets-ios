import SwiftUI
import UIKit

/// Presentation only. The existing viewer store resolves the exact sellable
/// product and owns price, stock, selection, and cart mutations.
@available(iOS 16.0, *)
struct PPUniversalVariantPicker: View {
    let accessory: PetAccessory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PPUniversalVariantPickerRepresentable(accessory: accessory) { dismiss() }
            .ignoresSafeArea(.container, edges: .bottom)
    }
}

@available(iOS 16.0, *)
private struct PPUniversalVariantPickerRepresentable: UIViewControllerRepresentable {
    let accessory: PetAccessory
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        PPUniversalVariantPickerController(accessory: accessory, close: onDismiss)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        (uiViewController as? PPUniversalVariantPickerController)?.finish()
    }
}

@available(iOS 16.0, *)
@MainActor
private final class PPUniversalVariantPickerController: UIViewController {
    private let accessory: PetAccessory
    private let close: () -> Void
    private var store: PPAccessoryViewerStore?
    private var loadTask: Task<Void, Never>?
    private var contentHeight: CGFloat = 420
    private weak var configuredSheet: UISheetPresentationController?
    private let contentDetent = UISheetPresentationController.Detent.Identifier("pp_variant_content")

    init(accessory: PetAccessory, close: @escaping () -> Void) {
        self.accessory = accessory
        self.close = close
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        view.semanticContentAttribute = Language
            .semanticAttributeForCurrentLanguage()
        let store = PPAccessoryViewerStore(accessory: accessory, presenter: self, contentScope: .quickAdd)
        self.store = store
        let content = PPUniversalVariantPickerContent(
            store: store,
            close: { [weak self] in
                guard let self, self.store?.cartPhase != .processing else { return }
                self.close()
            },
            mutationChanged: { [weak self] in self?.setDismissalBlocked($0) },
            onHeightChange: { [weak self] in self?.updateContentHeight($0) }
        )
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .ppBackground
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        loadTask = Task { await store.load() }
    }

    /// UIKit is the sole detent owner. Content changes preserve the user's
    /// expanded detent and are capped by the real presentation container.
    private func configureSheetIfNeeded() {
        var current: UIViewController? = self
        while let controller = current {
            // The regular sheetPresentationController getter can create a
            // phantom sheet for this representable child before presentation.
            if let sheet = controller.activePresentationController as? UISheetPresentationController {
                guard configuredSheet !== sheet else { return }
                configuredSheet = sheet
                sheet.preferredCornerRadius = 42
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
                sheet.detents = [
                    .custom(identifier: contentDetent) { [weak self] context in
                        min(max(self?.contentHeight ?? 420, 300), context.maximumDetentValue)
                    },
                    .large()
                ]
                sheet.selectedDetentIdentifier = contentDetent
                return
            }
            current = controller.parent
        }
    }

    private func updateContentHeight(_ height: CGFloat) {
        guard height.isFinite, height > 100, abs(contentHeight - height) > 2 else { return }
        contentHeight = ceil(height)
        configureSheetIfNeeded()
        guard let sheet = configuredSheet else { return }
        if UIAccessibility.isReduceMotionEnabled {
            sheet.invalidateDetents()
        } else {
            sheet.animateChanges { sheet.invalidateDetents() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureSheetIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureSheetIfNeeded()
        if store?.snapshot != nil { store?.resume() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store?.pause()
    }

    private func setDismissalBlocked(_ blocked: Bool) {
        var current: UIViewController? = self
        while let controller = current {
            controller.isModalInPresentation = blocked
            current = controller.parent
        }
    }

    func finish() {
        loadTask?.cancel()
        loadTask = nil
        store?.finishQuickAdd()
        setDismissalBlocked(false)
    }
}

@available(iOS 16.0, *)
private struct PPUniversalVariantPickerContent: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let close: () -> Void
    let mutationChanged: (Bool) -> Void
    let onHeightChange: (CGFloat) -> Void

    @State private var mutationPending = false
    @State private var mutationError: String?
    // Retain each operation through auth/provider presentation. An already
    // dispatched cart write must finish; disappearing is not a cancellation.
    @State private var cartTask: Task<Void, Never>?
    @State private var showsCombinations = false
    @State private var combinationQuery = ""
    @State private var showsDetails = false
    @FocusState private var searchFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorSchemeContrast) private var contrast

    private var isMutating: Bool { mutationPending || store.cartPhase == .processing }
    private var canEditCart: Bool {
        !isMutating && !store.isCheckoutProcessing && store.switchingVariantProductId == nil
    }
    private var canAdd: Bool {
        canEditCart && store.isVariantSelectionConfirmed && store.isPurchaseDataCurrent &&
            store.snapshot?.isAvailableForPurchase == true &&
            store.snapshot?.showsCart == true && store.remainingStock > 0
    }
    private var inlineActions: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact || searchFocused
    }

    var body: some View {
        VStack(spacing: 0) {
            header.measuringVariantHeight(.header)
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.xl) {
                    switch store.phase {
                    case .loading:
                        loadingState
                    case let .failed(message):
                        recovery(message, retry: store.retry)
                    case .loaded:
                        if let snapshot = store.snapshot {
                            productIdentity(snapshot)
                            options
                            selectionFeedback
                            details
                            if inlineActions { commerce(snapshot) }
                        }
                    }
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, PPSpace.xl)
                .padding(.top, PPSpace.sm)
                .padding(.bottom, PPSpace.xl)
                .frame(maxWidth: .infinity)
                .measuringVariantHeight(.content)
            }
            .scrollDismissesKeyboard(.interactively)

            if !inlineActions, store.phase == .loaded, let snapshot = store.snapshot {
                commerce(snapshot)
                    .frame(maxWidth: 620)
                    .padding(.horizontal, PPSpace.xl)
                    .padding(.top, PPSpace.base)
                    .padding(.bottom, PPSpace.base)
                    .frame(maxWidth: .infinity)
                    .background(Color.ppSurface)
                    .overlay(alignment: .top) { Divider() }
                    .measuringVariantHeight(.actions)
            }
        }
        .font(PPAccessoryTypography.body)
        .foregroundStyle(PPAccessoryPalette.ink)
        .background(Color.ppBackground.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .bottom)
        .tint(Color.ppAccentText)
        .environment(\.layoutDirection, PPAccessoryViewerLegacyBridge.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, PPAccessoryViewerL10n.locale)
        .interactiveDismissDisabled(isMutating)
        .onPreferenceChange(PPVariantSheetHeightKey.self) { heights in
            onHeightChange(heights.values.reduce(0, +))
        }
        .onChange(of: isMutating, perform: mutationChanged)
        .onChange(of: mutationError) { message in
            if let message { UIAccessibility.post(notification: .announcement, argument: message) }
        }
        .onChange(of: store.snapshot?.id) { _ in mutationError = nil }
        .onChange(of: showsCombinations) { expanded in
            if !expanded { combinationQuery = ""; searchFocused = false }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.resume() }
            else if phase == .background { store.pause() }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: PPSpace.base) {
            Text(PPAccessoryViewerL10n.text("variant_sheet_title"))
                .font(PPAccessoryTypography.headline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.ppSurface, in: Circle())
            }
            .buttonStyle(PPVariantPressStyle())
            .disabled(isMutating)
            .accessibilityLabel(PPAccessoryViewerL10n.text("Done"))
            .accessibilityIdentifier("pp.universal.variant.close")
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, PPSpace.xl)
        .padding(.top, PPSpace.xl)
        .padding(.bottom, PPSpace.base)
        .frame(maxWidth: .infinity)
    }

    private func productIdentity(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PPSpace.base))
            : AnyLayout(HStackLayout(alignment: .center, spacing: PPSpace.base))
        return layout {
            let media = snapshot.media.first
            PPAccessoryRemoteImageView(
                urlString: media?.imageURL, blurHash: media?.blurHash,
                contentMode: .fit, accessibilityLabel: snapshot.title,
                displaySize: CGSize(width: 88, height: 88)
            )
            .frame(width: 88, height: 88)
            .background(Color.ppSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(PPAccessoryViewerL10n.isolated(snapshot.title))
                    .font(PPAccessoryTypography.title)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let variant = store.currentVariant, store.hasResolvedVariantOptions {
                    Text(store.optionSummary(for: variant))
                        .font(PPAccessoryTypography.callout)
                        .foregroundStyle(PPAccessoryPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var loadingState: some View {
        HStack(spacing: PPSpace.base) {
            ProgressView().accessibilityHidden(true)
            Text(PPAccessoryViewerL10n.text("accessory_view_options_loading"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(PPAccessoryPalette.inkSecondary)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var options: some View {
        switch store.variantsPhase {
        case .idle, .loading:
            loadingState
        case let .failed(message):
            recovery(message, retry: store.retryVariants)
        case .empty:
            if !store.isVariantSelectionConfirmed {
                recovery(PPAccessoryViewerL10n.text("accessory_view_options_empty_axis"), retry: store.retryVariants)
            }
        case .loaded:
            VStack(alignment: .leading, spacing: PPSpace.lg) {
                ForEach(store.optionDefinitions) { option in
                    PPVariantSheetAxis(store: store, option: option, mutationPending: isMutating)
                }
                if store.optionDefinitions.isEmpty || !store.hasResolvedVariantOptions {
                    if !store.variants.isEmpty {
                        if !store.hasResolvedVariantOptions {
                            Text(PPAccessoryViewerL10n.text("accessory_view_selection_needed"))
                                .font(PPAccessoryTypography.callout)
                                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                        }
                        combinations
                    } else {
                        recovery(PPAccessoryViewerL10n.text("accessory_view_options_empty_axis"), retry: store.retryVariants)
                    }
                } else if store.optionDefinitions.count > 1 && store.variants.count > 1 {
                    DisclosureGroup(isExpanded: $showsCombinations) {
                        combinations.padding(.top, PPSpace.sm)
                    } label: {
                        Text(PPAccessoryViewerL10n.text("accessory_view_all_combinations_short"))
                            .font(PPAccessoryTypography.calloutBold)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("pp.universal.variant.combinations")
                }
            }
        }
    }

    private var matchingVariants: [PPAccessoryViewerVariant] {
        let query = combinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.variants }
        return store.variants.filter { variant in
            store.optionSummary(for: variant).localizedStandardContains(query) ||
                variant.sku.localizedStandardContains(query) ||
                store.optionDefinitions.contains { option in
                    option.values.first { $0.id == variant.selectedOptions[option.id] }?.matches(query) == true
                }
        }
    }

    private var combinations: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            if store.variants.count > 8 {
                TextField(PPAccessoryViewerL10n.text("accessory_view_search_combinations"), text: $combinationQuery)
                    .font(PPAccessoryTypography.body)
                    .padding(PPSpace.md)
                    .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 12))
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("pp.universal.variant.search")
            }
            if matchingVariants.isEmpty {
                Text(PPAccessoryViewerL10n.text("accessory_view_options_no_results"))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(matchingVariants, id: \.productId) { variant in
                        combinationRow(variant)
                        if variant.productId != matchingVariants.last?.productId { Divider() }
                    }
                }
            }
            if !combinationQuery.isEmpty {
                Button(PPAccessoryViewerL10n.text("accessory_view_options_clear_search")) {
                    combinationQuery = ""; searchFocused = false
                }
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .foregroundStyle(Color.ppAccentText)
            }
        }
    }

    private func combinationRow(_ variant: PPAccessoryViewerVariant) -> some View {
        let selected = variant.productId == store.snapshot?.id
        let pending = variant.productId == store.switchingVariantProductId
        return Button {
            searchFocused = false
            store.selectVariant(variant)
        } label: {
            HStack(spacing: PPSpace.md) {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(store.optionSummary(for: variant))
                        .font(PPAccessoryTypography.bodyBold)
                    if variant.isArchived {
                        Text(PPAccessoryViewerL10n.text("accessory_view_option_unavailable"))
                            .font(PPAccessoryTypography.caption)
                            .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                selectionMark(selected: selected, pending: pending)
            }
            .padding(.vertical, PPSpace.sm)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPVariantPressStyle())
        .disabled(isMutating || !store.canChangeVariant || selected || variant.isArchived)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityValue(pending ? PPAccessoryViewerL10n.text("accessory_view_options_loading") : "")
        .accessibilityIdentifier("pp.universal.variant.combination.\(variant.productId)")
    }

    @ViewBuilder private var selectionFeedback: some View {
        if let pending = store.pendingVariant {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                HStack(alignment: .top, spacing: PPSpace.sm) {
                    ProgressView().accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: PPSpace.xs) {
                        Text(PPAccessoryViewerL10n.text("accessory_view_options_resolving_label"))
                            .font(PPAccessoryTypography.calloutBold)
                        Text(store.optionSummary(for: pending))
                            .font(PPAccessoryTypography.callout)
                            .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    }
                }
                Button(PPAccessoryViewerL10n.text("accessory_view_keep_selection"), action: store.cancelVariantSelection)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.ppAccentText)
            }
        } else if let error = store.variantSelectionError {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                recovery(error, retry: store.retryVariantSelection)
                Button(PPAccessoryViewerL10n.text("accessory_view_keep_selection"), action: store.cancelVariantSelection)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.ppAccentText)
                    .disabled(isMutating)
            }
        }
        if store.livePhase == .stale {
            recovery(PPAccessoryViewerL10n.text("accessory_view_live_data_stale"), retry: store.retryLiveUpdates)
        }
    }

    @ViewBuilder private var details: some View {
        if let sku = store.currentVariant?.sku, !sku.isEmpty {
            DisclosureGroup(isExpanded: $showsDetails) {
                Text(PPAccessoryViewerL10n.formatted("accessory_view_option_sku_format", PPAccessoryViewerL10n.isolated(sku)))
                    .font(PPAccessoryTypography.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PPSpace.sm)
            } label: {
                Text(PPAccessoryViewerL10n.text("accessory_view_option_details"))
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func commerce(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            availability(snapshot)
            if snapshot.showsCart {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: PPSpace.md))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: PPSpace.base))
                layout {
                    price(snapshot)
                    quantityControl(snapshot)
                }
                if store.cartQuantity > 0 {
                    inCartActions
                } else {
                    Button(action: addToCart) {
                        HStack(spacing: PPSpace.sm) {
                            if isMutating { ProgressView().tint(.white) }
                            else { Image(systemName: "bag.badge.plus").accessibilityHidden(true) }
                            Text(PPAccessoryViewerL10n.text(isMutating ? "accessory_view_adding_to_cart" : "addToCart"))
                                .font(PPAccessoryTypography.bodyBold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(canAdd ? Color.white : PPAccessoryPalette.inkSecondary)
                        .padding(.horizontal, PPSpace.base)
                        .padding(.vertical, PPSpace.md)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(canAdd ? Color.ppPrimary : Color.ppSecondarySurface,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PPVariantPressStyle())
                    .disabled(!canAdd)
                    .accessibilityHint(PPAccessoryViewerL10n.text("universal_variant_options_hint"))
                    .accessibilityIdentifier("pp.universal.variant.add")
                }
                if snapshot.isUnavailable { stockNotification(snapshot) }
            } else {
                Text(snapshot.price)
                    .font(PPAccessoryTypography.price)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let message = mutationError ?? store.bannerMessage {
                Text(message)
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pp.universal.variant.feedback")
            }
        }
    }

    private func price(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        let count = store.cartQuantity > 0 ? store.cartQuantity : store.quantity
        return VStack(alignment: .leading, spacing: 0) {
            Text(PPAccessoryViewerL10n.text(store.cartQuantity > 0 ? "variant_sheet_cart_total" : "variant_sheet_total"))
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
            Text(PPAccessoryViewerLegacyBridge.formattedPrice(for: snapshot.accessory, quantity: count))
                .font(PPAccessoryTypography.price)
                .fixedSize(horizontal: false, vertical: true)
            if count > 1 {
                Text(PPAccessoryViewerL10n.formatted("variant_sheet_unit_price_format", PPAccessoryViewerL10n.isolated(snapshot.price)))
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func quantityControl(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        let existing = store.cartQuantity > 0
        let count = existing ? store.cartQuantity : store.quantity
        let canDecrease = existing ? canEditCart : (canAdd && count > 1)
        let canIncrease = existing ? (canAdd && count < snapshot.quantity) : (canAdd && count < store.remainingStock)
        return HStack(spacing: 0) {
            quantityButton("minus", label: "accessory_view_decrease_quantity", enabled: canDecrease) {
                if existing { updateCartQuantity(count - 1) } else { store.decrementQuantity() }
            }
            ZStack {
                Text(PPAccessoryViewerL10n.integer(count))
                    .font(PPAccessoryTypography.title)
                    .monospacedDigit()
                    .opacity(isMutating ? 0 : 1)
                if isMutating { ProgressView() }
            }
            .frame(minWidth: 32, minHeight: 48)
            .accessibilityLabel(PPAccessoryViewerL10n.formatted("accessory_view_quantity_format", count))
            quantityButton("plus", label: "accessory_view_increase_quantity", enabled: canIncrease) {
                if existing { updateCartQuantity(count + 1) } else { store.incrementQuantity() }
            }
        }
        .padding(.horizontal, PPSpace.xs)
        .background(Color.ppBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.ppTextSecondary : Color.ppSurfaceBorder,
                              lineWidth: contrast == .increased ? 1.5 : 1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pp.universal.variant.cartQuantity")
    }

    private func quantityButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(PPVariantPressStyle())
        .foregroundStyle(enabled ? PPAccessoryPalette.ink : PPAccessoryPalette.inkSecondary.opacity(0.5))
        .disabled(!enabled)
        .accessibilityLabel(PPAccessoryViewerL10n.text(label))
    }

    private var inCartActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: PPSpace.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: PPSpace.base))
        return layout {
            Label(PPAccessoryViewerL10n.text("InCart"), systemImage: "checkmark.circle.fill")
                .font(PPAccessoryTypography.bodyBold)
                .foregroundStyle(Color.ppAccentText)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            Button {
                updateCartQuantity(0)
            } label: {
                Label(PPAccessoryViewerL10n.text("variant_sheet_remove"), systemImage: "trash")
                    .font(PPAccessoryTypography.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
            }
            .buttonStyle(PPVariantPressStyle())
            .foregroundStyle(PPAccessoryPalette.inkSecondary)
            .disabled(!canEditCart)
            .accessibilityIdentifier("pp.universal.variant.remove")
        }
    }

    private func availability(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        let message: String
        let symbol: String
        if store.switchingVariantProductId != nil {
            message = PPAccessoryViewerL10n.text("accessory_view_options_resolving_label")
            symbol = "arrow.triangle.2.circlepath"
        } else if store.livePhase == .refreshing || store.livePhase == .stale {
            message = PPAccessoryViewerL10n.text("accessory_view_options_check_availability")
            symbol = "arrow.triangle.2.circlepath"
        } else if store.livePhase == .deleted || snapshot.isUnavailable {
            message = PPAccessoryViewerL10n.text("accessory_view_item_unavailable")
            symbol = "exclamationmark.circle"
        } else if !store.isVariantSelectionConfirmed {
            message = PPAccessoryViewerL10n.text("accessory_view_selection_needed")
            symbol = "slider.horizontal.3"
        } else {
            message = PPAccessoryViewerL10n.formatted("accessory_view_remaining_text_format", PPAccessoryViewerL10n.integer(store.remainingStock))
            symbol = "checkmark.circle"
        }
        return Label(message, systemImage: symbol)
            .font(PPAccessoryTypography.callout)
            .foregroundStyle(PPAccessoryPalette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func stockNotification(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        if snapshot.canRequestStockNotification && store.isVariantSelectionConfirmed {
            Button(action: store.registerStockNotification) {
                HStack(spacing: PPSpace.sm) {
                    if store.stockNotificationPhase == .processing { ProgressView() }
                    else { Image(systemName: "bell.badge").accessibilityHidden(true) }
                    Text(PPAccessoryViewerL10n.text(
                        store.stockNotificationPhase == .success ? "stock_notify_already_registered" : "notify_me"
                    ))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .font(PPAccessoryTypography.bodyBold)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.ppAccentText)
            .disabled(store.stockNotificationPhase == .processing || isMutating || store.switchingVariantProductId != nil)
        }
    }

    private func recovery(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(PPAccessoryTypography.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button(PPAccessoryViewerL10n.text("Retry"), action: retry)
                .font(PPAccessoryTypography.bodyBold)
                .foregroundStyle(Color.ppAccentText)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .disabled(isMutating || store.switchingVariantProductId != nil || store.isCheckoutProcessing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionMark(selected: Bool, pending: Bool) -> some View {
        ZStack {
            if pending { ProgressView().controlSize(.small) }
            else {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selected ? Color.ppAccentText : Color.ppSurfaceBorder)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private func addToCart() {
        guard canAdd else { return }
        mutationPending = true
        mutationError = nil
        store.dismissBanner()
        cartTask = Task { @MainActor in
            defer { mutationPending = false; cartTask = nil }
            do {
                let outcome = try await store.addToCartAsync()
                if outcome.addedQuantity > 0 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                announceCartQuantity()
                broadcastCartUpdated()
            } catch is CancellationError {
                // Authentication/provider-switch presentation owns cancellation.
            } catch {
                mutationError = store.bannerMessage ?? PPAccessoryViewerL10n.text("accessory_view_add_failed")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func updateCartQuantity(_ value: Int) {
        guard canEditCart else { return }
        mutationPending = true
        mutationError = nil
        store.dismissBanner()
        cartTask = Task { @MainActor in
            defer { mutationPending = false; cartTask = nil }
            do {
                _ = try await store.updateCartQuantity(value)
                announceCartQuantity()
                broadcastCartUpdated()
            } catch is CancellationError {
                // Keep the same cancellation boundary as add.
            } catch {
                mutationError = PPAccessoryViewerL10n.text("accessory_view_cart_quantity_update_failed")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func broadcastCartUpdated() {
        NotificationCenter.default.post(name: NSNotification.Name("kCartUpdatedNotification"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("CartUpdated"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("PPCartDidChangeNotification"), object: nil)
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }),
               let rootVC = window.rootViewController as? PPRootTabBarController {
                let target = (rootVC.selectedViewController as? UINavigationController)?.topViewController
                    ?? (rootVC.selectedViewController as? UINavigationController)?.visibleViewController
                    ?? rootVC.selectedViewController
                if let target { PPRootLegacyAdapter.applySurface(for: target, animated: true) }
            }
        }
    }

    private func announceCartQuantity() {
        UIAccessibility.post(notification: .announcement, argument: PPAccessoryViewerL10n.formatted(
            "universal_variant_cart_quantity_format", PPAccessoryViewerL10n.integer(store.cartQuantity)
        ))
    }
}

/// All values are visible in a wrapping layout. At accessibility text sizes
/// each choice takes the full width instead of becoming a horizontal scroll.
@available(iOS 16.0, *)
private struct PPVariantSheetAxis: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let option: PPAccessoryViewerOptionDefinition
    let mutationPending: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var offeredValues: [PPAccessoryViewerOptionValue] {
        option.values.filter { store.status(forOptionValue: $0, inOption: option).belongsOnPrimaryRail }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(option.localizedName)
                .font(PPAccessoryTypography.headline)
                .accessibilityAddTraits(.isHeader)
            if offeredValues.isEmpty {
                Text(PPAccessoryViewerL10n.text("accessory_view_options_empty_axis"))
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    ForEach(offeredValues) { choice($0, expanded: true) }
                }
            } else {
                PPVariantChoicesLayout(spacing: PPSpace.sm) {
                    ForEach(offeredValues) { choice($0, expanded: false) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func choice(_ value: PPAccessoryViewerOptionValue, expanded: Bool) -> some View {
        let status = store.status(forOptionValue: value, inOption: option)
        let selected = status == .selected
        let pending = !selected && store.pendingVariant?.selectedOptions[option.id] == value.id
        let detail = status == .incompatible ? PPAccessoryViewerL10n.text("accessory_view_option_adjusts")
            : status == .outOfStock ? PPAccessoryViewerL10n.text("accessory_view_option_out_of_stock") : nil
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            store.selectOptionValue(optionId: option.id, valueId: value.id)
        } label: {
            HStack(spacing: PPSpace.sm) {
                if option.isColor, let swatch = value.swatchComponents {
                    Circle()
                        .fill(Color(red: swatch.red, green: swatch.green, blue: swatch.blue))
                        .frame(width: 24, height: 24)
                        .overlay { Circle().strokeBorder(Color.ppTextSecondary.opacity(0.5), lineWidth: 1) }
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(PPAccessoryViewerL10n.isolated(value.summaryName))
                        .font(selected ? PPAccessoryTypography.bodyBold : PPAccessoryTypography.body)
                        .foregroundStyle(PPAccessoryPalette.ink)
                    if let detail {
                        Text(detail).font(PPAccessoryTypography.caption)
                            .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                if expanded { Spacer(minLength: 0) }
                ZStack {
                    if pending { ProgressView().controlSize(.small) }
                    else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .opacity(selected ? 1 : 0)
                    }
                }
                .frame(width: 18, height: 20)
                .accessibilityHidden(true)
            }
            .foregroundStyle(selected ? Color.ppAccentText : PPAccessoryPalette.ink)
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, PPSpace.sm)
            .frame(maxWidth: expanded ? .infinity : nil, minHeight: 48, alignment: .leading)
            .background(selected ? Color.ppSoftRose : Color.ppSurface, in: shape)
            .overlay {
                shape.strokeBorder(selected ? Color.ppAccentText :
                                    contrast == .increased ? Color.ppTextSecondary : Color.ppSurfaceBorder,
                                   lineWidth: selected || contrast == .increased ? 1.5 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(PPVariantPressStyle())
        .disabled(mutationPending || !store.canChangeVariant || !status.isActionable)
        .accessibilityLabel(PPAccessoryViewerL10n.formatted(
            "accessory_view_option_value_format", option.localizedName, PPAccessoryViewerL10n.isolated(value.accessibilityName)
        ))
        .accessibilityValue(pending ? PPAccessoryViewerL10n.text("accessory_view_options_loading") :
                            selected ? PPAccessoryViewerL10n.text("Selected") : detail ?? "")
        .accessibilityHint(status == .incompatible ? PPAccessoryViewerL10n.text("accessory_view_option_adjusts_hint") : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("pp.accessory.option.\(option.id).\(value.id)")
    }
}

/// Logical placements are mirrored by SwiftUI. Do not reverse the values or
/// apply another RTL transform; backend option order stays stable.
@available(iOS 16.0, *)
private struct PPVariantChoicesLayout: Layout {
    let spacing: CGFloat
    private struct Placement { let size: CGSize; let x: CGFloat; let y: CGFloat }

    private func placements(width: CGFloat, subviews: Subviews) -> [Placement] {
        let width = max(width, 1)
        var result: [Placement] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(ideal.width, width), height: nil))
            if x > 0 && x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            result.append(Placement(size: size, x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.reduce(CGFloat.zero) { $0 + $1.sizeThatFits(.unspecified).width } +
            CGFloat(max(0, subviews.count - 1)) * spacing
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? ideal
        let items = placements(width: width, subviews: subviews)
        return CGSize(width: max(width, 0), height: items.map { $0.y + $0.size.height }.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, item) in placements(width: bounds.width, subviews: subviews).enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y), anchor: .topLeading,
                                 proposal: ProposedViewSize(width: item.size.width, height: item.size.height))
        }
    }
}

private enum PPVariantSheetHeightPart: Hashable { case header, content, actions }
private struct PPVariantSheetHeightKey: PreferenceKey {
    static var defaultValue: [PPVariantSheetHeightPart: CGFloat] = [:]
    static func reduce(value: inout [PPVariantSheetHeightPart: CGFloat], nextValue: () -> [PPVariantSheetHeightPart: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
private extension View {
    func measuringVariantHeight(_ part: PPVariantSheetHeightPart) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: PPVariantSheetHeightKey.self, value: [part: geometry.size.height])
        })
    }
}

private struct PPVariantPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
