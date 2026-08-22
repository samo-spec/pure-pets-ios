//
//  PPOrderDetailsMissionControlModels.swift
//  Pure Pets
//

import Foundation
import SwiftUI
import UIKit

func PPOrderMissionText(_ key: String) -> String {
    let localized = Language.get(key, alter: key) ?? key
    return localized.isEmpty ? key : localized
}

enum PPOrderMissionTypography {
    static func display(_ size: CGFloat = 34) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .largeTitle)
    }

    static func title(_ size: CGFloat = 24) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .title2)
    }

    static func headline(_ size: CGFloat = 18) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .headline)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: .body)
    }

    static func callout(_ size: CGFloat = 15) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: .callout)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: .caption)
    }
}

extension Dictionary where Key == AnyHashable, Value == Any {
    func missionString(_ key: String) -> String {
        if let value = self[key] as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = self[key] as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    func missionInt(_ key: String) -> Int {
        (self[key] as? NSNumber)?.intValue ?? 0
    }

    func missionDouble(_ key: String) -> Double {
        (self[key] as? NSNumber)?.doubleValue ?? 0
    }

    func missionBool(_ key: String) -> Bool {
        (self[key] as? NSNumber)?.boolValue ?? false
    }

    func missionDate(_ key: String) -> Date? {
        self[key] as? Date
    }

    func missionDictionaries(_ key: String) -> [[AnyHashable: Any]] {
        if let values = self[key] as? [[AnyHashable: Any]] {
            return values
        }
        if let values = self[key] as? [NSDictionary] {
            return values.map { dictionary in
                var result: [AnyHashable: Any] = [:]
                dictionary.forEach { key, value in
                    if let hashable = key as? AnyHashable {
                        result[hashable] = value
                    }
                }
                return result
            }
        }
        return []
    }

    func missionStrings(_ key: String) -> [String] {
        (self[key] as? [String]) ?? []
    }

    func missionDictionary(_ key: String) -> [AnyHashable: Any] {
        if let value = self[key] as? [AnyHashable: Any] {
            return value
        }
        if let value = self[key] as? NSDictionary {
            var result: [AnyHashable: Any] = [:]
            value.forEach { key, entry in
                if let hashable = key as? AnyHashable {
                    result[hashable] = entry
                }
            }
            return result
        }
        return [:]
    }
}

struct PPOrderMissionItem: Identifiable, Hashable {
    let id: String
    let itemID: String
    let name: String
    let quantity: Int
    let lineTotalText: String
    let imageURL: String
    let canOpen: Bool

    init(dictionary: [AnyHashable: Any]) {
        id = dictionary.missionString("id")
        itemID = dictionary.missionString("itemID")
        name = dictionary.missionString("name")
        quantity = max(1, dictionary.missionInt("quantity"))
        lineTotalText = dictionary.missionString("lineTotalText")
        imageURL = dictionary.missionString("imageURL")
        canOpen = dictionary.missionBool("canOpen")
    }
}

struct PPOrderMissionTimelineEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let status: String
    let symbol: String
    let dateText: String
    let date: Date

    init(dictionary: [AnyHashable: Any]) {
        id = dictionary.missionString("id")
        title = dictionary.missionString("title")
        subtitle = dictionary.missionString("subtitle")
        status = dictionary.missionString("status")
        symbol = dictionary.missionString("symbol")
        dateText = dictionary.missionString("dateText")
        date = dictionary.missionDate("date") ?? .distantPast
    }
}

struct PPOrderMissionAttachment: Identifiable, Hashable {
    let id: String
    let url: String
    let fileName: String
    let mimeType: String

    init(dictionary: [AnyHashable: Any]) {
        url = dictionary.missionString("url")
        fileName = dictionary.missionString("fileName")
        mimeType = dictionary.missionString("mimeType")
        id = url.isEmpty ? fileName : url
    }
}

struct PPOrderMissionRequestItem: Identifiable, Hashable {
    let id: String
    let itemID: String
    let name: String
    let quantity: Int

    init(dictionary: [AnyHashable: Any]) {
        itemID = dictionary.missionString("itemId").isEmpty
            ? dictionary.missionString("itemID")
            : dictionary.missionString("itemId")
        name = dictionary.missionString("name")
        let rawQuantity = dictionary.missionInt("quantity")
        quantity = max(
            1,
            rawQuantity > 0 ? rawQuantity : dictionary.missionInt("qty")
        )
        id = itemID.isEmpty
            ? "\(name)-\(quantity)"
            : itemID
    }
}

