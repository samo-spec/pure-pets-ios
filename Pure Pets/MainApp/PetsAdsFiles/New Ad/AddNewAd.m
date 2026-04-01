#import "AddNewAd.h"
#import "PPImageCollection.h"
#import "PPMenuHelper.h"
#import "LocationPickerViewController.h"
#import "ZYCircleProgressView.h"
@import SwiftBridging;
#import <math.h>
#import <float.h>

static NSString * const PPAddNewAdUploadErrorDomain = @"PPAddNewAdUploadErrorDomain";
static NSString * const PPAddNewAdLanguageDidChangeNotification = @"LanguageDidChangeNotification";
static NSString * const PPAddNewAdDraftDefaultsPrefix = @"pp.add_pet_ad.draft";
static NSString * const PPAddNewAdDraftFormDataKey = @"formData";
static NSString * const PPAddNewAdDraftImagePathsKey = @"imagePaths";
static NSString * const PPAddNewAdDraftMediaMutatedKey = @"didMutateMedia";

static inline BOOL PPIsValidAdCoordinate(CLLocationCoordinate2D coordinate) {
    if (!isfinite(coordinate.latitude) || !isfinite(coordinate.longitude)) return NO;
    if (coordinate.latitude < -90.0 || coordinate.latitude > 90.0) return NO;
    if (coordinate.longitude < -180.0 || coordinate.longitude > 180.0) return NO;
    if (fabs(coordinate.latitude) < DBL_EPSILON && fabs(coordinate.longitude) < DBL_EPSILON) return NO; // invalid sentinel
    return YES;
}

@interface AddNewAd ()<UISheetPresentationControllerDelegate,UITextFieldDelegate,PPImageCollectionDelegate>
// form + data
@property (nonatomic, strong) XLFormDescriptor *mform;
@property (nonatomic, strong) FileUploadManager *uploadManager;

@property (nonatomic, strong) PetAd *adModel;
@property (nonatomic, strong) MainKindsModel *selectedKind;
@property (assign) BOOL presented;
@property (nonatomic, weak) UIView *ppFloatingBar;
@property (nonatomic, weak) UIButton *ppFloatingBarDoneButton;
 
@property (nonatomic, strong)  XLFormRowDescriptor *titleRow;

@property (nonatomic, strong) NSArray<PetImageItem *> *finalImageItems;
@property (nonatomic, strong) UIBarButtonItem *ppUploadSpinnerItem;
@property (nonatomic, strong) UIBarButtonItem *ppOriginalRightItem;
@property (nonatomic, strong) UIActivityIndicatorView *ppUploadSpinner;
@property (nonatomic, strong) PPPhotoBrowserBridge *photoBrowserBridge;
@property (nonatomic, strong) UIView *prefillLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *prefillLoadingSpinner;
@property (nonatomic, strong) UILabel *prefillLoadingLabel;
@property (nonatomic, strong) UIView *uploadProgressOverlay;
@property (nonatomic, strong) ZYCircleProgressView *uploadCircleProgressView;
@property (nonatomic, strong) UILabel *uploadProgressValueLabel;
@property (nonatomic, strong) UILabel *uploadProgressTitleLabel;
@property (nonatomic, assign) BOOL isSubmittingAd;
@property (nonatomic, assign) BOOL isPrefillInProgress;
@property (nonatomic, copy) NSString *createFlowAdID;
@property (nonatomic, assign) BOOL didMutateMediaAfterPrefill;
@property (nonatomic, assign) BOOL hasUserModifiedForm;
@property (nonatomic, assign) BOOL isHydratingFormData;
@property (nonatomic, assign) BOOL isHydratingMedia;
@end


@implementation AddNewAd


- (UIBarButtonItem *)pp_uploadSpinnerBarItem
{
    if (self.ppUploadSpinnerItem) {
        return self.ppUploadSpinnerItem;
    }

    UIActivityIndicatorViewStyle style =
        UIActivityIndicatorViewStyleMedium;

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];

    spinner.color = AppPrimaryClr;
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];

    self.ppUploadSpinner = spinner;
    self.ppUploadSpinnerItem =
        [[UIBarButtonItem alloc] initWithCustomView:spinner];

    return self.ppUploadSpinnerItem;
}


- (instancetype)initWithCoordinator:(id)coordinator {
      self = [super init];
      if (self) {
          _coordinator = coordinator;
          // Register for notifications here if needed
      }
      return self;
  }


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - viewDidLoad (Fixed)

- (void)viewDidLoad {
    [super viewDidLoad];
    self.presented=NO;
    self.isHydratingFormData = YES;
    self.isHydratingMedia = NO;
    self.hasUserModifiedForm = NO;

    [self initBase];
    [self initForm];
    [self setBackAndCorners];
    [self setupImageCollection];
    [self setupPrefillLoadingUI];
    [self setupUploadProgressUI];
    self.photoBrowserBridge = [PPPhotoBrowserBridge new];
    self.photoBrowserBridge.useArabic = Language.isRTL;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_handleLanguageDidChange:)
                                               name:PPAddNewAdLanguageDidChangeNotification
                                               object:nil];
    [self pp_refreshMediaLocalizedText];
    if (![self restoreDraftIfNeeded]) {
        [self configureForEditingIfNeeded];
    }
    self.isHydratingFormData = NO;
    
    
    // PPImageCollection owns editor notifications and picker handling.
}

#pragma mark - Media Access (PPImageCollection)

- (NSString *)pp_localizedStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = key.length ? kLang(key) : nil;
    if (![value isKindOfClass:NSString.class] || value.length == 0 || [value isEqualToString:key]) {
        return fallback ?: @"";
    }
    return value;
}

- (void)pp_refreshMediaLocalizedText
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.photoBrowserBridge.useArabic = Language.isRTL;
        self.imageCollection.useArabic = Language.isRTL;
        NSString *title = [self pp_localizedStringForKey:@"add.images.here"
                                                 fallback:@"Add images here"];
        [self.imageCollection setTitle:title icon:nil];
    });
}

- (void)pp_setSubmitEnabled:(BOOL)enabled
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.ppOriginalRightItem) {
            self.ppOriginalRightItem.enabled = enabled;
        }
        self.navigationItem.rightBarButtonItem.enabled = enabled;
    });
}

- (void)pp_setMediaLoadingVisible:(BOOL)visible
                          textKey:(NSString *)textKey
                         fallback:(NSString *)fallback
{
    NSString *text = [self pp_localizedStringForKey:textKey fallback:fallback];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.prefillLoadingLabel.text = text;
        [self setPrefillLoadingVisible:visible];
    });
}

- (void)pp_handleLanguageDidChange:(NSNotification *)note
{
    (void)note;
    [self pp_refreshMediaLocalizedText];
    self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
}

- (NSArray<UIImage *> *)safeMediaOutputArray {
    return [self.imageCollection allImages] ?: @[];
}

- (NSInteger)safeMediaOutputCount {
    return [self.imageCollection imageCount];
}

- (void)safeAddImage:(UIImage *)image {
    [self.imageCollection addImage:image];
}

- (void)safeReplaceImageAtIndex:(NSInteger)index withImage:(UIImage *)image {
    [self.imageCollection replaceImageAtIndex:index withImage:image];
}

- (void)safeRemoveImageAtIndex:(NSInteger)index {
    [self.imageCollection removeImageAtIndex:index];
}

- (void)safeClearAllImages {
    [self.imageCollection clearAllImages];
}

- (void)setupPrefillLoadingUI
{
    self.prefillLoadingView = [[UIView alloc] init];
    self.prefillLoadingView.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.prefillLoadingView.layer.cornerRadius = 12;
    self.prefillLoadingView.layer.masksToBounds = YES;
    self.prefillLoadingView.hidden = YES;

    self.prefillLoadingSpinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.prefillLoadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingSpinner.color = UIColor.whiteColor;

    self.prefillLoadingLabel = [[UILabel alloc] init];
    self.prefillLoadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.prefillLoadingLabel.font = [GM MidFontWithSize:12];
    self.prefillLoadingLabel.textColor = UIColor.whiteColor;
    NSString *loadingText = kLang(@"loading_images");
    self.prefillLoadingLabel.text = loadingText.length ? loadingText : kLang(@"Loading");

    [self.prefillLoadingView addSubview:self.prefillLoadingSpinner];
    [self.prefillLoadingView addSubview:self.prefillLoadingLabel];
    [self.view addSubview:self.prefillLoadingView];

    [NSLayoutConstraint activateConstraints:@[
        [self.prefillLoadingView.centerXAnchor constraintEqualToAnchor:self.imageCollection.centerXAnchor],
        [self.prefillLoadingView.centerYAnchor constraintEqualToAnchor:self.imageCollection.centerYAnchor],
        [self.prefillLoadingSpinner.leadingAnchor constraintEqualToAnchor:self.prefillLoadingView.leadingAnchor constant:10],
        [self.prefillLoadingSpinner.centerYAnchor constraintEqualToAnchor:self.prefillLoadingView.centerYAnchor],
        [self.prefillLoadingLabel.leadingAnchor constraintEqualToAnchor:self.prefillLoadingSpinner.trailingAnchor constant:8],
        [self.prefillLoadingLabel.trailingAnchor constraintEqualToAnchor:self.prefillLoadingView.trailingAnchor constant:-10],
        [self.prefillLoadingLabel.topAnchor constraintEqualToAnchor:self.prefillLoadingView.topAnchor constant:8],
        [self.prefillLoadingLabel.bottomAnchor constraintEqualToAnchor:self.prefillLoadingView.bottomAnchor constant:-8]
    ]];
}

