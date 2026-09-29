#if canImport(UIKit)
import PureLensCore
import SwiftUI
import UIKit

// MARK: - Spatial & Visual Design Metrics

private enum LensResultMetrics {
    static let screenInset: CGFloat = 18
    static let sectionSpacing: CGFloat = 22
    static let contentSpacing: CGFloat = 14
    static let heroCardRadius: CGFloat = 26
    static let cardRadius: CGFloat = 22
    static let itemCardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let compactRadius: CGFloat = 12
    static let pillRadius: CGFloat = 24
    static let heroIconSize: CGFloat = 58
    static let spotlightImageHeight: CGFloat = 172
    static let sculptedImageSize: CGFloat = 114
    static let categoryTabHeight: CGFloat = 46
    static let actionButtonHeight: CGFloat = 54
    static let circularActionSize: CGFloat = 36
}

// MARK: - Main Lens Result Sheet

struct LensResultSheet: View {
    @ObservedObject var store: PureLensStore

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedCategory: LensDiscoveryCategory = .accessories
    @State private var guidanceSignalVisible = false
    @State private var heroPulse = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LensResultMetrics.sectionSpacing) {
                // 1. Holographic Identity Hero Capsule
                detectionHero

                // 2. Consent Recovery Banner (if declined)
                if store.didDeclineRemoteProcessingForCurrentDetection {
                    consentRecovery
                }

                // 3. Nova AI Companion Sanctuary
                if store.showsGuidanceAction {
                    novaSanctuaryCard
                }

                // 4. Discovery Results & Categories
                if store.isDiscoveryComplete && !store.hasAnyResults {
                    terminalDiscoveryState
                    if store.hasDiscoveryFailures {
                        categoryStage
                    }
                } else {
                    categoryStage
                }
            }
            .padding(.horizontal, LensResultMetrics.screenInset)
            .padding(.top, 14)
            .padding(.bottom, 96) // Space for floating bottom dock
        }
        .lensScrollIndicatorsHidden()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            scanAgainDock
        }
        .background(store.theme.surfaceElevated)
        .lensPresentationDetents()
        .lensPresentationAppearance(
            store.theme.surfaceElevated,
            reduceTransparency: reduceTransparency
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.82),
            value: store.discoverySections
        )
        .alert(
            store.localized("lens.results.open_failed.title"),
            isPresented: $store.showsItemOpenError
        ) {
            Button(store.localized("lens.close"), role: .cancel) {}
        } message: {
            Text(store.localized("lens.results.open_failed.detail"))
        }
        .accessibilityAction(.escape, scanAgain)
        .onAppear {
            revealGuidanceSignal()
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    heroPulse = true
                }
            }
        }
    }

    // MARK: - 1. Holographic Identity Hero Capsule

    private var detectionHero: some View {
        VStack(alignment: .leading, spacing: LensResultMetrics.contentSpacing) {
            HStack(alignment: .center, spacing: 14) {
                // Multi-layered species emblem with circular confidence ring
                speciesEmblemBadge

                // Species identification typography
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.theme.recognition)
                            .frame(width: 7, height: 7)

                        Text(store.localized("lens.results.detected"))
                            .font(store.theme.typography.captionEmphasized)
                            .foregroundStyle(store.theme.recognition)
                    }

                    Text(store.localizedAnimalName)
                        .font(store.theme.typography.title2)
                        .foregroundStyle(store.theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer(minLength: 8)

                // High-precision confidence pill
                if let confidence = store.animalContext?.confidence {
                    confidencePill(confidence)
                }
            }

            // Refined Divider
            Rectangle()
                .fill(store.theme.separator.opacity(separatorOpacity))
                .frame(height: contrast == .increased ? 1.5 : 1)
                .accessibilityHidden(true)

            // Live Discovery Status Capsule
            discoveryStatusBar
        }
        .padding(18)
        .background(
            store.theme.surfaceRaised,
            in: RoundedRectangle(
                cornerRadius: LensResultMetrics.heroCardRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: LensResultMetrics.heroCardRadius,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        store.theme.recognition.opacity(contrast == .increased ? 0.75 : 0.35),
                        store.theme.brandStrong.opacity(contrast == .increased ? 0.45 : 0.12),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: contrast == .increased ? 1.5 : 1.2
            )
        }
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 12,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .contain)
    }

    private var speciesEmblemBadge: some View {
        ZStack {
            // Ambient soft glow backing
            Circle()
                .fill(store.theme.recognition.opacity(heroPulse && !reduceMotion ? 0.22 : 0.12))
                .frame(
                    width: LensResultMetrics.heroIconSize + 8,
                    height: LensResultMetrics.heroIconSize + 8
                )
                .scaleEffect(heroPulse && !reduceMotion ? 1.06 : 1.0)

            // Confidence progress arc
            if let confidence = store.animalContext?.confidence {
                Circle()
                    .stroke(store.theme.recognition.opacity(0.20), lineWidth: 3)
                    .frame(
                        width: LensResultMetrics.heroIconSize,
                        height: LensResultMetrics.heroIconSize
                    )

                Circle()
                    .trim(from: 0, to: min(max(CGFloat(confidence), 0.15), 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [store.theme.recognition, store.theme.brandStrong],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(
                        width: LensResultMetrics.heroIconSize,
                        height: LensResultMetrics.heroIconSize
                    )
            }

            // Core emblem disc
            Circle()
                .fill(store.theme.brandSoft)
                .frame(
                    width: LensResultMetrics.heroIconSize - 8,
                    height: LensResultMetrics.heroIconSize - 8
                )

            Image(systemName: "pawprint.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(store.theme.brandStrong)
        }
        .frame(
            width: LensResultMetrics.heroIconSize + 8,
            height: LensResultMetrics.heroIconSize + 8
        )
        .accessibilityHidden(true)
    }

    private func confidencePill(_ confidence: Double) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(store.theme.recognition)

            Text(
                store.localizedFormat(
                    "lens.results.confidence",
                    Int((confidence * 100).rounded())
                )
            )
            .font(store.theme.typography.captionEmphasized.monospacedDigit())
            .foregroundStyle(store.theme.recognition)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            store.theme.recognition.opacity(contrast == .increased ? 0.22 : 0.10),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    store.theme.recognition.opacity(contrast == .increased ? 0.60 : 0.25),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
        }
    }

    private var discoveryStatusBar: some View {
        HStack(alignment: .center, spacing: 10) {
            if store.isDiscoveryComplete {
                Image(
                    systemName: store.hasDiscoveryFailures
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(
                    store.hasDiscoveryFailures
                        ? store.theme.warning
                        : store.theme.recognition
                )
                .accessibilityHidden(true)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(store.theme.brandStrong)
                    .accessibilityHidden(true)
            }

            Text(discoveryStatusText)
                .font(store.theme.typography.subheadlineEmphasized)
                .foregroundStyle(store.theme.textPrimary)

            Spacer(minLength: 8)

            if totalResultCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(store.theme.brandStrong)

                    Text(
                        store.localizedFormat(
                            "lens.results.available_count",
                            totalResultCount
                        )
                    )
                    .font(store.theme.typography.captionEmphasized.monospacedDigit())
                    .foregroundStyle(store.theme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(store.theme.surfaceElevated, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var discoveryStatusText: String {
        if !store.isDiscoveryComplete {
            return store.localized("lens.results.discovery.searching")
        }
        return store.hasDiscoveryFailures
            ? store.localized("lens.results.discovery.partial")
            : store.localized("lens.results.discovery.ready")
    }

    // MARK: - 2. Nova AI Companion Sanctuary

    private var novaSanctuaryCard: some View {
        Button(action: store.openGuidance) {
            VStack(alignment: .leading, spacing: 14) {
                // Header with Nova Sparkle badge & live indicator
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        store.theme.brandSoft,
                                        Color.purple.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [store.theme.brandStrong, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(guidanceSignalVisible && !reduceMotion ? 1.08 : 0.96)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.theme.success)
                                .frame(width: 6, height: 6)

                            Text(store.localized("lens.results.nova.status"))
                                .font(store.theme.typography.caption2Medium)
                                .foregroundStyle(store.theme.textSecondary)
                        }

                        Text(store.localized("lens.results.nova.title"))
                            .font(store.theme.typography.headline)
                            .foregroundStyle(store.theme.textPrimary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: store.isRightToLeft ? "chevron.backward" : "chevron.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(store.theme.brandStrong)
                        .padding(8)
                        .background(store.theme.brandSoft, in: Circle())
                        .accessibilityHidden(true)
                }

                // Subtitle description
                Text(
                    store.localizedFormat(
                        "lens.results.nova.detail",
                        store.localizedAnimalName
                    )
                )
                .font(store.theme.typography.subheadline)
                .foregroundStyle(store.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                // Quick Contextual Prompt Chips (Preview of Nova's Intelligence)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        novaPromptChip(title: "🥗 " + store.localized("lens.species.diet_tip"))
                        novaPromptChip(title: "✂️ " + store.localized("lens.species.care_tip"))
                        novaPromptChip(title: "🩺 " + store.localized("lens.species.health_tip"))
                    }
                    .padding(.horizontal, 1)
                }
                .lensScrollIndicatorsHidden()

                // Action Pill & Privacy note
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(store.localized("lens.results.nova.action"))
                            .font(store.theme.typography.subheadlineEmphasized)
                            .foregroundStyle(Color.white)

                        if store.isOpeningGuidance {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.white)
                        } else {
                            Image(systemName: store.isRightToLeft ? "arrow.left" : "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.white)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(
                        LinearGradient(
                            colors: [store.theme.brandStrong, store.theme.brandPressed],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )

                    Spacer(minLength: 4)

                    Text(store.localized("lens.results.nova.privacy"))
                        .font(store.theme.typography.caption2Medium)
                        .foregroundStyle(store.theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(18)
            .background(
                store.theme.surfaceRaised,
                in: RoundedRectangle(
                    cornerRadius: LensResultMetrics.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: LensResultMetrics.cardRadius,
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            store.theme.brandStrong.opacity(contrast == .increased ? 0.65 : 0.30),
                            Color.purple.opacity(contrast == .increased ? 0.40 : 0.18),
                            store.theme.brandSignal.opacity(contrast == .increased ? 0.50 : 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 1.2
                )
            }
            .shadow(
                color: Color.black.opacity(0.03),
                radius: 10,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(
            LensSpringCardButtonStyle(reduceMotion: reduceMotion)
        )
        .disabled(!store.canOpenGuidance)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.localized("lens.results.nova.title"))
        .accessibilityValue(
            store.localizedFormat(
                "lens.results.nova.detail",
                store.localizedAnimalName
            )
        )
        .accessibilityHint(store.localized("lens.results.nova.hint"))
    }

    private func novaPromptChip(title: String) -> some View {
        Text(title)
            .font(store.theme.typography.captionEmphasized)
            .foregroundStyle(store.theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                store.theme.surfaceElevated.opacity(0.9),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        store.theme.brandStrong.opacity(0.18),
                        lineWidth: 1
                    )
            }
    }

    // MARK: - 3. Category Stage & Tactile Segmented Rail

    private var categoryStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            categoryRail
            activeCategoryContent
                .id(selectedCategory)
                .transition(.opacity)
        }
    }

    private var categoryRail: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(store.discoverySections) { section in
                    LensCategoryTab(
                        section: section,
                        isSelected: selectedCategory == section.category,
                        title: store.localized(
                            "lens.results.category.\(section.category.rawValue)"
                        ),
                        statusText: categoryStatusText(for: section),
                        theme: store.theme,
                        contrast: contrast,
                        differentiateWithoutColor: differentiateWithoutColor,
                        action: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            let animation = reduceMotion
                                ? nil
                                : Animation.spring(response: 0.32, dampingFraction: 0.8)
                            withAnimation(animation) {
                                selectedCategory = section.category
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .lensScrollIndicatorsHidden()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var activeCategoryContent: some View {
        if let section = activeSection {
            VStack(alignment: .leading, spacing: 14) {
                // Category Heading
                activeCategoryHeading(section)

                if section.items.isEmpty {
                    if section.isLoading {
                        LensDiscoveryLoadingGrid(theme: store.theme)
                    } else if !section.didFail {
                        categoryEmptyState
                    }
                } else {
                    // Category Discovery Items
                    discoveryItemsList(section.items)
                }

                // PureCare Medicine Advisory
                if section.category == .medicine, !section.items.isEmpty {
                    LensDiscoveryNotice(
                        theme: store.theme,
                        text: store.localized("lens.results.medicine.notice")
                    )
                }

                // Failure Banner
                if section.didFail {
                    LensDiscoveryFailureRow(
                        theme: store.theme,
                        detail: store.localized("lens.results.partial_failure"),
                        retryTitle: store.localized("lens.try_again"),
                        retryHint: store.localized("lens.results.retry.hint"),
                        canRetry: store.canRetryDiscovery(section.category),
                        isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                        retry: { store.retryDiscovery(section.category) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activeCategoryHeading(_ section: LensDiscoverySection) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: section.category.lensSymbolName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(store.theme.brandStrong)
                .frame(width: 32, height: 32)
                .background(store.theme.brandSoft, in: Circle())
                .accessibilityHidden(true)

            Text(
                store.localized(
                    "lens.results.category.\(section.category.rawValue)"
                )
            )
            .font(store.theme.typography.headline)
            .foregroundStyle(store.theme.textPrimary)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            if !section.items.isEmpty {
                Text(
                    store.localizedFormat(
                        "lens.results.category.count",
                        section.items.count
                    )
                )
                .font(store.theme.typography.captionEmphasized.monospacedDigit())
                .foregroundStyle(store.theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(store.theme.surfaceRaised, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 4. Discovery Items List: Spotlight Hero + Sculpted Cards

    @ViewBuilder
    private func discoveryItemsList(_ items: [LensDiscoveryItem]) -> some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 12) {
                // First Item: Spotlight Hero Card (creates editorial boutique hierarchy)
                if let heroItem = items.first {
                    LensDiscoverySpotlightCard(
                        item: heroItem,
                        animalName: store.localizedAnimalName,
                        isOpening: store.openingItemID == heroItem.id,
                        store: store,
                        openHint: store.localized("lens.results.open.hint"),
                        openingLabel: store.localized("lens.results.opening"),
                        isRightToLeft: store.isRightToLeft,
                        reduceMotion: reduceMotion,
                        contrast: contrast,
                        action: { store.open(heroItem) }
                    )
                }

                // Subsequent Items: Modern Sculpted Discovery Cards
                if items.count > 1 {
                    ForEach(Array(items.dropFirst())) { item in
                        LensDiscoverySculptedCard(
                            item: item,
                            isOpening: store.openingItemID == item.id,
                            theme: store.theme,
                            openHint: store.localized("lens.results.open.hint"),
                            openingLabel: store.localized("lens.results.opening"),
                            isRightToLeft: store.isRightToLeft,
                            reduceMotion: reduceMotion,
                            contrast: contrast,
                            action: { store.open(item) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - 5. Empty & Error States

    private var categoryEmptyState: some View {
        LensResultStateCard(
            theme: store.theme,
            symbol: "tray.fill",
            tint: store.theme.textSecondary,
            title: store.localized("lens.results.category.empty.title"),
            detail: store.localized("lens.results.category.empty.detail")
        )
    }

    private var terminalDiscoveryState: some View {
        Group {
            if store.hasDiscoveryFailures {
                LensResultStateCard(
                    theme: store.theme,
                    symbol: "wifi.exclamationmark",
                    tint: store.theme.warning,
                    title: store.localized("lens.results.failed.title"),
                    detail: store.localized("lens.results.failed.detail")
                )
            } else {
                LensResultStateCard(
                    theme: store.theme,
                    symbol: "sparkles",
                    tint: store.theme.success,
                    title: store.localized("lens.results.empty.title"),
                    detail: store.localized("lens.results.empty.detail")
                )
            }
        }
    }

    // MARK: - 6. Consent Recovery

    private var consentRecovery: some View {
        Button(action: store.requestRemoteProcessingConsentAgain) {
            HStack(spacing: 12) {
                Image(systemName: "photo.badge.arrow.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(store.theme.brandStrong)
                    .frame(width: 38, height: 38)
                    .background(store.theme.brandSoft, in: Circle())
                    .accessibilityHidden(true)

                Text(store.localized("lens.privacy.consent.resume"))
                    .font(store.theme.typography.subheadlineEmphasized)
                    .foregroundStyle(store.theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: store.isRightToLeft ? "chevron.backward" : "chevron.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(
                store.theme.surfaceRaised,
                in: RoundedRectangle(
                    cornerRadius: LensResultMetrics.controlRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: LensResultMetrics.controlRadius,
                    style: .continuous
                )
                .stroke(store.theme.separator.opacity(separatorOpacity), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(store.localized("lens.privacy.consent.resume.hint"))
    }

    // MARK: - 7. Safe Area Floating Glass Action Dock

    private var scanAgainDock: some View {
        VStack(spacing: 0) {
            Button(action: scanAgain) {
                HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 19, weight: .bold))

                    Text(store.localized("lens.scan_again"))
                        .font(store.theme.typography.headline)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: LensResultMetrics.actionButtonHeight)
                .background(
                    LinearGradient(
                        colors: [store.theme.brandStrong, store.theme.brandPressed],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(
                    color: store.theme.brandStrong.opacity(contrast == .increased ? 0.55 : 0.38),
                    radius: 12,
                    x: 0,
                    y: 5
                )
                .contentShape(Capsule())
            }
            .buttonStyle(
                LensSpringCardButtonStyle(reduceMotion: reduceMotion)
            )
            .accessibilityHint(store.localized("lens.scan_again.hint"))
            .padding(.horizontal, LensResultMetrics.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(
            store.theme.surfaceElevated
                .opacity(reduceTransparency ? 1.0 : 0.94)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    store.theme.separator.opacity(contrast == .increased ? 0.6 : 0.25),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1)
        }
    }

    // MARK: - Derived State & Helpers

    private var activeSection: LensDiscoverySection? {
        store.discoverySections.first { $0.category == selectedCategory }
    }

    private var totalResultCount: Int {
        store.discoverySections.reduce(0) { $0 + $1.items.count }
    }

    private var separatorOpacity: Double {
        contrast == .increased ? 0.86 : 0.40
    }

    private func categoryStatusText(for section: LensDiscoverySection) -> String {
        if section.isLoading {
            return store.localized("lens.results.loading")
        }
        if section.didFail {
            return store.localized("lens.results.partial_failure")
        }
        return store.localizedFormat(
            "lens.results.category.count",
            section.items.count
        )
    }

    private func revealGuidanceSignal() {
        guard store.showsGuidanceAction else { return }
        if reduceMotion {
            guidanceSignalVisible = true
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                guidanceSignalVisible = true
            }
        }
    }

    private func scanAgain() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.scanAgain()
        dismiss()
    }
}

// MARK: - Spotlight Hero Item Card (#1 Top Match)

private struct LensDiscoverySpotlightCard: View {
    let item: LensDiscoveryItem
    let animalName: String
    let isOpening: Bool
    let store: PureLensStore
    let openHint: String
    let openingLabel: String
    let isRightToLeft: Bool
    let reduceMotion: Bool
    let contrast: ColorSchemeContrast
    let action: () -> Void

    private var theme: PureLensTheme { store.theme }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Hero Image Canvas with Floating Frosted Price Badge & Match Tag
                ZStack(alignment: .topTrailing) {
                    LensDiscoveryImage(urlString: item.imageURL, theme: theme)
                        .frame(maxWidth: .infinity)
                        .frame(height: LensResultMetrics.spotlightImageHeight)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                        )

                    // Floating Glass Price Tag
                    if let price = item.priceText, !price.isEmpty {
                        Text(price)
                            .font(theme.typography.subheadlineEmphasized)
                            .foregroundStyle(theme.brandStrong)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                theme.surfaceElevated.opacity(0.92),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        theme.brandStrong.opacity(0.28),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                            .padding(10)
                    }

                    // Top Match Badge (Top Leading)
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text(item.category == .services ? store.localized("lens.results.service.featured") : store.localized("lens.results.match.top"))
                            .font(theme.typography.captionEmphasized)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [theme.brandStrong, theme.brandPressed],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Item Details & Action Pill
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    // Action Bar
                    HStack(alignment: .center, spacing: 8) {
                        Text(isOpening ? openingLabel : (item.category == .services ? store.localized("lens.results.book_service") : store.localized("lens.results.details")))
                            .font(theme.typography.subheadlineEmphasized)
                            .foregroundStyle(theme.brandStrong)

                        if isOpening {
                            ProgressView()
                                .controlSize(.small)
                                .tint(theme.brandStrong)
                        } else {
                            Image(systemName: isRightToLeft ? "arrow.up.left" : "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.brandStrong)
                        }

                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 4)
            }
            .padding(14)
            .background(
                theme.surfaceRaised,
                in: RoundedRectangle(
                    cornerRadius: LensResultMetrics.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: LensResultMetrics.cardRadius,
                    style: .continuous
                )
                .stroke(
                    theme.brandStrong.opacity(contrast == .increased ? 0.50 : 0.18),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .shadow(
                color: Color.black.opacity(0.04),
                radius: 12,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(LensSpringCardButtonStyle(reduceMotion: reduceMotion))
        .disabled(isOpening)
        .opacity(isOpening ? 0.85 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue([item.priceText, item.subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(openHint)
    }
}

// MARK: - Sculpted Discovery Card (Category-Defining Horizontal Item)

private struct LensDiscoverySculptedCard: View {
    let item: LensDiscoveryItem
    let isOpening: Bool
    let theme: PureLensTheme
    let openHint: String
    let openingLabel: String
    let isRightToLeft: Bool
    let reduceMotion: Bool
    let contrast: ColorSchemeContrast
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                // Generous Product / Service Imagery
                LensDiscoveryImage(urlString: item.imageURL, theme: theme)
                    .frame(
                        width: LensResultMetrics.sculptedImageSize,
                        height: LensResultMetrics.sculptedImageSize
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: LensResultMetrics.itemCardRadius - 4,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: LensResultMetrics.itemCardRadius - 4,
                            style: .continuous
                        )
                        .stroke(
                            theme.separator.opacity(contrast == .increased ? 0.70 : 0.28),
                            lineWidth: 1
                        )
                    }

                // Structured Information
                VStack(alignment: .leading, spacing: 6) {
                    // Floating Price Pill (Prominent Top Row)
                    if let price = item.priceText, !price.isEmpty {
                        Text(price)
                            .font(theme.typography.captionEmphasized)
                            .foregroundStyle(theme.brandStrong)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                theme.brandSoft,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        theme.brandStrong.opacity(contrast == .increased ? 0.45 : 0.16),
                                        lineWidth: 1
                                    )
                            }
                    }

                    // Product / Service Title
                    Text(item.title)
                        .font(theme.typography.subheadlineEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Subtitle / Brief Context
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(theme.typography.caption2Medium)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    // Bottom Row: Action Trigger
                    HStack(alignment: .center, spacing: 6) {
                        Spacer(minLength: 4)

                        // Circular Action Capsule with Spinner / Directional Arrow
                        ZStack {
                            Circle()
                                .fill(theme.brandSoft)
                                .frame(
                                    width: LensResultMetrics.circularActionSize,
                                    height: LensResultMetrics.circularActionSize
                                )

                            if isOpening {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(theme.brandStrong)
                            } else {
                                Image(systemName: isRightToLeft ? "arrow.up.left" : "arrow.up.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(theme.brandStrong)
                            }
                        }
                    }
                }
                .frame(minHeight: LensResultMetrics.sculptedImageSize)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.surfaceRaised,
                in: RoundedRectangle(
                    cornerRadius: LensResultMetrics.itemCardRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: LensResultMetrics.itemCardRadius,
                    style: .continuous
                )
                .stroke(
                    theme.separator.opacity(contrast == .increased ? 0.70 : 0.32),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .shadow(
                color: Color.black.opacity(0.03),
                radius: 8,
                x: 0,
                y: 3
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: LensResultMetrics.itemCardRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(LensSpringCardButtonStyle(reduceMotion: reduceMotion))
        .disabled(isOpening)
        .opacity(isOpening ? 0.82 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOpening ? openingLabel : "")
        .accessibilityHint(openHint)
    }

    private var accessibilityLabel: String {
        [item.title, item.priceText, item.subtitle]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Category Tab (Tactile Sliding Capsule)

private struct LensCategoryTab: View {
    let section: LensDiscoverySection
    let isSelected: Bool
    let title: String
    let statusText: String
    let theme: PureLensTheme
    let contrast: ColorSchemeContrast
    let differentiateWithoutColor: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: section.category.lensSymbolName)
                    .font(.system(size: 13, weight: .bold))
                    .accessibilityHidden(true)

                Text(title)
                    .font(theme.typography.subheadlineEmphasized)
                    .lineLimit(1)

                categoryState
            }
            .foregroundStyle(isSelected ? Color.white : theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(minHeight: LensResultMetrics.categoryTabHeight)
            .background(tabBackground)
            .overlay {
                Capsule()
                    .stroke(
                        isSelected
                            ? theme.brandStrong.opacity(contrast == .increased ? 0.8 : 0.3)
                            : theme.separator.opacity(contrast == .increased ? 0.8 : 0.35),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
            .shadow(
                color: isSelected ? theme.brandStrong.opacity(0.32) : Color.clear,
                radius: 8,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(statusText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [theme.brandStrong, theme.brandPressed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            Capsule()
                .fill(theme.surfaceRaised)
        }
    }

    @ViewBuilder
    private var categoryState: some View {
        if section.isLoading {
            ProgressView()
                .controlSize(.mini)
                .tint(isSelected ? Color.white : theme.brandStrong)
                .accessibilityHidden(true)
        } else if section.didFail {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.warning)
                .accessibilityHidden(true)
        } else if differentiateWithoutColor && isSelected {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.black))
                .accessibilityHidden(true)
        } else {
            Text("\(section.items.count)")
                .font(theme.typography.captionEmphasized.monospacedDigit())
                .foregroundStyle(isSelected ? theme.brandStrong : theme.textSecondary)
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .background(
                    isSelected ? Color.white : theme.surfaceElevated,
                    in: Capsule()
                )
                .accessibilityHidden(true)
        }
    }
}

// MARK: - State Cards & Notices

private struct LensResultStateCard: View {
    let theme: PureLensTheme
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            theme.surfaceRaised,
            in: RoundedRectangle(
                cornerRadius: LensResultMetrics.controlRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }
}

private struct LensDiscoveryFailureRow: View {
    let theme: PureLensTheme
    let detail: String
    let retryTitle: String
    let retryHint: String
    let canRetry: Bool
    let isAccessibilitySize: Bool
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.warning)
                .accessibilityHidden(true)

            Text(detail)
                .font(theme.typography.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if canRetry {
                Button(retryTitle, action: retry)
                    .font(theme.typography.captionEmphasized)
                    .foregroundStyle(theme.brandStrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.brandSoft, in: Capsule())
                    .accessibilityHint(retryHint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            theme.warning.opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: LensResultMetrics.compactRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: LensResultMetrics.compactRadius,
                style: .continuous
            )
            .stroke(theme.warning.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct LensDiscoveryNotice: View {
    let theme: PureLensTheme
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.brandStrong)
                .frame(width: 28, height: 28)
                .background(theme.brandSoft, in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(theme.typography.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            theme.surfaceRaised,
            in: RoundedRectangle(
                cornerRadius: LensResultMetrics.compactRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: LensResultMetrics.compactRadius,
                style: .continuous
            )
            .stroke(theme.separator.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Skeleton Loading

private struct LensDiscoveryLoadingGrid: View {
    let theme: PureLensTheme

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.separator.opacity(0.20))
                        .frame(
                            width: LensResultMetrics.sculptedImageSize,
                            height: LensResultMetrics.sculptedImageSize
                        )

                    VStack(alignment: .leading, spacing: 10) {
                        Capsule()
                            .fill(theme.separator.opacity(0.26))
                            .frame(width: 60, height: 16)

                        Capsule()
                            .fill(theme.separator.opacity(0.24))
                            .frame(maxWidth: 180, minHeight: 14, maxHeight: 14)

                        Capsule()
                            .fill(theme.separator.opacity(0.16))
                            .frame(maxWidth: 120, minHeight: 11, maxHeight: 11)

                        Spacer(minLength: 0)

                        HStack {
                            Spacer()
                            Circle()
                                .fill(theme.separator.opacity(0.22))
                                .frame(width: 32, height: 32)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
                .background(
                    theme.surfaceRaised,
                    in: RoundedRectangle(
                        cornerRadius: LensResultMetrics.itemCardRadius,
                        style: .continuous
                    )
                )
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Studio Discovery Image

private struct LensDiscoveryImage: View {
    let urlString: String?
    let theme: PureLensTheme

    var body: some View {
        ZStack {
            theme.surface
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView().tint(theme.brandStrong)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.title3)
            .foregroundStyle(theme.textSecondary.opacity(0.45))
    }
}

// MARK: - Tactile Spring Card ButtonStyle

private struct LensSpringCardButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.76),
                value: configuration.isPressed
            )
    }
}

// MARK: - Category Lens Symbols

private extension LensDiscoveryCategory {
    var lensSymbolName: String {
        switch self {
        case .accessories: return "tag.fill"
        case .services: return "person.2.fill"
        case .medicine: return "cross.case.fill"
        case .products: return "bag.fill"
        }
    }
}

// MARK: - View Compatibility Extensions

extension View {
    @ViewBuilder
    func lensScrollIndicatorsHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollIndicators(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func lensPresentationDetents() -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDragIndicator(.visible)
                .presentationDetents([.fraction(0.60), .large])
        } else {
            self
        }
    }

    @ViewBuilder
    func lensPresentationAppearance(
        _ color: Color,
        reduceTransparency: Bool
    ) -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationBackground(
                    color.opacity(reduceTransparency ? 1 : 0.98)
                )
                .presentationCornerRadius(38)
        } else {
            self
        }
    }
}
#endif
