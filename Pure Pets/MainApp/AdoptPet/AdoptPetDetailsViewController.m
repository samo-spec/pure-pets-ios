//
//  AdoptPetDetailsViewController.m
//  Pure Pets
//
//  Adoption detail experience — "Trusted Companion" redesign.
//  UIKit (Obj-C), code-only. Behaviour contracts preserved:
//  - initWithModel:/initWithModel:isOwner: public API.
//  - Image gallery (paging) with video-badge media + PPPremiumVideoPlayer.
//  - Owner vs non-owner surface (contact/favorite/report gated to non-owner).
//  - Report flow writes to adopt_pets (reportedBy/reportCount) + reports collection.
//  - Contact chat/call with sync cache + async Firestore owner fetch.
//  - Reduce Motion gating for every signature moment.
//  Design change: decorative hero glass replaced by a legibility scrim + a solid
//  identity card; facts use a semantic category-chip role.
//

#import "AdoptPetDetailsViewController.h"
#import "AdoptPetModel.h"
#import "AppClasses.h"
#import "FavoriteButton.h"
#import "GM.h"
#import "UserContactView.h"
#import <QuartzCore/QuartzCore.h>
#import <AVKit/AVKit.h>
#import "EnumValues.h"
#import "FullScreenImageViewerController.h"

static NSInteger const PPAdoptGalleryVideoBadgeTag = 81042;

static NSString *PPAdoptTrimmedString(id value)
{
    if (![value isKindOfClass:NSString.class]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PPAdoptDisplayValue(NSString *value)
{
    return value.length > 0 ? value : @"-";
}

static NSString *PPAdoptMediaStringValue(id value)
{
    if ([value isKindOfClass:NSString.class]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value stringValue];
    }
    return @"";
}

static NSString *PPAdoptAgeValue(NSInteger months)
{
    if (months <= 0) {
        return @"-";
    }
    NSString *unit = (months == 1) ? kLang(@"month") : kLang(@"months");
    return [NSString stringWithFormat:@"%ld %@", (long)months, unit];
}

static NSString *PPAdoptCreatedValue(NSDate *date)
{
    if (!date) {
        return @"-";
    }
    NSDateFormatter *formatter = [NSDateFormatter new];
    NSString *localeID = @"en_QA";
    formatter.locale = [NSLocale localeWithLocaleIdentifier:localeID];
    [formatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy h:mm a"];
    return [formatter stringFromDate:date] ?: @"-";
}

#pragma mark - PPAdoptGalleryCell

@interface PPAdoptGalleryCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
- (void)configureVideoBadgeVisible:(BOOL)visible;
@end

@implementation PPAdoptGalleryCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = UIColor.clearColor;

        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.backgroundColor = GM.backOffwhileColor;
        [self.contentView addSubview:_imageView];

        [NSLayoutConstraint activateConstraints:@[
            [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
        ]];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = nil;
    [self configureVideoBadgeVisible:NO];
}

- (void)configureVideoBadgeVisible:(BOOL)visible
{
    UIView *existing = [self.contentView viewWithTag:PPAdoptGalleryVideoBadgeTag];
    if (!visible) {
        [existing removeFromSuperview];
        return;
    }
    if (existing) {
        existing.hidden = NO;
        return;
    }
    UIImageView *badge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"play.circle.fill"]];
    badge.tag = PPAdoptGalleryVideoBadgeTag;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.tintColor = UIColor.whiteColor;
    badge.contentMode = UIViewContentModeScaleAspectFit;
    [self.contentView addSubview:badge];
    [NSLayoutConstraint activateConstraints:@[
        [badge.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [badge.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [badge.widthAnchor constraintEqualToConstant:54.0],
        [badge.heightAnchor constraintEqualToConstant:54.0]
    ]];
}

@end

#pragma mark - PPAdoptInfoBadgeView (Category/Status chip)

@interface PPAdoptInfoBadgeView : UIView
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *textLabel;
- (void)configureWithIconName:(NSString *)iconName text:(NSString *)text;
- (void)configureWithIconName:(NSString *)iconName text:(NSString *)text tint:(UIColor *)tint;
@end

@implementation PPAdoptInfoBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        self.layer.cornerRadius = PPCornerPill;
        self.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveContinuous;
        }

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = UIColor.whiteColor;

        _textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _textLabel.font = [GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
        _textLabel.textColor = UIColor.whiteColor;
        _textLabel.numberOfLines = 1;
        _textLabel.lineBreakMode = NSLineBreakByTruncatingTail;

        [self addSubview:_iconView];
        [self addSubview:_textLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:14],
            [_iconView.heightAnchor constraintEqualToConstant:14],

            [_textLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:6],
            [_textLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-10],
            [_textLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.heightAnchor constraintEqualToConstant:30]
        ]];
    }
    return self;
}

- (void)configureWithIconName:(NSString *)iconName text:(NSString *)text {
    [self configureWithIconName:iconName text:text tint:AppPrimaryClr];
}

- (void)configureWithIconName:(NSString *)iconName text:(NSString *)text tint:(UIColor *)tint {
    NSString *safeText = PPAdoptTrimmedString(text);
    self.hidden = (safeText.length == 0 || [safeText isEqualToString:@"-"]);
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"circle.fill"];
    self.iconView.tintColor = tint;
    self.textLabel.text = safeText;
    self.textLabel.textColor = tint;
    self.backgroundColor = [tint colorWithAlphaComponent:0.12];
}

@end

#pragma mark - PPAdoptFactView (Fact tile with category-chip role)

@interface PPAdoptFactView : UIView
@property (nonatomic, strong) UIView *iconPlateView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
- (void)configureWithIconName:(NSString *)iconName title:(NSString *)title value:(NSString *)value;
@end

