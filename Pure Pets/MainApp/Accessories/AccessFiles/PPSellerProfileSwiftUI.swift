import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import SwiftUI
import UIKit

@objc(SellerProfileVCDelegate)
public protocol PPSellerProfileDelegate: AnyObject {
    @objc optional func sellerProfileDidTapContact(_ seller: UserModel)
    @objc optional func sellerProfileDidTapCall(_ seller: UserModel)
    @objc optional func sellerProfileDidSelectItem(_ item: AnyObject)
}

struct PPSellerProfileAlert: Identifiable {
    let id = UUID()
    let titleKey: String
    let messageKey: String
}

@MainActor
final class PPSellerProfileStore: ObservableObject {
    enum ItemsPhase: Equatable {
        case loading
        case loaded
        case empty
        case failed
    }

    @Published private(set) var seller: UserModel?
    @Published private(set) var items: [PetAccessory] = []
    @Published private(set) var itemsPhase: ItemsPhase = .empty
    @Published private(set) var ratingValue = 0.0
    @Published private(set) var reviewCount = 0
    @Published private(set) var ratingEligibilityLoaded = false
    @Published private(set) var isCheckingRatingEligibility = false
    @Published private(set) var canRateProvider = false
    @Published private(set) var hasExistingProviderReview = false
    @Published private(set) var isSubmittingProviderReview = false
    @Published var showsRatingSheet = false
    @Published var selectedRating = 0
    @Published var reviewComment = ""
    @Published var alert: PPSellerProfileAlert? {
        didSet {
            guard let alert else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let vc = self.presenter ?? AppManager.sharedInstance().topViewController()
                PPAlertHelper.showInfo(
                    in: vc,
                    title: PPProviderStorefrontL10n.text(alert.titleKey),
                    subtitle: PPProviderStorefrontL10n.text(alert.messageKey)
                )
            }
        }
    }
    @Published private(set) var cartCount = 0
    @Published private(set) var cartRevision = 0
    @Published var bottomClearance: CGFloat = 0

    weak var presenter: UIViewController?

    private var categoryIdentifier: String?
    private var seededItems: [PetAccessory] = []
    private var itemsToken = UUID()
    private var ratingEligibilityUID = ""
    private var existingProviderRating = 0
    private var existingProviderReviewComment = ""
    private var ratingListener: ListenerRegistration?

    deinit {
        ratingListener?.remove()
    }

    var sellerID: String {
        PPProviderStorefrontDataBridge.sellerIdentifier(for: seller)
    }

    var sellerDisplayName: String {
        guard let seller else {
            return PPProviderStorefrontL10n.text("premium_seller")
        }
        let displayName = PPAccessoryViewerLegacyBridge.displayName(for: seller)
        return displayName.isEmpty
            ? PPProviderStorefrontL10n.text("premium_seller")
            : displayName
    }

    var sellerAbout: String {
        PPProviderStorefrontDataBridge.sellerAbout(for: seller)
    }

    var sellerAvatarURL: String {
        guard let seller else { return "" }
        return PPAccessoryViewerLegacyBridge.avatarURL(for: seller) ?? ""
    }

    var sellerIsVerified: Bool {
        guard let seller else { return false }
        return PPAccessoryViewerLegacyBridge.isVerified(user: seller)
    }

    var sellerIsActive: Bool {
        PPProviderStorefrontDataBridge.isSellerActive(seller)
    }

    var isProviderStorefront: Bool {
        !(categoryIdentifier ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var isPharmacyStorefront: Bool {
        isProviderStorefront && normalizedCategory == "pharmacy"
    }

    var categoryTitle: String {
        guard isProviderStorefront else {
            return PPProviderStorefrontL10n.text("premium_seller")
        }
        return PPProviderStorefrontL10n.text(
            isPharmacyStorefront
                ? "provider_pharmacies_title"
                : "provider_marketplace_title"
        )
    }

    var categorySupportText: String {
        guard isProviderStorefront else {
            return PPProviderStorefrontL10n.text("premium_seller_on_platform")
        }
        return PPProviderStorefrontL10n.text(
            isPharmacyStorefront
                ? "provider_storefront_subtitle_pharmacy"
                : "provider_storefront_subtitle_marketplace"
        )
    }

    var storefrontDescription: String {
        guard isProviderStorefront else {
            return PPProviderStorefrontL10n.text("premium_seller_description")
        }
        return PPProviderStorefrontL10n.text(
            isPharmacyStorefront
                ? "provider_storefront_description_pharmacy"
                : "provider_storefront_description_marketplace"
        )
    }

    var itemsTitle: String {
        guard isProviderStorefront else {
            return PPProviderStorefrontL10n.text("seller_items")
        }
        return PPProviderStorefrontL10n.text(
            isPharmacyStorefront
                ? "provider_storefront_items_title_pharmacy"
                : "provider_storefront_items_title_marketplace"
        )
    }

    var emptyItemsText: String {
        guard isProviderStorefront else {
            return PPProviderStorefrontL10n.text("seller_profile_empty_items")
        }
        return PPProviderStorefrontL10n.text(
            isPharmacyStorefront
                ? "provider_storefront_empty_pharmacy"
                : "provider_storefront_empty_marketplace"
        )
    }

    var statusText: String {
        if sellerIsVerified {
            return PPProviderStorefrontL10n.text("verified")
        }
        if sellerIsActive {
            return PPProviderStorefrontL10n.text("provider_company_status_active")
        }
        return ""
    }

    var ratingText: String {
        guard reviewCount > 0, ratingValue > 0 else {
            return PPProviderStorefrontL10n.text("provider_rating_new")
        }
        return String(format: "%.1f", ratingValue)
    }

    var rateActionTitle: String {
        if isCheckingRatingEligibility || isSubmittingProviderReview {
            return PPProviderStorefrontL10n.text(
                isSubmittingProviderReview
                    ? "provider_rating_submitting"
                    : "provider_rating_checking"
            )
        }
        if PPAccessoryViewerLegacyBridge.isSignedIn(),
           ratingEligibilityLoaded,
           !canRateProvider {
            return PPProviderStorefrontL10n.text("provider_rating_purchase_required_short")
        }
        if hasExistingProviderReview {
            return PPProviderStorefrontL10n.text("provider_rating_update_action")
        }
        if reviewCount > 0, ratingValue > 0 {
            return PPProviderStorefrontL10n.format(
                "provider_rating_action_score_format",
                ratingValue
            )
        }
        return PPProviderStorefrontL10n.text("provider_rating_action")
    }

    var rateActionSymbol: String {
        if isCheckingRatingEligibility || isSubmittingProviderReview {
            return "clock"
        }
        if PPAccessoryViewerLegacyBridge.isSignedIn(),
           ratingEligibilityLoaded,
           !canRateProvider {
            return "lock.fill"
        }
        return hasExistingProviderReview ? "star.circle.fill" : "star.fill"
    }

    var rateActionDisabled: Bool {
        isCheckingRatingEligibility || isSubmittingProviderReview || sellerID.isEmpty
    }

    var shouldShowRateAction: Bool {
        !sellerID.isEmpty && !isCurrentUserSeller
    }

    func configure(
        seller: UserModel?,
        seededItems: [PetAccessory],
        categoryIdentifier: String?
    ) {
        let nextSellerID = PPProviderStorefrontDataBridge.sellerIdentifier(for: seller)
        let sellerChanged = nextSellerID != sellerID
        let categoryChanged = self.categoryIdentifier != categoryIdentifier

        self.seller = seller
        self.seededItems = seededItems
        self.categoryIdentifier = categoryIdentifier

        if sellerChanged || categoryChanged {
            resetRatingState()
            items = []
            loadItems()
            startRatingListener()
            refreshRatingEligibility()
        } else {
            applySeededItems()
        }
        refreshCartCount()
    }

    func loadItems() {
        let sellerID = sellerID
        let token = UUID()
        itemsToken = token

        guard !sellerID.isEmpty else {
            items = []
            itemsPhase = .empty
            return
        }

        if seededItems.isEmpty {
            itemsPhase = .loading
        } else {
            items = seededItems
            itemsPhase = .loaded
        }

        PPProviderStorefrontDataBridge.fetchStorefrontItems(
            ownerID: sellerID,
            categoryIdentifier: categoryIdentifier,
            seededItems: (seededItems as NSArray) as! [PetAccessory]
        ) { [weak self] items, error in
            DispatchQueue.main.async {
                guard let self, self.itemsToken == token else { return }
                self.items = items
                if items.isEmpty {
                    self.itemsPhase = error == nil ? .empty : .failed
                } else {
                    self.itemsPhase = .loaded
                }
            }
        }
    }

    func retryItems() {
        loadItems()
    }

    func refreshCartCount() {
        cartCount = PPAccessoryViewerLegacyBridge.cartItemsCount()
    }

    func cartDidChange() {
        refreshCartCount()
        cartRevision += 1
    }

    func requestRating() {
        guard let presenter else { return }
        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            // The shared auth flow replaces the root controller on success, so
            // it owns post-auth navigation instead of resuming this sheet.
            PPAccessoryViewerLegacyBridge.presentSignIn(from: presenter) { _ in }
            return
        }
        guard !isCurrentUserSeller else {
            alert = PPSellerProfileAlert(
                titleKey: "provider_rating_owner_block",
                messageKey: "provider_rating_owner_block"
            )
            return
        }
        guard !isCheckingRatingEligibility, !isSubmittingProviderReview else {
            return
        }

        if ratingEligibilityLoaded {
            openRatingSheetIfEligible()
        } else {
            refreshRatingEligibility { [weak self] _ in
                self?.openRatingSheetIfEligible()
            }
        }
    }

    func submitRating() {
        let providerID = sellerID
        guard !providerID.isEmpty, (1...5).contains(selectedRating) else { return }

        isSubmittingProviderReview = true
        Functions.functions(region: "us-central1")
            .httpsCallable("submitProviderReview")
            .call([
                "providerID": providerID,
                "rating": selectedRating,
                "comment": reviewComment.trimmingCharacters(in: .whitespacesAndNewlines),
                "platform": "ios"
            ]) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isSubmittingProviderReview = false
                    guard error == nil, result?.data is [String: Any] else {
                        self.alert = PPSellerProfileAlert(
                            titleKey: "provider_rating_failed",
                            messageKey: "provider_rating_failed_subtitle"
                        )
                        return
                    }

                    let priorCount = max(self.reviewCount, 0)
                    let priorAverage = min(max(self.ratingValue, 0), 5)
                    if self.hasExistingProviderReview,
                       priorCount > 0,
                       self.existingProviderRating > 0 {
                        self.ratingValue = min(
                            max(
                                ((priorAverage * Double(priorCount))
                                    - Double(self.existingProviderRating)
                                    + Double(self.selectedRating)) / Double(priorCount),
                                0
                            ),
                            5
                        )
                    } else {
                        self.ratingValue = ((priorAverage * Double(priorCount))
                            + Double(self.selectedRating)) / Double(priorCount + 1)
                        self.reviewCount = priorCount + 1
                    }

                    self.ratingEligibilityLoaded = true
                    self.canRateProvider = true
                    self.hasExistingProviderReview = true
                    self.existingProviderRating = self.selectedRating
                    self.existingProviderReviewComment = self.reviewComment
                    self.showsRatingSheet = false
                    self.alert = PPSellerProfileAlert(
                        titleKey: "provider_rating_success",
                        messageKey: "provider_rating_success_subtitle"
                    )
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
    }

    func screenWillAppear() {
        startRatingListener()
        ratingEligibilityLoaded = false
        refreshRatingEligibility()
        refreshCartCount()
    }

    private var normalizedCategory: String {
        (categoryIdentifier ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var currentUserID: String {
        PPAccessoryViewerLegacyBridge.currentUserID() ?? ""
    }

    private var isCurrentUserSeller: Bool {
        !currentUserID.isEmpty && currentUserID == sellerID
    }

    private func applySeededItems() {
        items = seededItems
        itemsPhase = seededItems.isEmpty ? .empty : .loaded
    }

    private func resetRatingState() {
        ratingListener?.remove()
        ratingListener = nil
        ratingValue = 0
        reviewCount = 0
        ratingEligibilityLoaded = false
        isCheckingRatingEligibility = false
        canRateProvider = false
        hasExistingProviderReview = false
        existingProviderRating = 0
        existingProviderReviewComment = ""
        ratingEligibilityUID = ""
    }

    private func startRatingListener() {
        ratingListener?.remove()
        ratingListener = nil

        let providerID = sellerID
        guard !providerID.isEmpty, PPAccessoryViewerLegacyBridge.isSignedIn() else {
            return
        }

        ratingListener = Firestore.firestore()
            .collection("UsersCol")
            .document(providerID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard error == nil, let data = snapshot?.data() else { return }
                Task { @MainActor in
                    guard let self, self.sellerID == providerID else { return }
                    self.ratingValue = min(
                        max((data["providerRatingValue"] as? NSNumber)?.doubleValue ?? 0, 0),
                        5
                    )
                    self.reviewCount = max(
                        (data["providerReviewCount"] as? NSNumber)?.intValue ?? 0,
                        0
                    )
                }
            }
    }

    private func refreshRatingEligibility(
        completion: ((Bool) -> Void)? = nil
    ) {
        let providerID = sellerID
        let currentUID = currentUserID
        guard !providerID.isEmpty,
              !currentUID.isEmpty,
              PPAccessoryViewerLegacyBridge.isSignedIn(),
              !isCurrentUserSeller else {
            ratingEligibilityLoaded = true
            isCheckingRatingEligibility = false
            canRateProvider = false
            hasExistingProviderReview = false
            ratingEligibilityUID = currentUID
            completion?(false)
            return
        }

        guard !isCheckingRatingEligibility else { return }
        if ratingEligibilityLoaded, ratingEligibilityUID == currentUID {
            completion?(canRateProvider)
            return
        }

        isCheckingRatingEligibility = true
        ratingEligibilityLoaded = false
        ratingEligibilityUID = currentUID
        Functions.functions(region: "us-central1")
            .httpsCallable("getProviderReviewEligibility")
            .call(["providerID": providerID]) { [weak self] result, error in
                Task { @MainActor in
                    guard let self,
                          self.sellerID == providerID,
                          self.currentUserID == currentUID else { return }
                    self.isCheckingRatingEligibility = false
                    guard error == nil, let data = result?.data as? [String: Any] else {
                        self.ratingEligibilityLoaded = false
                        self.canRateProvider = false
                        completion?(false)
                        return
                    }

                    self.ratingEligibilityLoaded = true
                    self.canRateProvider = data["eligible"] as? Bool ?? false
                    self.hasExistingProviderReview = data["hasReview"] as? Bool ?? false
                    self.existingProviderRating = min(
                        max((data["rating"] as? NSNumber)?.intValue ?? 0, 0),
                        5
                    )
                    self.existingProviderReviewComment = data["comment"] as? String ?? ""
                    self.ratingValue = min(
                        max((data["providerRatingValue"] as? NSNumber)?.doubleValue ?? self.ratingValue, 0),
                        5
                    )
                    self.reviewCount = max(
                        (data["providerReviewCount"] as? NSNumber)?.intValue ?? self.reviewCount,
                        0
                    )
                    completion?(self.canRateProvider)
                }
            }
    }

    private func openRatingSheetIfEligible() {
        guard ratingEligibilityLoaded else {
            alert = PPSellerProfileAlert(
                titleKey: "provider_rating_check_failed",
                messageKey: "provider_rating_check_failed_subtitle"
            )
            return
        }
        guard canRateProvider else {
            alert = PPSellerProfileAlert(
                titleKey: "provider_rating_purchase_required_title",
                messageKey: "provider_rating_purchase_required_subtitle"
            )
            return
        }
        selectedRating = existingProviderRating
        reviewComment = existingProviderReviewComment
        showsRatingSheet = true
    }
}

private struct PPSellerProfileScreen: View {
    @ObservedObject var store: PPSellerProfileStore
    let onBack: () -> Void
    let onCart: () -> Void
    let onMessage: () -> Void
    let onRate: () -> Void
    let delegate: PPUniversalCellDelegate?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private let columns = [
        GridItem(.flexible(), spacing: PPSpace.md),
        GridItem(.flexible(), spacing: PPSpace.md)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PPSpace.xl) {
                hero
                productsSection
            }
            .padding(.horizontal, PPSpace.base)
            .padding(.bottom, max(PPSpace.xxxl, store.bottomClearance))
        }
        .background(Color.ppBackground.ignoresSafeArea())
        .sheet(isPresented: $store.showsRatingSheet) {
            PPSellerProfileRatingSheet(store: store)
        }
        .accessibilityIdentifier("sellerProfileSwiftUIScreen")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            HStack {
                circularAction(
                    symbol: "chevron.backward",
                    labelKey: "Back",
                    action: onBack
                )
                Spacer(minLength: 0)
                Button(action: onCart) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                        if store.cartCount > 0 {
                            Text("\(store.cartCount)")
                                .font(.custom("Beiruti-Bold", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Color.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.ppPrimary, in: Capsule(style: .continuous))
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.ppTextPrimary)
                .background(Color.ppSurface, in: Circle())
                .accessibilityLabel(PPProviderStorefrontL10n.text("Cart"))
                .accessibilityHint(PPProviderStorefrontL10n.text("a11y_btn_cart_hint"))
            }

            HStack(alignment: .top, spacing: PPSpace.base) {
                AppRemoteImage(
                    urlString: store.sellerAvatarURL,
                    displaySize: CGSize(width: 76, height: 76),
                    contentMode: .fill,
                    showsRetryAction: false,
                    placeholder: {
                        Color.clear
                    },
                    failurePlaceholder: {
                        Color.clear
                    }
                )
                .frame(width: 76, height: 76)
                .clipped()
                .background(Color.ppSecondarySurface)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.ppSurfaceBorder, lineWidth: contrast == .increased ? 1.4 : 1)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !store.statusText.isEmpty {
                        Image(systemName: store.sellerIsVerified ? "checkmark.seal.fill" : "circle.fill")
                            .font(.system(size: store.sellerIsVerified ? 18 : 10, weight: .bold))
                            .foregroundStyle(store.sellerIsVerified ? Color.ppSuccess : Color.ppPrimary)
                            .padding(PPSpace.xxs)
                            .background(Color.ppSurface, in: Circle())
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    Text(store.categoryTitle)
                        .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.ppPrimary)
                    Text(store.sellerDisplayName)
                        .font(.custom("Beiruti-Bold", size: 25, relativeTo: .title2))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(store.sellerAbout.isEmpty ? store.categorySupportText : store.sellerAbout)
                        .font(.custom("Beiruti-Regular", size: 14, relativeTo: .body))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(3)
                    if !store.statusText.isEmpty {
                        Text(store.statusText)
                            .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.ppSuccess)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(store.storefrontDescription)
                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .body))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PPSpace.sm) {
                Button(action: onMessage) {
                    Label(
                        PPProviderStorefrontL10n.text("message"),
                        systemImage: "message.fill"
                    )
                    .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(PPSellerProfileActionButtonStyle(prominent: true))
                .disabled(store.seller == nil)

                if store.shouldShowRateAction {
                    Button(action: onRate) {
                        Label(store.rateActionTitle, systemImage: store.rateActionSymbol)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(PPSellerProfileActionButtonStyle(prominent: false))
                    .disabled(store.rateActionDisabled)
                }
            }
            .accessibilityElement(children: .contain)

            HStack(spacing: PPSpace.sm) {
                sellerMetric(
                    symbol: "star.fill",
                    text: store.ratingText,
                    tint: Color.ppPremiumAccent
                )
                if store.reviewCount > 0 {
                    sellerMetric(
                        symbol: "text.bubble.fill",
                        text: "\(store.reviewCount)",
                        tint: Color.ppTextSecondary
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .padding(PPSpace.lg)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.78), lineWidth: contrast == .increased ? 1.2 : 0.8)
        }
        .shadow(color: Color.ppPrimary.opacity(reduceMotion ? 0.04 : 0.10), radius: 22, y: 10)
        .padding(.top, PPSpace.sm)
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            Text(store.itemsTitle)
                .font(.custom("Beiruti-Bold", size: 22, relativeTo: .title3))
                .foregroundStyle(Color.ppTextPrimary)

            switch store.itemsPhase {
            case .loading:
                ProgressView()
                    .tint(Color.ppPrimary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .accessibilityLabel(PPProviderStorefrontL10n.text("provider_companies_loading_title"))
            case .failed:
                PPSellerProfileItemsState(
                    symbol: "wifi.exclamationmark",
                    title: PPProviderStorefrontL10n.text("provider_storefront_error_message"),
                    actionTitle: PPProviderStorefrontL10n.text("provider_retry"),
                    action: store.retryItems
                )
            case .empty:
                PPSellerProfileItemsState(
                    symbol: "shippingbox",
                    title: store.emptyItemsText,
                    actionTitle: nil,
                    action: nil
                )
            case .loaded:
                LazyVGrid(columns: columns, spacing: PPSpace.md) {
                    ForEach(store.items, id: \.accessoryID) { item in
                        if #available(iOS 16.0, *) {
                            PPSellerProfileUniversalProductCard(
                                accessory: item,
                                delegate: delegate
                            )
                        } else {
                            PPSellerProfileCompatibilityProductCard(
                                accessory: item,
                                onTap: {
                                    delegateItemTap(item)
                                },
                                onAdd: {
                                    delegateQuantityChange(item, quantity: 1)
                                }
                            )
                        }
                    }
                }
                .id(store.cartRevision)
            }
        }
    }

    private func circularAction(
        symbol: String,
        labelKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ppTextPrimary)
        .background(Color.ppSurface, in: Circle())
        .accessibilityLabel(PPProviderStorefrontL10n.text(labelKey))
    }

    private func sellerMetric(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: PPSpace.xxs) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, PPSpace.sm)
        .frame(minHeight: 30)
        .background(tint.opacity(0.10), in: Capsule(style: .continuous))
    }

    private func delegateItemTap(_ item: PetAccessory) {
        let model = PPUniversalCellViewModel(model: item, context: item.isFood ? .forFood : .forMarket)
        delegate?.ppUniversalCell_tapCard?(model)
    }

    private func delegateQuantityChange(_ item: PetAccessory, quantity: Int) {
        let model = PPUniversalCellViewModel(model: item, context: item.isFood ? .forFood : .forMarket)
        delegate?.ppUniversalCell_changeQuantity?(model, quantity: quantity)
    }
}

