//
//  IndicatorType.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/1/8.
//

import UIKit

public enum IndicatorType {
    /// gradient ring
    /// Gradient circle
    case circle
    
    case circleJoin
    
    /// System chrysanthemum
    /// System Daisy
    case system
}

public protocol IndicatorTypeConfig {
    /// Loading indicator type
    /// Loading indicator type
    var indicatorType: IndicatorType { get set }
}

public extension IndicatorTypeConfig {
    var indicatorType: IndicatorType {
        get { PhotoManager.shared.indicatorType }
        set { PhotoManager.shared.indicatorType = newValue }
    }
}
