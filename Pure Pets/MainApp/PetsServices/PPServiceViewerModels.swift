import Foundation
import UIKit

enum PPServiceViewerL10n {
    static var locale: Locale {
        Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA")
    }

    @inline(__always)
    static func text(_ key: String, fallback: String = "") -> String {
        Language.get(key, alter: fallback) ?? fallback
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    static func number(_ value: Double, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    static func price(_ service: ServiceModel) -> String {
        guard service.price.isFinite, service.price >= 0 else {
            return text("not available", fallback: "Not available")
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        let currency = (service.currency ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        formatter.currencyCode = currency.count == 3 ? currency.uppercased() : "QAR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: service.price)) ?? ""
    }
}

public struct PPServiceViewerReviewItem: Identifiable, Equatable {
    public let id: String
    public let userName: String
    public let userAvatarURL: String?
    public let rating: Int
    public let text: String
    public let date: String
    public let createdAt: Date?
    public let userID: String

    public init(
        id: String,
        userName: String,
        userAvatarURL: String?,
        rating: Int,
        text: String,
        date: String,
        createdAt: Date? = nil,
        userID: String = ""
    ) {
        self.id = id
        self.userName = userName
        self.userAvatarURL = userAvatarURL
        self.rating = min(max(rating, 1), 5)
        self.text = text
        self.date = date
        self.createdAt = createdAt
        self.userID = userID
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
    public let ownerVerified: Bool
    public let ownerContactAllowed: Bool
    public let isLive: Bool
    public let isReviewable: Bool
    public let availableDateText: String?
    public let symbol: String

    public var hasImage: Bool {
        guard let imageURL, let url = URL(string: imageURL) else { return false }
        return ["https", "http"].contains(url.scheme?.lowercased() ?? "") &&
            !(url.host ?? "").isEmpty && url.user == nil && url.password == nil
    }

    public var hasContact: Bool {
        ownerContactAllowed && !(ownerPhone ?? "").components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined().isEmpty
    }

    public init(service: ServiceModel, owner: UserModel? = nil, ownerContactAllowed: Bool = true) {
        self.service = service
        self.serviceID = service.serviceID ?? ""
        let title = (service.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = title.isEmpty ? PPServiceViewerL10n.text("service_view_default_title") : title
        self.desc = (service.desc ?? service.descriptionText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.price = PPServiceViewerL10n.price(service)
        if service.isAllCategories {
            self.category = PPServiceViewerL10n.text("AllCategories", fallback: Language.isRTL() ? "جميع الفئات" : "All Categories")
        } else if let targets = service.targetCategories, !targets.isEmpty {
            self.category = targets.joined(separator: " • ")
        } else if let cats = service.categories, !cats.isEmpty {
            self.category = cats.joined(separator: " • ")
        } else {
            self.category = (service.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        self.serviceTypeText = service.localizedTypeName() ?? ""
        self.imageURL = service.imageURL
        self.blurHash = service.blurHash
        self.isAvailable = service.isAvailable
        let rating = service.ratingValue?.doubleValue ?? 0
        self.ratingValue = rating.isFinite && (1...5).contains(rating) ? rating : 0
        self.reviewCount = max(0, service.reviewCount)
        self.ownerID = service.serviceOwnerID ?? ""
        let name = (owner?.bestDisplayName() ?? owner?.userName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerName = name.isEmpty ? PPServiceViewerL10n.text("service_view_owner") : name
        self.ownerAvatarURL = owner?.userImageUrl?.absoluteString
        self.ownerPhone = owner?.mobileNo
        self.ownerVerified = owner?.isVerified ?? false
        self.ownerContactAllowed = owner != nil && ownerContactAllowed
        self.isLive = service.isLive()
        self.isReviewable = !service.isDeleted && !service.isBlocked && !service.isDisabled
            && !(service.serviceOwnerID ?? "").isEmpty
        if let date = service.availableDate, date > Date() {
            self.availableDateText = PPServiceViewerL10n.date(date)
        } else {
            self.availableDateText = nil
        }
        self.symbol = service.type == .grooming ? "scissors" : "pawprint"
    }
}
