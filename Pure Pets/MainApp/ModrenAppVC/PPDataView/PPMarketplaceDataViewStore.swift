import Combine
import SwiftUI
import UIKit

@available(iOS 15.0, *)
enum PPMarketplaceText {
    static func localized(_ key: String) -> String {
        let value = Language.get(key, alter: key) ?? ""
        return value.isEmpty ? key : value
    }

    static func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: localized(key),
            locale: Locale.current,
            arguments: arguments
        )
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceLoadState: Equatable {
    case loading
    case content
    case empty
    case offline(String)
    case failed(String)
}

@available(iOS 15.0, *)
enum PPMarketplaceSheet: String, Identifiable {
    case category
    case filters
    case providers

    var id: String { rawValue }
}

@available(iOS 15.0, *)
struct PPMarketplaceAccentPalette {
    let fill: Color
    let darker: Color
    let brighter: Color
    let soft: Color
    let onAccent: Color

    init(accent: UIColor) {
        let resolved = accent.resolvedColor(with: .current)
        fill = Color(uiColor: resolved)
        darker = Color(
            uiColor: Self.blended(resolved, toward: .black, amount: 0.18)
        )
        brighter = Color(
            uiColor: Self.blended(resolved, toward: .white, amount: 0.14)
        )
        soft = Color(uiColor: resolved).opacity(0.10)
        onAccent = Color(uiColor: Self.contrastingForeground(for: resolved))
    }

    private static func blended(
        _ color: UIColor,
        toward target: UIColor,
        amount: CGFloat
    ) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        var targetAlpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
              target.getRed(
                &targetRed,
                green: &targetGreen,
                blue: &targetBlue,
                alpha: &targetAlpha
              ) else {
            return color
        }
        let ratio = min(max(amount, 0), 1)
        return UIColor(
            red: red + (targetRed - red) * ratio,
            green: green + (targetGreen - green) * ratio,
            blue: blue + (targetBlue - blue) * ratio,
            alpha: alpha
        )
    }

    private static func contrastingForeground(for color: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if !color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            var white: CGFloat = 0
            color.getWhite(&white, alpha: &alpha)
            red = white
            green = white
            blue = white
        }

        let luminance = 0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
        let blackContrast = (luminance + 0.05) / 0.05
        let whiteContrast = 1.05 / (luminance + 0.05)
        return blackContrast >= whiteContrast ? .black : .white
    }

    private static func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

@available(iOS 15.0, *)
enum PPMarketplaceLayout: Int, CaseIterable, Identifiable {
    case compact = 2
    case showcase = 3
    case mosaic = 4
    case focus = 9001

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .compact: return "marketplace_layout_compact"
        case .showcase: return "marketplace_layout_showcase"
        case .mosaic: return "marketplace_layout_mosaic"
        case .focus: return "marketplace_layout_focus"
        }
    }

    var iconName: String {
        switch self {
        case .compact: return "rectangle.grid.1x2"
        case .showcase: return "rectangle.grid.1x2.fill"
        case .mosaic: return "square.grid.2x2"
        case .focus: return "rectangle.portrait.on.rectangle.portrait"
        }
    }

    var universalLayoutMode: PPManagerCellLayoutMode {
        switch self {
        case .compact:
            return .cellLayoutModeHorizontalRow
        case .showcase:
            return .cellLayoutModeVertical
        case .mosaic:
            return .cellLayoutModePinterest
        case .focus:
            return .cellLayoutModeDataViewFullDetails
        }
    }

    static func resolved(sectionRawValue: Int) -> PPMarketplaceLayout {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "PPLayoutModeChangedByUser"),
           let saved = PPMarketplaceLayout(
                rawValue: defaults.integer(forKey: "PPUserPreferredLayoutMode")
           ) {
            return saved
        }
        return .mosaic
    }
}

@available(iOS 15.0, *)
struct PPMarketplaceSectionDescriptor: Identifiable, Equatable {
    let rawValue: Int
    let titleKey: String
    let subtitleKey: String
    let iconName: String

