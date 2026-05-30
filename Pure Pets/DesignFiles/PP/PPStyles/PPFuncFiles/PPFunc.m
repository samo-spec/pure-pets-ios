//
//  PPFunc.m
//  Pure Pets
//
//  Created by SAM on 13/09/2025.
//

#import "PPFunc.h"
#import "UserManager.h"
#import "PPRolePermission.h"
@import FirebaseStorage;

NS_ASSUME_NONNULL_BEGIN

@implementation PPFunc

#pragma mark - User Country (Safe)


+ (NSString *)formattedPhoneNumber:(NSString *)raw
{
   if (!raw.length) return @"—";

   // 1️⃣ Normalize Arabic / Persian digits → English
   NSDictionary *map = @{
       @"٠":@"0",@"١":@"1",@"٢":@"2",@"٣":@"3",@"٤":@"4",
       @"٥":@"5",@"٦":@"6",@"٧":@"7",@"٨":@"8",@"٩":@"9",
       @"۰":@"0",@"۱":@"1",@"۲":@"2",@"۳":@"3",@"۴":@"4",
       @"۵":@"5",@"۶":@"6",@"۷":@"7",@"۸":@"8",@"۹":@"9"
   };

   NSMutableString *s = [raw mutableCopy];
   for (NSString *k in map) {
       [s replaceOccurrencesOfString:k
                           withString:map[k]
                              options:0
                                range:NSMakeRange(0, s.length)];
   }

   // 2️⃣ Keep digits and +
   NSCharacterSet *allowed =
   [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];

   NSMutableString *digits = [NSMutableString string];
   for (NSUInteger i = 0; i < s.length; i++) {
       unichar c = [s characterAtIndex:i];
       if ([allowed characterIsMember:c]) {
           [digits appendFormat:@"%C", c];
       }
   }

   // 3️⃣ International (starts with +)
   if ([digits hasPrefix:@"+"]) {

       // Example: +966501234567
       if (digits.length >= 7) {
           NSMutableString *out = [NSMutableString string];
           [out appendString:@"+"];

           // country code (1–3 digits)
           NSUInteger idx = 1;
           while (idx < digits.length &&
                  idx < 4 &&
                  isdigit([digits characterAtIndex:idx])) {
               [out appendFormat:@"%C", [digits characterAtIndex:idx]];
               idx++;
           }

           // rest grouped
           NSMutableString *rest =
           [[digits substringFromIndex:idx] mutableCopy];

           for (NSUInteger i = 0; i < rest.length; i++) {
               if (i % 3 == 0) [out appendString:@" "];
               [out appendFormat:@"%C", [rest characterAtIndex:i]];
           }

           return out;
       }

       return digits;
   }

   // 4️⃣ Local numbers (most common)
   if (digits.length == 10) {
       // 0501234567 → 050 123 4567
       return [NSString stringWithFormat:@"%@ %@ %@",
               [digits substringToIndex:3],
               [digits substringWithRange:NSMakeRange(3, 3)],
               [digits substringFromIndex:6]];
   }

   if (digits.length == 9) {
       // 501234567 → 50 123 4567
       return [NSString stringWithFormat:@"%@ %@ %@",
               [digits substringToIndex:2],
               [digits substringWithRange:NSMakeRange(2, 3)],
               [digits substringFromIndex:5]];
   }
    
    // 🇶🇦 Qatar local numbers (8 digits)
    if (digits.length == 8) {
        // 55123456 → 5512 3456
        return [NSString stringWithFormat:@"%@ %@",
                [digits substringToIndex:4],
                [digits substringFromIndex:4]];
    }
    
    // 🇶🇦 Qatar international
    if ([digits hasPrefix:@"+974"] && digits.length == 12) {
        // +97455123456 → +974 5512 3456
        NSString *local = [digits substringFromIndex:4];
        return [NSString stringWithFormat:@"+974 %@ %@",
                [local substringToIndex:4],
                [local substringFromIndex:4]];
    }

   // 5️⃣ Fallback
   return digits;
}
+ (void)reloadAppUI {
    DLog(@"[PPFUNC] reloadAppUI: %@",NSDate.date);
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    window.semanticContentAttribute =Language.semanticAttributeForCurrentLanguage;
    window.semanticContentAttribute = GM.setSemantic;
    [UIView appearance].semanticContentAttribute = GM.setSemantic;;

    // Rebuild root controller
    UIViewController *newRoot = [self buildRootController];
     newRoot.view.semanticContentAttribute =Language.semanticAttributeForCurrentLanguage;

    [UIView transitionWithView:window
                      duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        window.rootViewController = newRoot;
                [PPFunc setRootSemantic];

    } completion:nil];
}

+ (UIViewController *)buildRootController {
    // Your initial screen here
    DLog(@"[PPFUNC] buildRootController: %@",NSDate.date);

    PPRootTabBarController *home = [[PPRootTabBarController alloc] init]; //or the homeController
    home.view.semanticContentAttribute =Language.semanticAttributeForCurrentLanguage;

    return home;
}

+ (void)setRootSemantic {
    DLog(@"[PPFUNC] setRootSemantic: %@",NSDate.date);
    
    
    // 2) Apply semantic direction globally (affects NEW views)
    UISemanticContentAttribute attr = Language.semanticAttributeForCurrentLanguage;
    [UIView appearance].semanticContentAttribute        = attr;
    [UINavigationBar appearance].semanticContentAttribute = attr;
    
    DLog(@"[Language] applied appearance semanticAttribute=%ld", (long)attr);
    
    // 3) Reload all scenes so EXISTING UI rebuilds under new direction
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                UIWindowScene *ws = (UIWindowScene *)scene;
                //id delegate = ws.delegate;
                
                
                for (UIWindow *w in ws.windows) {
                    w.semanticContentAttribute = attr;
                    [w setNeedsLayout];
                    [w layoutIfNeeded];
                }
            }
        } else {
            // iOS 12 and earlier fallback
            UIWindow *w = UIApplication.sharedApplication.keyWindow;
            w.semanticContentAttribute = attr;
            [w setNeedsLayout];
            [w layoutIfNeeded];
        }
    });
}
+ (BOOL)PPUserCheck
{
    if (!UserManager.sharedManager.isUserLoggedIn) { [UserManager showPromptOnTopController]; return NO; } return YES;
}
  

 
+ (void)presentFloatingSheetFrom:(UIViewController *)presenter
                        sheetVC:(UIViewController *)sheetVC
                     detentStyle:(PPSheetDetentStyle)style
{
    if (!presenter || !sheetVC) return;

    // Always page sheet (NEVER overFullScreen)
    sheetVC.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet =
            sheetVC.sheetPresentationController;

        // ───────────────
        // Detents
        // ───────────────
        if (@available(iOS 16.0, *)) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent customDetentWithIdentifier:@"99" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                    return context.maximumDetentValue * 0.98;
                }]
            ];
        } else {
            sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        }
        // ───────────────
        // 🔥 FORCE FLOATING (CRITICAL)
        // ───────────────
        sheet.prefersEdgeAttachedInCompactHeight = NO;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = NO;

        // ───────────────
        // UI polish
        // ───────────────
      
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 42.0;

        //sheet.largestUndimmedDetentIdentifier =  @"99";

        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    // ───────────────
    // Present SAFELY
    // ───────────────
    UIViewController *safePresenter =
        presenter.presentedViewController ?: presenter;

    [safePresenter presentViewController:sheetVC
                                animated:YES
                              completion:nil];
}

+ (void)presentFloatingSheetFrom:(UIViewController *)presenter
                        sheetVC:(UIViewController *)sheetVC
                     detentStyle:(PPSheetDetentStyle)style
                    withCompletion:(void (^_Nullable)(void))completion
{
    if (!presenter || !sheetVC) return;

    sheetVC.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet =
            sheetVC.sheetPresentationController;

        if (@available(iOS 16.0, *)) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent customDetentWithIdentifier:@"99" resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                    return context.maximumDetentValue * 0.98;
                }]
            ];
        } else {
            sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        }

        sheet.prefersEdgeAttachedInCompactHeight = NO;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = NO;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 42.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }

    UIViewController *safePresenter =
        presenter.presentedViewController ?: presenter;

    [safePresenter presentViewController:sheetVC
                                animated:YES
                              completion:completion];
}

 

+ (void)presentSheetFrom:(UIViewController *)presentingVC
                sheetVC:(UIViewController *)sheetVC
            detentStyle:(PPSheetDetentStyle)style
{
    if (!presentingVC || !sheetVC) return;
    CGFloat height = UIScreen.mainScreen.bounds.size.height;

    //UIWindow *win = UIApplication.sharedApplication.windows.firstObject;
    //UIStatusBarManager *mgr = win.windowScene.statusBarManager;
    //CGFloat _statusH = mgr.statusBarFrame.size.height;
    
    sheetVC.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationControllerDetent *customMedium = UISheetPresentationControllerDetent.mediumDetent;
    UISheetPresentationControllerDetent *chatsDent = UISheetPresentationControllerDetent.mediumDetent;

    UISheetPresentationControllerDetent *profileDent = UISheetPresentationControllerDetent.mediumDetent;
    UISheetPresentationControllerDetent *customMedium80 = UISheetPresentationControllerDetent.mediumDetent;
    UISheetPresentationControllerDetent *customMedium300 = UISheetPresentationControllerDetent.mediumDetent;
    UISheetPresentationControllerDetent *adsViewDent = UISheetPresentationControllerDetent.mediumDetent;

    if (@available(iOS 16.0, *)) {

        chatsDent = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"chatsDent"  resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return height * 0.85; // your custom medium height
        }];
        
        customMedium = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"customMedium"  resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return height * 0.7; // your custom medium height
        }];
        
        customMedium80 = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"customMedium80"  resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return height * 0.85; // your custom medium height
        }];
        
        adsViewDent = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"adsViewDent"  resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return height * 0.95; // your custom medium height
        }];
        
        profileDent = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"profileDent"  resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return (height - PPTotalBarHeight); // your custom medium height
        }];
        
        customMedium300 = [UISheetPresentationControllerDetent customDetentWithIdentifier:@"customMedium300"  resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
            return 400; // your custom medium height
        }];
        
    } else {
        // Fallback on earlier versions
    }
    
    
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = sheetVC.sheetPresentationController;
        if (sheet) {
            // Configure detents
            switch (style) {
                case PPSheetDetentStyle70:
                    sheet.detents = @[customMedium];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                    break;
                    
                case PPSheetDetentStyleAdsView:
                    sheet.detents = @[adsViewDent];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                    break;
                    
                case PPSheetDetentStyle80:
                    sheet.detents = @[customMedium80];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                    break;
                    
                case PPSheetDetentStyle300:
                    sheet.detents = @[customMedium300];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                    break;
                    
                case PPSheetDetentStyleProfile:
                
                    sheet.detents = @[ profileDent];

                    
                    break;
                    
                case PPSheetDetentStyleMediumOnly:
                    sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                    break;

                case PPSheetDetentStyleLargeOnly:
                    sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
                    break;
                    
                case PPSheetDetentStyleMediumAndLarge:
                    sheet.detents = @[
                        UISheetPresentationControllerDetent.mediumDetent,
                        UISheetPresentationControllerDetent.largeDetent
                    ];
                    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
                    break;
                case PPSheetDetentStyleSemiLargAndLarge:
                    //sheet.detents = @[
                    //    chatsDent,
                       // UISheetPresentationControllerDetent.largeDetent
                    //];
                    //if (@available(iOS 16.0, *)) {
                    //    sheet.largestUndimmedDetentIdentifier = chatsDent.identifier;
                    //} else {
                        // Fallback on earlier versions
                    //}
                    
                    
                    if (@available(iOS 16.0, *)) {
                        sheet.detents = @[
                            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"99"
                                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                                return context.maximumDetentValue * 0.99;
                            }]
                        ];
                    } else {
                        // Fallback on earlier versions
                    }

                    sheet.selectedDetentIdentifier = @"99";
                    sheet.largestUndimmedDetentIdentifier = nil;
                    sheet.prefersGrabberVisible = YES;
                    
                    
                    break;
            }

            // Style settings
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 42.0;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
            
            if(PPIOS26())
            {
                //sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDete;
                //presentingVC.modalPresentationCapturesStatusBarAppearance = NO;
                //sheet.prefersEdgeAttachedInCompactHeight = NO;
                
            }
        }
    } else {
        // Fallback for iOS < 15
        sheetVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    
    

    // Present on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [presentingVC presentViewController:sheetVC animated:YES completion:nil];
    });
}


#pragma mark - 🔹 Add Bar Button (Right Side)
+ (void)addBarButtonToRightSide:(UIBarButtonItem *)barButton
                      inNavItem:(UINavigationItem *)navItem
             inNavigationController:(UINavigationController *)navController
                       animated:(BOOL)animated
{
    if (!navItem) return;
    
    NSArray *existingItems = navItem.rightBarButtonItems ?: @[];
    if ([existingItems containsObject:barButton]) return; // avoid duplicates
    
    NSMutableArray *newItems = [existingItems mutableCopy];
    [newItems addObject:barButton];

    // 🔊 Optional system feedback
    if (animated) {
        AudioServicesPlaySystemSound(1104);
        UIImpactFeedbackGenerator *feedback =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }

    UIView *targetView = navController.navigationBar ?: navController.view;

    // 🎞️ Fade animation
    [UIView transitionWithView:targetView
                      duration:animated ? 0.25 : 0.0
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [navItem setRightBarButtonItems:newItems animated:NO];
    } completion:nil];
}

#pragma mark - 🔹 Remove Bar Button (Right Side)
+ (void)removeBarButtonFromRightSide:(UIBarButtonItem *)barButton
                            inNavItem:(UINavigationItem *)navItem
               inNavigationController:(UINavigationController *)navController
                             animated:(BOOL)animated
{
    if (!navItem) return;

    NSMutableArray *existing = [navItem.rightBarButtonItems mutableCopy];
    if (!existing || existing.count == 0) return;
    if (![existing containsObject:barButton]) return;

    [existing removeObject:barButton];

    if (animated) {
        AudioServicesPlaySystemSound(1104);
        UIImpactFeedbackGenerator *feedback =
            [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [feedback impactOccurred];
    }

    UIView *targetView = navController.navigationBar ?: navController.view;

    [UIView transitionWithView:targetView
                      duration:animated ? 0.25 : 0.0
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [navItem setRightBarButtonItems:existing animated:NO];
    } completion:nil];
}




+ (NSDictionary *)ageInfoFromBirthday:(NSDate *)birthdate adultHood:(NSInteger)adultHood {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSString *readyString = @"";
    NSString *ageString = @"";
    
    if (!birthdate) {
        result[@"ageString"] = @"0";
        result[@"readyString"] = @"";
        return result;
    }
    
    NSDate *today = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                               fromDate:birthdate
                                                 toDate:today
                                                options:0];
    
    NSInteger years = components.year;
    NSInteger months = components.month;
    NSInteger days = components.day;
    NSInteger totalMonths = years * 12 + months;
    
    BOOL isAdult = (totalMonths >= adultHood);
    if (isAdult) readyString = kLang(@"readyToMarrage");
    
    // 🧠 Language detection
    BOOL isArabic = ([[Language currentLanguageCode] isEqualToString:@"ar"]);
    
    // 🕐 Build age string (localized short)
    if (years > 0 && months > 0) {
        if (isArabic)
            ageString = [NSString stringWithFormat:@"%ld س %ld ش", (long)years, (long)months];
        else
            ageString = [NSString stringWithFormat:@"%ldy %ldm", (long)years, (long)months];
    } else if (years > 0) {
        if (isArabic)
            ageString = [NSString stringWithFormat:@"%ld سنة", (long)years];
        else
            ageString = [NSString stringWithFormat:@"%ldy", (long)years];
    } else if (months > 0) {
        if (isArabic)
            ageString = [NSString stringWithFormat:@"%ld شهر", (long)months];
        else
            ageString = [NSString stringWithFormat:@"%ld month%@", (long)months, months > 1 ? @"s" : @""];
    } else if (days > 0) {
        if (isArabic)
            ageString = [NSString stringWithFormat:@"%ld أيام", (long)days];
        else
            ageString = [NSString stringWithFormat:@"%ld day%@", (long)days, days > 1 ? @"s" : @""];
    } else {
        if (isArabic)
            ageString = @"اليوم";
        else
            ageString = @"today";
    }
    
    result[@"ageString"] = ageString;
    result[@"readyString"] = readyString;
    
    //NSLog(@"🕒 [AgeInfo] %@ → %@ | totalMonths=%ld | adultHood=%ld | ready=%@", birthdate, ageString, (long)totalMonths, (long)adultHood, readyString);
    
    return result;
}



+ (UIImage *)fillEmptySidesWithBlur:(UIImage *)originalImage targetSize:(CGSize)targetSize {
    // Calculate aspect ratios
    CGFloat originalAspect = originalImage.size.width / originalImage.size.height;
    CGFloat targetAspect = targetSize.width / targetSize.height;
    
    // Create context for the final image
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
    //CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Calculate the rect for the original image (centered)
    CGRect imageRect;
    if (originalAspect > targetAspect) {
        // Image is wider than target - will have empty top/bottom
        CGFloat height = targetSize.width / originalAspect;
        imageRect = CGRectMake(0, (targetSize.height - height) / 2, targetSize.width, height);
    } else {
        // Image is taller than target - will have empty left/right
        CGFloat width = targetSize.height * originalAspect;
        imageRect = CGRectMake((targetSize.width - width) / 2, 0, width, targetSize.height);
    }
    
    // Draw the original image
    [originalImage drawInRect:imageRect];
    
    // Create blurred version for empty areas
    UIImage *blurredImage = [self createBlurredImage:originalImage];
    
    // Fill empty areas with blurred image
    if (originalAspect > targetAspect) {
        // Fill top and bottom
        CGRect topRect = CGRectMake(0, 0, targetSize.width, imageRect.origin.y);
        CGRect bottomRect = CGRectMake(0, CGRectGetMaxY(imageRect), targetSize.width, targetSize.height - CGRectGetMaxY(imageRect));
        
        [blurredImage drawInRect:topRect];
        [blurredImage drawInRect:bottomRect];
    } else {
        // Fill left and right
        CGRect leftRect = CGRectMake(0, 0, imageRect.origin.x, targetSize.height);
        CGRect rightRect = CGRectMake(CGRectGetMaxX(imageRect), 0, targetSize.width - CGRectGetMaxX(imageRect), targetSize.height);
        
        [blurredImage drawInRect:leftRect];
        [blurredImage drawInRect:rightRect];
    }
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}

+ (UIImage *)createBlurredImage:(UIImage *)image {
    CIImage *inputImage = [[CIImage alloc] initWithImage:image];
    
    // Apply Gaussian blur filter
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setValue:inputImage forKey:kCIInputImageKey];
    [blurFilter setValue:@10.0 forKey:kCIInputRadiusKey]; // Adjust blur radius as needed
    
    CIImage *outputImage = [blurFilter valueForKey:kCIOutputImageKey];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:[inputImage extent]];
    
    UIImage *blurredImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return blurredImage;
}


+ (UIImage *)fillEmptySidesWithGradient:(UIImage *)originalImage targetSize:(CGSize)targetSize {
    // Calculate aspect ratios
    CGFloat originalAspect = originalImage.size.width / originalImage.size.height;
    CGFloat targetAspect = targetSize.width / targetSize.height;
    
    // Create context for the final image
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Calculate the rect for the original image (centered)
    CGRect imageRect;
    if (originalAspect > targetAspect) {
        // Image is wider than target - will have empty top/bottom
        CGFloat height = targetSize.width / originalAspect;
        imageRect = CGRectMake(0, (targetSize.height - height) / 2, targetSize.width, height);
    } else {
        // Image is taller than target - will have empty left/right
        CGFloat width = targetSize.height * originalAspect;
        imageRect = CGRectMake((targetSize.width - width) / 2, 0, width, targetSize.height);
    }
    
    // Draw the original image
    [originalImage drawInRect:imageRect];
    
    // Create gradient for empty areas based on edge colors
    [self drawGradientInContext:context forImage:originalImage targetSize:targetSize imageRect:imageRect];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage;
}

+ (void)drawGradientInContext:(CGContextRef)context forImage:(UIImage *)image targetSize:(CGSize)targetSize imageRect:(CGRect)imageRect {
    // Get edge colors from the original image
    UIColor *topColor = [self colorFromImage:image atPoint:CGPointMake(0.5, 0)];
    UIColor *bottomColor = [self colorFromImage:image atPoint:CGPointMake(0.5, 1)];
    UIColor *leftColor = [self colorFromImage:image atPoint:CGPointMake(0, 0.5)];
    UIColor *rightColor = [self colorFromImage:image atPoint:CGPointMake(1, 0.5)];
    
    CGFloat originalAspect = image.size.width / image.size.height;
    CGFloat targetAspect = targetSize.width / targetSize.height;
    
    if (originalAspect > targetAspect) {
        // Fill top area with gradient from top color
        CGRect topRect = CGRectMake(0, 0, targetSize.width, imageRect.origin.y);
        [self drawVerticalGradientInRect:topRect fromColor:topColor toColor:topColor context:context];
        
        // Fill bottom area with gradient from bottom color
        CGRect bottomRect = CGRectMake(0, CGRectGetMaxY(imageRect), targetSize.width, targetSize.height - CGRectGetMaxY(imageRect));
        [self drawVerticalGradientInRect:bottomRect fromColor:bottomColor toColor:bottomColor context:context];
    } else {
        // Fill left area with gradient from left color
        CGRect leftRect = CGRectMake(0, 0, imageRect.origin.x, targetSize.height);
        [self drawHorizontalGradientInRect:leftRect fromColor:leftColor toColor:leftColor context:context];
        
        // Fill right area with gradient from right color
        CGRect rightRect = CGRectMake(CGRectGetMaxX(imageRect), 0, targetSize.width - CGRectGetMaxX(imageRect), targetSize.height);
        [self drawHorizontalGradientInRect:rightRect fromColor:rightColor toColor:rightColor context:context];
    }
}

+ (UIColor *)colorFromImage:(UIImage *)image atPoint:(CGPoint)point {
    CGImageRef imageRef = image.CGImage;
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = malloc(height * width * 4);
    NSUInteger bytesPerRow = 4 * width;
    NSUInteger bitsPerComponent = 8;
    
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    int x = (int)(point.x * width);
    int y = (int)(point.y * height);
    
    NSUInteger byteIndex = (bytesPerRow * y) + x * 4;
    
    CGFloat red   = rawData[byteIndex] / 255.0;
    CGFloat green = rawData[byteIndex + 1] / 255.0;
    CGFloat blue  = rawData[byteIndex + 2] / 255.0;
    CGFloat alpha = rawData[byteIndex + 3] / 255.0;
    
    free(rawData);
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (void)drawVerticalGradientInRect:(CGRect)rect fromColor:(UIColor *)fromColor toColor:(UIColor *)toColor context:(CGContextRef)context {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)fromColor.CGColor, (__bridge id)toColor.CGColor];
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, NULL);
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

