//
//  Styling.m
//  PurePetsAdmin
//

#import "Styling.h"
#import "PPThemeRefresh.h"
#import "AppManager.h" // for kAppPrimaryColor, etc.
#import "YYCache.h"

#if __has_include(<Lottie/Lottie.h>)
#import <Lottie/Lottie.h>
#define PP_HAS_LOTTIE 1
#elif __has_include("Lottie.h")
#import "Lottie.h"
#define PP_HAS_LOTTIE 1
#elif __has_include(<lottie-ios_Oc/Lottie.h>)
#import <lottie-ios_Oc/Lottie.h>
#define PP_HAS_LOTTIE 1
#elif __has_include(<lottie_ios_Oc/Lottie.h>)
#import <lottie_ios_Oc/Lottie.h>
#define PP_HAS_LOTTIE 1
#else
#define PP_HAS_LOTTIE 0
#endif

#if __has_include(<SSZipArchive/SSZipArchive.h>)
#import <SSZipArchive/SSZipArchive.h>
#endif

@import FirebaseStorage;

static NSString *PPLottieStoragePathForAnimationName(NSString *fileName)
{
    if (![fileName isKindOfClass:NSString.class]) {
        return @"";
    }

    NSString *trimmedName = [fileName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedName.length == 0) {
        return @"";
    }

    NSString *extension = trimmedName.pathExtension.lowercaseString;
    BOOL hasSupportedExtension = [extension isEqualToString:@"json"] || [extension isEqualToString:@"lottie"];
    BOOL includesStorageFolder = [trimmedName containsString:@"/"];
    NSString *resolvedName = hasSupportedExtension ? trimmedName : [trimmedName stringByAppendingPathExtension:@"json"];

    return includesStorageFolder
        ? resolvedName
        : [@"LottieAnimations" stringByAppendingPathComponent:resolvedName];
}


@implementation UIView (CornerMask)

+ (void)applyCornerMaskToGradientLayer:(CAGradientLayer *)layer
                                    tl:(CGFloat)tl
                                    tr:(CGFloat)tr
                                    bl:(CGFloat)bl
                                    br:(CGFloat)br
{
    if (!layer) return;

    CGRect bounds = layer.bounds;
    if (CGRectIsEmpty(bounds)) return;

    CGFloat w = CGRectGetWidth(bounds);
    CGFloat h = CGRectGetHeight(bounds);

    UIBezierPath *path = [UIBezierPath bezierPath];

    // Top-left
    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0)
                 controlPoint:CGPointZero];

    // Top
    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr)
                 controlPoint:CGPointMake(w, 0)];

    // Right
    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h)
                 controlPoint:CGPointMake(w, h)];

    // Bottom
    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl)
                 controlPoint:CGPointMake(0, h)];

    [path closePath];

    CAShapeLayer *mask = nil;
    if ([layer.mask isKindOfClass:[CAShapeLayer class]]) {
        mask = (CAShapeLayer *)layer.mask;
    } else {
        mask = [CAShapeLayer layer];
        layer.mask = mask;
    }

    // 🔥 CRITICAL: no implicit animations
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    mask.frame = bounds;
    mask.path  = path.CGPath;

    [CATransaction commit];
}

@end


@implementation Styling


+ (void)addBlurToView:(UIView *)targetView
            blurStyle:(UIBlurEffectStyle)style
         cornerRadius:(CGFloat)cornerRadius
                alpha:(CGFloat)alpha
     insertAtPosition:(NSInteger)index {
    
    UIBlurEffect *effect;
    if (@available(iOS 13.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        effect = [UIBlurEffect effectWithStyle:style];
    }
    
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.userInteractionEnabled = NO; // allow touches to pass through to button
    blurView.layer.cornerRadius = cornerRadius;
    blurView.clipsToBounds = YES;
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.alpha = alpha;
    
    // Add blur behind the button
    [targetView insertSubview:blurView atIndex:index];
    
    // Constrain blur to fill the target view
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:targetView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:targetView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:targetView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:targetView.bottomAnchor]
    ]];
}



#pragma mark - Generic Methods
+ (void)applyStyleWithCornerRadius:(CGFloat)cornerRadius
                   backgroundColor:(UIColor *)backgroundColor
                       borderColor:(nullable UIColor *)borderColor
                       borderWidth:(CGFloat)borderWidth
                         addShadow:(BOOL)addShadow
                            toView:(UIView *)view
{
    // 🔹 Apply rounded corners
    if(cornerRadius > 0)
        view.clipsToBounds = YES;
    view.layer.cornerRadius = cornerRadius;
    
    // 🔹 Background color
    view.backgroundColor = backgroundColor;
    
    // 🔹 Border color and width
    if (borderColor) {
        [view pp_setBorderColor:borderColor];
        view.layer.borderWidth = borderWidth;
    } else {
        view.layer.borderWidth = 0;
        [view pp_setBorderColor:nil];
    }
    
    // 🔹 Optional shadow
    if (addShadow) {
        UIColor *shadowClr = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
            CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.45 : 0.25;
            return [UIColor colorWithWhite:0 alpha:a];
        }];
        [view pp_setShadowColor:shadowClr];
        view.layer.shadowOpacity = 0.2;
        view.layer.shadowRadius = 4.0;
        view.layer.shadowOffset = CGSizeMake(0, 3);
        view.layer.masksToBounds = NO;
        DLog(@"[Styling] Shadow applied to %@", view);
    } else {
        view.layer.shadowOpacity = 0.0;
        DLog(@"[Styling] Shadow removed from %@", view);
    }
}

