#import "PetAd.h"
#import "MainKindsModel.h"
#import "ArabicNormalizer.h"
#import "CitiesManager.h"
#import <math.h>
#import <float.h>


@interface PetAd ()
@property (nonatomic, copy) NSString *searchTitle;
@end

static inline BOOL PPIsFiniteCoordinate(double value) {
    return isfinite(value);
}

static inline BOOL PPIsValidCoordinatePair(double latitude, double longitude) {
    if (!PPIsFiniteCoordinate(latitude) || !PPIsFiniteCoordinate(longitude)) return NO;
    if (latitude < -90.0 || latitude > 90.0) return NO;
    if (longitude < -180.0 || longitude > 180.0) return NO;
    if (fabs(latitude) < DBL_EPSILON && fabs(longitude) < DBL_EPSILON) return NO; // invalid sentinel (0,0)
    return YES;
}

static PetAdStatus PPStatusFromFirestore(id rawStatus) {
    if ([rawStatus isKindOfClass:NSNumber.class]) {
        return (PetAdStatus)[rawStatus integerValue];
    }

    if ([rawStatus isKindOfClass:NSString.class]) {
        NSString *statusString = [(NSString *)rawStatus lowercaseString];
        if ([statusString isEqualToString:@"active"]) return PetAdStatusActive;
        if ([statusString isEqualToString:@"sold"]) return PetAdStatusSold;
        if ([statusString isEqualToString:@"expired"]) return PetAdStatusExpired;
        if ([statusString isEqualToString:@"archived"]) return PetAdStatusArchived;
        if ([statusString isEqualToString:@"rejected"]) return PetAdStatusRejected;
        return PetAdStatusDraft;
    }

    return PetAdStatusDraft;
}

#pragma mark - PetAd
@implementation PetAd

#pragma mark - Computed State

- (BOOL)isDiscounted {
    return self.discountPercent && self.discountPercent.floatValue > 0;
}

- (BOOL)isNew {
    if (!self.createdAt) return NO;
    return [[NSDate date] timeIntervalSinceDate:self.createdAt] < (60 * 60 * 24 * 3); // 3 days
}

- (BOOL)isActive {
    return self.status == PetAdStatusActive && !self.isSold;
}

- (BOOL)isVisible {
    return self.visibility == PetAdVisibilityPublic;
}

#pragma mark - Price Helpers

- (NSNumber *)finalPrice {
    if (!self.price) return nil;
    if (!self.isDiscounted) return self.price;

    NSDecimalNumber *original =
    [NSDecimalNumber decimalNumberWithDecimal:self.price.decimalValue];

    NSDecimalNumber *discount =
    [NSDecimalNumber decimalNumberWithDecimal:self.discountPercent.decimalValue];

    NSDecimalNumber *hundred = [NSDecimalNumber decimalNumberWithString:@"100"];
    NSDecimalNumber *multiplier =
    [[hundred decimalNumberBySubtracting:discount] decimalNumberByDividingBy:hundred];

    return [original decimalNumberByMultiplyingBy:multiplier];
}


#pragma mark - Diffable Identity

- (NSUInteger)hash {
    // Stable, unique, production-safe
    return self.adID.hash;
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:PetAd.class]) return NO;

    PetAd *other = (PetAd *)object;

    // Identity equality ONLY
    return (self.adID && other.adID)
        ? [self.adID isEqualToString:other.adID]
        : NO;
}











#pragma mark - Derived Normalized Search Title
// The searchTitle property getter returns the normalized adTitle for search purposes.
- (NSString *)searchTitle
{
    if (_searchTitle != nil && _searchTitle.length > 0) {
        return _searchTitle;
    }
    // Always return a normalized version of adTitle if _searchTitle is not set.
    return [ArabicNormalizer normalize:self.adTitle ?: @""];
}


+ (instancetype)adFromFirestoreData:(NSDictionary *)data documentID:(NSString *)docID {
    return [[self alloc] initWithDictionary:data documentID:docID];
}