+ (void)drawHorizontalGradientInRect:(CGRect)rect fromColor:(UIColor *)fromColor toColor:(UIColor *)toColor context:(CGContextRef)context {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)fromColor.CGColor, (__bridge id)toColor.CGColor];
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, NULL);
    
    CGPoint startPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}



+ (void)removeOldGradientsFromView:(UIView *)view {
    NSMutableArray<CALayer *> *layersToRemove = [NSMutableArray array];
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            [layersToRemove addObject:layer];
        }
    }
    for (CALayer *layer in layersToRemove) {
        [layer removeFromSuperlayer];
    }
}


- (void)configureFirebase {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (![FIRApp defaultApp]) {
            [FIRApp configure];
            NSLog(@"Firebase configured ✅");
            
            //[FUM startAuthListenerWithChangeBlock:^(FIRUser * _Nullable authUser, UserModel * _Nullable userModel) { }];
            
        } else {
            DLog(@"Firebase already configured, skipping");
        }
    });
}

#pragma mark - Place Icon (Overlay style above view, not inside)

+ (void)PPPlaceIcon:(NSString *)icon onPostions:(IconPostions)Postions onView:(UIView *)view {
    if (!icon.length) return;
    if (!view) {
        //DLog(@"[HXFrame] ⚠️ No superview to place overlay icon on %@", self);
        return;
    }
    
    // Remove old one if any (avoid duplicates)
    for (UIView *sub in view.subviews) {
        if (sub.tag == 909090 && [sub isKindOfClass:UIImageView.class]) {
            [sub removeFromSuperview];
        }
        
        if (sub.tag == 9090901 && [sub isKindOfClass:UIImageView.class]) {
            [sub removeFromSuperview];
        }
    }
    
    UIImage *img = [UIImage pp_symbolNamed:icon pointSize:20 weight:UIImageSymbolWeightLight scale:UIImageSymbolScaleDefault palette:@[UIColor.whiteColor,UIColor.lightGrayColor] makeTemplate:NO];
    
    
    
    
    
    UIImageView *bgImageView = [[UIImageView alloc] init];
    bgImageView.contentMode = UIViewContentModeScaleToFill;
    bgImageView.tag = 9090901;
    bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat bgImageViewSize = 18;
    [NSLayoutConstraint activateConstraints:@[
        [bgImageView.widthAnchor constraintEqualToConstant:bgImageViewSize],
        [bgImageView.heightAnchor constraintEqualToConstant:bgImageViewSize]
    ]];
    bgImageView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.9];
    bgImageView.layer.cornerRadius =  9;
    bgImageView.clipsToBounds  = YES;
    [bgImageView pp_setBorderColor:AppSecondaryTextClr];
    bgImageView.layer.borderWidth = 1.0;
    [view addSubview:bgImageView];
    
    
    UIImageView *iv = [[UIImageView alloc] initWithImage:img];
    iv.contentMode = UIViewContentModeScaleToFill;
    iv.tag = 909090;
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.backgroundColor = AppClearClr; // transparent by default
    iv.layer.masksToBounds = NO;
    iv.tintColor = AppSecondaryTextClr;
    [view addSubview:iv];
    
    CGFloat size = 13;
    [NSLayoutConstraint activateConstraints:@[
        [iv.widthAnchor constraintEqualToConstant:size],
        [iv.heightAnchor constraintEqualToConstant:size]
    ]];
    
    CGFloat pad = 1;
    
    switch (Postions) {
        case IconPostionsTopLeft:
            [iv.topAnchor constraintEqualToAnchor:view.topAnchor constant:-pad].active = YES;
            [iv.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:-pad].active = YES;
            break;
        case IconPostionsTopRight:
            [iv.topAnchor constraintEqualToAnchor:view.topAnchor constant:-pad].active = YES;
            [iv.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:pad].active = YES;
            break;
        case IconPostionsTopMiddle:
            [iv.topAnchor constraintEqualToAnchor:view.topAnchor constant:-pad].active = YES;
            [iv.centerXAnchor constraintEqualToAnchor:view.centerXAnchor].active = YES;
            break;
        case IconPostionsBottomLeft:
            [iv.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:pad].active = YES;
            [iv.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:-pad].active = YES;
            break;
        case IconPostionsBottomRight:
            [iv.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:pad].active = YES;
            [iv.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:pad].active = YES;
            break;
        case IconPostionsBottomMiddle:
            [iv.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:pad].active = YES;
            [iv.centerXAnchor constraintEqualToAnchor:view.centerXAnchor].active = YES;
            break;
        case IconPostionsMiddleLeft:
            [iv.centerYAnchor constraintEqualToAnchor:view.centerYAnchor].active = YES;
            [iv.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:-pad].active = YES;
            break;
        case IconPostionsMiddleRight:
            [iv.centerYAnchor constraintEqualToAnchor:view.centerYAnchor].active = YES;
            [iv.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:pad].active = YES;
            break;
    }
    [bgImageView.centerYAnchor constraintEqualToAnchor:iv.centerYAnchor].active = YES;
    [bgImageView.centerXAnchor constraintEqualToAnchor:iv.centerXAnchor].active = YES;
    
    [bgImageView pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.32]];
    bgImageView.layer.shadowOpacity = 1.0;
    bgImageView.layer.shadowOffset = CGSizeMake(0, 0);
    bgImageView.layer.shadowRadius = 3;
    bgImageView.layer.masksToBounds = NO;
    
    iv.layer.cornerRadius =  10;
    iv.clipsToBounds=YES;
}


+ (UIView *)createEmptyModernCardView {
    // Container for the card view
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.layer.cornerRadius = 25; // Rounded corners
    cardView.layer.masksToBounds = NO; // Allow shadow outside the bounds
    [cardView pp_setShadowColor:[UIColor blackColor]];
    cardView.layer.shadowOpacity = 0.2;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 6;
    cardView.backgroundColor = [UIColor whiteColor];  // White background for the card
    
    // Optional: Add padding or content to the card as needed
    UIView *emptyContentView = [[UIView alloc] init];
    emptyContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:emptyContentView];
    
    // Set constraints for the empty content view (this is where you can add future content)
    [NSLayoutConstraint activateConstraints:@[
        [emptyContentView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:12],
        [emptyContentView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-12],
        [emptyContentView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:12],
        [emptyContentView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-12]
    ]];
    
    return cardView;
}

+ (UIView *)createCircleViewHeight:(float)height {
    // Container for the card view
    UIView *cardView = [[UIView alloc] init];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.layer.cornerRadius = height/2; // Rounded corners
    cardView.layer.masksToBounds = NO; // Allow shadow outside the bounds
    [cardView pp_setShadowColor:[UIColor blackColor]];
    cardView.layer.shadowOpacity = 0.4;
    cardView.layer.shadowOffset = CGSizeMake(0, 2);
    cardView.layer.shadowRadius = 8;
    cardView.backgroundColor = [UIColor whiteColor];  // White background for the card
    
    // Optional: Add padding or content to the card as needed
    UIView *emptyContentView = [[UIView alloc] init];
    emptyContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [cardView addSubview:emptyContentView];
    
    // Set constraints for the empty content view (this is where you can add future content)
    [NSLayoutConstraint activateConstraints:@[
        [emptyContentView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:2],
        [emptyContentView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-2],
        [emptyContentView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:2],
        [emptyContentView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-2]
    ]];
    
    return cardView;
}

#pragma mark - 🗑️ Firebase Storage Cleanup

+ (void)pp_deleteStorageImagesForURLs:(NSArray<NSString *> *)urls {
    if (!urls || urls.count == 0) return;

    FIRStorage *storage = [FIRStorage storage];
    for (NSString *urlString in urls) {
        if (![urlString isKindOfClass:NSString.class] || urlString.length == 0) continue;
        @try {
            FIRStorageReference *ref = [storage referenceForURL:urlString];
            [ref deleteWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"⚠️ [StorageCleanup] Failed to delete: %@ — %@",
                          ref.fullPath, error.localizedDescription);
                } else {
                    NSLog(@"🗑️ [StorageCleanup] Deleted: %@", ref.fullPath);
                }
            }];
        } @catch (NSException *exception) {
            NSLog(@"⚠️ [StorageCleanup] Invalid URL, skipping: %@", urlString);
        }
    }
}

+ (void)pp_deleteRemovedStorageImagesFromOldURLs:(NSArray<NSString *> *)oldURLs
                                         newURLs:(NSArray<NSString *> *)newURLs {
    if (!oldURLs || oldURLs.count == 0) return;

    NSSet<NSString *> *keepSet = [NSSet setWithArray:newURLs ?: @[]];
    NSMutableArray<NSString *> *toDelete = [NSMutableArray array];
    for (NSString *url in oldURLs) {
        if (![keepSet containsObject:url]) {
            [toDelete addObject:url];
        }
    }

    if (toDelete.count > 0) {
        NSLog(@"🗑️ [StorageCleanup] Deleting %lu orphaned image(s)…",
              (unsigned long)toDelete.count);
        [self pp_deleteStorageImagesForURLs:toDelete];
    }
}

@end

NS_ASSUME_NONNULL_END









 

/* ************************************************************************ PPUIIMAGE ******************************************************************************************* */
@implementation UIImage (PPSymbol)

- (UIImage *)resizedImageTo:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0); // 0.0 uses device scale
    [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


+ (UIImage *)symbolicImageNamed:(NSString *)imageName
                         weight:(UIImageSymbolWeight)weight
                          scale:(UIImageSymbolScale)scale
                      pointSize:(CGFloat)pointSize
{
    UIImage *baseImage = nil;
    
    if (@available(iOS 13.0, *)) {
        // Try system symbol first
        baseImage = [UIImage systemImageNamed:imageName];
    }
    
    // ✅ Fallback to custom image asset if not a system symbol
    if (!baseImage) {
        baseImage = [[UIImage imageNamed:imageName] resizedImageTo:CGSizeMake(30, 30)];
    }
    
    if (!baseImage) {
        NSLog(@"⚠️ Image not found: %@", imageName);
        return nil;
    }
    
    if (@available(iOS 13.0, *)) {
        // Build configuration like SF Symbol
        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:weight
                                                             scale:scale];
        
        // Apply configuration even to custom images
        baseImage = [baseImage imageByApplyingSymbolConfiguration:config];
    }
    baseImage  = [baseImage imageWithTintColor:AppPrimaryClr renderingMode:UIImageRenderingModeAlwaysTemplate];
    return baseImage;
}


+ (UIImage *)pp_symbolNamed:(NSString *)name
{
    return [UIImage pp_symbolNamed:name pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleDefault palette:@[AppForgroundColr , AppBackgroundClr] makeTemplate:NO];
}


+ (UIImage *)pp_symbolNamed:(NSString *)name
                  pointSize:(CGFloat)pointSize
                     weight:(UIImageSymbolWeight)weight
                      scale:(UIImageSymbolScale)scale
                    palette:(NSArray<UIColor *> *)palette
               makeTemplate:(BOOL)makeTemplate
{
    UIImage *img = [UIImage imageNamed:name];
#if __IPHONE_13_0
    if (!img) { img = [UIImage systemImageNamed:name]; } // allow using a real SF symbol name too
#endif
    if (!img) { return nil; }
    
#if __IPHONE_13_0
    // Try to apply symbol configuration (has effect only for symbol images)
    UIImageSymbolConfiguration *cfg =
    [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                    weight:weight
                                                     scale:scale];
    
#if __IPHONE_15_0
    if (palette.count > 0) {
        UIImageSymbolConfiguration *pal = [UIImageSymbolConfiguration configurationWithPaletteColors:palette];
        cfg = [cfg configurationByApplyingConfiguration:pal];
    }
#endif
    
    UIImage *configured = [img imageByApplyingSymbolConfiguration:cfg];
    if (configured) {
        return configured;
    }
#endif
    
    // Not a symbol → make it a template so tint works, and optionally resize to approx. point size.
    UIImage *templ = makeTemplate ? [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : img;
    return [self pp_resizedImage:templ toPointSize:pointSize];
}

+ (UIImage *)pp_resizedImage:(UIImage *)image toPointSize:(CGFloat)pointSize {
    if (!image) return nil;
    
    // Treat pointSize as target height; keep aspect
    CGFloat targetH = MAX(pointSize, 1.0);
    CGFloat aspect = image.size.width / MAX(image.size.height, 0.001);
    CGSize targetSize = CGSizeMake(targetH * aspect, targetH);
    
    UIGraphicsImageRenderer *renderer =
    [[UIGraphicsImageRenderer alloc] initWithSize:targetSize];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
        [image drawInRect:(CGRect){.origin=CGPointZero, .size=targetSize}];
    }];
}

@end


 
@implementation UIImage (PPDominantColor)

- (UIColor *)pp_dominantColor {

    CGSize size = CGSizeMake(40, 40);

    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGImageRef imageRef = scaled.CGImage;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    const UInt8 *pixels = CFDataGetBytePtr(data);

    NSUInteger length = CFDataGetLength(data);
    CGFloat r = 0, g = 0, b = 0;
    NSUInteger count = 0;

    for (NSUInteger i = 0; i < length; i += 4) {
        r += pixels[i];
        g += pixels[i + 1];
        b += pixels[i + 2];
        count++;
    }

    CFRelease(data);

    if (count == 0) return UIColor.clearColor;

    return [UIColor colorWithRed:(r / count) / 255.0
                           green:(g / count) / 255.0
                            blue:(b / count) / 255.0
                           alpha:1.0];
}

@end


@implementation UIImage (Crop)

- (void)pp_presentCircularCropperFromController:(nonnull UIViewController<TOCropViewControllerDelegate> *)controller {
    TOCropViewController *cropVC =
      [[TOCropViewController alloc] initWithCroppingStyle:TOCropViewCroppingStyleCircular
                                                    image:self];
    cropVC.delegate = controller;

    // Optional UI tweaks
    cropVC.aspectRatioPickerButtonHidden = YES;
    cropVC.resetButtonHidden = YES;
    cropVC.rotateButtonsHidden = YES;
    cropVC.title = kLang(@"Move & Zoom");

    [controller presentViewController:cropVC animated:YES completion:nil];
}

+ (void)pp_presentCircularCropperWithImage:(UIImage *)image
                            fromController:(UIViewController<TOCropViewControllerDelegate> *)controller {
    TOCropViewController *cropVC =
      [[TOCropViewController alloc] initWithCroppingStyle:TOCropViewCroppingStyleCircular
                                                    image:image];
    cropVC.delegate = controller;

    // Optional UI tweaks
    cropVC.aspectRatioPickerButtonHidden = YES;
    cropVC.resetButtonHidden = YES;
    cropVC.rotateButtonsHidden = NO;
    cropVC.title = kLang(@"Move & Zoom");
    cropVC.doneButtonTitle = kLang(@"Done");
    cropVC.cancelButtonTitle = kLang(@"Cancel");
     
 
    cropVC.modalPresentationStyle = UIModalPresentationFullScreen;
    cropVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve; // or .CoverVertical
    
    
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:cropVC];
    
    [controller presentViewController:nav inSize:CGSizeMake(cropVC.view.frame.size.width, cropVC.view.frame.size .height * 0.9) direction:PVCDirectionBottom completion:^{ }];}

@end






















@implementation UIButton (PPSymbol)

- (void)pp_setSymbolNamed:(NSString *)name
                pointSize:(CGFloat)pointSize
                   weight:(UIImageSymbolWeight)weight
                    scale:(UIImageSymbolScale)scale
                     tint:(UIColor *)tint
                  palette:(NSArray<UIColor *> *)palette
{
    UIImage *img =
    [UIImage pp_symbolNamed:name
                  pointSize:pointSize
                     weight:weight
                      scale:scale
                    palette:palette
               makeTemplate:YES];
    
    [self setImage:img forState:UIControlStateNormal];
    self.tintColor = tint ?: self.tintColor;
    
#if __IPHONE_13_0
    // If it's a real symbol, this gives dynamic behavior with text styles too
    self.imageView.preferredSymbolConfiguration =
    [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                    weight:weight
                                                     scale:scale];
#endif
    
    // Make sure image fills nicely without squeezing
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

- (void)pp_setCircularStyleWithDiameter:(CGFloat)diameter
                             background:(UIColor *)background
                                   tint:(UIColor *)tint
{
    self.backgroundColor = background;
    self.tintColor = tint ?: self.tintColor;
    
    if (diameter > 0) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [self.widthAnchor constraintEqualToConstant:diameter],
            [self.heightAnchor constraintEqualToConstant:diameter]
        ]];
        self.layer.cornerRadius = diameter * 0.5;
        self.layer.masksToBounds = YES;
    }
    
    // Place the glyph comfortably
    CGFloat inset = MAX( (diameter - 24.0) * 0.5, 6.0 ); // heuristic
    self.contentEdgeInsets = UIEdgeInsetsMake(inset, inset, inset, inset);
}



// ================================================================================================================//

@end


@interface CustomMenuView ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *backgroundView;
@end

@implementation CustomMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = UIColor.clearColor;
    
    // Background dimming view
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.3];
    self.backgroundView.alpha = 0;
    [self addSubview:self.backgroundView];
    
    // Table view for menu items
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.layer.cornerRadius = 12;
    self.tableView.clipsToBounds = YES;
    self.tableView.separatorInset = UIEdgeInsetsZero;
    [self addSubview:self.tableView];
    
    // Tap to dismiss
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap)];
    [self.backgroundView addGestureRecognizer:tapGesture];
}

- (void)showFromView:(UIView *)sourceView {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    self.frame = window.bounds;
    [window addSubview:self];
    
    // Calculate frame for table view
    CGFloat tableWidth = 280;
    CGFloat tableHeight = MIN(400, self.mainKindsArray.count * 60 + 20);
    CGRect sourceRect = [sourceView convertRect:sourceView.bounds toView:window];
    
    CGFloat tableX = sourceRect.origin.x;
    CGFloat tableY = CGRectGetMaxY(sourceRect) + 8;
    
    self.tableView.frame = CGRectMake(tableX, tableY, tableWidth, 0);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.backgroundView.alpha = 1;
        self.backgroundView.frame = self.bounds;
        self.tableView.frame = CGRectMake(tableX, tableY, tableWidth, tableHeight);
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.backgroundView.alpha = 0;
        self.tableView.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)handleBackgroundTap {
    [self dismiss];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mainKindsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"CategoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    MainKindsModel *category = self.mainKindsArray[indexPath.row];
    cell.textLabel.text = category.KindName;
    cell.textLabel.font = self.customFont ?: [UIFont systemFontOfSize:16];
    cell.textLabel.textColor = self.tintColor ?: [UIColor systemBlueColor];
    cell.imageView.image = [self imageForMainKindsModel:category];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MainKindsModel *selectedCategory = self.mainKindsArray[indexPath.row];
    if (self.selectionHandler) {
        self.selectionHandler(selectedCategory);
    }
    
    [self dismiss];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (UIImage *)imageForMainKindsModel:(MainKindsModel *)category {
    // Your image loading logic here
    return [UIImage systemImageNamed:@"pawprint.circle"];
}

@end

@implementation UIView (TapAction)

static char kUIViewTapActionKey;

- (void)addTapAction:(void (^)(void))handler {
    self.userInteractionEnabled = YES;

    // Store the handler block using associated object
    objc_setAssociatedObject(self, &kUIViewTapActionKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC);

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTapAction)];
    [self addGestureRecognizer:tap];
}

- (void)_handleTapAction {
    void (^handler)(void) = objc_getAssociatedObject(self, &kUIViewTapActionKey);
    if (handler) {
        handler();
    }
}

@end


@interface PPQuickActionsView ()
@property (nonatomic, strong) UIStackView *stack;
@end

@implementation PPQuickActionsView

+ (void)presentCustomMenuWithCategories:(NSArray<MainKindsModel *> *)categories
                                   font:(UIFont *)font
                              tintColor:(UIColor *)tintColor
                               fromView:(UIView *)sourceView
                                handler:(void(^)(MainKindsModel *category))actionHandler
{
    CustomMenuView *menuView = [[CustomMenuView alloc] init];
    menuView.mainKindsArray = categories;
    menuView.customFont = font;
    menuView.tintColor = tintColor;
    menuView.selectionHandler = actionHandler;
    
    [menuView showFromView:sourceView];
}



+ (UIViewController *)topViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}



