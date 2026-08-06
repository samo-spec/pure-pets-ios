#if canImport(SwiftUI)
  import SwiftUI

  @available(iOS 17.0, *)
  public struct PPFancyShareLabel: View {
    public let copy: PPAdShareCopy
    public let brandColor: Color
    public let isPreparing: Bool

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var appeared = false

    public init(
      copy: PPAdShareCopy,
      brandColor: Color,
      isPreparing: Bool
    ) {
      self.copy = copy
      self.brandColor = brandColor
      self.isPreparing = isPreparing
    }

    private var isHighContrast: Bool {
      colorSchemeContrast == .increased
    }

    private var backgroundFill: Color {
      brandColor.opacity(isHighContrast ? 0.16 : 0.09)
    }

    private var strokeColor: Color {
      brandColor.opacity(isHighContrast ? 0.48 : 0.22)
    }

    private var strokeLineWidth: CGFloat {
      isHighContrast ? 1.5 : 1.0
    }

    public var body: some View {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          accessibilityLayout
        } else {
          regularLayout
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 11)
      .frame(maxWidth: .infinity, minHeight: 62)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(backgroundFill)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(strokeColor, lineWidth: strokeLineWidth)
      )
      .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .onAppear {
        guard !appeared else { return }
        if reduceMotion {
          appeared = true
        } else {
          withAnimation(.snappy(duration: 0.32)) {
            appeared = true
          }
        }
      }
    }

    private var regularLayout: some View {
      HStack(spacing: 13) {
        leadingSymbol
        copyStack
        Spacer(minLength: 8)
        Image(systemName: "chevron.forward")
          .font(.caption.weight(.bold))
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
    }

    private var accessibilityLayout: some View {
      HStack(alignment: .top, spacing: 13) {
        leadingSymbol
        copyStack
        Spacer(minLength: 0)
      }
    }

    private var leadingSymbol: some View {
      ZStack {
        Circle()
          .fill(brandColor.opacity(0.14))

        if isPreparing {
          ProgressView()
            .tint(brandColor)
        } else {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(brandColor)
            .symbolEffect(.bounce, value: appeared)
        }
      }
      .frame(width: 42, height: 42)
      .accessibilityHidden(true)
    }

    private var copyStack: some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(isPreparing ? copy.preparingTitle : copy.buttonTitle)
          .font(.headline)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.leading)

        if !isPreparing {
          Text(copy.buttonSubtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
#endif
