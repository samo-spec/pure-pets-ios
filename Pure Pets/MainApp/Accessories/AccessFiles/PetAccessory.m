#import "PetAccessory.h"
#import "ArabicNormalizer.h"
#import "GM.h"

#import "PetAccessory.h"

// AppConfig.m
#ifdef DEBUG
BOOL const isPPDebugMode = YES;
#else
BOOL const isPPDebugMode = NO;
#endif

static NSString *PPAccessoryTrimmedString(id value)
{
    if ([value isKindOfClass:[NSNull class]] || value == nil) {
        return @"";
    }

    NSString *string = nil;
    if ([value isKindOfClass:[NSString class]]) {
        string = (NSString *)value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        string = [(NSNumber *)value stringValue];
    }

    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

static NSString *PPAccessoryStringValueForKeys(NSDictionary *dict, NSArray<NSString *> *keys)
{
    for (NSString *key in keys) {
        NSString *value = PPAccessoryTrimmedString(dict[key]);
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

static NSNumber *PPAccessoryNumberValueForKeys(NSDictionary *dict, NSArray<NSString *> *keys)
{
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
    });

    for (NSString *key in keys) {
        id value = dict[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            return value;
        }
        NSString *string = PPAccessoryTrimmedString(value);
        if (string.length > 0) {
            NSNumber *number = [formatter numberFromString:string];
            if (number) {
                return number;
            }
        }
    }
    return nil;
}







// MARK: - Private interface for searchTitle storage

@interface PetAccessory ()
@property (nonatomic, copy) NSString *searchTitle;
@end


@implementation PetAccessory
- (NSDictionary *)toFirestoreDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Basic info
    if (self.name) dict[@"name"] = self.name;
    dict[@"searchTitle"] = [ArabicNormalizer normalize:self.name ?: @""];
    if (self.desc) dict[@"desc"] = self.desc;
    if (self.price) dict[@"price"] = self.price;
    
    // Discount fields
    if (self.discountPercent) dict[@"discountPercent"] = self.discountPercent;
    if (self.discountAmount) dict[@"discountAmount"] = self.discountAmount;
    if (self.weightText.length > 0) {
        dict[@"weightText"] = self.weightText;
        dict[@"weight"] = self.weightText; // Keep sync with console field name
    }
    if (self.weight) dict[@"weight"] = self.weight;
    if (self.weightUnit.length > 0) dict[@"weightUnit"] = self.weightUnit;
    
    // Images
    if (self.imageURLsArray) dict[@"imageURLsArray"] = self.imageURLsArray;
    if (self.imageMeta) dict[@"imageMeta"] = self.imageMeta;
    if (self.blurHash) dict[@"blurHash"] = self.blurHash;

    // Categories
    dict[@"petMainCategoryID"] = @(self.petMainCategoryID);
    dict[@"petSubCategoryID"] = @(self.petSubCategoryID);
    
    // Dates and ownership
    if (self.createdAt) {
        dict[@"createdAt"] = [FIRTimestamp timestampWithDate:self.createdAt];
    }
    if (self.ownerID) dict[@"ownerID"] = self.ownerID;
    
    // Enums
    dict[@"accessKindType"] = @(self.accessKindType);
    dict[@"condition"] = @(self.condition);
    
    // Stock and status
    dict[@"quantity"] = @(self.quantity);
    dict[@"isNew"] = @(self.isNew);
    dict[@"hasOffer"] = @(self.hasOffer);
    dict[@"showInAppMarket"] = @(self.showInAppMarket);
    
    // Calculate and include final price
    NSNumber *finalPrice = [self calculateFinalPrice];
    if (finalPrice) dict[@"finalPrice"] = finalPrice;
    
    // Expiry date
    if (self.expiryDate) {
        dict[@"expiryDate"] = [FIRTimestamp timestampWithDate:self.expiryDate];
    }

    // Add timestamps for Firestore
    dict[@"updatedAt"] = [FIRTimestamp timestampWithDate:[NSDate date]];
    
    return [dict copy];
}

- (NSNumber *)calculateFinalPrice {
    if (!self.price) return nil;
    
    double basePrice = [self.price doubleValue];
    double finalPrice = basePrice;
    
    // Apply percentage discount first
    if (self.discountPercent && [self.discountPercent doubleValue] > 0) {
        double discount = (basePrice * [self.discountPercent doubleValue]) / 100.0;
        finalPrice = basePrice - discount;
    }
    
    // Apply absolute discount
    if (self.discountAmount && [self.discountAmount doubleValue] > 0) {
        finalPrice = finalPrice - [self.discountAmount doubleValue];
    }
    
    // Ensure price doesn't go negative
    if (finalPrice < 0) finalPrice = 0;
    
    return @(finalPrice);
}