#pragma mark - Sharing Methods

+ (void)sharePetAd:(PetAd *)petAd fromViewController:(UIViewController *)vc {
    [self sharePetAd:petAd fromViewController:vc sourceView:nil];
}

+ (void)sharePetAd:(PetAd *)petAd
fromViewController:(UIViewController *)vc
        sourceView:(nullable UIView *)sourceView {
    
    // Safe presentation check
    if (!vc.isViewLoaded || !vc.view.window) {
        // Try again after a delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sharePetAd:petAd fromViewController:vc sourceView:sourceView];
        });
        return;
    }
    
    // Don't present if already presenting
    if (vc.presentedViewController) {
        NSLog(@"ViewController already presenting something");
        return;
    }
    
    // Create the share message
    NSString *message = [self shareMessageForPetAd:petAd];
    
    // Prepare share items
    NSMutableArray *items = [NSMutableArray arrayWithObject:message];
    
    // Add first image if available
    NSURL *imageURL = [self firstImageURLForPetAd:petAd];
    if (imageURL) {
        [items addObject:imageURL];
    }
    
    // Create activity view controller
    UIActivityViewController *avc = [[UIActivityViewController alloc]
                                     initWithActivityItems:items
                                     applicationActivities:nil];
    
    // Configure for iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        avc.popoverPresentationController.sourceView = sourceView ?: vc.view;
        
        if (sourceView) {
            avc.popoverPresentationController.sourceRect = sourceView.bounds;
        } else {
            // Default to center of view
            avc.popoverPresentationController.sourceRect = CGRectMake(
                vc.view.bounds.size.width / 2,
                vc.view.bounds.size.height / 2,
                1, 1
            );
        }
    }
    
    // Add completion handler
    avc.completionWithItemsHandler = ^(UIActivityType __nullable activityType,
                                       BOOL completed,
                                       NSArray * __nullable returnedItems,
                                       NSError * __nullable error) {
        if (completed) {
            NSLog(@"Pet ad shared successfully via %@", activityType);
            // You can track analytics here
            [self trackShareAnalyticsForPetAd:petAd activityType:activityType];
        } else if (error) {
            NSLog(@"Sharing error: %@", error.localizedDescription);
        }
    };
    
    // Present with animation
    [vc presentViewController:avc animated:YES completion:nil];
}

#pragma mark - Instance Methods for Sharing

- (void)shareFromViewController:(UIViewController *)vc {
    [PetAd sharePetAd:self fromViewController:vc];
}

- (void)shareFromViewController:(UIViewController *)vc sourceView:(nullable UIView *)sourceView {
    [PetAd sharePetAd:self fromViewController:vc sourceView:sourceView];
}

#pragma mark - Share Content Generation

