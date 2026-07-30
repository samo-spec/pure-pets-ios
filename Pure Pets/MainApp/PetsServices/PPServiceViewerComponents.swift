import SwiftUI
import UIKit

// MARK: - Hero Header

struct PPServiceViewerHeroHeader: View {
    let imageURL: String?
    let blurHash: String?
    let cacheKey: String?
    let height: CGFloat
    let compact: Bool
    var onImageLoaded: ((UIImage) -> Void)? = nil

    private var galleryShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: compact ? 28 : 34,
            style: .continuous
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let imageURL, !imageURL.isEmpty {
                PPAccessoryRemoteImageView(
                    urlString: imageURL,
                    blurHash: blurHash,
                    contentMode: .fill,
                    accessibilityLabel: PPServiceViewerL10n.text("service_view_details_title", fallback: "Service Details"),
                    cacheKey: cacheKey,
                    onImageLoaded: onImageLoaded
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.ppPrimary.opacity(0.18),
                            Color.ppPrimary.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(Color.ppPrimary.opacity(0.42))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.clear,
                    Color.black.opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(height: height)
        .clipShape(galleryShape)
        .overlay {
            galleryShape
                .stroke(Color.ppTextPrimary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Title Card (Main Service Identity)

struct PPServiceViewerTitleCard: View {
    let snapshot: PPServiceViewerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if !snapshot.category.isEmpty {
                        categoryBadge(snapshot.category)
                    }

                    Text(snapshot.title)
                        .font(PPAccessoryTypography.hero)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer(minLength: 8)

                priceBadge(snapshot.price)
            }

            if !snapshot.serviceTypeText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.ppPrimary)

                    Text(snapshot.serviceTypeText)
                        .font(PPAccessoryTypography.captionBold)
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .ppGlassSurface(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            tint: Color.ppCard.opacity(0.85),
            fallback: Color(uiColor: .systemBackground).opacity(0.95),
            stroke: Color.white.opacity(0.22)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private func categoryBadge(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.ppPrimary)

            Text(text)
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(Color.ppPrimaryDarker)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.ppPrimary.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.ppPrimary.opacity(0.22), lineWidth: 0.8)
        )
    }

    private func priceBadge(_ price: String) -> some View {
        VStack(spacing: 2) {
            Text(PPServiceViewerL10n.text("Price", fallback: "Price"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.80))

            Text(price)
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.ppPrimary, Color.ppPrimaryDarker],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.ppPrimary.opacity(0.3), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(PPServiceViewerL10n.text("Price", fallback: "Price")): \(price)")
    }
}

// MARK: - Provider Card (Trust Component)

struct PPServiceViewerProviderCard: View {
    let snapshot: PPServiceViewerSnapshot
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if let avatarURL = snapshot.ownerAvatarURL, !avatarURL.isEmpty {
                PPAccessoryRemoteImageView(
                    urlString: avatarURL,
                    blurHash: nil,
                    contentMode: .fit,
                    accessibilityLabel: snapshot.ownerName,
                    cacheKey: snapshot.ownerID,
                    displaySize: CGSize(width: 48, height: 48)
                )
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.ppPrimary.opacity(0.24), lineWidth: 1))
            } else {
                ZStack {
                    Circle()
                        .fill(Color.ppPrimary.opacity(0.14))

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.ppPrimary)
                }
                .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.ownerName)
                    .font(PPAccessoryTypography.headline)
                    .foregroundStyle(Color.ppTextPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.ppPrimary)

                    Text(PPServiceViewerL10n.text("service_view_provider_verified", fallback: "Verified Provider"))
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            if snapshot.ownerPhone != nil {
                Button(action: onCall) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(PPServiceViewerL10n.text("Call", fallback: "Call"))
                            .font(PPAccessoryTypography.captionBold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.ppPrimary))
                }
                .buttonStyle(PPAccessoryPressStyle())
                .accessibilityLabel("\(PPServiceViewerL10n.text("Call", fallback: "Call")) \(snapshot.ownerName)")
            }
        }
        .padding(16)
        .ppGlassSurface(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: Color.ppCard.opacity(0.85),
            fallback: Color(uiColor: .systemBackground).opacity(0.95),
            stroke: Color.white.opacity(0.18)
        )
    }
}

// MARK: - Review Composer

@available(iOS 16.0, *)
struct PPServiceViewerReviewComposer: View {
    @Binding var rating: Int
    @Binding var text: String
    let isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(PPServiceViewerL10n.text("service_review_composer_title", fallback: "Write a Review"))
                    .font(PPAccessoryTypography.headline)
                    .foregroundStyle(Color.ppTextPrimary)

