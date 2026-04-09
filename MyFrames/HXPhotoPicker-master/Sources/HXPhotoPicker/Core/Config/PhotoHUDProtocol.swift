//
//  PhotoHUDProtocol.swift
//  HXPhotoPicker
//
//  Created by Silence on 2024/4/3.
//  Copyright © 2024 Silence. All rights reserved.
//

import UIKit

public protocol PhotoHUDProtocol: UIView {
    
    /// Set the text content of the prompt box
    func setText(_ text: String?)
    
    /// Set the progress of the prompt box
    func setProgress(_ progress: CGFloat)
    
    /// Loading box
    /// - Parameters:
    /// - text: text content
    /// - delay: delay display
    /// - animated: whether to display animation effects
    /// - view: added to the corresponding view
    @discardableResult
    static func show(with text: String?, delay: TimeInterval, animated: Bool, addedTo view: UIView?) -> PhotoHUDProtocol?
    
    /// Warning prompt box
    /// - Parameters:
    /// - text: text content
    /// - delay: delay disappears
    /// - animated: whether to display animation effects
    /// - view: added to the corresponding view
    static func showInfo(with text: String?, delay: TimeInterval, animated: Bool, addedTo view: UIView?)
    
    /// Progress prompt box
    /// - Parameters:
    /// - text: text content
    /// - progress: progress
    /// - animated: whether to display animation effects
    /// - view: added to the corresponding view
    /// - Returns: corresponding progress box
    static func showProgress(with text: String?, progress: CGFloat, animated: Bool, addedTo view: UIView?) -> PhotoHUDProtocol?
    
    /// Success prompt box
    /// - Parameters:
    /// - text: text content
    /// - delay: delay disappears
    /// - animated: whether to display animation effects
    /// - view: added to the corresponding view
    static func showSuccess(with text: String?, delay: TimeInterval, animated: Bool, addedTo view: UIView?)
    
    /// Hide prompt box
    /// - Parameters:
    /// - delay: delay disappears
    /// - animated: whether to display animation effects
    /// - view: the view where the prompt box is located
    static func dismiss(delay: TimeInterval, animated: Bool, for view: UIView?)
}

extension ProgressHUD: PhotoHUDProtocol {
    public static func show(with text: String?, delay: TimeInterval, animated: Bool, addedTo view: UIView?) -> PhotoHUDProtocol? {
        showLoading(addedTo: view, text: text, afterDelay: delay, animated: animated)
    }
    
    public static func showInfo(with text: String?, delay: TimeInterval, animated: Bool, addedTo view: UIView?) {
        showWarning(addedTo: view, text: text, animated: animated, delayHide: delay)
    }
    
    public static func showSuccess(with text: String?, delay: TimeInterval, animated: Bool, addedTo view: UIView?) {
        showSuccess(addedTo: view, text: text, animated: animated, delayHide: delay)
    }
    
    public static func showProgress(with text: String?, progress: CGFloat, animated: Bool, addedTo view: UIView?) -> PhotoHUDProtocol? {
        showProgress(addedTo: view, progress: progress, text: text, animated: animated)
    }
    
    public static func dismiss(delay: TimeInterval, animated: Bool, for view: UIView?) {
        hide(forView: view, animated: animated, afterDelay: delay)
    }
    
    public func setText(_ text: String?) {
        self.text = text
    }
    
    public func setProgress(_ progress: CGFloat) {
        if mode != .circleProgress {
            mode = .circleProgress
        }
        self.progress = progress
    }
}