- (instancetype)initWithFrame:(CGRect)frame Spacing:(float)spacing{
    if (self = [super initWithFrame:frame]) {
        _buttonHeight = frame.size.height;
        
        _cornerRadius = 16.0;
        _backgroundColorForButton = AppClearClr;
        _tintColorForIcon = AppPrimaryClr;
        
        // in -initWithFrame:
        self.stack = [UIStackView new];
        self.stack.axis = UILayoutConstraintAxisHorizontal;
        self.stack.alignment =UIStackViewAlignmentFill;
        // ⬇️ make arranged subviews equal width
        self.stack.distribution = UIStackViewDistributionFill;
        self.stack.spacing = spacing;
        
        self.stack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        //stack.distribution = UIStackViewDistributionFill;   // <— important
        
        [self addSubview:self.stack];
        self.stack.translatesAutoresizingMaskIntoConstraints = NO;
        
        [NSLayoutConstraint activateConstraints:@[
            [self.stack.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}


- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame Spacing:8];
}

- (void)setActions:(NSArray<PPQuickActionItem *> *)actions {
    // Clear old
    for (UIView *v in self.stack.arrangedSubviews) {
        [self.stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    
    // fixed widths
    
    // Add new
    for (PPQuickActionItem *a in actions) {
        [self.stack addArrangedSubview:[self buildButtonFor:a]];
        
    }
}

- (void)setActionsForCardViewr:(NSArray<PPQuickActionItem *> *)actions {
    // Clear old
    for (UIView *v in self.stack.arrangedSubviews) {
        [self.stack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    UIView *targer;
    for (PPQuickActionItem *a in actions) {
        UIView *v = [self buildButtonFor:a];
        
        if([a.subTitleKey isEqualToString:@"Required"])
        {
            targer = v;
        }
        
        [self.stack addArrangedSubview:v];
    }
    
    if(targer)  [targer.widthAnchor constraintEqualToConstant:100].active = YES;
}
- (UIView *)buildButtonFor:(PPQuickActionItem *)item {
    UIButton *btn;
    if (@available(iOS 26.0, *)) {
        // Create the button configuration for iOS 16 and above
        UIButtonConfiguration *cfg;

        UIFont *font = [GM boldFontWithSize:16];
        if(item.configFor == ConfigForCardCell)
        {
            cfg = [UIButtonConfiguration glassButtonConfiguration];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;

            font = [GM boldFontWithSize:14];
        }
        else if(item.configFor == ConfigForAppVC)
        {
            cfg = [UIButtonConfiguration glassButtonConfiguration];
            font = [GM boldFontWithSize:14];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        }
        else if(item.configFor == ConfigForAdsViewer)
        {
            cfg = [UIButtonConfiguration glassButtonConfiguration];
            font = [GM boldFontWithSize:14];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        }
        else if(item.configFor == ConfigForPetsAds)
        {
            cfg = [UIButtonConfiguration glassButtonConfiguration];
            font = [GM boldFontWithSize:14];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        }
        else if(item.configFor == ConfigForViewData)
        {
            cfg = [UIButtonConfiguration glassButtonConfiguration];
            font = [GM boldFontWithSize:14];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        }
        else
        {
            cfg = [UIButtonConfiguration tintedButtonConfiguration];
            font = [GM boldFontWithSize:16];
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        }
       
        // Create attributed string with custom font
        NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:kLang(item.titleKey)];
        [attributedTitle addAttribute:NSFontAttributeName
                                value:font
                                range:NSMakeRange(0, attributedTitle.length)];
        
        UIImage *img;
        if(item.iconName)
        {
            img = [UIImage systemImageNamed:item.iconName] ?: [UIImage imageNamed:item.iconName];
            img = [img imageWithTintColor:[AppPrimaryClr colorWithAlphaComponent:1.2] renderingMode:UIImageRenderingModeAlwaysTemplate];
        }
         
      
        if(item.configFor == ConfigForCardCell)
        {
            cfg.background.cornerRadius = 16;
             [attributedTitle addAttribute:NSForegroundColorAttributeName
                                     value:UIColor.secondaryLabelColor
                                    range:NSMakeRange(0, attributedTitle.length)];
            cfg.baseForegroundColor = UIColor.secondaryLabelColor ;
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;  // Center the title horizontally
         
            if(item.iconName)
            {
                cfg.imagePadding = 0;  // Space between image and title
                cfg.imagePlacement = NSDirectionalRectEdgeTop;  // Place the image on top
                cfg.image = [UIImage pp_symbolNamed:item.iconName pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClr,AppPrimaryClr] makeTemplate:YES] ;
            }
            font = [GM boldFontWithSize:16];
            NSDictionary *textAttributes = @{ NSFontAttributeName: font,  NSForegroundColorAttributeName: AppPrimaryTextClr };
            
            // Create attributed string
            NSAttributedString *countryText = [[NSAttributedString alloc] initWithString:kLang(item.subTitleKey) attributes:textAttributes];
            NSMutableAttributedString *attributedSubTitle = [[NSMutableAttributedString alloc] initWithAttributedString:countryText];

            // 🔑 Inner padding (LEFT / RIGHT)
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);

            // 🔑 Title ↔ Subtitle spacing
            cfg.titlePadding = 1;
            cfg.attributedSubtitle = attributedSubTitle;
            

            
        }
        else if(item.configFor == ConfigForAppVC)
        {
            cfg.background.cornerRadius = 18.0;
            //cfg.background.backgroundColor = AppPrimaryClr ;
            [attributedTitle addAttribute:NSForegroundColorAttributeName
                                    value:AppPrimaryTextClr
                                    range:NSMakeRange(0, attributedTitle.length)];
            cfg.baseForegroundColor = AppPrimaryClr ;
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentTrailing;  // Center the title horizontally
            
            if(item.iconName)
            {
                cfg.imagePlacement = NSDirectionalRectEdgeLeading;  // Place the image on top
                cfg.image = [UIImage pp_symbolNamed:item.iconName pointSize:18 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClr,AppPrimaryClr] makeTemplate:YES] ;
                cfg.imagePadding = 6;  // Space between image and title
            }

        }
        else if(item.configFor == ConfigForPetsAds)
        {
            //cfg = [UIButtonConfiguration glassButtonConfiguration];

            // ─────────────────────────────────────────────
            // Background
            // ─────────────────────────────────────────────
            cfg.background.cornerRadius = 22.0;
            cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
            // ─────────────────────────────────────────────
            // ICON (TOP)
            // ─────────────────────────────────────────────
            if (item.iconName) {

                cfg.imagePlacement = NSDirectionalRectEdgeTop;
                cfg.imagePadding = 6;

                cfg.image =
                [UIImage pp_symbolNamed:item.iconName
                              pointSize:18
                                 weight:UIImageSymbolWeightMedium
                                  scale:UIImageSymbolScaleMedium
                                palette:@[AppSecondaryTextClr]
                           makeTemplate:YES];
            }

            // ─────────────────────────────────────────────
            // TITLE (MIDDLE)
            // ─────────────────────────────────────────────
            NSMutableAttributedString *titleAttr =
            [[NSMutableAttributedString alloc] initWithString:kLang(item.titleKey)];

            UIFont *titleFont = [GM boldFontWithSize:15]; // your existing font
            UIColor *titleColor = UIColor.secondaryLabelColor;

            NSMutableParagraphStyle *titleStyle = [NSMutableParagraphStyle new];
            titleStyle.alignment = NSTextAlignmentCenter;
            titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;

            [titleAttr addAttributes:@{
                NSFontAttributeName : titleFont,
                NSForegroundColorAttributeName : titleColor,
                NSParagraphStyleAttributeName : titleStyle
            } range:NSMakeRange(0, titleAttr.length)];

            cfg.attributedTitle = titleAttr;

            // ─────────────────────────────────────────────
            // SUBTITLE (BOTTOM)
            // ─────────────────────────────────────────────
            NSMutableAttributedString *subTitleAttr =
            [[NSMutableAttributedString alloc] initWithString:kLang(item.subTitleKey)];
            UIFont *font = [GM boldFontWithSize:15];
            if([item.subTitleKey isEqualToString:@"Required"]) font = [GM boldFontWithSize:17];
            UIFont *subTitleFont = font;
            UIColor *subTitleColor = AppPrimaryClr;

            NSMutableParagraphStyle *subTitleStyle = [NSMutableParagraphStyle new];
            subTitleStyle.alignment = NSTextAlignmentCenter;
            subTitleStyle.lineBreakMode = NSLineBreakByTruncatingTail;

            [subTitleAttr addAttributes:@{
                NSFontAttributeName : subTitleFont,
                NSForegroundColorAttributeName : subTitleColor,
                NSParagraphStyleAttributeName : subTitleStyle
            } range:NSMakeRange(0, subTitleAttr.length)];

            cfg.attributedSubtitle = subTitleAttr;

            // ─────────────────────────────────────────────
            // FINAL CONFIG
            // ─────────────────────────────────────────────
            cfg.baseForegroundColor = AppSecondaryTextClr;
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(16, 12, 16, 12);
           

        }
        else if(item.configFor == ConfigForAdsViewer)
        {
            cfg.background.cornerRadius = 22.0;
            //cfg.background.backgroundColor = AppPrimaryClr ;
            [attributedTitle addAttribute:NSForegroundColorAttributeName
                                    value:AppPrimaryTextClr
                                    range:NSMakeRange(0, attributedTitle.length)];
            cfg.baseForegroundColor = AppPrimaryClr ;
            cfg.imagePadding = 6;  // Space between image and title
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;  // Center the title horizontally
            cfg.imagePlacement = NSDirectionalRectEdgeTop;  // Place the image on top
            cfg.image = [UIImage pp_symbolNamed:item.iconName pointSize:20 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr,AppPrimaryClrDarker] makeTemplate:YES] ;


        }
        
        else if(item.configFor == ConfigForViewData)
        {
            cfg.background.cornerRadius = 12.0;
            //cfg.background.backgroundColor = AppPrimaryClr ;
            [attributedTitle addAttribute:NSForegroundColorAttributeName
                                    value:AppPrimaryTextClr
                                    range:NSMakeRange(0, attributedTitle.length)];
            cfg.baseForegroundColor = AppPrimaryTextClr ;
            cfg.imagePadding = 6;  // Space between image and title
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;  // Center the title horizontally
            cfg.imagePlacement = NSDirectionalRectEdgeTop;  // Place the image on top
            cfg.image = [UIImage pp_symbolNamed:item.iconName pointSize:17 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleMedium palette:@[AppPrimaryTextClr,AppPrimaryTextClr] makeTemplate:YES] ;


        }
        
        else
        {
            cfg.background.backgroundColor = AppPrimaryClr ;
            cfg.baseForegroundColor = AppBackgroundClrLigter ?: [UIColor systemBlueColor];
            cfg.imagePadding = 4;  // Space between image and title
            cfg.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;  // Center the title horizontally
            cfg.imagePlacement = NSDirectionalRectEdgeLeading;  // Place the image on top
            [attributedTitle addAttribute:NSForegroundColorAttributeName
                                    value:AppBackgroundClrLigter
                                    range:NSMakeRange(0, attributedTitle.length)];
            cfg.background.cornerRadius = 22;
            cfg.image = [UIImage pp_symbolNamed:item.iconName pointSize:20 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr,AppPrimaryClrDarker] makeTemplate:YES] ;

        }
        
        cfg.attributedTitle = attributedTitle;  // Apply the attributed title to the configuration
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        
        // Apply other properties to the button if needed
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        
        btn.configurationUpdateHandler = ^(UIButton *btn) {
            btn.layer.shadowOpacity = 0.06;
            [btn pp_setShadowColor:UIColor.blackColor];
            btn.layer.shadowRadius = 8.0;
            btn.layer.shadowOffset = CGSizeMake(0, 2);
        };
        
        if(PPIOS26())
        {
            //btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
        }
        
        if(img)
        {
            CALayer *imageLayer = [CALayer layer];
            imageLayer.contents = (__bridge id)[UIImage imageNamed:@"blur123"].CGImage;
            imageLayer.frame = CGRectMake(0, 0, 100, 60);
            imageLayer.contentsGravity = kCAGravityCenter;
            imageLayer.masksToBounds = YES;
            imageLayer.cornerRadius = 25;
            //[btn.layer insertSublayer:imageLayer atIndex:0];
        }
        
    }
    else if (@available(iOS 15.0, *)) {
        // Create the button configuration for iOS 15–15.99
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8] ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = 20;
        
        // Set the title with specific attributes (including font)
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:kLang(item.titleKey)
                                                              attributes:@{
            NSFontAttributeName: [GM MidFontWithSize:16],  // Custom font
            NSForegroundColorAttributeName: AppSecondaryTextClr  // Text color
        }];
        
        // Set the image for the button
        UIImage *img = [UIImage systemImageNamed:item.iconName] ?: [UIImage imageNamed:item.iconName];
        cfg.image = img;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = 6;
        cfg.baseForegroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
        // Apply the button configuration to the button
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        [btn setTintColor:AppPrimaryClr];
    } else {
        // Fallback for iOS versions lower than 15
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.layer.cornerRadius = 30;
        btn.layer.masksToBounds = YES;
        btn.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        
        [btn.titleLabel setFont:[GM MidFontWithSize:16]];  // Apply font directly
        [btn setTitle:kLang(item.titleKey) forState:UIControlStateNormal];
        
        UIImage *img = [UIImage systemImageNamed:item.iconName] ?: [UIImage imageNamed:item.iconName];
        [btn setImage:img forState:UIControlStateNormal];
        
        UIImage *imgOnTap = [UIImage systemImageNamed:item.iconNameOnTap] ?: [UIImage imageNamed:item.iconNameOnTap];
        if (imgOnTap) {
            [btn setImage:imgOnTap forState:UIControlStateHighlighted];
        }
        btn.titleLabel.textColor = AppSecondaryTextClr;
        btn.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [btn setTitleColor:AppSecondaryTextClr forState:UIControlStateNormal];
        [btn setTintColor:AppPrimaryClr];
    }
    
    // Apply common properties to all button types
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    // [constraints addObject:[btn.heightAnchor constraintEqualToConstant:self.buttonHeight]];
    if (item.buttonWidth > 0) {
        [constraints addObject:[btn.widthAnchor constraintEqualToConstant:item.buttonWidth]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    if (PPIOS26()) {
        btn.layer.masksToBounds = NO;
        btn.layer.cornerRadius = 22;
    }

    if (item.handler) {
        [btn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            item.handler(btn);
        }] forControlEvents:UIControlEventTouchUpInside];
    }
    
    if (item.menu) {
        UIMenu *menu = item.menu;
        if (@available(iOS 16.0, *)) {
            menu.preferredElementSize = UIMenuElementSizeLarge;
        } else {
            // Fallback on earlier versions
        }
        btn.menu = menu;
        btn.showsMenuAsPrimaryAction = YES;  // Set to show menu on tap
    }
    
    return btn;
}


