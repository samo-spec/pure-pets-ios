//
//  PPSavedForLaterSheetView.swift
//  Pure Pets
//
//  SwiftUI content for the saved-for-later sheet. The saved/cart
//  managers and cart refresh callbacks remain owned by PPSavedForLaterBottomSheetVC.
//

import SwiftUI
import UIKit

@objc(PPSavedForLaterSheetContentControllerDelegate)
public protocol PPSavedForLaterSheetContentControllerDelegate: AnyObject {
    @objc(savedForLaterSheetContentControllerDidRequestDismiss:)
    func savedForLaterSheetContentControllerDidRequestDismiss(_ controller: PPSavedForLaterSheetContentController)

    @objc(savedForLaterSheetContentControllerDidRequestRetry:)
    func savedForLaterSheetContentControllerDidRequestRetry(_ controller: PPSavedForLaterSheetContentController)

    @objc(savedForLaterSheetContentController:didRequestMoveToCart:)
    func savedForLaterSheetContentController(
        _ controller: PPSavedForLaterSheetContentController,
        didRequestMoveToCart item: CartItem
    )

    @objc(savedForLaterSheetContentController:didRequestRemove:)
    func savedForLaterSheetContentController(
        _ controller: PPSavedForLaterSheetContentController,
        didRequestRemove item: CartItem
    )
}

@objc(PPSavedForLaterSheetContentController)
public final class PPSavedForLaterSheetContentController: UIViewController {
    @objc public weak var delegate: PPSavedForLaterSheetContentControllerDelegate?

    private let store = PPSavedForLaterSheetStore()
    private var hostingController: UIHostingController<PPSavedForLaterSheetRootView>?

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isOpaque = false
        view.clipsToBounds = false

        let rootView = PPSavedForLaterSheetRootView(
            store: store,
            onDismiss: { [weak self] in
                guard let self else { return }
                self.delegate?.savedForLaterSheetContentControllerDidRequestDismiss(self)
            },
            onRetry: { [weak self] in
                guard let self else { return }
                self.delegate?.savedForLaterSheetContentControllerDidRequestRetry(self)
            },
            onMoveToCart: { [weak self] item in
                guard let self else { return }
                self.store.beginPending(item: item, operation: .move)
                self.delegate?.savedForLaterSheetContentController(self, didRequestMoveToCart: item)
            },
            onRemove: { [weak self] item in
                guard let self else { return }
                self.store.beginPending(item: item, operation: .remove)
                self.delegate?.savedForLaterSheetContentController(self, didRequestRemove: item)
            }
        )

        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false

        addChild(controller)
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    @objc(configureWithSavedItems:animated:)
    public func configure(savedItems: [CartItem], animated: Bool) {
        store.setItems(savedItems, animated: animated)
    }

    @objc(setLoading:)
    public func setLoading(_ loading: Bool) {
        store.setLoading(loading)
    }

    @objc(setPendingItemID:operation:)
    public func setPendingItemID(_ itemID: String?, operation: String?) {
        store.setPendingItemID(itemID, operation: operation.flatMap(PPSavedForLaterPendingOperation.init(rawValue:)))
    }

    @objc(showStatusMessage:success:)
    public func showStatusMessage(_ message: String, success: Bool) {
        store.showStatus(message, kind: success ? .success : .error)
    }

    @objc(showErrorMessage:)
    public func showErrorMessage(_ message: String) {
        store.showError(message)
    }
}

// MARK: - State

private enum PPSavedForLaterPresentation: Equatable {
    case loading
    case content
    case empty
    case error(String)
}

private enum PPSavedForLaterPendingOperation: String {
    case move
    case remove
}

private enum PPSavedForLaterStatusKind {
    case success
    case error
}

private final class PPSavedForLaterSheetStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    @Published private(set) var presentation: PPSavedForLaterPresentation = .loading
    @Published private(set) var pendingItemID: String?
    @Published private(set) var pendingOperation: PPSavedForLaterPendingOperation?
    @Published private(set) var hasEntered = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusKind: PPSavedForLaterStatusKind = .success

    private var statusToken = UUID()

    var countText: String {
        String(
            format: ppLocalized("saved_for_later_count_format", fallback: "%ld saved"),
            items.count
        )
    }

    var itemsSignature: String {
        items.map(\.ppSavedStableID).joined(separator: "|")
    }

    func setItems(_ newItems: [CartItem], animated: Bool) {
        let apply = {
            self.items = newItems
            self.presentation = newItems.isEmpty ? .empty : .content
        }

        if animated && !UIAccessibility.isReduceMotionEnabled {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                apply()
            }
        } else {
            apply()
        }
    }

    func setLoading(_ loading: Bool) {
        guard loading else { return }
        presentation = .loading
    }

    func activateEntrance(reduceMotion: Bool) {
        guard !hasEntered else { return }
        if reduceMotion {
            hasEntered = true
        } else {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                hasEntered = true
            }
        }
    }

    func beginPending(item: CartItem, operation: PPSavedForLaterPendingOperation) {
        pendingItemID = item.ppSavedStableID
        pendingOperation = operation
    }

    func setPendingItemID(_ itemID: String?, operation: PPSavedForLaterPendingOperation?) {
        pendingItemID = itemID?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingOperation = operation
    }

    func showStatus(_ message: String, kind: PPSavedForLaterStatusKind) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return }

        statusKind = kind
        statusMessage = cleanMessage

        switch kind {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        let token = UUID()
        statusToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.statusToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                self.statusMessage = nil
            }
        }
    }

    func showError(_ message: String) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if items.isEmpty {
            presentation = .error(cleanMessage.isEmpty ? ppLocalized("SomethingWentWrong", fallback: "Something went wrong") : cleanMessage)
        } else {
            showStatus(cleanMessage.isEmpty ? ppLocalized("SomethingWentWrong", fallback: "Something went wrong") : cleanMessage, kind: .error)
        }
    }
}

// MARK: - Root View

private struct PPSavedForLaterSheetRootView: View {
    @ObservedObject var store: PPSavedForLaterSheetStore