+ (void)applyStyleWithCornerRadius:(CGFloat)cornerRadius
                       borderColor:(nullable UIColor *)borderColor
                         addShadow:(BOOL)addShadow
                            toView:(UIView *)view
{
    [self applyStyleWithCornerRadius:cornerRadius
                     backgroundColor:UIColor.clearColor
                         borderColor:borderColor
                         borderWidth:(borderColor ? 1.0 : 0.0)
                           addShadow:addShadow
                              toView:view];
    DLog(@"[Styling] Short style method used for %@", view);
}

#pragma mark - Presets
+ (void)applyCardStyleToView:(UIView *)view {
    [self applyStyleWithCornerRadius:12
                     backgroundColor:UIColor.whiteColor
                         borderColor:nil
                         borderWidth:0
                           addShadow:YES
                              toView:view];
    DLog(@"[Styling] Card style applied");
}

+ (void)applyIconButtonStyle:(UIButton *)button
                   tintColor:(UIColor *)tintColor
             backgroundColor:(UIColor *)backgroundColor {
    if (!button) return;
    
    // Force layout so button has a real size
    [button layoutIfNeeded];
    
    button.tintColor = tintColor;
    button.backgroundColor = backgroundColor;
    
    // ✅ Round based on current bounds
    CGFloat radius = button.hx_h / 2; ;
    button.layer.cornerRadius = radius;
    button.clipsToBounds = YES;
    button.layer.masksToBounds = NO; // allow shadow
    
    // Shadow (if needed)
    [button pp_setShadowColor:[UIColor blackColor]];
    button.layer.shadowOpacity = 0.07f;
    button.layer.shadowOffset = CGSizeMake(0, 2);
    button.layer.shadowRadius = 4.0f;
    
    // DLog(@"[Styling] Icon button corner radius %.2f applied", radius);
}




+ (void)applyHeaderStyleToView:(UIView *)view {
    [self applyStyleWithCornerRadius:0
                     backgroundColor:AppBackgroundClr
                         borderColor:nil
                         borderWidth:0
                           addShadow:NO
                              toView:view];
    DLog(@"[Styling] Header style applied");
}


+ (UIFont *)fontBold:(CGFloat)size {
    UIFont *font = [UIFont fontWithName:@"Beiruti-Bold" size:size];
    return font ?: [UIFont boldSystemFontOfSize:size]; // fallback
}

+ (UIFont *)fontMedium:(CGFloat)size {
    UIFont *font = [UIFont fontWithName:@"Beiruti-Medium" size:size];
    return font ?: [UIFont systemFontOfSize:size weight:UIFontWeightMedium]; // fallback
}

+ (UIFont *)fontRegular:(CGFloat)size {
    UIFont *font = [UIFont fontWithName:@"Beiruti-Regular" size:size];
    return font ?: [UIFont systemFontOfSize:size]; // fallback
}


+ (void)applyButtonTextStyle:(UIButton *)button
                        size:(CGFloat)pointSize
                      weight:(UIFontWeight)weight
                       scale:(UIFontTextStyle)scale
{
    if (!button) return;
    
    // Create base font
    UIFont *baseFont = [UIFont systemFontOfSize:pointSize weight:weight];
    
    // Apply dynamic scaling (so it respects Accessibility > Larger Text)
    UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:scale];
    UIFont *scaledFont = [metrics scaledFontForFont:baseFont];
    
    // Apply to button title
    button.titleLabel.font = scaledFont;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    
    DLog(@"[Styling] Applied button font size %.1f, weight %.1f, scale %@",
         pointSize, weight, scale);
}

+ (void)applyButtonIconStyle:(UIButton *)button
                   tintColor:(UIColor *)tintColor
             backgroundColor:(UIColor *)backgroundColor
                cornerRadius:(CGFloat)cornerRadius
             symbolPointSize:(CGFloat)pointSize
                      weight:(UIImageSymbolWeight)weight
                       scale:(UIImageSymbolScale)scale
{
    if (!button) return;
    
    // 🎨 Colors
    button.tintColor = tintColor ?: UIColor.whiteColor;
    button.backgroundColor = backgroundColor ?: UIColor.clearColor;
    
    
    // ⚡️ Detect if current image is SF Symbol (systemName based)
    UIImage *icon = [button imageForState:UIControlStateNormal];
    if (icon && icon.configuration) {
        // Apply SF Symbol config
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                        weight:weight
                                                         scale:scale];
        [button setImage:[icon imageByApplyingSymbolConfiguration:config]
                forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        DLog(@"[Styling] Applied SF Symbol config (%.1f pt, weight %ld, scale %ld) ✅",
             pointSize, (long)weight, (long)scale);
    } else {
        DLog(@"[Styling] Normal image detected, skipping SF Symbol config ⚪️");
    }
    
    // 🟣 Apply rounded style after layout
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat radius = cornerRadius > 0 ? cornerRadius :
        MIN(button.bounds.size.width, button.bounds.size.height) / 2.0;
        button.layer.cornerRadius = radius;
        button.layer.masksToBounds = NO;
        
        DLog(@"[Styling] Icon button radius applied: %.1f", radius);
    });
}

