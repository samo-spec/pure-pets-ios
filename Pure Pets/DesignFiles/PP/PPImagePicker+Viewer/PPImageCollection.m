//
//  PPImageCollection 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 03/12/2025.
//


#import "PPImageCollection.h"
#import "QB.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "PPPermissionHelper.h"
#import "PPSelectOptionViewController.h"
#import "OptionModel.h"
#import "Styling.h"
#import "FullScreenImageViewerController.h"
#import "YYImageCoder.h"
@import FirebaseStorage;

@interface PPMediaUploadResult ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *imageURLs;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary *> *imageMetadata;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *videoURLs;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary *> *videoMetadata;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary *> *mixedMetadata;
@property (nonatomic, assign, readwrite) BOOL hasVideos;
@property (nonatomic, assign, readwrite) BOOL hasImages;
@end

@implementation PPMediaUploadResult

- (instancetype)initWithImageURLs:(NSArray<NSString *> *)imageURLs
                    imageMetadata:(NSArray<NSDictionary *> *)imageMetadata
                        videoURLs:(NSArray<NSString *> *)videoURLs
                    videoMetadata:(NSArray<NSDictionary *> *)videoMetadata
                     mixedMetadata:(NSArray<NSDictionary *> *)mixedMetadata
{
    self = [super init];
    if (self) {
        _imageURLs = [imageURLs copy] ?: @[];
        _imageMetadata = [imageMetadata copy] ?: @[];
        _videoURLs = [videoURLs copy] ?: @[];
        _videoMetadata = [videoMetadata copy] ?: @[];
        _mixedMetadata = [mixedMetadata copy] ?: @[];
        _hasImages = _imageURLs.count > 0 || _imageMetadata.count > 0;
        _hasVideos = _videoURLs.count > 0 || _videoMetadata.count > 0;
    }
    return self;
}

@end

@interface PPImageCollection () <UISheetPresentationControllerDelegate>
@property (nonatomic, strong) UIView *titleContainer;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countPillLabel;
@property (nonatomic, strong) UILabel *helperLabel;
@property (nonatomic, strong) UIView *collectionShellView;
@property (nonatomic, strong) UIVisualEffectView *collectionShellBlurView;
@property (nonatomic, strong) UIView *collectionShellTintView;
@property (nonatomic, strong) QBImagePickerController *currentPicker;
@property (nonatomic, strong) PPPickerBridge *photoPickerBridge;
@property (nonatomic, strong) PPCoreBridge *corePickerBridge;
@property (nonatomic, strong) UIImagePickerController *cameraPicker;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *mediaTypeArray;
@property (nonatomic, strong) NSMutableArray *videoURLArray;
@property (nonatomic, strong) NSMutableArray *preloadedMediaMetadataArray;
@property (nonatomic, strong) UILongPressGestureRecognizer *reorderLongPressGesture;
@property (nonatomic, assign) BOOL isPresentingMediaPicker;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpinner;
@property (nonatomic, copy) dispatch_block_t loadingTimeoutBlock;
@property (nonatomic, strong) NSLayoutConstraint *titleContainerLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleContainerTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleContainerHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *iconLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *countPillTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *helperTrailingConstraint;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIBlurEffect *blur;
@end

@implementation PPImageCollection

static CGFloat const PPImageCollectionRemoteImageMaxPixelSize = 1800.0;
static NSInteger const PPImageCollectionMaxVideoSelectionCount = 1;
static NSTimeInterval const PPImageCollectionMaxVideoDuration = 30.0;
static NSString * const PPAppMediaUploadsRoot = @"uploads";

static inline UISemanticContentAttribute PPImageCollectionSemanticAttributeForArabic(BOOL useArabic) {
    return useArabic
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
}

static inline NSTextAlignment PPImageCollectionTextAlignmentForArabic(BOOL useArabic) {
    return useArabic ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

static NSString *PPImageCollectionCleanPathComponent(NSString *value) {
    NSString *clean = [value isKindOfClass:NSString.class] ? value : @"";
    clean = [clean stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    clean = [clean stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return clean.length > 0 ? clean : NSUUID.UUID.UUIDString;
}

static NSString *PPImageCollectionNormalizedEntityType(NSString *entityType) {
    NSString *clean = [[entityType isKindOfClass:NSString.class] ? entityType : @"" lowercaseString];
    clean = [clean stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    if ([clean isEqualToString:@"pet-ads"] || [clean isEqualToString:@"ads"]) return @"ads";
    if ([clean isEqualToString:@"petaccessories"] || [clean isEqualToString:@"accessories"]) return @"accessories";
    if ([clean isEqualToString:@"used-accessories"] || [clean isEqualToString:@"usedaccessories"]) return @"used-accessories";
    if ([clean isEqualToString:@"adopt-pets"] || [clean isEqualToString:@"adoptions"]) return @"adoptions";
    if ([clean isEqualToString:@"users"] || [clean isEqualToString:@"user"]) return @"users";
    return clean.length > 0 ? clean : @"ads";
}

static NSString *PPImageCollectionMediaSubfolder(NSString *mediaType) {
    NSString *clean = [[mediaType isKindOfClass:NSString.class] ? mediaType : @"" lowercaseString];
    if ([clean containsString:@"video"]) return @"videos";
    if ([clean containsString:@"thumb"]) return @"thumbs";
    return @"images";
}

static NSString *PPImageCollectionStoragePath(NSString *entityType,
                                             NSString *entityID,
                                             NSString *mediaID,
                                             NSString *mediaType,
                                             NSString *extension) {
    NSString *entity = PPImageCollectionNormalizedEntityType(entityType);
    NSString *safeEntityID = PPImageCollectionCleanPathComponent(entityID);
    NSString *safeMediaID = PPImageCollectionCleanPathComponent(mediaID);
    NSString *ext = [[extension isKindOfClass:NSString.class] ? extension : @"" lowercaseString];
    if (ext.length == 0) ext = [PPImageCollectionMediaSubfolder(mediaType) isEqualToString:@"videos"] ? @"mp4" : @"webp";
    if ([ext hasPrefix:@"."]) ext = [ext substringFromIndex:1];

    if ([entity isEqualToString:@"users"]) {
        return [NSString stringWithFormat:@"%@/users/%@/profile/profile.%@", PPAppMediaUploadsRoot, safeEntityID, ext];
    }
    return [NSString stringWithFormat:@"%@/%@/%@/%@/%@.%@",
            PPAppMediaUploadsRoot,
            entity,
            safeEntityID,
            PPImageCollectionMediaSubfolder(mediaType),
            safeMediaID,
            ext];
}

static NSDictionary *PPImageCollectionImageUploadPayload(UIImage *image, CGFloat maxDimension) {
    if (![image isKindOfClass:UIImage.class] || image.size.width <= 0.0 || image.size.height <= 0.0) {
        return nil;
    }
    UIImage *source = image;
    if (source.imageOrientation != UIImageOrientationUp) {
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = source.scale;
        format.opaque = NO;
        source = [[[UIGraphicsImageRenderer alloc] initWithSize:source.size format:format] imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
            [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
        }];
    }
    CGFloat largest = MAX(source.size.width, source.size.height);
    if (largest > maxDimension) {
        CGFloat scale = maxDimension / largest;
        CGSize size = CGSizeMake(MAX(1.0, floor(source.size.width * scale)),
                                 MAX(1.0, floor(source.size.height * scale)));
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = 1.0;
        format.opaque = NO;
        source = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
            [source drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];
        }];
    }

    NSData *data = nil;
    NSString *extension = @"webp";
    NSString *contentType = @"image/webp";
    if (YYImageWebPAvailable() && source.CGImage) {
        data = CFBridgingRelease(YYCGImageCreateEncodedData(source.CGImage, YYImageTypeWebP, 0.84));
    }
    if (data.length == 0) {
        data = UIImageJPEGRepresentation(source, 0.86);
        extension = @"jpg";
        contentType = @"image/jpeg";
    }
    if (data.length == 0) return nil;
    return @{
        @"data": data,
        @"extension": extension,
        @"content_type": contentType,
        @"width": @(source.size.width),
        @"height": @(source.size.height)
    };
}

static NSString *PPImageCollectionVideoContentTypeForURL(NSURL *url) {
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mov"] || [ext isEqualToString:@"qt"]) return @"video/quicktime";
    if ([ext isEqualToString:@"m4v"]) return @"video/x-m4v";
    return @"video/mp4";
}

static UIImage *PPImageCollectionThumbnailForVideoURL(NSURL *videoURL) {
    if (![videoURL isKindOfClass:NSURL.class]) return nil;
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(900.0, 900.0);
    NSError *error = nil;
    CGImageRef cgImage = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.1, 600)
                                           actualTime:NULL
                                                error:&error];
    if (!cgImage) {
        NSLog(@"[PPImageCollection] Failed to generate video thumbnail: %@", error.localizedDescription);
        return nil;
    }
    UIImage *thumbnail = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return thumbnail;
}

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame maxImageCount:(NSInteger)maxCount useArabic:(BOOL)useArabic {
    self = [super initWithFrame:frame];
    if (self) {
        _maxImageCount = maxCount;
        _useArabic = useArabic;
        _allowsEditing = YES;
        _allowsReordering = YES;
        _allowsVideoSelection = NO;
        _selectedForEdit = -1;
        _headerContentInsets = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
        _arrayLock = [[NSRecursiveLock alloc] init];
        _mediaOutputArray = [[NSMutableArray alloc] init];
        _mediaTypeArray = [[NSMutableArray alloc] init];
        _videoURLArray = [[NSMutableArray alloc] init];
        _preloadedMediaMetadataArray = [[NSMutableArray alloc] init];
        
        [self setupImageManager];
        [self setupEditorBridge];
        [self setupUI];
        [self setupLoadingOverlay];
        [self setupNotifications];
        
        // Set default title
        [self setTitle:kLang(@"add.images.here") icon:nil];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame maxImageCount:8 useArabic:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self pp_cancelLoadingTimeoutIfNeeded];
}

#pragma mark - Setup

- (void)setupImageManager {
    _imageManager = [PPImageManager sharedManager];
    [_imageManager clearAll];
    _imageManager.maxImageCount = self.maxImageCount;
    if (![_imageManager.selectedImages isKindOfClass:NSMutableArray.class]) {
        NSArray *snapshot =
            [_imageManager.selectedImages isKindOfClass:NSArray.class] ? (NSArray *)_imageManager.selectedImages : @[];
        _imageManager.selectedImages = [snapshot mutableCopy];
    }
}

- (void)setupEditorBridge {
    _editorBridge = [[PPEditorBridge alloc] init];
    _photoPickerBridge = [[PPPickerBridge alloc] init];
    _corePickerBridge = [[PPCoreBridge alloc] init];
    _corePickerBridge.useArabic = self.useArabic;
    [_corePickerBridge preparePickerLanguageBundle];
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(editorDidFinish:)
                                                 name:@"PPEditorBridgeDidFinish"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(editorDidCancel:)
                                                 name:@"PPEditorBridgeDidCancel"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(photoPickerDidFinish:)
                                                 name:@"PPPickerBridgeDidFinish"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(photoPickerDidCancel:)
                                                 name:@"PPPickerBridgeDidCancel"
                                               object:nil];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    self.semanticContentAttribute = PPImageCollectionSemanticAttributeForArabic(self.useArabic);

    // Setup title container
    [self setupTitleContainer];

    // Setup collection view
    [self setupCollectionView];

    // Layout constraints
    [self setupConstraints];
    [self pp_applyLayoutDirection];
}

- (void)setupTitleContainer {
    _blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:_blur];
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    //blurView.layer.cornerRadius = 20.0;
    _blurView.clipsToBounds = YES;

    _titleContainer = [[UIView alloc] init];
    _titleContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _titleContainer.layer.cornerRadius = 18.0;
    _titleContainer.layer.cornerCurve = kCACornerCurveContinuous;
    _titleContainer.clipsToBounds = YES;
    _titleContainer.semanticContentAttribute = PPImageCollectionSemanticAttributeForArabic(self.useArabic);
    [self addSubview:_titleContainer];

    // Icon
    UIImageSymbolConfiguration *symConfig = [[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightRegular]
                                             configurationByApplyingConfiguration:
                                                 [UIImageSymbolConfiguration configurationWithPaletteColors:@[
                                                    [UIColor secondaryLabelColor],
                                                    [AppPrimaryClr colorWithAlphaComponent:1.0]
                                                 ]]];

    UIImage *icon = [UIImage systemImageNamed:@"photo.on.rectangle" withConfiguration:symConfig];
    _iconView = [[UIImageView alloc] initWithImage:icon];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = [UIColor labelColor];

    // Title label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:14]];
    _titleLabel.textColor = [UIColor secondaryLabelColor];
    _titleLabel.adjustsFontForContentSizeCategory = YES;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.textAlignment = PPImageCollectionTextAlignmentForArabic(self.useArabic);

    _countPillLabel = [[UILabel alloc] init];
    _countPillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countPillLabel.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:11.5]];
    _countPillLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    _countPillLabel.textAlignment = NSTextAlignmentCenter;
    _countPillLabel.adjustsFontForContentSizeCategory = YES;
    _countPillLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.94];
    _countPillLabel.layer.cornerRadius = 13.0;
    _countPillLabel.layer.masksToBounds = YES;

    _helperLabel = [[UILabel alloc] init];
    _helperLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _helperLabel.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:11.0]];
    _helperLabel.textColor = [UIColor tertiaryLabelColor];
    _helperLabel.adjustsFontForContentSizeCategory = YES;
    _helperLabel.numberOfLines = 1;
    _helperLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _helperLabel.textAlignment = PPImageCollectionTextAlignmentForArabic(self.useArabic);
    _helperLabel.text = kLang(@"drag_to_reorder");
    if (![_helperLabel.text isKindOfClass:NSString.class] || _helperLabel.text.length == 0 || [_helperLabel.text isEqualToString:@"drag_to_reorder"]) {
        _helperLabel.text = @"Tap to edit. Hold to reorder.";
    }

    [_titleContainer addSubview:_blurView];
    [_titleContainer addSubview:_iconView];
    [_titleContainer addSubview:_titleLabel];
    [_titleContainer addSubview:_countPillLabel];
    [_titleContainer addSubview:_helperLabel];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10.0, 12.0, 10.0, 12.0);
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    _collectionShellView = [[UIView alloc] init];
    _collectionShellView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionShellView.backgroundColor = UIColor.clearColor;
    _collectionShellView.layer.cornerRadius = 24.0;
    _collectionShellView.layer.masksToBounds = NO;
    _collectionShellView.semanticContentAttribute = PPImageCollectionSemanticAttributeForArabic(self.useArabic);
    _collectionShellView.layer.borderWidth = 1.0;
    [_collectionShellView pp_setBorderColor:[UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.05]];
    [_collectionShellView pp_setShadowColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
    _collectionShellView.layer.shadowOpacity = 0.03;
    _collectionShellView.layer.shadowRadius = 10.0;
    _collectionShellView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [self addSubview:_collectionShellView];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleExtraLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    _collectionShellBlurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    _collectionShellBlurView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionShellBlurView.userInteractionEnabled = NO;
    _collectionShellBlurView.clipsToBounds = YES;
    [_collectionShellView addSubview:_collectionShellBlurView];

    _collectionShellTintView = [[UIView alloc] init];
    _collectionShellTintView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionShellTintView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:1.0];
    _collectionShellTintView.userInteractionEnabled = NO;
    [_collectionShellBlurView.contentView addSubview:_collectionShellTintView];
    
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.backgroundColor = UIColor.clearColor;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.alwaysBounceHorizontal = YES;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.semanticContentAttribute = PPImageCollectionSemanticAttributeForArabic(self.useArabic);
    
    [_collectionView registerClass:[AddButtonCell class] forCellWithReuseIdentifier:@"AddButtonCell"];
    [_collectionView registerClass:[PP_ImageCell class] forCellWithReuseIdentifier:@"PP_ImageCell"];
    
    _collectionView.clipsToBounds = NO;

    _reorderLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(handleReorderLongPress:)];
    [_collectionView addGestureRecognizer:_reorderLongPressGesture];
    
    [_collectionShellView addSubview:_collectionView];
}

- (void)setupLoadingOverlay {
    _loadingOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    _loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.08];
    _loadingOverlay.layer.cornerRadius = 16;
    _loadingOverlay.hidden = YES;
    _loadingOverlay.clipsToBounds = YES;

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleLight;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemUltraThinMaterial;
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [_loadingOverlay addSubview:blurView];

    UIActivityIndicatorViewStyle style = UIActivityIndicatorViewStyleLarge;
    if (@available(iOS 13.0, *)) {
        style = UIActivityIndicatorViewStyleLarge;
    }
    _loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    _loadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingSpinner.color = AppPrimaryClr ?: UIColor.labelColor;

    [_loadingOverlay addSubview:_loadingSpinner];
    [self addSubview:_loadingOverlay];

    [NSLayoutConstraint activateConstraints:@[
        [_loadingOverlay.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_loadingOverlay.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_loadingOverlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_loadingOverlay.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [blurView.topAnchor constraintEqualToAnchor:_loadingOverlay.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:_loadingOverlay.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:_loadingOverlay.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:_loadingOverlay.bottomAnchor],

        [_loadingSpinner.centerXAnchor constraintEqualToAnchor:_loadingOverlay.centerXAnchor],
        [_loadingSpinner.centerYAnchor constraintEqualToAnchor:_loadingOverlay.centerYAnchor]
    ]];
}

