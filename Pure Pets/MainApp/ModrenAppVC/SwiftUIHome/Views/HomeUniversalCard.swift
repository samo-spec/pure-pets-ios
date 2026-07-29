import SwiftUI
import UIKit

struct HomeUniversalCard: View {
    let card: HomeCardModel
    let delegate: PPUniversalCellDelegate?
    let onTap: () -> Void
    let onQuantityChange: (Int) -> Void

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                HomeUniversalHostingCard(
                    card: card,
                    delegate: delegate,
                    onQuantityChange: onQuantityChange
                )
            } else {
                HomeUniversalCompatibilityCard(
                    card: card,
                    onTap: onTap,
                    onQuantityChange: onQuantityChange
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 328)
    }
}

@available(iOS 16.0, *)
private struct HomeUniversalHostingCard: UIViewRepresentable {
    let card: HomeCardModel
    let delegate: PPUniversalCellDelegate?
    let onQuantityChange: (Int) -> Void

    func makeUIView(context: Context) -> PPUniversalCardHostingCell {
        let cell = PPUniversalCardHostingCell(frame: .zero)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.delegate = delegate
        cell.showsSubtitle = true
        cell.userBordersV2 = true
        return cell
    }

    func updateUIView(
        _ cell: PPUniversalCardHostingCell,
        context: Context
    ) {
        cell.delegate = delegate
        // The hosted universal cell already forwards card taps through its
        // legacy delegate. Supplying `onTap` as well makes its store invoke
        // both routes and pushes the same viewer twice.
        cell.onTap = nil
        cell.onQuantityChange = onQuantityChange
        cell.showsSubtitle = true
        cell.applyViewModel(
            card.viewModel,
            context: card.context,
            layoutMode: .cellLayoutModeVertical,
            discountMode: .badge,
            imageLoader: nil
        )
    }

    static func dismantleUIView(
        _ cell: PPUniversalCardHostingCell,
        coordinator: Void
    ) {
        cell.stopMediaPlayback()
        cell.delegate = nil
        cell.onTap = nil
        cell.onQuantityChange = nil
    }
}

private struct HomeUniversalCompatibilityCard: View {
    let card: HomeCardModel
    let onTap: () -> Void
    let onQuantityChange: (Int) -> Void

    @State private var quantity = 0
    @State private var notificationLoading = false
    @State private var notificationRegistered = false

    private var viewModel: PPUniversalCellViewModel {
        card.viewModel
    }

    private var usesQuantity: Bool {
        PPUniversalCellSwiftUIBridge.usesQuantityControl(for: viewModel)
    }

    private var stockLimit: Int {
        max(0, PPUniversalCellSwiftUIBridge.stockLimit(for: viewModel))
    }

    private var isUnavailable: Bool {
        usesQuantity && stockLimit == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
                ZStack(alignment: .topTrailing) {
                    HomeRemoteImage(
                        urlString: viewModel.imageURL,
                        placeholder: viewModel.image ?? viewModel.placeholder,
                        contentMode: .scaleAspectFill
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 166)
                    .clipped()

                    if !viewModel.badgeText.isEmpty {
                        Text(viewModel.badgeText)
                            .font(HomeFont.bold(11))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, PPSpace.sm)
                            .padding(.vertical, PPSpace.xs)
                            .background(Color.ppPrimary, in: Capsule())
                            .padding(PPSpace.sm)
                    }
                }

                Text(viewModel.title)
                    .font(HomeFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.subtitle.isEmpty {
                    Text(viewModel.subtitle)
                        .font(HomeFont.caption1())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                    Text(viewModel.priceText)
                        .font(HomeFont.bold(17))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if viewModel.hasOffer, !viewModel.discountText.isEmpty {
                        Text(viewModel.discountText)
                            .font(HomeFont.caption1())
                            .foregroundStyle(Color.ppPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                action
        }
        .padding(.bottom, PPSpace.md)
        .background(Color.ppCard)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.card,
                style: .continuous
            )
            .stroke(Color.ppBorder, lineWidth: 0.6)
        }
        .contentShape(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onTap()
        }
        .onAppear {
            quantity = max(
                0,
                PPUniversalCellSwiftUIBridge.cartQuantity(for: viewModel)
            )
        }
    }