- (UIView *)PPActionViewWithIconFor:(PPQuickActionItem *)item {
    NSLog(@"🔹 [PPActionViewWithIcon] Creating view with icon:%@ | title:%@ | subtitle:%@ | enabled:%@",
          item.iconName ?: @"nil",
          item.titleKey ?: @"nil",
          item.subTitleKey ?: @"nil",
          item.enabled ? @"YES" : @"NO");

    // --- Container view ---
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = PPCorners - 5;
    container.clipsToBounds = YES;
    container.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.9];

    // --- Icon view ---
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleToFill;
    iconView.tintColor = AppPrimaryClr;
    [iconView pp_setShadowColor:AppShadowClr];
    iconView.layer.shadowOffset = CGSizeMake(0, 2);
    iconView.layer.shadowOpacity = 0.15;
    iconView.layer.shadowRadius = 6;

    UIImage *iconImage = nil;
    if (item.iconName.length > 0) {
        iconImage = [UIImage systemImageNamed:item.iconName];
        if (!iconImage) iconImage = [UIImage imageNamed:item.iconName];
    }
    iconView.image = iconImage;
    BOOL hasIcon = (iconImage != nil);

    // --- Title label ---
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = item.titleKey;
    titleLabel.font = [GM MidFontWithSize:14];
    titleLabel.textColor = AppSecondaryTextClr;
    titleLabel.textAlignment = GM.setAligment;
    BOOL hasTitle = (item.titleKey.length > 0);

    // --- Subtitle label ---
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = item.subTitleKey;
    subtitleLabel.font = [GM boldFontWithSize:16];
    subtitleLabel.textColor = AppPrimaryTextClr;
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    BOOL hasSubtitle = (item.subTitleKey.length > 0);

    // --- Add subviews ---
    if (hasIcon) [container addSubview:iconView];
    if (hasTitle) [container addSubview:titleLabel];
    if (hasSubtitle) [container addSubview:subtitleLabel];

    CGFloat iconSize = 22.0;
    CGFloat spacing = 8.0;

    // === Layout Cases ===
    if (hasIcon && hasTitle && hasSubtitle) {
        [NSLayoutConstraint activateConstraints:@[
            [iconView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:spacing],
            [iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:spacing],
            [iconView.widthAnchor constraintEqualToConstant:iconSize],
            [iconView.heightAnchor constraintEqualToConstant:iconSize],
            [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:spacing],
            [titleLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
            [subtitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:spacing],
            [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-spacing]
        ]];
    } else if (hasIcon && !hasTitle && hasSubtitle) {
        [NSLayoutConstraint activateConstraints:@[
            [iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:spacing],
            [iconView.widthAnchor constraintEqualToConstant:iconSize],
            [iconView.heightAnchor constraintEqualToConstant:iconSize],
            [subtitleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [subtitleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:spacing],
            [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-spacing]
        ]];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
    } else if (hasTitle && !hasIcon && !hasSubtitle) {
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [titleLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
        ]];
        titleLabel.textAlignment = NSTextAlignmentCenter;
    } else if (hasSubtitle && !hasIcon && !hasTitle) {
        [NSLayoutConstraint activateConstraints:@[
            [subtitleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [subtitleLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
        ]];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
    } else if (hasIcon && !hasTitle && !hasSubtitle) {
        [NSLayoutConstraint activateConstraints:@[
            [iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
            [iconView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:iconSize * 1.4],
            [iconView.heightAnchor constraintEqualToConstant:iconSize * 1.4]
        ]];
    }

    // --- Apply Disabled Behavior ---
    if (!item.enabled) {
        container.alpha = 0.7;
        iconView.tintColor = [UIColor systemGray3Color];
        titleLabel.textColor = [UIColor systemGray3Color];
        subtitleLabel.textColor = [UIColor systemGray3Color];
        container.userInteractionEnabled = NO;

        // Add a light gray overlay to indicate disabled state visually
        UIView *overlay = [[UIView alloc] init];
        overlay.translatesAutoresizingMaskIntoConstraints = NO;
        overlay.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
        [container addSubview:overlay];
        [NSLayoutConstraint activateConstraints:@[
            [overlay.topAnchor constraintEqualToAnchor:container.topAnchor],
            [overlay.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
            [overlay.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [overlay.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
        ]];
        NSLog(@"🚫 [PPActionViewWithIcon] Disabled view: %@", item.titleKey);
    } else {
        // --- Enable Tap Interaction ---
        __weak typeof(container) weakContainer = container;
        [container addTapAction:^{
            __strong typeof(weakContainer) strongContainer = weakContainer;
            NSLog(@"👆 Icon tapped: %@", item.titleKey);
            [self animatenTap:strongContainer];
            if (item.handler) item.handler(strongContainer);
        }];
    }

    NSLog(@"✅ [PPActionViewWithIcon] Created %@ (enabled=%@)", item.titleKey, item.enabled ? @"YES" : @"NO");
    return container;
}

- (void)animatenTap:(UIView *)view {
    AudioServicesPlaySystemSound(1519);
    [UIView animateWithDuration:0.1 animations:^{
        view.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
             
        }];
    }];
}
#pragma mark - Helpers
// In PPQuickActionsView.m

- (void)onIconTapped:(UITapGestureRecognizer *)gr {
    void (^handler)(void) = objc_getAssociatedObject(gr.view, @"pp_action_handler");
    if (handler) handler();
}


@end

#pragma mark - PPQuickActionItem

@implementation PPQuickActionItem

+ (instancetype)itemWithTitleKey:(NSString * _Nullable)titleKey iconName:(NSString * _Nullable)iconName iconNameOnTap:(NSString * _Nullable)iconNameOnTap width:(CGFloat)width  configFor:(ConfigFor)configFor menu:(UIMenu * _Nullable)menu handler:(PPActionHandler _Nullable)handler{
    return [PPQuickActionItem itemWithTitleKey:titleKey subTitleKey:nil iconName:iconName iconNameOnTap:iconNameOnTap width:width  configFor:configFor menu:menu  enabled:YES handler:handler];
}
+ (instancetype)itemWithTitleKey:(NSString * _Nullable)titleKey subTitleKey:(NSString * _Nullable)subTitleKey iconName:(NSString * _Nullable)iconName iconNameOnTap:(NSString * _Nullable)iconNameOnTap width:(CGFloat)width  configFor:(ConfigFor )configFor menu:(UIMenu * _Nullable)menu  enabled:(BOOL)enabled handler:(PPActionHandler _Nullable)handler {
    PPQuickActionItem *i = [PPQuickActionItem new];
    i.titleKey = titleKey ?: @"";
    i.subTitleKey = subTitleKey ?: @"";
    i.iconName = iconName ?: nil;
    i.iconNameOnTap = iconNameOnTap ?: nil;
    i.handler  = handler;
    i.buttonWidth  = width;
    i.menu  = menu;
    i.enabled  = enabled;
    i.configFor  = configFor;
    return i;
}




@end



/*
 -(UIView *)PPActionViewWithIconFor:(PPQuickActionItem *)item
 {
     NSLog(@"🔹 [PPActionViewWithIcon] Creating view with icon:%@ | title:%@ | subtitle:%@",
           item.iconName ?: @"nil", item.titleKey ?: @"nil", item.subTitleKey ?: @"nil");

     UIView *container = [[UIView alloc] init];
     container.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.9];
     container.layer.cornerRadius = PPCorners - 5;
     container.translatesAutoresizingMaskIntoConstraints = NO;

     // Icon
     UIImageView *iconView = [[UIImageView alloc] init];
     iconView.translatesAutoresizingMaskIntoConstraints = NO;
     iconView.contentMode = UIViewContentModeScaleToFill;
     iconView.tintColor = AppPrimaryClr;
     [iconView pp_setShadowColor:AppPrimaryClr];
     iconView.layer.shadowOffset = CGSizeMake(0, 2);
     iconView.layer.shadowOpacity = 0.35;
     iconView.layer.shadowRadius = 4;

     UIImage *iconImage = nil;
     if (item.iconName.length > 0) {
         iconImage = [UIImage systemImageNamed:item.iconName];
         if (!iconImage) iconImage = [UIImage imageNamed:item.iconName];
     }
     iconView.image = iconImage;
     BOOL hasIcon = (iconImage != nil);

     // Title
     UILabel *titleLabel = [[UILabel alloc] init];
     titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
     titleLabel.text = item.titleKey;
     titleLabel.font = [GM MidFontWithSize:14];
     titleLabel.textColor = AppSecondaryTextClr;
     titleLabel.textAlignment = GM.setAligment;
     BOOL hasTitle = (item.titleKey.length > 0);

     // Subtitle
     UILabel *subtitleLabel = [[UILabel alloc] init];
     subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
     subtitleLabel.text = item.subTitleKey;
     subtitleLabel.font = [GM boldFontWithSize:16];
     subtitleLabel.textColor = AppPrimaryTextClr;
     subtitleLabel.textAlignment = NSTextAlignmentCenter;
     BOOL hasSubtitle = (item.subTitleKey.length > 0);

     // Add subviews that exist
     if (hasIcon) [container addSubview:iconView];
     if (hasTitle) [container addSubview:titleLabel];
     if (hasSubtitle) {
         [subtitleLabel sizeToFit]; [container addSubview:subtitleLabel];
     }

     CGFloat iconSize = 22.0;
     CGFloat spacing = 8.0;

     // CASE 1: icon + title (+ optional subtitle)
     if (hasIcon && hasTitle && hasSubtitle) {
         NSMutableArray *constraints = [NSMutableArray array];
         [constraints addObjectsFromArray:@[
             [iconView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:spacing],
             [iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:spacing],
             [iconView.widthAnchor constraintEqualToConstant:iconSize],
             [iconView.heightAnchor constraintEqualToConstant:iconSize],
             [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:spacing],
             [titleLabel.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
             [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor  constant:0]
         ]];

         if (hasSubtitle) {
             [constraints addObjectsFromArray:@[
                 [subtitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                 [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:spacing],
                 [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
                 [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-spacing]
             ]];
         } else {
             [constraints addObject:[titleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]];
         }

         [NSLayoutConstraint activateConstraints:constraints];
         NSLog(@"🧩 [PPActionViewWithIcon] Layout: icon + title%@",
               hasSubtitle ? @" + subtitle" : @" (no subtitle)");
     }

     // CASE 2: icon only
     else if (hasIcon && !hasTitle  && !hasSubtitle) {
         [NSLayoutConstraint activateConstraints:@[
             [iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
             [iconView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
             [iconView.widthAnchor constraintEqualToConstant:iconSize * 1.4],
             [iconView.heightAnchor constraintEqualToConstant:iconSize * 1.4]
         ]];
         NSLog(@"🟢 [PPActionViewWithIcon] Layout: icon only (centered)");
     }

     // CASE 3: title only (+ optional subtitle)
     else if (!hasIcon && hasTitle  && !hasSubtitle) {
         NSMutableArray *constraints = [NSMutableArray array];
         [constraints addObject:[titleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor]];
         [constraints addObject:[titleLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]];

         [NSLayoutConstraint activateConstraints:constraints];
         titleLabel.textAlignment = NSTextAlignmentCenter;
         subtitleLabel.textAlignment = NSTextAlignmentCenter;
         NSLog(@"🟡 [PPActionViewWithIcon] Layout: title%@ only", hasSubtitle ? @" + subtitle" : @"");
     }
     
     else if (!hasIcon && !hasTitle  && hasSubtitle) {
         NSMutableArray *constraints = [NSMutableArray array];
         if (hasSubtitle) {
             [constraints addObjectsFromArray:@[
                 [subtitleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
                 [subtitleLabel.topAnchor constraintEqualToAnchor:container.bottomAnchor constant:-4],
                 [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
             ]];
         } else {
             [constraints addObject:[titleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]];
         }

         [NSLayoutConstraint activateConstraints:constraints];
         titleLabel.textAlignment = NSTextAlignmentCenter;
         subtitleLabel.textAlignment = NSTextAlignmentCenter;
         NSLog(@"🟡 [PPActionViewWithIcon] Layout: title%@ only", hasSubtitle ? @" + subtitle" : @"");
     }

     else if (hasIcon && !hasTitle && hasSubtitle) {
         // 🟣 CASE: icon + subtitle only
         NSMutableArray *constraints = [NSMutableArray array];
         
         // Center the icon at top
         [constraints addObjectsFromArray:@[
             [iconView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
             [iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:spacing],
             [iconView.widthAnchor constraintEqualToConstant:iconSize],
             [iconView.heightAnchor constraintEqualToConstant:iconSize]
         ]];
         
         // Subtitle centered below icon
         [constraints addObjectsFromArray:@[
             [subtitleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
             [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-spacing]
         ]];
         
         [NSLayoutConstraint activateConstraints:constraints];
         
         subtitleLabel.textAlignment = NSTextAlignmentCenter;
         
         // Optional modern drop shadow on icon
         [iconView pp_setShadowColor:[UIColor blackColor]];
         iconView.layer.shadowOpacity = 0.25;
         iconView.layer.shadowOffset = CGSizeMake(0, 3);
         iconView.layer.shadowRadius = 6;

         NSLog(@"🟣 [PPActionViewWithIcon] Layout: icon + subtitle (centered vertically)");
     }
     // CASE 4: no icon, no title (edge case)
     else {
         NSLog(@"⚠️ [PPActionViewWithIcon] Warning: both icon and title are nil!");
     }

     NSLog(@"✅ [PPActionViewWithIcon] Created view successfully — hasIcon=%@, hasTitle=%@, hasSubtitle=%@",
           hasIcon ? @"YES" : @"NO", hasTitle ? @"YES" : @"NO", hasSubtitle ? @"YES" : @"NO");

     
     [PPFunc removeOldGradientsFromView:container];
     CGRect frame = CGRectMake(0, 0, 100, 100);
     CAGradientLayer *gradient = [UIView gradientLayerWithFadeForColor:AppPrimaryClr
                                                             direction:PPGradientDirectionTopToBottom
                                                                 frame:frame];
     gradient.cornerRadius = PPCorners;
     gradient.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
     __weak typeof(container) weakContainer = container;
     //[container.layer insertSublayer:gradient atIndex:0];
     [container addTapAction:^{
         __strong typeof(weakContainer) container = weakContainer;
         NSLog(@"👆 Icon view tapped!");
         [self animatenTap:container];
         if (item.handler) item.handler(container);
     }];
     return container;
 }
 
 
 - (UIButton *)createMenuButtonWithTitle:(NSString *)title menu:(UIMenu *)menu {
 UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
 
 // Configure button appearance
 button.titleLabel.font = [GM fontWithSize:20];
 [button setTitle:title forState:UIControlStateNormal];
 [button setTitleColor:UIColor.systemBlueColor forState:UIControlStateNormal];
 
 // Assign menu
 if (@available(iOS 14.0, *)) {
 button.menu = menu;
 button.showsMenuAsPrimaryAction = YES;
 }
 
 return button;
 }
 
 
 - (UIButton *)createStyledMenuButtoniOS_15_APIsMenu:(UIMenu *)mennu {
 UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
 config.title = @"Menu";
 config.baseForegroundColor = UIColor.systemBlueColor;
 
 // Create attributed string for custom font
 NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:@"Menu"];
 [attributedTitle addAttribute:NSFontAttributeName
 value:[UIFont systemFontOfSize:18 weight:UIFontWeightBold]
 range:NSMakeRange(0, attributedTitle.length)];
 
 config.attributedTitle = attributedTitle;
 
 UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
 
 // Create and assign menu
 button.menu = mennu;
 button.showsMenuAsPrimaryAction = YES;
 
 return button;
 }
 
 
 - (UIView *)buildButtonFor:(PPQuickActionItem *)item {
 UIButton *btn;
 
 
 
 //btn = [UIButton buttonWithType:UIButtonTypeCustom];
 if (@available(iOS 26.0, *)) {
 UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
 cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
 cfg.cornerStyle =  UIButtonConfigurationCornerStyleFixed;
 cfg.background.cornerRadius = 22;
 //cfg.background.backgroundColor = AppBackgroundClrLigter ?: [UIColor colorWithWhite:0.95 alpha:1.0];
 
 NSMutableAttributedString *attrTitle =
 [[NSMutableAttributedString alloc] initWithString:kLang(item.titleKey)
 attributes:@{
 NSFontAttributeName: [GM MidFontWithSize:16],
 NSForegroundColorAttributeName: AppSecondaryTextClr
 }];
 
 cfg.attributedTitle = [[NSAttributedString alloc] initWithAttributedString:attrTitle];
 
 
 UIImage *img = [UIImage systemImageNamed:item.iconName] ?: [UIImage imageNamed:item.iconName];
 // 👇 State-based image handling
 btn.configurationUpdateHandler = ^(UIButton *button) {
 if (button.isHighlighted || button.isSelected) {
 button.configuration.image = img; // tapped state
 } else {
 button.configuration.image = img;      // normal state
 }
 };
 
 btn = [UIButton new];
 btn.configuration = cfg;
 
 }
 else if (@available(iOS 15.0, *)) {
 UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
 cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
 cfg.cornerStyle =  UIButtonConfigurationCornerStyleFixed;
 // ✅ Set background color through configuration
 cfg.background.backgroundColor = AppForgroundColr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
 cfg.background.cornerRadius = 22;
 
 NSMutableAttributedString *attrTitle =
 [[NSMutableAttributedString alloc] initWithString:kLang(item.titleKey)
 attributes:@{
 NSFontAttributeName: [GM MidFontWithSize:16],
 NSForegroundColorAttributeName: AppSecondaryTextClr
 }];
 
 cfg.attributedTitle = [[NSAttributedString alloc] initWithAttributedString:attrTitle];
 
 
 UIImage *img = [UIImage systemImageNamed:item.iconName] ?: [UIImage imageNamed:item.iconName];
 // 👇 State-based image handling
 btn.configurationUpdateHandler = ^(UIButton *button) {
 if (button.isHighlighted || button.isSelected) {
 button.configuration.image = img; // tapped state
 } else {
 button.configuration.image = img;      // normal state
 }
 };
 
 
 btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
 }
 else
 {
 //btn.backgroundColor = AppPrimaryClr;
 btn.layer.cornerRadius = 22;
 btn.layer.masksToBounds = YES;
 btn.backgroundColor = AppForgroundColr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
 
 
 [btn.titleLabel setFont:[GM MidFontWithSize:16]];
 [btn setTitle:kLang(item.titleKey) forState:UIControlStateNormal];
 
 UIImage *img = [UIImage systemImageNamed:item.iconName] ?: [UIImage imageNamed:item.iconName];
 [btn setImage:img forState:UIControlStateNormal];
 
 UIImage *imgOnTap = [UIImage systemImageNamed:item.iconNameOnTap] ?: [UIImage imageNamed:item.iconNameOnTap];
 if(imgOnTap)
 [btn setImage:imgOnTap forState:UIControlStateFocused];
 }
 
 [NSLayoutConstraint activateConstraints:@[
 [btn.heightAnchor constraintEqualToConstant:self.buttonHeight]
 ]];
 
 // tap animation + handler
 //[PPButtonHelper attachTapAnimationToButton:btn style:PPButtonAnimationStyleDefault];
 if (item.handler) {
 [btn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
 item.handler();
 }] forControlEvents:UIControlEventTouchUpInside];
 }
 
 // (optional) also allow tapping the icon:
 if (item.handler) {
 UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onIconTapped:)];
 [btn addGestureRecognizer:tap];
 objc_setAssociatedObject(btn, @"pp_action_handler", item.handler, OBJC_ASSOCIATION_COPY_NONATOMIC);
 }
 
 return btn;
 }
 */
















@implementation PPActionButton

+ (UIMenu *)actionsArrayfor:(nullable UIViewController *)superVC
                 mainKinds:(NSArray<MainKindsModel *> *)mainKinds
                   handler:(void (^)(MainKindsModel *model))handler
{
    //__weak typeof(superVC) weakSelf = superVC;

    // =========================
    // Groups
    // =========================
    NSMutableArray *birdsGroup  = [NSMutableArray array];
    NSMutableArray *catsGroup   = [NSMutableArray array];
    NSMutableArray *horsesGroup = [NSMutableArray array];
    NSMutableArray *fishGroup   = [NSMutableArray array];

    UIImageSymbolConfiguration *symCfg =
    [UIImageSymbolConfiguration configurationWithPointSize:17
                                                    weight:UIImageSymbolWeightSemibold
                                                     scale:UIImageSymbolScaleMedium];

    // =========================
    // Build Actions
    // =========================
    for (MainKindsModel *kind in mainKinds) {

        if (kind.ID == 1010) continue; // excluded kind

        UIImage *icon = nil;
        if (kind.KindIconName.length) {
            icon = [UIImage imageNamed:kind.KindIconName];
        }
        if (!icon) {
            icon = [UIImage systemImageNamed:@"pawprint.fill"];
        }

        icon = [[icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                imageByApplyingSymbolConfiguration:symCfg];

        UIAction *action =
        [UIAction actionWithTitle:kind.KindName
                            image:icon
                       identifier:nil
                          handler:^(__kindof UIAction * _Nonnull act) {

            if (handler) handler(kind);
        }];

        // =========================
        // Grouping by ID
        // =========================
        if (kind.ID == 1 || kind.ID == 11) {
            [birdsGroup addObject:action];
        }
        else if (kind.ID == 5 || kind.ID == 6) {
            [catsGroup addObject:action];
        }
        else if (kind.ID == 2 || kind.ID == 3 || kind.ID == 10) {
            [horsesGroup addObject:action];
        }
        else if (kind.ID == 7) {
            [fishGroup addObject:action];
        }
    }

    // =========================
    // Submenus
    // =========================
    NSMutableArray *children = [NSMutableArray array];

    if (birdsGroup.count) {
        [children addObject:
         [UIMenu menuWithTitle:kLang(@"Birds")
                         image:nil
                    identifier:nil
                       options:UIMenuOptionsDisplayInline
                      children:birdsGroup]];
    }

    if (catsGroup.count) {
        [children addObject:
         [UIMenu menuWithTitle:kLang(@"KLang_CatsAndDogs")
                         image:nil
                    identifier:nil
                       options:UIMenuOptionsDisplayInline
                      children:catsGroup]];
    }

    if (fishGroup.count) {
        [children addObject:
         [UIMenu menuWithTitle:kLang(@"KLang_FishAndMarine")
                         image:nil
                    identifier:nil
                       options:UIMenuOptionsDisplayInline
                      children:fishGroup]];
    }

    if (horsesGroup.count) {
        [children addObject:
         [UIMenu menuWithTitle:kLang(@"KLang_HorsesAndCamels")
                         image:nil
                    identifier:nil
                       options:UIMenuOptionsDisplayInline
                      children:horsesGroup]];
    }

    // =========================
    // Root Menu (Palette)
    // =========================
    if (@available(iOS 17.0, *)) {

        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:UIMenuOptionsDisplayAsPalette
                            children:children];
    }
    else {

        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:UIMenuOptionsDisplayInline
                            children:children];
    }
}


+ (nonnull UIMenu *)generateActionsForMainKind:(nonnull NSArray<MainKindsModel *> *)mainKindsArray font:(nonnull UIFont *)font tintColor:(nonnull UIColor *)tintColor rowHeight:(CGFloat)rowHeight handler:(nonnull void (^)(MainKindsModel * _Nonnull __strong))actionHandler {
    return [self generateActionsForMainKind:mainKindsArray tintColor:tintColor handler:actionHandler];
}

+ (UIMenu *)generateActionsForMainKind:(NSArray<MainKindsModel *> *)mainKindsArray
                             tintColor:(UIColor *)tintColor
                               handler:(void (^)(MainKindsModel *category))actionHandler
{
    NSMutableArray<UIAction *> *birds   = [NSMutableArray array];
    NSMutableArray<UIAction *> *cats    = [NSMutableArray array];
    NSMutableArray<UIAction *> *horses  = [NSMutableArray array];
    NSMutableArray<UIAction *> *fish    = [NSMutableArray array];

    // =========================
    // Build actions
    // =========================
    for (MainKindsModel *category in mainKindsArray) {

        if (category.ID == 1010) continue;

        NSString *icon = nil;
        if (category.KindIconName.length) {
            icon = category.KindImageNamed;
        }
        if (!icon) {
            icon = @"pawprint.fill";
        }

       

        UIAction *action =
        [self actionWithTitle:category.KindName
              systemImageName:icon
                         font:[GM MidFontWithSize:15]
                        color:AppPrimaryTextClr
                      handler:^(__kindof UIAction * _Nonnull act) {
            if (actionHandler) actionHandler(category);
        }];

        // =========================
        // Grouping
        // =========================
        if (category.ID == 1 || category.ID == 11) {
            [birds addObject:action];
        }
        else if (category.ID == 5 || category.ID == 6) {
            [cats addObject:action];
        }
        else if (category.ID == 2 || category.ID == 3 || category.ID == 10) {
            [horses addObject:action];
        }
        else if (category.ID == 7) {
            [fish addObject:action];
        }
    }

    // =========================
    // Helper: inline vs nested
    // =========================
    UIMenu* (^menuForGroup)(NSString *, NSArray<UIAction *> *,int index) =
    ^UIMenu* (NSString *title, NSArray<UIAction *> *items,int index) {

        if (mainKindsArray.count == 0) return nil;

        // >5 → nested submenu
        if (mainKindsArray.count > 50 && index != 0) {
            return [UIMenu menuWithTitle:title
                                   image:nil
                              identifier:nil
                                 options:0
                                children:items];
        }

        // ≤5 → inline
        return [UIMenu menuWithTitle:title
                               image:nil
                          identifier:nil
                             options:UIMenuOptionsDisplayInline
                            children:items];
    };

    NSMutableArray<UIMenu *> *children = [NSMutableArray array];

    UIMenu *birdsMenu   = [UIMenu menuWithTitle:kLang(@"Birds") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:birds];
    UIMenu *catsMenu    =  [UIMenu menuWithTitle:kLang(@"KLang_CatsAndDogs") image:nil identifier:nil options:UIMenuOptionsDisplayInline children:cats];
    UIMenu *fishMenu    = menuForGroup(kLang(@"KLang_FishAndMarine"), fish,2);
    UIMenu *horsesMenu  = menuForGroup(kLang(@"KLang_HorsesAndCamels"), horses,3);

    if (birdsMenu)  [children addObject:birdsMenu];
    if (catsMenu)   [children addObject:catsMenu];
    if (horsesMenu) [children addObject:horsesMenu];
    if (fishMenu)   [children addObject:fishMenu];
    

    // =========================
    // Root menu
    // =========================
    return [UIMenu menuWithTitle:kLang(@"KLang_SelectPetCategory")
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:children];
}


// Helper function to determine the image for a PetCategory object
+ (UIImage *)imageForMainKind:(MainKindsModel *)mainKind
{
    UIImage *image = nil;
    
    // Check if the category has a valid imageName or image property
    if (mainKind.KindName && mainKind.KindName.length > 0) {
        image = [UIImage systemImageNamed:mainKind.KindName];
    } else if (mainKind.image) {
        image = mainKind.image;
    } else if (mainKind.KindImageUrl && mainKind.KindImageUrl.length > 0) {
        // Asynchronously load the image from the URL if the imageUrl exists
        // You can replace this block with actual network loading logic, e.g., using a library like SDWebImage
        NSURL *imageUrl = [NSURL URLWithString:mainKind.KindImageUrl];
        NSData *imageData = [NSData dataWithContentsOfURL:imageUrl];
        image = [UIImage imageWithData:imageData];
    }
    
    // Return a default icon if no image is available
    return image ?: [UIImage systemImageNamed:@"photo"]; // Placeholder icon
}



+ (UIAction *)actionWithTitle:(NSString *)title
              systemImageName:(nullable NSString *)systemImageName
                         font:(nullable UIFont *)font
                        color:(nullable UIColor *)color
                      handler:(void (^)(UIAction *action))handler
{
    UIImage *icon =  [UIImage imageNamed:systemImageName]?:  [UIImage systemImageNamed:systemImageName] ?: nil;
    
    UIAction *action = [UIAction actionWithTitle:title
                                           image:icon
                                      identifier:nil
                                         handler:^(__kindof UIAction * _Nonnull act) {
        if (handler) handler(act);
    }];
    
    // Apply attributed title
    UIFont *useFont = font ?: [GM MidFontWithSize:16];
    UIColor *useColor = color ?: UIColor.labelColor;
    
    NSDictionary *attributes = @{
        NSFontAttributeName: useFont,
        NSForegroundColorAttributeName: useColor
    };
    
    
    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:title attributes:attributes];
    // KVC hack removed

    return action;}

#pragma mark - Presets

+ (UIAction *)deleteActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"Delete")
                 systemImageName:@"trash"
                            font:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]
                           color:UIColor.systemRedColor
                         handler:handler];
}

+ (UIAction *)editActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"Edit")
                 systemImageName:@"pencil"
                            font:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium]
                           color:UIColor.labelColor
                         handler:handler];
}

+ (UIAction *)shareActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"Share")
                 systemImageName:@"square.and.arrow.up"
                            font:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium]
                           color:UIColor.labelColor
                         handler:handler];
}

+ (UIAction *)infoActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"Info")
                 systemImageName:@"info.circle"
                            font:[UIFont systemFontOfSize:15 weight:UIFontWeightRegular]
                           color:UIColor.secondaryLabelColor
                         handler:handler];
}


#pragma mark - Actions

+ (UIAction *)showProfileActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"showProfile")
                 systemImageName:@"person.circle.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)loginActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"go_to_login")
                 systemImageName:@"person.crop.circle.fill.badge.plus"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}



+ (UIAction *)showFavoritesActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"showfav")
                 systemImageName:@"star.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)showMyAdsActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"showMyAds")
                 systemImageName:@"megaphone.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)servicesManagerActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"myadsTitle")
                 systemImageName:@"circle.hexagonpath.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)showProtectionActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"showProdection")
                 systemImageName:@"doc.on.doc.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)orderHistoryActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"OrderHistory")
                 systemImageName:@"bag.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)cartActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"Cart")
                 systemImageName:@"cart.fill"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)settingsActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"Setting")
                 systemImageName:@"gear"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}

+ (UIAction *)supportActionWithHandler:(void (^)(UIAction *action))handler {
    return [self actionWithTitle:kLang(@"supprot")
                 systemImageName:@"person.crop.circle.badge.questionmark"
                            font:[GM MidFontWithSize:16]
                           color:AppSecondaryTextClr
                         handler:handler];
}


// =====================================================================================================================================




+ (NSArray *)menuArray
{
    
    FTPopOverMenuModel *archive = [[FTPopOverMenuModel alloc] init];
    archive.title = kLang(@"showProfile");
    archive.image = [UIImage systemImageNamed:@"person.circle.fill"];
    // No submenu for item1
    
    FTPopOverMenuModel *sale = [[FTPopOverMenuModel alloc] init];
    sale.title = kLang(@"showfav");
    sale.image = [UIImage systemImageNamed:@"star.fill"];
    // No submenu for item1
    
    
    FTPopOverMenuModel *editCard = [[FTPopOverMenuModel alloc] init];
    editCard.title = kLang(@"showMyAds");
    editCard.image = [UIImage systemImageNamed:@"megaphone.fill"];
    // No submenu for item1
    
    FTPopOverMenuModel *servicesManager = [[FTPopOverMenuModel alloc] init];
    servicesManager.title = kLang(@"servicesManager");
    servicesManager.image = [UIImage systemImageNamed:@"pawprint.fill"];
    
    
    FTPopOverMenuModel *deleteCard = [[FTPopOverMenuModel alloc] init];
    deleteCard.title = kLang(@"showProdection");
    deleteCard.image = [UIImage systemImageNamed:@"doc.on.doc.fill"];
    // No submenu for item1
    
    
    FTPopOverMenuModel *orders = [[FTPopOverMenuModel alloc] init];
    orders.title = kLang(@"OrderHistory");
    orders.image = [UIImage systemImageNamed:@"cart"];
    
    
    FTPopOverMenuModel *setting = [[FTPopOverMenuModel alloc] init];
    setting.title = kLang(@"Setting");
    setting.image = [UIImage systemImageNamed:@"gear"];
    
    
    FTPopOverMenuModel *support = [[FTPopOverMenuModel alloc] init];
    support.title = kLang(@"supprot");
    support.image = [UIImage systemImageNamed:@"person.crop.circle.badge.questionmark"];
    
    return @[archive,sale,editCard,servicesManager,deleteCard,orders,setting,support];
}

// 

+ (UIMenu *)appActionsArrayfor:(nullable UIViewController *)superVC
{
    __weak typeof(superVC) weakSuperVC = superVC;
    NSMutableArray<UIAction *> *actions = [NSMutableArray array];

    UserModel *currentUser = UserManager.sharedManager.currentUser;
    BOOL canShowProductionAction = [currentUser.prodectionStatus isEqualToString:@"active"];

    if (canShowProductionAction) {
        [actions addObject:[PPActionButton showProtectionActionWithHandler:^(UIAction *action) {
             MainController *vc =
            [MainController new];
            [weakSuperVC.navigationController pushViewController:vc animated:YES];
        }]];
    }

    [actions addObject:[PPActionButton settingsActionWithHandler:^(UIAction *action) {
         SettingVC *vc =
        (SettingVC *)[SettingVC new];
        [PPFunc presentSheetFrom:weakSuperVC sheetVC:vc detentStyle:PPSheetDetentStyle70];
    }]];

    [actions addObject:[PPActionButton supportActionWithHandler:^(UIAction *action) {
        CompanyLocationVC *vc = [CompanyLocationVC new];
        [weakSuperVC.navigationController pushViewController:vc animated:YES];
    }]];

    return [UIMenu menuWithTitle:@""
                            image:nil
                       identifier:nil
                          options:UIMenuOptionsDisplayInline
                         children:actions];
}

// suadi mare noha 745438