    var id: Int { rawValue }

    var section: PPDataSection {
        PPDataSection(rawValue: rawValue)!
    }

    static let all: [PPMarketplaceSectionDescriptor] = [
        .init(
            rawValue: 0,
            titleKey: "Ads",
            subtitleKey: "marketplace_section_ads_subtitle",
            iconName: "sparkles.rectangle.stack"
        ),
        .init(
            rawValue: 1,
            titleKey: "Accessories",
            subtitleKey: "marketplace_section_accessories_subtitle",
            iconName: "bag"
        ),
        .init(
            rawValue: 2,
            titleKey: "Food",
            subtitleKey: "marketplace_section_food_subtitle",
            iconName: "takeoutbag.and.cup.and.straw"
        ),
        .init(
            rawValue: 3,
            titleKey: "CellSectionServices",
            subtitleKey: "marketplace_section_services_subtitle",
            iconName: "hands.sparkles"
        )
    ]
}

@available(iOS 15.0, *)
struct PPMarketplaceItemRecord: Identifiable {
    let id: String
    let viewModel: PPUniversalCellViewModel
    let section: PPDataSection
    let ordinal: Int
}

@available(iOS 15.0, *)
struct PPMarketplaceMainKindChoice: Identifiable {
    let id: Int
    let title: String
}

@available(iOS 15.0, *)
struct PPMarketplaceSubKindChoice: Identifiable {
    let id: Int
    let title: String
}

@available(iOS 15.0, *)
enum PPMarketplaceContentTransitionIntent: Equatable {
    case initial
    case navigation(direction: Int)
    case refinement
}

@available(iOS 15.0, *)
@MainActor
final class PPMarketplaceDataViewStore: ObservableObject {
    let bridge: PPMarketplaceDataViewBridge
    private let searchAction: () -> Void
    private let categoryApplyAction: (Int, Int) -> Void

    @Published private(set) var loadState: PPMarketplaceLoadState = .loading
    @Published private(set) var records: [PPMarketplaceItemRecord] = []
    @Published private(set) var currentSection: PPDataSection
    @Published private(set) var currentMainKindTitle: String
    @Published private(set) var currentSubKindTitle: String
    @Published private(set) var resolvedAccentColor: UIColor
    @Published private(set) var usesBrandAccent: Bool
    @Published private(set) var navigationContext: PPMarketplaceNavigationContext
    @Published private(set) var providerOptions: [PPMarketplaceProviderOption] = []
    @Published private(set) var selectedProviderID: String?
    @Published private(set) var cartItemCount = 0
    @Published private(set) var bottomClearance: CGFloat = 0
    @Published private(set) var isRefreshing = false
    @Published private(set) var isReplacingContext = false
    @Published private(set) var updateErrorMessage: String?
    @Published private(set) var contentRevision = 0
    @Published private(set) var contentTransitionIntent: PPMarketplaceContentTransitionIntent = .initial
    @Published var layout: PPMarketplaceLayout
    @Published var activeSheet: PPMarketplaceSheet?
    @Published var filterDraft: PPFilterState?
    @Published private(set) var filterPreviewCount = 0
    @Published private(set) var categoryDraftMainKindID = 0
    @Published private(set) var categoryDraftSubKindID = 0

    private var rawItems: [PPUniversalCellViewModel] = []
    private var selectedProviderIDs: [Int: String] = [:]
    private var observerTokens: [NSObjectProtocol] = []
    private var didStart = false
    private var didLoadContent = false
    private var lastEmptyContextSignature: String?
    private var presentationStateRefreshScheduled = false
    private var awaitsBridgeContentTransition = false
    private var bridgeContextCommitPending = false

