//
//  AppClasses.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "AppClasses.h"

@implementation AppClasses

+(void)addShadowToView:(UIView *)view
{
    view.layer.cornerRadius = view.hx_h / 2;;
    view.layer.masksToBounds = NO;
    
    // Shadow
    view.layer.shadowColor = GM.AppShadowColor.CGColor;
    view.layer.shadowOpacity = 0.15;
    view.layer.shadowOffset = CGSizeMake(0, 4);
    view.layer.shadowRadius = 8;
}


+ (void)startWhatsAppWith:(NSString *)phoneNumber  fromViewController:(UIViewController *)viewController{
    
    NSString *wa = [NSString stringWithFormat:@"https://wa.me/%@", phoneNumber ?: @""];
    NSURL *u = [NSURL URLWithString:wa];
    if (u) { [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil]; }
        
}
+ (void)callPhoneNumber:(NSString *)phoneNumber  fromViewController:(UIViewController *)viewController{
    // Remove any non-numeric characters
    NSString *cleanedNumber = [[phoneNumber componentsSeparatedByCharactersInSet:
                               [[NSCharacterSet characterSetWithCharactersInString:@"+0123456789"] invertedSet]]
                               componentsJoinedByString:@""];
    
    // Create the phone URL
    NSString *phoneURLString = [NSString stringWithFormat:@"telprompt://%@", cleanedNumber];
    NSURL *phoneURL = [NSURL URLWithString:phoneURLString];
    
    // Check if device can make calls
    if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:phoneURL options:@{} completionHandler:nil];
        } else {
            // Fallback for earlier versions
            [[UIApplication sharedApplication] openURL:phoneURL];
        }
    } else {
        // Device can't make calls or simulator
        UIAlertController *alert = [UIAlertController
                                   alertControllerWithTitle:@"Error"
                                   message:@"Your device cannot make phone calls"
                                   preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [viewController presentViewController:alert animated:YES completion:nil];
    }
}


/*
 @[
     [[PetCategory alloc] initWithName:kLang(@"Birds") image:[UIImage imageNamed:@"aaa2"] mainCatID:1 ID:1 categoryKind:CategoryKindMain LightenAmount:0.4 IconName:@"bird.fill"] , // birdnew birds
     
     [[PetCategory alloc] initWithName:kLang(@"Falcon") image:[UIImage imageNamed:@"falcon"] mainCatID:11 ID:11 categoryKind:CategoryKindMain LightenAmount:0.45 IconName:@"falcon_icon"],
     
     [[PetCategory alloc] initWithName:@"AdoptCell" image:[UIImage imageNamed:@"AdsBanner"] mainCatID:1010 ID:1010 categoryKind:CategoryKindMain],
     
     
     [[PetCategory alloc] initWithName:kLang(@"Cats") image:[UIImage imageNamed:@"cats1"] mainCatID:5 ID:5 categoryKind:CategoryKindMain LightenAmount:0.2 IconName:@"cat.fill"] ,
     
   
     
     [[PetCategory alloc] initWithName:kLang(@"Dogs") image:[UIImage imageNamed:@"dog"] mainCatID:6 ID:6 categoryKind:CategoryKindMain LightenAmount:0.35 IconName:@"dog.fill"] ,
     
      
     
     [[PetCategory alloc] initWithName:kLang(@"Horses") image:[UIImage imageNamed:@"horses"] mainCatID:3 ID:3 categoryKind:CategoryKindMain LightenAmount:0.6 IconName:@"horses"] ,
     
     [[PetCategory alloc] initWithName:kLang(@"Camel") image:[UIImage imageNamed:@"camel"] mainCatID:2 ID:2 categoryKind:CategoryKindMain LightenAmount:0.4 IconName:@"camel"] ,
     
     [[PetCategory alloc] initWithName:kLang(@"Sheeps") image:[UIImage imageNamed:@"sheep"] mainCatID:4 ID:4 categoryKind:CategoryKindMain LightenAmount:0.4 IconName:@"sheep"],
     
     
     
     [[PetCategory alloc] initWithName:kLang(@"Deer") image:[UIImage imageNamed:@"mDeer"] mainCatID:10 ID:10 categoryKind:CategoryKindMain LightenAmount:0.5 IconName:@"mDeer"],
     
     [[PetCategory alloc] initWithName:kLang(@"Fish") image:[UIImage imageNamed:@"fish"] mainCatID:7 ID:7 categoryKind:CategoryKindMain LightenAmount:0.3 IconName:@"tortoise.fill"],
    // [[PetCategory alloc] initWithName:kLang(@"Hot_Rabbits") image:[UIImage imageNamed:@"Rabbits"] mainCatID:7 ID:7 categoryKind:CategoryKindMain LightenAmount:0.1 IconName:@"hare"]
 ];
 */