- (NSString *)stockStatusText {
    if (self.quantity <= 0) {
        return kLang(@"Out of stock");
    } else if (self.quantity <= 5) {
        return [NSString stringWithFormat:@"%@ %ld %@",
                kLang(@"Only"),
                (long)self.quantity,
                kLang(@"leftInStock")];
    } else {
        return kLang(@"inStock");
    }
}

- (NSArray<PetImageItem *> *)imageItems {
    NSMutableArray *items = [NSMutableArray array];
    
    for (NSInteger i = 0; i < self.imageURLsArray.count; i++) {
        NSString *url = self.imageURLsArray[i];
        NSDictionary *meta = (i < self.imageMeta.count) ? self.imageMeta[i] : nil;
        
        CGFloat width = [meta[@"width"] floatValue] ?: 0;
        CGFloat height = [meta[@"height"] floatValue] ?: 0;
        
        PetImageItem *item = [[PetImageItem alloc] initWithURL:url
                                                         width:width
                                                        height:height blurHash:nil];
        [items addObject:item];
    }
    
    return [items copy];
}







/*
 
 
 #pragma mark - 🎯 Weighted Random Discount Generator (Realistic Testing)

 - (void)applyRandomTestDiscount {
     // 0–99 random number for probability weighting
     int roll = arc4random_uniform(100);
     
     // Default (no discount)
     self.discountPercent = nil;
     self.discountAmount = nil;
     
     if (roll < 60) {
         // 60% chance — no discount
         //self.hasOffer = NO;
         return;
     }
     
     // Randomly decide between percentage or fixed
     BOOL usePercent = arc4random_uniform(2) == 0;
     
     if (usePercent) {
         if (roll < 85) {
             // 25% chance total — small 10% discount
             self.discountPercent = @(10);
         } else {
             // 15% chance — big 50% discount
             self.discountPercent = @(50);
         }
     } else {
         if (roll < 85) {
             // 25% chance total — small absolute discount
             NSArray *smallAmounts = @[@10, @20];
             self.discountAmount = smallAmounts[arc4random_uniform((uint32_t)smallAmounts.count)];
         } else {
             // 15% chance — large absolute discount
             NSArray *bigAmounts = @[@70, @100];
             self.discountAmount = bigAmounts[arc4random_uniform((uint32_t)bigAmounts.count)];
         }
     }
     
     // Mark as having offer
     //self.hasOffer = YES;
 }

 */

- (NSNumber *)finalPrice {
    return [self calculateFinalPrice];
}

- (BOOL)isLivePet {
    return self.accessKindType == AccessTypeLivePet;
}

- (BOOL)isFood {
    return self.accessKindType == AccessTypeFood;
}