+ (NSString *)shareMessageForPetAd:(PetAd *)petAd {
    NSMutableString *message = [NSMutableString string];
    
    // Title/Introduction
    [message appendFormat:@"%@\n\n", kLang(@"Check out this pet ad!")];
    
    // Title
    if (petAd.adTitle.length > 0) {
        [message appendFormat:@"%@: %@\n", kLang(@"Title"), petAd.adTitle];
    }
    
    // Description (truncated if too long)
    if (petAd.adDescription.length > 0) {
        NSString *shortDesc = petAd.adDescription;
        if (shortDesc.length > 100) {
            shortDesc = [[shortDesc substringToIndex:100] stringByAppendingString:@"..."];
        }
        [message appendFormat:@"%@: %@\n", kLang(@"Description"), shortDesc];
    }
    
    // Category Information
    if (petAd.category > 0) {
        NSString *mainCategoryName = [MainKindsModel kindNameForID:petAd.category];
        if (mainCategoryName) {
            [message appendFormat:@"%@: %@\n", kLang(@"Category"), mainCategoryName];
        }
    }
    
    if (petAd.subcategory > 0) {
        NSArray *subKinds = [MKM getSubKindArray:petAd.category];
        NSString *subCategoryName = [SubKindModel getSubKindName:petAd.subcategory
                                                  subKindsArrayLocal:subKinds];
        if (subCategoryName) {
            [message appendFormat:@"%@: %@\n", kLang(@"Breed"), subCategoryName];
        }
    }
    
    // Price Information
    if (petAd.price) {
        NSString *priceString = [self formattedPrice:petAd.price
                                      discountPercent:petAd.discountPercent];
        [message appendFormat:@"%@: %@\n", kLang(@"Price"), priceString];
    }
    
    // Age
    if (petAd.petAgeMonths) {
        NSString *ageString = [self formattedAge:petAd.petAgeMonths];
        [message appendFormat:@"%@: %@\n", kLang(@"Age"), ageString];
    }
    
    // Gender
    NSString *genderString = petAd.isFemale ? kLang(@"Female") : kLang(@"Male");
    [message appendFormat:@"%@: %@\n", kLang(@"Gender"), genderString];
    
    // Location (if you have location names)
    if (petAd.locationName.length > 0 || petAd.adLocation > 0) {
        // Assuming you have a method to get location name from ID
        NSString *locationName = petAd.locationName.length > 0
            ? petAd.locationName
            : [self locationNameForID:petAd.adLocation];
        if (locationName) {
            [message appendFormat:@"%@: %@\n", kLang(@"Location"), locationName];
        }
    }
    
    // Status
    NSString *statusString = petAd.isSold ? kLang(@"Sold") : kLang(@"Available");
    [message appendFormat:@"%@: %@", kLang(@"Status"), statusString];
    
    return [message copy];
}

#pragma mark - Helper Methods for Sharing

+ (NSString *)formattedPrice:(NSNumber *)price discountPercent:(NSNumber *)discountPercent {
    if (!price) return @"N/A";
    
    if (discountPercent && discountPercent.floatValue > 0) {
        // Calculate discounted price
        NSDecimalNumber *original = [NSDecimalNumber decimalNumberWithDecimal:price.decimalValue];
        NSDecimalNumber *discount = [NSDecimalNumber decimalNumberWithDecimal:discountPercent.decimalValue];
        NSDecimalNumber *oneHundred = [NSDecimalNumber decimalNumberWithString:@"100"];
        
        // Calculate discount multiplier (1 - discountPercent/100)
        NSDecimalNumber *discountMultiplier = [[oneHundred decimalNumberBySubtracting:discount]
                                               decimalNumberByDividingBy:oneHundred];
        NSDecimalNumber *finalPrice = [original decimalNumberByMultiplyingBy:discountMultiplier];
        
        return [NSString stringWithFormat:@"%@ (Was %@, %@%% off)",
                [self formatCurrency:finalPrice],
                [self formatCurrency:price],
                discountPercent];
    } else {
        return [self formatCurrency:price];
    }
}

+ (NSString *)formatCurrency:(NSNumber *)amount {
    if (!amount) return @"N/A";
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_QA"];
    formatter.currencyCode = @"QAR";
    formatter.maximumFractionDigits = 2;
    formatter.minimumFractionDigits = 0;
    
    return [formatter stringFromNumber:amount] ?: @"";
}

+ (NSString *)formattedAge:(NSNumber *)ageInMonths {
    if (!ageInMonths) return @"N/A";
    
    NSInteger months = ageInMonths.integerValue;
    
    if (months < 1) {
        return kLang(@"Less than 1 month");
    } else if (months < 12) {
        return [NSString stringWithFormat:@"%@ %@", @(months),
                months == 1 ? kLang(@"month") : kLang(@"months")];
    } else {
        NSInteger years = months / 12;
        NSInteger remainingMonths = months % 12;
        
        if (remainingMonths == 0) {
            return [NSString stringWithFormat:@"%@ %@", @(years),
                    years == 1 ? kLang(@"year") : kLang(@"years")];
        } else {
            return [NSString stringWithFormat:@"%@ %@, %@ %@",
                    @(years), years == 1 ? kLang(@"year") : kLang(@"years"),
                    @(remainingMonths), remainingMonths == 1 ? kLang(@"month") : kLang(@"months")];
        }
    }
}