+ (void)reloadThisCollectionView:(UICollectionView *)collectionView {
    // Reload with completion so we can animate afterwards
    
    dispatch_async(dispatch_get_main_queue(), ^{
           [UIView transitionWithView:collectionView
                             duration:0.25
                              options:UIViewAnimationOptionTransitionCrossDissolve
                           animations:^{
               [collectionView reloadData]; // ✅ Safe for count changes
           } completion:nil];
       });
    
    /*
     [collectionView performBatchUpdates:^{
         [collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
     } completion:^(BOOL finished) {
         // Animate visible cells after reload
         NSArray *cells = [collectionView visibleCells];
         
         CGFloat delay = 0.05;
         CGFloat duration = 0.35;
         
         for (NSInteger i = 0; i < cells.count; i++) {
             UICollectionViewCell *cell = cells[i];
             cell.transform = CGAffineTransformMakeTranslation(0, collectionView.bounds.size.height * 0.2);
             cell.alpha = 0.0;
             
             [UIView animateWithDuration:duration
                                   delay:delay * i
                  usingSpringWithDamping:0.8
                   initialSpringVelocity:0.6
                                 options:UIViewAnimationOptionCurveEaseOut
                              animations:^{
                 cell.transform = CGAffineTransformIdentity;
                 cell.alpha = 1.0;
             } completion:nil];
         }
     }];
     */
   
}


+ (void)reloadThisCollectionView:(UICollectionView *)collectionView
                     completion:(void (^ __nullable)(BOOL finished))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
           [UIView transitionWithView:collectionView
                             duration:0.25
                              options:UIViewAnimationOptionTransitionCrossDissolve
                           animations:^{
               [collectionView reloadData]; // ✅ Safe for count changes
           } completion:completion];
       });
    /*
     
     
     
  [UIView transitionWithView:collectionView
                        duration:0.25
                         options:UIViewAnimationOptionTransitionCrossDissolve
                      animations:^{
          [collectionView reloadData]; // ✅ safe for changed data source
      } completion:completion];
     
     
    [UIView transitionWithView:collectionView
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        NSInteger sections = [collectionView numberOfSections];
        for (NSInteger section = 0; section < sections; section++) {
            NSInteger items = [collectionView numberOfItemsInSection:section];
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
            for (NSInteger item = 0; item < items; item++) {
                [indexPaths addObject:[NSIndexPath indexPathForItem:item inSection:section]];
            }
            [collectionView reloadItemsAtIndexPaths:indexPaths];
        }

    } completion:completion]; */
}

+ (void)smartReloadCollectionView:(UICollectionView *)collectionView
                      oldItemCount:(NSInteger)oldCount
                      newItemCount:(NSInteger)newCount
                       completion:(void (^ __nullable)(BOOL finished))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (oldCount != newCount) {
            // counts changed → full reload
            [UIView transitionWithView:collectionView
                              duration:0.25
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                [collectionView reloadData];
            } completion:completion];
        } else {
            // counts match → just reload visible cells
            NSArray *visible = [collectionView indexPathsForVisibleItems];
            if (visible.count == 0) {
                if (completion) completion(YES);
                return;
            }
            [UIView transitionWithView:collectionView
                              duration:0.25
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                [collectionView reloadItemsAtIndexPaths:visible];
            } completion:completion];
        }
    });
}


+(void)reloadThisTableView:(UITableView *)tableView
{
    [UIView transitionWithView:tableView duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [tableView reloadData];
    } completion:nil];
}

+ (void)reloadThisTableView:(UITableView *)tableView
                     completion:(void (^ __nullable)(BOOL finished))completion
{
    [UIView transitionWithView:tableView
                      duration:0.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        [tableView reloadData];
    } completion:completion];
}


