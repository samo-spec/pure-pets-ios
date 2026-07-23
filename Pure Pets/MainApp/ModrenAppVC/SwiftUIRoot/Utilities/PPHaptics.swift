//
//  PPHaptics.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//
//  Lightweight haptic feedback utility matching legacy UIKit haptic patterns
//  used in PPRootTabBarController (UIImpactFeedbackStyleSoft for tab taps,
//  UISelectionFeedbackGenerator for tab selections).
//

import UIKit

/// Centralized haptic feedback matching the legacy PPRootTabBarController patterns.
@MainActor
public enum PPHaptics {
    
    private static let softImpactGenerator: UIImpactFeedbackGenerator = {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        return gen
    }()
    
    private static let selectionGenerator: UISelectionFeedbackGenerator = {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        return gen
    }()
    
    /// Soft impact — used for create-tab interception, nova tap, cart tap.
    /// Matches: `[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft]`
    public static func softImpact() {
        softImpactGenerator.impactOccurred()
        softImpactGenerator.prepare()
    }
    
    /// Selection changed — used for tab switch confirmation.
    /// Matches: `[[UISelectionFeedbackGenerator alloc] init]`
    public static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
}