+ (UIMenu *)userActionsArrayfor:(nullable UIViewController *)superVC;
{
    
    __weak typeof(superVC) weakSuperVC = superVC;
    NSMutableArray<UIAction *> *UserActions = [NSMutableArray array];

    if (UserManager.sharedManager.currentUser) {
        [UserActions addObject:
         [PPActionButton showProfileActionWithHandler:^(UIAction *action) {
            ProfileVC *vc = [ProfileVC new];
            vc.view.layer.cornerRadius = 42;
            vc.view.backgroundColor = AppBackgroundClr;
            vc.view.clipsToBounds = YES;
            [weakSuperVC.navigationController pushViewController:vc animated:YES];
        }]];
    } else {
        [UserActions addObject:
         [PPActionButton loginActionWithHandler:^(UIAction *action) {
            [PPUserSigningManager presentSignInFrom:superVC
                                    withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                                  presentationStyle:PPSignInPresentationStyleSheet
                               autoDismissOnSuccess:YES
                                             success:^(UserModel *user) {
                [PPFunc reloadAppUI];
                [[AppDataListenerManager shared] stopAllListeners];
                [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
              
                
            } failure:nil cancelled:nil];
        }]];
    }

    [UserActions addObject:
     [PPActionButton showFavoritesActionWithHandler:^(UIAction *action) {
        if(![PPFunc PPUserCheck]) return;
        MyItemsViewController *vc =
        [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites];
        [weakSuperVC.navigationController pushViewController:vc animated:YES];
    }]];

    [UserActions addObject:
     [PPActionButton servicesManagerActionWithHandler:^(UIAction *action) {
        if(![PPFunc PPUserCheck]) return;
        MyItemsViewController *vc =
        [[MyItemsViewController alloc] initWithMode:MyItemsModeMyAds];
        [weakSuperVC.navigationController pushViewController:vc animated:YES];
    }]];

    // Cart & Orders in a separate inline group (renders a separator above)
    NSMutableArray<UIAction *> *commerceActions = [NSMutableArray array];

    [commerceActions addObject:
     [PPActionButton cartActionWithHandler:^(UIAction *action) {
        if(![PPFunc PPUserCheck]) return;
        CartViewController *vc = [CartViewController new];
        [weakSuperVC.navigationController pushViewController:vc animated:YES];
    }]];

    [commerceActions addObject:
     [PPActionButton orderHistoryActionWithHandler:^(UIAction *action) {
        if(![PPFunc PPUserCheck]) return;
        OrderHistoryViewController *vc = [OrderHistoryViewController new];
        [weakSuperVC.navigationController pushViewController:vc animated:YES];
    }]];

    UIMenu *profileGroup = [UIMenu menuWithTitle:@""
                                           image:nil
                                      identifier:nil
                                         options:UIMenuOptionsDisplayInline
                                        children:UserActions];

    UIMenu *commerceGroup = [UIMenu menuWithTitle:@""
                                            image:nil
                                       identifier:nil
                                          options:UIMenuOptionsDisplayInline
                                         children:commerceActions];

    return [UIMenu menuWithTitle:@""
                            image:nil
                       identifier:nil
                          options:UIMenuOptionsDisplayInline
                         children:@[profileGroup, commerceGroup]];
    
    
}
+ (UIMenu *)actionsArrayfor:(nullable UIViewController *)superVC
{
    __weak typeof(superVC) weakSelf = superVC;
    
    
    NSMutableArray *profileGroup = [NSMutableArray array];
    NSMutableArray *cartGroup = [NSMutableArray array];
    if (UserManager.sharedManager.currentUser) {
        [profileGroup addObject:[PPActionButton showProfileActionWithHandler:^(UIAction *action) {
        
            ProfileVC *vc = [[ProfileVC alloc] init];
            vc.view.layer.cornerRadius = 42;
            vc.view.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:1.0];
            vc.view.clipsToBounds = YES;
            [weakSelf.navigationController pushViewController:vc animated:YES];

            
        }]];
    } else {
        [profileGroup addObject:[PPActionButton loginActionWithHandler:^(UIAction *action) {
            // push LoginVC
             // Present with full customization
            [PPUserSigningManager presentSignInFrom:superVC
                                    withCountryCode:CitiesManager.shared.CurrentCountry.countryCode
                                  presentationStyle:PPSignInPresentationStyleSheet
                               autoDismissOnSuccess:YES
                                             success:^(UserModel *user) {
                
                [PPFunc reloadAppUI];
                [[AppDataListenerManager shared] stopAllListeners];
                [[AppDataListenerManager shared] startListenersForUser:PPCurrentUser.ID];
              
                
                // Custom handling
            } failure:^(NSError *error) {
                // Error handling
            } cancelled:^{
                // Cancellation handling
            }];
            
            
        }]];
    }
    
    [profileGroup addObject:[PPActionButton showFavoritesActionWithHandler:^(UIAction *action) {
        // Favorites
        if(![PPFunc PPUserCheck]) return; /* * User Check * */
        MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];
    
    [profileGroup addObject:[PPActionButton servicesManagerActionWithHandler:^(UIAction *action) {
        // Favorites
        if(![PPFunc PPUserCheck]) return; /* * User Check * */
        MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeMyAds];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];
    
   
    [PPActionButton servicesManagerActionWithHandler:^(UIAction *action) {
        
        if(![PPFunc PPUserCheck]) return; /* * User Check * */
        MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeMyAds];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }];
    
    [cartGroup addObject: [PPActionButton cartActionWithHandler:^(UIAction *action) {
        if(![PPFunc PPUserCheck]) return; /* * User Check * */
        CartViewController *vc = [[CartViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];
    
    [cartGroup addObject: [PPActionButton orderHistoryActionWithHandler:^(UIAction *action) {
        if(![PPFunc PPUserCheck]) return; /* * User Check * */
        OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
        [weakSelf.navigationController pushViewController:vc animated:YES];
    }]];
    
    NSMutableArray *servicesGroup = [NSMutableArray array];
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (currentUser && [currentUser.prodectionStatus isEqualToString:@"active"]) {
        [servicesGroup addObject:[PPActionButton showProtectionActionWithHandler:^(UIAction *action) {
            MainController *controller = [MainController new];
            [weakSelf.navigationController pushViewController:controller animated:YES];
        }]];
    }
    
    NSArray *settingsGroup = @[
        [PPActionButton settingsActionWithHandler:^(UIAction *action) {
            __strong typeof(weakSelf) vc = weakSelf;
            if (!vc) return;
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            SettingVC *VC =   [SettingVC new];
            //VC.delegate = vc;
            [PPFunc presentSheetFrom:vc sheetVC:VC detentStyle:PPSheetDetentStyle70];
        }],
        [PPActionButton supportActionWithHandler:^(UIAction *action) {
            CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }]
    ];
    
    UIMenu *menu;
    // Build menus (separators auto inserted)
    if (@available(iOS 17.0, *)) {
        menu  = [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayAsPalette
                 
                                    children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:profileGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:cartGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:servicesGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:settingsGroup]
        ]];
        
        
        // Attach to button
        /* self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Menu"
         style:UIBarButtonItemStylePlain
         target:nil
         action:nil];
         self.navigationItem.rightBarButtonItem.menu = menu; */
        
        
        return  menu;
    } else {
        // Fallback on earlier versions
        
        menu  = [UIMenu menuWithTitle:@""
                                       image:nil
                                  identifier:nil
                                     options:UIMenuOptionsDisplayInline
                                    children:@[
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:profileGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:cartGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:servicesGroup],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:settingsGroup]
        ]];
        
    }
    return  menu;
}


+ (nonnull NSString *)pp_convertArabicToEnglish:(nonnull NSString *)str
{
    if (str.length == 0) return @"";

    NSMutableString *result = [str mutableCopy];

    NSDictionary<NSString *, NSString *> *map = @{
        // Arabic digits
        @"٠": @"0", @"١": @"1", @"٢": @"2", @"٣": @"3", @"٤": @"4",
        @"٥": @"5", @"٦": @"6", @"٧": @"7", @"٨": @"8", @"٩": @"9",

        // Persian digits
        @"۰": @"0", @"۱": @"1", @"۲": @"2", @"۳": @"3", @"۴": @"4",
        @"۵": @"5", @"۶": @"6", @"۷": @"7", @"۸": @"8", @"۹": @"9"
    };

    [map enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [result replaceOccurrencesOfString:key
                                 withString:value
                                    options:0
                                      range:NSMakeRange(0, result.length)];
    }];

    return result;
}



@end




// =========================================  PaddedLabel   ===========================================//

@implementation PaddedLabel


- (void)setLineSpacing:(CGFloat)spacing {
    if (!self.text || self.text.length == 0) return;
    [self setLineSpacing:spacing text:self.text];
}

- (void)setLineSpacing:(CGFloat)spacing text:(NSString *)text {
    if (!text) return;

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = spacing;
    style.alignment = self.textAlignment;

    NSDictionary *attrs = @{
        NSFontAttributeName: self.font ?: [UIFont systemFontOfSize:17],
        NSForegroundColorAttributeName: self.textColor ?: UIColor.labelColor,
        NSParagraphStyleAttributeName: style
    };

    self.attributedText = [[NSAttributedString alloc] initWithString:text attributes:attrs];
}


- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.textInsets = UIEdgeInsetsMake(4, 8, 4, 8); // default padding
    }
    return self;
}

// Draw text with insets
- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.textInsets)];
}

// Adjust intrinsic size for Auto Layout
- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    size.width  += self.textInsets.left + self.textInsets.right;
    size.height += self.textInsets.top + self.textInsets.bottom;
    return size;
}

// Adjust sizeThatFits (if not using Auto Layout)
- (CGSize)sizeThatFits:(CGSize)size {
    CGSize adjusted = [super sizeThatFits:size];
    adjusted.width  += self.textInsets.left + self.textInsets.right;
    adjusted.height += self.textInsets.top + self.textInsets.bottom;
    return adjusted;
}


@end










@implementation PPButtonHelper
+ (UIButton *)buttonWithTitle:(NSString *)title
                    imageName:(nullable NSString *)imageName
                        style:(PPButtonTitleStyle)style
                       target:(nullable id)target
                       action:(nullable SEL)action
{
    UIButton *button = nil;

    UIImage *icon = nil;
    if (imageName.length > 0) {
        icon = [UIImage systemImageNamed:imageName] ?: [UIImage imageNamed:imageName];
    }

    // ============================
    // iOS 26+ (Glass Button)
    // ============================
    if (@available(iOS 26.0, *)) {

        UIButtonConfiguration *cfg =
            [UIButtonConfiguration glassButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);

        // Title
        if (title.length > 0) {
            cfg.attributedTitle =
                [[NSAttributedString alloc] initWithString:title
                                                attributes:@{
                    NSFontAttributeName: [GM MidFontWithSize:16],
                    NSForegroundColorAttributeName:
                        (style == PPButtonTitleStylePrimary
                         ? AppPrimaryTextClr
                         : AppPrimaryTextClr)
                }];
        }

        // Image
        if (icon) {
            UIImageSymbolConfiguration *symCfg =
                [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                weight:UIImageSymbolWeightMedium
                                                                 scale:UIImageSymbolScaleMedium];
            cfg.image = [icon imageByApplyingSymbolConfiguration:symCfg];
            cfg.imagePadding = 8;
        }

        // Style
        switch (style) {
            case PPButtonTitleStylePrimary:
            {
                // Image-first layout
                cfg.imagePlacement = NSDirectionalRectEdgeLeading; // or Trailing for RTL if needed
                cfg.imagePadding = 6;
                
                // Prefer image visually
                cfg.titleAlignment = UIButtonConfigurationTitleAlignmentAutomatic;
                cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 10, 6, 10);
                
                // Symbol configuration (THIS IS THE KEY PART)
                UIImageSymbolConfiguration *symbolCfg =
                [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                weight:UIImageSymbolWeightSemibold
                                                                 scale:UIImageSymbolScaleMedium];
                
                // Apply explicit tint via palette or hierarchical color
                symbolCfg =
                [symbolCfg configurationByApplyingConfiguration:
                 [UIImageSymbolConfiguration configurationWithPaletteColors:@[
                    AppPrimaryClr   // 👈 primary symbol tint
                 ]]];
                
                // Assign image with config
                cfg.image = [icon imageByApplyingSymbolConfiguration:symbolCfg];
                
                // Foreground color ONLY affects title now
                cfg.baseForegroundColor = AppPrimaryClr;
                
                
                cfg.baseBackgroundColor =UIColor.clearColor;;
                cfg.background.backgroundColor = UIColor.clearColor;;
                cfg.baseForegroundColor = UIColor.whiteColor;
                break;
            }
            case PPButtonTitleStyleSecondry:
                cfg.baseBackgroundColor =
                    [AppPrimaryClr colorWithAlphaComponent:0.12];
                cfg.background.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.12];
                cfg.baseForegroundColor = AppPrimaryClr;
                break;

            case PPButtonTitleStyleGhost:
            default:
                cfg.baseBackgroundColor = UIColor.clearColor;
                cfg.baseForegroundColor = AppPrimaryTextClr;
                cfg.background.backgroundColor = AppPrimaryTextClr;
                break;
        }

        button = [UIButton new];
        button.configuration = cfg;
    }

    // ============================
    // iOS 15–25 (Modern fallback)
    // ============================
    else if (@available(iOS 15.0, *)) {

        UIButtonConfiguration *cfg =
            [UIButtonConfiguration filledButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);

        if (title.length > 0) {
            cfg.attributedTitle =
                [[NSAttributedString alloc] initWithString:title
                                                attributes:@{
                    NSFontAttributeName: [GM MidFontWithSize:15]
                }];
        }

        if (icon) {
            UIImageSymbolConfiguration *symCfg =
                [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                weight:UIImageSymbolWeightMedium];
            cfg.image = [icon imageByApplyingSymbolConfiguration:symCfg];
            cfg.imagePadding = 8;
        }

        switch (style) {
            case PPButtonTitleStylePrimary:
                cfg.baseBackgroundColor = AppPrimaryClr;
                cfg.baseForegroundColor = UIColor.whiteColor;
                break;

            case PPButtonTitleStyleSecondry:
                cfg.baseBackgroundColor =
                    [AppPrimaryClr colorWithAlphaComponent:0.15];
                cfg.baseForegroundColor = AppPrimaryClr;
                break;

            case PPButtonTitleStyleGhost:
            default:
                cfg = [UIButtonConfiguration plainButtonConfiguration];
                cfg.baseForegroundColor = AppPrimaryTextClr;
                break;
        }

        button = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    }

    // ============================
    // Legacy (< iOS 15)
    // ============================
    else {

        button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.layer.cornerRadius = 22;
        button.clipsToBounds = YES;
        button.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);

        if (title.length > 0) {
            [button setTitle:title forState:UIControlStateNormal];
            button.titleLabel.font = [GM MidFontWithSize:15];
        }

        if (icon) {
            [button setImage:icon forState:UIControlStateNormal];
            button.tintColor = AppPrimaryTextClr;
        }

        switch (style) {
            case PPButtonTitleStylePrimary:
                button.backgroundColor = AppPrimaryClr;
                [button setTitleColor:UIColor.whiteColor
                             forState:UIControlStateNormal];
                break;

            case PPButtonTitleStyleSecondry:
                button.backgroundColor =
                    [AppPrimaryClr colorWithAlphaComponent:0.15];
                [button setTitleColor:AppPrimaryClr
                             forState:UIControlStateNormal];
                break;

            case PPButtonTitleStyleGhost:
            default:
                button.backgroundColor = UIColor.clearColor;
                [button setTitleColor:AppPrimaryTextClr
                             forState:UIControlStateNormal];
                break;
        }
    }

    // ============================
    // Target / Action
    // ============================
    if (target && action) {
        [button addTarget:target
                   action:action
         forControlEvents:UIControlEventTouchUpInside];
    }

    // ============================
    // Common polish
    // ============================
    button.translatesAutoresizingMaskIntoConstraints = NO;

    // Soft lift shadow (Pure Pets style)
    [button pp_setShadowColor:AppShadowClr];
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowOffset = CGSizeMake(0, 2);
    button.layer.shadowRadius = 6;
    button.layer.masksToBounds = NO;

    return button;
}
+ (UIButton *)pp_glassBackgroundButtonWithCornerRadius:(CGFloat)radius
                                           maskedEdges:(CACornerMask)masked
{
    UIButton *button;
    
    if (@available(iOS 26.0, *)) {
        
        // ✅ iOS 26 Glass Configuration
        UIButtonConfiguration *cfg =
        [UIButtonConfiguration glassButtonConfiguration];
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsZero;
        
        // لا عنوان ولا أيقونة (زر خلفية فقط)
        cfg.title = nil;
        cfg.image = nil;
        
        // زجاج ناعم
        cfg.background.backgroundColor =
        [[UIColor whiteColor] colorWithAlphaComponent:0.00];
        
        button = [UIButton buttonWithConfiguration:cfg
                                     primaryAction:nil];
        
        button.configuration = cfg;
        
        // Corner masking
        button.layer.cornerRadius = radius;
        
    } else {
        
        // 🔻 Fallback أقل من iOS 26
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor =
        [[UIColor whiteColor] colorWithAlphaComponent:0.18];
        
        button.layer.cornerRadius = radius;
        button.layer.maskedCorners = masked;
        [button pp_setShadowColor:[UIColor blackColor]];
        button.layer.shadowOpacity = 0.12;
        button.layer.shadowRadius = 10;
        button.layer.shadowOffset = CGSizeMake(0, 6);
    }
    
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.userInteractionEnabled = YES;
    
    return button;
}

