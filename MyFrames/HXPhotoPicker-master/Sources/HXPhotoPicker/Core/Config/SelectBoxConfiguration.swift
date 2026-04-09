//
//  SelectBoxConfiguration.swift
//  HXPhotoPicker
//
//  Created by Slience on 2020/12/29.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit

// MARK: Selection box configuration class
public struct SelectBoxConfiguration {
    
    /// The size of the selection box
    public var size: CGSize = CGSize(width: 25, height: 25)
    
    /// The style of the selection box
    public var style: SelectBoxView.Style = .number
    
    /// The text size of the title
    public var titleFontSize: CGFloat = 16
    
    /// Title color after selection
    public var titleColor: UIColor = .white
    
    /// Title color after selection in dark style
    public var titleDarkColor: UIColor = .white
    
    /// The width of the tick in the selected state
    public var tickWidth: CGFloat = 1.5
    
    /// The color of the tick after selection
    public var tickColor: UIColor = .white
    
    /// The color of the check mark after selection in dark style
    public var tickDarkColor: UIColor = .white
    
    /// The color in the middle of the frame when it is not selected
    public var backgroundColor: UIColor = .black.withAlphaComponent(0.4)
    
    /// The color in the middle of the frame when it is not selected in dark style
    public var darkBackgroundColor: UIColor = .black.withAlphaComponent(0.4)
    
    /// Background color after selection
    public var selectedBackgroundColor: UIColor = .systemBlue
    
    /// Background color after selection in dark style
    public var selectedBackgroudDarkColor: UIColor = .systemBlue
    
    /// Border width when not selected
    public var borderWidth: CGFloat = 1.5
    
    /// Border color when not selected
    public var borderColor: UIColor = .white
    
    /// Border color when unselected in dark style
    public var borderDarkColor: UIColor = .white
    
    public init() { }
    
    public mutating func setThemeColor(_ color: UIColor) {
        selectedBackgroundColor = color
        selectedBackgroudDarkColor = color
    }
}