    let onDismiss: () -> Void
    let onRetry: () -> Void
    let onMoveToCart: (CartItem) -> Void
    let onRemove: (CartItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var sheetShape: PPSavedForLaterTopRoundedShape {
        PPSavedForLaterTopRoundedShape(radius: 34)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 24)
                    .opacity(store.hasEntered ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (store.hasEntered ? 0 : 10))

                stateContent
                    .opacity(store.hasEntered ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (store.hasEntered ? 0 : 14))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground)
            .clipShape(sheetShape)
            .overlay(sheetBorder)
            .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)

            statusToast
                .padding(.top, 16)
                .padding(.horizontal, 20)
        }
        .onAppear {
            store.activateEntrance(reduceMotion: reduceMotion)
        }
    }

    private var sheetBackground: some View {
        Color.clear
            .allowsHitTesting(false)
    }

    private var sheetBorder: some View {
        sheetShape
            .stroke(
                Color(uiColor: .separator).opacity(colorScheme == .dark ? 0.34 : 0.22),
                lineWidth: 0.75
            )
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                iconMark

                VStack(alignment: .leading, spacing: 4) {
                    Text(ppLocalized("saved_for_later", fallback: "Saved for later"))
                        .font(.custom("Beiruti-Bold", size: 28, relativeTo: .title2))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(store.countText)
                        .font(.custom("Beiruti-Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.ppTextSecondary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .separator).opacity(0.20), lineWidth: 0.75)
                        )
                }
                .buttonStyle(PPSavedForLaterPressButtonStyle())
                .accessibilityLabel(ppLocalized("saved_for_later_close_accessibility", fallback: "Close saved items"))
                .accessibilityHint(ppLocalized("Swipe_Down_To_Close", fallback: "Swipe down to close"))
            }

            Text(ppLocalized("choose_items_to_move", fallback: "Choose items to move to cart"))
                .font(.custom("Beiruti-Medium", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var iconMark: some View {
        ZStack {
            Circle()
                .fill(Color.ppPrimary.opacity(colorScheme == .dark ? 0.18 : 0.12))
            Circle()
                .stroke(Color.ppPrimary.opacity(0.20), lineWidth: 0.75)
            Image(systemName: "bookmark.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch store.presentation {
        case .loading:
            PPSavedForLaterLoadingView()
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.opacity)
        case .empty:
            PPSavedForLaterEmptyView(onDismiss: onDismiss)
                .padding(.horizontal, 24)
                .padding(.top, 38)
                .transition(.opacity)
        case .error(let message):
            PPSavedForLaterErrorView(message: message, onRetry: onRetry)
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .transition(.opacity)
        case .content:
            itemList
                .transition(.opacity)
        }
    }

    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(store.items, id: \.ppSavedStableID) { item in
                    PPSavedForLaterItemRow(
                        item: item,
                        isPending: store.pendingItemID == item.ppSavedStableID,
                        pendingOperation: store.pendingOperation,
                        onMoveToCart: onMoveToCart,
                        onRemove: onRemove
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.985))
                        )
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.32, dampingFraction: 0.90),
            value: store.itemsSignature
        )
    }

    @ViewBuilder
    private var statusToast: some View {
        if let message = store.statusMessage {
            HStack(spacing: 9) {
                Image(systemName: store.statusKind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.statusKind == .success ? Color.ppSuccess : Color.ppError)
                Text(message)
                    .font(.custom("Beiruti-Bold", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color(uiColor: .separator).opacity(0.20), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 18, y: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Rows

private struct PPSavedForLaterItemRow: View {
    let item: CartItem
    let isPending: Bool
    let pendingOperation: PPSavedForLaterPendingOperation?
    let onMoveToCart: (CartItem) -> Void
    let onRemove: (CartItem) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var usesAccessibleLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                productImage
                titleAndPrice
                    .padding(.top, 2)
            }

            actionBar
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.055), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }

    private var productImage: some View {
        PPSavedForLaterRemoteImage(urlString: item.ppImageURL)
            .frame(width: usesAccessibleLayout ? 86 : 78, height: usesAccessibleLayout ? 86 : 78)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.20), lineWidth: 0.75)
            )
            .accessibilityLabel(
                String(
                    format: ppLocalized("saved_for_later_image_accessibility", fallback: "Image for %@"),
                    item.ppDisplayName
                )
            )
    }

    private var titleAndPrice: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.ppDisplayName)
                .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            priceLine

            Label(ppLocalized("saved_for_later_item_badge", fallback: "Ready when you are"), systemImage: "clock.arrow.circlepath")
                .font(.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var priceLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(item.ppFormattedPrice)
                .font(.custom("Beiruti-Bold", size: 16, relativeTo: .callout))
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.84)

            if item.ppHasDiscount {
                Text(item.ppFormattedOriginalPrice)
                    .font(.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
                    .overlay(
                        Rectangle()
                            .fill(Color.ppTextSecondary.opacity(0.64))
                            .frame(height: 1),
                        alignment: .center
                    )
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: ppLocalized("saved_for_later_price_accessibility", fallback: "Price %@"),
                item.ppFormattedPrice
            )
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            moveButton
            removeButton
        }
        .padding(5)
        .background(actionBarBackground)
        .overlay(actionBarBorder)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var moveButton: some View {
        Button {
            guard !isPending else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onMoveToCart(item)
        } label: {
            HStack(spacing: 7) {
                if isPending && pendingOperation == .move {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.74)
                } else {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                }

                Text(isPending && pendingOperation == .move
                     ? ppLocalized("moving_to_cart", fallback: "Moving...")
                     : ppLocalized("move_to_cart", fallback: "Move to Cart"))
                    .font(.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 14)
            .background(moveButtonBackground)
            .overlay(moveButtonBorder)
            .contentShape(Capsule())
        }
        .buttonStyle(PPSavedForLaterPressButtonStyle())
        .disabled(isPending)
        .opacity(isPending && pendingOperation != .move ? 0.48 : 1)
        .accessibilityLabel(ppLocalized("move_to_cart", fallback: "Move to Cart"))
        .accessibilityHint(ppLocalized("saved_for_later_move_hint", fallback: "Moves this item back to your cart"))
    }

    private var removeButton: some View {
        Button {
            guard !isPending else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onRemove(item)
        } label: {
            HStack(spacing: 7) {
                if isPending && pendingOperation == .remove {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.ppError)
                        .scaleEffect(0.72)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(Color.ppError)
            .frame(width: 48, height: 48)
            .background(removeButtonBackground)
            .overlay(removeButtonBorder)
            .contentShape(Circle())
        }
        .buttonStyle(PPSavedForLaterPressButtonStyle())
        .disabled(isPending)
        .opacity(isPending && pendingOperation != .remove ? 0.48 : 1)
        .accessibilityLabel(ppLocalized("saved_for_later_remove_action", fallback: "Remove"))
        .accessibilityHint(ppLocalized("saved_for_later_remove_hint", fallback: "Removes this item from saved for later"))
    }

    private var actionBarBackground: some View {
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 0.42 : 0.74))
    }

    private var actionBarBorder: some View {
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .stroke(Color(uiColor: .separator).opacity(colorScheme == .dark ? 0.20 : 0.14), lineWidth: 0.75)
    }

    private var moveButtonBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.ppPrimary.opacity(colorScheme == .dark ? 0.96 : 1),
                        Color.ppPrimary.opacity(colorScheme == .dark ? 0.74 : 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
                    .frame(height: 18)
                    .padding(.horizontal, 1)
                    .blur(radius: 0.35)
            }
            .shadow(color: Color.ppPrimary.opacity(colorScheme == .dark ? 0.20 : 0.16), radius: 12, y: 6)
    }

    private var moveButtonBorder: some View {
        Capsule()
            .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
    }

    private var removeButtonBackground: some View {
        Circle()
            .fill(Color.ppError.opacity(colorScheme == .dark ? 0.18 : 0.10))
            .overlay(
                Circle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.18))
                    .padding(1)
            )
    }

    private var removeButtonBorder: some View {
        Circle()
            .stroke(Color.ppError.opacity(colorScheme == .dark ? 0.28 : 0.20), lineWidth: 0.75)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.ppCard.opacity(colorScheme == .dark ? 0.72 : 0.96))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                Color(uiColor: .lightGray)
                    .opacity(colorScheme == .dark ? 0.30 : 0.18),
                lineWidth: 0.75
            )
    }
}