- (void)pp_showLoadingOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loadingOverlay.hidden = NO;
        [self.loadingSpinner startAnimating];
    });
}

- (void)pp_hideLoadingOverlay {
    [self pp_cancelLoadingTimeoutIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingSpinner stopAnimating];
        self.loadingOverlay.hidden = YES;
    });
}

- (void)pp_refreshTitlePresentation
{
    NSInteger currentCount = [self imageCount];
    self.countPillLabel.text = [NSString stringWithFormat:@"  %ld/%ld  ", (long)currentCount, (long)self.maxImageCount];
    self.collectionShellTintView.backgroundColor =
        currentCount > 0
        ? [[UIColor whiteColor] colorWithAlphaComponent:0.62]
        : [[UIColor whiteColor] colorWithAlphaComponent:0.80];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.loadingOverlay.layer.cornerRadius = 24.0;
    [self pp_refreshTitlePresentation];
    self.blurView.layer.cornerRadius = self.titleContainer.layer.cornerRadius;
    self.collectionShellView.layer.cornerRadius = 24.0;
    self.collectionShellBlurView.layer.cornerRadius = 24.0;
    self.collectionShellView.layer.borderWidth = 1.0;
    [self.collectionShellView pp_setBorderColor:[UIColor colorWithRed:0.25 green:0.17 blue:0.18 alpha:0.05]];
    self.countPillLabel.layer.borderWidth = 1.0;
    [self.countPillLabel pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.72]];
}

- (void)pp_applyLayoutDirection
{
    UISemanticContentAttribute semantic = PPImageCollectionSemanticAttributeForArabic(self.useArabic);
    NSTextAlignment textAlignment = PPImageCollectionTextAlignmentForArabic(self.useArabic);

    self.semanticContentAttribute = semantic;
    self.titleContainer.semanticContentAttribute = semantic;
    self.collectionShellView.semanticContentAttribute = semantic;
    self.collectionView.semanticContentAttribute = semantic;
    self.titleLabel.textAlignment = textAlignment;
    self.helperLabel.textAlignment = textAlignment;
    self.countPillLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
}

- (void)setupConstraints {
    self.titleContainerLeadingConstraint =
        [_titleContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
    self.titleContainerTrailingConstraint =
        [_titleContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor];
    self.titleContainerHeightConstraint =
        [_titleContainer.heightAnchor constraintEqualToConstant:62.0];
    self.iconLeadingConstraint =
        [_iconView.leadingAnchor constraintEqualToAnchor:_titleContainer.leadingAnchor constant:self.headerContentInsets.left];
    self.countPillTrailingConstraint =
        [_countPillLabel.trailingAnchor constraintEqualToAnchor:_titleContainer.trailingAnchor constant:-self.headerContentInsets.right];
    self.helperTrailingConstraint =
        [_helperLabel.trailingAnchor constraintEqualToAnchor:_titleContainer.trailingAnchor constant:-self.headerContentInsets.right];

    [NSLayoutConstraint activateConstraints:@[
        // Title container
        [_titleContainer.topAnchor constraintEqualToAnchor:self.topAnchor],
        self.titleContainerLeadingConstraint,
        self.titleContainerTrailingConstraint,
        self.titleContainerHeightConstraint,

        [_blurView.leadingAnchor constraintEqualToAnchor:self.titleContainer.leadingAnchor],
        [_blurView.trailingAnchor constraintEqualToAnchor:self.titleContainer.trailingAnchor],
        [_blurView.topAnchor constraintEqualToAnchor:self.titleContainer.topAnchor],
        [_blurView.bottomAnchor constraintEqualToAnchor:self.titleContainer.bottomAnchor],

        // Icon
        self.iconLeadingConstraint,
        [_iconView.topAnchor constraintEqualToAnchor:_titleContainer.topAnchor constant:10.0],
        [_iconView.widthAnchor constraintEqualToConstant:20],
        [_iconView.heightAnchor constraintEqualToConstant:20],

        // Title label
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:6],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconView.centerYAnchor],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_countPillLabel.leadingAnchor constant:-8.0],

        [_countPillLabel.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        self.countPillTrailingConstraint,
        [_countPillLabel.heightAnchor constraintEqualToConstant:26.0],
        [_countPillLabel.widthAnchor constraintGreaterThanOrEqualToConstant:56.0],

        [_helperLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
        [_helperLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        self.helperTrailingConstraint,
        [_helperLabel.bottomAnchor constraintLessThanOrEqualToAnchor:_titleContainer.bottomAnchor constant:-8.0],

        [_collectionShellView.topAnchor constraintEqualToAnchor:_titleContainer.bottomAnchor constant:10.0],
        [_collectionShellView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_collectionShellView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_collectionShellView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

        [_collectionShellBlurView.topAnchor constraintEqualToAnchor:_collectionShellView.topAnchor],
        [_collectionShellBlurView.leadingAnchor constraintEqualToAnchor:_collectionShellView.leadingAnchor],
        [_collectionShellBlurView.trailingAnchor constraintEqualToAnchor:_collectionShellView.trailingAnchor],
        [_collectionShellBlurView.bottomAnchor constraintEqualToAnchor:_collectionShellView.bottomAnchor],

        [_collectionShellTintView.topAnchor constraintEqualToAnchor:_collectionShellBlurView.contentView.topAnchor],
        [_collectionShellTintView.leadingAnchor constraintEqualToAnchor:_collectionShellBlurView.contentView.leadingAnchor],
        [_collectionShellTintView.trailingAnchor constraintEqualToAnchor:_collectionShellBlurView.contentView.trailingAnchor],
        [_collectionShellTintView.bottomAnchor constraintEqualToAnchor:_collectionShellBlurView.contentView.bottomAnchor],

        [_collectionView.topAnchor constraintEqualToAnchor:_collectionShellView.topAnchor constant:8.0],
        [_collectionView.leadingAnchor constraintEqualToAnchor:_collectionShellView.leadingAnchor constant:8.0],
        [_collectionView.trailingAnchor constraintEqualToAnchor:_collectionShellView.trailingAnchor constant:-8.0],
        [_collectionView.bottomAnchor constraintEqualToAnchor:_collectionShellView.bottomAnchor constant:-8.0]
    ]];
}

- (void)setHeaderContentInsets:(UIEdgeInsets)headerContentInsets
{
    if (UIEdgeInsetsEqualToEdgeInsets(_headerContentInsets, headerContentInsets)) {
        return;
    }

    _headerContentInsets = headerContentInsets;
    self.titleContainerLeadingConstraint.constant = 0.0;
    self.titleContainerTrailingConstraint.constant = 0.0;
    self.iconLeadingConstraint.constant = headerContentInsets.left;
    self.countPillTrailingConstraint.constant = -headerContentInsets.right;
    self.helperTrailingConstraint.constant = -headerContentInsets.right;
    [self setNeedsLayout];
}

- (void)setUseArabic:(BOOL)useArabic
{
    if (_useArabic == useArabic) {
        return;
    }

    _useArabic = useArabic;
    [self pp_applyLayoutDirection];
    [self reloadCollectionView];
}

#pragma mark - Public Methods

- (BOOL)pp_allowsReusableVideoMedia
{
    return PPReusableVideoMediaEnabled() && self.allowsVideoSelection;
}

- (NSString *)pp_mediaStringValue:(id)value
{
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

- (BOOL)pp_mediaMetadataIsVideo:(NSDictionary *)metadata
{
    if (![metadata isKindOfClass:NSDictionary.class] || ![self pp_allowsReusableVideoMedia]) {
        return NO;
    }
    NSString *type = [[self pp_mediaStringValue:metadata[@"media_type"]] lowercaseString];
    return [type isEqualToString:@"video"];
}

- (NSString *)pp_displayURLForMediaMetadata:(NSDictionary *)metadata
{
    if (![metadata isKindOfClass:NSDictionary.class]) {
        return @"";
    }
    if ([self pp_mediaMetadataIsVideo:metadata]) {
        NSString *thumbnailURL = [self pp_mediaStringValue:metadata[@"thumbnail_url"]];
        if (thumbnailURL.length > 0) {
            return thumbnailURL;
        }
    }
    return [self pp_mediaStringValue:metadata[@"url"]];
}

- (NSDictionary *)pp_normalizedExistingMetadata:(NSDictionary *)metadata order:(NSInteger)order
{
    if (![metadata isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSMutableDictionary *normalized = [metadata mutableCopy];
    normalized[@"order"] = @(order);
    normalized[@"is_primary"] = @(order == 0);
    NSString *type = [[self pp_mediaStringValue:normalized[@"media_type"]] lowercaseString];
    if (type.length == 0 || ([type isEqualToString:@"video"] && ![self pp_allowsReusableVideoMedia])) {
        normalized[@"media_type"] = @"image";
    } else {
        normalized[@"media_type"] = type;
    }
    return normalized.copy;
}

- (void)setAllowsVideoSelection:(BOOL)allowsVideoSelection
{
    _allowsVideoSelection = allowsVideoSelection;
    if (!PPReusableVideoMediaEnabled() && allowsVideoSelection) {
        _allowsVideoSelection = NO;
    }
    [self reloadCollectionView];
}

- (void)pp_ensureMutableCollections
{
    if (![self.mediaOutputArray isKindOfClass:NSMutableArray.class]) {
        NSArray *snapshot =
            [self.mediaOutputArray isKindOfClass:NSArray.class] ? (NSArray *)self.mediaOutputArray : @[];
        self.mediaOutputArray = [snapshot mutableCopy];
    }
    if (!self.mediaOutputArray) {
        self.mediaOutputArray = [NSMutableArray array];
    }
    if (![self.mediaTypeArray isKindOfClass:NSMutableArray.class]) {
        NSArray *snapshot =
            [self.mediaTypeArray isKindOfClass:NSArray.class] ? (NSArray *)self.mediaTypeArray : @[];
        self.mediaTypeArray = [snapshot mutableCopy];
    }
    if (!self.mediaTypeArray) {
        self.mediaTypeArray = [NSMutableArray array];
    }
    if (![self.videoURLArray isKindOfClass:NSMutableArray.class]) {
        NSArray *snapshot =
            [self.videoURLArray isKindOfClass:NSArray.class] ? (NSArray *)self.videoURLArray : @[];
        self.videoURLArray = [snapshot mutableCopy];
    }
    if (!self.videoURLArray) {
        self.videoURLArray = [NSMutableArray array];
    }
    if (![self.preloadedMediaMetadataArray isKindOfClass:NSMutableArray.class]) {
        NSArray *snapshot =
            [self.preloadedMediaMetadataArray isKindOfClass:NSArray.class] ? (NSArray *)self.preloadedMediaMetadataArray : @[];
        self.preloadedMediaMetadataArray = [snapshot mutableCopy];
    }
    if (!self.preloadedMediaMetadataArray) {
        self.preloadedMediaMetadataArray = [NSMutableArray array];
    }

    if (!self.imageManager) {
        self.imageManager = [PPImageManager sharedManager];
    }
    if (![self.imageManager.selectedImages isKindOfClass:NSMutableArray.class]) {
        NSArray *snapshot =
            [self.imageManager.selectedImages isKindOfClass:NSArray.class] ? (NSArray *)self.imageManager.selectedImages : @[];
        self.imageManager.selectedImages = [snapshot mutableCopy];
    }
    if (!self.imageManager.selectedImages) {
        self.imageManager.selectedImages = [NSMutableArray array];
    }
    if (![self.imageManager.assetArray isKindOfClass:NSMutableOrderedSet.class]) {
        NSOrderedSet *snapshot =
            [self.imageManager.assetArray isKindOfClass:NSOrderedSet.class] ? (NSOrderedSet *)self.imageManager.assetArray : [NSOrderedSet orderedSet];
        self.imageManager.assetArray = [snapshot mutableCopy];
    }
    if (!self.imageManager.assetArray) {
        self.imageManager.assetArray = [NSMutableOrderedSet orderedSet];
    }
}

- (NSString *)pp_uniqueAssetPlaceholder
{
    NSString *uuid = [[NSUUID UUID] UUIDString];
    if (![uuid isKindOfClass:[NSString class]] || uuid.length == 0) {
        NSTimeInterval timestamp = [NSDate date].timeIntervalSince1970;
        uuid = [NSString stringWithFormat:@"%.0f", timestamp * 1000.0];
    }
    return [NSString stringWithFormat:@"pp-asset-placeholder-%@", uuid];
}

- (UIImage *)pp_normalizedImageForCollection:(UIImage *)image
{
    if (!image) return nil;
    if (image.size.width <= 0.0 || image.size.height <= 0.0) return nil;

    UIImage *source = image;
    CGFloat maxDimension = MAX(source.size.width, source.size.height);
    CGFloat targetMaxDimension = 1800.0; // keep memory stable for repeated picks/edits.

    CGSize targetSize = source.size;
    if (maxDimension > targetMaxDimension) {
        CGFloat scale = targetMaxDimension / maxDimension;
        targetSize = CGSizeMake(MAX(1.0, floor(source.size.width * scale)),
                                MAX(1.0, floor(source.size.height * scale)));
    }

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    format.scale = source.scale > 0 ? source.scale : UIScreen.mainScreen.scale;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    UIImage *normalized = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [source drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];
    return normalized ?: source;
}

- (BOOL)pp_isRenderableImage:(UIImage *)image
{
    return [image isKindOfClass:[UIImage class]] &&
           image.size.width > 0.0 &&
           image.size.height > 0.0;
}

- (UIImage *)pp_downsampledImageFromData:(NSData *)data
                            maxPixelSize:(CGFloat)maxPixelSize
{
    if (![data isKindOfClass:NSData.class] || data.length == 0) {
        return nil;
    }

    NSDictionary *sourceOptions = @{
        (NSString *)kCGImageSourceShouldCache : @NO
    };
    CGImageSourceRef source =
        CGImageSourceCreateWithData((__bridge CFDataRef)data, (__bridge CFDictionaryRef)sourceOptions);
    if (!source) {
        return [UIImage imageWithData:data];
    }

    NSDictionary *thumbnailOptions = @{
        (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
        (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
        (NSString *)kCGImageSourceShouldCacheImmediately : @NO,
        (NSString *)kCGImageSourceThumbnailMaxPixelSize : @((NSInteger)MAX(1.0, maxPixelSize))
    };
    CGImageRef thumbnail =
        CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)thumbnailOptions);
    CFRelease(source);

    if (!thumbnail) {
        return [UIImage imageWithData:data];
    }

    UIImage *image =
        [UIImage imageWithCGImage:thumbnail
                            scale:UIScreen.mainScreen.scale
                      orientation:UIImageOrientationUp];
    CGImageRelease(thumbnail);
    return [self pp_normalizedImageForCollection:image];
}

- (NSArray<UIImage *> *)pp_sanitizedImagesFromArray:(NSArray *)images
{
    NSMutableArray<UIImage *> *sanitized = [NSMutableArray array];
    for (id candidate in images) {
        if (![candidate isKindOfClass:[UIImage class]]) {
            continue;
        }
        UIImage *normalized = [self pp_normalizedImageForCollection:(UIImage *)candidate];
        if ([self pp_isRenderableImage:normalized]) {
            [sanitized addObject:normalized];
        }
    }
    return [sanitized copy];
}

- (nullable UIImage *)pp_renderableImageAtIndex:(NSInteger)index
{
    if (index < 0) {
        return nil;
    }

    [self.arrayLock lock];
    UIImage *candidate =
        (index < self.mediaOutputArray.count && [self.mediaOutputArray[index] isKindOfClass:[UIImage class]])
        ? (UIImage *)self.mediaOutputArray[index]
        : nil;
    [self.arrayLock unlock];

    if (![self pp_isRenderableImage:candidate]) {
        return nil;
    }
    return candidate;
}

- (void)pp_syncImagesFromManager
{
    NSArray *managerImages = [self.imageManager.selectedImages copy] ?: @[];
    NSArray *managerAssets = [self.imageManager.assetArray.array copy] ?: @[];
    NSMutableArray<UIImage *> *sanitized = [NSMutableArray array];
    NSMutableArray *sanitizedAssets = [NSMutableArray array];

    for (NSUInteger idx = 0; idx < managerImages.count; idx++) {
        id candidate = managerImages[idx];
        if (![candidate isKindOfClass:[UIImage class]]) {
            continue;
        }
        UIImage *normalized = [self pp_normalizedImageForCollection:(UIImage *)candidate];
        if (![self pp_isRenderableImage:normalized]) {
            continue;
        }

        [sanitized addObject:normalized];
        id asset = (idx < managerAssets.count) ? managerAssets[idx] : nil;
        if (!asset) {
            asset = [self pp_uniqueAssetPlaceholder];
        }
        if (asset) {
            [sanitizedAssets addObject:asset];
        }
    }

    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    [self.mediaOutputArray removeAllObjects];
    [self.mediaOutputArray addObjectsFromArray:sanitized];
    [self.mediaTypeArray removeAllObjects];
    [self.videoURLArray removeAllObjects];
    [self.preloadedMediaMetadataArray removeAllObjects];
    for (__unused UIImage *image in sanitized) {
        [self.mediaTypeArray addObject:@(PHAssetMediaTypeImage)];
        [self.videoURLArray addObject:(NSURL *)NSNull.null];
        [self.preloadedMediaMetadataArray addObject:NSNull.null];
    }
    self.imageManager.selectedImages = [sanitized mutableCopy];
    self.imageManager.assetArray = [NSMutableOrderedSet orderedSetWithArray:sanitizedAssets];
    [self.arrayLock unlock];
}

- (void)pp_cancelLoadingTimeoutIfNeeded
{
    if (self.loadingTimeoutBlock) {
        dispatch_block_cancel(self.loadingTimeoutBlock);
        self.loadingTimeoutBlock = nil;
    }
}

- (NSString *)pp_localizedSheetStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    if (![key isKindOfClass:[NSString class]] || key.length == 0) {
        return fallback ?: @"";
    }

    NSString *localized = kLang(key);
    if ([localized isKindOfClass:[NSString class]]) {
        NSString *trimmed =
            [localized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length > 0 && ![trimmed isEqualToString:key]) {
            return localized;
        }
    }

    return fallback ?: @"";
}

- (BOOL)pp_isMediaPickerViewController:(UIViewController *)viewController
{
    if (!viewController) {
        return NO;
    }

    if ([viewController isKindOfClass:[QBImagePickerController class]] ||
        [viewController isKindOfClass:[UIImagePickerController class]] ||
        [viewController isKindOfClass:[UIDocumentPickerViewController class]]) {
        return YES;
    }

    NSString *className = NSStringFromClass(viewController.class);
    return [className containsString:@"PhotoPickerController"];
}

- (BOOL)pp_hasActiveMediaPresentation
{
    UIWindow *window = self.window ?: [self pp_parentViewController].view.window ?: AppMgr.topViewController.view.window;
    UIViewController *cursor = window.rootViewController ?: [self pp_parentViewController] ?: AppMgr.topViewController;

    while (cursor) {
        if ([self pp_isMediaPickerViewController:cursor]) {
            return YES;
        }
        cursor = cursor.presentedViewController;
    }

    return NO;
}

- (void)pp_resetMediaPresentationState
{
    self.currentPicker = nil;
    self.cameraPicker = nil;
    self.isPresentingMediaPicker = NO;
    [self pp_cancelLoadingTimeoutIfNeeded];
}

- (void)pp_scheduleMediaPresentationResetWithAttempts:(NSInteger)attempts
{
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        if ([self pp_hasActiveMediaPresentation] && attempts > 0) {
            [self pp_scheduleMediaPresentationResetWithAttempts:(attempts - 1)];
            return;
        }

        [self pp_resetMediaPresentationState];
    });
}

- (void)pp_performMediaPresentationAction:(dispatch_block_t)action attempt:(NSInteger)attempt
{
    if (!action) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }

        [self pp_resetStalePresentingFlagIfNeeded];
        UIViewController *readyVC = [self pp_bestPresentingViewController:nil];
        BOOL hostBusy = (readyVC == nil) ||
                        readyVC.presentedViewController != nil ||
                        readyVC.isBeingPresented ||
                        readyVC.isBeingDismissed ||
                        self.isPresentingMediaPicker;
        if (hostBusy) {
            if (attempt < 18) {
                [self pp_performMediaPresentationAction:action attempt:(attempt + 1)];
            }
            return;
        }

        action();
    });
}