struct PPOrderMissionRequest: Identifiable, Hashable {
    let id: String
    let requestID: String
    let type: String
    let typeTitle: String
    let reasonTitle: String
    let notes: String
    let status: String
    let statusTitle: String
    let finalResolution: String
    let itemIDs: [String]
    let itemSnapshots: [PPOrderMissionRequestItem]
    let attachments: [PPOrderMissionAttachment]
    let adminReviewSummary: String
    let resolutionSummary: String
    let createdAt: Date
    let createdAtText: String
    let orderCancelled: Bool
    let cancellationDisposition: String

    init(dictionary: [AnyHashable: Any]) {
        id = dictionary.missionString("id")
        requestID = dictionary.missionString("requestID")
        type = dictionary.missionString("type")
        typeTitle = dictionary.missionString("typeTitle")
        reasonTitle = dictionary.missionString("reasonTitle")
        notes = dictionary.missionString("notes")
        status = dictionary.missionString("status")
        statusTitle = dictionary.missionString("statusTitle")
        finalResolution = dictionary.missionString("finalResolution")
        itemIDs = dictionary.missionStrings("itemIDs")
        itemSnapshots = dictionary.missionDictionaries("itemSnapshots")
            .map(PPOrderMissionRequestItem.init)
        attachments = dictionary.missionDictionaries("attachments")
            .map(PPOrderMissionAttachment.init)
        adminReviewSummary = Self.summary(
            dictionary.missionDictionary("adminReview")
        )
        resolutionSummary = Self.summary(
            dictionary.missionDictionary("resolution")
        )
        createdAt = dictionary.missionDate("createdAt") ?? .distantPast
        createdAtText = dictionary.missionString("createdAtText")
        orderCancelled = dictionary.missionBool("orderCancelled")
        cancellationDisposition = dictionary.missionString(
            "cancellationDisposition"
        )
    }

    private static func summary(
        _ dictionary: [AnyHashable: Any]
    ) -> String {
        for key in ["summary", "note", "notes", "message", "decision"] {
            let value = dictionary.missionString(key)
            if !value.isEmpty { return value }
        }
        return ""
    }
}

struct PPOrderMissionFulfillment: Identifiable, Hashable {
    let id: String
    let sequence: Int
    let ownerTitle: String
    let ownerType: String
    let status: String
    let statusTitle: String
    let statusColor: UIColor
    let itemCount: Int
    let itemCountText: String
    let subtotalText: String

    init(dictionary: [AnyHashable: Any]) {
        id = dictionary.missionString("id")
        sequence = dictionary.missionInt("sequence")
        ownerTitle = dictionary.missionString("ownerTitle")
        ownerType = dictionary.missionString("ownerType")
        status = dictionary.missionString("status")
        statusTitle = dictionary.missionString("statusTitle")
        statusColor = (dictionary["statusColor"] as? UIColor) ?? .systemGray
        itemCount = dictionary.missionInt("itemCount")
        itemCountText = dictionary.missionString("itemCountText")
        subtotalText = dictionary.missionString("subtotalText")
    }

    static func == (
        lhs: PPOrderMissionFulfillment,
        rhs: PPOrderMissionFulfillment
    ) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status &&
            lhs.itemCount == rhs.itemCount &&
            lhs.subtotalText == rhs.subtotalText
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
        hasher.combine(itemCount)
        hasher.combine(subtotalText)
    }
}

struct PPOrderMissionAction: Identifiable, Hashable {
    let id: String
    let kind: String
    let actionType: Int
    let title: String
    let message: String
    let symbol: String
    let isVisible: Bool
    let isEligible: Bool
    let isDestructive: Bool

    init(dictionary: [AnyHashable: Any]) {
        id = dictionary.missionString("id")
        kind = dictionary.missionString("kind")
        actionType = dictionary.missionInt("actionType")
        title = dictionary.missionString("title")
        message = dictionary.missionString("message")
        symbol = dictionary.missionString("symbol")
        isVisible = dictionary.missionBool("visible")
        isEligible = dictionary.missionBool("eligible")
        isDestructive = dictionary.missionBool("destructive")
    }

    var v6Title: String {
        switch kind {
        case "track":
            return PPOrderMissionText("order_v6_action_track_title")
        case "requests":
            return PPOrderMissionText("order_v6_action_requests_title")
        case "support":
            return PPOrderMissionText("order_v6_action_support_title")
        case "complaint":
            return PPOrderMissionText("order_v6_action_complaint_title")
        case "cancel":
            return PPOrderMissionText("order_v6_action_cancel_title")
        case "return":
            return PPOrderMissionText("order_v6_action_return_title")
        case "replacement":
            return PPOrderMissionText("order_v6_action_replacement_title")
        case "refund":
            return PPOrderMissionText("order_v6_action_refund_title")
        default:
            return title
        }
    }