+ (nullable NSURL *)firstImageURLForPetAd:(PetAd *)petAd
{
    PetImageItem *item = petAd.imageItems.firstObject;
    if (!item.url.length) return nil;
    return [NSURL URLWithString:item.url];
}

+ (nullable NSString *)locationNameForID:(NSInteger)locationID {
    // Implement your location mapping logic here
    // Example: return [LocationManager locationNameForID:locationID];
    return nil;
}

#pragma mark - Analytics Tracking

+ (void)trackShareAnalyticsForPetAd:(PetAd *)petAd activityType:(UIActivityType)activityType {
    // Track sharing analytics
    NSMutableDictionary *analyticsData = [NSMutableDictionary dictionary];
    
    analyticsData[@"ad_id"] = petAd.adID ?: @"unknown";
    analyticsData[@"category"] = @(petAd.category);
    analyticsData[@"price"] = petAd.price ?: @0;
    analyticsData[@"share_method"] = [self shareMethodNameForActivityType:activityType];
    
    // Log to analytics service
    NSLog(@"📊 Pet Ad Share Analytics: %@", analyticsData);
    
    // Example: [AnalyticsManager logEvent:@"pet_ad_shared" parameters:analyticsData];
}

+ (NSString *)shareMethodNameForActivityType:(UIActivityType)activityType {
    if (!activityType) return @"unknown";
    
    if ([activityType isEqualToString:UIActivityTypePostToFacebook]) {
        return @"facebook";
    } else if ([activityType isEqualToString:UIActivityTypePostToTwitter]) {
        return @"twitter";
    } else if ([activityType isEqualToString:UIActivityTypeMessage]) {
        return @"message";
    } else if ([activityType isEqualToString:UIActivityTypeMail]) {
        return @"email";
    } else if ([activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
        return @"copy_to_clipboard";
    } else if ([activityType isEqualToString:UIActivityTypeAirDrop]) {
        return @"airdrop";
    } else if ([activityType isEqualToString:UIActivityTypeAddToReadingList]) {
        return @"reading_list";
    } else if ([activityType isEqualToString:UIActivityTypeSaveToCameraRoll]) {
        return @"camera_roll";
    } else {
        return activityType;
    }
}

#pragma mark - Enhanced Sharing with Images

+ (void)sharePetAdWithLocalImages:(PetAd *)petAd
               fromViewController:(UIViewController *)vc
                       sourceView:(nullable UIView *)sourceView {
    
    if (!petAd.localImages || petAd.localImages.count == 0) {
        // Fall back to URL sharing
        [self sharePetAd:petAd fromViewController:vc sourceView:sourceView];
        return;
    }
    
    // Safe presentation check
    if (!vc.isViewLoaded || !vc.view.window) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sharePetAdWithLocalImages:petAd fromViewController:vc sourceView:sourceView];
        });
        return;
    }
    
    if (vc.presentedViewController) {
        NSLog(@"ViewController already presenting something");
        return;
    }
    
    // Create message
    NSString *message = [self shareMessageForPetAd:petAd];
    
    // Prepare items (add all local images)
    NSMutableArray *items = [NSMutableArray arrayWithObject:message];
    [items addObjectsFromArray:petAd.localImages];
    
    // Create and present activity view controller
    UIActivityViewController *avc = [[UIActivityViewController alloc]
                                     initWithActivityItems:items
                                     applicationActivities:nil];
    
    // Configure for iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        avc.popoverPresentationController.sourceView = sourceView ?: vc.view;
        
        if (sourceView) {
            avc.popoverPresentationController.sourceRect = sourceView.bounds;
        } else {
            avc.popoverPresentationController.sourceRect = CGRectMake(
                vc.view.bounds.size.width / 2,
                vc.view.bounds.size.height / 2,
                1, 1
            );
        }
    }
    
    [vc presentViewController:avc animated:YES completion:nil];
}

