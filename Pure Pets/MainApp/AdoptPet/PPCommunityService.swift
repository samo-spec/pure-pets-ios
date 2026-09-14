//
//  PPCommunityService.swift
//  Pure Pets
//
//  Canonical callable and moderated-media client for Community.
//  Firestore documents remain server-owned; this client never writes a
//  Community aggregate directly.
//

import CryptoKit
import FirebaseAuth
import FirebaseFunctions
import FirebaseStorage
import Foundation
import UIKit

enum PPCommunityError: LocalizedError {
    case invalidResponse
    case signInRequired
    case featureUnavailable
    case mediaRejected
    case mediaTooLarge
    case missingMedia

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return PPAdoptLang("community_error_invalid_response")
        case .signInRequired:
            return PPAdoptLang("community_error_sign_in_required")
        case .featureUnavailable:
            return PPAdoptLang("community_error_feature_unavailable")
        case .mediaRejected:
            return PPAdoptLang("community_error_media_rejected")
        case .mediaTooLarge:
            return PPAdoptLang("community_error_media_too_large")
        case .missingMedia:
            return PPAdoptLang("community_error_media_required")
        }
    }
}

struct PPCommunityQuestionOption: Identifiable, Equatable {
    let id: String
    let labelAr: String
    let labelEn: String

