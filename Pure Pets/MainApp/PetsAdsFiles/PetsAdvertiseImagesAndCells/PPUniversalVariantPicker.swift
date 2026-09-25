import SwiftUI
import UIKit

/// The universal card supplies only a family member. The established viewer
/// store resolves every option and owns the selected product's cart mutations.
@available(iOS 16.0, *)
struct PPUniversalVariantPicker: View {
    let accessory: PetAccessory
    @State private var measuredHeight: CGFloat = 390
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let base = PPUniversalVariantPickerRepresentable(accessory: accessory, onHeightChange: { height in
            if height > 100 && abs(measuredHeight - height) > 2 {
                measuredHeight = height
            }
        }) {
            dismiss()
        }
        .presentationDetents([.height(min(max(measuredHeight, 300), UIScreen.main.bounds.height * 0.88))])
        .presentationDragIndicator(.visible)

        if #available(iOS 16.4, *) {
            base
                .presentationCornerRadius(42)
                .presentationBackground(.ultraThinMaterial)
        } else {
            base
        }
    }
}

@available(iOS 16.0, *)
private struct PPUniversalVariantPickerRepresentable: UIViewControllerRepresentable {
    let accessory: PetAccessory
    let onHeightChange: (CGFloat) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        PPUniversalVariantPickerController(
            accessory: accessory,
            onHeightChange: onHeightChange,
            close: onDismiss
        )
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
    private let onHeightChange: (CGFloat) -> Void
    private let close: () -> Void
    private var store: PPAccessoryViewerStore?
    private var loadTask: Task<Void, Never>?