#pragma mark - Copy to Clipboard

+ (void)copyPetAdToClipboard:(PetAd *)petAd {
    NSString *message = [self shareMessageForPetAd:petAd];
    [UIPasteboard generalPasteboard].string = message;
    
    // Optional: Show feedback
    // [self showToast:kLang(@"Copied to clipboard!")];
}

- (void)copyToClipboard {
    [PetAd copyPetAdToClipboard:self];
}

#pragma mark - Export as Text File

+ (void)exportPetAdAsTextFile:(PetAd *)petAd
           fromViewController:(UIViewController *)vc {
    
    NSString *message = [self shareMessageForPetAd:petAd];
    NSString *fileName = [NSString stringWithFormat:@"Pet_Ad_%@.txt",
                         petAd.adTitle ?: @"details"];
    
    // Remove invalid characters from filename
    NSCharacterSet *illegalCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    fileName = [[fileName componentsSeparatedByCharactersInSet:illegalCharacters] componentsJoinedByString:@""];
    
    // Create temporary file
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    NSError *error = nil;
    [message writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"Error creating text file: %@", error);
        return;
    }
    
    // Share the file
    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                            initWithActivityItems:@[fileURL]
                                            applicationActivities:nil];
    
    // Configure for iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = vc.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(
            vc.view.bounds.size.width / 2,
            vc.view.bounds.size.height / 2,
            1, 1
        );
    }
    
    [vc presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Generate Shareable Link (Optional)

+ (nullable NSURL *)shareableLinkForPetAd:(PetAd *)petAd {
    if (!petAd.adID) return nil;
    
    // Example deep link: "yourapp://petad/12345"
    NSString *deepLink = [NSString stringWithFormat:@"yourapp://petad/%@", petAd.adID];
    
    // OR web URL: "https://yourapp.com/petad/12345"
    // NSString *webURL = [NSString stringWithFormat:@"https://yourapp.com/petad/%@", petAd.adID];
    
    return [NSURL URLWithString:deepLink];
}
 


+ (BOOL)supportsSecureCoding { return YES; }
 
#pragma mark - Encoding
- (void)encodeWithCoder:(NSCoder *)coder {

    [coder encodeObject:self.adID forKey:@"adID"];
    [coder encodeObject:self.ownerID forKey:@"ownerID"];
    [coder encodeObject:self.blurHash forKey:@"blurHash"];
    [coder encodeObject:self.ownerName forKey:@"ownerName"];
    [coder encodeObject:self.ownerContact forKey:@"ownerContact"];

    [coder encodeInteger:self.category      forKey:@"category"];
    [coder encodeInteger:self.subcategory   forKey:@"subcategory"];
    [coder encodeInteger:self.adLocation    forKey:@"adLocation"];
    [coder encodeDouble:self.latitude        forKey:@"latitude"];
    [coder encodeDouble:self.longitude       forKey:@"longitude"];
    [coder encodeObject:self.geohash         forKey:@"geohash"];
    [coder encodeObject:self.locationName    forKey:@"locationName"];
    [coder encodeBool:self.isFemale         forKey:@"isFemale"];
    [coder encodeBool:self.isSold           forKey:@"isSold"];
    [coder encodeBool:self.isApproved       forKey:@"isApproved"];
    [coder encodeBool:self.isDeleted        forKey:@"isDeleted"];
    [coder encodeBool:self.isBlocked        forKey:@"isBlocked"];

    [coder encodeObject:self.adTitle        forKey:@"adTitle"];
    [coder encodeObject:self.adDescription  forKey:@"adDescription"];
    [coder encodeObject:self.price          forKey:@"price"];
    [coder encodeObject:self.discountPercent forKey:@"discountPercent"];
    [coder encodeObject:self.petAgeMonths    forKey:@"petAgeMonths"];

     [coder encodeObject:self.imageItems      forKey:@"imageItems"];

    [coder encodeObject:self.viewsCount     forKey:@"viewsCount"];
    [coder encodeObject:self.postedDate     forKey:@"postedDate"];
    [coder encodeObject:self.createdAt      forKey:@"createdAt"];
    [coder encodeObject:self.updatedAt      forKey:@"updatedAt"];
    [coder encodeObject:self.expiresAt      forKey:@"expiresAt"];
}

#pragma mark - Decoding
- (instancetype)initWithCoder:(NSCoder *)coder {

    if (self = [super init]) {

        NSSet *allowedString   = [NSSet setWithObject:NSString.class];
        NSSet *allowedNumber   = [NSSet setWithObject:NSNumber.class];
        NSSet *allowedDate     = [NSSet setWithObject:NSDate.class];

        // Array of dictionaries {url, width, height}
       // NSSet *allowedMetaDict = [NSSet setWithObjects:
                                  //NSDictionary.class, NSString.class,
                                  //NSNumber.class, nil];

        NSSet *allowedMetaArray = [NSSet setWithObjects:
                                   NSArray.class, NSDictionary.class,
                                   NSString.class, NSNumber.class, nil];

        NSSet *allowed = [NSSet setWithObjects:
                          NSString.class,
                          NSNumber.class,
                          NSArray.class,
                          NSDictionary.class,
                          PetImageItem.class,
                          nil];
        
        
        
        _adID         = [coder decodeObjectOfClass:NSString.class forKey:@"adID"];
        _blurHash         = [coder decodeObjectOfClass:NSString.class forKey:@"blurHash"];
        _ownerID      = [coder decodeObjectOfClass:NSString.class forKey:@"ownerID"];
        _ownerName    = [coder decodeObjectOfClasses:allowedString forKey:@"ownerName"];
        _ownerContact = [coder decodeObjectOfClasses:allowedString forKey:@"ownerContact"];

        _category     = [coder decodeIntegerForKey:@"category"];
        _subcategory  = [coder decodeIntegerForKey:@"subcategory"];
        _adLocation   = [coder decodeIntegerForKey:@"adLocation"];
        _latitude     = [coder decodeDoubleForKey:@"latitude"];
        _longitude    = [coder decodeDoubleForKey:@"longitude"];
        _geohash      = [coder decodeObjectOfClass:NSString.class forKey:@"geohash"];
        _locationName = [coder decodeObjectOfClass:NSString.class forKey:@"locationName"];
        _isFemale     = [coder decodeBoolForKey:@"isFemale"];
        _isSold       = [coder decodeBoolForKey:@"isSold"];
        _isApproved   = [coder containsValueForKey:@"isApproved"]
            ? [coder decodeBoolForKey:@"isApproved"]
            : YES;
        _isDeleted    = [coder decodeBoolForKey:@"isDeleted"];
        _isBlocked    = [coder decodeBoolForKey:@"isBlocked"];

        _adTitle       = [coder decodeObjectOfClass:NSString.class forKey:@"adTitle"];
        _searchTitle   = [coder decodeObjectOfClass:NSString.class forKey:@"searchTitle"];
        _adDescription = [coder decodeObjectOfClass:NSString.class forKey:@"adDescription"];
        _price         = [coder decodeObjectOfClasses:allowedNumber forKey:@"price"];
        _discountPercent = [coder decodeObjectOfClasses:allowedNumber forKey:@"discountPercent"];
        _petAgeMonths    = [coder decodeObjectOfClasses:allowedNumber forKey:@"petAgeMonths"];


        // FIX 🔥🔥 Allows array of dictionaries safely
        _imageItemsRaw     = [coder decodeObjectOfClasses:allowed forKey:@"imageItems"];

        _viewsCount = [coder decodeObjectOfClasses:allowedNumber forKey:@"viewsCount"];
        _postedDate = [coder decodeObjectOfClasses:allowedDate forKey:@"postedDate"];
        _createdAt  = [coder decodeObjectOfClasses:allowedDate forKey:@"createdAt"];
        _updatedAt  = [coder decodeObjectOfClasses:allowedDate forKey:@"updatedAt"];
        _expiresAt  = [coder decodeObjectOfClasses:allowedDate forKey:@"expiresAt"];
    }
    return self;
}

#pragma mark - Firestore
- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)docID {

    if (self = [super init]) {

        _adID         = docID ?: @"";
        _ownerID      = dict[@"ownerID"] ?: @"";
        _blurHash      = dict[@"blurHash"] ?: @"";
        _ownerName    = dict[@"ownerName"];
        _ownerContact = dict[@"ownerContact"];

        _category     = [dict[@"category"] integerValue];
        _subcategory  = [dict[@"subcategory"] integerValue];
        _adTitle      = dict[@"adTitle"];
        _searchTitle      = dict[@"searchTitle"];
        /*
         name_lowercase is a derived, persisted field used for Firebase prefix search.
         Older documents may not contain it; the computed helper safely falls back
         to adTitle.lowercaseString.
        */
        _adDescription = dict[@"desc"] ?: dict[@"adDescription"];
        _adLocation  = [dict[@"adLocation"] integerValue];
        _latitude = [dict[@"latitude"] doubleValue];
        _longitude = [dict[@"longitude"] doubleValue];
        _geohash = [dict[@"geohash"] isKindOfClass:NSString.class] ? dict[@"geohash"] : nil;
        _locationName = [dict[@"locationName"] isKindOfClass:NSString.class] ? dict[@"locationName"] : nil;
        if (_locationName.length == 0 && _adLocation > 0) {
            _locationName = [CitiesManager.shared cityNameForID:_adLocation];
        }

        _price           = dict[@"price"];
        _discountPercent = dict[@"discountPercent"];
        _petAgeMonths    = dict[@"petAge"];
        _isFemale        = [dict[@"isFemale"] boolValue];
 

        id meta = dict[@"imageItems"];
        if ([meta isKindOfClass:NSArray.class]) {
            _imageItemsRaw = meta;
        } else {
            _imageItemsRaw = nil;
        }

        _isSold = [dict[@"isSold"] boolValue];
        _viewsCount = dict[@"viewsCount"];

        _postedDate = [PetAd safeDateFromFirestore:dict[@"postedDate"]];
        _createdAt  = [PetAd safeDateFromFirestore:dict[@"createdAt"]];
        _updatedAt  = [PetAd safeDateFromFirestore:dict[@"updatedAt"]];
        _expiresAt  = [PetAd safeDateFromFirestore:dict[@"expiresAt"]];
        
        id rawStatus = dict[@"status"] ?: dict[@"statusCode"];
        _status     = PPStatusFromFirestore(rawStatus);
        _visibility = [dict[@"visibility"] integerValue];
        _isApproved = [dict[@"isApproved"] respondsToSelector:@selector(boolValue)]
            ? [dict[@"isApproved"] boolValue]
            : YES;
        _isDeleted = [dict[@"isDeleted"] boolValue];
        _isBlocked = [dict[@"isBlocked"] boolValue];

        _priorityScore = dict[@"priorityScore"];
        _rankScore     = dict[@"rankScore"];

        _favoritesCount = dict[@"favoritesCount"];
        _sharesCount    = dict[@"sharesCount"];

        _keywords = dict[@"keywords"];
    }
    return self;
}

