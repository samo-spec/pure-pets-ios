//
//  PPCommunityScreens.swift
//  Pure Pets
//
//  Customer Community gateway, Adoption applications, Missing/Found reports,
//  sightings, activity, safe messaging entry points, and responsive states.
//

import CoreLocation
import PhotosUI
import Security
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

/// Community reports can contain sensitive identity and location details.
/// Pending report state therefore lives in the device-only Keychain rather
/// than UserDefaults; exact coordinates are never copied into application
/// preferences or analytics.
private enum CommunityDraftVault {
    private static let service = "com.purepets.community.pending-drafts.v1"

    static func dictionary(for account: String) -> [String: Any]? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = try? JSONSerialization.jsonObject(with: data),
              let dictionary = value as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    static func save(_ value: [String: Any], for account: String) {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return
        }
        let identity: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributesToUpdate: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(identity as CFDictionary, attributesToUpdate as CFDictionary)
        // Do not delete a recoverable private draft before proving that a new
        // Keychain write can succeed. This matters when storage is transiently
        // unavailable or the device has just changed lock state.
        guard updateStatus == errSecItemNotFound else { return }
        var insert = identity
        insert[kSecValueData] = data
        insert[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    static func remove(_ account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
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

private func communityString(_ value: Any?, fallback: String = "") -> String {
    let string = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return string.isEmpty ? fallback : string
}

private func communityInt(_ value: Any?, fallback: Int = 0) -> Int {
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String, let number = Int(string) { return number }
    return fallback
}

private func communityDouble(_ value: Any?, fallback: Double = 0) -> Double {
    if let number = value as? NSNumber { return number.doubleValue }
    if let number = value as? Double { return number }
    if let string = value as? String, let number = Double(string) { return number }
    return fallback
}

private func communityCoordinate(from payload: [String: Any]) -> CLLocationCoordinate2D? {
    let location = communityDictionary(payload["location"])
    let latitude = communityDouble(location["latitude"], fallback: .nan)
    let longitude = communityDouble(location["longitude"], fallback: .nan)
    guard latitude.isFinite, longitude.isFinite,
          (-90...90).contains(latitude), (-180...180).contains(longitude) else {
        return nil
    }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
}

/// Preserves server-issued asset order while dropping malformed or duplicate
/// identifiers. Ordering is part of the submit payload: the first item can be
/// used as the cover, and changing it on a network retry would change the
/// durable command fingerprint.
private func communityOrderedUniqueStrings(_ values: [String], maximum: Int) -> [String] {
    guard maximum > 0 else { return [] }
    var seen = Set<String>()
    var result: [String] = []
    for rawValue in values {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, seen.insert(value).inserted else { continue }
        result.append(value)
        if result.count == maximum { break }
    }
    return result
}

private func communityID(_ item: [String: Any]) -> String {
    communityString(item["id"] ?? item["listingId"] ?? item["caseId"] ?? item["reportId"] ?? item["applicationId"] ?? item["matchId"])
}

private func communityTitle(_ item: [String: Any]) -> String {
    let pet = communityDictionary(item["pet"])
    let profile = communityDictionary(item["profile"])
    for candidate in [pet["name"], profile["name"], item["petName"], item["title"]] {
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
        } else if store.configuration?.communityEnabled != true || store.configuration?.rolloutAvailable != true {
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
                .fixedSize(horizontal: false, vertical: true)
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
                Text(subtitle)
                    .font(CommunityFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommunityRemoteMedia(url: PPCommunityService.shared.primaryImageURL(in: item))
                .frame(height: 190)
            VStack(alignment: .leading, spacing: 9) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        recordTitle
                        recordStatus
                    }
                } else {
                    HStack(alignment: .top) {
                        recordTitle
                        Spacer()
                        recordStatus
                    }
                }
                Label(communityArea(item), systemImage: "mappin.and.ellipse")
                    .font(CommunityFont.medium(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                Text(communityString(item["description"]))
                    .font(CommunityFont.regular(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
            .padding(16)
        }
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 23).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var recordTitle: some View {
        Text(communityTitle(item))
            .font(CommunityFont.bold(20, relativeTo: .headline))
            .foregroundStyle(Color.ppTextPrimary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
    }

    private var recordStatus: some View {
        Text(communityStatus(item))
            .font(CommunityFont.bold(11, relativeTo: .caption))
            .foregroundStyle(kind == .missing ? CommunityPalette.missing : CommunityPalette.found)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background((kind == .missing ? CommunityPalette.missing : CommunityPalette.found).opacity(0.12), in: Capsule())
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

// MARK: - Community Haptics & Media Extension

private enum CommunityHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

private extension PPCommunityMediaSource {
    var previewImage: UIImage? {
        if contentType.contains("image"), let img = UIImage(data: data) {
            return img
        }
        return nil
    }
    var isVideo: Bool {
        contentType.contains("video")
    }
}

private struct CommunitySpeciesQuickOption: Identifiable {
    let id: String
    let symbol: String
    let nameAr: String
    let nameEn: String

    var localizedName: String {
        Language.isRTL() ? nameAr : nameEn
    }
}

private struct CommunityColorOption: Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let color: Color
    let isLight: Bool

    var localizedName: String {
        Language.isRTL() ? nameAr : nameEn
    }
}

private struct CommunityCustodyOption: Identifiable {
    let id: String
    let symbol: String
    let tint: Color
    let titleKey: String
    let descKey: String
}

private enum CommunityFormSheetType: Identifiable {
    case media
    case city
    case district
    case species
    case breed

    var id: String {
        switch self {
        case .media: return "media"
        case .city: return "city"
        case .district: return "district"
        case .species: return "species"
        case .breed: return "breed"
        }
    }
}

@MainActor
private final class CommunityCaseFormStore: ObservableObject {
    let kind: CommunityCaseKind
    private(set) var recordID: String
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
    @Published var microchipped = false
    @Published var microchipID = ""
    @Published var ringTag = ""
    @Published var city = ""
    @Published var district = ""
    @Published var eventDate = Date()
    @Published var rewardOffered = false
    @Published var custodyStatus = "unknown"
    @Published var media: [PPCommunityMediaSource] = []
    @Published private(set) var uploadedMediaAssetIDs: [String] = []
    @Published var loadingPets = false
    @Published var submitting = false
    @Published var errorMessage: String?
    @Published var success = false

    // Domain models & sync
    @Published var availableKinds: [MainKindsModel] = []
    @Published var availableCities: [CityModel] = []
    @Published var selectedKind: MainKindsModel? = nil
    @Published var selectedBreed: SubKindModel? = nil
    @Published var selectedCityModel: CityModel? = nil
    @Published var selectedAreaModel: StateModel? = nil
    @Published var selectedColors: Set<String> = []

    private let draftOwnerUID: String
    private let draftPersistenceEnabled: Bool
    private var pendingCoordinate: CLLocationCoordinate2D?
    private var submissionPayloadLocked = false
    // A stable record ID by itself does not make a create retry idempotent: a
    // changed field produces a different command fingerprint. Keep the exact
    // serializable request body once a create is about to leave the device.
    private var lockedSubmissionPayload: [String: Any]?

    private var draftKey: String {
        "case-form.\(kind.rawValue).\(draftOwnerUID)"
    }

    init(kind: CommunityCaseKind) {
        self.kind = kind
        let currentUID = communityString(UserManager.shared().currentUser?.id)
        self.draftOwnerUID = currentUID.isEmpty ? UUID().uuidString.lowercased() : currentUID
        self.draftPersistenceEnabled = !currentUID.isEmpty
        self.recordID = UUID().uuidString.lowercased()
        restoreDraft()
        loadDomainData()
    }

    func loadPets() {
        guard kind == .missing else { return }
        loadingPets = true
        UserManager.shared().fetchPetProfilesForCurrentUser { [weak self] pets, error in
            Task { @MainActor in
                guard let self else { return }
                self.loadingPets = false
                self.pets = pets ?? []
                if self.selectedPetID.isEmpty, let firstPet = self.pets.first {
                    self.selectPetProfile(firstPet)
                }
                if let error { self.errorMessage = error.localizedDescription }
            }
        }
    }

    func selectPetProfile(_ pet: PPPetProfile) {
        selectedPetID = pet.petID
        if let cat = pet.categoryName, !cat.isEmpty { species = cat }
        if let br = pet.breed, !br.isEmpty { breed = br }
    }

    // MARK: - Domain Data

    func loadDomainData() {
        refreshKinds()
        refreshCities()
        if availableCities.isEmpty {
            CitiesManager.shared().loadData()
        }
        syncDomainModelsFromCurrentStrings()
    }

    func refreshKinds() {
        let kinds = (MainKindsArrayManager.shared().visibleMainKindsSnapshot() as? [MainKindsModel])
            ?? (MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel])
            ?? []
        self.availableKinds = kinds
    }

    func refreshCities() {
        let cities = (CitiesManager.shared().citiesForCurrentCountry() as? [CityModel])
            ?? (CitiesManager.shared().qatarCountry()?.cities as? [CityModel])
            ?? []
        self.availableCities = cities
    }

    var availableBreeds: [SubKindModel] {
        guard let kind = selectedKind else { return [] }
        let fromKind = (kind.subKindsArray as? [SubKindModel]) ?? []
        if !fromKind.isEmpty { return fromKind }
        return (MainKindsArrayManager.shared().getSubKindArray(kind.id) as? [SubKindModel]) ?? []
    }

    var availableAreas: [StateModel] {
        guard let city = selectedCityModel else { return [] }
        return (city.states as? [StateModel]) ?? []
    }

    func selectKind(_ kindModel: MainKindsModel?) {
        self.selectedKind = kindModel
        if let km = kindModel {
            self.species = km.localizedName
        }
        self.selectedBreed = nil
        self.breed = ""
    }

    func selectBreed(_ breedModel: SubKindModel?) {
        self.selectedBreed = breedModel
        if let bm = breedModel {
            self.breed = bm.localizedName
        }
    }

    func selectCityModel(_ cityModel: CityModel?) {
        self.selectedCityModel = cityModel
        if let cm = cityModel {
            self.city = cm.localizedName
        }
        self.selectedAreaModel = nil
        self.district = ""
    }

    func selectAreaModel(_ areaModel: StateModel?) {
        self.selectedAreaModel = areaModel
        if let am = areaModel {
            self.district = am.localizedName
        }
    }

    func toggleColor(_ colorName: String) {
        if selectedColors.contains(colorName) {
            selectedColors.remove(colorName)
        } else {
            selectedColors.insert(colorName)
        }
        colors = selectedColors.sorted().joined(separator: ", ")
    }

    func removeMedia(at index: Int) {
        guard index >= 0 && index < media.count else { return }
        media.remove(at: index)
    }

    func removeUploadedMedia(at index: Int) {
        guard index >= 0 && index < uploadedMediaAssetIDs.count else { return }
        uploadedMediaAssetIDs.remove(at: index)
    }

    func readinessPercentage(_ liveCoordinate: CLLocationCoordinate2D?) -> Int {
        var score = 0
        if mediaAttachmentCount > 0 { score += 30 }
        let hasSpecies = kind == .missing ? !selectedPetID.isEmpty : !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSpecies { score += 25 }
        if submissionLocationIsAvailable(liveCoordinate) { score += 15 }
        if !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 15 }
        if !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 15 }
        return min(100, score)
    }

    func missingFieldNotice(_ liveCoordinate: CLLocationCoordinate2D?) -> String? {
        if mediaAttachmentCount == 0 {
            return PPAdoptLang("community_readiness_needs_media")
        }
        let hasSpecies = kind == .missing ? !selectedPetID.isEmpty : !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasSpecies {
            return PPAdoptLang("community_readiness_needs_species")
        }
        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PPAdoptLang("community_readiness_needs_city")
        }
        if !submissionLocationIsAvailable(liveCoordinate) {
            return PPAdoptLang("community_location_required")
        }
        if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PPAdoptLang("community_readiness_needs_details")
        }
        return nil
    }

    func syncDomainModelsFromCurrentStrings() {
        if !species.isEmpty && selectedKind == nil {
            selectedKind = availableKinds.first(where: {
                $0.localizedName == species || $0.kindName == species || $0.kindNameAr == species || $0.kindNameEn == species
            })
        }
        if !city.isEmpty && selectedCityModel == nil {
            selectedCityModel = availableCities.first(where: {
                $0.localizedName == city || $0.name == city
            })
        }
        if let selectedCityModel, !district.isEmpty, selectedAreaModel == nil {
            selectedAreaModel = (selectedCityModel.states as? [StateModel])?.first(where: {
                $0.localizedName == district || $0.arName == district || $0.enName == district
            })
        }
        if !colors.isEmpty && selectedColors.isEmpty {
            let splitColors = colors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            selectedColors = Set(splitColors)
        }
    }

    var canSubmit: Bool {
        if lockedSubmissionPayload != nil { return true }
        let common = !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mediaAttachmentCount > 0
        if kind == .missing { return common && !selectedPetID.isEmpty }
        return common && !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var mediaAttachmentCount: Int { min(8, uploadedMediaAssetIDs.count + media.count) }
    var restoredCoordinate: CLLocationCoordinate2D? { pendingCoordinate }
    func submissionLocationIsAvailable(_ liveCoordinate: CLLocationCoordinate2D?) -> Bool {
        coordinateForSubmission(liveCoordinate) != nil
    }

    private var activeSessionOwnsDraft: Bool {
        draftPersistenceEnabled && communityString(UserManager.shared().currentUser?.id) == draftOwnerUID
    }

    func coordinateForSubmission(_ liveCoordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        // Preserve the exact coordinate tied to a pending command until that
        // command reaches a receipt. A fresh location would otherwise change
        // the command fingerprint after an interrupted submission.
        if let lockedSubmissionPayload,
           let lockedCoordinate = communityCoordinate(from: lockedSubmissionPayload) {
            return lockedCoordinate
        }
        return submissionPayloadLocked ? (pendingCoordinate ?? liveCoordinate) : (liveCoordinate ?? pendingCoordinate)
    }

    func persistDraft(
        coordinate: CLLocationCoordinate2D? = nil,
        lockSubmissionPayload: Bool = false,
        submissionPayload: [String: Any]? = nil
    ) {
        guard draftPersistenceEnabled else { return }
        if let coordinate { pendingCoordinate = coordinate }
        if let submissionPayload,
           JSONSerialization.isValidJSONObject(submissionPayload) {
            lockedSubmissionPayload = submissionPayload
            submissionPayloadLocked = true
        } else if lockSubmissionPayload {
            submissionPayloadLocked = true
        }
        var payload: [String: Any] = [
            "recordID": recordID,
            "selectedPetID": selectedPetID,
            "species": species,
            "breed": breed,
            "sex": sex,
            "size": size,
            "colors": colors,
            "distinctiveMarks": distinctiveMarks,
            "descriptionText": descriptionText,
            "wearing": wearing,
            "microchipped": microchipped,
            "microchipID": microchipID,
            "ringTag": ringTag,
            "city": city,
            "district": district,
            "eventDate": eventDate.timeIntervalSince1970,
            "rewardOffered": rewardOffered,
            "custodyStatus": custodyStatus,
            "uploadedMediaAssetIDs": uploadedMediaAssetIDs,
            "submissionPayloadLocked": submissionPayloadLocked
        ]
        if let lockedSubmissionPayload {
            payload["lockedSubmissionPayload"] = lockedSubmissionPayload
        }
        if let coordinate = pendingCoordinate {
            payload["latitude"] = coordinate.latitude
            payload["longitude"] = coordinate.longitude
        }
        CommunityDraftVault.save(payload, for: draftKey)
    }

    private func restoreDraft() {
        guard draftPersistenceEnabled,
              let payload = CommunityDraftVault.dictionary(for: draftKey) else { return }
        let storedID = communityString(payload["recordID"])
        if !storedID.isEmpty { recordID = storedID }
        selectedPetID = communityString(payload["selectedPetID"])
        species = communityString(payload["species"])
        breed = communityString(payload["breed"])
        sex = communityString(payload["sex"])
        size = communityString(payload["size"])
        colors = communityString(payload["colors"])
        distinctiveMarks = communityString(payload["distinctiveMarks"])
        descriptionText = communityString(payload["descriptionText"])
        wearing = communityString(payload["wearing"])
        microchipped = payload["microchipped"] as? Bool ?? false
        microchipID = communityString(payload["microchipID"])
        ringTag = communityString(payload["ringTag"])
        city = communityString(payload["city"])
        district = communityString(payload["district"])
        if let eventTime = payload["eventDate"] as? Double, eventTime > 0 {
            eventDate = Date(timeIntervalSince1970: eventTime)
        }
        rewardOffered = payload["rewardOffered"] as? Bool ?? false
        custodyStatus = communityString(payload["custodyStatus"], fallback: "unknown")
        if let locked = payload["lockedSubmissionPayload"] as? [String: Any],
           JSONSerialization.isValidJSONObject(locked) {
            lockedSubmissionPayload = locked
            submissionPayloadLocked = true
        } else {
            // Drafts written before the request-body snapshot was introduced
            // remain editable instead of being incorrectly treated as a safe
            // retry of an unknown command.
            submissionPayloadLocked = false
        }
        uploadedMediaAssetIDs = communityOrderedUniqueStrings(
            payload["uploadedMediaAssetIDs"] as? [String] ?? [],
            maximum: 8
        )
        let latitude = communityDouble(payload["latitude"], fallback: .nan)
        let longitude = communityDouble(payload["longitude"], fallback: .nan)
        if latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) {
            pendingCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        syncDomainModelsFromCurrentStrings()
    }

    func clearDraft() {
        if draftPersistenceEnabled { CommunityDraftVault.remove(draftKey) }
        pendingCoordinate = nil
        submissionPayloadLocked = false
        lockedSubmissionPayload = nil
        uploadedMediaAssetIDs = []
    }

    private func unlockDefinitivelyRejectedSubmission(after error: Error) {
        guard lockedSubmissionPayload != nil,
              !PPCommunityService.shouldRetainPendingSubmission(after: error) else {
            return
        }
        // Retain the user's fields, location, and processed media identities;
        // only the server-rejected command body is discarded.
        submissionPayloadLocked = false
        lockedSubmissionPayload = nil
        persistDraft()
    }

    private func submit(_ payload: [String: Any]) async throws {
        if kind == .missing {
            _ = try await PPCommunityService.shared.createMissingCase(payload: payload)
        } else {
            _ = try await PPCommunityService.shared.createFoundReport(payload: payload)
        }
    }

    func submit(coordinate: CLLocationCoordinate2D?) async {
        guard activeSessionOwnsDraft else {
            errorMessage = PPAdoptLang("community_error_sign_in_required")
            return
        }
        guard canSubmit, let coordinate = coordinateForSubmission(coordinate) else {
            errorMessage = PPAdoptLang("community_location_required")
            return
        }
        submitting = true
        errorMessage = nil
        do {
            if let lockedSubmissionPayload {
                try await submit(lockedSubmissionPayload)
            } else {
                let context = kind == .missing ? "missing_case" : "found_report"
                var assetIDs = uploadedMediaAssetIDs
                if !media.isEmpty {
                    let uploaded = try await PPCommunityService.shared.uploadMedia(media, contextType: context, contextID: recordID)
                    uploadedMediaAssetIDs = communityOrderedUniqueStrings(
                        uploadedMediaAssetIDs + uploaded.assetIDs,
                        maximum: 8
                    )
                    media.removeAll()
                    assetIDs = uploadedMediaAssetIDs
                    persistDraft(coordinate: coordinate)
                }
                guard !assetIDs.isEmpty else { throw PPCommunityError.missingMedia }
                let area: [String: Any] = [
                    "countryCode": CountryModel.safeCurrentCountryISOCode() ?? "",
                    "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
                    "district": district.trimmingCharacters(in: .whitespacesAndNewlines)
                ]
                let location: [String: Any] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
                let submissionPayload: [String: Any]
                if kind == .missing {
                    guard let pet = pets.first(where: { $0.petID == selectedPetID }) else { throw PPCommunityError.invalidResponse }
                    let appearance: [String: Any] = [
                        "speciesId": communityString(pet.categoryName).isEmpty ? String(pet.categoryId) : communityString(pet.categoryName),
                        "breed": communityString(pet.breed), "sex": sex, "size": size,
                        "colors": colorValues, "distinctiveMarks": distinctiveMarks
                    ]
                    submissionPayload = [
                        "caseId": recordID, "petId": pet.petID,
                        "lostAt": PPCommunityService.shared.isoString(eventDate),
                        "location": location, "area": area, "appearance": appearance,
                        "description": descriptionText, "wearing": wearing,
                        "microchipped": microchipped,
                        "identification": ["microchipId": microchipID, "ringTag": ringTag],
                        "rewardOffered": rewardOffered, "contactMode": "in_app",
                        "mediaAssetIds": assetIDs
                    ]
                } else {
                    let appearance: [String: Any] = [
                        "speciesId": species, "breed": breed, "sex": sex, "size": size,
                        "colors": colorValues, "distinctiveMarks": distinctiveMarks
                    ]
                    submissionPayload = [
                        "reportId": recordID,
                        "foundAt": PPCommunityService.shared.isoString(eventDate),
                        "location": location, "area": area, "appearance": appearance,
                        "identification": ["microchipId": microchipID, "ringTag": ringTag],
                        "description": descriptionText, "custodyStatus": custodyStatus,
                        "contactMode": "in_app", "mediaAssetIds": assetIDs
                    ]
                }
                persistDraft(
                    coordinate: coordinate,
                    lockSubmissionPayload: true,
                    submissionPayload: submissionPayload
                )
                try await submit(submissionPayload)
            }
            success = true
            clearDraft()
        } catch {
            unlockDefinitivelyRejectedSubmission(after: error)
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
    @State private var activeSheet: CommunityFormSheetType? = nil
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    init(kind: CommunityCaseKind, onFinished: @escaping () -> Void) {
        self.kind = kind
        self.onFinished = onFinished
        _store = StateObject(wrappedValue: CommunityCaseFormStore(kind: kind))
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.ppBackground.ignoresSafeArea()

                // Case-reactive ambient backdrop glow
                VStack {
                    LinearGradient(
                        colors: [
                            (kind == .missing ? CommunityPalette.missing : CommunityPalette.found).opacity(0.12),
                            Color.ppBackground.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)
                    .ignoresSafeArea()
                    Spacer()
                }

                ScrollView {
                    VStack(spacing: 18) {
                        apexHeader
                        readinessRadarCard
                        evidenceStudioCard
                        if kind == .missing {
                            petSelectorCard
                        }
                        petDnaCard
                        if kind == .found {
                            custodyDossierCard
                        }
                        geospatialRadarCard
                        timelineStoryCard
                        identificationVaultCard
                        if let error = store.errorMessage {
                            errorBanner(error)
                        }
                        // Bottom inset spacing for fixed floating dock
                        Spacer()
                            .frame(height: 110)
                    }
                    .frame(maxWidth: 720)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }

                // Floating Studio Action Dock
                floatingActionDock

                if store.submitting {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color.white)
                        Text(PPAdoptLang("community_submitting"))
                            .font(CommunityFont.bold(16))
                            .foregroundStyle(.white)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 16)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            store.loadPets()
            if location.coordinate == nil, let restored = store.restoredCoordinate {
                location.coordinate = restored
                location.state = .ready
            }
        }
        .onChange(of: store.success) { succeeded in if succeeded { onFinished() } }
        .onDisappear {
            guard !store.success else { return }
            store.persistDraft(coordinate: store.coordinateForSubmission(location.coordinate))
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .media:
                let remaining = max(0, 8 - store.mediaAttachmentCount)
                CommunityMediaPicker(
                    maximumCount: max(1, remaining),
                    completion: { sources in store.media.append(contentsOf: sources.prefix(remaining)) },
                    failure: { error in store.errorMessage = error.localizedDescription }
                )
            case .city:
                CommunityCityPickerSheet(
                    cities: store.availableCities,
                    selectedCity: $store.selectedCityModel,
                    onSelect: { city in store.selectCityModel(city) }
                )
            case .district:
                CommunityDistrictPickerSheet(
                    areas: store.availableAreas,
                    selectedArea: $store.selectedAreaModel,
                    onSelect: { area in store.selectAreaModel(area) },
                    manualDistrict: $store.district
                )
            case .species:
                CommunitySpeciesPickerSheet(
                    kinds: store.availableKinds,
                    selectedKind: $store.selectedKind,
                    speciesString: $store.species,
                    onSelect: { kind in store.selectKind(kind) }
                )
            case .breed:
                CommunityBreedPickerSheet(
                    breeds: store.availableBreeds,
                    selectedBreed: $store.selectedBreed,
                    breedString: $store.breed,
                    onSelect: { breed in store.selectBreed(breed) }
                )
            }
        }
    }

    // MARK: - Subviews

    private var apexHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: kind == .missing ? "exclamationmark.triangle.fill" : "shield.checkered")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(kind == .missing ? CommunityPalette.missing : CommunityPalette.found)
                    Text(PPAdoptLang(kind == .missing ? "community_missing_form_title" : "community_found_form_title"))
                        .font(CommunityFont.bold(12))
                        .foregroundStyle(kind == .missing ? CommunityPalette.missing : CommunityPalette.found)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    (kind == .missing ? CommunityPalette.missing : CommunityPalette.found).opacity(0.12),
                    in: Capsule()
                )

                Text(PPAdoptLang(kind == .missing ? "community_report_missing" : "community_report_found"))
                    .font(CommunityFont.bold(22, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            Spacer()

            Button {
                CommunityHaptics.light()
                presentationMode.wrappedValue.dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(PPAdoptLang("Cancel"))
                        .font(CommunityFont.medium(14))
                }
                .foregroundStyle(Color.ppTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.ppSurface, in: Capsule())
                .overlay(Capsule().stroke(Color.ppBorder.opacity(0.7), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            }
            .buttonStyle(CommunityPressStyle())
        }
        .padding(.bottom, 2)
    }

    private var readinessRadarCard: some View {
        let readiness = store.readinessPercentage(location.coordinate)
        let tintColor = kind == .missing ? CommunityPalette.missing : CommunityPalette.found

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(tintColor.opacity(0.16), lineWidth: 4.5)
                        .frame(width: 46, height: 46)
                    Circle()
                        .trim(from: 0, to: CGFloat(readiness) / 100.0)
                        .stroke(
                            AngularGradient(
                                colors: [tintColor, CommunityPalette.safe],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 46, height: 46)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: readiness)

                    Text("\(readiness)%")
                        .font(CommunityFont.bold(12))
                        .foregroundStyle(Color.ppTextPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(PPAdoptLang("community_match_radar_badge"))
                            .font(CommunityFont.bold(14))
                            .foregroundStyle(Color.ppTextPrimary)

                        if readiness >= 100 {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                Text(PPAdoptLang("community_readiness_complete"))
                                    .font(CommunityFont.medium(11))
                            }
                            .foregroundStyle(CommunityPalette.safe)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(CommunityPalette.safe.opacity(0.12), in: Capsule())
                        }
                    }

                    if let notice = store.missingFieldNotice(location.coordinate) {
                        Text(notice)
                            .font(CommunityFont.regular(12))
                            .foregroundStyle(Color.ppTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(PPAdoptLang("community_readiness_complete"))
                            .font(CommunityFont.medium(12))
                            .foregroundStyle(CommunityPalette.safe)
                    }
                }

                Spacer()
            }
        }
        .padding(14)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tintColor.opacity(readiness >= 100 ? 0.35 : 0.18), lineWidth: 1)
        )
    }

    private var evidenceStudioCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                        .frame(width: 34, height: 34)
                        .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(PPAdoptLang("community_media_title"))
                            .font(CommunityFont.bold(16, relativeTo: .headline))
                            .foregroundStyle(Color.ppTextPrimary)
                        Text(PPAdoptLang("community_media_privacy"))
                            .font(CommunityFont.regular(11))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }

                Spacer()

                Text(String(format: PPAdoptLang("community_media_count"), store.mediaAttachmentCount, 8))
                    .font(CommunityFont.bold(12))
                    .foregroundStyle(store.mediaAttachmentCount > 0 ? CommunityPalette.safe : Color.ppTextSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        (store.mediaAttachmentCount > 0 ? CommunityPalette.safe : Color.ppTextSecondary).opacity(0.12),
                        in: Capsule()
                    )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add Media Hero Button
                    Button {
                        CommunityHaptics.light()
                        activeSheet = .media
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.indigo.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.indigo)
                            }
                            Text(PPAdoptLang("community_add_media"))
                                .font(CommunityFont.bold(12))
                                .foregroundStyle(Color.indigo)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 104, height: 116)
                        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.indigo.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        )
                    }
                    .buttonStyle(CommunityPressStyle())
                    .disabled(store.mediaAttachmentCount >= 8)
                    .opacity(store.mediaAttachmentCount >= 8 ? 0.45 : 1)

                    // Local Media Thumbnails
                    ForEach(Array(store.media.enumerated()), id: \.offset) { index, source in
                        ZStack(alignment: .topTrailing) {
                            ZStack(alignment: .bottomLeading) {
                                if let img = source.previewImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 104, height: 116)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.black.opacity(0.85))
                                        .frame(width: 104, height: 116)
                                        .overlay(
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundStyle(.white)
                                        )
                                }

                                if index == 0 {
                                    Text(PPAdoptLang("community_media_cover_badge"))
                                        .font(CommunityFont.bold(9))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.65), in: Capsule())
                                        .padding(6)
                                }

                                if source.isVideo {
                                    HStack(spacing: 3) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 8))
                                        Text(PPAdoptLang("community_media_video_badge"))
                                            .font(CommunityFont.bold(9))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.65), in: Capsule())
                                    .padding(6)
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
                            )

                            // Remove Button
                            Button {
                                CommunityHaptics.medium()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    store.removeMedia(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.red)
                                    .shadow(color: Color.black.opacity(0.25), radius: 2)
                            }
                            .offset(x: 5, y: -5)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(CommunityPalette.safe)
                Text(PPAdoptLang("community_media_safe_inspection"))
                    .font(CommunityFont.regular(11))
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
    }

    private var petSelectorHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CommunityPalette.adoption)
                .frame(width: 34, height: 34)
                .background(CommunityPalette.adoption.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(PPAdoptLang("community_select_pet"))
                    .font(CommunityFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                Text(PPAdoptLang("community_select_pet_message"))
                    .font(CommunityFont.regular(11))
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func petProfileChip(for pet: PPPetProfile, isSelected: Bool) -> some View {
        let bgFill: Color = isSelected ? CommunityPalette.adoption.opacity(0.1) : Color.ppSecondarySurface
        let borderColor: Color = isSelected ? CommunityPalette.adoption : Color.clear

        Button {
            CommunityHaptics.selection()
            store.selectPetProfile(pet)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CommunityPalette.adoption.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(CommunityPalette.adoption)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(CommunityFont.bold(14))
                        .foregroundStyle(Color.ppTextPrimary)
                    if let breed = pet.breed, !breed.isEmpty {
                        Text(breed)
                            .font(CommunityFont.regular(11))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(CommunityPalette.adoption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                bgFill,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(CommunityPressStyle())
    }

    private var petSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            petSelectorHeader

            if store.loadingPets {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else if store.pets.isEmpty {
                Text(PPAdoptLang("community_no_pet_profiles"))
                    .font(CommunityFont.regular(14))
                    .foregroundStyle(Color.ppTextSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.pets, id: \.petID) { pet in
                            let isSelected = store.selectedPetID == pet.petID
                            petProfileChip(for: pet, isSelected: isSelected)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
    }

    private var petDnaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.purple)
                    .frame(width: 34, height: 34)
                    .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(PPAdoptLang("community_appearance_title"))
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPAdoptLang("community_appearance_message"))
                        .font(CommunityFont.regular(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            if kind == .found {
                // Species Quick Selector
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(PPAdoptLang("community_species"))
                            .font(CommunityFont.bold(13))
                            .foregroundStyle(Color.ppTextPrimary)
                        Spacer()
                        Button {
                            CommunityHaptics.light()
                            activeSheet = .species
                        } label: {
                            HStack(spacing: 4) {
                                Text(PPAdoptLang("community_species_other"))
                                    .font(CommunityFont.medium(12))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(CommunityPalette.found)
                        }
                    }

                    let quickSpecies: [CommunitySpeciesQuickOption] = [
                        CommunitySpeciesQuickOption(id: "cat", symbol: "cat.fill", nameAr: "قطط", nameEn: "Cats"),
                        CommunitySpeciesQuickOption(id: "dog", symbol: "dog.fill", nameAr: "كلاب", nameEn: "Dogs"),
                        CommunitySpeciesQuickOption(id: "bird", symbol: "bird.fill", nameAr: "طيور", nameEn: "Birds"),
                        CommunitySpeciesQuickOption(id: "rabbit", symbol: "hare.fill", nameAr: "أرانب", nameEn: "Rabbits"),
                        CommunitySpeciesQuickOption(id: "other", symbol: "sparkles", nameAr: "أخرى", nameEn: "Other")
                    ]

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickSpecies) { opt in
                                let isSelected = isSpeciesQuickOptionSelected(opt, all: quickSpecies)
                                Button {
                                    CommunityHaptics.selection()
                                    if opt.id == "other" {
                                        activeSheet = .species
                                    } else {
                                        store.species = Language.isRTL() ? opt.nameAr : opt.nameEn
                                        store.selectedKind = store.availableKinds.first(where: {
                                            $0.localizedName.contains(opt.nameAr) || $0.localizedName.contains(opt.nameEn)
                                        })
                                        store.selectedBreed = nil
                                        store.breed = ""
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: opt.symbol)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(opt.localizedName)
                                            .font(CommunityFont.bold(13))
                                    }
                                    .foregroundStyle(isSelected ? .white : Color.ppTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(
                                        isSelected ? CommunityPalette.found : Color.ppSecondarySurface,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule().stroke(isSelected ? Color.clear : Color.ppBorder.opacity(0.6), lineWidth: 0.8)
                                    )
                                }
                                .buttonStyle(CommunityPressStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Breed Selector Card
                VStack(alignment: .leading, spacing: 6) {
                    Text(PPAdoptLang("Breed"))
                        .font(CommunityFont.bold(13))
                        .foregroundStyle(Color.ppTextPrimary)

                    Button {
                        CommunityHaptics.light()
                        activeSheet = .breed
                    } label: {
                        HStack {
                            Text(store.breed.isEmpty ? PPAdoptLang("Breed") : store.breed)
                                .font(CommunityFont.medium(14))
                                .foregroundStyle(store.breed.isEmpty ? Color.ppTextSecondary : Color.ppTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(CommunityPressStyle())
                }
            }

            // Gender Twin Cards
            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("Gender"))
                    .font(CommunityFont.bold(13))
                    .foregroundStyle(Color.ppTextPrimary)

                HStack(spacing: 8) {
                    let genders = [
                        (id: "male", nameKey: "community_gender_male", symbol: "figure.stand", tint: Color.blue),
                        (id: "female", nameKey: "community_gender_female", symbol: "figure.stand.dress", tint: Color.pink),
                        (id: "unknown", nameKey: "community_gender_unknown", symbol: "questionmark", tint: Color.gray)
                    ]

                    ForEach(genders, id: \.id) { g in
                        let isSelected = store.sex.lowercased() == g.id || store.sex == PPAdoptLang(g.nameKey)
                        Button {
                            CommunityHaptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                store.sex = PPAdoptLang(g.nameKey)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: g.symbol)
                                    .font(.system(size: 13, weight: .bold))
                                Text(PPAdoptLang(g.nameKey))
                                    .font(CommunityFont.bold(13))
                            }
                            .foregroundStyle(isSelected ? .white : Color.ppTextPrimary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                isSelected ? g.tint : Color.ppSecondarySurface,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.clear : Color.ppBorder.opacity(0.5), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(CommunityPressStyle())
                    }
                }
            }

            // Size 3-Tier Pill
            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("community_size"))
                    .font(CommunityFont.bold(13))
                    .foregroundStyle(Color.ppTextPrimary)

                HStack(spacing: 8) {
                    let sizes = [
                        (id: "small", nameKey: "community_size_small"),
                        (id: "medium", nameKey: "community_size_medium"),
                        (id: "large", nameKey: "community_size_large")
                    ]

                    ForEach(sizes, id: \.id) { s in
                        let isSelected = store.size.lowercased() == s.id || store.size == PPAdoptLang(s.nameKey)
                        Button {
                            CommunityHaptics.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                store.size = PPAdoptLang(s.nameKey)
                            }
                        } label: {
                            Text(PPAdoptLang(s.nameKey))
                                .font(CommunityFont.bold(13))
                                .foregroundStyle(isSelected ? .white : Color.ppTextPrimary)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(
                                    isSelected ? CommunityPalette.found : Color.ppSecondarySurface,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(isSelected ? Color.clear : Color.ppBorder.opacity(0.5), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(CommunityPressStyle())
                    }
                }
            }

            // Visual Color Swatches
            VStack(alignment: .leading, spacing: 8) {
                Text(PPAdoptLang("community_colors"))
                    .font(CommunityFont.bold(13))
                    .foregroundStyle(Color.ppTextPrimary)

                let colorOptions: [CommunityColorOption] = [
                    CommunityColorOption(id: "white", nameAr: "أبيض", nameEn: "White", color: Color.white, isLight: true),
                    CommunityColorOption(id: "black", nameAr: "أسود", nameEn: "Black", color: Color(white: 0.15), isLight: false),
                    CommunityColorOption(id: "brown", nameAr: "بني", nameEn: "Brown", color: Color(red: 0.52, green: 0.32, blue: 0.18), isLight: false),
                    CommunityColorOption(id: "beige", nameAr: "بيج / ذهبي", nameEn: "Beige / Gold", color: Color(red: 0.91, green: 0.78, blue: 0.62), isLight: true),
                    CommunityColorOption(id: "gray", nameAr: "رمادي", nameEn: "Gray", color: Color.gray, isLight: false),
                    CommunityColorOption(id: "orange", nameAr: "مشمشي / برتقالي", nameEn: "Ginger / Orange", color: Color.orange, isLight: false),
                    CommunityColorOption(id: "pattern", nameAr: "مرقش / تايجر", nameEn: "Patterned / Tabby", color: Color.purple, isLight: false)
                ]

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(colorOptions) { opt in
                            let name = opt.localizedName
                            let isSelected = store.selectedColors.contains(name) || store.selectedColors.contains(opt.nameAr) || store.selectedColors.contains(opt.nameEn)
                            Button {
                                CommunityHaptics.selection()
                                store.toggleColor(name)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(opt.color)
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 0.8))
                                    Text(name)
                                        .font(CommunityFont.medium(12))
                                        .foregroundStyle(isSelected ? .white : Color.ppTextPrimary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected ? CommunityPalette.found : Color.ppSecondarySurface,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(isSelected ? Color.clear : Color.ppBorder.opacity(0.6), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(CommunityPressStyle())
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Custom Color Tag Field
                TextField(PPAdoptLang("community_colors"), text: $store.colors)
                    .font(CommunityFont.regular(13))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            // Distinctive Marks
            VStack(alignment: .leading, spacing: 6) {
                Text(PPAdoptLang("community_marks"))
                    .font(CommunityFont.bold(13))
                    .foregroundStyle(Color.ppTextPrimary)
                TextField(PPAdoptLang("community_marks"), text: $store.distinctiveMarks)
                    .font(CommunityFont.regular(14))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
    }

    private func isSpeciesQuickOptionSelected(_ opt: CommunitySpeciesQuickOption, all: [CommunitySpeciesQuickOption]) -> Bool {
        if store.species == opt.nameAr || store.species == opt.nameEn {
            return true
        }
        if opt.id == "other" && !store.species.isEmpty {
            let isKnownStandard = all.prefix(4).contains(where: {
                store.species == $0.nameAr || store.species == $0.nameEn
            })
            return !isKnownStandard
        }
        return false
    }

    private var custodyDossierCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CommunityPalette.found)
                    .frame(width: 34, height: 34)
                    .background(CommunityPalette.found.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(PPAdoptLang("community_custody"))
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPAdoptLang("community_details_message"))
                        .font(CommunityFont.regular(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            VStack(spacing: 10) {
                let custodyOptions: [CommunityCustodyOption] = [
                    CommunityCustodyOption(
                        id: "with_reporter",
                        symbol: "house.fill",
                        tint: CommunityPalette.safe,
                        titleKey: "community_custody_with_me",
                        descKey: "community_custody_with_me_desc"
                    ),
                    CommunityCustodyOption(
                        id: "safe_location",
                        symbol: "cross.case.fill",
                        tint: Color.blue,
                        titleKey: "community_custody_safe_place",
                        descKey: "community_custody_safe_place_desc"
                    ),
                    CommunityCustodyOption(
                        id: "unknown",
                        symbol: "eye.fill",
                        tint: Color.orange,
                        titleKey: "community_custody_unknown",
                        descKey: "community_custody_unknown_desc"
                    )
                ]

                ForEach(custodyOptions) { option in
                    let isSelected = store.custodyStatus == option.id
                    Button {
                        CommunityHaptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            store.custodyStatus = option.id
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(option.tint.opacity(isSelected ? 0.2 : 0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: option.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(option.tint)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(PPAdoptLang(option.titleKey))
                                    .font(CommunityFont.bold(14))
                                    .foregroundStyle(isSelected ? Color.ppTextPrimary : Color.ppTextSecondary)
                                Text(PPAdoptLang(option.descKey))
                                    .font(CommunityFont.regular(11))
                                    .foregroundStyle(Color.ppTextSecondary.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .stroke(isSelected ? option.tint : Color.ppBorder, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                                if isSelected {
                                    Circle()
                                        .fill(option.tint)
                                        .frame(width: 14, height: 14)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            isSelected ? option.tint.opacity(0.06) : Color.ppSecondarySurface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? option.tint.opacity(0.6) : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(CommunityPressStyle())
                }
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
    }

    private var geospatialRadarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CommunityPalette.missing)
                    .frame(width: 34, height: 34)
                    .background(CommunityPalette.missing.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(PPAdoptLang("community_location_title"))
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPAdoptLang("community_location_privacy"))
                        .font(CommunityFont.regular(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            // Interactive City & District Chips
            HStack(spacing: 10) {
                // City Button
                Button {
                    CommunityHaptics.light()
                    activeSheet = .city
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PPAdoptLang("City"))
                            .font(CommunityFont.medium(11))
                            .foregroundStyle(Color.ppTextSecondary)
                        HStack {
                            Text(store.city.isEmpty ? PPAdoptLang("community_location_select_city") : store.city)
                                .font(CommunityFont.bold(14))
                                .foregroundStyle(store.city.isEmpty ? Color.ppTextSecondary : Color.ppTextPrimary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(store.city.isEmpty ? Color.clear : CommunityPalette.found.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(CommunityPressStyle())

                // District Button
                Button {
                    CommunityHaptics.light()
                    activeSheet = .district
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PPAdoptLang("community_district"))
                            .font(CommunityFont.medium(11))
                            .foregroundStyle(Color.ppTextSecondary)
                        HStack {
                            Text(store.district.isEmpty ? PPAdoptLang("community_location_select_district") : store.district)
                                .font(CommunityFont.bold(14))
                                .foregroundStyle(store.district.isEmpty ? Color.ppTextSecondary : Color.ppTextPrimary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(store.district.isEmpty ? Color.clear : CommunityPalette.found.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(CommunityPressStyle())
            }

            // Manual District Text Field Fallback
            VStack(alignment: .leading, spacing: 4) {
                Text(PPAdoptLang("community_location_manual_hint"))
                    .font(CommunityFont.regular(11))
                    .foregroundStyle(Color.ppTextSecondary)
                TextField(PPAdoptLang("community_district"), text: $store.district)
                    .font(CommunityFont.regular(14))
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Live GPS Beacon
            Button {
                CommunityHaptics.medium()
                location.request()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((location.coordinate != nil ? CommunityPalette.safe : CommunityPalette.missing).opacity(0.15))
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(location.coordinate != nil ? CommunityPalette.safe : CommunityPalette.missing)
                            .frame(width: 10, height: 10)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(locationTitle)
                            .font(CommunityFont.bold(14))
                            .foregroundStyle(location.coordinate != nil ? CommunityPalette.safe : CommunityPalette.missing)
                        if location.coordinate != nil {
                            Text(PPAdoptLang("community_location_pulse_ready"))
                                .font(CommunityFont.regular(11))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: location.coordinate != nil ? "checkmark.circle.fill" : "location.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(location.coordinate != nil ? CommunityPalette.safe : CommunityPalette.missing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    (location.coordinate != nil ? CommunityPalette.safe : CommunityPalette.missing).opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke((location.coordinate != nil ? CommunityPalette.safe : CommunityPalette.missing).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(CommunityPressStyle())

            // Coarse Notice
            Label(PPAdoptLang("community_location_coarse_notice"), systemImage: "shield.lefthalf.filled")
                .font(CommunityFont.regular(11))
                .foregroundStyle(Color.ppTextSecondary)
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
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

    private var timelineStoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 34, height: 34)
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(PPAdoptLang("community_details_title"))
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPAdoptLang("community_details_message"))
                        .font(CommunityFont.regular(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            // Date & Time Picker
            DatePicker(
                PPAdoptLang(kind == .missing ? "community_lost_at" : "community_found_at"),
                selection: $store.eventDate,
                in: ...Date()
            )
            .font(CommunityFont.medium(14))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Guided Story Text Area
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    if store.descriptionText.isEmpty {
                        Text(PPAdoptLang(kind == .missing ? "community_story_placeholder_missing" : "community_story_placeholder_found"))
                            .font(CommunityFont.regular(14))
                            .foregroundStyle(Color.ppTextSecondary.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $store.descriptionText)
                        .font(CommunityFont.regular(14))
                        .frame(minHeight: 110)
                        .padding(8)
                        .background(Color.clear)
                }
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(store.descriptionText.isEmpty ? Color.clear : CommunityPalette.found.opacity(0.3), lineWidth: 1)
                )

                HStack {
                    Spacer()
                    Text("\(store.descriptionText.count) حرف")
                        .font(CommunityFont.regular(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            if kind == .missing {
                CommunityField(title: PPAdoptLang("community_wearing"), text: $store.wearing)

                Toggle(isOn: $store.rewardOffered) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.orange)
                        Text(PPAdoptLang("community_reward"))
                            .font(CommunityFont.medium(14))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
    }

    private var identificationVaultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CommunityPalette.safe)
                    .frame(width: 34, height: 34)
                    .background(CommunityPalette.safe.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(PPAdoptLang("community_ident_vault_title"))
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPAdoptLang("community_identification_privacy"))
                        .font(CommunityFont.regular(11))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }

            if kind == .missing {
                Toggle(PPAdoptLang("community_microchipped"), isOn: $store.microchipped)
                    .font(CommunityFont.medium(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if kind == .found || store.microchipped {
                CommunityField(title: PPAdoptLang("community_microchip_optional"), text: $store.microchipID)
            }

            CommunityField(title: PPAdoptLang("community_ring_tag_optional"), text: $store.ringTag)

            Label(PPAdoptLang("community_ident_vault_note"), systemImage: "key.fill")
                .font(CommunityFont.regular(11))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
            Text(message)
                .font(CommunityFont.medium(13))
                .foregroundStyle(Color.red)
            Spacer()
        }
        .padding(14)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var floatingActionDock: some View {
        VStack(spacing: 8) {
            if let notice = store.missingFieldNotice(location.coordinate) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .medium))
                    Text(notice)
                        .font(CommunityFont.medium(12))
                }
                .foregroundStyle(Color.ppTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.ppSurface.opacity(0.92), in: Capsule())
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            }

            Button {
                CommunityHaptics.success()
                Task { await store.submit(coordinate: location.coordinate) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(PPAdoptLang("community_submit_instant_match"))
                        .font(CommunityFont.bold(17, relativeTo: .headline))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(
                        colors: kind == .missing
                            ? [Color.orange, Color.red.opacity(0.85)]
                            : [CommunityPalette.found, CommunityPalette.safe],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(
                    color: (kind == .missing ? CommunityPalette.missing : CommunityPalette.found).opacity(0.35),
                    radius: 12,
                    y: 5
                )
            }
            .buttonStyle(CommunityPressStyle())
            .disabled(!store.canSubmit || !store.submissionLocationIsAvailable(location.coordinate) || store.submitting)
            .opacity((!store.canSubmit || !store.submissionLocationIsAvailable(location.coordinate) || store.submitting) ? 0.45 : 1.0)
            .accessibilityHint(PPAdoptLang("community_submit_review_hint"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
        .overlay(
            VStack {
                Divider()
                Spacer()
            }
        )
    }
}

// MARK: - Dedicated Picker Sheets

private struct CommunityCityPickerSheet: View {
    let cities: [CityModel]
    @Binding var selectedCity: CityModel?
    let onSelect: (CityModel) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var search = ""

    var filtered: [CityModel] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return cities }
        return cities.filter {
            ($0.localizedName).localizedCaseInsensitiveContains(search) ||
            ($0.name ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.ppTextSecondary)
                        TextField(PPAdoptLang("community_search_placeholder"), text: $search)
                            .font(CommunityFont.regular(15))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    List(filtered, id: \.cityID) { city in
                        Button {
                            CommunityHaptics.selection()
                            selectedCity = city
                            onSelect(city)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            HStack {
                                Text(city.localizedName)
                                    .font(CommunityFont.medium(16))
                                    .foregroundStyle(Color.ppTextPrimary)
                                Spacer()
                                if selectedCity?.cityID == city.cityID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(CommunityPalette.found)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .padding(.top, 12)
            }
            .navigationTitle(PPAdoptLang("community_location_select_city"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

private struct CommunityDistrictPickerSheet: View {
    let areas: [StateModel]
    @Binding var selectedArea: StateModel?
    let onSelect: (StateModel) -> Void
    @Binding var manualDistrict: String
    @Environment(\.presentationMode) private var presentationMode
    @State private var search = ""

    var filtered: [StateModel] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return areas }
        return areas.filter {
            ($0.localizedName).localizedCaseInsensitiveContains(search) ||
            ($0.arName ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.enName ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.ppTextSecondary)
                        TextField(PPAdoptLang("community_search_placeholder"), text: $search)
                            .font(CommunityFont.regular(15))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    List {
                        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                CommunityHaptics.selection()
                                manualDistrict = search.trimmingCharacters(in: .whitespacesAndNewlines)
                                selectedArea = nil
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(CommunityPalette.found)
                                    Text("\(PPAdoptLang("community_location_manual_hint")): \(search)")
                                        .font(CommunityFont.bold(15))
                                        .foregroundStyle(CommunityPalette.found)
                                }
                            }
                        }

                        ForEach(filtered, id: \.stateID) { area in
                            Button {
                                CommunityHaptics.selection()
                                selectedArea = area
                                manualDistrict = area.localizedName
                                onSelect(area)
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Text(area.localizedName)
                                        .font(CommunityFont.medium(16))
                                        .foregroundStyle(Color.ppTextPrimary)
                                    Spacer()
                                    if selectedArea?.stateID == area.stateID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(CommunityPalette.found)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .padding(.top, 12)
            }
            .navigationTitle(PPAdoptLang("community_location_select_district"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

private struct CommunitySpeciesPickerSheet: View {
    let kinds: [MainKindsModel]
    @Binding var selectedKind: MainKindsModel?
    @Binding var speciesString: String
    let onSelect: (MainKindsModel) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var search = ""

    var filtered: [MainKindsModel] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return kinds }
        return kinds.filter {
            ($0.localizedName).localizedCaseInsensitiveContains(search) ||
            ($0.kindNameAr ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.kindNameEn ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.ppTextSecondary)
                        TextField(PPAdoptLang("community_search_placeholder"), text: $search)
                            .font(CommunityFont.regular(15))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    List {
                        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                CommunityHaptics.selection()
                                speciesString = search.trimmingCharacters(in: .whitespacesAndNewlines)
                                selectedKind = nil
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(CommunityPalette.found)
                                    Text("\(search)")
                                        .font(CommunityFont.bold(15))
                                        .foregroundStyle(CommunityPalette.found)
                                }
                            }
                        }

                        ForEach(filtered, id: \.id) { kind in
                            Button {
                                CommunityHaptics.selection()
                                selectedKind = kind
                                speciesString = kind.localizedName
                                onSelect(kind)
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Text(kind.localizedName)
                                        .font(CommunityFont.medium(16))
                                        .foregroundStyle(Color.ppTextPrimary)
                                    Spacer()
                                    if selectedKind?.id == kind.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(CommunityPalette.found)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .padding(.top, 12)
            }
            .navigationTitle(PPAdoptLang("community_species"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

private struct CommunityBreedPickerSheet: View {
    let breeds: [SubKindModel]
    @Binding var selectedBreed: SubKindModel?
    @Binding var breedString: String
    let onSelect: (SubKindModel) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var search = ""

    var filtered: [SubKindModel] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return breeds }
        return breeds.filter {
            ($0.localizedName).localizedCaseInsensitiveContains(search) ||
            ($0.subKindNameAr ?? "").localizedCaseInsensitiveContains(search) ||
            ($0.subKindNameEn ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.ppTextSecondary)
                        TextField(PPAdoptLang("community_search_placeholder"), text: $search)
                            .font(CommunityFont.regular(15))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)

                    List {
                        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                CommunityHaptics.selection()
                                breedString = search.trimmingCharacters(in: .whitespacesAndNewlines)
                                selectedBreed = nil
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(CommunityPalette.found)
                                    Text("\(search)")
                                        .font(CommunityFont.bold(15))
                                        .foregroundStyle(CommunityPalette.found)
                                }
                            }
                        }

                        ForEach(filtered, id: \.id) { breed in
                            Button {
                                CommunityHaptics.selection()
                                selectedBreed = breed
                                breedString = breed.localizedName
                                onSelect(breed)
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Text(breed.localizedName)
                                        .font(CommunityFont.medium(16))
                                        .foregroundStyle(Color.ppTextPrimary)
                                    Spacer()
                                    if selectedBreed?.id == breed.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(CommunityPalette.found)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .padding(.top, 12)
            }
            .navigationTitle(PPAdoptLang("Breed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
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
    let failure: (PPCommunityError) -> Void

    init(
        maximumCount: Int,
        completion: @escaping ([PPCommunityMediaSource]) -> Void,
        failure: @escaping (PPCommunityError) -> Void
    ) {
        self.maximumCount = maximumCount
        self.completion = completion
        self.failure = failure
    }

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion, failure: failure) }

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
        let failure: (PPCommunityError) -> Void

        init(
            completion: @escaping ([PPCommunityMediaSource]) -> Void,
            failure: @escaping (PPCommunityError) -> Void
        ) {
            self.completion = completion
            self.failure = failure
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { completion([]); return }
            let videoResultCount = results.filter {
                !$0.itemProvider.canLoadObject(ofClass: UIImage.self)
            }.count
            // Mirror the server and service contract before loading large file
            // representations into memory. A mixed batch permits one video.
            guard videoResultCount <= 1 else {
                failure(.mediaTooLarge)
                return
            }
            let group = DispatchGroup()
            let lock = NSLock()
            var indexed: [(Int, PPCommunityMediaSource)] = []
            var didFailToLoad = false
            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                group.enter()
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage, let source = try? PPCommunityMediaSource(image: image) {
                            lock.lock(); indexed.append((index, source)); lock.unlock()
                        } else {
                            lock.lock(); didFailToLoad = true; lock.unlock()
                        }
                        group.leave()
                    }
                } else {
                    let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.quickTimeMovie.identifier) ? UTType.quickTimeMovie.identifier : UTType.movie.identifier
                    provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                        let fileSize: Int
                        if let url,
                           let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                           let size = values.fileSize {
                            fileSize = size
                        } else {
                            fileSize = 0
                        }
                        if let url,
                           fileSize > 0,
                           fileSize <= (60 * 1024 * 1024) - 1,
                           let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
                           let source = try? PPCommunityMediaSource(data: data, contentType: typeIdentifier == UTType.quickTimeMovie.identifier ? "video/quicktime" : "video/mp4") {
                            lock.lock(); indexed.append((index, source)); lock.unlock()
                        } else {
                            lock.lock(); didFailToLoad = true; lock.unlock()
                        }
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                lock.lock()
                let sources = indexed.sorted { $0.0 < $1.0 }.map(\.1)
                let failed = didFailToLoad || sources.count != results.count ||
                    sources.reduce(0) { $0 + $1.data.count } > 80 * 1024 * 1024
                lock.unlock()
                if failed {
                    self.failure(.mediaTooLarge)
                } else {
                    self.completion(sources)
                }
            }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    detailHeader
                    Text(communityString(store.item["description"])).font(CommunityFont.regular(16, relativeTo: .body)).foregroundStyle(Color.ppTextPrimary).lineSpacing(4)
                    privacyCard
                    if let error = store.errorMessage { Text(error).font(CommunityFont.medium(14)).foregroundStyle(.red).padding(14).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)) }
                    if !isOwner {
                        Button {
                            guard UserManager.shared().isUserLoggedIn() else {
                                UserManager.showPromptOnTopController()
                                return
                            }
                            reportRequested = true
                        } label: {
                            Label(PPAdoptLang("community_report_content"), systemImage: "exclamationmark.bubble")
                                .font(CommunityFont.medium(14))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                    }
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

    @ViewBuilder
    private var detailHeader: some View {
        let identity = VStack(alignment: .leading, spacing: 4) {
            Text(communityTitle(store.item))
                .font(CommunityFont.bold(29, relativeTo: .largeTitle))
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Label(communityArea(store.item), systemImage: "mappin.and.ellipse")
                .font(CommunityFont.medium(14))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        let share = Button { store.showsShare = true } label: {
            Image(systemName: "square.and.arrow.up")
                .frame(width: 44, height: 44)
                .background(Color.ppSurface, in: Circle())
        }
        .accessibilityLabel(PPAdoptLang("Share"))
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) { identity; share }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack { identity; Spacer(); share }
        }
    }

    private var actionDock: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { actionButtons }
                } else {
                    HStack(spacing: 12) { actionButtons }
                }
            }
            .padding(14)
            .background(Color.ppElevatedSurface)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button { presentationMode.wrappedValue.dismiss() } label: {
            Text(PPAdoptLang("Back"))
                .font(CommunityFont.bold(15))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        if store.kind == .missing && (isOwner || sightingsEnabled) {
            Button {
                guard UserManager.shared().isUserLoggedIn() else {
                    UserManager.showPromptOnTopController()
                    return
                }
                if isOwner { Task { await store.confirmReunion() } } else { store.showsSighting = true }
            } label: {
                Label(
                    PPAdoptLang(isOwner ? "community_confirm_reunion" : "community_submit_sighting"),
                    systemImage: isOwner ? "house.and.flag.fill" : "eye.fill"
                )
                .font(CommunityFont.bold(15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(isOwner ? CommunityPalette.safe : CommunityPalette.missing, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(store.actionInProgress)
        }
    }
}

@MainActor
private final class CommunitySightingStore: ObservableObject {
    let caseID: String
    private(set) var sightingID: String
    @Published var descriptionText = ""
    @Published var seenAt = Date()
    @Published var confidence = 0.7
    @Published var media: [PPCommunityMediaSource] = []
    @Published private(set) var uploadedMediaAssetIDs: [String] = []
    @Published var submitting = false
    @Published var errorMessage: String?
    @Published var success = false
    private let draftOwnerUID: String
    private let draftPersistenceEnabled: Bool
    private var pendingCoordinate: CLLocationCoordinate2D?
    private var submissionPayloadLocked = false
    private var lockedSubmissionPayload: [String: Any]?

    private var draftKey: String {
        "sighting-form.\(caseID).\(draftOwnerUID)"
    }

    init(caseID: String) {
        self.caseID = caseID
        let currentUID = communityString(UserManager.shared().currentUser?.id)
        self.draftOwnerUID = currentUID.isEmpty ? UUID().uuidString.lowercased() : currentUID
        self.draftPersistenceEnabled = !currentUID.isEmpty
        self.sightingID = UUID().uuidString.lowercased()
        restoreDraft()
    }

    var mediaAttachmentCount: Int { min(6, uploadedMediaAssetIDs.count + media.count) }
    var restoredCoordinate: CLLocationCoordinate2D? { pendingCoordinate }
    var canSubmit: Bool {
        lockedSubmissionPayload != nil || !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    func submissionLocationIsAvailable(_ liveCoordinate: CLLocationCoordinate2D?) -> Bool {
        coordinateForSubmission(liveCoordinate) != nil
    }

    private var activeSessionOwnsDraft: Bool {
        draftPersistenceEnabled && communityString(UserManager.shared().currentUser?.id) == draftOwnerUID
    }

    func coordinateForSubmission(_ liveCoordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        // A retry must preserve the coordinate that was part of the original
        // durable command payload rather than silently sampling a new one.
        if let lockedSubmissionPayload,
           let lockedCoordinate = communityCoordinate(from: lockedSubmissionPayload) {
            return lockedCoordinate
        }
        return submissionPayloadLocked ? (pendingCoordinate ?? liveCoordinate) : (liveCoordinate ?? pendingCoordinate)
    }

    func persistDraft(
        coordinate: CLLocationCoordinate2D? = nil,
        lockSubmissionPayload: Bool = false,
        submissionPayload: [String: Any]? = nil
    ) {
        guard draftPersistenceEnabled else { return }
        if let coordinate { pendingCoordinate = coordinate }
        if let submissionPayload,
           JSONSerialization.isValidJSONObject(submissionPayload) {
            lockedSubmissionPayload = submissionPayload
            submissionPayloadLocked = true
        } else if lockSubmissionPayload {
            submissionPayloadLocked = true
        }
        var payload: [String: Any] = [
            "sightingID": sightingID,
            "descriptionText": descriptionText,
            "seenAt": seenAt.timeIntervalSince1970,
            "confidence": confidence,
            "uploadedMediaAssetIDs": uploadedMediaAssetIDs,
            "submissionPayloadLocked": submissionPayloadLocked
        ]
        if let lockedSubmissionPayload {
            payload["lockedSubmissionPayload"] = lockedSubmissionPayload
        }
        if let coordinate = pendingCoordinate {
            payload["latitude"] = coordinate.latitude
            payload["longitude"] = coordinate.longitude
        }
        CommunityDraftVault.save(payload, for: draftKey)
    }

    private func restoreDraft() {
        guard draftPersistenceEnabled,
              let payload = CommunityDraftVault.dictionary(for: draftKey) else { return }
        let storedID = communityString(payload["sightingID"])
        if !storedID.isEmpty { sightingID = storedID }
        descriptionText = communityString(payload["descriptionText"])
        if let seenTime = payload["seenAt"] as? Double, seenTime > 0 {
            seenAt = min(Date(), Date(timeIntervalSince1970: seenTime))
        }
        confidence = min(1, max(0, communityDouble(payload["confidence"], fallback: confidence)))
        if let locked = payload["lockedSubmissionPayload"] as? [String: Any],
           JSONSerialization.isValidJSONObject(locked) {
            lockedSubmissionPayload = locked
            submissionPayloadLocked = true
        } else {
            submissionPayloadLocked = false
        }
        uploadedMediaAssetIDs = communityOrderedUniqueStrings(
            payload["uploadedMediaAssetIDs"] as? [String] ?? [],
            maximum: 6
        )
        let latitude = communityDouble(payload["latitude"], fallback: .nan)
        let longitude = communityDouble(payload["longitude"], fallback: .nan)
        if latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) {
            pendingCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private func clearDraft() {
        if draftPersistenceEnabled { CommunityDraftVault.remove(draftKey) }
        pendingCoordinate = nil
        submissionPayloadLocked = false
        lockedSubmissionPayload = nil
        uploadedMediaAssetIDs = []
    }

    private func unlockDefinitivelyRejectedSubmission(after error: Error) {
        guard lockedSubmissionPayload != nil,
              !PPCommunityService.shouldRetainPendingSubmission(after: error) else {
            return
        }
        submissionPayloadLocked = false
        lockedSubmissionPayload = nil
        persistDraft()
    }

    func submit(coordinate: CLLocationCoordinate2D?) async {
        guard activeSessionOwnsDraft else {
            errorMessage = PPAdoptLang("community_error_sign_in_required")
            return
        }
        guard canSubmit,
              let coordinate = coordinateForSubmission(coordinate) else {
            errorMessage = PPAdoptLang("community_location_required")
            return
        }
        submitting = true
        errorMessage = nil
        do {
            if let lockedSubmissionPayload {
                _ = try await PPCommunityService.shared.submitSighting(payload: lockedSubmissionPayload)
            } else {
                var assetIDs = uploadedMediaAssetIDs
                if !media.isEmpty {
                    let uploaded = try await PPCommunityService.shared.uploadMedia(
                        media,
                        contextType: "sighting",
                        contextID: "\(caseID)~\(sightingID)"
                    )
                    uploadedMediaAssetIDs = communityOrderedUniqueStrings(
                        uploadedMediaAssetIDs + uploaded.assetIDs,
                        maximum: 6
                    )
                    media.removeAll()
                    assetIDs = uploadedMediaAssetIDs
                    persistDraft(coordinate: coordinate)
                }
                let submissionPayload: [String: Any] = [
                    "caseId": caseID, "sightingId": sightingID,
                    "seenAt": PPCommunityService.shared.isoString(seenAt),
                    "location": ["latitude": coordinate.latitude, "longitude": coordinate.longitude],
                    "description": descriptionText, "confidence": confidence,
                    "mediaAssetIds": assetIDs
                ]
                persistDraft(
                    coordinate: coordinate,
                    lockSubmissionPayload: true,
                    submissionPayload: submissionPayload
                )
                _ = try await PPCommunityService.shared.submitSighting(payload: submissionPayload)
            }
            success = true
            clearDraft()
        } catch {
            unlockDefinitivelyRejectedSubmission(after: error)
            errorMessage = error.localizedDescription
        }
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
                    Button(PPAdoptLang("community_add_optional_media")) { picker = true }
                        .disabled(store.mediaAttachmentCount >= 6)
                    if store.mediaAttachmentCount > 0 {
                        Text(String(format: PPAdoptLang("community_media_count"), store.mediaAttachmentCount, 6))
                    }
                }
                if let error = store.errorMessage { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button(PPAdoptLang("community_submit_sighting")) {
                        Task { await store.submit(coordinate: location.coordinate) }
                    }
                    .disabled(
                        store.submitting ||
                        !store.submissionLocationIsAvailable(location.coordinate) ||
                        !store.canSubmit
                    )
                }
            }
            .navigationTitle(PPAdoptLang("community_submit_sighting"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(PPAdoptLang("Cancel")) { presentationMode.wrappedValue.dismiss() } } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if location.coordinate == nil, let restored = store.restoredCoordinate {
                location.coordinate = restored
                location.state = .ready
            }
        }
        .onChange(of: store.success) { if $0 { onFinished() } }
        .onDisappear {
            guard !store.success else { return }
            store.persistDraft(coordinate: store.coordinateForSubmission(location.coordinate))
        }
        .sheet(isPresented: $picker) {
            let remaining = max(0, 6 - store.mediaAttachmentCount)
            CommunityMediaPicker(
                maximumCount: max(1, remaining),
                completion: { sources in store.media.append(contentsOf: sources.prefix(remaining)) },
                failure: { error in store.errorMessage = error.localizedDescription }
            )
        }
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
                CommunityActivityRow(
                    item: pair.element,
                    group: key,
                    messagingEnabled: messagingEnabled,
                    onApplicationChanged: { Task { await store.loadActivity() } }
                )
            }
        }
    }
}

private struct CommunityMatchSignal: Identifiable {
    let id: String
    let title: String
    let value: Double
}

@MainActor
private final class CommunityMatchDetailStore: ObservableObject {
    @Published var item: [String: Any]
    @Published var loading = true
    @Published var actionInProgress = false
    @Published var errorMessage: String?
    private var generation = UUID()

    init(item: [String: Any]) {
        self.item = item
    }

    func load() async {
        let matchID = communityID(item)
        guard !matchID.isEmpty else {
            loading = false
            errorMessage = PPAdoptLang("community_match_unavailable_message")
            return
        }
        let requestGeneration = UUID()
        generation = requestGeneration
        loading = true
        errorMessage = nil
        do {
            let latest = try await PPCommunityService.shared.matchDetail(id: matchID)
            guard generation == requestGeneration else { return }
            item = latest
        } catch {
            guard generation == requestGeneration else { return }
            errorMessage = error.localizedDescription
        }
        if generation == requestGeneration { loading = false }
    }

    func confirmReunion() async {
        let reunion = communityDictionary(item["reunion"])
        let caseID = communityString(reunion["caseId"])
        let expectedVersion = communityInt(reunion["expectedVersion"])
        let matchID = communityID(item)
        guard !caseID.isEmpty, !matchID.isEmpty, expectedVersion > 0 else {
            errorMessage = PPAdoptLang("community_match_reunion_refresh")
            return
        }
        actionInProgress = true
        errorMessage = nil
        do {
            _ = try await PPCommunityService.shared.transition("confirmPetReunion", payload: [
                "caseId": caseID,
                "matchId": matchID,
                "expectedVersion": expectedVersion
            ], prefix: "match-reunion")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
        actionInProgress = false
    }
}

private struct CommunityMatchDetailScreen: View {
    @StateObject private var store: CommunityMatchDetailStore
    @State private var showsReunionConfirmation = false
    let messagingEnabled: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(item: [String: Any], messagingEnabled: Bool) {
        _store = StateObject(wrappedValue: CommunityMatchDetailStore(item: item))
        self.messagingEnabled = messagingEnabled
    }

    var body: some View {
        ZStack {
            Color.ppBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                CommunityScreenHeader(
                    title: PPAdoptLang("community_match_detail_title"),
                    subtitle: PPAdoptLang("community_match_detail_subtitle")
                )
                content
            }
        }
        .navigationBarHidden(true)
        .task { await store.load() }
        .confirmationDialog(
            PPAdoptLang("community_match_reunion_confirm_title"),
            isPresented: $showsReunionConfirmation,
            titleVisibility: .visible
        ) {
            Button(PPAdoptLang("community_match_reunion_confirm_action")) {
                Task { await store.confirmReunion() }
            }
            Button(PPAdoptLang("Cancel"), role: .cancel) {}
        } message: {
            Text(PPAdoptLang("community_match_reunion_confirm_message"))
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.loading {
            CommunityStateView(
                symbol: "sparkles",
                title: PPAdoptLang("community_match_loading_title"),
                message: PPAdoptLang("community_match_loading_message"),
                showsProgress: true
            )
        } else if let error = store.errorMessage, store.item.isEmpty {
            CommunityStateView(
                symbol: "exclamationmark.shield",
                title: PPAdoptLang("community_match_unavailable_title"),
                message: error,
                actionTitle: PPAdoptLang("Retry"),
                action: { Task { await store.load() } }
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    identityCard
                    confidenceCard
                    if !signals.isEmpty { signalCard }
                    privacyCard
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(CommunityFont.medium(14))
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
                    }
                    actionCard
                }
                .frame(maxWidth: 760)
                .padding(18)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await store.load() }
        }
    }

    private var identityCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.purple)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(communityTitle(store.item))
                    .font(CommunityFont.bold(26, relativeTo: .title2))
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(communityStatus(store.item))
                    .font(CommunityFont.bold(13, relativeTo: .subheadline))
                    .foregroundStyle(.purple)
                Text(statusMessage)
                    .font(CommunityFont.regular(14, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
    }

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            confidenceHeader
            if hasSafeEvaluation {
                ProgressView(value: score, total: 1)
                    .tint(.purple)
                    .accessibilityLabel(PPAdoptLang("community_match_confidence_title"))
                    .accessibilityValue(score.formatted(.percent.precision(.fractionLength(0))))
            }
            Text(PPAdoptLang(hasSafeEvaluation ? "community_match_confidence_\(confidenceBand)" : "community_match_confidence_protected"))
                .font(CommunityFont.medium(13))
                .foregroundStyle(Color.ppTextSecondary)
            matchFacts
            .font(CommunityFont.regular(13))
            .foregroundStyle(Color.ppTextSecondary)
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
    }

    private var signalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PPAdoptLang("community_match_signals_title"))
                .font(CommunityFont.bold(17, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
            Text(PPAdoptLang("community_match_signals_message"))
                .font(CommunityFont.regular(13))
                .foregroundStyle(Color.ppTextSecondary)
            ForEach(signals) { signal in
                signalRow(signal)
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
    }

    @ViewBuilder
    private var confidenceHeader: some View {
        let title = Label(
            PPAdoptLang("community_match_confidence_title"),
            systemImage: "gauge.with.dots.needle.67percent"
        )
        .font(CommunityFont.bold(17, relativeTo: .headline))
        .foregroundStyle(Color.ppTextPrimary)
        if hasSafeEvaluation {
            let percentage = Text(score.formatted(.percent.precision(.fractionLength(0))))
                .font(CommunityFont.bold(18, relativeTo: .headline).monospacedDigit())
                .foregroundStyle(.purple)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { title; percentage }
            } else {
                HStack { title; Spacer(); percentage }
            }
        } else {
            title
        }
    }

    @ViewBuilder
    private var matchFacts: some View {
        let distance = optionalDouble("distanceKm").map {
            Label(
                String(format: PPAdoptLang("community_match_distance_format"), $0),
                systemImage: "point.topleft.down.to.point.bottomright.curvepath"
            )
        }
        let time = optionalDouble("timeDeltaHours").map {
            Label(
                String(format: PPAdoptLang("community_match_time_format"), $0),
                systemImage: "clock.arrow.circlepath"
            )
        }
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                if let distance { distance }
                if let time { time }
            }
        } else {
            HStack(spacing: 16) {
                if let distance { distance }
                if let time { time }
            }
        }
    }

    @ViewBuilder
    private func signalRow(_ signal: CommunityMatchSignal) -> some View {
        let isStrong = signal.value >= 0.75
        let isWeak = signal.value <= 0.25
        let isNeutral = abs(signal.value - 0.5) < 0.001
        let symbol = Image(systemName: isStrong ? "checkmark.seal.fill" : isWeak ? "xmark.circle.fill" : "circle.lefthalf.filled")
            .foregroundStyle(isStrong ? CommunityPalette.safe : isWeak ? Color.red : Color.orange)
            .accessibilityHidden(true)
        let title = Text(signal.title)
            .font(CommunityFont.medium(14))
            .foregroundStyle(Color.ppTextPrimary)
        let value = Text(isNeutral ? PPAdoptLang("community_match_signal_neutral") : signal.value.formatted(.percent.precision(.fractionLength(0))))
            .font(CommunityFont.medium(13).monospacedDigit())
            .foregroundStyle(Color.ppTextSecondary)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) { symbol; title }
                value
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(spacing: 10) { symbol; title; Spacer(); value }
                .accessibilityElement(children: .combine)
        }
    }

    private var privacyCard: some View {
        Label(PPAdoptLang("community_match_privacy_message"), systemImage: "lock.shield.fill")
            .font(CommunityFont.regular(13))
            .foregroundStyle(Color.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CommunityPalette.safe.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var actionCard: some View {
        if canMessage || canConfirmReunion {
            VStack(spacing: 10) {
                if canMessage {
                    Button(action: openChat) {
                        Label(PPAdoptLang("community_safe_message"), systemImage: "bubble.left.and.bubble.right.fill")
                            .font(CommunityFont.bold(16))
                            .foregroundStyle(.purple)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(CommunityPressStyle())
                }
                if canConfirmReunion {
                    Button { showsReunionConfirmation = true } label: {
                        Label(PPAdoptLang("community_match_reunion_confirm_action"), systemImage: "house.and.flag.fill")
                            .font(CommunityFont.bold(16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(CommunityPalette.safe, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(CommunityPressStyle())
                    .disabled(store.actionInProgress)
                }
            }
            .padding(16)
            .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            Text(PPAdoptLang("community_match_no_action_message"))
                .font(CommunityFont.regular(13))
                .foregroundStyle(Color.ppTextSecondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var score: Double {
        max(0, min(1, communityDouble(store.item["score"])))
    }

    private var hasSafeEvaluation: Bool {
        optionalDouble("score") != nil
    }

    private var confidenceBand: String {
        let value = communityString(store.item["confidenceBand"])
        return ["high", "medium", "review"].contains(value) ? value : "review"
    }

    private var status: String { communityString(store.item["status"]) }

    private var statusMessage: String {
        let supported = ["pending_review", "needs_information", "likely_match", "escalated", "confirmed", "rejected", "dismissed"]
        return PPAdoptLang("community_match_state_\(supported.contains(status) ? status : "unavailable")")
    }

    private var signals: [CommunityMatchSignal] {
        let values = communityDictionary(store.item["signals"])
        return values.compactMap { key, value in
            let score = communityDouble(value, fallback: -1)
            guard score >= 0 else { return nil }
            return CommunityMatchSignal(
                id: key,
                title: PPAdoptLang("community_match_signal_\(key)"),
                value: max(0, min(1, score))
            )
        }
        .sorted { left, right in
            if left.value == right.value { return left.id < right.id }
            return left.value > right.value
        }
    }

    private var canMessage: Bool {
        messagingEnabled && ["needs_information", "likely_match", "confirmed"].contains(status) && !peerUID.isEmpty
    }

    private var canConfirmReunion: Bool {
        status == "likely_match" && !communityDictionary(store.item["reunion"]).isEmpty
    }

    private var peerUID: String {
        let uid = UserManager.shared().currentUser?.id ?? ""
        let key = communityString(store.item["missingOwnerUid"]) == uid ? "foundReporterUid" : "missingOwnerUid"
        return communityString(store.item[key])
    }

    private func optionalDouble(_ key: String) -> Double? {
        guard store.item[key] != nil else { return nil }
        let value = communityDouble(store.item[key], fallback: -1)
        return value >= 0 ? value : nil
    }

    private func openChat() {
        PPCommunityChatCoordinator.open(
            contextType: "found_match",
            contextID: communityID(store.item),
            peerUID: peerUID
        )
    }
}

private enum CommunityAdoptionApplicationAction: String, Identifiable {
    case startReview = "start_review"
    case requestQuestions = "request_questions"
    case scheduleMeetAndGreet = "schedule_meet_and_greet"
    case requestHomeCheck = "request_home_check"
    case approve = "approve"
    case startHandover = "start_handover"
    case reject = "reject"
    case cancelHandover = "cancel_handover"
    case withdraw = "withdraw"

    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .startReview: return "community_application_action_start_review"
        case .requestQuestions: return "community_application_action_request_questions"
        case .scheduleMeetAndGreet: return "community_application_action_schedule_meet"
        case .requestHomeCheck: return "community_application_action_request_home_check"
        case .approve: return "community_application_action_approve"
        case .startHandover: return "community_application_action_start_handover"
        case .reject: return "community_application_action_reject"
        case .cancelHandover: return "community_application_action_cancel_handover"
        case .withdraw: return "community_application_action_withdraw"
        }
    }
    var symbol: String {
        switch self {
        case .startReview: return "doc.text.magnifyingglass"
        case .requestQuestions: return "questionmark.bubble"
        case .scheduleMeetAndGreet: return "person.2.badge.gearshape"
        case .requestHomeCheck: return "house"
        case .approve: return "checkmark.seal.fill"
        case .startHandover: return "heart.circle.fill"
        case .reject, .cancelHandover: return "xmark.octagon.fill"
        case .withdraw: return "arrow.uturn.backward.circle"
        }
    }
    var requiresReason: Bool { self == .reject || self == .cancelHandover }
    var isDestructive: Bool { self == .reject || self == .cancelHandover || self == .withdraw }
}

@MainActor
private final class CommunityAdoptionApplicationDetailStore: ObservableObject {
    @Published var item: [String: Any]
    @Published private(set) var accessRole = ""
    @Published var loading = true
    @Published var actionInProgress = false
    @Published var errorMessage: String?
    private var generation = UUID()

    init(item: [String: Any]) {
        self.item = item
    }

    func load() async {
        let applicationID = communityID(item)
        guard !applicationID.isEmpty else {
            loading = false
            errorMessage = PPAdoptLang("community_application_unavailable")
            return
        }
        let requestGeneration = UUID()
        generation = requestGeneration
        loading = true
        errorMessage = nil
        do {
            let detail = try await PPCommunityService.shared.adoptionApplicationDetail(id: applicationID)
            guard generation == requestGeneration else { return }
            item = detail.item
            accessRole = detail.accessRole
        } catch {
            guard generation == requestGeneration else { return }
            errorMessage = error.localizedDescription
        }
        if generation == requestGeneration { loading = false }
    }

    func transition(_ action: CommunityAdoptionApplicationAction, reason: String = "") async -> Bool {
        let applicationID = communityID(item)
        let expectedVersion = communityInt(item["version"])
        guard !applicationID.isEmpty, expectedVersion > 0 else {
            errorMessage = PPAdoptLang("community_application_refresh_required")
            return false
        }
        actionInProgress = true
        errorMessage = nil
        do {
            let result = try await PPCommunityService.shared.transitionAdoptionApplication(
                applicationID: applicationID,
                expectedVersion: expectedVersion,
                action: action.rawValue,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            item["status"] = result["status"] as? String ?? item["status"]
            item["version"] = result["version"] ?? item["version"]
            if !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item["statusReason"] = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            actionInProgress = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionInProgress = false
            return false
        }
    }
}

private func communityApplicationAnswerText(_ value: [String: Any]) -> String {
    let selectedOptions = value["selectedOptions"] as? [[String: Any]] ?? []
    let selectedLabels = selectedOptions.compactMap { option -> String? in
        let preferred = Language.isRTL() ? communityString(option["labelAr"]) : communityString(option["labelEn"])
        let fallback = Language.isRTL() ? communityString(option["labelEn"]) : communityString(option["labelAr"])
        return preferred.isEmpty ? (fallback.isEmpty ? nil : fallback) : preferred
    }
    if !selectedLabels.isEmpty { return selectedLabels.joined(separator: PPAdoptLang("community_separator")) }
    if let array = value["answer"] as? [Any] {
        let values = array.map { communityString($0) }.filter { !$0.isEmpty }
        if !values.isEmpty { return values.joined(separator: PPAdoptLang("community_separator")) }
    }
    return communityString(value["answer"])
}

private struct CommunityAdoptionApplicationDetailScreen: View {
    @StateObject private var store: CommunityAdoptionApplicationDetailStore
    @State private var confirmationAction: CommunityAdoptionApplicationAction?
    @State private var reasonAction: CommunityAdoptionApplicationAction?
    @State private var reason = ""
    @State private var showsReasonEditor = false
    let messagingEnabled: Bool
    let onChanged: () -> Void

    init(item: [String: Any], messagingEnabled: Bool, onChanged: @escaping () -> Void) {
        _store = StateObject(wrappedValue: CommunityAdoptionApplicationDetailStore(item: item))
        self.messagingEnabled = messagingEnabled
        self.onChanged = onChanged
    }

    var body: some View {
        ZStack {
            Color.ppBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                CommunityScreenHeader(
                    title: PPAdoptLang("community_application_review_title"),
                    subtitle: PPAdoptLang("community_application_review_message")
                )
                content
            }
        }
        .navigationBarHidden(true)
        .task { await store.load() }
        .confirmationDialog(
            PPAdoptLang("community_application_action_confirm_title"),
            isPresented: Binding(
                get: { confirmationAction != nil },
                set: { if !$0 { confirmationAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = confirmationAction {
                Button(PPAdoptLang(action.titleKey), role: action.isDestructive ? .destructive : nil) {
                    confirmationAction = nil
                    perform(action)
                }
            }
            Button(PPAdoptLang("Cancel"), role: .cancel) { confirmationAction = nil }
        } message: {
            Text(PPAdoptLang("community_application_action_confirm_message"))
        }
        .sheet(isPresented: $showsReasonEditor) {
            if let action = reasonAction {
                CommunityAdoptionApplicationReasonSheet(
                    action: action,
                    reason: $reason,
                    onCancel: {
                        reasonAction = nil
                        showsReasonEditor = false
                    },
                    onSubmit: {
                        let submittedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                        reasonAction = nil
                        showsReasonEditor = false
                        perform(action, reason: submittedReason)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.loading {
            CommunityStateView(
                symbol: "doc.text.magnifyingglass",
                title: PPAdoptLang("community_application_loading_title"),
                message: PPAdoptLang("community_application_loading_message"),
                showsProgress: true
            )
        } else if let error = store.errorMessage, store.item.isEmpty {
            CommunityStateView(
                symbol: "exclamationmark.shield",
                title: PPAdoptLang("community_application_unavailable"),
                message: error,
                actionTitle: PPAdoptLang("Retry"),
                action: { Task { await store.load() } }
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    overviewCard
                    responseCard
                    statusReasonCard
                    actionCard
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(CommunityFont.medium(14, relativeTo: .body))
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
                .frame(maxWidth: 760)
                .padding(18)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await store.load() }
        }
    }

    private var overviewCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: canReview ? "person.text.rectangle.fill" : "doc.text.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(CommunityPalette.adoption)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(overviewTitle)
                    .font(CommunityFont.bold(23, relativeTo: .title2))
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(communityStatus(store.item))
                    .font(CommunityFont.bold(13, relativeTo: .subheadline))
                    .foregroundStyle(CommunityPalette.adoption)
                Text(PPAdoptLang("community_application_protected_review_note"))
                    .font(CommunityFont.regular(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
        .accessibilityElement(children: .combine)
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(PPAdoptLang("community_application_response_title"))
                .font(CommunityFont.bold(18, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
            if !message.isEmpty {
                CommunityApplicationResponseRow(title: PPAdoptLang("community_application_message"), value: message)
            }
            ForEach(Array(coreAnswers.enumerated()), id: \.offset) { entry in
                CommunityApplicationResponseRow(title: PPAdoptLang(entry.element.key), value: entry.element.value)
            }
            ForEach(configuredAnswers.indices, id: \.self) { index in
                let answer = configuredAnswers[index]
                CommunityApplicationResponseRow(title: configuredAnswerTitle(answer), value: communityApplicationAnswerText(answer))
            }
            if message.isEmpty && coreAnswers.isEmpty && configuredAnswers.isEmpty {
                Text(PPAdoptLang("community_application_response_empty"))
                    .font(CommunityFont.regular(14, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .padding(18)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
    }

    @ViewBuilder
    private var statusReasonCard: some View {
        if !statusReason.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text(PPAdoptLang("community_application_status_note_title"))
                    .font(CommunityFont.bold(15, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                Text(statusReason)
                    .font(CommunityFont.regular(14, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            if canMessage {
                Button(action: openChat) {
                    Label(PPAdoptLang("community_safe_message"), systemImage: "bubble.left.and.bubble.right.fill")
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(CommunityPalette.adoption)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(CommunityPalette.adoption.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(CommunityPressStyle())
            }
            if !progressActions.isEmpty {
                Menu {
                    ForEach(progressActions) { action in
                        Button {
                            select(action)
                        } label: {
                            Label(PPAdoptLang(action.titleKey), systemImage: action.symbol)
                        }
                    }
                } label: {
                    Label(PPAdoptLang("community_application_review_actions"), systemImage: "slider.horizontal.3")
                        .font(CommunityFont.bold(16, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(CommunityPalette.adoption, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(store.actionInProgress)
            }
            if let destructiveAction {
                Button {
                    select(destructiveAction)
                } label: {
                    Label(PPAdoptLang(destructiveAction.titleKey), systemImage: destructiveAction.symbol)
                        .font(CommunityFont.bold(15, relativeTo: .headline))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(CommunityPressStyle())
                .disabled(store.actionInProgress)
            }
            if !canMessage && availableActions.isEmpty {
                Text(PPAdoptLang("community_application_no_action_message"))
                    .font(CommunityFont.regular(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .padding(16)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.ppBorder.opacity(0.65), lineWidth: 0.8) }
    }

    private var overviewTitle: String {
        let displayName = communityString(communityDictionary(store.item["applicant"])["displayName"])
        if canReview, !displayName.isEmpty {
            return String(format: PPAdoptLang("community_application_reviewing_applicant"), displayName)
        }
        return PPAdoptLang("community_application_your_submission")
    }

    private var message: String { communityString(store.item["message"]) }
    private var status: String { communityString(store.item["status"]) }
    private var statusReason: String { communityString(store.item["statusReason"]) }
    private var canReview: Bool { ["listing_owner", "organization_operator"].contains(store.accessRole) }
    private var canMessage: Bool {
        messagingEnabled && !["draft", "withdrawn", "rejected"].contains(status) && !peerUID.isEmpty
    }
    private var peerUID: String {
        let applicantUID = communityString(store.item["applicantUid"])
        let listingOwnerUID = communityString(store.item["listingOwnerUid"])
        let currentUID = UserManager.shared().currentUser?.id ?? ""
        return currentUID == applicantUID ? listingOwnerUID : applicantUID
    }
    private var coreAnswers: [(key: String, value: String)] {
        let values = communityDictionary(store.item["answers"])
        let fields = [
            ("community_household_type", "householdType"),
            ("community_household_members", "householdMembers"),
            ("community_children", "children"),
            ("community_existing_pets", "existingPets"),
            ("community_pet_experience", "petExperience"),
            ("community_housing_permission", "housingPermission"),
            ("community_daily_routine", "dailyRoutine"),
            ("community_care_plan", "carePlan")
        ]
        return fields.compactMap { key, field in
            let value = communityString(values[field])
            return value.isEmpty ? nil : (key, value)
        }
    }
    private var configuredAnswers: [[String: Any]] {
        store.item["questionAnswers"] as? [[String: Any]] ?? []
    }
    private var availableActions: [CommunityAdoptionApplicationAction] {
        if canReview {
            switch status {
            case "submitted": return [.startReview, .requestQuestions, .scheduleMeetAndGreet, .requestHomeCheck, .approve, .reject]
            case "under_review": return [.requestQuestions, .scheduleMeetAndGreet, .requestHomeCheck, .approve, .reject]
            case "questions", "meet_and_greet", "home_check": return [.startReview, .requestQuestions, .scheduleMeetAndGreet, .requestHomeCheck, .approve, .reject]
            case "approved": return [.startHandover, .reject]
            case "handover": return [.cancelHandover]
            default: return []
            }
        }
        if store.accessRole == "applicant", ["submitted", "under_review", "questions", "meet_and_greet", "home_check", "approved"].contains(status) {
            return [.withdraw]
        }
        return []
    }
    private var progressActions: [CommunityAdoptionApplicationAction] {
        availableActions.filter { !$0.isDestructive }
    }
    private var destructiveAction: CommunityAdoptionApplicationAction? {
        availableActions.first(where: { $0.isDestructive })
    }

    private func configuredAnswerTitle(_ answer: [String: Any]) -> String {
        let preferred = Language.isRTL() ? communityString(answer["labelAr"]) : communityString(answer["labelEn"])
        let fallback = Language.isRTL() ? communityString(answer["labelEn"]) : communityString(answer["labelAr"])
        return preferred.isEmpty ? (fallback.isEmpty ? PPAdoptLang("community_application_response_title") : fallback) : preferred
    }

    private func select(_ action: CommunityAdoptionApplicationAction) {
        if action.requiresReason {
            reason = ""
            reasonAction = action
            showsReasonEditor = true
        } else {
            confirmationAction = action
        }
    }

    private func perform(_ action: CommunityAdoptionApplicationAction, reason: String = "") {
        Task {
            if await store.transition(action, reason: reason) {
                onChanged()
            }
        }
    }

    private func openChat() {
        PPCommunityChatCoordinator.open(
            contextType: "adoption_application",
            contextID: communityID(store.item),
            peerUID: peerUID
        )
    }
}

private struct CommunityApplicationResponseRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(CommunityFont.medium(13, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
            Text(value)
                .font(CommunityFont.regular(15, relativeTo: .body))
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CommunityAdoptionApplicationReasonSheet: View {
    let action: CommunityAdoptionApplicationAction
    @Binding var reason: String
    let onCancel: () -> Void
    let onSubmit: () -> Void
    @FocusState private var isFocused: Bool

    private var trimmedReason: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ppBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(PPAdoptLang("community_application_reason_message"))
                        .font(CommunityFont.regular(14, relativeTo: .body))
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TextEditor(text: $reason)
                        .font(CommunityFont.regular(16, relativeTo: .body))
                        .frame(minHeight: 150)
                        .padding(10)
                        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .focused($isFocused)
                        .accessibilityLabel(PPAdoptLang("community_application_reason_title"))
                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .navigationTitle(PPAdoptLang(action.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(PPAdoptLang("Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(PPAdoptLang("community_application_reason_submit"), action: onSubmit)
                        .disabled(trimmedReason.count < 3)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { isFocused = true }
    }
}

private struct CommunityActivityRow: View {
    let item: [String: Any]
    let group: String
    let messagingEnabled: Bool
    let onApplicationChanged: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            if opensMatchDetail {
                NavigationLink(destination: CommunityMatchDetailScreen(item: item, messagingEnabled: messagingEnabled)) {
                    rowSummary
                }
                .buttonStyle(.plain)
                .accessibilityHint(PPAdoptLang("community_match_open_details"))
            } else if opensApplicationDetail {
                NavigationLink(
                    destination: CommunityAdoptionApplicationDetailScreen(
                        item: item,
                        messagingEnabled: messagingEnabled,
                        onChanged: onApplicationChanged
                    )
                ) {
                    rowSummary
                }
                .buttonStyle(.plain)
                .accessibilityHint(PPAdoptLang("community_application_open_details"))
            } else {
                rowSummary
            }
            if canMessage {
                Button { openChat() } label: { Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(tint).frame(width: 40, height: 40).background(tint.opacity(0.1), in: Circle()) }.accessibilityLabel(PPAdoptLang("community_safe_message"))
            }
        }
        .padding(14).background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.ppBorder.opacity(0.6), lineWidth: 0.8) }
        .accessibilityElement(children: canMessage || opensMatchDetail || opensApplicationDetail ? .contain : .combine)
    }
    private var rowSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint).frame(width: 42, height: 42).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) { Text(communityTitle(item)).font(CommunityFont.bold(16)).foregroundStyle(Color.ppTextPrimary); Text(communityStatus(item)).font(CommunityFont.regular(13)).foregroundStyle(Color.ppTextSecondary) }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    private var opensMatchDetail: Bool { group == "matches" && !communityID(item).isEmpty }
    private var opensApplicationDetail: Bool { group == "adoptionApplications" && !communityID(item).isEmpty }
    private var symbol: String { group == "adoptionApplications" ? "doc.text.fill" : group == "matches" ? "sparkles" : group == "sightings" ? "eye.fill" : "pawprint.fill" }
    private var tint: Color { group == "matches" ? .purple : group == "sightings" ? CommunityPalette.missing : CommunityPalette.adoption }
    private var canMessage: Bool {
        guard messagingEnabled else { return false }
        let status = communityString(item["status"] ?? item["verificationStatus"])
        if group == "adoptionApplications" {
            let uid = UserManager.shared().currentUser?.id ?? ""
            let peerKey = communityString(item["applicantUid"]) == uid ? "listingOwnerUid" : "applicantUid"
            return !["draft", "withdrawn", "rejected"].contains(status) && !communityString(item[peerKey]).isEmpty
        }
        if group == "sightings" { return status != "rejected" }
        if group == "matches" {
            let uid = UserManager.shared().currentUser?.id ?? ""
            let peerKey = communityString(item["missingOwnerUid"]) == uid ? "foundReporterUid" : "missingOwnerUid"
            return ["needs_information", "likely_match", "confirmed"].contains(status) && !communityString(item[peerKey]).isEmpty
        }
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
    @State private var reportTarget: CommunityReportTarget?

    var body: some View {
        ZStack {
            Color.ppBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                CommunityScreenHeader(
                    title: PPAdoptLang("community_organizations_title"),
                    subtitle: PPAdoptLang("community_organizations_message")
                )
                content
            }
        }
        .navigationBarHidden(true)
        .task { await store.loadOrganizations() }
        .sheet(item: $reportTarget) { target in
            CommunityContentReportScreen(targetType: target.type, targetID: target.id) {
                reportTarget = nil
            }
        }
    }

    @ViewBuilder private var content: some View {
        if store.loading { CommunityStateView(symbol: "checkmark.seal", title: PPAdoptLang("community_loading_title"), message: PPAdoptLang("community_loading_message"), showsProgress: true) }
        else if let error = store.errorMessage { CommunityStateView(symbol: "exclamationmark.triangle", title: PPAdoptLang("community_error_title"), message: error, actionTitle: PPAdoptLang("Retry"), action: { Task { await store.loadOrganizations() } }) }
        else if store.items.isEmpty { CommunityStateView(symbol: "building.2", title: PPAdoptLang("community_organizations_empty_title"), message: PPAdoptLang("community_organizations_empty_message")) }
        else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(Array(store.items.enumerated()), id: \.offset) { pair in
                        CommunityOrganizationCard(item: pair.element) {
                            guard UserManager.shared().isUserLoggedIn() else {
                                UserManager.showPromptOnTopController()
                                return
                            }
                            let organizationID = communityID(pair.element)
                            guard !organizationID.isEmpty else { return }
                            reportTarget = CommunityReportTarget(id: organizationID, type: "organization")
                        }
                    }
                }
                .frame(maxWidth: 900)
                .padding(18)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct CommunityReportTarget: Identifiable {
    let id: String
    let type: String
}

private struct CommunityOrganizationCard: View {
    let item: [String: Any]
    let onReport: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(CommunityPalette.safe)
                    .accessibilityHidden(true)
                Text(communityString(item["name"]))
                    .font(CommunityFont.bold(19))
                    .foregroundStyle(Color.ppTextPrimary)
                Spacer()
            }
            Text(communityString(item["description"]))
                .font(CommunityFont.regular(14))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 4)
            Label(communityArea(item), systemImage: "mappin.and.ellipse")
                .font(CommunityFont.medium(13))
                .foregroundStyle(Color.ppTextSecondary)
            Button(action: onReport) {
                Label(PPAdoptLang("community_report_content"), systemImage: "exclamationmark.bubble")
                    .font(CommunityFont.medium(13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(CommunityPressStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 199, alignment: .topLeading)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.ppBorder.opacity(0.6), lineWidth: 0.8) }
        .accessibilityElement(children: .contain)
    }
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
    private var reasons: [String] {
        if targetType == "organization" {
            return ["impersonation", "fraud", "incorrect_information", "spam"]
        }
        var values = ["incorrect_information", "animal_welfare_concern", "stolen_pet", "fraud", "spam", "inappropriate_media", "dangerous_interaction", "impersonation"]
        if targetType == "adoption_listing" { values.insert("fake_adoption_listing", at: 0) }
        return values
    }
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