    init(accessory: PetAccessory, onHeightChange: @escaping (CGFloat) -> Void, close: @escaping () -> Void) {
        self.accessory = accessory
        self.onHeightChange = onHeightChange
        self.close = close
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        if let sheet = self.sheetPresentationController {
            sheet.preferredCornerRadius = 42
            sheet.prefersGrabberVisible = true
        }

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
            },
            onHeightChange: { [weak self] height in
                self?.onHeightChange(height)
            }
        ))
        host.view.backgroundColor = .clear
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
    let onHeightChange: (CGFloat) -> Void

    @State private var mutationPending = false
    @State private var mutationError: String?
    @State private var hasAppeared = false
    @State private var selectPulse = false
    @State private var justAdded = false
    @State private var cartIconBounce = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    switch store.phase {
                    case .loading:
                        loadingState
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
                .padding(.horizontal, PPSpace.lg)
                .padding(.top, PPSpace.xs)
                .padding(.bottom, PPSpace.base)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: PPContentHeightPreferenceKey.self,
                            value: geo.size.height
                        )
                    }
                )
            }
            .scrollDisabled(true)
            .background(Color.clear)
            .navigationTitle(PPAccessoryViewerL10n.text("accessory_view_options_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(PPAccessoryViewerL10n.text("Done"), action: close)
                        .font(PPAccessoryTypography.bodyBold)
                        .disabled(isMutating)
                }
            }
        }
        .tint(PPAccessoryPalette.brand)
        .background(glassBackground)
        .environment(\.layoutDirection, PPAccessoryViewerLegacyBridge.isRTL() ? .rightToLeft : .leftToRight)
        .interactiveDismissDisabled(isMutating)
        .onPreferenceChange(PPContentHeightPreferenceKey.self) { height in
            guard height > 100 else { return }
            onHeightChange(height + 74)
        }
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                    hasAppeared = true
                }
            }
        }
        .onChange(of: isMutating, perform: mutationChanged)
        .onChange(of: store.snapshot?.id) { _ in
            mutationError = nil
            triggerSelectAnimation()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.resume() }
            else if phase == .background { store.pause() }
        }
    }

    private var loadingState: some View {
        VStack(spacing: PPSpace.base) {
            ProgressView()
                .controlSize(.large)
                .tint(PPAccessoryPalette.brand)
            Text(PPAccessoryViewerL10n.text("accessory_view_options_loading"))
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var glassBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.65),
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func content(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        // Title & Price Section
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(snapshot.title)
                .font(PPAccessoryTypography.title)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(snapshot.price)
                .font(PPAccessoryTypography.price)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: snapshot.price)
        }
        .offset(y: reduceMotion || hasAppeared ? 0 : 16)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.04), value: hasAppeared)

        // Variant Selector Section
        PPAccessoryVariantSelectorSection(
            store: store, snapshot: snapshot, compact: true, showsDeliveryContext: false
        )
        .disabled(isMutating)
        .scaleEffect(selectPulse ? 1.015 : 1.0)
        .offset(y: reduceMotion || hasAppeared ? 0 : 20)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.44, dampingFraction: 0.82).delay(0.09), value: hasAppeared)

        if store.variantsPhase == .empty && !store.isVariantSelectionConfirmed {
            recovery(PPAccessoryViewerL10n.text("accessory_view_options_empty_axis"), retry: store.retryVariants)
        }

        if store.livePhase == .refreshing {
            ProgressView(PPAccessoryViewerL10n.text("accessory_view_options_check_availability"))
        } else if store.livePhase == .stale {
            recovery(PPAccessoryViewerL10n.text("accessory_view_live_data_stale"), retry: store.retryLiveUpdates)
        }

        // Redesigned Bottom CTA Dock
        if snapshot.showsCart {
            cartControls(snapshot)
                .offset(y: reduceMotion || hasAppeared ? 0 : 24)
                .opacity(hasAppeared ? 1 : 0)
                .animation(.spring(response: 0.46, dampingFraction: 0.82).delay(0.14), value: hasAppeared)
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
        VStack(spacing: PPSpace.sm) {
            if store.cartQuantity > 0 {
                inCartConsole(snapshot)
            } else {
                addToCartConsole(snapshot)
            }

            if snapshot.isUnavailable {
                unavailableNotice(snapshot)
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppElevatedSurface.opacity(colorScheme == .dark ? 0.85 : 0.90),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.22 : 0.14),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06),
            radius: 12,
            y: 4
        )
    }

    private func addToCartConsole(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        HStack(spacing: PPSpace.sm) {
            // Tactile Micro-Stepper
            HStack(spacing: 0) {
                Button {
                    PPUniversalHaptics.light()
                    store.decrementQuantity()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 36, height: 46)
                        .contentShape(Rectangle())
                }
                .disabled(!canAdd || store.quantity <= 1)
                .opacity(store.quantity <= 1 ? 0.35 : 1.0)

                Text(PPAccessoryViewerL10n.integer(store.quantity))
                    .font(.custom("Beiruti-Bold", size: 17, relativeTo: .body))
                    .frame(minWidth: 26)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: store.quantity)

                Button {
                    PPUniversalHaptics.light()
                    store.incrementQuantity()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 36, height: 46)
                        .contentShape(Rectangle())
                }
                .disabled(!canAdd || store.quantity >= store.remainingStock)
                .opacity(store.quantity >= store.remainingStock ? 0.35 : 1.0)
            }
            .foregroundStyle(PPAccessoryPalette.ink)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.ppSecondarySurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(PPAccessorySubviewBackground.faintStroke, lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(PPAccessoryViewerL10n.formatted("accessory_view_quantity_format", store.quantity))

            // Hero Add-to-Cart Action Button
            Button(action: handleAddToCart) {
                HStack(spacing: PPSpace.sm) {
                    if isMutating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else if justAdded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .scaleEffect(justAdded ? 1.15 : 0.8)
                    } else {
                        Image(systemName: "bag.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                            .scaleEffect(cartIconBounce ? 1.25 : 1.0)
                    }

                    Text(PPAccessoryViewerL10n.text(
                        isMutating ? "accessory_view_adding_to_cart" :
                        (justAdded ? "AddedToCart" : "addToCart")
                    ))
                    .font(.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .lineLimit(1)

                    if canAdd && !isMutating && !justAdded {
                        Spacer(minLength: 4)

                        Text(formattedCalculatedPrice(snapshot))
                            .font(.custom("Beiruti-SemiBold", size: 14, relativeTo: .callout))
                            .opacity(0.92)
                            .contentTransition(.numericText())
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, PPSpace.base)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: canAdd
                                    ? [PPAccessoryPalette.brand, PPAccessoryPalette.brand.opacity(0.88)]
                                    : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.4),
                            lineWidth: 0.75
                        )
                )
                .shadow(
                    color: canAdd ? PPAccessoryPalette.brand.opacity(0.28) : .clear,
                    radius: 10,
                    y: 4
                )
            }
            .buttonStyle(PPOptionsScaleButtonStyle())
            .disabled(!canAdd)
            .accessibilityIdentifier("pp.universal.variant.add")
        }
    }

    private func inCartConsole(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        HStack(spacing: PPSpace.sm) {
            // Remove item button
            Button {
                PPUniversalHaptics.light()
                updateCartQuantity(0)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(width: 44, height: 46)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(colorScheme == .dark ? 0.16 : 0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PPOptionsScaleButtonStyle())
            .disabled(isMutating || store.switchingVariantProductId != nil)
            .accessibilityLabel(PPAccessoryViewerL10n.text("a11y_btn_remove_cart_item"))

            // In-Cart Stepper & Status Bar
            HStack(spacing: PPSpace.sm) {
                // In-Cart Badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PPAccessoryPalette.brand)
                    Text(PPAccessoryViewerL10n.text("InCart"))
                        .font(.custom("Beiruti-Bold", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(PPAccessoryPalette.brand)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.18 : 0.10))
                )

                Spacer()

                // Stepper
                HStack(spacing: 0) {
                    Button {
                        PPUniversalHaptics.light()
                        updateCartQuantity(store.cartQuantity - 1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 46)
                            .contentShape(Rectangle())
                    }
                    .disabled(isMutating || store.cartQuantity <= 0)

                    if isMutating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 26)
                    } else {
                        Text(PPAccessoryViewerL10n.integer(store.cartQuantity))
                            .font(.custom("Beiruti-Bold", size: 16, relativeTo: .body))
                            .frame(minWidth: 26)
                            .contentTransition(.numericText())
                    }

                    Button {
                        PPUniversalHaptics.light()
                        updateCartQuantity(store.cartQuantity + 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 46)
                            .contentShape(Rectangle())
                    }
                    .disabled(isMutating || store.cartQuantity >= snapshot.quantity)
                }
                .foregroundStyle(PPAccessoryPalette.ink)
            }
            .padding(.horizontal, PPSpace.sm)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.ppSecondarySurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        PPAccessoryPalette.brand.opacity(colorScheme == .dark ? 0.28 : 0.16),
                        lineWidth: 1
                    )
            )
            .accessibilityIdentifier("pp.universal.variant.cartQuantity")
        }
    }

    @ViewBuilder
    private func unavailableNotice(_ snapshot: PPAccessoryViewerSnapshot) -> some View {
        VStack(spacing: PPSpace.xs) {
            Text(PPAccessoryViewerL10n.text("accessory_view_item_unavailable"))
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(PPAccessoryPalette.inkSecondary)

            if snapshot.canRequestStockNotification && store.isVariantSelectionConfirmed {
                Button(action: store.registerStockNotification) {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 13, weight: .bold))
                        Text(PPAccessoryViewerL10n.text(
                            store.stockNotificationPhase == .success ? "stock_notify_already_registered" : "notify_me"
                        ))
                        .font(PPAccessoryTypography.bodyBold)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 38)
                    .background(
                        Capsule()
                            .fill(PPAccessoryPalette.brand.opacity(0.12))
                    )
                }
                .buttonStyle(PPOptionsScaleButtonStyle())
                .disabled(store.stockNotificationPhase == .processing || isMutating)
            }
        }
    }

    private func recovery(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(message).fixedSize(horizontal: false, vertical: true)
            Button(PPAccessoryViewerL10n.text("Retry"), action: retry)
                .buttonStyle(PPOptionsScaleButtonStyle())
                .frame(minHeight: 44)
                .disabled(isMutating)
        }
    }

    private func handleAddToCart() {
        guard canAdd else { return }
        PPUniversalHaptics.medium()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cartIconBounce = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cartIconBounce = false
        }
        addToCart()
    }

    private func triggerSelectAnimation() {
        guard !reduceMotion else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            selectPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            selectPulse = false
        }
    }

    private func formattedCalculatedPrice(_ snapshot: PPAccessoryViewerSnapshot) -> String {
        PPAccessoryViewerLegacyBridge.formattedPrice(for: snapshot.accessory, quantity: store.quantity)
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    justAdded = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation {
                        justAdded = false
                    }
                }
                announceCartQuantity()
            } catch is CancellationError {
                // The existing auth/provider-switch presentation owns cancellation.
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                announceCartQuantity()
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
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

private struct PPContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 380
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

private struct PPOptionsScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