                Text(PPServiceViewerL10n.text("service_review_composer_subtitle", fallback: "Your review helps pet owners choose with confidence."))
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        rating = index
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(
                                index <= rating
                                    ? Color.ppWarning
                                    : Color.ppTextSecondary.opacity(0.25)
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index) \(PPServiceViewerL10n.text("stars", fallback: "stars"))")
                    .accessibilityAddTraits(index == rating ? [.isSelected] : [])
                }
            }
            .accessibilityElement(children: .contain)

            TextField(
                PPServiceViewerL10n.text("service_review_placeholder", fallback: "Share your experience..."),
                text: $text,
                axis: .vertical
            )
            .lineLimit(3...5)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.ppForeground.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.ppSeparator.opacity(0.4), lineWidth: 1)
            )

            Button(action: onSubmit) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(PPServiceViewerL10n.text("service_review_submit", fallback: "Submit Review"))
                            .font(PPAccessoryTypography.calloutBold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(Color.ppPrimary))
            }
            .buttonStyle(PPAccessoryPressStyle())
            .disabled(isSubmitting)
        }
        .padding(16)
        .ppGlassSurface(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: Color.ppCard.opacity(0.85),
            fallback: Color(uiColor: .systemBackground).opacity(0.95),
            stroke: Color.white.opacity(0.18)
        )
    }
}

// MARK: - Review Row

struct PPServiceViewerReviewRow: View {
    let item: PPServiceViewerReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let avatar = item.userAvatarURL, !avatar.isEmpty {
                    PPAccessoryRemoteImageView(
                        urlString: avatar,
                        blurHash: nil,
                        contentMode: .fill,
                        accessibilityLabel: item.userName,
                        cacheKey: item.id,
                        displaySize: CGSize(width: 36, height: 36)
                    )
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.ppPrimary.opacity(0.14))

                        Text(String(item.userName.prefix(1)))
                            .font(PPAccessoryTypography.captionBold)
                            .foregroundStyle(Color.ppPrimary)
                    }
                    .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.userName)
                        .font(PPAccessoryTypography.calloutBold)
                        .foregroundStyle(Color.ppTextPrimary)

                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(
                                    index <= item.rating
                                        ? Color.ppWarning
                                        : Color.ppTextSecondary.opacity(0.20)
                                )
                        }
                    }
                }

                Spacer(minLength: 4)

                Text(item.date)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
            }

            Text(item.text)
                .font(PPAccessoryTypography.body)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(nil)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.ppForeground.opacity(0.4))
        )
    }
}

// MARK: - Persistent Contact Action Bar

struct PPServiceViewerActionBar: View {
    let snapshot: PPServiceViewerSnapshot?
    let onShare: () -> Void
    let onCall: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: Language.isRTL() ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.ppForeground.opacity(0.85)))
                    .overlay(Circle().stroke(Color.ppSeparator.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PPAccessoryPressStyle())
            .accessibilityLabel(PPServiceViewerL10n.text("Back", fallback: "Back"))

            Button(action: onCall) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(PPServiceViewerL10n.text("Contact Provider", fallback: "Contact Provider"))
                        .font(PPAccessoryTypography.calloutBold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Color.ppPrimary))
                .shadow(color: Color.ppPrimary.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(PPAccessoryPressStyle())
            .accessibilityLabel(PPServiceViewerL10n.text("Contact Provider", fallback: "Contact Provider"))

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.ppForeground.opacity(0.85)))
                    .overlay(Circle().stroke(Color.ppSeparator.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PPAccessoryPressStyle())
            .accessibilityLabel(PPServiceViewerL10n.text("Share", fallback: "Share"))
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(
            Color.ppBackground.opacity(0.94)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Top Navigation Bar & Smart Pill

struct PPServiceViewerTopBar: View {
    let onClose: () -> Void
    let onShare: () -> Void
    let snapshot: PPServiceViewerSnapshot?
    let showsSmartTitle: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PPSpace.md) {
            chromeButton(
                symbol: Language.isRTL()
                    ? "chevron.right"
                    : "chevron.left",
                label: PPServiceViewerL10n.text("Back", fallback: "Back"),
                action: onClose
            )
            .accessibilityAddTraits(.isButton)

            ZStack {
                if showsSmartTitle, let snapshot {
                    PPServiceViewerNavBarSmartPill(snapshot: snapshot)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(
                                    with: .scale(scale: 0.95).combined(with: .offset(y: 4))
                                )
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .layoutPriority(1)
            .accessibilityHidden(!showsSmartTitle)

            chromeButton(
                symbol: "square.and.arrow.up",
                label: PPServiceViewerL10n.text("Share", fallback: "Share"),
                action: onShare
            )
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.bottom, 8)
        .animation(
            reduceMotion
                ? nil
                : .spring(response: 0.30, dampingFraction: 0.88),
            value: showsSmartTitle
        )
    }

    @ViewBuilder
    private func chromeButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(width: 44, height: 44)
                .ppAccessorySubviewBackground(
                    PPAccessorySubviewBackground.chromeFill,
                    in: Circle(),
                    stroke: PPAccessorySubviewBackground.chromeStroke,
                    lineWidth: 0.8
                )
                .contentShape(Circle())
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.90))
        .accessibilityLabel(label)
    }
}