- (BOOL)pp_notificationBelongsToCurrentPhotoPicker:(NSNotification *)notification
{
    if (notification.object) {
        return (notification.object == self.photoPickerBridge);
    }
    return self.isPresentingMediaPicker;
}

- (void)setTitle:(NSString *)title icon:(UIImage *)icon {
    _titleText = [title copy];
    _titleLabel.text = _titleText;
    if (icon) {
        _iconView.image = icon;
    }
    [self pp_refreshTitlePresentation];
}

- (void)setTitleText:(NSString *)titleText {
    _titleText = [titleText copy];
    [self setTitle:_titleText icon:nil];
}

- (NSArray<UIImage *> *)allImages {
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    [self.arrayLock lock];
    for (NSInteger idx = 0; idx < self.mediaOutputArray.count; idx++) {
        NSNumber *mediaType = idx < self.mediaTypeArray.count ? self.mediaTypeArray[idx] : @(PHAssetMediaTypeImage);
        if (mediaType.integerValue != PHAssetMediaTypeImage) {
            continue;
        }
        id image = self.mediaOutputArray[idx];
        if ([image isKindOfClass:UIImage.class]) {
            [images addObject:image];
        }
    }
    [self.arrayLock unlock];
    return images.copy;
}

- (NSArray<UIImage *> *)allPhotoImages {
    NSMutableArray<UIImage *> *photos = [NSMutableArray array];
    [self.arrayLock lock];
    for (NSInteger idx = 0; idx < self.mediaOutputArray.count; idx++) {
        NSNumber *mediaType = idx < self.mediaTypeArray.count ? self.mediaTypeArray[idx] : @(PHAssetMediaTypeImage);
        id image = self.mediaOutputArray[idx];
        if (mediaType.integerValue == PHAssetMediaTypeImage && [image isKindOfClass:UIImage.class]) {
            [photos addObject:image];
        }
    }
    [self.arrayLock unlock];
    return photos.copy;
}

- (NSArray<NSURL *> *)allVideoURLs {
    if (![self pp_allowsReusableVideoMedia]) {
        return @[];
    }
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    [self.arrayLock lock];
    for (id candidate in self.videoURLArray) {
        if ([candidate isKindOfClass:NSURL.class]) {
            [urls addObject:candidate];
        }
    }
    [self.arrayLock unlock];
    return urls.copy;
}

- (BOOL)hasSelectedVideos {
    if (![self pp_allowsReusableVideoMedia]) {
        return NO;
    }
    [self.arrayLock lock];
    BOOL hasVideos = NO;
    for (NSNumber *mediaType in self.mediaTypeArray) {
        if (mediaType.integerValue == PHAssetMediaTypeVideo) {
            hasVideos = YES;
            break;
        }
    }
    [self.arrayLock unlock];
    return hasVideos;
}

- (NSInteger)pp_selectedVideoCount
{
    if (![self pp_allowsReusableVideoMedia]) {
        return 0;
    }
    NSInteger count = 0;
    [self.arrayLock lock];
    for (NSNumber *mediaType in self.mediaTypeArray) {
        if (mediaType.integerValue == PHAssetMediaTypeVideo) {
            count += 1;
        }
    }
    [self.arrayLock unlock];
    return count;
}

- (NSString *)pp_videoCountLimitMessage
{
    NSString *message = kLang(@"media_video_count_limit_message");
    if ([message isKindOfClass:NSString.class] && message.length > 0 && ![message isEqualToString:@"media_video_count_limit_message"]) {
        return message;
    }
    return [NSString stringWithFormat:@"You can add up to %ld video.", (long)PPImageCollectionMaxVideoSelectionCount];
}

- (NSString *)pp_videoDurationLimitMessage
{
    NSString *message = kLang(@"media_video_duration_limit_message");
    if ([message isKindOfClass:NSString.class] && message.length > 0 && ![message isEqualToString:@"media_video_duration_limit_message"]) {
        return message;
    }
    return [NSString stringWithFormat:@"Videos must be %@ seconds or shorter.", @(PPImageCollectionMaxVideoDuration)];
}

- (void)pp_presentMediaLimitMessage:(NSString *)message
{
    UIViewController *presenter = [self pp_bestPresentingViewController:nil];
    if (!presenter || presenter.presentedViewController) {
        return;
    }
    [self presentSimpleAlertOn:presenter
                         title:[self pp_localizedSheetStringForKey:@"media_limit_title" fallback:@"Media limit"]
                       message:message];
}

- (void)pp_presentMediaLimitMessageAfterPickerDismiss:(NSString *)message
{
    if (message.length == 0) {
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *presenter = [self pp_bestPresentingViewController:nil] ?: AppMgr.topViewController;
        if (!presenter || presenter.presentedViewController) {
            return;
        }
        [self presentSimpleAlertOn:presenter
                             title:[self pp_localizedSheetStringForKey:@"media_limit_title" fallback:@"Media limit"]
                           message:message];
    });
}

- (BOOL)pp_canAcceptAdditionalVideoWithPresenter:(UIViewController *)presenter
{
    if (![self pp_allowsReusableVideoMedia]) {
        return NO;
    }
    if ([self pp_selectedVideoCount] < PPImageCollectionMaxVideoSelectionCount) {
        return YES;
    }
    UIViewController *target = presenter ?: [self pp_bestPresentingViewController:nil];
    if (target) {
        [self presentSimpleAlertOn:target
                             title:[self pp_localizedSheetStringForKey:@"media_limit_title" fallback:@"Media limit"]
                           message:[self pp_videoCountLimitMessage]];
    }
    return NO;
}

- (BOOL)pp_videoDurationIsAllowed:(NSTimeInterval)duration
{
    return duration > 0.0 && duration <= PPImageCollectionMaxVideoDuration;
}

- (NSInteger)imageCount {
    [self.arrayLock lock];
    NSInteger count = self.mediaOutputArray.count;
    [self.arrayLock unlock];
    return count;
}

- (void)addImage:(UIImage *)image {
    if (!image || [self imageCount] >= self.maxImageCount) return;
    UIImage *normalized = [self pp_normalizedImageForCollection:image];
    if (!normalized) return;
    
    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
        [self.mediaOutputArray addObject:normalized];
        [self.mediaTypeArray addObject:@(PHAssetMediaTypeImage)];
        [self.videoURLArray addObject:(NSURL *)NSNull.null];
        [self.preloadedMediaMetadataArray addObject:NSNull.null];
        [self.imageManager addImage:normalized];
    [self.arrayLock unlock];
    
    [self reloadCollectionView];
    [self notifyDelegate];
}

- (void)addImages:(NSArray<UIImage *> *)images {
    if (images.count == 0) return;

    NSMutableArray<UIImage *> *normalizedCandidates = [NSMutableArray arrayWithCapacity:images.count];
    for (UIImage *candidate in images) {
        UIImage *normalized = [self pp_normalizedImageForCollection:candidate];
        if (normalized) {
            [normalizedCandidates addObject:normalized];
        }
    }

    if (normalizedCandidates.count == 0) return;

    NSInteger availableSlots = self.maxImageCount - [self imageCount];
    if (availableSlots <= 0) return;
    
    NSArray *imagesToAdd = normalizedCandidates;
    if (normalizedCandidates.count > availableSlots) {
        imagesToAdd = [normalizedCandidates subarrayWithRange:NSMakeRange(0, availableSlots)];
    }
    
    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    [self.mediaOutputArray addObjectsFromArray:imagesToAdd];
    
    for (UIImage *image in imagesToAdd) {
        [self.mediaTypeArray addObject:@(PHAssetMediaTypeImage)];
        [self.videoURLArray addObject:(NSURL *)NSNull.null];
        [self.preloadedMediaMetadataArray addObject:NSNull.null];
        [self.imageManager addImage:image];
    }
    [self.arrayLock unlock];
    
    [self reloadCollectionView];
    [self notifyDelegate];
}

- (UIImage *)pp_thumbnailForVideoURL:(NSURL *)videoURL
{
    if (![videoURL isKindOfClass:NSURL.class]) {
        return nil;
    }
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(900.0, 900.0);
    NSError *error = nil;
    CGImageRef cgImage = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.1, 600)
                                           actualTime:NULL
                                                error:&error];
    if (!cgImage) {
        NSLog(@"[PPImageCollection] Failed to generate video thumbnail: %@", error.localizedDescription);
        return nil;
    }
    UIImage *thumbnail = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return [self pp_normalizedImageForCollection:thumbnail];
}

- (NSURL *)pp_stableLocalVideoURLForSelection:(NSURL *)videoURL
{
    if (![videoURL isKindOfClass:NSURL.class] || !videoURL.isFileURL) {
        return nil;
    }

    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *directoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"PPImageCollectionVideos"];
    NSError *directoryError = nil;
    if (![fileManager createDirectoryAtPath:directoryPath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&directoryError]) {
        NSLog(@"[PPImageCollection] Failed to create video staging directory: %@", directoryError.localizedDescription);
        return videoURL;
    }

    NSString *ext = videoURL.pathExtension.length > 0 ? videoURL.pathExtension.lowercaseString : @"mov";
    NSURL *targetURL = [NSURL fileURLWithPath:[directoryPath stringByAppendingPathComponent:
                                               [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, ext]]];
    BOOL didAccess = [videoURL startAccessingSecurityScopedResource];
    NSError *copyError = nil;
    [fileManager copyItemAtURL:videoURL toURL:targetURL error:&copyError];
    if (didAccess) {
        [videoURL stopAccessingSecurityScopedResource];
    }
    if (copyError) {
        NSLog(@"[PPImageCollection] Failed to stage selected video: %@", copyError.localizedDescription);
        return nil;
    }
    return targetURL;
}

- (void)addVideoWithURL:(NSURL *)videoURL thumbnail:(UIImage *)thumbnail
{
    if (![self pp_allowsReusableVideoMedia]) return;
    if (![videoURL isKindOfClass:NSURL.class] || [self imageCount] >= self.maxImageCount) return;
    if (![self pp_canAcceptAdditionalVideoWithPresenter:nil]) return;
    NSURL *stableVideoURL = [self pp_stableLocalVideoURLForSelection:videoURL];
    if (![stableVideoURL isKindOfClass:NSURL.class] || !stableVideoURL.isFileURL) return;
    NSDictionary *videoInfo = [self pp_videoInfoForURL:stableVideoURL];
    if (![self pp_videoDurationIsAllowed:[videoInfo[@"duration"] doubleValue]] ||
        [videoInfo[@"width"] doubleValue] <= 0.0 ||
        [videoInfo[@"height"] doubleValue] <= 0.0) {
        NSLog(@"[PPImageCollection] Rejected unsupported selected video: %@", stableVideoURL);
        [self pp_presentMediaLimitMessage:[self pp_videoDurationLimitMessage]];
        return;
    }
    UIImage *videoThumbnail = thumbnail ?: [self pp_thumbnailForVideoURL:stableVideoURL];
    if (![self pp_isRenderableImage:videoThumbnail]) return;

    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    [self.mediaOutputArray addObject:videoThumbnail];
    [self.mediaTypeArray addObject:@(PHAssetMediaTypeVideo)];
    [self.videoURLArray addObject:stableVideoURL];
    [self.preloadedMediaMetadataArray addObject:NSNull.null];
    [self.imageManager.selectedImages addObject:videoThumbnail];
    NSString *placeholder = [self pp_uniqueAssetPlaceholder];
    if (placeholder.length > 0) {
        [self.imageManager.assetArray addObject:placeholder];
    }
    [self.arrayLock unlock];

    [self reloadCollectionView];
    [self notifyDelegate];
}

- (void)removeImageAtIndex:(NSInteger)index {
    if (index < 0 || index >= [self imageCount]) return;
    
    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    [self.mediaOutputArray removeObjectAtIndex:index];
    if (index < self.mediaTypeArray.count) [self.mediaTypeArray removeObjectAtIndex:index];
    if (index < self.videoURLArray.count) [self.videoURLArray removeObjectAtIndex:index];
    if (index < self.preloadedMediaMetadataArray.count) [self.preloadedMediaMetadataArray removeObjectAtIndex:index];
    [self.imageManager removeImageAtIndex:index];
    [self.arrayLock unlock];
    
    [self reloadCollectionView];
    [self notifyDelegate];
}

- (void)replaceImageAtIndex:(NSInteger)index withImage:(UIImage *)image {
    if (index < 0 || index >= [self imageCount] || !image) return;
    UIImage *normalized = [self pp_normalizedImageForCollection:image];
    if (!normalized) return;
    
    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    [self.mediaOutputArray replaceObjectAtIndex:index withObject:normalized];
    if (index < self.mediaTypeArray.count) self.mediaTypeArray[index] = @(PHAssetMediaTypeImage);
    if (index < self.videoURLArray.count) self.videoURLArray[index] = (NSURL *)NSNull.null;
    if (index < self.preloadedMediaMetadataArray.count) self.preloadedMediaMetadataArray[index] = NSNull.null;
    
    // For PPImageManager, we need to replace with asset if available
    PHAsset *asset = nil;
    if (index < self.imageManager.assetArray.count) {
        id obj = [self.imageManager.assetArray objectAtIndex:index];
        if ([obj isKindOfClass:[PHAsset class]]) {
            asset = obj;
        }
    }
    [self.imageManager replaceImageAtIndex:index withImage:normalized asset:asset];
    [self.arrayLock unlock];
    
    [self reloadCollectionView];
    [self notifyDelegate];
}

