//
//  AddAdoptPetScreen.swift
//  Pure Pets
//
//  Category-defining Pet Adoption Intake Studio.
//  First-Principles Redesign: Dedicated iPhone and iPad architectures,
//  exclusive Beiruti brand typography (100% Beiruti only), 6-state resilience,
//  live real-time preview cockpit on iPad, thumb-zone ergonomics on iPhone,
//  and full-screen modal presentation.
//

import SwiftUI
import UIKit
import PhotosUI
import Combine

// MARK: - Model Localization & Icon Helpers

extension MainKindsModel {
    var localizedName: String {
        let isRTL = Language.isRTL()
        let primary = isRTL ? (kindNameAr ?? kindName ?? "") : (kindNameEn ?? kindName ?? "")
        let fallback = isRTL ? (kindNameEn ?? kindName ?? "") : (kindNameAr ?? kindName ?? "")
        let result = primary.isEmpty ? (fallback.isEmpty ? (kindName ?? "") : fallback) : primary
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension SubKindModel {
    var localizedName: String {
        let isRTL = Language.isRTL()
        let primary = isRTL ? (subKindNameAr ?? subKindName ?? "") : (subKindNameEn ?? subKindName ?? "")
        let fallback = isRTL ? (subKindNameEn ?? subKindName ?? "") : (subKindNameAr ?? subKindName ?? "")
        let result = primary.isEmpty ? (fallback.isEmpty ? (subKindName ?? "") : fallback) : primary
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CityModel {
    var localizedName: String {
        let isRTL = Language.isRTL()
        let primary = isRTL ? (arName ?? name ?? "") : (enName ?? name ?? "")
        let fallback = isRTL ? (enName ?? name ?? "") : (arName ?? name ?? "")
        let result = primary.isEmpty ? (fallback.isEmpty ? (name ?? "") : fallback) : primary
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension StateModel {
    var localizedName: String {
        let isRTL = Language.isRTL()
        let primary = isRTL ? (arName ?? "") : (enName ?? "")
        let fallback = isRTL ? (enName ?? "") : (arName ?? "")
        return primary.isEmpty ? fallback : primary
    }
}

private func PPKindIcon(for name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("قطط") || lower.contains("cat") { return "cat.fill" }
    if lower.contains("كلاب") || lower.contains("dog") { return "dog.fill" }
    if lower.contains("طيور") || lower.contains("bird") { return "bird.fill" }
    if lower.contains("أرانب") || lower.contains("rabbit") { return "hare.fill" }
    if lower.contains("أسماك") || lower.contains("fish") { return "fish.fill" }
    return "pawprint.fill"
}

private func PPKindIcon(for kind: MainKindsModel?) -> String {
    guard let kind else { return "pawprint.fill" }
    return PPKindIcon(for: kind.kindNameAr ?? kind.kindName ?? kind.localizedName)
}

// MARK: - Exclusive Typography Engine (100% Beiruti Only)

private enum AdoptFont {
    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: style)
    }

    static func black(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Black", size: size, relativeTo: style)
    }
}

// MARK: - Tactile Haptics Engine

private enum AdoptHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impactLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func impactMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Press Button Style

private struct AdoptPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed || !isEnabled ? 1 : pressedScale)
            .opacity(!isEnabled ? 0.48 : (configuration.isPressed ? 0.88 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Media Item Model

struct AdoptMediaItem: Identifiable, Equatable {
    let id: String
    var image: UIImage?
    var remoteURL: String?
    var assetID: String? = nil
    var videoURL: URL?
    var isVideo: Bool = false

    static func == (lhs: AdoptMediaItem, rhs: AdoptMediaItem) -> Bool {
        lhs.id == rhs.id && lhs.remoteURL == rhs.remoteURL && lhs.assetID == rhs.assetID && lhs.isVideo == rhs.isVideo
    }
}

// MARK: - Store & View Model

@MainActor
final class AddAdoptPetStore: ObservableObject {
    // Form Inputs
    @Published var name: String = "" {
        didSet { onFieldModified() }
    }
    @Published var selectedKind: MainKindsModel? = nil {
        didSet {
            selectedBreed = nil
            onFieldModified()
        }
    }
    @Published var selectedBreed: SubKindModel? = nil {
        didSet { onFieldModified() }
    }
    @Published var ageMonths: Int = 3 {
        didSet { onFieldModified() }
    }
    @Published var selectedGender: String = "" { // "Male" or "Female"
        didSet { onFieldModified() }
    }
    @Published var selectedCity: CityModel? = nil {
        didSet {
            selectedArea = nil
            onFieldModified()
        }
    }
    @Published var selectedArea: StateModel? = nil {
        didSet { onFieldModified() }
    }
    @Published var details: String = "" {
        didSet { onFieldModified() }
    }
    @Published var adoptionReason: String = "" {
        didSet { onFieldModified() }
    }

    // Media
    @Published var mediaItems: [AdoptMediaItem] = [] {
        didSet { onFieldModified() }
    }

    // Available Data
    @Published var availableKinds: [MainKindsModel] = []
    @Published var availableCities: [CityModel] = []
    private var cancellables = Set<AnyCancellable>()

    // 6-State Status
    @Published var isSubmitting: Bool = false
    @Published var submissionStepText: String = ""
    @Published var errorMessage: String? = nil
    @Published var isCommunityAdoptionActive: Bool = true
    @Published var communityNotice: String? = nil
    @Published var hasSavedDraft: Bool = false
    @Published var showDraftRestoredBanner: Bool = false
    @Published var showValidationShake: Bool = false
    @Published var showUnsavedChangesDialog: Bool = false

    // Metadata
    let editingPet: AdoptPetModel?
    var isEditing: Bool { editingPet != nil }
    private var hasUserModifiedForm: Bool = false
    private var isHydrating: Bool = false
    // A create command must retain the same aggregate identity across an
    // uncertain response or relaunch. The callable's command ledger can only
    // deduplicate a request when the client preserves this value.
    private var creationListingID: String = ""
    // Once a submission reaches the server boundary, preserve the complete
    // normalized payload as well as its listing identity. Reconstructing it
    // from editable fields after an unknown response changes the callable
    // fingerprint and can turn a safe retry into a duplicate command.
    private var lockedSubmissionPayload: [String: Any]?
    // Freeze the owner at presentation time. Reading UserManager dynamically
    // for a persisted draft lets an already-visible form follow a later
    // logout/account switch and cross an account boundary on the same device.
    private let draftOwnerUID: String
    private let draftPersistenceEnabled: Bool

    // Persistence Keys
    private let draftPrefix = "pp.add_adopt_pet.draft"
    private var draftDefaultsKey: String {
        if let editingDocID = editingPet?.documentID, !editingDocID.isEmpty {
            return "\(draftPrefix).edit.\(editingDocID).\(draftOwnerUID)"
        }
        return "\(draftPrefix).create.\(draftOwnerUID)"
    }

    private var creationIdentityDefaultsKey: String {
        return "\(draftPrefix).create-identity.\(draftOwnerUID)"
    }

    // Draft media must be scoped to the same account/form identity as the
    // UserDefaults payload. A shared `draft_0.jpg` path could otherwise let a
    // second account on the same device overwrite—or later see—the first
    // account's unfinished local media.
    private var draftMediaDirectoryURL: URL {
        let scope = Data(draftDefaultsKey.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("AdoptPetDrafts", isDirectory: true)
            .appendingPathComponent(scope, isDirectory: true)
    }

    private func isOwnedDraftMediaPath(_ rawPath: String) -> Bool {
        guard rawPath.hasPrefix("/") else { return false }
        let fileURL = URL(fileURLWithPath: rawPath).standardizedFileURL
        let directoryPath = draftMediaDirectoryURL.standardizedFileURL.path + "/"
        return fileURL.path.hasPrefix(directoryPath)
    }

    private func removeOwnedDraftMedia() {
        // The target is a deterministic child of the application's temporary
        // directory and contains only this account/form's cache namespace.
        try? FileManager.default.removeItem(at: draftMediaDirectoryURL)
    }

    init(pet: AdoptPetModel? = nil) {
        self.editingPet = pet
        let currentUID = (UserManager.shared().currentUser?.id ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A guest may still view this form, but its local media/draft payload
        // must not be written under a device-wide "guest" namespace.
        self.draftOwnerUID = currentUID.isEmpty ? UUID().uuidString.lowercased() : currentUID
        self.draftPersistenceEnabled = !currentUID.isEmpty
        if let existingID = pet?.documentID, !existingID.isEmpty {
            self.creationListingID = existingID
        } else if draftPersistenceEnabled {
            let persisted = UserDefaults.standard.string(forKey: creationIdentityDefaultsKey)
            self.creationListingID = (persisted?.isEmpty == false ? persisted : nil) ?? UUID().uuidString.lowercased()
            UserDefaults.standard.set(self.creationListingID, forKey: creationIdentityDefaultsKey)
        } else {
            self.creationListingID = UUID().uuidString.lowercased()
        }
        NotificationCenter.default.publisher(for: NSNotification.Name("CitiesManagerDidUpdateNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCities()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("MainKindsUpdatedNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshKinds()
            }
            .store(in: &cancellables)

        loadDomainData()
        if pet != nil {
            hydrateFromEditingPet()
        }
        // Edit drafts use an account-and-listing-scoped key, so restoring one
        // after the live model hydration is safe and lets an uncertain update
        // retry the exact same versioned payload after an app relaunch.
        checkAndRestoreDraft()
        checkCommunityConfiguration()
    }

    // MARK: - Community Feature Preflight

    func checkCommunityConfiguration() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let config = try await PPCommunityService.shared.configuration()
                if !config.communityEnabled || !config.adoptionEnabled {
                    self.isCommunityAdoptionActive = false
                    self.communityNotice = PPAdoptLang("community_error_feature_unavailable")
                } else if !config.rolloutAvailable {
                    // Advisory notice: rollout stage is constrained, but allow drafting and server evaluation
                    self.isCommunityAdoptionActive = true
                    self.communityNotice = PPAdoptLang("community_unavailable_message")
                } else {
                    self.isCommunityAdoptionActive = true
                    self.communityNotice = nil
                }
            } catch {
                // Keep resilient default state during offline drafting
                self.isCommunityAdoptionActive = true
                self.communityNotice = nil
            }
        }
    }

    // MARK: - Domain Data

    func loadDomainData() {
        refreshKinds()
        refreshCities()
        if availableCities.isEmpty {
            CitiesManager.shared().loadData()
        }
    }

    func refreshKinds() {
        let kinds = (MainKindsArrayManager.shared().visibleMainKindsSnapshot() as? [MainKindsModel])
            ?? (MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel])
            ?? []
        self.availableKinds = kinds
    }

    func refreshCities() {
        let cities = (CitiesManager.shared().citiesForCurrentCountry() as? [CityModel])
            ?? (CitiesManager.shared().qatarCountry()?.cities as? [CityModel])
            ?? []
        self.availableCities = cities
    }

    var availableBreeds: [SubKindModel] {
        guard let kind = selectedKind else { return [] }
        let fromKind = (kind.subKindsArray as? [SubKindModel]) ?? []
        if !fromKind.isEmpty { return fromKind }
        return (MainKindsArrayManager.shared().getSubKindArray(kind.id) as? [SubKindModel]) ?? []
    }

    var availableAreas: [StateModel] {
        guard let city = selectedCity else { return [] }
        return (city.states as? [StateModel]) ?? []
    }

    // MARK: - Hydration

    private func hydrateFromEditingPet() {
        guard let pet = editingPet else { return }
        isHydrating = true

        self.name = pet.name ?? ""
        self.ageMonths = max(1, pet.ageMonths)
        self.details = pet.details ?? ""
        self.adoptionReason = pet.adoptionReason ?? ""

        // Normalize Gender
        let rawGender = (pet.gender ?? "").lowercased()
        if rawGender.contains("female") || rawGender.contains("انث") || rawGender.contains("أنث") {
            self.selectedGender = "Female"
        } else if rawGender.contains("male") || rawGender.contains("ذكر") {
            self.selectedGender = "Male"
        } else {
            self.selectedGender = pet.gender ?? ""
        }

        // Find Species
        if let match = availableKinds.first(where: { $0.id == pet.kindID }) {
            self.selectedKind = match
            if let breedMatch = (match.subKindsArray as? [SubKindModel])?.first(where: { $0.id == pet.breedID }) {
                self.selectedBreed = breedMatch
            }
        }

        // Find City & Area
        if let cityMatch = availableCities.first(where: { $0.cityID == pet.cityID }) {
            self.selectedCity = cityMatch
        } else if pet.cityID > 0 {
            self.selectedCity = CitiesManager.shared().city(byID: pet.cityID)
        }
        if let city = selectedCity, let states = city.states as? [StateModel] {
            let loc = pet.locationDisplayName ?? ""
            if let match = states.first(where: { loc.contains($0.arName ?? "") || loc.contains($0.enName ?? "") }) {
                self.selectedArea = match
            }
        }

        // Existing Images
        var items: [AdoptMediaItem] = []
        for (idx, urlStr) in pet.imageURLs.enumerated() {
            var isVid = false
            if let meta = pet.imageMeta, idx < meta.count,
               let type = meta[idx]["type"] as? String, type.contains("video") {
                isVid = true
            }
            let assetID = pet.mediaAssetIDs.indices.contains(idx) ? pet.mediaAssetIDs[idx] : nil
            items.append(AdoptMediaItem(id: "remote_\(idx)", remoteURL: urlStr, assetID: assetID, isVideo: isVid))
        }
        self.mediaItems = items

        isHydrating = false
        hasUserModifiedForm = false
    }

    // MARK: - Draft Engine

    private func checkAndRestoreDraft() {
        guard draftPersistenceEnabled,
              let data = UserDefaults.standard.dictionary(forKey: draftDefaultsKey) else {
            hasSavedDraft = false
            return
        }

        hasSavedDraft = true
        isHydrating = true

        if let n = data["name"] as? String { self.name = n }
        if let a = data["age"] as? Int, a > 0 { self.ageMonths = a }
        if let g = data["gender"] as? String { self.selectedGender = g }
        if let d = data["details"] as? String { self.details = d }
        if let reason = data["adoptionReason"] as? String { self.adoptionReason = reason }
        if !isEditing, let listingID = data["creationListingID"] as? String, !listingID.isEmpty {
            self.creationListingID = listingID
            UserDefaults.standard.set(listingID, forKey: creationIdentityDefaultsKey)
        }

        if let kID = data["kindID"] as? Int,
           let kind = availableKinds.first(where: { $0.id == kID }) {
            self.selectedKind = kind
            if let bID = data["breedID"] as? Int,
               let breed = (kind.subKindsArray as? [SubKindModel])?.first(where: { $0.id == bID }) {
                self.selectedBreed = breed
            }
        }

        if let cID = data["cityID"] as? Int,
           let city = availableCities.first(where: { $0.cityID == cID }) {
            self.selectedCity = city
            if let aID = data["areaID"] as? Int,
               let area = (city.states as? [StateModel])?.first(where: { $0.stateID == aID }) {
                self.selectedArea = area
            }
        }

        // New drafts retain the complete media order and every finalized
        // server asset identity. That lets an interrupted create retry its
        // original immutable media payload, including a video whose local
        // picker URL is no longer available after relaunch.
        if let manifest = data["mediaManifest"] as? [[String: Any]] {
            let restoredItems = manifest.prefix(8).compactMap { entry -> AdoptMediaItem? in
                let assetID = (entry["assetID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let remoteURL = (entry["remoteURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let isVideo = entry["isVideo"] as? Bool ?? false
                let image: UIImage?
                if let path = entry["imagePath"] as? String,
                   self.isOwnedDraftMediaPath(path),
                   FileManager.default.fileExists(atPath: path) {
                    image = UIImage(contentsOfFile: path)
                } else {
                    image = nil
                }

                let hasAsset = !(assetID ?? "").isEmpty
                let hasRemoteURL = !(remoteURL ?? "").isEmpty
                // Unprocessed videos cannot safely survive a picker session:
                // retaining only their thumbnail would accidentally upload an
                // image in place of the original video on retry.
                guard image != nil || hasAsset || hasRemoteURL,
                      !(isVideo && !hasAsset && !hasRemoteURL) else {
                    return nil
                }
                let storedID = (entry["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let itemID = (storedID?.isEmpty == false ? storedID : nil) ?? UUID().uuidString
                return AdoptMediaItem(
                    id: itemID,
                    image: image,
                    remoteURL: hasRemoteURL ? remoteURL : nil,
                    assetID: hasAsset ? assetID : nil,
                    isVideo: isVideo
                )
            }
            if !restoredItems.isEmpty {
                self.mediaItems = restoredItems
            }
        } else if let paths = data["imagePaths"] as? [String] {
            // Compatibility for drafts saved before the complete media
            // manifest was introduced.
            let assetIDs = data["imageAssetIDs"] as? [String] ?? []
            var restoredItems: [AdoptMediaItem] = []
            for (index, path) in paths.enumerated() {
                if isOwnedDraftMediaPath(path),
                   FileManager.default.fileExists(atPath: path),
                   let img = UIImage(contentsOfFile: path) {
                    let savedAssetID = assetIDs.indices.contains(index) ? assetIDs[index] : ""
                    let assetID = savedAssetID.isEmpty ? nil : savedAssetID
                    restoredItems.append(AdoptMediaItem(id: UUID().uuidString, image: img, assetID: assetID))
                }
            }
            if !restoredItems.isEmpty {
                self.mediaItems = restoredItems
            }
        }

        if let lockedPayload = data["lockedSubmissionPayload"] as? [String: Any],
           JSONSerialization.isValidJSONObject(lockedPayload) {
            self.lockedSubmissionPayload = lockedPayload
        }

        isHydrating = false
        hasUserModifiedForm = false
        showDraftRestoredBanner = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.showDraftRestoredBanner = false
            }
        }
    }

    func saveDraft() {
        persistDraft(showSuccessFeedback: true)
    }

    private func persistDraft(
        showSuccessFeedback: Bool,
        submissionPayload: [String: Any]? = nil
    ) {
        guard draftPersistenceEnabled else { return }
        if let submissionPayload,
           JSONSerialization.isValidJSONObject(submissionPayload) {
            lockedSubmissionPayload = submissionPayload
        }
        var dict: [String: Any] = [
            "name": name,
            "age": ageMonths,
            "gender": selectedGender,
            "details": details,
            "adoptionReason": adoptionReason,
            "creationListingID": creationListingID,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let k = selectedKind { dict["kindID"] = k.id }
        if let b = selectedBreed { dict["breedID"] = b.id }
        if let c = selectedCity { dict["cityID"] = c.cityID }
        if let a = selectedArea { dict["areaID"] = a.stateID }

        // Cache local images
        let tempDirectory = draftMediaDirectoryURL
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        var imagePaths: [String] = []
        var imageAssetIDs: [String] = []
        var mediaManifest: [[String: Any]] = []
        for (idx, item) in mediaItems.enumerated() {
            var entry: [String: Any] = [
                "id": item.id,
                "assetID": item.assetID ?? "",
                "remoteURL": item.remoteURL ?? "",
                "isVideo": item.isVideo
            ]
            if let img = item.image, let pngData = img.jpegData(compressionQuality: 0.75) {
                let fileURL = tempDirectory.appendingPathComponent("draft_\(idx).jpg")
                try? pngData.write(to: fileURL)
                imagePaths.append(fileURL.path)
                imageAssetIDs.append(item.assetID ?? "")
                entry["imagePath"] = fileURL.path
            }
            mediaManifest.append(entry)
        }
        dict["imagePaths"] = imagePaths
        dict["imageAssetIDs"] = imageAssetIDs
        dict["mediaManifest"] = mediaManifest
        if let lockedSubmissionPayload,
           JSONSerialization.isValidJSONObject(lockedSubmissionPayload) {
            dict["lockedSubmissionPayload"] = lockedSubmissionPayload
        }

        UserDefaults.standard.set(dict, forKey: draftDefaultsKey)
        if !isEditing { UserDefaults.standard.set(creationListingID, forKey: creationIdentityDefaultsKey) }
        hasSavedDraft = true
        if showSuccessFeedback { AdoptHaptics.success() }
    }

    func clearDraft() {
        removeOwnedDraftMedia()
        lockedSubmissionPayload = nil
        if draftPersistenceEnabled {
            UserDefaults.standard.removeObject(forKey: draftDefaultsKey)
            if !isEditing { UserDefaults.standard.removeObject(forKey: creationIdentityDefaultsKey) }
        }
        hasSavedDraft = false
    }

    private func unlockDefinitivelyRejectedSubmission(after error: Error?) {
        guard let error,
              lockedSubmissionPayload != nil,
              !PPCommunityService.shouldRetainPendingSubmission(after: error) else {
            return
        }
        // The callable confirmed that this payload did not commit. Keep the
        // user's form and processed media, but let the next submit build a
        // corrected request rather than silently resending stale input.
        lockedSubmissionPayload = nil
        persistDraft(showSuccessFeedback: false)
    }

    private func onFieldModified() {
        guard !isHydrating else { return }
        hasUserModifiedForm = true
    }

    var canDismissSafely: Bool {
        !hasUserModifiedForm
    }

    // MARK: - Validation & Readiness Radar

    var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasKind: Bool {
        selectedKind != nil
    }

    var hasBreed: Bool {
        selectedBreed != nil
    }

    var hasAge: Bool {
        ageMonths > 0
    }

    var hasGender: Bool {
        !selectedGender.isEmpty
    }

    var hasCity: Bool {
        selectedCity != nil
    }

    var hasArea: Bool {
        availableAreas.isEmpty || selectedArea != nil
    }

    var hasMedia: Bool {
        !mediaItems.isEmpty
    }

    var hasAdoptionReason: Bool {
        !adoptionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasDetails: Bool {
        !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var totalCheckpointsCount: Int {
        availableAreas.isEmpty ? 9 : 10
    }

    var completedCheckpointsCount: Int {
        var count = 0
        if hasName { count += 1 }
        if hasKind { count += 1 }
        if hasBreed { count += 1 }
        if hasAge { count += 1 }
        if hasGender { count += 1 }
        if hasCity { count += 1 }
        if !availableAreas.isEmpty && hasArea { count += 1 }
        if hasMedia { count += 1 }
        if hasDetails { count += 1 }
        if hasAdoptionReason { count += 1 }
        return count
    }

    var isFormReadyToSubmit: Bool {
        lockedSubmissionPayload != nil || completedCheckpointsCount == totalCheckpointsCount
    }

    var readinessFraction: Double {
        Double(completedCheckpointsCount) / Double(totalCheckpointsCount)
    }

    // MARK: - Media Actions

    func addImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let remaining = max(0, 8 - mediaItems.count)
        guard remaining > 0 else { return }

        let toAdd = Array(images.prefix(remaining))
        for img in toAdd {
            mediaItems.append(AdoptMediaItem(id: UUID().uuidString, image: img))
        }
        AdoptHaptics.impactLight()
    }

    func addVideo(url: URL, thumbnail: UIImage?) {
        guard mediaItems.count < 8 else { return }
        mediaItems.append(
            AdoptMediaItem(
                id: UUID().uuidString,
                image: thumbnail,
                videoURL: url,
                isVideo: true
            )
        )
        AdoptHaptics.impactMedium()
    }

    func removeMedia(at index: Int) {
        guard mediaItems.indices.contains(index) else { return }
        mediaItems.remove(at: index)
        AdoptHaptics.selection()
    }

    func setCoverPhoto(at index: Int) {
        guard mediaItems.indices.contains(index), index != 0 else { return }
        let item = mediaItems.remove(at: index)
        mediaItems.insert(item, at: 0)
        AdoptHaptics.selection()
    }

    // MARK: - Submit / Publish Flow

    func submitForm(completion: @escaping (Bool) -> Void) {
        guard isFormReadyToSubmit else {
            AdoptHaptics.error()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                showValidationShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showValidationShake = false
            }
            return
        }

        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }

        let currentUID = (UserManager.shared().currentUser?.id ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard draftPersistenceEnabled, currentUID == draftOwnerUID else {
            // Do not submit an already-visible draft through a different
            // account after a session transition. The opening account retains
            // its own local draft; reopening under the active account starts
            // a new, isolated form.
            errorMessage = PPAdoptLang("community_error_sign_in_required")
            return
        }

        isSubmitting = true
        errorMessage = nil
        submissionStepText = isEditing ? PPAdoptLang("adopt_form_save_changes") : PPAdoptLang("adopt_form_publish_action")

        let listingID = editingPet?.documentID.isEmpty == false ? editingPet!.documentID : creationListingID
        let petID = editingPet?.petID.isEmpty == false ? editingPet!.petID : listingID

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let payload: [String: Any]
                if let lockedSubmissionPayload = self.lockedSubmissionPayload {
                    payload = lockedSubmissionPayload
                } else {
                    self.submissionStepText = PPAdoptLang("adopt_form_media_studio_title")
                    var pendingMedia: [(index: Int, source: PPCommunityMediaSource)] = []
                    for index in self.mediaItems.indices {
                        let item = self.mediaItems[index]
                        guard item.remoteURL == nil, item.assetID == nil else { continue }
                        if item.isVideo, let url = item.videoURL {
                            pendingMedia.append((index, try PPCommunityMediaSource(videoURL: url)))
                        } else if let image = item.image {
                            pendingMedia.append((index, try PPCommunityMediaSource(image: image)))
                        } else {
                            throw PPCommunityError.missingMedia
                        }
                    }

                    var assetIDs = self.mediaItems.compactMap(\.assetID)
                    if !pendingMedia.isEmpty {
                        let media = try await PPCommunityService.shared.uploadMedia(
                            pendingMedia.map(\.source),
                            contextType: "adoption_listing",
                            contextID: listingID
                        )
                        guard media.assetIDs.count == pendingMedia.count else { throw PPCommunityError.invalidResponse }
                        for (offset, pending) in pendingMedia.enumerated() {
                            self.mediaItems[pending.index].assetID = media.assetIDs[offset]
                        }
                        // Persist the processed asset identities before the listing
                        // write. A timeout after media finalization can then retry
                        // the same listing payload rather than uploading duplicates.
                        self.persistDraft(showSuccessFeedback: false)
                        assetIDs = self.mediaItems.compactMap(\.assetID)
                    }
                    var seenAssetIDs = Set<String>()
                    assetIDs = Array(assetIDs.filter { seenAssetIDs.insert($0).inserted }.prefix(8))
                    guard !assetIDs.isEmpty else { throw PPCommunityError.missingMedia }

                    let cityName = self.selectedCity?.localizedName ?? self.selectedCity?.name ?? ""
                    let districtName = self.selectedArea?.localizedName ?? self.selectedArea?.arName ?? ""
                    let countryCode = self.selectedCity?.country?.iso ?? self.selectedCity?.country?.countryCode ?? CountryModel.safeCurrentCountryISOCode() ?? ""
                    payload = [
                        "listingId": listingID,
                        "petId": petID,
                        "expectedVersion": self.editingPet?.version ?? 0,
                        "title": self.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        "description": self.details.trimmingCharacters(in: .whitespacesAndNewlines),
                        "adoptionReason": self.adoptionReason.trimmingCharacters(in: .whitespacesAndNewlines),
                        "requirements": [],
                        "location": ["countryCode": countryCode, "city": cityName, "district": districtName],
                        "story": self.details.trimmingCharacters(in: .whitespacesAndNewlines),
                        "medicalNotes": "",
                        "organizationId": self.editingPet?.organizationID ?? "",
                        "mediaAssetIds": assetIDs,
                        "compatibility": [
                            "children": "unknown", "dogs": "unknown", "cats": "unknown",
                            "apartment": "unknown", "experienceLevel": "unknown"
                        ],
                        "profile": [
                            "name": self.name.trimmingCharacters(in: .whitespacesAndNewlines),
                            "categoryId": self.selectedKind?.id ?? 0,
                            "breedId": self.selectedBreed?.id ?? 0,
                            "breed": self.selectedBreed?.subKindNameAr ?? self.selectedBreed?.subKindNameEn ?? "",
                            "cityId": self.selectedCity?.cityID ?? 0,
                            "stateId": self.selectedArea?.stateID ?? 0,
                            "district": districtName,
                            "ageInMonths": self.ageMonths,
                            "gender": self.selectedGender.lowercased(),
                            "size": "",
                            "colors": [],
                            "distinctiveMarks": ""
                        ]
                    ]
                    // Persist the complete, normalized request before the
                    // callable. If its acknowledgement is lost, a retry uses
                    // the same command fingerprint and immutable media order.
                    self.persistDraft(
                        showSuccessFeedback: false,
                        submissionPayload: payload
                    )
                }

                self.submissionStepText = self.isEditing ? PPAdoptLang("adopt_form_save_changes") : PPAdoptLang("adopt_form_publish_action")
                if self.isEditing {
                    _ = try await PPCommunityService.shared.updateAdoptionListing(payload: payload)
                } else {
                    _ = try await PPCommunityService.shared.submitAdoptionListing(payload: payload)
                }
                self.handlePersistenceResult(success: true, error: nil, completion: completion)
            } catch {
                self.handlePersistenceResult(success: false, error: error, completion: completion)
            }
        }
    }

    private func handlePersistenceResult(success: Bool, error: Error?, completion: @escaping (Bool) -> Void) {
        self.isSubmitting = false
        if success {
            self.clearDraft()
            AdoptHaptics.success()
            completion(true)
        } else {
            self.unlockDefinitivelyRejectedSubmission(after: error)
            self.errorMessage = PPCommunityService.userFacingErrorMessage(for: error)
            AdoptHaptics.error()
            completion(false)
        }
    }
}

// MARK: - Root Container (Adaptive Routing)

struct AddAdoptPetScreen: View {
    @StateObject private var store: AddAdoptPetStore

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var onDismiss: () -> Void
    var onSuccess: () -> Void

    init(pet: AdoptPetModel? = nil, onDismiss: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        _store = StateObject(wrappedValue: AddAdoptPetStore(pet: pet))
        self.onDismiss = onDismiss
        self.onSuccess = onSuccess
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }

    var body: some View {
        ZStack {
            // Adaptive Studio Backdrop
            studioAtmosphere
                .ignoresSafeArea()

            if isPad {
                iPadAddAdoptPetCockpit(store: store, onDismiss: handleDismissRequest, onSuccess: onSuccess)
            } else {
                iPhoneAddAdoptPetDeck(store: store, onDismiss: handleDismissRequest, onSuccess: onSuccess)
            }

            // Submitting State Veil
            if store.isSubmitting {
                submittingVeil
            }

            // Draft Restored Banner
            if store.showDraftRestoredBanner {
                draftRestoredToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onAppear {
            store.checkCommunityConfiguration()
        }
        .alert(isPresented: $store.showUnsavedChangesDialog) {
            Alert(
                title: Text(PPAdoptLang("adopt_form_unsaved_title")).font(AdoptFont.bold(17)),
                message: Text(PPAdoptLang("adopt_form_unsaved_message")).font(AdoptFont.regular(14)),
                primaryButton: .default(Text(PPAdoptLang("adopt_form_save_draft")).font(AdoptFont.medium(15))) {
                    store.saveDraft()
                    onDismiss()
                },
                secondaryButton: .destructive(Text(PPAdoptLang("adopt_form_discard_action")).font(AdoptFont.regular(15))) {
                    store.clearDraft()
                    onDismiss()
                }
            )
        }
    }

    private func handleDismissRequest() {
        if store.canDismissSafely {
            onDismiss()
        } else {
            store.showUnsavedChangesDialog = true
        }
    }

    // MARK: - Studio Atmosphere

    private var studioAtmosphere: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)

            // Dynamic Accent Ambient Glow
            GeometryReader { proxy in
                let w = proxy.size.width
                Circle()
                    .fill(speciesAmbientColor.opacity(0.12))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 70)
                    .offset(x: -w * 0.2, y: -100)

                Circle()
                    .fill(Color(hex: 0xC41E3A).opacity(0.06))
                    .frame(width: w * 0.75, height: w * 0.75)
                    .blur(radius: 80)
                    .offset(x: w * 0.4, y: 250)
            }
        }
    }

    private var speciesAmbientColor: Color {
        guard let kind = store.selectedKind else {
            return Color(hex: 0xC41E3A)
        }
        let kName = (kind.kindNameAr ?? "").lowercased()
        if kName.contains("قطط") || kName.contains("cat") {
            return Color(hex: 0xF59E0B) // Warm Amber
        } else if kName.contains("كلاب") || kName.contains("dog") {
            return Color(hex: 0x3B82F6) // Cobalt Blue
        } else if kName.contains("طيور") || kName.contains("bird") {
            return Color(hex: 0x10B981) // Emerald Mint
        }
        return Color(hex: 0x8B5CF6) // Violet
    }

    // MARK: - Submitting State Veil

    private var submittingVeil: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)

                Text(store.submissionStepText)
                    .font(AdoptFont.bold(17))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground).opacity(0.92))
                    .shadow(color: .black.opacity(0.2), radius: 25, y: 10)
            )
            .padding(40)
        }
    }

    // MARK: - Draft Restored Toast

    private var draftRestoredToast: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: 0x10B981))

                Text(PPAdoptLang("adopt_form_draft_restored"))
                    .font(AdoptFont.medium(14))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.top, 56)

            Spacer()
        }
    }
}

