//
//  PPNotificationsHubModels.swift
//  Pure Pets
//
//  SwiftUI replacement for the payload-normalisation layer that previously
//  lived as file-static C functions inside PPNotificationsHubViewController.m.
//  Every localisation key, precedence rule and fallback below is a 1:1 port of
//  the legacy behaviour — the inbox must keep rendering identical copy for
//  identical Firestore documents.
//

import Foundation
import SwiftUI
import UIKit
import FirebaseFirestore

// MARK: - Metrics

/// Token-exact mirror of the `kPPHub*` constants from the legacy screen.
/// Values that already exist in the Swift design system are referenced from
/// `PPSpace` / `PPCorner` instead of being redeclared here.
enum PPHubMetrics {
    static let topBarHeight: CGFloat = 52
    static let actionButtonSize: CGFloat = 48
    static let heroHorizontalInset: CGFloat = 20
    static let heroTopInset: CGFloat = 8
    static let contentTopGap: CGFloat = 12
    static let segmentIconPlateSize: CGFloat = 26
    static let segmentIconSize: CGFloat = 14
    static let segmentActiveRailWidth: CGFloat = 30
    static let segmentActiveRailHeight: CGFloat = 3
    /// `PPSpaceMDHalf` — the icon/title gap inside a segment.
    static let segmentContentSpacing: CGFloat = 6

    /// The root tab controller owns the floating Command Deck clearance and
    /// raises visible list insets dynamically. Only the screen's intrinsic
    /// breathing room lives here so a measured deck can also shrink or hide
    /// without leaving a hole.
    static let listBaseBottomInset: CGFloat = PPSpace.md

    /// `PPCorner16` has no Swift design-system mirror.
    static let iconContainerCorner: CGFloat = 16
    /// `PPTouchTargetMin` has no Swift design-system mirror.
    static let touchTargetMin: CGFloat = 44
    /// `PPAnimDurationNormal` has no Swift design-system mirror.
    static let animationDurationNormal: Double = 0.25
}

// MARK: - Localisation

/// `kLang(key)` is a C macro and therefore invisible to Swift.
/// `Language.get(_:alter:)` already falls back to the key itself, so this
/// wrapper reproduces `kLang(...) ?: @""` exactly.
func PPHubText(_ key: String) -> String {
    Language.get(key, alter: nil) ?? key
}

var PPHubLocale: Locale {
    Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA")
}

func PPHubFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: PPHubText(key), locale: PPHubLocale, arguments: arguments)
}

// MARK: - Typography

/// `GM` adds one point to every requested size (`Beiruti-Bold size + 1`), so the
/// literals below are the legacy sizes already resolved to their effective
/// value. Dynamic Type scaling replaces the `UIFontMetrics` calls.
enum PPHubTypography {
    static func heroEyebrow() -> Font {
        .custom("Beiruti-Bold", size: 13, relativeTo: .caption)
    }

    static func heroTitle() -> Font {
        .custom("Beiruti-Bold", size: 30, relativeTo: .largeTitle)
    }

    static func heroSubtitle() -> Font {
        .custom("Beiruti-Medium", size: 15.5, relativeTo: .subheadline)
    }

    static func segmentTitle() -> Font {
        .custom("Beiruti-Bold", size: 14.5, relativeTo: .callout)
    }

    static func rowTitle(isRead: Bool) -> Font {
        .custom(isRead ? "Beiruti-Medium" : "Beiruti-Bold", size: 17.5, relativeTo: .headline)
    }

    static func rowSubtitle() -> Font {
        .custom("Beiruti-Medium", size: 15, relativeTo: .subheadline)
    }

    static func rowMeta() -> Font {
        .custom("Beiruti-Medium", size: 13, relativeTo: .caption)
    }

    static func stateTitle() -> Font {
        .custom("Beiruti-Bold", size: 21, relativeTo: .title2)
    }

    static func stateSubtitle() -> Font {
        .custom("Beiruti-Medium", size: 15, relativeTo: .subheadline)
    }

    static func stateAction() -> Font {
        .custom("Beiruti-Bold", size: 16, relativeTo: .headline)
    }
}

// MARK: - Inbox item

