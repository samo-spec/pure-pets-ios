//
//  PPBlockedAccountState.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Foundation

/// Value type representing full-screen blocked account overlay presentation parameters and actions.
public struct PPBlockedAccountState: Equatable, Sendable {
    public var isBlocked: Bool
    public var brandName: String
    public var supportPhoneNumber: String
    public var animationName: String
    
    public init(
        isBlocked: Bool = false,
        brandName: String = "Pure Pets",
        supportPhoneNumber: String = "+97459997720",
        animationName: String = "contactUs"
    ) {
        self.isBlocked = isBlocked
        self.brandName = brandName
        self.supportPhoneNumber = supportPhoneNumber
        self.animationName = animationName
    }
}