// MARK: - States

private struct PPSavedForLaterLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(uiColor: .systemFill))
                            .frame(width: 78, height: 78)

                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .systemFill))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemFill))
                                .frame(width: 128, height: 12)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(width: 104, height: 12)
                        }
                        .padding(.top, 3)
                    }

                    HStack(spacing: 10) {
                        Capsule()
                            .fill(Color(uiColor: .systemFill))
                            .frame(maxWidth: .infinity, minHeight: 48)

                        Circle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(width: 48, height: 48)
                    }
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72))
                    )
                }
                .padding(12)
                .background(Color.ppCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ppLocalized("saved_for_later_loading", fallback: "Loading saved items"))
    }
}

private struct PPSavedForLaterEmptyView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.12))
                Image(systemName: "bookmark.slash")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .frame(width: 82, height: 82)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(ppLocalized("saved_for_later_empty_title", fallback: "Nothing saved yet"))
                    .font(.custom("Beiruti-Bold", size: 22, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(ppLocalized("saved_for_later_empty_message", fallback: "Items you save from the marketplace will wait here until you are ready to buy."))
                    .font(.custom("Beiruti-Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onDismiss) {
                Text(ppLocalized("KLang_Close", fallback: "Close"))
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PPSavedForLaterPrimaryTextButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct PPSavedForLaterErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.ppError.opacity(0.12))
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.ppError)
            }
            .frame(width: 78, height: 78)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(ppLocalized("SomethingWentWrong", fallback: "Something went wrong"))
                    .font(.custom("Beiruti-Bold", size: 22, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message.isEmpty ? ppLocalized("saved_for_later_retry_message", fallback: "We could not refresh your saved items. Please try again.") : message)
                    .font(.custom("Beiruti-Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRetry) {
                Label(ppLocalized("KLang_Retry", fallback: "Retry"), systemImage: "arrow.clockwise")
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PPSavedForLaterPrimaryTextButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Image

private final class PPSavedForLaterImageView: UIImageView {
    var representedURLString = ""
}

private struct PPSavedForLaterRemoteImage: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> PPSavedForLaterImageView {
        let imageView = PPSavedForLaterImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .secondarySystemFill
        imageView.tintColor = UIColor(named: "AppPrimaryColor") ?? .systemBlue
        imageView.isAccessibilityElement = false
        return imageView
    }

    func updateUIView(_ imageView: PPSavedForLaterImageView, context: Context) {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageView.representedURLString != trimmedURLString else { return }

        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        imageView.representedURLString = trimmedURLString
        imageView.contentMode = .scaleAspectFill

        let placeholder = UIImage(named: "placeholder")
            ?? UIImage(systemName: "bag.fill")?.withRenderingMode(.alwaysTemplate)
        imageView.image = placeholder

        guard !trimmedURLString.isEmpty else {
            imageView.contentMode = .scaleAspectFit
            return
        }

        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: trimmedURLString,
            placeholder: placeholder,
            transitionStyle: .crossDissolve,
            completion: nil
        )
    }

    static func dismantleUIView(_ imageView: PPSavedForLaterImageView, coordinator: Void) {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        imageView.representedURLString = ""
    }
}

// MARK: - Styling

private struct PPSavedForLaterTopRoundedShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct PPSavedForLaterPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.965 : 1))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct PPSavedForLaterPrimaryTextButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Color.ppPrimary, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .animation(.spring(response: 0.18, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

// MARK: - Helpers

private func ppLocalized(_ key: String, fallback: String) -> String {
    let value = Language.get(key, alter: fallback) ?? fallback
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || trimmed == key ? fallback : value
}

private extension CartItem {
    var ppSavedStableID: String {
        let cleanID = (itemID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanID.isEmpty {
            return cleanID
        }
        return String(ObjectIdentifier(self).hashValue)
    }

    var ppDisplayName: String {
        let cleanName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? ppLocalized("saved_for_later_unknown_item", fallback: "Saved item") : cleanName
    }

    var ppImageURL: String {
        (imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var ppHasDiscount: Bool {
        originalPrice > price && price > 0
    }

    var ppFormattedPrice: String {
        String(format: "%.2f %@", price, ppLocalized("Rials", fallback: "QAR"))
    }

    var ppFormattedOriginalPrice: String {
        String(format: "%.2f %@", originalPrice, ppLocalized("Rials", fallback: "QAR"))
    }
}