+ (NSDate *)safeDateFromFirestore:(id)obj {
    if ([obj isKindOfClass:NSDate.class]) return obj;
    if ([obj respondsToSelector:@selector(dateValue)]) return [obj dateValue];
    return nil;
}

#pragma mark - Firestore Dictionary
#pragma mark - Firestore Dictionary
- (NSDictionary *)toFirestoreDictionary {
    NSMutableDictionary *d = NSMutableDictionary.dictionary;

    d[@"ownerID"]      = _ownerID ?: @"";
    d[@"ownerName"]    = _ownerName ?: @"";
    d[@"ownerContact"] = _ownerContact ?: @"";
    d[@"blurHash"] = _blurHash ?: @"";

    d[@"category"]     = @(_category);
    d[@"subcategory"]  = @(_subcategory);

    d[@"adTitle"]      = _adTitle ?: @"";
    NSString *normalized = [ArabicNormalizer normalize:_adTitle ?: @""];
    d[@"searchTitle"] = normalized;
    d[@"desc"]         = _adDescription ?: @"";

    d[@"adLocation"]   = @(_adLocation);
    if (PPIsValidCoordinatePair(_latitude, _longitude)) {
        d[@"latitude"] = @(_latitude);
        d[@"longitude"] = @(_longitude);
    }
    if (_geohash.length > 0) {
        d[@"geohash"] = _geohash;
    }
    if (_locationName.length > 0) {
        d[@"locationName"] = _locationName;
    }
    d[@"price"]        = _price ?: @0;
    d[@"discountPercent"] = _discountPercent ?: @0;
    d[@"petAge"]       = _petAgeMonths ?: @0;

    d[@"isFemale"]     = @(_isFemale);
    d[@"isSold"]       = @(_isSold);
    d[@"isApproved"]   = @(_isApproved);
    d[@"isDeleted"]    = @(_isDeleted);
    d[@"isBlocked"]    = @(_isBlocked);

 
    // Persist raw media metadata when available so image-only and mixed media
    // documents remain backward-compatible under the existing imageItems field.
    if ([self.imageItemsRaw isKindOfClass:NSArray.class] && self.imageItemsRaw.count > 0) {
        d[@"imageItems"] = self.imageItemsRaw;
    } else if (self.imageItems.count > 0) {
        NSMutableArray *items = [NSMutableArray arrayWithCapacity:self.imageItems.count];
        for (PetImageItem *item in self.imageItems) {
            [items addObject:[item toDictionary]];
        }
        d[@"imageItems"] = items;
    }
    
    
    d[@"viewsCount"]   = _viewsCount ?: @0;
    d[@"postedDate"]   = _postedDate ?: NSDate.date;
    d[@"createdAt"]    = _createdAt ?: NSDate.date;
    d[@"updatedAt"]    = NSDate.date;
    if (_expiresAt) {
        d[@"expiresAt"] = _expiresAt;
    }

    d[@"status"]     = @(self.status);
    d[@"statusCode"] = @(self.status);
    d[@"visibility"] = @(self.visibility);

    if (_priorityScore) d[@"priorityScore"] = _priorityScore;
    if (_rankScore)     d[@"rankScore"] = _rankScore;

    if (_favoritesCount) d[@"favoritesCount"] = _favoritesCount;
    if (_sharesCount)    d[@"sharesCount"] = _sharesCount;

    if (_keywords) d[@"keywords"] = _keywords;
    
    
    return d;
}


