//
//  PPCommunityScreens.swift
//  Pure Pets
//
//  Customer Community gateway, Adoption applications, Missing/Found reports,
//  sightings, activity, safe messaging entry points, and responsive states.
//

import CoreLocation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum CommunityFont {
    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: style)
    }
}

private enum CommunityPalette {
    static let adoption = Color.ppAdoptionAccent
    static let missing = Color.orange
    static let found = Color.teal
    static let safe = Color.green
}

private struct CommunityPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && enabled && !reduceMotion ? 0.975 : 1)
            .opacity(enabled ? (configuration.isPressed ? 0.88 : 1) : 0.48)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private func communityDictionary(_ value: Any?) -> [String: Any] {
    value as? [String: Any] ?? [:]
}

private func communityString(_ value: Any?) -> String {
    (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

private func communityInt(_ value: Any?, fallback: Int = 0) -> Int {
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String, let number = Int(string) { return number }
    return fallback
}

private func communityID(_ item: [String: Any]) -> String {
    communityString(item["id"] ?? item["listingId"] ?? item["caseId"] ?? item["reportId"] ?? item["applicationId"] ?? item["matchId"])
}

private func communityTitle(_ item: [String: Any]) -> String {
    let pet = communityDictionary(item["pet"])
    let profile = communityDictionary(item["profile"])
    for candidate in [pet["name"], profile["name"], item["title"]] {
        let value = communityString(candidate)
        if !value.isEmpty { return value }
    }
    return PPAdoptLang("community_pet_fallback")
}

private func communityArea(_ item: [String: Any]) -> String {
    let area = communityDictionary(item["area"] ?? item["location"])
    let values = [communityString(area["district"]), communityString(area["city"])]
        .filter { !$0.isEmpty }
    return values.isEmpty ? PPAdoptLang("community_location_private") : values.joined(separator: PPAdoptLang("community_separator"))
}

private func communityStatus(_ item: [String: Any]) -> String {
    let status = communityString(item["status"])
    return status.isEmpty ? PPAdoptLang("community_status_unknown") : PPAdoptLang("community_status_\(status)")
}

@MainActor
private final class CommunityGatewayStore: ObservableObject {
    @Published var configuration: PPCommunityConfiguration?
    @Published var loading = true
    @Published var errorMessage: String?

    func load() async {
        loading = true
        errorMessage = nil
        do {
            configuration = try await PPCommunityService.shared.configuration()
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

struct PPCommunityGatewayScreen: View {
    @StateObject private var store = CommunityGatewayStore()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    let onSelectAdoption: (AdoptPetModel) -> Void
    let onCreateAdoption: () -> Void
    let onClose: () -> Void
    let initialRoute: String
    @State private var opensInitialActivity = false

    init(
        onSelectAdoption: @escaping (AdoptPetModel) -> Void,
        onCreateAdoption: @escaping () -> Void,
        onClose: @escaping () -> Void,
        initialRoute: String = ""
    ) {
        self.onSelectAdoption = onSelectAdoption
        self.onCreateAdoption = onCreateAdoption
        self.onClose = onClose
        self.initialRoute = initialRoute
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                content
            }
            .background {
                NavigationLink(
                    destination: CommunityActivityScreen(messagingEnabled: store.configuration?.messagingEnabled ?? false),
                    isActive: $opensInitialActivity
                ) { EmptyView() }
                .hidden()
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: store.loading) { loading in
            guard !loading, initialRoute.lowercased().hasPrefix("community/") else { return }
            opensInitialActivity = true
        }
        .task { await store.load() }
    }

    @ViewBuilder
    private var content: some View {
        if store.loading {
            CommunityStateView(
                symbol: "pawprint.circle.fill",
                title: PPAdoptLang("community_loading_title"),
                message: PPAdoptLang("community_loading_message"),
                showsProgress: true
            )
        } else if let error = store.errorMessage {
            CommunityStateView(
                symbol: "wifi.exclamationmark",
                title: PPAdoptLang("community_error_title"),
                message: error,
                actionTitle: PPAdoptLang("Retry"),
                action: { Task { await store.load() } }
            )
        } else if store.configuration?.communityEnabled != true {
            CommunityStateView(
                symbol: "clock.badge.checkmark",
                title: PPAdoptLang("community_unavailable_title"),
                message: PPAdoptLang("community_unavailable_message"),
                actionTitle: PPAdoptLang("Close"),
                action: onClose
            )
        } else {
            gateway
        }
    }

    private var gateway: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: isPad ? 28 : 20) {
                CommunityGatewayHeader(onClose: onClose)

                if isPad {
                    HStack(alignment: .top, spacing: 24) {
                        hero
                            .frame(maxWidth: 390)
                        featureGrid
                    }
                } else {
                    hero
                    featureGrid
                }

                safetyBanner
            }
            .frame(maxWidth: 1100)
            .padding(.horizontal, isPad ? 34 : 18)
            .padding(.bottom, 40)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [CommunityPalette.adoption.opacity(0.92), Color.purple.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Text(PPAdoptLang("community_hero_title"))
                        .font(CommunityFont.bold(isPad ? 34 : 29, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(PPAdoptLang("community_hero_message"))
                        .font(CommunityFont.regular(16, relativeTo: .body))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .frame(minHeight: isPad ? 310 : 245)
            .accessibilityElement(children: .combine)

            Text(PPAdoptLang("community_privacy_note"))
                .font(CommunityFont.medium(13, relativeTo: .footnote))
                .foregroundStyle(Color.ppTextSecondary)
                .padding(.horizontal, 4)
        }
    }

    private var featureGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: isPad ? 250 : 150), spacing: 14)],
            spacing: 14
        ) {
            if store.configuration?.adoptionEnabled == true {
                NavigationLink {
                    CommunityAdoptionDestination(onSelect: onSelectAdoption, onCreate: onCreateAdoption)
                } label: {
                    CommunityGatewayCard(
                        symbol: "heart.fill",
                        color: CommunityPalette.adoption,
                        title: PPAdoptLang("community_adoption_title"),
                        message: PPAdoptLang("community_adoption_message")
                    )
                }
                .buttonStyle(CommunityPressStyle())
            }

            if store.configuration?.missingPetsEnabled == true || store.configuration?.foundPetReportsEnabled == true {
                NavigationLink {
                    CommunityLostFoundScreen(configuration: store.configuration!)
                } label: {
                    CommunityGatewayCard(
                        symbol: "location.magnifyingglass",
                        color: CommunityPalette.missing,
                        title: PPAdoptLang("community_lost_found_title"),
                        message: PPAdoptLang("community_lost_found_message")
                    )
                }
                .buttonStyle(CommunityPressStyle())
            }

            NavigationLink {
                CommunityActivityScreen(messagingEnabled: store.configuration?.messagingEnabled ?? false)
            } label: {
                CommunityGatewayCard(
                    symbol: "clock.arrow.circlepath",
                    color: Color.blue,
                    title: PPAdoptLang("community_activity_title"),
                    message: PPAdoptLang("community_activity_message")
                )
            }
            .buttonStyle(CommunityPressStyle())

            NavigationLink {
                CommunitySavedScreen(sightingsEnabled: store.configuration?.sightingsEnabled ?? false)
            } label: {
                CommunityGatewayCard(
                    symbol: "bookmark.fill",
                    color: Color.indigo,
                    title: PPAdoptLang("community_saved_title"),
                    message: PPAdoptLang("community_saved_message")
                )
            }
            .buttonStyle(CommunityPressStyle())

            if store.configuration?.organizationsEnabled == true {
                NavigationLink {
                    CommunityOrganizationsScreen()
                } label: {
                    CommunityGatewayCard(
                        symbol: "checkmark.seal.fill",
                        color: CommunityPalette.safe,
                        title: PPAdoptLang("community_organizations_title"),
                        message: PPAdoptLang("community_organizations_message")
                    )
                }
                .buttonStyle(CommunityPressStyle())
            }
        }
    }

    private var safetyBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CommunityPalette.safe)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(PPAdoptLang("community_safety_title"))
                    .font(CommunityFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                Text(PPAdoptLang("community_safety_message"))
                    .font(CommunityFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.7), lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
    }
}

