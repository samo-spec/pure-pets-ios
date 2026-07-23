//
//  PPRootNovaState.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Foundation

/// Value type representing Nova AI floating action button presentation and configuration state.
public struct PPRootNovaState: Equatable, Sendable {
    public var isVisibleByConfig: Bool
    public var isHiddenByBottomNavigation: Bool
    public var animationName: String
    public var animationSpeed: Double
    
    public init(
        isVisibleByConfig: Bool = true,
        isHiddenByBottomNavigation: Bool = false,
        animationName: String = "Ncolored",
        animationSpeed: Double = 0.6
    ) {
        self.isVisibleByConfig = isVisibleByConfig
        self.isHiddenByBottomNavigation = isHiddenByBottomNavigation
        self.animationName = animationName
        self.animationSpeed = animationSpeed
    }
    
    /// Effective visibility calculation considering configuration preference and bottom navigation state.
    public var isEffectivelyVisible: Bool {
        isVisibleByConfig && !isHiddenByBottomNavigation
    }
}
