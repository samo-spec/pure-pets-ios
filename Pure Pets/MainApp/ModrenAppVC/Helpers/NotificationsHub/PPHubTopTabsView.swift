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
//  v2 — Liquid Glass segmented bar:
//  • The track is a quiet glass pill with a hairline top highlight.
//  • The selected segment is a brand-gradient capsule with a glossy top sheen,
//    soft brand shadow and white content so the active tab reads instantly.
//  • Unselected segments use the track's quiet secondary tones; pressing them
//    lifts the whole chip with scale + opacity (Reduce Motion aware).
//

import SwiftUI

// MARK: - Item

struct PPHubTopTabItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let systemImage: String
}

// MARK: - Tabs-only geometry

private enum PPHubTopTabShape {
    /// Continuous-corner radius of the selected capsule.
    static let capsule: CGFloat = PPCorner.medium
    /// Where the gloss gradient stops (fraction of the capsule height).
    static let sheen: CGFloat = 0.42
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
        VStack(spacing: 0) {
            segmentBar
        }
        .frame(height: PPHubMetrics.topBarHeight)
        .padding(PPSpace.xs)
        .background(trackSurface)
        .animation(selectionAnimation, value: selectedIndex)
        .accessibilityElement(children: .contain)
    }

    private var segmentBar: some View {
        HStack(spacing: PPSpace.xs) {
            ForEach(items) { item in
                segment(for: item)
            }
        }
    }

    // MARK: Track — quiet glass pill

    private var trackSurface: some View {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.ppSecondarySurface, Color.ppSurface.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppBorder, lineWidth: 0.75)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, PPSpace.base)
                    .padding(.top, PPSpace.xxs)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    // MARK: Selection — brand glass capsule

    private var selectionIndicator: some View {
        RoundedRectangle(cornerRadius: PPHubTopTabShape.capsule, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.ppPrimary, Color.ppPrimary.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPHubTopTabShape.capsule, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.clear],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: PPHubTopTabShape.sheen)
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: PPHubTopTabShape.capsule, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
            }
            .shadow(color: Color.ppPrimary.opacity(0.38), radius: 10, x: 0, y: 4)
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
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : Color.ppTextSecondary
                        )
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
                        .matchedGeometryEffect(
                            id: PPHubTopTabsView.indicatorID,
                            in: indicatorNamespace
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PPHubTopTabPressStyle())
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
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .overlay {
                            Circle().strokeBorder(
                                Color.white.opacity(0.22),
                                lineWidth: 0.75
                            )
                        }
                }
            }
            .accessibilityHidden(true)
    }

    private static let indicatorID = "pp.hub.tabs.selection"
}

// MARK: - Press physics

private struct PPHubTopTabPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.96 : 1
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