+ (void)applyGroupCellStyle:(UITableViewCell *)cell
                atIndexPath:(NSIndexPath *)indexPath
                inTableView:(UITableView *)tableView {
    
    // Use insets to make cell look like a floating card
    CGFloat sideInset = 16;
    CGRect bounds = CGRectMake(sideInset, 8, tableView.bounds.size.width - sideInset * 2, cell.bounds.size.height - 8);
    
    // Always apply full rounded rect (card style)
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:20];
    
    // Mask
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    cell.layer.mask = maskLayer;
    
    // Remove old shadows
    for (CALayer *sublayer in cell.contentView.layer.sublayers.copy) {
        if ([sublayer.name isEqualToString:@"GroupCellShadow"]) {
            [sublayer removeFromSuperlayer];
        }
    }
    
    // Shadow layer
    CAShapeLayer *shadowLayer = [CAShapeLayer layer];
    shadowLayer.name = @"GroupCellShadow";
    shadowLayer.path = maskPath.CGPath;
    shadowLayer.fillColor = UIColor.whiteColor.CGColor; // AppForgroundColr if you want
    shadowLayer.frame = bounds;
    
    shadowLayer.shadowColor = [UIColor blackColor].CGColor;
    shadowLayer.shadowOpacity = 0.15;
    shadowLayer.shadowOffset = CGSizeMake(0, 2);
    shadowLayer.shadowRadius = 6;
    
    [cell.contentView.layer insertSublayer:shadowLayer atIndex:0];
    
    // Make sure background is transparent
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
}




#pragma mark - Lottie Animation

+ (void)setAnimationNamed:(NSString *)fileName
                   toView:(LOTAnimationView *)lot
                withSpeed:(float)animationSpeed
               completion:(void (^)(BOOL success))completion
{
    [Styling setAnimationNamed:fileName
                        toView:lot
                     withSpeed:animationSpeed
                 loopAnimation:YES
                      autoplay:YES
                    completion:completion];
}

+ (void)setAnimationNamed:(NSString *)fileName
                   toView:(LOTAnimationView *)lot
                withSpeed:(float)animationSpeed
            loopAnimation:(BOOL)loopAnimation
                 autoplay:(BOOL)autoplay
               completion:(void (^)(BOOL success))completion
{
#if PP_HAS_LOTTIE
    NSString *storagePath = PPLottieStoragePathForAnimationName(fileName);
    if (storagePath.length == 0 || !lot) {
        if (completion) completion(NO);
        return;
    }

    [Styling fetchLottieJSONFromFirebasePath:storagePath
                                  completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ Lottie: Failed to fetch JSON: %@", error.localizedDescription);
                if (completion) completion(NO);
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                NSLog(@"❌ Lottie: Failed to build LOTComposition");
                if (completion) completion(NO);
                return;
            }

            // Apply composition
            [lot setSceneModel:composition];
            lot.animationSpeed = animationSpeed;
            lot.loopAnimation  = loopAnimation;
            lot.animationProgress = 0.0;

            if (autoplay) {
                lot.hidden = NO;

                // Prepare for a smooth reveal
                lot.alpha = 0.0;
                lot.transform = CGAffineTransformMakeScale(0.96, 0.96);

                // Start playing immediately
                [lot play];

                // Fade + gentle pop-in
                [UIView animateWithDuration:0.35
                                      delay:0
                     usingSpringWithDamping:0.90
                      initialSpringVelocity:0.20
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                    lot.alpha = 1.0;
                    lot.transform = CGAffineTransformIdentity;
                }
                                 completion:nil];
            }
            
            if (completion) completion(YES);
        });
    }];
#else
    NSLog(@"⚠️ Lottie SDK is not available in this build configuration.");
    if (completion) completion(NO);
#endif
}

+ (void)fetchLottieJSONFromFirebasePath:(NSString *)storagePath
                             completion:(void (^)(NSDictionary *jsonDict, NSError *error))completion {
    
    static YYCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[YYCache alloc] initWithName:@"LottieJSONCache"];
    });
    
    NSString *cacheKey = [NSString stringWithFormat:@"lottie_%@", storagePath];
    
    // 🔹 Cached?
    NSDictionary *cachedJSON = (NSDictionary *)[cache objectForKey:cacheKey];
    if (cachedJSON) {
        NSLog(@"✅ Lottie: Loaded from cache");
        if (completion) completion(cachedJSON, nil);
        return;
    }
    
    // 🔹 Download from Firebase
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *ref = [storage referenceWithPath:storagePath];
    
    int64_t maxDownloadSize = 20 * 1024 * 1024; // 20 MB
    
    [ref dataWithMaxSize:maxDownloadSize completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error || !data) {
            if (completion) completion(nil, error ?: [NSError errorWithDomain:@"LottieFetch" code:-1 userInfo:nil]);
            return;
        }
        
        NSString *lower = storagePath.lowercaseString;
        BOOL isDotLottie = [lower hasSuffix:@".lottie"];
        
        if (!isDotLottie) {
            // JSON only
            NSError *jsonErr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonErr];
            if (jsonErr || ![json isKindOfClass:[NSDictionary class]]) {
                if (completion) completion(nil, jsonErr);
                return;
            }
            [cache setObject:json forKey:cacheKey];
            if (completion) completion(json, nil);
            return;
        }
        