- (void)setupUploadProgressUI
{
    UIView *overlay = [[UIView alloc] init];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.62];
    overlay.layer.cornerRadius = 16.0;
    overlay.layer.masksToBounds = YES;
    overlay.hidden = YES;

    ZYCircleProgressView *circleView = [[ZYCircleProgressView alloc] init];
    circleView.translatesAutoresizingMaskIntoConstraints = NO;
    [circleView updateConfig:^(ZYCircleProgressViewConfig *config) {
        config.lineWidth = 8.0;
        config.backLineColor = [[UIColor whiteColor] colorWithAlphaComponent:0.25];
        config.progressLineColor = AppPrimaryClr;
    }];
    circleView.progress = 0.0;

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.font = [GM MidFontWithSize:16];
    valueLabel.textColor = UIColor.whiteColor;
    valueLabel.textAlignment = NSTextAlignmentCenter;
    valueLabel.text = @"0%";

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM MidFontWithSize:12];
    titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];

    [overlay addSubview:circleView];
    [overlay addSubview:valueLabel];
    [overlay addSubview:titleLabel];
    [self.view addSubview:overlay];

    self.uploadProgressOverlay = overlay;
    self.uploadCircleProgressView = circleView;
    self.uploadProgressValueLabel = valueLabel;
    self.uploadProgressTitleLabel = titleLabel;

    [NSLayoutConstraint activateConstraints:@[
        [overlay.centerXAnchor constraintEqualToAnchor:self.imageCollection.centerXAnchor],
        [overlay.centerYAnchor constraintEqualToAnchor:self.imageCollection.centerYAnchor],
        [overlay.widthAnchor constraintEqualToConstant:168.0],
        [overlay.heightAnchor constraintEqualToConstant:176.0],

        [circleView.centerXAnchor constraintEqualToAnchor:overlay.centerXAnchor],
        [circleView.topAnchor constraintEqualToAnchor:overlay.topAnchor constant:18.0],
        [circleView.widthAnchor constraintEqualToConstant:86.0],
        [circleView.heightAnchor constraintEqualToConstant:86.0],

        [valueLabel.centerXAnchor constraintEqualToAnchor:circleView.centerXAnchor],
        [valueLabel.centerYAnchor constraintEqualToAnchor:circleView.centerYAnchor],

        [titleLabel.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:12.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-12.0],
        [titleLabel.topAnchor constraintEqualToAnchor:circleView.bottomAnchor constant:14.0]
    ]];
}

- (void)pp_setCircularUploadProgressVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            self.uploadProgressTitleLabel.text = [self pp_localizedStringForKey:@"uploading_images" fallback:@"Uploading images..."];
            self.uploadProgressValueLabel.text = @"0%";
            self.uploadCircleProgressView.progress = 0.0;
        }
        self.uploadProgressOverlay.hidden = !visible;
    });
}

- (void)pp_updateCircularUploadProgress:(CGFloat)progress
{
    CGFloat clampedProgress = MIN(1.0, MAX(0.0, progress));
    NSInteger percentage = (NSInteger)lrint(clampedProgress * 100.0);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.uploadCircleProgressView.progress = clampedProgress;
        self.uploadProgressValueLabel.text = [NSString stringWithFormat:@"%ld%%", (long)percentage];
    });
}

- (void)setPrefillLoadingVisible:(BOOL)visible
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.prefillLoadingView.hidden = !visible;
        if (visible) {
            [self.prefillLoadingSpinner startAnimating];
        } else {
            [self.prefillLoadingSpinner stopAnimating];
        }
    });
}

- (void)openImagePreviewAtIndex:(NSInteger)index
{
    NSArray<UIImage *> *images = [self safeMediaOutputArray];
    if (images.count == 0 || index < 0 || index >= images.count) return;

    self.photoBrowserBridge.useArabic = Language.isRTL;
    [self.photoBrowserBridge showBrowserFrom:self
                                      images:images
                                  startIndex:index];
}

#pragma mark - PPImageCollectionDelegate

- (void)imageCollection:(PPImageCollection *)collection didUpdateImages:(NSArray<UIImage *> *)images {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[PPImages] Updated images count=%ld", (long)images.count);
        if (!self.isHydratingFormData && !self.isHydratingMedia && !self.isPrefillInProgress) {
            self.hasUserModifiedForm = YES;
        }
        if (self.mode == AdEditorModeEdit && !self.isPrefillInProgress && !self.isHydratingMedia) {
            self.didMutateMediaAfterPrefill = YES;
        }
        [self pp_refreshMediaLocalizedText];
        [self pp_reloadMediaUI];
    });
}

- (void)imageCollection:(PPImageCollection *)collection
         didSelectImage:(nonnull UIImage *)selectedImage
                AtIndex:(NSInteger)index
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedViewController) {
            return;
        }

        UIView *anchorView = collection.collectionView ?: self.imageCollection;

        NSString *previewTitle = [self pp_localizedStringForKey:@"preview" fallback:@"Preview"];
        NSString *editTitle = [self pp_localizedStringForKey:@"edit" fallback:@"Edit"];
        NSArray<NSString *> *titles = @[previewTitle, editTitle];
        NSArray<UIImage *> *icons = @[
            [UIImage systemImageNamed:@"eye"],
            [UIImage systemImageNamed:@"slider.horizontal.3"]
        ];

        __weak typeof(self) weakSelf = self;
        [PPMenuHelper presentActionSheetFromViewController:self
                                                sourceView:anchorView
                                                    titles:titles
                                                    images:icons
                                              destructive:nil
                                                  handler:^(NSInteger menuIndex, NSString *title) {
            if (menuIndex == 0) {
                [weakSelf openImagePreviewAtIndex:index];
            } else if (menuIndex == 1) {
                [collection presentEditorForImageAtIndex:index fromViewController:weakSelf];
            }
        }];
    });
}

- (void)imageCollectionDidRequestAddImage:(PPImageCollection *)collection {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self safeMediaOutputCount] >= collection.maxImageCount) {
            NSString *title = [self pp_localizedStringForKey:@"max_images_reached"
                                                     fallback:@"Maximum images reached"];
            NSString *subtitle = [NSString stringWithFormat:@"%@ %ld",
                                  [self pp_localizedStringForKey:@"max_images_hint" fallback:@"You can upload up to"],
                                  (long)collection.maxImageCount];
            [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
            return;
        }
        [collection presentPickerFromViewController:self];
    });
}

#pragma mark - Prefill for Editing

- (void)pp_finishPrefillFlow
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPrefillInProgress = NO;
        [self pp_setMediaLoadingVisible:NO textKey:@"loading_images" fallback:@"Loading images..."];
        self.imageCollection.userInteractionEnabled = !self.isSubmittingAd;
        [self pp_setSubmitEnabled:!self.isSubmittingAd];
    });
}

- (void)prefillPhotosForEdit
{
    self.isPrefillInProgress = YES;
    [self pp_setSubmitEnabled:NO];
    [self pp_setMediaLoadingVisible:YES textKey:@"loading_images" fallback:@"Loading images..."];

    NSArray<PetImageItem *> *items = self.adModel.imageItems;
    if (items.count == 0) {
        [self pp_finishPrefillFlow];
        return;
    }

    NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:items.count];
    for (PetImageItem *item in items) {
        if (item.url.length) {
            [urls addObject:item.url];
        }
    }

    if (urls.count == 0) {
        [self pp_finishPrefillFlow];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageCollection.userInteractionEnabled = NO;
    });

    [self.imageCollection preloadImagesFromURLs:urls completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Prefilled %ld images for editing", (long)urls.count);
            [self pp_reloadMediaUI];
            [self pp_refreshMediaLocalizedText];
        });
        [self pp_finishPrefillFlow];
    }];
}

#pragma mark - Upload Handling (Fixed)

- (NSError *)pp_uploadErrorWithCode:(NSInteger)code description:(NSString *)description
{
    NSString *message = description.length ? description : @"Image upload failed.";
    return [NSError errorWithDomain:PPAddNewAdUploadErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (BOOL)pp_validateCreateHasAtLeastOneImage
{
    if ([self safeMediaOutputCount] > 0) {
        return YES;
    }

    NSString *title = [self pp_localizedStringForKey:@"add_images_required"
                                             fallback:@"Add at least one image"];
    NSString *subtitle = [self pp_localizedStringForKey:@"add_images_required_desc"
                                                fallback:@"Please add at least one image before posting your ad."];
    [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
    return NO;
}

- (UIImage *)pp_normalizedImageForUpload:(UIImage *)image
{
    if (!image) return nil;
    if (image.size.width <= 0.0 || image.size.height <= 0.0) return nil;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = image.scale > 0 ? image.scale : UIScreen.mainScreen.scale;

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];
    UIImage *normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    }];
    return normalized ?: image;
}