+ (void)gardToView:(UIView *)theView colorOne:(UIColor *)colorOne colorTwo:(UIColor *)colorTwo colorThree:(UIColor *)colorThree rds:(float)rds
{
    // Create the gradient
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];

    theViewGradient.colors = [NSArray arrayWithObjects:(id)colorOne.CGColor, (id)colorTwo.CGColor, (id)colorThree.CGColor, nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = rds;
    //[theViewGradient set]
    //Add gradient to view
    //[theViewGradient setMaskedCorners:kCALayerMinXMinYCorner | kCALayerMaxXMaxYCorner];
    [theView.layer insertSublayer:theViewGradient atIndex:0];
    [theView.layer setCornerRadius:rds];
}

+ (void)setTitle:(NSString *)title onController:(UIViewController *)controller backgroundColor:(UIColor *)bgColor align:(titleAlign)align masked:(CACornerMask)masked
{
    
    UIFont *font = [GM boldFontWithSize:18];

    CGSize textSize = [title sizeWithAttributes:@{NSFontAttributeName: font}];
    CGFloat width = textSize.width + 100;
    
    
    float titleX = 0;
    if(Language.isRTL)
        titleX = controller.view.frame.size.width - width;
    else if(align == titleAlignCenter)
        titleX = (controller.view.frame.size.width / 2) - (width / 2);
    
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(titleX, [GM topPadding] - 2,  width, 42)];
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter; // Right-align text
    titleLabel.textColor = GM.PrimaryTextColor;// GM.appPrimaryColor; // Customize color
    titleLabel.font =  [GM boldFontWithSize:18]; // Customize font
    titleLabel.backgroundColor =  bgColor; //[UIColor secondarySystemBackgroundColor]; // Customize font
    // Set the label as the titleView



    // Add a fixed space with negative width to shift it closer
    UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc]
                                        initWithCustomView:titleLabel];
   

   // controller.navigationItem.rightBarButtonItems = @[negativeSpacer, customLabelItem];
    
    titleLabel.layer.cornerRadius = 20;
    titleLabel.clipsToBounds = YES;
    [titleLabel.layer setMaskedCorners:masked];
    
    
    [controller.view addSubview:titleLabel];

}


+ (UILabel *)getTitleLabel:(NSString *)title onController:(UIViewController *)controller backgroundColor:(UIColor *)bgColor align:(titleAlign)align masked:(CACornerMask)masked fromLabel:(UILabel *)fromLabel
{
    
    UIFont *font = [GM boldFontWithSize:18];

    CGSize textSize = [title sizeWithAttributes:@{NSFontAttributeName: font}];
    CGFloat width = textSize.width + 150;
    
    
    float titleX = 0;
    if(align == titleAlignRigth)
        titleX = controller.view.frame.size.width - width;
    else if(align == titleAlignCenter)
        titleX = (controller.view.frame.size.width / 2) - (width / 2);
    
    if(!fromLabel)
    fromLabel = [[UILabel alloc] initWithFrame:CGRectMake(titleX, [GM topPadding] - 2,  width, 42)];
    fromLabel.text = title;
    fromLabel.textAlignment = NSTextAlignmentCenter; // Right-align text
    fromLabel.textColor = GM.PrimaryTextColor;// GM.appPrimaryColor; // Customize color
    fromLabel.font =  [GM boldFontWithSize:18]; // Customize font
    fromLabel.backgroundColor =  bgColor; //[UIColor secondarySystemBackgroundColor]; // Customize font
    // Set the label as the titleView



    // Add a fixed space with negative width to shift it closer
    UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc]
                                        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                        target:nil
                                        action:nil];
    negativeSpacer.width = 0; // Adjust as needed

   // controller.navigationItem.rightBarButtonItems = @[negativeSpacer, customLabelItem];
    
    fromLabel.layer.cornerRadius = 20;
    fromLabel.clipsToBounds = YES;
    [fromLabel.layer setMaskedCorners:masked];
    
    [fromLabel removeFromSuperview];
    [controller.view addSubview:fromLabel];
    
    return fromLabel;

}