// MARK: - Reusable Form Picker Row

private struct AdoptFormPickerRow: View {
    let title: String
    let value: String?
    let placeholder: String
    let icon: String
    var iconTint: Color = Color(hex: 0xC41E3A)
    var isEnabled: Bool = true
    var isRequired: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                if isRequired {
                    Text("*")
                        .font(AdoptFont.bold(13))
                        .foregroundColor(Color(hex: 0xC41E3A))
                }
            }

            Button(action: {
                if isEnabled {
                    AdoptHaptics.selection()
                    action()
                } else {
                    AdoptHaptics.error()
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconTint.opacity(0.12))
                            .frame(width: 32, height: 32)

                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconTint)
                    }

                    Text(value ?? placeholder)
                        .font(value != nil ? AdoptFont.bold(15) : AdoptFont.medium(15))
                        .foregroundColor(value != nil ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(value != nil ? iconTint.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(AdoptPressStyle())
            .opacity(isEnabled ? 1.0 : 0.55)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(value ?? placeholder)")
            .accessibilityHint(isEnabled ? PPAdoptLang("Tap to change selection") : placeholder)
        }
    }
}

// MARK: - iPhone Architecture (`iPhoneAddAdoptPetDeck`)

private struct iPhoneAddAdoptPetDeck: View {
    @ObservedObject var store: AddAdoptPetStore
    var onDismiss: () -> Void
    var onSuccess: () -> Void