    var v6Subtitle: String {
        switch kind {
        case "track":
            return PPOrderMissionText("order_v6_action_track_sub")
        case "requests":
            return PPOrderMissionText("order_v6_action_requests_sub")
        case "support":
            return PPOrderMissionText("order_v6_action_support_sub")
        case "complaint":
            return PPOrderMissionText("order_v6_action_complaint_sub")
        case "cancel":
            return PPOrderMissionText("order_v6_action_cancel_sub")
        case "return":
            return PPOrderMissionText("order_v6_action_return_sub")
        case "replacement":
            return PPOrderMissionText("order_v6_action_replacement_sub")
        case "refund":
            return PPOrderMissionText("order_v6_action_refund_sub")
        default:
            return message
        }
    }

    var v6Symbol: String {
        switch kind {
        case "track":
            return "location.fill"
        case "requests":
            return "tray.full.fill"
        case "support":
            return "lifepreserver.fill"
        case "complaint":
            return "exclamationmark.bubble.fill"
        case "cancel":
            return "xmark.circle.fill"
        case "return":
            return "arrow.uturn.backward.circle.fill"
        case "replacement":
            return "arrow.triangle.2.circlepath.circle.fill"
        case "refund":
            return "dollarsign.arrow.circlepath"
        default:
            return symbol.isEmpty ? "bolt.fill" : symbol
        }
    }
}

struct PPOrderMissionFulfillmentSummary: Equatable {
    let total: Int
    let visible: Int
    let pending: Int
    let accepted: Int
    let preparing: Int
    let ready: Int
    let inDelivery: Int
    let delivered: Int
    let completed: Int
    let cancelled: Int
    let rejected: Int
    let failed: Int
    let returned: Int
    let missing: Int
    let isPartial: Bool

    init(dictionary: [AnyHashable: Any]) {
        total = dictionary.missionInt("total")
        visible = dictionary.missionInt("visible")
        pending = dictionary.missionInt("pending")
        accepted = dictionary.missionInt("accepted")
        preparing = dictionary.missionInt("preparing")
        ready = dictionary.missionInt("ready")
        inDelivery = dictionary.missionInt("inDelivery")
        delivered = dictionary.missionInt("delivered")
        completed = dictionary.missionInt("completed")
        cancelled = dictionary.missionInt("cancelled")
        rejected = dictionary.missionInt("rejected")
        failed = dictionary.missionInt("failed")
        returned = dictionary.missionInt("returned")
        missing = dictionary.missionInt("missing")
        isPartial = dictionary.missionBool("isPartial")
    }

    static let empty = PPOrderMissionFulfillmentSummary(dictionary: [:])
}

struct PPOrderMissionState {
    let orderID: String
    let reference: String
    let rawStatus: String
    let statusKey: String
    let statusTitle: String
    let statusHint: String
    let statusSymbol: String
    let statusColor: UIColor
    let statusProgress: Double
    let statusRevision: Int
    let createdAtText: String
    let updatedAtText: String
    let subtotalText: String
    let shippingText: String
    let totalText: String
    let paymentText: String
    let addressText: String
    let addressEditable: Bool
    let addressEditMessage: String
    let hasCoordinate: Bool
    let latitude: Double
    let longitude: Double
    let items: [PPOrderMissionItem]
    let timeline: [PPOrderMissionTimelineEvent]
    let requests: [PPOrderMissionRequest]
    let fulfillments: [PPOrderMissionFulfillment]
    let fulfillmentSummary: PPOrderMissionFulfillmentSummary
    let actions: [PPOrderMissionAction]
    let isAuthorized: Bool
    let isInitialLoading: Bool
    let isOffline: Bool
    let errorMessage: String
    let supportErrorMessage: String
    let timelineErrorMessage: String
    let fulfillmentErrorMessage: String
    let supportLoading: Bool
    let timelineLoading: Bool
    let fulfillmentLoading: Bool
    let fulfillmentVersion: Int
    let hasFulfillmentData: Bool
    let screenTitle: String

