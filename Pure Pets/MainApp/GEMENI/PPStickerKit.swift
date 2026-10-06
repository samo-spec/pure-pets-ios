//
//  PPStickerKit.swift
//  Pure Pets
//
//  Created by Codex on 17/07/2026.
//

import SwiftUI
import UIKit
import FirebaseStorage

private enum PPStickerPalette {
    static let accent = Color(
        uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.710, green: 0.745, blue: 0.720, alpha: 1.0)
            }
            return UIColor(red: 0.145, green: 0.166, blue: 0.165, alpha: 1.0)
        }
    )

    static let fieldSurface = Color(
        uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.085)
            }
            return UIColor(red: 0.955, green: 0.948, blue: 0.925, alpha: 0.82)
        }
    )
}

private extension Color {
    static var ppStickerAccent: Color { PPStickerPalette.accent }
    static var ppStickerFieldSurface: Color { PPStickerPalette.fieldSurface }
}

@objc(PPChatSticker)
public final class PPChatSticker: NSObject, Identifiable {
    @objc public let storagePath: String
    @objc public let downloadURLString: String
    @objc public let displayName: String

    public var id: String { cacheKey }

    @objc public var cacheKey: String {
        storagePath.isEmpty ? downloadURLString : storagePath
    }

    @objc public init(
        storagePath: String,
        downloadURLString: String,
        displayName: String
    ) {
        self.storagePath = storagePath
        self.downloadURLString = downloadURLString
        self.displayName = displayName
        super.init()
    }
}

private struct PPStickerManifestEntry: Codable {
    let storagePath: String
    let downloadURLString: String
    let displayName: String
}

fileprivate enum PPStickerPickerPhase: Equatable {
    case idle
    case loading
    case ready
    case empty
    case offline
    case failed
}

@objc(PPStickerStore)
public final class PPStickerStore: NSObject, ObservableObject {
    @objc public static let shared = PPStickerStore()

    @Published fileprivate(set) var stickers: [PPChatSticker] = []
    @Published fileprivate var phase: PPStickerPickerPhase = .idle
    @Published fileprivate var isRefreshing = false

    private let workQueue = DispatchQueue(label: "com.purepets.chat.stickers.cache", qos: .userInitiated)
    private var hasLoadedRemoteManifest = false

    private lazy var cacheDirectory: URL = {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return root.appendingPathComponent("PPStickerCache", isDirectory: true)
    }()

    private var manifestURL: URL {
        cacheDirectory.appendingPathComponent("stickers.json", isDirectory: false)
    }

    public override init() {
        super.init()
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        let cached = loadCachedManifest()
        if !cached.isEmpty {
            stickers = cached
            phase = .ready
        }
    }

    @objc public func warmStickerCache() {
        refreshStickers(force: false)
    }

    fileprivate func refreshStickers(force: Bool) {
        if isRefreshing { return }
        if hasLoadedRemoteManifest, !force, !stickers.isEmpty {
            prefetch(stickers)
            return
        }

        let cached = loadCachedManifest()
        if !cached.isEmpty, stickers.isEmpty {
            stickers = cached
            phase = .ready
        } else if stickers.isEmpty {
            phase = .loading
        }

        isRefreshing = true

        let folder = Storage.storage().reference().child("stickers")
        listStickerReferences(in: folder) { [weak self] references, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                    self.phase = self.isOfflineError(error) ? .offline : .failed
                }
                return
            }

            let items = references
                .filter { self.isSupportedStickerReference($0) }
                .sorted { $0.fullPath.localizedStandardCompare($1.fullPath) == .orderedAscending }