/// Value-type replacement for the legacy `PPNotificationInboxItem` class.
struct PPNotificationInboxItem: Identifiable, Equatable {
    let id: String
    let documentID: String
    let title: String
    let subtitle: String
    let categoryTitle: String
    let symbolName: String
    let accentColor: Color
    let timestamp: Date?
    let payload: [String: Any]
    var isRead: Bool

    static func == (lhs: PPNotificationInboxItem, rhs: PPNotificationInboxItem) -> Bool {
        lhs.id == rhs.id
            && lhs.documentID == rhs.documentID
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.categoryTitle == rhs.categoryTitle
            && lhs.symbolName == rhs.symbolName
            && lhs.timestamp == rhs.timestamp
            && lhs.isRead == rhs.isRead
    }
}

enum PPNotificationsInboxState: Equatable {
    case loading
    case content
    case empty
    case error
}

// MARK: - Payload normalisation

/// Direct port of the `PPHub*` file-static helpers. Keeping them in one
/// namespace preserves the original resolution order, which is load bearing:
/// explicit localisation keys win, then per-language sibling keys, then nested
/// maps, then the type/status heuristics, then the raw server copy.
enum PPHubPayload {

    // MARK: Scalars

    static func trimmed(_ value: Any?) -> String {
        guard let string = value as? String else { return "" }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scalarString(_ value: Any?) -> String {
        let stringValue = trimmed(value)
        if !stringValue.isEmpty { return stringValue }

        if let number = value as? NSNumber {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: number) ?? number.stringValue
        }

        return ""
    }

    static func date(from value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        return nil
    }

