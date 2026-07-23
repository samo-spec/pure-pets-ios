//
//  PPRootPassthroughView.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Custom `UIView` subclass and SwiftUI view modifier providing explicit control over touch pass-through.
open class PPRootPassthroughView: UIView {
    public var shouldPassThroughTouches: Bool = true
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else {
            return nil
        }
        if hitView === self && shouldPassThroughTouches {
            return nil
        }
        return hitView
    }
}

/// SwiftUI ViewModifier adding touch pass-through behavior to transparent container regions.
public struct PPRootPassthroughModifier: ViewModifier {
    public var passThrough: Bool
    
    public init(passThrough: Bool = true) {
        self.passThrough = passThrough
    }
    
    public func body(content: Content) -> some View {
        content
            .background(PPRootPassthroughViewRepresentable(passThrough: passThrough))
    }
}

private struct PPRootPassthroughViewRepresentable: UIViewRepresentable {
    let passThrough: Bool
    
    func makeUIView(context: Context) -> PPRootPassthroughView {
        let view = PPRootPassthroughView()
        view.backgroundColor = .clear
        view.shouldPassThroughTouches = passThrough
        return view
    }
    
    func updateUIView(_ uiView: PPRootPassthroughView, context: Context) {
        uiView.shouldPassThroughTouches = passThrough
    }
}

public extension View {
    func passthroughTouches(_ passThrough: Bool = true) -> some View {
        modifier(PPRootPassthroughModifier(passThrough: passThrough))
    }
}