#if __has_include(<SSZipArchive/SSZipArchive.h>)
        // Handle .lottie
        NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        NSString *zipPath = [tempDir stringByAppendingPathComponent:@"anim.lottie"];
        
        NSError *fsErr = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&fsErr];
        if (![data writeToFile:zipPath options:NSDataWritingAtomic error:&fsErr]) {
            if (completion) completion(nil, fsErr);
            return;
        }
        
        NSString *unzipDir = [tempDir stringByAppendingPathComponent:@"unzipped"];
        if (![SSZipArchive unzipFileAtPath:zipPath toDestination:unzipDir]) {
            if (completion) completion(nil, [NSError errorWithDomain:@"LottieFetch" code:-2 userInfo:nil]);
            return;
        }
        
        NSString *manifestPath = [unzipDir stringByAppendingPathComponent:@"manifest.json"];
        NSData *manifestData = [NSData dataWithContentsOfFile:manifestPath];
        NSDictionary *manifest = manifestData ? [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil] : nil;
        
        NSArray *anims = manifest[@"animations"];
        NSDictionary *chosen = anims.count ? anims.firstObject : nil;
        NSString *jsonRelPath = [chosen isKindOfClass:NSDictionary.class] ? (chosen[@"json"] ?: @"") : @"";
        NSString *animationID = [chosen isKindOfClass:NSDictionary.class] ? (chosen[@"id"] ?: @"") : @"";
        if (jsonRelPath.length == 0 && animationID.length > 0) {
            jsonRelPath = [NSString stringWithFormat:@"animations/%@.json", animationID];
        }
        if (jsonRelPath.length == 0) {
            jsonRelPath = @"animations/animation.json";
        }
        NSString *jsonAbsPath = [unzipDir stringByAppendingPathComponent:jsonRelPath];
        
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonAbsPath];
        if (!jsonData) {
            NSString *animationsDir = [unzipDir stringByAppendingPathComponent:@"animations"];
            NSArray<NSString *> *animationFiles =
                [[NSFileManager defaultManager] contentsOfDirectoryAtPath:animationsDir error:nil];
            for (NSString *fileName in animationFiles) {
                if (![fileName.lowercaseString hasSuffix:@".json"]) {
                    continue;
                }
                jsonRelPath = [@"animations" stringByAppendingPathComponent:fileName];
                jsonAbsPath = [unzipDir stringByAppendingPathComponent:jsonRelPath];
                jsonData = [NSData dataWithContentsOfFile:jsonAbsPath];
                if (jsonData) {
                    break;
                }
            }
        }
        NSDictionary *json = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
        
        if (json) {
            [cache setObject:json forKey:cacheKey];
            if (completion) completion(json, nil);
        } else {
            if (completion) completion(nil, [NSError errorWithDomain:@"LottieFetch" code:-3 userInfo:nil]);
        }
        
        // Cleanup temp files
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        });
#else
        if (completion) completion(nil, [NSError errorWithDomain:@"LottieFetch"
                                                            code:-9
                                                        userInfo:@{NSLocalizedDescriptionKey:
                                                                       @".lottie support requires SSZipArchive. Add `pod 'SSZipArchive'`"}]);
#endif
    }];
}


+ (void)setRowFonts:(XLFormRowDescriptor *)row
{
    row.cellConfig[@"textLabel.font"] = [Styling fontMedium:17];
    row.cellConfig[@"textField.font"] = [Styling fontMedium:17];
}

+ (void)setRowButtonStyle:(XLFormRowDescriptor *)row
{
    // row.cellConfig[@"textLabel.backgroundColor"] = AppPrimaryClr;
    row.cellConfig[@"textLabel.textColor"] = [UIColor whiteColor];
    //  row.cellConfigAtConfigure[@"layer.cornerRadius"] = @(10.0);
    row.cellConfig[@"textLabel.textAlignment"] = @(NSTextAlignmentCenter);
    
    row.cellConfig[@"textLabel.font"] = [Styling fontMedium:17];
}


+ (void)applyGlobalStyleToRow:(XLFormRowDescriptor *)row {
    UIFont *font = [Styling fontMedium:16];
    UIColor *textColor = AppPrimaryTextClr;
    UIColor *secondaryColor = AppSecondaryTextClr;
    
    // Always safe
    row.cellConfig[@"textLabel.font"] = font;
    row.cellConfig[@"textLabel.textColor"] = textColor;
    row.cellConfig[@"detailTextLabel.font"] = font;
    row.cellConfig[@"detailTextLabel.textColor"] = secondaryColor;
    
    // === Text-field based rows ===
    if ([row.rowType isEqualToString:XLFormRowDescriptorTypeText] ||
        [row.rowType isEqualToString:XLFormRowDescriptorTypeName] ||
        [row.rowType isEqualToString:XLFormRowDescriptorTypeEmail] ||
        [row.rowType isEqualToString:XLFormRowDescriptorTypeURL] ||
        [row.rowType isEqualToString:XLFormRowDescriptorTypePhone] ||
        [row.rowType isEqualToString:XLFormRowDescriptorTypePassword]) {
        row.cellConfig[@"textField.font"] = font;
        row.cellConfig[@"textField.textColor"] = textColor;
    }
    
    // === Multiline ===
    if ([row.rowType isEqualToString:XLFormRowDescriptorTypeTextView]) {
        row.cellConfig[@"textView.font"] = font;
        row.cellConfig[@"textView.textColor"] = textColor;
    }
    
    // === Buttons ===
    if ([row.rowType isEqualToString:XLFormRowDescriptorTypeButton]) {
        row.cellConfig[@"textLabel.textAlignment"] = @(NSTextAlignmentCenter);
        row.cellConfig[@"detailTextLabel.textColor"] = AppPrimaryClr;
        row.cellConfig[@"textLabel.textColor"] = AppPrimaryClr;
        //row.cellConfig[@"contentView.backgroundColor"] = AppPrimaryClr;
        
    }
    
    // === Segmented control ===
    if ([row.rowType isEqualToString:XLFormRowDescriptorTypeSelectorSegmentedControl]) {
        row.cellConfig[@"segmentedControl.tintColor"] = AppPrimaryClr;
        row.cellConfig[@"segmentedControl.backgroundColor"] = AppForgroundColr;
        row.cellConfig[@"segmentedControl.layer.cornerRadius"] = @8;
        row.cellConfig[@"segmentedControl.layer.masksToBounds"] = @YES;
    }
    
    // ✅ Apply RTL / LTR globally
    UISemanticContentAttribute attr = [Language semanticAttributeForCurrentLanguage];
    row.cellConfig[@"contentView.semanticContentAttribute"] = @(attr);
    row.cellConfig[@"textLabel.semanticContentAttribute"] = @(attr);
    row.cellConfig[@"detailTextLabel.semanticContentAttribute"] = @(attr);
}



