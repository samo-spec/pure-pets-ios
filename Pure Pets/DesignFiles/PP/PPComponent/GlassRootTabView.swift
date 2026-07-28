//
//  GlassRootTabView.swift
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/28/26.
//


import SwiftUI

// MARK: - Root Tab View

@available(iOS 17.0, *)
struct GlassRootTabView: View {

    @State private var selectedTab: AppTab = .profile
    @State private var isPresentingCreate = false

    @available(iOS 17.0, *)
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(AppTab.home)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            OrdersView()
                .tag(AppTab.orders)
                .tabItem {
                    Label("Orders", systemImage: "shippingbox")
                }

            ProfileView()
                .tag(AppTab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdaptiveGlassTabBar(
                selection: $selectedTab,
                onAddTapped: {
                    isPresentingCreate = true
                }
            )
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $isPresentingCreate) {
            CreateItemView()
        }
    }
}

// MARK: - Tab Model

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case orders
    case profile

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .home:
            "Home"
        case .orders:
            "Orders"
        case .profile:
            "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home:
            "house"
        case .orders:
            "shippingbox"
        case .profile:
            "person"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home:
            "house.fill"
        case .orders:
            "shippingbox.fill"
        case .profile:
            "person.fill"
        }
    }
}

// MARK: - Adaptive Wrapper

@available(iOS 17.0, *)
struct AdaptiveGlassTabBar: View {

    @Binding var selection: AppTab
    let onAddTapped: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                NativeGlassTabBar(
                    selection: $selection,
                    onAddTapped: onAddTapped
                )
            } else {
                MaterialGlassTabBar(
                    selection: $selection,
                    onAddTapped: onAddTapped
                )
            }
        }
    }
}

// MARK: - iOS 26 Native Liquid Glass

@available(iOS 26.0, *)
private struct NativeGlassTabBar: View {

    @Binding var selection: AppTab
    let onAddTapped: () -> Void

    @Namespace private var glassNamespace

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var selectionAnimation: Animation? {
        reduceMotion
            ? nil
            : .spring(
                response: 0.42,
                dampingFraction: 0.82,
                blendDuration: 0.1
            )
    }

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                tabsContainer

                Button(action: onAddTapped) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 58, height: 58)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Create new item")
            }
        }
    }

    private var tabsContainer: some View {
        HStack(spacing: 3) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: 31)
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            guard selection != tab else {
                return
            }

            withAnimation(selectionAnimation) {
                selection = tab
            }
        } label: {
            tabLabel(tab)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(
            selection == tab ? .isSelected : []
        )
    }

    @ViewBuilder
    private func tabLabel(_ tab: AppTab) -> some View {
        let label = VStack(spacing: 4) {
            Image(
                systemName: selection == tab
                    ? tab.selectedSymbol
                    : tab.symbol
            )
            .font(.system(size: 20, weight: .semibold))
            .symbolEffect(
                .bounce,
                value: selection == tab
            )

            Text(tab.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(
            selection == tab
                ? Color.blue
                : Color.primary.opacity(0.72)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .contentShape(
            RoundedRectangle(
                cornerRadius: 25,
                style: .continuous
            )
        )

        if selection == tab {
            label
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: 25)
                )
                .glassEffectID(
                    "selected-tab",
                    in: glassNamespace
                )
        } else {
            label
        }
    }
}

// MARK: - iOS 17–25 Material Fallback

@available(iOS 17.0, *)
private struct MaterialGlassTabBar: View {

    @Binding var selection: AppTab
    let onAddTapped: () -> Void

    @Namespace private var selectionNamespace

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var selectionAnimation: Animation? {
        reduceMotion
            ? nil
            : .spring(
                response: 0.42,
                dampingFraction: 0.82,
                blendDuration: 0.1
            )
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(5)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(
                    cornerRadius: 31,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 31,
                    style: .continuous
                )
                .strokeBorder(
                    .white.opacity(0.42),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(0.08),
                radius: 18,
                y: 8
            )

            Button(action: onAddTapped) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 58, height: 58)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                .white.opacity(0.44),
                                lineWidth: 1
                            )
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(GlassPressButtonStyle())
            .shadow(
                color: .black.opacity(0.08),
                radius: 16,
                y: 7
            )
            .accessibilityLabel("Create new item")
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            guard selection != tab else {
                return
            }

            withAnimation(selectionAnimation) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(
                    systemName: selection == tab
                        ? tab.selectedSymbol
                        : tab.symbol
                )
                .font(.system(size: 20, weight: .semibold))
                .symbolEffect(
                    .bounce,
                    value: selection == tab
                )

                Text(tab.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(
                selection == tab
                    ? Color.blue
                    : Color.primary.opacity(0.72)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                if selection == tab {
                    RoundedRectangle(
                        cornerRadius: 25,
                        style: .continuous
                    )
                    .fill(.regularMaterial)
                    .matchedGeometryEffect(
                        id: "selected-tab",
                        in: selectionNamespace
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 25,
                            style: .continuous
                        )
                        .strokeBorder(
                            .white.opacity(0.5),
                            lineWidth: 1
                        )
                    }
                    .shadow(
                        color: .black.opacity(0.06),
                        radius: 10,
                        y: 4
                    )
                }
            }
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 25,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(
            selection == tab ? .isSelected : []
        )
    }
}

// MARK: - Button Press Feedback

private struct GlassPressButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !reduceMotion
                    ? 0.93
                    : 1
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.15),
                value: configuration.isPressed
            )
    }
}



@available(iOS 16.0, *)
private struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("Home")
                .navigationTitle("Home")
        }
    }
}

@available(iOS 16.0, *)
private struct OrdersView: View {
    var body: some View {
        NavigationStack {
            Text("Orders")
                .navigationTitle("Orders")
        }
    }
}
@available(iOS 16.0, *)
private struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Profile")
                .navigationTitle("Profile")
        }
    }
}

@available(iOS 16.0, *)
private struct CreateItemView: View {

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Text("Create new item")
                .navigationTitle("Create")
                .toolbar {
                    ToolbarItem(
                        placement: .confirmationAction
                    ) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