private struct CommunityGatewayHeader: View {
    @Environment(\.layoutDirection) private var direction
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: direction == .rightToLeft ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.ppSurface, in: Circle())
            }
            .buttonStyle(CommunityPressStyle())
            .accessibilityLabel(PPAdoptLang("Close"))

            VStack(alignment: .leading, spacing: 1) {
                Text(PPAdoptLang("community_title"))
                    .font(CommunityFont.bold(22, relativeTo: .title2))
                    .foregroundStyle(Color.ppTextPrimary)
                Text(PPAdoptLang("community_subtitle"))
                    .font(CommunityFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct CommunityGatewayCard: View {
    let symbol: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(CommunityFont.bold(18, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(message)
                .font(CommunityFont.regular(13, relativeTo: .footnote))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 195, alignment: .topLeading)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct CommunityAdoptionDestination: View {
    @Environment(\.presentationMode) private var presentationMode
    let onSelect: (AdoptPetModel) -> Void
    let onCreate: () -> Void

    var body: some View {
        AdoptPetListScreen(
            onSelectPet: onSelect,
            onAddPet: onCreate,
            onClose: { presentationMode.wrappedValue.dismiss() }
        )
    }
}

private struct CommunityStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var showsProgress = false

    var body: some View {
        VStack(spacing: 14) {
            if showsProgress {
                ProgressView().scaleEffect(1.1)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(CommunityPalette.adoption)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(CommunityFont.bold(22, relativeTo: .title2))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(CommunityFont.regular(15, relativeTo: .body))
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .frame(minHeight: 48)
                        .background(CommunityPalette.adoption, in: Capsule())
                }
                .buttonStyle(CommunityPressStyle())
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
private final class CommunityLostFoundStore: ObservableObject {
    @Published var query = "" { didSet { scheduleSearch() } }
    @Published var missing: [[String: Any]] = []
    @Published var found: [[String: Any]] = []
    @Published var loading = true
    @Published var refreshing = false
    @Published var featureDisabled = false
    @Published var errorMessage: String?
    @Published var loadingMoreMissing = false
    @Published var loadingMoreFound = false
    private var generation = 0
    private var missingCursor: String?
    private var foundCursor: String?
    private var hasMoreMissing = false
    private var hasMoreFound = false
    private var searchTask: Task<Void, Never>?

    func load(refresh: Bool = false) async {
        generation += 1
        let requestGeneration = generation
        missingCursor = nil
        foundCursor = nil
        hasMoreMissing = false
        hasMoreFound = false
        if refresh { refreshing = true } else { loading = missing.isEmpty && found.isEmpty }
        errorMessage = nil
        do {
            let result = try await PPCommunityService.shared.browseLostFound(query: query)
            guard requestGeneration == generation else { return }
            missing = result.missing.items
            found = result.found.items
            missingCursor = result.missing.nextCursor
            foundCursor = result.found.nextCursor
            hasMoreMissing = result.missing.hasMore && result.missing.nextCursor != nil
            hasMoreFound = result.found.hasMore && result.found.nextCursor != nil
            featureDisabled = result.featureDisabled
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
        loading = false
        refreshing = false
    }

    func loadNextIfNeeded(kind: CommunityCaseKind, current item: [String: Any]) {
        let items = kind == .missing ? missing : found
        guard items.suffix(4).contains(where: { communityID($0) == communityID(item) }) else { return }
        if kind == .missing {
            guard hasMoreMissing, !loadingMoreMissing else { return }
            loadingMoreMissing = true
        } else {
            guard hasMoreFound, !loadingMoreFound else { return }
            loadingMoreFound = true
        }
        Task { @MainActor [weak self] in await self?.loadNext(kind: kind) }
    }

    private func loadNext(kind: CommunityCaseKind) async {
        let requestGeneration = generation
        defer {
            if kind == .missing { loadingMoreMissing = false } else { loadingMoreFound = false }
        }
        do {
            let result = try await PPCommunityService.shared.browseLostFound(
                query: query,
                missingCursor: kind == .missing ? missingCursor : nil,
                foundCursor: kind == .found ? foundCursor : nil,
                includeMissing: kind == .missing,
                includeFound: kind == .found
            )
            guard requestGeneration == generation else { return }
            if kind == .missing {
                var seen = Set(missing.map(communityID))
                missing.append(contentsOf: result.missing.items.filter { seen.insert(communityID($0)).inserted })
                missingCursor = result.missing.nextCursor
                hasMoreMissing = result.missing.hasMore && result.missing.nextCursor != nil
            } else {
                var seen = Set(found.map(communityID))
                found.append(contentsOf: result.found.items.filter { seen.insert(communityID($0)).inserted })
                foundCursor = result.found.nextCursor
                hasMoreFound = result.found.hasMore && result.found.nextCursor != nil
            }
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.load(refresh: true)
        }
    }
}

private struct CommunityLostFoundScreen: View {
    enum Segment: String, CaseIterable, Identifiable {
        case missing
        case found
        var id: String { rawValue }
    }

    let configuration: PPCommunityConfiguration
    @StateObject private var store = CommunityLostFoundStore()
    @State private var segment: Segment = .missing
    @State private var presentedForm: CommunityCaseKind?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var items: [[String: Any]] { segment == .missing ? store.missing : store.found }
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.ppBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                CommunityScreenHeader(
                    title: PPAdoptLang("community_lost_found_title"),
                    subtitle: PPAdoptLang("community_lost_found_message")
                )
                controls
                content
            }
            reportMenu
                .padding(isPad ? 34 : 20)
        }
        .navigationBarHidden(true)
        .task { await store.load() }
        .sheet(item: $presentedForm) { kind in
            CommunityCaseFormScreen(kind: kind) {
                presentedForm = nil
                Task { await store.load(refresh: true) }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Segment.allCases) { value in
                    Button {
                        segment = value
                    } label: {
                        Text(PPAdoptLang(value == .missing ? "community_missing_title" : "community_found_title"))
                            .font(CommunityFont.bold(15, relativeTo: .subheadline))
                            .foregroundStyle(segment == value ? .white : Color.ppTextSecondary)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(segment == value ? (value == .missing ? CommunityPalette.missing : CommunityPalette.found) : Color.ppSurface, in: Capsule())
                    }
                    .buttonStyle(CommunityPressStyle())
                    .accessibilityAddTraits(segment == value ? .isSelected : [])
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.ppTextSecondary)
                TextField(PPAdoptLang("community_search_placeholder"), text: $store.query)
                    .font(CommunityFont.regular(15))
                    .submitLabel(.search)
                    .onSubmit { Task { await store.load(refresh: true) } }
                if !store.query.isEmpty {
                    Button { store.query = ""; Task { await store.load(refresh: true) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ppTextTertiary)
                    }
                    .accessibilityLabel(PPAdoptLang("ClearFilters"))
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .padding(.horizontal, isPad ? 34 : 18)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if store.loading {
            CommunityStateView(symbol: "location.magnifyingglass", title: PPAdoptLang("community_loading_title"), message: PPAdoptLang("community_loading_message"), showsProgress: true)
        } else if let error = store.errorMessage, items.isEmpty {
            CommunityStateView(symbol: "wifi.exclamationmark", title: PPAdoptLang("community_error_title"), message: error, actionTitle: PPAdoptLang("Retry"), action: { Task { await store.load() } })
        } else if store.featureDisabled {
            CommunityStateView(symbol: "clock.badge.checkmark", title: PPAdoptLang("community_unavailable_title"), message: PPAdoptLang("community_unavailable_message"))
        } else if items.isEmpty {
            CommunityStateView(
                symbol: segment == .missing ? "pawprint" : "hand.raised",
                title: PPAdoptLang(segment == .missing ? "community_missing_empty_title" : "community_found_empty_title"),
                message: PPAdoptLang(segment == .missing ? "community_missing_empty_message" : "community_found_empty_message")
            )
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: isPad ? 310 : 280), spacing: 16)], spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.offset) { pair in
                        let item = pair.element
                        NavigationLink {
                            CommunityLostFoundDetailScreen(
                                item: item,
                                kind: segment == .missing ? .missing : .found,
                                sightingsEnabled: configuration.sightingsEnabled
                            )
                        } label: {
                            CommunityRecordCard(item: item, kind: segment == .missing ? .missing : .found)
                        }
                        .buttonStyle(CommunityPressStyle())
                        .onAppear { store.loadNextIfNeeded(kind: segment == .missing ? .missing : .found, current: item) }
                    }
                }
                .padding(.horizontal, isPad ? 34 : 18)
                .padding(.bottom, 110)
            }
            .refreshable { await store.load(refresh: true) }
        }
    }

    private var reportMenu: some View {
        Menu {
            if configuration.missingPetsEnabled {
                Button(PPAdoptLang("community_report_missing"), systemImage: "exclamationmark.magnifyingglass") {
                    guard UserManager.shared().isUserLoggedIn() else { UserManager.showPromptOnTopController(); return }
                    presentedForm = .missing
                }
            }
            if configuration.foundPetReportsEnabled {
                Button(PPAdoptLang("community_report_found"), systemImage: "hand.raised.fill") {
                    guard UserManager.shared().isUserLoggedIn() else { UserManager.showPromptOnTopController(); return }
                    presentedForm = .found
                }
            }
        } label: {
            Label(PPAdoptLang("community_report_action"), systemImage: "plus")
                .font(CommunityFont.bold(16, relativeTo: .headline))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(CommunityPalette.adoption, in: Capsule())
                .shadow(color: CommunityPalette.adoption.opacity(0.28), radius: 12, y: 5)
        }
        .accessibilityHint(PPAdoptLang("community_report_action_hint"))
    }
}

