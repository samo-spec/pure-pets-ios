import SwiftUI

struct PPPetAdInlineStateView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let tint: Color
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(
                    tint.opacity(0.10),
                    in: RoundedRectangle(
                        cornerRadius: 0,
                        style: .continuous
                    )
                )

            VStack(spacing: PPSpace.xs) {
                Text(title)
                    .font(PPPetAdTypography.headline)
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                if !message.isEmpty {
                    Text(message)
                        .font(PPPetAdTypography.subheadline)
                        .foregroundStyle(Color.ppTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(PPPetAdTypography.calloutBold)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, PPSpace.lg)
                        .frame(minHeight: 46)
                        .background(
                            tint,
                            in: RoundedRectangle(
                                cornerRadius:
                                    PPPetAdViewerStyle.insetRadius,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(PPPetAdPressButtonStyle())
            }
        }
        .padding(PPPetAdViewerStyle.compactSurfacePadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
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
