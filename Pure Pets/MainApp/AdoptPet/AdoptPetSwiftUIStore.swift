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
import FirebaseFunctions

func PPAdoptLang(_ key: String) -> String {
    let localized = Language.get(key, alter: key) ?? key
    return localized.isEmpty ? key : localized
}

/// Normalizes legacy English/Arabic gender values before presenting them.
/// The Firestore model remains unchanged; this only prevents a stored key such
/// as "male" from leaking into an Arabic interface.
func PPAdoptGenderLabel(_ rawValue: String?) -> String {
    let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !raw.isEmpty else { return "" }

    let normalized = raw.lowercased()
    if normalized.contains("female") || normalized.contains("انث") || normalized.contains("أنث") || normalized.contains("بنت") {
        return PPAdoptLang("Female")
    }
    if normalized.contains("male") || normalized.contains("ذكر") || normalized.contains("ولد") {
        return PPAdoptLang("Male")
    }
    return raw
}

// MARK: - Adopt Pet List Store

@MainActor
final class AdoptPetListStore: ObservableObject {
    @Published var pets: [AdoptPetModel] = []
    @Published var filteredPets: [AdoptPetModel] = []
    @Published var searchText: String = "" {
        didSet { filterDidChange() }
    }
    @Published var selectedKindID: Int = 0 { // 0 = All
        didSet { filterDidChange() }
    }
    @Published var selectedGender: String = "" { // "" = All, "male", "female"
        didSet { filterDidChange() }
    }
    @Published var selectedCityID: Int = 0 { // 0 = All
        didSet { filterDidChange() }
    }

    @Published var isLoading: Bool = true
    @Published var isRefreshing: Bool = false
    @Published var isOffline: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasReceivedInitialSnapshot: Bool = false
    @Published var hasMore: Bool = false
    @Published var isLoadingMore: Bool = false

    private var observationGeneration = 0
    private var nextCursor: String?
    private var loadTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    private var isClearingFilters = false

    init() {
        startObserving()
    }

    deinit {
        loadTask?.cancel()
        filterTask?.cancel()
    }

    func startObserving() {
        guard loadTask == nil else { return }
        loadTask = Task { @MainActor [weak self] in
            await self?.loadPage(reset: true)
            self?.loadTask = nil
        }
    }

    func stopObserving() {
        observationGeneration += 1
        loadTask?.cancel()
        loadTask = nil
        filterTask?.cancel()
        filterTask = nil
        isRefreshing = false
        isLoadingMore = false
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        await loadPage(reset: true)
        isRefreshing = false
    }

    func requestRefresh() {
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }

    var hasStaleConnectionIssue: Bool {
        !pets.isEmpty && (isOffline || errorMessage != nil)
    }

    /// Retained for existing screen call sites. Filtering is authoritative on
    /// the Community read callable, so this schedules a fresh ranked page.
    func applyFilters() {
        filterDidChange()
    }

    func clearFilters() {
        isClearingFilters = true
        searchText = ""
        selectedKindID = 0
        selectedGender = ""
        selectedCityID = 0
        isClearingFilters = false
        scheduleFilterReload(delayNanoseconds: 0)
    }

    func loadNextIfNeeded(current pet: AdoptPetModel) {
        guard hasMore, !isLoadingMore, filteredPets.suffix(4).contains(where: { $0.documentID == pet.documentID }) else { return }
        Task { @MainActor [weak self] in await self?.loadPage(reset: false) }
    }

    private func filterDidChange() {
        guard !isClearingFilters else { return }
        scheduleFilterReload(delayNanoseconds: 300_000_000)
    }

    private func scheduleFilterReload(delayNanoseconds: UInt64) {
        filterTask?.cancel()
        filterTask = Task { @MainActor [weak self] in
            if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
            guard !Task.isCancelled else { return }
            await self?.loadPage(reset: true)
            self?.filterTask = nil
        }
    }