private struct CommunityScreenHeader: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.layoutDirection) private var direction
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Button { presentationMode.wrappedValue.dismiss() } label: {
                Image(systemName: direction == .rightToLeft ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.ppSurface, in: Circle())
            }
            .buttonStyle(CommunityPressStyle())
            .accessibilityLabel(PPAdoptLang("Back"))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(CommunityFont.bold(21, relativeTo: .title2)).foregroundStyle(Color.ppTextPrimary)
                Text(subtitle).font(CommunityFont.regular(12, relativeTo: .caption)).foregroundStyle(Color.ppTextSecondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.ppElevatedSurface)
    }
}

private enum CommunityCaseKind: String, Identifiable {
    case missing
    case found
    var id: String { rawValue }
}

private struct CommunityRecordCard: View {
    let item: [String: Any]
    let kind: CommunityCaseKind

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommunityRemoteMedia(url: PPCommunityService.shared.primaryImageURL(in: item))
                .frame(height: 190)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    Text(communityTitle(item))
                        .font(CommunityFont.bold(20, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                    Spacer()
                    Text(communityStatus(item))
                        .font(CommunityFont.bold(11, relativeTo: .caption))
                        .foregroundStyle(kind == .missing ? CommunityPalette.missing : CommunityPalette.found)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background((kind == .missing ? CommunityPalette.missing : CommunityPalette.found).opacity(0.12), in: Capsule())
                }
                Label(communityArea(item), systemImage: "mappin.and.ellipse")
                    .font(CommunityFont.medium(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                Text(communityString(item["description"]))
                    .font(CommunityFont.regular(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
            }
            .padding(16)
        }
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 23).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct CommunityRemoteMedia: View {
    let url: URL?
    var body: some View {
        ZStack {
            Color.ppSecondarySurface
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: fallback
                    default: ProgressView()
                    }
                }
            } else { fallback }
        }
        .clipped()
    }
    private var fallback: some View {
        Image(systemName: "pawprint.fill").font(.system(size: 38)).foregroundStyle(Color.ppTextTertiary)
    }
}

@MainActor
private final class CommunityLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum State { case idle, requesting, ready, denied, failed }
    @Published var state: State = .idle
    @Published var coordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        state = .requesting
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: state = .denied
        @unknown default: state = .failed
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            state = .denied
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { state = .failed; return }
        coordinate = location.coordinate
        state = .ready
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        state = .failed
    }
}

@MainActor
private final class CommunityCaseFormStore: ObservableObject {
    let kind: CommunityCaseKind
    let recordID = UUID().uuidString.lowercased()
    @Published var pets: [PPPetProfile] = []
    @Published var selectedPetID = ""
    @Published var species = ""
    @Published var breed = ""
    @Published var sex = ""
    @Published var size = ""
    @Published var colors = ""
    @Published var distinctiveMarks = ""
    @Published var descriptionText = ""
    @Published var wearing = ""
    @Published var city = ""
    @Published var district = ""
    @Published var eventDate = Date()
    @Published var rewardOffered = false
    @Published var custodyStatus = "unknown"
    @Published var media: [PPCommunityMediaSource] = []
    @Published var loadingPets = false
    @Published var submitting = false
    @Published var errorMessage: String?
    @Published var success = false

    init(kind: CommunityCaseKind) { self.kind = kind }

    func loadPets() {
        guard kind == .missing else { return }
        loadingPets = true
        UserManager.shared().fetchPetProfilesForCurrentUser { [weak self] pets, error in
            Task { @MainActor in
                guard let self else { return }
                self.loadingPets = false
                self.pets = pets ?? []
                if self.selectedPetID.isEmpty { self.selectedPetID = self.pets.first?.petID ?? "" }
                if let error { self.errorMessage = error.localizedDescription }
            }
        }
    }