+ (UIButton *)iconButtonTitle:(NSString *)title
                        Named:(NSString *)imageName
                         size:(CGFloat)btnSize
                         tint:(UIColor *)tint
              backgroundColor:(UIColor *)bg
                        style:(PPIconButtonStyle)style
                       target:(id)target
                       action:(nullable SEL)action
                accessibility:(NSString *)axLabel
{
    UIButton *btn = nil;
    UIColor *fallbackBG = bg ?: AppForgroundColr;
    tint = tint ?: UIColor.systemBlueColor;
    
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = nil;
        
        switch (style) {
            case PPIconButtonStyleTinted:  cfg = [UIButtonConfiguration tintedButtonConfiguration];  break;
            case PPIconButtonStyleFilled:  cfg = [UIButtonConfiguration filledButtonConfiguration];  break;
            case PPIconButtonStyleGray:    cfg = [UIButtonConfiguration grayButtonConfiguration];    break;
            case PPIconButtonStylePlain:   cfg = [UIButtonConfiguration plainButtonConfiguration];   break;
            case PPIconButtonStyleMine:    if (@available(iOS 26.0, *)) {
                cfg = [UIButtonConfiguration tintedButtonConfiguration];
            } else {
                cfg = [UIButtonConfiguration plainButtonConfiguration];
            }   break;
                
                
            case PPIconButtonStyleGlass:
            default: {
                // “Glass” look built on plain + blur visual effect
                if (@available(iOS 26.0, *)) {
                    cfg = [UIButtonConfiguration glassButtonConfiguration];
                } else {
                    cfg = [UIButtonConfiguration plainButtonConfiguration];
                }
                
                
            } break;
        }
        
        UIImage *icon = [UIImage systemImageNamed:imageName];
        if (!icon) { icon = [UIImage imageNamed:imageName];  }
        if (!icon) { icon = [UIImage new]; }
        
        // For Plain on light backgrounds, give a subtle bg
        if (style == PPIconButtonStylePlain || style == PPIconButtonStyleGlass) {
            cfg.background.backgroundColor = fallbackBG;
        }
        
        if (style == PPIconButtonStyleMine)
        {
            cfg.background.backgroundColor = AppPrimaryClr;
            //cfg.baseBackgroundColor = fallbackBG;
            if (title) {
                cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                      attributes:@{
                    NSFontAttributeName: [GM MidFontWithSize:16],
                    NSForegroundColorAttributeName: AppForgroundColr
                }];
                cfg.baseForegroundColor = AppForgroundColr;
            }
            cfg.image = icon;
        }else
        {
            if (title) {
                cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                      attributes:@{
                    NSFontAttributeName: [GM MidFontWithSize:16],
                    NSForegroundColorAttributeName: AppPrimaryTextClr
                }];
            }
            
            
            
            cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 18, 6, 18);
            cfg.background.cornerRadius = btnSize * 0.5;  // round
            cfg.baseForegroundColor = tint;
            cfg.image = icon;
        }
        
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        //if (style == PPIconButtonStyleMine) [btn setTitleColor:AppForgroundColr forState:UIControlStateNormal];
        
    } else {
        
        // < iOS 15 fallback
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.backgroundColor = fallbackBG;
        btn.layer.cornerRadius = btnSize * 0.5;
        btn.tintColor = tint;
        if(title) {
            [btn setTitle:title forState:UIControlStateNormal];
            [btn setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
        }
        [self pp_addPressAnimationToButton:btn];
    }
    
    
    if (@available(iOS 26.0, *)) {
        
    }else
    {
        // Image (SF Symbol → asset fallback)
        UIImage *icon = [UIImage systemImageNamed:imageName];
        if (!icon) { icon = [UIImage imageNamed:imageName];  }
        if (!icon) { icon = [UIImage new]; }
        
        [btn setImage:icon forState:UIControlStateNormal];
        
        // Use symbol configuration instead of bitmap resizing
        if (@available(iOS 15.0, *)) {
            UIImageSymbolConfiguration *symCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:20
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleMedium];
            [btn setPreferredSymbolConfiguration:symCfg forImageInState:UIControlStateNormal];
        }
    }
    
    
    if(btnSize > 0)
    {
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
        [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
    }
    
    
    // Subtle shadow for lift
    [btn pp_setShadowColor:[UIColor colorWithWhite:0 alpha:0.25]];
    btn.layer.shadowOpacity = 0.12;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO;
    
    // Target
    if (target && action) {
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    
    // Accessibility
    if (axLabel.length > 0) {
        btn.isAccessibilityElement = YES;
        btn.accessibilityLabel = axLabel;
        btn.accessibilityTraits |= UIAccessibilityTraitButton;
    }
    
    // Pointer hover (iPad / Catalyst)
    if (@available(iOS 13.4, *)) {
        UIPointerInteraction *ptr = [[UIPointerInteraction alloc] initWithDelegate:nil];
        [btn addInteraction:ptr];
    }
    
    // Tap haptic
    
    [btn addTarget:self action:@selector(pp_handleHaptic:) forControlEvents:UIControlEventTouchUpInside];
    
    
    return btn;
}
#pragma mark - Press animation (optional)

+ (void)pp_addPressAnimationToButton:(UIButton *)btn {
    [btn addTarget:self action:@selector(pp_down:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(pp_up:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
}

+ (void)pp_down:(UIButton *)btn {
    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        btn.transform = CGAffineTransformMakeScale(0.94, 0.94);
        btn.layer.shadowOpacity = 0.06; // subtle while pressed
    } completion:nil];
}

+ (void)pp_up:(UIButton *)btn {
    [UIView animateWithDuration:0.18 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.6 options:0 animations:^{
        btn.transform = CGAffineTransformIdentity;
        btn.layer.shadowOpacity = 0.12;
    } completion:nil];
}

+ (void)pp_handleHaptic:(id)sender {
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];
}


+ (UIButton *)createTintWithSystemName:(NSString *)systemName pointSize:(CGFloat)pointSize
{
    UIButton *button;
    
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *config;
        if (@available(iOS 26.0, *)) {
            config = [UIButtonConfiguration filledButtonConfiguration];
        } else {
            config = [UIButtonConfiguration plainButtonConfiguration];
        }
        
        // Assign SF Symbol
        UIImage *templ = [[UIImage systemImageNamed:systemName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        config.image = templ;
        
        // Force size/weight
        config.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleLarge];
        
        // Tint color for icon/text
        config.baseForegroundColor = AppForgroundColr;
        config.baseBackgroundColor =   AppPrimaryClr;
        button = [UIButton buttonWithConfiguration:config primaryAction:nil];
        
        
    } else {
        // Legacy < iOS 15
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *icon = [UIImage systemImageNamed:systemName];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = AppForgroundColr;
        button.backgroundColor = AppPrimaryClr;
    }
    
    return button;
}


+ (UIButton *)pp_buttonWithTitle:(nullable NSString *)title
                            font:(nullable UIFont *)font
                       imageName:(nullable NSString *)imageName
                          target:(id)target
                          config:(UIButtonConfiguration *)config
                          action:(SEL)action
{
    return [self pp_buttonWithTitle:title font:font textColor:UIColor.labelColor corners:22 imageName:imageName target:target config:config btnSize:44 action:action];
}


+ (UIButton *)pp_buttonWithTitleForBar:(nullable NSString *)title
                             imageName:(nullable NSString *)imageName
                                target:(id)target
                                action:(nullable SEL)action
{
    if (@available(iOS 26.0, *)) {
        return [self pp_buttonWithTitle:title font:[GM boldFontWithSize:14] textColor:[AppPrimaryClr colorWithAlphaComponent:1.1] corners:22 imageName:imageName target:target config:[UIButtonConfiguration glassButtonConfiguration] btnSize:0 action:action];
    } else {
        return [self pp_buttonWithTitle:title font:[GM boldFontWithSize:14] textColor:[AppPrimaryClr colorWithAlphaComponent:1.1] corners:22 imageName:imageName target:target config:[UIButtonConfiguration filledButtonConfiguration] btnSize:0 action:action];
    }
}



+ (UIButton *)pp_buttonForDataVCNavBar:(nullable NSString *)title
                             imageName:(nullable NSString *)imageName
                                target:(id)target
              dataViewNavBarButtonKind:(PPDataViewNavBarButtonKind)buttonKind
{
    if (@available(iOS 26.0, *)) {
        return [self pp_buttonWithTitle:title font:[GM boldFontWithSize:17] textColor:[AppPrimaryClr colorWithAlphaComponent:1.0] corners:22 imageName:imageName target:target config:[UIButtonConfiguration tintedButtonConfiguration] btnSize:0 action:nil];
    } else {
        return [self pp_buttonWithTitle:title font:[GM boldFontWithSize:14] textColor:[AppPrimaryClr colorWithAlphaComponent:1.0] corners:22 imageName:imageName target:target config:[UIButtonConfiguration filledButtonConfiguration] btnSize:0 action:nil];
    }
}

+ (UIButton *)pp_buttonWithTitle:(nullable NSString *)title
                            font:(nullable UIFont *)font
                       textColor:(nullable UIColor *)textColor
                         corners:(float)corners
                       imageName:(nullable NSString *)imageName
                          target:(id)target
                          config:(UIButtonConfiguration *)config
                         btnSize:(CGFloat)btnSize
                          action:(nullable SEL)action
{
    UIFont *resolvedFont = font ?: ([GM boldFontWithSize:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold]);
    UIColor *resolvedTextColor = textColor ?: (AppPrimaryClr ?: UIColor.labelColor);
    UIColor *brandColor = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *surfaceColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    BOOL hasTitle = [title isKindOfClass:NSString.class] && title.length > 0;
    NSString *trimmedImageName = [imageName isKindOfClass:NSString.class]
        ? [imageName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : @"";
    BOOL hasIcon = trimmedImageName.length > 0;

    UIImage *icon = nil;
    if (trimmedImageName.length > 0) {
        CGFloat iconPointSize = (btnSize > 0.0 && !hasTitle) ? 18.0 : 15.0;
        UIImageSymbolConfiguration *symbolConfig =
            [UIImageSymbolConfiguration configurationWithPointSize:iconPointSize
                                                            weight:UIImageSymbolWeightSemibold
                                                             scale:UIImageSymbolScaleMedium];
        icon = [UIImage systemImageNamed:trimmedImageName withConfiguration:symbolConfig];
        if (!icon) {
            icon = [UIImage imageNamed:trimmedImageName];
            if (icon) {
                icon = [UIImage pp_resizedImage:icon toPointSize:(btnSize > 0.0 && !hasTitle) ? 20.0 : 18.0];
            }
        }
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    CGFloat resolvedCornerRadius = corners > 0.0
        ? corners
        : ((btnSize > 0.0 ? btnSize : PPButtonHeightLG) * 0.5);
    CGFloat verticalInset = hasTitle ? 8.0 : 0.0;
    CGFloat horizontalInset = hasTitle ? 14.0 : 0.0;
    UIColor *resolvedSurface = btnSize == 0.0
        ? UIColor.clearColor
        : [surfaceColor colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.88];
    UIColor *strokeColor = [brandColor colorWithAlphaComponent:PPIOS26() ? 0.20 : 0.14];

    UIButton *btn = nil;
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = config ? [config copy] : [UIButtonConfiguration tintedButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(verticalInset, horizontalInset, verticalInset, horizontalInset);
        cfg.baseForegroundColor = resolvedTextColor;
        cfg.baseBackgroundColor = resolvedSurface;
        cfg.background.backgroundColor = resolvedSurface;
        cfg.background.cornerRadius = resolvedCornerRadius;
        cfg.background.strokeColor = strokeColor;
        cfg.background.strokeWidth = btnSize == 0.0 ? 0.0 : 0.8;
        cfg.imagePadding = hasTitle && hasIcon ? 7.0 : 0.0;
        cfg.titlePadding = hasTitle && hasIcon ? 4.0 : 0.0;
        cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;
        cfg.imagePlacement = Language.isRTL ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading;

        if (hasTitle) {
            cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                                  attributes:@{
                NSFontAttributeName: resolvedFont,
                NSForegroundColorAttributeName: resolvedTextColor
            }];
        }

        if (icon) {
            cfg.image = icon;
            cfg.preferredSymbolConfigurationForImage =
                [UIImageSymbolConfiguration configurationWithPointSize:(btnSize > 0.0 && !hasTitle) ? 18.0 : 15.0
                                                                weight:UIImageSymbolWeightSemibold
                                                                 scale:UIImageSymbolScaleMedium];
        }

        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.backgroundColor = resolvedSurface;
        [btn setTitle:hasTitle ? title : nil forState:UIControlStateNormal];
        [btn setTitleColor:resolvedTextColor forState:UIControlStateNormal];
        btn.titleLabel.font = resolvedFont;
        btn.tintColor = resolvedTextColor;
        if (icon) {
            [btn setImage:icon forState:UIControlStateNormal];
        }
        if (hasTitle && hasIcon) {
            btn.contentEdgeInsets = UIEdgeInsetsMake(verticalInset, horizontalInset, verticalInset, horizontalInset);
            CGFloat imageInset = Language.isRTL ? 6.0 : -6.0;
            btn.imageEdgeInsets = UIEdgeInsetsMake(0.0, imageInset, 0.0, -imageInset);
        }
    }

    btn.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    btn.tintColor = resolvedTextColor;
    btn.adjustsImageWhenHighlighted = NO;
    btn.clipsToBounds = YES;
    btn.layer.cornerRadius = resolvedCornerRadius;
    btn.layer.borderWidth = btnSize == 0.0 ? 0.0 : 0.8;
    [btn pp_setBorderColor:strokeColor];
    if (@available(iOS 13.0, *)) {
        btn.layer.cornerCurve = kCACornerCurveContinuous;
    }

    if (btnSize > 0) {
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
        if (!hasTitle) {
            [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
        } else {
            CGFloat minimumWidth = btnSize * (hasIcon ? 2.25 : 1.85);
            [btn.widthAnchor constraintGreaterThanOrEqualToConstant:minimumWidth].active = YES;
        }
    }

    btn.layer.masksToBounds = YES;

    if (target && action) {
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }
    
    return btn;
}


+ (UIButton *)pp_buttonSectionsTitle:(nullable NSString *)title
{
    UIButton *btn;
    UIImage *icon = [UIImage pp_symbolNamed:@"chevron.down" pointSize:15 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleMedium palette:@[AppPrimaryClr ] makeTemplate:YES];
    
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
    }
    
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                             attributes:@{
        NSFontAttributeName: [GM boldFontWithSize:17],
        NSForegroundColorAttributeName: AppPrimaryClr
    }];
    
    
    btn = [[UIButton alloc]init];
    btn.configuration = config;
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 10, 6, 10);
    btn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.04];
    btn.layer.cornerRadius = 18;
    btn.clipsToBounds = YES;
    
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:AppPrimaryClr forState:UIControlStateNormal];
    btn.titleLabel.font = [GM boldFontWithSize:18];
    [btn.titleLabel setFont:[GM boldFontWithSize:18]];
    [btn setImage:icon forState:UIControlStateNormal];
    btn.tintColor = AppPrimaryClr;
    
    
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    // --- Shadows ---
    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.12;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO;
    
    // 🔁 Force icon to be trailing in both LTR & RTL
    btn.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    
    
    
    // --- Shadows (modern, soft lift) ---
    btn.layer.masksToBounds = NO;
    
    
    // Performance + shape correctness
    btn.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:btn.bounds
                               cornerRadius:btn.layer.cornerRadius].CGPath;
    // Spacing between title and icon
    //  btn.imageEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
    //  btn.titleEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
    
    return btn;
}

+ (void)pp_setButton:(UIButton *)button title:(NSString *)title {
    [self pp_setButton:button title:title color:AppPrimaryTextClr];
}
+ (void)pp_setButton:(UIButton *)button title:(NSString *)title color:(UIColor *)color {
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = button.configuration ;
        //cfg.title = title;
        cfg.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
            NSFontAttributeName: [GM boldFontWithSize:17] ,
            NSForegroundColorAttributeName: color ,
        }];
        cfg.baseForegroundColor = color;
        button.configuration = cfg;
    
    } else {
        [button setTitle:title forState:UIControlStateNormal];
        [button.titleLabel setFont:[GM MidFontWithSize:16]];
    }
}
/*
 // Icon only
 UIButton *searchBtn = [PPButtonHelper pp_buttonWithTitle:nil
 imageName:@"magnifyingglass"
 target:self
 action:@selector(searchTapped:)];
 
 // Title only
 UIButton *cancelBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"Cancel")
 imageName:nil
 target:self
 action:@selector(cancelTapped:)];
 
 // Icon + Title
 UIButton *profileBtn = [PPButtonHelper pp_buttonWithTitle:kLang(@"Profile")
 imageName:@"person.crop.circle"
 target:self
 action:@selector(profileTapped:)];
 */
+ (UIButton *)createButtonWithSystemName:(NSString *)systemName  pointSize:(CGFloat)pointSize{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage symbolicImageNamed:systemName weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium pointSize:pointSize] forState:UIControlStateNormal];
    //[button setImage:[UIImage pp_symbolNamed:systemName pointSize:pointSize weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleUnspecified palette:@[UIColor.blackColor,UIColor.darkGrayColor] makeTemplate:YES] forState:UIControlStateNormal];
    button.tintColor = AppPrimaryTextClr;
    return button;
}

+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                            target:(id)target
                            action:(SEL)action
{
    return [self buttonWithSystemName:imageName buttonSide:0 target:target action:action];
}



+ (UIButton *)buttonWithSystemName:(NSString *)imageName
                        buttonSide:(float)side
                            target:(id)target
                            action:(SEL)action
{
    NSParameterAssert(imageName.length > 0);

    UIButton *btn = nil;
    CGFloat size = side > 0 ? side : 44.0;

    if (@available(iOS 26.0, *)) {
        // ✅ iOS 26 Glass Button
        UIButtonConfiguration *cfg =
            [UIButtonConfiguration glassButtonConfiguration];

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;

        UIImageSymbolConfiguration *symCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:18
                                                            weight:UIImageSymbolWeightMedium
                                                             scale:UIImageSymbolScaleMedium];

        cfg.image = [[UIImage systemImageNamed:imageName]
                     imageByApplyingSymbolConfiguration:symCfg];

        cfg.baseForegroundColor = AppPrimaryTextClr;

        btn = [UIButton new];
        btn.configuration = cfg;
    }
    else if (@available(iOS 15.0, *)) {
        // ✅ iOS 15–25 modern config
        UIButtonConfiguration *cfg =
            [UIButtonConfiguration plainButtonConfiguration];

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.background.backgroundColor =
            [[UIColor labelColor] colorWithAlphaComponent:0.08];
        cfg.background.cornerRadius = size * 0.5;

        UIImageSymbolConfiguration *symCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:18
                                                            weight:UIImageSymbolWeightMedium];

        cfg.image = [[UIImage systemImageNamed:imageName]
                     imageByApplyingSymbolConfiguration:symCfg];
        cfg.baseForegroundColor = AppPrimaryTextClr;

        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    }
    else {
        // ✅ Legacy fallback
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *img = [UIImage systemImageNamed:imageName];
        [btn setImage:img forState:UIControlStateNormal];
        btn.tintColor = AppPrimaryTextClr;
        btn.backgroundColor =
            [[UIColor labelColor] colorWithAlphaComponent:0.08];
        btn.layer.cornerRadius = size * 0.5;
    }

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn.widthAnchor constraintEqualToConstant:size].active = YES;
    [btn.heightAnchor constraintEqualToConstant:size].active = YES;

    // Subtle lift (matches your style)
    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.12;
    btn.layer.shadowRadius = 6;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.masksToBounds = NO;

    if (target && action) {
        [btn addTarget:target
                action:action
      forControlEvents:UIControlEventTouchUpInside];
    }

    return btn;
}

+ (UIButton *)createButtonWithSystemName:(NSString *)systemName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:systemName] forState:UIControlStateNormal];
    button.tintColor = UIColor.darkGrayColor;
    return button;
}
+ (void)onBack {
    
}

+ (UIButton *)pp_NavBarButtonWithSystemName:(NSString *)imageName action:(SEL)action controller:(UIViewController *)controller{
    UIButton *btn;
    CGFloat btnSize = 40;
    
    if (@available(iOS 26.0, *)) {
        // ✅ Use glass button on iOS 17+
        btnSize = 44;
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        cfg.baseBackgroundColor = UIColor.systemMintColor;
        cfg.baseForegroundColor = UIColor.whiteColor;
        btn = [UIButton new];
        btn.configuration = cfg;
        [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    }
    else if (@available(iOS 15.0, *)) {
        // ✅ iOS 15–16: plain button with background config
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        cfg.background.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = 20;
        
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    } else {
        // ✅ iOS < 15 fallback
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = 20;
        [btn setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    }
    
    // Try SF Symbol → fallback to asset
    UIImage *icon = [UIImage systemImageNamed:imageName];
    if (!icon) {
        icon = [UIImage imageNamed:imageName];
        icon = [UIImage pp_resizedImage:icon toPointSize:18];
    }
    
    if (!icon) {
        DLog(@"[pp_circleButton] ⚠️ No image found for name: %@", imageName);
        icon = [UIImage new];
    }
    
    if ([imageName isEqualToString:@"headset"]) {
        icon = [[UIImage pp_resizedImage:icon toPointSize:18] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    
    [btn setImage:icon forState:UIControlStateNormal];
    
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tintColor = AppPrimaryClr ?: [UIColor systemBlueColor];
    
    // Apply size constraints
    [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
    [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;
    
    // Shadows (glass or not)
    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.10;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO;
    
    // Apply symbol config if SF Symbol
    if ([UIImage systemImageNamed:imageName]) {
        UIImageSymbolConfiguration *config =
        [UIImageSymbolConfiguration configurationWithPointSize:20
                                                        weight:UIImageSymbolWeightRegular
                                                         scale:UIImageSymbolScaleMedium];
        [btn setImage:[icon imageByApplyingSymbolConfiguration:config] forState:UIControlStateNormal];
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else {
        btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    [btn addTarget:controller action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}


// Refactored: buttonWithIcon:title: (no target/action)
+ (UIButton *)buttonWithIcon:(NSString *)systemImageName title:(nullable NSString *)title
{
    UIButton *btn;
    CGFloat btnSize = 40;

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        if (systemImageName.length > 0) {
            UIImage *icon = [UIImage systemImageNamed:systemImageName];
            if (!icon) {
                icon = [UIImage imageNamed:systemImageName];
                if (icon) icon = [UIImage pp_resizedImage:icon toPointSize:18];
            }
            cfg.image = icon;
        }
        if (title.length > 0) {
            cfg.title = title;
        }
        btn = [UIButton new];
        btn.configuration = cfg;
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        cfg.background.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = 20;
        if (systemImageName.length > 0) {
            UIImage *icon = [UIImage systemImageNamed:systemImageName];
            if (!icon) {
                icon = [UIImage imageNamed:systemImageName];
                if (icon) icon = [UIImage pp_resizedImage:icon toPointSize:18];
            }
            cfg.image = icon;
        }
        if (title.length > 0) {
            cfg.title = title;
        }
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = 20;
        if (systemImageName.length > 0) {
            UIImage *icon = [UIImage systemImageNamed:systemImageName];
            if (!icon) {
                icon = [UIImage imageNamed:systemImageName];
                if (icon) icon = [UIImage pp_resizedImage:icon toPointSize:18];
            }
            [btn setImage:icon forState:UIControlStateNormal];
        }
        if (title.length > 0) {
            [btn setTitle:title forState:UIControlStateNormal];
        }
    }

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tintColor = AppPrimaryClr ?: [UIColor systemBlueColor];

    [btn.widthAnchor constraintEqualToConstant:btnSize].active = YES;
    [btn.heightAnchor constraintEqualToConstant:btnSize].active = YES;

    [btn pp_setShadowColor:AppShadowClr];
    btn.layer.shadowOpacity = 0.16;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 8;
    btn.layer.masksToBounds = NO;

    btn.imageView.contentMode = UIViewContentModeScaleAspectFit;

    return btn;
}

+ (UIButton *)buttonWithImageNamed:(nullable NSString *)imageName
               selectedImageNamed:(nullable NSString *)selectedImageNamed
                             width:(float)width
                            height:(float)height
                              menu:(nullable UIMenu *)menu
                            target:(nullable id)target
                            action:(nullable SEL)action
{
    UIButton *btn = nil;

    CGFloat w = width  > 0 ? width  : 40.0;
    CGFloat h = height > 0 ? height : 40.0;

    // ----------------------------------------------------
    // Button creation (iOS-aware)
    // ----------------------------------------------------
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        btn = [UIButton new];
        btn.configuration = cfg;
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        cfg.background.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        cfg.background.cornerRadius = h * 0.5;
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    }
    else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.backgroundColor = AppBackgroundClr ?: [UIColor colorWithWhite:0.95 alpha:1.0];
        btn.layer.cornerRadius = h * 0.5;
    }

    // ----------------------------------------------------
    // Images (system → asset fallback)
    // ----------------------------------------------------
    UIImage *normalImage = nil;
    UIImage *selectedImage = nil;

    if (imageName.length) {
        normalImage = [UIImage systemImageNamed:imageName] ?: [UIImage imageNamed:imageName];
    }
    if (selectedImageNamed.length) {
        selectedImage = [UIImage systemImageNamed:selectedImageNamed] ?: [UIImage imageNamed:selectedImageNamed];
    }

    if(@available(iOS 15.0, *))
    {
        if (normalImage ) {
            UIImageSymbolConfiguration *symCfg =
            [UIImageSymbolConfiguration configurationWithPointSize:20
                                                            weight:UIImageSymbolWeightRegular
                                                             scale:UIImageSymbolScaleMedium];
            normalImage = [normalImage imageByApplyingSymbolConfiguration:symCfg];
            selectedImage = [selectedImage imageByApplyingSymbolConfiguration:symCfg];
        }
    }
    

    [btn setImage:normalImage forState:UIControlStateNormal];
    if (selectedImage) {
        [btn setImage:selectedImage forState:UIControlStateSelected];
    }

    btn.tintColor = AppPrimaryClr ?: UIColor.systemBlueColor;
    btn.imageView.contentMode = UIViewContentModeScaleAspectFit;

    // ----------------------------------------------------
    // Menu support (iOS 14+)
    // ----------------------------------------------------
    if (menu) {
        btn.menu = menu;
        btn.showsMenuAsPrimaryAction = (target == nil && action == nil);
    }

    // ----------------------------------------------------
    // Target / Action (optional)
    // ----------------------------------------------------
    if (target && action) {
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }

    // ----------------------------------------------------
    // Layout
    // ----------------------------------------------------
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    if(width > 0)
    {
        [btn.widthAnchor  constraintEqualToConstant:w].active = YES;
        [btn.heightAnchor constraintEqualToConstant:h].active = YES;
    }
    

    // ----------------------------------------------------
    // Shadow (Pure Pets style)
    // ----------------------------------------------------
    [btn pp_setShadowColor:(AppShadowClr ?: UIColor.blackColor)];
    btn.layer.shadowOpacity = 0.10;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO;

    // ----------------------------------------------------
    // Pointer + Haptic
    // ----------------------------------------------------
    if (@available(iOS 13.4, *)) {
        [btn addInteraction:[[UIPointerInteraction alloc] initWithDelegate:nil]];
    }

    [btn addTarget:self action:@selector(pp_handleHaptic:)
   forControlEvents:UIControlEventTouchUpInside];

    return btn;
}

 

@end
 
 








@implementation UIButton (PPStyle)

- (void)pp_setBgColor:(nullable UIColor *)bgColor
{
    UIColor *finalBG = bgColor ?: UIColor.clearColor;

    // iOS 15+ using UIButtonConfiguration
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.configuration;

        // If no configuration exists yet, create a plain one
        if (!config) {
            config = [UIButtonConfiguration plainButtonConfiguration];
        }

        // Apply background color safely
        config.background.backgroundColor = finalBG;

        // Preserve corner radius if already set on layer
        if (self.layer.cornerRadius > 0) {
            config.background.cornerRadius = self.layer.cornerRadius;
        }

        self.configuration = config;
        return;
    }

    // Fallback for < iOS 15
    self.backgroundColor = finalBG;
}
- (void)pp_setIconWithImageName:(nullable NSString *)imageName
               systemImageName:(nullable NSString *)systemImageName
                      tintColor:(UIColor *)tintColor
                       alignment:(PPIconAlignment)alignment
                       iconSize:(CGFloat)iconSize
                       animated:(BOOL)animated
{
    void (^applyBlock)(void) = ^{

        UIImage *image = nil;

        // =========================
        // Image resolution
        // =========================
        if (systemImageName.length > 0) {
            UIImageSymbolConfiguration *cfg =
            [UIImageSymbolConfiguration configurationWithPointSize:iconSize
                                                            weight:UIImageSymbolWeightMedium];

            image = [UIImage systemImageNamed:systemImageName
                         withConfiguration:cfg];
        }
        else if (imageName.length > 0) {
            image = [[UIImage imageNamed:imageName]
                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }

        // =========================
        // iOS 15+ UIButtonConfiguration
        // =========================
        if (@available(iOS 15.0, *)) {

            if (self.configuration) {

                UIButtonConfiguration *config = self.configuration;

                config.image = image;
                config.baseForegroundColor = tintColor;

                switch (alignment) {

                    case PPIconAlignmentLeading:
                        config.imagePlacement = NSDirectionalRectEdgeLeading;
                        break;

                    case PPIconAlignmentTrailing:
                        config.imagePlacement = NSDirectionalRectEdgeTrailing;
                        break;

                    case PPIconAlignmentTop:
                        config.imagePlacement = NSDirectionalRectEdgeTop;
                        break;

                    case PPIconAlignmentCenter:
                    default:
                        config.imagePlacement = NSDirectionalRectEdgeLeading;
                        break;
                }

                config.imagePadding = (alignment == PPIconAlignmentCenter) ? 0 : 6;

                self.configuration = config;
                return;
            }
        }

        // =========================
        // Legacy UIButton fallback
        // =========================
        [self setImage:image forState:UIControlStateNormal];
        self.tintColor = tintColor;

        switch (alignment) {

            case PPIconAlignmentCenter:
                self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
                self.contentVerticalAlignment   = UIControlContentVerticalAlignmentCenter;
                self.imageEdgeInsets = UIEdgeInsetsZero;
                break;

            case PPIconAlignmentLeading:
                self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
                self.imageEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
                break;

            case PPIconAlignmentTrailing:
                self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
                self.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
                break;

            case PPIconAlignmentTop:
                self.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
                self.imageEdgeInsets = UIEdgeInsetsMake(8, 0, 0, 0);
                break;
        }
    };

    if (animated) {
        [UIView transitionWithView:self
                          duration:0.20
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:applyBlock
                        completion:nil];
    } else {
        applyBlock();
    }
}


- (void)pp_setTitle:(NSString *)title
               font:(UIFont *)font
          textColor:(UIColor *)textColor
          animation:(BOOL)animated
{
    void (^applyBlock)(void) = ^{

        // =========================
        // iOS 15+ (UIButtonConfiguration)
        // =========================
        if (@available(iOS 15.0, *)) {

            if (self.configuration) {

                UIButtonConfiguration *config = self.configuration;

                // Title
                config.title = title;

                // Font
                if (font) {
                    NSMutableAttributedString *attrTitle =
                    [[NSMutableAttributedString alloc]
                     initWithString:title ?: @""];

                    [attrTitle addAttribute:NSFontAttributeName
                                      value:font
                                      range:NSMakeRange(0, attrTitle.length)];

                    config.attributedTitle = attrTitle;
                }

                // Color
                if (textColor) {
                    config.baseForegroundColor = textColor;
                }

                self.configuration = config;
                return;
            }
        }

        // =========================
        // Legacy UIButton fallback
        // =========================
        [self setTitle:title forState:UIControlStateNormal];

        if (font) {
            self.titleLabel.font = font;
        }

        if (textColor) {
            [self setTitleColor:textColor forState:UIControlStateNormal];
        }
    };

    if (animated) {
        [UIView transitionWithView:self
                          duration:0.20
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:applyBlock
                        completion:nil];
    } else {
        applyBlock();
    }
}


- (void)pp_setTitle:(NSString *)title
               font:(UIFont *)font
              color:(UIColor *)color {
    
    // If using configuration (iOS 15+)
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = self.configuration ?: [UIButtonConfiguration plainButtonConfiguration];

        NSAttributedString *attr =
        [[NSAttributedString alloc] initWithString:title
                                        attributes:@{
                                            NSFontAttributeName: font ?: [UIFont systemFontOfSize:16],
                                            NSForegroundColorAttributeName: color ?: UIColor.labelColor
                                        }];

        config.attributedTitle = attr;
        self.configuration = config;
    }
    // Fallback for older iOS (if you support them)
    else {
        [self setTitle:title forState:UIControlStateNormal];
        [self.titleLabel setFont:font];
        [self setTitleColor:color forState:UIControlStateNormal];
    }
}

@end









@implementation PPColorHelper

#pragma mark - Color Extraction

+ (NSArray<UIColor *> *)extractTwoMainColorsFromImage:(UIImage *)image
                                        lightenAmount:(CGFloat)amount {
    if (!image) {
        return @[[UIColor colorWithWhite:1 alpha:0.1],
                 [UIColor colorWithWhite:0.95 alpha:0.1]];
    }
    
    // … your existing color extraction logic here …
    // (shortened for brevity)
    
    return @[ [UIColor whiteColor], [UIColor lightGrayColor] ]; // fallback
}

+ (UIColor *)lightenColor:(UIColor *)color amount:(CGFloat)amount {
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        return [UIColor colorWithRed:MIN(r + amount, 1.0)
                               green:MIN(g + amount, 1.0)
                                blue:MIN(b + amount, 1.0)
                               alpha:a];
    }
    return color;
}

#pragma mark - Gradient setter (works with shadow)

+ (void)setBackgroundGradientOnView:(UIView *)view
                               from:(UIColor *)startColor
                                 to:(UIColor *)endColor
                              angle:(CGFloat)degrees {
    if (!view) return;
    
    // Remove existing gradient if any
    CAGradientLayer *oldLayer = nil;
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]] &&
            [layer.name isEqualToString:@"PPColorHelperGradient"]) {
            oldLayer = (CAGradientLayer *)layer;
            break;
        }
    }
    [oldLayer removeFromSuperlayer];
    
    // Create gradient
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.name = @"PPColorHelperGradient";
    gradient.frame = view.bounds;
    gradient.colors = @[(__bridge id)startColor.CGColor,
                        (__bridge id)endColor.CGColor];
    gradient.locations = @[@0.0, @1.0];
    
    // Angle math
    CGFloat theta = degrees * (CGFloat)M_PI / 180.0;
    CGPoint start = CGPointMake(0.5 - 0.5 * cos(theta),
                                0.5 - 0.5 * sin(theta));
    CGPoint end   = CGPointMake(0.5 + 0.5 * cos(theta),
                                0.5 + 0.5 * sin(theta));
    gradient.startPoint = start;
    gradient.endPoint   = end;
    
    // Insert gradient behind content
    [view.layer insertSublayer:gradient atIndex:0];
}

