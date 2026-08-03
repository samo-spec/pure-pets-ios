import Foundation

struct PPPetAdTrustJourneyFact: Identifiable, Equatable {
    let id: String
    let symbol: String
    let label: String
    let value: String
}

enum PPPetAdTrustEvidenceKind: Equatable {
    case verified
    case reviewed
    case provided
    case attention
}

struct PPPetAdTrustEvidence: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
    let kind: PPPetAdTrustEvidenceKind
}

struct PPPetAdDecisionPrompt: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
}

struct PPPetAdTrustJourneyModel {
    let facts: [PPPetAdTrustJourneyFact]
    let evidence: [PPPetAdTrustEvidence]
    let decisionPrompts: [PPPetAdDecisionPrompt]
    let story: String
    let sellerDisplayName: String
    let sellerAvatarURL: String?
    let isSellerVerified: Bool

    init(snapshot: PPPetAdViewerSnapshot, owner: PPPetAdOwner?) {
        story = snapshot.description
        facts = Self.makeFacts(snapshot: snapshot)
        evidence = Self.makeEvidence(snapshot: snapshot, owner: owner)
        decisionPrompts = Self.makeDecisionPrompts()
        sellerDisplayName = Self.sellerName(snapshot: snapshot, owner: owner)
        sellerAvatarURL = owner?.avatarURL
        isSellerVerified = owner?.isVerified == true
    }

    private static func makeFacts(
        snapshot: PPPetAdViewerSnapshot
    ) -> [PPPetAdTrustJourneyFact] {
        var values = makeCoreFacts(snapshot: snapshot)

        if values.count < 3 {
            let category = snapshot.subcategory.isEmpty
                ? snapshot.category
                : snapshot.subcategory
            appendFact(
                to: &values,
                id: "type",
                symbol: "pawprint.fill",
                label: text(
                    "pet_ad_trust_type_label",
                    fallback: "Type"
                ),
                value: category
            )
        }

        return Array(values.prefix(3))
    }

    private static func makeCoreFacts(
        snapshot: PPPetAdViewerSnapshot
    ) -> [PPPetAdTrustJourneyFact] {
        var values: [PPPetAdTrustJourneyFact] = []

        if hasLocation(snapshot.ad) {
            appendFact(
                to: &values,
                id: "location",
                symbol: "location.fill",
                label: text(
                    "pet_ad_trust_location_label",
                    fallback: "Location"
                ),
                value: snapshot.location
            )
        }
        if hasAge(snapshot.ad) {
            appendFact(
                to: &values,
                id: "age",
                symbol: "calendar",
                label: text(
                    "pet_ad_trust_age_label",
                    fallback: "Age"
                ),
                value: snapshot.age
            )
        }
        if hasExplicitGender(snapshot.ad) {
            appendFact(
                to: &values,
                id: "gender",
                symbol: "circle.lefthalf.filled",
                label: text(
                    "pet_ad_viewer_sex_label",
                    fallback: "Sex"
                ),
                value: snapshot.gender
            )
        }
        return values
    }

    private static func appendFact(
        to values: inout [PPPetAdTrustJourneyFact],
        id: String,
        symbol: String,
        label: String,
        value: String
    ) {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty,
              !values.contains(where: { $0.value == trimmed }) else {
            return
        }
        values.append(
            PPPetAdTrustJourneyFact(
                id: id,
                symbol: symbol,
                label: label,
                value: trimmed
            )
        )
    }

