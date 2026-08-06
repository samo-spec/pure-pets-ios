#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @available(iOS 17.0, *)
  public struct PPAdShareCard: View {
    public let payload: PPAdSharePayload
    public let listingImage: UIImage
    public let configuration: PPAdShareConfiguration
    public let copy: PPAdShareCopy

    public init(
      payload: PPAdSharePayload,
      listingImage: UIImage,
      configuration: PPAdShareConfiguration = .purePets,
      copy: PPAdShareCopy = .english
    ) {
      self.payload = payload
      self.listingImage = listingImage
      self.configuration = configuration
      self.copy = copy
    }

    public var body: some View {
      ZStack {
        configuration.cardBackground

        VStack(spacing: 0) {
          heroImage
          detailSection
        }
      }
      .frame(
        width: configuration.cardSize.width,
        height: configuration.cardSize.height
      )
      .clipped()
      .environment(
        \.layoutDirection,
        copy.localeIdentifier.hasPrefix("ar") ? .rightToLeft : .leftToRight
      )
    }

    private var heroImage: some View {
      ZStack(alignment: .bottom) {
        Image(uiImage: listingImage)
          .resizable()
          .scaledToFill()
          .frame(
            width: configuration.cardSize.width,
            height: configuration.imageHeight
          )
          .clipped()

        LinearGradient(
          colors: [.clear, Color.black.opacity(0.42)],
          startPoint: .center,
          endPoint: .bottom
        )

        HStack(spacing: 16) {
          brandMark

          Text(configuration.brandName)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(.white)

          Spacer()

          if let price = payload.formattedPrice {
            Text(price)
              .font(.system(size: 34, weight: .heavy, design: .rounded))
              .foregroundStyle(.white)
              .padding(.horizontal, 24)
              .padding(.vertical, 13)
              .background(.black.opacity(0.35), in: Capsule())
          }
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 32)
      }
      .frame(height: configuration.imageHeight)
    }

    private var brandMark: some View {
      Group {
        if let logoImage = configuration.logoImage {
          Image(uiImage: logoImage)
            .resizable()
            .scaledToFit()
            .padding(10)
        } else {
          Image(systemName: configuration.brandSymbolName)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(configuration.brandColor)
        }
      }
      .frame(width: 58, height: 58)
      .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var detailSection: some View {
      VStack(alignment: .leading, spacing: 22) {
        Text(payload.title)
          .font(.system(size: 50, weight: .bold, design: .rounded))
          .foregroundStyle(configuration.primaryTextColor)
          .lineLimit(2)
          .minimumScaleFactor(0.78)

        if let location = payload.location {
          Label(location, systemImage: "location.fill")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(configuration.secondaryTextColor)
        }

        if let seller = payload.sellerDisplayName {
          Label(seller, systemImage: "person.crop.circle.fill")
            .font(.system(size: 25, weight: .medium, design: .rounded))
            .foregroundStyle(configuration.secondaryTextColor)
            .lineLimit(1)
        }

        if !payload.attributes.isEmpty {
          HStack(spacing: 14) {
            ForEach(payload.attributes) { attribute in
              Text(attribute.title)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .foregroundStyle(configuration.primaryTextColor)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                  configuration.brandColor.opacity(0.10),
                  in: Capsule()
                )
            }
          }
        }

        if let description = payload.shortDescription {
          Text(description)
            .font(.system(size: 25, weight: .regular, design: .rounded))
            .foregroundStyle(configuration.secondaryTextColor)
            .lineLimit(3)
        }

        Spacer(minLength: 8)

        HStack(spacing: 15) {
          Image(systemName: "arrow.up.right.square.fill")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(configuration.brandColor)

          Text(copy.callToAction.replacingOccurrences(of: ":", with: ""))
            .font(.system(size: 25, weight: .bold, design: .rounded))
            .foregroundStyle(configuration.primaryTextColor)

          Spacer()

          Text(payload.canonicalURL.host ?? configuration.brandName)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundStyle(configuration.secondaryTextColor)
            .lineLimit(1)
        }
        .padding(.top, 12)
      }
      .padding(.horizontal, 48)
      .padding(.top, 38)
      .padding(.bottom, 40)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var resolvedBrandSymbolName: String {
      UIImage(systemName: configuration.brandSymbolName) == nil
        ? "pawprint.fill"
        : configuration.brandSymbolName
    }

    private var cardTitle: String {
      guard payload.title.count > 120 else { return payload.title }
      let end = payload.title.index(payload.title.startIndex, offsetBy: 119)
      return String(payload.title[..<end]).ppShareTrimmed + "…"
    }

  }
#endif