    init?(dictionary: [String: Any]) {
        let identifier = (dictionary["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return nil }
        id = identifier
        labelAr = dictionary["labelAr"] as? String ?? ""
        labelEn = dictionary["labelEn"] as? String ?? ""
    }

    var localizedLabel: String {
        let preferred = Language.isRTL() ? labelAr : labelEn
        let fallback = Language.isRTL() ? labelEn : labelAr
        return preferred.isEmpty ? (fallback.isEmpty ? id : fallback) : preferred
    }
}

struct PPCommunityQuestion: Identifiable, Equatable {
    let id: String
    let labelAr: String
    let labelEn: String
    let type: String
    let required: Bool
    let options: [PPCommunityQuestionOption]

    init?(dictionary: [String: Any]) {
        let identifier = (dictionary["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return nil }
        id = identifier
        labelAr = dictionary["labelAr"] as? String ?? ""
        labelEn = dictionary["labelEn"] as? String ?? ""
        type = dictionary["type"] as? String ?? "text"
        required = dictionary["required"] as? Bool ?? false
        options = (dictionary["options"] as? [[String: Any]] ?? []).compactMap(PPCommunityQuestionOption.init)
    }

    var localizedLabel: String {
        let preferred = Language.isRTL() ? labelAr : labelEn
        let fallback = Language.isRTL() ? labelEn : labelAr
        return preferred.isEmpty ? (fallback.isEmpty ? id : fallback) : preferred
    }
}

struct PPCommunityConfiguration {
    let communityEnabled: Bool
    let adoptionEnabled: Bool
    let adoptionApplicationsEnabled: Bool
    let missingPetsEnabled: Bool
    let foundPetReportsEnabled: Bool
    let sightingsEnabled: Bool
    let matchingEnabled: Bool
    let messagingEnabled: Bool
    let organizationsEnabled: Bool
    let rolloutStage: String
    let rolloutAvailable: Bool
    let adoptionQuestions: [PPCommunityQuestion]

    init(dictionary: [String: Any]) {
        communityEnabled = dictionary["communityEnabled"] as? Bool ?? false
        adoptionEnabled = dictionary["adoptionEnabled"] as? Bool ?? false
        adoptionApplicationsEnabled = dictionary["adoptionApplicationsEnabled"] as? Bool ?? false
        missingPetsEnabled = dictionary["missingPetsEnabled"] as? Bool ?? false
        foundPetReportsEnabled = dictionary["foundPetReportsEnabled"] as? Bool ?? false
        sightingsEnabled = dictionary["sightingsEnabled"] as? Bool ?? false
        matchingEnabled = dictionary["matchingEnabled"] as? Bool ?? false
        messagingEnabled = dictionary["communityMessagingEnabled"] as? Bool ?? false
        organizationsEnabled = dictionary["organizationsEnabled"] as? Bool ?? false
        rolloutStage = dictionary["rolloutStage"] as? String ?? "internal"
        rolloutAvailable = dictionary["rolloutAvailable"] as? Bool ?? false
        let adoptionPolicy = dictionary["adoptionPolicy"] as? [String: Any] ?? [:]
        adoptionQuestions = (adoptionPolicy["questions"] as? [[String: Any]] ?? []).compactMap(PPCommunityQuestion.init)
    }
}

struct PPCommunityPage {
    let items: [[String: Any]]
    let nextCursor: String?
    let hasMore: Bool
    let featureDisabled: Bool
}

struct PPCommunityLostFoundPage {
    let missing: PPCommunityPage
    let found: PPCommunityPage
    let featureDisabled: Bool
}

struct PPCommunityAdoptionApplicationDetail {
    let item: [String: Any]
    /// This is presentation metadata only. The callable remains the source of
    /// truth for every transition and validates the actor again in its
    /// transaction.
    let accessRole: String
}

struct PPCommunityMediaSource {
    let data: Data
    let contentType: String

    init(image: UIImage) throws {
        guard let encoded = image.jpegData(compressionQuality: 0.88), !encoded.isEmpty else {
            throw PPCommunityError.missingMedia
        }
        data = encoded
        contentType = "image/jpeg"
    }

    init(videoURL: URL) throws {
        data = try Data(contentsOf: videoURL, options: [.mappedIfSafe])
        let ext = videoURL.pathExtension.lowercased()
        contentType = ext == "mov" ? "video/quicktime" : "video/mp4"
    }

    init(data: Data, contentType: String) throws {
        guard !data.isEmpty else { throw PPCommunityError.missingMedia }
        self.data = data
        self.contentType = contentType
    }

    var sha256: String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct PPCommunityMediaResult {
    let assetIDs: [String]
    let requiresManualReview: Bool
}

private enum PPCommunityMediaLimits {
    static let maximumAssetCount = 8
    static let maximumVideoCount = 1
    static let maximumSessionBytes = 80 * 1024 * 1024
}

/// Persists only an opaque request fingerprint and command identifier. If a
/// request times out after the server commits, a retry (including after app
/// relaunch) reuses the same command ID and receives the original receipt.
private final class PPCommunityCommandLedger {
    static let shared = PPCommunityCommandLedger()
    private let defaultsKey = "pp.community.pending-command-ledger.v1"
    private let lock = NSLock()
    private let maximumAge: TimeInterval = 7 * 24 * 60 * 60

    func commandID(callable: String, uid: String, payload: [String: Any], prefix: String) -> (key: String, id: String) {
        var normalized = payload
        normalized.removeValue(forKey: "commandId")
        let body = (try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])) ?? Data()
        var fingerprintInput = Data("\(uid)|\(callable)|".utf8)
        fingerprintInput.append(body)
        let key = SHA256.hash(data: fingerprintInput).map { String(format: "%02x", $0) }.joined()

        lock.lock()
        defer { lock.unlock() }
        let now = Date().timeIntervalSince1970
        var ledger = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Any]] ?? [:]
        ledger = ledger.filter { now - (($0.value["createdAt"] as? NSNumber)?.doubleValue ?? now) < maximumAge }
        if let existing = ledger[key]?["commandId"] as? String, !existing.isEmpty {
            UserDefaults.standard.set(ledger, forKey: defaultsKey)
            return (key, existing)
        }
        let safePrefix = prefix.lowercased().replacingOccurrences(of: "_", with: "-")
        let commandID = "ios-\(safePrefix)-\(UUID().uuidString.lowercased())"
        ledger[key] = ["commandId": commandID, "createdAt": now]
        UserDefaults.standard.set(ledger, forKey: defaultsKey)
        return (key, commandID)
    }

    func complete(key: String) {
        lock.lock()
        defer { lock.unlock() }
        var ledger = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [String: Any]] ?? [:]
        ledger.removeValue(forKey: key)
        UserDefaults.standard.set(ledger, forKey: defaultsKey)
    }
}

private typealias SystemISO8601DateFormatter = Foundation.ISO8601DateFormatter

final class PPCommunityService {
    static let shared = PPCommunityService()

