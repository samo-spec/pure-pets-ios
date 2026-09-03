//
//  PPNotificationsInboxView.swift
//  Pure Pets
//
//  SwiftUI replacement for the presentation half of the legacy
//  `PPNotificationsInboxViewController` (table view, inbox cell, state view).
//
//  Card metrics, corner radii, insets and copy are ported unchanged; only the
//  rendering technology differs.
//

import SwiftUI

// MARK: - Inbox

struct PPNotificationsInboxView: View {
    @ObservedObject var store: PPNotificationsInboxStore

    /// Bottom clearance measured by the hosting controller from the root tab
    /// bar's Command Deck. Mirrors the legacy `contentInset.bottom` that
    /// `PPRootTabBarController` used to raise on the table view directly.
    let bottomClearance: CGFloat

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: PPSpace.sm) {
                ForEach(store.items) { item in
                    Button {
                        store.select(item)
                    } label: {
                        PPNotificationInboxRow(item: item, metaText: store.metaText(for: item))
                    }
                    .buttonStyle(PPNotificationInboxRowStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(accessibilityLabel(for: item))
                    .accessibilityValue(
                        item.isRead ? "" : PPHubText("notifications_inbox_accessibility_new")
                    )
                }
            }
            .padding(.top, PPSpace.sm)
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.bottom, max(PPHubMetrics.listBaseBottomInset, bottomClearance))
        }
        .scrollIndicatorsHiddenCompat()
        .refreshable {
            await store.refresh()
        }
        .background {
            if store.items.isEmpty, store.state != .content {
                PPNotificationsInboxStateView(state: store.state) {
                    store.reloadNotifications()
                }
            }
        }
        .onAppear { store.activate() }
    }

    private func accessibilityLabel(for item: PPNotificationInboxItem) -> String {
        var parts: [String] = []
        if !item.title.isEmpty { parts.append(item.title) }
        if !item.subtitle.isEmpty { parts.append(item.subtitle) }
        let meta = store.metaText(for: item)
        if !meta.isEmpty { parts.append(meta) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Row

private struct PPNotificationInboxRow: View {
    let item: PPNotificationInboxItem
    let metaText: String

    var body: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            iconContainer

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(PPHubTypography.rowTitle(isRead: item.isRead))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(PPHubTypography.rowSubtitle())
                        .foregroundStyle(Color.ppTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, PPSpace.xs)
                }

                if !metaText.isEmpty {
                    Text(metaText)
                        .font(PPHubTypography.rowMeta())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, PPSpace.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PPSpace.base)
        .background(cardSurface)
        .overlay(alignment: .leading) {
            if !item.isRead {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.ppPrimary)
                    .frame(width: 3, height: 32)
                    .padding(.leading, PPSpace.xs)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
            .fill(item.isRead ? Color.ppSurface : Color.ppElevatedSurface)
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppBorder, lineWidth: 0.75)
            }
    }

    private var iconContainer: some View {
        Image(systemName: item.symbolName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(item.accentColor)
            .frame(width: 46, height: 46)
            .background {
                RoundedRectangle(
                    cornerRadius: PPHubMetrics.iconContainerCorner,
                    style: .continuous
                )
                .fill(item.accentColor.opacity(0.14))
            }
            .accessibilityHidden(true)
    }
}

/// Reproduces the legacy `setHighlighted:` card feedback (0.985 scale, 0.92
/// alpha) and honours Reduce Motion the same way.
private struct PPNotificationInboxRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: configuration.isPressed ? 0.12 : 0.24),
                value: configuration.isPressed
            )
    }
}

// MARK: - State view

private struct PPNotificationsInboxStateView: View {
    let state: PPNotificationsInboxState
    let onRetry: () -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                indicator
                    .frame(height: 44)

                Text(titleText)
                    .font(PPHubTypography.stateTitle())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, PPSpace.base)
                    .padding(.horizontal, 28)

                Text(subtitleText)
                    .font(PPHubTypography.stateSubtitle())
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, PPSpace.sm)
                    .padding(.horizontal, 34)

                if showsRetry {
                    Button(action: onRetry) {
                        Text(PPHubText("retry"))
                            .font(PPHubTypography.stateAction())
                            .foregroundStyle(Color.ppPrimary)
                            .padding(.vertical, PPSpace.sm)
                            .padding(.horizontal, PPSpace.base)
                            .frame(minHeight: PPHubMetrics.touchTargetMin)
                            .background {
                                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                    .strokeBorder(Color.ppBorder, lineWidth: 0.75)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, PPSpace.base)
                }
            }
            .frame(width: proxy.size.width)
            .position(x: proxy.size.width / 2, y: (proxy.size.height / 2) - 38)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(titleText)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.ppPrimary)
        case .error:
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(Color.ppAccentText)
        case .empty, .content:
            Image(systemName: "bell.slash")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(Color.ppTextSecondary)
        }
    }

    private var titleText: String {
        switch state {
        case .loading:
            return PPHubText("notifications_inbox_loading_title")
        case .error:
            return PPHubText("load_error_title")
        case .empty, .content:
            return PPHubText("notifications_inbox_empty_title")
        }
    }

    private var subtitleText: String {
        switch state {
        case .loading:
            return PPHubText("notifications_hub_hero_notifications_subtitle")
        case .error:
            return PPHubText("connection_timeout_message")
        case .empty, .content:
            return PPHubText("notifications_inbox_empty_subtitle")
        }
    }

    private var showsRetry: Bool {
        state == .error
    }
}

private extension View {
    @ViewBuilder
    func scrollIndicatorsHiddenCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollIndicators(.hidden)
        } else {
            self
        }
    }
}