- (void)uploadUIImages:(NSArray<UIImage *> *)images
                 forAd:(PetAd *)ad
            completion:(void (^)(PetAd *_Nullable updatedAd, NSError *_Nullable error))completion
{
    NSLog(@"🟢 [uploadUIImages] START | adID=%@ | images=%lu",
          ad.adID, (unsigned long)images.count);

    if (ad.adID.length == 0) {
        if (completion) completion(nil, [self pp_uploadErrorWithCode:400 description:@"Missing adID for image upload."]);
        return;
    }

    if (images.count == 0) {
        NSLog(@"⚠️ [uploadUIImages] No images, returning immediately");
        ad.imageItems = @[];
        self.finalImageItems = @[];
        if (completion) completion(ad, nil);
        return;
    }

    NSMutableArray<UIImage *> *normalizedImages = [NSMutableArray arrayWithCapacity:images.count];
    for (NSInteger idx = 0; idx < images.count; idx++) {
        UIImage *normalized = [self pp_normalizedImageForUpload:images[idx]];
        if (!normalized) {
            if (completion) completion(nil, [self pp_uploadErrorWithCode:401
                                                             description:[NSString stringWithFormat:@"Failed to prepare image at index %ld.", (long)idx]]);
            return;
        }
        [normalizedImages addObject:normalized];
    }

    FIRStorage *storage = [FIRStorage storage];
    FIRStorageReference *rootRef = storage.reference;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:normalizedImages.count];
    dispatch_queue_t stateQueue = dispatch_queue_create("com.purepets.addnewad.upload", DISPATCH_QUEUE_SERIAL);
    __block NSMutableDictionary<NSNumber *, NSNumber *> *progressByIndex = [NSMutableDictionary dictionaryWithCapacity:normalizedImages.count];
    __block NSError *firstError = nil;

    for (NSInteger i = 0; i < normalizedImages.count; i++) {
        [items addObject:[NSNull null]];
        progressByIndex[@(i)] = @(0.0);
    }
    [self pp_updateCircularUploadProgress:0.0];

    for (NSInteger idx = 0; idx < normalizedImages.count; idx++) {

        UIImage *img = normalizedImages[idx];
        if (!img) {
            NSLog(@"❌ [uploadUIImages] Image at index %ld is nil", (long)idx);
            dispatch_sync(stateQueue, ^{
                if (!firstError) {
                    firstError = [self pp_uploadErrorWithCode:402
                                                   description:[NSString stringWithFormat:@"Image at index %ld is empty.", (long)idx]];
                }
            });
            continue;
        }

        NSLog(@"⬆️ [uploadUIImages] Uploading image %ld/%lu",
              (long)(idx + 1), (unsigned long)normalizedImages.count);

        dispatch_group_enter(group);

        NSData *data = UIImageJPEGRepresentation(img, 0.75);
        if (!data) {
            NSLog(@"❌ [uploadUIImages] Failed to encode image at index %ld", (long)idx);
            dispatch_sync(stateQueue, ^{
                if (!firstError) {
                    firstError = [self pp_uploadErrorWithCode:403
                                                   description:[NSString stringWithFormat:@"Failed to encode image at index %ld.", (long)idx]];
                }
            });
            dispatch_group_leave(group);
            continue;
        }

        NSString *fileName = [self pp_storageFileNameForAdID:ad.adID index:idx];

        FIRStorageReference *ref =
        [rootRef child:[NSString stringWithFormat:@"pet_ads/%@/%@", ad.adID, fileName]];

        FIRStorageUploadTask *uploadTask =
            [ref putData:data metadata:nil completion:^(FIRStorageMetadata *meta, NSError *error) {

            if (error) {
                NSLog(@"❌ [uploadUIImages] Upload failed idx=%ld | %@",
                      (long)idx, error.localizedDescription);
                dispatch_sync(stateQueue, ^{
                    if (!firstError) {
                        firstError = error;
                    }
                    progressByIndex[@(idx)] = @(1.0);
                });
                __block CGFloat overallProgress = 0.0;
                dispatch_sync(stateQueue, ^{
                    double total = 0.0;
                    for (NSNumber *value in progressByIndex.allValues) {
                        total += value.doubleValue;
                    }
                    overallProgress = (CGFloat)(total / (double)normalizedImages.count);
                });
                [self pp_updateCircularUploadProgress:overallProgress];
                dispatch_group_leave(group);
                return;
            }

            NSLog(@"✅ [uploadUIImages] Upload success idx=%ld", (long)idx);

            [ref downloadURLWithCompletion:^(NSURL *url, NSError *error2) {

                if (!url) {
                    NSLog(@"❌ [uploadUIImages] URL fetch failed idx=%ld | %@",
                          (long)idx, error2.localizedDescription);
                    dispatch_sync(stateQueue, ^{
                        if (!firstError) {
                            firstError = error2 ?: [self pp_uploadErrorWithCode:404 description:@"Failed to fetch uploaded image URL."];
                        }
                    });
                    dispatch_group_leave(group);
                    return;
                }

                NSLog(@"🔗 [uploadUIImages] Got download URL idx=%ld", (long)idx);

                // 🔥 BlurHash generation happens HERE
                [PPBlurHashGenerator generateBlurHashFromImage:img
                                                     completion:^(NSString *hash) {

                    NSLog(@"🎨 [uploadUIImages] BlurHash generated idx=%ld | %@",
                          (long)idx, hash.length > 0 ? @"YES" : @"NO");

                    PetImageItem *item =
                    [PetImageItem itemWithURL:url.absoluteString
                                        width:img.size.width
                                       height:img.size.height
                                     blurHash:hash];

                    dispatch_sync(stateQueue, ^{
                        items[idx] = item ?: [NSNull null];
                        progressByIndex[@(idx)] = @(1.0);
                    });

                    __block CGFloat overallProgress = 0.0;
                    dispatch_sync(stateQueue, ^{
                        double total = 0.0;
                        for (NSNumber *value in progressByIndex.allValues) {
                            total += value.doubleValue;
                        }
                        overallProgress = (CGFloat)(total / (double)normalizedImages.count);
                    });
                    [self pp_updateCircularUploadProgress:overallProgress];

                    NSLog(@"📦 [uploadUIImages] ImageItem ready idx=%ld", (long)idx);

                    dispatch_group_leave(group);
                }];
            }];
        }];

        [uploadTask observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot) {
            NSProgress *taskProgress = snapshot.progress;
            if (!taskProgress) {
                return;
            }
            double current = 0.0;
            if (taskProgress.totalUnitCount > 0) {
                current = (double)taskProgress.completedUnitCount / (double)taskProgress.totalUnitCount;
            }
            current = MIN(1.0, MAX(0.0, current));

            __block CGFloat overallProgress = 0.0;
            dispatch_sync(stateQueue, ^{
                progressByIndex[@(idx)] = @(current);
                double total = 0.0;
                for (NSNumber *value in progressByIndex.allValues) {
                    total += value.doubleValue;
                }
                overallProgress = (CGFloat)(total / (double)normalizedImages.count);
            });
            [self pp_updateCircularUploadProgress:overallProgress];
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        NSMutableArray<PetImageItem *> *finalItems = [NSMutableArray array];
        for (id obj in [items copy]) {
            if ([obj isKindOfClass:PetImageItem.class]) {
                [finalItems addObject:obj];
            }
        }

        NSLog(@"🏁 [uploadUIImages] FINISHED | validItems=%lu",
              (unsigned long)finalItems.count);

        if (firstError) {
            if (completion) completion(nil, firstError);
            return;
        }

        if (finalItems.count != normalizedImages.count) {
            if (completion) completion(nil, [self pp_uploadErrorWithCode:405
                                                             description:@"Not all images were uploaded successfully."]);
            return;
        }

        // 🔑 SINGLE SOURCE OF TRUTH
        self.finalImageItems = finalItems;
        ad.imageItems = finalItems;
        [self pp_reloadMediaUI];
        [self pp_updateCircularUploadProgress:1.0];

        NSLog(@"🧠 [uploadUIImages] Assigned imageItems to adID=%@",
              ad.adID);

        // ✅ Upload finished — images are now on the model
        if (completion) completion(ad, nil);
    });
}

- (NSString *)pp_storageFileNameForAdID:(NSString *)adID index:(NSInteger)index
{
    NSString *safeAdID = adID.length ? adID : @"ad";
    NSString *token = [NSUUID.UUID.UUIDString lowercaseString];
    return [NSString stringWithFormat:@"%@_%03ld_%@.jpg", safeAdID, (long)index, token];
}

#pragma mark - Cleanup

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    NSLog(@"[PPImages] viewWillDisappear - preserving media state");
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (NSString *)draftStorageKey
{
    NSString *currentUserID = PPSafeString(UserManager.sharedManager.currentUser.ID);
    if (self.mode == AdEditorModeEdit && self.editingAd.adID.length) {
        return [NSString stringWithFormat:@"%@.edit.%@.%@",
                PPAddNewAdDraftDefaultsPrefix,
                self.editingAd.adID,
                currentUserID];
    }

    NSInteger kindID = self.selectedMainKind.ID > 0 ? self.selectedMainKind.ID : self.selectedKind.ID;
    return [NSString stringWithFormat:@"%@.create.%ld.%@",
            PPAddNewAdDraftDefaultsPrefix,
            (long)kindID,
            currentUserID];
}

- (NSString *)draftDirectoryPath
{
    NSString *draftID = [[[self draftStorageKey]
                          stringByReplacingOccurrencesOfString:@"." withString:@"_"]
                         stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"pp_form_drafts"];
    return [root stringByAppendingPathComponent:draftID];
}

- (BOOL)hasSavedDraft
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]] isKindOfClass:NSDictionary.class];
}

- (NSData *)archivedDraftDataForObject:(id)object
{
    if (!object) return nil;

    if (@available(iOS 11.0, *)) {
        return [NSKeyedArchiver archivedDataWithRootObject:object
                                     requiringSecureCoding:NO
                                                     error:nil];
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedArchiver archivedDataWithRootObject:object];
#pragma clang diagnostic pop
}

- (id)unarchivedDraftObjectFromData:(NSData *)data
{
    if (![data isKindOfClass:NSData.class] || data.length == 0) return nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
}