@end





#import <objc/runtime.h>

static const void *kPPTwoToneLayerKey = &kPPTwoToneLayerKey;
static const void *kPPTwoToneMaskKey  = &kPPTwoToneMaskKey;

@implementation UIView (PPTwoTone)

- (void)pp_applyTwoToneTopColor:(UIColor *)topColor
                    bottomColor:(UIColor *)bottomColor
                   cornerRadius:(CGFloat)cornerRadius
                    shadowColor:(UIColor *)shadowColor
                  shadowOpacity:(CGFloat)shadowOpacity
                   shadowRadius:(CGFloat)shadowRadius
                   shadowOffset:(CGSize)shadowOffset
{
    // 1) gradient layer (create once)
    CAGradientLayer *grad = objc_getAssociatedObject(self, kPPTwoToneLayerKey);
    if (!grad) {
        grad = [CAGradientLayer layer];
        grad.needsDisplayOnBoundsChange = YES; // hint
                                               // vertical
        grad.startPoint = CGPointMake(0.5, 0.0);
        grad.endPoint   = CGPointMake(0.5, 1.0);
        // insert at back
        [self.layer insertSublayer:grad atIndex:0];
        objc_setAssociatedObject(self, kPPTwoToneLayerKey, grad, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 2) colors with a hard split at 50%
    grad.colors = @[ (__bridge id)topColor.CGColor,
                     (__bridge id)topColor.CGColor,
                     (__bridge id)bottomColor.CGColor,
                     (__bridge id)bottomColor.CGColor ];
    grad.locations = @[@0.0, @0.5, @0.5, @1.0];
    
    // 3) rounded-corner mask (so the view itself keeps masksToBounds = NO for shadow)
    CAShapeLayer *mask = objc_getAssociatedObject(self, kPPTwoToneMaskKey);
    if (!mask) {
        mask = [CAShapeLayer layer];
        objc_setAssociatedObject(self, kPPTwoToneMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        grad.mask = mask;
    }
    
    // 4) place/paths now
    grad.frame = self.bounds;
    UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:cornerRadius];
    mask.path = rounded.CGPath;
    
    // 5) view shadow (not clipped)
    self.layer.masksToBounds = NO;
    [self pp_setShadowColor:shadowColor];
    self.layer.shadowOpacity = shadowOpacity;
    self.layer.shadowRadius  = shadowRadius;
    self.layer.shadowOffset  = shadowOffset;
    self.layer.shadowPath    = rounded.CGPath; // perf: rasterize exact shape
}

- (void)pp_updateTwoToneIfNeeded {
    CAGradientLayer *grad = objc_getAssociatedObject(self, kPPTwoToneLayerKey);
    CAShapeLayer *mask    = objc_getAssociatedObject(self, kPPTwoToneMaskKey);
    if (!grad || !mask) return;
    
    // try to read radius from current mask path; otherwise keep last
    // build a new rounded path matching current bounds
    CGFloat inferredRadius = 0;
    // If you store radius somewhere else, set it here. For now, infer a reasonable corner radius:
    if (@available(iOS 11.0, *)) {
        inferredRadius = self.layer.cornerRadius; // may be 0 if not set
    }
    grad.frame = self.bounds;
    UIBezierPath *rounded = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:inferredRadius];
    mask.path = rounded.CGPath;
    self.layer.shadowPath = rounded.CGPath;
}

@end





















@implementation LocationLabelUtils

#pragma mark - Basic Implementation

+ (void)updateLocationLabel:(UILabel *)label
                withCountry:(NSString *)country
                      isRTL:(BOOL)isRTL {
    
    [self updateLocationLabel:label
                  withCountry:country
                        isRTL:isRTL
                     pinImage:nil
                     fontSize:10
                    textColor:[UIColor secondaryLabelColor]
               verticalOffset:-2];
}

#pragma mark - Advanced Implementation

+ (void)updateLocationLabel:(UILabel *)label
                withCountry:(NSString *)country
                      isRTL:(BOOL)isRTL
                   pinImage:(UIImage * _Nullable)pinImage
                   fontSize:(CGFloat)fontSize
                  textColor:(UIColor *)textColor
             verticalOffset:(CGFloat)verticalOffset {
    
    // Validate input
    if (!label) {
        NSLog(@"❌ LocationLabelUtils: Label is nil");
        return;
    }
    
    // Use provided country or fallback
    NSString *countryName = country.length > 0 ? country : kLang(@"Unknown");
    
    // Get or create pin image
    UIImage *finalPinImage = pinImage ?: [self defaultPinImage];
    finalPinImage = [finalPinImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    // Create text attachment for pin
    NSTextAttachment *pinAttachment = [NSTextAttachment new];
    pinAttachment.image = finalPinImage;
    pinAttachment.bounds = CGRectMake(0, verticalOffset, fontSize, fontSize);
    
    // Text attributes
    UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightRegular];
    NSDictionary *textAttributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor
    };
    
    // Create attributed string
    NSAttributedString *countryText = [[NSAttributedString alloc] initWithString:countryName
                                                                      attributes:textAttributes];
    NSAttributedString *space = [[NSAttributedString alloc] initWithString:@" "];
    NSAttributedString *pinString = [NSAttributedString attributedStringWithAttachment:pinAttachment];
    
    NSMutableAttributedString *finalText = [[NSMutableAttributedString alloc] init];
    
    // RTL/LTR layout
    if (isRTL) {
        // RTL: Text first, then pin
        [finalText appendAttributedString:countryText];
        [finalText appendAttributedString:space];
        [finalText appendAttributedString:pinString];
    } else {
        // LTR: Pin first, then text
        [finalText appendAttributedString:pinString];
        [finalText appendAttributedString:space];
        [finalText appendAttributedString:countryText];
    }
    
    // Apply to label
    label.attributedText = finalText;
    label.semanticContentAttribute = isRTL ? UISemanticContentAttributeForceRightToLeft
    : UISemanticContentAttributeForceLeftToRight;
    
    // Debug log
    NSLog(@"📍 LocationLabelUtils: Set '%@' with %@ layout", countryName, isRTL ? @"RTL" : @"LTR");
}

#pragma mark - Helper Methods

+ (UIImage *)defaultPinImage {
    // Try custom image first
    UIImage *customPin = [UIImage imageNamed:@"pin"];
    if (customPin) {
        return customPin;
    }
    
    // Fallback to SF Symbol on iOS 13+
    if (@available(iOS 13.0, *)) {
        UIImage *systemPin = [UIImage systemImageNamed:@"mappin.circle.fill"];
        if (systemPin) {
            return systemPin;
        }
    }
    
    // Ultimate fallback
    return [UIImage new];
}

+ (NSString *)getCurrentUserCountry {
    if (![UserManager sharedManager].isUserLoggedIn) {
        return @"";
    }
    
    NSInteger countryID = [UserManager sharedManager].currentUser.CountryID;
    if (countryID <= 0) {
        return @"";
    }
    
    // Get country from your GM utility
    NSArray *countries = [GM getMiddleEastCountriesForLanguage:[Language currentLanguageCode]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.ID == %ld", countryID];
    CountryCodeModel *countryModel = [countries filteredArrayUsingPredicate:predicate].firstObject;
    
    return countryModel.country ?: @"";
}

#pragma mark - Convenience Methods

+ (void)updateLocationLabel:(UILabel *)label withCurrentUserCountryAndIsRTL:(BOOL)isRTL {
    NSString *country = [self getCurrentUserCountry];
    [self updateLocationLabel:label withCountry:country isRTL:isRTL];
}

+ (void)updateLocationLabelWithAutoRTL:(UILabel *)label country:(NSString *)country {
    BOOL isRTL = [Language isRTL];
    [self updateLocationLabel:label withCountry:country isRTL:isRTL];
}

+ (void)updateLocationLabelWithAutoRTL:(UILabel *)label {
    BOOL isRTL = [Language isRTL];
    NSString *country = [self getCurrentUserCountry];
    [self updateLocationLabel:label withCountry:country isRTL:isRTL];
}

@end





















@implementation PPButtonFactory


+ (nullable UIMenu *)menuWithItems:(NSArray<NSDictionary *> *)items
                    primaryHandler:(void (^ _Nullable)(void))primaryHandler
{
    if (!items.count) {
        //NSLog(@"⚠️ [PPMenuButtonFactory] No items provided — returning nil");
        return nil;
    }

    // 🔹 Available from iOS 15+
    if (@available(iOS 15.0, *)) {
        NSMutableArray<UIAction *> *actions = [NSMutableArray array];

        for (NSDictionary *dict in items) {
            NSString *title = dict[@"title"];
            NSString *iconName = dict[@"icon"];
            UIImage *icon = iconName.length ? [UIImage systemImageNamed:iconName] : nil;
            void (^handler)(void) = dict[@"handler"];

            UIAction *action = [UIAction actionWithTitle:title
                                                   image:icon
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull act) {
                NSLog(@"🔘 [PPMenu] Action tapped: %@", title);
                AudioServicesPlaySystemSound(1104); // Standard tap sound
                if (handler) handler();
            }];
            [actions addObject:action];
        }

        // 🧩 Optional: primary handler as first action (if provided)
        if (primaryHandler) {
            UIAction *main = [UIAction actionWithTitle:@"Main Action"
                                                 image:[UIImage systemImageNamed:@"bolt.circle"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull act) {
                NSLog(@"⚡ [PPMenu] Primary action fired");
                AudioServicesPlaySystemSound(1104);
                primaryHandler();
            }];
            [actions insertObject:main atIndex:0];
        }

        UIMenu *menu = [UIMenu menuWithTitle:@"" children:actions];
        //NSLog(@"✅ [PPMenuButtonFactory] Created menu with %lu actions", (unsigned long)actions.count);
        return menu;
    }

    // 🟥 Fallback (older iOS versions)
    //NSLog(@"⚠️ [PPMenuButtonFactory] UIMenu not supported on this iOS version");
    return nil;
}





 

+ (UIButton *)buttonWithTitle:(NSString *)title
                   systemName:(NSString *)systemName
                    assetName:(NSString *)assetName
                 imageOnRight:(BOOL)imageOnRight
                       height:(CGFloat)height
                        style:(PPButtonStyle)style
                      target:(id)target
                      action:(SEL)action
{
    NSParameterAssert(title.length > 0);

    UIImage *img = nil;
    if (systemName.length) img = [UIImage systemImageNamed:systemName];
    if (!img && assetName.length) img = [UIImage imageNamed:assetName];

    UIColor *bgFilled     = AppPrimaryClr ?: [UIColor systemBlueColor];
    UIColor *bgTonal      = (AppBackgroundClr ?: [UIColor secondarySystemBackgroundColor]);
    UIColor *fgOnFilled   = [UIColor whiteColor];
    UIColor *fgOnTonal    = (AppPrimaryTextClr ?: [UIColor labelColor]);
    UIColor *fgPlain      = (AppPrimaryClr ?: [UIColor systemBlueColor]);
    CGFloat  corner       = 20.0;

    UIButton *btn = nil;

    // -------- iOS 26 “glass” branch (keep to match your project) --------
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration tintedButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 14, 10, 14);
        cfg.background.cornerRadius = corner;
        cfg.imagePadding = 8;

        // map styles
        switch (style) {
            case PPButtonStyleFilled:
                cfg.baseBackgroundColor = bgFilled;
                cfg.baseForegroundColor = fgOnFilled;
                break;
            case PPButtonStyleTonal:
                cfg.baseBackgroundColor = bgTonal;
                cfg.baseForegroundColor = fgOnTonal;
                break;
            case PPButtonStylePlain:
            default:
                cfg.baseBackgroundColor = UIColor.clearColor;
                cfg.baseForegroundColor = fgPlain;
                break;
        }

        cfg.title = title;
        if (img) cfg.image = img;
        cfg.imagePlacement = imageOnRight ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading;

        btn = [UIButton new];
        btn.configuration = cfg;

        // font (config doesn’t carry custom fonts reliably—set on label)
        btn.titleLabel.font = [GM boldFontWithSize:16];

        // height
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [[btn.heightAnchor constraintEqualToConstant:MAX(36, height ?: 44)] setActive:YES];
    }

    // -------- iOS 15–25: modern configuration API --------
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg =
            (style == PPButtonStyleFilled) ? [UIButtonConfiguration filledButtonConfiguration] :
            (style == PPButtonStyleTonal)  ? [UIButtonConfiguration tintedButtonConfiguration] :
                                             [UIButtonConfiguration plainButtonConfiguration];

        cfg.contentInsets = NSDirectionalEdgeInsetsMake(10, 14, 10, 14);
        cfg.imagePadding  = 8;
        cfg.background.cornerRadius = corner;

        // colors
        if (style == PPButtonStyleFilled) {
            cfg.baseBackgroundColor = bgFilled;
            cfg.baseForegroundColor = fgOnFilled;
        } else if (style == PPButtonStyleTonal) {
            cfg.baseBackgroundColor = bgTonal;
            cfg.baseForegroundColor = fgOnTonal;
        } else {
            cfg.baseForegroundColor = fgPlain;
        }

        cfg.title = title;
        if (img) cfg.image = img;
        cfg.imagePlacement = imageOnRight ? NSDirectionalRectEdgeTrailing : NSDirectionalRectEdgeLeading;

        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
        btn.titleLabel.font = [GM boldFontWithSize:16];

        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [[btn.heightAnchor constraintEqualToConstant:MAX(36, height ?: 44)] setActive:YES];
    }

    // -------- < iOS 15: classic UIButton --------
    else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [GM boldFontWithSize:16];

        if (img) {
            [btn setImage:img forState:UIControlStateNormal];
            btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        }

        // paddings
        btn.contentEdgeInsets = UIEdgeInsetsMake(10, 14, 10, 14);

        // image left/right
        if (img) {
            CGFloat spacing = 8.0;
            if (imageOnRight) {
                // flip semantic for RTL-friendly swap
                btn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
                btn.contentEdgeInsets = UIEdgeInsetsMake(10, 14, 10, 14);
                btn.titleEdgeInsets   = UIEdgeInsetsMake(0, 8, 0, -8);
            } else {
                btn.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
                btn.titleEdgeInsets   = UIEdgeInsetsMake(0, 8, 0, 0);
            }
            // ensure spacing visually
            btn.contentEdgeInsets = UIEdgeInsetsMake(10, 14, 10, 14 + spacing);
        }

        // colors & background
        btn.layer.cornerRadius = corner;
        if (style == PPButtonStyleFilled) {
            btn.backgroundColor = bgFilled;
            [btn setTitleColor:fgOnFilled forState:UIControlStateNormal];
            btn.tintColor = fgOnFilled;
        } else if (style == PPButtonStyleTonal) {
            btn.backgroundColor = bgTonal;
            [btn setTitleColor:fgOnTonal forState:UIControlStateNormal];
            btn.tintColor = fgOnTonal;
        } else {
            btn.backgroundColor = UIColor.clearColor;
            [btn setTitleColor:fgPlain forState:UIControlStateNormal];
            btn.tintColor = fgPlain;
        }

        [[btn.heightAnchor constraintEqualToConstant:MAX(36, height ?: 44)] setActive:YES];
    }

    // tint for SF Symbols on all versions
         UIImageSymbolConfiguration *sym =
        [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        [btn setImage:[img imageByApplyingSymbolConfiguration:sym] forState:UIControlStateNormal];
 
    // shadow (subtle)
    [btn pp_setShadowColor:(AppShadowClr ?: [UIColor blackColor])];
    btn.layer.shadowOpacity = 0.12;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    btn.layer.shadowRadius = 6;
    btn.layer.masksToBounds = NO;

    // target
    if (target && action) {
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    }

    // nice tap feel
    [self pp_addPressAnimationToButton:btn];

    return btn;
}



- (UIButton *)makeButtonWithSymbol:(NSString *)systemName selector:(SEL)action {
    UIButtonConfiguration *cfg;
    if (@available(iOS 26.0, *)) {
        cfg = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.background.backgroundColor = [UIColor.systemGray4Color colorWithAlphaComponent:0.2];
    }
    cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);

    // 🔧 Apply symbol config properly
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [[UIImage systemImageNamed:systemName] imageByApplyingSymbolConfiguration:symbolConfig];
    cfg.image = icon;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.configuration = cfg;
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

+ (void)applyEnabled:(BOOL)enabled toButton:(UIButton *)button {
    button.enabled = enabled;
    CGFloat alpha = enabled ? 1.0 : 0.5;
    [UIView animateWithDuration:0.15 animations:^{
        button.alpha = alpha;
        button.layer.shadowOpacity = enabled ? 0.12 : 0.0;
    }];
}

