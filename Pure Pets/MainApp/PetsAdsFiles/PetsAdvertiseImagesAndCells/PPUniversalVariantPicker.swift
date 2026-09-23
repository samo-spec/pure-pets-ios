import SwiftUI
import UIKit

/// The universal card supplies only a family member. The established viewer
/// store resolves every option and owns the selected product's cart mutations.
@available(iOS 16.0, *)
struct PPUniversalVariantPicker: UIViewControllerRepresentable {
    let accessory: PetAccessory
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIViewController {
        PPUniversalVariantPickerController(accessory: accessory) {
            dismiss()
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        (uiViewController as? PPUniversalVariantPickerController)?.finish()
    }
}

@available(iOS 16.0, *)
@MainActor
private final class PPUniversalVariantPickerController: UIViewController {
    private let accessory: PetAccessory
    private let close: () -> Void
    private var store: PPAccessoryViewerStore?
    private var loadTask: Task<Void, Never>?

    init(accessory: PetAccessory, close: @escaping () -> Void) {
        self.accessory = accessory
        self.close = close
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let store = PPAccessoryViewerStore(
            accessory: accessory, presenter: self, contentScope: .quickAdd
        )
        self.store = store
        let host = UIHostingController(rootView: PPUniversalVariantPickerContent(
            store: store,
            close: { [weak self] in
                guard let self, self.store?.cartPhase != .processing else { return }
                self.close()
            },
            mutationChanged: { [weak self] busy in
                self?.setDismissalBlocked(busy)
            }
        ))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        loadTask = Task { await store.load() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if store?.snapshot != nil { store?.resume() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store?.pause()
    }

    private func setDismissalBlocked(_ blocked: Bool) {
        var controller: UIViewController = self
        controller.isModalInPresentation = blocked
        while let parent = controller.parent {
            controller = parent
            controller.isModalInPresentation = blocked
        }
    }

    func finish() {
        loadTask?.cancel()
        loadTask = nil
        store?.finishQuickAdd()
        setDismissalBlocked(false)
    }
}

@available(iOS 16.0, *)
private struct PPUniversalVariantPickerContent: View {
    @ObservedObject var store: PPAccessoryViewerStore
    let close: () -> Void
    let mutationChanged: (Bool) -> Void

    @State private var mutationPending = false
    @State private var mutationError: String?
    @Environment(\.scenePhase) private var scenePhase

    private var isMutating: Bool {
        mutationPending || store.cartPhase == .processing
    }

    private var canAdd: Bool {
        store.isVariantSelectionConfirmed && store.isPurchaseDataCurrent &&
            store.snapshot?.isAvailableForPurchase == true &&
            store.snapshot?.showsCart == true && store.remainingStock > 0 && !isMutating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    switch store.phase {
                    case .loading:
                        ProgressView(PPAccessoryViewerL10n.text("accessory_view_options_loading"))
                            .frame(maxWidth: .infinity, minHeight: 160)
                    case let .failed(message):
                        recovery(message, retry: store.retry)
                    case .loaded:
                        if let snapshot = store.snapshot {
                            content(snapshot)
                        }
                    }
                }
                .font(PPAccessoryTypography.body)
                .foregroundStyle(PPAccessoryPalette.ink)
                .frame(maxWidth: 720, alignment: .leading)
                .padding(PPSpace.lg)
                .frame(maxWidth: .infinity)
            }
            .background(PPAccessoryPalette.appBackground)
            .navigationTitle(PPAccessoryViewerL10n.text("accessory_view_options_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(PPAccessoryViewerL10n.text("Done"), action: close)
                        .disabled(isMutating)
                }
            }
        }
        .tint(PPAccessoryPalette.brand)
        .environment(\.layoutDirection, PPAccessoryViewerLegacyBridge.isRTL() ? .rightToLeft : .leftToRight)
        .interactiveDismissDisabled(isMutating)
        .onChange(of: isMutating, perform: mutationChanged)
        .onChange(of: store.snapshot?.id) { _ in mutationError = nil }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.resume() }
            else if phase == .background { store.pause() }
        }
    }

    @ViewBuilder
    private func content(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(snapshot.title)
                .font(PPAccessoryTypography.title)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(snapshot.price)
                .font(PPAccessoryTypography.price)
                .fixedSize(horizontal: false, vertical: true)
        }

        PPAccessoryVariantSelectorSection(
            store: store, snapshot: snapshot, compact: true, showsDeliveryContext: false
        )
            .disabled(isMutating)

        if store.variantsPhase == .empty && !store.isVariantSelectionConfirmed {
            recovery(PPAccessoryViewerL10n.text("accessory_view_options_empty_axis"), retry: store.retryVariants)
        }

        if store.livePhase == .refreshing {
            ProgressView(PPAccessoryViewerL10n.text("accessory_view_options_check_availability"))
        } else if store.livePhase == .stale {
            recovery(PPAccessoryViewerL10n.text("accessory_view_live_data_stale"), retry: store.retryLiveUpdates)
        }

        if snapshot.showsCart {
            cartControls(snapshot)
        }

        if let message = mutationError ?? store.bannerMessage {
            Text(message)
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pp.universal.variant.feedback")
        }
    }

    @ViewBuilder
    private func cartControls(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            if store.cartQuantity > 0 {
                // The binding belongs to the currently loaded sellable product,
                // never the family total shown on the card behind this sheet.
                Stepper(
                    value: Binding(get: { store.cartQuantity }, set: updateCartQuantity),
                    in: 0...max(store.cartQuantity, canAdd ? snapshot.quantity : 0)
                ) {
                    Text(PPAccessoryViewerL10n.formatted(
                        "universal_variant_cart_quantity_format",
                        PPAccessoryViewerL10n.integer(store.cartQuantity)
                    ))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(isMutating || store.switchingVariantProductId != nil)
                .accessibilityIdentifier("pp.universal.variant.cartQuantity")

                Button(role: .destructive) { updateCartQuantity(0) } label: {
                    Label(PPAccessoryViewerL10n.text("a11y_btn_remove_cart_item"), systemImage: "trash")
                        .frame(minHeight: 44)
                }
                .disabled(isMutating || store.switchingVariantProductId != nil)
            } else {
                Stepper(
                    value: Binding(
                        get: { store.quantity },
                        set: { value in
                            if value > store.quantity { store.incrementQuantity() }
                            else if value < store.quantity { store.decrementQuantity() }
                        }
                    ),
                    in: 1...max(store.remainingStock, 1)
                ) {
                    Text(PPAccessoryViewerL10n.formatted("accessory_view_quantity_format", store.quantity))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!canAdd)

                Button(action: addToCart) {
                    HStack(spacing: PPSpace.sm) {
                        if isMutating { ProgressView() }
                        Text(PPAccessoryViewerL10n.text(isMutating ? "accessory_view_adding_to_cart" : "addToCart"))
                            .font(PPAccessoryTypography.bodyBold)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
                .accessibilityIdentifier("pp.universal.variant.add")
            }

            if snapshot.isUnavailable {
                Text(PPAccessoryViewerL10n.text("accessory_view_item_unavailable"))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                if snapshot.canRequestStockNotification && store.isVariantSelectionConfirmed {
                    Button(PPAccessoryViewerL10n.text(
                        store.stockNotificationPhase == .success ? "stock_notify_already_registered" : "notify_me"
                    ), action: store.registerStockNotification)
                    .frame(minHeight: 44)
                    .disabled(store.stockNotificationPhase == .processing || isMutating)
                }
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppForeground, in: RoundedRectangle(cornerRadius: PPCorner.card))
    }

    private func recovery(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(message).fixedSize(horizontal: false, vertical: true)
            Button(PPAccessoryViewerL10n.text("Retry"), action: retry)
                .frame(minHeight: 44)
                .disabled(isMutating)
        }
    }

    private func addToCart() {
        guard canAdd else { return }
        mutationPending = true
        mutationError = nil
        store.dismissBanner()
        Task { @MainActor in
            defer { mutationPending = false }
            do {
                _ = try await store.addToCartAsync()
                announceCartQuantity()
            } catch is CancellationError {
                // The existing auth/provider-switch presentation owns cancellation.
            } catch {
                mutationError = store.bannerMessage ?? PPAccessoryViewerL10n.text("accessory_view_add_failed")
            }
        }
    }

    private func updateCartQuantity(_ value: Int) {
        guard !isMutating, store.switchingVariantProductId == nil else { return }
        mutationPending = true
        mutationError = nil
        store.dismissBanner()
        Task { @MainActor in
            defer { mutationPending = false }
            do {
                _ = try await store.updateCartQuantity(value)
                announceCartQuantity()
            } catch {
                mutationError = PPAccessoryViewerL10n.text("accessory_view_cart_quantity_update_failed")
            }
        }
    }

    private func announceCartQuantity() {
        UIAccessibility.post(notification: .announcement, argument: PPAccessoryViewerL10n.formatted(
            "universal_variant_cart_quantity_format", PPAccessoryViewerL10n.integer(store.cartQuantity)
        ))
    }
}