- (NSDictionary *)draftFormDataSnapshot
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];

    NSString *title = [PPSafeString(self.titleRow.value) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length) {
        snapshot[@"adTitle"] = title;
    }

    MainKindsModel *mainKind = self.selectedMainKind;
    if (!mainKind && [self.categoryRow.value isKindOfClass:MainKindsModel.class]) {
        mainKind = (MainKindsModel *)self.categoryRow.value;
    }
    if (!mainKind) {
        mainKind = self.selectedKind;
    }
    if (mainKind.ID > 0) {
        snapshot[@"categoryID"] = @(mainKind.ID);
    }

    SubKindModel *subKind = [self.subcategoryRow.value isKindOfClass:SubKindModel.class]
        ? (SubKindModel *)self.subcategoryRow.value
        : nil;
    if (subKind.ID > 0) {
        snapshot[@"subcategoryID"] = @(subKind.ID);
    }

    snapshot[@"isFemale"] = @(self.adModel.isFemale);

    if ([self.petAgeRow.value respondsToSelector:@selector(integerValue)]) {
        NSInteger age = [self.petAgeRow.value integerValue];
        if (age > 0) {
            snapshot[@"petAgeMonths"] = @(age);
        }
    }

    if ([self.priceRow.value respondsToSelector:@selector(integerValue)]) {
        NSInteger price = [self.priceRow.value integerValue];
        if (price > 0) {
            snapshot[@"price"] = @(price);
        }
    }

    NSString *desc = [PPSafeString(self.descRow.value) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (desc.length) {
        snapshot[@"desc"] = desc;
    }

    NSString *locationName = PPSafeString(self.selectedAdLocationName.length ? self.selectedAdLocationName : self.adLocationRow.value);
    if (locationName.length) {
        snapshot[@"locationName"] = locationName;
    }

    if (self.hasSelectedAdCoordinate && PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        snapshot[@"latitude"] = @(self.selectedAdCoordinate.latitude);
        snapshot[@"longitude"] = @(self.selectedAdCoordinate.longitude);
    }

    snapshot[PPAddNewAdDraftMediaMutatedKey] = @(self.didMutateMediaAfterPrefill);
    return snapshot.copy;
}

- (NSString *)writeDraftImage:(UIImage *)image
                        named:(NSString *)fileName
                    directory:(NSString *)directory
{
    if (!image || fileName.length == 0 || directory.length == 0) return nil;

    NSData *imageData = UIImageJPEGRepresentation(image, 0.88);
    if (!imageData) {
        imageData = UIImagePNGRepresentation(image);
    }
    if (!imageData) return nil;

    NSString *path = [directory stringByAppendingPathComponent:fileName];
    return [imageData writeToFile:path atomically:YES] ? path : nil;
}

- (NSArray<NSString *> *)writeDraftImages:(NSArray<UIImage *> *)images
                               withPrefix:(NSString *)prefix
                                directory:(NSString *)directory
{
    if (images.count == 0) return @[];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
        (void)stop;
        NSString *fileName = [NSString stringWithFormat:@"%@_%lu.jpg",
                              prefix,
                              (unsigned long)idx];
        NSString *path = [self writeDraftImage:image named:fileName directory:directory];
        if (path.length) {
            [paths addObject:path];
        }
    }];

    return paths.copy;
}

- (NSArray<UIImage *> *)imagesFromDraftPaths:(NSArray<NSString *> *)paths
{
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    for (NSString *path in paths) {
        if (![path isKindOfClass:NSString.class] || path.length == 0) continue;
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            [images addObject:image];
        }
    }
    return images.copy;
}

- (void)clearSavedDraft
{
    [[NSFileManager defaultManager] removeItemAtPath:[self draftDirectoryPath] error:nil];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs removeObjectForKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)saveDraftForLater
{
    NSDictionary *snapshot = [self draftFormDataSnapshot];
    NSData *archivedForm = [self archivedDraftDataForObject:snapshot];
    if (!archivedForm) return;

    NSString *directory = [self draftDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:directory error:nil];
    [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray<NSString *> *imagePaths = [self writeDraftImages:[self.imageCollection allImages]
                                                  withPrefix:@"media"
                                                   directory:directory];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[PPAddNewAdDraftFormDataKey] = archivedForm;
    payload[PPAddNewAdDraftImagePathsKey] = imagePaths ?: @[];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:payload.copy forKey:[self draftStorageKey]];
    [prefs synchronize];
}

- (void)applyDraftValue:(id)value
               toRowTag:(NSString *)tag
           triggerBlock:(BOOL)triggerBlock
{
    XLFormRowDescriptor *row = [self.form formRowWithTag:tag];
    if (!row || !value || value == [NSNull null]) return;

    id oldValue = row.value;
    row.value = value;
    [self updateFormRow:row];

    if (triggerBlock && row.onChangeBlock) {
        row.onChangeBlock(oldValue, value, row);
    }
}

- (BOOL)restoreDraftIfNeeded
{
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:[self draftStorageKey]];
    if (![payload isKindOfClass:NSDictionary.class]) {
        return NO;
    }

    NSDictionary *storedValues = [self unarchivedDraftObjectFromData:payload[PPAddNewAdDraftFormDataKey]];
    if (![storedValues isKindOfClass:NSDictionary.class]) {
        [self clearSavedDraft];
        return NO;
    }

    self.isHydratingFormData = YES;

    NSString *title = PPSafeString(storedValues[@"adTitle"]);
    if (title.length) {
        [self applyDraftValue:title toRowTag:@"adTitle" triggerBlock:YES];
    }

    MainKindsModel *mainKind = self.selectedMainKind;
    NSNumber *mainKindID = storedValues[@"categoryID"];
    if (!mainKind && [mainKindID respondsToSelector:@selector(integerValue)]) {
        mainKind = [MKM mainKindForID:mainKindID.integerValue];
    }

    if (mainKind) {
        self.selectedKind = mainKind;
        self.adModel.category = mainKind.ID;
        if (!self.selectedMainKind) {
            [self applyDraftValue:mainKind toRowTag:kcategory triggerBlock:YES];
        }
        self.subcategoryRow.disabled = @NO;
        self.subcategoryRow.selectorOptions = mainKind.SubKindsArray ?: @[];
        [self updateFormRow:self.subcategoryRow];
    }

    NSNumber *subKindID = storedValues[@"subcategoryID"];
    if ([subKindID respondsToSelector:@selector(integerValue)] && self.selectedKind) {
        SubKindModel *subKind = nil;
        for (SubKindModel *candidate in self.selectedKind.SubKindsArray) {
            if (candidate.ID == subKindID.integerValue) {
                subKind = candidate;
                break;
            }
        }
        if (subKind) {
            [self applyDraftValue:subKind toRowTag:ksubcategory triggerBlock:YES];
        }
    }

    if (storedValues[@"isFemale"] != nil) {
        [self applyDraftValue:@([storedValues[@"isFemale"] boolValue]) toRowTag:@"isFemale" triggerBlock:YES];
    }

    if ([storedValues[@"petAgeMonths"] respondsToSelector:@selector(integerValue)]) {
        [self applyDraftValue:storedValues[@"petAgeMonths"] toRowTag:kpetAge triggerBlock:YES];
    }

    if ([storedValues[@"price"] respondsToSelector:@selector(integerValue)]) {
        [self applyDraftValue:storedValues[@"price"] toRowTag:kprice triggerBlock:YES];
    }

    NSString *desc = PPSafeString(storedValues[@"desc"]);
    if (desc.length) {
        [self applyDraftValue:desc toRowTag:kdesc triggerBlock:YES];
    }

    NSString *locationName = PPSafeString(storedValues[@"locationName"]);
    NSNumber *latitude = storedValues[@"latitude"];
    NSNumber *longitude = storedValues[@"longitude"];
    if (locationName.length) {
        self.selectedAdLocationName = locationName;
        self.adModel.locationName = locationName;
        [self applyDraftValue:locationName toRowTag:kadLocation triggerBlock:NO];
    }
    if ([latitude respondsToSelector:@selector(doubleValue)] &&
        [longitude respondsToSelector:@selector(doubleValue)]) {
        CLLocationCoordinate2D coordinate =
        CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
        if (PPIsValidAdCoordinate(coordinate)) {
            self.selectedAdCoordinate = coordinate;
            self.hasSelectedAdCoordinate = YES;
            self.adModel.latitude = coordinate.latitude;
            self.adModel.longitude = coordinate.longitude;
        }
    }

    NSArray<UIImage *> *draftImages = [self imagesFromDraftPaths:payload[PPAddNewAdDraftImagePathsKey]];
    self.isHydratingMedia = YES;
    [self.imageCollection clearAllImages];
    if (draftImages.count > 0) {
        [self.imageCollection addImages:draftImages];
    }
    self.isHydratingMedia = NO;

    self.didMutateMediaAfterPrefill = [storedValues[PPAddNewAdDraftMediaMutatedKey] boolValue];
    self.hasUserModifiedForm = NO;
    self.isHydratingFormData = NO;
    [self.tableView reloadData];
    return YES;
}

- (BOOL)pp_shouldPromptForDraftOptions
{
    return self.hasUserModifiedForm || [self hasSavedDraft];
}

- (void)pp_dismissForm
{
    BOOL isRootOfPresentedNav = (self.navigationController.presentingViewController != nil &&
                                 self.navigationController.viewControllers.firstObject == self);
    if (isRootOfPresentedNav) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    [self.navigationController popViewControllerAnimated:YES];
}

