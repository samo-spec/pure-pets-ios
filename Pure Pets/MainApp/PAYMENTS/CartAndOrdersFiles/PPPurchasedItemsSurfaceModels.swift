//
//  PPPurchasedItemsSurfaceModels.swift
//  Pure Pets
//
//  Category-defining presentation contract for the Pet Restock & Repeat Orders Sanctuary.
//

import Foundation
import SwiftUI
import UIKit

func PPPurchasedText(_ key: String) -> String {
    let localized = Language.get(key, alter: key) ?? key
    return localized.isEmpty ? key : localized
}

var PPPurchasedLocale: Locale {
    let code = Language.currentLanguageCode() ?? "en"
    return Locale(identifier: code == "ar" ? "ar_QA" : "en_QA")
}

func PPPurchasedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(
        format: PPPurchasedText(key),
        locale: PPPurchasedLocale,
        arguments: arguments
    )
}

enum PPPurchasedTypography {
    static func display(_ size: CGFloat = 28) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .largeTitle)
    }

    static func title(_ size: CGFloat = 20) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .title3)
    }

    static func headline(_ size: CGFloat = 16) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .headline)
    }

    static func subheadline(_ size: CGFloat = 15) -> Font {
        .custom("Beiruti-SemiBold", size: size, relativeTo: .subheadline)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: .body)
    }

    static func callout(_ size: CGFloat = 13) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: .callout)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: .caption)
    }

    static func micro(_ size: CGFloat = 11) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .caption2)
    }
}

@objcMembers
final class PPPurchasedItemDescriptor: NSObject, Identifiable {
    var id: String = ""
    var name: String = ""
    var imageURL: String = ""
    var price: Double = 0.0
    var originalPrice: Double = 0.0
    var formattedPrice: String = ""
    var formattedOriginalPrice: String = ""
    var hasDiscount: Bool = false

    var purchaseCount: Int = 1
    var totalUnitsPurchased: Int = 1
    var latestPurchaseDate: Date?
    var latestPurchaseDateText: String = ""

    var isOutOfStock: Bool = false
    var stockQuantity: Int = 0
    var stockStatusText: String = ""

    var categoryKey: String = "all"
    var categoryTagText: String = ""
    var weightOrSizeText: String = ""

    var isReadyForRefill: Bool = false
    var cadenceBadgeText: String = ""
    var cadenceSubtext: String = ""

    var searchIndex: String = ""
}

@objcMembers
final class PPPurchasedFilterDescriptor: NSObject, Identifiable {
    var id: String = "all"
    var title: String = ""
    var icon: String = "sparkles"
    var count: Int = 0

    init(id: String, title: String, icon: String, count: Int) {
        self.id = id
        self.title = title
        self.icon = icon
        self.count = count
        super.init()
    }
}

@objcMembers
final class PPPurchasedItemsSnapshotDescriptor: NSObject {
    var items: [PPPurchasedItemDescriptor] = []
    var quickReorderItems: [PPPurchasedItemDescriptor] = []
    var filters: [PPPurchasedFilterDescriptor] = []

    var totalDistinctCount: Int = 0
    var totalOrdersCount: Int = 0
    var totalUnitsRestocked: Int = 0
    var readyForRefillCount: Int = 0

    var isInitialLoading: Bool = false
    var errorMessage: String?

    var cartBadgeCount: Int = 0
    var cartTotalFormatted: String = ""
    var showsBackButton: Bool = true
}

@objc(PPPurchasedItemsSurfaceControllerDelegate)
protocol PPPurchasedItemsSurfaceControllerDelegate: AnyObject {
    func purchasedItemsSurfaceDidRequestBack()
    func purchasedItemsSurfaceDidRequestRefresh()
    func purchasedItemsSurfaceDidRequestAddToCart(itemID: String, quantity: Int)
    func purchasedItemsSurfaceDidRequestOpenProduct(itemID: String)
    func purchasedItemsSurfaceDidRequestOpenCart()
    func purchasedItemsSurfaceDidRequestExploreStore()
}
