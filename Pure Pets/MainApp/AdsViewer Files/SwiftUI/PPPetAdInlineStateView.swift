import SwiftUI

struct PPPetAdInlineStateView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let tint: Color
    let action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    stateIdentity
                    actionButton
                }
            } else {
                HStack(alignment: .top, spacing: PPSpace.md) {
                    stateIcon
                    stateCopy
                        .frame(maxWidth: .infinity, alignment: .leading)
                    actionButton
                }
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var stateIdentity: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            stateIcon
            stateCopy
        }
    }

    private var stateIcon: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(
                tint.opacity(0.10),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private var stateCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(title)
                .font(PPPetAdTypography.headline)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !message.isEmpty {
                Text(message)
                    .font(PPPetAdTypography.subheadline)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(action: action) {
                Text(actionTitle)
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(tint)
                    .padding(.horizontal, PPSpace.base)
                    .frame(minHeight: 44)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: PPPetAdViewerStyle.insetRadius,
                            style: .continuous
                        )
                        .strokeBorder(tint.opacity(0.48), lineWidth: 1)
                    }
            }
            .buttonStyle(
                PPPetAdPressButtonStyle(pressedScale: 0.985)
            )
        }
    }
}

struct PPPetAdViewerStateScaffold: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let primaryTitle: String
    let primarySymbol: String?
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                stateContent
                    .padding(.horizontal, PPSpace.xxl)
                    .padding(.top, 92)
                    .padding(.bottom, PPSpace.xxxl)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height,
                        alignment: .center
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var stateContent: some View {
        VStack(spacing: PPSpace.xl) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(
                    tint.opacity(0.09),
                    in: RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                        .stroke(
                            tint.opacity(0.16),
                            lineWidth: PPPetAdViewerStyle.hairlineWidth
                        )
                }
                .accessibilityHidden(true)

            VStack(spacing: PPSpace.sm) {
                Text(title)
                    .font(PPPetAdTypography.title2)
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(PPPetAdTypography.body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: PPSpace.sm) {
                Button(action: primaryAction) {
                    Group {
                        if let primarySymbol {
                            Label(
                                primaryTitle,
                                systemImage: primarySymbol
                            )
                        } else {
                            Text(primaryTitle)
                        }
                    }
                    .font(PPPetAdTypography.calloutBold)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        Color.ppPrimary,
                        in: RoundedRectangle(
                            cornerRadius:
                                PPPetAdViewerStyle.insetRadius,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(PPPetAdPressButtonStyle())

                if let secondaryTitle,
                   let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(PPPetAdTypography.calloutBold)
                            .foregroundStyle(Color.ppPrimary)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 46
                            )
                    }
                    .buttonStyle(
                        PPPetAdPressButtonStyle(pressedScale: 0.98)
                    )
                }
            }
        }
        .frame(maxWidth: 420)
    }
}
