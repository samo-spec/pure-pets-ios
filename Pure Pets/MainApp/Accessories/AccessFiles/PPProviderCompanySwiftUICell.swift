//
//  PPProviderCompanySwiftUICell.swift
//  Pure Pets
//
//  SwiftUI provider storefront row hosted in the existing UIKit list.
//  The bridge owns presentation only; ProviderCompaniesListVC remains the
//  owner of provider data, filtering, selection, and navigation.
//

import SwiftUI
import UIKit

private enum PPProviderCompanyCellTypography {
    static let title = Font.custom("Beiruti-Bold", size: 19, relativeTo: .headline)
    static let compactTitle = Font.custom("Beiruti-Bold", size: 17, relativeTo: .headline)
    static let body = Font.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline)
    static let metric = Font.custom("Beiruti-Bold", size: 13, relativeTo: .caption)
    static let category = Font.custom("Beiruti-Bold", size: 12, relativeTo: .caption)
}

private struct PPProviderCompanyRemoteImage: UIViewRepresentable {
    let url: String?
    let placeholder: UIImage?
    let contentMode: UIView.ContentMode

    final class Coordinator {
        var loadedURL: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = contentMode
        imageView.backgroundColor = .clear
        update(imageView, coordinator: context.coordinator)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = contentMode
        update(imageView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ imageView: UIImageView, coordinator: Coordinator) {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }

    private func update(_ imageView: UIImageView, coordinator: Coordinator) {
        let safeURL = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard coordinator.loadedURL != safeURL else { return }

        coordinator.loadedURL = safeURL
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        imageView.image = placeholder

        guard !safeURL.isEmpty else { return }
        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: safeURL,
            placeholder: placeholder,
            transitionStyle: .crossDissolve,
            completion: nil
        )
    }
}

private struct PPProviderCompanySnapshot {
    let providerID: String
    let title: String
    let subtitle: String
    let category: String
    let countDisplay: String
    let city: String
    let rating: String
    let ratingCount: String
    let imageURL: String?
    let avatarURL: String?
    let placeholderImage: UIImage?
    let avatarPlaceholderImage: UIImage?
    let accent: Color
    let verified: Bool
    let active: Bool
    let favorite: Bool

    init(viewModel: PPProviderCompanyPremiumCardViewModel) {
        providerID = viewModel.providerIdentifier
        title = viewModel.title
        subtitle = viewModel.subtitle
        category = viewModel.categoryText
        countDisplay = viewModel.countDisplayText.isEmpty
            ? viewModel.countTitleText
            : viewModel.countDisplayText
        city = viewModel.cityText
        rating = viewModel.ratingText
        ratingCount = viewModel.ratingCountText
        imageURL = viewModel.imageURL?.absoluteString
        avatarURL = viewModel.avatarURL?.absoluteString
        placeholderImage = viewModel.placeholderImage
        avatarPlaceholderImage = viewModel.avatarPlaceholderImage
        accent = Color(uiColor: viewModel.accentColor ?? .ppPrimary)
        verified = viewModel.isVerified
        active = viewModel.isActive
        favorite = viewModel.isFavorite
    }
}

private struct PPProviderCompanyMetric: View {
    let symbol: String
    let text: String
    let tint: Color
    let fill: Color
    let border: Color

    var body: some View {
        Label {
            Text(text)
                .font(PPProviderCompanyCellTypography.metric)
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 32)
        .background(fill, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).stroke(border, lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
    }
}

private struct PPProviderCompanyFavoriteButton: View {
    let isFavorite: Bool
    let accent: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isFavorite ? accent : Color.ppTextPrimary.opacity(0.86))
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .overlay { Circle().stroke(Color.white.opacity(0.20), lineWidth: 0.8) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("favorite"))
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
        .scaleEffect(isFavorite && !reduceMotion ? 1.05 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.72), value: isFavorite)
    }
}

private struct PPProviderCompanyAvatar: View {
    let snapshot: PPProviderCompanySnapshot
    let size: CGFloat

    var body: some View {
        PPProviderCompanyRemoteImage(
            url: snapshot.avatarURL,
            placeholder: snapshot.avatarPlaceholderImage,
            contentMode: .scaleAspectFill
        )
        .frame(width: size, height: size)
        .background(Color.ppSecondarySurface)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(Color.ppSurface.opacity(0.96), lineWidth: 3)
        }
        .overlay(alignment: .bottomTrailing) {
            if snapshot.verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ppSuccess)
                    .background(Circle().fill(Color.ppSurface).padding(-2))
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 7, y: 3)
    }
}

private struct PPProviderCompanyShowcaseRow: View {
    let snapshot: PPProviderCompanySnapshot
    let entranceDelay: Double

