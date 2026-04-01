//
//  PPBannerViewModel.m
//  PurePets
//


#import "PPBannerViewModel.h"

@implementation PPBannerViewModel
#pragma mark - Init


#pragma mark - Designated Initializer

- (instancetype)initWithTitleEn:(NSString *)titleEn
                        titleAr:(NSString *)titleAr
                     descTextEn:(NSString *)descEn
                     descTextAr:(NSString *)descAr
                       postDate:(NSDate * _Nullable)postDate
              backgroundImageURL:(NSURL * _Nullable)bgURL
                  sampleImageURL:(NSURL * _Nullable)sampleURL
                   badgeImageURL:(NSURL * _Nullable)badgeURL
                     onTapAction:(PPBannerOnTapAction)action
                      textStyle:(PPBannerTextStyle)textStyle
                      onTapValue:(NSString * _Nullable)value
                        bannerID:(NSString *)bannerID
                        validity:(NSDateComponents * _Nullable)validity
                  expireInDateTime:(NSDate * _Nullable)expireInDateTime {
    if (self = [super init]) {
        _titleTextEn  = [titleEn copy];
        _titleTextAr  = [titleAr copy];
        _descTextEn   = [descEn copy];
        _descTextAr   = [descAr copy];
        _postDate     = postDate;
        
        if (postDate) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateStyle = NSDateFormatterMediumStyle;
            fmt.timeStyle = NSDateFormatterNoStyle;
            _postDateText = [fmt stringFromDate:postDate];
        } else {
            _postDateText = @"";
        }
        
        _backgroundImageURL = [bgURL copy];
        _sampleImageURL     = [sampleURL copy];
        _badgeImageURL      = [badgeURL copy];
        
        _onTapAction    = action;
        _textStyle      = textStyle;
        _onTapValue     = [value copy];
        _tapCount       = 0;
        
        _bannerID       = [bannerID copy];
        _pannerValidity       = [validity copy];
        _expireInDateTime = [expireInDateTime copy];
    }
    return self;
}

#pragma mark - Convenience Initializers