            guard !items.isEmpty else {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                    self.stickers = []
                    self.phase = .empty
                    self.persistManifest([])
                }
                return
            }

            self.resolveDownloadURLs(for: items)
        }
    }

    private func listStickerReferences(
        in folder: StorageReference,
        completion: @escaping ([StorageReference], Error?) -> Void
    ) {
        folder.listAll { result, error in
            if let error {
                completion([], error)
                return
            }

            var references = result?.items ?? []
            let prefixes = result?.prefixes ?? []
            guard !prefixes.isEmpty else {
                completion(references, nil)
                return
            }

            let group = DispatchGroup()
            let lock = NSLock()
            var firstError: Error?

            for prefix in prefixes {
                group.enter()
                self.listStickerReferences(in: prefix) { nestedReferences, nestedError in
                    lock.lock()
                    if let nestedError, firstError == nil {
                        firstError = nestedError
                    }
                    references.append(contentsOf: nestedReferences)
                    lock.unlock()
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(references, firstError)
            }
        }
    }

    @objc(imageForStickerWithStoragePath:downloadURLString:completion:)
    public func imageForSticker(
        storagePath: String,
        downloadURLString: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        AppRemoteImagePipeline.load(
            urlString: downloadURLString,
            cacheKey: storagePath.isEmpty ? nil : storagePath,
            completion: completion
        )
    }

    private func resolveDownloadURLs(for items: [StorageReference]) {
        let group = DispatchGroup()
        let lock = NSLock()
        var resolved: [PPChatSticker] = []

        for item in items {
            group.enter()
            item.downloadURL { url, _ in
                defer { group.leave() }
                guard let url else { return }
                let sticker = PPChatSticker(
                    storagePath: item.fullPath,
                    downloadURLString: url.absoluteString,
                    displayName: item.name
                )
                lock.lock()
                resolved.append(sticker)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            let stickers = resolved.sorted {
                $0.storagePath.localizedStandardCompare($1.storagePath) == .orderedAscending
            }

            self.isRefreshing = false
            self.hasLoadedRemoteManifest = true
            self.stickers = stickers
            self.phase = stickers.isEmpty ? .empty : .ready
            self.persistManifest(stickers)
            self.prefetch(stickers)
        }
    }

    private func prefetch(_ stickers: [PPChatSticker]) {
        for sticker in stickers {
            imageForSticker(
                storagePath: sticker.storagePath,
                downloadURLString: sticker.downloadURLString
            ) { _ in }
        }
    }

    private func persistManifest(_ stickers: [PPChatSticker]) {
        let entries = stickers.map {
            PPStickerManifestEntry(
                storagePath: $0.storagePath,
                downloadURLString: $0.downloadURLString,
                displayName: $0.displayName
            )
        }
        workQueue.async {
            try? FileManager.default.createDirectory(
                at: self.cacheDirectory,
                withIntermediateDirectories: true
            )
            if let data = try? JSONEncoder().encode(entries) {
                try? data.write(to: self.manifestURL, options: .atomic)
            }
        }
    }

    private func loadCachedManifest() -> [PPChatSticker] {
        guard let data = try? Data(contentsOf: manifestURL),
              let entries = try? JSONDecoder().decode(
                [PPStickerManifestEntry].self,
                from: data
              ) else {
            return []
        }

        return entries.map {
            PPChatSticker(
                storagePath: $0.storagePath,
                downloadURLString: $0.downloadURLString,
                displayName: $0.displayName
            )
        }
    }

    private func isSupportedStickerReference(_ reference: StorageReference) -> Bool {
        let name = reference.name
        guard !name.hasPrefix(".") else { return false }
        let ext = (name as NSString).pathExtension.lowercased()
        return ["png", "webp", "gif", "jpg", "jpeg", "heic"].contains(ext)
    }

    private func isOfflineError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorTimedOut,
                NSURLErrorInternationalRoamingOff,
                NSURLErrorDataNotAllowed
            ].contains(nsError.code)
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isOfflineError(underlying)
        }

        return false
    }

}

