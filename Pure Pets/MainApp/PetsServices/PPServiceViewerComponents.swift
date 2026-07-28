import SwiftUI
import UIKit

// MARK: - Hero Header

struct PPServiceViewerHeroHeader: View {
    let imageURL: String?
    let blurHash: String?
    let height: CGFloat
    let compact: Bool

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
                    accessibilityLabel: "Service Image"
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
    }
}

// MARK: - Title Card

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
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
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
    }
}

// MARK: - Provider Card

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
                    accessibilityLabel: snapshot.ownerName
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

                Text(PPServiceViewerL10n.text("Verified Provider", fallback: "Verified Provider"))
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
            }

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
            Text(PPServiceViewerL10n.text("Write a Review", fallback: "Write a Review"))
                .font(PPAccessoryTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        rating = index
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(
                                index <= rating
                                    ? Color.ppWarning
                                    : Color.ppTextSecondary.opacity(0.25)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(
                PPServiceViewerL10n.text("Share your experience...", fallback: "Share your experience..."),
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
                        Text(PPServiceViewerL10n.text("Submit Review", fallback: "Submit Review"))
                            .font(PPAccessoryTypography.calloutBold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
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
                        accessibilityLabel: item.userName
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

// MARK: - Action Bar

struct PPServiceViewerActionBar: View {
    let snapshot: PPServiceViewerSnapshot?
    let onShare: () -> Void
    let onCall: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: PPAccessoryViewerLegacyBridge.isRTL() ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.ppForeground.opacity(0.85)))
                    .overlay(Circle().stroke(Color.ppSeparator.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PPAccessoryPressStyle())

            Button(action: onCall) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(PPServiceViewerL10n.text("Contact Provider", fallback: "Contact Provider"))
                        .font(PPAccessoryTypography.calloutBold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(Color.ppPrimary))
                .shadow(color: Color.ppPrimary.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(PPAccessoryPressStyle())

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.ppForeground.opacity(0.85)))
                    .overlay(Circle().stroke(Color.ppSeparator.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(PPAccessoryPressStyle())
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 24)
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
                symbol: PPAccessoryViewerLegacyBridge.isRTL()
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
                } else if let snapshot {
                    defaultTitleView(snapshot: snapshot)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(
                                    with: .scale(scale: 0.95).combined(with: .offset(y: -4))
                                )
                        )
                } else {
                    Spacer(minLength: PPSpace.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .layoutPriority(1)

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
    private func defaultTitleView(snapshot: PPServiceViewerSnapshot) -> some View {
        VStack(spacing: 1) {
            Text(firstRowText(snapshot: snapshot))
                .font(PPAccessoryTypography.calloutBold)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            let subText = secondRowText(snapshot: snapshot)
            if !subText.isEmpty {
                Text(subText)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func firstRowText(snapshot: PPServiceViewerSnapshot) -> String {
        let title = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        return PPServiceViewerL10n.text("Service Details", fallback: "Service Details")
    }

    private func secondRowText(snapshot: PPServiceViewerSnapshot) -> String {
        let category = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeText = snapshot.serviceTypeText.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !category.isEmpty {
            parts.append(category)
        }
        if !typeText.isEmpty && typeText != category {
            parts.append(typeText)
        }
        return parts.joined(separator: " · ")
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
                isAvatar: true
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
        return title.isEmpty ? "Service" : title
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
