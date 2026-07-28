import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
public final class PPServiceViewerStore: ObservableObject {
    @Published public var service: ServiceModel?
    @Published public var snapshot: PPServiceViewerSnapshot?
    @Published public var owner: UserModel?
    @Published public var reviews: [PPServiceViewerReviewItem] = []
    @Published public var isSubmittingReview = false
    @Published public var reviewRating: Int = 5
    @Published var reviewText: String = ""
    @Published public var bannerMessage: String? = nil

    private var reviewsListener: ListenerRegistration?

    public init(service: ServiceModel? = nil) {
        self.service = service
        if let service {
            self.snapshot = PPServiceViewerSnapshot(service: service)
        }
    }

    deinit {
        reviewsListener?.remove()
    }

    public func configure(with service: ServiceModel) {
        self.service = service
        self.snapshot = PPServiceViewerSnapshot(service: service, owner: owner)
        loadOwnerIfNeeded()
        listenToReviews()
    }

    public func load() {
        guard let service else { return }
        self.snapshot = PPServiceViewerSnapshot(service: service, owner: owner)
        loadOwnerIfNeeded()
        listenToReviews()
    }

    private func loadOwnerIfNeeded() {
        guard let service else { return }
        let ownerID = service.serviceOwnerID ?? ""
        guard !ownerID.isEmpty else { return }
        
        let db = Firestore.firestore()
        db.collection("UsersCol").document(ownerID).getDocument { [weak self] snapshot, error in
            guard let self, let data = snapshot?.data(), snapshot?.exists == true else { return }
            let user = UserModel(dict: data)
            Task { @MainActor in
                self.owner = user
                if let service = self.service {
                    self.snapshot = PPServiceViewerSnapshot(service: service, owner: user)
                }
            }
        }
    }

    private func listenToReviews() {
        reviewsListener?.remove()
        guard let serviceID = service?.serviceID, !serviceID.isEmpty else { return }

        let db = Firestore.firestore()
        reviewsListener = db.collection("serviceOffers")
            .document(serviceID)
            .collection("reviews")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self, let documents = querySnapshot?.documents else { return }
                let items = documents.compactMap { doc -> PPServiceViewerReviewItem? in
                    let data = doc.data()
                    let userName = (data["userName"] as? String) ?? "User"
                    let userAvatarURL = data["userAvatarURL"] as? String
                    let rating = (data["rating"] as? Int) ?? 5
                    let text = (data["text"] as? String) ?? ""
                    let dateStr = (data["date"] as? String) ?? ""
                    return PPServiceViewerReviewItem(
                        id: doc.documentID,
                        userName: userName,
                        userAvatarURL: userAvatarURL,
                        rating: rating,
                        text: text,
                        date: dateStr
                    )
                }
                Task { @MainActor in
                    self.reviews = items
                }
            }
    }

    public func submitReview() {
        guard let serviceID = service?.serviceID, !serviceID.isEmpty else { return }
        let trimmedText = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            bannerMessage = PPServiceViewerL10n.text("please_enter_review", fallback: "Please enter your review text.")
            return
        }

        isSubmittingReview = true
        let authUser = Auth.auth().currentUser
        let currentUID = authUser?.uid ?? "guest"
        let currentUserName = authUser?.displayName ?? "User"
        let currentUserAvatar = authUser?.photoURL?.absoluteString ?? ""

        let docData: [String: Any] = [
            "userID": currentUID,
            "userName": currentUserName,
            "userAvatarURL": currentUserAvatar,
            "rating": reviewRating,
            "text": trimmedText,
            "timestamp": FieldValue.serverTimestamp(),
            "date": DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        ]

        let db = Firestore.firestore()
        db.collection("serviceOffers")
            .document(serviceID)
            .collection("reviews")
            .addDocument(data: docData) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isSubmittingReview = false
                    if let error {
                        self.bannerMessage = error.localizedDescription
                    } else {
                        self.reviewText = ""
                        self.reviewRating = 5
                        self.bannerMessage = PPServiceViewerL10n.text("review_submitted_success", fallback: "Thank you! Your review has been submitted.")
                    }
                }
            }
    }

    public func callProvider() {
        guard let phone = snapshot?.ownerPhone, !phone.isEmpty else { return }
        let cleanPhone = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let url = URL(string: "tel://\(cleanPhone)") {
            UIApplication.shared.open(url)
        }
    }

    public func shareService(from viewController: UIViewController? = nil) {
        guard let snapshot else { return }
        let text = "\(snapshot.title)\n\(snapshot.price)"
        let items: [Any] = [text]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        presenter?.present(activityVC, animated: true)
    }

    private func windowSessionUID() -> String? {
        Auth.auth().currentUser?.uid
    }
}