    private func loadPage(reset: Bool) async {
        if reset {
            observationGeneration += 1
            nextCursor = nil
            hasMore = false
            if pets.isEmpty { isLoading = true }
        } else {
            guard hasMore, nextCursor != nil, !isLoadingMore else { return }
            isLoadingMore = true
        }
        let generation = observationGeneration
        errorMessage = nil
        isOffline = false
        defer {
            if reset { isLoading = false }
            else { isLoadingMore = false }
        }

        do {
            var filters: [String: Any] = [:]
            if selectedKindID > 0 { filters["categoryId"] = selectedKindID }
            if !selectedGender.isEmpty { filters["gender"] = selectedGender }
            if selectedCityID > 0 { filters["cityId"] = selectedCityID }
            let page = try await PPCommunityService.shared.browseAdoption(
                query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                filters: filters,
                cursor: reset ? nil : nextCursor,
                limit: 24
            )
            guard generation == observationGeneration, !Task.isCancelled else { return }
            let models = page.items.compactMap { item -> AdoptPetModel? in
                let identifier = item["id"] as? String ?? ""
                guard !identifier.isEmpty else { return nil }
                return AdoptPetModel(dictionary: item, documentID: identifier)
            }
            if reset {
                pets = models
            } else {
                var seen = Set(pets.map(\.documentID))
                pets.append(contentsOf: models.filter { seen.insert($0.documentID).inserted })
            }
            filteredPets = pets
            nextCursor = page.nextCursor
            hasMore = page.hasMore && page.nextCursor != nil
            hasReceivedInitialSnapshot = true
        } catch {
            guard generation == observationGeneration, !Task.isCancelled else { return }
            let nsError = error as NSError
            isOffline = nsError.domain == NSURLErrorDomain || nsError.code == 14
            errorMessage = error.localizedDescription
            if reset && pets.isEmpty { filteredPets = [] }
        }
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
    @Published var isReporting: Bool = false
    @Published var errorMessage: String? = nil
    @Published private(set) var applicationsEnabled: Bool = false

    private let collectionName = "favoritesAdoptPets"

    init(pet: AdoptPetModel, isOwner: Bool = false) {
        self.pet = pet
        let currentUID = UserManager.shared().currentUser?.id ?? ""
        self.isOwner = isOwner || (!pet.ownerID.isEmpty && pet.ownerID == currentUID)
        loadOwnerAndFavoriteState()
    }

    func loadOwnerAndFavoriteState() {
        // Community listings expose a bounded public owner snapshot. Do not
        // fetch the full user record or private contact data for discovery.
        ownerUser = nil
        isLoadingOwner = false
        Task { @MainActor [weak self] in
            do {
                let configuration = try await PPCommunityService.shared.configuration()
                self?.applicationsEnabled = configuration.communityEnabled && configuration.adoptionEnabled && configuration.adoptionApplicationsEnabled
            } catch {
                self?.applicationsEnabled = false
            }
        }
        guard UserManager.shared().isUserLoggedIn(), !pet.documentID.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let saved = try await PPCommunityService.shared.savedItems()
                self.isFavorited = saved.contains {
                    communitySavedTargetID($0) == self.pet.documentID &&
                    (($0["targetType"] as? String) == "adoption_listing")
                }
            } catch {
                // A saved-state refresh is non-critical; the explicit save
                // action still reports a server error if the user invokes it.
            }
        }
    }

    var isOwnerContactUnavailable: Bool {
        !isLoadingOwner && ownerUser == nil
    }

    var canCallOwner: Bool {
        false
    }

    var canChatOwner: Bool {
        false
    }

    var isApplicationAvailable: Bool {
        !isOwner && applicationsEnabled && pet.status == "published"
    }

    func retryOwnerLoading() {
        loadOwnerAndFavoriteState()
    }

    func toggleFavorite() {
        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }

        guard !pet.documentID.isEmpty else { return }

        let previousState = isFavorited
        isFavorited = !previousState

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                self.isFavorited = try await PPCommunityService.shared.setSaved(
                    self.isFavorited,
                    targetType: "adoption_listing",
                    targetID: self.pet.documentID
                )
            } catch {
                self.isFavorited = previousState
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func contactOwnerByCall(from viewController: UIViewController?) {
        // Retained for compatibility with legacy callers. Public Community
        // discovery never exposes or invokes direct phone contact.
        presentContactUnavailable(from: viewController)
    }

    func contactOwnerByChat(from viewController: UIViewController?) {
        // Messaging is unlocked only from a server-authorized adoption
        // application, sighting, or match context.
        presentContactUnavailable(from: viewController)
    }

    private func presentContactUnavailable(from viewController: UIViewController?) {
        guard let viewController else { return }
        GM.showAlert(
            withTitle: PPAdoptLang("adopt_detail_contact_unavailable"),
            message: PPAdoptLang("adopt_detail_contact_unavailable_message"),
            imageName: "exclamationmark.triangle.fill",
            in: viewController
        )
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

    func reportPet(reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isReporting else {
            completion(.failure(reportError(code: 409)))
            return
        }

        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            completion(.failure(reportError(code: 401)))
            return
        }

        guard !isOwner, !pet.documentID.isEmpty else {
            completion(.failure(reportError(code: 400)))
            return
        }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else {
            completion(.failure(reportError(code: 422)))
            return
        }

        // Reports are server-owned. The callable derives the reporter and
        // owner from authenticated/authoritative records, retains the original
        // case timestamps, and treats a repeat submission as idempotent.
        isReporting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await PPCommunityService.shared.report(
                    targetType: "adoption_listing",
                    targetID: self.pet.documentID,
                    reason: "incorrect_information",
                    details: trimmedReason
                )
                self.isReporting = false
                completion(.success(()))
            } catch {
                self.isReporting = false
                completion(.failure(error))
            }
        }
    }

    func presentApplication(from viewController: UIViewController?) {
        guard !isOwner else { return }
        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }
        guard isApplicationAvailable else {
            errorMessage = PPAdoptLang("community_application_unavailable")
            return
        }
        let presenter = viewController ?? AppManager.sharedInstance().topViewController()
        let controller = PPAdoptionApplicationHostingController(listing: pet)
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        presenter.present(controller, animated: true)
    }

    private func reportError(code: Int) -> NSError {
        NSError(
            domain: "AdoptPetDetailsStore.Report",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: PPAdoptLang("adopt_detail_report_failed_message")]
        )
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

private func communitySavedTargetID(_ wrapper: [String: Any]) -> String {
    let item = wrapper["item"] as? [String: Any]
    return (item?["id"] as? String) ?? ""
}
