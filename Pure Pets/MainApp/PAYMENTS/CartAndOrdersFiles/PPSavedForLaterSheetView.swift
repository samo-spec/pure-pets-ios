//
//  PPSavedForLaterSheetView.swift
//  Pure Pets
//
//  SwiftUI content for the saved-for-later sheet. The saved/cart
//  managers and cart refresh callbacks remain owned by PPSavedForLaterBottomSheetVC.
//

import SwiftUI
import UIKit

@objc(PPSavedForLaterSheetContentControllerDelegate)
public protocol PPSavedForLaterSheetContentControllerDelegate: AnyObject {
    @objc(savedForLaterSheetContentControllerDidRequestDismiss:)
    func savedForLaterSheetContentControllerDidRequestDismiss(_ controller: PPSavedForLaterSheetContentController)

    @objc(savedForLaterSheetContentControllerDidRequestRetry:)
    func savedForLaterSheetContentControllerDidRequestRetry(_ controller: PPSavedForLaterSheetContentController)

    @objc(savedForLaterSheetContentController:didRequestMoveToCart:)
    func savedForLaterSheetContentController(
        _ controller: PPSavedForLaterSheetContentController,
        didRequestMoveToCart item: CartItem
    )

    @objc(savedForLaterSheetContentController:didRequestRemove:)
    func savedForLaterSheetContentController(
        _ controller: PPSavedForLaterSheetContentController,
        didRequestRemove item: CartItem
    )

    @objc(savedForLaterSheetContentController:didRequestNotifyWhenAvailable:)
    func savedForLaterSheetContentController(
        _ controller: PPSavedForLaterSheetContentController,
        didRequestNotifyWhenAvailable item: CartItem
    )
}

@objc(PPSavedForLaterSheetContentController)
public final class PPSavedForLaterSheetContentController: UIViewController {
    @objc public weak var delegate: PPSavedForLaterSheetContentControllerDelegate?

    private let store = PPSavedForLaterSheetStore()
    private var hostingController: UIHostingController<PPSavedForLaterSheetRootView>?

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isOpaque = false
        view.clipsToBounds = false

        let rootView = PPSavedForLaterSheetRootView(
            store: store,
            onDismiss: { [weak self] in
                guard let self else { return }
                self.delegate?.savedForLaterSheetContentControllerDidRequestDismiss(self)
            },
            onRetry: { [weak self] in
                guard let self else { return }
                self.delegate?.savedForLaterSheetContentControllerDidRequestRetry(self)
            },
            onMoveToCart: { [weak self] item in
                guard let self else { return }
                self.store.beginPending(item: item, operation: .move)
                self.delegate?.savedForLaterSheetContentController(self, didRequestMoveToCart: item)
            },
            onRemove: { [weak self] item in
                guard let self else { return }
                self.delegate?.savedForLaterSheetContentController(self, didRequestRemove: item)
            },
            onNotifyWhenAvailable: { [weak self] item in
                guard let self else { return }
                self.store.beginPending(item: item, operation: .notify)
                self.delegate?.savedForLaterSheetContentController(self, didRequestNotifyWhenAvailable: item)
            }
        )

        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        //controller.view.backgroundColor = .clear
        controller.view.isOpaque = false

        addChild(controller)
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    @objc(configureWithSavedItems:animated:)
    public func configure(savedItems: [CartItem], animated: Bool) {
        store.setItems(savedItems, animated: animated)
    }

    @objc(setLoading:)
    public func setLoading(_ loading: Bool) {
        store.setLoading(loading)
    }

    @objc(setPendingItemID:operation:)
    public func setPendingItemID(_ itemID: String?, operation: String?) {
        store.setPendingItemID(itemID, operation: operation.flatMap(PPSavedForLaterPendingOperation.init(rawValue:)))
    }

    @objc(showStatusMessage:success:)
    public func showStatusMessage(_ message: String, success: Bool) {
        store.showStatus(message, kind: success ? .success : .error)
    }

    @objc(markMoveSucceededForItemID:)
    public func markMoveSucceeded(for itemID: String) {
        store.markCompleted(itemID: itemID, operation: .move)
    }

    @objc(showErrorMessage:)
    public func showErrorMessage(_ message: String) {
        store.showError(message)
    }
}

// MARK: - State