- (void)presentUnsavedChangesPrompt
{
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showThreeActionConfirmationIn:self
                                           title:kLang(@"form_draft_prompt_title")
                                        subtitle:kLang(@"form_draft_prompt_message")
                                   primaryButton:kLang(@"form_draft_save_and_close")
                                    primaryStyle:UIAlertActionStyleDefault
                                 secondaryButton:kLang(@"form_draft_discard")
                                  secondaryStyle:UIAlertActionStyleDestructive
                                  tertiaryButton:kLang(@"form_draft_keep_editing")
                                   tertiaryStyle:UIAlertActionStyleCancel
                                    primaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf saveDraftForLater];
        [strongSelf pp_dismissForm];
    } secondaryBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf clearSavedDraft];
        [strongSelf pp_dismissForm];
    } tertiaryBlock:^{
    }];
}

- (void)pp_handleBackNavigation
{
    if (self.isSubmittingAd) {
        return;
    }

    [self.view endEditing:YES];
    if ([self pp_shouldPromptForDraftOptions]) {
        [self presentUnsavedChangesPrompt];
        return;
    }

    [self pp_dismissForm];
}



























- (void)forceLTRRecursively:(UIView *)view {
    view.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    for (UIView *sub in view.subviews) {
        [self forceLTRRecursively:sub];
    }
}
- (void)setupImageCollection {
    self.imageCollection =
        [[PPImageCollection alloc] initWithFrame:CGRectZero
                                   maxImageCount:8
                                       useArabic:Language.isRTL];
    self.imageCollection.delegate = self;
    self.imageCollection.allowsEditing = YES;
    self.imageCollection.useArabic = Language.isRTL;
    [self pp_refreshMediaLocalizedText];

    [self.view addSubview:self.imageCollection];
    self.imageCollection.translatesAutoresizingMaskIntoConstraints = NO;

     float height = 140;

    [NSLayoutConstraint activateConstraints:@[
        [self.imageCollection.topAnchor constraintEqualToAnchor:self.tableView.bottomAnchor constant:14],
        [self.imageCollection.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.imageCollection.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.imageCollection.heightAnchor constraintEqualToConstant:height]
    ]];

    self.tableView.scrollEnabled = NO;
    self.tableView.backgroundColor = AppBackgroundClr;
}

- (void)pp_presentAdLocationPickerForRow:(XLFormRowDescriptor *)row
{
    LocationPickerViewController *picker = [[LocationPickerViewController alloc] init];
    if (self.hasSelectedAdCoordinate && PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        picker.initialCoordinate = self.selectedAdCoordinate;
    }
    __weak typeof(self) weakSelf = self;
    void (^applyCoordinate)(CLLocationCoordinate2D, NSString *) =
    ^(CLLocationCoordinate2D coordinate, NSString *title) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !PPIsValidAdCoordinate(coordinate)) {
            return;
        }
        self.selectedAdCoordinate = coordinate;
        self.hasSelectedAdCoordinate = YES;
        self.selectedAdLocationName = PPSafeString(title);
        if (self.selectedAdLocationName.length == 0) {
            self.selectedAdLocationName = [NSString stringWithFormat:@"%.6f, %.6f",
                                           coordinate.latitude, coordinate.longitude];
        }
        self.adModel.latitude = coordinate.latitude;
        self.adModel.longitude = coordinate.longitude;
        self.adModel.locationName = self.selectedAdLocationName;

        row.value = self.selectedAdLocationName.length
            ? self.selectedAdLocationName
            : kLang(@"select_location");
        [self updateFormRow:row];
        if (!self.isHydratingFormData) {
            self.hasUserModifiedForm = YES;
        }
    };
    picker.onLocationConfirmed = ^(GMSAddress *gmsAddress) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !gmsAddress) return;

        CLLocationCoordinate2D coordinate = gmsAddress.coordinate;
        if (!PPIsValidAdCoordinate(coordinate)) {
            [PPAlertHelper showErrorIn:self
                                 title:kLang(@"Location")
                              subtitle:kLang(@"Please choose a valid location from the map.")];
            return;
        }

        NSString *resolvedTitle = [LocationPickerViewController titleFromAddress:gmsAddress];
        if (resolvedTitle.length == 0 && gmsAddress.country.length > 0) {
            resolvedTitle = gmsAddress.country;
        }
        applyCoordinate(coordinate, resolvedTitle);
    };
    picker.onCoordinateConfirmed = ^(CLLocationCoordinate2D coordinate, NSString *locationTitle) {
        applyCoordinate(coordinate, locationTitle);
    };
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)didSelectFormRow:(XLFormRowDescriptor *)formRow
{
    if ([formRow.tagM isEqualToString:kadLocation]) {
        NSIndexPath *indexPath = [self.form indexPathOfFormRow:formRow];
        if (indexPath) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        [self pp_presentAdLocationPickerForRow:formRow];
        return;
    }
    [super didSelectFormRow:formRow];
}
 

// Removed didHighlightItemAtIndexPath to fix out-of-bounds and confusion with image index.

- (void)initBase {
    self.uploadManager = [FileUploadManager new];
    self.mform = [XLFormDescriptor formDescriptorWithTitle:@""];
    self.selectedAdCoordinate = kCLLocationCoordinate2DInvalid;
    self.hasSelectedAdCoordinate = NO;
    self.selectedAdLocationName = nil;
    
    
    // default is Create
    if (self.mode == AdEditorModeCreate) {
        self.mode = AdEditorModeCreate;
        self.adModel = [PetAd new];
    } else {
        if (self.editingAd) {
            self.adModel =
            [[PetAd alloc] initWithDictionary:[self.editingAd toFirestoreDictionary]
                                    documentID:self.editingAd.adID];
            self.adModel.adID = self.editingAd.adID;
            self.adModel.ownerID = self.editingAd.ownerID;
            self.adModel.postedDate = self.editingAd.postedDate;
            if (self.adModel.status == 0) {
                self.adModel.status = self.editingAd.status;
            }
        } else {
            self.adModel = [PetAd new];
        }
    }
    
}

