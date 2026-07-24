import SwiftUI

struct PPPetAdInfoPillView: View {
    let symbol: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(label)
                    .font(PPPetAdTypography.caption)
                    .foregroundStyle(Color.ppTextTertiary)
                Text(value)
                    .font(PPPetAdTypography.subheadlineBold)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(Color.ppForeground.opacity(0.72))
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .stroke(tint.opacity(0.12), lineWidth: 0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