struct PPServiceViewerNavBarSmartPill: View {
    let snapshot: PPServiceViewerSnapshot

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            mediaAvatar

            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle)
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                let subText = subtitleText
                if !subText.isEmpty {
                    Text(subText)
                        .font(PPAccessoryTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: PPSpace.xs)

            if !priceText.isEmpty {
                Text(priceText)
                    .font(PPAccessoryTypography.captionBold)
                    .foregroundStyle(Color.ppPrimary)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .ppGlassSurface(
            in: Capsule(),
            tint: Color.ppCard.opacity(0.85),
            fallback: Color(uiColor: .systemBackground).opacity(0.95),
            stroke: Color.white.opacity(0.24),
            lineWidth: 0.5
        )
    }

    @ViewBuilder
    private var mediaAvatar: some View {
        if let imageURL = snapshot.imageURL, !imageURL.isEmpty {
            PPAccessoryRemoteImageView(
                urlString: imageURL,
                blurHash: snapshot.blurHash,
                contentMode: .fill,
                accessibilityLabel: displayTitle,
                isAvatar: true,
                cacheKey: snapshot.serviceID,
                displaySize: CGSize(width: 28, height: 28)
            )
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.12))

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .frame(width: 28, height: 28)
        }
    }

    private var displayTitle: String {
        let title = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? PPServiceViewerL10n.text("service_view_default_title", fallback: "Service") : title
    }

    private var subtitleText: String {
        let category = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeText = snapshot.serviceTypeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !category.isEmpty && !typeText.isEmpty && typeText != category {
            return "\(category) · \(typeText)"
        }
        return !category.isEmpty ? category : typeText
    }

    private var priceText: String {
        snapshot.price.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}