#pragma mark - Build Form
- (void)initForm {
   
    
    __weak typeof(self) weakSelf = self;
    XLFormSectionDescriptor *section;
    float rowHeight = 48;
    // 🐾 Section 2: Basic Info
    section = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"basicInfoSection")];
    
    // Title
    self.titleRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"adTitle"
                                                                          rowType:XLFormRowDescriptorTypeText
                                                                            title:kLang(@"adTitle")];
    [self.titleRow.cellConfigAtConfigure setObject:kLang(@"enter_title") forKey:@"textField.placeholder"];
    self.titleRow.required = YES;
    self.titleRow.height = rowHeight;
    self.titleRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.adModel.adTitle = newValue;
    };
    [section addFormRow:self.titleRow];
    
    // Category
    self.categoryRow = [XLFormRowDescriptor formRowDescriptorWithTag:kcategory
                                                             rowType:XLFormRowDescriptorTypeSelectorPush
                                                               title:kLang(@"Species")];
    // Category (conditionally hidden)
    if (self.selectedMainKind) {
        weakSelf.selectedKind = self.selectedMainKind;
        weakSelf.adModel.category = self.selectedMainKind.ID;
        
        // ✅ Directly populate subcategories for selected category
        self.subcategoryRow = [XLFormRowDescriptor formRowDescriptorWithTag:ksubcategory
                                                                    rowType:XLFormRowDescriptorTypeSelectorPush
                                                                      title:kLang(@"Breed")];
        self.subcategoryRow.required = YES;
        self.subcategoryRow.height = rowHeight;
        self.subcategoryRow.disabled = @NO;
        self.subcategoryRow.selectorOptions = self.selectedMainKind.SubKindsArray ?: @[];
        self.subcategoryRow.selectorTitle = nil;
        self.subcategoryRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
            if (![newValue isKindOfClass:[SubKindModel class]]) return;
            SubKindModel *sub = newValue;
            weakSelf.adModel.subcategory = sub.ID;
        };
        [section addFormRow:self.subcategoryRow];
    } else {
        // Normal Category selection
        self.categoryRow = [XLFormRowDescriptor formRowDescriptorWithTag:kcategory
                                                                 rowType:XLFormRowDescriptorTypeSelectorPush
                                                                   title:kLang(@"Species")];
        self.categoryRow.required = YES;
        self.categoryRow.height = rowHeight;
        self.categoryRow.selectorOptions = MKM.MainKindsArray;
        self.categoryRow.selectorTitle = kLang(@"Species");
        self.categoryRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
            if (![newValue isKindOfClass:[MainKindsModel class]]) {
                weakSelf.selectedKind = nil;
                weakSelf.adModel.category = 0;
                weakSelf.subcategoryRow.disabled = @YES;
                weakSelf.subcategoryRow.selectorOptions = @[];
                [weakSelf updateFormRow:weakSelf.subcategoryRow];
                return;
            }
            MainKindsModel *kind = newValue;
            weakSelf.selectedKind = kind;
            weakSelf.adModel.category = kind.ID;
            weakSelf.subcategoryRow.disabled = @NO;
            weakSelf.subcategoryRow.selectorOptions = kind.SubKindsArray ?: @[];
            [weakSelf updateFormRow:weakSelf.subcategoryRow];
        };
        [section addFormRow:self.categoryRow];
        
        // Subcategory (disabled until category picked)
        self.subcategoryRow = [XLFormRowDescriptor formRowDescriptorWithTag:ksubcategory
                                                                    rowType:XLFormRowDescriptorTypeSelectorPush
                                                                      title:kLang(@"Breed")];
        self.subcategoryRow.required = YES;
        self.subcategoryRow.height = rowHeight;
        self.subcategoryRow.disabled = @YES;
        self.subcategoryRow.selectorTitle = kLang(@"Breed");
        self.subcategoryRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
            if (![newValue isKindOfClass:[SubKindModel class]]) return;
            SubKindModel *sub = newValue;
            weakSelf.adModel.subcategory = sub.ID;
        };
        [section addFormRow:self.subcategoryRow];
    }
    
    [self.mform addFormSection:section];
    
    // 📝 Section 3: Description
    section = [XLFormSectionDescriptor formSectionWithTitle:kLang(@"")];
    // Gender
    XLFormRowDescriptor *genderRow = [XLFormRowDescriptor formRowDescriptorWithTag:@"isFemale"
                                                                           rowType:XLFormRowDescriptorTypeBooleanSwitch
                                                                             title:kLang(@"isFemale")];
    genderRow.value = @(weakSelf.adModel.isFemale);
    genderRow.height = rowHeight;
    genderRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.adModel.isFemale = [newValue boolValue];
    };
    [section addFormRow:genderRow];
    
    // Pet Age
    self.petAgeRow = [XLFormRowDescriptor formRowDescriptorWithTag:kpetAge
                                                           rowType:XLFormRowDescriptorTypeInteger
                                                             title:kLang(@"age_months")];
    [self.petAgeRow.cellConfigAtConfigure setObject:kLang(@"enter_pet_age_in_months") forKey:@"textField.placeholder"];
    self.petAgeRow.required = YES;
    self.petAgeRow.height = rowHeight;
    self.petAgeRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
    
        weakSelf.adModel.petAgeMonths = newValue;
    };
    [section addFormRow:self.petAgeRow];
    
    // Price
    self.priceRow = [XLFormRowDescriptor formRowDescriptorWithTag:kprice
                                                          rowType:XLFormRowDescriptorTypeInteger
                                                            title:kLang(@"price")];
    [self.priceRow.cellConfigAtConfigure setObject:kLang(@"enter_price") forKey:@"textField.placeholder"];
    self.priceRow.required = YES;
    self.priceRow.height = rowHeight;
    self.priceRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        
         weakSelf.adModel.price = newValue;
    };
    [section addFormRow:self.priceRow];
    
    // Location
    self.adLocationRow = [XLFormRowDescriptor formRowDescriptorWithTag:kadLocation
                                                               rowType:XLFormRowDescriptorTypeSelectorPush
                                                                 title:kLang(@"adLocation")];
    self.adLocationRow.selectorTitle = kLang(@"select_location");
    self.adLocationRow.noValueDisplayText = kLang(@"select_location");
    self.adLocationRow.required = YES;
    self.adLocationRow.height = rowHeight + 6;

    self.adLocationRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        if (newValue && [newValue isKindOfClass:NSString.class]) {
            weakSelf.adModel.locationName = (NSString *)newValue;
        }
    };
    [section addFormRow:self.adLocationRow];
    
    // Description
    self.descRow = [XLFormRowDescriptor formRowDescriptorWithTag:kdesc
                                                         rowType:XLFormRowDescriptorTypeTextView
                                                           title:nil];
    [self.descRow.cellConfigAtConfigure setObject:kLang(@"enter_description") forKey:@"textView.placeholder"];
    self.descRow.height = 70;
    self.descRow.required = YES;
    self.descRow.onChangeBlock = ^(id oldValue, id newValue, XLFormRowDescriptor *row) {
        weakSelf.adModel.adDescription = newValue;
    };
    [section addFormRow:self.descRow];
    [self.mform addFormSection:section];
    
    // ✅ Assign
    self.form = self.mform;
    
    self.tableView.estimatedSectionFooterHeight = 10;
    self.tableView.sectionFooterHeight = 10;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

#pragma mark - Prefill when Editing

- (void)configureForEditingIfNeeded {
    if (self.mode != AdEditorModeEdit || !self.editingAd) return;
    
    // Use the passed model as source-of-truth
    //self.adModel = self.editingAd;
    self.adModel =
    [[PetAd alloc] initWithDictionary:[self.editingAd toFirestoreDictionary]
                            documentID:self.editingAd.adID];
    // 🔒 Protect immutable fields
    self.adModel.adID = self.editingAd.adID;
    self.adModel.ownerID = self.editingAd.ownerID;
    self.adModel.postedDate = self.editingAd.postedDate;

    // Editing does NOT reset status unless explicitly changed
    if (self.adModel.status == 0) {
        self.adModel.status = self.editingAd.status;
    }
    
    // Prefill category + subcategory
    MainKindsModel *kind = [MKM mainKindForID:self.adModel.category];
    if (kind) {
        self.selectedKind = kind;
        self.categoryRow.value = kind;
        self.subcategoryRow.disabled = @NO;
        self.subcategoryRow.selectorOptions = kind.SubKindsArray;
        
        SubKindModel *sub = [kind subKindForID:self.adModel.subcategory];
        if (!sub) {
            // fallback: find in array by ID
            for (SubKindModel *s in kind.SubKindsArray) if (s.ID == self.adModel.subcategory) { sub = s; break; }
        }
        self.subcategoryRow.value = sub;
        [self updateFormRow:self.categoryRow];
        [self updateFormRow:self.subcategoryRow];
    }
    
    // Prefill scalar fields
    self.petAgeRow.value = self.adModel.petAgeMonths;
    self.priceRow.value  = self.adModel.price;
    self.descRow.value   = self.adModel.adDescription;
    self.titleRow.value   = self.adModel.adTitle;
    NSString *prefillLocation = self.adModel.locationName;
    if (prefillLocation.length == 0 && self.adModel.adLocation > 0) {
        prefillLocation = [CitiesManager.shared cityNameForID:self.adModel.adLocation];
    }
    self.adLocationRow.value = prefillLocation;
    self.selectedAdLocationName = prefillLocation;
    self.selectedAdCoordinate = CLLocationCoordinate2DMake(self.adModel.latitude, self.adModel.longitude);
    self.hasSelectedAdCoordinate = PPIsValidAdCoordinate(self.selectedAdCoordinate);
    
    [self updateFormRow:self.petAgeRow];
    [self updateFormRow:self.priceRow];
    [self updateFormRow:self.descRow];
    [self updateFormRow:self.adLocationRow];
    
    self.didMutateMediaAfterPrefill = NO;
    [self pp_setSubmitEnabled:NO];
    [self prefillPhotosForEdit];
    
}
//self.assetArray
- (void)showPopupPreview:(UIImage *)image {
    
}


#pragma mark - Search Metadata

- (void)prepareSearchMetadataForAd:(PetAd *)ad {

    // Title lowercase index
    ad.name_lowercase = ad.adTitle.lowercaseString ?: @"";

    // Keywords (very important)
    NSMutableSet *keys = [NSMutableSet set];

    if (ad.adTitle.length) {
        [[ad.adTitle.lowercaseString componentsSeparatedByCharactersInSet:
          NSCharacterSet.whitespaceAndNewlineCharacterSet]
         enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if (obj.length > 1) [keys addObject:obj];
        }];
    }
    
    
    if (self.subcategoryRow.value &&
        [self.subcategoryRow.value respondsToSelector:@selector(SubKindName)]) {

        NSString *sub =
        [[self.subcategoryRow.value SubKindName] lowercaseString];
        if (sub.length) [keys addObject:sub];
    }
    
    

    if (self.selectedKind.KindName.length) {
        [keys addObject:self.selectedKind.KindName.lowercaseString];
    }

    ad.keywords = keys.allObjects;
}

- (void)setBackAndCorners
{
    self.view.layer.cornerRadius = 25;
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.tableView.backgroundColor = AppBackgroundClrLigter;
    self.tableView.layer.cornerRadius = 25;
    self.tableView.clipsToBounds = YES;
}


-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.view sendSubviewToBack:self.tableView];
    self.tableView.alpha = 1;
    //self.photoView.backgroundColor = UIColor.systemMintColor;
     

}