@implementation PPAdoptFactView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor colorWithRed:0.15 green:0.15 blue:0.17 alpha:1.0];
            }
            return [UIColor colorWithWhite:1.0 alpha:0.92];
        }];
        PPApplyContinuousCorners(self, PPCornerMedium);
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
        [self pp_setBorderColor:[[UIColor separatorColor] colorWithAlphaComponent:0.18]];

        _iconPlateView = [[UIView alloc] initWithFrame:CGRectZero];
        _iconPlateView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconPlateView.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:0.10];
        PPApplyContinuousCorners(_iconPlateView, 11.0);
        _iconPlateView.layer.masksToBounds = YES;

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = AppPrimaryClr;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
        _titleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
        _titleLabel.numberOfLines = 1;

        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [GM boldFontWithSize:PPFontCallout] ?: [UIFont systemFontOfSize:PPFontCallout weight:UIFontWeightBold];
        _valueLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
        _valueLabel.numberOfLines = 2;

        [self addSubview:_iconPlateView];
        [_iconPlateView addSubview:_iconView];
        [self addSubview:_titleLabel];
        [self addSubview:_valueLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconPlateView.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [_iconPlateView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_iconPlateView.widthAnchor constraintEqualToConstant:34],
            [_iconPlateView.heightAnchor constraintEqualToConstant:34],

            [_iconView.centerXAnchor constraintEqualToAnchor:_iconPlateView.centerXAnchor],
            [_iconView.centerYAnchor constraintEqualToAnchor:_iconPlateView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:17],
            [_iconView.heightAnchor constraintEqualToConstant:17],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconPlateView.trailingAnchor constant:10],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:16],

            [_valueLabel.topAnchor constraintEqualToAnchor:_iconPlateView.bottomAnchor constant:8],
            [_valueLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
            [_valueLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
            [self.heightAnchor constraintGreaterThanOrEqualToConstant:92]
        ]];
    }
    return self;
}

- (void)configureWithIconName:(NSString *)iconName title:(NSString *)title value:(NSString *)value {
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"circle.fill"];
    self.titleLabel.text = PPAdoptDisplayValue(title);
    self.valueLabel.text = PPAdoptDisplayValue(value);
}

@end


#pragma mark - AdoptPetDetailsViewController

@interface AdoptPetDetailsViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate>
@property (nonatomic, strong) AdoptPetModel *model;
@property (nonatomic, assign) BOOL isOwner;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *contentStack;

// Hero (pure gallery — no decorative glass)
@property (nonatomic, strong) UIView *heroContainer;
@property (nonatomic, strong) UICollectionView *imagesCV;
@property (nonatomic, strong) NSArray<NSDictionary *> *mediaItems;
@property (nonatomic, strong) NSLayoutConstraint *imagesHeightConstraint;
@property (nonatomic, strong) UIView *heroShadeView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIView *galleryProgressTrackView;
@property (nonatomic, strong) UIView *galleryProgressFillView;
@property (nonatomic, strong) NSLayoutConstraint *galleryProgressLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *galleryProgressWidthConstraint;

// Identity card (solid surface — replaces decorative blur plate)
@property (nonatomic, strong) UIView *identityCard;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *identityChipsStack;

// Content
@property (nonatomic, strong) UILabel *detailsBodyLabel;
@property (nonatomic, strong) UserContactView *contactView;
@property (nonatomic, strong) CAGradientLayer *contactGradientLayer;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *factItems;

// Controls
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) FavoriteButton *favoriteButton;
@property (nonatomic, strong) UIStackView *topActionsStack;

@property (nonatomic, assign) BOOL didAnimateEntrance;
@end

@implementation AdoptPetDetailsViewController

#pragma mark - Lifecycle

- (instancetype)initWithModel:(AdoptPetModel *)model {
    return [self initWithModel:model isOwner:NO];
}

- (instancetype)initWithModel:(AdoptPetModel *)model isOwner:(BOOL)isOwner {
    self = [super init];
    if (self) {
        _model = model;
        _isOwner = isOwner;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.semanticContentAttribute = GM.setSemantic;

    [self pp_buildMediaItems];
    [self pp_buildFactItems];
    [self pp_setupScrollView];
    [self pp_setupHero];
    [self pp_setupIdentityCard];
    [self pp_setupContentSections];
    [self pp_setupTopButtons];
    [self pp_setupContactView];
    [self pp_configureContent];
    [self pp_prepareEntranceStateIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceAnimationIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds) - (PPSpaceBase * 2.0);
    CGFloat heroHeight = MIN(MAX(width * 0.92, 380.0), 520.0);
    self.imagesHeightConstraint.constant = heroHeight;
    self.heroGradientLayer.frame = self.heroShadeView.bounds;
    self.heroShadeView.layer.cornerRadius = PPCornerHero;
    self.heroContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.heroContainer.bounds cornerRadius:PPCornerHero].CGPath;
    if (self.contactGradientLayer) {
        self.contactGradientLayer.frame = self.contactView.bounds;
    }
    self.contactView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.contactView.bounds cornerRadius:PPCornerCard].CGPath;

    // Progress rail fill width = track width / page count.
    NSInteger pages = MAX(self.mediaItems.count, 1);
    CGFloat trackWidth = CGRectGetWidth(self.galleryProgressTrackView.bounds);
    self.galleryProgressWidthConstraint.constant = (pages > 1) ? (trackWidth / (CGFloat)pages) : trackWidth;
}

#pragma mark - Build Data