    init(
        bridge: PPMarketplaceDataViewBridge,
        searchAction: (() -> Void)? = nil,
        categoryApplyAction: ((Int, Int) -> Void)? = nil
    ) {
        self.bridge = bridge
        self.searchAction = searchAction ?? { bridge.openSearch() }
        self.categoryApplyAction = categoryApplyAction ?? { mainKindID, subKindID in
            bridge.applyCategory(
                mainKindIdentifier: mainKindID,
                subKindIdentifier: subKindID
            )
        }
        currentSection = bridge.currentSection
        currentMainKindTitle = bridge.currentMainKindTitle
        currentSubKindTitle = bridge.currentSubKindTitle
        resolvedAccentColor = bridge.accentColor
        usesBrandAccent = bridge.isUsingBrandAccent
        navigationContext = bridge.navigationContext(
            for: bridge.currentSection,
            selectedProviderID: nil
        )
        layout = PPMarketplaceLayout.resolved(
            sectionRawValue: bridge.currentSection.rawValue
        )
        bindBridge()
        installObservers()
        refreshPresentationState()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        bridge.itemsDidChange = nil
        bridge.itemsDidAppend = nil
        bridge.loadingDidFail = nil
        bridge.initialContentDidLoad = nil
        bridge.providerIdentitiesDidChange = nil
        bridge.presentationStateDidChange = nil
    }

    var isRightToLeft: Bool {
        PPUniversalCellSwiftUIBridge.isRightToLeft()
    }

    var accentColor: UIColor {
        resolvedAccentColor
    }

    var accentPalette: PPMarketplaceAccentPalette {
        PPMarketplaceAccentPalette(accent: accentColor)
    }

    var sections: [PPMarketplaceSectionDescriptor] {
        PPMarketplaceSectionDescriptor.all
    }

    var currentSectionDescriptor: PPMarketplaceSectionDescriptor {
        sections.first(where: { $0.rawValue == currentSection.rawValue })
            ?? sections[0]
    }

    var mainKindChoices: [PPMarketplaceMainKindChoice] {
        let kinds = bridge.mainKindOptions
            .filter { $0.identifier != 0 }
            .map { option in
            PPMarketplaceMainKindChoice(
                id: option.identifier,
                title: option.title
            )
        }
        return [
            PPMarketplaceMainKindChoice(
                id: 0,
                title: PPMarketplaceText.localized("All")
            )
        ] + kinds
    }

    var subKindChoices: [PPMarketplaceSubKindChoice] {
        let all = PPMarketplaceSubKindChoice(
            id: 0,
            title: PPMarketplaceText.localized("data_nav_all_breed")
        )
        return [all] + bridge.subKindOptions
            .filter { $0.identifier != 0 }
            .map { option in
            PPMarketplaceSubKindChoice(
                id: option.identifier,
                title: option.title
            )
        }
    }

    var categoryDraftSubKindChoices: [PPMarketplaceSubKindChoice] {
        let all = PPMarketplaceSubKindChoice(
            id: 0,
            title: PPMarketplaceText.localized("data_nav_all_breed")
        )
        guard categoryDraftMainKindID != 0 else {
            return [all]
        }
        return [all] + bridge.subKindOptions(
            mainKindIdentifier: categoryDraftMainKindID
        )
        .filter { $0.identifier != 0 }
        .map { option in
            PPMarketplaceSubKindChoice(
                id: option.identifier,
                title: option.title
            )
        }
    }

    var currentMainKindID: Int {
        bridge.currentMainKindID
    }

    var currentSubKindID: Int {
        bridge.currentSubKindID
    }

    var currentFilterState: PPFilterState {
        bridge.filterState(for: currentSection)
    }

    var activeFilterCount: Int {
        bridge.activeFilterCount(for: currentSection)
            + (selectedProviderID == nil ? 0 : 1)
    }

    var unfilteredResultCount: Int {
        rawItems.count
    }

    var resultCountText: String {
        PPMarketplaceText.formatted(
            "marketplace_results_count_format",
            records.count
        )
    }

