#if canImport(UIKit)
import SwiftUI

/// Canonical Pure Pets Eyes entry point. The original Pure Lens symbols remain
/// available so existing integrations can migrate without a flag day.
public typealias PurePetsEyesView = PureLensView
public typealias PurePetsEyesModule = PureLensModule
public typealias PurePetsEyesConfiguration = PureLensConfiguration
public typealias PurePetsEyesTheme = PureLensTheme
public typealias PurePetsEyesFeatureButton<Label: View> = PureLensFeatureButton<Label>

#if canImport(UIKit)
public typealias PurePetsEyesUIKit = PureLensUIKit
public typealias PurePetsEyesViewControllerDelegate = PureLensViewControllerDelegate
public typealias PurePetsEyesObjCConfiguration = PureLensObjCConfiguration
public typealias PurePetsEyesViewControllerFactory = PureLensViewControllerFactory
#endif

/// Stable identity for remote configuration, analytics, and host routing.
public enum PurePetsEyesFeature {
    public static let identifier = PurePetsEyesIntegrationContract.featureIdentifier
    public static let displayName = "Pure Pets Eyes"
}


#endif