- (void)pp_buildMediaItems
{
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    if (PPReusableVideoMediaEnabled() && [self.model.imageMeta isKindOfClass:NSArray.class]) {
        for (NSDictionary *meta in self.model.imageMeta) {
            if (![meta isKindOfClass:NSDictionary.class]) {
                continue;
            }
            NSString *type = [PPAdoptMediaStringValue(meta[@"media_type"]) lowercaseString];
            BOOL isVideo = [type isEqualToString:@"video"];
            NSString *displayURL = isVideo ? PPAdoptMediaStringValue(meta[@"thumbnail_url"]) : PPAdoptMediaStringValue(meta[@"url"]);
            if (displayURL.length == 0) {
                displayURL = PPAdoptMediaStringValue(meta[@"url"]);
            }
            if (displayURL.length == 0) {
                continue;
            }
            [items addObject:@{
                @"media_type": isVideo ? @"video" : @"image",
                @"display_url": displayURL,
                @"video_url": isVideo ? PPAdoptMediaStringValue(meta[@"url"]) : @""
            }];
        }
    }

    if (items.count == 0) {
        for (NSString *url in self.model.imageURLs) {
            NSString *cleanURL = PPAdoptTrimmedString(url);
            if (cleanURL.length > 0) {
                [items addObject:@{@"media_type": @"image", @"display_url": cleanURL, @"video_url": @""}];
            }
        }
    }
    self.mediaItems = items.copy;
}

- (void)pp_buildFactItems {
    NSString *kind = [MainKindsModel kindNameForID:self.model.kindID] ?: @"-";
    NSString *breed = self.model.subKindModel.SubKindName ?: [[self.model.mainKindModel subKindForID:self.model.breedID] SubKindName] ?: @"-";
    NSString *age = PPAdoptAgeValue(self.model.ageMonths);
    NSString *gender = self.model.gender.length > 0 ? kLang(self.model.gender) : @"-";
    NSString *city = self.model.mCityName.length > 0 ? self.model.mCityName : @"-";
    NSString *created = PPAdoptCreatedValue(self.model.createdAt);

    self.factItems = @[
        @{@"icon": @"pawprint.fill",       @"title": kLang(@"Kind"),   @"value": PPAdoptDisplayValue(kind)},
        @{@"icon": @"leaf.fill",           @"title": kLang(@"Breed"),  @"value": PPAdoptDisplayValue(breed)},
        @{@"icon": @"calendar",            @"title": kLang(@"Age"),    @"value": PPAdoptDisplayValue(age)},
        @{@"icon": @"figure.stand",        @"title": kLang(@"Gender"), @"value": PPAdoptDisplayValue(gender)},
        @{@"icon": @"mappin.and.ellipse",  @"title": kLang(@"City"),   @"value": PPAdoptDisplayValue(city)},
        @{@"icon": @"clock.fill",          @"title": kLang(@"Created"),@"value": PPAdoptDisplayValue(created)}
    ];
}

#pragma mark - Setup ScrollView

- (void)pp_setupScrollView {
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.scrollView];

    UIEdgeInsets bottomInsets = self.isOwner ? UIEdgeInsetsMake(0, 0, 40, 0) : UIEdgeInsetsMake(0, 0, 116, 0);
    self.scrollView.contentInset = bottomInsets;
    self.scrollView.verticalScrollIndicatorInsets = bottomInsets;

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;
    [self.scrollView addSubview:self.contentView];

    self.contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = PPSpaceBase;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.semanticContentAttribute = GM.setSemantic;
    [self.contentView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:PPSpaceMD],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:PPSpaceBase],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-PPSpaceBase],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-PPSpaceXL]
    ]];
}

#pragma mark - Setup Hero (pure gallery + legibility scrim + progress rail)

