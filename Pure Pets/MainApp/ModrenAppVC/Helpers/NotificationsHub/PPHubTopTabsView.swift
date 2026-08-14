//
//  PPHubTopTabsView.swift
//  Pure Pets
//
//  SwiftUI replacement for the UIKit `PPHubTopTabsView` that previously lived
//  inside PPNotificationsHubViewController.m.
//
//  The sliding selection surface is expressed with `matchedGeometryEffect`
//  rather than a manually driven leading/width constraint pair. That keeps the
//  slide correct under Arabic RTL without mirroring arithmetic, which the
//  legacy `convertRect:fromView:` maths had to do by hand.
//

import SwiftUI

// MARK: - Item

struct PPHubTopTabItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let systemImage: String
}

// MARK: - View

struct PPHubTopTabsView: View {
    let items: [PPHubTopTabItem]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicatorNamespace

    private var hidesTitles: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var selectionAnimation: Animation? {
        reduceMotion
            ? nil
            : .spring(duration: PPHubMetrics.animationDurationNormal, bounce: 0.18)
    }

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            ForEach(items) { item in
                segment(for: item)
            }
        }
        .padding(PPSpace.xs)
        .frame(height: PPHubMetrics.topBarHeight)
        .background(surface)
        .animation(selectionAnimation, value: selectedIndex)
    }

    // MARK: Surface

    private var surface: some View {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
            .fill(Color.ppSecondarySurface)
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppBorder, lineWidth: 0.75)
            }
    }

    private var selectionIndicator: some View {
        RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
            .fill(Color.ppSurface)
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .strokeBorder(Color.ppPrimary.opacity(0.22), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                Capsule(style: .continuous)
                    .fill(Color.ppPrimary)
                    .frame(
                        width: PPHubMetrics.segmentActiveRailWidth,
                        height: PPHubMetrics.segmentActiveRailHeight
                    )
                    .padding(.bottom, PPSpace.xxs)
            }
    }

    // MARK: Segment

    private func segment(for item: PPHubTopTabItem) -> some View {
        let isSelected = item.id == selectedIndex

        return Button {
            guard item.id != selectedIndex else { return }
            onSelect(item.id)
        } label: {
            HStack(spacing: PPHubMetrics.segmentContentSpacing) {
                iconPlate(for: item, isSelected: isSelected)

                if !hidesTitles {
                    Text(item.title)
                        .font(PPHubTypography.segmentTitle())
                        .foregroundStyle(isSelected ? Color.ppTextPrimary : Color.ppTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, PPSpace.xs)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    selectionIndicator
                        .matchedGeometryEffect(id: PPHubTopTabsView.indicatorID, in: indicatorNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func iconPlate(for item: PPHubTopTabItem, isSelected: Bool) -> some View {
        Image(systemName: item.systemImage)
            .font(.system(size: PPHubMetrics.segmentIconSize, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Color.ppTextSecondary)
            .frame(
                width: PPHubMetrics.segmentIconPlateSize,
                height: PPHubMetrics.segmentIconPlateSize
            )
            .background {
                Circle().fill(isSelected ? Color.ppPrimary : Color.clear)
            }
            .accessibilityHidden(true)
    }

    private static let indicatorID = "pp.hub.tabs.selection"
}