    @State private var isFavorite: Bool
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(snapshot: PPProviderCompanySnapshot, entranceDelay: Double) {
        self.snapshot = snapshot
        self.entranceDelay = entranceDelay
        _isFavorite = State(initialValue: snapshot.favorite)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        let accent = snapshot.accent

        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                PPProviderCompanyRemoteImage(
                    url: snapshot.imageURL,
                    placeholder: snapshot.placeholderImage,
                    contentMode: .scaleAspectFill
                )
                .frame(height: 158)
                .frame(maxWidth: .infinity)
                .background(accent.opacity(0.10))
                .clipped()

                LinearGradient(
                    colors: [
                        .black.opacity(0.04),
                        .black.opacity(0.08),
                        .black.opacity(0.76)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                HStack(alignment: .top, spacing: 10) {
                    Text(snapshot.category)
                        .font(PPProviderCompanyCellTypography.category)
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 28)
                        .background(.black.opacity(0.24), in: Capsule(style: .continuous))
                        .overlay { Capsule(style: .continuous).stroke(.white.opacity(0.20), lineWidth: 0.7) }

                    Spacer(minLength: 8)

                    PPProviderCompanyFavoriteButton(
                        isFavorite: isFavorite,
                        accent: accent,
                        action: toggleFavorite
                    )
                }
                .padding(12)

                HStack(alignment: .bottom, spacing: 12) {
                    PPProviderCompanyAvatar(snapshot: snapshot, size: 56)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(snapshot.title)
                                .font(PPProviderCompanyCellTypography.title)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            if snapshot.active {
                                Circle()
                                    .fill(Color.ppSuccess)
                                    .frame(width: 7, height: 7)
                                    .accessibilityLabel(Text("provider_company_status_active"))
                            }
                        }

                        Text(snapshot.subtitle.isEmpty ? snapshot.category : snapshot.subtitle)
                            .font(PPProviderCompanyCellTypography.body)
                            .foregroundStyle(.white.opacity(0.80))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .frame(height: 158)

            HStack(spacing: 8) {
                PPProviderCompanyMetric(
                    symbol: "shippingbox.fill",
                    text: snapshot.countDisplay,
                    tint: accent,
                    fill: accent.opacity(0.08),
                    border: accent.opacity(colorSchemeContrast == .increased ? 0.34 : 0.16)
                )

                if !snapshot.city.isEmpty {
                    PPProviderCompanyMetric(
                        symbol: "mappin.and.ellipse",
                        text: snapshot.city,
                        tint: Color.ppTextSecondary,
                        fill: Color.ppSecondarySurface.opacity(reduceTransparency ? 1 : 0.72),
                        border: Color.ppSeparator.opacity(colorSchemeContrast == .increased ? 1 : 0.72)
                    )
                }

                Spacer(minLength: 0)

                PPProviderCompanyMetric(
                    symbol: "star.fill",
                    text: snapshot.rating + snapshot.ratingCount,
                    tint: Color.ppPremiumAccent,
                    fill: Color.ppPremiumAccent.opacity(0.12),
                    border: Color.ppPremiumAccent.opacity(colorSchemeContrast == .increased ? 0.52 : 0.24)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.ppSurface)
        }
        .background(Color.ppSurface, in: shape)
        .clipShape(shape)
        .overlay { shape.stroke(Color.ppSurfaceBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.72), lineWidth: colorSchemeContrast == .increased ? 1.2 : 0.8) }
        .shadow(
            color: .black.opacity(reduceTransparency ? 0.09 : 0.06),
            radius: 18,
            y: 8
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text("a11y_cell_tap_hint"))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear(perform: reveal)
    }

    private var accessibilityLabel: Text {
        var components = [snapshot.title]
        if snapshot.verified { components.append(NSLocalizedString("verified", comment: "Verified provider")) }
        if !snapshot.subtitle.isEmpty { components.append(snapshot.subtitle) }
        if !snapshot.city.isEmpty { components.append(snapshot.city) }
        if !snapshot.countDisplay.isEmpty { components.append(snapshot.countDisplay) }
        if !snapshot.rating.isEmpty { components.append(snapshot.rating + snapshot.ratingCount) }
        return Text(components.joined(separator: ", "))
    }

    private func toggleFavorite() {
        if reduceMotion {
            isFavorite.toggle()
        } else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                isFavorite.toggle()
            }
        }
    }

    private func reveal() {
        guard !isVisible else { return }
        if reduceMotion || entranceDelay <= 0 {
            isVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.42).delay(entranceDelay)) {
            isVisible = true
        }
    }
}

private struct PPProviderCompanyCompactRow: View {
    let snapshot: PPProviderCompanySnapshot
    let entranceDelay: Double

