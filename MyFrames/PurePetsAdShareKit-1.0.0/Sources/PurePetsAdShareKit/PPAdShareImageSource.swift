#if canImport(UIKit)
  import Foundation
  import UIKit

  @available(iOS 17.0, *)
  public enum PPAdShareImageSource {
    case image(UIImage)
    case data(Data)
    case remote(URL)
  }
#endif