    @State private var showSpeciesPicker: Bool = false
    @State private var showBreedPicker: Bool = false
    @State private var showGenderPicker: Bool = false
    @State private var showCityPicker: Bool = false
    @State private var showAreaPicker: Bool = false
    @State private var showMediaPickerSheet: Bool = false
    @State private var showPhotoLibrary: Bool = false
    @State private var showCamera: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Apex Navigation Header
            apexHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if let notice = store.communityNotice {
                        communityUnavailableNoticeCard(notice)
                    }

                    if let err = store.errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(hex: 0xC41E3A))
                                .font(.system(size: 16, weight: .bold))
                            Text(err)
                                .font(AdoptFont.bold(14))
                                .foregroundColor(Color(hex: 0xC41E3A))
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: 0xFFF1F2))
                        )
                    }

                    // Mission Hero Card
                    missionHeroCard

                    // 1. Media Studio Tray
                    mediaStudioSection

                    // 2. Identity & Lineage (Name, Species, Breed)
                    identitySection

                    // 3. Demographics & Location (Age, Gender, City, Area)
                    demographicsSection

                    // 4. Adoption Story & Notes
                    storySection

                    // Spacer for Floating Action Bar
                    Spacer().frame(height: 130)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboardCompat()
        }
        .overlay(alignment: .bottom) {
            floatingActionDock
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .sheet(isPresented: $showSpeciesPicker) {
            AdoptSpeciesPickerSheet(
                kinds: store.availableKinds,
                selectedKind: $store.selectedKind,
                selectedBreed: $store.selectedBreed
            )
        }
        .sheet(isPresented: $showBreedPicker) {
            AdoptBreedPickerSheet(
                breeds: store.availableBreeds,
                selectedBreed: $store.selectedBreed
            )
        }
        .sheet(isPresented: $showGenderPicker) {
            AdoptGenderPickerSheet(
                selectedGender: $store.selectedGender
            )
        }
        .sheet(isPresented: $showCityPicker) {
            AdoptCityPickerSheet(
                cities: store.availableCities,
                selectedCity: $store.selectedCity,
                selectedArea: $store.selectedArea
            )
        }
        .sheet(isPresented: $showAreaPicker) {
            AdoptAreaPickerSheet(
                areas: store.availableAreas,
                cityName: store.selectedCity?.localizedName ?? "",
                selectedArea: $store.selectedArea
            )
        }
        .sheet(isPresented: $showPhotoLibrary) {
            AdoptPhotoLibraryPicker { images in
                store.addImages(images)
            }
        }
        .sheet(isPresented: $showCamera) {
            AdoptCameraPicker { image in
                if let img = image {
                    store.addImages([img])
                }
            }
        }
        .confirmationDialog(
            PPAdoptLang("adopt_form_media_studio_title"),
            isPresented: $showMediaPickerSheet,
            titleVisibility: .visible
        ) {
            Button(PPAdoptLang("adopt_form_media_add_photo")) {
                showPhotoLibrary = true
            }
            Button(PPAdoptLang("Take Photo")) {
                showCamera = true
            }
            Button(PPAdoptLang("Cancel"), role: .cancel) {}
        }
    }

    private func communityUnavailableNoticeCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(hex: 0xD97706))
                .font(.system(size: 18, weight: .semibold))

            Text(text)
                .font(AdoptFont.medium(13))
                .foregroundColor(Color(hex: 0x92400E))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0xFEF3C7).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: 0xF59E0B).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Apex Header

    private var apexHeader: some View {
        HStack {
            // Dismiss / Back Button
            Button(action: onDismiss) {
                Image(systemName: Language.isRTL() ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                    )
            }
            .buttonStyle(AdoptPressStyle())

            Spacer()

            // Title
            Text(store.isEditing ? PPAdoptLang("adopt_form_edit_title") : PPAdoptLang("addPetForAdoption"))
                .font(AdoptFont.bold(18))
                .foregroundColor(.primary)

            Spacer()

            // Readiness Badge Capsule
            HStack(spacing: 5) {
                Image(systemName: store.isFormReadyToSubmit ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(readinessBadgeTint)

                Text(String(format: PPAdoptLang("adopt_form_progress_format"), store.completedCheckpointsCount, store.totalCheckpointsCount))
                    .font(AdoptFont.bold(13))
                    .foregroundColor(readinessBadgeTint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(readinessBadgeBackground)
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var readinessBadgeTint: Color {
        if store.isFormReadyToSubmit {
            return Color(hex: 0x059669) // Emerald
        } else if store.completedCheckpointsCount >= 4 {
            return Color(hex: 0xD97706) // Amber
        }
        return Color(hex: 0xC41E3A) // Crimson
    }

    private var readinessBadgeBackground: Color {
        if store.isFormReadyToSubmit {
            return Color(hex: 0xECFDF5)
        } else if store.completedCheckpointsCount >= 4 {
            return Color(hex: 0xFEF3C7)
        }
        return Color(hex: 0xFFF1F2)
    }

    // MARK: - Mission Hero Card

    private var missionHeroCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(PPAdoptLang("adopt_form_eyebrow"))
                    .font(AdoptFont.bold(12))
                    .foregroundColor(Color(hex: 0xC41E3A))
                    .textCase(.uppercase)

                Text(store.isEditing ? PPAdoptLang("adopt_form_edit_title") : PPAdoptLang("adopt_form_create_title"))
                    .font(AdoptFont.bold(18))
                    .foregroundColor(.primary)

                Text(store.isEditing ? PPAdoptLang("adopt_form_edit_subtitle") : PPAdoptLang("adopt_form_create_subtitle"))
                    .font(AdoptFont.regular(13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: 0xC41E3A).opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: 0xC41E3A))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(hex: 0xC41E3A).opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        )
    }

    // MARK: - Media Studio Section

    private var mediaStudioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(PPAdoptLang("adopt_form_media_studio_title"))
                        .font(AdoptFont.bold(16))
                } icon: {
                    Image(systemName: "photo.stack.fill")
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                Spacer()

                Text("\(store.mediaItems.count)/8")
                    .font(AdoptFont.bold(13))
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add Media Button
                    if store.mediaItems.count < 8 {
                        Button(action: {
                            AdoptHaptics.impactLight()
                            showMediaPickerSheet = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: 0xC41E3A))

                                Text(PPAdoptLang("adopt_form_media_add_button"))
                                    .font(AdoptFont.bold(13))
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 105, height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                            .foregroundColor(Color(hex: 0xC41E3A).opacity(0.4))
                                    )
                            )
                        }
                        .buttonStyle(AdoptPressStyle())
                    }

                    // Uploaded Media Thumbnails
                    ForEach(Array(store.mediaItems.enumerated()), id: \.element.id) { idx, item in
                        AdoptMediaThumbnailCard(
                            item: item,
                            isCover: idx == 0,
                            onMakeCover: { store.setCoverPhoto(at: idx) },
                            onDelete: { store.removeMedia(at: idx) }
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - Identity & Breed Section

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(PPAdoptLang("adopt_form_identity_title"))
                    .font(AdoptFont.bold(16))
            } icon: {
                Image(systemName: "tag.fill")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            // Pet Name Field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(PPAdoptLang("adopt_form_pet_name_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)
                    Text("*")
                        .font(AdoptFont.bold(13))
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                HStack {
                    TextField(PPAdoptLang("adopt_form_pet_name_placeholder"), text: $store.name)
                        .font(AdoptFont.bold(15))
                        .textInputAutocapitalization(.words)

                    if !store.name.isEmpty {
                        Button(action: { store.name = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
            }

            // Species Picker Row
            AdoptFormPickerRow(
                title: PPAdoptLang("adopt_form_species_label"),
                value: store.selectedKind?.localizedName,
                placeholder: PPAdoptLang("adopt_form_select_species"),
                icon: PPKindIcon(for: store.selectedKind?.localizedName ?? ""),
                iconTint: speciesPickerTint,
                isEnabled: true,
                isRequired: true
            ) {
                showSpeciesPicker = true
            }

            // Breed Picker Row
            AdoptFormPickerRow(
                title: PPAdoptLang("adopt_form_breed_label"),
                value: store.selectedBreed?.localizedName,
                placeholder: store.selectedKind == nil ? PPAdoptLang("adopt_form_select_species_first") : PPAdoptLang("adopt_form_select_breed"),
                icon: "tag.fill",
                iconTint: Color(hex: 0xC41E3A),
                isEnabled: store.selectedKind != nil,
                isRequired: true
            ) {
                showBreedPicker = true
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private var speciesPickerTint: Color {
        guard let kind = store.selectedKind else {
            return Color(hex: 0xC41E3A)
        }
        let kName = (kind.kindNameAr ?? "").lowercased()
        if kName.contains("قطط") || kName.contains("cat") {
            return Color(hex: 0xF59E0B)
        } else if kName.contains("كلاب") || kName.contains("dog") {
            return Color(hex: 0x3B82F6)
        } else if kName.contains("طيور") || kName.contains("bird") {
            return Color(hex: 0x10B981)
        }
        return Color(hex: 0x8B5CF6)
    }

    // MARK: - Demographics Section (Age, Gender, City, Area)

    private var demographicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(PPAdoptLang("adopt_form_physical_title"))
                    .font(AdoptFont.bold(16))
            } icon: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            // Age Stepper & Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Text(PPAdoptLang("adopt_form_age_label"))
                            .font(AdoptFont.medium(13))
                            .foregroundColor(.secondary)
                        Text("*")
                            .font(AdoptFont.bold(13))
                            .foregroundColor(Color(hex: 0xC41E3A))
                    }

                    Spacer()

                    Text(formattedAge(months: store.ageMonths))
                        .font(AdoptFont.bold(15))
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                // Age Presets
                HStack(spacing: 8) {
                    agePresetChip(label: PPAdoptLang("adopt_form_age_preset_3m"), months: 3)
                    agePresetChip(label: PPAdoptLang("adopt_form_age_preset_6m"), months: 6)
                    agePresetChip(label: PPAdoptLang("adopt_form_age_preset_1y"), months: 12)
                    agePresetChip(label: PPAdoptLang("adopt_form_age_preset_2y"), months: 24)
                    agePresetChip(label: PPAdoptLang("adopt_form_age_preset_3y"), months: 36)
                }

                // Stepper Buttons
                HStack {
                    Button(action: {
                        if store.ageMonths > 1 {
                            AdoptHaptics.impactLight()
                            store.ageMonths -= 1
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(AdoptPressStyle())

                    Text(formattedAge(months: store.ageMonths))
                        .font(AdoptFont.bold(15))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 100)
                        .padding(.horizontal, 8)

                    Button(action: {
                        if store.ageMonths < 240 {
                            AdoptHaptics.impactLight()
                            store.ageMonths += 1
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(AdoptPressStyle())
                }
            }

            Divider()

            // Gender Picker Row
            AdoptFormPickerRow(
                title: PPAdoptLang("adopt_form_gender_label"),
                value: store.selectedGender.isEmpty ? nil : (store.selectedGender.lowercased() == "male" ? PPAdoptLang("adopt_form_gender_male") : PPAdoptLang("adopt_form_gender_female")),
                placeholder: PPAdoptLang("adopt_form_select_gender"),
                icon: store.selectedGender.isEmpty ? "pawprint.circle" : (store.selectedGender.lowercased() == "female" ? "figure.stand.dress" : "figure.stand"),
                iconTint: store.selectedGender.isEmpty ? Color(hex: 0x6B7280) : (store.selectedGender.lowercased() == "female" ? Color(hex: 0xEC4899) : Color(hex: 0x3B82F6)),
                isEnabled: true,
                isRequired: true
            ) {
                showGenderPicker = true
            }

            Divider()

            // City Picker Row
            AdoptFormPickerRow(
                title: PPAdoptLang("adopt_form_city_label"),
                value: store.selectedCity?.localizedName,
                placeholder: PPAdoptLang("adopt_form_select_city"),
                icon: "mappin.circle.fill",
                iconTint: Color(hex: 0xC41E3A),
                isEnabled: true,
                isRequired: true
            ) {
                showCityPicker = true
            }

            // Area / District Picker Row
            AdoptFormPickerRow(
                title: PPAdoptLang("adopt_form_area_label"),
                value: store.selectedArea?.localizedName,
                placeholder: store.selectedCity == nil ? PPAdoptLang("adopt_form_select_city_first") : (store.availableAreas.isEmpty ? PPAdoptLang("adopt_form_no_areas_available") : PPAdoptLang("adopt_form_select_area")),
                icon: "building.2.crop.circle.fill",
                iconTint: Color(hex: 0x10B981),
                isEnabled: store.selectedCity != nil && !store.availableAreas.isEmpty,
                isRequired: !store.availableAreas.isEmpty
            ) {
                showAreaPicker = true
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private func agePresetChip(label: String, months: Int) -> some View {
        let isSelected = store.ageMonths == months
        return Button(action: {
            AdoptHaptics.selection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                store.ageMonths = months
            }
        }) {
            Text(label)
                .font(isSelected ? AdoptFont.bold(12) : AdoptFont.medium(12))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: 0xC41E3A) : Color(UIColor.tertiarySystemGroupedBackground))
                )
        }
        .buttonStyle(AdoptPressStyle())
    }

    // MARK: - Adoption Story & Notes Section

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(PPAdoptLang("adopt_form_story_title"))
                        .font(AdoptFont.bold(16))
                } icon: {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                Spacer()

                Text("\(store.details.count) " + PPAdoptLang("characters"))
                    .font(AdoptFont.regular(12))
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if store.details.isEmpty {
                    Text(PPAdoptLang("adopt_form_story_placeholder"))
                        .font(AdoptFont.regular(15))
                        .foregroundColor(.secondary.opacity(0.65))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $store.details)
                    .font(AdoptFont.regular(15))
                    .hideScrollContentBackgroundCompat()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 110)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("community_adoption_reason_title"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                ZStack(alignment: .topLeading) {
                    if store.adoptionReason.isEmpty {
                        Text(PPAdoptLang("community_adoption_reason_placeholder"))
                            .font(AdoptFont.regular(14))
                            .foregroundColor(.secondary.opacity(0.65))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $store.adoptionReason)
                        .font(AdoptFont.regular(15))
                        .hideScrollContentBackgroundCompat()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 82)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
                .accessibilityLabel(PPAdoptLang("community_adoption_reason_title"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(PPAdoptLang("Done")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(AdoptFont.bold(14))
                .foregroundColor(Color(hex: 0xC41E3A))
            }
        }
    }

    // MARK: - Floating Action Dock

    private var floatingActionDock: some View {
        VStack(spacing: 10) {
            if let err = store.errorMessage {
                Button(action: {
                    AdoptHaptics.selection()
                    if !UserManager.shared().isUserLoggedIn() {
                        UserManager.showPromptOnTopController()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))

                        Text(err)
                            .font(AdoptFont.bold(13))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        if !UserManager.shared().isUserLoggedIn() {
                            Image(systemName: Language.isRTL() ? "chevron.left" : "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .opacity(0.7)
                        }
                    }
                    .foregroundColor(Color(hex: 0xC41E3A))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: 0xFFF1F2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: 0xFCA5A5).opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(AdoptPressStyle())
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }

            HStack(spacing: 12) {
                // Draft Save Button
                Button(action: {
                    store.saveDraft()
                }) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        )
                }
                .buttonStyle(AdoptPressStyle())

                // Primary CTA
                Button(action: {
                    store.submitForm { success in
                        if success {
                            onSuccess()
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if store.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: store.isEditing ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                        }

                        Text(store.isEditing ? PPAdoptLang("adopt_form_save_changes") : PPAdoptLang("adopt_form_publish_action"))
                            .font(AdoptFont.bold(16))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(store.isFormReadyToSubmit ? Color(hex: 0xC41E3A) : Color(hex: 0xC41E3A).opacity(0.6))
                            .shadow(color: Color(hex: 0xC41E3A).opacity(0.35), radius: 12, y: 4)
                    )
                }
                .buttonStyle(AdoptPressStyle())
                .disabled(store.isSubmitting)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            Color(UIColor.systemBackground).opacity(0.92)
                .background(.ultraThinMaterial)
                .overlay(
                    VStack {
                        Divider().opacity(0.6)
                        Spacer()
                    }
                )
                .shadow(color: .black.opacity(0.06), radius: 16, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func formattedAge(months: Int) -> String {
        return PPAdoptFormattedAge(months: months)
    }
}

// MARK: - iPad Architecture (`iPadAddAdoptPetCockpit`)

private struct iPadAddAdoptPetCockpit: View {
    @ObservedObject var store: AddAdoptPetStore
    var onDismiss: () -> Void
    var onSuccess: () -> Void

    @State private var showSpeciesPicker: Bool = false
    @State private var showBreedPicker: Bool = false
    @State private var showGenderPicker: Bool = false
    @State private var showCityPicker: Bool = false
    @State private var showAreaPicker: Bool = false
    @State private var showMediaPickerSheet: Bool = false
    @State private var showPhotoLibrary: Bool = false
    @State private var showCamera: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // iPad Top Navigation Toolbar
            iPadToolbar

            // 2-Column Spatial Studio Layout
            HStack(alignment: .top, spacing: 24) {
                // LEFT COLUMN (42%): Real-time Listing Preview & Readiness Radar
                VStack(spacing: 20) {
                    // Live Listing Preview Card
                    AdoptLiveListingPreviewCard(store: store)

                    // 7-Point Readiness Radar
                    AdoptReadinessRadarCard(store: store)

                    // Best Practices & Trust Guidelines Card
                    adoptionTrustCard

                    Spacer()
                }
                .frame(maxWidth: 420)

                // RIGHT COLUMN (58%): Structured Intake Studio Deck
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        if let notice = store.communityNotice {
                            communityUnavailableNoticeCard(notice)
                        }

                        if let err = store.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(Color(hex: 0xC41E3A))
                                    .font(.system(size: 16, weight: .bold))
                                Text(err)
                                    .font(AdoptFont.bold(14))
                                    .foregroundColor(Color(hex: 0xC41E3A))
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(hex: 0xFFF1F2))
                            )
                        }

                        // Media Studio Section
                        iPadMediaStudioSection

                        // Species & Lineage Section
                        iPadSpeciesIdentitySection

                        // Physical Demographics & Location Section
                        iPadDemographicsSection

                        // Story & Notes Section
                        iPadStorySection

                        Spacer().frame(height: 40)
                    }
                }
                .scrollDismissesKeyboardCompat()
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        .sheet(isPresented: $showSpeciesPicker) {
            AdoptSpeciesPickerSheet(
                kinds: store.availableKinds,
                selectedKind: $store.selectedKind,
                selectedBreed: $store.selectedBreed
            )
        }
        .sheet(isPresented: $showBreedPicker) {
            AdoptBreedPickerSheet(
                breeds: store.availableBreeds,
                selectedBreed: $store.selectedBreed
            )
        }
        .sheet(isPresented: $showGenderPicker) {
            AdoptGenderPickerSheet(
                selectedGender: $store.selectedGender
            )
        }
        .sheet(isPresented: $showCityPicker) {
            AdoptCityPickerSheet(
                cities: store.availableCities,
                selectedCity: $store.selectedCity,
                selectedArea: $store.selectedArea
            )
        }
        .sheet(isPresented: $showAreaPicker) {
            AdoptAreaPickerSheet(
                areas: store.availableAreas,
                cityName: store.selectedCity?.localizedName ?? "",
                selectedArea: $store.selectedArea
            )
        }
        .sheet(isPresented: $showPhotoLibrary) {
            AdoptPhotoLibraryPicker { images in
                store.addImages(images)
            }
        }
        .sheet(isPresented: $showCamera) {
            AdoptCameraPicker { image in
                if let img = image {
                    store.addImages([img])
                }
            }
        }
        .confirmationDialog(
            PPAdoptLang("adopt_form_media_studio_title"),
            isPresented: $showMediaPickerSheet,
            titleVisibility: .visible
        ) {
            Button(PPAdoptLang("adopt_form_media_add_photo")) {
                showPhotoLibrary = true
            }
            Button(PPAdoptLang("Take Photo")) {
                showCamera = true
            }
            Button(PPAdoptLang("Cancel"), role: .cancel) {}
        }
    }

    private func communityUnavailableNoticeCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color(hex: 0xD97706))
                .font(.system(size: 18, weight: .semibold))

            Text(text)
                .font(AdoptFont.medium(13))
                .foregroundColor(Color(hex: 0x92400E))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: 0xFEF3C7).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: 0xF59E0B).opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - iPad Toolbar

    private var iPadToolbar: some View {
        HStack {
            // Dismiss Button
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                    Text(PPAdoptLang("Cancel"))
                        .font(AdoptFont.bold(14))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )
            }
            .buttonStyle(AdoptPressStyle())
            .hoverEffect(.lift)
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Header Title
            VStack(spacing: 2) {
                Text(store.isEditing ? PPAdoptLang("adopt_form_edit_title") : PPAdoptLang("addPetForAdoption"))
                    .font(AdoptFont.bold(19))
                    .foregroundColor(.primary)

                Text(PPAdoptLang("adopt_form_eyebrow"))
                    .font(AdoptFont.medium(12))
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            Spacer()

            // Actions (Save Draft + Publish)
            HStack(spacing: 12) {
                Button(action: { store.saveDraft() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .bold))
                        Text(PPAdoptLang("adopt_form_save_draft"))
                            .font(AdoptFont.medium(14))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    )
                }
                .buttonStyle(AdoptPressStyle())
                .hoverEffect(.lift)
                .keyboardShortcut("d", modifiers: .command)

                Button(action: {
                    store.submitForm { success in
                        if success { onSuccess() }
                    }
                }) {
                    HStack(spacing: 6) {
                        if store.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: store.isEditing ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text(store.isEditing ? PPAdoptLang("adopt_form_save_changes") : PPAdoptLang("adopt_form_publish_action"))
                            .font(AdoptFont.bold(14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(store.isFormReadyToSubmit ? Color(hex: 0xC41E3A) : Color(hex: 0xC41E3A).opacity(0.6))
                            .shadow(color: Color(hex: 0xC41E3A).opacity(0.3), radius: 8, y: 3)
                    )
                }
                .buttonStyle(AdoptPressStyle())
                .hoverEffect(.lift)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(store.isSubmitting)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(Color(UIColor.secondarySystemGroupedBackground).opacity(0.6))
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - iPad Right Column Sections

    private var iPadMediaStudioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text(PPAdoptLang("adopt_form_media_studio_title"))
                        .font(AdoptFont.bold(17))
                } icon: {
                    Image(systemName: "photo.stack.fill")
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                Spacer()

                Text("\(store.mediaItems.count)/8")
                    .font(AdoptFont.bold(14))
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if store.mediaItems.count < 8 {
                        Button(action: {
                            AdoptHaptics.impactLight()
                            showMediaPickerSheet = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: 0xC41E3A))

                                Text(PPAdoptLang("adopt_form_media_add_button"))
                                    .font(AdoptFont.bold(13))
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 120, height: 135)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                            .foregroundColor(Color(hex: 0xC41E3A).opacity(0.4))
                                    )
                            )
                        }
                        .buttonStyle(AdoptPressStyle())
                        .hoverEffect(.lift)
                    }

                    ForEach(Array(store.mediaItems.enumerated()), id: \.element.id) { idx, item in
                        AdoptMediaThumbnailCard(
                            item: item,
                            isCover: idx == 0,
                            onMakeCover: { store.setCoverPhoto(at: idx) },
                            onDelete: { store.removeMedia(at: idx) }
                        )
                    }
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        )
    }

    private var iPadSpeciesIdentitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(PPAdoptLang("adopt_form_identity_title"))
                    .font(AdoptFont.bold(17))
            } icon: {
                Image(systemName: "tag.fill")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            // Name Field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(PPAdoptLang("adopt_form_pet_name_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)
                    Text("*")
                        .font(AdoptFont.bold(13))
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                TextField(PPAdoptLang("adopt_form_pet_name_placeholder"), text: $store.name)
                    .font(AdoptFont.bold(15))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
            }

            // Species and Breed 2-Column Row
            HStack(spacing: 16) {
                // Species Picker
                AdoptFormPickerRow(
                    title: PPAdoptLang("adopt_form_species_label"),
                    value: store.selectedKind?.localizedName,
                    placeholder: PPAdoptLang("adopt_form_select_species"),
                    icon: PPKindIcon(for: store.selectedKind?.localizedName ?? ""),
                    iconTint: speciesPickerTint,
                    isEnabled: true,
                    isRequired: true
                ) {
                    showSpeciesPicker = true
                }
                .frame(maxWidth: .infinity)

                // Breed Picker
                AdoptFormPickerRow(
                    title: PPAdoptLang("adopt_form_breed_label"),
                    value: store.selectedBreed?.localizedName,
                    placeholder: store.selectedKind == nil ? PPAdoptLang("adopt_form_select_species_first") : PPAdoptLang("adopt_form_select_breed"),
                    icon: "tag.fill",
                    iconTint: Color(hex: 0xC41E3A),
                    isEnabled: store.selectedKind != nil,
                    isRequired: true
                ) {
                    showBreedPicker = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        )
    }

    private var speciesPickerTint: Color {
        guard let kind = store.selectedKind else {
            return Color(hex: 0xC41E3A)
        }
        let kName = (kind.kindNameAr ?? "").lowercased()
        if kName.contains("قطط") || kName.contains("cat") {
            return Color(hex: 0xF59E0B)
        } else if kName.contains("كلاب") || kName.contains("dog") {
            return Color(hex: 0x3B82F6)
        } else if kName.contains("طيور") || kName.contains("bird") {
            return Color(hex: 0x10B981)
        }
        return Color(hex: 0x8B5CF6)
    }

    private var iPadDemographicsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label {
                Text(PPAdoptLang("adopt_form_physical_title"))
                    .font(AdoptFont.bold(17))
            } icon: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            // Row 1: Age & Gender
            HStack(alignment: .top, spacing: 18) {
                // Age Column
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 4) {
                            Text(PPAdoptLang("adopt_form_age_label"))
                                .font(AdoptFont.medium(13))
                                .foregroundColor(.secondary)
                            Text("*")
                                .font(AdoptFont.bold(13))
                                .foregroundColor(Color(hex: 0xC41E3A))
                        }
                        Spacer()
                        Text(PPAdoptFormattedAge(months: store.ageMonths))
                            .font(AdoptFont.bold(14))
                            .foregroundColor(Color(hex: 0xC41E3A))
                    }

                    HStack(spacing: 6) {
                        iPadAgePreset(label: "3M", months: 3)
                        iPadAgePreset(label: "6M", months: 6)
                        iPadAgePreset(label: "1Y", months: 12)
                        iPadAgePreset(label: "2Y", months: 24)
                    }

                    HStack {
                        Button(action: {
                            if store.ageMonths > 1 { store.ageMonths -= 1 }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                        }
                        .buttonStyle(AdoptPressStyle())

                        Button(action: {
                            if store.ageMonths < 240 { store.ageMonths += 1 }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                        }
                        .buttonStyle(AdoptPressStyle())
                    }
                }
                .frame(maxWidth: .infinity)

                // Gender Column
                AdoptFormPickerRow(
                    title: PPAdoptLang("adopt_form_gender_label"),
                    value: store.selectedGender.isEmpty ? nil : (store.selectedGender.lowercased() == "male" ? PPAdoptLang("adopt_form_gender_male") : PPAdoptLang("adopt_form_gender_female")),
                    placeholder: PPAdoptLang("adopt_form_select_gender"),
                    icon: store.selectedGender.isEmpty ? "pawprint.circle" : (store.selectedGender.lowercased() == "female" ? "figure.stand.dress" : "figure.stand"),
                    iconTint: store.selectedGender.isEmpty ? Color(hex: 0x6B7280) : (store.selectedGender.lowercased() == "female" ? Color(hex: 0xEC4899) : Color(hex: 0x3B82F6)),
                    isEnabled: true,
                    isRequired: true
                ) {
                    showGenderPicker = true
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Row 2: City & Area
            HStack(spacing: 18) {
                // City Column
                AdoptFormPickerRow(
                    title: PPAdoptLang("adopt_form_city_label"),
                    value: store.selectedCity?.localizedName,
                    placeholder: PPAdoptLang("adopt_form_select_city"),
                    icon: "mappin.circle.fill",
                    iconTint: Color(hex: 0xC41E3A),
                    isEnabled: true,
                    isRequired: true
                ) {
                    showCityPicker = true
                }
                .frame(maxWidth: .infinity)

                // Area Column
                AdoptFormPickerRow(
                    title: PPAdoptLang("adopt_form_area_label"),
                    value: store.selectedArea?.localizedName,
                    placeholder: store.selectedCity == nil ? PPAdoptLang("adopt_form_select_city_first") : (store.availableAreas.isEmpty ? PPAdoptLang("adopt_form_no_areas_available") : PPAdoptLang("adopt_form_select_area")),
                    icon: "building.2.crop.circle.fill",
                    iconTint: Color(hex: 0x10B981),
                    isEnabled: store.selectedCity != nil && !store.availableAreas.isEmpty,
                    isRequired: !store.availableAreas.isEmpty
                ) {
                    showAreaPicker = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        )
    }

    private func iPadAgePreset(label: String, months: Int) -> some View {
        let isSelected = store.ageMonths == months
        return Button(action: {
            AdoptHaptics.selection()
            store.ageMonths = months
        }) {
            Text(label)
                .font(AdoptFont.bold(12))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: 0xC41E3A) : Color(UIColor.tertiarySystemGroupedBackground))
                )
        }
        .buttonStyle(AdoptPressStyle())
    }

    private var iPadStorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text(PPAdoptLang("adopt_form_story_title"))
                        .font(AdoptFont.bold(17))
                } icon: {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                Spacer()

                Text("\(store.details.count) " + PPAdoptLang("characters"))
                    .font(AdoptFont.regular(13))
                    .foregroundColor(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if store.details.isEmpty {
                    Text(PPAdoptLang("adopt_form_story_placeholder"))
                        .font(AdoptFont.regular(15))
                        .foregroundColor(.secondary.opacity(0.65))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $store.details)
                    .font(AdoptFont.regular(15))
                    .hideScrollContentBackgroundCompat()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("community_adoption_reason_title"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                ZStack(alignment: .topLeading) {
                    if store.adoptionReason.isEmpty {
                        Text(PPAdoptLang("community_adoption_reason_placeholder"))
                            .font(AdoptFont.regular(14))
                            .foregroundColor(.secondary.opacity(0.65))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $store.adoptionReason)
                        .font(AdoptFont.regular(15))
                        .hideScrollContentBackgroundCompat()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .frame(minHeight: 92)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
                .accessibilityLabel(PPAdoptLang("community_adoption_reason_title"))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(PPAdoptLang("Done")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(AdoptFont.bold(14))
                .foregroundColor(Color(hex: 0xC41E3A))
            }
        }
    }

    // MARK: - Trust & Best Practices Card

    private var adoptionTrustCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color(hex: 0x10B981))
                Text(PPAdoptLang("adopt_form_best_practices_title"))
                    .font(AdoptFont.bold(15))
                    .foregroundColor(.primary)
            }

            Text(PPAdoptLang("adopt_form_best_practices_tip1"))
                .font(AdoptFont.regular(12))
                .foregroundColor(.secondary)

            Text(PPAdoptLang("adopt_form_best_practices_tip2"))
                .font(AdoptFont.regular(12))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0xECFDF5).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: 0x10B981).opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Live Listing Preview Card (iPad Real-time Dossier)