+ (void)applyCorner:(CGFloat)cornerRadius
    backgroundColor:(UIColor *)backgroundColor
             toView:(UIView *)view
{
    if (!view) return;
    
    view.layer.cornerRadius = cornerRadius;
    view.layer.masksToBounds = YES;
    view.backgroundColor = backgroundColor ?: UIColor.clearColor;
    
    DLog(@"[Styling] Corner %.1f + BG color applied to %@", cornerRadius, view);
}


// Back-compat convenience
+ (void)applyBackgroundStyleForTableView:(UITableView *)tableView
                                    cell:(UITableViewCell *)cell
                               indexPath:(NSIndexPath *)indexPath
                          useRowCardMode:(BOOL)useRowCardMode
{
    [self applyBackgroundStyleForTableView:tableView
                                      cell:cell
                                 indexPath:indexPath
                            useRowCardMode:useRowCardMode
                            buttonRowIndex:-1
                             buttonSection:-1];
}

+ (void)applyBackgroundStyleForTableView:(UITableView *)tableView
                                    cell:(UITableViewCell *)cell
                               indexPath:(NSIndexPath *)indexPath
                          useRowCardMode:(BOOL)useRowCardMode
                          buttonRowIndex:(NSInteger)buttonRowIndex
                           buttonSection:(NSInteger)buttonSection
{
    // Clear defaults for card mode
    if (useRowCardMode) {
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;
    }
    
    
    if(indexPath.row == buttonRowIndex && indexPath.section == buttonSection)
    {
        cell.backgroundColor = AppPrimaryClr;
        cell.contentView.backgroundColor = AppPrimaryClr;
        cell.tintColor  = AppForgroundColr;
        
    }
    else
    {
        cell.backgroundColor = AppForgroundColr;
        cell.contentView.backgroundColor = AppForgroundColr;
        cell.tintColor  = AppPrimaryClr;
    }
    cell.contentView.tintColor  = AppPrimaryClr;
    // Determine rounding based on position
    NSInteger rows = [tableView numberOfRowsInSection:indexPath.section];
    CGFloat radius = 26.0;
    CGRect bounds = cell.bounds; // willDisplayCell timing
    
    // Special “button” row (full rounding)
    BOOL isButtonRow = (buttonRowIndex >= 0 &&
                        indexPath.section == buttonSection &&
                        indexPath.row == buttonRowIndex);
    
    UIBezierPath *path = nil;
    
    if (isButtonRow) {
        path = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:radius];
        // Optional: tweak appearance for the button row only:
        // cell.contentView.backgroundColor = AppPrimaryClr;
        // cell.textLabel.textColor = UIColor.whiteColor;
        // tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    } else if (rows <= 1) {
        path = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:radius];
    } else if (indexPath.row == 0) {
        path = [UIBezierPath bezierPathWithRoundedRect:bounds
                                     byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                           cornerRadii:CGSizeMake(radius, radius)];
    } else if (indexPath.row == rows - 1) {
        path = [UIBezierPath bezierPathWithRoundedRect:bounds
                                     byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
                                           cornerRadii:CGSizeMake(radius, radius)];
    } else {
        path = [UIBezierPath bezierPathWithRect:bounds];
    }
    
    // Apply mask
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    cell.layer.mask = mask;
    cell.layer.masksToBounds = YES;
    
    // Optional: shadow in card mode (applied on cell.layer)
    /*if (!useRowCardMode) {
     cell.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.12].CGColor;
     cell.layer.shadowOpacity = 1.0;
     cell.layer.shadowOffset = CGSizeMake(0, 2);
     cell.layer.shadowRadius = 6;
     cell.layer.masksToBounds = NO; // shadow needs this
     } else {
     cell.layer.shadowOpacity = 0.0;
     cell.layer.masksToBounds = YES;
     }*/
    
    UIColor *cellShadowClr = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        CGFloat a = (tc.userInterfaceStyle == UIUserInterfaceStyleDark) ? 0.40 : 0.22;
        return [UIColor colorWithWhite:0 alpha:a];
    }];
    [cell pp_setShadowColor:cellShadowClr];
    cell.layer.shadowOpacity = 1.0;
    cell.layer.shadowOffset = CGSizeMake(0, 2);
    cell.layer.shadowRadius = 6;
    cell.layer.masksToBounds = NO; // shadow needs this
}

