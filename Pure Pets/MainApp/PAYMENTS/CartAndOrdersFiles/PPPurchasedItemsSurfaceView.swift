//
//  PPPurchasedItemsSurfaceView.swift
//  Pure Pets
//
//  Category-defining Pet Restock & Repeat Orders Sanctuary ("خزانة مشترياتي المتكررة").
//

import SwiftUI

@available(iOS 15.0, *)
struct PPPurchasedItemsScreen: View {
    @ObservedObject var store: PPPurchasedItemsSurfaceStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var resolvedLayoutDirection: LayoutDirection {
        Language.isRTL() ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ppBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeader
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.top, PPSpace.sm)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PPSpace.base, pinnedViews: [.sectionHeaders]) {
                        // Quick Stats & Repeat Overview
                        headerSanctuaryCard
                            .padding(.horizontal, PPSpace.screenMargin)
                            .padding(.top, PPSpace.xs)

                        // Frequently Reordered Horizontal Avatars Shelf
                        if !store.snapshot.quickReorderItems.isEmpty {
                            quickReorderShelf
                        }

                        // Search & Filter Sticky Section
                        Section {
                            itemsContent
                                .padding(.horizontal, PPSpace.screenMargin)
                        } header: {
                            discoveryControlsHeader
                        }
                    }
                    // Extra bottom clearance for the floating cart bar
                    .padding(.bottom, store.snapshot.cartBadgeCount > 0 ? 110 : 48)
                }
            }

            // Floating Express Cart Bar
            if store.snapshot.cartBadgeCount > 0 {
                floatingCartBar
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.bottom, PPSpace.md)
            }
        }
        .environment(\.layoutDirection, resolvedLayoutDirection)
    }

    // MARK: - Navigation Header
    private var navigationHeader: some View {
        HStack(spacing: PPSpace.md) {
            if store.snapshot.showsBackButton {
                Button(action: {
                    store.requestBack()
                }) {
                    Image(systemName: resolvedLayoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.ppSurfaceBase)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.ppBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(PPPurchasedText("purchased_items_title"))
                    .font(PPPurchasedTypography.headline(18))
                    .foregroundStyle(Color.ppTextPrimary)

                Text(PPPurchasedText("purchased_sanctuary_subtitle"))
                    .font(PPPurchasedTypography.caption(12))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: PPSpace.sm) {
                Button(action: {
                    store.requestRefresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.ppSurfaceBase)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.ppBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(store.snapshot.isInitialLoading)

                Button(action: {
                    store.requestOpenCart()
                }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.ppPrimary)
                            .frame(width: 42, height: 42)
                            .background(Color.ppSurfaceBase)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.ppBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)

                        if store.snapshot.cartBadgeCount > 0 {
                            Text("\(store.snapshot.cartBadgeCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.ppPrimary)
                                .clipShape(Capsule())
                                .offset(x: 4, y: -3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, PPSpace.xs)
    }

    // MARK: - Header Sanctuary Quick Stats Card
    private var headerSanctuaryCard: some View {
        VStack(spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                // Heart & Restock Icon
                ZStack {
                    Circle()
                        .fill(Color.ppSoftRose)
                        .frame(width: 54, height: 54)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.ppPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(PPPurchasedText("purchased_sanctuary_title"))
                        .font(PPPurchasedTypography.headline(17))
                        .foregroundStyle(Color.ppTextPrimary)

                    Text(PPPurchasedText("purchased_sanctuary_header_desc"))
                        .font(PPPurchasedTypography.caption(12))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .overlay(Color.ppBorder.opacity(0.6))

            // Quick Stats Row
            HStack(spacing: 0) {
                statColumn(
                    value: "\(store.snapshot.totalDistinctCount)",
                    title: PPPurchasedText("purchased_stat_distinct_products")
                )

                Divider()
                    .frame(height: 32)
                    .overlay(Color.ppBorder.opacity(0.6))

                statColumn(
                    value: "\(store.snapshot.totalOrdersCount)",
                    title: PPPurchasedText("purchased_stat_repeat_orders")
                )

                if store.snapshot.readyForRefillCount > 0 {
                    Divider()
                        .frame(height: 32)
                        .overlay(Color.ppBorder.opacity(0.6))

                    statColumn(
                        value: "\(store.snapshot.readyForRefillCount)",
                        title: PPPurchasedText("purchased_stat_ready_refill"),
                        accentColor: Color.ppPrimary
                    )
                }
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppSurfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.ppBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func statColumn(value: String, title: String, accentColor: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PPPurchasedTypography.headline(18))
                .foregroundStyle(accentColor ?? Color.ppTextPrimary)

            Text(title)
                .font(PPPurchasedTypography.caption(11))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Frequently Reordered Avatars Shelf
    private var quickReorderShelf: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack {
                Text(PPPurchasedText("purchased_quick_reorder_title"))
                    .font(PPPurchasedTypography.headline(15))
                    .foregroundStyle(Color.ppTextPrimary)

                Spacer()
            }
            .padding(.horizontal, PPSpace.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.md) {
                    ForEach(store.snapshot.quickReorderItems) { item in
                        quickReorderItemCard(item)
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, PPSpace.xs)
    }

    private func quickReorderItemCard(_ item: PPPurchasedItemDescriptor) -> some View {
        Button(action: {
            store.requestOpenProduct(itemID: item.id)
        }) {
            HStack(spacing: PPSpace.sm) {
                // Round thumbnail
                ZStack {
                    if let url = URL(string: item.imageURL), !item.imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(Color.ppTextSecondary.opacity(0.5))
                            }
                        }
                    } else {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(Color.ppTextSecondary.opacity(0.5))
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.ppBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.ppBorder, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(PPPurchasedTypography.callout(13))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: 110, alignment: .leading)

                    Text(item.cadenceBadgeText)
                        .font(PPPurchasedTypography.micro(10))
                        .foregroundStyle(Color.ppPrimary)
                }

                // 1-Tap Reorder Button
                Button(action: {
                    store.requestAddToCart(itemID: item.id, quantity: 1)
                }) {
                    ZStack {
                        Circle()
                            .fill(store.isItemAdded(item.id) ? Color.ppSuccess : Color.ppPrimary)
                            .frame(width: 32, height: 32)

                        Image(systemName: store.isItemAdded(item.id) ? "checkmark" : "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(item.isOutOfStock)
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, 8)
            .background(Color.ppSurfaceBase)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.ppBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search & Filters Sticky Header
    private var discoveryControlsHeader: some View {
        VStack(spacing: PPSpace.sm) {
            // Search Bar Capsule with Barcode Scanner Icon
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ppTextSecondary)

                TextField(PPPurchasedText("purchased_search_placeholder"), text: $store.searchQuery)
                    .font(PPPurchasedTypography.body(14))
                    .foregroundStyle(Color.ppTextPrimary)

                if !store.searchQuery.isEmpty {
                    Button(action: {
                        store.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 18)
                    .overlay(Color.ppBorder)

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .padding(.horizontal, PPSpace.md)
            .frame(height: 44)
            .background(Color.ppSurfaceBase)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.ppBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
            .padding(.horizontal, PPSpace.screenMargin)

            // Category Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    ForEach(store.snapshot.filters) { filter in
                        filterChip(filter)
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, PPSpace.sm)
        .background(
            Color.ppBackground
                .opacity(0.96)
                .ignoresSafeArea(edges: .horizontal)
        )
    }

    private func filterChip(_ filter: PPPurchasedFilterDescriptor) -> some View {
        let isSelected = store.selectedFilterID == filter.id

        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                store.selectedFilterID = filter.id
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .bold))

                Text(filter.title)
                    .font(PPPurchasedTypography.subheadline(13))

                if filter.count > 0 {
                    Text("(\(filter.count))")
                        .font(PPPurchasedTypography.caption(11))
                        .opacity(isSelected ? 0.9 : 0.6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.ppTextPrimary)
            .background(
                isSelected ? Color.ppPrimary : Color.ppSurfaceBase
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.ppPrimary : Color.ppBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.02), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Items Content / States
    @ViewBuilder
    private var itemsContent: some View {
        if store.snapshot.isInitialLoading {
            // Skeleton Shimmer Loading
            VStack(spacing: PPSpace.md) {
                ForEach(0..<4, id: \.self) { _ in
                    skeletonItemCard
                }
            }
        } else if store.visibleItems.isEmpty {
            if !store.searchQuery.isEmpty || store.selectedFilterID != "all" {
                searchEmptyState
            } else {
                sanctuaryEmptyState
            }
        } else {
            // Category-Defining Product Cards
            VStack(spacing: PPSpace.md) {
                ForEach(store.visibleItems) { item in
                    purchasedProductCard(item)
                }
            }
        }
    }

    // MARK: - Category-Defining Product Card (from 'بيع سريع' spec)
    private func purchasedProductCard(_ item: PPPurchasedItemDescriptor) -> some View {
        let isAdded = store.isItemAdded(item.id)
        let qty = store.quantity(for: item.id)

        return VStack(spacing: 0) {
            // Top Category Tag & Cadence Row
            HStack(spacing: PPSpace.xs) {
                if !item.categoryTagText.isEmpty {
                    Text(item.categoryTagText)
                        .font(PPPurchasedTypography.micro(11))
                        .foregroundStyle(Color.ppTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.ppBackground)
                        .clipShape(Capsule())
                }

                Spacer()

                // Restock Cadence Pill
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold))

                    Text(item.cadenceBadgeText)
                        .font(PPPurchasedTypography.micro(11))

                    if item.isReadyForRefill {
                        Text("• " + PPPurchasedText("purchased_cadence_ready_badge"))
                            .font(PPPurchasedTypography.micro(11))
                            .foregroundStyle(Color.ppPrimary)
                    }
                }
                .foregroundStyle(Color.ppPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.ppSoftRose.opacity(0.8))
                .clipShape(Capsule())
            }
            .padding(.bottom, 8)

            Button(action: {
                store.requestOpenProduct(itemID: item.id)
            }) {
                HStack(alignment: .top, spacing: PPSpace.md) {
                    // Product Image (86x86)
                    ZStack(alignment: .topLeading) {
                        if let url = URL(string: item.imageURL), !item.imageURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                default:
                                    Image(systemName: "shippingbox.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(Color.ppTextSecondary.opacity(0.4))
                                }
                            }
                        } else {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Color.ppTextSecondary.opacity(0.4))
                        }

                        // Ready for Refill Indicator Tag
                        if item.isReadyForRefill {
                            Circle()
                                .fill(Color.ppPrimary)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .padding(6)
                        }
                    }
                    .frame(width: 86, height: 86)
                    .background(Color.ppBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.ppBorder, lineWidth: 1)
                    )

                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        // Title
                        Text(item.name)
                            .font(PPPurchasedTypography.headline(15))
                            .foregroundStyle(Color.ppTextPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Weight or Size
                        if !item.weightOrSizeText.isEmpty {
                            Text(item.weightOrSizeText)
                                .font(PPPurchasedTypography.caption(12))
                                .foregroundStyle(Color.ppTextSecondary)
                        }

                        // Prominent Crimson Price & In-Stock Pill
                        HStack(spacing: PPSpace.sm) {
                            Text(item.formattedPrice)
                                .font(PPPurchasedTypography.headline(17))
                                .foregroundStyle(Color.ppPrimary)

                            if item.hasDiscount && !item.formattedOriginalPrice.isEmpty {
                                Text(item.formattedOriginalPrice)
                                    .font(PPPurchasedTypography.caption(12))
                                    .foregroundStyle(Color.ppTextSecondary)
                                    .strikethrough(true, color: Color.ppTextSecondary)
                            }

                            Spacer()

                            // In-Stock Status Pill
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(item.isOutOfStock ? Color.red : Color.ppSuccess)
                                    .frame(width: 6, height: 6)

                                Text(item.stockStatusText)
                                    .font(PPPurchasedTypography.caption(11))
                                    .foregroundStyle(item.isOutOfStock ? Color.red : Color.ppSuccess)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(Color.ppBorder.opacity(0.5))
                .padding(.vertical, PPSpace.sm)

            // Bottom Tactile Actions: Date + Stepper + 1-Tap Reorder Button
            HStack(spacing: PPSpace.sm) {
                // Latest purchase date
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.ppTextSecondary)

                    Text(item.latestPurchaseDateText)
                        .font(PPPurchasedTypography.caption(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }

                Spacer()

                // Quantity Stepper (if in stock)
                if !item.isOutOfStock {
                    HStack(spacing: 8) {
                        Button(action: {
                            store.decrementQuantity(for: item.id)
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(qty > 1 ? Color.ppTextPrimary : Color.ppTextSecondary.opacity(0.4))
                                .frame(width: 28, height: 28)
                                .background(Color.ppBackground)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(qty <= 1)

                        Text("\(qty)")
                            .font(PPPurchasedTypography.headline(14))
                            .foregroundStyle(Color.ppTextPrimary)
                            .frame(minWidth: 20)

                        Button(action: {
                            store.incrementQuantity(for: item.id)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.ppTextPrimary)
                                .frame(width: 28, height: 28)
                                .background(Color.ppBackground)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.ppBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.ppBorder, lineWidth: 1))
                }

                // 1-Tap Express Buy / Reorder Button
                Button(action: {
                    store.requestAddToCart(itemID: item.id, quantity: qty)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isAdded ? "checkmark" : "cart.badge.plus")
                            .font(.system(size: 13, weight: .bold))

                        Text(isAdded ? PPPurchasedText("purchased_express_added_button") : PPPurchasedText("purchased_express_reorder_button"))
                            .font(PPPurchasedTypography.headline(13))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color.white)
                    .background(
                        item.isOutOfStock
                            ? Color.gray.opacity(0.4)
                            : (isAdded ? Color.ppSuccess : Color.ppPrimary)
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(item.isOutOfStock ? 0 : 0.08), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(item.isOutOfStock)
            }
        }
        .padding(PPSpace.md)
        .background(Color.ppSurfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.ppBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Floating Cart Bar (from 'بيع سريع' spec)
    private var floatingCartBar: some View {
        Button(action: {
            store.requestOpenCart()
        }) {
            HStack(spacing: PPSpace.md) {
                // Cart Icon with Badge
                ZStack {
                    Circle()
                        .fill(Color.ppSoftRose)
                        .frame(width: 44, height: 44)

                    Image(systemName: "bag.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.ppPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: PPPurchasedText("purchased_floating_cart_title_format"), store.snapshot.cartBadgeCount))
                        .font(PPPurchasedTypography.headline(15))
                        .foregroundStyle(Color.ppTextPrimary)

                    if !store.snapshot.cartTotalFormatted.isEmpty {
                        Text(store.snapshot.cartTotalFormatted)
                            .font(PPPurchasedTypography.subheadline(13))
                            .foregroundStyle(Color.ppPrimary)
                    }
                }

                Spacer()

                // Action CTA
                HStack(spacing: 5) {
                    Text(PPPurchasedText("purchased_floating_cart_cta"))
                        .font(PPPurchasedTypography.headline(13))

                    Image(systemName: resolvedLayoutDirection == .rightToLeft ? "arrow.left" : "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.ppPrimary)
                .clipShape(Capsule())
            }
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, 10)
            .background(Color.ppSurfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.ppBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Skeleton Shimmer Loading
    private var skeletonItemCard: some View {
        HStack(spacing: PPSpace.md) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.ppBorder.opacity(0.5))
                .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.ppBorder.opacity(0.4))
                    .frame(width: 100, height: 16)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.ppBorder.opacity(0.5))
                    .frame(height: 18)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.ppBorder.opacity(0.3))
                    .frame(width: 140, height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PPSpace.md)
        .background(Color.ppSurfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.ppBorder, lineWidth: 1)
        )
        .opacity(0.7)
    }

    // MARK: - Empty States
    private var sanctuaryEmptyState: some View {
        VStack(spacing: PPSpace.base) {
            ZStack {
                Circle()
                    .fill(Color.ppSoftRose)
                    .frame(width: 90, height: 90)

                Image(systemName: "bag.badge.plus")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .padding(.top, PPSpace.xl)

            Text(PPPurchasedText("purchased_empty_sanctuary_title"))
                .font(PPPurchasedTypography.headline(20))
                .foregroundStyle(Color.ppTextPrimary)

            Text(PPPurchasedText("purchased_empty_sanctuary_sub"))
                .font(PPPurchasedTypography.body(14))
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PPSpace.xl)

            Button(action: {
                store.requestExploreStore()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))

                    Text(PPPurchasedText("purchased_empty_explore_cta"))
                        .font(PPPurchasedTypography.headline(15))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.ppPrimary)
                .clipShape(Capsule())
                .shadow(color: Color.ppPrimary.opacity(0.24), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, PPSpace.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PPSpace.xxl)
    }

    private var searchEmptyState: some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
                .padding(.top, PPSpace.lg)

            Text(PPPurchasedText("purchased_search_empty_title"))
                .font(PPPurchasedTypography.headline(17))
                .foregroundStyle(Color.ppTextPrimary)

            Text(PPPurchasedText("purchased_search_empty_sub"))
                .font(PPPurchasedTypography.caption(13))
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PPSpace.xl)

            Button(action: {
                store.searchQuery = ""
                store.selectedFilterID = "all"
            }) {
                Text(PPPurchasedText("purchased_search_clear_button"))
                    .font(PPPurchasedTypography.headline(13))
                    .foregroundStyle(Color.ppPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.ppSoftRose)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PPSpace.xl)
    }
}