    init(dictionary: [AnyHashable: Any]) {
        orderID = dictionary.missionString("orderID")
        reference = dictionary.missionString("reference")
        rawStatus = dictionary.missionString("rawStatus")
        statusKey = dictionary.missionString("statusKey")
        statusTitle = dictionary.missionString("statusTitle")
        statusHint = dictionary.missionString("statusHint")
        statusSymbol = dictionary.missionString("statusSymbol")
        statusColor = (dictionary["statusColor"] as? UIColor) ?? .systemGray
        statusProgress = dictionary.missionDouble("statusProgress")
        statusRevision = dictionary.missionInt("statusRevision")
        createdAtText = dictionary.missionString("createdAtText")
        updatedAtText = dictionary.missionString("updatedAtText")
        subtotalText = dictionary.missionString("subtotalText")
        shippingText = dictionary.missionString("shippingText")
        totalText = dictionary.missionString("totalText")
        paymentText = dictionary.missionString("paymentText")
        addressText = dictionary.missionString("addressText")
        addressEditable = dictionary.missionBool("addressEditable")
        addressEditMessage = dictionary.missionString("addressEditMessage")
        hasCoordinate = dictionary.missionBool("hasCoordinate")
        latitude = dictionary.missionDouble("latitude")
        longitude = dictionary.missionDouble("longitude")
        items = dictionary.missionDictionaries("items")
            .map(PPOrderMissionItem.init)
        timeline = dictionary.missionDictionaries("timeline")
            .map(PPOrderMissionTimelineEvent.init)
            .sorted { $0.date < $1.date }
        requests = dictionary.missionDictionaries("requests")
            .map(PPOrderMissionRequest.init)
            .sorted { $0.createdAt > $1.createdAt }
        fulfillments = dictionary.missionDictionaries("fulfillments")
            .map(PPOrderMissionFulfillment.init)
            .sorted { $0.sequence < $1.sequence }
        fulfillmentSummary = PPOrderMissionFulfillmentSummary(
            dictionary: dictionary.missionDictionary("fulfillmentSummary")
        )
        actions = dictionary.missionDictionaries("actions")
            .map(PPOrderMissionAction.init)
        isAuthorized = dictionary.missionBool("isAuthorized")
        isInitialLoading = dictionary.missionBool("isInitialLoading")
        isOffline = dictionary.missionBool("isOffline")
        errorMessage = dictionary.missionString("errorMessage")
        supportErrorMessage = dictionary.missionString("supportErrorMessage")
        timelineErrorMessage = dictionary.missionString("timelineErrorMessage")
        fulfillmentErrorMessage = dictionary.missionString(
            "fulfillmentErrorMessage"
        )
        supportLoading = dictionary.missionBool("supportLoading")
        timelineLoading = dictionary.missionBool("timelineLoading")
        fulfillmentLoading = dictionary.missionBool("fulfillmentLoading")
        fulfillmentVersion = dictionary.missionInt("fulfillmentVersion")
        hasFulfillmentData = dictionary.missionBool("hasFulfillmentData")
        screenTitle = dictionary.missionString("screenTitle")
    }

    static let empty = PPOrderMissionState(dictionary: [
        "isInitialLoading": true,
        "statusProgress": 0.0,
        "statusColor": UIColor.systemGray
    ])
}

struct PPOrderMissionReason: Identifiable, Hashable {
    let id: String
    let code: String
    let title: String
    let subtitle: String
    let requiresItemSelection: Bool

    init(dictionary: [AnyHashable: Any]) {
        code = dictionary.missionString("code")
        id = code
        title = dictionary.missionString("title")
        subtitle = dictionary.missionString("subtitle")
        requiresItemSelection = dictionary.missionBool(
            "requiresItemSelection"
        )
    }
}

struct PPOrderMissionAddress: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let isDefault: Bool
    let isSelected: Bool
    let isSelectable: Bool
    let availabilityMessage: String

    init(dictionary: [AnyHashable: Any]) {
        id = dictionary.missionString("id")
        title = dictionary.missionString("title")
        subtitle = dictionary.missionString("subtitle")
        isDefault = dictionary.missionBool("isDefault")
        isSelected = dictionary.missionBool("isSelected")
        isSelectable = dictionary.missionBool("isSelectable")
        availabilityMessage = dictionary.missionString(
            "availabilityMessage"
        )
    }
}

struct PPOrderMissionNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let isError: Bool
}

enum PPOrderMissionSheet: Identifiable {
    case timeline
    case requests
    case request(PPOrderMissionRequest)
    case support
    case composer(PPOrderMissionAction)
    case addresses
    case fulfillment(PPOrderMissionFulfillment)

    var id: String {
        switch self {
        case .timeline: return "timeline"
        case .requests: return "requests"
        case let .request(request): return "request-\(request.id)"
        case .support: return "support"
        case let .composer(action): return "composer-\(action.id)"
        case .addresses: return "addresses"
        case let .fulfillment(fulfillment):
            return "fulfillment-\(fulfillment.id)"
        }
    }
}