    var canSubmit: Bool {
        let common = !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !media.isEmpty
        if kind == .missing { return common && !selectedPetID.isEmpty }
        return common && !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(coordinate: CLLocationCoordinate2D?) async {
        guard canSubmit, let coordinate else {
            errorMessage = PPAdoptLang("community_location_required")
            return
        }
        submitting = true
        errorMessage = nil
        do {
            let context = kind == .missing ? "missing_case" : "found_report"
            let uploaded = try await PPCommunityService.shared.uploadMedia(media, contextType: context, contextID: recordID)
            let area: [String: Any] = [
                "countryCode": CountryModel.safeCurrentCountryISOCode() ?? "",
                "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
                "district": district.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
            let location: [String: Any] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
            if kind == .missing {
                guard let pet = pets.first(where: { $0.petID == selectedPetID }) else { throw PPCommunityError.invalidResponse }
                let appearance: [String: Any] = [
                    "speciesId": communityString(pet.categoryName).isEmpty ? String(pet.categoryId) : communityString(pet.categoryName),
                    "breed": communityString(pet.breed), "sex": sex, "size": size,
                    "colors": colorValues, "distinctiveMarks": distinctiveMarks
                ]
                _ = try await PPCommunityService.shared.createMissingCase(payload: [
                    "caseId": recordID, "petId": pet.petID,
                    "lostAt": PPCommunityService.shared.isoString(eventDate),
                    "location": location, "area": area, "appearance": appearance,
                    "description": descriptionText, "wearing": wearing,
                    "rewardOffered": rewardOffered, "contactMode": "in_app",
                    "mediaAssetIds": uploaded.assetIDs
                ])
            } else {
                let appearance: [String: Any] = [
                    "speciesId": species, "breed": breed, "sex": sex, "size": size,
                    "colors": colorValues, "distinctiveMarks": distinctiveMarks
                ]
                _ = try await PPCommunityService.shared.createFoundReport(payload: [
                    "reportId": recordID,
                    "foundAt": PPCommunityService.shared.isoString(eventDate),
                    "location": location, "area": area, "appearance": appearance,
                    "description": descriptionText, "custodyStatus": custodyStatus,
                    "contactMode": "in_app", "mediaAssetIds": uploaded.assetIDs
                ])
            }
            success = true
        } catch {
            errorMessage = error.localizedDescription
        }
        submitting = false
    }

    private var colorValues: [String] {
        let items = colors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(items.prefix(6))
    }
}

private struct CommunityCaseFormScreen: View {
    let kind: CommunityCaseKind
    let onFinished: () -> Void
    @StateObject private var store: CommunityCaseFormStore
    @StateObject private var location = CommunityLocationProvider()
    @State private var showsMediaPicker = false
    @Environment(\.presentationMode) private var presentationMode

    init(kind: CommunityCaseKind, onFinished: @escaping () -> Void) {
        self.kind = kind
        self.onFinished = onFinished
        _store = StateObject(wrappedValue: CommunityCaseFormStore(kind: kind))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        introCard
                        if kind == .missing { petSelector }
                        appearanceCard
                        storyCard
                        locationCard
                        mediaCard
                        if let error = store.errorMessage { errorCard(error) }
                        submitButton
                    }
                    .frame(maxWidth: 760)
                    .padding(18)
                }
                if store.submitting {
                    Color.black.opacity(0.22).ignoresSafeArea()
                    ProgressView(PPAdoptLang("community_submitting"))
                        .font(CommunityFont.bold(16))
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .navigationTitle(PPAdoptLang(kind == .missing ? "community_report_missing" : "community_report_found"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { store.loadPets() }
        .onChange(of: store.success) { succeeded in if succeeded { onFinished() } }
        .sheet(isPresented: $showsMediaPicker) {
            CommunityMediaPicker(maximumCount: max(1, 8 - store.media.count)) { sources in
                store.media.append(contentsOf: sources.prefix(max(0, 8 - store.media.count)))
            }
        }
    }

    private var introCard: some View {
        CommunityFormCard(
            symbol: kind == .missing ? "exclamationmark.magnifyingglass" : "hand.raised.fill",
            tint: kind == .missing ? CommunityPalette.missing : CommunityPalette.found,
            title: PPAdoptLang(kind == .missing ? "community_missing_form_title" : "community_found_form_title"),
            message: PPAdoptLang("community_form_privacy_message")
        ) { EmptyView() }
    }

    private var petSelector: some View {
        CommunityFormCard(symbol: "pawprint.fill", tint: CommunityPalette.adoption, title: PPAdoptLang("community_select_pet"), message: PPAdoptLang("community_select_pet_message")) {
            if store.loadingPets {
                ProgressView()
            } else if store.pets.isEmpty {
                Text(PPAdoptLang("community_no_pet_profiles"))
                    .font(CommunityFont.regular(14)).foregroundStyle(Color.ppTextSecondary)
            } else {
                Picker(PPAdoptLang("community_select_pet"), selection: $store.selectedPetID) {
                    ForEach(store.pets, id: \.petID) { pet in Text(pet.name).tag(pet.petID) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var appearanceCard: some View {
        CommunityFormCard(symbol: "sparkles", tint: .purple, title: PPAdoptLang("community_appearance_title"), message: PPAdoptLang("community_appearance_message")) {
            VStack(spacing: 12) {
                if kind == .found { CommunityField(title: PPAdoptLang("community_species"), text: $store.species) }
                CommunityField(title: PPAdoptLang("Breed"), text: $store.breed)
                HStack { CommunityField(title: PPAdoptLang("Gender"), text: $store.sex); CommunityField(title: PPAdoptLang("community_size"), text: $store.size) }
                CommunityField(title: PPAdoptLang("community_colors"), text: $store.colors)
                CommunityField(title: PPAdoptLang("community_marks"), text: $store.distinctiveMarks)
            }
        }
    }

    private var storyCard: some View {
        CommunityFormCard(symbol: "text.alignleft", tint: .blue, title: PPAdoptLang("community_details_title"), message: PPAdoptLang("community_details_message")) {
            VStack(spacing: 12) {
                DatePicker(PPAdoptLang(kind == .missing ? "community_lost_at" : "community_found_at"), selection: $store.eventDate, in: ...Date())
                    .font(CommunityFont.medium(14))
                TextEditor(text: $store.descriptionText)
                    .font(CommunityFont.regular(15))
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(PPAdoptLang("community_details_title"))
                if kind == .missing {
                    CommunityField(title: PPAdoptLang("community_wearing"), text: $store.wearing)
                    Toggle(PPAdoptLang("community_reward"), isOn: $store.rewardOffered).font(CommunityFont.medium(14))
                } else {
                    Picker(PPAdoptLang("community_custody"), selection: $store.custodyStatus) {
                        Text(PPAdoptLang("community_custody_with_me")).tag("with_reporter")
                        Text(PPAdoptLang("community_custody_safe_place")).tag("safe_location")
                        Text(PPAdoptLang("community_custody_unknown")).tag("unknown")
                    }.pickerStyle(.segmented)
                }
            }
        }
    }

    private var locationCard: some View {
        CommunityFormCard(symbol: "location.fill", tint: CommunityPalette.missing, title: PPAdoptLang("community_location_title"), message: PPAdoptLang("community_location_privacy")) {
            VStack(spacing: 12) {
                HStack { CommunityField(title: PPAdoptLang("City"), text: $store.city); CommunityField(title: PPAdoptLang("community_district"), text: $store.district) }
                Button { location.request() } label: {
                    Label(locationTitle, systemImage: location.coordinate == nil ? "location" : "checkmark.circle.fill")
                        .font(CommunityFont.bold(15)).foregroundStyle(location.coordinate == nil ? CommunityPalette.missing : CommunityPalette.safe)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(CommunityPressStyle())
            }
        }
    }

    private var locationTitle: String {
        switch location.state {
        case .idle: return PPAdoptLang("community_use_current_location")
        case .requesting: return PPAdoptLang("community_location_requesting")
        case .ready: return PPAdoptLang("community_location_ready")
        case .denied: return PPAdoptLang("community_location_denied")
        case .failed: return PPAdoptLang("community_location_failed")
        }
    }

    private var mediaCard: some View {
        CommunityFormCard(symbol: "photo.stack.fill", tint: .indigo, title: PPAdoptLang("community_media_title"), message: PPAdoptLang("community_media_privacy")) {
            VStack(spacing: 10) {
                HStack {
                    Text(String(format: PPAdoptLang("community_media_count"), store.media.count, 8)).font(CommunityFont.medium(13)).foregroundStyle(Color.ppTextSecondary)
                    Spacer()
                    Button(PPAdoptLang("community_add_media")) { showsMediaPicker = true }
                        .font(CommunityFont.bold(14)).disabled(store.media.count >= 8)
                }
                if !store.media.isEmpty {
                    HStack { Image(systemName: "checkmark.shield.fill").foregroundStyle(CommunityPalette.safe); Text(PPAdoptLang("community_media_selected")).font(CommunityFont.regular(13)); Spacer() }
                }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Text(message).font(CommunityFont.medium(14)).foregroundStyle(Color.red).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var submitButton: some View {
        Button { Task { await store.submit(coordinate: location.coordinate) } } label: {
            Text(PPAdoptLang("community_submit_for_review"))
                .font(CommunityFont.bold(17, relativeTo: .headline)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(kind == .missing ? CommunityPalette.missing : CommunityPalette.found, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(CommunityPressStyle())
        .disabled(!store.canSubmit || location.coordinate == nil || store.submitting)
        .accessibilityHint(PPAdoptLang("community_submit_review_hint"))
    }
}

private struct CommunityFormCard<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let content: Content

    init(symbol: String, tint: Color, title: String, message: String, @ViewBuilder content: () -> Content) {
        self.symbol = symbol; self.tint = tint; self.title = title; self.message = message; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint).frame(width: 38, height: 38).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CommunityFont.bold(17, relativeTo: .headline)).foregroundStyle(Color.ppTextPrimary)
                    Text(message).font(CommunityFont.regular(12, relativeTo: .caption)).foregroundStyle(Color.ppTextSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            content
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
    }
}

private struct CommunityField: View {
    let title: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(CommunityFont.medium(12, relativeTo: .caption)).foregroundStyle(Color.ppTextSecondary)
            TextField(title, text: $text)
                .font(CommunityFont.regular(15))
                .padding(.horizontal, 12)
                .frame(minHeight: 45)
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CommunityMediaPicker: UIViewControllerRepresentable {
    let maximumCount: Int
    let completion: ([PPCommunityMediaSource]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = min(max(maximumCount, 1), 8)
        config.filter = .any(of: [.images, .videos])
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([PPCommunityMediaSource]) -> Void
        init(completion: @escaping ([PPCommunityMediaSource]) -> Void) { self.completion = completion }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { completion([]); return }
            let group = DispatchGroup()
            let lock = NSLock()
            var indexed: [(Int, PPCommunityMediaSource)] = []
            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                group.enter()
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage, let source = try? PPCommunityMediaSource(image: image) {
                            lock.lock(); indexed.append((index, source)); lock.unlock()
                        }
                        group.leave()
                    }
                } else {
                    let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.quickTimeMovie.identifier) ? UTType.quickTimeMovie.identifier : UTType.movie.identifier
                    provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                        if let url, let data = try? Data(contentsOf: url),
                           let source = try? PPCommunityMediaSource(data: data, contentType: typeIdentifier == UTType.quickTimeMovie.identifier ? "video/quicktime" : "video/mp4") {
                            lock.lock(); indexed.append((index, source)); lock.unlock()
                        }
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) { self.completion(indexed.sorted { $0.0 < $1.0 }.map(\.1)) }
        }
    }
}

@MainActor
private final class CommunityDetailStore: ObservableObject {
    @Published var item: [String: Any]
    @Published var loading = false
    @Published var actionInProgress = false
    @Published var errorMessage: String?
    @Published var showsSighting = false
    @Published var showsShare = false
    let kind: CommunityCaseKind

    init(item: [String: Any], kind: CommunityCaseKind) { self.item = item; self.kind = kind }

    func reload() async {
        let id = communityID(item)
        guard !id.isEmpty else { return }
        loading = true
        do { item = try await PPCommunityService.shared.detail(action: kind == .missing ? "missing_detail" : "found_detail", id: id) }
        catch { errorMessage = error.localizedDescription }
        loading = false
    }

    func confirmReunion() async {
        guard kind == .missing else { return }
        actionInProgress = true
        do {
            let result = try await PPCommunityService.shared.transition("confirmPetReunion", payload: [
                "caseId": communityID(item), "expectedVersion": communityInt(item["version"])
            ], prefix: "reunion")
            item["status"] = result["status"]
            item["version"] = result["version"]
        } catch { errorMessage = error.localizedDescription }
        actionInProgress = false
    }
}

private struct CommunityLostFoundDetailScreen: View {
    @StateObject private var store: CommunityDetailStore
    @State private var reportRequested = false
    @Environment(\.presentationMode) private var presentationMode
    let sightingsEnabled: Bool

    init(item: [String: Any], kind: CommunityCaseKind, sightingsEnabled: Bool) {
        _store = StateObject(wrappedValue: CommunityDetailStore(item: item, kind: kind))
        self.sightingsEnabled = sightingsEnabled
    }

    private var isOwner: Bool {
        let uid = UserManager.shared().currentUser?.id ?? ""
        return !uid.isEmpty && [communityString(store.item["ownerUid"]), communityString(store.item["reporterUid"])].contains(uid)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.ppBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    CommunityRemoteMedia(url: PPCommunityService.shared.primaryImageURL(in: store.item)).frame(height: 320).clipShape(RoundedRectangle(cornerRadius: 26))
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(communityTitle(store.item)).font(CommunityFont.bold(29, relativeTo: .largeTitle)).foregroundStyle(Color.ppTextPrimary)
                            Label(communityArea(store.item), systemImage: "mappin.and.ellipse").font(CommunityFont.medium(14)).foregroundStyle(Color.ppTextSecondary)
                        }
                        Spacer()
                        Button { store.showsShare = true } label: { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44).background(Color.ppSurface, in: Circle()) }.accessibilityLabel(PPAdoptLang("Share"))
                    }
                    Text(communityString(store.item["description"])).font(CommunityFont.regular(16, relativeTo: .body)).foregroundStyle(Color.ppTextPrimary).lineSpacing(4)
                    privacyCard
                    if let error = store.errorMessage { Text(error).font(CommunityFont.medium(14)).foregroundStyle(.red).padding(14).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)) }
                    Button { reportRequested = true } label: { Label(PPAdoptLang("community_report_content"), systemImage: "exclamationmark.bubble").font(CommunityFont.medium(14)).foregroundStyle(Color.ppTextSecondary) }
                    Spacer().frame(height: 90)
                }
                .frame(maxWidth: 760)
                .padding(18)
                .frame(maxWidth: .infinity)
            }
            actionDock
        }
        .navigationBarHidden(true)
        .task { await store.reload() }
        .sheet(isPresented: $store.showsSighting) { CommunitySightingFormScreen(caseID: communityID(store.item)) { store.showsSighting = false; Task { await store.reload() } } }
        .sheet(isPresented: $store.showsShare) { CommunityShareSheet(items: [communityTitle(store.item), communityArea(store.item), PPAdoptLang("community_share_privacy_note")]) }
        .sheet(isPresented: $reportRequested) { CommunityContentReportScreen(targetType: store.kind == .missing ? "missing_case" : "found_report", targetID: communityID(store.item)) { reportRequested = false } }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundStyle(CommunityPalette.safe)
            Text(PPAdoptLang("community_location_coarse_notice")).font(CommunityFont.regular(13)).foregroundStyle(Color.ppTextSecondary)
            Spacer()
        }.padding(14).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var actionDock: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button { presentationMode.wrappedValue.dismiss() } label: { Text(PPAdoptLang("Back")).font(CommunityFont.bold(15)).foregroundStyle(Color.ppTextPrimary).frame(maxWidth: .infinity, minHeight: 50).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 16)) }
                if store.kind == .missing && (isOwner || sightingsEnabled) {
                    Button {
                        guard UserManager.shared().isUserLoggedIn() else { UserManager.showPromptOnTopController(); return }
                        if isOwner { Task { await store.confirmReunion() } } else { store.showsSighting = true }
                    } label: {
                        Label(PPAdoptLang(isOwner ? "community_confirm_reunion" : "community_submit_sighting"), systemImage: isOwner ? "house.and.flag.fill" : "eye.fill")
                            .font(CommunityFont.bold(15)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50)
                            .background(isOwner ? CommunityPalette.safe : CommunityPalette.missing, in: RoundedRectangle(cornerRadius: 16))
                    }.disabled(store.actionInProgress)
                }
            }.padding(14).background(Color.ppElevatedSurface)
        }
    }
}