- (void)pp_setupHero {
    self.heroContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainer.backgroundColor = UIColor.clearColor;
    PPApplyContinuousCorners(self.heroContainer, PPCornerHero);
    [self.heroContainer pp_setShadowColor:UIColor.blackColor];
    self.heroContainer.layer.shadowOpacity = 0.09;
    self.heroContainer.layer.shadowRadius = 22.0;
    self.heroContainer.layer.shadowOffset = CGSizeMake(0, 12);
    self.heroContainer.layer.masksToBounds = NO;
    [self.contentStack addArrangedSubview:self.heroContainer];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 0.0;
    layout.minimumInteritemSpacing = 0.0;

    self.imagesCV = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.imagesCV.translatesAutoresizingMaskIntoConstraints = NO;
    self.imagesCV.backgroundColor = AppForgroundColr;
    self.imagesCV.showsHorizontalScrollIndicator = NO;
    self.imagesCV.pagingEnabled = YES;
    self.imagesCV.dataSource = self;
    self.imagesCV.delegate = self;
    self.imagesCV.clipsToBounds = YES;
    PPApplyContinuousCorners(self.imagesCV, PPCornerHero);
    [self.imagesCV registerClass:PPAdoptGalleryCell.class forCellWithReuseIdentifier:@"PPAdoptGalleryCell"];
    [self.heroContainer addSubview:self.imagesCV];

    // Legibility scrim — functional gradient (not decorative glass) for page control.
    self.heroShadeView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroShadeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroShadeView.backgroundColor = UIColor.clearColor;
    self.heroShadeView.clipsToBounds = YES;
    PPApplyContinuousCorners(self.heroShadeView, PPCornerHero);
    [self.heroContainer addSubview:self.heroShadeView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.45].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.62, @1.0];
    [self.heroShadeView.layer addSublayer:self.heroGradientLayer];

    self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageControl.pageIndicatorTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45];
    self.pageControl.currentPageIndicatorTintColor = UIColor.whiteColor;
    self.pageControl.hidesForSinglePage = YES;
    [self.heroContainer addSubview:self.pageControl];

    // Signature moment 1 — brand progress rail (scroll-linked indicator).
    self.galleryProgressTrackView = [[UIView alloc] initWithFrame:CGRectZero];
    self.galleryProgressTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.galleryProgressTrackView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.28];
    self.galleryProgressTrackView.layer.cornerRadius = 2.0;
    self.galleryProgressTrackView.layer.masksToBounds = YES;
    [self.heroContainer addSubview:self.galleryProgressTrackView];

    self.galleryProgressFillView = [[UIView alloc] initWithFrame:CGRectZero];
    self.galleryProgressFillView.translatesAutoresizingMaskIntoConstraints = NO;
    self.galleryProgressFillView.backgroundColor = UIColor.whiteColor;
    self.galleryProgressFillView.layer.cornerRadius = 2.0;
    self.galleryProgressFillView.layer.masksToBounds = YES;
    [self.galleryProgressTrackView addSubview:self.galleryProgressFillView];

    CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    if (@available(iOS 11.0, *)) {
        if (self.view.safeAreaInsets.top > 0) {
            statusBarHeight = self.view.safeAreaInsets.top;
        }
    }
    CGFloat navBarHeight = (self.navigationController && !self.navigationController.navigationBarHidden) ? self.navigationController.navigationBar.frame.size.height : 44.0;
    CGFloat minGalleryHeight = navBarHeight + statusBarHeight + 80.0;

    self.imagesHeightConstraint = [self.heroContainer.heightAnchor constraintEqualToConstant:MAX(420.0, minGalleryHeight)];
    self.galleryProgressLeadingConstraint = [self.galleryProgressFillView.leadingAnchor constraintEqualToAnchor:self.galleryProgressTrackView.leadingAnchor constant:0];
    self.galleryProgressWidthConstraint = [self.galleryProgressFillView.widthAnchor constraintEqualToConstant:40.0];

    [NSLayoutConstraint activateConstraints:@[
        self.imagesHeightConstraint,
        [self.heroContainer.heightAnchor constraintGreaterThanOrEqualToConstant:minGalleryHeight],

        [self.imagesCV.topAnchor constraintEqualToAnchor:self.heroContainer.topAnchor],
        [self.imagesCV.leadingAnchor constraintEqualToAnchor:self.heroContainer.leadingAnchor],
        [self.imagesCV.trailingAnchor constraintEqualToAnchor:self.heroContainer.trailingAnchor],
        [self.imagesCV.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor],
        [self.imagesCV.heightAnchor constraintGreaterThanOrEqualToConstant:minGalleryHeight],

        [self.heroShadeView.topAnchor constraintEqualToAnchor:self.heroContainer.topAnchor],
        [self.heroShadeView.leadingAnchor constraintEqualToAnchor:self.heroContainer.leadingAnchor],
        [self.heroShadeView.trailingAnchor constraintEqualToAnchor:self.heroContainer.trailingAnchor],
        [self.heroShadeView.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor],

        [self.pageControl.centerXAnchor constraintEqualToAnchor:self.heroContainer.centerXAnchor],
        [self.pageControl.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor constant:-16.0],

        [self.galleryProgressTrackView.leadingAnchor constraintEqualToAnchor:self.heroContainer.leadingAnchor constant:PPSpaceBase],
        [self.galleryProgressTrackView.trailingAnchor constraintEqualToAnchor:self.heroContainer.trailingAnchor constant:-PPSpaceBase],
        [self.galleryProgressTrackView.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor constant:-8.0],
        [self.galleryProgressTrackView.heightAnchor constraintEqualToConstant:3.0],

        self.galleryProgressLeadingConstraint,
        self.galleryProgressWidthConstraint,
        [self.galleryProgressFillView.topAnchor constraintEqualToAnchor:self.galleryProgressTrackView.topAnchor],
        [self.galleryProgressFillView.bottomAnchor constraintEqualToAnchor:self.galleryProgressTrackView.bottomAnchor]
    ]];

    self.galleryProgressTrackView.hidden = (self.mediaItems.count <= 1);
}


#pragma mark - Identity Card (solid surface — replaces decorative blur)

- (void)pp_setupIdentityCard {
    self.identityCard = [self pp_makeSectionCard];
    [self.contentStack addArrangedSubview:self.identityCard];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:PPFontTitle1 weight:UIFontWeightBold];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = NSTextAlignmentNatural;

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
    self.subtitleLabel.textColor = GM.SecondaryTextColor ?: UIColor.secondaryLabelColor;
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.textAlignment = NSTextAlignmentNatural;

    self.identityChipsStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.identityChipsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.identityChipsStack.axis = UILayoutConstraintAxisHorizontal;
    self.identityChipsStack.spacing = PPSpaceSM;
    self.identityChipsStack.alignment = UIStackViewAlignmentCenter;
    self.identityChipsStack.distribution = UIStackViewDistributionFill;
    self.identityChipsStack.semanticContentAttribute = GM.setSemantic;

    [self.identityCard addSubview:self.titleLabel];
    [self.identityCard addSubview:self.subtitleLabel];
    [self.identityCard addSubview:self.identityChipsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.identityCard.topAnchor constant:18],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:18],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-18],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:18],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.identityCard.trailingAnchor constant:-18],

        [self.identityChipsStack.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:12],
        [self.identityChipsStack.leadingAnchor constraintEqualToAnchor:self.identityCard.leadingAnchor constant:18],
        [self.identityChipsStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.identityCard.trailingAnchor constant:-18],
        [self.identityChipsStack.bottomAnchor constraintEqualToAnchor:self.identityCard.bottomAnchor constant:-18],
        [self.identityChipsStack.heightAnchor constraintEqualToConstant:30]
    ]];
}

#pragma mark - Content Sections (Facts + Story)

