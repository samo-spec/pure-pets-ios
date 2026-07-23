//
//  PPFont.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Custom font utility mapping Beiruti brand typography to SwiftUI Font tokens with system fallbacks.
public enum PPFont {
    public static func beirutiBold(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-Bold", size: size) != nil {
            return .custom("Beiruti-Bold", size: size)
        }
        return .system(size: size, weight: .bold)
    }
    
    public static func beirutiMedium(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-Medium", size: size) != nil {
            return .custom("Beiruti-Medium", size: size)
        }
        return .system(size: size, weight: .medium)
    }
    
    public static func beirutiSemiBold(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-SemiBold", size: size) != nil {
            return .custom("Beiruti-SemiBold", size: size)
        } else if UIFont(name: "Beiruti-Bold", size: size) != nil {
            return .custom("Beiruti-Bold", size: size)
        }
        return .system(size: size, weight: .semibold)
    }
    
    public static func beirutiRegular(size: CGFloat) -> Font {
        if UIFont(name: "Beiruti-Regular", size: size) != nil {
            return .custom("Beiruti-Regular", size: size)
        }
        return .system(size: size, weight: .regular)
    }
}
