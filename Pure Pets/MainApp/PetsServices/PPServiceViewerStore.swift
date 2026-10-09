import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

// Firebase removal APIs are thread-safe. All installation/state stays on MainActor.
private final class PPServiceViewerListenerLifetime: @unchecked Sendable {
    var service: ListenerRegistration?
    var reviews: ListenerRegistration?
    var profile: ListenerRegistration?
    var auth: AuthStateDidChangeListenerHandle?

    func stop() {
        service?.remove()
        reviews?.remove()
        profile?.remove()
        if let auth { Auth.auth().removeStateDidChangeListener(auth) }
        service = nil
        reviews = nil
        profile = nil
        auth = nil
    }

    deinit { stop() }
}

@MainActor
public final class PPServiceViewerStore: ObservableObject {
    @Published public private(set) var service: ServiceModel?
    @Published public private(set) var snapshot: PPServiceViewerSnapshot?
    @Published public private(set) var owner: UserModel?
    @Published public private(set) var reviews: [PPServiceViewerReviewItem] = []
    @Published public private(set) var isSubmittingReview = false
    @Published public var reviewRating: Int = 0
    @Published var reviewText = ""
    @Published public var bannerMessage: String?
    @Published private var serviceErrorKey: String?
    @Published private(set) var serviceMissing = false
    @Published private(set) var isServiceCached = false
    @Published private(set) var isLoadingService = false
    @Published private(set) var isLoadingOwner = false
    @Published private var ownerErrorKey: String?
    @Published private(set) var ownerContactAllowed = false
    @Published private(set) var isSignedIn = false
    @Published private(set) var isLoadingReviews = false
    @Published private var reviewsErrorKey: String?
    @Published private(set) var isLoadingMoreReviews = false
    @Published private(set) var canLoadMoreReviews = false
    @Published private var reviewErrorKey: String?
    @Published private(set) var reviewSucceeded = false
    @Published private(set) var isLoadingOwnReview = false
    @Published private(set) var hasExistingReview = false
    @Published private(set) var ownReviewChecked = false
    @Published private(set) var reviewerAllowed = false
    @Published private(set) var reviewerChecking = false

    // Kept for existing callers; the new composition uses semantic brand colors.
    @Published public var heroTopColor: UIColor?
    @Published public var heroMiddleColor: UIColor?
    @Published public var heroBottomColor: UIColor?
    @Published public var mainServiceColor: UIColor?
    public var serviceAccentColor: Color { .ppPrimary }

    weak var presentingViewController: UIViewController?
    var onRequestSignIn: (() -> Void)?
    var onContactOpened: (() -> Void)?

    // SDK completion callbacks only hop to the main queue. stop() removes listeners
    // and invalidates generation tokens before stale completions can apply.
    private let lifetime = PPServiceViewerListenerLifetime()
    private var active = false
    private var generation = UUID()
    private var configuredServiceID = ""
    private var actorID: String?
    private var reviewerName = ""
    private var ownReview: PPServiceViewerReviewItem?
    private var latestReviews: [PPServiceViewerReviewItem] = []
    private var olderReviews: [PPServiceViewerReviewItem] = []
    private var legacyReviews: [PPServiceViewerReviewItem] = []
    private var lastReviewDocument: DocumentSnapshot?
    private var ownReviewReadGeneration = UUID()
    private var reviewsReadGeneration = UUID()

    public init(service: ServiceModel? = nil) {
        self.service = service
        configuredServiceID = service?.serviceID ?? ""
        if let service { snapshot = PPServiceViewerSnapshot(service: service) }
    }

    public func configure(with service: ServiceModel) {
        let changed = configuredServiceID != (service.serviceID ?? "")
        let shouldRestart = active
        if changed {
            stop()
            owner = nil
            ownerContactAllowed = false
            ownReviewChecked = false
            reviews = []
            latestReviews = []
            olderReviews = []
            legacyReviews = []
            ownReview = nil
            reviewText = ""
            reviewRating = 0
            hasExistingReview = false
            serviceMissing = false
            lastReviewDocument = nil
        }
        self.service = service
        configuredServiceID = service.serviceID ?? ""
        rebuildSnapshot()
        if changed && shouldRestart { load() }
    }