#pragma mark - Press animation (same as earlier)
+ (void)pp_addPressAnimationToButton:(UIButton *)btn {
    [btn addTarget:self action:@selector(pp_down:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(pp_up:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
}
+ (void)pp_down:(UIButton *)btn {
    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        btn.transform = CGAffineTransformMakeScale(0.96, 0.96);
        btn.layer.shadowOpacity = 0.06;
    } completion:nil];
}
+ (void)pp_up:(UIButton *)btn {
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.6 options:0 animations:^{
        btn.transform = CGAffineTransformIdentity;
        btn.layer.shadowOpacity = 0.12;
    } completion:nil];
}


@end










































 
























@implementation PPQuantityButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSLog(@"[PPQuantityButton] ▶︎ Init with frame: %@", NSStringFromCGRect(frame));

        _quantity = 0;
        _animationStyle = PPQuantityAnimationStyleFade;
        _collapsingBehavior = PPCollapsingBehaviorCollapseOnOutsideTap;
        _isExpanded = NO;

        [self setupViews];
        [self collapseAnimated:NO]; // Start collapsed
    }
    return self;
}

- (void)setupViews {
    NSLog(@"[PPQuantityButton] ▶︎ Setting up views");
    
    
    UIImage *plusIcon = [UIImage pp_symbolNamed:@"plus"];
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.image = plusIcon;
        self.plusButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.plusButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.plusButton setBackgroundColor:[UIColor systemGrayColor]];
        [self.plusButton setImage:plusIcon forState:UIControlStateNormal];
        self.plusButton.layer.cornerRadius = 8;
        self.plusButton.clipsToBounds = YES;
    }
    [self.plusButton addTarget:self action:@selector(plusTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.plusButton];
    
    
    
    UIImage *minusIcon = [UIImage pp_symbolNamed:@"minus"];

    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        cfg.image = minusIcon;
        cfg.imagePlacement =  NSDirectionalRectEdgeAll;
        self.minusOrTrashButton = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        self.minusOrTrashButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.minusOrTrashButton setBackgroundColor:[UIColor systemGrayColor]];
        [self.minusOrTrashButton setImage:minusIcon forState:UIControlStateNormal];
        self.minusOrTrashButton.layer.cornerRadius = 8;
    }
    [self.minusOrTrashButton addTarget:self action:@selector(minusTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.minusOrTrashButton];

    self.quantityLabel = [[UILabel alloc] init];
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    self.quantityLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.quantityLabel.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.7];
    self.quantityLabel.layer.cornerRadius = 12;
    self.quantityLabel.clipsToBounds = YES;
    [self addSubview:self.quantityLabel];
    
    
    //self.contentView.layer.masksToBounds = YES;
    self.backgroundColor = AppClearClr;
    //self.contentView.backgroundColor = AppBackgroundClr;
    [self pp_setShadowColor:GM.AppShadowColor];
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowRadius = 6.0;
    self.layer.shadowOpacity = 0.26;
    self.layer.masksToBounds = NO;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    NSLog(@"[PPQuantityButton] ▶︎ layoutSubviews — expanded: %@, quantity: %ld", self.isExpanded ? @"YES" : @"NO", (long)self.quantity);

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    if (!self.isExpanded) {
 
        self.plusButton.frame = CGRectMake(0, 0, h, h);
        self.minusOrTrashButton.hidden = YES;
        self.quantityLabel.hidden = YES;
    } else {
        CGFloat btnW = h;
        self.plusButton.frame = CGRectMake(0, 0, h, h);
        self.quantityLabel.frame = CGRectMake(btnW+5, 0, (w - 2 * btnW)-10, h);
        self.minusOrTrashButton.frame = CGRectMake(w - h, 0, h, h);
        self.minusOrTrashButton.hidden = NO;
        self.quantityLabel.hidden = NO;
    }
}

- (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated {
    _quantity = MAX(0, quantity);
    NSLog(@"[PPQuantityButton] ▶︎ setQuantity: %ld (animated: %@)", (long)_quantity, animated ? @"YES" : @"NO");

    [self updateUI];
    
    if ([self.delegate respondsToSelector:@selector(quantityButton:didChangeQuantity:)]) {
        [self.delegate quantityButton:self didChangeQuantity:_quantity];
    }

    if (_quantity == 0) {
        [self collapseAnimated:animated];
    }
}

- (void)updateUI {
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.quantity];
    
}

- (void)plusTapped {
    NSLog(@"[PPQuantityButton] ▶︎ plusTapped");

    if (!self.isExpanded) {
        NSLog(@"[PPQuantityButton] ▶︎ Expanding from collapsed state");
        self.quantity = 1;
        [self expandAnimated:YES];
    } else {
        [self setQuantity:self.quantity + 1 animated:YES];
    }
}

- (void)minusTapped {
    NSLog(@"[PPQuantityButton] ▶︎ minusTapped");
    [self setQuantity:self.quantity - 1 animated:YES];
}

- (void)expandAnimated:(BOOL)animated {
    if (self.isExpanded) {
        NSLog(@"[PPQuantityButton] ▶︎ expandAnimated skipped (already expanded)");
        return;
    }

    NSLog(@"[PPQuantityButton] ▶︎ Expanding (animated: %@)", animated ? @"YES" : @"NO");
    self.isExpanded = YES;

    void (^changes)(void) = ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (animated) {
        if (self.animationStyle == PPQuantityAnimationStyleFloat) {
            self.transform = CGAffineTransformMakeScale(0.85, 0.85);
            [UIView animateWithDuration:0.25 animations:^{
                self.transform = CGAffineTransformIdentity;
                changes();
            }];
        } else if (self.animationStyle == PPQuantityAnimationStyleFade) {
            self.alpha = 0.0;
            [UIView animateWithDuration:0.25 animations:^{
                self.alpha = 1.0;
                changes();
            }];
        } else {
            changes();
        }
    } else {
        changes();
    }
}

- (void)collapseAnimated:(BOOL)animated {
    if (!self.isExpanded) {
        NSLog(@"[PPQuantityButton] ▶︎ collapseAnimated skipped (already collapsed)");
        return;
    }

    NSLog(@"[PPQuantityButton] ▶︎ Collapsing (animated: %@)", animated ? @"YES" : @"NO");
    self.isExpanded = NO;
    self.quantity = 0;

    void (^changes)(void) = ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (animated) {
        if (self.animationStyle == PPQuantityAnimationStyleFade) {
            [UIView animateWithDuration:0.25 animations:^{
                self.alpha = 0.5;
                changes();
            } completion:^(BOOL finished) {
                self.alpha = 1.0;
            }];
        } else {
            changes();
        }
    } else {
        changes();
    }
}

@end

















 
@implementation UIScrollView (ScrollHelpers)

- (void)pp_scrollToTopAnimated:(BOOL)animated {
    if (self.contentOffset.y <= 0) return; // Already at top

    // Disable bouncing glitches if already animating
    [self.layer removeAllAnimations];

    if (@available(iOS 15.0, *)) {
        // 💎 Modern animation curve (smooth cubic ease)
        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
                                            initWithDuration:0.55
                                            dampingRatio:0.85
                                            animations:^{
            [self setContentOffset:CGPointZero animated:NO];
        }];
        [animator startAnimation];
    } else {
        // Fallback for older iOS
        [UIView animateWithDuration:0.55
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0.7
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self setContentOffset:CGPointZero animated:NO];
        }
                         completion:nil];
    }
}

@end
















/*
 
 
 
 useing opjective c and following best peactis , i want you to create an object call PPAdsBrowser that i call any where it will display a horizantal categrois and bellow it collectionview to display available ads for selected categgory, for collection view i think its beffter to use UICollectionViewDiffableDataSource for smooth and fast resposeses
 
 i will attach now the CollectionViewCell Am Using it called PPUniversalCell that using PPUniversalCellViewModel  and bellow .h file
 
 
 #import <UIKit/UIKit.h>
  NS_ASSUME_NONNULL_BEGIN


 typedef NS_ENUM(NSInteger, PPSection) {
     PPSectionAccess,
     PPSectionAds,
     PPSectionFood,
     PPSectionVets,
     PPSectionServices
 };

 typedef NS_ENUM(NSInteger, CollectioCellSection) {
     CellSectionAds = 0,
     CellSectionAccessories,
     CellSectionFood,
     CellSectionVet,
     CellSectionServices
 };

 typedef NS_ENUM(NSInteger, PPCellContext) {
     PPCellForMarket = 0,
     PPCellForAds,
     PPCellForFood,
     PPCellForVets,
     PPCellForServices
 };



 typedef NS_ENUM(NSInteger, PPDiscountStyle) {
     PPDiscountStyleBadge = 0,    // rounded badge (default)
     PPDiscountStylePlain         // plain text near price
 };

 /// Image loader signature (use your YYWebImage/SdWebImage/etc. here)
 typedef void (^PPImageLoader)(UIImageView *imageView,
                               NSString * _Nullable urlString,
                               UIImage  * _Nullable placeholder,
                               UIView  * _Nullable card);

 /// Public view model for configuring the cell
 @interface PPUniversalCellViewModel : NSObject
 @property (nonatomic, copy,nullable)   NSString *ModelID;
 @property (nonatomic, copy)   NSString *title;
 @property (nonatomic, copy)   NSString *subtitle;          // optional
 @property (nonatomic, copy)   NSString *priceText;         // e.g. "200 ﷼"
 @property (nonatomic, copy)   NSString *discountText;      // e.g. "-35%" (show if length > 0)
 @property (nonatomic, assign) BOOL isNew;                  // show NEW ribbon
 @property (nonatomic, assign) BOOL hasOffer;               // show OFFER ribbon
 @property (nonatomic, assign) BOOL isOwner;                // show edit/delete
 @property (nonatomic, copy, nullable) NSString *imageURL;  // remote
 @property (nonatomic, strong, nullable) UIImage *image;    // local
 @property (nonatomic, strong, nullable) UIImage *placeholder;
 @property (nonatomic,strong)   id ModelObject;
 @property (nonatomic, assign) PPCellContext modelContext;
 @property (nonatomic, assign) CollectioCellSection cellSection;
 @property (nonatomic, copy) NSString *modelType;
 @property (nonatomic, assign) PPSection ppSection;
 @property (nonatomic, strong) NSString *stockStatusText;
 @property (nonatomic, assign) NSIndexPath *indexPath;
 @property (nonatomic, assign) CGSize imageSize;
 @property (nonatomic, assign) NSInteger itemQuantitiy;
 @property (nonatomic, strong, nullable) NSNumber *discountPercent;  // % discount (0–100)
 @property (nonatomic, strong, nullable) NSNumber *discountAmount;   // Absolute discount (e.g. 15.0)
 @property (nonatomic, strong) NSNumber *finalPrice;               // Auto-calculated final price
 @property (nonatomic, strong) NSNumber *price;                     // Base/original price
 @end

 @protocol PPUniversalCellDelegate <NSObject>

 @optional
 // Legacy (kept)
 - (void)PPUniversalCell_tapCard:(PPUniversalCellViewModel *)universalModel;
 - (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel;
 - (void)PPUniversalCell_tapFavorite:(PPUniversalCellViewModel *)universalModel;
 - (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel;
 - (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel;
 - (void)PPUniversalCell_changeQuantity:(PPUniversalCellViewModel *)universalModel quantity:(NSInteger)quantity;


 @end



 @interface PPUniversalCell : UICollectionViewCell
 @property (nonatomic, weak) id<PPUniversalCellDelegate> delegate;

 @property (nonatomic, strong) NSIndexPath *indexPath;
 /// Core config
 @property (nonatomic, assign) PPCellContext      context;
 @property (nonatomic, assign) PPManagerCellLayoutMode   layoutMode;
 @property (nonatomic, assign) PPDiscountStyle    discountStyle; // default: Badge

 /// Quantity (only used in Marker context)
 @property (nonatomic, assign, readonly) NSInteger quantity;
 - (void)setQuantity:(NSInteger)quantity animated:(BOOL)animated;
 - (void)collapseStepper:(BOOL)animated;
 /// Configure cell from a view model
 - (void)applyViewModel:(PPUniversalCellViewModel *)vm
                context:(PPCellContext)context
             layoutMode:(PPManagerCellLayoutMode)layout
           discountMode:(PPDiscountStyle)discountStyle
            imageLoader:(PPImageLoader _Nullable)loader;



 @end

 NS_ASSUME_NONNULL_END

 
 samlpe of my current working code


 - (void)applyEmptySnapshot {
     NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
     [snapshot appendSectionsWithIdentifiers:@[@0]];
     [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
 }

 - (void)loadData {
     // After loading data, apply new snapshot
     NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
     [snapshot appendSectionsWithIdentifiers:@[@0]];
     [snapshot appendItemsWithIdentifiers:self.pp_currentUniversalModelArray intoSectionWithIdentifier:@0];
     [self.dataSource applySnapshot:snapshot animatingDifferences:YES];
 }

 - (void)configureDataSource {
     
     self.dataSource =  [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView
                                                                              cellProvider:^PPUniversalCell * _Nullable(UICollectionView *collectionView, NSIndexPath *indexPath, PPItem *item) {
         
         PPUniversalCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPUniversalCell" forIndexPath:indexPath];
         if (![item.universalViewModel isKindOfClass:[PPUniversalCellViewModel class]])
         {  NSLog(@"⚠️ Expected PPUniversalCellViewModel but got %@", [item.universalViewModel class]); return cell; }
         
         PPUniversalCellViewModel *universalModel = (PPUniversalCellViewModel *)item.universalViewModel;
         universalModel.indexPath = indexPath;
         [cell applyViewModel:universalModel context:universalModel.modelContext layoutMode:self.cellLayoutMode discountMode:PPDiscountStyleBadge imageLoader:^(UIImageView * _Nonnull imageView, NSString * _Nullable urlString, UIImage * _Nullable placeholder, UIView * _Nullable card) {
              
             // 3. Load image asynchronously with low priority
             __weak typeof(cell) weakCell = cell;
             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                 
                 [GM setImageFromUrlString:urlString imageView:imageView phImage:@"placeholder" completion:^(UIImage * _Nullable image, NSError * _Nullable error) { }];
             });
             
             
             
              
         }];
         cell.delegate = self; return cell;
         return cell;
     }];
     
     [self loadData];
 }


 #pragma mark - 🧠 Universal Model Builders
 /// Converts a generic array (ads, accessories, vets, etc.) into universal models
 - (NSArray<PPUniversalCellViewModel *> *)pp_generateUniversalModelsArrayFromArray:(NSArray<id> *)objectsArray {
     if (objectsArray.count == 0) return @[];

     NSMutableArray<PPUniversalCellViewModel *> *result = [NSMutableArray arrayWithCapacity:objectsArray.count];

     for (id obj in objectsArray) {
         PPUniversalCellViewModel *vm = [PPUniversalCellViewModel new];
         vm.placeholder = [UIImage imageNamed:@"placeholder"];
         vm.isOwner = NO;
         vm.hasOffer = NO;
         vm.isNew = NO;
         vm.ModelID = NSUUID.UUID.UUIDString;
         vm.imageURL = nil;
         vm.priceText = @"";
         vm.subtitle = @"";
         vm.ppSection = PPSectionAds;
         vm.imageSize = CGSizeZero; // ✅ default

         // 🐾 PetAd
         if ([obj isKindOfClass:[PetAd class]]) {
             PetAd *ad = (PetAd *)obj;
             vm.title = ad.adTitle ?: kLang(@"UntitledAd");
             vm.ModelID = ad.adID;
             vm.imageURL = ad.imageURLs.firstObject;
             vm.priceText = ad.price ? [NSString stringWithFormat:@"%@ %@", ad.price, kLang(@"Rials")] : kLang(@"NoPrice");
             vm.isOwner = [[PPCurrentUser ID] isEqualToString:ad.ownerID];
             vm.ModelObject = ad;
             vm.modelContext = PPCellForAds;
             vm.cellSection = CellSectionAds;
             vm.ppSection = PPSectionAds;
             vm.finalPrice = ad.price;
         }

         // 🧩 PetAccessory
         else if ([obj isKindOfClass:[PetAccessory class]]) {
             PetAccessory *acc = (PetAccessory *)obj;
             vm.title = acc.name ?: kLang(@"UntitledAccessory");
             vm.ModelID = acc.accessoryID;
             vm.imageURL = acc.imageURLsArray.firstObject;
             vm.priceText = acc.price ? [NSString stringWithFormat:@"%@", acc.price] : kLang(@"NoPrice");
             //vm.discountText = acc;
             vm.price = acc.price;
             vm.isOwner = [[PPCurrentUser ID] isEqualToString:acc.ownerID];
             vm.hasOffer = acc.hasOffer;
             vm.isNew = acc.isNew;
             vm.ModelObject = acc;
             vm.modelContext = PPCellForMarket;
             vm.cellSection = self.cellSection;
             vm.ppSection = self.cellSection == CellSectionAccessories ?  PPSectionAccess : PPSectionFood;
             
             vm.discountPercent = acc.discountPercent;
             vm.discountAmount = acc.discountAmount;
             vm.finalPrice = acc.finalPrice;
             vm.stockStatusText = acc.stockStatusText;
             vm.itemQuantitiy = acc.quantity;

            // NSLog(@"🧩 %@ | Base: %@ | Percent: %@ | Amount: %@ | Final: %@",
                   // acc.name, acc.price, acc.discountPercent, acc.discountAmount, acc.finalPrice);
         }
 */



//
//  PPImageButtonHelper.m
//

 
@implementation PPImageButtonHelper

#pragma mark - Public

+ (UIImage *)imageFor44ptButton:(UIImage *)image {
    return [self image:image
         forButtonSize:CGSizeMake(44, 44)
            imageInset:2]; // 44 - (2 * 10) = 24pt visual size (best practice)
}


+ (UIImage *)image:(UIImage *)image
   forButtonSize:(CGSize)buttonSize
      imageInset:(CGFloat)inset
{
    if (!image) return nil;

    CGFloat scale = UIScreen.mainScreen.scale;
    CGSize canvasSize = buttonSize;

    CGRect drawingRect =
    CGRectInset((CGRect){CGPointZero, canvasSize}, inset, inset);

    CGSize imageSize = image.size;

    // Aspect-fit calculation
    CGFloat aspect =
    MIN(drawingRect.size.width / imageSize.width,
        drawingRect.size.height / imageSize.height);

    CGSize finalImageSize = CGSizeMake(imageSize.width * aspect,
                                       imageSize.height * aspect);

    CGRect imageRect = CGRectMake(
        drawingRect.origin.x + (drawingRect.size.width - finalImageSize.width) / 2.0,
        drawingRect.origin.y + (drawingRect.size.height - finalImageSize.height) / 2.0,
        finalImageSize.width,
        finalImageSize.height
    );

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // 🔵 Circular clip (this is the ONLY addition)
    CGFloat diameter = MIN(drawingRect.size.width, drawingRect.size.height);
    CGRect circleRect = CGRectMake(
        (canvasSize.width  - diameter) * 0.5,
        (canvasSize.height - diameter) * 0.5,
        diameter,
        diameter
    );

    UIBezierPath *circlePath =
    [UIBezierPath bezierPathWithOvalInRect:circleRect];

    CGContextAddPath(ctx, circlePath.CGPath);
    CGContextClip(ctx);

    // Draw image inside clipped circle
    [image drawInRect:imageRect];

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return result;
}

/*

+ (UIImage *)image:(UIImage *)image
   forButtonSize:(CGSize)buttonSize
      imageInset:(CGFloat)inset {

    if (!image) return nil;

    CGFloat scale = UIScreen.mainScreen.scale;
    CGSize canvasSize = buttonSize;

    CGRect drawingRect =
    CGRectInset((CGRect){CGPointZero, canvasSize}, inset, inset);

    CGSize imageSize = image.size;

    // Aspect-fit calculation
    CGFloat aspect =
    MIN(drawingRect.size.width / imageSize.width,
        drawingRect.size.height / imageSize.height);

    CGSize finalImageSize = CGSizeMake(imageSize.width * aspect,
                                       imageSize.height * aspect);

    CGRect imageRect = CGRectMake(
        drawingRect.origin.x + (drawingRect.size.width - finalImageSize.width) / 2.0,
        drawingRect.origin.y + (drawingRect.size.height - finalImageSize.height) / 2.0,
        finalImageSize.width,
        finalImageSize.height
    );

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, scale);
    [image drawInRect:imageRect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return result;
}
*/
@end

















@implementation AdvancedGlassView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // إعداد الخلفية الشفافة
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = NO;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // تحديث إطارات الطبقات عندما يتغير حجم الـ View
    if (self.gradientLayer) {
        self.gradientLayer.frame = self.bounds;
        self.borderLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                           cornerRadius:12].CGPath;
    }
}

#pragma mark - Public Methods

- (void)setupGlassEffect {
    // 1. طبقة التدرج اللوني
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.frame = self.bounds;
    self.gradientLayer.colors = @[
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor,
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.05].CGColor
    ];
    self.gradientLayer.locations = @[@0.0, @1.0];
    self.gradientLayer.cornerRadius = 12;
    [self.layer insertSublayer:self.gradientLayer atIndex:0];
    
    // 2. طبقة Blur
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.bounds;
    blurView.layer.cornerRadius = 12;
    blurView.layer.masksToBounds = YES;
    [self insertSubview:blurView atIndex:0];
    
    // 3. طبقة الحدود اللامعة
    self.borderLayer = [CAShapeLayer layer];
    self.borderLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:12].CGPath;
    self.borderLayer.lineWidth = 1.0;
    self.borderLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
    self.borderLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.borderLayer];
    
    // 4. تأثير اللمعان
    CALayer *shineLayer = [CALayer layer];
    shineLayer.frame = CGRectMake(0, 0, self.bounds.size.width, 2);
    shineLayer.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4].CGColor;
    shineLayer.cornerRadius = 1.0;
    [self.layer addSublayer:shineLayer];
    
    // 5. إضافة ظل للتأثير ثلاثي الأبعاد
    [self pp_setShadowColor:[UIColor blackColor]];
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    self.layer.shadowOpacity = 0.1;
}

- (void)updateColorsForStyle:(UIUserInterfaceStyle)style
            withTransformer:(UIColor* (^)(UIColor *, UIUserInterfaceStyle))transformer {
    
    UIColor *baseColor = (style == UIUserInterfaceStyleDark) ?
        [UIColor blackColor] : [UIColor whiteColor];
    
    UIColor *transformedColor = transformer(baseColor, style);
    
    [UIView animateWithDuration:0.3 animations:^{
        self.gradientLayer.colors = @[
            (id)[transformedColor colorWithAlphaComponent:0.3].CGColor,
            (id)[transformedColor colorWithAlphaComponent:0.1].CGColor
        ];
        
        // تحديث لون الحدود بناءً على النمط
        if (style == UIUserInterfaceStyleDark) {
            self.borderLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        } else {
            self.borderLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4].CGColor;
        }
    }];
}

@end
