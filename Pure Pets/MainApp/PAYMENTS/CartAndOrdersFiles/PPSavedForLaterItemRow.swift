//
//  PPSavedForLaterItemRow.swift
//  Pure Pets
//

import SwiftUI

// MARK: - Row

struct PPSavedForLaterItemRow: View {
    let item: CartItem
    let isPending: Bool
    let isLockedByOtherItem: Bool
    let isCompletingMove: Bool
    let pendingOperation: PPSavedForLaterPendingOperation?
    let onMoveToCart: (CartItem) -> Void
    let onRemove: (CartItem) -> Void
    let onNotifyWhenAvailable: (CartItem) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesAccessibleLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var isMoving: Bool {
        isPending && pendingOperation == .move
    }

    private var isDeleting: Bool {
        isPending && pendingOperation == .remove
    }

    private var isNotifying: Bool {
        isPending && pendingOperation == .notify
    }

    private var isOutOfStock: Bool {
        item.stockQuantity != NSNotFound && item.stockQuantity <= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                productImage
                VStack(alignment: .leading, spacing: 8) {
                    titleAndPrice
                        .padding(.top, 2)
                    actionBar
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            completionBadge
                .padding(10)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.055), radius: 18, y: 8)
        .scaleEffect(reduceMotion ? 1 : (isCompletingMove ? 0.985 : 1), anchor: .center)
        .opacity(isLockedByOtherItem ? 0.62 : 1)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: isCompletingMove)
        .animation(.easeOut(duration: 0.16), value: isLockedByOtherItem)
        .accessibilityElement(children: .contain)
    }

    private var productImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill).opacity(colorScheme == .dark ? 0.55 : 0.72))

            PPSavedForLaterRemoteImage(urlString: item.ppImageURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(contentMode: .fit)
        }
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
        .aspectRatio(contentMode: .fit)
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

    private var moveButton: some View {
        PPSavedForLaterMoveToCartButton(
            isLoading: isMoving,
            isCompleted: isCompletingMove,
            isDisabled: isDeleting || isLockedByOtherItem,
            action: {
                onMoveToCart(item)
            }
        )
    }

    private var notifyButton: some View {
        PPSavedForLaterNotifyButton(
            isLoading: isNotifying,
            isDisabled: isMoving || isDeleting || isCompletingMove || isLockedByOtherItem,
            action: {
                onNotifyWhenAvailable(item)
            }
        )
    }

    private var removeButton: some View {
        PPSavedForLaterDeleteButton(
            isLoading: isDeleting,
            isDisabled: isMoving || isNotifying || isCompletingMove || isLockedByOtherItem,
            usesAccessibleLayout: usesAccessibleLayout,
            action: {
                onRemove(item)
            }
        )
    }

    private var actionBar: some View {
        Group {
            if usesAccessibleLayout {
                VStack(spacing: 8) {
                    primaryActionButton
                    removeButton
                }
            } else {
                HStack(spacing: 8) {
                    primaryActionButton
                    removeButton
                }
            }
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if isOutOfStock {
            notifyButton
        } else {
            moveButton
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.ppCard.opacity(colorScheme == .dark ? 0.72 : 0.96))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                Color(uiColor: .lightGray)
                    .opacity(colorScheme == .dark ? 0.30 : 0.18),
                lineWidth: 0.75
            )
    }

    @ViewBuilder
    private var completionBadge: some View {
        if isCompletingMove {
            Label(ppLocalized("saved_for_later_moved_action", fallback: "Moved"), systemImage: "checkmark")
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.ppSuccess, in: Capsule())
                .shadow(color: Color.ppSuccess.opacity(colorScheme == .dark ? 0.20 : 0.24), radius: 12, y: 5)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Move To Cart Button

struct PPSavedForLaterMoveToCartButton: View {
    let isLoading: Bool
    let isCompleted: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            guard !isLoading, !isCompleted, !isDisabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                icon

                Text(title)
                    .font(.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 14)
            .background(background)
            .overlay(border)
            .contentShape(Capsule())
        }
        .buttonStyle(PPSavedForLaterTransactionButtonStyle())
        .disabled(isLoading || isCompleted || isDisabled)
        .opacity(isDisabled && !isLoading && !isCompleted ? 0.54 : 1)
        .accessibilityLabel(ppLocalized("move_to_cart", fallback: "Move to Cart"))
        .accessibilityHint(ppLocalized("saved_for_later_move_hint", fallback: "Moves this item back to your cart"))
    }

    @ViewBuilder
    private var icon: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(0.74)
        } else if isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .scaleEffect(reduceMotion ? 1 : 1.08)
                .transition(.opacity.combined(with: .scale(scale: 0.82)))
        } else {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 13, weight: .bold))
        }
    }

    private var title: String {
        if isLoading {
            return ppLocalized("moving_to_cart", fallback: "Moving...")
        }
        if isCompleted {
            return ppLocalized("saved_for_later_moved_action", fallback: "Moved")
        }
        return ppLocalized("move_to_cart", fallback: "Move to Cart")
    }

    private var background: some View {
        Capsule()
            .fill(isCompleted ? Color.ppSuccess : Color.ppPrimary)
            .shadow(
                color: (isCompleted ? Color.ppSuccess : Color.ppPrimary).opacity(colorScheme == .dark ? 0.20 : 0.26),
                radius: isLoading || isCompleted ? 12 : 16,
                y: 7
            )
    }

    private var border: some View {
        Capsule()
            .stroke(Color.white.opacity(isCompleted ? 0.30 : 0.24), lineWidth: 0.75)
    }
}

