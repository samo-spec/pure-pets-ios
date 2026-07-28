import Foundation
import UIKit

enum PPServiceViewerL10n {
    @inline(__always)
    static func text(_ key: String, fallback: String) -> String {
        let localized = Language.get(key, alter: fallback)
        guard let localized, !localized.isEmpty, localized != key else {
            return fallback
        }
        return localized
    }
}

public struct PPServiceViewerReviewItem: Identifiable, Equatable {
    public let id: String
    public let userName: String
    public let userAvatarURL: String?
    public let rating: Int
    public let text: String
    public let date: String

    public init(
        id: String,
        userName: String,
        userAvatarURL: String?,
        rating: Int,
        text: String,
        date: String
    ) {
        self.id = id
        self.userName = userName
        self.userAvatarURL = userAvatarURL
        self.rating = rating
        self.text = text
        self.date = date
    }
}

public struct PPServiceViewerSnapshot: Equatable {
    public let service: ServiceModel
    public let serviceID: String
    public let title: String
    public let desc: String
    public let price: String
    public let category: String
    public let serviceTypeText: String
    public let imageURL: String?
    public let blurHash: String?
    public let isAvailable: Bool
    public let ratingValue: Double
    public let reviewCount: Int
    public let ownerID: String
    public let ownerName: String
    public let ownerAvatarURL: String?
    public let ownerPhone: String?
    public let isLive: Bool

    public init(service: ServiceModel, owner: UserModel? = nil) {
        self.service = service
        self.serviceID = service.serviceID ?? ""
        self.title = service.title ?? PPServiceViewerL10n.text("service_view_default_title", fallback: "Service")
        self.desc = service.desc ?? service.descriptionText ?? ""
        
        let formattedPrice: String = {
            if service.price > 0 {
                let curr = service.currency ?? "QAR"
                return String(format: "%.0f %@", service.price, curr)
            }
            return PPServiceViewerL10n.text("not available", fallback: "Not available")
        }()
        self.price = formattedPrice
        
        self.category = service.category ?? ""
        self.serviceTypeText = service.serviceTypeText ?? service.localizedTypeName() ?? ""
        self.imageURL = service.imageURL
        self.blurHash = service.blurHash
        self.isAvailable = service.isAvailable
        self.ratingValue = service.ratingValue?.doubleValue ?? 0.0
        self.reviewCount = service.reviewCount
        self.ownerID = service.serviceOwnerID ?? ""
        
        if let owner {
            self.ownerName = owner.bestDisplayName() ?? owner.userName ?? PPServiceViewerL10n.text("service_view_owner", fallback: "Provider")
            self.ownerAvatarURL = owner.userImageUrl?.absoluteString
            self.ownerPhone = owner.mobileNo
        } else {
            self.ownerName = PPServiceViewerL10n.text("service_view_owner", fallback: "Provider")
            self.ownerAvatarURL = nil
            self.ownerPhone = nil
        }
        
        self.isLive = service.isLive()
    }
}