- (void)setImageItems:(NSArray<PetImageItem *> *)imageItems
{
    if (imageItems.count == 0) {
        _imageItemsRaw = @[];
        return;
    }

    NSMutableArray *raw = [NSMutableArray arrayWithCapacity:imageItems.count];

    for (PetImageItem *item in imageItems) {
        NSDictionary *dict = [item toDictionary];
        if (dict) {
            [raw addObject:dict];
        }
    }

    _imageItemsRaw = [raw copy];
}




- (NSArray<PetImageItem *> *)imageItems
{
    if (![_imageItemsRaw isKindOfClass:NSArray.class] ||
        _imageItemsRaw.count == 0) {
        return @[];
    }

    NSMutableArray<PetImageItem *> *items = [NSMutableArray array];

    for (NSDictionary *m in _imageItemsRaw) {
        PetImageItem *item = [PetImageItem itemWithMediaMetadata:m] ?: [PetImageItem itemFromDictionary:m];
        if (item) {
            [items addObject:item];
        }
        }

    return items.copy;
}

- (BOOL)hasValidGeoLocation
{
    return PPIsValidCoordinatePair(self.latitude, self.longitude);
}

- (BOOL)hasImages { return self.imageItems.count > 0; }

- (BOOL)requiresUpload { return self.localImages.count > 0; }

@end

 