enum PPSavedForLaterPresentation: Equatable {
    case loading
    case content
    case empty
    case error(String)
}

enum PPSavedForLaterPendingOperation: String {
    case move
    case remove
    case notify
}

enum PPSavedForLaterStatusKind {
    case success
    case error
}

final class PPSavedForLaterSheetStore: ObservableObject {
    @Published private(set) var items: [CartItem] = []
    @Published private(set) var presentation: PPSavedForLaterPresentation = .loading
    @Published private(set) var pendingItemID: String?
    @Published private(set) var pendingOperation: PPSavedForLaterPendingOperation?
    @Published private(set) var completedItemID: String?
    @Published private(set) var completedOperation: PPSavedForLaterPendingOperation?
    @Published private(set) var hasEntered = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusKind: PPSavedForLaterStatusKind = .success

    private var statusToken = UUID()
    private var completionToken = UUID()

    var countText: String {
        String(
            format: ppLocalized("saved_for_later_count_format", fallback: "%ld saved"),
            items.count
        )
    }

    var itemsSignature: String {
        items.map(\.ppSavedStableID).joined(separator: "|")
    }

    func setItems(_ newItems: [CartItem], animated: Bool) {
        let apply = {
            self.items = newItems
            self.presentation = newItems.isEmpty ? .empty : .content
        }

        if animated && !UIAccessibility.isReduceMotionEnabled {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                apply()
            }
        } else {
            apply()
        }
    }

    func setLoading(_ loading: Bool) {
        guard loading else { return }
        presentation = .loading
    }

    func activateEntrance(reduceMotion: Bool) {
        guard !hasEntered else { return }
        if reduceMotion {
            hasEntered = true
        } else {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                hasEntered = true
            }
        }
    }

    func beginPending(item: CartItem, operation: PPSavedForLaterPendingOperation) {
        pendingItemID = item.ppSavedStableID
        pendingOperation = operation
        clearCompleted()
    }

    func setPendingItemID(_ itemID: String?, operation: PPSavedForLaterPendingOperation?) {
        let cleanItemID = itemID?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingItemID = cleanItemID?.isEmpty == false ? cleanItemID : nil
        pendingOperation = operation
        if pendingItemID != nil {
            clearCompleted()
        }
    }

    func markCompleted(itemID: String, operation: PPSavedForLaterPendingOperation) {
        let cleanItemID = itemID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanItemID.isEmpty else { return }

        let apply = {
            self.completedItemID = cleanItemID
            self.completedOperation = operation
        }

        if UIAccessibility.isReduceMotionEnabled {
            apply()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                apply()
            }
        }

        let token = UUID()
        completionToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { [weak self] in
            guard let self, self.completionToken == token else { return }
            self.clearCompleted()
        }
    }

    func clearCompleted() {
        let apply = {
            self.completedItemID = nil
            self.completedOperation = nil
        }
        if UIAccessibility.isReduceMotionEnabled {
            apply()
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                apply()
            }
        }
    }

    func showStatus(_ message: String, kind: PPSavedForLaterStatusKind) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return }

        statusKind = kind
        statusMessage = cleanMessage

        switch kind {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        let token = UUID()
        statusToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.statusToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                self.statusMessage = nil
            }
        }
    }

    func showError(_ message: String) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if items.isEmpty {
            presentation = .error(cleanMessage.isEmpty ? ppLocalized("SomethingWentWrong", fallback: "Something went wrong") : cleanMessage)
        } else {
            showStatus(cleanMessage.isEmpty ? ppLocalized("SomethingWentWrong", fallback: "Something went wrong") : cleanMessage, kind: .error)
        }
    }
}

// MARK: - Root View

struct PPSavedForLaterSheetRootView: View {
    @ObservedObject var store: PPSavedForLaterSheetStore