    var contextAccessibilityLabel: String {
        [
            navigationContext.accessibilityLabel,
            resultCountText
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        bridge.start()
    }

    func refresh() async {
        guard !isReplacingContext,
              !isRefreshing,
              !bridge.isLoading else { return }
        isRefreshing = true
        updateErrorMessage = nil
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in
            bridge.reload { _ in
                continuation.resume()
            }
        }
        if !isReplacingContext {
            isRefreshing = false
        }
    }

    func retry() {
        guard !bridge.isLoading else { return }
        updateErrorMessage = nil
        if records.isEmpty {
            loadState = .loading
        } else {
            isRefreshing = true
        }
        bridge.reload()
    }

    func fetchNextPageIfNeeded(for record: PPMarketplaceItemRecord) {
        guard !bridge.isLoading,
              record.id == records.last?.id else { return }
        bridge.fetchNextPage()
    }

    func selectSection(_ descriptor: PPMarketplaceSectionDescriptor) {
        guard !isReplacingContext,
              descriptor.rawValue != currentSection.rawValue else { return }
        prepareBridgeContentTransition(
            .navigation(
                direction: descriptor.rawValue > currentSection.rawValue ? 1 : -1
            )
        )
        updateErrorMessage = nil
        UISelectionFeedbackGenerator().selectionChanged()

        if !UserDefaults.standard.bool(forKey: "PPLayoutModeChangedByUser") {
            layout = .mosaic
        }
        bridge.switchSection(descriptor.section)
    }

    func selectMainKind(_ choice: PPMarketplaceMainKindChoice) {
        guard !isReplacingContext,
              choice.id != currentMainKindID else { return }
        prepareBridgeContentTransition(.refinement)
        selectedProviderIDs.removeAll()
        selectedProviderID = nil
        providerOptions = []
        updateErrorMessage = nil
        bridge.switchMainKind(identifier: choice.id)
    }

    func selectSubKind(_ choice: PPMarketplaceSubKindChoice) {
        guard !isReplacingContext,
              choice.id != currentSubKindID else { return }
        prepareBridgeContentTransition(
            .navigation(direction: choice.id > currentSubKindID ? 1 : -1)
        )
        updateErrorMessage = nil
        bridge.switchSubKind(identifier: choice.id)
    }