struct PPStickerPickerSheet: View {
    @ObservedObject private var store = PPStickerStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onSelect: (PPChatSticker) -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 74.0, maximum: 96.0),
                spacing: PPSpace.md
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0.0) {
            header

            if store.phase == .offline, !store.stickers.isEmpty {
                offlineBanner
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            content
        }
        .background(sheetBackground)
        .onAppear {
            store.refreshStickers(force: false)
        }
        .modifier(PPStickerSheetPresentationModifier())
    }

    private var header: some View {
        HStack(spacing: PPSpace.sm) {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(localized("chat_stickers_title"))
                    .font(.custom("Beiruti-Bold", size: 22.0, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
                Text(localized("chat_stickers_subtitle"))
                    .font(.custom("Beiruti-Medium", size: 13.0, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: PPSpace.sm)

            Button {
                store.refreshStickers(force: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14.0, weight: .semibold))
                    .frame(width: 36.0, height: 36.0)
                    .contentShape(Circle())
            }
            .buttonStyle(PPStickerIconButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(Text(localized("chat_stickers_retry")))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13.0, weight: .bold))
                    .frame(width: 36.0, height: 36.0)
                    .contentShape(Circle())
            }
            .buttonStyle(PPStickerIconButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(Text(localized("cancel")))
        }
        .padding(.horizontal, PPSpace.lg)
        .padding(.top, PPSpace.lg)
        .padding(.bottom, PPSpace.md)
    }

    @ViewBuilder
    private var content: some View {
        if store.stickers.isEmpty {
            switch store.phase {
            case .loading, .idle:
                stickerStateView(
                    icon: "hourglass",
                    titleKey: "chat_stickers_loading_title",
                    subtitleKey: "chat_stickers_loading_subtitle",
                    showsProgress: true
                )
            case .empty:
                stickerStateView(
                    icon: "face.smiling",
                    titleKey: "chat_stickers_empty_title",
                    subtitleKey: "chat_stickers_empty_subtitle",
                    showsProgress: false
                )
            case .offline:
                retryStateView(
                    icon: "wifi.slash",
                    titleKey: "chat_stickers_offline_title",
                    subtitleKey: "chat_stickers_offline_subtitle"
                )
            case .failed:
                retryStateView(
                    icon: "exclamationmark.triangle",
                    titleKey: "chat_stickers_error_title",
                    subtitleKey: "chat_stickers_error_subtitle"
                )
            case .ready:
                EmptyView()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: PPSpace.md) {
                    ForEach(store.stickers) { sticker in
                        PPStickerPickerItem(sticker: sticker) {
                            onSelect(sticker)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, PPSpace.lg)
                .padding(.top, PPSpace.xs)
                .padding(.bottom, PPSpace.xl)
            }
            .overlay(alignment: .top) {
                if store.isRefreshing {
                    ProgressView()
                        .tint(Color.ppStickerAccent)
                        .padding(.top, PPSpace.xs)
                }
            }
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12.0, weight: .semibold))
            Text(localized("chat_stickers_offline_cached"))
                .font(.custom("Beiruti-Medium", size: 13.0, relativeTo: .caption))
                .lineLimit(1)
        }
        .foregroundStyle(Color.ppWarning)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppWarning.opacity(0.10))
    }

    private func stickerStateView(
        icon: String,
        titleKey: String,
        subtitleKey: String,
        showsProgress: Bool
    ) -> some View {
        VStack(spacing: PPSpace.md) {
            if showsProgress {
                ProgressView()
                    .tint(Color.ppStickerAccent)
                    .scaleEffect(1.08)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 32.0, weight: .semibold))
                    .foregroundStyle(Color.ppStickerAccent)
            }

            VStack(spacing: 4.0) {
                Text(localized(titleKey))
                    .font(.custom("Beiruti-Bold", size: 18.0, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                Text(localized(subtitleKey))
                    .font(.custom("Beiruti-Medium", size: 14.0, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, PPSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func retryStateView(
        icon: String,
        titleKey: String,
        subtitleKey: String
    ) -> some View {
        VStack(spacing: PPSpace.lg) {
            stickerStateView(
                icon: icon,
                titleKey: titleKey,
                subtitleKey: subtitleKey,
                showsProgress: false
            )
            Button {
                store.refreshStickers(force: true)
            } label: {
                Label(localized("chat_stickers_retry"), systemImage: "arrow.clockwise")
                    .font(.custom("Beiruti-Bold", size: 15.0, relativeTo: .body))
                    .padding(.horizontal, PPSpace.lg)
                    .frame(height: 44.0)
            }
            .buttonStyle(PPStickerRetryButtonStyle(reduceMotion: reduceMotion))
            .padding(.bottom, PPSpace.xl)
        }
    }

    private var sheetBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
            Rectangle()
                .fill(
                    Color(
                        uiColor: UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark
                                ? UIColor(red: 0.080, green: 0.086, blue: 0.092, alpha: 0.90)
                                : UIColor(red: 0.990, green: 0.985, blue: 0.968, alpha: 0.92)
                        }
                    )
                )
        }
        .ignoresSafeArea()
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct PPStickerPickerItem: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sticker: PPChatSticker
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                            .fill(Color.ppStickerFieldSurface.opacity(0.66))
                    }

                AppRemoteImage(
                    urlString: sticker.downloadURLString,
                    cacheKey: sticker.cacheKey,
                    displaySize: CGSize(width: 96, height: 96),
                    contentMode: .fit,
                    showsRetryAction: false
                ) {
                    ProgressView()
                        .tint(Color.ppStickerAccent)
                } failurePlaceholder: {
                    Image(systemName: "photo")
                        .font(.system(size: 20.0, weight: .semibold))
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .padding(PPSpace.sm)
            }
            .aspectRatio(1.0, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 18.0, style: .continuous))
        }
        .buttonStyle(PPStickerItemButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(NSLocalizedString("chat_stickers_send_accessibility", comment: "")))
    }
}