- (void)pp_setupContentSections {
    UIView *factsCard = [self pp_makeSectionCard];
    [self.contentStack addArrangedSubview:factsCard];

    UILabel *factsEyebrow = [[UILabel alloc] initWithFrame:CGRectZero];
    factsEyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    factsEyebrow.font = [GM boldFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightBold];
    factsEyebrow.textColor = [AppPrimaryClr colorWithAlphaComponent:0.92];
    factsEyebrow.text = kLang(@"adopt_detail_section_facts");

    UIStackView *factsGrid = [[UIStackView alloc] initWithFrame:CGRectZero];
    factsGrid.translatesAutoresizingMaskIntoConstraints = NO;
    factsGrid.axis = UILayoutConstraintAxisVertical;
    factsGrid.spacing = PPSpaceMD;
    factsGrid.alignment = UIStackViewAlignmentFill;
    factsGrid.distribution = UIStackViewDistributionFillEqually;
    [factsCard addSubview:factsEyebrow];
    [factsCard addSubview:factsGrid];

    for (NSInteger idx = 0; idx < self.factItems.count; idx += 2) {
        NSMutableArray<UIView *> *rowItems = [NSMutableArray array];
        for (NSInteger column = idx; column < MIN(idx + 2, self.factItems.count); column++) {
            NSDictionary *item = self.factItems[column];
            PPAdoptFactView *factView = [[PPAdoptFactView alloc] initWithFrame:CGRectZero];
            [factView configureWithIconName:item[@"icon"]
                                      title:item[@"title"]
                                      value:item[@"value"]];
            [rowItems addObject:factView];
        }

        if (rowItems.count == 1) {
            UIView *spacer = [[UIView alloc] initWithFrame:CGRectZero];
            spacer.translatesAutoresizingMaskIntoConstraints = NO;
            [rowItems addObject:spacer];
        }

        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:rowItems];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = PPSpaceMD;
        row.alignment = UIStackViewAlignmentFill;
        row.distribution = UIStackViewDistributionFillEqually;
        [factsGrid addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [factsEyebrow.topAnchor constraintEqualToAnchor:factsCard.topAnchor constant:18],
        [factsEyebrow.leadingAnchor constraintEqualToAnchor:factsCard.leadingAnchor constant:18],
        [factsEyebrow.trailingAnchor constraintEqualToAnchor:factsCard.trailingAnchor constant:-18],

        [factsGrid.topAnchor constraintEqualToAnchor:factsEyebrow.bottomAnchor constant:12],
        [factsGrid.leadingAnchor constraintEqualToAnchor:factsCard.leadingAnchor constant:14],
        [factsGrid.trailingAnchor constraintEqualToAnchor:factsCard.trailingAnchor constant:-14],
        [factsGrid.bottomAnchor constraintEqualToAnchor:factsCard.bottomAnchor constant:-14]
    ]];

    UIView *detailsCard = [self pp_makeSectionCard];
    [self.contentStack addArrangedSubview:detailsCard];

    UILabel *detailsTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    detailsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailsTitleLabel.font = [GM boldFontWithSize:PPFontTitle2] ?: [UIFont systemFontOfSize:PPFontTitle2 weight:UIFontWeightBold];
    detailsTitleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    detailsTitleLabel.text = kLang(@"adopt_detail_story_title");

    self.detailsBodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.detailsBodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsBodyLabel.font = [GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium];
    self.detailsBodyLabel.textColor = GM.PrimaryTextColor ?: UIColor.labelColor;
    self.detailsBodyLabel.numberOfLines = 0;
    self.detailsBodyLabel.textAlignment = NSTextAlignmentNatural;

    [detailsCard addSubview:detailsTitleLabel];
    [detailsCard addSubview:self.detailsBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [detailsTitleLabel.topAnchor constraintEqualToAnchor:detailsCard.topAnchor constant:18],
        [detailsTitleLabel.leadingAnchor constraintEqualToAnchor:detailsCard.leadingAnchor constant:18],
        [detailsTitleLabel.trailingAnchor constraintEqualToAnchor:detailsCard.trailingAnchor constant:-18],

        [self.detailsBodyLabel.topAnchor constraintEqualToAnchor:detailsTitleLabel.bottomAnchor constant:12],
        [self.detailsBodyLabel.leadingAnchor constraintEqualToAnchor:detailsCard.leadingAnchor constant:18],
        [self.detailsBodyLabel.trailingAnchor constraintEqualToAnchor:detailsCard.trailingAnchor constant:-18],
        [self.detailsBodyLabel.bottomAnchor constraintEqualToAnchor:detailsCard.bottomAnchor constant:-18]
    ]];
}

#pragma mark - Top Buttons (functional control glass over hero)

- (void)pp_setupTopButtons {
    self.closeButton = [self pp_makeGlassCircleButtonWithSymbol:@"xmark" action:@selector(pp_closeTapped)];
    self.shareButton = [self pp_makeGlassCircleButtonWithSymbol:@"square.and.arrow.up" action:@selector(pp_shareTapped)];

    NSMutableArray<UIView *> *trailingButtons = [NSMutableArray arrayWithObject:self.shareButton];
    if (!self.isOwner) {
        self.favoriteButton = [[FavoriteButton alloc] init];
        self.favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.favoriteButton.layer.cornerRadius = 23.0;
        self.favoriteButton.layer.masksToBounds = YES;
        self.favoriteButton.adID = self.model.documentID ?: @"";
        self.favoriteButton.collection = @"favoritesAdoptPets";
        [self.favoriteButton initValue];
        [self.favoriteButton colosTintForAds];
        [self.favoriteButton.widthAnchor constraintEqualToConstant:42].active = YES;
        [self.favoriteButton.heightAnchor constraintEqualToConstant:42].active = YES;
        [trailingButtons addObject:self.favoriteButton];

        UIButton *reportBtn = [self pp_makeGlassCircleButtonWithSymbol:@"flag" action:@selector(reportAdBTN:)];
        [trailingButtons addObject:reportBtn];
    }

    self.topActionsStack = [[UIStackView alloc] initWithArrangedSubviews:trailingButtons];
    self.topActionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.topActionsStack.axis = UILayoutConstraintAxisVertical;
    self.topActionsStack.spacing = 10.0;
    self.topActionsStack.alignment = UIStackViewAlignmentCenter;
    self.topActionsStack.distribution = UIStackViewDistributionEqualSpacing;

    [self.view addSubview:self.closeButton];
    [self.view addSubview:self.topActionsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceXL],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:PPSpaceXL],

        [self.topActionsStack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:PPSpaceXL],
        [self.topActionsStack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-PPSpaceXL]
    ]];
}

