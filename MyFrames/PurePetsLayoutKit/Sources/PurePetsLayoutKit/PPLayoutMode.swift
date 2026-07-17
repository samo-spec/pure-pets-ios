import Foundation

/// SwiftUI-native equivalent of the legacy `PPManagerCellLayoutMode` values.
/// Raw values intentionally remain identical so Objective-C callers and saved state keep working.
public enum PPLayoutMode: Int, CaseIterable, Codable, Sendable {
    case none = 0
    case fullWidth = 1
    case horizontalRow = 2
    case vertical = 3
    case pinterest = 4
    case market = 5
    case carousel = 6
    case mainKinds = 7
    case allKinds = 8
    case dataViewFullDetails = 9001

    public init(legacyRawValue: Int) {
        self = PPLayoutMode(rawValue: legacyRawValue) ?? .pinterest
    }
}