/// 💎 The classic fallback version with your custom visual quality
+ (UIButton *)legacyContainerButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    button.layer.cornerRadius = 25;
    button.layer.masksToBounds = YES;
    [button pp_setShadowColor:AppShadowClr];
    button.layer.shadowOpacity = 0.15;
    button.layer.shadowRadius = 8;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    return button;
}


+ (UIButton *)createContainerInParent:(UIView *)parentView withBgColor:(UIColor * _Nullable)backgroundColor
{
    UIButton *bgButton;
    
    if (@available(iOS 26.0, *)) {
        // 🧊 Modern iOS 26+ glass style
        if ([UIButtonConfiguration respondsToSelector:@selector(glassButtonConfiguration)]) {
            UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(PP_IOS26_Inset, PP_IOS26_Inset, PP_IOS26_Inset, PP_IOS26_Inset);
            
            if(backgroundColor)
                cfg.baseBackgroundColor = [backgroundColor colorWithAlphaComponent:0.35];
            else
                cfg.baseBackgroundColor = [AppForgroundColr colorWithAlphaComponent:0.35];
            cfg.baseForegroundColor = AppPrimaryClr;
            
            bgButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
            bgButton.configuration = cfg;
        } else {
            // fallback if Apple changes API name
            bgButton = [self legacyContainerButton];
        }
    } else {
        // 🌫️ iOS < 26.0 legacy design (the good one)
        bgButton = [self legacyContainerButton];
    }
    
    // ✅ common styling for both paths
    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    bgButton.layer.cornerRadius = 25;
    bgButton.clipsToBounds = YES;
    
    [parentView addSubview:bgButton];
    
    
    return bgButton;
}


+ (void)applyCornerMaskToView:(UIView *)view
                           tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br
{
    if (!view) return;

    [view layoutIfNeeded];
    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) return;

    CGFloat w = CGRectGetWidth(bounds);
    CGFloat h = CGRectGetHeight(bounds);

    UIBezierPath *path = [UIBezierPath bezierPath];

    // Start top-left
    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0)
                 controlPoint:CGPointZero];

    // Top edge
    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr)
                 controlPoint:CGPointMake(w, 0)];

    // Right edge
    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h)
                 controlPoint:CGPointMake(w, h)];

    // Bottom edge
    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl)
                 controlPoint:CGPointMake(0, h)];

    [path closePath];

    CAShapeLayer *mask = nil;

    if ([view.layer.mask isKindOfClass:[CAShapeLayer class]]) {
        mask = (CAShapeLayer *)view.layer.mask;
    } else {
        mask = [CAShapeLayer layer];
        view.layer.mask = mask;
    }

    // 🔥 Disable implicit animations (CRITICAL)
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    mask.frame = bounds;
    mask.path  = path.CGPath;

    [CATransaction commit];
}
/*+ (void)applyCornerMaskToView:(UIView *)view
                           tl:(CGFloat)tl
                           tr:(CGFloat)tr
                           bl:(CGFloat)bl
                           br:(CGFloat)br

{
    [view layoutIfNeeded];
    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) return;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    
    // Draw each corner manually
    [path moveToPoint:CGPointMake(0, tl)];
    [path addQuadCurveToPoint:CGPointMake(tl, 0) controlPoint:CGPointZero];
    
    [path addLineToPoint:CGPointMake(w - tr, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, tr) controlPoint:CGPointMake(w, 0)];
    
    [path addLineToPoint:CGPointMake(w, h - br)];
    [path addQuadCurveToPoint:CGPointMake(w - br, h) controlPoint:CGPointMake(w, h)];
    
    [path addLineToPoint:CGPointMake(bl, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - bl) controlPoint:CGPointMake(0, h)];
    
    [path closePath];
    
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    view.layer.mask = mask;
    
    
}*/

+ (void)addLiquidGlassBorderToView:(UIView *)view {
    [self addLiquidGlassBorderToView:view cornerRadius:12 color:[UIColor colorWithWhite:1 alpha:0.9]];
}

