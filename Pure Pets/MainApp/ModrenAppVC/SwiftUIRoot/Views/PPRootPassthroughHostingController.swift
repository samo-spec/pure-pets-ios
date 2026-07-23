//
//  PPRootPassthroughHostingController.swift
//  PurePetsSwiftUIRefactor
//
//  Created for PurePets Platform SwiftUI Root Architecture.
//

import SwiftUI
import UIKit

/// Custom `UIHostingController` subclass wrapping its hosting view in a pass-through container view
/// so that touches in transparent background regions pass directly through to underlying UIKit views (Fixes Risk #2).
open class PPRootPassthroughHostingController<Content: View>: UIHostingController<Content> {
    
    /// Optional closure evaluating whether a touch point (in container coordinates) is interactive.
    /// If returns `true`, the touch is delivered to the hosted SwiftUI view.
    /// If returns `false`, `hitTest` returns `nil` so the touch passes through to underlying UIKit views.
    public var isInteractivePoint: ((CGPoint) -> Bool)? {
        didSet {
            containerView?.isInteractivePoint = isInteractivePoint
        }
    }
    
    private weak var containerView: PassthroughContainerView?
    
    private final class PassthroughContainerView: UIView {
        weak var hostedView: UIView?
        var isInteractivePoint: ((CGPoint) -> Bool)?
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let hostedView = hostedView else {
                return super.hitTest(point, with: event)
            }
            
            // 1. If a custom interactive point handler is provided, use it explicitly:
            if let isInteractive = isInteractivePoint {
                if isInteractive(point) {
                    let convertedPoint = convert(point, to: hostedView)
                    return hostedView.hitTest(convertedPoint, with: event) ?? hostedView
                } else {
                    return nil
                }
            }
            
            // 2. Default fallback passthrough check
            let convertedPoint = convert(point, to: hostedView)
            guard let hitView = hostedView.hitTest(convertedPoint, with: event) else {
                return nil
            }
            
            if hitView === hostedView {
                return nil
            }
            
            if let passthroughView = hitView as? PPRootPassthroughView, passthroughView.shouldPassThroughTouches {
                return nil
            }
            
            return hitView
        }
    }
    
    public override init(rootView: Content) {
        super.init(rootView: rootView)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        view.backgroundColor = .clear
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
    
    open override func loadView() {
        super.loadView()
        guard let hostingView = self.view else { return }
        hostingView.backgroundColor = .clear
        
        let container = PassthroughContainerView(frame: hostingView.bounds)
        container.backgroundColor = .clear
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.hostedView = hostingView
        container.isInteractivePoint = isInteractivePoint
        self.containerView = container
        
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(hostingView)
        
        self.view = container
    }
}