private struct PPSellerProfileActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Beiruti-Bold", size: 14, relativeTo: .headline))
            .foregroundStyle(prominent ? Color.white : Color.ppPrimary)
            .background(
                prominent ? Color.ppPrimary : Color.ppPrimary.opacity(0.10),
                in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .stroke(
                        prominent ? Color.clear : Color.ppPrimary.opacity(0.20),
                        lineWidth: 0.8
                    )
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct PPSellerProfileItemsState: View {
    let symbol: String
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.ppPrimary)
            Text(title)
                .font(.custom("Beiruti-Regular", size: 15, relativeTo: .body))
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ppPrimary)
            }
        }
        .padding(PPSpace.xl)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
    }
}

@available(iOS 16.0, *)
private struct PPSellerProfileUniversalProductCard: View {
    private let viewModel: PPUniversalCellViewModel
    private let context: PPCellContext
    private let delegate: PPUniversalCellDelegate?

    init(accessory: PetAccessory, delegate: PPUniversalCellDelegate?) {
        context = accessory.isFood ? .forFood : .forMarket
        viewModel = PPUniversalCellViewModel(model: accessory, context: context)
        self.delegate = delegate
    }

    var body: some View {
        PPUniversalCardView(
            viewModel: viewModel,
            delegate: delegate,
            context: context,
            layoutMode: .cellLayoutModeVertical,
            discountMode: .badge,
            imageLoader: nil,
            hideTopBadge: false,
            showsSubtitle: true,
            forceShowsOwnerMenuButton: false,
            dataViewPresentation: false,
            isHomePresentation: false,
            onTap: nil,
            onQuantityChange: nil
        )
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("sellerStorefrontProduct_\(viewModel.modelID ?? "")")
    }
}