- (instancetype)initWithTitle:(NSString *)title
                  description:(NSString *)desc
                     postDate:(NSString *)postDateText
            backgroundImageURL:(NSURL *)bgURL
                sampleImageURL:(NSURL *)sampleURL
                 badgeImageURL:(NSURL *)badgeURL {
    return [self initWithTitleEn:title
                         titleAr:@""
                      descTextEn:desc
                      descTextAr:@""
                        postDate:nil
               backgroundImageURL:bgURL
                   sampleImageURL:sampleURL
                    badgeImageURL:badgeURL
                      onTapAction:PPBannerOnTapViewAccessory
                       textStyle:PPBannerTextStyleBlack
                       onTapValue:nil
                         bannerID:@""
                         validity:nil
                   expireInDateTime:nil];
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    
    //NSLog(@"initWithDictionaryyyyy %@",dict);

    
    
    NSString *bannerID    = dict[@"ChildsPannerID"] ?: dict[@"ChildBannerID"] ?: @"";
    NSString *titleEn     = dict[@"titleTextEn"] ?: @"";
    NSString *titleAr     = dict[@"titleTextAr"] ?: @"";
    NSString *descEn      = dict[@"descTextEn"] ?: @"";
    NSString *descAr      = dict[@"descTextAr"] ?: @"";

    NSDate *postDate = nil;
    if ([dict[@"postDate"] isKindOfClass:NSDate.class]) {
        postDate = dict[@"postDate"];
    } else if ([dict[@"postDate"] isKindOfClass:NSString.class]) {
        // Optional: parse ISO8601 strings if your backend sends text
        NSDateFormatter *isoFmt = [NSDateFormatter new];
        isoFmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
        postDate = [isoFmt dateFromString:dict[@"postDate"]];
    }

    NSURL *bgURL     = dict[@"backgroundImageURL"] ? [NSURL URLWithString:dict[@"backgroundImageURL"]] : nil;
    NSURL *sampleURL = dict[@"sampleImageURL"] ? [NSURL URLWithString:dict[@"sampleImageURL"]] : nil;
    NSURL *badgeURL  = dict[@"badgeImageURL"] ? [NSURL URLWithString:dict[@"badgeImageURL"]] : nil;

    PPBannerOnTapAction action = [dict[@"pannerOnTapAction"] integerValue];
    PPBannerTextStyle textStyle = [dict[@"pannerTextStyle"] integerValue];
    NSString *tapValue = dict[@"pannerOnTapValue"] ?: @"";

  
    id rawExpire = dict[@"expireInDateTime"];
    if ([rawExpire isKindOfClass:[FIRTimestamp class]]) {
        self.expireInDateTime = ((FIRTimestamp *)rawExpire).dateValue;
    } else if ([rawExpire respondsToSelector:@selector(doubleValue)]) {
        NSTimeInterval ts = [rawExpire doubleValue];
        if (ts > 0) self.expireInDateTime = [NSDate dateWithTimeIntervalSince1970:ts];
    }
    //NSLog(@"📅 Final expireInDateTime = %@", self.expireInDateTime);

    
    
    //Thread 1: "-[NSNull dateValue]: unrecognized selector sent to instance 0x206ebae68"
    
    ////NSLog(@"expireInDateTime %@",expireInDateTime);

    //NSLog(@"self.expireInDateTime %@",self.expireInDateTime);
    NSDateComponents *validity = nil;
    if ([dict[@"pannerValidity"] isKindOfClass:NSDictionary.class]) {
        NSDictionary *v = dict[@"pannerValidity"];
        validity = [[NSDateComponents alloc] init];
        validity.day    = [v[@"days"] integerValue];
        validity.hour   = [v[@"hours"] integerValue];
        validity.minute = [v[@"minutes"] integerValue];
    }

    self = [self initWithTitleEn:titleEn
                         titleAr:titleAr
                      descTextEn:descEn
                      descTextAr:descAr
                        postDate:postDate
               backgroundImageURL:bgURL
                   sampleImageURL:sampleURL
                    badgeImageURL:badgeURL
                      onTapAction:action
                       textStyle:textStyle
                       onTapValue:tapValue
                         bannerID:bannerID
                         validity:validity
                   expireInDateTime:self.expireInDateTime];
    if (self) {
        _tapCount = [dict[@"pannerTapsCount"] integerValue];
        _holderName = dict[@"BannerViewHolder"] ?: @"";
        _position   = [dict[@"BannerViewPosition"] integerValue];
        _transaction= [dict[@"BannerViewTransaction"] integerValue];
        
        [self logValidityAndExpiration:@"[BANNERS]  initWithDictionary"];
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict bannerID:(NSString *)bannerID {
    NSMutableDictionary *mutable = [dict mutableCopy];
    mutable[@"ChildsPannerID"] = bannerID; // normalize key
    
    return [[self alloc] initWithDictionary:mutable];
}








+ (BOOL)supportsSecureCoding { return YES; }

#pragma mark - NSSecureCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.bannerID forKey:@"bannerID"];
    [coder encodeObject:self.holderName forKey:@"holderName"];
    [coder encodeObject:self.backgroundImageURL forKey:@"backgroundImageURL"];
    [coder encodeObject:self.sampleImageURL forKey:@"sampleImageURL"];
    [coder encodeObject:self.badgeImageURL forKey:@"badgeImageURL"];
    
    [coder encodeObject:self.titleTextEn forKey:@"titleTextEn"];
    [coder encodeObject:self.titleTextAr forKey:@"titleTextAr"];
    [coder encodeObject:self.descTextEn forKey:@"descTextEn"];
    [coder encodeObject:self.descTextAr forKey:@"descTextAr"];
    
    [coder encodeObject:self.postDateText forKey:@"postDateText"];
    [coder encodeObject:self.postDate forKey:@"postDate"];
    [coder encodeObject:self.expireInDateTime forKey:@"expireInDateTime"];
    [coder encodeObject:self.pannerValidity forKey:@"pannerValidity"];
    
    [coder encodeInteger:self.onTapAction forKey:@"onTapAction"];
    [coder encodeObject:self.onTapValue forKey:@"onTapValue"];
    [coder encodeInteger:self.tapCount forKey:@"tapCount"];
    
    [coder encodeInteger:self.textStyle forKey:@"textStyle"];
    [coder encodeInteger:self.position forKey:@"position"];
    [coder encodeInteger:self.transaction forKey:@"transaction"];
    
    [self logValidityAndExpiration:@"[BANNERS]  encodeWithCoder"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    NSString *bannerID = [coder decodeObjectOfClass:NSString.class forKey:@"bannerID"];
    NSString *holderName = [coder decodeObjectOfClass:NSString.class forKey:@"holderName"];
    NSURL *backgroundImageURL = [coder decodeObjectOfClass:NSURL.class forKey:@"backgroundImageURL"];
    NSURL *sampleImageURL = [coder decodeObjectOfClass:NSURL.class forKey:@"sampleImageURL"];
    NSURL *badgeImageURL = [coder decodeObjectOfClass:NSURL.class forKey:@"badgeImageURL"];

    NSString *titleTextEn = [coder decodeObjectOfClass:NSString.class forKey:@"titleTextEn"];
    NSString *titleTextAr = [coder decodeObjectOfClass:NSString.class forKey:@"titleTextAr"];
    NSString *descTextEn  = [coder decodeObjectOfClass:NSString.class forKey:@"descTextEn"];
    NSString *descTextAr  = [coder decodeObjectOfClass:NSString.class forKey:@"descTextAr"];

    NSString *postDateText = [coder decodeObjectOfClass:NSString.class forKey:@"postDateText"]; // fallback only
    NSDate *postDate       = [coder decodeObjectOfClass:NSDate.class forKey:@"postDate"];
    NSDate *expireInDateTime = [coder decodeObjectOfClass:NSDate.class forKey:@"expireInDateTime"];
    NSDateComponents *pannerValidity = [coder decodeObjectOfClass:NSDateComponents.class forKey:@"pannerValidity"];

    PPBannerOnTapAction action = (PPBannerOnTapAction)[coder decodeIntegerForKey:@"onTapAction"];
    NSString *onTapValue = [coder decodeObjectOfClass:NSString.class forKey:@"onTapValue"];
    NSInteger tapCount = [coder decodeIntegerForKey:@"tapCount"];

    PPBannerTextStyle textStyle = (PPBannerTextStyle)[coder decodeIntegerForKey:@"textStyle"];
    NSInteger position = [coder decodeIntegerForKey:@"position"];
    NSInteger transaction = [coder decodeIntegerForKey:@"transaction"];

    self = [self initWithTitleEn:titleTextEn
                         titleAr:titleTextAr
                      descTextEn:descTextEn
                      descTextAr:descTextAr
                        postDate:postDate
               backgroundImageURL:backgroundImageURL
                   sampleImageURL:sampleImageURL
                    badgeImageURL:badgeImageURL
                      onTapAction:action
                       textStyle:textStyle
                       onTapValue:onTapValue
                         bannerID:bannerID];
    if (self) {
        _holderName = [holderName copy];
        _tapCount   = tapCount;
        _position   = position;
        _transaction= transaction;
        // If we didn't have a postDate but we have a stored postDateText, preserve it.
        if (!postDate && postDateText) {
            _postDateText = [postDateText copy];
        }
        _pannerValidity = pannerValidity;
        _expireInDateTime = expireInDateTime;
    }
    
    [self logValidityAndExpiration:@"[BANNERS]  initWithCoder"];
    return self;
}




#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    PPBannerViewModel *copy = [[[self class] allocWithZone:zone] initWithTitleEn:self.titleTextEn
                                                                        titleAr:self.titleTextAr
                                                                     descTextEn:self.descTextEn
                                                                     descTextAr:self.descTextAr
                                                                       postDate:self.postDate
                                                              backgroundImageURL:self.backgroundImageURL
                                                                  sampleImageURL:self.sampleImageURL
                                                                   badgeImageURL:self.badgeImageURL
                                                                     onTapAction:self.onTapAction
                                                                      textStyle:self.textStyle
                                                                      onTapValue:self.onTapValue
                                                                        bannerID:self.bannerID];
    copy.holderName = [self.holderName copy];
    copy.tapCount   = self.tapCount;
    copy.position   = self.position;
    copy.transaction= self.transaction;
    copy.pannerValidity = [self.pannerValidity copy];
    copy.expireInDateTime = [self.expireInDateTime copy];
    return copy;
}


- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"titleTextEn"] = self.titleTextEn ?: @"";
    d[@"titleTextAr"] = self.titleTextAr ?: @"";
    d[@"descTextEn"]  = self.descTextEn  ?: @"";
    d[@"descTextAr"]  = self.descTextAr  ?: @"";
    
    if (self.backgroundImageURL) d[@"backgroundImageURL"] = self.backgroundImageURL.absoluteString;
    if (self.sampleImageURL)     d[@"sampleImageURL"] = self.sampleImageURL.absoluteString;
    if (self.badgeImageURL)      d[@"badgeImageURL"] = self.badgeImageURL.absoluteString;
    
    d[@"pannerOnTapAction"] = @(self.onTapAction);
    d[@"pannerOnTapValue"]  = self.onTapValue ?: @"";
    d[@"pannerTapsCount"]   = @(self.tapCount);
    d[@"pannerTextStyle"]   = @(self.textStyle);
    d[@"BannerViewPosition"]= @(self.position);
    d[@"BannerViewTransaction"] = @(self.transaction);
    
    
    if (self.expireInDateTime) {
        d[@"expireInDateTime"] = @([self.expireInDateTime timeIntervalSince1970]);
    }
    if (self.pannerValidity) {
        d[@"pannerValidity"] = @{
            @"days": @(self.pannerValidity.day),
            @"hours": @(self.pannerValidity.hour),
            @"minutes": @(self.pannerValidity.minute)
        };
    }
    
    [self logValidityAndExpiration:@"[BANNERS]  toDictionary"];
    
    return d;
}