+ (void)addLiquidGlassBorderToView:(UIView *)view
                      cornerRadius:(float)cornerRadius
                             color:(UIColor *)color
{
    if (!view) return;

    // Remove old glass layers
    for (CALayer *layer in view.layer.sublayers.copy) {
        if ([layer.name hasPrefix:@"LiquidGlass"]) {
            [layer removeFromSuperlayer];
        }
    }

    [view layoutIfNeeded];

    CGRect bounds = view.bounds;
    if (CGRectIsEmpty(bounds)) return;

    UIColor *strokeColor = color ?: [UIColor colorWithWhite:1 alpha:0.9];

    // ─────────────────────────────
    // Primary glass stroke
    // ─────────────────────────────
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.name = @"LiquidGlassStroke";
    stroke.frame = bounds;
    stroke.path = [UIBezierPath bezierPathWithRoundedRect:bounds
                                             cornerRadius:cornerRadius].CGPath;
    stroke.fillColor = UIColor.clearColor.CGColor;
    stroke.strokeColor = strokeColor.CGColor;
    stroke.lineWidth = 0.5;
    stroke.opacity = 0.75;

    // Soft glow
    stroke.shadowColor = strokeColor.CGColor;
    stroke.shadowOpacity = 0.35;
    stroke.shadowRadius = 10;
    stroke.shadowOffset = CGSizeZero;

    [view.layer addSublayer:stroke];

    // ─────────────────────────────
    // Inner highlight (glass edge)
    // ─────────────────────────────
    CAShapeLayer *innerGlow = [CAShapeLayer layer];
    innerGlow.name = @"LiquidGlassInnerGlow";
    innerGlow.frame = bounds;
    innerGlow.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 1, 1)
                                               cornerRadius:cornerRadius - 1].CGPath;
    innerGlow.fillColor = UIColor.clearColor.CGColor;
    innerGlow.strokeColor = [UIColor.whiteColor colorWithAlphaComponent:0.35].CGColor;
    innerGlow.lineWidth = 0.5;
    innerGlow.opacity = 0.6;

    [view.layer addSublayer:innerGlow];

    // ─────────────────────────────
    // Subtle animated shine (iOS 26 feel)
    // ─────────────────────────────
    CAGradientLayer *shine = [CAGradientLayer layer];
    shine.name = @"LiquidGlassShine";
    shine.frame = bounds;
    shine.cornerRadius = cornerRadius;
    shine.colors = @[
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.0].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.25].CGColor,
        (__bridge id)[UIColor.whiteColor colorWithAlphaComponent:0.0].CGColor
    ];
    shine.startPoint = CGPointMake(0.0, 0.0);
    shine.endPoint   = CGPointMake(1.0, 1.0);
    shine.locations  = @[@0.35, @0.5, @0.65];
    shine.opacity    = 0.4;

    CAShapeLayer *shineMask = [CAShapeLayer layer];
    shineMask.path = stroke.path;
    shine.mask = shineMask;

    [view.layer addSublayer:shine];

    // Slow breathing animation (system-like)
    CABasicAnimation *pulse =
    [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.25;
    pulse.toValue   = @0.45;
    pulse.duration  = 2.8;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction =
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [shine addAnimation:pulse forKey:@"liquidPulse"];

    // ─────────────────────────────
    // Touch feedback (interactive glow)
    // ─────────────────────────────
    stroke.actions = @{
        @"shadowOpacity" : [NSNull null],
        @"opacity"       : [NSNull null]
    };
}

 

+ (void)addLiquidGlassBorderToView:(UIView *)view cornerRadius:(float)cornerRadius{
    [self addLiquidGlassBorderToView:view cornerRadius:cornerRadius color:[UIColor colorWithWhite:1 alpha:0.9]];

    /*
     // Animate shimmer (slow)
     CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
     anim.fromValue = @0;
     anim.toValue = @(M_PI * 2);
     anim.duration = 12.0;
     anim.repeatCount = HUGE_VALF;
     [gradient addAnimation:anim forKey:@"liquidShimmer"];
     */
}


+ (nullable UIView *)addBgForOldIOSOn:(UIView *)container Corners:(float)corners
                          Constraints:(nullable void (^)(UIView *bgView))constraintsBlock
{
    // 🔹 Background view
    UIView *bgView = [[UIView alloc] init];
    bgView.translatesAutoresizingMaskIntoConstraints = NO;
    bgView.layer.cornerRadius = corners;
    bgView.clipsToBounds = YES;
    
    // 🔹 Blur effect (fallback for old iOS)
    UIBlurEffect *effect;
    if (@available(iOS 13.0, *)) {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    } else {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    blurView.layer.cornerRadius = corners;
    blurView.clipsToBounds = YES;
    blurView.alpha = 0.8;
    
    // 🔹 Add subviews
    [bgView addSubview:blurView];
    [container addSubview:bgView];
    
    // 🔹 Fill blur inside bg
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:bgView.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:bgView.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:bgView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:bgView.trailingAnchor]
    ]];
    
    // 🔹 Optional décor
    bgView.layer.borderWidth = 0.5;
    UIColor *decorBorder = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:1.0 alpha:0.15]
            : [UIColor colorWithWhite:1.0 alpha:0.9];
    }];
    [bgView pp_setBorderColor:decorBorder];
    
    [bgView pp_setShadowColor:[UIColor blackColor]];
    bgView.layer.shadowOpacity = 0.3;
    bgView.layer.shadowOffset = CGSizeMake(0, 2);
    bgView.layer.shadowRadius = 4;
    
    // 🔥 If user provided layout constraints — apply them
    if (constraintsBlock != nil) {
        constraintsBlock(bgView);
    }
    
    return bgView;
}

#pragma mark - Design System Presets (PPDesignTokens)

+ (void)applyElevatedCardStyleToView:(UIView *)view {
    view.backgroundColor = AppForgroundColr;
    view.layer.cornerRadius = PPCornerLarge;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.clipsToBounds = NO;
    PPApplyElevatedShadow(view);
}

+ (void)applySubtleCardStyleToView:(UIView *)view {
    view.backgroundColor = AppForgroundColr;
    view.layer.cornerRadius = PPCornerMedium;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.clipsToBounds = NO;
    PPApplyCardShadow(view);
}

+ (void)applyPrimaryCTAStyleToButton:(UIButton *)button {
    button.backgroundColor = AppPrimaryClr;
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [GM boldFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    button.layer.cornerRadius = PPButtonHeightLG / 2.0;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.clipsToBounds = YES;
    PPApplyButtonShadow(button);

    NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:PPButtonHeightLG];
    height.priority = UILayoutPriorityDefaultHigh;
    height.active = YES;
}

