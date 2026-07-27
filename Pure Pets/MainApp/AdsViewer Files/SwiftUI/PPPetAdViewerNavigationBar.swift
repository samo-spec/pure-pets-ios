import SwiftUI

/// A canonical, category-defining transparent navigation bar for the Pet Ad Viewer.
/// Provides glass floating action controls over the hero gallery with safe status bar clearance.
struct PPPetAdViewerNavigationBar: View {
    let snapshot: PPPetAdViewerSnapshot
    let isCollapsed: Bool
    let isFavorite: Bool
    let isFavoriteWorking: Bool
    let canShare: Bool
    let canFavorite: Bool
    let canReport: Bool
    let isReportWorking: Bool
    let onBack: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasOverflowActions: Bool {
        canShare || canReport
    }

    var body: some View {
        HStack(spacing: PPSpace.md) {
            backButton

            if isCollapsed {
                PPPetAdViewerNavBarSmartPill(snapshot: snapshot)
                    .frame(maxWidth: .infinity)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 0.95).combined(with: .offset(y: 4))
                            )
                    )
            } else {
                Spacer(minLength: PPSpace.sm)
            }

            if canFavorite {
                favoriteControl
            } else if hasOverflowActions {
                overflowMenu
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.bottom, 8)
        .animation(
            reduceMotion ? nil : PPPetAdViewerMotion.navigation,
            value: isCollapsed
        )
    }

    private var backButton: some View {
        Button(action: onBack) {
            circleControl(
                symbol:
                    layoutDirection == .rightToLeft
                    ? "chevron.right"
                    : "chevron.left",
                tint: .ppTextPrimary
            )
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
        .accessibilityLabel(
            PPPetAdLocalization.text("Back", fallback: "Back")
        )
    }

    @ViewBuilder
    private var favoriteControl: some View {
        if hasOverflowActions {
            Menu {
                overflowActions
            } label: {
                favoriteLabel
            } primaryAction: {
                onFavorite()
            }
            .menuIndicator(.hidden)
            .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
            .accessibilityLabel(favoriteAccessibilityLabel)
            .accessibilityValue(favoriteAccessibilityValue)
            .accessibilityHint(
                PPPetAdLocalization.text(
                    "pet_ad_viewer_favorite_menu_hint",
                    fallback:
                        "Tap to change favorite status. Touch and hold for more actions."
                )
            )
        } else {
            Button(action: onFavorite) {
                favoriteLabel
            }
            .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
            .disabled(isFavoriteWorking)
            .accessibilityLabel(favoriteAccessibilityLabel)
            .accessibilityValue(favoriteAccessibilityValue)
        }
    }

    private var favoriteLabel: some View {
        circleControl(
            symbol: isFavorite ? "heart.fill" : "heart",
            tint: isFavorite ? .ppError : .ppTextPrimary,
            showsProgress: isFavoriteWorking
        )
    }

    private var favoriteAccessibilityLabel: String {
        isFavorite
            ? PPPetAdLocalization.text(
                "a11y_btn_unfavorite",
                fallback: "Remove from favorites"
            )
            : PPPetAdLocalization.text(
                "a11y_btn_favorite",
                fallback: "Add to favorites"
            )
    }

    private var favoriteAccessibilityValue: String {
        if isFavoriteWorking {
            return PPPetAdLocalization.text(
                "Loading",
                fallback: "Loading"
            )
        }
        return isFavorite
            ? PPPetAdLocalization.text(
                "Selected",
                fallback: "Selected"
            )
            : ""
    }

    private var overflowMenu: some View {
        Menu {
            overflowActions
        } label: {
            circleControl(
                symbol: "ellipsis",
                tint: .ppTextPrimary,
                showsProgress: isReportWorking
            )
        }
        .menuIndicator(.hidden)
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.90))
        .disabled(isReportWorking)
        .accessibilityLabel(
            PPPetAdLocalization.text("Actions", fallback: "Actions")
        )
    }

    @ViewBuilder
    private var overflowActions: some View {
        if canShare {
            Button(action: onShare) {
                Label(
                    PPPetAdLocalization.text(
                        "Share",
                        fallback: "Share"
                    ),
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if canReport {
            Button(action: onReport) {
                Label(
                    PPPetAdLocalization.text(
                        "report_ad_title",
                        fallback: "Report advertisement"
                    ),
                    systemImage: "exclamationmark.triangle"
                )
            }
            .disabled(isReportWorking)
        }
    }

    private func circleControl(
        symbol: String,
        tint: Color,
        showsProgress: Bool = false
    ) -> some View {
        ZStack {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: 44, height: 44)
        .ppGlassSurface(
            in: Circle(),
            tint: Color.ppCard.opacity(0.76),
            fallback: Color(uiColor: .systemBackground).opacity(0.92),
            stroke: Color.white.opacity(0.32),
            lineWidth: PPPetAdViewerStyle.hairlineWidth
        )
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
        .contentShape(Circle())
    }
}

/// A compact, high-fidelity responsive capsule card designed for navigation center area.
struct PPPetAdViewerNavBarSmartPill: View {
    let snapshot: PPPetAdViewerSnapshot
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            // Circle Avatar for First Pet Image
            if let firstMedia = snapshot.media.first {
                PPPetAdRemoteImageView(
                    urlString: firstMedia.imageURL,
                    blurHash: firstMedia.blurHash,
                    contentMode: .fill,
                    accessibilityLabel: firstMedia.isVideo ? "Video thumbnail" : "Pet image",
                    showsRetryOnFailure: false
                )
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
            } else {
                // Fallback Avatar Icon
                ZStack {
                    Color.ppPrimary.opacity(0.12)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ppPrimary)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.ppPrimary.opacity(0.2), lineWidth: 1))
            }

            // Text Stack: Title & Subtitle (Breed · Species)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.title)
                    .font(PPPetAdTypography.footnoteBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                let subText = subtitleText
                if !subText.isEmpty {
                    Text(subText)
                        .font(PPPetAdTypography.caption)
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: PPSpace.xs)

            // Trailing Edge: Bold price stacked vertically with secondary currency
            let pc = priceAndCurrency
            if pc.currency.isEmpty {
                Text(pc.price)
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            } else {
                VStack(alignment: .center, spacing: -2) {
                    Text(pc.price)
                        .font(.custom("Beiruti-Bold", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Color.ppPrimary)
                        .lineLimit(1)

                    Text(pc.currency)
                        .font(.custom("Beiruti-Regular", size: 9, relativeTo: .caption2))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
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
            lineWidth: PPPetAdViewerStyle.hairlineWidth
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 4,
            x: 0,
            y: 2
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: PPPetAdLocalization.text(
                    "a11y_nav_smart_pill_format",
                    fallback: "%@, %@, price %@"
                ),
                snapshot.title,
                subtitleText,
                snapshot.price
            )
        )
        .accessibilityAddTraits(.isHeader)
    }

    private var subtitleText: String {
        let breed = snapshot.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let species = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines)

        if !breed.isEmpty && !species.isEmpty {
            return "\(breed) · \(species)"
        } else if !breed.isEmpty {
            return breed
        } else {
            return species
        }
    }

    private var priceAndCurrency: (price: String, currency: String) {
        let components = snapshot.price.components(separatedBy: .whitespaces)
        guard components.count >= 2 else {
            return (snapshot.price, "")
        }

        let first = components[0]
        let last = components[components.count - 1]

        let hasDigits = first.rangeOfCharacter(from: .decimalDigits) != nil
        if hasDigits {
            let value = components.dropLast().joined(separator: " ")
            return (value, last)
        } else {
            let lastHasDigits = last.rangeOfCharacter(from: .decimalDigits) != nil
            if lastHasDigits {
                let value = components.dropFirst().joined(separator: " ")
                return (value, first)
            }
        }
        return (snapshot.price, "")
    }
}