#pragma mark - Contact Dock

- (void)pp_setupContactView {
    if (self.isOwner) {
        return;
    }

    self.contactView = [[UserContactView alloc] initWithFrame:CGRectZero];
    self.contactView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactView.alpha = 0.0;
    self.contactView.semanticContentAttribute = GM.setSemantic;
    self.contactView.backgroundColor = AppForgroundColr ?: UIColor.secondarySystemBackgroundColor;
    self.contactView.layer.cornerRadius = PPCornerCard;
    self.contactView.layer.masksToBounds = NO;
    self.contactView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [self.contactView pp_setBorderColor:[[UIColor separatorColor] colorWithAlphaComponent:0.20]];
    [self.contactView pp_setShadowColor:UIColor.blackColor];
    self.contactView.layer.shadowOpacity = 0.12;
    self.contactView.layer.shadowRadius = 18.0;
    self.contactView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    if (@available(iOS 13.0, *)) {
        self.contactView.layer.cornerCurve = kCACornerCurveContinuous;
    }

    self.contactGradientLayer = [CAGradientLayer layer];
    self.contactGradientLayer.colors = @[
        (__bridge id)[AppBackgroundClrDarker colorWithAlphaComponent:1.0].CGColor,
        (__bridge id)[AppBackgroundClrLigter colorWithAlphaComponent:1.0].CGColor
    ];
    self.contactGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.contactGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.contactGradientLayer.cornerRadius = PPCornerCard;
    [self.contactView.layer insertSublayer:self.contactGradientLayer atIndex:0];

    [self.view addSubview:self.contactView];
    [NSLayoutConstraint activateConstraints:@[
        [self.contactView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:PPSpaceBase],
        [self.contactView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-PPSpaceBase],
        [self.contactView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-PPSpaceMD],
        [self.contactView.heightAnchor constraintEqualToConstant:78]
    ]];

    [self.view bringSubviewToFront:self.contactView];
    [self.view bringSubviewToFront:self.closeButton];
    [self.view bringSubviewToFront:self.topActionsStack];

    UserModel *owner = [UserManager userModelForID:self.model.ownerID];
    if (owner) {
        [self pp_configureContactViewWithOwner:owner];
    }

    if (self.model.ownerID.length > 0) {
        __weak typeof(self) weakSelf = self;
        [UsrMgr getOtherUserModelFromFirestoreWithUID:self.model.ownerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !user || error) {
                return;
            }
            [strongSelf pp_configureContactViewWithOwner:user];
        }];
    }
}


#pragma mark - Configure

- (void)pp_configureContent {
    NSString *name = PPAdoptDisplayValue(PPAdoptTrimmedString(self.model.name));
    NSString *kind = [MainKindsModel kindNameForID:self.model.kindID] ?: @"";
    NSString *breed = self.model.subKindModel.SubKindName ?: [[self.model.mainKindModel subKindForID:self.model.breedID] SubKindName] ?: @"";
    NSString *city = PPAdoptTrimmedString(self.model.mCityName);
    NSString *gender = self.model.gender.length > 0 ? kLang(self.model.gender) : @"";
    NSString *age = PPAdoptAgeValue(self.model.ageMonths);

    self.titleLabel.text = name;

    NSMutableArray<NSString *> *subtitleParts = [NSMutableArray array];
    if (PPAdoptTrimmedString(breed).length > 0 && ![breed isEqualToString:@"-"]) {
        [subtitleParts addObject:breed];
    }
    if (PPAdoptTrimmedString(kind).length > 0 && ![kind isEqualToString:@"-"]) {
        [subtitleParts addObject:kind];
    }
    if (city.length > 0) {
        [subtitleParts addObject:city];
    }
    self.subtitleLabel.text = subtitleParts.count > 0 ? [subtitleParts componentsJoinedByString:@"  •  "] : kLang(@"adopt_detail_available_now");

    // Identity chips — status (success) + gender + age quick facts.
    for (UIView *view in self.identityChipsStack.arrangedSubviews) {
        [self.identityChipsStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    PPAdoptInfoBadgeView *statusChip = [[PPAdoptInfoBadgeView alloc] initWithFrame:CGRectZero];
    [statusChip configureWithIconName:@"heart.fill"
                                 text:kLang(@"adopt_detail_available_now")
                                 tint:AppSuccessClr ?: UIColor.systemGreenColor];
    [self.identityChipsStack addArrangedSubview:statusChip];

    if (PPAdoptTrimmedString(gender).length > 0 && ![gender isEqualToString:@"-"]) {
        PPAdoptInfoBadgeView *genderChip = [[PPAdoptInfoBadgeView alloc] initWithFrame:CGRectZero];
        [genderChip configureWithIconName:@"figure.stand" text:gender];
        [self.identityChipsStack addArrangedSubview:genderChip];
    }
    if (PPAdoptTrimmedString(age).length > 0 && ![age isEqualToString:@"-"]) {
        PPAdoptInfoBadgeView *ageChip = [[PPAdoptInfoBadgeView alloc] initWithFrame:CGRectZero];
        [ageChip configureWithIconName:@"calendar" text:age];
        [self.identityChipsStack addArrangedSubview:ageChip];
    }

    NSString *details = PPAdoptTrimmedString(self.model.details);
    if (details.length == 0) {
        details = kLang(@"adopt_detail_no_details");
    }
    self.detailsBodyLabel.attributedText = [self pp_bodyText:details];

    NSInteger pageCount = MAX(self.mediaItems.count, 1);
    self.pageControl.numberOfPages = pageCount;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = (pageCount < 2);
    self.galleryProgressTrackView.hidden = (pageCount < 2);
    [self.imagesCV reloadData];
}

- (void)pp_configureContactViewWithOwner:(UserModel *)owner {
    if (!owner) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.contactView configureWithUser:owner
                           chatCallback:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!UserManager.sharedManager.isUserLoggedIn) {
            [UserManager showPromptOnTopController];
            return;
        }
        [ChManager.sharedManager startChatWith:owner fromController:strongSelf];
    }
                           callCallback:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!owner.MobileNo.length) {
            [GM showAlertWithTitle:kLang(@"No Number")
                           message:kLang(@"This user has no phone number")
                         imageName:@"exclamationmark.triangle.fill"
                 inViewController:strongSelf];
            return;
        }
        [AppClasses callPhoneNumber:owner.MobileNo fromViewController:strongSelf];
    }];

    [self.contactView.callButton setTitle:nil forState:UIControlStateNormal];
    [self.contactView.callButton setTitle:nil forState:UIControlStateHighlighted];
    [self.contactView.callButton setTitle:nil forState:UIControlStateDisabled];
    [self.contactView.chatButton setTitle:nil forState:UIControlStateNormal];
    [self.contactView.chatButton setTitle:nil forState:UIControlStateHighlighted];
    [self.contactView.chatButton setTitle:nil forState:UIControlStateDisabled];

    [UIView animateWithDuration:PPAnimDurationNormal animations:^{
        weakSelf.contactView.alpha = 1.0;
    }];
}