+ (void)applySecondaryCTAStyleToButton:(UIButton *)button {
    button.backgroundColor = UIColor.clearColor;
    [button setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    button.titleLabel.font = [GM boldFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
    button.layer.cornerRadius = PPButtonHeightLG / 2.0;
    button.layer.borderWidth = 1.5;
    [button pp_setBorderColor:AppPrimaryClr];
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
    button.clipsToBounds = YES;

    NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:PPButtonHeightLG];
    height.priority = UILayoutPriorityDefaultHigh;
    height.active = YES;
}

+ (void)applyGlassStyleToView:(UIView *)view cornerRadius:(CGFloat)cornerRadius {
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    view.layer.cornerRadius = cornerRadius;
    view.layer.borderWidth = 0.5;
    UIColor *glassBorder = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return (tc.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [UIColor colorWithWhite:1.0 alpha:0.18]
            : [UIColor colorWithWhite:1.0 alpha:0.10];
    }];
    [view pp_setBorderColor:glassBorder];
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
    view.clipsToBounds = YES;
}

@end






































//
//  PPThemeManager.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/11/2025.
//



static NSString * const PPLegacyThemePreferenceKey = @"themePreference";

@implementation PPThemeManager

+ (instancetype)sharedManager {
    static PPThemeManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PPThemeManager alloc] init];
    });
    return manager;
}

#pragma mark - Save / Load

- (void)saveUserInterfaceStyle:(UIUserInterfaceStyle)style {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:style forKey:kUserInterfaceStyleKey];
    NSString *legacy;
    if (style == UIUserInterfaceStyleDark) {
        legacy = @"dark";
    } else if (style == UIUserInterfaceStyleLight) {
        legacy = @"light";
    } else {
        legacy = @"system";
    }
    [defaults setObject:legacy forKey:PPLegacyThemePreferenceKey];
    NSLog(@"💾 Saved interface style: %@", legacy);
}

- (UIUserInterfaceStyle)loadUserInterfaceStyle {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:kUserInterfaceStyleKey] != nil) {
        return (UIUserInterfaceStyle)[defaults integerForKey:kUserInterfaceStyleKey];
    }

    NSString *legacyTheme = [defaults stringForKey:PPLegacyThemePreferenceKey];
    if ([legacyTheme isEqualToString:@"dark"]) {
        return UIUserInterfaceStyleDark;
    } else if ([legacyTheme isEqualToString:@"light"]) {
        return UIUserInterfaceStyleLight;
    } else if ([legacyTheme isEqualToString:@"system"]) {
        return UIUserInterfaceStyleUnspecified;
    }

    // Default to dark for first launch
    UIUserInterfaceStyle fallback = UIUserInterfaceStyleDark;
    [self saveUserInterfaceStyle:fallback];
    return fallback;
}

#pragma mark - Apply

- (void)applySavedInterfaceStyleToWindow:(UIWindow *)window {
    if (!window) return;
    UIUserInterfaceStyle style = [self loadUserInterfaceStyle];
    window.overrideUserInterfaceStyle = style;
    NSString *label = (style == UIUserInterfaceStyleDark) ? @"Dark"
                    : (style == UIUserInterfaceStyleLight) ? @"Light" : @"System";
    NSLog(@"🌗 Applied saved style: %@", label);
}

#pragma mark - Toggle

- (void)toggleUserInterfaceStyleForWindow:(UIWindow *)window {
    if (!window) return;

    UIUserInterfaceStyle current = [self loadUserInterfaceStyle];
    UIUserInterfaceStyle next = (current == UIUserInterfaceStyleDark)
                                ? UIUserInterfaceStyleLight
                                : UIUserInterfaceStyleDark;

    window.overrideUserInterfaceStyle = next;
    [self saveUserInterfaceStyle:next];

    [UIView transitionWithView:window
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        // Force the entire view hierarchy to re-resolve dynamic CGColorRef
        // values (border, shadow) during the cross-dissolve.
        [window pp_resolveLayerColorsRecursively];
    }
                    completion:^(BOOL finished) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PPThemeDidChangeNotification
                          object:self
                        userInfo:@{@"style": @(next)}];
    }];
}

- (void)applyInterfaceStyle:(UIUserInterfaceStyle)style toWindow:(UIWindow *)window {
    if (!window) return;

    window.overrideUserInterfaceStyle = style;
    [self saveUserInterfaceStyle:style];

    [UIView transitionWithView:window
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [window pp_resolveLayerColorsRecursively];
    }
                    completion:^(BOOL finished) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:PPThemeDidChangeNotification
                          object:self
                        userInfo:@{@"style": @(style)}];
    }];
}




@end



/* ********************************************************************** UISegmentedControl ************************************************************************************ */

@implementation UISegmentedControl (Rounded)

- (UIImage *)imageWithColor:(UIColor *)color radius:(CGFloat)radius {
    CGRect rect = CGRectMake(0, 0, 1, 40); // ثابت للطول فقط
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    [color setFill];
    [path fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)applyRoundedStyleWithRadius:(CGFloat)radius
                          tintColor:(UIColor *)tint
                    backgroundColor:(UIColor *)background {
    
    // خلفية التحديد
    UIImage *selectedImg = [self imageWithColor:tint radius:radius];
    [self setBackgroundImage:selectedImg forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    
    // خلفية غير محدد
    UIImage *normalImg = [self imageWithColor:background radius:radius];
    [self setBackgroundImage:normalImg forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    
    // Remove dividers completely
    [self setDividerImage:[UIImage new]
      forLeftSegmentState:UIControlStateNormal
        rightSegmentState:UIControlStateNormal
               barMetrics:UIBarMetricsDefault];
    
    self.layer.cornerRadius = radius;
    self.layer.masksToBounds = YES;
}
@end