- (BOOL)isPetMedicine {
    return self.accessKindType == AccessTypePetMedicine;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict documentID:(NSString *)docID {
    
    if (self = [super init]) {
        _accessoryID = docID ?: @"";
        _name = dict[@"name"] ?: @"";
        _desc = dict[@"desc"] ?: @"";
        _price = dict[@"price"] ?: @(0);
        _discountPercent = dict[@"discountPercent"];
        _discountAmount = dict[@"discountAmount"];
        _weightText = PPAccessoryStringValueForKeys(dict, (@[
            @"weight",
            @"weightText",
            @"weightLabel",
            @"packageWeightText",
            @"netWeightText",
            @"itemWeightText"
        ]));
        _weight = PPAccessoryNumberValueForKeys(dict, (@[
            @"weight",
            @"packageWeight",
            @"netWeight",
            @"itemWeight",
            @"unitWeight"
        ]));
        _weightUnit = PPAccessoryStringValueForKeys(dict, (@[
            @"weightUnit",
            @"unit",
            @"packageUnit",
            @"measurementUnit",
            @"weight_unit"
        ]));
        _imageURLsArray = dict[@"imageURLsArray"] ?: @[];
        _imageMeta  = dict[@"imageMeta"] ?: nil;
        _petMainCategoryID = [dict[@"petMainCategoryID"] integerValue];
        _petSubCategoryID = [dict[@"petSubCategoryID"] integerValue];
        id createdVal = dict[@"createdAt"];
        if ([createdVal isKindOfClass:[FIRTimestamp class]]) {
            _createdAt = [(FIRTimestamp *)createdVal dateValue];
        } else if ([createdVal isKindOfClass:[NSDate class]]) {
            _createdAt = (NSDate *)createdVal;
        } else {
            _createdAt = [NSDate date];
        }

        // Expiry date — nil if missing/null (not all items expire)
        id expiryVal = dict[@"expiryDate"];
        if (expiryVal && ![expiryVal isKindOfClass:[NSNull class]]) {
            if ([expiryVal isKindOfClass:[NSDate class]]) {
                _expiryDate = (NSDate *)expiryVal;
            } else if ([expiryVal isKindOfClass:[FIRTimestamp class]]) {
                _expiryDate = [(FIRTimestamp *)expiryVal dateValue];
            }
        }

        _ownerID = dict[@"ownerID"] ?: @"";
        _blurHash = dict[@"blurHash"] ?: @"";
        _accessKindType = ({
            NSInteger rawKind = [dict[@"accessKindType"] integerValue];
            AccessKindType parsed;
            switch (rawKind) {
                case AccessTypeFood:     parsed = AccessTypeFood;     break;
                case AccessTypeLivePet:  parsed = AccessTypeLivePet;  break;
                case AccessTypePetMedicine: parsed = AccessTypePetMedicine; break;
                default:                 parsed = AccessTypeAccessory; break;
            }
            // Backward compat: old docs with product_type == "live" but no accessKindType 3
            if (parsed == AccessTypeAccessory) {
                NSString *productType = dict[@"product_type"];
                if ([productType isKindOfClass:[NSString class]] &&
                    [productType caseInsensitiveCompare:@"live"] == NSOrderedSame) {
                    parsed = AccessTypeLivePet;
                }
            }
            parsed;
        });
        _condition = [dict[@"condition"] integerValue];
        _isNew = [dict[@"isNew"] boolValue];
        _hasOffer = [dict[@"hasOffer"] boolValue];
        _showInAppMarket = [dict[@"showInAppMarket"] boolValue];
        
        _quantity = [dict[@"quantity"] integerValue];
        _searchTitle = dict[@"searchTitle"];
        if(isPPDebugMode)
        {
            //[self applyRandomTestDiscount];
            //_desc = kLang(@"tempDesc");
            //_quantity = arc4random_uniform(15); // random quantity for testing
        }
        
        
    }
    return self;
}

// PetAccessory.m
+ (instancetype)deepCopyFrom:(PetAccessory *)source {
    PetAccessory *copy = [[PetAccessory alloc] init];
    copy.accessoryID = [source.accessoryID copy];
    copy.name = [source.name copy];
    copy.price = [source.price copy];
    copy.discountPercent = [source.discountPercent copy];
    copy.discountAmount = [source.discountAmount copy];
    copy.weightText = [source.weightText copy];
    copy.weight = [source.weight copy];
    copy.weightUnit = [source.weightUnit copy];
    copy.desc = [source.desc copy];
    copy.blurHash = [source.blurHash copy];
    copy.petMainCategoryID = source.petMainCategoryID;
    copy.petSubCategoryID = source.petSubCategoryID;
    copy.condition = source.condition;
    copy.accessKindType = source.accessKindType;
    copy.imageURLsArray = [source.imageURLsArray copy];
    copy.imageMeta = [source.imageMeta copy];
    copy.ownerID = [source.ownerID copy];
    copy.createdAt = [source.createdAt copy];
    copy.expiryDate = [source.expiryDate copy];
    copy.quantity = source.quantity;
    copy.isNew = source.isNew;
    copy.hasOffer = source.hasOffer;
    copy.showInAppMarket = source.showInAppMarket;
    return copy;
}







#pragma mark - Sharing

+ (void)sharePetAccessory:(PetAccessory *)accessory fromViewController:(UIViewController *)vc {
    [self sharePetAccessory:accessory fromViewController:vc sourceView:nil];
}

+ (void)sharePetAccessory:(PetAccessory *)accessory
       fromViewController:(UIViewController *)vc
               sourceView:(nullable UIView *)sourceView {
    
    // Create the share message
    NSString *message = [self shareMessageForAccessory:accessory];
    
    // Prepare share items
    NSMutableArray *items = [NSMutableArray arrayWithObject:message];
    
    // Add first image if available
    NSURL *imageURL = [self firstImageURLForAccessory:accessory];
    if (imageURL) {
        [items addObject:imageURL];
    }
    
    // Create activity view controller
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                            initWithActivityItems:items
                                            applicationActivities:nil];
    
    // Exclude certain activities if needed
    // activityVC.excludedActivityTypes = @[UIActivityTypeAirDrop, UIActivityTypeAddToReadingList];
    
    // For iPad, configure popover
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = sourceView ?: vc.view;
        
        if (sourceView) {
            activityVC.popoverPresentationController.sourceRect = sourceView.bounds;
        } else {
            // Default to center of view
            activityVC.popoverPresentationController.sourceRect = CGRectMake(
                vc.view.bounds.size.width / 2,
                vc.view.bounds.size.height / 2,
                1, 1
            );
        }
    }
    
    // Present the share sheet
    [PPFunc presentSheetFrom:AppMgr.topViewController sheetVC:activityVC detentStyle:PPSheetDetentStyleMediumOnly];
}

