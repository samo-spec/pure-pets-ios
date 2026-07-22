import SwiftUI

// MARK: - Sheet Item (for .sheet(item:) pattern)

public struct PPSavedForLaterSheetItem: Identifiable {
    public let id = UUID()
    public let savedItems: [CartItem]

    public init(savedItems: [CartItem]) {
        self.savedItems = savedItems
    }
}

// MARK: - SwiftUI Sheet View

public struct PPSavedForLaterSheetSwiftUIView: View {
    @StateObject private var store = PPSavedForLaterSheetStore()
    @Environment(\.dismiss) private var dismiss

    private let savedItems: [CartItem]
    private let onRetry: () -> Void
    private let onMoveToCart: (CartItem) -> Void
    private let onRemove: (CartItem) -> Void
    private let onNotifyWhenAvailable: (CartItem) -> Void

    public init(
        savedItems: [CartItem],
        onRetry: @escaping () -> Void,
        onMoveToCart: @escaping (CartItem) -> Void,
        onRemove: @escaping (CartItem) -> Void,
        onNotifyWhenAvailable: @escaping (CartItem) -> Void
    ) {
        self.savedItems = savedItems
        self.onRetry = onRetry
        self.onMoveToCart = onMoveToCart
        self.onRemove = onRemove
        self.onNotifyWhenAvailable = onNotifyWhenAvailable
    }

    public var body: some View {
        PPSavedForLaterSheetRootView(
            store: store,
            onDismiss: { dismiss() },
            onRetry: onRetry,
            onMoveToCart: { item in
                store.beginPending(item: item, operation: .move)
                onMoveToCart(item)
            },
            onRemove: { item in
                onRemove(item)
            },
            onNotifyWhenAvailable: { item in
                store.beginPending(item: item, operation: .notify)
                onNotifyWhenAvailable(item)
            }
        )
        .onAppear {
            store.setItems(savedItems, animated: true)
        }
    }
}

// MARK: - View Extension

extension View {
    public func savedForLaterSheet(
        item: Binding<PPSavedForLaterSheetItem?>,
        onRetry: @escaping () -> Void = {},
        onMoveToCart: @escaping (CartItem) -> Void,
        onRemove: @escaping (CartItem) -> Void,
        onNotifyWhenAvailable: @escaping (CartItem) -> Void
    ) -> some View {
        self.sheet(item: item) { sheetItem in
            PPSavedForLaterSheetSwiftUIView(
                savedItems: sheetItem.savedItems,
                onRetry: onRetry,
                onMoveToCart: onMoveToCart,
                onRemove: onRemove,
                onNotifyWhenAvailable: onNotifyWhenAvailable
            )
        }
    }
}