- (void)clearAllImages {
    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    [self.mediaOutputArray removeAllObjects];
    [self.mediaTypeArray removeAllObjects];
    [self.videoURLArray removeAllObjects];
    [self.preloadedMediaMetadataArray removeAllObjects];
    [self.imageManager clearAll];
    [self.arrayLock unlock];
    
    [self reloadCollectionView];
    [self notifyDelegate];
}

- (void)reloadCollectionView {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

- (void)pp_presentAddImageOptionsFromViewController:(UIViewController *)viewController
                                        sourceView:(UIView *)sourceView
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pp_presentAddImageOptionsFromViewController:viewController sourceView:sourceView];
        });
        return;
    }

    // Self-healing: reset stuck flag before trying to present
    [self pp_resetStalePresentingFlagIfNeeded];

    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) {
        return;
    }
    if (presentingVC.presentedViewController) {
        return;
    }

    // Build modern option models with SF Symbols
    NSMutableArray<OptionModel *> *options = [NSMutableArray array];

    BOOL allowsVideoMedia = [self pp_allowsReusableVideoMedia];

    OptionModel *libraryOption = [OptionModel optionWithID:@"photo_library"
                                                     title:[self pp_localizedSheetStringForKey:@"Photo_Library"
                                                                                      fallback:@"Photo Library"]
                                               systemImage:allowsVideoMedia ? @"photo.stack" : @"photo.on.rectangle.angled"];
    libraryOption.subtitle = allowsVideoMedia
        ? [self pp_localizedSheetStringForKey:@"choose_media_from_gallery" fallback:@"Choose photos or videos"]
        : [self pp_localizedSheetStringForKey:@"choose_from_gallery" fallback:@"Choose from gallery"];
    [options addObject:libraryOption];

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        OptionModel *cameraOption = [OptionModel optionWithID:@"camera"
                                                        title:[self pp_localizedSheetStringForKey:@"Camera"
                                                                                         fallback:@"Camera"]
                                                  systemImage:@"camera.fill"];
        cameraOption.subtitle = allowsVideoMedia
            ? [self pp_localizedSheetStringForKey:@"take_photo_or_video" fallback:@"Take a photo or video"]
            : [self pp_localizedSheetStringForKey:@"take_a_photo" fallback:@"Take a photo"];
        [options addObject:cameraOption];
    }

    OptionModel *filesOption = [OptionModel optionWithID:@"files"
                                                   title:[self pp_localizedSheetStringForKey:@"files"
                                                                                    fallback:@"Files"]
                                             systemImage:@"folder.fill"];
    filesOption.subtitle = [self pp_localizedSheetStringForKey:@"browse_files"
                                                      fallback:@"Browse files"];
    [options addObject:filesOption];

    NSString *sheetTitle =
        self.titleText.length > 0
        ? self.titleText
        : [self pp_localizedSheetStringForKey:@"add.images.here" fallback:@"Add images here"];

    __weak typeof(self) weakSelf = self;
    PPSelectOptionViewController *optionVC =
        [[PPSelectOptionViewController alloc] initWithOptions:options
                                                        title:sheetTitle
                                                          row:nil
                                             presentationStyle:PPSelectOptionPresentationMain
                                                showSearchBar:NO
                                                   completion:^(id _Nullable selectedObject) {
        if (![selectedObject isKindOfClass:[OptionModel class]]) return;
        OptionModel *selected = (OptionModel *)selectedObject;
        UIViewController *anchorVC = [weakSelf pp_bestPresentingViewController:nil] ?: presentingVC;

        [weakSelf pp_performMediaPresentationAction:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                return;
            }

            UIViewController *targetPresenter =
                [self pp_bestPresentingViewController:anchorVC] ?: [self pp_bestPresentingViewController:nil];

            if ([selected.optID isEqualToString:@"photo_library"]) {
                [self openGalleryPickerFromViewController:targetPresenter];
            } else if ([selected.optID isEqualToString:@"camera"]) {
                [self openCameraFromViewController:targetPresenter];
            } else if ([selected.optID isEqualToString:@"files"]) {
                [self openFilesPickerFromViewController:targetPresenter];
            }
        } attempt:0];
    }];

    [presentingVC presentViewController:optionVC animated:YES completion:nil];
}

- (void)notifyDelegate {
    [self pp_refreshTitlePresentation];
    if ([self.delegate respondsToSelector:@selector(imageCollection:didUpdateImages:)]) {
        [self.delegate imageCollection:self didUpdateImages:[self allImages]];
    }
}

#pragma mark - Reusable Media Metadata + Upload

- (NSString *)pp_mediaLocalizedStringForKey:(NSString *)key fallback:(NSString *)fallback
{
    NSString *value = kLang(key);
    if ([value isKindOfClass:NSString.class] && value.length > 0 && ![value isEqualToString:key]) {
        return value;
    }
    return fallback ?: @"";
}

- (NSError *)pp_mediaErrorWithCode:(NSInteger)code
                       description:(NSString *)description
                          userInfo:(NSDictionary *)userInfo
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:userInfo ?: @{}];
    info[NSLocalizedDescriptionKey] = description.length > 0
        ? description
        : [self pp_mediaLocalizedStringForKey:@"media_upload_failed_message"
                                     fallback:@"Media upload failed. Please try again."];
    return [NSError errorWithDomain:@"PPImageCollectionMediaUpload" code:code userInfo:info.copy];
}

- (NSError *)pp_firstUnderlyingUploadErrorFromErrors:(NSArray<NSError *> *)errors
{
    for (NSError *error in errors) {
        if ([error isKindOfClass:NSError.class]) {
            return error;
        }
    }
    return nil;
}

- (NSString *)pp_userVisibleUploadFailureDescriptionForErrors:(NSArray<NSError *> *)errors
{
    NSError *firstError = [self pp_firstUnderlyingUploadErrorFromErrors:errors];
    if ([firstError.domain isEqualToString:FIRStorageErrorCodeDomain]) {
        if (firstError.code == FIRStorageErrorCodeUnauthenticated) {
            return [self pp_mediaLocalizedStringForKey:@"media_upload_login_required_message"
                                              fallback:@"Please sign in again before uploading media."];
        }
        if (firstError.code == FIRStorageErrorCodeUnauthorized) {
            return [self pp_mediaLocalizedStringForKey:@"media_upload_permission_denied_message"
                                              fallback:@"You do not have permission to upload media here."];
        }
    }

    NSString *lowerDescription = firstError.localizedDescription.lowercaseString ?: @"";
    if ([lowerDescription containsString:@"permission"] ||
        [lowerDescription containsString:@"unauthorized"]) {
        return [self pp_mediaLocalizedStringForKey:@"media_upload_permission_denied_message"
                                          fallback:@"You do not have permission to upload media here."];
    }
    if ([lowerDescription containsString:@"unauthenticated"] ||
        [lowerDescription containsString:@"sign in"]) {
        return [self pp_mediaLocalizedStringForKey:@"media_upload_login_required_message"
                                          fallback:@"Please sign in again before uploading media."];
    }

    return firstError.localizedDescription.length > 0
        ? firstError.localizedDescription
        : [self pp_mediaLocalizedStringForKey:@"media_upload_failed_message"
                                     fallback:@"Media upload failed. Please try again."];
}

- (void)pp_logUploadErrors:(NSArray<NSError *> *)errors folder:(NSString *)folder contextID:(NSString *)contextID
{
    for (NSError *error in errors) {
        if (![error isKindOfClass:NSError.class]) {
            continue;
        }
        NSLog(@"[PPImageCollection] Media upload failed | folder=%@ | context=%@ | domain=%@ | code=%ld | message=%@",
              folder ?: @"",
              contextID ?: @"",
              error.domain ?: @"",
              (long)error.code,
              error.localizedDescription ?: @"");
    }
}

- (NSArray<NSDictionary *> *)pp_selectedMediaEntriesSnapshot
{
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    [self.arrayLock lock];
    for (NSInteger idx = 0; idx < self.mediaOutputArray.count; idx++) {
        UIImage *thumbnail = [self.mediaOutputArray[idx] isKindOfClass:UIImage.class] ? self.mediaOutputArray[idx] : nil;
        NSNumber *mediaType = (idx < self.mediaTypeArray.count) ? self.mediaTypeArray[idx] : @(PHAssetMediaTypeImage);
        BOOL storedVideo = mediaType.integerValue == PHAssetMediaTypeVideo;
        if (storedVideo && ![self pp_allowsReusableVideoMedia]) {
            continue;
        }
        BOOL isVideo = storedVideo;
        id videoURL = (idx < self.videoURLArray.count) ? self.videoURLArray[idx] : NSNull.null;
        id preloadedMetadata = (idx < self.preloadedMediaMetadataArray.count) ? self.preloadedMediaMetadataArray[idx] : NSNull.null;
        NSMutableDictionary *entry = [@{
            @"order": @(idx),
            @"media_type": isVideo ? @"video" : @"image"
        } mutableCopy];
        if ([thumbnail isKindOfClass:UIImage.class]) {
            entry[@"image"] = thumbnail;
            entry[@"width"] = @(thumbnail.size.width);
            entry[@"height"] = @(thumbnail.size.height);
        }
        if (isVideo && [videoURL isKindOfClass:NSURL.class]) {
            entry[@"video_url"] = videoURL;
        }
        if ([preloadedMetadata isKindOfClass:NSDictionary.class]) {
            entry[@"existing_metadata"] = preloadedMetadata;
        }
        [entries addObject:entry.copy];
    }
    [self.arrayLock unlock];
    return entries.copy;
}

- (NSArray<NSDictionary *> *)selectedImageMetadata
{
    NSMutableArray<NSDictionary *> *metadata = [NSMutableArray array];
    for (NSDictionary *entry in [self pp_selectedMediaEntriesSnapshot]) {
        if (![entry[@"media_type"] isEqual:@"image"]) {
            continue;
        }
        CGFloat width = [entry[@"width"] doubleValue];
        CGFloat height = [entry[@"height"] doubleValue];
        NSMutableDictionary *item = [@{
            @"width": @(width),
            @"height": @(height),
            @"is_primary": @([entry[@"order"] integerValue] == 0),
            @"order": entry[@"order"] ?: @(metadata.count),
            @"media_type": @"image"
        } mutableCopy];
        if (width > 0.0 && height > 0.0) {
            item[@"aspect_ratio"] = @(width / MAX(height, 1.0));
        }
        [metadata addObject:item.copy];
    }
    return metadata.copy;
}

- (NSArray<NSDictionary *> *)selectedVideoMetadata
{
    if (![self pp_allowsReusableVideoMedia]) {
        return @[];
    }
    NSMutableArray<NSDictionary *> *metadata = [NSMutableArray array];
    for (NSDictionary *entry in [self pp_selectedMediaEntriesSnapshot]) {
        if (![entry[@"media_type"] isEqual:@"video"]) {
            continue;
        }
        NSURL *videoURL = [entry[@"video_url"] isKindOfClass:NSURL.class] ? entry[@"video_url"] : nil;
        NSDictionary *videoInfo = [self pp_videoInfoForURL:videoURL];
        NSMutableDictionary *item = [@{
            @"media_type": @"video",
            @"order": entry[@"order"] ?: @(metadata.count),
            @"thumbnail_width": entry[@"width"] ?: @(0),
            @"thumbnail_height": entry[@"height"] ?: @(0)
        } mutableCopy];
        [item addEntriesFromDictionary:videoInfo ?: @{}];
        [metadata addObject:item.copy];
    }
    return metadata.copy;
}

- (NSArray<NSDictionary *> *)selectedMixedMediaMetadata
{
    NSMutableArray<NSDictionary *> *metadata = [NSMutableArray array];
    NSArray<NSDictionary *> *imageMetadata = [self selectedImageMetadata];
    NSArray<NSDictionary *> *videoMetadata = [self selectedVideoMetadata];
    [metadata addObjectsFromArray:imageMetadata];
    [metadata addObjectsFromArray:videoMetadata];
    [metadata sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"order"] compare:b[@"order"]];
    }];
    return metadata.copy;
}

- (NSString *)pp_safeStorageFolder:(NSString *)storageFolder ownerID:(NSString *)ownerID
{
    NSString *folder = [storageFolder stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (folder.length == 0) {
        NSString *uid = ownerID.length > 0 ? ownerID : (UserManager.sharedManager.currentUser.ID ?: @"unknown");
        folder = [NSString stringWithFormat:@"CardsImages/%@", uid];
    }
    while ([folder hasPrefix:@"/"]) folder = [folder substringFromIndex:1];
    while ([folder hasSuffix:@"/"]) folder = [folder substringToIndex:folder.length - 1];
    return folder;
}

- (NSData *)pp_pngDataForUploadImage:(UIImage *)image maxDimension:(CGFloat)maxDimension
{
    UIImage *source = [self pp_normalizedImageForCollection:image];
    if (![self pp_isRenderableImage:source]) {
        return nil;
    }
    CGFloat largest = MAX(source.size.width, source.size.height);
    if (largest > maxDimension) {
        CGFloat scale = maxDimension / largest;
        CGSize size = CGSizeMake(MAX(1.0, floor(source.size.width * scale)),
                                 MAX(1.0, floor(source.size.height * scale)));
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = 1.0;
        format.opaque = NO;
        source = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            [source drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];
        }];
    }
    return UIImagePNGRepresentation(source);
}

- (NSDictionary *)pp_imageUploadPayloadForImage:(UIImage *)image maxDimension:(CGFloat)maxDimension
{
    UIImage *source = [self pp_normalizedImageForCollection:image];
    if (![self pp_isRenderableImage:source]) {
        return nil;
    }
    CGFloat largest = MAX(source.size.width, source.size.height);
    if (largest > maxDimension) {
        CGFloat scale = maxDimension / largest;
        CGSize size = CGSizeMake(MAX(1.0, floor(source.size.width * scale)),
                                 MAX(1.0, floor(source.size.height * scale)));
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
        format.scale = 1.0;
        format.opaque = NO;
        source = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            [source drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];
        }];
    }

    NSData *data = nil;
    NSString *extension = @"webp";
    NSString *contentType = @"image/webp";
    if (YYImageWebPAvailable() && source.CGImage) {
        data = CFBridgingRelease(YYCGImageCreateEncodedData(source.CGImage, YYImageTypeWebP, 0.84));
    }
    if (data.length == 0) {
        data = UIImageJPEGRepresentation(source, 0.86);
        extension = @"jpg";
        contentType = @"image/jpeg";
    }
    if (data.length == 0) return nil;
    return @{
        @"data": data,
        @"extension": extension,
        @"content_type": contentType,
        @"width": @(source.size.width),
        @"height": @(source.size.height)
    };
}

+ (NSString *)pp_thumbnailStoragePathForVideoPath:(NSString *)storagePath
{
    if (![storagePath isKindOfClass:NSString.class] || storagePath.length == 0) return nil;
    NSString *path = storagePath;
    NSRange videosRange = [path rangeOfString:@"/videos/"];
    if (videosRange.location == NSNotFound) return nil;
    NSString *thumbPath = [path stringByReplacingOccurrencesOfString:@"/videos/" withString:@"/thumbs/"];
    NSString *extension = thumbPath.pathExtension;
    if (extension.length > 0) {
        thumbPath = [thumbPath stringByDeletingPathExtension];
    }
    return [thumbPath stringByAppendingPathExtension:@"webp"];
}

+ (void)pp_deleteStorageReferenceRecursively:(FIRStorageReference *)reference
                                  completion:(void(^)(NSError * _Nullable error))completion
{
    [reference listAllWithCompletion:^(FIRStorageListResult * _Nullable result, NSError * _Nullable error) {
        if (error) {
            if (completion) completion(error);
            return;
        }

        dispatch_group_t group = dispatch_group_create();
        __block NSError *firstError = nil;
        NSLock *lock = [NSLock new];

        for (FIRStorageReference *item in result.items) {
            dispatch_group_enter(group);
            [item deleteWithCompletion:^(NSError * _Nullable deleteError) {
                if (deleteError) {
                    [lock lock];
                    if (!firstError) firstError = deleteError;
                    [lock unlock];
                }
                dispatch_group_leave(group);
            }];
        }

        for (FIRStorageReference *prefix in result.prefixes) {
            dispatch_group_enter(group);
            [self pp_deleteStorageReferenceRecursively:prefix completion:^(NSError * _Nullable nestedError) {
                if (nestedError) {
                    [lock lock];
                    if (!firstError) firstError = nestedError;
                    [lock unlock];
                }
                dispatch_group_leave(group);
            }];
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (completion) completion(firstError);
        });
    }];
}