private struct AdoptLiveListingPreviewCard: View {
    @ObservedObject var store: AddAdoptPetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Live Preview Header Tag
            HStack {
                Circle()
                    .fill(Color(hex: 0x10B981))
                    .frame(width: 8, height: 8)
                Text(PPAdoptLang("adopt_form_live_preview_title"))
                    .font(AdoptFont.bold(13))
                    .foregroundColor(Color(hex: 0x065F46))

                Spacer()

                Text(PPAdoptLang("adopt_form_trust_badge"))
                    .font(AdoptFont.medium(11))
                    .foregroundColor(Color(hex: 0x059669))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: 0xD1FAE5))

            // Hero Media Preview
            ZStack(alignment: .bottomLeading) {
                if let firstItem = store.mediaItems.first {
                    if let img = firstItem.image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else if let urlStr = firstItem.remoteURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(height: 200)
                        .clipped()
                    }
                } else {
                    ZStack {
                        Color(UIColor.tertiarySystemGroupedBackground)
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text(PPAdoptLang("adopt_form_media_studio_subtitle"))
                                .font(AdoptFont.medium(12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 200)
                }

                // Media Count Pill
                if !store.mediaItems.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 11))
                        Text("\(store.mediaItems.count)")
                            .font(AdoptFont.bold(12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(12)
                }
            }

            // Pet Information Dossier
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.hasName ? store.name : PPAdoptLang("adopt_form_pet_name_placeholder"))
                        .font(AdoptFont.bold(18))
                        .foregroundColor(store.hasName ? .primary : .secondary)

                    Spacer()

                    if let kind = store.selectedKind {
                        Text(kind.kindNameAr ?? "")
                            .font(AdoptFont.bold(12))
                            .foregroundColor(Color(hex: 0xC41E3A))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: 0xC41E3A).opacity(0.12)))
                    }
                }

                // Traits Pills (Species, Breed, Age, Gender, City / Area)
                HStack(spacing: 6) {
                    if let kind = store.selectedKind {
                        previewTraitPill(icon: PPKindIcon(for: kind.localizedName), text: kind.localizedName)
                    }
                    if let breed = store.selectedBreed {
                        previewTraitPill(icon: "tag.fill", text: breed.localizedName)
                    }
                    if store.hasAge {
                        previewTraitPill(icon: "calendar", text: PPAdoptFormattedAge(months: store.ageMonths))
                    }
                    if store.hasGender {
                        previewTraitPill(icon: store.selectedGender.lowercased() == "female" ? "figure.stand.dress" : "figure.stand", text: store.selectedGender.lowercased() == "male" ? PPAdoptLang("adopt_form_gender_male") : PPAdoptLang("adopt_form_gender_female"))
                    }
                    if let city = store.selectedCity {
                        let locText = store.selectedArea.map { "\($0.localizedName)، \(city.localizedName)" } ?? city.localizedName
                        previewTraitPill(icon: "mappin.circle.fill", text: locText)
                    }
                }

                if !store.details.isEmpty {
                    Text(store.details)
                        .font(AdoptFont.regular(13))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func previewTraitPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(text)
                .font(AdoptFont.medium(11))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Readiness Radar Card (iPad Checkpoints)

private struct AdoptReadinessRadarCard: View {
    @ObservedObject var store: AddAdoptPetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(PPAdoptLang("adopt_form_readiness_radar_title"))
                    .font(AdoptFont.bold(15))
                    .foregroundColor(.primary)

                Spacer()

                Text(String(format: PPAdoptLang("adopt_form_readiness_complete"), store.completedCheckpointsCount))
                    .font(AdoptFont.bold(13))
                    .foregroundColor(store.isFormReadyToSubmit ? Color(hex: 0x059669) : Color(hex: 0xC41E3A))
            }

            // Segmented Progress Bar
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        .frame(height: 6)

                    Capsule()
                        .fill(store.isFormReadyToSubmit ? Color(hex: 0x10B981) : Color(hex: 0xC41E3A))
                        .frame(width: w * CGFloat(store.readinessFraction), height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.readinessFraction)
                }
            }
            .frame(height: 6)

            // Checklist Items
            VStack(spacing: 7) {
                radarCheckRow(title: PPAdoptLang("adopt_form_check_name"), isComplete: store.hasName)
                radarCheckRow(title: PPAdoptLang("adopt_form_check_species"), isComplete: store.hasKind)
                radarCheckRow(title: PPAdoptLang("adopt_form_check_breed"), isComplete: store.hasBreed)
                radarCheckRow(title: PPAdoptLang("adopt_form_check_age"), isComplete: store.hasAge)
                radarCheckRow(title: PPAdoptLang("adopt_form_check_gender"), isComplete: store.hasGender)
                radarCheckRow(title: PPAdoptLang("adopt_form_check_city"), isComplete: store.hasCity)
                if !store.availableAreas.isEmpty {
                    radarCheckRow(title: PPAdoptLang("adopt_form_check_area"), isComplete: store.hasArea)
                }
                radarCheckRow(title: PPAdoptLang("adopt_form_check_media"), isComplete: store.hasMedia)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private func radarCheckRow(title: String, isComplete: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isComplete ? Color(hex: 0x10B981) : .secondary.opacity(0.6))

            Text(title)
                .font(AdoptFont.medium(12))
                .foregroundColor(isComplete ? .primary : .secondary)

            Spacer()
        }
    }
}

