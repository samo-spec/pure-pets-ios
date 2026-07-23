//
//  PPCartFloatingBarState.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Foundation

/// Value type representing floating cart bar presentation state, item counts, totals, and collapse state.
public struct PPCartFloatingBarState: Equatable, Sendable {
    public var itemCount: Int
    public var totalAmount: Double
    public var isVisible: Bool
    public var isCollapsed: Bool
    
    public init(
        itemCount: Int = 0,
        totalAmount: Double = 0.0,
        isVisible: Bool = false,
        isCollapsed: Bool = false
    ) {
        self.itemCount = max(0, itemCount)
        self.totalAmount = max(0.0, totalAmount)
        self.isVisible = isVisible
        self.isCollapsed = isCollapsed
    }
    
    /// Formatted count badge text ("99+" when count exceeds 99).
    public var badgeText: String {
        itemCount > 99 ? "99+" : "\(itemCount)"
    }
    
    /// Formatted count string matching legacy `PPCartFloatingBarCountText`.
    public var countText: String {
        if itemCount == 1 {
            let singleFormat = NSLocalizedString("myitems_count_single", value: "1 item", comment: "")
            return singleFormat.isEmpty ? "1 item" : singleFormat
        }
        let format = NSLocalizedString("myitems_count_format", value: "%ld items", comment: "")
        if format.isEmpty || !format.contains("%") {
            return "\(itemCount) items"
        }
        return String(format: format, itemCount)
    }
    
    /// Formatted price text.
    public var formattedAmountText: String {
        let currency = NSLocalizedString("Rials", value: "QAR", comment: "Currency")
        let resolvedCurrency = currency.isEmpty ? "QAR" : currency
        return String(format: "%.2f %@", totalAmount, resolvedCurrency)
    }
    
    /// Combined subtitle string ("1 item · 150.00 QAR").
    public var subtitleText: String {
        "\(countText) · \(formattedAmountText)"
    }
}