+ (void)uploadMediaWithEntityType:(NSString *)entityType
                          entityID:(NSString *)entityID
                              file:(id)file
                         mediaType:(NSString *)mediaType
                           ownerID:(NSString *)ownerID
                        completion:(PPImageCollectionSingleMediaCompletion)completion
{
    NSString *uid = ownerID.length > 0 ? ownerID : (UserManager.sharedManager.currentUser.ID ?: @"unknown");
    NSString *normalizedType = PPImageCollectionNormalizedEntityType(entityType);
    NSString *mediaID = NSUUID.UUID.UUIDString;
    BOOL isVideo = [[[mediaType isKindOfClass:NSString.class] ? mediaType : @"" lowercaseString] containsString:@"video"];

    if (!isVideo && [file isKindOfClass:UIImage.class]) {
        NSDictionary *payload = PPImageCollectionImageUploadPayload(file, 2048.0);
        NSData *data = payload[@"data"];
        if (data.length == 0) {
            NSString *message = kLang(@"invalid_image_upload_message");
            if (![message isKindOfClass:NSString.class] || message.length == 0 || [message isEqualToString:@"invalid_image_upload_message"]) {
                message = @"One selected image could not be prepared.";
            }
            if (completion) completion(nil, [NSError errorWithDomain:@"PPImageCollectionMediaUpload"
                                                                 code:20
                                                             userInfo:@{NSLocalizedDescriptionKey: message}]);
            return;
        }

        NSString *storagePath = PPImageCollectionStoragePath(normalizedType, entityID, mediaID, mediaType, payload[@"extension"]);
        FIRStorageReference *ref = [[FIRStorage storage].reference child:storagePath];
        FIRStorageMetadata *metadata = [FIRStorageMetadata new];
        metadata.contentType = payload[@"content_type"] ?: @"image/webp";
        metadata.customMetadata = @{
            @"uploaded_by": uid ?: @"unknown",
            @"entity_type": normalizedType ?: @"unknown",
            @"entity_id": PPImageCollectionCleanPathComponent(entityID),
            @"media_id": mediaID,
            @"media_type": @"image"
        };

        [ref putData:data metadata:metadata completion:^(FIRStorageMetadata * _Nullable firebaseMetadata, NSError * _Nullable error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            [ref downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable urlError) {
                if (!downloadURL || urlError) {
                    if (completion) completion(nil, urlError);
                    return;
                }
                if (completion) {
                    completion(@{
                        @"url": downloadURL.absoluteString,
                        @"storage_path": storagePath,
                        @"media_id": mediaID,
                        @"media_type": @"image",
                        @"content_type": metadata.contentType ?: @"image/webp",
                        @"width": payload[@"width"] ?: @0,
                        @"height": payload[@"height"] ?: @0,
                        @"file_size": @(data.length)
                    }, nil);
                }
            }];
        }];
        return;
    }

    if (isVideo && [file isKindOfClass:NSURL.class]) {
        NSURL *videoURL = (NSURL *)file;
        NSString *storagePath = PPImageCollectionStoragePath(normalizedType, entityID, mediaID, @"video", @"mp4");
        UIImage *thumbnail = PPImageCollectionThumbnailForVideoURL(videoURL);
        NSDictionary *thumbnailPayload = PPImageCollectionImageUploadPayload(thumbnail, 1280.0);
        NSData *thumbnailData = thumbnailPayload[@"data"];
        if (thumbnailData.length == 0) {
            NSString *message = kLang(@"video_processing_failed_message");
            if (![message isKindOfClass:NSString.class] || message.length == 0 || [message isEqualToString:@"video_processing_failed_message"]) {
                message = @"The selected video could not be processed.";
            }
            if (completion) completion(nil, [NSError errorWithDomain:@"PPImageCollectionMediaUpload"
                                                                 code:31
                                                             userInfo:@{NSLocalizedDescriptionKey: message}]);
            return;
        }
        NSString *thumbPath = PPImageCollectionStoragePath(normalizedType, entityID, mediaID, @"thumb", thumbnailPayload[@"extension"]);
        FIRStorageReference *ref = [[FIRStorage storage].reference child:storagePath];
        FIRStorageReference *thumbRef = [[FIRStorage storage].reference child:thumbPath];

        FIRStorageMetadata *thumbMetadata = [FIRStorageMetadata new];
        thumbMetadata.contentType = thumbnailPayload[@"content_type"] ?: @"image/webp";
        thumbMetadata.customMetadata = @{
            @"uploaded_by": uid ?: @"unknown",
            @"entity_type": normalizedType ?: @"unknown",
            @"entity_id": PPImageCollectionCleanPathComponent(entityID),
            @"media_id": mediaID,
            @"media_type": @"video_thumbnail"
        };

        FIRStorageMetadata *metadata = [FIRStorageMetadata new];
        metadata.contentType = PPImageCollectionVideoContentTypeForURL(videoURL);
        metadata.customMetadata = @{
            @"uploaded_by": uid ?: @"unknown",
            @"entity_type": normalizedType ?: @"unknown",
            @"entity_id": PPImageCollectionCleanPathComponent(entityID),
            @"media_id": mediaID,
            @"media_type": @"video",
            @"thumbnail_path": thumbPath
        };

        [thumbRef putData:thumbnailData metadata:thumbMetadata completion:^(__unused FIRStorageMetadata * _Nullable thumbFirebaseMetadata, NSError * _Nullable thumbError) {
            if (thumbError) {
                if (completion) completion(nil, thumbError);
                return;
            }

            [thumbRef downloadURLWithCompletion:^(NSURL * _Nullable thumbDownloadURL, NSError * _Nullable thumbURLError) {
                if (!thumbDownloadURL || thumbURLError) {
                    if (completion) completion(nil, thumbURLError);
                    return;
                }

                BOOL didAccess = [videoURL startAccessingSecurityScopedResource];
                [ref putFile:videoURL metadata:metadata completion:^(__unused FIRStorageMetadata * _Nullable firebaseMetadata, NSError * _Nullable error) {
                    if (didAccess) [videoURL stopAccessingSecurityScopedResource];
                    if (error) {
                        if (completion) completion(nil, error);
                        return;
                    }
                    [ref downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable urlError) {
                        if (!downloadURL || urlError) {
                            if (completion) completion(nil, urlError);
                            return;
                        }
                        if (completion) {
                            completion(@{
                                @"url": downloadURL.absoluteString,
                                @"storage_path": storagePath,
                                @"thumbnail_url": thumbDownloadURL.absoluteString,
                                @"thumbnail_storage_path": thumbPath,
                                @"thumbnail_file_size": @(thumbnailData.length),
                                @"media_id": mediaID,
                                @"media_type": @"video",
                                @"content_type": metadata.contentType ?: @"video/mp4"
                            }, nil);
                        }
                    }];
                }];
            }];
        }];
        return;
    }

    if (completion) {
        NSString *message = kLang(@"invalid_video_upload_message");
        if (![message isKindOfClass:NSString.class] || message.length == 0 || [message isEqualToString:@"invalid_video_upload_message"]) {
            message = @"One selected video is unsupported.";
        }
        completion(nil, [NSError errorWithDomain:@"PPImageCollectionMediaUpload"
                                            code:22
                                        userInfo:@{NSLocalizedDescriptionKey: message}]);
    }
}

+ (void)deleteMediaAtStoragePath:(NSString *)storagePath
                       completion:(void (^)(NSError * _Nullable))completion
{
    NSString *path = [storagePath isKindOfClass:NSString.class] ? storagePath : @"";
    if (path.length == 0) {
        if (completion) completion(nil);
        return;
    }
    FIRStorageReference *ref = [[FIRStorage storage].reference child:path];
    [ref deleteWithCompletion:^(NSError * _Nullable error) {
        if (completion) completion(error);
    }];
}

+ (void)replaceMediaAtOldStoragePath:(NSString *)oldStoragePath
                           entityType:(NSString *)entityType
                             entityID:(NSString *)entityID
                                 file:(id)file
                            mediaType:(NSString *)mediaType
                              ownerID:(NSString *)ownerID
                            completion:(PPImageCollectionSingleMediaCompletion)completion
{
    [self uploadMediaWithEntityType:entityType entityID:entityID file:file mediaType:mediaType ownerID:ownerID completion:^(NSDictionary * _Nullable metadata, NSError * _Nullable error) {
        if (error || !metadata) {
            if (completion) completion(metadata, error);
            return;
        }

        NSMutableDictionary *replacement = [metadata mutableCopy];
        if (oldStoragePath.length > 0) {
            replacement[@"old_storage_path"] = oldStoragePath;
        }
        NSString *oldThumbPath = [self pp_thumbnailStoragePathForVideoPath:oldStoragePath];
        if (oldThumbPath.length > 0) {
            replacement[@"old_thumbnail_storage_path"] = oldThumbPath;
        }
        if (completion) completion(replacement.copy, nil);
    }];
}

+ (void)deleteEntityMediaWithEntityType:(NSString *)entityType
                               entityID:(NSString *)entityID
                             completion:(void (^)(NSError * _Nullable))completion
{
    NSString *normalizedType = PPImageCollectionNormalizedEntityType(entityType);
    NSString *safeEntityID = PPImageCollectionCleanPathComponent(entityID);
    NSString *folderPath = [normalizedType isEqualToString:@"users"]
        ? [NSString stringWithFormat:@"%@/users/%@/profile", PPAppMediaUploadsRoot, safeEntityID]
        : [NSString stringWithFormat:@"%@/%@/%@", PPAppMediaUploadsRoot, normalizedType, safeEntityID];
    FIRStorageReference *folderRef = [[FIRStorage storage].reference child:folderPath];
    [self pp_deleteStorageReferenceRecursively:folderRef completion:completion];
}

- (NSDictionary *)pp_videoInfoForURL:(NSURL *)videoURL
{
    if (![videoURL isKindOfClass:NSURL.class]) {
        return @{};
    }
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
    CMTime duration = asset.duration;
    Float64 seconds = CMTIME_IS_NUMERIC(duration) ? CMTimeGetSeconds(duration) : 0.0;

    CGSize pixelSize = CGSizeZero;
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (track) {
        CGSize natural = track.naturalSize;
        CGSize transformed = CGSizeApplyAffineTransform(natural, track.preferredTransform);
        pixelSize = CGSizeMake(fabs(transformed.width), fabs(transformed.height));
    }

    unsigned long long fileSize = 0;
    if (videoURL.isFileURL) {
        NSNumber *sizeNumber = nil;
        [videoURL getResourceValue:&sizeNumber forKey:NSURLFileSizeKey error:nil];
        fileSize = sizeNumber.unsignedLongLongValue;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"duration"] = @(MAX(seconds, 0.0));
    info[@"file_size"] = @(fileSize);
    info[@"width"] = @(pixelSize.width);
    info[@"height"] = @(pixelSize.height);
    if (pixelSize.width > 0.0 && pixelSize.height > 0.0) {
        info[@"aspect_ratio"] = @(pixelSize.width / MAX(pixelSize.height, 1.0));
    }
    return info.copy;
}

- (NSString *)pp_videoContentTypeForURL:(NSURL *)url
{
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mov"] || [ext isEqualToString:@"qt"]) {
        return @"video/quicktime";
    }
    if ([ext isEqualToString:@"m4v"]) {
        return @"video/x-m4v";
    }
    return @"video/mp4";
}

