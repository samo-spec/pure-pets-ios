//
//  AdoptPetSwiftUIStore.swift
//  Pure Pets
//
//  Production-ready store and state management for Adopt Pet SwiftUI screens.
//

import Foundation
import SwiftUI
import UIKit
import Combine
import FirebaseFirestore

func PPAdoptLang(_ key: String) -> String {
    let localized = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    return localized.isEmpty ? key : localized
}

// MARK: - Adopt Pet List Store

@MainActor
final class AdoptPetListStore: ObservableObject {
    @Published var pets: [AdoptPetModel] = []
    @Published var filteredPets: [AdoptPetModel] = []
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    @Published var selectedKindID: Int = 0 { // 0 = All
        didSet { applyFilters() }
    }
    @Published var selectedGender: String = "" { // "" = All, "male", "female"
        didSet { applyFilters() }
    }
    @Published var selectedCityID: Int = 0 { // 0 = All
        didSet { applyFilters() }
    }

    @Published var isLoading: Bool = true
    @Published var isRefreshing: Bool = false
    @Published var isOffline: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasReceivedInitialSnapshot: Bool = false

    private var listenerRegistration: ListenerRegistration?

    init() {
        startObserving()
    }

    deinit {
        listenerRegistration?.remove()
    }

    func startObserving() {
        stopObserving()
        isLoading = true
        isOffline = false
        errorMessage = nil

        listenerRegistration = AdoptPetManager.shared().observeAllPets(update: { [weak self] updatedPets, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                self.isRefreshing = false
                self.hasReceivedInitialSnapshot = true

                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain || nsError.code == 14 {
                        self.isOffline = true
                    }
                    self.errorMessage = error.localizedDescription
                    if self.pets.isEmpty {
                        self.pets = []
                        self.filteredPets = []
                    }
                    return
                }

                self.isOffline = false
                self.errorMessage = nil
                self.pets = updatedPets ?? []
                self.applyFilters()
            }
        })
    }

    func stopObserving() {
        listenerRegistration?.remove()
        listenerRegistration = nil
    }

    func refresh() {
        isRefreshing = true
        startObserving()
    }

    func applyFilters() {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        filteredPets = pets.filter { pet in
            // Visibility check: 0 = public
            if pet.visibility != 0 {
                return false
            }

            // Kind/Species filter
            if selectedKindID > 0 && pet.kindID != selectedKindID {
                return false
            }

            // Gender filter
            if !selectedGender.isEmpty {
                let normalizedPetGender = self.normalizeGender(pet.gender)
                if normalizedPetGender != selectedGender {
                    return false
                }
            }

            // City filter
            if selectedCityID > 0 && pet.cityID != selectedCityID {
                return false
            }

            // Search query filter
            if !trimmedQuery.isEmpty {
                let nameMatch = pet.name.lowercased().contains(trimmedQuery)
                let detailsMatch = pet.details.lowercased().contains(trimmedQuery)
                let cityMatch = pet.mCityName.lowercased().contains(trimmedQuery)
                let kindMatch = pet.mainKindModel.kindName.lowercased().contains(trimmedQuery)
                let breedMatch = pet.subKindModel.subKindName.lowercased().contains(trimmedQuery)

                if !(nameMatch || detailsMatch || cityMatch || kindMatch || breedMatch) {
                    return false
                }
            }

            return true
        }
    }

    func clearFilters() {
        searchText = ""
        selectedKindID = 0
        selectedGender = ""
        selectedCityID = 0
        applyFilters()
    }

    private func normalizeGender(_ gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !g.isEmpty else {
            return ""
        }
        if g.contains("female") || g.contains("انث") || g.contains("أنث") || g.contains("بنت") {
            return "female"
        }
        if g.contains("male") || g.contains("ذكر") || g.contains("ولد") {
            return "male"
        }
        return g
    }
}

// MARK: - Adopt Pet Details Store

@MainActor
final class AdoptPetDetailsStore: ObservableObject {
    @Published var pet: AdoptPetModel
    @Published var isOwner: Bool
    @Published var ownerUser: UserModel? = nil
    @Published var isFavorited: Bool = false
    @Published var isLoadingOwner: Bool = true
    @Published var isDeleting: Bool = false
    @Published var isUpdatingVisibility: Bool = false
    @Published var errorMessage: String? = nil

    private let collectionName = "favoritesAdoptPets"

    init(pet: AdoptPetModel, isOwner: Bool = false) {
        self.pet = pet
        let currentUID = UserManager.shared().currentUser?.id ?? ""
        self.isOwner = isOwner || (!pet.ownerID.isEmpty && pet.ownerID == currentUID)
        loadOwnerAndFavoriteState()
    }