    @ViewBuilder
    private var action: some View {
        if usesQuantity {
            if isUnavailable {
                Button {
                    guard !notificationLoading else { return }
                    notificationLoading = true
                    PPUniversalCellSwiftUIBridge.registerStockNotification(
                        for: viewModel
                    ) { success in
                        DispatchQueue.main.async {
                            notificationLoading = false
                            notificationRegistered = success
                        }
                    }
                } label: {
                    Label(
                        notificationRegistered
                            ? HomeModelAdapter.localized(
                                "home_pulse_notify_registered",
                                fallback: "You will be notified"
                            )
                            : HomeModelAdapter.localized(
                                "home_pulse_notify_available",
                                fallback: "Notify me"
                            ),
                        systemImage: notificationRegistered
                            ? "checkmark.circle.fill"
                            : "bell.fill"
                    )
                    .font(HomeFont.bold(14))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(
                        notificationRegistered
                            ? Color.ppSuccess
                            : Color.ppTextPrimary
                    )
                    .background(Color.ppSecondarySurface, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(notificationLoading || notificationRegistered)
            } else if quantity > 0 {
                HStack(spacing: PPSpace.sm) {
                    quantityButton(
                        symbol: "minus",
                        labelKey: "home_pulse_decrease_quantity_a11y",
                        fallback: "Decrease quantity"
                    ) {
                        mutateQuantity(quantity - 1)
                    }
                    Text("\(quantity)")
                        .font(HomeFont.bold(16))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(
                            String(
                                format: HomeModelAdapter.localized(
                                    "home_pulse_quantity_a11y",
                                    fallback: "Quantity %d"
                                ),
                                quantity
                            )
                        )
                    quantityButton(
                        symbol: "plus",
                        labelKey: "home_pulse_increase_quantity_a11y",
                        fallback: "Increase quantity"
                    ) {
                        mutateQuantity(min(stockLimit, quantity + 1))
                    }
                    .disabled(quantity >= stockLimit)
                }
                .frame(height: 46)
                .padding(.horizontal, PPSpace.xs)
                .background(Color.ppSecondarySurface, in: Capsule())
            } else {
                Button {
                    mutateQuantity(1)
                } label: {
                    Label(
                        HomeModelAdapter.localized(
                            "home_pulse_add_to_cart",
                            fallback: "Add to cart"
                        ),
                        systemImage: "cart.badge.plus"
                    )
                    .font(HomeFont.bold(14))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(Color.white)
                    .background(Color.ppPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        } else {
            Label(
                HomeModelAdapter.localized(
                    "home_pulse_details",
                    fallback: "Details"
                ),
                systemImage: "arrow.forward"
            )
            .font(HomeFont.bold(14))
            .foregroundStyle(Color.ppPrimary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Color.ppSoftRose.opacity(0.72), in: Capsule())
        }
    }

    private func quantityButton(
        symbol: String,
        labelKey: String,
        fallback: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(labelKey, fallback: fallback)
        )
    }

    private func mutateQuantity(_ next: Int) {
        let clamped = min(max(0, next), stockLimit)
        quantity = clamped
        onQuantityChange(clamped)
    }

    private var accessibilitySummary: String {
        [
            viewModel.title,
            viewModel.priceText,
            viewModel.availabilityText,
            quantity > 0
                ? String(
                    format: HomeModelAdapter.localized(
                        "home_pulse_in_cart_quantity_a11y",
                        fallback: "In cart, quantity %d"
                    ),
                    quantity
                )
                : "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}
