//
//  PPOrderHistorySurfaceModels.swift
//  Pure Pets
//
//  SwiftUI presentation contract for the existing Order History data owner.
//

import Foundation
import SwiftUI
import UIKit

func PPOrderHistoryText(_ key: String) -> String {
    let localized = Language.get(key, alter: key) ?? key
    return localized.isEmpty ? key : localized
}

enum PPOrderHistoryTypography {
    static func display(_ size: CGFloat = 32) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .largeTitle)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .title2)
    }

    static func headline(_ size: CGFloat = 17) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: .headline)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: .body)
    }

    static func callout(_ size: CGFloat = 15) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: .callout)
    }

    static func caption(_ size: CGFloat = 13) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: .caption)
    }
}

@objcMembers
final class PPOrderHistoryFilterDescriptor: NSObject {
    var key = "all"
    var title = ""
    var count = 0
}

@objcMembers
final class PPOrderHistoryItemDescriptor: NSObject {
    var identifier = ""
    var reference = ""
    var statusKey = ""
    var filterKey = "pending"
    var statusTitle = ""
    var dateText = ""
    var primaryDescription = ""
    var amountText = ""
    var imageURL = ""
    var searchIndex = ""
    var quantity = 0
    var progressStage = 0
    var isActive = false
}

@objcMembers
final class PPOrderHistorySnapshotDescriptor: NSObject {
    var items: [PPOrderHistoryItemDescriptor] = []
    var filters: [PPOrderHistoryFilterDescriptor] = []
    var totalCount = 0
    var activeCount = 0
    var totalSpentText = ""
    var errorMessage: String?
    var isInitialLoading = false
    var isLoadingMore = false
    var hasMore = false
    var showsBackButton = false
    var isShowingCachedData = false
}

@objc(PPOrderHistorySurfaceControllerDelegate)
protocol PPOrderHistorySurfaceControllerDelegate: AnyObject {
    func orderHistorySurfaceDidRequestBack()
    func orderHistorySurfaceDidRequestRefresh()
    func orderHistorySurfaceDidRequestLoadMore()
    func orderHistorySurfaceDidRequestSupport()
    func orderHistorySurfaceDidOpenOrder(_ orderID: String)
}

struct PPOrderHistoryItem: Identifiable, Hashable {
    let id: String
    let reference: String
    let statusKey: String
    let filterKey: String
    let statusTitle: String
    let dateText: String
    let primaryDescription: String
    let amountText: String
    let imageURL: String
    let searchIndex: String
    let quantity: Int
    let progressStage: Int
    let isActive: Bool

    init(_ descriptor: PPOrderHistoryItemDescriptor) {
        id = descriptor.identifier
        reference = descriptor.reference
        statusKey = descriptor.statusKey
        filterKey = descriptor.filterKey
        statusTitle = descriptor.statusTitle
        dateText = descriptor.dateText
        primaryDescription = descriptor.primaryDescription
        amountText = descriptor.amountText
        imageURL = descriptor.imageURL
        searchIndex = descriptor.searchIndex
        quantity = descriptor.quantity
        progressStage = descriptor.progressStage
        isActive = descriptor.isActive
    }
}

struct PPOrderHistoryFilter: Identifiable, Hashable {
    let id: String
    let title: String
    let count: Int

    init(_ descriptor: PPOrderHistoryFilterDescriptor) {
        id = descriptor.key
        title = descriptor.title
        count = descriptor.count
    }
}

struct PPOrderHistorySnapshot {
    var items: [PPOrderHistoryItem] = []
    var filters: [PPOrderHistoryFilter] = []
    var totalCount = 0
    var activeCount = 0
    var totalSpentText = ""
    var errorMessage: String?
    var isInitialLoading = true
    var isLoadingMore = false
    var hasMore = false
    var showsBackButton = false
    var isShowingCachedData = false

    init() {}

    init(_ descriptor: PPOrderHistorySnapshotDescriptor) {
        items = descriptor.items.map(PPOrderHistoryItem.init)
        filters = descriptor.filters.map(PPOrderHistoryFilter.init)
        totalCount = descriptor.totalCount
        activeCount = descriptor.activeCount
        totalSpentText = descriptor.totalSpentText
        errorMessage = descriptor.errorMessage
        isInitialLoading = descriptor.isInitialLoading
        isLoadingMore = descriptor.isLoadingMore
        hasMore = descriptor.hasMore
        showsBackButton = descriptor.showsBackButton
        isShowingCachedData = descriptor.isShowingCachedData
    }
}

@MainActor
final class PPOrderHistorySurfaceStore: ObservableObject {
    @Published private(set) var snapshot = PPOrderHistorySnapshot()
    @Published var selectedFilterID = "all"
    @Published var searchText = ""

    weak var delegate: PPOrderHistorySurfaceControllerDelegate?
    private var lastLoadMoreCount: Int?

    var visibleItems: [PPOrderHistoryItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = normalized(trimmed)

        return snapshot.items.filter { item in
            let matchesFilter = selectedFilterID == "all" ||
                item.filterKey == selectedFilterID
            guard matchesFilter else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return normalized(item.searchIndex).contains(normalizedQuery)
        }
    }

    var hasActiveQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedFilterID != "all"
    }

    func apply(_ descriptor: PPOrderHistorySnapshotDescriptor) {
        let previousCount = snapshot.items.count
        snapshot = PPOrderHistorySnapshot(descriptor)
        if !snapshot.filters.contains(where: { $0.id == selectedFilterID }) {
            selectedFilterID = "all"
        }
        if snapshot.items.count != previousCount || !snapshot.isLoadingMore {
            lastLoadMoreCount = nil
        }
    }

    func selectFilter(_ identifier: String) {
        guard selectedFilterID != identifier else { return }
        selectedFilterID = identifier
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func clearQuery() {
        searchText = ""
        selectedFilterID = "all"
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func open(_ item: PPOrderHistoryItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.orderHistorySurfaceDidOpenOrder(item.id)
    }

    func requestRefresh() {
        guard !snapshot.isInitialLoading else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.orderHistorySurfaceDidRequestRefresh()
    }

    func requestSupport() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.orderHistorySurfaceDidRequestSupport()
    }

    func requestBack() {
        delegate?.orderHistorySurfaceDidRequestBack()
    }

    func requestMoreIfNeeded(for item: PPOrderHistoryItem) {
        guard item.id == visibleItems.last?.id,
              snapshot.hasMore,
              !snapshot.isInitialLoading,
              !snapshot.isLoadingMore,
              lastLoadMoreCount != snapshot.items.count
        else { return }
        lastLoadMoreCount = snapshot.items.count
        delegate?.orderHistorySurfaceDidRequestLoadMore()
    }

    private func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        .lowercased()
    }
}