    public func load() {
        guard !active else { return }
        guard !configuredServiceID.isEmpty else {
            serviceMissing = true
            isLoadingService = false
            return
        }
        active = true
        generation = UUID()
        startServiceListener()
        startReviewsListener()
        lifetime.auth = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                let current = Auth.auth().currentUser
                self.updateActor(current?.isAnonymous == false ? current?.uid : nil)
            }
        }
    }

    public func stop() {
        active = false
        generation = UUID()
        lifetime.stop()
        isLoadingMoreReviews = false
        isLoadingOwnReview = false
        isLoadingOwner = false
        isLoadingReviews = false
        ownReviewReadGeneration = UUID()
        // An in-flight review retains its own completion; it is never replayed here.
    }

    func refresh() {
        stop()
        serviceErrorKey = nil
        reviewsErrorKey = nil
        load()
    }

    func refreshLocalization() {
        rebuildSnapshot()
        // Dates are rendered from createdAt so locale changes do not rewrite data.
    }

    private func rebuildSnapshot() {
        if let service {
            snapshot = PPServiceViewerSnapshot(service: service, owner: owner,
                ownerContactAllowed: ownerContactAllowed)
        }
    }

    private func startServiceListener() {
        isLoadingService = snapshot == nil
        let requestGeneration = generation
        let id = configuredServiceID
        lifetime.service = Firestore.firestore().collection("serviceOffers").document(id)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] document, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.active, self.generation == requestGeneration else { return }
                    self.isLoadingService = false
                    if error != nil {
                        self.serviceErrorKey = "service_note_details_error"
                        return
                    }
                    guard let data = document?.data(), document?.exists == true else {
                        if document?.metadata.isFromCache == true {
                            self.isServiceCached = true
                            self.isLoadingService = self.snapshot == nil
                            return
                        }
                        self.serviceMissing = true
                        self.snapshot = nil
                        self.service = nil
                        return
                    }
                    let previousOwnerID = self.service?.serviceOwnerID
                    self.service = ServiceModel(dictionary: data, documentID: id)
                    self.serviceMissing = false
                    self.serviceErrorKey = nil
                    self.isServiceCached = document?.metadata.isFromCache == true
                    if previousOwnerID != self.service?.serviceOwnerID {
                        self.owner = nil
                        self.isLoadingOwner = false
                        self.ownerContactAllowed = false
                        self.loadOwnerIfNeeded()
                    }
                    self.rebuildSnapshot()
                }
            }
    }

    private func updateActor(_ uid: String?) {
        let previous = actorID
        actorID = uid
        isSignedIn = uid != nil
        if previous != uid {
            lifetime.profile?.remove()
            lifetime.profile = nil
            owner = nil
            isLoadingOwner = false
            ownerContactAllowed = false
            ownReviewChecked = false
            reviewerAllowed = false
            ownReview = nil
            hasExistingReview = false
            reviewerName = ""
            // Preserve a guest's draft through sign-in; never carry a signed-in draft
            // into a different account.
            if previous != nil {
                reviewText = ""
                reviewRating = 0
                reviewErrorKey = nil
                reviewSucceeded = false
            }
            rebuildSnapshot()
        }
        loadOwnerIfNeeded(force: true)
        guard let uid else { reviewerChecking = false; return }
        guard lifetime.profile == nil else { return }
        reviewerChecking = true
        let requestGeneration = generation
        lifetime.profile = Firestore.firestore().collection("UsersCol").document(uid)
            .addSnapshotListener { [weak self] document, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.active, self.generation == requestGeneration,
                          self.actorID == uid, Auth.auth().currentUser?.uid == uid else { return }
                    self.reviewerChecking = false
                    self.reviewerAllowed = error == nil && Self.accountCanReview(document?.data())
                    let data = document?.data() ?? [:]
                    let name = (UserModel(dict: data).bestDisplayName() ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    self.reviewerName = name.isEmpty ? Auth.auth().currentUser?.displayName ?? "" : name
                }
            }
    }

    func retryOwner() { loadOwnerIfNeeded(force: true) }

    private func loadOwnerIfNeeded(force: Bool = false) {
        guard let service, isSignedIn else { return }
        let ownerID = service.serviceOwnerID ?? ""
        guard !ownerID.isEmpty else {
            ownerErrorKey = "service_view_provider_unavailable"
            ownerContactAllowed = false
            rebuildSnapshot()
            return
        }
        guard !isLoadingOwner, force || owner == nil else { return }
        isLoadingOwner = true
        ownerContactAllowed = false
        rebuildSnapshot()
        ownerErrorKey = nil
        let requestGeneration = generation
        let requestingUID = actorID
        Firestore.firestore().collection("UsersCol").document(ownerID).getDocument(source: .server) { [weak self] document, error in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.generation == requestGeneration,
                      self.actorID == requestingUID, Auth.auth().currentUser?.uid == requestingUID,
                      self.service?.serviceOwnerID == ownerID else { return }
                self.isLoadingOwner = false
                guard error == nil, let data = document?.data(), document?.exists == true else {
                    self.ownerErrorKey = "service_view_provider_unavailable"
                    return
                }
                self.owner = UserModel(dict: data)
                self.ownerContactAllowed = Self.accountCanAct(data)
                self.ownerErrorKey = self.ownerContactAllowed ? nil : "service_note_provider_inactive"
                self.rebuildSnapshot()
            }
        }
    }

    func retryReviews() {
        lifetime.reviews?.remove()
        startReviewsListener()
    }

    private func startReviewsListener() {
        isLoadingReviews = reviews.isEmpty
        reviewsErrorKey = nil
        let requestGeneration = generation
        let readGeneration = UUID()
        reviewsReadGeneration = readGeneration
        let ref = Firestore.firestore().collection("serviceOffers").document(configuredServiceID).collection("reviews")
        lifetime.reviews = ref.order(by: "createdAt", descending: true).limit(to: 20)
            .addSnapshotListener { [weak self] result, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.active, self.generation == requestGeneration,
                          self.reviewsReadGeneration == readGeneration else { return }
                    self.isLoadingReviews = false
                    guard error == nil, let documents = result?.documents else {
                        self.reviewsErrorKey = "service_note_reviews_error"
                        return
                    }
                    self.latestReviews = documents.compactMap(Self.reviewItem)
                    if self.olderReviews.isEmpty {
                        self.lastReviewDocument = documents.last
                        self.canLoadMoreReviews = documents.count == 20
                    }
                    self.reviewsErrorKey = nil
                    self.mergeReviews()
                }
            }
        // Preserve older documents written with the former timestamp/text shape.
        // This bounded compatibility read never writes or migrates legacy reviews.
        ref.order(by: "timestamp", descending: true).limit(to: 20).getDocuments { [weak self] result, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.generation == requestGeneration,
                      self.reviewsReadGeneration == readGeneration else { return }
                self.legacyReviews = result?.documents.compactMap(Self.reviewItem) ?? []
                self.mergeReviews()
            }
        }
    }

    func loadMoreReviews() {
        guard active, canLoadMoreReviews, !isLoadingMoreReviews,
              let lastReviewDocument else { return }
        isLoadingMoreReviews = true
        let requestGeneration = generation
        Firestore.firestore().collection("serviceOffers").document(configuredServiceID)
            .collection("reviews").order(by: "createdAt", descending: true)
            .start(afterDocument: lastReviewDocument).limit(to: 20).getDocuments { [weak self] result, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.active, self.generation == requestGeneration else { return }
                    self.isLoadingMoreReviews = false
                    guard error == nil, let documents = result?.documents else {
                        self.reviewsErrorKey = "service_note_reviews_error"
                        return
                    }
                    self.olderReviews += documents.compactMap(Self.reviewItem)
                    self.lastReviewDocument = documents.last ?? self.lastReviewDocument
                    self.canLoadMoreReviews = documents.count == 20
                    self.reviewsErrorKey = nil
                    self.mergeReviews()
                }
            }
    }

    private func mergeReviews() {
        var unique = Dictionary(olderReviews.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for review in legacyReviews + latestReviews { unique[review.id] = review }
        reviews = unique.values.sorted {
            let first = $0.createdAt ?? .distantPast
            let second = $1.createdAt ?? .distantPast
            return first == second ? $0.id < $1.id : first > second
        }
    }

    private static func reviewItem(_ document: DocumentSnapshot) -> PPServiceViewerReviewItem? {
        guard let data = document.data(),
              let value = (data["rating"] as? NSNumber)?.doubleValue,
              value.isFinite, (1...5).contains(value) else { return nil }
        let name = (data["reviewerName"] as? String) ?? (data["userName"] as? String) ?? ""
        let date = (data["createdAt"] as? Timestamp)?.dateValue()
            ?? (data["timestamp"] as? Timestamp)?.dateValue()
        return PPServiceViewerReviewItem(
            id: document.documentID,
            userName: name,
            userAvatarURL: data["userAvatarURL"] as? String,
            rating: Int(value.rounded()),
            text: (data["comment"] as? String) ?? (data["text"] as? String) ?? "",
            date: data["date"] as? String ?? "",
            createdAt: date,
            userID: data["userID"] as? String ?? document.documentID
        )
    }

    func prepareReview() {
        reviewErrorKey = nil
        reviewSucceeded = false
        guard let uid = actorID, !isSubmittingReview, !isLoadingOwnReview else { return }
        isLoadingOwnReview = true
        ownReviewChecked = false
        let readGeneration = UUID()
        ownReviewReadGeneration = readGeneration
        let id = configuredServiceID
        Firestore.firestore().collection("serviceOffers").document(id).collection("reviews")
            .document(uid).getDocument(source: .server) { [weak self] document, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.actorID == uid, Auth.auth().currentUser?.uid == uid,
                          self.configuredServiceID == id, self.ownReviewReadGeneration == readGeneration else { return }
                    self.isLoadingOwnReview = false
                    guard error == nil, let document else {
                        self.reviewErrorKey = "service_note_review_load_error"
                        return
                    }
                    self.ownReview = Self.reviewItem(document)
                    self.ownReviewChecked = true
                    self.hasExistingReview = document.exists
                    if let review = self.ownReview, self.reviewText.isEmpty, self.reviewRating == 0 {
                        self.reviewText = review.text
                        self.reviewRating = review.rating
                    }
                }
            }
    }

    private var reviewAccessMessageKey: String? {
        if !isSignedIn { return "service_note_review_sign_in" }
        if reviewerChecking { return "service_note_review_checking" }
        if service?.serviceOwnerID == actorID { return "service_note_review_own" }
        if snapshot?.isReviewable != true { return "service_note_review_unavailable" }
        if !reviewerAllowed { return "service_review_blocked_account" }
        return nil
    }

    var reviewAccessMessage: String? { reviewAccessMessageKey.map { PPServiceViewerL10n.text($0) } }
    var serviceError: String? { serviceErrorKey.map { PPServiceViewerL10n.text($0) } }
    var ownerError: String? { ownerErrorKey.map { PPServiceViewerL10n.text($0) } }
    var reviewsError: String? { reviewsErrorKey.map { PPServiceViewerL10n.text($0) } }
    var reviewError: String? { reviewErrorKey.map { PPServiceViewerL10n.text($0) } }

    func reviewDraftChanged() {
        if reviewErrorKey == "service_note_review_too_long" && reviewText.utf16.count <= 600 {
            reviewErrorKey = nil
        } else if reviewErrorKey == "service_review_select_rating" && reviewRating > 0 {
            reviewErrorKey = nil
        }
    }

    public func submitReview() {
        guard !isSubmittingReview, !isLoadingOwnReview else { return }
        guard let uid = actorID, uid == Auth.auth().currentUser?.uid,
              Auth.auth().currentUser?.isAnonymous == false else {
            onRequestSignIn?()
            return
        }
        guard ownReviewChecked else {
            reviewErrorKey = "service_note_review_load_error"
            return
        }
        guard reviewAccessMessage == nil else {
            reviewErrorKey = reviewAccessMessageKey
            return
        }
        guard (1...5).contains(reviewRating) else {
            reviewErrorKey = "service_review_select_rating"
            return
        }
        let comment = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard comment.utf16.count <= 600 else {
            reviewErrorKey = "service_note_review_too_long"
            return
        }
        let id = configuredServiceID
        let rating = reviewRating
        var name = ""
        var nameLength = 0
        for scalar in reviewerName.unicodeScalars {
            let length = scalar.value > 0xFFFF ? 2 : 1
            guard nameLength + length <= 120 else { break }
            name.unicodeScalars.append(scalar)
            nameLength += length
        }
        let reviewName = name
        isSubmittingReview = true
        reviewErrorKey = nil
        let serviceRef = Firestore.firestore().collection("serviceOffers").document(id)
        let reviewRef = serviceRef.collection("reviews").document(uid)
        Firestore.firestore().runTransaction({ transaction, errorPointer -> Any? in
            do {
                let liveService = try transaction.getDocument(serviceRef)
                let existingReview = try transaction.getDocument(reviewRef)
                guard let data = liveService.data(),
                      let ownerID = data["serviceOwnerID"] as? String, !ownerID.isEmpty,
                      ownerID != uid,
                      data["isDeleted"] as? Bool != true,
                      data["isBlocked"] as? Bool != true,
                      data["isDisabled"] as? Bool != true else {
                    errorPointer?.pointee = NSError(domain: "PPServiceReview", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: PPServiceViewerL10n.text("service_note_review_unavailable")])
                    return nil
                }
                var payload: [String: Any] = [
                    "reviewID": uid, "serviceID": id, "serviceOwnerID": ownerID,
                    "userID": uid, "rating": rating, "comment": comment,
                    "platform": "ios", "updatedAt": FieldValue.serverTimestamp()
                ]
                payload["createdAt"] = existingReview.data()?["createdAt"] ?? FieldValue.serverTimestamp()
                if !reviewName.isEmpty { payload["reviewerName"] = reviewName }
                transaction.setData(payload, forDocument: reviewRef)
                return true
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] _, error in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isSubmittingReview = false
                guard self.configuredServiceID == id, self.actorID == uid,
                      Auth.auth().currentUser?.uid == uid else { return }
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == "PPServiceReview" {
                        self.reviewErrorKey = "service_note_review_unavailable"
                    } else if nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                        self.reviewErrorKey = "service_note_review_denied"
                    } else {
                        self.reviewErrorKey = "service_note_review_save_error"
                    }
                } else {
                    self.reviewText = ""
                    self.reviewRating = 0
                    self.hasExistingReview = true
                    self.reviewSucceeded = true
                    UIAccessibility.post(notification: .announcement,
                        argument: PPServiceViewerL10n.text("service_note_review_saved"))
                }
            }
        }
    }

    private static func accountCanAct(_ data: [String: Any]?) -> Bool {
        guard let data else { return false }
        // Matches Infra requesterAccountCanAct, including legacy aliases.
        for key in ["status", "accountStatus"] {
            if let value = data[key] {
                guard let status = value as? String, status == "active" else { return false }
            }
        }
        if let accountType = data["accountType"] as? String,
           !["user", "staff"].contains(accountType) { return false }
        for key in ["isBlocked", "blocked", "banned", "deactivated", "isDeleted",
                    "deleted", "isSuspended", "suspended", "isDisabled", "disabled"] {
            if data[key] as? Bool == true { return false }
        }
        return true
    }

    private static func accountCanReview(_ data: [String: Any]?) -> Bool {
        guard accountCanAct(data), let data else { return false }
        let restrictions = data["restrictions"] as? [String: Any] ?? [:]
        return restrictions["postingBlocked"] as? Bool != true
            && data["postingBlocked"] as? Bool != true
    }

    public func callProvider() {
        guard isSignedIn, actorID == Auth.auth().currentUser?.uid,
              Auth.auth().currentUser?.isAnonymous == false else {
            onRequestSignIn?()
            return
        }
        guard let snapshot, snapshot.isLive else {
            bannerMessage = PPServiceViewerL10n.text("service_view_unavailable_banner")
            return
        }
        guard let phone = snapshot.ownerPhone, snapshot.hasContact else {
            bannerMessage = PPServiceViewerL10n.text("service_view_provider_contact_pending")
            return
        }
        let digits = phone.compactMap { character -> String? in
            guard let value = character.wholeNumberValue, (0...9).contains(value) else { return nil }
            return String(value)
        }.joined()
        let prefix = phone.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") ? "+" : ""
        guard !digits.isEmpty, let url = URL(string: "tel:\(prefix)\(digits)") else { return }
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if opened { self.onContactOpened?() }
                else { self.bannerMessage = PPServiceViewerL10n.text("service_note_call_failed") }
            }
        }
    }

    public func shareService(from viewController: UIViewController? = nil) {
        guard let snapshot else { return }
        guard var presenter = viewController ?? presentingViewController else { return }
        while let presented = presenter.presentedViewController {
            if presented.isBeingDismissed { return }
            presenter = presented
        }
        guard presenter.viewIfLoaded?.window != nil else { return }
        let activity = UIActivityViewController(
            activityItems: ["\(snapshot.title)\n\(snapshot.price)"], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 80, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    public func handleImageLoaded(_ image: UIImage) {
        // Image-derived color animation was presentation-only; semantic palette
        // ownership now stays with the Pure Pets design system.
    }
}