private struct PPStickerIconButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ppStickerAccent)
            .background(Color.ppStickerFieldSurface, in: Circle())
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.94 : 1.0))
            .opacity(configuration.isPressed ? 0.76 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct PPStickerRetryButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Color.ppStickerAccent, in: Capsule(style: .continuous))
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .opacity(configuration.isPressed ? 0.84 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct PPStickerItemButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.965 : 1.0))
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.06 : 0.10),
                radius: configuration.isPressed ? 6.0 : 12.0,
                x: 0.0,
                y: configuration.isPressed ? 2.0 : 6.0
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct PPStickerSheetPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

// MARK: - Messaging sticker stage

/// Selection is local presentation state. Only `commit` hands the original
/// PPChatSticker to the existing message pipeline, once per presentation.
struct PPMessageStickerStage: View {
    @ObservedObject private var store = PPStickerStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedID: String?
    @State private var lift: CGSize = .zero
    @State private var isArmed = false
    @State private var didHandOff = false
    @State private var isVisible = false
    @AccessibilityFocusState private var previewFocused: Bool

    let onSelect: (PPChatSticker) -> Void

    private var selected: PPChatSticker? { store.stickers.first { $0.id == selectedID } }
    private var spring: Animation? { reduceMotion ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.82) }

    var body: some View {
        ScrollViewReader { scrollProxy in
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            VStack(spacing: 16) {
                                header
                                if !store.stickers.isEmpty {
                                    if store.phase == .offline || store.phase == .failed { retainedBanner }
                                    stage(size: 128)
                                    collectionContent
                                } else { emptyContent }
                            }
                            .padding(.bottom, 20)
                        }
                    } else {
                        header
                        if !store.stickers.isEmpty {
                            if store.phase == .offline || store.phase == .failed { retainedBanner }
                            if geometry.size.width > 640 {
                                HStack(alignment: .top, spacing: 24) {
                                    ScrollView {
                                        stage(size: min(240, geometry.size.height * 0.40))
                                    }
                                    .frame(width: geometry.size.width * 0.42)
                                    collection
                                }
                            } else {
                                ScrollView {
                                    VStack(spacing: 16) {
                                        stage(size: max(112, min(200, geometry.size.height * 0.27)))
                                        collectionContent
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                        } else { ScrollView { emptyContent } }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // Keep the viewport stable when the first sticker is picked.
                    if !store.stickers.isEmpty { sendEdge }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.ppBackground.ignoresSafeArea())
            }
            .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: Language.currentLanguageCode() ?? "en"))
            .modifier(PPStickerStagePresentation())
            .interactiveDismissDisabled(didHandOff)
            .onAppear {
                isVisible = true
                store.refreshStickers(force: false)
            }
            .onDisappear {
                isVisible = false
                lift = .zero
                isArmed = false
            }
            .onChange(of: store.stickers.map(\.id)) { ids in
                if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
            }
            .onChange(of: scenePhase) { phase in
                guard phase != .active else { return }
                lift = .zero
                isArmed = false
                if didHandOff { dismiss() }
            }
            .onChange(of: reduceMotion) { _ in
                lift = .zero
                isArmed = false
            }
            .task(id: didHandOff) {
                guard didHandOff else { return }
                if !reduceMotion {
                    do { try await Task.sleep(nanoseconds: 180_000_000) }
                    catch { return }
                }
                guard !Task.isCancelled, isVisible else { return }
                dismiss()
            }
            .task(id: selectedID) {
                guard let selection = selectedID else { return }
                // Defer scrolling out of the synchronous selection update.
                // A rapid second selection cancels this work instead of racing it.
                await Task.yield()
                guard !Task.isCancelled, isVisible, !didHandOff,
                      scenePhase == .active, selectedID == selection else { return }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrollProxy.scrollTo("sticker.stage", anchor: .top)
                }
                await Task.yield()
                guard !Task.isCancelled, isVisible, !didHandOff,
                      scenePhase == .active, selectedID == selection else { return }
                if UIAccessibility.isVoiceOverRunning { previewFocused = true }
            }
            .accessibilityIdentifier("pp.messaging.sticker-stage")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(copy("chat_sticker_stage_title"))
                    .font(.custom("Beiruti-Bold", size: 30, relativeTo: .title))
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(copy("chat_sticker_stage_subtitle"))
                    .font(.custom("Beiruti-Regular", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.refreshStickers(force: true) } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(store.isRefreshing || didHandOff)
            .accessibilityLabel(copy("chat_stickers_retry"))
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(didHandOff)
            .accessibilityLabel(copy("Close"))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ppTextPrimary)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func stage(size: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack {
                // The open arc is the lift target, filled only by direct input.
                Circle()
                    .trim(from: 0.08, to: 0.42)
                    .stroke(Color.ppSurfaceBorder, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: size + 24, height: size + 24)
                Circle()
                    .trim(from: 0.08, to: 0.08 + 0.34 * min(max(-lift.height / 88, 0), 1))
                    .stroke(Color.ppPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: size + 24, height: size + 24)

                if let selected {
                    stickerArtwork(selected, size: size, retryable: true)
                        .id(selected.id)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(lift.width / 10)), axis: (x: 0, y: 1, z: 0))
                        .rotationEffect(.degrees(reduceMotion ? 0 : Double(lift.width / 18)))
                        .scaleEffect(reduceMotion ? 1 : (isArmed ? 1.06 : 1))
                        .offset(x: reduceMotion ? 0 : lift.width * 0.28, y: reduceMotion ? 0 : lift.height * 0.42)
                        .offset(y: didHandOff && !reduceMotion ? -size : 0)
                        .opacity(didHandOff ? 0 : 1)
                        .gesture(liftGesture)
                        .accessibilityLabel(stickerName(selected))
                        .accessibilityHint(copy("chat_sticker_stage_preview_hint"))
                        .accessibilityAction(named: Text(copy("chat_sticker_stage_send"))) { commit() }
                        .accessibilityFocused($previewFocused)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 44, weight: .ultraLight))
                        Text(copy("chat_sticker_stage_pick"))
                            .font(.custom("Beiruti-Medium", size: 16, relativeTo: .body))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Color.ppTextSecondary)
                    .frame(width: size, height: size)
                }
            }
            .frame(height: size + 32)
            .frame(maxWidth: .infinity)
            // Animate only the preview. The lazy grid keeps its own image identity.
            .animation(spring, value: selectedID)
            .padding(.top, 12)
            .accessibilityElement(children: .contain)

            if let selected {
                Text(stickerName(selected))
                    .font(.custom("Beiruti-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                Text(copy(isArmed ? "chat_sticker_stage_release" : "chat_sticker_stage_lift"))
                    .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .id("sticker.stage")
    }

    private var collection: some View {
        ScrollView { collectionContent.padding(.bottom, 20) }
    }

    private var collectionContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 128 : 88), spacing: 12)], spacing: 16) {
            ForEach(store.stickers) { sticker in
                Button { select(sticker) } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            // Never transfer a live image loader between the lazy
                            // grid and the preview during a scroll/layout update.
                            stickerArtwork(sticker, size: 80, retryable: false)
                            if selectedID == sticker.id {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.ppPrimary, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                                    .padding(4)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(height: 96)
                        Text(selectedID == sticker.id ? copy("chat_sticker_stage_selected") : stickerName(sticker))
                            .font(.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                            .foregroundStyle(Color.ppTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PPStickerStagePressStyle())
                .disabled(didHandOff)
                .accessibilityLabel(stickerName(sticker))
                .accessibilityValue(selectedID == sticker.id ? copy("chat_sticker_stage_selected") : "")
                .accessibilityHint(copy("chat_sticker_stage_preview_hint"))
                .accessibilityIdentifier("pp.sticker.preview.\(sticker.id)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var sendEdge: some View {
        Button(action: commit) {
            HStack(spacing: 12) {
                Text(copy(didHandOff ? "chat_sticker_stage_handoff" : "chat_sticker_stage_send"))
                    .font(.custom("Beiruti-Bold", size: 18, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .background(Color.ppBackground)
            .overlay(alignment: .top) { Rectangle().fill(Color.ppPrimary).frame(height: 2) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PPStickerStagePressStyle())
        .disabled(selected == nil || didHandOff)
        .opacity(selected == nil ? 0.45 : 1)
        .accessibilityIdentifier("pp.sticker.send")
    }

    private var retainedBanner: some View {
        Label(copy(store.phase == .offline ? "chat_stickers_offline_cached" : "chat_sticker_stage_retained"), systemImage: "wifi.slash")
            .font(.custom("Beiruti-Medium", size: 14, relativeTo: .subheadline))
            .foregroundStyle(Color.ppTextSecondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyContent: some View {
        VStack(spacing: 20) {
                if store.phase == .loading || store.phase == .idle {
                    ProgressView().tint(Color.ppPrimary)
                    Text(copy("chat_stickers_loading_title"))
                } else {
                    Image(systemName: store.phase == .offline ? "wifi.slash" : "face.smiling")
                        .font(.system(size: 40, weight: .light))
                        .accessibilityHidden(true)
                    Text(copy(store.phase == .empty ? "chat_stickers_empty_title" : "chat_stickers_error_title"))
                    Text(copy(store.phase == .empty ? "chat_sticker_stage_empty_detail" : "chat_stickers_error_subtitle"))
                        .font(.custom("Beiruti-Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(Color.ppTextSecondary)
                    Button { store.refreshStickers(force: true) } label: {
                        Label(copy("chat_stickers_retry"), systemImage: "arrow.clockwise")
                            .frame(minHeight: 44)
                    }
                    .disabled(store.isRefreshing)
                }
            }
            .font(.custom("Beiruti-SemiBold", size: 20, relativeTo: .title3))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.ppTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(32)
            .padding(.top, 32)
    }

    private func stickerArtwork(_ sticker: PPChatSticker, size: CGFloat, retryable: Bool) -> some View {
        AppRemoteImage(
            urlString: sticker.downloadURLString,
            cacheKey: sticker.cacheKey,
            displaySize: CGSize(width: size, height: size),
            contentMode: .fit,
            showsRetryAction: retryable
        ) {
            ProgressView().tint(Color.ppPrimary)
        } failurePlaceholder: {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.ppTextSecondary)
        }
        .frame(width: size, height: size)
    }

    private var liftGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !didHandOff, scenePhase == .active else { return }
                lift = CGSize(width: min(max(value.translation.width, -80), 80), height: min(max(value.translation.height, -160), 24))
                let armed = value.translation.height < -88 && abs(value.translation.width) < 100
                if armed && !isArmed { UISelectionFeedbackGenerator().selectionChanged() }
                isArmed = armed
            }
            .onEnded { value in
                if isArmed && value.translation.height < -88 && abs(value.translation.width) < 100 {
                    commit()
                }
                withAnimation(spring) { lift = .zero; isArmed = false }
            }
    }

    private func select(_ sticker: PPChatSticker) {
        guard !didHandOff, selectedID != sticker.id else { return }
        previewFocused = false
        selectedID = sticker.id
        lift = .zero
        isArmed = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func commit() {
        guard !didHandOff, isVisible, scenePhase == .active, let selected else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { didHandOff = true }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        onSelect(selected)
    }

    private func stickerName(_ sticker: PPChatSticker) -> String {
        let raw = sticker.displayName.removingPercentEncoding ?? sticker.displayName
        let name = (raw as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? copy("chat_sticker_stage_unnamed") : name
    }

    private func copy(_ key: String) -> String {
        Language.get(key, alter: key) ?? NSLocalizedString(key, comment: "")
    }
}

private struct PPStickerStagePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

private struct PPStickerStagePresentation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.large]).presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