/*
 @swiftify-ui

 # Pure Pets Accessory Viewer — Flagship 10/10 Execution Contract

 Mode: `redesign + contract-safe refactor/migration`

 Scope: Completely redesign and implement the existing Pure Pets Accessory viewer used for food, accessories, marketplace products, available products, unavailable products, seller information, media galleries, recommendations, quantity selection, and cart operations.

 This is an implementation task—not another review, proposal, mockup, or specification. Inspect the repository, modify the real production code, build it, run it, validate it, fix defects, and continue iterating until every applicable release gate passes.

 Use the supplied screenshots, recording, and prior audit as evidence of the current experience. They are not the desired final design.

 ## Final outcome

 Transform the viewer into a distinctive, Apple Design Award–caliber, product-aware commerce experience named:

 **Adaptive Pet Intelligence**

 The final viewer must help a customer:

 1. Understand whether the product is appropriate for their pet.
 2. inspect every image clearly.
 3. understand variants, specifications, availability, delivery, returns, and safety.
 4. trust the seller and product.
 5. select the correct quantity or variant.
 6. add the product to the cart confidently.
 7. recover intelligently when the product is unavailable, deleted, stale, offline, or fails to load.

 Preserve the existing Pure Pets visual identity—especially the brand-pink authority derived from `#CB2654`—but elevate it into a disciplined semantic design system. The result must feel pet-specific even if the Pure Pets logo is removed.

 Do not produce a generic ecommerce template decorated with pink glass.

 ## Mandatory execution sequence

 ### Phase 1 — Inspect before editing

 Read all repository instructions and inspect:

 * The complete Git worktree and current uncommitted changes.
 * Application deployment target, Swift version, schemes, targets, and target memberships.
 * Existing Objective-C, UIKit, Swift, and SwiftUI implementations related to the viewer.
 * Viewer coordinators, presentation routes, deep-link callers, navigation wrappers, and dismissal behavior.
 * Product, ad, seller, cart, inventory, media, favorite, category, and recommendation models.
 * API clients, caching, image loading, localization, analytics, notification, and persistence layers.
 * Existing design tokens, colors, typography, materials, primitives, animations, icons, and shared components.
 * Tests, fixtures, previews, build scripts, and permitted device workflow.

 Use these as search anchors where present, without assuming the exact names are unchanged:

 * `ViewerVC`
 * gallery or image-viewer types
 * `PetImageGalleryView`
 * `PPInfoPillsView`
 * `PPPetsTitleView`
 * `UserContactView`
 * `PPSimilarAdsView`
 * product/ad models
 * cart services
 * seller routes
 * viewer coordinators
 * Objective-C bridging headers and runtime lookups

 Trace every caller and dependency. Do not edit only the visible root view while ignoring imported cells, wrappers, delegates, services, or coordinators.

 Establish a clean baseline build before modifying code when the environment permits it.

 ### Phase 2 — Create the contract ledgers

 Before replacing anything, create an internal:

 1. Symbol ledger.
 2. Call-site ledger.
 3. Runtime ownership ledger.
 4. Behavior-parity matrix.
 5. State coverage matrix.
 6. Analytics and persistence ledger.

 Inventory and preserve:

 * Runtime class names and Objective-C visibility.
 * Public initializers and parameters.
 * `@objc` selectors.
 * Delegates and callbacks.
 * Notifications and `userInfo` keys.
 * KVC/KVO paths.
 * Coordinator routes.
 * Push, modal, sheet, deep-link, and back-swipe behavior.
 * Analytics event names, parameters, timing, and single-fire behavior.
 * Persistence keys and stored formats.
 * Authentication and session behavior.
 * Product, seller, gallery, inventory, favorite, quantity, pricing, and cart semantics.
 * Cancellation, retry, repeated-tap, and idempotency behavior.

 There must be exactly one active production owner for every responsibility. Never leave duplicate Swift and Objective-C implementations of the same class or feature compiled together.

 A minimal compatibility shell may remain only when Objective-C or coordinator contracts require it. All visible UI must be implemented in SwiftUI.

 ## Existing behaviors that must remain correct

 Verify these against the actual source rather than hardcoding the sample values:

 * Back navigation and interactive swipe-back.
 * Seller navigation.
 * Favorite selection and persistence.
 * Gallery page selection, counters, and thumbnails.
 * Available and unavailable product behavior.
 * Quantity limits and inventory validation.
 * Total price calculation.
 * Single-provider cart rules.
 * Cross-provider cart replacement confirmation.
 * Cart badge updates.
 * Inventory reduction after a successful addition.
 * Correct behavior after a quantity is added.
 * Retry and duplicate-tap protection.
 * Existing analytics, API calls, and business rules.

 The prior interaction evidence showed that selecting quantity `3` produced a total of `QAR 60`, updated the cart quantity to `3`, reduced inventory from `144` to `141`, and reset the selector afterward. Treat this as a parity clue, not a business rule to hardcode.

 Do not fabricate delivery estimates, ratings, return policies, stock predictions, nutrition values, seller statistics, or backend data. Surface only real data supplied by existing models or APIs. Use conditional presentation for optional fields and document any genuine backend gap.

 ## Confirmed problems to solve

 1. The current universal viewer reduces food and accessories to overly generic metadata.
 2. Essential compatibility, nutrition, dimensions, safety, variants, and usage information are missing or buried.
 3. Delivery, pickup, return eligibility, seller reputation, and marketplace trust appear too late or are absent.
 4. The unavailable state repeats the status but offers no meaningful recovery.
 5. Navigation exposes a blank rounded shell before viewer content appears.
 6. The compact header allows underlying text and imagery to collide through the glass.
 7. Arabic screens still expose raw English `QAR`, inconsistent currency ordering, and spacing/localization defects.
 8. The cross-provider cart dialog does not show enough context before discarding the current cart.
 9. The purchase dock does not clearly label the changing price as the total.
 10. The gallery lacks a complete full-screen zoom experience.
 11. Thumbnails and overlays can interfere with important product photography.
 12. Seller stars lack review count and sufficient supporting trust information.
 13. Recommendations can prioritize unavailable products.
 14. Image framing is inconsistent—some images contain excessive whitespace while others crop too aggressively.
 15. Loading, image failure, offline, stale-price, stale-stock, deleted-product, maximum-quantity, add failure, and retry states are incomplete or unverified.
 16. VoiceOver, Dynamic Type, Reduce Motion, dark mode, contrast, memory behavior, and real-device performance remain unverified.

 ## Product DNA

 Primary outcome: Enable the customer to decide whether a product is right for their pet and purchase it confidently.

 Dominant action: Add the correct available product, quantity, and variant to the cart. When purchase is unavailable, the dominant action becomes the best recovery path.

 Audience: Arabic-first and English-secondary pet owners with varied technical ability who need emotional warmth, clear safety information, and marketplace trust.

 Brand character:

 * Premium but warm.
 * Intelligent but approachable.
 * Pet-specific rather than generic retail.
 * Playful in small moments, serious around safety and money.
 * Brand pink has authority but must never reduce contrast or overwhelm content.
 * Rounded shapes and materials should feel intentional, not bubbly or childish.

 Content density: Comfortable progressive disclosure—immediate buying information first, deeper specifications below.

 Required hierarchy:

 1. Product media.
 2. Title, localized price, availability, and Pet Fit summary.
 3. Variant and quantity decisions.
 4. Delivery, returns, safety, and trust.
 5. Seller.
 6. Description and product-specific specifications.
 7. Reviews and recommendations.
 8. Persistent purchase or recovery action.

 Native iOS behavior:

 * Standard navigation semantics.
 * Interactive swipe-back.
 * Safe-area correctness.
 * Native sheets and confirmation behavior.
 * Semantic controls and accessibility actions.
 * System-supported haptics.
 * No gesture-only essential behavior.

 ## Three structural concepts

 Evaluate these three concepts against repository evidence. They must remain structurally different—not palette variations.

 ### A — Commerce Precision

 A highly structured, transactional viewer with media followed by compact decision cards, fulfillment, seller trust, specifications, and a restrained sticky purchase dock.

 Strength: Maximum clarity and low migration risk.

 Risk: Could feel like a polished generic store unless the pet-intelligence layer is strong.

 ### B — Immersive Pet Story

 A media-led viewer with an immersive gallery, emotional product storytelling, contextual product details, and progressive purchasing controls.

 Strength: Strong brand emotion and media presentation.

 Risk: Buying details, accessibility, and performance could become secondary.

 ### C — Adaptive Pet Intelligence

 A product-type-aware viewer that changes its hierarchy and decision modules for food, accessories, and future product categories. Its signature component is the Pet Fit Card, which synthesizes compatibility, safety, availability, delivery, and trust.

 Strength: Best balance of brand specificity, decision clarity, accessibility, and differentiation.

 Risk: Requires disciplined model adaptation and conditional composition.

 Score every concept from 0–5 on:

 * Task clarity.
 * Product-DNA fit.
 * Native iOS behavior.
 * Accessibility and RTL resilience.
 * State completeness.
 * Performance feasibility.
 * Migration risk.
 * Distinctiveness.
 * Contract safety.

 Select the highest evidence-backed concept. `Adaptive Pet Intelligence` is the expected direction, but do not select it blindly if repository evidence reveals a contract or feasibility problem. Document why the other concepts were rejected.

 ## Selected experience architecture

 If Adaptive Pet Intelligence remains the winner, implement this hierarchy.

 ### 1. Immediate-content navigation

 Never push an empty white or rounded shell.

 * Pass an existing product summary or cached snapshot from the source card when available.
 * Render a product-shaped skeleton immediately.
 * Start image and detail loading without blocking the first meaningful frame.
 * Use a matched transition only when supported, stable, accessible, and correctly availability-gated.
 * Preserve back-swipe and cancellation.
 * Never raise the deployment target for a visual API.

 ### 2. Product gallery

 Implement:

 * Stable page identity.
 * Full-screen presentation.
 * Pinch-to-zoom.
 * Double-tap zoom.
 * Panning with correct bounds.
 * Swipe dismissal only when it cannot conflict with zoom.
 * Media count.
 * Accessible image descriptions.
 * Useful missing-media and load-failure states.
 * Predictable thumbnail selection.
 * Framing that handles transparent assets, excessive whitespace, portrait images, and wide images.
 * Overlays that never obscure critical photography or collide with the status area.

 ### 3. Adaptive compact header

 When the hero collapses:

 * Show one concise title line and one locale-aware price.
 * Use an adaptive scrim or material that protects legibility.
 * Hide or transform gallery overlays before collision.
 * Respect safe areas and navigation-bar behavior.
 * Avoid stacked translucent layers.
 * Maintain sufficient contrast in light mode, dark mode, Increased Contrast, and over complex images.

 ### 4. Pet Fit Card — signature component

 Place a compact Pet Fit Card directly after the title and primary price.

 For accessories, synthesize sourced values such as:

 * Species compatibility.
 * Breed or size suitability.
 * Age suitability.
 * Measurements.
 * Size, color, material, and pack count.
 * Safety warnings.
 * Package contents.
 * Care or assembly.
 * Warranty or return eligibility.

 For food, synthesize sourced values such as:

 * Species.
 * Life stage.
 * Health suitability.
 * Weight and package count.
 * Flavor and primary protein.
 * Ingredients.
 * Nutritional analysis.
 * Feeding guide.
 * Allergens.
 * Storage.
 * Expiry.
 * Manufacturer and origin.
 * Veterinary or safety warnings.

 The collapsed card should answer “Is this right for my pet?” in seconds. Tapping it may reveal structured details. It must remain useful without animation.

 Do not show empty labels or invented values.

 ### 5. Fulfilment and trust

 Move real purchase-confidence information above recommendations:

 * Delivery estimate.
 * Delivery charge.
 * Pickup availability.
 * Return eligibility and period.
 * Payment reassurance.
 * Seller verification.
 * Seller rating and review count.
 * Response time.
 * Completed-order history.
 * Authenticity or manufacturer information.

 Render only data that genuinely exists.

 ### 6. Seller section

 Provide a strong seller card with:

 * Identity.
 * Verification state.
 * Rating plus review count.
 * Response information.
 * Marketplace history where available.
 * Clear destination to view seller.
 * Clear action to ask the seller.
 * Loading, missing, blocked, and failure behavior.

 ### 7. Recommendations

 * Rank available and relevant products first.
 * Do not promote unavailable products ahead of purchasable alternatives.
 * Use a clear RTL-aware chevron rather than an ambiguous diagonal arrow.
 * Preserve stable IDs and bounded image loading.
 * Add a useful empty state when no valid recommendations exist.

 ### 8. Purchase dock

 For available products:

 * Label the changing value as `الإجمالي` in Arabic and its proper localized equivalent in English.
 * Provide an accessible quantity control with minimum, maximum, and inventory semantics.
 * Support VoiceOver adjustable actions.
 * Prevent duplicate submissions.
 * Show progress during cart mutation.
 * On success, show a meaningful checkmark state, localized quantity confirmation such as `تمت إضافة 3`, appropriate haptic feedback, cart-badge feedback, and a VoiceOver announcement.
 * On failure, keep the user’s selection and provide retry.

 For unavailable products, replace the dead disabled ending with the best real recovery actions supported by the system:

 * `أبلغني عند التوفر`
 * `اعرض بدائل مشابهة`
 * `اسأل البائع`

 Do not display an action that the backend cannot support.

 For cross-provider cart conflicts, the confirmation must show:

 * Current provider.
 * Current cart item count.
 * Current cart value.
 * New provider.
 * Quantity being added.
 * Consequence of replacement.

 Actions should communicate:

 * View the current cart.
 * Start a new cart and add the selected quantity.
 * Cancel.

 Use a warning-appropriate symbol and semantics rather than a neutral question mark.

 ## Visual and glass system

 Create an elegant, restrained glass hierarchy.

 * Use existing project tokens first.
 * Map `#CB2654` to one semantic brand token rather than scattering the raw hex.
 * Extend the token system only when evidence requires it.
 * Glass is reserved for navigational and interactive elevation: compact header, gallery controls, and purchase dock.
 * Content and trust cards should favor clarity over excessive transparency.
 * Avoid glass-on-glass stacking, uncontrolled blur, weak contrast, and decorative reflections.
 * If the deployment target supports native Liquid Glass, use it through proper availability gates.
 * On earlier iOS versions, use an intentional semantic material fallback.
 * Do not raise the minimum iOS version.
 * Use semantic spacing, radius, typography, elevation, color, and motion tokens.
 * Use the project font and Dynamic Type text styles.
 * Use SF Symbols or the existing approved icon system.
 * Do not introduce arbitrary third-party UI dependencies.
 * Support light mode, dark mode, Increased Contrast, and Differentiate Without Color.

 ## Motion contract

 Motion must communicate product behavior.

 Use the existing project motion grammar when available. Otherwise use restrained semantic timings comparable to:

 * Instant: approximately 0.08 seconds.
 * Fast feedback: approximately 0.16 seconds.
 * Standard transition: approximately 0.24 seconds.
 * Emphasized transition: approximately 0.38 seconds.
 * Purposeful spring only where spatial continuity is important.

 Required motion behaviors:

 * Immediate skeleton-to-content transition without a blank flash.
 * Gallery-to-compact-header morph.
 * Pet Fit Card expansion and collapse.
 * Quantity and total updates.
 * Add-to-cart progress, success, and failure.
 * Cart badge update.
 * Sheet presentation and dismissal.

 With Reduce Motion enabled:

 * Remove springs, parallax, stagger, and large travel.
 * Replace them with concise fades or immediate state changes.
 * Preserve every piece of meaning.

 No ambient or decorative animation that consumes energy without helping comprehension.

 ## Complete state matrix

 Implement and verify every applicable reachable state.

 Data states:

 * Initial loading.
 * Loaded.
 * Partial data.
 * Empty product.
 * Deleted product.
 * Unavailable or sold-out product.
 * Missing seller.
 * Missing recommendations.
 * Error with retry.
 * Offline with cached data.
 * Offline without cached data.
 * Stale price.
 * Stale inventory.
 * Missing media.
 * Media load failure.

 Interaction states:

 * Idle.
 * Pressed.
 * Selected.
 * Focused.
 * Loading.
 * Success.
 * Failure.
 * Disabled.
 * Minimum quantity.
 * Maximum quantity.
 * Inventory changed during checkout.
 * Repeated tap.
 * Favorite mutation and failure.
 * Cross-provider cart conflict.
 * Authentication required where applicable.

 Layout states:

 * Compact iPhone.
 * Landscape.
 * Any regular-width layout supported by the application.
 * Dynamic Type XS through AX5.
 * Arabic RTL.
 * English LTR.
 * Light mode.
 * Dark mode.
 * Increased Contrast.
 * Differentiate Without Color.
 * Reduce Motion.

 Lifecycle states:

 * Cold entry.
 * Warm resume.
 * Background return.
 * Deep-link entry.
 * Language switch.
 * Authentication change.
 * Interrupted network or cart operation.

 Mark genuinely inapplicable states as `N/A` with evidence. Do not silently omit them.

 ## Arabic and localization requirements

 Arabic is primary; English is secondary.

 * Use locale-aware `FormatStyle` or the project’s equivalent formatter for every price.
 * Never concatenate amount and `QAR` manually.
 * Use one shared price formatter/component across the hero, compact header, purchase dock, cart conflict, and recommendations.
 * Protect mixed numbers and currency from bidirectional reordering.
 * Use locale-appropriate digits according to the project’s Arabic locale.
 * Fix spacing and authored Arabic, including forms such as `غير متوفر` and `أعشاش وبياضات`.
 * Use localization keys—no hardcoded user-facing strings.
 * Use leading and trailing, never left and right.
 * Flip only directional icons.
 * Do not flip neutral icons such as hearts, stars, search, or media symbols.
 * Use leading multiline alignment.
 * Test Arabic content at least 30% longer than the current samples.
 * Ensure English remains a genuinely authored LTR layout.

 ## Accessibility requirements

 * Every actionable element must have a meaningful label, value, trait, and hint where needed.
 * VoiceOver order must follow the visual and decision hierarchy in both Arabic and English.
 * Quantity must support adjustable accessibility actions.
 * Gallery paging and zoom must have non-gesture alternatives.
 * Decorative content must be hidden from accessibility.
 * Success, failure, stock changes, and modal transitions must produce appropriate announcements.
 * Move VoiceOver focus correctly into and out of sheets.
 * All touch targets must be at least 44×44 points.
 * Normal text contrast must reach at least 4.5:1.
 * Meaningful non-text controls and large text must meet appropriate contrast requirements.
 * Status cannot depend on color alone.
 * AX5 must not clip text, overlap controls, hide prices, or block purchase/recovery actions.
 * Support Voice Control and Switch Control through semantic controls.
 * Preserve meaning under Reduce Motion.

 ## SwiftUI engineering requirements

 * Preserve the current deployment target and toolchain.
 * Use architecture consistent with the repository.
 * Use `@Observable` only when supported by the deployment target and project architecture; otherwise use the appropriate established observation model.
 * Keep UI state on the correct actor.
 * Give async tasks clear ownership and cancellation.
 * Use stable identity—not collection indices—for galleries and recommendations.
 * Keep expensive formatting, image processing, and calculations out of `body`.
 * Decode and resize images off the main thread.
 * Reuse the existing cache when valid; otherwise keep caching explicitly bounded.
 * Avoid nested `GeometryReader` and unnecessary preference-key feedback loops.
 * Prevent retain cycles, abandoned tasks, and duplicate subscriptions.
 * Keep the root viewer readable and focused.
 * Give each meaningful public production type its own Swift file.
 * Tiny private helpers may remain inside their owner file.
 * Do not place multiple unrelated public classes in one file.
 * Do not create a forest of one-use wrappers.
 * Do not leave duplicate classes, symbols, legacy UI owners, backup files, or dead target memberships.
 * Do not modify unrelated features.
 * Do not overwrite unrelated existing user changes.
 * Do not use placeholder code, fake data, `TODO` implementations, or pseudocode.

 ## Performance requirements

 Target smooth ProMotion interaction on the required iPhone 13 Pro Max.

 * Aim for an approximately 8.33 ms frame budget at 120 Hz where ProMotion schedules 120 Hz.
 * Keep the main thread free from synchronous I/O and image decoding.
 * Bound memory and disk image caches; use the project’s stricter limits when present, otherwise use approximately 50 MB memory and 150 MB disk as upper bounds.
 * Cancel viewer-owned async work when the screen disappears.
 * Prevent repeated body invalidations and unstable identity.
 * Profile navigation, gallery paging, zoom, scrolling, header collapse, quantity changes, recommendation loading, and cart mutation.
 * Inspect memory growth, retain cycles, and leaks.
 * Never claim a fixed 120 Hz rate without real device evidence.

 ## Required implementation validation

 Use only the already-connected iPhone 13 Pro Max for runtime work.

 * Never use a simulator.
 * Never use another device.
 * Do not alter bundle identifiers, signing identities, provisioning settings, or unrelated build configuration.
 * Use the repository’s existing workspace, scheme, and build workflow.
 * Build before and after implementation.
 * Resolve all errors and warnings introduced by the changed files.
 * Run relevant unit, UI, snapshot, localization, and accessibility tests that exist.
 * Add focused tests for newly isolated business/presentation behavior when appropriate.
 * Test representative real records for:

   * Food.
   * Accessories.
   * Available products.
   * Unavailable products.
   * Multiple images.
   * Missing images.
   * Maximum quantity.
   * Seller navigation.
   * Cross-provider cart replacement.
   * Cart failure.
   * Offline and stale inventory.
 * Capture real-device evidence for Arabic and English, light and dark mode, normal text and AX5, and Reduce Motion.
 * Run the available static audit on every changed Swift and Objective-C file.
 * Use Instruments or the permitted device profiling workflow for performance and leaks.
 * Report anything that could not be executed as `UNVERIFIED`; never convert missing evidence into a pass.

 If the connected device is unavailable, continue all safe implementation and static validation that can be completed without it, then identify device validation as the exact external blocker. Do not silently substitute a simulator.

 ## Seven anti-template gates

 The selected implementation must pass:

 1. Five-second test: the product state and primary action are immediately clear.
 2. Logo-removal test: it still feels like Pure Pets.
 3. Template test: replacing pet products with unrelated retail content breaks the design logic.
 4. Safe-dead test: unavailable, error, offline, stale, and missing-media states remain useful.
 5. RTL-native test: Arabic feels authored rather than mirrored.
 6. Reduce-Motion test: all meaning survives without movement.
 7. Dynamic-Type AX5 test: nothing clips, overlaps, or blocks an essential action.

 Revise the implementation whenever any gate fails.

 ## 100-point release gate

 Score only evidence from the finished implementation:

 * Contract integrity: 25 points.
 * Creative direction: 20 points.
 * Production behavior: 15 points.
 * Accessibility and localization: 15 points.
 * Engineering health: 15 points.
 * Performance: 10 points.

 A release is blocked by any of the following:

 * Contract regression.
 * Duplicate runtime owner.
 * Incompatible API or deployment-target violation.
 * Missing reachable state.
 * Trapped or unreachable essential action.
 * RTL meaning failure.
 * Accessibility blocker.
 * Magic-number visual system.
 * Generic template design.
 * Unsafe async ownership.
 * Required build failure.
 * Fabricated build, device, accessibility, or performance evidence.

 Target a verified `100/100`.

 Do not stop voluntarily at a plan, audit, partial migration, compiling screen, or subjective claim of “premium.” Continue inspecting, implementing, testing, and correcting until every in-scope verifiable point is earned and there are zero auto-fail conditions.

 If a genuinely external blocker prevents 100/100, complete everything that is independently possible, mark only the blocked evidence `UNVERIFIED`, and state the exact blocker without claiming 100.

 ## Final handoff

 Return a concise Fidelity and Architecture Manifest containing:

 1. Final outcome.
 2. Changed files.
 3. Removed or deactivated legacy owners.
 4. Preserved-contract evidence.
 5. Symbol and call-site ledger summary.
 6. Product DNA Card.
 7. Three concept scores.
 8. Selected concept and rejection reasons.
 9. Implemented signature component and interaction.
 10. Before-and-after state matrix.
 11. Accessibility and localization results.
 12. Static-audit results.
 13. Build and test commands with real outcomes.
 14. Real-device validation evidence.
 15. Performance and leak evidence.
 16. Remaining risks or `UNVERIFIED` checks.
 17. Transparent 100-point scorecard.

 Do not return another list of recommendations in place of code. Execute the complete transformation in the real project.

 */
