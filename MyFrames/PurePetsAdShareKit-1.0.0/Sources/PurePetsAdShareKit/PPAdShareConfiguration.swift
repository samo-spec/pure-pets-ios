#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @available(iOS 17.0, *)
  public struct PPAdShareConfiguration {
    public var brandName: String
    public var brandColor: Color
    public var cardBackground: Color
    public var primaryTextColor: Color
    public var secondaryTextColor: Color
    public var brandSymbolName: String
    public var logoImage: UIImage?
    public var cardSize: CGSize
    public var imageHeight: CGFloat
    public var jpegQuality: CGFloat
    public var maximumDownloadBytes: Int
    public var maximumImagePixelSize: CGFloat
    public var excludedActivityTypes: [UIActivity.ActivityType]
    public var cleansTemporaryFileAfterSharing: Bool

    public init(
      brandName: String = "Pure Pets",
      brandColor: Color = Color(
        red: 203.0 / 255.0,
        green: 38.0 / 255.0,
        blue: 84.0 / 255.0
      ),
      cardBackground: Color = Color(
        red: 250.0 / 255.0,
        green: 248.0 / 255.0,
        blue: 244.0 / 255.0
      ),
      primaryTextColor: Color = Color(
        red: 25.0 / 255.0,
        green: 25.0 / 255.0,
        blue: 27.0 / 255.0
      ),
      secondaryTextColor: Color = Color(
        red: 100.0 / 255.0,
        green: 98.0 / 255.0,
        blue: 96.0 / 255.0
      ),
      brandSymbolName: String = "pawprint.fill",
      logoImage: UIImage? = nil,
      cardSize: CGSize = CGSize(width: 1080, height: 1350),
      imageHeight: CGFloat = 760,
      jpegQuality: CGFloat = 0.9,
      maximumDownloadBytes: Int = 25 * 1_024 * 1_024,
      maximumImagePixelSize: CGFloat = 2_400,
      excludedActivityTypes: [UIActivity.ActivityType] = [],
      cleansTemporaryFileAfterSharing: Bool = true
    ) {
      let normalizedBrandName = brandName.ppShareNormalized(maximumCharacters: 80)
      self.brandName = normalizedBrandName.isEmpty ? "Pure Pets" : normalizedBrandName
      self.brandColor = brandColor
      self.cardBackground = cardBackground
      self.primaryTextColor = primaryTextColor
      self.secondaryTextColor = secondaryTextColor

      let symbolCandidate = brandSymbolName.ppShareNormalized(maximumCharacters: 80)
      self.brandSymbolName =
        UIImage(systemName: symbolCandidate) == nil
        ? "pawprint.fill"
        : symbolCandidate
      self.logoImage = logoImage
      self.cardSize = CGSize(
        width: max(720, cardSize.width.isFinite ? cardSize.width : 1080),
        height: max(900, cardSize.height.isFinite ? cardSize.height : 1350)
      )
      self.imageHeight = min(
        max(360, imageHeight.isFinite ? imageHeight : 760),
        self.cardSize.height * 0.72
      )
      let safeJPEGQuality = jpegQuality.isFinite ? jpegQuality : 0.9
      self.jpegQuality = min(max(safeJPEGQuality, 0.55), 1)
      self.maximumDownloadBytes = min(
        max(1_024_000, maximumDownloadBytes),
        100 * 1_024 * 1_024
      )
      let safeMaximumPixelSize =
        maximumImagePixelSize.isFinite
        ? maximumImagePixelSize
        : 2_400
      self.maximumImagePixelSize = max(1_080, safeMaximumPixelSize)
      self.excludedActivityTypes = excludedActivityTypes
      self.cleansTemporaryFileAfterSharing = cleansTemporaryFileAfterSharing
    }

    public static let purePets = PPAdShareConfiguration()
  }
#endif
