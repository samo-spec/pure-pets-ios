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

    // 6-State Status
    @Published var isSubmitting: Bool = false
    @Published var submissionStepText: String = ""
    @Published var errorMessage: String? = nil
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

    // Persistence Keys
    private let draftPrefix = "pp.add_adopt_pet.draft"
    private var draftDefaultsKey: String {
        let uid = UserManager.shared().currentUser?.id ?? "guest"
        if let editingDocID = editingPet?.documentID, !editingDocID.isEmpty {
            return "\(draftPrefix).edit.\(editingDocID).\(uid)"
        }
        return "\(draftPrefix).create.\(uid)"
    }

    private var creationIdentityDefaultsKey: String {
        let uid = UserManager.shared().currentUser?.id ?? "guest"
        return "\(draftPrefix).create-identity.\(uid)"
    }

    init(pet: AdoptPetModel? = nil) {
        self.editingPet = pet
        if let existingID = pet?.documentID, !existingID.isEmpty {
            self.creationListingID = existingID
        } else {
            let uid = UserManager.shared().currentUser?.id ?? "guest"
            let identityKey = "pp.add_adopt_pet.draft.create-identity.\(uid)"
            let persisted = UserDefaults.standard.string(forKey: identityKey)
            self.creationListingID = (persisted?.isEmpty == false ? persisted : nil) ?? UUID().uuidString.lowercased()
            UserDefaults.standard.set(self.creationListingID, forKey: identityKey)
        }
        loadDomainData()
        if pet != nil {
            hydrateFromEditingPet()
        } else {
            checkAndRestoreDraft()
        }
    }

    // MARK: - Domain Data

    func loadDomainData() {
        if let kinds = MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel] {
            self.availableKinds = kinds
        } else {
            self.availableKinds = []
        }

        if let cities = CitiesManager.shared().citiesForCurrentCountry() as? [CityModel] {
            self.availableCities = cities
        } else {
            self.availableCities = []
        }
    }

    var availableBreeds: [SubKindModel] {
        guard let kind = selectedKind else { return [] }
        return (kind.subKindsArray as? [SubKindModel]) ?? []
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

        // Find City
        if let cityMatch = availableCities.first(where: { $0.cityID == pet.cityID }) {
            self.selectedCity = cityMatch
        } else if pet.cityID > 0 {
            self.selectedCity = CitiesManager.shared().city(byID: pet.cityID)
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
        guard let data = UserDefaults.standard.dictionary(forKey: draftDefaultsKey) else {
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
        }

        // Restore cached local images
        if let paths = data["imagePaths"] as? [String] {
            let assetIDs = data["imageAssetIDs"] as? [String] ?? []
            var restoredItems: [AdoptMediaItem] = []
            for (index, path) in paths.enumerated() {
                if FileManager.default.fileExists(atPath: path),
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

    private func persistDraft(showSuccessFeedback: Bool) {
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

        // Cache local images
        let tempDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("AdoptPetDrafts")
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        var imagePaths: [String] = []
        var imageAssetIDs: [String] = []
        for (idx, item) in mediaItems.enumerated() {
            if let img = item.image, let pngData = img.jpegData(compressionQuality: 0.75) {
                let filePath = (tempDir as NSString).appendingPathComponent("draft_\(idx).jpg")
                try? pngData.write(to: URL(fileURLWithPath: filePath))
                imagePaths.append(filePath)
                imageAssetIDs.append(item.assetID ?? "")
            }
        }
        dict["imagePaths"] = imagePaths
        dict["imageAssetIDs"] = imageAssetIDs

        UserDefaults.standard.set(dict, forKey: draftDefaultsKey)
        if !isEditing { UserDefaults.standard.set(creationListingID, forKey: creationIdentityDefaultsKey) }
        hasSavedDraft = true
        if showSuccessFeedback { AdoptHaptics.success() }
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftDefaultsKey)
        if !isEditing { UserDefaults.standard.removeObject(forKey: creationIdentityDefaultsKey) }
        hasSavedDraft = false
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

    var hasMedia: Bool {
        !mediaItems.isEmpty
    }

    var hasAdoptionReason: Bool {
        !adoptionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasDetails: Bool {
        !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var completedCheckpointsCount: Int {
        var count = 0
        if hasName { count += 1 }
        if hasKind { count += 1 }
        if hasBreed { count += 1 }
        if hasAge { count += 1 }
        if hasGender { count += 1 }
        if hasCity { count += 1 }
        if hasMedia { count += 1 }
        if hasDetails { count += 1 }
        if hasAdoptionReason { count += 1 }
        return count
    }

    var isFormReadyToSubmit: Bool {
        completedCheckpointsCount == 9
    }

    var readinessFraction: Double {
        Double(completedCheckpointsCount) / 9.0
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

        isSubmitting = true
        errorMessage = nil
        submissionStepText = isEditing ? PPAdoptLang("adopt_form_save_changes") : PPAdoptLang("adopt_form_publish_action")

        let listingID = editingPet?.documentID.isEmpty == false ? editingPet!.documentID : creationListingID
        let petID = editingPet?.petID.isEmpty == false ? editingPet!.petID : listingID

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
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

                let cityName = self.selectedCity?.name ?? self.selectedCity?.enName ?? ""
                let countryCode = self.selectedCity?.country?.iso ?? self.selectedCity?.country?.countryCode ?? CountryModel.safeCurrentCountryISOCode() ?? ""
                let payload: [String: Any] = [
                    "listingId": listingID,
                    "petId": petID,
                    "expectedVersion": self.editingPet?.version ?? 0,
                    "title": self.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "description": self.details.trimmingCharacters(in: .whitespacesAndNewlines),
                    "adoptionReason": self.adoptionReason.trimmingCharacters(in: .whitespacesAndNewlines),
                    "requirements": [],
                    "location": ["countryCode": countryCode, "city": cityName, "district": ""],
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
                        "ageInMonths": self.ageMonths,
                        "gender": self.selectedGender.lowercased(),
                        "size": "",
                        "colors": [],
                        "distinctiveMarks": ""
                    ]
                ]

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
            self.errorMessage = error?.localizedDescription ?? PPAdoptLang("unknownError")
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

// MARK: - iPhone Architecture (`iPhoneAddAdoptPetDeck`)

private struct iPhoneAddAdoptPetDeck: View {
    @ObservedObject var store: AddAdoptPetStore
    var onDismiss: () -> Void
    var onSuccess: () -> Void

    @State private var showBreedPicker: Bool = false
    @State private var showCityPicker: Bool = false
    @State private var showMediaPickerSheet: Bool = false
    @State private var showPhotoLibrary: Bool = false
    @State private var showCamera: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Apex Navigation Header
            apexHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Mission Hero Card
                    missionHeroCard

                    // 1. Media Studio Tray
                    mediaStudioSection

                    // 2. Species Visual Cards
                    speciesSection

                    // 3. Identity & Breed
                    identitySection

                    // 4. Demographics (Age, Gender, City)
                    demographicsSection

                    // 5. Adoption Story & Notes
                    storySection

                    // Spacer for Floating Action Bar
                    Spacer().frame(height: 110)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .overlay(alignment: .bottom) {
            floatingActionDock
        }
        .sheet(isPresented: $showBreedPicker) {
            AdoptBreedPickerSheet(
                breeds: store.availableBreeds,
                selectedBreed: $store.selectedBreed
            )
        }
        .sheet(isPresented: $showCityPicker) {
            AdoptCityPickerSheet(
                cities: store.availableCities,
                selectedCity: $store.selectedCity
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

                Text(String(format: PPAdoptLang("adopt_form_progress_format"), store.completedCheckpointsCount, 8))
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

    // MARK: - Species Visual Section

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(PPAdoptLang("adopt_form_species_label"))
                    .font(AdoptFont.bold(16))
            } icon: {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.availableKinds, id: \.id) { kind in
                        let isSelected = store.selectedKind?.id == kind.id
                        Button(action: {
                            AdoptHaptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                store.selectedKind = kind
                            }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Color(hex: 0xC41E3A) : Color(UIColor.tertiarySystemGroupedBackground))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: kindIcon(for: kind))
                                        .font(.system(size: 22))
                                        .foregroundColor(isSelected ? .white : .primary)
                                }

                                Text(kind.kindNameAr ?? "")
                                    .font(isSelected ? AdoptFont.bold(14) : AdoptFont.medium(13))
                                    .foregroundColor(isSelected ? Color(hex: 0xC41E3A) : .primary)
                            }
                            .frame(width: 85, height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(isSelected ? Color(hex: 0xC41E3A).opacity(0.08) : Color(UIColor.secondarySystemGroupedBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(isSelected ? Color(hex: 0xC41E3A) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                    )
                            )
                        }
                        .buttonStyle(AdoptPressStyle())
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

    private func kindIcon(for kind: MainKindsModel) -> String {
        let name = (kind.kindNameAr ?? "").lowercased()
        if name.contains("قطط") || name.contains("cat") { return "cat.fill" }
        if name.contains("كلاب") || name.contains("dog") { return "dog.fill" }
        if name.contains("طيور") || name.contains("bird") { return "bird.fill" }
        if name.contains("أرانب") || name.contains("rabbit") { return "hare.fill" }
        if name.contains("أسماك") || name.contains("fish") { return "fish.fill" }
        return "pawprint.fill"
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
                Text(PPAdoptLang("adopt_form_pet_name_label"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

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

            // Breed Selector Chip
            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("adopt_form_breed_label"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                Button(action: {
                    if store.selectedKind == nil {
                        AdoptHaptics.error()
                        return
                    }
                    AdoptHaptics.selection()
                    showBreedPicker = true
                }) {
                    HStack {
                        Text(store.selectedBreed?.subKindNameAr ?? (store.selectedKind == nil ? PPAdoptLang("adopt_form_select_species") : PPAdoptLang("adopt_form_select_breed")))
                            .font(AdoptFont.bold(15))
                            .foregroundColor(store.selectedBreed == nil ? .secondary : .primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
                .buttonStyle(AdoptPressStyle())
                .disabled(store.selectedKind == nil)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - Demographics Section (Age, Gender, City)

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
                    Text(PPAdoptLang("adopt_form_age_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)

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

                    Text("\(store.ageMonths) " + PPAdoptLang("%ld Months"))
                        .font(AdoptFont.bold(15))
                        .frame(width: 120)

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

            // Gender Dual Cards
            VStack(alignment: .leading, spacing: 8) {
                Text(PPAdoptLang("adopt_form_gender_label"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    genderCard(
                        title: PPAdoptLang("adopt_form_gender_male"),
                        icon: "figure.walk",
                        value: "Male",
                        accent: Color(hex: 0x3B82F6)
                    )

                    genderCard(
                        title: PPAdoptLang("adopt_form_gender_female"),
                        icon: "heart.circle.fill",
                        value: "Female",
                        accent: Color(hex: 0xEC4899)
                    )
                }
            }

            Divider()

            // City Selector Chip
            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("adopt_form_city_label"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                Button(action: {
                    AdoptHaptics.selection()
                    showCityPicker = true
                }) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(Color(hex: 0xC41E3A))

                        Text(store.selectedCity?.name ?? PPAdoptLang("adopt_form_select_city"))
                            .font(AdoptFont.bold(15))
                            .foregroundColor(store.selectedCity == nil ? .secondary : .primary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                }
                .buttonStyle(AdoptPressStyle())
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

    private func genderCard(title: String, icon: String, value: String, accent: Color) -> some View {
        let isSelected = store.selectedGender.lowercased() == value.lowercased()
        return Button(action: {
            AdoptHaptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                store.selectedGender = value
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? accent : .secondary)

                Text(title)
                    .font(AdoptFont.bold(15))
                    .foregroundColor(isSelected ? accent : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color(UIColor.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? accent : Color.clear, lineWidth: 1.5)
                    )
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
                    Image(systemName: "quote.opening")
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                Spacer()

                Text("\(store.details.count) " + PPAdoptLang("characters"))
                    .font(AdoptFont.regular(12))
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $store.details)
                .font(AdoptFont.regular(15))
                .frame(minHeight: 110)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
                .overlay(alignment: .topLeading) {
                    if store.details.isEmpty {
                        Text(PPAdoptLang("adopt_form_story_placeholder"))
                            .font(AdoptFont.regular(14))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("community_adoption_reason_title"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                TextEditor(text: $store.adoptionReason)
                    .font(AdoptFont.regular(15))
                    .frame(minHeight: 82)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                    .overlay(alignment: .topLeading) {
                        if store.adoptionReason.isEmpty {
                            Text(PPAdoptLang("community_adoption_reason_placeholder"))
                                .font(AdoptFont.regular(14))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(PPAdoptLang("community_adoption_reason_title"))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - Floating Action Dock

    private var floatingActionDock: some View {
        VStack(spacing: 8) {
            if let err = store.errorMessage {
                Text(err)
                    .font(AdoptFont.bold(13))
                    .foregroundColor(Color(hex: 0xC41E3A))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(hex: 0xFFF1F2))
                    )
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
                                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(
                Rectangle()
                    .fill(Color(UIColor.systemBackground).opacity(0.88))
                    .background(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 16, y: -4)
            )
        }
    }

    private func formattedAge(months: Int) -> String {
        if months < 12 {
            return "\(months) " + PPAdoptLang("%ld Months")
        }
        let years = months / 12
        let rem = months % 12
        if rem == 0 {
            return "\(years) " + (years == 1 ? PPAdoptLang("Year") : PPAdoptLang("Years"))
        }
        return "\(years) " + PPAdoptLang("Year") + " & \(rem) " + PPAdoptLang("%ld Months")
    }
}

// MARK: - iPad Architecture (`iPadAddAdoptPetCockpit`)

private struct iPadAddAdoptPetCockpit: View {
    @ObservedObject var store: AddAdoptPetStore
    var onDismiss: () -> Void
    var onSuccess: () -> Void

    @State private var showBreedPicker: Bool = false
    @State private var showCityPicker: Bool = false
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
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
        }
        .sheet(isPresented: $showBreedPicker) {
            AdoptBreedPickerSheet(
                breeds: store.availableBreeds,
                selectedBreed: $store.selectedBreed
            )
        }
        .sheet(isPresented: $showCityPicker) {
            AdoptCityPickerSheet(
                cities: store.availableCities,
                selectedCity: $store.selectedCity
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
                Image(systemName: "pawprint.fill")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            // Species Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.availableKinds, id: \.id) { kind in
                        let isSelected = store.selectedKind?.id == kind.id
                        Button(action: {
                            AdoptHaptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                store.selectedKind = kind
                            }
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Color(hex: 0xC41E3A) : Color(UIColor.tertiarySystemGroupedBackground))
                                        .frame(width: 52, height: 52)

                                    Image(systemName: kindIcon(for: kind))
                                        .font(.system(size: 24))
                                        .foregroundColor(isSelected ? .white : .primary)
                                }

                                Text(kind.kindNameAr ?? "")
                                    .font(isSelected ? AdoptFont.bold(14) : AdoptFont.medium(13))
                                    .foregroundColor(isSelected ? Color(hex: 0xC41E3A) : .primary)
                            }
                            .frame(width: 95, height: 110)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(isSelected ? Color(hex: 0xC41E3A).opacity(0.08) : Color(UIColor.secondarySystemGroupedBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(isSelected ? Color(hex: 0xC41E3A) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                    )
                            )
                        }
                        .buttonStyle(AdoptPressStyle())
                        .hoverEffect(.highlight)
                    }
                }
            }

            HStack(spacing: 16) {
                // Name Field
                VStack(alignment: .leading, spacing: 6) {
                    Text(PPAdoptLang("adopt_form_pet_name_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)

                    TextField(PPAdoptLang("adopt_form_pet_name_placeholder"), text: $store.name)
                        .font(AdoptFont.bold(15))
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                }

                // Breed Selector
                VStack(alignment: .leading, spacing: 6) {
                    Text(PPAdoptLang("adopt_form_breed_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)

                    Button(action: {
                        if store.selectedKind != nil {
                            showBreedPicker = true
                        }
                    }) {
                        HStack {
                            Text(store.selectedBreed?.subKindNameAr ?? (store.selectedKind == nil ? PPAdoptLang("adopt_form_select_species") : PPAdoptLang("adopt_form_select_breed")))
                                .font(AdoptFont.bold(15))
                                .foregroundColor(store.selectedBreed == nil ? .secondary : .primary)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(AdoptPressStyle())
                    .hoverEffect(.highlight)
                    .disabled(store.selectedKind == nil)
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

    private func kindIcon(for kind: MainKindsModel) -> String {
        let name = (kind.kindNameAr ?? "").lowercased()
        if name.contains("قطط") || name.contains("cat") { return "cat.fill" }
        if name.contains("كلاب") || name.contains("dog") { return "dog.fill" }
        if name.contains("طيور") || name.contains("bird") { return "bird.fill" }
        if name.contains("أرانب") || name.contains("rabbit") { return "hare.fill" }
        return "pawprint.fill"
    }

    private var iPadDemographicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(PPAdoptLang("adopt_form_physical_title"))
                    .font(AdoptFont.bold(17))
            } icon: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(Color(hex: 0xC41E3A))
            }

            HStack(spacing: 20) {
                // Age Column
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(PPAdoptLang("adopt_form_age_label"))
                            .font(AdoptFont.medium(13))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(store.ageMonths) " + PPAdoptLang("%ld Months"))
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(PPAdoptLang("adopt_form_gender_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        iPadGenderCard(title: PPAdoptLang("adopt_form_gender_male"), value: "Male", accent: Color(hex: 0x3B82F6))
                        iPadGenderCard(title: PPAdoptLang("adopt_form_gender_female"), value: "Female", accent: Color(hex: 0xEC4899))
                    }
                }
                .frame(maxWidth: .infinity)

                // City Column
                VStack(alignment: .leading, spacing: 8) {
                    Text(PPAdoptLang("adopt_form_city_label"))
                        .font(AdoptFont.medium(13))
                        .foregroundColor(.secondary)

                    Button(action: { showCityPicker = true }) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(Color(hex: 0xC41E3A))
                            Text(store.selectedCity?.name ?? PPAdoptLang("adopt_form_select_city"))
                                .font(AdoptFont.bold(14))
                                .foregroundColor(store.selectedCity == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(AdoptPressStyle())
                    .hoverEffect(.highlight)
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

    private func iPadGenderCard(title: String, value: String, accent: Color) -> some View {
        let isSelected = store.selectedGender.lowercased() == value.lowercased()
        return Button(action: {
            AdoptHaptics.selection()
            store.selectedGender = value
        }) {
            Text(title)
                .font(AdoptFont.bold(14))
                .foregroundColor(isSelected ? accent : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.12) : Color(UIColor.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? accent : Color.clear, lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(AdoptPressStyle())
        .hoverEffect(.highlight)
    }

    private var iPadStorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text(PPAdoptLang("adopt_form_story_title"))
                        .font(AdoptFont.bold(17))
                } icon: {
                    Image(systemName: "quote.opening")
                        .foregroundColor(Color(hex: 0xC41E3A))
                }

                Spacer()

                Text("\(store.details.count) " + PPAdoptLang("characters"))
                    .font(AdoptFont.regular(13))
                    .foregroundColor(.secondary)
            }

            TextEditor(text: $store.details)
                .font(AdoptFont.regular(15))
                .frame(minHeight: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
                .overlay(alignment: .topLeading) {
                    if store.details.isEmpty {
                        Text(PPAdoptLang("adopt_form_story_placeholder"))
                            .font(AdoptFont.regular(14))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("community_adoption_reason_title"))
                    .font(AdoptFont.medium(13))
                    .foregroundColor(.secondary)

                TextEditor(text: $store.adoptionReason)
                    .font(AdoptFont.regular(15))
                    .frame(minHeight: 92)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
                    .overlay(alignment: .topLeading) {
                        if store.adoptionReason.isEmpty {
                            Text(PPAdoptLang("community_adoption_reason_placeholder"))
                                .font(AdoptFont.regular(14))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(PPAdoptLang("community_adoption_reason_title"))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        )
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

                // Traits Pills (Breed, Age, Gender, City)
                HStack(spacing: 6) {
                    if let breed = store.selectedBreed {
                        previewTraitPill(icon: "tag.fill", text: breed.subKindNameAr ?? "")
                    }
                    if store.hasAge {
                        previewTraitPill(icon: "calendar", text: "\(store.ageMonths) " + PPAdoptLang("%ld Months"))
                    }
                    if store.hasGender {
                        previewTraitPill(icon: "heart.fill", text: store.selectedGender == "Male" ? PPAdoptLang("adopt_form_gender_male") : PPAdoptLang("adopt_form_gender_female"))
                    }
                    if let city = store.selectedCity {
                        previewTraitPill(icon: "mappin.circle.fill", text: city.name ?? "")
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

// MARK: - Readiness Radar Card (iPad 7 Checkpoints)

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
            ($0.subKindNameAr ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.subKindNameEn ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(PPAdoptLang("adopt_form_search_breed"), text: $searchText)
                        .font(AdoptFont.medium(15))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

                List(filteredBreeds, id: \.id) { breed in
                    Button(action: {
                        selectedBreed = breed
                        AdoptHaptics.selection()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(breed.subKindNameAr ?? "")
                                .font(AdoptFont.bold(15))
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedBreed?.id == breed.id {
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

// MARK: - City Picker Bottom Sheet

private struct AdoptCityPickerSheet: View {
    let cities: [CityModel]
    @Binding var selectedCity: CityModel?
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText: String = ""

    var filteredCities: [CityModel] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cities
        }
        return cities.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.arName ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.enName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(PPAdoptLang("adopt_form_search_city"), text: $searchText)
                        .font(AdoptFont.medium(15))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)

                List(filteredCities, id: \.cityID) { city in
                    Button(action: {
                        selectedCity = city
                        AdoptHaptics.selection()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color(hex: 0xC41E3A))

                            Text(city.name ?? "")
                                .font(AdoptFont.bold(15))
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedCity?.cityID == city.cityID {
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

// MARK: - PHPicker Photos Integration

private struct AdoptPhotoLibraryPicker: UIViewControllerRepresentable {
    var onSelect: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 15
        config.filter = .any(of: [.images, .videos])
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