// MARK: - Notify Button

struct PPSavedForLaterNotifyButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            guard !isLoading, !isDisabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.ppPrimary)
                        .scaleEffect(0.72)
                } else {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 13, weight: .bold))
                }

                Text(isLoading
                     ? ppLocalized("notify_me_loading", fallback: "Saving alert")
                     : ppLocalized("notify_me", fallback: "Notify me"))
                    .font(.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .foregroundStyle(Color.ppPrimary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 14)
            .background(background)
            .overlay(border)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPSavedForLaterTransactionButtonStyle())
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled && !isLoading ? 0.54 : 1)
        .accessibilityLabel(ppLocalized("notify_me", fallback: "Notify me"))
        .accessibilityHint(ppLocalized("stock_notify_success", fallback: "We will notify you when it is back."))
    }

    private var background: some View {
        Capsule()
            .fill(Color.ppPrimary.opacity(colorScheme == .dark ? 0.18 : 0.10))
            .shadow(
                color: Color.ppPrimary.opacity(colorScheme == .dark ? 0.12 : 0.18),
                radius: 12, y: 6
            )
    }

    private var border: some View {
        Capsule()
            .stroke(Color.ppPrimary.opacity(colorScheme == .dark ? 0.30 : 0.22), lineWidth: 0.75)
    }
}

// MARK: - Delete Button

struct PPSavedForLaterDeleteButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let usesAccessibleLayout: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var buttonSize: CGFloat {
        usesAccessibleLayout ? 54 : 50
    }

    var body: some View {
        Button {
            guard !isLoading, !isDisabled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            ZStack {
                if isLoading {
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
            .frame(width: buttonSize, height: buttonSize)
            .background(background)
            .overlay(border)
            .contentShape(Circle())
        }
        .buttonStyle(PPSavedForLaterTransactionButtonStyle())
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled && !isLoading ? 0.54 : 1)
        .accessibilityLabel(ppLocalized("saved_for_later_delete_action", fallback: "Delete"))
        .accessibilityHint(ppLocalized("saved_for_later_remove_hint", fallback: "Removes this item from saved for later"))
    }

    private var background: some View {
        Circle()
            .fill(Color.ppError.opacity(colorScheme == .dark ? 0.18 : 0.10))
            .overlay(
                Circle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.03 : 0.18))
                    .padding(1)
            )
    }

    private var border: some View {
        Circle()
            .stroke(Color.ppError.opacity(colorScheme == .dark ? 0.30 : 0.22), lineWidth: 0.75)
    }
}

// MARK: - Transaction Button Style

struct PPSavedForLaterTransactionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.955 : 1))
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                .spring(response: 0.24, dampingFraction: 0.72, blendDuration: 0.02),
                value: configuration.isPressed
            )
    }
}