@MainActor
private final class CommunitySightingStore: ObservableObject {
    let caseID: String
    let sightingID = UUID().uuidString.lowercased()
    @Published var descriptionText = ""
    @Published var seenAt = Date()
    @Published var confidence = 0.7
    @Published var media: [PPCommunityMediaSource] = []
    @Published var submitting = false
    @Published var errorMessage: String?
    @Published var success = false
    init(caseID: String) { self.caseID = caseID }

    func submit(coordinate: CLLocationCoordinate2D?) async {
        guard let coordinate, !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = PPAdoptLang("community_location_required"); return }
        submitting = true
        do {
            var assetIDs: [String] = []
            if !media.isEmpty {
                assetIDs = try await PPCommunityService.shared.uploadMedia(media, contextType: "sighting", contextID: "\(caseID)~\(sightingID)").assetIDs
            }
            _ = try await PPCommunityService.shared.submitSighting(payload: [
                "caseId": caseID, "sightingId": sightingID,
                "seenAt": PPCommunityService.shared.isoString(seenAt),
                "location": ["latitude": coordinate.latitude, "longitude": coordinate.longitude],
                "description": descriptionText, "confidence": confidence,
                "mediaAssetIds": assetIDs
            ])
            success = true
        } catch { errorMessage = error.localizedDescription }
        submitting = false
    }
}

private struct CommunitySightingFormScreen: View {
    let onFinished: () -> Void
    @StateObject private var store: CommunitySightingStore
    @StateObject private var location = CommunityLocationProvider()
    @State private var picker = false
    @Environment(\.presentationMode) private var presentationMode
    init(caseID: String, onFinished: @escaping () -> Void) { self.onFinished = onFinished; _store = StateObject(wrappedValue: CommunitySightingStore(caseID: caseID)) }
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(PPAdoptLang("community_sighting_details"))) {
                    DatePicker(PPAdoptLang("community_seen_at"), selection: $store.seenAt, in: ...Date())
                    TextEditor(text: $store.descriptionText).frame(minHeight: 120).accessibilityLabel(PPAdoptLang("community_sighting_details"))
                    VStack(alignment: .leading) { Text(PPAdoptLang("community_confidence")); Slider(value: $store.confidence, in: 0...1, step: 0.1); Text(String(format: PPAdoptLang("community_confidence_value"), Int(store.confidence * 100))).font(CommunityFont.regular(12)).foregroundStyle(Color.ppTextSecondary) }
                }
                Section(header: Text(PPAdoptLang("community_location_title"))) {
                    Button { location.request() } label: { Label(location.coordinate == nil ? PPAdoptLang("community_use_current_location") : PPAdoptLang("community_location_ready"), systemImage: location.coordinate == nil ? "location" : "checkmark.circle.fill") }
                    Text(PPAdoptLang("community_location_privacy")).font(CommunityFont.regular(12)).foregroundStyle(Color.ppTextSecondary)
                }
                Section(header: Text(PPAdoptLang("community_media_title"))) {
                    Button(PPAdoptLang("community_add_optional_media")) { picker = true }.disabled(store.media.count >= 6)
                    if !store.media.isEmpty { Text(String(format: PPAdoptLang("community_media_count"), store.media.count, 6)) }
                }
                if let error = store.errorMessage { Section { Text(error).foregroundStyle(.red) } }
                Section { Button(PPAdoptLang("community_submit_sighting")) { Task { await store.submit(coordinate: location.coordinate) } }.disabled(store.submitting || location.coordinate == nil || store.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .navigationTitle(PPAdoptLang("community_submit_sighting"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() } } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: store.success) { if $0 { onFinished() } }
        .sheet(isPresented: $picker) { CommunityMediaPicker(maximumCount: max(1, 6 - store.media.count)) { store.media.append(contentsOf: $0.prefix(max(0, 6 - store.media.count))) } }
    }
}