    static func boolean(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return (string as NSString).boolValue }
        return false
    }

    static func safeDictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    static func firstString(in source: [String: Any], keys: [String]) -> String {
        for key in keys {
            let value = trimmed(source[key])
            if !value.isEmpty { return value }
        }
        return ""
    }

    static func firstScalar(in source: [String: Any], keys: [String]) -> String {
        for key in keys {
            let value = scalarString(source[key])
            if !value.isEmpty { return value }
        }
        return ""
    }

    static func stringEquals(_ lhs: String?, _ rhs: String) -> Bool {
        trimmed(lhs).compare(trimmed(rhs), options: .caseInsensitive) == .orderedSame
    }

    static func stringHasPrefix(_ value: String?, _ prefix: String) -> Bool {
        trimmed(value).range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
    }

    // MARK: Identifiers

    static func orderID(from payload: [String: Any]) -> String {
        let safePayload = safeDictionary(payload)
        let meta = safeDictionary(safePayload["meta"])
        let keys = ["orderId", "orderID", "parentOrderId", "parentOrderID"]
        let orderID = firstScalar(in: safePayload, keys: keys)
        if orderID.isEmpty {
            return firstScalar(in: meta, keys: keys)
        }
        return orderID
    }

    static func threadID(from payload: [String: Any]) -> String {
        let value = trimmed(payload["threadID"])
        return value.isEmpty ? trimmed(payload["threadId"]) : value
    }

    // MARK: Localised value lookup

    static func localizedValue(in source: [String: Any], arKeys: [String], enKeys: [String]) -> String {
        let isRTL = Language.isRTL()
        let primaryKeys = isRTL ? arKeys : enKeys
        let fallbackKeys = isRTL ? enKeys : arKeys
        let primary = firstString(in: source, keys: primaryKeys)
        if !primary.isEmpty { return primary }
        return firstString(in: source, keys: fallbackKeys)
    }

    static func localizedNestedValue(_ nestedValue: Any?) -> String {
        let dictionary = safeDictionary(nestedValue)
        if dictionary.isEmpty { return trimmed(nestedValue) }
        return localizedValue(
            in: dictionary,
            arKeys: ["ar", "arabic", "titleAr", "bodyAr", "valueAr", "textAr"],
            enKeys: ["en", "english", "titleEn", "bodyEn", "valueEn", "textEn"]
        )
    }

    // MARK: Audience filtering

    /// Pro/driver-only traffic must never surface in the consumer inbox.
    static func isProviderOnlyNotification(_ payload: [String: Any]) -> Bool {
        let safePayload = safeDictionary(payload)
        let type = firstString(in: safePayload, keys: ["notificationType", "type"]).lowercased()
        let route = trimmed(safePayload["route"]).lowercased()
        let targetAppID = firstString(in: safePayload, keys: ["targetApp", "targetAppId", "appId"]).lowercased()
        let audience = trimmed(safePayload["audience"]).lowercased()
        let customerOrderID = orderID(from: safePayload)

        return targetAppID == "pro_ios"
            || audience == "delivery_providers"
            || type.hasPrefix("drivers_delivery_")
            || type == "provider_new_fulfillment"
            || (route == "fulfillment_order" && customerOrderID.isEmpty)
    }

    // MARK: Order references

    static func orderReference(fromTitle title: String?) -> String {
        let safeTitle = trimmed(title)
        let prefix = "New Order "
        guard stringHasPrefix(safeTitle, prefix), safeTitle.count > prefix.count else { return "" }
        let index = safeTitle.index(safeTitle.startIndex, offsetBy: prefix.count)
        return trimmed(String(safeTitle[index...]))
    }

    static func orderReference(fromBody body: String?) -> String {
        let safeBody = trimmed(body)
        if safeBody.isEmpty { return "" }

        guard let regex = try? NSRegularExpression(pattern: "^\\s*(#[^\\s]+)\\s+", options: []) else {
            return ""
        }
        let range = NSRange(safeBody.startIndex..., in: safeBody)
        guard let match = regex.firstMatch(in: safeBody, options: [], range: range),
              match.numberOfRanges >= 2,
              let captured = Range(match.range(at: 1), in: safeBody) else { return "" }
        return String(safeBody[captured])
    }

    static func displayOrderReference(_ reference: String) -> String {
        let safeReference = trimmed(reference)
        if safeReference.isEmpty { return "" }
        if safeReference.hasPrefix("#") { return safeReference }
        return "#\(safeReference)"
    }

    static func orderReference(fromPayload payload: [String: Any], meta: [String: Any]) -> String {
        var reference = firstScalar(
            in: meta,
            keys: ["orderReference", "orderNumber", "parentOrderNumber", "orderId", "parentOrderId"]
        )
        if reference.isEmpty {
            reference = firstScalar(
                in: payload,
                keys: ["orderReference", "orderNumber", "orderId", "parentOrderNumber", "parentOrderId"]
            )
        }
        return displayOrderReference(reference)
    }

    struct OrderSummary {
        let itemCount: String
        let amount: String
        let currency: String
    }

    static func parseOrderSummary(body: String?) -> OrderSummary? {
        let safeBody = trimmed(body)
        if safeBody.isEmpty { return nil }

        let pattern = "^\\s*(\\d+)\\s+item\\(s\\)\\s*•\\s*([0-9]+(?:\\.[0-9]+)?)\\s*([A-Za-z]+)\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(safeBody.startIndex..., in: safeBody)
        guard let match = regex.firstMatch(in: safeBody, options: [], range: range),
              match.numberOfRanges >= 4,
              let countRange = Range(match.range(at: 1), in: safeBody),
              let amountRange = Range(match.range(at: 2), in: safeBody),
              let currencyRange = Range(match.range(at: 3), in: safeBody) else { return nil }

        return OrderSummary(
            itemCount: String(safeBody[countRange]),
            amount: String(safeBody[amountRange]),
            currency: String(safeBody[currencyRange])
        )
    }

    // MARK: Type & status

    static func notificationType(_ payload: [String: Any], _ meta: [String: Any]) -> String {
        var type = firstString(in: payload, keys: ["notificationType", "type", "key", "eventKey", "route"])
        if type.isEmpty {
            type = firstString(in: meta, keys: ["notificationType", "type", "key", "eventKey", "route"])
        }
        return type.lowercased()
    }

    static func notificationStatus(_ payload: [String: Any], _ meta: [String: Any]) -> String {
        var status = firstString(
            in: payload,
            keys: ["status", "fulfillmentStatus", "toStatus", "paymentStatus", "deliveryStatus"]
        )
        if status.isEmpty {
            status = firstString(
                in: meta,
                keys: ["status", "fulfillmentStatus", "toStatus", "paymentStatus", "deliveryStatus"]
            )
        }
        return status.lowercased()
    }

    private static func isOrderStatusType(_ type: String) -> Bool {
        type == "order_status" || (type.hasPrefix("order") && type != "order_payment_status")
    }

    // MARK: Customer delivery keys

    static func customerDeliveryTitleKey(type: String, rawTitle: String, rawBody: String) -> String {
        if type == "customer_delivery_requested" || stringEquals(rawTitle, "Your Order Is Ready") {
            return "notifications_inbox_customer_delivery_requested_title"
        }
        if type == "customer_delivery_assigned" || stringEquals(rawTitle, "Delivery Partner Assigned") {
            return "notifications_inbox_customer_delivery_assigned_title"
        }
        if type == "customer_delivery_on_the_way" || stringEquals(rawTitle, "Your Order Is On the Way") {
            return "notifications_inbox_customer_delivery_on_the_way_title"
        }
        if type == "customer_delivery_delivered" || stringEquals(rawTitle, "Order Delivered") {
            return "notifications_inbox_customer_delivery_delivered_title"
        }
        if type == "customer_delivery_completed" || stringEquals(rawTitle, "Order Completed") {
            return "notifications_inbox_customer_delivery_completed_title"
        }
        if type == "customer_delivery_cancelled"
            || stringEquals(rawBody, "The delivery for your order has been cancelled. Please contact support if you need assistance.") {
            return "notifications_inbox_customer_delivery_update_title"
        }
        if type == "customer_delivery_failed"
            || stringEquals(rawBody, "We were unable to complete your delivery. Our team will review the order and update you shortly.") {
            return "notifications_inbox_customer_delivery_update_title"
        }
        if type == "customer_delivery_delayed"
            || stringEquals(rawBody, "Your delivery needs a little more time. Our team is reviewing the order and will update you shortly.") {
            return "notifications_inbox_customer_delivery_update_title"
        }
        return ""
    }

    static func customerDeliveryBodyKey(type: String, rawBody: String) -> String {
        if type == "customer_delivery_requested"
            || stringEquals(rawBody, "Your order is packed and ready for shipment. A delivery partner will be assigned shortly.") {
            return "notifications_inbox_customer_delivery_requested_body"
        }
        if type == "customer_delivery_assigned"
            || stringEquals(rawBody, "A delivery partner has been assigned to your order and will collect it shortly.") {
            return "notifications_inbox_customer_delivery_assigned_body"
        }
        if type == "customer_delivery_on_the_way"
            || stringEquals(rawBody, "Your order has been collected and is now on its way to you.") {
            return "notifications_inbox_customer_delivery_on_the_way_body"
        }
        if type == "customer_delivery_delivered"
            || stringEquals(rawBody, "Your order has been delivered successfully. Thank you for choosing Pure Pets.") {
            return "notifications_inbox_customer_delivery_delivered_body"
        }
        if type == "customer_delivery_completed"
            || stringEquals(rawBody, "Your order has been completed successfully. Thank you for shopping with Pure Pets.") {
            return "notifications_inbox_customer_delivery_completed_body"
        }
        if type == "customer_delivery_cancelled"
            || stringEquals(rawBody, "The delivery for your order has been cancelled. Please contact support if you need assistance.") {
            return "notifications_inbox_customer_delivery_cancelled_body"
        }
        if type == "customer_delivery_failed"
            || stringEquals(rawBody, "We were unable to complete your delivery. Our team will review the order and update you shortly.") {
            return "notifications_inbox_customer_delivery_failed_body"
        }
        if type == "customer_delivery_delayed"
            || stringEquals(rawBody, "Your delivery needs a little more time. Our team is reviewing the order and will update you shortly.") {
            return "notifications_inbox_customer_delivery_delayed_body"
        }
        return ""
    }

    // MARK: Order status keys

    static func orderStatusTitleKey(type: String, status: String, rawTitle: String) -> String {
        if type == "order_payment_status" || stringEquals(rawTitle, "Cash Payment Collected | تم تحصيل الدفع") {
            return "notifications_inbox_order_cash_collected_title"
        }

        let isOrderStatus = isOrderStatusType(type)
        if (isOrderStatus && status == "paid") || stringEquals(rawTitle, "Payment Confirmed | تم تأكيد الدفع") {
            return "notifications_inbox_order_payment_confirmed_title"
        }
        if (isOrderStatus && status == "processing") || stringEquals(rawTitle, "Order Processing | جاري تجهيز الطلب") {
            return "notifications_inbox_order_processing_title"
        }
        if (isOrderStatus && status == "shipped") || stringEquals(rawTitle, "Order Shipped | تم شحن الطلب") {
            return "notifications_inbox_order_shipped_title"
        }
        if (isOrderStatus && status == "delivered") || stringEquals(rawTitle, "Order Delivered | تم تسليم الطلب") {
            return "notifications_inbox_order_delivered_title"
        }
        if (isOrderStatus && (status == "cancelled" || status == "canceled"))
            || stringEquals(rawTitle, "Order Cancelled | تم إلغاء الطلب") {
            return "notifications_inbox_order_cancelled_title"
        }
        if (isOrderStatus && status == "failed") || stringEquals(rawTitle, "Payment Failed | فشل الدفع") {
            return "notifications_inbox_order_failed_title"
        }
        return ""
    }

    static func orderStatusBodyFormatKey(type: String, status: String, rawTitle: String, rawBody: String) -> String {
        if type == "order_payment_status"
            || stringEquals(rawTitle, "Cash Payment Collected | تم تحصيل الدفع")
            || rawBody.contains("cash payment was collected successfully.") {
            return "notifications_inbox_order_cash_collected_body_format"
        }

        let isOrderStatus = isOrderStatusType(type)
        if (isOrderStatus && status == "paid")
            || stringEquals(rawTitle, "Payment Confirmed | تم تأكيد الدفع")
            || rawBody.contains("is confirmed and paid.") {
            return "notifications_inbox_order_payment_confirmed_body_format"
        }
        if (isOrderStatus && status == "processing")
            || stringEquals(rawTitle, "Order Processing | جاري تجهيز الطلب")
            || rawBody.contains("is now being prepared.") {
            return "notifications_inbox_order_processing_body_format"
        }
        if (isOrderStatus && status == "shipped")
            || stringEquals(rawTitle, "Order Shipped | تم شحن الطلب")
            || rawBody.contains("is on the way.") {
            return "notifications_inbox_order_shipped_body_format"
        }
        if (isOrderStatus && status == "delivered")
            || stringEquals(rawTitle, "Order Delivered | تم تسليم الطلب")
            || rawBody.contains("has been delivered.") {
            return "notifications_inbox_order_delivered_body_format"
        }
        if (isOrderStatus && (status == "cancelled" || status == "canceled"))
            || stringEquals(rawTitle, "Order Cancelled | تم إلغاء الطلب")
            || rawBody.contains("was cancelled.") {
            return "notifications_inbox_order_cancelled_body_format"
        }
        if (isOrderStatus && status == "failed")
            || stringEquals(rawTitle, "Payment Failed | فشل الدفع")
            || rawBody.contains("could not be completed.") {
            return "notifications_inbox_order_failed_body_format"
        }
        return ""
    }

    // MARK: Title & body resolution

    static func localizedTitle(rawTitle: String, rawBody: String, payload: [String: Any]) -> String {
        let safePayload = safeDictionary(payload)
        let meta = safeDictionary(safePayload["meta"])
        let type = notificationType(safePayload, meta)
        let status = notificationStatus(safePayload, meta)

        var titleKey = firstString(in: safePayload, keys: ["titleLocalizationKey", "titleKey", "titleLocKey"])
        if titleKey.isEmpty {
            titleKey = firstString(in: meta, keys: ["titleLocalizationKey", "titleKey", "titleLocKey"])
        }
        if !titleKey.isEmpty { return PPHubText(titleKey) }

        let arKeys = ["titleAr", "title_ar", "arTitle", "titleArabic", "title_arabic"]
        let enKeys = ["titleEn", "title_en", "enTitle", "titleEnglish", "title_english"]
        var localized = localizedValue(in: safePayload, arKeys: arKeys, enKeys: enKeys)
        if localized.isEmpty {
            localized = localizedValue(in: meta, arKeys: arKeys, enKeys: enKeys)
        }
        if !localized.isEmpty { return localized }

        for key in ["localizedTitle", "titleLocalized", "titleI18n", "title_i18n", "titleMap"] {
            localized = localizedNestedValue(safePayload[key])
            if !localized.isEmpty { return localized }
            localized = localizedNestedValue(meta[key])
            if !localized.isEmpty { return localized }
        }

        let customerDeliveryKey = customerDeliveryTitleKey(type: type, rawTitle: rawTitle, rawBody: rawBody)
        if !customerDeliveryKey.isEmpty { return PPHubText(customerDeliveryKey) }

        let orderStatusKey = orderStatusTitleKey(type: type, status: status, rawTitle: rawTitle)
        if !orderStatusKey.isEmpty { return PPHubText(orderStatusKey) }

        if type == "drivers_delivery_requested"
            || type == "delivery_requested"
            || stringEquals(rawTitle, "New Delivery Request") {
            return PPHubText("notifications_inbox_new_delivery_request_title")
        }

        if type == "drivers_delivery_request_closed"
            || type == "delivery_request_closed"
            || stringEquals(rawTitle, "Delivery Request Closed") {
            return PPHubText("notifications_inbox_delivery_request_closed_title")
        }

        if type == "provider_new_fulfillment"
            || type == "fulfillment_order"
            || status == "new_request"
            || stringHasPrefix(rawTitle, "New Order ") {
            var orderReference = firstScalar(
                in: meta,
                keys: ["orderNumber", "parentOrderNumber", "orderReference", "orderId", "parentOrderId"]
            )
            if orderReference.isEmpty {
                orderReference = firstScalar(in: safePayload, keys: ["orderNumber", "orderReference", "orderId"])
            }
            if orderReference.isEmpty {
                orderReference = self.orderReference(fromTitle: rawTitle)
            }
            return orderReference.isEmpty
                ? PPHubText("notifications_inbox_new_order_title")
                : PPHubFormat("notifications_inbox_new_order_title_format", orderReference)
        }

        return trimmed(rawTitle)
    }

    static func localizedBody(rawBody: String, rawTitle: String, payload: [String: Any]) -> String {
        let safePayload = safeDictionary(payload)
        let meta = safeDictionary(safePayload["meta"])
        let type = notificationType(safePayload, meta)
        let status = notificationStatus(safePayload, meta)

        var bodyKey = firstString(in: safePayload, keys: ["bodyLocalizationKey", "bodyKey", "bodyLocKey"])
        if bodyKey.isEmpty {
            bodyKey = firstString(in: meta, keys: ["bodyLocalizationKey", "bodyKey", "bodyLocKey"])
        }
        if !bodyKey.isEmpty { return PPHubText(bodyKey) }

        let arKeys = ["bodyAr", "body_ar", "arBody", "bodyArabic", "body_arabic", "messageAr", "message_ar"]
        let enKeys = ["bodyEn", "body_en", "enBody", "bodyEnglish", "body_english", "messageEn", "message_en"]
        var localized = localizedValue(in: safePayload, arKeys: arKeys, enKeys: enKeys)
        if localized.isEmpty {
            localized = localizedValue(in: meta, arKeys: arKeys, enKeys: enKeys)
        }
        if !localized.isEmpty { return localized }

        for key in ["localizedBody", "bodyLocalized", "bodyI18n", "body_i18n", "bodyMap"] {
            localized = localizedNestedValue(safePayload[key])
            if !localized.isEmpty { return localized }
            localized = localizedNestedValue(meta[key])
            if !localized.isEmpty { return localized }
        }

        let customerDeliveryKey = customerDeliveryBodyKey(type: type, rawBody: rawBody)
        if !customerDeliveryKey.isEmpty { return PPHubText(customerDeliveryKey) }

        let orderFormatKey = orderStatusBodyFormatKey(
            type: type,
            status: status,
            rawTitle: rawTitle,
            rawBody: rawBody
        )
        if !orderFormatKey.isEmpty {
            var reference = orderReference(fromPayload: safePayload, meta: meta)
            if reference.isEmpty { reference = orderReference(fromBody: rawBody) }
            if reference.isEmpty { reference = PPHubText("notifications_inbox_order_reference_fallback") }
            return PPHubFormat(orderFormatKey, reference)
        }

        if type == "drivers_delivery_requested"
            || type == "delivery_requested"
            || stringEquals(rawTitle, "New Delivery Request")
            || stringEquals(rawBody, "A new order is ready for pickup. Please review the details and accept the delivery request.") {
            return PPHubText("notifications_inbox_new_delivery_request_body")
        }

        if type == "drivers_delivery_request_closed"
            || type == "delivery_request_closed"
            || stringEquals(rawTitle, "Delivery Request Closed")
            || stringEquals(rawBody, "This delivery request is no longer available.") {
            return PPHubText("notifications_inbox_delivery_request_closed_body")
        }

        if type == "provider_new_fulfillment"
            || type == "fulfillment_order"
            || status == "new_request"
            || stringHasPrefix(rawTitle, "New Order ") {
            var itemCount = firstScalar(in: meta, keys: ["itemCount", "itemsCount"])
            var amount = firstScalar(in: meta, keys: ["subtotal", "amount", "total"])
            var currency = firstScalar(in: meta, keys: ["currency"])

            if itemCount.isEmpty || amount.isEmpty || currency.isEmpty {
                if itemCount.isEmpty {
                    itemCount = firstScalar(in: safePayload, keys: ["itemCount", "itemsCount"])
                }
                if amount.isEmpty {
                    amount = firstScalar(in: safePayload, keys: ["subtotal", "amount", "total"])
                }
                if currency.isEmpty {
                    currency = firstScalar(in: safePayload, keys: ["currency"])
                }
            }

            if itemCount.isEmpty || amount.isEmpty || currency.isEmpty,
               let parsed = parseOrderSummary(body: rawBody) {
                if itemCount.isEmpty { itemCount = parsed.itemCount }
                if amount.isEmpty { amount = parsed.amount }
                if currency.isEmpty { currency = parsed.currency }
            }

            if !itemCount.isEmpty, !amount.isEmpty, !currency.isEmpty {
                return PPHubFormat(
                    "notifications_inbox_order_items_total_format",
                    itemCount,
                    amount,
                    currency
                )
            }
        }

        return trimmed(rawBody)
    }

    // MARK: Presentation

    static func categoryTitle(for payload: [String: Any]) -> String {
        let meta = safeDictionary(payload["meta"])
        let type = notificationType(payload, meta)
        let thread = threadID(from: payload)
        let order = orderID(from: payload)

        if !thread.isEmpty || type == "chat" {
            return PPHubText("notifications_inbox_category_chat")
        }
        if !order.isEmpty || type.hasPrefix("order") {
            return PPHubText("notifications_inbox_category_orders")
        }
        return PPHubText("notifications_inbox_category_updates")
    }

    static func accentColor(for payload: [String: Any]) -> Color {
        let meta = safeDictionary(payload["meta"])
        let type = notificationType(payload, meta)
        let status = notificationStatus(payload, meta)
        let thread = threadID(from: payload)

        if !thread.isEmpty || type == "chat" {
            return Color(uiColor: GM.appPrimaryColor())
        }
        if status.contains("deliver") || status.contains("paid") {
            return .ppSuccess
        }
        if status.contains("ship") {
            return .ppInfo
        }
        if status.contains("fail") || status.contains("cancel") {
            return .ppError
        }
        return .ppWarning
    }

    static func symbolName(for payload: [String: Any]) -> String {
        let meta = safeDictionary(payload["meta"])
        let type = notificationType(payload, meta)
        let thread = threadID(from: payload)
        let order = orderID(from: payload)
        let status = notificationStatus(payload, meta)

        if !thread.isEmpty || type == "chat" {
            return "ellipsis.message.fill"
        }
        if !order.isEmpty || type.hasPrefix("order") {
            if status.contains("deliver") { return "checkmark.seal.fill" }
            if status.contains("ship") { return "shippingbox.fill" }
            if status.contains("fail") || status.contains("cancel") { return "xmark.octagon.fill" }
            return "bag.fill.badge.plus"
        }
        return "bell.badge.fill"
    }
}
