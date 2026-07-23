//
//  PPRootSessionState.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import Foundation

/// Value type holding reactive snapshot of current user session, authentication, and blocked status.
public struct PPRootSessionState: Equatable, Sendable {
    public var isLoggedIn: Bool
    public var isBlocked: Bool
    public var isEffectivelyBlocked: Bool
    public var displayName: String
    public var userImageUrl: URL?
    
    public init(
        isLoggedIn: Bool = false,
        isBlocked: Bool = false,
        isEffectivelyBlocked: Bool = false,
        displayName: String = "",
        userImageUrl: URL? = nil
    ) {
        self.isLoggedIn = isLoggedIn
        self.isBlocked = isBlocked
        self.isEffectivelyBlocked = isEffectivelyBlocked
        self.displayName = displayName
        self.userImageUrl = userImageUrl
    }
    
    public var isGuest: Bool {
        !isLoggedIn
    }
    
    public var isAnyBlocked: Bool {
        isLoggedIn && (isBlocked || isEffectivelyBlocked)
    }
    
    public var effectiveDisplayName: String {
        if !isLoggedIn || displayName.isEmpty {
            return NSLocalizedString("Guest", value: "Guest", comment: "Guest user title")
        }
        return displayName
    }
}
