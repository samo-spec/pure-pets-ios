//
//  LanguageType.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/1/7.
//

import Foundation

public enum LanguageType: Equatable {
    /// Follow the system language
    case system
    /// Simplified Chinese
    case simplifiedChinese
    /// Traditional Chinese
    case traditionalChinese
    /// Japanese
    case japanese
    /// Korean
    case korean
    /// English
    case english
    /// Thai
    case thai
    /// Indonesian
    case indonesia
    /// Vietnamese
    case vietnamese
    /// Russian
    case russian
    /// German
    case german
    /// French
    case french
    ///Arab
    case arabic
    /// Spain
    case spanish
    /// Portugal
    case portuguese
    /// Amharic
    case amharic
    /// Bengali
    case bengali
    /// Dhivehi
    case divehi
    /// Persian
    case persian
    /// Filipino
    case filipino
    /// Hausa
    case hausa
    /// Hebrew
    case hebrew
    /// Hindi
    case hindi
    /// Italian
    case italian
    /// Malay
    case malay
    /// Nepali
    case nepali
    /// Punjabi
    case punjabi
    /// Sinhala
    case sinhala
    /// Swahili
    case swahili
    /// Syriac
    case syriac
    /// Turkish
    case turkish
    /// Ukrainian
    case ukrainian
    /// 乌尔都语
    case urdu
    
    case custom(Bundle)
}