    let onDismiss: () -> Void
    let onRetry: () -> Void
    let onMoveToCart: (CartItem) -> Void
    let onRemove: (CartItem) -> Void
    let onNotifyWhenAvailable: (CartItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var sheetShape: PPSavedForLaterTopRoundedShape {
        PPSavedForLaterTopRoundedShape(radius: 34)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 24)
                    .opacity(store.hasEntered ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (store.hasEntered ? 0 : 10))

                stateContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(store.hasEntered ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (store.hasEntered ? 0 : 14))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground)
            .clipShape(sheetShape)
            .overlay(sheetBorder)
            .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)

            statusToast
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .allowsHitTesting(false)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .onAppear {
            store.activateEntrance(reduceMotion: reduceMotion)
        }
    }

    private var sheetBackground: some View {
        Color.clear
            .allowsHitTesting(false)
    }

    private var sheetBorder: some View {
        sheetShape
            .stroke(
                Color(uiColor: .separator).opacity(colorScheme == .dark ? 0.34 : 0.22),
                lineWidth: 0.75
            )
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                iconMark

                VStack(alignment: .leading, spacing: 4) {
                    Text(ppLocalized("saved_for_later", fallback: "Saved for later"))
                        .font(.custom("Beiruti-Bold", size: 28, relativeTo: .title2))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(store.countText)
                        .font(.custom("Beiruti-Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.ppTextSecondary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .separator).opacity(0.20), lineWidth: 0.75)
                        )
                }
                .buttonStyle(PPSavedForLaterPressButtonStyle())
                .accessibilityLabel(ppLocalized("saved_for_later_close_accessibility", fallback: "Close saved items"))
                .accessibilityHint(ppLocalized("Swipe_Down_To_Close", fallback: "Swipe down to close"))
            }

            Text(ppLocalized("choose_items_to_move", fallback: "Choose items to move to cart"))
                .font(.custom("Beiruti-Medium", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var iconMark: some View {
        ZStack {
            Circle()
                .fill(Color.ppPrimary.opacity(colorScheme == .dark ? 0.18 : 0.12))
            Circle()
                .stroke(Color.ppPrimary.opacity(0.20), lineWidth: 0.75)
            Image(systemName: "bookmark.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch store.presentation {
        case .loading:
            PPSavedForLaterLoadingView()
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.opacity)
        case .empty:
            PPSavedForLaterEmptyView(onDismiss: onDismiss)
                .padding(.horizontal, 24)
                .padding(.top, 38)
                .transition(.opacity)
        case .error(let message):
            PPSavedForLaterErrorView(message: message, onRetry: onRetry)
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .transition(.opacity)
        case .content:
            itemList
                .transition(.opacity)
        }
    }

    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(store.items, id: \.ppSavedStableID) { item in
                    PPSavedForLaterItemRow(
                        item: item,
                        isPending: store.pendingItemID == item.ppSavedStableID,
                        isLockedByOtherItem: store.pendingItemID != nil && store.pendingItemID != item.ppSavedStableID,
                        isCompletingMove: store.completedItemID == item.ppSavedStableID && store.completedOperation == .move,
                        pendingOperation: store.pendingOperation,
                        onMoveToCart: onMoveToCart,
                        onRemove: onRemove,
                        onNotifyWhenAvailable: onNotifyWhenAvailable
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.985))
                        )
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.32, dampingFraction: 0.90),
            value: store.itemsSignature
        )
    }

    @ViewBuilder
    private var statusToast: some View {
        if let message = store.statusMessage {
            HStack(spacing: 9) {
                Image(systemName: store.statusKind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.statusKind == .success ? Color.ppSuccess : Color.ppError)
                Text(message)
                    .font(.custom("Beiruti-Bold", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color(uiColor: .separator).opacity(0.20), lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 18, y: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Rows
// Row views extracted to PPSavedForLaterItemRow.swift

// MARK: - States

private struct PPSavedForLaterLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(uiColor: .systemFill))
                            .frame(width: 78, height: 78)

                        VStack(alignment: .leading, spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .systemFill))
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemFill))
                                .frame(width: 128, height: 12)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(width: 104, height: 12)
                        }
                        .padding(.top, 3)
                    }

                    HStack(spacing: 10) {
                        Capsule()
                            .fill(Color(uiColor: .systemFill))
                            .frame(maxWidth: .infinity, minHeight: 48)

                        Circle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(width: 48, height: 48)
                    }
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72))
                    )
                }
                .padding(12)
                .background(Color.ppCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ppLocalized("saved_for_later_loading", fallback: "Loading saved items"))
    }
}