    @State private var isFavorite: Bool
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(snapshot: PPProviderCompanySnapshot, entranceDelay: Double) {
        self.snapshot = snapshot
        self.entranceDelay = entranceDelay
        _isFavorite = State(initialValue: snapshot.favorite)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        let accent = snapshot.accent

        HStack(spacing: 12) {
            PPProviderCompanyAvatar(snapshot: snapshot, size: 58)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(snapshot.title)
                        .font(PPProviderCompanyCellTypography.compactTitle)
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if snapshot.active {
                        Circle()
                            .fill(Color.ppSuccess)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                }

                Text(snapshot.subtitle.isEmpty ? snapshot.category : snapshot.subtitle)
                    .font(PPProviderCompanyCellTypography.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 8) {
                    if !snapshot.city.isEmpty {
                        Label(snapshot.city, systemImage: "mappin.and.ellipse")
                    }
                    Label(snapshot.rating + snapshot.ratingCount, systemImage: "star.fill")
                        .foregroundStyle(Color.ppPremiumAccent)
                }
                .font(PPProviderCompanyCellTypography.metric)
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                PPProviderCompanyFavoriteButton(
                    isFavorite: isFavorite,
                    accent: accent,
                    action: toggleFavorite
                )
                .frame(width: 44, height: 44)

                Text(snapshot.countDisplay)
                    .font(PPProviderCompanyCellTypography.metric)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.ppSurface, in: shape)
        .overlay { shape.stroke(Color.ppSurfaceBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.78), lineWidth: colorSchemeContrast == .increased ? 1.2 : 0.8) }
        .shadow(color: .black.opacity(0.045), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text("a11y_cell_tap_hint"))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear(perform: reveal)
    }

    private var accessibilityLabel: Text {
        var components = [snapshot.title]
        if snapshot.verified { components.append(NSLocalizedString("verified", comment: "Verified provider")) }
        if !snapshot.city.isEmpty { components.append(snapshot.city) }
        if !snapshot.countDisplay.isEmpty { components.append(snapshot.countDisplay) }
        if !snapshot.rating.isEmpty { components.append(snapshot.rating + snapshot.ratingCount) }
        return Text(components.joined(separator: ", "))
    }

    private func toggleFavorite() {
        if reduceMotion {
            isFavorite.toggle()
        } else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                isFavorite.toggle()
            }
        }
    }

    private func reveal() {
        guard !isVisible else { return }
        if reduceMotion || entranceDelay <= 0 {
            isVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.36).delay(entranceDelay)) {
            isVisible = true
        }
    }
}

private struct PPProviderCompanyHostedCell: View {
    let snapshot: PPProviderCompanySnapshot
    let compact: Bool
    let entranceDelay: Double

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Group {
            if compact {
                PPProviderCompanyCompactRow(snapshot: snapshot, entranceDelay: entranceDelay)
            } else {
                PPProviderCompanyShowcaseRow(snapshot: snapshot, entranceDelay: entranceDelay)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 16 : 6)
        .padding(.vertical, 6)
    }
}

/// UIKit bridge for the company providers list.
///
/// The list controller remains the single owner of provider state and
/// navigation. This object only installs a SwiftUI rendering surface into a
/// reusable UITableViewCell.
@objcMembers
@MainActor
final class PPProviderCompanySwiftUICellBridge: NSObject {
    @objc static func reuseIdentifier() -> String {
        "PPProviderCompanySwiftUICell"
    }

    @objc static func preferredHeight(forTableWidth tableWidth: CGFloat, compact: Bool) -> CGFloat {
        if compact {
            return 104
        }

        let cardWidth = max(tableWidth - 32, 0)
        let coverHeight = min(max(cardWidth * 0.48, 150), 188)
        return coverHeight + 92
    }

    @objc(configureCell:withViewModel:compact:entranceDelay:)
    func configureCell(
        _ cell: UITableViewCell,
        withViewModel viewModel: PPProviderCompanyPremiumCardViewModel,
        compact: Bool,
        entranceDelay: Double
    ) {
        let snapshot = PPProviderCompanySnapshot(viewModel: viewModel)
        let languageCode = Language.currentLanguageCode() ?? "en"
        let locale = Locale(identifier: languageCode)

        cell.contentConfiguration = UIHostingConfiguration {
            PPProviderCompanyHostedCell(
                snapshot: snapshot,
                compact: compact,
                entranceDelay: entranceDelay
            )
            .id(snapshot.providerID)
            .environment(\.locale, locale)
            .environment(
                \.layoutDirection,
                languageCode == "ar" ? .rightToLeft : .leftToRight
            )
        }
        .margins(.all, 0)
        .minSize(width: 0, height: Self.preferredHeight(forTableWidth: cell.bounds.width, compact: compact))

        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.accessibilityIdentifier = "providerCompanySwiftUICell_\(snapshot.providerID)"
    }
}