// MARK: - Media Thumbnail Card

private struct AdoptMediaThumbnailCard: View {
    let item: AdoptMediaItem
    let isCover: Bool
    var onMakeCover: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Media Content
            Group {
                if let img = item.image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let urlStr = item.remoteURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                } else if item.assetID != nil {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: item.isVideo ? "video.badge.checkmark" : "photo.badge.checkmark")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 105, height: 120)
            .clipped()
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isCover ? Color(hex: 0xC41E3A) : Color.primary.opacity(0.06), lineWidth: isCover ? 2 : 1)
            )

            // Video Indicator
            if item.isVideo {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .offset(x: -8, y: 8)
            }

            // Cover Badge
            if isCover {
                Text(PPAdoptLang("adopt_form_media_primary_badge"))
                    .font(AdoptFont.bold(10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: 0xC41E3A)))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.black.opacity(0.65)))
            }
            .padding(6)
        }
    }
}

// MARK: - Species Picker Bottom Sheet

private struct AdoptSpeciesPickerSheet: View {
    let kinds: [MainKindsModel]
    @Binding var selectedKind: MainKindsModel?
    @Binding var selectedBreed: SubKindModel?
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""

    var filteredKinds: [MainKindsModel] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return kinds
        }
        return kinds.filter {
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            ($0.kindNameAr ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.kindNameEn ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(PPAdoptLang("adopt_form_search_species"), text: $searchText)
                        .font(AdoptFont.medium(15))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

                List(filteredKinds, id: \.id) { kind in
                    let isSelected = selectedKind?.id == kind.id
                    Button(action: {
                        if selectedKind?.id != kind.id {
                            selectedKind = kind
                            selectedBreed = nil
                        }
                        AdoptHaptics.selection()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color(hex: 0xC41E3A).opacity(0.12) : Color(UIColor.tertiarySystemGroupedBackground))
                                    .frame(width: 36, height: 36)
                                Image(systemName: PPKindIcon(for: kind.localizedName))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isSelected ? Color(hex: 0xC41E3A) : .secondary)
                            }

                            Text(kind.localizedName)
                                .font(isSelected ? AdoptFont.bold(16) : AdoptFont.medium(15))
                                .foregroundColor(.primary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xC41E3A))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(PPAdoptLang("adopt_form_select_species"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(AdoptFont.medium(15))
                }
            }
        }
    }
}