private struct PPSavedForLaterEmptyView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.12))
                Image(systemName: "bookmark.slash")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .frame(width: 82, height: 82)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(ppLocalized("saved_for_later_empty_title", fallback: "Nothing saved yet"))
                    .font(.custom("Beiruti-Bold", size: 22, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(ppLocalized("saved_for_later_empty_message", fallback: "Items you save from the marketplace will wait here until you are ready to buy."))
                    .font(.custom("Beiruti-Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onDismiss) {
                Text(ppLocalized("KLang_Close", fallback: "Close"))
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PPSavedForLaterPrimaryTextButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct PPSavedForLaterErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.ppError.opacity(0.12))
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.ppError)
            }
            .frame(width: 78, height: 78)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(ppLocalized("SomethingWentWrong", fallback: "Something went wrong"))
                    .font(.custom("Beiruti-Bold", size: 22, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message.isEmpty ? ppLocalized("saved_for_later_retry_message", fallback: "We could not refresh your saved items. Please try again.") : message)
                    .font(.custom("Beiruti-Medium", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onRetry) {
                Label(ppLocalized("KLang_Retry", fallback: "Retry"), systemImage: "arrow.clockwise")
                    .font(.custom("Beiruti-Bold", size: 15, relativeTo: .body))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PPSavedForLaterPrimaryTextButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Image

final class PPSavedForLaterImageView: UIImageView {
    var representedURLString = ""
    var isShowingPlaceholder = true {
        didSet {
            pp_applyProductContentMode()
        }
    }

    override var image: UIImage? {
        didSet {
            pp_applyProductContentMode()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pp_applyProductContentMode()
    }

    func pp_applyProductContentMode() {
        contentMode = .scaleAspectFill
        layer.contentsGravity = .resizeAspectFill
    }
}

struct PPSavedForLaterRemoteImage: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> PPSavedForLaterImageView {
        let imageView = PPSavedForLaterImageView()
        imageView.clipsToBounds = true
        imageView.isShowingPlaceholder = true
        imageView.backgroundColor = .clear
        imageView.tintColor = UIColor(named: "AppPrimaryColor") ?? .systemBlue
        imageView.isAccessibilityElement = false
        return imageView
    }

    func updateUIView(_ imageView: PPSavedForLaterImageView, context: Context) {
        imageView.pp_applyProductContentMode()

        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageView.representedURLString != trimmedURLString else { return }

        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        imageView.representedURLString = trimmedURLString

        let placeholder = UIImage(named: "placeholder")
            ?? UIImage(systemName: "bag.fill")?.withRenderingMode(.alwaysTemplate)
        imageView.isShowingPlaceholder = true
        imageView.image = placeholder

        guard !trimmedURLString.isEmpty else {
            imageView.pp_applyProductContentMode()
            return
        }

        let expectedURLString = trimmedURLString
        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: trimmedURLString,
            placeholder: placeholder,
            transitionStyle: .crossDissolve,
            completion: { [weak imageView] image, _ in
                guard let imageView, imageView.representedURLString == expectedURLString else { return }
                imageView.isShowingPlaceholder = image == nil
                imageView.pp_applyProductContentMode()
            }
        )
    }

    static func dismantleUIView(_ imageView: PPSavedForLaterImageView, coordinator: Void) {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        imageView.representedURLString = ""
        imageView.isShowingPlaceholder = true
    }
}

// MARK: - Styling

private struct PPSavedForLaterTopRoundedShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct PPSavedForLaterPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.965 : 1))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct PPSavedForLaterPrimaryTextButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(Color.ppPrimary, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.975 : 1))
            .animation(.spring(response: 0.18, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

// MARK: - Helpers

func ppLocalized(_ key: String, fallback: String) -> String {
    let value = Language.get(key, alter: fallback) ?? fallback
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || trimmed == key ? fallback : value
}

extension CartItem {
    var ppSavedStableID: String {
        let cleanID = (itemID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanID.isEmpty {
            return cleanID
        }
        return String(ObjectIdentifier(self).hashValue)
    }

    var ppDisplayName: String {
        let cleanName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? ppLocalized("saved_for_later_unknown_item", fallback: "Saved item") : cleanName
    }

    var ppImageURL: String {
        (imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var ppHasDiscount: Bool {
        originalPrice > price && price > 0
    }

    var ppFormattedPrice: String {
        String(format: "%.2f %@", price, ppLocalized("Rials", fallback: "QAR"))
    }

    var ppFormattedOriginalPrice: String {
        String(format: "%.2f %@", originalPrice, ppLocalized("Rials", fallback: "QAR"))
    }
}
