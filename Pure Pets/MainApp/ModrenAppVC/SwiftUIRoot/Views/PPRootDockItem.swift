//
//  PPRootDockItem.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Custom font extension mapping Beiruti brand typography for SwiftUI views.
public extension Font {
    static func ppBeirutiBold(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-Bold", size: size) != nil {
            return .custom("Beiruti-Bold", size: size)
        }
        return .system(size: size, weight: .bold)
    }
    
    static func ppBeirutiMedium(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-Medium", size: size) != nil {
            return .custom("Beiruti-Medium", size: size)
        }
        return .system(size: size, weight: .medium)
    }
    
    static func ppBeirutiSemiBold(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-SemiBold", size: size) != nil {
            return .custom("Beiruti-SemiBold", size: size)
        } else if UIFont(name: "Beiruti-Bold", size: size) != nil {
            return .custom("Beiruti-Bold", size: size)
        }
        return .system(size: size, weight: .semibold)
    }
}

/// Declarative SwiftUI item component rendering individual native tab bar items with haptics, unread badges, and RTL layout support.
public struct PPRootDockItem: View {
    public let tab: PPRootTab
    public let isSelected: Bool
    public let unreadCount: Int
    public let sessionState: PPRootSessionState
    public let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var primaryColor: Color {
        Color(uiColor: UIColor(named: "AppPrimaryColor") ?? UIColor(red: 227/255, green: 6/255, blue: 83/255, alpha: 1.0))
    }
    
    public init(
        tab: PPRootTab,
        isSelected: Bool,
        unreadCount: Int,
        sessionState: PPRootSessionState,
        action: @escaping () -> Void
    ) {
        self.tab = tab
        self.isSelected = isSelected
        self.unreadCount = unreadCount
        self.sessionState = sessionState
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 3.0) {
                ZStack(alignment: .topTrailing) {
                    if tab == .menu {
                        PPRootAvatarView(sessionState: sessionState, isSelected: isSelected)
                    } else {
                        Image(systemName: isSelected ? tab.symbolSelectedName : tab.symbolNormalName)
                            .font(.system(size: isSelected ? 21 : 20, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(
                                isSelected
                                    ? primaryColor
                                    : Color(uiColor: .secondaryLabel)
                            )
                            .scaleEffect(isPressed ? 0.92 : 1.0)
                    }
                    
                    // Unread badge indicator (Chats tab = index 3)
                    if tab == .chats && unreadCount > 0 {
                        let badgeText = unreadCount > 99 ? "99+" : "\(unreadCount)"
                        Text(badgeText)
                            .font(Font.ppBeirutiBold(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(primaryColor, in: Capsule())
                            .offset(x: 10, y: -4)
                    }
                }
                .frame(height: 24)
                
                Text(tab.title)
                    .font(Font.ppBeirutiSemiBold(size: 10.5))
                    .foregroundStyle(
                        isSelected
                            ? primaryColor
                            : Color(uiColor: .secondaryLabel)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint(tab.accessibilityHint)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