@MainActor
private final class CommunityCollectionStore: ObservableObject {
    @Published var groups: [String: [[String: Any]]] = [:]
    @Published var items: [[String: Any]] = []
    @Published var loading = true
    @Published var errorMessage: String?
    func loadActivity() async { await load { self.groups = try await PPCommunityService.shared.activity() } }
    func loadSaved() async { await load { self.items = try await PPCommunityService.shared.savedItems() } }
    func loadOrganizations() async { await load { self.items = try await PPCommunityService.shared.organizations() } }
    private func load(operation: () async throws -> Void) async { loading = true; errorMessage = nil; do { try await operation() } catch { errorMessage = error.localizedDescription }; loading = false }
}

private struct CommunityActivityScreen: View {
    @StateObject private var store = CommunityCollectionStore()
    let messagingEnabled: Bool
    private let order = ["adoptionApplications", "adoptionListings", "missingCases", "foundReports", "sightings", "matches"]
    var body: some View {
        ZStack { Color.ppBackground.ignoresSafeArea(); VStack(spacing: 0) { CommunityScreenHeader(title: PPAdoptLang("community_activity_title"), subtitle: PPAdoptLang("community_activity_message")); content } }
            .navigationBarHidden(true).task { await store.loadActivity() }
    }
    @ViewBuilder private var content: some View {
        if store.loading { CommunityStateView(symbol: "clock", title: PPAdoptLang("community_loading_title"), message: PPAdoptLang("community_loading_message"), showsProgress: true) }
        else if let error = store.errorMessage { CommunityStateView(symbol: "exclamationmark.triangle", title: PPAdoptLang("community_error_title"), message: error, actionTitle: PPAdoptLang("Retry"), action: { Task { await store.loadActivity() } }) }
        else if store.groups.values.allSatisfy(\.isEmpty) { CommunityStateView(symbol: "tray", title: PPAdoptLang("community_activity_empty_title"), message: PPAdoptLang("community_activity_empty_message")) }
        else { ScrollView { LazyVStack(spacing: 18) { ForEach(order, id: \.self) { key in if let items = store.groups[key], !items.isEmpty { activitySection(key: key, items: items) } } }.frame(maxWidth: 820).padding(18).frame(maxWidth: .infinity) }.refreshable { await store.loadActivity() } }
    }
    private func activitySection(key: String, items: [[String: Any]]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PPAdoptLang("community_activity_\(key)")) .font(CommunityFont.bold(19, relativeTo: .headline)).foregroundStyle(Color.ppTextPrimary)
            ForEach(Array(items.enumerated()), id: \.offset) { pair in
                CommunityActivityRow(item: pair.element, group: key, messagingEnabled: messagingEnabled)
            }
        }
    }
}

private struct CommunityActivityRow: View {
    let item: [String: Any]
    let group: String
    let messagingEnabled: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint).frame(width: 42, height: 42).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) { Text(communityTitle(item)).font(CommunityFont.bold(16)).foregroundStyle(Color.ppTextPrimary); Text(communityStatus(item)).font(CommunityFont.regular(13)).foregroundStyle(Color.ppTextSecondary) }
            Spacer()
            if canMessage {
                Button { openChat() } label: { Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(tint).frame(width: 40, height: 40).background(tint.opacity(0.1), in: Circle()) }.accessibilityLabel(PPAdoptLang("community_safe_message"))
            }
        }
        .padding(14).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.ppBorder.opacity(0.6), lineWidth: 0.8) }
        .accessibilityElement(children: canMessage ? .contain : .combine)
    }
    private var symbol: String { group == "adoptionApplications" ? "doc.text.fill" : group == "matches" ? "sparkles" : group == "sightings" ? "eye.fill" : "pawprint.fill" }
    private var tint: Color { group == "matches" ? .purple : group == "sightings" ? CommunityPalette.missing : CommunityPalette.adoption }
    private var canMessage: Bool {
        guard messagingEnabled else { return false }
        let status = communityString(item["status"] ?? item["verificationStatus"])
        if group == "adoptionApplications" { return !["draft", "withdrawn", "rejected"].contains(status) }
        if group == "sightings" { return status != "rejected" }
        if group == "matches" { return ["likely_match", "confirmed"].contains(status) }
        return false
    }
    private func openChat() {
        let uid = UserManager.shared().currentUser?.id ?? ""
        let contextType: String
        let contextID: String
        let peer: String
        if group == "adoptionApplications" { contextType = "adoption_application"; contextID = communityString(item["id"] ?? item["applicationId"]); peer = communityString(item[communityString(item["applicantUid"]) == uid ? "listingOwnerUid" : "applicantUid"]) }
        else if group == "sightings" { contextType = "missing_sighting"; contextID = "\(communityString(item["caseId"]))~\(communityString(item["id"] ?? item["sightingId"]))"; peer = communityString(item[communityString(item["reporterUid"]) == uid ? "caseOwnerUid" : "reporterUid"]) }
        else { contextType = "found_match"; contextID = communityString(item["id"] ?? item["matchId"]); peer = communityString(item[communityString(item["missingOwnerUid"]) == uid ? "foundReporterUid" : "missingOwnerUid"]) }
        PPCommunityChatCoordinator.open(contextType: contextType, contextID: contextID, peerUID: peer)
    }
}

private struct CommunitySavedScreen: View {
    @StateObject private var store = CommunityCollectionStore()
    let sightingsEnabled: Bool
    var body: some View { ZStack { Color.ppBackground.ignoresSafeArea(); VStack(spacing: 0) { CommunityScreenHeader(title: PPAdoptLang("community_saved_title"), subtitle: PPAdoptLang("community_saved_message")); collectionContent } }.navigationBarHidden(true).task { await store.loadSaved() } }
    @ViewBuilder private var collectionContent: some View {
        if store.loading { CommunityStateView(symbol: "bookmark", title: PPAdoptLang("community_loading_title"), message: PPAdoptLang("community_loading_message"), showsProgress: true) }
        else if let error = store.errorMessage { CommunityStateView(symbol: "exclamationmark.triangle", title: PPAdoptLang("community_error_title"), message: error, actionTitle: PPAdoptLang("Retry"), action: { Task { await store.loadSaved() } }) }
        else if store.items.isEmpty { CommunityStateView(symbol: "bookmark", title: PPAdoptLang("community_saved_empty_title"), message: PPAdoptLang("community_saved_empty_message")) }
        else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(store.items.enumerated()), id: \.offset) { pair in
                        let wrapper = pair.element
                        CommunitySavedRow(wrapper: wrapper, sightingsEnabled: sightingsEnabled)
                    }
                }
                .frame(maxWidth: 760)
                .padding(18)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await store.loadSaved() }
        }
    }
}

private struct CommunitySavedRow: View {
    let wrapper: [String: Any]
    let sightingsEnabled: Bool