#pragma mark - Helpers

- (UIView *)pp_makeSectionCard {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    PPApplyContinuousCorners(card, PPCornerCard);
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [card pp_setBorderColor:[[UIColor separatorColor] colorWithAlphaComponent:0.28]];
    card.layer.masksToBounds = YES;
    return card;
}

- (NSAttributedString *)pp_bodyText:(NSString *)text {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineSpacing = 6.0;
    style.alignment = NSTextAlignmentNatural;
    return [[NSAttributedString alloc] initWithString:text ?: @""
                                           attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:PPFontBody] ?: [UIFont systemFontOfSize:PPFontBody weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: GM.PrimaryTextColor ?: UIColor.labelColor,
        NSParagraphStyleAttributeName: style
    }];
}

- (UIButton *)pp_makeGlassCircleButtonWithSymbol:(NSString *)symbol action:(SEL)action {
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.baseBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.18];
    config.baseForegroundColor = UIColor.whiteColor;
    config.background.visualEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    config.image = [UIImage systemImageNamed:symbol];
    config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    config.contentInsets = NSDirectionalEdgeInsetsMake(13, 13, 13, 13);

    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 23.0;
    button.layer.masksToBounds = YES;
    [button.widthAnchor constraintEqualToConstant:46].active = YES;
    [button.heightAnchor constraintEqualToConstant:46].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Entrance (Signature Moment — Reduce-Motion gated)

- (void)pp_prepareEntranceStateIfNeeded {
    if (self.didAnimateEntrance || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    self.heroContainer.alpha = 0.0;
    self.heroContainer.transform = CGAffineTransformMakeScale(1.018, 1.018);
    self.topActionsStack.alpha = 0.0;
    self.closeButton.alpha = 0.0;
    self.contactView.alpha = 0.0;
    self.contactView.transform = CGAffineTransformMakeTranslation(0.0, 18.0);

    for (UIView *view in self.contentStack.arrangedSubviews) {
        if (view == self.heroContainer) {
            continue;
        }
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    }
}

- (void)pp_runEntranceAnimationIfNeeded {
    if (self.didAnimateEntrance) {
        return;
    }
    self.didAnimateEntrance = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.heroContainer.alpha = 1.0;
        self.heroContainer.transform = CGAffineTransformIdentity;
        self.topActionsStack.alpha = 1.0;
        self.closeButton.alpha = 1.0;
        self.contactView.alpha = 1.0;
        self.contactView.transform = CGAffineTransformIdentity;
        for (UIView *view in self.contentStack.arrangedSubviews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }

    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.52
                          delay:0.02
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.heroContainer.alpha = 1.0;
        self.heroContainer.transform = CGAffineTransformIdentity;
        self.closeButton.alpha = 1.0;
        self.topActionsStack.alpha = 1.0;
    } completion:nil];

    NSTimeInterval delay = 0.12;
    for (UIView *view in self.contentStack.arrangedSubviews) {
        if (view == self.heroContainer) {
            continue;
        }
        [UIView animateWithDuration:0.38
                              delay:delay
                             options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                          animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        delay += 0.055;
    }

    // Signature moment 2 — contact dock rises last.
    [UIView animateWithDuration:0.38
                          delay:delay
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.20
                         options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                      animations:^{
        self.contactView.alpha = 1.0;
        self.contactView.transform = CGAffineTransformIdentity;
    } completion:nil];
}


#pragma mark - Actions

