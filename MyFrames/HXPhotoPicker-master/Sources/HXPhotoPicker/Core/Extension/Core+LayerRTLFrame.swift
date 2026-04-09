import UIKit

private var refWidthKey: UInt8 = 0

extension CALayer {
    /// Reference width, which is the width of [parent layer].
    /// - If the [parent layer] is a `CAScrollLayer` it is best to set it to its `content width`.
    @objc var hxPicker_refWidth: CGFloat {
        set { objc_setAssociatedObject(self, &refWidthKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
        get { objc_getAssociatedObject(self, &refWidthKey) as? CGFloat ?? superlayer?.bounds.maxX ?? 0 }
    }
    
    var hxPicker_frame: CGRect {
        set {
            guard PhotoManager.isRTL else {
                frame = newValue
                return
            }
            let x = hxPicker_refWidth - newValue.maxX
            frame = CGRect(origin: CGPoint(x: x, y: newValue.origin.y), size: newValue.size)
        }
        get {
            guard PhotoManager.isRTL else {
                return frame
            }
            let x = hxPicker_refWidth - frame.maxX
            return CGRect(origin: CGPoint(x: x, y: frame.origin.y), size: frame.size)
        }
    }
    
    var hxPicker_position: CGPoint {
        set {
            guard PhotoManager.isRTL else {
                position = newValue
                return
            }
            let positionX = hxPicker_refWidth - newValue.x
            position = CGPoint(x: positionX, y: newValue.y)
        }
        get {
            guard PhotoManager.isRTL else {
                return position
            }
            let positionX = hxPicker_refWidth - position.x
            return CGPoint(x: positionX, y: position.y)
        }
    }
    
    var hxPicker_x: CGFloat {
        set {
            guard PhotoManager.isRTL else {
                frame.origin.x = newValue
                return
            }
            let x = hxPicker_refWidth - frame.width - newValue
            frame.origin.x = x
        }
        get {
            guard PhotoManager.isRTL else {
                return frame.origin.x
            }
            let x = hxPicker_refWidth - frame.maxX
            return x
        }
    }
    
    var hxPicker_midX: CGFloat {
        guard PhotoManager.isRTL else {
            return frame.midX
        }
        let midX = hxPicker_refWidth - frame.midX
        return midX
    }
    
    var hxPicker_maxX: CGFloat {
        guard PhotoManager.isRTL else {
            return frame.maxX
        }
        return hxPicker_refWidth - frame.origin.x
    }
    
    /// Conversion value relative to [self-width]
    func hxPicker_valueFromSelf(_ v: CGFloat) -> CGFloat {
        PhotoManager.isRTL ? (bounds.width - v) : v
    }
    
    /// Conversion value relative to [reference width]
    func hxPicker_valueFromRef(_ v: CGFloat) -> CGFloat {
        PhotoManager.isRTL ? (hxPicker_refWidth - v) : v
    }
}

extension CALayer {
    /// Flip 180° along the Y axis (horizontal mirroring)
    func hxPicker_flip() {
        guard PhotoManager.isRTL else { return }
        transform = CATransform3DMakeRotation(CGFloat.pi, 0, 1, 0)
    }
}