    private var item: [String: Any] { communityDictionary(wrapper["item"]) }
    private var targetType: String { communityString(wrapper["targetType"]) }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 13) {
                CommunityRemoteMedia(url: PPCommunityService.shared.primaryImageURL(in: item))
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(communityTitle(item))
                        .font(CommunityFont.bold(17, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                    Text(PPAdoptLang("community_saved_type_\(targetType)"))
                        .font(CommunityFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(tint)
                    Label(communityArea(item), systemImage: "mappin.and.ellipse")
                        .font(CommunityFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.ppTextTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(12)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color.ppBorder.opacity(0.6), lineWidth: 0.8) }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(CommunityPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var destination: some View {
        if targetType == "adoption_listing" {
            AdoptPetDetailsScreen(
                pet: AdoptPetModel(dictionary: item, documentID: communityID(item)),
                hostViewControllerProvider: { nil }
            )
        } else {
            CommunityLostFoundDetailScreen(
                item: item,
                kind: targetType == "found_report" ? .found : .missing,
                sightingsEnabled: sightingsEnabled
            )
        }
    }

    private var tint: Color {
        switch targetType {
        case "missing_case": return CommunityPalette.missing
        case "found_report": return CommunityPalette.found
        default: return CommunityPalette.adoption
        }
    }
}

private struct CommunityOrganizationsScreen: View {
    @StateObject private var store = CommunityCollectionStore()
    var body: some View { ZStack { Color.ppBackground.ignoresSafeArea(); VStack(spacing: 0) { CommunityScreenHeader(title: PPAdoptLang("community_organizations_title"), subtitle: PPAdoptLang("community_organizations_message")); content } }.navigationBarHidden(true).task { await store.loadOrganizations() } }
    @ViewBuilder private var content: some View {
        if store.loading { CommunityStateView(symbol: "checkmark.seal", title: PPAdoptLang("community_loading_title"), message: PPAdoptLang("community_loading_message"), showsProgress: true) }
        else if let error = store.errorMessage { CommunityStateView(symbol: "exclamationmark.triangle", title: PPAdoptLang("community_error_title"), message: error, actionTitle: PPAdoptLang("Retry"), action: { Task { await store.loadOrganizations() } }) }
        else if store.items.isEmpty { CommunityStateView(symbol: "building.2", title: PPAdoptLang("community_organizations_empty_title"), message: PPAdoptLang("community_organizations_empty_message")) }
        else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(Array(store.items.enumerated()), id: \.offset) { pair in
                        CommunityOrganizationCard(item: pair.element)
                    }
                }
                .frame(maxWidth: 900)
                .padding(18)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct CommunityOrganizationCard: View {
    let item: [String: Any]
    var body: some View { VStack(alignment: .leading, spacing: 10) { HStack { Image(systemName: "checkmark.seal.fill").foregroundStyle(CommunityPalette.safe); Text(communityString(item["name"])).font(CommunityFont.bold(19)).foregroundStyle(Color.ppTextPrimary); Spacer() }; Text(communityString(item["description"])).font(CommunityFont.regular(14)).foregroundStyle(Color.ppTextSecondary).lineLimit(4); Label(communityArea(item), systemImage: "mappin.and.ellipse").font(CommunityFont.medium(13)).foregroundStyle(Color.ppTextSecondary) }.padding(18).frame(maxWidth: .infinity, minHeight: 155, alignment: .topLeading).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22)).overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.6), lineWidth: 0.8) }.accessibilityElement(children: .combine) }
}

private struct CommunityContentReportScreen: View {
    let targetType: String
    let targetID: String
    let onFinished: () -> Void
    @State private var reason = "incorrect_information"
    @State private var details = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) private var presentationMode
    private let reasons = ["incorrect_information", "animal_welfare_concern", "stolen_pet", "fraud", "spam", "inappropriate_media", "dangerous_interaction", "impersonation"]
    var body: some View { NavigationView { Form { Picker(PPAdoptLang("community_report_reason"), selection: $reason) { ForEach(reasons, id: \.self) { Text(PPAdoptLang("community_report_reason_\($0)")).tag($0) } }; Section(header: Text(PPAdoptLang("community_report_details"))) { TextEditor(text: $details).frame(minHeight: 120) }; if let errorMessage { Text(errorMessage).foregroundStyle(.red) }; Button(PPAdoptLang("community_report_submit")) { Task { await submit() } }.disabled(details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting) }.navigationTitle(PPAdoptLang("community_report_content")).toolbar { ToolbarItem(placement: .cancellationAction) { Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() } } } }.navigationViewStyle(StackNavigationViewStyle()) }
    private func submit() async { submitting = true; do { try await PPCommunityService.shared.report(targetType: targetType, targetID: targetID, reason: reason, details: details); onFinished() } catch { errorMessage = error.localizedDescription }; submitting = false }
}

private struct CommunityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
final class PPCommunityChatCoordinator {
    static func open(contextType: String, contextID: String, peerUID: String) {
        guard !contextType.isEmpty, !contextID.isEmpty, !peerUID.isEmpty else { return }
        let presenter = AppManager.sharedInstance().topViewController()
        UserManager.shared().getOtherUserModelFromFirestore(withUID: peerUID) { user, _ in
            guard let user else { return }
            ChManager.shared().createOrGetChatThread(withUser: user, contextType: contextType, contextID: contextID) { thread, _ in
                guard let thread else { return }
                PPOverlayCoordinator.pp_openChatThread(thread, fromVC: presenter)
            }
        }
    }
}

@MainActor
final class PPAdoptionApplicationStore: ObservableObject {
    static let multipleAnswerSeparator = "\u{001F}"
    let listing: AdoptPetModel
    @Published var message = ""
    @Published var householdType = ""
    @Published var householdMembers = ""
    @Published var children = ""
    @Published var existingPets = ""
    @Published var petExperience = ""
    @Published var housingPermission = ""
    @Published var dailyRoutine = ""
    @Published var carePlan = ""
    @Published var questions: [PPCommunityQuestion] = []
    @Published var questionAnswers: [String: String] = [:]
    @Published var loadingQuestions = true
    @Published var configurationError: String?
    @Published var version = 0
    @Published var submitting = false
    @Published var errorMessage: String?
    @Published var success = false
    init(listing: AdoptPetModel) { self.listing = listing }
    var answers: [String: String] { ["householdType": householdType, "householdMembers": householdMembers, "children": children, "existingPets": existingPets, "petExperience": petExperience, "housingPermission": housingPermission, "dailyRoutine": dailyRoutine, "carePlan": carePlan, "preferredContact": "in_app"] }
    var configuredAnswersPayload: [String: Any] {
        var pairs: [(String, Any)] = []
        for question in questions {
            let value = questionAnswers[question.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if question.type == "multiple_choice" {
                pairs.append((question.id, value.components(separatedBy: Self.multipleAnswerSeparator).filter { !$0.isEmpty }))
            } else {
                pairs.append((question.id, value))
            }
        }
        return Dictionary(uniqueKeysWithValues: pairs)
    }
    var complete: Bool {
        guard !loadingQuestions, configurationError == nil,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [householdType, petExperience, housingPermission, carePlan].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return false }
        return questions.filter(\.required).allSatisfy {
            !questionAnswers[$0.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    func loadQuestions() async {
        loadingQuestions = true
        configurationError = nil
        do {
            let configuration = try await PPCommunityService.shared.configuration()
            guard configuration.communityEnabled, configuration.adoptionApplicationsEnabled else {
                throw PPCommunityError.featureUnavailable
            }
            questions = configuration.adoptionQuestions
        } catch {
            configurationError = error.localizedDescription
        }
        loadingQuestions = false
    }
    func saveDraft() async {
        guard !loadingQuestions, configurationError == nil else { return }
        await perform {
            try await PPCommunityService.shared.saveAdoptionApplicationDraft(
                listingID: listing.documentID,
                expectedVersion: version,
                message: message,
                answers: answers,
                questionAnswers: configuredAnswersPayload
            )
        }
    }
    func submit() async {
        guard complete else { errorMessage = PPAdoptLang("community_application_required"); return }
        await perform {
            try await PPCommunityService.shared.submitAdoptionApplication(
                listingID: listing.documentID,
                expectedVersion: version,
                message: message,
                answers: answers,
                questionAnswers: configuredAnswersPayload
            )
        }
        if errorMessage == nil { success = true }
    }
    private func perform(_ operation: () async throws -> [String: Any]) async { submitting = true; errorMessage = nil; do { let result = try await operation(); version = communityInt(result["version"], fallback: version) } catch { errorMessage = error.localizedDescription }; submitting = false }
}

struct PPAdoptionApplicationScreen: View {
    @StateObject private var store: PPAdoptionApplicationStore
    let onFinished: () -> Void
    @Environment(\.presentationMode) private var presentationMode
    init(listing: AdoptPetModel, onFinished: @escaping () -> Void) { _store = StateObject(wrappedValue: PPAdoptionApplicationStore(listing: listing)); self.onFinished = onFinished }
    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        CommunityFormCard(symbol: "heart.text.square.fill", tint: CommunityPalette.adoption, title: PPAdoptLang("community_application_title"), message: String(format: PPAdoptLang("community_application_for"), store.listing.name)) { EmptyView() }
                        applicationFields
                        configuredQuestions
                        if let error = store.errorMessage {
                            Text(error).font(CommunityFont.medium(14)).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                        actions
                    }
                    .frame(maxWidth: 760)
                    .padding(18)
                }
            }
            .navigationTitle(PPAdoptLang("community_application_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() } } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task { await store.loadQuestions() }
        .onChange(of: store.success) { if $0 { onFinished() } }
    }
    private var applicationFields: some View { VStack(spacing: 14) { CommunityField(title: PPAdoptLang("community_application_message"), text: $store.message); CommunityField(title: PPAdoptLang("community_household_type"), text: $store.householdType); CommunityField(title: PPAdoptLang("community_household_members"), text: $store.householdMembers); CommunityField(title: PPAdoptLang("community_children"), text: $store.children); CommunityField(title: PPAdoptLang("community_existing_pets"), text: $store.existingPets); CommunityField(title: PPAdoptLang("community_pet_experience"), text: $store.petExperience); CommunityField(title: PPAdoptLang("community_housing_permission"), text: $store.housingPermission); CommunityField(title: PPAdoptLang("community_daily_routine"), text: $store.dailyRoutine); CommunityField(title: PPAdoptLang("community_care_plan"), text: $store.carePlan) }.padding(18).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22)).overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.6), lineWidth: 0.8) } }
    @ViewBuilder private var configuredQuestions: some View {
        if store.loadingQuestions {
            HStack(spacing: 10) {
                ProgressView()
                Text(PPAdoptLang("community_application_questions_loading")).font(CommunityFont.medium(14)).foregroundStyle(Color.ppTextSecondary)
                Spacer()
            }
            .padding(18)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22))
        } else if let error = store.configurationError {
            CommunityStateView(symbol: "arrow.clockwise.circle", title: PPAdoptLang("community_application_questions_error_title"), message: error, actionTitle: PPAdoptLang("Retry"), action: { Task { await store.loadQuestions() } })
        } else if !store.questions.isEmpty {
            CommunityFormCard(symbol: "checklist", tint: CommunityPalette.adoption, title: PPAdoptLang("community_application_questions_title"), message: PPAdoptLang("community_application_questions_message")) {
                VStack(spacing: 16) {
                    ForEach(store.questions) { question in
                        CommunityConfiguredQuestionField(
                            question: question,
                            answer: Binding(
                                get: { store.questionAnswers[question.id, default: ""] },
                                set: { store.questionAnswers[question.id] = $0 }
                            )
                        )
                    }
                }
            }
        }
    }
    private var actions: some View {
        HStack(spacing: 10) { actionButtons }
            .buttonStyle(CommunityPressStyle())
            .disabled(store.submitting || store.loadingQuestions || store.configurationError != nil)
    }
    @ViewBuilder private var actionButtons: some View {
        Button { Task { await store.saveDraft() } } label: { Text(PPAdoptLang("community_save_draft")).font(CommunityFont.bold(15)).foregroundStyle(Color.ppTextPrimary).frame(maxWidth: .infinity, minHeight: 52).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 16)) }
        Button { Task { await store.submit() } } label: { Text(PPAdoptLang("community_submit_application")).font(CommunityFont.bold(15)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 52).background(CommunityPalette.adoption, in: RoundedRectangle(cornerRadius: 16)) }.disabled(!store.complete)
    }
}