private struct PPSellerProfileCompatibilityProductCard: View {
    let accessory: PetAccessory
    let onTap: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            AppRemoteImage(
                urlString: accessory.imageURLsArray.first,
                contentMode: .fill,
                showsRetryAction: false,
                placeholder: {
                    Color.clear
                },
                failurePlaceholder: {
                    Color.clear
                }
            )
            .frame(height: 122)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(Color.ppSecondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
            Text(accessory.name)
                .font(.custom("Beiruti-Bold", size: 15, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(2)
            Text(PPAccessoryViewerLegacyBridge.formattedPrice(for: accessory))
                .font(.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.ppPrimary)
            HStack(spacing: PPSpace.sm) {
                Button(PPProviderStorefrontL10n.text("view_details"), action: onTap)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .buttonStyle(.bordered)
            .tint(Color.ppPrimary)
        }
        .padding(PPSpace.sm)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
    }
}

private struct PPSellerProfileRatingSheet: View {
    @ObservedObject var store: PPSellerProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ratingForm
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        } else {
            NavigationView {
                ratingForm
            }
            .navigationViewStyle(.stack)
        }
    }

    private var ratingForm: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            Text(
                PPProviderStorefrontL10n.format(
                    "provider_rating_sheet_title_format",
                    store.sellerDisplayName
                )
            )
                .font(.custom("Beiruti-Bold", size: 23, relativeTo: .title2))
                .foregroundStyle(Color.ppTextPrimary)
            Text(PPProviderStorefrontL10n.text("provider_rating_sheet_subtitle"))
                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .body))
                .foregroundStyle(Color.ppTextSecondary)
            HStack(spacing: PPSpace.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        store.selectedRating = value
                    } label: {
                        Image(systemName: value <= store.selectedRating ? "star.fill" : "star")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.ppPremiumAccent)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        PPProviderStorefrontL10n.format(
                            "provider_rating_star_accessibility_format",
                            value
                        )
                    )
                }
            }
            TextEditor(text: $store.reviewComment)
                .font(.custom("Beiruti-Regular", size: 15, relativeTo: .body))
                .frame(minHeight: 150)
                .padding(PPSpace.sm)
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                .accessibilityLabel(PPProviderStorefrontL10n.text("provider_rating_action"))
            Spacer(minLength: 0)
            Button {
                store.submitRating()
            } label: {
                Group {
                    if store.isSubmittingProviderReview {
                        ProgressView().tint(Color.white)
                    } else {
                        Text(PPProviderStorefrontL10n.text("provider_rating_submit"))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PPSellerProfileActionButtonStyle(prominent: true))
            .disabled(store.selectedRating == 0 || store.isSubmittingProviderReview)
        }
        .padding(PPSpace.lg)
        .background(Color.ppBackground)
        .navigationTitle(PPProviderStorefrontL10n.text("provider_rating_action"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(PPProviderStorefrontL10n.text("cancel")) {
                    dismiss()
                }
            }
        }
    }
}