- (void)saveFormData:(UIBarButtonItem *)sender {
    if (self.isSubmittingAd) {
        return;
    }

    if (self.mode == AdEditorModeEdit && self.isPrefillInProgress) {
        NSString *title = [self pp_localizedStringForKey:@"loading_images" fallback:@"Loading images..."];
        NSString *subtitle = [self pp_localizedStringForKey:@"please_wait_prefill"
                                                    fallback:@"Please wait until images finish loading."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    if (self.mode == AdEditorModeEdit) {
        [self updateAdFlow];
    } else {
        [self createAdFlow];
    }
    
}


#pragma mark - Submit flows
#pragma mark - Unified Submit Handler
- (void)pp_handleAdSubmitIsEditing:(BOOL)isEditing {
    if (self.isSubmittingAd) {
        return;
    }
    [PPHUD dismiss];

    if (isEditing && self.isPrefillInProgress) {
        NSString *title = [self pp_localizedStringForKey:@"loading_images" fallback:@"Loading images..."];
        NSString *subtitle = [self pp_localizedStringForKey:@"please_wait_prefill"
                                                    fallback:@"Please wait until images finish loading."];
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return;
    }

    // 1️⃣ Validate user form
    NSArray *errors = [self formValidationErrors];
    if (errors.count > 0) {
        [self highlightErrors:errors];
        return;
    }

    if (!isEditing && ![self pp_validateCreateHasAtLeastOneImage]) {
        return;
    }

    if (![self pp_validateAdLocationBeforeSubmit]) {
        return;
    }
    
    // 2️⃣ Prepare the ad model
    if (!isEditing) {
        if (self.createFlowAdID.length == 0) {
            self.createFlowAdID = NSUUID.UUID.UUIDString;
        }
        self.adModel.adID = self.createFlowAdID;
        if (!self.adModel.postedDate) {
            self.adModel.postedDate = NSDate.date;
        }
        self.adModel.ownerID = [UserManager sharedManager].currentUser.ID;

        // 🔥 New production defaults
        self.adModel.status = PetAdStatusActive;
        self.adModel.visibility = PetAdVisibilityPublic;

        self.adModel.favoritesCount = @(0);
        self.adModel.sharesCount = @(0);

        self.adModel.rankScore = @(0);
        self.adModel.priorityScore = @(0);

        self.adModel.isMine = YES;
        self.adModel.isFavorite = NO;
        self.adModel.isApproved = YES;
        self.adModel.isDeleted = NO;
        self.adModel.isBlocked = NO;
    }

    [self prepareSearchMetadataForAd:self.adModel];
    
    // 3️⃣ Upload media + save on server
    [self sendFormDataToServerIsEditing:isEditing];
}
#pragma mark - Create / Update Entry Points
- (void)createAdFlow {
    [self pp_handleAdSubmitIsEditing:NO];
}

- (void)updateAdFlow {
    [self pp_handleAdSubmitIsEditing:YES];
}


- (void)highlightErrors:(NSArray *)errors {
    __block int errorCount = 0;
    [errors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        XLFormValidationStatus *status = [obj userInfo][XLValidationStatusErrorKey];
        if (!status) return;
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:status.rowDescriptor]];
        errorCount++;
        [GM animateCell:cell];
    }];
}

- (BOOL)pp_validateAdLocationBeforeSubmit
{
    if (!self.hasSelectedAdCoordinate || !PPIsValidAdCoordinate(self.selectedAdCoordinate)) {
        NSString *title = kLang(@"Location");
        NSString *subtitle = kLang(@"Please choose a valid location from the map.");
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        return NO;
    }

    self.adModel.latitude = self.selectedAdCoordinate.latitude;
    self.adModel.longitude = self.selectedAdCoordinate.longitude;
    self.adModel.locationName = self.selectedAdLocationName.length
        ? self.selectedAdLocationName
        : (self.adLocationRow.value ?: @"");

    return [self.adModel hasValidGeoLocation];
}


#pragma mark - Submit to Server (Refactored)
- (void)sendFormDataToServerIsEditing:(BOOL)isEditing
{
    NSArray<UIImage *> *imagesToUpload = [self safeMediaOutputArray];
    self.isSubmittingAd = YES;

    [self pp_showUploadIndicatorOnNavBar];
    [self pp_setCircularUploadProgressVisible:YES];
    [self pp_updateCircularUploadProgress:0.0];
    [self pp_setSubmitEnabled:NO];
    [self pp_setMediaLoadingVisible:YES textKey:@"uploading_images" fallback:@"Uploading images..."];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.form.disabled = YES;
        self.mform.disabled = YES;
        self.imageCollection.userInteractionEnabled = NO;
    });

    if (isEditing) {
        [self pp_updateExistingAdWithImages:imagesToUpload];
    } else {
        [self pp_createNewAdWithImages:imagesToUpload];
    }
}
- (void)pp_showUploadIndicatorOnNavBar
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.ppOriginalRightItem) {
            self.ppOriginalRightItem = self.navigationItem.rightBarButtonItem;
        }

        self.navigationItem.rightBarButtonItem =
            [self pp_uploadSpinnerBarItem];
    });
}


- (void)pp_createNewAdWithImages:(NSArray<UIImage *> *)images
{
    if (self.adModel.adID.length == 0) {
        [self pp_handleSubmitFailure:[self pp_uploadErrorWithCode:406 description:@"Missing adID before create flow."]];
        return;
    }

    // 🔒 IMPORTANT: Start with EMPTY imageItems
    self.adModel.imageItems = @[];

    [self uploadUIImages:images
                   forAd:self.adModel
               completion:^(PetAd *updatedAd, NSError *error)
    {
        if (error) {
            [self pp_handleSubmitFailure:error];
            return;
        }

        // 🔒 SINGLE SOURCE OF TRUTH
        [self prepareSearchMetadataForAd:updatedAd];
        [[PetAdManager sharedManager] addPetAd:updatedAd
                                    completion:^(NSError *error)
        {
            if (error) {
                [self pp_handleSubmitFailure:error];
                return;
            }
            self.adModel = updatedAd;
            [self pp_finishCreateSuccess];
        }];
    }];

    
}

- (void)pp_updateExistingAdWithImages:(NSArray<UIImage *> *)images
{
    
    NSArray *originalImageItems = self.editingAd.imageItems ?: @[];
    
    
    void (^performUpdate)(void) = ^{
        [self prepareSearchMetadataForAd:self.adModel];
        [[PetAdManager sharedManager] updatePetAd:self.adModel
                                       completion:^(NSError *error)
        {
            if (error) {
                NSLog(@"❌ [UpdateAd] Firestore update failed: %@", error);
                [self pp_handleSubmitFailure:error];
                return;
            }
            [self pp_finishUpdateSuccess];
        }];
    };

    if (!self.didMutateMediaAfterPrefill) {
        self.adModel.imageItems = originalImageItems;
        performUpdate();
        return;
    }
    
    
    // User changed media and removed all images.
    if (images.count == 0) {
        self.adModel.imageItems = @[];
        performUpdate();
        return;
    }

    // Upload images first
    [self uploadUIImages:images
                   forAd:self.adModel
               completion:^(PetAd *updatedAd, NSError *error)
    {
        if (error) {
            NSLog(@"❌ [UpdateAd] Image upload failed: %@", error);
            [self pp_handleSubmitFailure:error];
            return;
        }

        self.adModel = updatedAd;
        self.didMutateMediaAfterPrefill = NO;
        performUpdate();
    }];
}

- (void)pp_finishCreateSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.createFlowAdID = nil;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PPAdDidFinishUploadNotification
         object:nil
         userInfo:@{
            @"ad": self.adModel,
            @"isEditing": @(NO)
         }];

        if ([self.delegate respondsToSelector:@selector(addNewAd:didCreateAd:)]) {
            [self.delegate addNewAd:self didCreateAd:self.adModel];
        }

        [self clearSavedDraft];
        [self pp_finishSubmitUI];
        [self closeAfterSuccess:NO];
    });
}

- (void)pp_finishUpdateSuccess
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.didMutateMediaAfterPrefill = NO;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PPAdDidFinishUploadNotification
         object:nil
         userInfo:@{
            @"ad": self.adModel,
            @"isEditing": @(YES)
         }];

        if ([self.delegate respondsToSelector:@selector(addNewAd:didUpdateAd:)]) {
            [self.delegate addNewAd:self didUpdateAd:self.adModel];
        }

        [self clearSavedDraft];
        [self pp_finishSubmitUI];
        [self closeAfterSuccess:YES];
    });
}

- (void)pp_handleSubmitFailure:(NSError *)error
{
    NSString *title = [self pp_localizedStringForKey:@"error" fallback:@"Error"];
    NSString *fallbackSubtitle =
        [self pp_localizedStringForKey:@"submit_failed"
                              fallback:@"Unable to save your ad right now. Please try again."];
    NSString *subtitle = error.localizedDescription.length ? error.localizedDescription : fallbackSubtitle;
    dispatch_async(dispatch_get_main_queue(), ^{
        [PPAlertHelper showErrorIn:self title:title subtitle:subtitle];
        [self pp_finishSubmitUI];
    });
}






- (void)pp_hideUploadIndicatorOnNavBar
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.ppUploadSpinner stopAnimating];

        if (self.ppOriginalRightItem) {
            self.ppOriginalRightItem.enabled = (!self.isSubmittingAd && !self.isPrefillInProgress);
            self.navigationItem.rightBarButtonItem =
                self.ppOriginalRightItem;
        }

        self.ppOriginalRightItem = nil;
    });
}






- (void)pp_finishSubmitUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isSubmittingAd = NO;
        self.form.disabled = NO;
        self.mform.disabled = NO;
        self.imageCollection.userInteractionEnabled = !self.isPrefillInProgress;
        [self pp_setCircularUploadProgressVisible:NO];

        if (self.isPrefillInProgress) {
            [self pp_setMediaLoadingVisible:YES textKey:@"loading_images" fallback:@"Loading images..."];
        } else {
            [self pp_setMediaLoadingVisible:NO textKey:@"uploading_images" fallback:@"Uploading images..."];
        }

        [self pp_setSubmitEnabled:!self.isPrefillInProgress];

        [self pp_hideUploadIndicatorOnNavBar];
    });
}

- (void)closeAfterSuccess:(BOOL)isEditing {
    // Success alert
    NSString *title = isEditing
        ? [self pp_localizedStringForKey:@"adUpdatedTitle" fallback:@"Ad updated"]
        : [self pp_localizedStringForKey:@"adDoneTitle" fallback:@"Ad posted"];
    NSString *msg = isEditing
        ? [self pp_localizedStringForKey:@"adUpdatedDesc" fallback:@"Your ad was updated successfully."]
        : [self pp_localizedStringForKey:@"adDoneDesc" fallback:@"Your ad was posted successfully."];
    
    __weak typeof(self) weakSelf = self;
    [PPAlertHelper showSuccessIn:self title:title subtitle:msg confirmAction:^(NSString * _Nullable text, BOOL didConfirm) {
        if(!didConfirm) return;
        [weakSelf pp_dismissForm];
    } cancelAction:^{
        
    }];
   
    
}