#pragma mark - Share Content Generation

+ (NSString *)shareMessageForAccessory:(PetAccessory *)accessory {
    NSMutableString *message = [NSMutableString string];
    
    // Title/Introduction
    [message appendFormat:@"%@\n\n", kLang(@"Check out this pet accessory!")];
    
    // Name
    if (accessory.name.length > 0) {
        [message appendFormat:@"%@: %@\n", kLang(@"Name"), accessory.name];
    }
    
    // Description (truncated if too long)
    if (accessory.desc.length > 0) {
        NSString *shortDesc = accessory.desc;
        if (shortDesc.length > 100) {
            shortDesc = [[shortDesc substringToIndex:100] stringByAppendingString:@"..."];
        }
        [message appendFormat:@"%@: %@\n", kLang(@"Description"), shortDesc];
    }
    
    // Category Information
    if (accessory.petMainCategoryID > 0) {
        NSString *mainCategoryName = [MainKindsModel kindNameForID:accessory.petMainCategoryID];
        if (mainCategoryName) {
            [message appendFormat:@"%@: %@\n", kLang(@"Category"), mainCategoryName];
        }
    }
    
    if (accessory.petSubCategoryID > 0) {
        NSArray *subKinds = [MKM getSubKindArray:accessory.petMainCategoryID];
        NSString *subCategoryName = [SubKindModel getSubKindName:accessory.petSubCategoryID
                                                  subKindsArrayLocal:subKinds];
        if (subCategoryName) {
            [message appendFormat:@"%@: %@\n", kLang(@"Subcategory"), subCategoryName];
        }
    }
    
    // Price Information
    if (accessory.finalPrice) {
        NSString *priceString = [self formattedPrice:accessory.finalPrice
                                          originalPrice:accessory.price
                                        discountPercent:accessory.discountPercent];
        [message appendFormat:@"%@: %@\n", kLang(@"Price"), priceString];
    }
    
    // Condition
    NSString *conditionText = [self conditionTextForAccessory:accessory];
    if (conditionText) {
        [message appendFormat:@"%@: %@\n", kLang(@"Condition"), conditionText];
    }
    
    // Stock status
    NSString *stockText = [accessory stockStatusText];
    if (stockText) {
        [message appendFormat:@"%@: %@\n", kLang(@"Availability"), stockText];
    }
    
    // Type
    NSString *typeText = [self typeTextForAccessory:accessory];
    if (typeText) {
        [message appendFormat:@"%@: %@", kLang(@"Type"), typeText];
    }
    
    return [message copy];
}

+ (NSString *)formattedPrice:(NSNumber *)finalPrice
               originalPrice:(NSNumber *)originalPrice
             discountPercent:(NSNumber *)discountPercent {
    if (!finalPrice) return @"";
    return [self formatCurrency:finalPrice];
}

+ (NSString *)formatCurrency:(NSNumber *)amount {
    if (!amount) return @"";
    return [GM formatPrice:amount currencyCode:kLang(@"Rials")];
}

+ (NSString *)conditionTextForAccessory:(PetAccessory *)accessory {
    switch (accessory.condition) {
        case AccessConditionsNew:
            return kLang(@"New");
        case AccessConditionsUsed:
            return kLang(@"Used");
        case AccessConditionsNone:
        default:
            return kLang(@"Not specified");
    }
}

+ (NSString *)typeTextForAccessory:(PetAccessory *)accessory {
    switch (accessory.accessKindType) {
        case AccessTypeAccessory:
            return kLang(@"Accessory");
        case AccessTypeFood:
            return kLang(@"Food");
        case AccessTypeLivePet:
            return kLang(@"Live Pet");
        case AccessTypePetMedicine:
            return kLang(@"PetMedicine");
        default:
            return kLang(@"Unknown");
    }
}