#pragma mark - Helpers

- (NSString *)localizedTitleText {
    return (Language.languageVal == 1 ? self.titleTextAr : self.titleTextEn) ?: @"";
}

- (NSString *)localizedDescText {
    return (Language.languageVal == 1 ? self.descTextAr : self.descTextEn) ?: @"";
}

- (BOOL)isExpired {
    NSDate *now = [NSDate date];
    if (self.expireInDateTime && [now compare:self.expireInDateTime] != NSOrderedAscending) {
        return YES;
    }
    if (self.pannerValidity && self.postDate) {
        NSDate *exp = [[NSCalendar currentCalendar] dateByAddingComponents:self.pannerValidity
                                                                    toDate:self.postDate
                                                                   options:0];
        return [now compare:exp] != NSOrderedAscending;
    }
    return NO;
}

- (nullable NSString *)countdownTimeRemaining {
    
    //[self logValidityAndExpiration:@"[BANNERS]  countdownTimeRemaining"];

    
    NSDate *now = [NSDate date];
    NSDate *target = self.expireInDateTime;
    
    if (!target && self.pannerValidity && self.postDate) {
        target = [[NSCalendar currentCalendar] dateByAddingComponents:self.pannerValidity toDate:self.postDate options:0];
    }
    
    
    //target = [[NSCalendar currentCalendar] dateByAddingComponents:self.pannerValidity toDate:self.postDate options:0];
    
    if (!target) return nil;
    
    if ([now compare:target] != NSOrderedAscending) return @"0m";
    
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *diff = [cal components:NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute
                                     fromDate:now
                                       toDate:target
                                      options:0];
    NSMutableString *s = [NSMutableString string];
    if (diff.day > 0)   [s appendFormat:@"%ldd ", (long)diff.day];
    if (diff.hour > 0)  [s appendFormat:@"%ldh ", (long)diff.hour];

    if (diff.minute >= 0) {
        [s appendFormat:@"%ldm", (long)diff.minute];  // Appending minutes with 'm'
    }
    if (diff.second >= 0) {
        [s appendFormat:@"%lds", (long)diff.second];  // Appending seconds with 's'
    }
    
    
    ////NSLog(@" \n \n \n  \n \n now: %@    \n target: %@    \n self.pannerValidity: %@    \n self.postDate: %@    \n diff: %@   \n \n \n  \n  ",now,target,self.pannerValidity,self.postDate,diff);

    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


#pragma mark - Designated Initializer

- (instancetype)initWithTitleEn:(NSString *)titleEn
                        titleAr:(NSString *)titleAr
                     descTextEn:(NSString *)descEn
                     descTextAr:(NSString *)descAr
                       postDate:(NSDate * _Nullable)postDate
              backgroundImageURL:(NSURL * _Nullable)bgURL
                  sampleImageURL:(NSURL * _Nullable)sampleURL
                   badgeImageURL:(NSURL * _Nullable)badgeURL
                     onTapAction:(PPBannerOnTapAction)action
                      textStyle:(PPBannerTextStyle)textStyle
                      onTapValue:(NSString * _Nullable)value
                        bannerID:(NSString *)bannerID {
    if (self = [super init]) {
        _titleTextEn  = [titleEn copy];
        _titleTextAr  = [titleAr copy];
        _descTextEn   = [descEn copy];
        _descTextAr   = [descAr copy];
        _postDate     = postDate;

        if (postDate) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateStyle = NSDateFormatterMediumStyle;
            fmt.timeStyle = NSDateFormatterNoStyle;
            _postDateText = [fmt stringFromDate:postDate];
        } else {
            _postDateText = @"";
        }

        _backgroundImageURL = [bgURL copy];
        _sampleImageURL     = [sampleURL copy];
        _badgeImageURL      = [badgeURL copy];

        _onTapAction    = action;
        _textStyle      = textStyle;
        _onTapValue     = [value copy];
        _tapCount       = 0;

        _bannerID       = [bannerID copy];
        _pannerValidity = nil;
        _expireInDateTime = nil;
        
       // [self logValidityAndExpiration:@"[BANNERS]  "];

    }
    return self;
}


