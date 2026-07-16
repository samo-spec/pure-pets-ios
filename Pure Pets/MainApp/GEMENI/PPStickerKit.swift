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

    private let memoryCache = NSCache<NSString, UIImage>()
    private let workQueue = DispatchQueue(label: "com.purepets.chat.stickers.cache", qos: .userInitiated)
    private var inflightDownloads: [String: [(UIImage?) -> Void]] = [:]
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
        let key = cacheKey(storagePath: storagePath, downloadURLString: downloadURLString)
        if let cached = memoryCache.object(forKey: key as NSString) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        let fileURL = cacheFileURL(storagePath: storagePath, downloadURLString: downloadURLString)
        workQueue.async {
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                self.memoryCache.setObject(image, forKey: key as NSString)
                DispatchQueue.main.async { completion(image) }
                return
            }

            if self.inflightDownloads[key] != nil {
                self.inflightDownloads[key]?.append(completion)
                return
            }

            self.inflightDownloads[key] = [completion]

            guard let remoteURL = URL(string: downloadURLString) else {
                self.finishDownload(key: key, image: nil)
                return
            }

            URLSession.shared.dataTask(with: remoteURL) { data, _, _ in
                var image: UIImage?
                if let data,
                   let decoded = UIImage(data: data) {
                    image = decoded
                    self.memoryCache.setObject(decoded, forKey: key as NSString)
                    try? data.write(to: fileURL, options: .atomic)
                }
                self.finishDownload(key: key, image: image)
            }.resume()
        }
    }

    fileprivate func image(
        for sticker: PPChatSticker,
        completion: @escaping (UIImage?) -> Void
    ) {
        imageForSticker(
            storagePath: sticker.storagePath,
            downloadURLString: sticker.downloadURLString,
            completion: completion
        )
    }

    private func finishDownload(key: String, image: UIImage?) {
        workQueue.async {
            let completions = self.inflightDownloads.removeValue(forKey: key) ?? []
            DispatchQueue.main.async {
                completions.forEach { $0(image) }
            }
        }
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
            image(for: sticker) { _ in }
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

    private func cacheKey(storagePath: String, downloadURLString: String) -> String {
        storagePath.isEmpty ? downloadURLString : storagePath
    }

    private func cacheFileURL(storagePath: String, downloadURLString: String) -> URL {
        let key = cacheKey(storagePath: storagePath, downloadURLString: downloadURLString)
        let data = Data(key.utf8)
        var safe = data.base64EncodedString()
        safe = safe
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        let ext = (storagePath as NSString).pathExtension.isEmpty
            ? "png"
            : (storagePath as NSString).pathExtension
        return cacheDirectory.appendingPathComponent("\(safe).\(ext)", isDirectory: false)
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
    @ObservedObject private var store = PPStickerStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sticker: PPChatSticker
    let onSelect: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18.0, style: .continuous)
                            .fill(Color.ppStickerFieldSurface.opacity(0.66))
                    }

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(PPSpace.sm)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.96))
                        )
                } else if isLoading {
                    ProgressView()
                        .tint(Color.ppStickerAccent)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 20.0, weight: .semibold))
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
            .contentShape(RoundedRectangle(cornerRadius: 18.0, style: .continuous))
        }
        .buttonStyle(PPStickerItemButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(Text(NSLocalizedString("chat_stickers_send_accessibility", comment: "")))
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        isLoading = true
        store.image(for: sticker) { image in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.16)) {
                self.image = image
                self.isLoading = false
            }
        }
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