+ (nullable NSURL *)firstImageURLForAccessory:(PetAccessory *)accessory {
    if (accessory.imageURLsArray.count > 0) {
        NSString *firstImageURL = accessory.imageURLsArray.firstObject;
        if (firstImageURL.length > 0) {
            return [NSURL URLWithString:firstImageURL];
        }
    }
    return nil;
}

#pragma mark - Instance Method for Sharing

- (void)shareFromViewController:(UIViewController *)vc {
    [PetAccessory sharePetAccessory:self fromViewController:vc];
}

- (void)shareFromViewController:(UIViewController *)vc sourceView:(nullable UIView *)sourceView {
    [PetAccessory sharePetAccessory:self fromViewController:vc sourceView:sourceView];
}

#pragma mark - Share Link Generation (Optional)

+ (nullable NSURL *)shareableLinkForAccessory:(PetAccessory *)accessory {
    // Generate a deep link or web URL for the accessory
    // This depends on your app's URL scheme or website
    
    if (!accessory.accessoryID) return nil;
    
    // Example: "yourapp://accessory/12345"
    NSString *deepLink = [NSString stringWithFormat:@"yourapp://accessory/%@", accessory.accessoryID];
    
    // OR web URL: "https://yourapp.com/accessory/12345"
    // NSString *webURL = [NSString stringWithFormat:@"https://yourapp.com/accessory/%@", accessory.accessoryID];
    
    return [NSURL URLWithString:deepLink];
}

#pragma mark - Social Media Specific Sharing (Optional)

+ (void)shareToFacebook:(PetAccessory *)accessory fromViewController:(UIViewController *)vc {
    // Facebook-specific sharing implementation
    // You might want to use Facebook SDK or a custom implementation
    
    NSString *message = [self shareMessageForAccessory:accessory];
    
    // For Facebook, you might want to use:
    // - FBSDKShareLinkContent for link sharing
    // - FBSDKSharePhotoContent for photo sharing
    // - FBSDKShareDialog to present the share dialog
    
    NSLog(@"Facebook sharing not implemented. Message: %@", message);
}

+ (void)shareToInstagram:(PetAccessory *)accessory fromViewController:(UIViewController *)vc {
    // Instagram sharing typically requires image or video content
    // You can share via Instagram's URL scheme
    
    NSURL *imageURL = [self firstImageURLForAccessory:accessory];
    if (imageURL) {
        // Save image locally first, then share to Instagram
        [self downloadAndShareToInstagram:imageURL
                         withCaption:accessory.name
                  fromViewController:vc];
    }
}

+ (void)downloadAndShareToInstagram:(NSURL *)imageURL
                       withCaption:(NSString *)caption
                fromViewController:(UIViewController *)vc {
    
    // Implementation for downloading image and sharing to Instagram
    // This would typically involve:
    // 1. Downloading the image
    // 2. Saving to photo library or documents directory
    // 3. Using Instagram's URL scheme: instagram://library?AssetPath=...
    
    NSLog(@"Instagram sharing not fully implemented");
}

#pragma mark - Export Methods (Optional)

+ (void)exportAsPDF:(PetAccessory *)accessory fromViewController:(UIViewController *)vc {
    // Generate and share as PDF
    // This is useful for creating printable listings
    
    NSData *pdfData = [self generatePDFForAccessory:accessory];
    
    if (pdfData) {
        // Save to temporary file
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingFormat:@"%@.pdf", accessory.name ?: @"accessory"];
        [pdfData writeToFile:tempPath atomically:YES];
        
        // Share the file
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc]
                                                initWithActivityItems:@[fileURL]
                                                applicationActivities:nil];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            activityVC.popoverPresentationController.sourceView = vc.view;
            activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds),
                                                                             CGRectGetMidY(vc.view.bounds),
                                                                             0, 0);
            activityVC.popoverPresentationController.permittedArrowDirections = 0;
        }
        [vc presentViewController:activityVC animated:YES completion:nil];
    }
}

+ (NSData *)generatePDFForAccessory:(PetAccessory *)accessory {
    // Implement PDF generation using Core Graphics
    // This would create a nicely formatted PDF of the accessory details
    
    // Placeholder implementation
    return nil;
}

#pragma mark - Copy to Clipboard

+ (void)copyToClipboard:(PetAccessory *)accessory {
    NSString *message = [self shareMessageForAccessory:accessory];
    [UIPasteboard generalPasteboard].string = message;
    
    // Optional: Show feedback to user
    // [self showToast:@"Copied to clipboard!"];
}



@end