// Returns the height of the navigation bar, if available
+ (CGFloat)navigationBarHeightController:(UIViewController *)controller {
    CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat totalNavBarHeight = controller.navigationController.navigationBar.frame.size.height + statusBarHeight;
    return totalNavBarHeight;
}

+ (void)setAnimationNamed:(NSString *)fileName
                   ToView:(LOTAnimationView *)lot
               withSpeed:(float)animationSpeed
              completion:(void (^)(BOOL success))completion
{
    [AppClasses fetchLottieJSONFromFirebasePath:[NSString stringWithFormat:@"LottieAnimations/%@.json", fileName]
                                     completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Lottie --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                if (completion) completion(NO);
                return;
            }

            if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                NSLog(@"Lottie --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                if (completion) completion(NO);
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (composition) {
                lot.animationSpeed = animationSpeed;
                [lot setSceneModel:composition];
                //[lot play];
                if (completion) completion(YES);
            } else {
                NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
                if (completion) completion(NO);
            }
        });

    }];
}


+ (void)fetchLottieJSONFromFirebasePath:(NSString *)storagePath
                             completion:(void (^)(NSDictionary *jsonDict, NSError *error))completion {

    // Initialize a YYCache instance (memory + disk)
    static YYCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[YYCache alloc] initWithName:@"LottieJSONCache"];
    });

    // Use storage path as the cache key (works for .json and .lottie)
    NSString *cacheKey = [NSString stringWithFormat:@"lottie_%@", storagePath];

    // Check cache
    NSDictionary *cachedJSON = (NSDictionary *)[cache objectForKey:cacheKey];
    if (cachedJSON) {
        NSLog(@"✅ Fetched Lottie JSON from cache");
        if (completion) completion(cachedJSON, nil);
        return;
    }

    // Not cached — fetch from Firebase Storage
    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *ref = [storage referenceWithPath:storagePath];

    int64_t maxDownloadSize = 20 * 1024 * 1024; // 20 MB to allow .lottie files

    [ref dataWithMaxSize:maxDownloadSize completion:^(NSData * _Nullable data, NSError * _Nullable error) {
        if (error || !data) {
            NSLog(@"❌ Failed to download Lottie data: %@", error.localizedDescription);
            if (completion) completion(nil, error ?: [NSError errorWithDomain:@"LottieFetch" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"No data"}]);
            return;
        }

        NSString *lower = storagePath.lowercaseString;
        BOOL isDotLottie = [lower hasSuffix:@".lottie"];
        BOOL isJSON      = [lower hasSuffix:@".json"] || !isDotLottie; // default to JSON if unknown

        if (isJSON) {
            // === ORIGINAL JSON PATH (UNCHANGED) ===
            NSError *jsonError = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];

            if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
                NSLog(@"❌ Failed to parse JSON: %@", jsonError.localizedDescription);
                if (completion) completion(nil, jsonError ?: [NSError errorWithDomain:@"LottieFetch" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON"}]);
                return;
            }

            [cache setObject:json forKey:cacheKey];
            NSLog(@"✅ Downloaded and cached Lottie JSON");
            if (completion) completion(json, nil);
            return;
        }

        // === .LOTTIE SUPPORT ===
        // Requires SSZipArchive to unzip the dotlottie package
#if __has_include(<SSZipArchive/SSZipArchive.h>)
        // 1) Write the .lottie bytes to a temp file
        NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        NSString *zipPath = [tempDir stringByAppendingPathComponent:@"anim.lottie"];
        NSError *fsErr = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&fsErr];
        if (fsErr) {
            if (completion) completion(nil, fsErr);
            return;
        }
        if (![data writeToFile:zipPath options:NSDataWritingAtomic error:&fsErr]) {
            if (completion) completion(nil, fsErr ?: [NSError errorWithDomain:@"LottieFetch" code:-3 userInfo:@{NSLocalizedDescriptionKey:@"Failed to write .lottie"}]);
            return;
        }

        // 2) Unzip
        NSString *unzipDir = [tempDir stringByAppendingPathComponent:@"unzipped"];
        BOOL unzipOK = [SSZipArchive unzipFileAtPath:zipPath toDestination:unzipDir];
        if (!unzipOK) {
            if (completion) completion(nil, [NSError errorWithDomain:@"LottieFetch" code:-4 userInfo:@{NSLocalizedDescriptionKey:@"Failed to unzip .lottie"}]);
            return;
        }

        // 3) Read manifest.json
        NSString *manifestPath = [unzipDir stringByAppendingPathComponent:@"manifest.json"];
        NSData *manifestData = [NSData dataWithContentsOfFile:manifestPath];
        if (!manifestData) {
            if (completion) completion(nil, [NSError errorWithDomain:@"LottieFetch" code:-5 userInfo:@{NSLocalizedDescriptionKey:@"manifest.json not found in .lottie"}]);
            return;
        }
        NSError *manifestErr = nil;
        NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:kNilOptions error:&manifestErr];
        if (manifestErr || ![manifest isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, manifestErr ?: [NSError errorWithDomain:@"LottieFetch" code:-6 userInfo:@{NSLocalizedDescriptionKey:@"Invalid manifest.json"}]);
            return;
        }

        // 4) Pick the animation file
        // Manifest spec: { "animations": [{ "id":"", "loop":true, "direction":1, "theme":"", "json":"animations/xxx.json", "default":true }, ...] }
        NSArray *anims = manifest[@"animations"];
        NSDictionary *chosen = nil;
        if ([anims isKindOfClass:[NSArray class]] && anims.count > 0) {
            for (NSDictionary *a in anims) {
                if ([a isKindOfClass:[NSDictionary class]] && [a[@"default"] boolValue]) { chosen = a; break; }
            }
            if (!chosen) chosen = anims.firstObject;
        }
        NSString *jsonRelPath = [chosen isKindOfClass:[NSDictionary class]] ? (chosen[@"json"] ?: @"") : @"";
        if (jsonRelPath.length == 0) {
            // Fallback: try common location
            jsonRelPath = @"animations/animation.json";
        }

        NSString *jsonAbsPath = [unzipDir stringByAppendingPathComponent:jsonRelPath];
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonAbsPath];
        if (!jsonData) {
            if (completion) completion(nil, [NSError errorWithDomain:@"LottieFetch" code:-7 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Animation JSON not found at %@", jsonRelPath]}]);
            return;
        }

        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&jsonErr];
        if (jsonErr || ![json isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, jsonErr ?: [NSError errorWithDomain:@"LottieFetch" code:-8 userInfo:@{NSLocalizedDescriptionKey:@"Invalid animation JSON inside .lottie"}]);
            return;
        }

        // 5) Cache the resolved animation JSON using the same key
        [cache setObject:json forKey:cacheKey];

        // 6) Cleanup temp files (best-effort)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [[NSFileManager defaultManager] removeItemAtPath:tempDir error:nil];
        });

        NSLog(@"✅ Downloaded .lottie, extracted animation JSON, and cached");
        if (completion) completion(json, nil);