    private let functions = Functions.functions(region: "us-central1")
    private let storage = Storage.storage()
    private let iso8601: SystemISO8601DateFormatter = {
        let formatter = SystemISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    func call(_ name: String, payload: [String: Any], timeout: TimeInterval = 30) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            let callable = functions.httpsCallable(name)
            callable.timeoutInterval = timeout
            callable.call(payload) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let dictionary = result?.data as? [String: Any] else {
                    continuation.resume(throwing: PPCommunityError.invalidResponse)
                    return
                }
                continuation.resume(returning: dictionary)
            }
        }
    }

    func configuration() async throws -> PPCommunityConfiguration {
        let result = try await call("communityBrowse", payload: ["action": "configuration"])
        return PPCommunityConfiguration(dictionary: result["configuration"] as? [String: Any] ?? [:])
    }

    func browseAdoption(
        query: String = "",
        filters: [String: Any] = [:],
        cursor: String? = nil,
        limit: Int = 24
    ) async throws -> PPCommunityPage {
        var payload: [String: Any] = [
            "action": "adoption_discovery",
            "query": String(query.prefix(120)),
            "filters": filters,
            "limit": min(max(limit, 1), 50)
        ]
        if let cursor, !cursor.isEmpty { payload["cursor"] = cursor }
        let result = try await call("communityBrowse", payload: payload)
        return page(from: result)
    }

    func browseLostFound(
        query: String = "",
        filters: [String: Any] = [:],
        missingCursor: String? = nil,
        foundCursor: String? = nil,
        includeMissing: Bool = true,
        includeFound: Bool = true,
        limit: Int = 24
    ) async throws -> PPCommunityLostFoundPage {
        var payload: [String: Any] = [
            "action": "missing_discovery",
            "query": String(query.prefix(120)),
            "filters": filters,
            "includeMissing": includeMissing,
            "includeFound": includeFound,
            "limit": min(max(limit, 1), 50)
        ]
        if let missingCursor, !missingCursor.isEmpty { payload["missingCursor"] = missingCursor }
        if let foundCursor, !foundCursor.isEmpty { payload["foundCursor"] = foundCursor }
        let result = try await call("communityBrowse", payload: payload)
        let missing = page(from: result["missing"] as? [String: Any] ?? [:])
        let found = page(from: result["found"] as? [String: Any] ?? [:])
        return PPCommunityLostFoundPage(
            missing: missing,
            found: found,
            featureDisabled: result["featureDisabled"] as? Bool ?? false
        )
    }

    func detail(action: String, id: String) async throws -> [String: Any] {
        let result = try await call("communityBrowse", payload: ["action": action, "id": id])
        guard let item = result["item"] as? [String: Any] else {
            throw PPCommunityError.invalidResponse
        }
        var enriched = item
        if let sightings = result["sightings"] as? [[String: Any]] {
            enriched["sightings"] = sightings
        }
        return enriched
    }

    func matchDetail(id: String) async throws -> [String: Any] {
        try await detail(action: "match_detail", id: id)
    }

    func adoptionApplicationDetail(id: String) async throws -> PPCommunityAdoptionApplicationDetail {
        let result = try await call("communityBrowse", payload: ["action": "adoption_application_detail", "id": id])
        guard let item = result["item"] as? [String: Any] else {
            throw PPCommunityError.invalidResponse
        }
        let role = (result["accessRole"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["applicant", "listing_owner", "organization_operator"].contains(role) else {
            throw PPCommunityError.invalidResponse
        }
        return PPCommunityAdoptionApplicationDetail(item: item, accessRole: role)
    }

    func activity() async throws -> [String: [[String: Any]]] {
        let result = try await call("communityBrowse", payload: ["action": "my_activity", "limit": 50])
        guard let activity = result["activity"] as? [String: Any] else {
            throw PPCommunityError.invalidResponse
        }
        var mapped: [String: [[String: Any]]] = [:]
        for (key, value) in activity {
            mapped[key] = value as? [[String: Any]] ?? []
        }
        return mapped
    }

    func savedItems() async throws -> [[String: Any]] {
        let result = try await call("communityBrowse", payload: ["action": "saved", "limit": 50])
        return result["items"] as? [[String: Any]] ?? []
    }

    func organizations() async throws -> [[String: Any]] {
        let result = try await call("communityBrowse", payload: ["action": "organizations", "limit": 50])
        if result["featureDisabled"] as? Bool == true { throw PPCommunityError.featureUnavailable }
        return result["items"] as? [[String: Any]] ?? []
    }

    func uploadMedia(
        _ sources: [PPCommunityMediaSource],
        contextType: String,
        contextID: String
    ) async throws -> PPCommunityMediaResult {
        guard !sources.isEmpty else { throw PPCommunityError.missingMedia }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw PPCommunityError.signInRequired
        }
        guard sources.count <= PPCommunityMediaLimits.maximumAssetCount else { throw PPCommunityError.mediaTooLarge }
        let videoCount = sources.filter { $0.contentType.hasPrefix("video/") }.count
        let totalBytes = sources.reduce(0) { $0 + $1.data.count }
        guard videoCount <= PPCommunityMediaLimits.maximumVideoCount,
              totalBytes <= PPCommunityMediaLimits.maximumSessionBytes else {
            throw PPCommunityError.mediaTooLarge
        }
        for source in sources {
            let maximum = source.contentType.hasPrefix("video/") ? (60 * 1024 * 1024) - 1 : (12 * 1024 * 1024) - 1
            guard source.data.count > 0, source.data.count <= maximum else {
                throw PPCommunityError.mediaTooLarge
            }
        }

        let descriptors = sources.map {
            ["contentType": $0.contentType, "byteSize": $0.data.count, "sha256": $0.sha256] as [String: Any]
        }
        let prepared = try await command(
            "prepareCommunityMediaUpload",
            payload: [
                "contextType": contextType,
                "contextId": contextID,
                "media": descriptors
            ],
            prefix: "media-prepare"
        )
        guard let sessionID = prepared["sessionId"] as? String,
              let remoteAssets = prepared["assets"] as? [[String: Any]],
              remoteAssets.count == sources.count else {
            throw PPCommunityError.invalidResponse
        }

        for index in sources.indices {
            let source = sources[index]
            let remote = remoteAssets[index]
            guard let assetID = remote["assetId"] as? String,
                  let storagePath = remote["storagePath"] as? String else {
                throw PPCommunityError.invalidResponse
            }
            let metadata = StorageMetadata()
            metadata.contentType = source.contentType
            metadata.customMetadata = [
                "owner_uid": uid,
                "asset_id": assetID,
                "session_id": sessionID,
                "content_sha256": source.sha256
            ]
            try await put(source.data, at: storage.reference(withPath: storagePath), metadata: metadata)
        }

        let finalized = try await command(
            "finalizeCommunityMediaUpload",
            payload: ["sessionId": sessionID],
            prefix: "media-finalize",
            timeout: 180
        )
        if finalized["rejected"] as? Bool == true { throw PPCommunityError.mediaRejected }
        let assets = finalized["assets"] as? [[String: Any]] ?? []
        let assetIDs = assets.compactMap { $0["assetId"] as? String }
        guard assetIDs.count == sources.count else { throw PPCommunityError.invalidResponse }
        return PPCommunityMediaResult(
            assetIDs: assetIDs,
            requiresManualReview: finalized["requiresManualReview"] as? Bool ?? false
        )
    }

    func saveAdoptionListingDraft(payload: [String: Any]) async throws -> [String: Any] {
        try await command("saveAdoptionListingDraft", payload: payload, prefix: "adoption-draft")
    }

    func submitAdoptionListing(payload: [String: Any]) async throws -> [String: Any] {
        try await command("createAdoptionListing", payload: payload, prefix: "adoption-submit")
    }

    func updateAdoptionListing(payload: [String: Any]) async throws -> [String: Any] {
        try await command("updateAdoptionListing", payload: payload, prefix: "adoption-update")
    }

    func submitAdoptionApplication(listingID: String, expectedVersion: Int, message: String, answers: [String: String], questionAnswers: [String: Any] = [:]) async throws -> [String: Any] {
        try await command(
            "submitAdoptionApplication",
            payload: [
                "listingId": listingID,
                "expectedVersion": expectedVersion,
                "message": message,
                "answers": answers,
                "questionAnswers": questionAnswers
            ],
            prefix: "application-submit"
        )
    }

    func saveAdoptionApplicationDraft(listingID: String, expectedVersion: Int, message: String, answers: [String: String], questionAnswers: [String: Any] = [:]) async throws -> [String: Any] {
        try await command(
            "saveAdoptionApplicationDraft",
            payload: [
                "listingId": listingID,
                "expectedVersion": expectedVersion,
                "message": message,
                "answers": answers,
                "questionAnswers": questionAnswers
            ],
            prefix: "application-draft"
        )
    }

    func transitionAdoptionApplication(
        applicationID: String,
        expectedVersion: Int,
        action: String,
        reason: String = ""
    ) async throws -> [String: Any] {
        try await command(
            "transitionAdoptionApplication",
            payload: [
                "applicationId": applicationID,
                "expectedVersion": expectedVersion,
                "action": action,
                "reason": reason
            ],
            prefix: "application-transition"
        )
    }

    func createMissingCase(payload: [String: Any]) async throws -> [String: Any] {
        try await command("createMissingPetCase", payload: payload, prefix: "missing-create")
    }

    func createFoundReport(payload: [String: Any]) async throws -> [String: Any] {
        try await command("createFoundPetReport", payload: payload, prefix: "found-create")
    }

    func submitSighting(payload: [String: Any]) async throws -> [String: Any] {
        try await command("submitPetSighting", payload: payload, prefix: "sighting-create")
    }

    func transition(_ callable: String, payload: [String: Any], prefix: String) async throws -> [String: Any] {
        try await command(callable, payload: payload, prefix: prefix)
    }

    func setSaved(_ saved: Bool, targetType: String, targetID: String) async throws -> Bool {
        let result = try await command(
            "communitySavedItemCommand",
            payload: ["action": saved ? "save" : "remove", "targetType": targetType, "targetId": targetID],
            prefix: saved ? "save" : "unsave"
        )
        return result["saved"] as? Bool ?? saved
    }

    func report(targetType: String, targetID: String, reason: String, details: String) async throws {
        _ = try await command(
            "submitCommunityReport",
            payload: ["targetType": targetType, "targetId": targetID, "reason": reason, "details": details],
            prefix: "report"
        )
    }

    func isoString(_ date: Date) -> String {
        iso8601.string(from: date)
    }

    func commandID(prefix: String) -> String {
        let safePrefix = prefix.lowercased().replacingOccurrences(of: "_", with: "-")
        return "ios-\(safePrefix)-\(UUID().uuidString.lowercased())"
    }

    func primaryImageURL(in item: [String: Any]) -> URL? {
        if let media = item["media"] as? [[String: Any]] {
            for asset in media {
                let variants = asset["variants"] as? [String: Any] ?? [:]
                for key in ["card", "detail", "thumbnail", "fullScreen"] {
                    if let variant = variants[key] as? [String: Any],
                       let rawURL = variant["url"] as? String,
                       let url = URL(string: rawURL) {
                        return url
                    }
                }
            }
        }
        if let pet = item["pet"] as? [String: Any],
           let rawURL = pet["imageURL"] as? String {
            return URL(string: rawURL)
        }
        return nil
    }

    private func page(from dictionary: [String: Any]) -> PPCommunityPage {
        PPCommunityPage(
            items: dictionary["items"] as? [[String: Any]] ?? [],
            nextCursor: dictionary["nextCursor"] as? String,
            hasMore: dictionary["hasMore"] as? Bool ?? false,
            featureDisabled: dictionary["featureDisabled"] as? Bool ?? false
        )
    }

    private func command(_ callable: String, payload: [String: Any], prefix: String, timeout: TimeInterval = 30) async throws -> [String: Any] {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { throw PPCommunityError.signInRequired }
        var request = payload
        if request["commandId"] != nil { return try await call(callable, payload: request, timeout: timeout) }
        let pending = PPCommunityCommandLedger.shared.commandID(callable: callable, uid: uid, payload: payload, prefix: prefix)
        request["commandId"] = pending.id
        let result = try await call(callable, payload: request, timeout: timeout)
        PPCommunityCommandLedger.shared.complete(key: pending.key)
        return result
    }

    private func put(_ data: Data, at reference: StorageReference, metadata: StorageMetadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putData(data, metadata: metadata) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}