@MainActor
@objc(SellerProfileVC)
public class PPSellerProfileViewController: UIViewController, PPUniversalCellDelegate {
    @objc public var seller: UserModel? {
        didSet { configureStoreIfNeeded() }
    }

    @objc public var sellerItems: NSArray = [] {
        didSet { configureStoreIfNeeded() }
    }

    @objc public var providerCategoryIdentifier: String? {
        didSet { configureStoreIfNeeded() }
    }

    @objc public weak var delegate: PPSellerProfileDelegate?
    @objc public weak var parentVC: UIViewController?

    private let store = PPSellerProfileStore()
    private var hostingController: UIHostingController<AnyView>?
    private var inheritedNavigationBarHidden: Bool?
    private var inheritedInteractivePopGestureEnabled: Bool?
    private var cartObserver: NSObjectProtocol?

    public init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required public init?(coder: NSCoder) {
        fatalError("SellerProfileVC is code-only.")
    }

    deinit {
        if let cartObserver {
            NotificationCenter.default.removeObserver(cartObserver)
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        store.presenter = self
        configureStoreIfNeeded()

        let host = UIHostingController(rootView: rootView())
        hostingController = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        cartObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("CartUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.store.cartDidChange()
                self?.pp_updateBottomNavigationInsetsIfNeeded()
            }
        }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController {
            inheritedNavigationBarHidden = navigationController.isNavigationBarHidden
            navigationController.setNavigationBarHidden(true, animated: animated)
        }
        if let gesture = navigationController?.interactivePopGestureRecognizer {
            inheritedInteractivePopGestureEnabled = gesture.isEnabled
            gesture.isEnabled = true
        }
        hostingController?.rootView = rootView()
        store.screenWillAppear()
        pp_updateBottomNavigationInsetsIfNeeded()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let gesture = navigationController?.interactivePopGestureRecognizer,
           let inheritedInteractivePopGestureEnabled {
            gesture.isEnabled = inheritedInteractivePopGestureEnabled
            self.inheritedInteractivePopGestureEnabled = nil
        }
        if let navigationController,
           let inheritedNavigationBarHidden {
            navigationController.setNavigationBarHidden(
                inheritedNavigationBarHidden,
                animated: animated
            )
            self.inheritedNavigationBarHidden = nil
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pp_updateBottomNavigationInsetsIfNeeded()
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        pp_updateBottomNavigationInsetsIfNeeded()
    }

    @objc(pp_preferredBottomSurfaceKind)
    public func pp_preferredBottomSurfaceKind() -> Int {
        3
    }

    @objc(pp_isFloatingCartEligible)
    public func pp_isFloatingCartEligible() -> Bool {
        true
    }

    @objc(pp_openCart)
    public func pp_openCart() {
        PPAccessoryViewerLegacyBridge.openCart(from: self)
    }

    @objc(pp_updateBottomNavigationInsetsIfNeeded)
    public func pp_updateBottomNavigationInsetsIfNeeded() {
        store.bottomClearance = floatingCartClearance()
    }

    @objc(updateCollectionContentInset)
    public func updateCollectionContentInset() {
        pp_updateBottomNavigationInsetsIfNeeded()
    }

    public func ppUniversalCell_tapCard(_ universalModel: PPUniversalCellViewModel) {
        guard let accessory = universalModel.modelObject as? PetAccessory else { return }
        if let delegate {
            delegate.sellerProfileDidSelectItem?(accessory)
        } else {
            PPAccessoryViewerLegacyBridge.openAccessory(accessory, from: self)
        }
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    public func ppUniversalCell_changeQuantity(
        _ universalModel: PPUniversalCellViewModel,
        quantity: Int
    ) {
        guard let accessory = universalModel.modelObject as? PetAccessory else { return }
        let existingQuantity = PPAccessoryViewerLegacyBridge.cartQuantity(for: accessory)
        if quantity == 0 || existingQuantity > 0 {
            PPAccessoryViewerLegacyBridge.updateCartQuantity(
                quantity,
                for: accessory
            ) { _, _, _ in
                NotificationCenter.default.post(
                    name: Notification.Name("CartUpdated"),
                    object: nil
                )
            }
            return
        }

        PPAccessoryViewerLegacyBridge.addToCart(
            accessory,
            quantity: max(quantity, 1),
            from: self
        ) { _, _, _, _ in
            NotificationCenter.default.post(
                name: Notification.Name("CartUpdated"),
                object: nil
            )
        }
    }

    private func configureStoreIfNeeded() {
        guard isViewLoaded else { return }
        store.configure(
            seller: seller,
            seededItems: sellerItems.compactMap { $0 as? PetAccessory },
            categoryIdentifier: providerCategoryIdentifier
        )
        hostingController?.rootView = rootView()
    }

    private func rootView() -> AnyView {
        let languageCode = Language.currentLanguageCode() ?? "ar"
        return AnyView(
            PPSellerProfileScreen(
                store: store,
                onBack: { [weak self] in self?.goBack() },
                onCart: { [weak self] in self?.pp_openCart() },
                onMessage: { [weak self] in self?.openMessage() },
                onRate: { [weak self] in self?.store.requestRating() },
                delegate: self
            )
            .environment(\.locale, Locale(identifier: languageCode))
            .environment(
                \.layoutDirection,
                languageCode == "ar" ? .rightToLeft : .leftToRight
            )
        )
    }

    private func goBack() {
        if navigationController?.viewControllers.first !== self {
            navigationController?.popViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        }
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    private func openMessage() {
        guard let seller else { return }
        if let delegate {
            delegate.sellerProfileDidTapContact?(seller)
        } else {
            PPProviderStorefrontDataBridge.openChat(
                seller: seller,
                from: parentVC ?? self
            )
        }
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    private func floatingCartClearance() -> CGFloat {
        guard let tabBarController,
              !view.bounds.isEmpty else {
            return 0
        }

        var bottomNavigationView: UIView?
        let anchorSelector = NSSelectorFromString("pp_novaAmbientBottomNavigationAnchorView")
        if tabBarController.responds(to: anchorSelector) {
            bottomNavigationView = tabBarController.perform(anchorSelector)?
                .takeUnretainedValue() as? UIView
        }
        if bottomNavigationView == nil,
           !tabBarController.tabBar.isHidden,
           tabBarController.tabBar.alpha > 0.01 {
            bottomNavigationView = tabBarController.tabBar
        }
        guard let bottomNavigationView,
              !bottomNavigationView.isHidden,
              bottomNavigationView.alpha > 0.01,
              let superview = bottomNavigationView.superview else {
            return 0
        }

        let frame = superview.convert(bottomNavigationView.frame, to: view)
        guard !frame.isEmpty else { return 0 }
        let safeBottom = view.bounds.maxY - view.safeAreaInsets.bottom
        return ceil(max(0, safeBottom - frame.minY) + PPSpace.md)
    }
}

@MainActor
@objc(ProviderStorefrontProductsVC)
public final class PPProviderStorefrontProductsViewController: PPSellerProfileViewController {
    @objc(initWithSeller:items:categoryIdentifier:)
    public init(
        seller: UserModel?,
        items: NSArray,
        categoryIdentifier: String?
    ) {
        super.init()
        self.seller = seller
        sellerItems = items
        providerCategoryIdentifier = categoryIdentifier
    }

    public override init() {
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ProviderStorefrontProductsVC is code-only.")
    }
}
