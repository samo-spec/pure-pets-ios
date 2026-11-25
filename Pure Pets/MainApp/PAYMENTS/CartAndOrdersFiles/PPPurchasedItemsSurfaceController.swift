//
//  PPPurchasedItemsSurfaceController.swift
//  Pure Pets
//
//  ViewController and Observable Store bridging the NextGen Purchased Items Sanctuary to UIKit.
//

import SwiftUI
import UIKit

@available(iOS 15.0, *)
@MainActor
final class PPPurchasedItemsSurfaceStore: ObservableObject {
    @Published var snapshot = PPPurchasedItemsSnapshotDescriptor()
    @Published var searchQuery: String = ""
    @Published var selectedFilterID: String = "all"
    @Published private(set) var itemQuantities: [String: Int] = [:]
    @Published private(set) var addedItemIDs: Set<String> = []

    weak var delegate: PPPurchasedItemsSurfaceControllerDelegate?

    var visibleItems: [PPPurchasedItemDescriptor] {
        let rawItems = snapshot.items
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return rawItems.filter { item in
            // Filter chip check
            if selectedFilterID != "all" {
                if selectedFilterID == "popular" {
                    if item.purchaseCount < 2 { return false }
                } else if item.categoryKey != selectedFilterID {
                    return false
                }
            }

            // Search query check
            if !query.isEmpty {
                let matchesName = item.name.lowercased().contains(query)
                let matchesIndex = item.searchIndex.lowercased().contains(query)
                let matchesDate = item.latestPurchaseDateText.lowercased().contains(query)
                let matchesWeight = item.weightOrSizeText.lowercased().contains(query)
                if !matchesName && !matchesIndex && !matchesDate && !matchesWeight {
                    return false
                }
            }

            return true
        }
    }

    func quantity(for itemID: String) -> Int {
        return itemQuantities[itemID] ?? 1
    }

    func incrementQuantity(for itemID: String) {
        let current = quantity(for: itemID)
        if current < 99 {
            itemQuantities[itemID] = current + 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func decrementQuantity(for itemID: String) {
        let current = quantity(for: itemID)
        if current > 1 {
            itemQuantities[itemID] = current - 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func isItemAdded(_ itemID: String) -> Bool {
        return addedItemIDs.contains(itemID)
    }

    func apply(_ snapshot: PPPurchasedItemsSnapshotDescriptor) {
        self.snapshot = snapshot
    }

    func updateCartBadge(count: Int, total: String) {
        self.snapshot.cartBadgeCount = count
        self.snapshot.cartTotalFormatted = total
    }

    func requestBack() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.purchasedItemsSurfaceDidRequestBack()
    }

    func requestRefresh() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.purchasedItemsSurfaceDidRequestRefresh()
    }

    func requestOpenProduct(itemID: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.purchasedItemsSurfaceDidRequestOpenProduct(itemID: itemID)
    }

    func requestAddToCart(itemID: String, quantity: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        addedItemIDs.insert(itemID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.addedItemIDs.remove(itemID)
        }

        delegate?.purchasedItemsSurfaceDidRequestAddToCart(itemID: itemID, quantity: quantity)
    }

    func requestOpenCart() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.purchasedItemsSurfaceDidRequestOpenCart()
    }

    func requestExploreStore() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.purchasedItemsSurfaceDidRequestExploreStore()
    }
}

@available(iOS 15.0, *)
@MainActor
@objc(PPPurchasedItemsSurfaceController)
final class PPPurchasedItemsSurfaceController: UIViewController {
    private let store = PPPurchasedItemsSurfaceStore()
    private var hostingController: UIHostingController<PPPurchasedItemsScreen>?

    @objc(initWithDelegate:)
    init(delegate: PPPurchasedItemsSurfaceControllerDelegate) {
        super.init(nibName: nil, bundle: nil)
        store.delegate = delegate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPPurchasedItemsSurfaceController is code-only.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear

        let hosting = UIHostingController(
            rootView: PPPurchasedItemsScreen(store: store)
        )
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    @objc(applySnapshot:)
    func applySnapshot(_ descriptor: PPPurchasedItemsSnapshotDescriptor) {
        store.apply(descriptor)
    }

    @objc(updateCartBadgeWithCount:total:)
    func updateCartBadge(count: Int, total: String) {
        store.updateCartBadge(count: count, total: total)
    }
}