- (void)uploadSelectedMediaWithStorageFolder:(NSString *)storageFolder
                                     ownerID:(NSString *)ownerID
                                   contextID:(NSString *)contextID
                                  completion:(PPImageCollectionMediaUploadCompletion)completion
{
    NSArray<NSDictionary *> *entries = [self pp_selectedMediaEntriesSnapshot];
    if (entries.count == 0) {
        if (completion) {
            completion(nil, [self pp_mediaErrorWithCode:10
                                            description:[self pp_mediaLocalizedStringForKey:@"please_add_photos_before_submit"
                                                                                   fallback:@"Please add at least one image before posting."]
                                               userInfo:nil]);
        }
        return;
    }

    NSString *uid = ownerID.length > 0 ? ownerID : (UserManager.sharedManager.currentUser.ID ?: @"unknown");
    NSString *entityType = PPImageCollectionNormalizedEntityType(storageFolder);
    NSString *safeContextID = contextID.length > 0 ? contextID : NSUUID.UUID.UUIDString;

    NSMutableArray *mixedSlots = [NSMutableArray arrayWithCapacity:entries.count];
    for (__unused NSDictionary *entry in entries) {
        [mixedSlots addObject:NSNull.null];
    }
    NSMutableArray<NSError *> *errors = [NSMutableArray array];
    NSLock *resultLock = [NSLock new];
    dispatch_group_t group = dispatch_group_create();

    for (NSDictionary *entry in entries) {
        NSInteger order = [entry[@"order"] integerValue];
        NSString *mediaType = [entry[@"media_type"] isKindOfClass:NSString.class] ? entry[@"media_type"] : @"image";
        UIImage *image = [entry[@"image"] isKindOfClass:UIImage.class] ? entry[@"image"] : nil;
        BOOL isVideo = [mediaType isEqualToString:@"video"] && [self pp_allowsReusableVideoMedia];
        NSDictionary *existingMetadata = [entry[@"existing_metadata"] isKindOfClass:NSDictionary.class] ? entry[@"existing_metadata"] : nil;

        if (existingMetadata.count > 0) {
            NSDictionary *normalizedExisting = [self pp_normalizedExistingMetadata:existingMetadata order:order];
            if (normalizedExisting) {
                [resultLock lock];
                if (order >= 0 && order < mixedSlots.count) {
                    mixedSlots[order] = normalizedExisting;
                }
                [resultLock unlock];
                continue;
            }
        }

        if (!isVideo) {
            dispatch_group_enter(group);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                NSDictionary *imagePayload = PPImageCollectionImageUploadPayload(image, 2048.0);
                NSData *imageData = imagePayload[@"data"];
                if (imageData.length == 0) {
                    [resultLock lock];
                    [errors addObject:[self pp_mediaErrorWithCode:20
                                                      description:[self pp_mediaLocalizedStringForKey:@"invalid_image_upload_message"
                                                                                             fallback:@"One selected image could not be prepared."]
                                                         userInfo:@{@"order": @(order)}]];
                    [resultLock unlock];
                    dispatch_group_leave(group);
                    return;
                }

                NSInteger timestamp = (NSInteger)NSDate.date.timeIntervalSince1970;
                NSString *mediaID = NSUUID.UUID.UUIDString;
                NSString *storagePath = PPImageCollectionStoragePath(entityType, safeContextID, mediaID, @"image", imagePayload[@"extension"]);
                FIRStorageReference *ref = [[FIRStorage storage].reference child:storagePath];
                FIRStorageMetadata *metadata = [FIRStorageMetadata new];
                metadata.contentType = imagePayload[@"content_type"] ?: @"image/webp";
                metadata.customMetadata = @{
                    @"uploaded_by": uid ?: @"unknown",
                    @"context_id": safeContextID ?: @"unknown",
                    @"entity_type": entityType ?: @"unknown",
                    @"entity_id": safeContextID ?: @"unknown",
                    @"media_id": mediaID ?: @"unknown",
                    @"upload_timestamp": @(timestamp).stringValue,
                    @"image_width": @(image.size.width).stringValue,
                    @"image_height": @(image.size.height).stringValue,
                    @"file_size": @(imageData.length).stringValue,
                    @"media_type": @"image",
                    @"is_primary": (order == 0) ? @"true" : @"false"
                };

                [ref putData:imageData metadata:metadata completion:^(FIRStorageMetadata * _Nullable firebaseMetadata, NSError * _Nullable error) {
                    if (error) {
                        [resultLock lock];
                        [errors addObject:error];
                        [resultLock unlock];
                        dispatch_group_leave(group);
                        return;
                    }
                    [ref downloadURLWithCompletion:^(NSURL * _Nullable downloadURL, NSError * _Nullable urlError) {
                        if (urlError || !downloadURL) {
                            [resultLock lock];
                            [errors addObject:urlError ?: [self pp_mediaErrorWithCode:21
                                                                          description:[self pp_mediaLocalizedStringForKey:@"media_upload_failed_message"
                                                                                                                 fallback:@"Media upload failed. Please try again."]
                                                                             userInfo:@{@"order": @(order)}]];
                            [resultLock unlock];
                        } else {
                            CGFloat width = image.size.width;
                            CGFloat height = image.size.height;
                            NSMutableDictionary *item = [@{
                                @"url": downloadURL.absoluteString,
                                @"width": @(width),
                                @"height": @(height),
                                @"file_size": @(imageData.length),
                                @"is_primary": @(order == 0),
                                @"order": @(order),
                                @"media_id": mediaID,
                                @"storage_path": storagePath,
                                @"uploaded_at": metadata.customMetadata[@"upload_timestamp"] ?: @"",
                                @"media_type": @"image",
                                @"content_type": metadata.contentType ?: @"image/webp"
                            } mutableCopy];
                            if (width > 0.0 && height > 0.0) {
                                item[@"aspect_ratio"] = @(width / MAX(height, 1.0));
                            }
                            [resultLock lock];
                            if (order >= 0 && order < mixedSlots.count) {
                                mixedSlots[order] = item.copy;
                            }
                            [resultLock unlock];
                        }
                        dispatch_group_leave(group);
                    }];
                }];
            });
            continue;
        }

        NSURL *videoURL = [entry[@"video_url"] isKindOfClass:NSURL.class] ? entry[@"video_url"] : nil;
        if (!videoURL.isFileURL) {
            [errors addObject:[self pp_mediaErrorWithCode:30
                                             description:[self pp_mediaLocalizedStringForKey:@"invalid_video_upload_message"
                                                                                    fallback:@"One selected video is unsupported."]
                                                userInfo:@{@"order": @(order)}]];
            continue;
        }

        dispatch_group_enter(group);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                UIImage *thumbnail = [self pp_isRenderableImage:image] ? image : [self pp_thumbnailForVideoURL:videoURL];
            NSDictionary *thumbnailPayload = PPImageCollectionImageUploadPayload(thumbnail, 1280.0);
            NSData *thumbnailData = thumbnailPayload[@"data"];
            if (thumbnailData.length == 0) {
                [resultLock lock];
                [errors addObject:[self pp_mediaErrorWithCode:31
                                                  description:[self pp_mediaLocalizedStringForKey:@"video_processing_failed_message"
                                                                                         fallback:@"The selected video could not be processed."]
                                                     userInfo:@{@"order": @(order)}]];
                [resultLock unlock];
                dispatch_group_leave(group);
                return;
            }

            NSDictionary *videoInfo = [self pp_videoInfoForURL:videoURL];
            if (![self pp_videoDurationIsAllowed:[videoInfo[@"duration"] doubleValue]] ||
                [videoInfo[@"width"] doubleValue] <= 0.0 ||
                [videoInfo[@"height"] doubleValue] <= 0.0) {
                [resultLock lock];
                [errors addObject:[self pp_mediaErrorWithCode:34
                                                  description:[self pp_mediaLocalizedStringForKey:@"invalid_video_upload_message"
                                                                                         fallback:@"One selected video is unsupported."]
                                                     userInfo:@{@"order": @(order)}]];
                [resultLock unlock];
                dispatch_group_leave(group);
                return;
            }
            NSInteger timestamp = (NSInteger)NSDate.date.timeIntervalSince1970;
            NSString *mediaID = NSUUID.UUID.UUIDString;
            NSString *videoPath = PPImageCollectionStoragePath(entityType, safeContextID, mediaID, @"video", @"mp4");
            NSString *thumbPath = PPImageCollectionStoragePath(entityType, safeContextID, mediaID, @"thumb", thumbnailPayload[@"extension"]);
            FIRStorageReference *videoRef = [[FIRStorage storage].reference child:videoPath];
            FIRStorageReference *thumbRef = [[FIRStorage storage].reference child:thumbPath];

            FIRStorageMetadata *thumbMetadata = [FIRStorageMetadata new];
            thumbMetadata.contentType = thumbnailPayload[@"content_type"] ?: @"image/webp";
            thumbMetadata.customMetadata = @{
                @"uploaded_by": uid ?: @"unknown",
                @"context_id": safeContextID ?: @"unknown",
                @"entity_type": entityType ?: @"unknown",
                @"entity_id": safeContextID ?: @"unknown",
                @"media_id": mediaID ?: @"unknown",
                @"upload_timestamp": @(timestamp).stringValue,
                @"media_type": @"video_thumbnail",
                @"thumbnail_width": @(thumbnail.size.width).stringValue,
                @"thumbnail_height": @(thumbnail.size.height).stringValue,
                @"file_size": @(thumbnailData.length).stringValue
            };

            [thumbRef putData:thumbnailData metadata:thumbMetadata completion:^(FIRStorageMetadata * _Nullable thumbFirebaseMetadata, NSError * _Nullable thumbError) {
                if (thumbError) {
                    [resultLock lock];
                    [errors addObject:thumbError];
                    [resultLock unlock];
                    dispatch_group_leave(group);
                    return;
                }

                [thumbRef downloadURLWithCompletion:^(NSURL * _Nullable thumbDownloadURL, NSError * _Nullable thumbURLError) {
                    if (thumbURLError || !thumbDownloadURL) {
                        [resultLock lock];
                        [errors addObject:thumbURLError ?: [self pp_mediaErrorWithCode:32
                                                                           description:[self pp_mediaLocalizedStringForKey:@"media_upload_failed_message"
                                                                                                                  fallback:@"Media upload failed. Please try again."]
                                                                              userInfo:@{@"order": @(order)}]];
                        [resultLock unlock];
                        dispatch_group_leave(group);
                        return;
                    }

                    FIRStorageMetadata *videoMetadata = [FIRStorageMetadata new];
                    videoMetadata.contentType = PPImageCollectionVideoContentTypeForURL(videoURL);
                    videoMetadata.customMetadata = @{
                        @"uploaded_by": uid ?: @"unknown",
                        @"context_id": safeContextID ?: @"unknown",
                        @"entity_type": entityType ?: @"unknown",
                        @"entity_id": safeContextID ?: @"unknown",
                        @"media_id": mediaID ?: @"unknown",
                        @"upload_timestamp": @(timestamp).stringValue,
                        @"media_type": @"video",
                        @"duration": [videoInfo[@"duration"] stringValue] ?: @"0",
                        @"video_width": [videoInfo[@"width"] stringValue] ?: @"0",
                        @"video_height": [videoInfo[@"height"] stringValue] ?: @"0",
                        @"file_size": [videoInfo[@"file_size"] stringValue] ?: @"0",
                        @"thumbnail_path": thumbPath
                    };

                    BOOL didAccess = [videoURL startAccessingSecurityScopedResource];
                    [videoRef putFile:videoURL metadata:videoMetadata completion:^(FIRStorageMetadata * _Nullable firebaseMetadata, NSError * _Nullable videoError) {
                        if (didAccess) {
                            [videoURL stopAccessingSecurityScopedResource];
                        }
                        if (videoError) {
                            [resultLock lock];
                            [errors addObject:videoError];
                            [resultLock unlock];
                            dispatch_group_leave(group);
                            return;
                        }
                        [videoRef downloadURLWithCompletion:^(NSURL * _Nullable videoDownloadURL, NSError * _Nullable videoURLError) {
                            if (videoURLError || !videoDownloadURL) {
                                [resultLock lock];
                                [errors addObject:videoURLError ?: [self pp_mediaErrorWithCode:33
                                                                                  description:[self pp_mediaLocalizedStringForKey:@"media_upload_failed_message"
                                                                                                                         fallback:@"Media upload failed. Please try again."]
                                                                                     userInfo:@{@"order": @(order)}]];
                                [resultLock unlock];
                            } else {
                                NSMutableDictionary *item = [@{
                                    @"url": videoDownloadURL.absoluteString,
                                    @"media_id": mediaID,
                                    @"storage_path": videoPath,
                                    @"thumbnail_url": thumbDownloadURL.absoluteString,
                                    @"thumbnail_storage_path": thumbPath,
                                    @"thumbnail_width": @(thumbnail.size.width),
                                    @"thumbnail_height": @(thumbnail.size.height),
                                    @"thumbnail_file_size": @(thumbnailData.length),
                                    @"media_type": @"video",
                                    @"content_type": videoMetadata.contentType ?: @"video/mp4",
                                    @"is_primary": @(order == 0),
                                    @"order": @(order),
                                    @"uploaded_at": videoMetadata.customMetadata[@"upload_timestamp"] ?: @""
                                } mutableCopy];
                                [item addEntriesFromDictionary:videoInfo ?: @{}];
                                [resultLock lock];
                                if (order >= 0 && order < mixedSlots.count) {
                                    mixedSlots[order] = item.copy;
                                }
                                [resultLock unlock];
                            }
                            dispatch_group_leave(group);
                        }];
                    }];
                }];
            }];
        });
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (errors.count > 0) {
            [self pp_logUploadErrors:errors folder:entityType contextID:safeContextID];
            NSString *description = [self pp_userVisibleUploadFailureDescriptionForErrors:errors];
            if (completion) {
                completion(nil, [self pp_mediaErrorWithCode:40
                                                description:description
                                                   userInfo:@{@"underlyingErrors": errors.copy}]);
            }
            return;
        }

        NSMutableArray<NSDictionary *> *mixed = [NSMutableArray array];
        for (id candidate in mixedSlots) {
            if ([candidate isKindOfClass:NSDictionary.class]) {
                [mixed addObject:candidate];
            }
        }
        if (mixed.count != entries.count) {
            if (completion) {
                completion(nil, [self pp_mediaErrorWithCode:41
                                                description:[self pp_mediaLocalizedStringForKey:@"media_upload_incomplete_message"
                                                                                       fallback:@"Media upload did not complete. Please try again."]
                                                   userInfo:@{@"expected": @(entries.count), @"received": @(mixed.count)}]);
            }
            return;
        }

        NSMutableArray<NSString *> *imageURLs = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *imageMetadata = [NSMutableArray array];
        NSMutableArray<NSString *> *videoURLs = [NSMutableArray array];
        NSMutableArray<NSDictionary *> *videoMetadata = [NSMutableArray array];
        for (NSDictionary *item in mixed) {
            NSString *type = [item[@"media_type"] isKindOfClass:NSString.class] ? item[@"media_type"] : @"image";
            NSString *url = [item[@"url"] isKindOfClass:NSString.class] ? item[@"url"] : @"";
            if ([type isEqualToString:@"video"]) {
                if (url.length > 0) [videoURLs addObject:url];
                [videoMetadata addObject:item];
            } else {
                if (url.length > 0) [imageURLs addObject:url];
                [imageMetadata addObject:item];
            }
        }

        PPMediaUploadResult *result = [[PPMediaUploadResult alloc] initWithImageURLs:imageURLs
                                                                       imageMetadata:imageMetadata
                                                                           videoURLs:videoURLs
                                                                       videoMetadata:videoMetadata
                                                                        mixedMetadata:mixed];
        if (completion) {
            completion(result, nil);
        }
    });
}

#pragma mark - Preloading Images

- (void)preloadImagesFromURLs:(NSArray<NSString *> *)urls completion:(void(^)(void))completion {
    if (urls.count == 0) {
        if (completion) completion();
        return;
    }
    
    [self clearAllImages];
    
    // Create placeholders
    for (NSInteger i = 0; i < urls.count; i++) {
        [self.arrayLock lock];
        [self pp_ensureMutableCollections];
        [self.mediaOutputArray addObject:[UIImage new]];
        [self.mediaTypeArray addObject:@(PHAssetMediaTypeImage)];
        [self.videoURLArray addObject:(NSURL *)NSNull.null];
        [self.preloadedMediaMetadataArray addObject:NSNull.null];
        [self.imageManager.selectedImages addObject:[UIImage new]];
        NSString *placeholder = [self pp_uniqueAssetPlaceholder];
        if (placeholder.length > 0) {
            [self.imageManager.assetArray addObject:placeholder];
        }
        [self.arrayLock unlock];
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSInteger i = 0; i < urls.count; i++) {
        NSString *urlStr = urls[i];
        NSURL *url = [NSURL URLWithString:urlStr];
        if (!url) continue;
        
        dispatch_group_enter(group);
        
        // Using system URLSession for simplicity
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            UIImage *image = nil;
            if (data && !error) {
                image = [self pp_downsampledImageFromData:data
                                             maxPixelSize:PPImageCollectionRemoteImageMaxPixelSize];
            }
            
            UIImage *finalImage = image ?: [UIImage new];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.arrayLock lock];
                if (i < self.mediaOutputArray.count) {
                    [self.mediaOutputArray replaceObjectAtIndex:i withObject:finalImage];
                }
                if (i < self.imageManager.selectedImages.count) {
                    [self.imageManager.selectedImages replaceObjectAtIndex:i withObject:finalImage];
                }
                [self.arrayLock unlock];
                
                dispatch_group_leave(group);
            });
        }];
        [task resume];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSArray<UIImage *> *cleanImages = [self pp_sanitizedImagesFromArray:self.mediaOutputArray];
        NSArray *assetEntries = [self.imageManager.assetArray.array copy] ?: @[];
        NSMutableArray *cleanAssets = [NSMutableArray arrayWithCapacity:cleanImages.count];
        for (NSUInteger idx = 0; idx < cleanImages.count; idx++) {
            id entry = (idx < assetEntries.count) ? assetEntries[idx] : nil;
            if (!entry) {
                entry = [self pp_uniqueAssetPlaceholder];
            }
            if (entry) {
                [cleanAssets addObject:entry];
            }
        }
        [self.arrayLock lock];
        [self pp_ensureMutableCollections];
        [self.mediaOutputArray removeAllObjects];
        [self.mediaOutputArray addObjectsFromArray:cleanImages];
        [self.mediaTypeArray removeAllObjects];
        [self.videoURLArray removeAllObjects];
        [self.preloadedMediaMetadataArray removeAllObjects];
        for (__unused UIImage *image in cleanImages) {
            [self.mediaTypeArray addObject:@(PHAssetMediaTypeImage)];
            [self.videoURLArray addObject:(NSURL *)NSNull.null];
            [self.preloadedMediaMetadataArray addObject:NSNull.null];
        }
        self.imageManager.selectedImages = [cleanImages mutableCopy];
        self.imageManager.assetArray = [NSMutableOrderedSet orderedSetWithArray:cleanAssets];
        [self.arrayLock unlock];
        
        [self reloadCollectionView];
        [self notifyDelegate];
        
        if (completion) completion();
    });
}

- (void)preloadMediaMetadata:(NSArray<NSDictionary *> *)metadata completion:(void(^)(void))completion {
    if (![metadata isKindOfClass:NSArray.class] || metadata.count == 0) {
        if (completion) completion();
        return;
    }

    NSMutableArray<NSDictionary *> *validMetadata = [NSMutableArray array];
    for (id candidate in metadata) {
        if (![candidate isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSString *displayURL = [self pp_displayURLForMediaMetadata:(NSDictionary *)candidate];
        if (displayURL.length == 0) {
            continue;
        }
        [validMetadata addObject:(NSDictionary *)candidate];
    }

    if (validMetadata.count == 0) {
        if (completion) completion();
        return;
    }

    [self clearAllImages];

    for (NSDictionary *item in validMetadata) {
        BOOL isVideo = [self pp_mediaMetadataIsVideo:item];
        [self.arrayLock lock];
        [self pp_ensureMutableCollections];
        [self.mediaOutputArray addObject:[UIImage new]];
        [self.mediaTypeArray addObject:@(isVideo ? PHAssetMediaTypeVideo : PHAssetMediaTypeImage)];
        [self.videoURLArray addObject:NSNull.null];
        [self.preloadedMediaMetadataArray addObject:item];
        [self.imageManager.selectedImages addObject:[UIImage new]];
        NSString *placeholder = [self pp_uniqueAssetPlaceholder];
        if (placeholder.length > 0) {
            [self.imageManager.assetArray addObject:placeholder];
        }
        [self.arrayLock unlock];
    }

    dispatch_group_t group = dispatch_group_create();

    for (NSInteger i = 0; i < validMetadata.count; i++) {
        NSDictionary *item = validMetadata[i];
        NSString *urlString = [self pp_displayURLForMediaMetadata:item];
        NSURL *url = [NSURL URLWithString:urlString];
        if (![url isKindOfClass:NSURL.class]) {
            continue;
        }

        dispatch_group_enter(group);
        NSURLSessionDataTask *task =
        [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            (void)response;
            UIImage *image = nil;
            if (data.length > 0 && !error) {
                image = [self pp_downsampledImageFromData:data
                                             maxPixelSize:PPImageCollectionRemoteImageMaxPixelSize];
            }
            UIImage *finalImage = [self pp_isRenderableImage:image] ? image : [UIImage new];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.arrayLock lock];
                if (i < self.mediaOutputArray.count) {
                    [self.mediaOutputArray replaceObjectAtIndex:i withObject:finalImage];
                }
                if (i < self.imageManager.selectedImages.count) {
                    [self.imageManager.selectedImages replaceObjectAtIndex:i withObject:finalImage];
                }
                [self.arrayLock unlock];
                dispatch_group_leave(group);
            });
        }];
        [task resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self reloadCollectionView];
        [self notifyDelegate];
        if (completion) completion();
    });
}