#pragma mark - Debug Logging Helper
- (void)logValidityAndExpiration:(NSString *)context {
    //NSLog(@"[PPBannerViewModel][%@] bannerID=%@ holder=%@", context, self.bannerID, self.holderName);

    if (self.expireInDateTime) {
        //NSLog(@"  • expireInDateTime = %@ (ts=%.0f)", self.expireInDateTime, [self.expireInDateTime timeIntervalSince1970]);
    } else {
       //NSLog(@"  • expireInDateTime = nil");
    }

    if (self.pannerValidity) {
        NSLog(@"  • pannerValidity = %ldd %ldh %ldm", (long)self.pannerValidity.day, (long)self.pannerValidity.hour, (long)self.pannerValidity.minute);
        if (self.postDate) {
            NSDate *calcExp = [[NSCalendar currentCalendar] dateByAddingComponents:self.pannerValidity
                                                                            toDate:self.postDate
                                                                           options:0];
            NSLog(@"    → Effective expiry (postDate + validity) = %@", calcExp);
        }
    } else {
        //NSLog(@"  • pannerValidity = nil");
    }
}



@end




/*
 
 - (NSString *)localizedTitleText {
     if (Language.languageVal == 1 && _titleTextAr.length > 0) {
         return _titleTextAr;
     }
     return _titleTextEn;
 }

 - (NSString *)localizedDescText {
     if (Language.languageVal == 1 && _descTextAr.length > 0) {
         return _descTextAr;
     }
     return _descTextEn;
 }

 - (BOOL)isExpired {
     if (!_expireInDateTime) return NO;
     return ([[NSDate date] timeIntervalSinceDate:_expireInDateTime] > 0);
 }

 - (NSString *)countdownTimeRemaining {
     if (!_expireInDateTime) return nil;

     NSDate *now = [NSDate date];
     if ([now timeIntervalSinceDate:_expireInDateTime] >= 0) return @"0m";

     NSCalendar *cal = [NSCalendar currentCalendar];
     NSUInteger units = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
     NSDateComponents *diff = [cal components:units fromDate:now toDate:_expireInDateTime options:0];

     NSMutableString *result = [NSMutableString string];
     if (diff.day > 0)   [result appendFormat:@"%ldd ", (long)diff.day];
     if (diff.hour >= 0) [result appendFormat:@"%ldh ", (long)diff.hour];
     if (diff.minute >= 0) [result appendFormat:@"%ldm", (long)diff.minute];
     return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
 }


 - (NSDictionary *)toDictionary {
     return @{
         @"ChildsPannerID"   : PPSafeString(self.bannerID),
         @"titleTextEn"      : PPSafeString(self.titleTextEn),
         @"titleTextAr"      : PPSafeString(self.titleTextAr),
         @"descTextEn"       : PPSafeString(self.descTextEn),
         @"descTextAr"       : PPSafeString(self.descTextAr),
         @"postDate"         : self.postDate ?: [NSNull null],
         @"postDateText"     : PPSafeString(self.postDateText),
         @"backgroundImageURL": PPSafeString(self.backgroundImageURL.absoluteString),
         @"sampleImageURL"   : PPSafeString(self.sampleImageURL.absoluteString),
         @"badgeImageURL"    : PPSafeString(self.badgeImageURL.absoluteString),
         @"pannerOnTapAction": @(self.onTapAction),
         @"pannerTextStyle"  : @(self.pannerTextStyle),
         @"pannerOnTapValue" : PPSafeString(self.onTapValue),
         @"pannerTapsCount"  : @(self.tapCount),
         @"expireInDateTime" : self.expireInDateTime ?: [NSNull null],
         @"pannerValidity"   : self.validityDuration ? [NSString stringWithFormat:@"%ldd %ldh %ldm",
                                                        (long)self.validityDuration.day,
                                                        (long)self.validityDuration.hour,
                                                        (long)self.validityDuration.minute] : @""
     };
 }
 */



