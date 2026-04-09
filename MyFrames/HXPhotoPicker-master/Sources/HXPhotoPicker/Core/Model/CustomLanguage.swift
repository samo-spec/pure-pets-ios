//  CustomLanguage.swift
//  HXPhotoPicker
//
//  Created by Slience on 2021/1/7.
//  Created by Silence on 2024/3/30.
//  Copyright © 2024 Silence. All rights reserved.
//

import Foundation

public class CustomLanguage {
    
    /// Will be matched with Locale.preferredLanguages, and only those that match successfully will be used. Please ensure correctness
    public let language: String
    /// Language Bundle
    /// ```
    /// - xxx.lproj
    ///   - Localizable.strings
    /// ```
    public let bundle: Bundle
    
    public init(
        language: String,
        bundle: Bundle
    ) {
        self.language = language
        self.bundle = bundle
    }
}