#pragma mark - Collection View Data Source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger imageCount = [self imageCount];
    BOOL shouldShowAddButton = (imageCount < self.maxImageCount);
    return imageCount + (shouldShowAddButton ? 1 : 0);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger imageCount = [self imageCount];
    BOOL shouldShowAddButton = (imageCount < self.maxImageCount);
    BOOL isAddButtonCell = shouldShowAddButton && (indexPath.item == imageCount);
    
    if (isAddButtonCell) {
        AddButtonCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AddButtonCell" forIndexPath:indexPath];
        NSString *buttonTitle = (imageCount == 0)
            ? (self.titleText.length > 0 ? self.titleText : [self pp_localizedSheetStringForKey:@"add.images.here" fallback:@"Add images here"])
            : @"";
        [cell setButtonTitle:buttonTitle];
        [cell setButtonSymbol:@"photo.badge.plus"];
        __weak typeof(self) weakSelf = self;
        __weak AddButtonCell *weakCell = cell;
        if (@available(iOS 14.0, *)) {
            [cell setPrimaryMenu:nil];
        }
        cell.onTap = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(imageCollectionDidRequestAddImage:)]) {
                [weakSelf.delegate imageCollectionDidRequestAddImage:weakSelf];
                return;
            }
            UIViewController *presentingVC = [weakSelf pp_bestPresentingViewController:nil];
            UIView *anchorView = weakCell ?: weakSelf.collectionView;
            [weakSelf pp_presentAddImageOptionsFromViewController:presentingVC sourceView:anchorView];
        };
        return cell;
    }
    
    // Image cell
    PP_ImageCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PP_ImageCell" forIndexPath:indexPath];
    cell.imageView.image = nil;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    cell.imageView.backgroundColor = UIColor.clearColor;
    UIView *oldVideoBadge = [cell.contentView viewWithTag:9092];
    [oldVideoBadge removeFromSuperview];
    
    if (indexPath.item < imageCount) {
        UIImage *candidate = (indexPath.item < self.mediaOutputArray.count && [self.mediaOutputArray[indexPath.item] isKindOfClass:[UIImage class]])
            ? (UIImage *)self.mediaOutputArray[indexPath.item]
            : nil;
        if ([self pp_isRenderableImage:candidate]) {
            cell.imageView.image = candidate;
            cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
            cell.imageView.backgroundColor = UIColor.clearColor;
            NSNumber *mediaType = (indexPath.item < self.mediaTypeArray.count) ? self.mediaTypeArray[indexPath.item] : @(PHAssetMediaTypeImage);
            if ([self pp_allowsReusableVideoMedia] && mediaType.integerValue == PHAssetMediaTypeVideo) {
                UIImageView *badge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
                badge.tag = 9092;
                badge.translatesAutoresizingMaskIntoConstraints = NO;
                badge.tintColor = UIColor.whiteColor;
                badge.contentMode = UIViewContentModeScaleAspectFit;
                badge.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.18];
                badge.layer.cornerRadius = 17.0;
                badge.clipsToBounds = YES;
                [cell.contentView addSubview:badge];
                [NSLayoutConstraint activateConstraints:@[
                    [badge.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
                    [badge.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                    [badge.widthAnchor constraintEqualToConstant:34.0],
                    [badge.heightAnchor constraintEqualToConstant:34.0]
                ]];
            }
        } else {
            UIImage *placeholder = [UIImage systemImageNamed:@"photo"];
            cell.imageView.image = placeholder;
            cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
            cell.imageView.tintColor = [UIColor secondaryLabelColor];
            cell.imageView.backgroundColor = [UIColor tertiarySystemFillColor];
        }
    }
    
    __weak typeof(self) weakSelf = self;
    __weak PP_ImageCell *weakCell = cell;
    cell.onDelete = ^{
        PP_ImageCell *strongCell = weakCell;
        NSIndexPath *currentPath = [collectionView indexPathForCell:strongCell];
        if (!currentPath || currentPath.item >= [weakSelf imageCount]) return;
        [weakSelf removeImageAtIndex:currentPath.item];
    };
    
    cell.onTap = ^{
        PP_ImageCell *strongCell = weakCell;
        NSIndexPath *currentPath = [collectionView indexPathForCell:strongCell];
        if (!currentPath || currentPath.item >= [weakSelf imageCount]) return;
        [weakSelf handleImageTapAtIndex:currentPath.item];
    };
    
    return cell;
}

#pragma mark - Collection View Delegate

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat collectionHeight = CGRectGetHeight(collectionView.bounds);
     UIEdgeInsets sectionInset = UIEdgeInsetsZero;
    CGFloat minimumLineSpacing = 10.0;
    if ([collectionViewLayout isKindOfClass:UICollectionViewFlowLayout.class]) {
        UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *)collectionViewLayout;
        sectionInset = flowLayout.sectionInset;
        minimumLineSpacing = flowLayout.minimumLineSpacing;
    }

    CGFloat horizontalInsets = sectionInset.left + sectionInset.right;
    CGFloat verticalInsets = sectionInset.top + sectionInset.bottom;
    CGFloat availableHeight = MAX(0.0, collectionHeight - verticalInsets);
    NSInteger imageCount = [self imageCount];
    BOOL shouldShowAddButton = (imageCount < self.maxImageCount);
    BOOL isEmptyStateAddButton = (imageCount == 0 && shouldShowAddButton && indexPath.item == 0);
    
    CGFloat itemWidth = MAX(92.0, availableHeight);
     return CGSizeMake(itemWidth, itemWidth);
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return self.allowsReordering && (indexPath.item < [self imageCount]);
}

- (NSIndexPath *)collectionView:(UICollectionView *)collectionView
targetIndexPathForMoveFromItemAtIndexPath:(NSIndexPath *)originalIndexPath
            toProposedIndexPath:(NSIndexPath *)proposedIndexPath
{
    NSInteger currentCount = [self imageCount];
    if (currentCount <= 0) {
        return originalIndexPath;
    }
    NSInteger clampedItem = MIN(MAX(proposedIndexPath.item, 0), currentCount - 1);
    return [NSIndexPath indexPathForItem:clampedItem inSection:originalIndexPath.section];
}

- (void)collectionView:(UICollectionView *)collectionView
moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath
           toIndexPath:(NSIndexPath *)destinationIndexPath
{
    NSInteger fromIndex = sourceIndexPath.item;
    NSInteger toIndex = destinationIndexPath.item;
    NSInteger count = [self imageCount];

    if (fromIndex == toIndex || fromIndex < 0 || toIndex < 0 || fromIndex >= count || toIndex >= count) {
        [self reloadCollectionView];
        return;
    }

    [self.arrayLock lock];
    [self pp_ensureMutableCollections];
    UIImage *movingImage = (fromIndex < self.mediaOutputArray.count) ? self.mediaOutputArray[fromIndex] : nil;
    NSNumber *movingMediaType = (fromIndex < self.mediaTypeArray.count) ? self.mediaTypeArray[fromIndex] : @(PHAssetMediaTypeImage);
    id movingVideoURL = (fromIndex < self.videoURLArray.count) ? self.videoURLArray[fromIndex] : NSNull.null;
    if (!movingImage) {
        [self.arrayLock unlock];
        [self reloadCollectionView];
        return;
    }
    [self.mediaOutputArray removeObjectAtIndex:fromIndex];
    [self.mediaOutputArray insertObject:movingImage atIndex:toIndex];
    if (fromIndex < self.mediaTypeArray.count) {
        [self.mediaTypeArray removeObjectAtIndex:fromIndex];
        [self.mediaTypeArray insertObject:movingMediaType atIndex:toIndex];
    }
    if (fromIndex < self.videoURLArray.count) {
        [self.videoURLArray removeObjectAtIndex:fromIndex];
        [self.videoURLArray insertObject:movingVideoURL atIndex:toIndex];
    }
    id movingPreloadedMetadata = (fromIndex < self.preloadedMediaMetadataArray.count) ? self.preloadedMediaMetadataArray[fromIndex] : NSNull.null;
    if (fromIndex < self.preloadedMediaMetadataArray.count) {
        [self.preloadedMediaMetadataArray removeObjectAtIndex:fromIndex];
        [self.preloadedMediaMetadataArray insertObject:movingPreloadedMetadata atIndex:toIndex];
    }
    [self.arrayLock unlock];

    [self.imageManager moveImageFromIndex:fromIndex toIndex:toIndex];
    [self reloadCollectionView];
    [self notifyDelegate];
}

- (void)handleReorderLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (!self.allowsReordering) return;

    CGPoint location = [gesture locationInView:self.collectionView];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
            if (!indexPath || indexPath.item >= [self imageCount]) {
                return;
            }
            [self.collectionView beginInteractiveMovementForItemAtIndexPath:indexPath];
            break;
        }
        case UIGestureRecognizerStateChanged:
            [self.collectionView updateInteractiveMovementTargetPosition:location];
            break;
        case UIGestureRecognizerStateEnded:
            [self.collectionView endInteractiveMovement];
            break;
        default:
            [self.collectionView cancelInteractiveMovement];
            break;
    }
}

#pragma mark - Image Tap Handling

- (void)handleImageTapAtIndex:(NSInteger)index {
    if (index < 0 || index >= [self imageCount]) return;
    NSNumber *mediaType = (index < self.mediaTypeArray.count) ? self.mediaTypeArray[index] : @(PHAssetMediaTypeImage);
    if ([self pp_allowsReusableVideoMedia] && mediaType.integerValue == PHAssetMediaTypeVideo) {
        NSURL *videoURL = nil;
        id localURL = (index < self.videoURLArray.count) ? self.videoURLArray[index] : NSNull.null;
        if ([localURL isKindOfClass:NSURL.class]) {
            videoURL = localURL;
        } else {
            NSDictionary *metadata = (index < self.preloadedMediaMetadataArray.count && [self.preloadedMediaMetadataArray[index] isKindOfClass:NSDictionary.class])
                ? self.preloadedMediaMetadataArray[index]
                : nil;
            NSString *remoteURL = [self pp_mediaStringValue:metadata[@"url"]];
            if (remoteURL.length > 0) {
                videoURL = [NSURL URLWithString:remoteURL];
            }
        }
        UIViewController *presenter = [self pp_bestPresentingViewController:nil];
        if (videoURL && presenter) {
            PPPremiumVideoPlayerViewController *playerVC =
            [[PPPremiumVideoPlayerViewController alloc] initWithURL:videoURL];
            [presenter presentViewController:playerVC animated:YES completion:nil];
        }
        return;
    }

    UIImage *image = [self pp_renderableImageAtIndex:index];
    if (![self pp_isRenderableImage:image]) {
        NSLog(@"[PPImageCollection] Ignoring tap for non-renderable image at index %ld", (long)index);
        return;
    }
    
    if (self.allowsEditing) {
        // Store selection and open editor
        self.selectedForEdit = index;

        // Present editor through the parent view controller
        if ([self.delegate respondsToSelector:@selector(imageCollection:didSelectImage:AtIndex:)]) {
            [self.delegate imageCollection:self didSelectImage:image AtIndex:index];
        }
        
        // You can also present editor directly if you have access to view controller
        //[self.editorBridge presentEditorFromViewController:AppMgr.topViewController withImage:image useArabic:self.useArabic];
    } else {
        // Just notify delegate
        if ([self.delegate respondsToSelector:@selector(imageCollection:didSelectImage:AtIndex:)]) {
            [self.delegate imageCollection:self didSelectImage:image AtIndex:index];
        }
    }
}
 

#pragma mark - Image Picker

- (void)openImagePicker {
    [self pp_resetStalePresentingFlagIfNeeded];
    UIViewController *presentingVC = [self pp_bestPresentingViewController:nil];
    if (!presentingVC) {
        return;
    }
    [self pp_presentAddImageOptionsFromViewController:presentingVC sourceView:self.collectionView ?: self];
}

- (UIViewController *)pp_bestPresentingViewController:(UIViewController * _Nullable)preferredVC
{
    UIViewController *vc = preferredVC;
    if ((!vc.isViewLoaded || !vc.view.window) && preferredVC != nil) {
        vc = nil;
    }
    vc = vc ?: [self pp_parentViewController] ?: AppMgr.topViewController;
    if (!vc) {
        return nil;
    }

    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        vc = nav.topViewController ?: nav;
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)vc;
        UIViewController *selected = tab.selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)selected;
            vc = nav.topViewController ?: nav;
        } else if (selected) {
            vc = selected;
        }
    }

    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
        vc = vc.presentedViewController;
    }

    if ([vc isKindOfClass:[UIAlertController class]]) {
        vc = vc.presentingViewController ?: vc;
    }

    if ([self pp_isMediaPickerViewController:vc]) {
        return nil;
    }

    if (vc.isBeingDismissed || vc.isBeingPresented) {
        return nil;
    }

    if (!vc.isViewLoaded || !vc.view.window) {
        return nil;
    }

    // Block presentation if VC still has a child that is mid-dismiss animation
    if (vc.presentedViewController && vc.presentedViewController.isBeingDismissed) {
        return nil;
    }

    return vc;
}

- (UIViewController *)pp_parentViewController
{
    UIResponder *responder = self;
    while (responder) {
        responder = responder.nextResponder;
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

/// Self-healing: if `isPresentingMediaPicker` is stuck YES but no picker VC
/// is actually on screen, reset the flag so the user can pick again.
- (void)pp_resetStalePresentingFlagIfNeeded
{
    if (!self.isPresentingMediaPicker) return;
    if ([self pp_hasActiveMediaPresentation]) {
        return;
    }

    if (self.currentPicker || self.cameraPicker || self.isPresentingMediaPicker) {
        NSLog(@"[PPImageCollection] Self-healing: resetting stale isPresentingMediaPicker flag");
    }
    [self pp_resetMediaPresentationState];
}

- (void)openGalleryPickerFromViewController:(UIViewController *)viewController
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openGalleryPickerFromViewController:viewController];
        });
        return;
    }

    // Self-healing: reset stuck flag if no picker is actually presented
    [self pp_resetStalePresentingFlagIfNeeded];

    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) return;
    if (![self pp_canAddMoreImagesForPresenter:presentingVC]) return;
    if (self.isPresentingMediaPicker || self.currentPicker || self.cameraPicker) return;
    if (presentingVC.presentedViewController) return;
    __weak typeof(self) weakSelf = self;
    [PPPermissionHelper requestPhotoLibraryPermissionFromViewController:presentingVC
                                                            completion:^(BOOL granted) {
        if (!granted) return;
        if (!weakSelf) return;
        UIViewController *readyPresenter =
            [weakSelf pp_bestPresentingViewController:presentingVC] ?: [weakSelf pp_bestPresentingViewController:nil];
        if (!readyPresenter) return;
        if (weakSelf.isPresentingMediaPicker || weakSelf.currentPicker || weakSelf.cameraPicker) return;
        if (readyPresenter.presentedViewController) return;

        if ([weakSelf pp_shouldUseTemporaryHXPicker]) {
            [weakSelf pp_presentHXPhotoPickerFromViewController:readyPresenter];
            return;
        }

        QBImagePickerController *imagePickerController = [QBImagePickerController new];
        imagePickerController.delegate = weakSelf;
        imagePickerController.allowsMultipleSelection = YES;
        imagePickerController.showsNumberOfSelectedAssets = YES;
        imagePickerController.maximumNumberOfSelection = weakSelf.maxImageCount - [weakSelf imageCount];

        imagePickerController.mediaType = [weakSelf pp_allowsReusableVideoMedia] ? QBImagePickerMediaTypeAny : QBImagePickerMediaTypeImage;
        NSArray<PHAsset *> *preselected = [weakSelf.imageManager preselectedAssetsForPicker];
        if (preselected.count > 0) {
            imagePickerController.selectedAssets = [NSMutableOrderedSet orderedSetWithArray:preselected];
        }

        imagePickerController.modalPresentationStyle = UIModalPresentationPageSheet;
        imagePickerController.view.backgroundColor = AppClearClr;
        imagePickerController.modalInPresentation = YES;
        imagePickerController.view.backgroundColor = UIColor.clearColor;

        weakSelf.isPresentingMediaPicker = YES;
        weakSelf.currentPicker = imagePickerController;

        [readyPresenter presentViewController:imagePickerController
                                     animated:YES
                                   completion:^{
            NSLog(@"[PPImageCollection] Gallery picker presented successfully");
        }];
    }];
}

- (BOOL)pp_shouldUseTemporaryHXPicker
{
    // HXPhotoPicker rollout is disabled here because this presentation path is
    // currently the crash source in the customer app. Keep the bridge in place
    // for later validation, but route production gallery selection through the
    // proven QB picker until the HX flow is stabilized.
    return YES;
}

- (void)pp_presentHXPhotoPickerFromViewController:(UIViewController *)viewController
{
    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) {
        return;
    }

    if (!self.photoPickerBridge) {
        self.photoPickerBridge = [[PPPickerBridge alloc] init];
    }
    if (!self.corePickerBridge) {
        self.corePickerBridge = [[PPCoreBridge alloc] init];
    }

    self.corePickerBridge.useArabic = self.useArabic;
    [self.corePickerBridge preparePickerLanguageBundle];

    self.photoPickerBridge.useArabic = self.useArabic;
    self.photoPickerBridge.navigationTitleFont =
        [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:17]];
    self.photoPickerBridge.navigationButtonFont =
        [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:15]];
    self.photoPickerBridge.buttonFont =
        [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:16]];
    self.photoPickerBridge.bottomLabelFont =
        [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:14]];

    NSInteger remainingSlots = MAX(0, self.maxImageCount - [self imageCount]);
    self.photoPickerBridge.maxSelectionCount = remainingSlots;
    self.photoPickerBridge.maxVideoSelectionCount = MAX(0, PPImageCollectionMaxVideoSelectionCount - [self pp_selectedVideoCount]);
    self.photoPickerBridge.useArabic = self.useArabic;
    self.photoPickerBridge.allowPhoto = YES;
    self.photoPickerBridge.allowVideo = [self pp_allowsReusableVideoMedia];

    NSArray<NSString *> *preselectedIdentifiers = [self.imageManager preselectedAssetLocalIdentifiers];
    self.photoPickerBridge.preselectedAssetIdentifiers = preselectedIdentifiers ?: @[];

    self.isPresentingMediaPicker = YES;
    [self.photoPickerBridge presentPickerFromViewController:presentingVC];
}