    func loadOwnerAndFavoriteState() {
        // Load owner profile
        if let cachedOwner = UserManager.userModel(forID: pet.ownerID) {
            self.ownerUser = cachedOwner
            self.isLoadingOwner = false
        } else if !pet.ownerID.isEmpty {
            self.isLoadingOwner = true
            UserManager.shared().getOtherUserModelFromFirestore(withUID: pet.ownerID) { [weak self] user, _ in
                Task { @MainActor in
                    self?.ownerUser = user
                    self?.isLoadingOwner = false
                }
            }
        } else {
            self.isLoadingOwner = false
        }

        // Check favorite status
        if let currentUID = UserManager.shared().currentUser?.id, !currentUID.isEmpty, !pet.documentID.isEmpty {
            PetAdManager.isAdFavorited(pet.documentID, forUser: currentUID, collection: collectionName) { [weak self] favorited in
                Task { @MainActor in
                    self?.isFavorited = favorited
                }
            }
        }
    }

    func toggleFavorite() {
        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }

        guard !pet.documentID.isEmpty,
              let currentUID = UserManager.shared().currentUser?.id else { return }

        let previousState = isFavorited
        isFavorited = !previousState

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if isFavorited {
            PetAdManager.addFavoriteAd(withID: pet.documentID, collection: collectionName, forUserID: currentUID)
        } else {
            PetAdManager.removeFavoriteAd(withID: pet.documentID, collection: collectionName, forUserID: currentUID)
        }
    }

    func contactOwnerByCall(from viewController: UIViewController?) {
        guard let owner = ownerUser else {
            if !pet.ownerID.isEmpty {
                UserManager.shared().getOtherUserModelFromFirestore(withUID: pet.ownerID) { [weak self] fetchedUser, _ in
                    Task { @MainActor in
                        self?.ownerUser = fetchedUser
                        if let u = fetchedUser {
                            self?.performCall(for: u, from: viewController)
                        }
                    }
                }
            }
            return
        }
        performCall(for: owner, from: viewController)
    }

    private func performCall(for owner: UserModel, from viewController: UIViewController?) {
        guard let mobile = owner.mobileNo, !mobile.isEmpty else {
            if let vc = viewController {
                GM.showAlert(
                    withTitle: PPAdoptLang("No Number"),
                    message: PPAdoptLang("This user has no phone number"),
                    imageName: "exclamationmark.triangle.fill",
                    in: vc
                )
            }
            return
        }
        guard let viewController else { return }
        AppClasses.callPhoneNumber(mobile, from: viewController)
    }

    func contactOwnerByChat(from viewController: UIViewController?) {
        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }

        guard let targetVC = viewController else { return }

        if let owner = ownerUser {
            ChManager.shared().startChat(with: owner, from: targetVC)
        } else if !pet.ownerID.isEmpty {
            UserManager.shared().getOtherUserModelFromFirestore(withUID: pet.ownerID) { [weak self] fetchedUser, _ in
                Task { @MainActor in
                    self?.ownerUser = fetchedUser
                    if let u = fetchedUser {
                        ChManager.shared().startChat(with: u, from: targetVC)
                    }
                }
            }
        }
    }

    func sharePet(from viewController: UIViewController?) {
        guard let vc = viewController else { return }

        let petTitle = pet.name.isEmpty ? PPAdoptLang("AdoptPet") : pet.name
        let detailText = pet.details
        var itemsToShare: [Any] = [petTitle, detailText]

        if let firstURLString = pet.imageURLs.first, let url = URL(string: firstURLString) {
            itemsToShare.append(url)
        }

        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = vc.view
            popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        vc.present(activityVC, animated: true)
    }

    func reportPet(reason: String, completion: @escaping (Bool) -> Void) {
        guard !pet.documentID.isEmpty else {
            completion(false)
            return
        }

        let reporterUID = UserManager.shared().currentUser?.id ?? "anonymous"
        let reportData: [String: Any] = [
            "targetID": pet.documentID,
            "targetType": "adopt_pet",
            "reason": reason,
            "reporterID": reporterUID,
            "createdAt": FieldValue.serverTimestamp()
        ]

        Firestore.firestore().collection("reports").addDocument(data: reportData) { error in
            completion(error == nil)
        }
    }

    func togglePetVisibility(completion: @escaping (Bool) -> Void) {
        guard !pet.documentID.isEmpty else {
            completion(false)
            return
        }

        let newVisibility = pet.visibility == 0 ? 1 : 0
        isUpdatingVisibility = true

        AdoptPetManager.shared().updatePetVisibility(withID: pet.documentID, visibility: newVisibility) { [weak self] success, error in
            Task { @MainActor in
                self?.isUpdatingVisibility = false
                if success {
                    self?.pet.visibility = newVisibility
                }
                completion(success)
            }
        }
    }

    func deletePet(completion: @escaping (Bool) -> Void) {
        guard !pet.documentID.isEmpty else {
            completion(false)
            return
        }

        isDeleting = true
        AdoptPetManager.shared().deletePet(withID: pet.documentID) { [weak self] success, _ in
            Task { @MainActor in
                self?.isDeleting = false
                completion(success)
            }
        }
    }
}