- (void)pp_closeTapped {
    if (self.navigationController && self.navigationController.viewControllers.firstObject != self) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)pp_shareTapped {
    NSMutableArray *items = [NSMutableArray array];

    NSString *name = PPAdoptTrimmedString(self.model.name);
    if (name.length > 0) {
        [items addObject:name];
    }

    NSString *firstURL = PPAdoptTrimmedString(self.model.imageURLs.firstObject);
    NSURL *url = firstURL.length > 0 ? [NSURL URLWithString:firstURL] : nil;
    if (url) {
        [items addObject:url];
    }

    if (items.count == 0) {
        return;
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.shareButton;
        activityVC.popoverPresentationController.sourceRect = self.shareButton.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return MAX(self.mediaItems.count, 1);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPAdoptGalleryCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPAdoptGalleryCell" forIndexPath:indexPath];

    NSDictionary *media = (indexPath.item < self.mediaItems.count) ? self.mediaItems[indexPath.item] : nil;
    NSString *imageURL = PPAdoptMediaStringValue(media[@"display_url"]);
    BOOL isVideo = PPReusableVideoMediaEnabled() && [PPAdoptMediaStringValue(media[@"media_type"]) isEqualToString:@"video"];
    [cell configureVideoBadgeVisible:isVideo];
    if (imageURL.length > 0) {
        [GM setImageFromFirebaseURLString:imageURL
                                imageView:cell.imageView
                                  phImage:@"pawPlaceholder"
                              showShimmer:YES
                               completion:nil];
    } else {
        cell.imageView.image = [UIImage imageNamed:@"pawPlaceholder"];
    }

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item >= self.mediaItems.count) {
        return;
    }
    NSDictionary *media = self.mediaItems[indexPath.item];
    BOOL isVideo = PPReusableVideoMediaEnabled() && [PPAdoptMediaStringValue(media[@"media_type"]) isEqualToString:@"video"];
    NSString *videoURLString = PPAdoptMediaStringValue(media[@"video_url"]);
    if (!isVideo || videoURLString.length == 0) {
        return;
    }
    NSURL *videoURL = [NSURL URLWithString:videoURLString];
    if (!videoURL) {
        return;
    }
    PPPremiumVideoPlayerViewController *playerVC =
    [[PPPremiumVideoPlayerViewController alloc] initWithURL:videoURL];
    UIViewController *presenter = AppMgr.topViewController ?: self;
    [presenter presentViewController:playerVC animated:YES completion:nil];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return collectionView.bounds.size;
}

#pragma mark - UIScrollViewDelegate (page + progress rail)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.imagesCV || self.pageControl.numberOfPages == 0) {
        return;
    }

    CGFloat width = MAX(CGRectGetWidth(scrollView.bounds), 1.0);
    NSInteger page = (NSInteger)lround(scrollView.contentOffset.x / width);
    page = MAX(0, MIN(page, self.pageControl.numberOfPages - 1));
    self.pageControl.currentPage = page;

    // Progress rail — scroll-linked fill (continuous indicator).
    NSInteger pages = MAX(self.mediaItems.count, 1);
    if (pages <= 1 || self.galleryProgressTrackView.hidden) {
        return;
    }
    CGFloat trackWidth = CGRectGetWidth(self.galleryProgressTrackView.bounds);
    CGFloat fillWidth = self.galleryProgressWidthConstraint.constant;
    CGFloat maxLeading = MAX(trackWidth - fillWidth, 0.0);
    CGFloat progress = scrollView.contentOffset.x / MAX((scrollView.contentSize.width - width), 1.0);
    progress = MAX(0.0, MIN(progress, 1.0));
    self.galleryProgressLeadingConstraint.constant = maxLeading * progress;
}

#pragma mark - Report Ad

- (void)reportAdBTN:(UIButton *)sender {
    if (![UserManager sharedManager].isUserLoggedIn) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:kLang(@"login_required_title")
            message:kLang(@"report_login_required_message")
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
        message:kLang(@"report_alert_message")
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *reasons = @{
        @"inappropriate_content": kLang(@"report_reason_inappropriate"),
        @"scam_fraud": kLang(@"report_reason_fraud"),
        @"wrong_category": kLang(@"report_reason_wrong_category"),
        @"spam": kLang(@"report_reason_spam"),
        @"other": kLang(@"report_reason_other")
    };

    for (NSString *code in @[@"inappropriate_content", @"scam_fraud", @"wrong_category", @"spam", @"other"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:reasons[code]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [self submitAdoptReportWithReason:code];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
        style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = sender;
        sheet.popoverPresentationController.sourceRect = sender.bounds;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)submitAdoptReportWithReason:(NSString *)reason {
    NSString *docID = self.model.documentID;
    if (docID.length == 0) return;

    NSString *currentUID = PPCurrentFIRAuthUser.uid;
    if (currentUID.length == 0) {
        currentUID = [UserManager sharedManager].currentUser.ID;
    }
    if (currentUID.length == 0) return;

    FIRFirestore *db = [FIRFirestore firestore];

    // 1. Flag on the content document (array-union for multi-reporter support)
    FIRDocumentReference *docRef =
        [[db collectionWithPath:@"adopt_pets"] documentWithPath:docID];

    [docRef updateData:@{
        @"reportedBy"    : [FIRFieldValue fieldValueForArrayUnion:@[currentUID]],
        @"reportCount"   : [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    // 2. Write a dedicated report document for audit trail
    NSString *reportID = [NSString stringWithFormat:@"%@_%@", docID, currentUID];
    FIRDocumentReference *reportRef = [[db collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId"         : reportID,
        @"contentId"        : docID,
        @"contentType"      : @"adopt_pet",
        @"collection"       : @"adopt_pets",
        @"reason"           : reason,
        @"reporterUid"      : currentUID,
        @"reportedOwnerUid" : self.model.ownerID ?: @"",
        @"status"           : @"pending",
        @"platform"         : @"ios",
        @"createdAt"        : [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt"        : [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportRef setData:reportData merge:YES completion:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:kLang(@"Error")
                    message:kLang(@"report_submit_failed_message")
                    preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:kLang(@"report_submit_title")
                    message:kLang(@"report_submit_message")
                    preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

@end