// MARK: - Breed Picker Bottom Sheet

private struct AdoptBreedPickerSheet: View {
    let breeds: [SubKindModel]
    @Binding var selectedBreed: SubKindModel?
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""

    var filteredBreeds: [SubKindModel] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return breeds
        }
        return breeds.filter {
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            ($0.subKindNameAr ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.subKindNameEn ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                if breeds.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(PPAdoptLang("adopt_form_no_breeds_available"))
                            .font(AdoptFont.medium(15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Search Field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(PPAdoptLang("adopt_form_search_breed"), text: $searchText)
                            .font(AdoptFont.medium(15))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    List(filteredBreeds, id: \.id) { breed in
                        let isSelected = selectedBreed?.id == breed.id
                        Button(action: {
                            selectedBreed = breed
                            AdoptHaptics.selection()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text(breed.localizedName)
                                    .font(isSelected ? AdoptFont.bold(16) : AdoptFont.medium(15))
                                    .foregroundColor(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: 0xC41E3A))
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(PPAdoptLang("adopt_form_select_breed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(AdoptFont.medium(15))
                }
            }
        }
    }
}

// MARK: - Gender Picker Bottom Sheet

private struct AdoptGenderPickerSheet: View {
    @Binding var selectedGender: String
    @Environment(\.presentationMode) private var presentationMode

    private struct GenderOption {
        let key: String
        let titleKey: String
        let icon: String
        let color: Color
    }

    private let options = [
        GenderOption(key: "Male", titleKey: "adopt_form_gender_male", icon: "figure.stand", color: Color(hex: 0x3B82F6)),
        GenderOption(key: "Female", titleKey: "adopt_form_gender_female", icon: "figure.stand.dress", color: Color(hex: 0xEC4899))
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ForEach(options, id: \.key) { opt in
                    let isSelected = selectedGender.lowercased() == opt.key.lowercased()
                    Button(action: {
                        selectedGender = opt.key
                        AdoptHaptics.selection()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(opt.color.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: opt.icon)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(opt.color)
                            }

                            Text(PPAdoptLang(opt.titleKey))
                                .font(isSelected ? AdoptFont.bold(17) : AdoptFont.medium(16))
                                .foregroundColor(.primary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(opt.color)
                            } else {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? opt.color.opacity(0.08) : Color(UIColor.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(isSelected ? opt.color : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                )
                                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
                        )
                    }
                    .buttonStyle(AdoptPressStyle())
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(PPAdoptLang("adopt_form_select_gender"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(AdoptFont.medium(15))
                }
            }
        }
    }
}

// MARK: - City Picker Bottom Sheet

private struct AdoptCityPickerSheet: View {
    let cities: [CityModel]
    @Binding var selectedCity: CityModel?
    @Binding var selectedArea: StateModel?
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""

    var filteredCities: [CityModel] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cities
        }
        return cities.filter {
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.arName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.enName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(PPAdoptLang("adopt_form_search_city"), text: $searchText)
                        .font(AdoptFont.medium(15))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

                List(filteredCities, id: \.cityID) { city in
                    let isSelected = selectedCity?.cityID == city.cityID
                    Button(action: {
                        if selectedCity?.cityID != city.cityID {
                            selectedCity = city
                            selectedArea = nil
                        }
                        AdoptHaptics.selection()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color(hex: 0xC41E3A).opacity(0.12) : Color(UIColor.tertiarySystemGroupedBackground))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(Color(hex: 0xC41E3A))
                                    .font(.system(size: 16))
                            }

                            Text(city.localizedName)
                                .font(isSelected ? AdoptFont.bold(16) : AdoptFont.medium(15))
                                .foregroundColor(.primary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: 0xC41E3A))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(PPAdoptLang("adopt_form_select_city"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(AdoptFont.medium(15))
                }
            }
        }
    }
}

// MARK: - Area / District Picker Bottom Sheet

private struct AdoptAreaPickerSheet: View {
    let areas: [StateModel]
    let cityName: String
    @Binding var selectedArea: StateModel?
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""

    var filteredAreas: [StateModel] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return areas
        }
        return areas.filter {
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            ($0.arName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.enName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                if areas.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(PPAdoptLang("adopt_form_no_areas_available"))
                            .font(AdoptFont.medium(15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Search Field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(PPAdoptLang("adopt_form_search_area"), text: $searchText)
                            .font(AdoptFont.medium(15))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    List(filteredAreas, id: \.stateID) { area in
                        let isSelected = selectedArea?.stateID == area.stateID
                        Button(action: {
                            selectedArea = area
                            AdoptHaptics.selection()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Color(hex: 0x10B981).opacity(0.12) : Color(UIColor.tertiarySystemGroupedBackground))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "building.2.crop.circle.fill")
                                        .foregroundColor(Color(hex: 0x10B981))
                                        .font(.system(size: 16))
                                }

                                Text(area.localizedName)
                                    .font(isSelected ? AdoptFont.bold(16) : AdoptFont.medium(15))
                                    .foregroundColor(.primary)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: 0x10B981))
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(cityName.isEmpty ? PPAdoptLang("adopt_form_select_area") : "\(PPAdoptLang("adopt_form_select_area")) (\(cityName))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(AdoptFont.medium(15))
                }
            }
        }
    }
}

// MARK: - PHPicker Photos Integration

private struct AdoptPhotoLibraryPicker: UIViewControllerRepresentable {
    var onSelect: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        // This intake surface intentionally exposes photo-library and camera
        // choices only. Keep its picker aligned with the visible contract and
        // its eight-item form capacity instead of silently dropping videos or
        // loading more images than the form can retain.
        config.selectionLimit = 8
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: AdoptPhotoLibraryPicker

        init(_ parent: AdoptPhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            var collectedImages: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let img = image as? UIImage {
                            DispatchQueue.main.async {
                                collectedImages.append(img)
                            }
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                self.parent.onSelect(collectedImages)
            }
        }
    }
}

// MARK: - Camera UIImagePickerController Integration

private struct AdoptCameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AdoptCameraPicker

        init(_ parent: AdoptCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            let img = info[.originalImage] as? UIImage
            parent.onCapture(img)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onCapture(nil)
        }
    }
}

private extension View {
    @ViewBuilder
    func hideScrollContentBackgroundCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