#else
        // SSZipArchive not present → tell the caller
        NSError *noZipErr = [NSError errorWithDomain:@"LottieFetch"
                                                code:-9
                                            userInfo:@{NSLocalizedDescriptionKey:
                                                       @".lottie support requires SSZipArchive. Add `pod 'SSZipArchive'` or supply a .json file."}];
        if (completion) completion(nil, noZipErr);
#endif
    }];
}


@end
























@implementation PetAdCardView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        
        self.backgroundColor = AppForgroundColr;
        self.layer.cornerRadius = PPCorners;
        self.layer.masksToBounds = YES;
        
        CGFloat padding = 8.0f;
        CGFloat iconSize = 20.0f;
        
        // Name
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [GM boldFontWithSize:16];
        _nameLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        _genderIcon = [[UIImageView alloc] init];
        _genderIcon.contentMode = UIViewContentModeScaleAspectFit;
        _genderIcon.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Breed
        _breedLabel = [[UILabel alloc] init];
        _breedLabel.font = [GM MidFontWithSize:14];
        _breedLabel.textColor = UIColor.secondaryLabelColor;
        _breedLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Age row
        _ageIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"clock"]];
        _ageIcon.tintColor = UIColor.grayColor;
        _ageIcon.contentMode = UIViewContentModeScaleAspectFit;
        _ageIcon.translatesAutoresizingMaskIntoConstraints = NO;
        
        _ageLabel = [[UILabel alloc] init];
        _ageLabel.font = [GM MidFontWithSize:14];
        _ageLabel.textColor = UIColor.grayColor;
        _ageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Location row
        _locationIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mappin.and.ellipse"]];
        _locationIcon.tintColor = UIColor.grayColor;
        _locationIcon.contentMode = UIViewContentModeScaleAspectFit;
        _locationIcon.translatesAutoresizingMaskIntoConstraints = NO;
        
        _locationLabel = [[UILabel alloc] init];
        _locationLabel.font = [GM MidFontWithSize:14];
        _locationLabel.textColor = UIColor.grayColor;
        _locationLabel.numberOfLines = 1;
        _locationLabel.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Add subviews
        [self addSubview:_nameLabel];
        [self addSubview:_genderIcon];
        [self addSubview:_breedLabel];
        [self addSubview:_ageIcon];
        [self addSubview:_ageLabel];
        [self addSubview:_locationIcon];
        [self addSubview:_locationLabel];
        
        // Constraints
        [NSLayoutConstraint activateConstraints:@[
            
            // Name
            [_nameLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:padding],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
            [_nameLabel.heightAnchor constraintEqualToConstant:20],
            
            // Gender icon
            [_genderIcon.leadingAnchor constraintEqualToAnchor:_nameLabel.trailingAnchor constant:4],
            [_genderIcon.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_genderIcon.widthAnchor constraintEqualToConstant:iconSize],
            [_genderIcon.heightAnchor constraintEqualToConstant:iconSize],
            
            // Breed
            [_breedLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:4],
            [_breedLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
            [_breedLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
            [_breedLabel.heightAnchor constraintEqualToConstant:18],
            
            // Age icon
            [_ageIcon.topAnchor constraintEqualToAnchor:_breedLabel.bottomAnchor constant:6],
            [_ageIcon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
            [_ageIcon.widthAnchor constraintEqualToConstant:iconSize],
            [_ageIcon.heightAnchor constraintEqualToConstant:iconSize],
            
            // Age label
            [_ageLabel.leadingAnchor constraintEqualToAnchor:_ageIcon.trailingAnchor constant:4],
            [_ageLabel.centerYAnchor constraintEqualToAnchor:_ageIcon.centerYAnchor],
            [_ageLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
            [_ageLabel.heightAnchor constraintEqualToConstant:16],
            
            // Location icon
            [_locationIcon.topAnchor constraintEqualToAnchor:_ageIcon.bottomAnchor constant:6],
            [_locationIcon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:padding],
            [_locationIcon.widthAnchor constraintEqualToConstant:iconSize],
            [_locationIcon.heightAnchor constraintEqualToConstant:iconSize],
            
            // Location label
            [_locationLabel.leadingAnchor constraintEqualToAnchor:_locationIcon.trailingAnchor constant:4],
            [_locationLabel.centerYAnchor constraintEqualToAnchor:_locationIcon.centerYAnchor],
            [_locationLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-padding],
            [_locationLabel.heightAnchor constraintEqualToConstant:16]
        ]];
    }
    return self;
}


- (void)layoutSubviews {
    [super layoutSubviews];
    
   
}

- (void)configureWithPetAd:(PetAd *)pet {
    self.nameLabel.text = pet.adTitle;
    MainKindsModel *mainKindModel = [MainKindsModel mainKindModelForID:pet.category];
    self.breedLabel.text = [mainKindModel subKindForID:pet.subcategory] ? [mainKindModel subKindForID:pet.subcategory].SubKindName : @"";
    self.ageLabel.text = [NSString stringWithFormat:@"%@ %@",
                          pet.petAgeMonths,
                          kLang(@"age")];;
    self.locationLabel.text = [CitiesManager.shared cityNameForID:pet.adLocation];
    
    NSString *genderSymbol = pet.isFemale ? @"female" : @"male";

    self.genderIcon.image = [UIImage imageNamed:genderSymbol];
}

// Helper: Convert symbol to UIImage
- (UIImage *)imageFromText:(NSString *)text withColor:(UIColor *)color {
    NSDictionary *attrs = @{NSFontAttributeName: [UIFont systemFontOfSize:14],
                            NSForegroundColorAttributeName: color};
    CGSize size = [text sizeWithAttributes:attrs];
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [text drawAtPoint:CGPointZero withAttributes:attrs];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end

