    func selectLayout(_ newLayout: PPMarketplaceLayout) {
        guard !isReplacingContext, layout != newLayout else { return }
        contentTransitionIntent = .refinement
        layout = newLayout
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "PPLayoutModeChangedByUser")
        defaults.set(newLayout.rawValue, forKey: "PPUserPreferredLayoutMode")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        contentRevision &+= 1
    }

    func beginFilterEditing() {
        guard !isReplacingContext else { return }
        filterDraft = currentFilterState.copy() as? PPFilterState
        updateFilterPreview()
        activeSheet = .filters
    }

    func beginCategoryEditing() {
        guard !isReplacingContext else { return }
        categoryDraftMainKindID = bridge.currentMainKindID
        categoryDraftSubKindID = bridge.currentSubKindID
        normalizeCategoryDraftSubKind()
        activeSheet = .category
    }

    func cancelCategoryEditing() {
        categoryDraftMainKindID = bridge.currentMainKindID
        categoryDraftSubKindID = bridge.currentSubKindID
        activeSheet = nil
    }

    func selectCategoryMainKind(_ choice: PPMarketplaceMainKindChoice) {
        guard categoryDraftMainKindID != choice.id else { return }
        categoryDraftMainKindID = choice.id
        normalizeCategoryDraftSubKind()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectCategorySubKind(_ choice: PPMarketplaceSubKindChoice) {
        guard categoryDraftSubKindID != choice.id,
              categoryDraftSubKindChoices.contains(where: {
                  $0.id == choice.id
              }) else { return }
        categoryDraftSubKindID = choice.id
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func applyMainKindShortcut(_ choice: PPMarketplaceMainKindChoice) {
        let compatibleSubKindID: Int
        if choice.id != 0,
           bridge.subKindOptions(mainKindIdentifier: choice.id).contains(
                where: { $0.identifier == currentSubKindID }
           ) {
            compatibleSubKindID = currentSubKindID
        } else {
            compatibleSubKindID = 0
        }
        applyCategorySelection(
            mainKindID: choice.id,
            subKindID: compatibleSubKindID
        )
    }

    func applySubKindShortcut(_ choice: PPMarketplaceSubKindChoice) {
        guard subKindChoices.contains(where: { $0.id == choice.id }) else {
            return
        }
        applyCategorySelection(
            mainKindID: currentMainKindID,
            subKindID: choice.id
        )
    }

    func clearCategoryDraft() {
        categoryDraftMainKindID = 0
        categoryDraftSubKindID = 0
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func applyCategoryDraft() {
        normalizeCategoryDraftSubKind()
        let nextMainKindID = categoryDraftMainKindID
        let nextSubKindID = categoryDraftSubKindID
        activeSheet = nil

        applyCategorySelection(
            mainKindID: nextMainKindID,
            subKindID: nextSubKindID
        )
    }

    private func applyCategorySelection(
        mainKindID nextMainKindID: Int,
        subKindID nextSubKindID: Int
    ) {
        guard !isReplacingContext else { return }
        guard mainKindChoices.contains(where: { $0.id == nextMainKindID }) else {
            return
        }
        let validSubKind = nextSubKindID == 0 || (
            nextMainKindID != 0 &&
            bridge.subKindOptions(
                mainKindIdentifier: nextMainKindID
            ).contains(where: { $0.identifier == nextSubKindID })
        )
        guard validSubKind else { return }
        guard nextMainKindID != bridge.currentMainKindID ||
                nextSubKindID != bridge.currentSubKindID else {
            return
        }

        selectedProviderIDs.removeAll()
        selectedProviderID = nil
        providerOptions = []
        updateErrorMessage = nil
        prepareBridgeContentTransition(.refinement)
        categoryApplyAction(nextMainKindID, nextSubKindID)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func cancelFilterEditing() {
        filterDraft = nil
        activeSheet = nil
    }

    func selectFilterOption(groupID: String, value: Int) {
        guard let draft = filterDraft,
              let group = draft.groups.first(where: { $0.filterID == groupID }),
              group.selectedValue != value else {
            return
        }
        objectWillChange.send()
        group.selectedValue = value
        UISelectionFeedbackGenerator().selectionChanged()
        updateFilterPreview()
    }

    func applyQuickFilter(groupID: String, value: Int) {
        guard !isReplacingContext,
              let state = currentFilterState.copy() as? PPFilterState,
              let group = state.groups.first(where: { $0.filterID == groupID }),
              group.selectedValue != value else {
            return
        }
        group.selectedValue = value
        isRefreshing = !records.isEmpty
        prepareBridgeContentTransition(.refinement)
        bridge.applyFilter(state, section: currentSection)
    }

    func resetFilterDraft() {
        filterDraft?.resetAll()
        objectWillChange.send()
        updateFilterPreview()
    }

    func applyFilterDraft() {
        guard !isReplacingContext, let draft = filterDraft else { return }
        activeSheet = nil
        filterDraft = nil
        isRefreshing = !records.isEmpty
        prepareBridgeContentTransition(.refinement)
        bridge.applyFilter(draft, section: currentSection)
    }

    func clearAllFilters() {
        guard !isReplacingContext,
              let state = currentFilterState.copy() as? PPFilterState else {
            return
        }
        state.resetAll()
        selectedProviderIDs[currentSection.rawValue] = nil
        selectedProviderID = nil
        isRefreshing = !records.isEmpty
        prepareBridgeContentTransition(.refinement)
        bridge.applyFilter(state, section: currentSection)
    }

    func presentProviderFilter() {
        guard !isReplacingContext,
              bridge.sectionSupportsProviderFilter(currentSection),
              !providerOptions.isEmpty else {
            return
        }
        activeSheet = .providers
    }

    func selectProvider(_ providerID: String?) {
        guard !isReplacingContext else { return }
        guard selectedProviderID != providerID else {
            activeSheet = nil
            return
        }
        selectedProviderIDs[currentSection.rawValue] = providerID
        selectedProviderID = providerID
        activeSheet = nil
        rebuildPresentedRecords()
        contentTransitionIntent = .refinement
        contentRevision &+= 1
        rebuildNavigationContext()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func dismissActiveSheet() {
        if activeSheet == .filters {
            filterDraft = nil
        }
        if activeSheet == .category {
            categoryDraftMainKindID = bridge.currentMainKindID
            categoryDraftSubKindID = bridge.currentSubKindID
        }
        activeSheet = nil
    }

    func sheetDidDismiss() {
        filterDraft = nil
        categoryDraftMainKindID = bridge.currentMainKindID
        categoryDraftSubKindID = bridge.currentSubKindID
    }

    func openSearch() {
        // Search is an external route. The retained bridge remains the sole
        // owner of the active Main Kind/Subkind while it is presented.
        searchAction()
    }

    func goBack() {
        bridge.goBack()
    }

    func openCart() {
        bridge.openCart()
    }

    func dismissUpdateError() {
        updateErrorMessage = nil
    }

    func refreshPresentationState(includeContext: Bool? = nil) {
        let nextMainKindTitle = bridge.currentMainKindTitle
        let nextSubKindTitle = bridge.currentSubKindTitle
        let nextAccentColor = bridge.accentColor
        let nextUsesBrandAccent = bridge.isUsingBrandAccent
        let nextCartItemCount = bridge.cartItemCount
        let nextBottomClearance = max(0, bridge.bottomNavigationClearance)
        let shouldRefreshContext = includeContext ?? (
            !isReplacingContext && !bridgeContextCommitPending
        )

        if shouldRefreshContext {
            if currentMainKindTitle != nextMainKindTitle {
                currentMainKindTitle = nextMainKindTitle
            }
            if currentSubKindTitle != nextSubKindTitle {
                currentSubKindTitle = nextSubKindTitle
            }
            if !resolvedAccentColor.isEqual(nextAccentColor) {
                resolvedAccentColor = nextAccentColor
            }
            if usesBrandAccent != nextUsesBrandAccent {
                usesBrandAccent = nextUsesBrandAccent
            }
            rebuildNavigationContext()
        }
        if cartItemCount != nextCartItemCount {
            cartItemCount = nextCartItemCount
        }
        if abs(bottomClearance - nextBottomClearance) > 0.5 {
            bottomClearance = nextBottomClearance
        }
    }

    /// UIKit can ask for safe-area and bottom-surface updates several times in
    /// one layout transaction. Coalesce those callbacks onto the next main
    /// queue turn so ObservableObject never publishes from SwiftUI's render
    /// pass.
    func schedulePresentationStateRefresh() {
        guard !presentationStateRefreshScheduled else { return }
        presentationStateRefreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.presentationStateRefreshScheduled = false
            self.refreshPresentationState()
        }
    }

    private func bindBridge() {
        bridge.itemsDidChange = { [weak self] in
            Task { @MainActor in
                self?.consumeBridgeState()
            }
        }
        bridge.itemsDidAppend = { [weak self] _ in
            Task { @MainActor in
                self?.consumeBridgeState()
            }
        }
        bridge.loadingDidFail = { [weak self] error in
            Task { @MainActor in
                self?.consume(error: error)
            }
        }
        bridge.initialContentDidLoad = { [weak self] in
            Task { @MainActor in
                self?.didLoadContent = true
            }
        }
        bridge.providerIdentitiesDidChange = { [weak self] in
            Task { @MainActor in
                self?.rebuildProviderOptions()
                self?.rebuildNavigationContext()
            }
        }
        bridge.presentationStateDidChange = { [weak self] in
            Task { @MainActor in
                self?.schedulePresentationStateRefresh()
            }
        }
    }

    private func installObservers() {
        let center = NotificationCenter.default
        let names = [
            "CartUpdated",
            UIApplication.willEnterForegroundNotification.rawValue,
            UIApplication.didBecomeActiveNotification.rawValue
        ]
        observerTokens.append(contentsOf: names.map { name in
            center.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.bridge.refreshPresentationState()
                }
            }
        })
        observerTokens.append(
            center.addObserver(
                forName: Notification.Name("PPAdDidFinishUploadNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.currentSection.rawValue == 0 else {
                        return
                    }
                    guard !self.bridge.isLoading,
                          !self.isReplacingContext else { return }
                    self.bridge.reload()
                }
            }
        )
    }

    private func consumeBridgeState() {
        let previousSection = currentSection.rawValue
        let incomingItems = bridge.items

        if bridge.isLoading && incomingItems.isEmpty {
            // A context change intentionally clears the bridge before its next
            // payload arrives. Keep the existing result geometry in place so a
            // deeply scrolled Species/Breed change neither jumps nor strands
            // the pinned dock beyond a suddenly-short loading subtree.
            if records.isEmpty {
                rawItems = []
                loadState = .loading
            } else {
                isRefreshing = true
                loadState = .content
            }
            return
        }

        bridgeContextCommitPending = false
        currentSection = bridge.currentSection
        if previousSection != currentSection.rawValue {
            selectedProviderID = selectedProviderIDs[currentSection.rawValue]
            providerOptions = []
            if !UserDefaults.standard.bool(forKey: "PPLayoutModeChangedByUser") {
                layout = .mosaic
            }
        }
        refreshPresentationState(includeContext: true)

        rawItems = incomingItems
        rebuildProviderOptions()
        rebuildPresentedRecords()
        // The bridge first publishes an intentional empty loading snapshot and
        // later publishes the replacement payload. Commit the visual content
        // transition only for that completed payload; committing on the empty
        // snapshot can strand a retained ScrollView offset beyond its content.
        let delaysInteractionUnlock = isReplacingContext
        commitBridgeContentTransitionIfNeeded()
        let committedRevision = contentRevision
        isRefreshing = false
        didLoadContent = true
        updateErrorMessage = nil
        loadState = records.isEmpty ? .empty : .content
        if records.isEmpty {
            emitEmptyStateIfNeeded()
        } else {
            lastEmptyContextSignature = nil
        }
        if delaysInteractionUnlock {
            // Allow reused universal-card StateObjects and the scroll geometry
            // marker one main turn to consume the completed payload before
            // result actions become available again.
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.contentRevision == committedRevision else { return }
                self.isReplacingContext = false
            }
        } else {
            isReplacingContext = false
        }
    }

    private func consume(error: Error) {
        _ = error
        let failedContextReplacement = bridgeContextCommitPending
        bridgeContextCommitPending = false
        isRefreshing = false
        isReplacingContext = false
        commitBridgeContentTransitionIfNeeded()
        let isOffline = !bridge.isNetworkAvailable
        let message = PPMarketplaceText.localized(
            isOffline
                ? "marketplace_offline_message"
                : "marketplace_error_message"
        )
        if failedContextReplacement {
            // The bridge has already committed the requested Species/Breed or
            // section as its query authority. Do not leave old cards and menu
            // checkmarks under that new live context after a failed fetch.
            currentSection = bridge.currentSection
            selectedProviderID = selectedProviderIDs[currentSection.rawValue]
            providerOptions = []
            rawItems = []
            records = []
            refreshPresentationState(includeContext: true)
            didLoadContent = true
            updateErrorMessage = nil
            loadState = isOffline ? .offline(message) : .failed(message)
            return
        }
        if !records.isEmpty {
            updateErrorMessage = message
            loadState = .content
            return
        }
        loadState = isOffline ? .offline(message) : .failed(message)
    }

    private func rebuildProviderOptions() {
        guard bridge.sectionSupportsProviderFilter(currentSection) else {
            providerOptions = []
            selectedProviderID = nil
            return
        }
        providerOptions = bridge.providerOptions(
            items: rawItems,
            section: currentSection
        )
        bridge.hydrateProviderIdentities(
            items: rawItems,
            section: currentSection
        )
        if let selectedProviderID,
           !providerOptions.contains(where: {
               $0.providerID == selectedProviderID
           }) {
            selectedProviderIDs[currentSection.rawValue] = nil
            self.selectedProviderID = nil
        }
    }

    private func rebuildPresentedRecords() {
        let presented = bridge.items(
            rawItems,
            matchingProviderID: selectedProviderID
        )
        var duplicateCounts: [String: Int] = [:]
        records = presented.enumerated().map { index, viewModel in
            let baseID: String
            if let modelID = viewModel.modelID, !modelID.isEmpty {
                baseID = [
                    String(currentSection.rawValue),
                    String(currentMainKindID),
                    String(currentSubKindID),
                    modelID
                ].joined(separator: "|")
            } else {
                baseID = [
                    String(currentSection.rawValue),
                    String(currentMainKindID),
                    String(currentSubKindID),
                    "index",
                    String(index)
                ].joined(separator: "|")
            }
            let duplicateIndex = duplicateCounts[baseID, default: 0]
            duplicateCounts[baseID] = duplicateIndex + 1
            let stableID = duplicateIndex == 0
                ? baseID
                : "\(baseID)|\(duplicateIndex)"
            return PPMarketplaceItemRecord(
                id: stableID,
                viewModel: viewModel,
                section: currentSection,
                ordinal: index
            )
        }
        if !bridge.isLoading {
            loadState = records.isEmpty ? .empty : .content
        }
    }

    private func updateFilterPreview() {
        guard let filterDraft else {
            filterPreviewCount = records.count
            return
        }
        filterPreviewCount = bridge.previewResultCount(for: filterDraft)
    }

    private func normalizeCategoryDraftSubKind() {
        guard categoryDraftSubKindChoices.contains(where: {
            $0.id == categoryDraftSubKindID
        }) else {
            categoryDraftSubKindID = 0
            return
        }
    }

    private func prepareBridgeContentTransition(
        _ intent: PPMarketplaceContentTransitionIntent
    ) {
        contentTransitionIntent = intent
        awaitsBridgeContentTransition = true
        bridgeContextCommitPending = true
        isReplacingContext = true
        if records.isEmpty {
            loadState = .loading
        } else {
            isRefreshing = true
            loadState = .content
        }
    }

    private func commitBridgeContentTransitionIfNeeded() {
        guard awaitsBridgeContentTransition else { return }
        awaitsBridgeContentTransition = false
        contentRevision &+= 1
    }

    private func emitEmptyStateIfNeeded() {
        let selectedFilterSignature = currentFilterState.groups
            .sorted { $0.filterID < $1.filterID }
            .map { "\($0.filterID)=\($0.selectedValue)" }
            .joined(separator: ",")
        let signature = [
            String(currentSection.rawValue),
            String(currentMainKindID),
            String(currentSubKindID),
            selectedProviderID ?? "all",
            selectedFilterSignature
        ].joined(separator: "|")
        guard signature != lastEmptyContextSignature else { return }
        lastEmptyContextSignature = signature
        bridge.screenDidShowEmptyState()
    }

    private func rebuildNavigationContext() {
        guard !bridgeContextCommitPending else { return }
        let next = bridge.navigationContext(
            for: currentSection,
            selectedProviderID: selectedProviderID
        )
        guard navigationContext.title != next.title ||
                navigationContext.subtitle != next.subtitle ||
                navigationContext.systemImageName != next.systemImageName ||
                navigationContext.accessibilityLabel != next.accessibilityLabel else {
            return
        }
        navigationContext = next
    }
}