#pragma mark - Close / nav

- (void)closeForm:(UIBarButtonItem *)sender {
    (void)sender;
    [self pp_handleBackNavigation];
}

- (void)onBack
{
    [self pp_handleBackNavigation];
}

- (void)onBack:(id)sender
{
    (void)sender;
    [self pp_handleBackNavigation];
}




#pragma mark - Progress bar host

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
   /*
    if (!self.uploadProgressView) {
        GSIndeterminateProgressView *pv = [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0,  self.navigationController.navigationBar.hx_maxy , self.view.hx_w, 4)];
        pv.progressTintColor = [GM appPrimaryColor];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        pv.backgroundColor = [PPColorUtils pp_selectedCellColorFromPrimary]; //UIColor.whiteColor;
        [self.view addSubview:pv];
        self.uploadProgressView = pv;
    }
    */
}

-(void)dismiss
{
    [self popoverPresentationController];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //[PPBarMgr hide];
    [self pp_refreshMediaLocalizedText];
    
    if(!self.presented)
    {
         self.presented=YES;
    }
    
   
    NSString *title = (self.mode == AdEditorModeEdit)? kLang(@"EditAdTitle")   : kLang(@"PostAdTitle");       // add to Localizable
    NSString *subKindName = nil;
    if (self.selectedMainKind) {  subKindName = [NSString stringWithFormat:@"%@",self.selectedMainKind.KindName]; }
 
    
     [self ios26Bar];
    [self pp_setSubmitEnabled:!self.isSubmittingAd && !self.isPrefillInProgress];
    
    UIView *topView = [self pp_modernBlurTitleViewWithTitle:title
                                                   subtitle:subKindName ?: nil];
    [self pp_navBarSetTitleViewCenteredSmallWidth:topView];
  
}

- (UIView *)pp_modernBlurTitleViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    NSString *safeTitle = title ?: @"";
    NSString *safeSubtitle = subtitle ?: @"";
    UIFont *titleFont = [GM boldFontWithSize:16];
    UIFont *subtitleFont = [GM MidFontWithSize:12];
    CGFloat maxWidth = MIN(UIScreen.mainScreen.bounds.size.width * 0.62, 240.0);

    CGFloat titleWidth =
    ceil([safeTitle boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                              attributes:@{NSFontAttributeName: titleFont}
                                 context:nil].size.width);

    CGFloat subtitleWidth = 0.0;
    if (safeSubtitle.length) {
        subtitleWidth =
        ceil([safeSubtitle boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                     attributes:@{NSFontAttributeName: subtitleFont}
                                        context:nil].size.width);
    }

    CGFloat width = MIN(MAX(MAX(titleWidth, subtitleWidth) + 36.0, 156.0), maxWidth);
    CGFloat height = safeSubtitle.length ? 50.0 : 42.0;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    container.backgroundColor = UIColor.clearColor;
    container.userInteractionEnabled = NO;
    container.semanticContentAttribute =
    Language.isRTL ? UISemanticContentAttributeForceRightToLeft
                   : UISemanticContentAttributeForceLeftToRight;

    CGFloat cornerRadius = height / 2.0;
    if (@available(iOS 13.0, *)) {
        UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        blurView.frame = container.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = cornerRadius;
        blurView.layer.masksToBounds = YES;
        [container addSubview:blurView];

        UIView *tintView = [[UIView alloc] initWithFrame:blurView.bounds];
        tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tintView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.08];
        [blurView.contentView addSubview:tintView];
    } else {
        container.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.12];
    }

    container.layer.cornerRadius = cornerRadius;
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:PPIOS26() ? 0.16 : 0.10].CGColor;
    container.layer.shadowColor = [AppShadowClr colorWithAlphaComponent:0.18].CGColor;
    container.layer.shadowOffset = CGSizeMake(0, 8);
    container.layer.shadowOpacity = 1.0;
    container.layer.shadowRadius = 18.0;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = safeSubtitle.length ? 1.0 : 0.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [container addSubview:stack];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = titleFont;
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    titleLabel.numberOfLines = 1;
    titleLabel.text = safeTitle;
    [stack addArrangedSubview:titleLabel];

    if (safeSubtitle.length) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.font = subtitleFont;
        subtitleLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.72];
        subtitleLabel.textAlignment = NSTextAlignmentCenter;
        subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitleLabel.numberOfLines = 1;
        subtitleLabel.text = safeSubtitle;
        [stack addArrangedSubview:subtitleLabel];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-16.0],
        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
    ]];

    return container;
}



- (UIView *)pp_navigationTitleViewWithTitle:(NSString *)title
                                   subtitle:(NSString * _Nullable)subtitle
                                   textColor:(UIColor * _Nullable)textColor
                                       image:(UIImage * _Nullable)image
                              showBackground:(BOOL)showBackground
{
    UIButtonConfiguration *cfg = nil;

    if (@available(iOS 26.0, *)) {
        // 🧊 Native iOS 26 glass button
        cfg = showBackground
            ? [UIButtonConfiguration glassButtonConfiguration]
            : [UIButtonConfiguration plainButtonConfiguration];

        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.buttonSize  = UIButtonConfigurationSizeMedium;

        cfg.baseForegroundColor = textColor ?: AppPrimaryTextClr;

        // Title
        cfg.title = title ?: @"";
        cfg.titleAlignment = UIButtonConfigurationTitleAlignmentCenter;

        cfg.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
            NSMutableDictionary *attrs = incoming.mutableCopy;
            attrs[NSFontAttributeName] = [GM boldFontWithSize:16];
            attrs[NSForegroundColorAttributeName] = textColor ?: AppPrimaryTextClr;
            return attrs;
        };

        // Subtitle (iOS 16+ supported)
        if (subtitle.length > 0) {
            cfg.subtitle = subtitle;
            cfg.subtitleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *incoming) {
                NSMutableDictionary *attrs = incoming.mutableCopy;
                attrs[NSFontAttributeName] = [GM MidFontWithSize:13];
                attrs[NSForegroundColorAttributeName] =
                [textColor ?: AppPrimaryTextClr colorWithAlphaComponent:0.75];
                return attrs;
            };
            cfg.titlePadding = 2;
        }

        // Leading icon
        if (image) {
            cfg.image = image;
            cfg.imagePlacement = NSDirectionalRectEdgeLeading;
            cfg.imagePadding = 6;
        }

        if (!showBackground) {
            cfg.background.backgroundColor =
                [UIColor.labelColor colorWithAlphaComponent:0.20];
        }
    }
    else {
        // 🧱 iOS ≤25 fallback (modern pill, blur)
        cfg = [UIButtonConfiguration filledButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseForegroundColor = textColor ?: AppPrimaryTextClr;
        cfg.title = title ?: @"";
        cfg.image = image;
    }

    UIButton *button =
        [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.clipsToBounds = YES;
    button.userInteractionEnabled = NO; // titleView behavior

    // Navigation title sizing (important!)
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:36]
    ]];

    return button;
}

-(void)ios26Bar
{
    //NSString *buttonTitle = (self.mode == AdEditorModeEdit) ? kLang(@"saveChanges") : kLang(@"postAd");
    //UIButton *saveBTN = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:@"checkmark" target:self action:@selector(saveFormData:)];
    UIBarButtonItem *saveBarButton = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(@"checkmark") style:UIBarButtonItemStylePlain target:self action:@selector(saveFormData:)];
    self.navigationItem.rightBarButtonItem = saveBarButton;
    
    //UIButton *backBTN = [PPButtonHelper pp_buttonWithTitleForBar:nil imageName:PPChevronName target:self action:@selector(onBack:)];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithImage:PPSYSImage(PPChevronName) style:UIBarButtonItemStylePlain target:self action:@selector(onBack:)];
    self.navigationItem.leftBarButtonItem = backBarButton;
    [self pp_setSubmitEnabled:!self.isSubmittingAd && !self.isPrefillInProgress];
}
- (XLFormRowDescriptor *)generateRawWithType:(NSString *)rowType
                                   inputType:(XLFormFullWidthTextFieldType)inputType
                                         tag:(NSString *)tag
                                       title:(NSString *)title
                                 placeholder:(NSString *)placeholder
                                    required:(BOOL)required
                                       value:(id)value
{
    XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:tag
                                                                     rowType:rowType
                                                                       title:title];
    [row.cellConfigAtConfigure setObject:placeholder forKey:@"textField.placeholder"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[GM MidFontWithSize:14] forKey:@"detailTextLabel.font"];
    [row.cellConfig setObject:AppPrimaryClr forKey:@"detailTextLabel.textColor"];
    [row.cellConfig setObject:AppPrimaryClr forKey:@"textField.textColor"];
    
    [row.cellConfig setObject:@(GM.setAligment) forKey:@"detailTextLabel.textAlignment"];
    row.cellConfig[@"inputType"] = @(inputType);
    row.cellConfig[@"titlePosition"] = @(XLFormFullWidthTextFieldTitlePosTop);
    
    row.required = required;
    if (value) row.value = value;
    row.height = 54;
    return row;
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)formRow
                                oldValue:(id)oldValue
                                newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:formRow oldValue:oldValue newValue:newValue];

    if (!self.isHydratingFormData) {
        self.hasUserModifiedForm = YES;
    }
}












 
#pragma mark - UI Reload

- (void)pp_reloadMediaUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageCollection reloadCollectionView];
    });
}


@end