private struct CommunityConfiguredQuestionField: View {
    let question: PPCommunityQuestion
    @Binding var answer: String

    private var title: String {
        question.required ? "\(question.localizedLabel) \(PPAdoptLang("community_required_marker"))" : question.localizedLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(CommunityFont.medium(13, relativeTo: .caption)).foregroundStyle(Color.ppTextSecondary)
            if question.type == "long_text" {
                TextEditor(text: $answer)
                    .font(CommunityFont.regular(15))
                    .frame(minHeight: 108)
                    .padding(8)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityLabel(title)
            } else if question.type == "yes_no" {
                choiceButton(id: "yes", label: PPAdoptLang("community_answer_yes"))
                choiceButton(id: "no", label: PPAdoptLang("community_answer_no"))
            } else if question.type == "single_choice" {
                ForEach(question.options) { option in choiceButton(id: option.id, label: option.localizedLabel) }
            } else if question.type == "multiple_choice" {
                ForEach(question.options) { option in multipleChoiceButton(option) }
            } else {
                TextField(question.localizedLabel, text: $answer)
                    .font(CommunityFont.regular(15))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 45)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityLabel(title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceButton(id: String, label: String) -> some View {
        Button { answer = id } label: {
            HStack(spacing: 10) {
                Image(systemName: answer == id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(answer == id ? CommunityPalette.adoption : Color.ppTextSecondary)
                    .accessibilityHidden(true)
                Text(label).font(CommunityFont.regular(15)).foregroundStyle(Color.ppTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(answer == id ? CommunityPalette.adoption.opacity(0.1) : Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(CommunityPressStyle())
        .accessibilityAddTraits(answer == id ? .isSelected : [])
    }

    private func multipleChoiceButton(_ option: PPCommunityQuestionOption) -> some View {
        let selected = Set(answer.components(separatedBy: PPAdoptionApplicationStore.multipleAnswerSeparator).filter { !$0.isEmpty })
        let isSelected = selected.contains(option.id)
        return Button {
            var next = selected
            if isSelected { next.remove(option.id) } else { next.insert(option.id) }
            answer = question.options.map(\.id).filter(next.contains).joined(separator: PPAdoptionApplicationStore.multipleAnswerSeparator)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? CommunityPalette.adoption : Color.ppTextSecondary)
                    .accessibilityHidden(true)
                Text(option.localizedLabel).font(CommunityFont.regular(15)).foregroundStyle(Color.ppTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(isSelected ? CommunityPalette.adoption.opacity(0.1) : Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(CommunityPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

@objc(PPCommunityViewController)
final class PPCommunityViewController: UIViewController {
    private var hosting: UIHostingController<PPCommunityGatewayScreen>?
    @objc var initialRoute: String = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        weak var weakSelf = self
        let screen = PPCommunityGatewayScreen(
            onSelectAdoption: { weakSelf?.openDetails($0) },
            onCreateAdoption: { weakSelf?.openCreateAdoption() },
            onClose: { weakSelf?.close() },
            initialRoute: initialRoute
        )
        let host = UIHostingController(rootView: screen)
        hosting = host; addChild(host); host.view.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(host.view)
        NSLayoutConstraint.activate([host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        host.didMove(toParent: self)
        hidesBottomBarWhenPushed = true
    }
    private func openDetails(_ pet: AdoptPetModel) { let controller = AdoptPetDetailsViewController(model: pet); if let nav = navigationController { nav.pushViewController(controller, animated: true) } else { controller.modalPresentationStyle = .fullScreen; present(controller, animated: true) } }
    private func openCreateAdoption() { guard UserManager.shared().isUserLoggedIn() else { UserManager.showPromptOnTopController(); return }; let controller = AddAdoptPetHostingController(pet: nil, onDismiss: nil, onSuccess: nil); controller.modalPresentationStyle = .fullScreen; present(controller, animated: true) }
    private func close() { if let nav = navigationController, nav.viewControllers.first != self { nav.popViewController(animated: true) } else { dismiss(animated: true) } }
}

@objc(PPAdoptionApplicationHostingController)
final class PPAdoptionApplicationHostingController: UIViewController {
    private let listing: AdoptPetModel
    private var hosting: UIHostingController<PPAdoptionApplicationScreen>?
    @objc(initWithListing:) init(listing: AdoptPetModel) { self.listing = listing; super.init(nibName: nil, bundle: nil); modalPresentationStyle = .pageSheet }
    required init?(coder: NSCoder) { return nil }
    override func viewDidLoad() { super.viewDidLoad(); weak var weakSelf = self; let host = UIHostingController(rootView: PPAdoptionApplicationScreen(listing: listing) { weakSelf?.dismiss(animated: true) }); hosting = host; addChild(host); host.view.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(host.view); NSLayoutConstraint.activate([host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)]); host.didMove(toParent: self) }
}