- (void)openCameraFromViewController:(UIViewController *)viewController
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openCameraFromViewController:viewController];
        });
        return;
    }

    if (!viewController) return;

    // Self-healing: reset stuck flag if no picker is actually presented
    [self pp_resetStalePresentingFlagIfNeeded];

    if (![self pp_canAddMoreImagesForPresenter:viewController]) return;
    if (self.isPresentingMediaPicker || self.currentPicker || self.cameraPicker) return;

    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [self presentSimpleAlertOn:viewController
                             title:[self pp_localizedSheetStringForKey:@"Camera"
                                                              fallback:@"Camera"]
                           message:[self pp_localizedSheetStringForKey:@"camera_not_available"
                                                              fallback:@"Camera is not available on this device."]];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [PPPermissionHelper requestCameraPermissionFromViewController:viewController
                                                       completion:^(BOOL granted) {
        if (!granted) return;
        UIViewController *readyPresenter =
            [weakSelf pp_bestPresentingViewController:viewController] ?: [weakSelf pp_bestPresentingViewController:nil];
        if (!readyPresenter) return;
        // iPad: brief delay so any previous alert/popover finishes dismissing
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [weakSelf presentCameraPickerFromViewController:readyPresenter];
            });
        } else {
            [weakSelf presentCameraPickerFromViewController:readyPresenter];
        }
    }];
}

- (BOOL)pp_canAddMoreImagesForPresenter:(UIViewController *)viewController
{
    if ([self imageCount] < self.maxImageCount) {
        return YES;
    }

    NSString *title = [self pp_localizedSheetStringForKey:@"max_images_reached"
                                                 fallback:@"Maximum images reached"];
    NSString *hintPrefix = [self pp_localizedSheetStringForKey:@"max_images_hint"
                                                      fallback:@"Maximum allowed images:"];

    NSString *message = [NSString stringWithFormat:@"%@ %ld", hintPrefix, (long)self.maxImageCount];
    [self presentSimpleAlertOn:viewController title:title message:message];
    return NO;
}

- (void)presentCameraPickerFromViewController:(UIViewController *)viewController
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentCameraPickerFromViewController:viewController];
        });
        return;
    }

    if (self.isPresentingMediaPicker || self.currentPicker || self.cameraPicker) return;

    // On iPad, walk up to find a VC that is free to present
    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) return;

    // If the best VC already presents something, try its root ancestor on iPad
    if (presentingVC.presentedViewController) {
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            UIViewController *root = presentingVC.view.window.rootViewController;
            while (root.presentedViewController && !root.presentedViewController.isBeingDismissed) {
                root = root.presentedViewController;
            }
            if (root && root != presentingVC && !root.presentedViewController) {
                presentingVC = root;
            } else {
                return;
            }
        } else {
            return;
        }
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    if ([self pp_allowsReusableVideoMedia]) {
        NSMutableArray<NSString *> *mediaTypes = [NSMutableArray arrayWithObject:UTTypeImage.identifier];
        if ([self pp_selectedVideoCount] < PPImageCollectionMaxVideoSelectionCount &&
            [[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera] containsObject:UTTypeMovie.identifier]) {
            [mediaTypes addObject:UTTypeMovie.identifier];
        }
        picker.mediaTypes = mediaTypes.copy;
        picker.videoQuality = UIImagePickerControllerQualityTypeMedium;
        picker.videoMaximumDuration = PPImageCollectionMaxVideoDuration;
    }

    // iPad: configure popover as safety net (system may convert presentation)
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = presentingVC.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(
            CGRectGetMidX(presentingVC.view.bounds),
            CGRectGetMidY(presentingVC.view.bounds),
            1, 1
        );
        picker.popoverPresentationController.permittedArrowDirections = 0;
    }

    // Set flags before presentation
    self.isPresentingMediaPicker = YES;
    self.cameraPicker = picker;

    // Present with completion handler to verify success
    [presentingVC presentViewController:picker animated:YES completion:^{
        NSLog(@"[PPImageCollection] Camera picker presented successfully");
    }];
}

- (void)presentSimpleAlertOn:(UIViewController *)viewController title:(NSString *)title message:(NSString *)message
{
    if (!viewController) return;
    NSString *finalTitle = title.length ? title : @"";
    NSString *finalMessage = message.length ? message : @"";
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:finalTitle
                                        message:finalMessage
                                 preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[self pp_localizedSheetStringForKey:@"OK"
                                                                               fallback:@"OK"]
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [viewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Files Picker

- (void)openFilesPickerFromViewController:(UIViewController *)viewController
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openFilesPickerFromViewController:viewController];
        });
        return;
    }

    [self pp_resetStalePresentingFlagIfNeeded];

    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) return;
    if (![self pp_canAddMoreImagesForPresenter:presentingVC]) return;
    if (self.isPresentingMediaPicker || self.currentPicker || self.cameraPicker) return;
    if (presentingVC.presentedViewController) return;

    NSArray<UTType *> *contentTypes = [self pp_allowsReusableVideoMedia] ? @[UTTypeImage, UTTypeMovie] : @[UTTypeImage];
    UIDocumentPickerViewController *docPicker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes];
    docPicker.delegate = self;
    docPicker.allowsMultipleSelection = ([self imageCount] < self.maxImageCount);
    docPicker.modalPresentationStyle = UIModalPresentationPageSheet;

    self.isPresentingMediaPicker = YES;
    [presentingVC presentViewController:docPicker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    [self pp_resetMediaPresentationState];
    if (urls.count == 0) return;

    NSInteger availableSlots = self.maxImageCount - [self imageCount];
    NSInteger count = MIN((NSInteger)urls.count, availableSlots);
    for (NSInteger i = 0; i < count; i++) {
        NSURL *url = urls[i];
        NSString *typeIdentifier = nil;
        [url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:nil];
        UTType *selectedType = typeIdentifier.length > 0 ? [UTType typeWithIdentifier:typeIdentifier] : nil;
        BOOL isVideo = [self pp_allowsReusableVideoMedia] && [selectedType conformsToType:UTTypeMovie];
        if (isVideo) {
            if (![self pp_canAcceptAdditionalVideoWithPresenter:nil]) {
                continue;
            }
            [self addVideoWithURL:url thumbnail:nil];
            continue;
        }

        BOOL accessed = [url startAccessingSecurityScopedResource];
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (accessed) [url stopAccessingSecurityScopedResource];
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        if (image) {
            [self addImage:image];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    [self pp_resetMediaPresentationState];
}

#pragma mark - QBImagePickerControllerDelegate

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets {
    __weak typeof(self) weakSelf = self;
    [self pp_showLoadingOverlay];
    [self pp_cancelLoadingTimeoutIfNeeded];

    __block BOOL didFinalize = NO;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        if (didFinalize || !weakSelf) return;
        didFinalize = YES;
        [weakSelf pp_syncImagesFromManager];
        [weakSelf reloadCollectionView];
        [weakSelf notifyDelegate];
        [weakSelf pp_hideLoadingOverlay];
    });
    self.loadingTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);

    [self.imageManager addAssetsFromPicker:assets completion:^(BOOL didChange) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (didFinalize) {
                return;
            }
            didFinalize = YES;
            [weakSelf pp_cancelLoadingTimeoutIfNeeded];
            if (!didChange) {
                NSLog(@"[PPImageCollection] Picker returned no delta, syncing existing manager images");
            }
            [weakSelf pp_syncImagesFromManager];
            [weakSelf reloadCollectionView];
            [weakSelf notifyDelegate];
            [weakSelf pp_hideLoadingOverlay];
        });
    }];
    
    [self dismissPicker];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [self pp_cancelLoadingTimeoutIfNeeded];
    [self dismissPicker];
    [self pp_hideLoadingOverlay];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info
{
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    if ([self pp_allowsReusableVideoMedia] && [mediaType isEqualToString:UTTypeMovie.identifier]) {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        if (videoURL && [self pp_canAcceptAdditionalVideoWithPresenter:nil]) {
            [self addVideoWithURL:videoURL thumbnail:nil];
        }
        [picker dismissViewControllerAnimated:YES completion:^{
            [self pp_resetMediaPresentationState];
            [self pp_hideLoadingOverlay];
        }];
        return;
    }

    UIImage *pickedImage = info[UIImagePickerControllerOriginalImage];
    if (!pickedImage) {
        pickedImage = info[UIImagePickerControllerEditedImage];
    }

    if (pickedImage) {
        [self addImage:pickedImage];
    }

    [picker dismissViewControllerAnimated:YES completion:^{
        [self pp_resetMediaPresentationState];
        [self pp_hideLoadingOverlay];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:^{
        [self pp_resetMediaPresentationState];
        [self pp_hideLoadingOverlay];
    }];
}

- (void)dismissPicker {
    if (self.currentPicker) {
        UIViewController *picker = self.currentPicker;
        self.currentPicker = nil;
        self.cameraPicker = nil;
        [picker dismissViewControllerAnimated:YES completion:^{
            [self pp_resetMediaPresentationState];
        }];
    } else {
        // HX picker path: bridge already dismissed the VC, but the dismiss
        // animation may still be in progress, so poll briefly until it fully clears.
        self.currentPicker = nil;
        self.cameraPicker = nil;
        [self pp_scheduleMediaPresentationResetWithAttempts:10];
    }
}

#pragma mark - Editor Notifications

- (void)editorDidFinish:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    UIImage *editedImage = userInfo[@"image"];
    
    if (!editedImage) {
        // Try to get from URL
        NSURL *fileURL = userInfo[@"url"];
        if (fileURL) {
            NSData *imageData = [NSData dataWithContentsOfURL:fileURL];
            editedImage = [UIImage imageWithData:imageData];
        }
    }
    
    if (!editedImage) return;
    
    if (self.selectedForEdit >= 0 && self.selectedForEdit < [self imageCount]) {
        // Replace existing image
        [self replaceImageAtIndex:self.selectedForEdit withImage:editedImage];
    } else {
        // Add new image
        [self addImage:editedImage];
    }
    
    self.selectedForEdit = -1;
}

- (void)editorDidCancel:(NSNotification *)notification {
    self.selectedForEdit = -1;
}

#pragma mark - HXPhotoPicker Notifications

- (void)photoPickerDidFinish:(NSNotification *)notification
{
    if (![self pp_notificationBelongsToCurrentPhotoPicker:notification]) {
        return;
    }

    NSDictionary *userInfo = notification.userInfo;
    NSArray<PHAsset *> *selectedAssets =
        [userInfo[@"selectedAssets"] isKindOfClass:[NSArray class]] ? userInfo[@"selectedAssets"] : @[];
    NSArray<UIImage *> *selectedImages =
        [userInfo[@"selectedImages"] isKindOfClass:[NSArray class]] ? userInfo[@"selectedImages"] : @[];

    __weak typeof(self) weakSelf = self;
    [self pp_showLoadingOverlay];
    [self pp_cancelLoadingTimeoutIfNeeded];

    __block BOOL didFinalize = NO;
    __block NSString *pendingMediaLimitMessage = nil;
    dispatch_block_t timeoutBlock = dispatch_block_create(0, ^{
        if (didFinalize || !weakSelf) return;
        didFinalize = YES;
        [weakSelf pp_syncImagesFromManager];
        [weakSelf reloadCollectionView];
        [weakSelf notifyDelegate];
        [weakSelf dismissPicker];
        [weakSelf pp_hideLoadingOverlay];
    });
    self.loadingTimeoutBlock = timeoutBlock;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   timeoutBlock);

    if ([self pp_allowsReusableVideoMedia] && selectedAssets.count > 0) {
        NSInteger availableSlots = MAX(0, self.maxImageCount - [self imageCount]);
        NSInteger count = MIN((NSInteger)selectedAssets.count, availableSlots);
        if (count <= 0) {
            [self pp_cancelLoadingTimeoutIfNeeded];
            [self dismissPicker];
            [self pp_hideLoadingOverlay];
            return;
        }

        dispatch_group_t group = dispatch_group_create();
        NSInteger acceptedVideoCount = [self pp_selectedVideoCount];
        for (NSInteger idx = 0; idx < count; idx++) {
            PHAsset *asset = selectedAssets[idx];
            if (![asset isKindOfClass:PHAsset.class]) continue;
            dispatch_group_enter(group);
            if (asset.mediaType == PHAssetMediaTypeVideo) {
                if (acceptedVideoCount >= PPImageCollectionMaxVideoSelectionCount) {
                    pendingMediaLimitMessage = [weakSelf pp_videoCountLimitMessage];
                    dispatch_group_leave(group);
                    continue;
                }
                if (![weakSelf pp_videoDurationIsAllowed:asset.duration]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        pendingMediaLimitMessage = [weakSelf pp_videoDurationLimitMessage];
                        dispatch_group_leave(group);
                    });
                    continue;
                }
                acceptedVideoCount += 1;
                PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
                options.networkAccessAllowed = YES;
                options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
                [[PHImageManager defaultManager] requestAVAssetForVideo:asset
                                                                 options:options
                                                           resultHandler:^(AVAsset * _Nullable avAsset,
                                                                           AVAudioMix * _Nullable audioMix,
                                                                           NSDictionary * _Nullable info) {
                    (void)audioMix;
                    NSURL *videoURL = [avAsset isKindOfClass:AVURLAsset.class] ? ((AVURLAsset *)avAsset).URL : nil;
                    CGSize targetSize = CGSizeMake(900.0, 900.0);
                    PHImageRequestOptions *thumbnailOptions = [[PHImageRequestOptions alloc] init];
                    thumbnailOptions.networkAccessAllowed = YES;
                    thumbnailOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                    thumbnailOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
                    [[PHImageManager defaultManager] requestImageForAsset:asset
                                                               targetSize:targetSize
                                                              contentMode:PHImageContentModeAspectFill
                                                                  options:thumbnailOptions
                                                            resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable imageInfo) {
                        (void)info; (void)imageInfo;
                        if ([imageInfo[PHImageResultIsDegradedKey] boolValue]) {
                            return;
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (videoURL) {
                                [weakSelf addVideoWithURL:videoURL thumbnail:result];
                            }
                            dispatch_group_leave(group);
                        });
                    }];
                }];
            } else {
                UIImage *pickedImage = (idx < selectedImages.count) ? selectedImages[idx] : nil;
                if (pickedImage) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf addImage:pickedImage];
                        dispatch_group_leave(group);
                    });
                } else {
                    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                    options.networkAccessAllowed = YES;
                    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                    [[PHImageManager defaultManager] requestImageForAsset:asset
                                                               targetSize:CGSizeMake(1800.0, 1800.0)
                                                              contentMode:PHImageContentModeAspectFill
                                                                  options:options
                                                            resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                        if ([info[PHImageResultIsDegradedKey] boolValue]) {
                            return;
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (result) {
                                [weakSelf addImage:result];
                            }
                            dispatch_group_leave(group);
                        });
                    }];
                }
            }
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (didFinalize) {
                return;
            }
            didFinalize = YES;
            [weakSelf pp_cancelLoadingTimeoutIfNeeded];
            [weakSelf reloadCollectionView];
            [weakSelf notifyDelegate];
            [weakSelf dismissPicker];
            [weakSelf pp_hideLoadingOverlay];
            [weakSelf pp_presentMediaLimitMessageAfterPickerDismiss:pendingMediaLimitMessage];
        });
        return;
    }

    if (selectedAssets.count > 0) {
        [self.imageManager addAssetsFromPicker:selectedAssets completion:^(BOOL didChange) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (didFinalize) {
                    return;
                }
                didFinalize = YES;
                [weakSelf pp_cancelLoadingTimeoutIfNeeded];
                if (!didChange) {
                    NSLog(@"[PPImageCollection] HXPhotoPicker returned no delta, syncing existing manager images");
                }
                [weakSelf pp_syncImagesFromManager];
                [weakSelf reloadCollectionView];
                [weakSelf notifyDelegate];
                [weakSelf dismissPicker];
                [weakSelf pp_hideLoadingOverlay];
            });
        }];
        return;
    }

    if (selectedImages.count > 0) {
        [self addImages:selectedImages];
    }
    [self pp_cancelLoadingTimeoutIfNeeded];
    [self dismissPicker];
    [self pp_hideLoadingOverlay];
}

- (void)photoPickerDidCancel:(NSNotification *)notification
{
    if (![self pp_notificationBelongsToCurrentPhotoPicker:notification]) {
        return;
    }
    [self pp_cancelLoadingTimeoutIfNeeded];
    [self dismissPicker];
    [self pp_hideLoadingOverlay];
}

#pragma mark - Convenience

- (void)presentPickerFromViewController:(UIViewController *)viewController {
    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) {
        return;
    }
    [self pp_presentAddImageOptionsFromViewController:presentingVC sourceView:self.collectionView ?: self];
}

- (void)presentEditorForImageAtIndex:(NSInteger)index fromViewController:(UIViewController *)viewController {
    if (index < 0 || index >= [self imageCount] || !viewController) return;

    UIImage *image = [self pp_renderableImageAtIndex:index];
    if (![self pp_isRenderableImage:image]) {
        NSLog(@"[PPImageCollection] Skipping editor presentation for non-renderable image at index %ld", (long)index);
        return;
    }

    UIViewController *presentingVC = [self pp_bestPresentingViewController:viewController];
    if (!presentingVC) {
        NSLog(@"[PPImageCollection] Missing valid presenter for editor at index %ld", (long)index);
        return;
    }

    self.selectedForEdit = index;
    
    [self.editorBridge presentEditorFromViewController:presentingVC withImage:image useArabic:self.useArabic];
}

@end