/*//
//  PPBannerViewModel.m
//  PurePets
//

// PPBannerViewModel.m

#import "PPBannerViewModel.h"

@implementation PPBannerViewModel

- (instancetype)initWithTitle:(NSString *)title
                  description:(NSString *)desc
                     postDate:(NSString *)postDateText
            backgroundImageURL:(NSURL *)bgURL
                sampleImageURL:(NSURL *)sampleURL
                 badgeImageURL:(NSURL *)badgeURL {
    if (self = [super init]) {
        // Initialize with provided values (assume single language usage)
        _titleTextEn      = [title copy];
        _titleTextAr      = @"";            // default empty if not provided
        _descTextEn       = [desc copy];
        _descTextAr       = @"";
        _postDateText     = [postDateText copy];
        _backgroundImageURL = [bgURL copy];
        _sampleImageURL     = [sampleURL copy];
        _badgeImageURL      = [badgeURL copy];
        _postDate        = nil;
        _onTapAction     = PPBannerOnTapViewAccessory;  // default action
        _pannerTextStyle     = PPBannerTextStyleBlack;  // default action
        _onTapValue      = nil;
        _tapCount        = 0;
        _expireInDateTime  = nil;
        _validityDuration = nil;
        _bannerID        = @"";  // will be set if available
    }
    return self;
}

// Extended initializer that covers all properties
- (instancetype)initWithTitleEn:(NSString *)titleEn
                        titleAr:(NSString *)titleAr
                     descTextEn:(NSString *)descEn
                     descTextAr:(NSString *)descAr
                       postDate:(NSDate * _Nullable)postDate
              backgroundImageURL:(NSURL * _Nullable)bgURL
                  sampleImageURL:(NSURL * _Nullable)sampleURL
                   badgeImageURL:(NSURL * _Nullable)badgeURL
                     onTapAction:(PPBannerOnTapAction)action
                      textStyle:(PPBannerTextStyle)textStyle
                      onTapValue:(NSString * _Nullable)value
                        bannerID:(NSString *)bannerID {
    if (self = [super init]) {
        _titleTextEn      = [titleEn copy];
        _titleTextAr      = [titleAr copy];
        _descTextEn       = [descEn copy];
        _descTextAr       = [descAr copy];
        if (postDate) {
            _postDate = postDate;
            // Format the date into a user-facing string (e.g., "Sep 7, 2025")
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateStyle:NSDateFormatterMediumStyle];
            [fmt setTimeStyle:NSDateFormatterNoStyle];
            _postDateText = [fmt stringFromDate:postDate];
        } else {
            _postDate = nil;
            _postDateText = @"";
        }
        _backgroundImageURL = [bgURL copy];
        _sampleImageURL     = [sampleURL copy];
        _badgeImageURL      = [badgeURL copy];
        _onTapAction     = action;
        _pannerTextStyle     = textStyle;
        _onTapValue      = [value copy];
        _tapCount        = 0;
        _expireInDateTime  = nil;
        _validityDuration = nil;
        _bannerID        = [bannerID copy];
    }
    return self;
}

// Fallback default init funnels to designated initializer
- (instancetype)init {
    return [self initWithTitle:@""
                   description:@""
                      postDate:@""
             backgroundImageURL:nil
                 sampleImageURL:nil
                  badgeImageURL:nil];
}

// Initialize from Firestore dictionary (child banner data)
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    // Extract fields from the dictionary safely
    NSString *bannerID    = dict[@"ChildsPannerID"] ?: dict[@"ChildBannerID"] ?: @"";
    NSString *titleEn     = dict[@"titleTextEn"] ?: @"";
    NSString *titleAr     = dict[@"titleTextAr"] ?: @"";
    NSString *descEn      = dict[@"descTextEn"] ?: @"";
    NSString *descAr      = dict[@"descTextAr"] ?: @"";
    NSString *postDateStr = dict[@"postDate"] ?: @"";  // could be a timestamp string
    NSDate *postDate = nil;
    if ([postDateStr isKindOfClass:[NSString class]] && postDateStr.length > 0) {
        // Attempt to parse date string if in a standard format, otherwise leave as nil
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        // (Assume ISO8601 or known format from server, here just try a generic)
        [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        postDate = [df dateFromString:postDateStr];
    } else if ([dict[@"postDate"] isKindOfClass:[NSDate class]]) {
        postDate = dict[@"postDate"];
    }
    // URLs: assume stored as strings in Firestore
    NSURL *bgURL    = nil;
    NSURL *sampleURL= nil;
    NSURL *badgeURL = nil;
    if ([dict[@"backgroundImageURL"] isKindOfClass:[NSString class]]) {
        bgURL = [NSURL URLWithString:dict[@"backgroundImageURL"]];
    }
    if ([dict[@"sampleImageURL"] isKindOfClass:[NSString class]]) {
        sampleURL = [NSURL URLWithString:dict[@"sampleImageURL"]];
    }
    if ([dict[@"badgeImageURL"] isKindOfClass:[NSString class]]) {
        badgeURL = [NSURL URLWithString:dict[@"badgeImageURL"]];
    }
    PPBannerOnTapAction action = PPBannerOnTapViewAccessory;
    if (dict[@"pannerOnTapAction"] || dict[@"bannerOnTapAction"]) {
        // Get the numeric action or map string to enum
        id actionField = dict[@"pannerOnTapAction"] ?: dict[@"bannerOnTapAction"];
        if ([actionField isKindOfClass:[NSNumber class]]) {
            action = (PPBannerOnTapAction)[actionField integerValue];
        } else if ([actionField isKindOfClass:[NSString class]]) {
            NSString *actionStr = (NSString *)actionField;
            if ([actionStr isEqualToString:@"PPBannerOnTapViewAccessory"]) {
                action = PPBannerOnTapViewAccessory;
            } else if ([actionStr isEqualToString:@"PPBannerOnTapViewAd"]) {
                action = PPBannerOnTapViewAd;
            } else if ([actionStr isEqualToString:@"PPBannerOnTapOpenUrl"]) {
                action = PPBannerOnTapOpenUrl;
            } else if ([actionStr isEqualToString:@"PPBannerOnTapCallPhoneNumber"]) {
                action = PPBannerOnTapCallPhoneNumber;
            } else if ([actionStr isEqualToString:@"PPBannerOnTapWhatsApp"]) {
                action = PPBannerOnTapWhatsApp;
            }
        }
    }
    NSUInteger pannerTextStyle      = [dict[@"pannerTextStyle"] interval];
    NSString *tapValue = dict[@"pannerOnTapValue"] ?: dict[@"bannerOnTapValue"] ?: @"";
    NSNumber *taps = dict[@"pannerTapsCount"] ?: dict[@"bannerTapsCount"] ?: @(0);
    NSUInteger tapCount = [taps unsignedIntegerValue];
    // Validity and expiration
    NSDate *expires = nil;
    if (dict[@"expireInDateTime"]) {
        // Firestore timestamp might come as an NSDate or seconds.
        if ([dict[@"expireInDateTime"] isKindOfClass:[NSDate class]]) {
            expires = dict[@"expireInDateTime"];
        } else if ([dict[@"expireInDateTime"] isKindOfClass:[NSNumber class]]) {
            // If it's a timestamp in seconds
            NSTimeInterval ts = [dict[@"expireInDateTime"] doubleValue];
            expires = [NSDate dateWithTimeIntervalSince1970:ts];
        } else if ([dict[@"expireInDateTime"] isKindOfClass:[NSString class]]) {
            // Try parsing string timestamp
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
            expires = [df dateFromString:dict[@"expireInDateTime"]];
        }
    }
    NSDateComponents *validity = nil;
    if (dict[@"pannerValidity"] || dict[@"validateDaysHoursMins"]) {
        // If admin provided a validity duration, parse it (could be in a custom format, e.g. "5d3h20m")
        NSString *valStr = dict[@"pannerValidity"] ?: dict[@"validateDaysHoursMins"];
        if ([valStr isKindOfClass:[NSString class]] && valStr.length > 0) {
            validity = [[NSDateComponents alloc] init];
            // Simple parse example: assume format "Xd Yh Zm"
            NSScanner *scanner = [NSScanner scannerWithString:valStr];
            NSInteger days, hours, mins;
            days = hours = mins = 0;
            if ([scanner scanInteger:&days]) { validity.day = days; }
            [scanner scanUpToString:@"h" intoString:NULL]; // skip to hours part
            if ([scanner scanInteger:&hours]) { validity.hour = hours; }
            [scanner scanUpToString:@"m" intoString:NULL]; // skip to mins part
            if ([scanner scanInteger:&mins]) { validity.minute = mins; }
        }
    }
    // Initialize with the gathered values
    if (self = [self initWithTitleEn:titleEn
                             titleAr:titleAr
                          descTextEn:descEn
                          descTextAr:descAr
                            postDate:postDate
                   backgroundImageURL:bgURL
                       sampleImageURL:sampleURL
                        badgeImageURL:badgeURL
                          onTapAction:action
                           textStyle:(PPBannerTextStyle)pannerTextStyle
                           onTapValue:tapValue
                             bannerID:bannerID]) {
        _tapCount = tapCount;
        _expireInDateTime = expires;
        _pannerValidity = validity;
    }
    return self;
}

// Get the appropriate title based on the current locale or app language setting.
- (NSString *)localizedTitleText {
    if (Language.languageVal == 1 && _titleTextAr.length > 0) {
        return _titleTextAr;
    }
    return _titleTextEn;
}

// Similarly for description text.
- (NSString *)localizedDescText {
    if (Language.languageVal == 1 && _descTextAr.length > 0) {
        return _descTextAr;
    }
    return _descTextEn;
}

// Check if the banner is expired (current time past expireInDateTime).
- (BOOL)isExpired {
    if (!_expireInDateTime) {
        return NO;
    }
    return ([[NSDate date] timeIntervalSinceDate:_expireInDateTime] > 0);
}

// Compute remaining time as a formatted string (days, hours, minutes).
- (NSString *)countdownTimeRemaining {
    if (!_expireInDateTime) {
        // If no specific expiration date, but maybe a validity duration is set:
        if (_pannerValidity) {
            // Compute expiration by adding duration to postDate or current date
            NSDate *startDate = _postDate ? _postDate : [NSDate date];
            NSCalendar *cal = [NSCalendar currentCalendar];
            NSDate *calcExpire = [cal dateByAddingComponents:_pannerValidity toDate:startDate options:0];
            self.expireInDateTime = calcExpire; // update expireInDateTime for consistency
        } else {
            return nil;
        }
    }
    // Now _expireInDateTime is set
    NSDate *now = [NSDate date];
    if ([now timeIntervalSinceDate:_expireInDateTime] >= 0) {
        return @"0m"; // already expired or expiring now
    }
    // Calculate difference
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSUInteger units = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    NSDateComponents *diff = [cal components:units fromDate:now toDate:_expireInDateTime options:0];
    NSInteger days = diff.day;
    NSInteger hours = diff.hour;
    NSInteger mins = diff.minute;
    // Format to a string, e.g. "2d 5h 30m"
    NSMutableString *result = [NSMutableString string];
    if (days > 0) {
        [result appendFormat:@"%ldd ", (long)days];
    }
    if (hours >= 0) {
        [result appendFormat:@"%ldh ", (long)hours];
    }
    if (mins >= 0) {
        [result appendFormat:@"%ldm", (long)mins];
    }
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@end
*/