    private static func makeEvidence(
        snapshot: PPPetAdViewerSnapshot,
        owner: PPPetAdOwner?
    ) -> [PPPetAdTrustEvidence] {
        var values: [PPPetAdTrustEvidence] = []

        if owner?.isVerified == true {
            values.append(
                PPPetAdTrustEvidence(
                    id: "seller-verified",
                    symbol: "checkmark.seal.fill",
                    title: text(
                        "pet_ad_trust_seller_verified",
                        fallback: "Advertiser identity verified"
                    ),
                    detail: text(
                        "pet_ad_trust_seller_verified_detail",
                        fallback:
                            "Pure Pets has verified this advertiser’s account."
                    ),
                    kind: .verified
                )
            )
        }

        if snapshot.ad.isApproved {
            values.append(
                PPPetAdTrustEvidence(
                    id: "listing-reviewed",
                    symbol: "checkmark.shield.fill",
                    title: text(
                        "pet_ad_trust_listing_reviewed",
                        fallback: "Listing reviewed"
                    ),
                    detail: text(
                        "pet_ad_trust_listing_reviewed_detail",
                        fallback:
                            "This listing passed platform moderation. "
                            + "This is not a veterinary certificate."
                    ),
                    kind: .reviewed
                )
            )
        }

        let suppliedCount = makeCoreFacts(snapshot: snapshot).count

        if suppliedCount > 0 {
            values.append(
                PPPetAdTrustEvidence(
                    id: "details-provided",
                    symbol: "doc.text.fill",
                    title: text(
                        "pet_ad_trust_details_provided",
                        fallback: "Core details supplied"
                    ),
                    detail: String(
                        format: text(
                            "pet_ad_trust_details_provided_detail",
                            fallback: "%d of 3 key details are available."
                        ),
                        suppliedCount
                    ),
                    kind: .provided
                )
            )
        }

        values.append(
            PPPetAdTrustEvidence(
                id: "health-records-missing",
                symbol: "cross.case.fill",
                title: text(
                    "pet_ad_trust_health_missing",
                    fallback: "Health records not attached"
                ),
                detail: text(
                    "pet_ad_trust_health_missing_detail",
                    fallback:
                        "Ask for vaccination, veterinary, and ownership documents before agreeing."
                ),
                kind: .attention
            )
        )

        return values
    }

    private static func makeDecisionPrompts() -> [PPPetAdDecisionPrompt] {
        [
            PPPetAdDecisionPrompt(
                id: "health",
                symbol: "heart.text.square.fill",
                title: text(
                    "pet_ad_trust_question_health",
                    fallback:
                        "Request the latest veterinary and vaccination records."
                )
            ),
            PPPetAdDecisionPrompt(
                id: "behavior",
                symbol: "pawprint.fill",
                title: text(
                    "pet_ad_trust_question_behavior",
                    fallback:
                        "Ask about behavior, routine, diet, and care needs."
                )
            ),
            PPPetAdDecisionPrompt(
                id: "handover",
                symbol: "person.2.fill",
                title: text(
                    "pet_ad_trust_question_handover",
                    fallback:
                        "Meet safely and verify ownership before payment."
                )
            )
        ]
    }

    private static func sellerName(
        snapshot: PPPetAdViewerSnapshot,
        owner: PPPetAdOwner?
    ) -> String {
        let loadedName = owner?.displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let loadedName, !loadedName.isEmpty {
            return loadedName
        }

        let listingName = snapshot.ad.ownerName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let listingTitle = snapshot.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let listingName,
           !listingName.isEmpty,
           listingName.caseInsensitiveCompare(listingTitle) != .orderedSame {
            return listingName
        }

        return text(
            "pet_ad_trust_seller_fallback",
            fallback: "Pure Pets advertiser"
        )
    }

    private static func text(_ key: String, fallback: String) -> String {
        PPPetAdLocalization.text(key, fallback: fallback)
    }

    private static func hasLocation(_ ad: PetAd) -> Bool {
        let name = ad.locationName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return ad.adLocation > 0
            || name?.isEmpty == false
            || ad.hasValidGeoLocation()
    }

    private static func hasAge(_ ad: PetAd) -> Bool {
        guard let age = ad.petAgeMonths else { return false }
        return age.intValue > 0
    }

    private static func hasExplicitGender(_ ad: PetAd) -> Bool {
        let gender = ad.gender?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return gender?.isEmpty == false || ad.isFemale
    }
}
