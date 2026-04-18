//
//  AdoptPetDetailsViewController.m
//  Pure Pets
//

#import "AdoptPetDetailsViewController.h"
#import "AdoptPetModel.h"
#import "AppClasses.h"
#import "FavoriteButton.h"
#import "GM.h"
#import "UserContactView.h"
#import <QuartzCore/QuartzCore.h>

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
    // Force en locale so dates show Latin digits (0-9)
    NSString *localeID = @"en_QA";
    formatter.locale = [NSLocale localeWithLocaleIdentifier:localeID];
    [formatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy h:mm a"];
    return [formatter stringFromDate:date] ?: @"-";
}

@interface PPAdoptGalleryCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
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
}

@end

@interface PPAdoptBadgeView : UIVisualEffectView
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *textLabel;
- (void)configureWithIconName:(NSString *)iconName text:(NSString *)text;
@end

@implementation PPAdoptBadgeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 14.0;
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
        _textLabel.font = [GM MidFontWithSize:12];
        _textLabel.textColor = UIColor.whiteColor;
        _textLabel.numberOfLines = 1;
        _textLabel.lineBreakMode = NSLineBreakByTruncatingTail;

        [self.contentView addSubview:_iconView];
        [self.contentView addSubview:_textLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:14],
            [_iconView.heightAnchor constraintEqualToConstant:14],

            [_textLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:6],
            [_textLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_textLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.heightAnchor constraintEqualToConstant:30]
        ]];
    }
    return self;
}

- (void)configureWithIconName:(NSString *)iconName text:(NSString *)text {
    NSString *safeText = PPAdoptTrimmedString(text);
    self.hidden = (safeText.length == 0 || [safeText isEqualToString:@"-"]);
    self.iconView.image = [UIImage systemImageNamed:iconName ?: @"circle.fill"];
    self.textLabel.text = safeText;
}

@end

@interface PPAdoptFactView : UIView
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
        self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.layer.cornerRadius = 18.0;
        self.layer.masksToBounds = YES;
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveContinuous;
        }

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = GM.appPrimaryColor;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [GM MidFontWithSize:12];
        _titleLabel.textColor = GM.SecondaryTextColor;
        _titleLabel.numberOfLines = 1;

        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _valueLabel.font = [GM boldFontWithSize:16];
        _valueLabel.textColor = GM.PrimaryTextColor;
        _valueLabel.numberOfLines = 2;

        [self addSubview:_iconView];
        [self addSubview:_titleLabel];
        [self addSubview:_valueLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.topAnchor constraintEqualToAnchor:self.topAnchor constant:14],
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_iconView.widthAnchor constraintEqualToConstant:16],
            [_iconView.heightAnchor constraintEqualToConstant:16],

            [_titleLabel.centerYAnchor constraintEqualToAnchor:_iconView.centerYAnchor],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:8],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],

            [_valueLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:10],
            [_valueLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:14],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-14],
            [_valueLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-14],
            [self.heightAnchor constraintGreaterThanOrEqualToConstant:88]
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

@interface AdoptPetDetailsViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate>
@property (nonatomic, strong) AdoptPetModel *model;
@property (nonatomic, assign) BOOL isOwner;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UIView *heroContainer;
@property (nonatomic, strong) UICollectionView *imagesCV;
@property (nonatomic, strong) NSLayoutConstraint *imagesHeightConstraint;
@property (nonatomic, strong) UIView *heroShadeView;
@property (nonatomic, strong) CAGradientLayer *heroGradientLayer;
@property (nonatomic, strong) UIVisualEffectView *heroInfoBlur;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *heroBadgesStack;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) FavoriteButton *favoriteButton;
@property (nonatomic, strong) UIStackView *topActionsStack;
@property (nonatomic, strong) UILabel *detailsBodyLabel;
@property (nonatomic, strong) UserContactView *contactView;
@property (nonatomic, strong) CAGradientLayer *contactGradientLayer;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *factItems;
@end

@implementation AdoptPetDetailsViewController

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

    [self pp_buildFactItems];
    [self pp_setupScrollView];
    [self pp_setupHero];
    [self pp_setupContentSections];
    [self pp_setupTopButtons];
    [self pp_setupContactView];
    [self pp_configureContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds) - 32.0;
    CGFloat heroHeight = MIN(MAX(width * 0.96, 420.0), 540.0);
    self.imagesHeightConstraint.constant = heroHeight;
    self.heroGradientLayer.frame = self.heroShadeView.bounds;
    self.heroShadeView.layer.cornerRadius = 30.0;
    self.heroContainer.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.heroContainer.bounds cornerRadius:30.0].CGPath;
    if (self.contactGradientLayer) {
        self.contactGradientLayer.frame = self.contactView.bounds;
    }
}

#pragma mark - Build Data

- (void)pp_buildFactItems {
    NSString *kind = [MainKindsModel kindNameForID:self.model.kindID] ?: @"-";
    NSString *breed = self.model.subKindModel.SubKindName ?: [[self.model.mainKindModel subKindForID:self.model.breedID] SubKindName] ?: @"-";
    NSString *age = PPAdoptAgeValue(self.model.ageMonths);
    NSString *gender = self.model.gender.length > 0 ? kLang(self.model.gender) : @"-";
    NSString *city = self.model.mCityName.length > 0 ? self.model.mCityName : @"-";
    NSString *created = PPAdoptCreatedValue(self.model.createdAt);

    self.factItems = @[
        @{@"icon": @"pawprint.fill", @"title": kLang(@"Kind"), @"value": PPAdoptDisplayValue(kind)},
        @{@"icon": @"leaf.fill", @"title": kLang(@"Breed"), @"value": PPAdoptDisplayValue(breed)},
        @{@"icon": @"calendar", @"title": kLang(@"Age"), @"value": PPAdoptDisplayValue(age)},
        @{@"icon": @"figure.stand", @"title": kLang(@"Gender"), @"value": PPAdoptDisplayValue(gender)},
        @{@"icon": @"mappin.and.ellipse", @"title": kLang(@"City"), @"value": PPAdoptDisplayValue(city)},
        @{@"icon": @"clock.fill", @"title": kLang(@"Created"), @"value": PPAdoptDisplayValue(created)}
    ];
}

#pragma mark - Setup

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
    self.contentStack.spacing = 14.0;
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

        [self.contentStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24]
    ]];
}

- (void)pp_setupHero {
    self.heroContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroContainer.backgroundColor = UIColor.clearColor;
    self.heroContainer.layer.cornerRadius = 30.0;
    if (@available(iOS 13.0, *)) {
        self.heroContainer.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroContainer pp_setShadowColor:UIColor.blackColor];
    self.heroContainer.layer.shadowOpacity = 0.12;
    self.heroContainer.layer.shadowRadius = 24.0;
    self.heroContainer.layer.shadowOffset = CGSizeMake(0, 14);
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
    self.imagesCV.layer.cornerRadius = 30.0;
    if (@available(iOS 13.0, *)) {
        self.imagesCV.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.imagesCV registerClass:PPAdoptGalleryCell.class forCellWithReuseIdentifier:@"PPAdoptGalleryCell"];
    [self.heroContainer addSubview:self.imagesCV];

    self.heroShadeView = [[UIView alloc] initWithFrame:CGRectZero];
    self.heroShadeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroShadeView.userInteractionEnabled = NO;
    self.heroShadeView.backgroundColor = UIColor.clearColor;
    self.heroShadeView.clipsToBounds = YES;
    self.heroShadeView.layer.cornerRadius = 30.0;
    if (@available(iOS 13.0, *)) {
        self.heroShadeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroContainer addSubview:self.heroShadeView];

    self.heroGradientLayer = [CAGradientLayer layer];
    self.heroGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.08].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.52].CGColor
    ];
    self.heroGradientLayer.locations = @[@0.0, @0.54, @1.0];
    [self.heroShadeView.layer addSublayer:self.heroGradientLayer];

    self.heroInfoBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    self.heroInfoBlur.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroInfoBlur.layer.cornerRadius = 24.0;
    self.heroInfoBlur.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.heroInfoBlur.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.heroContainer addSubview:self.heroInfoBlur];

    self.heroBadgesStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.heroBadgesStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroBadgesStack.axis = UILayoutConstraintAxisHorizontal;
    self.heroBadgesStack.spacing = 8.0;
    self.heroBadgesStack.alignment = UIStackViewAlignmentLeading;
    self.heroBadgesStack.distribution = UIStackViewDistributionFillProportionally;

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:28];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.textAlignment = NSTextAlignmentNatural;

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:15];
    self.subtitleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.88];
    self.subtitleLabel.numberOfLines = 2;
    self.subtitleLabel.textAlignment = NSTextAlignmentNatural;

    [self.heroInfoBlur.contentView addSubview:self.heroBadgesStack];
    [self.heroInfoBlur.contentView addSubview:self.titleLabel];
    [self.heroInfoBlur.contentView addSubview:self.subtitleLabel];

    self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageControl.pageIndicatorTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.28];
    self.pageControl.currentPageIndicatorTintColor = UIColor.whiteColor;
    self.pageControl.hidesForSinglePage = YES;
    [self.heroContainer addSubview:self.pageControl];

    self.imagesHeightConstraint = [self.heroContainer.heightAnchor constraintEqualToConstant:440.0];

    [NSLayoutConstraint activateConstraints:@[
        self.imagesHeightConstraint,

        [self.imagesCV.topAnchor constraintEqualToAnchor:self.heroContainer.topAnchor],
        [self.imagesCV.leadingAnchor constraintEqualToAnchor:self.heroContainer.leadingAnchor],
        [self.imagesCV.trailingAnchor constraintEqualToAnchor:self.heroContainer.trailingAnchor],
        [self.imagesCV.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor],

        [self.heroShadeView.topAnchor constraintEqualToAnchor:self.heroContainer.topAnchor],
        [self.heroShadeView.leadingAnchor constraintEqualToAnchor:self.heroContainer.leadingAnchor],
        [self.heroShadeView.trailingAnchor constraintEqualToAnchor:self.heroContainer.trailingAnchor],
        [self.heroShadeView.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor],

        [self.heroInfoBlur.leadingAnchor constraintEqualToAnchor:self.heroContainer.leadingAnchor constant:14],
        [self.heroInfoBlur.trailingAnchor constraintEqualToAnchor:self.heroContainer.trailingAnchor constant:-14],
        [self.heroInfoBlur.bottomAnchor constraintEqualToAnchor:self.heroContainer.bottomAnchor constant:-14],

        [self.heroBadgesStack.topAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.topAnchor constant:14],
        [self.heroBadgesStack.leadingAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.leadingAnchor constant:14],
        [self.heroBadgesStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroInfoBlur.contentView.trailingAnchor constant:-14],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.heroBadgesStack.bottomAnchor constant:10],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.leadingAnchor constant:14],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.trailingAnchor constant:-14],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.leadingAnchor constant:14],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.trailingAnchor constant:-14],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroInfoBlur.contentView.bottomAnchor constant:-14],

        [self.pageControl.centerXAnchor constraintEqualToAnchor:self.heroContainer.centerXAnchor],
        [self.pageControl.bottomAnchor constraintEqualToAnchor:self.heroInfoBlur.topAnchor constant:-10]
    ]];
}

- (void)pp_setupContentSections {
    UIView *factsCard = [self pp_makeSectionCard];
    [self.contentStack addArrangedSubview:factsCard];

    UIStackView *factsGrid = [[UIStackView alloc] initWithFrame:CGRectZero];
    factsGrid.translatesAutoresizingMaskIntoConstraints = NO;
    factsGrid.axis = UILayoutConstraintAxisVertical;
    factsGrid.spacing = 12.0;
    factsGrid.alignment = UIStackViewAlignmentFill;
    factsGrid.distribution = UIStackViewDistributionFillEqually;
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
        row.spacing = 12.0;
        row.alignment = UIStackViewAlignmentFill;
        row.distribution = UIStackViewDistributionFillEqually;
        [factsGrid addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [factsGrid.topAnchor constraintEqualToAnchor:factsCard.topAnchor constant:14],
        [factsGrid.leadingAnchor constraintEqualToAnchor:factsCard.leadingAnchor constant:14],
        [factsGrid.trailingAnchor constraintEqualToAnchor:factsCard.trailingAnchor constant:-14],
        [factsGrid.bottomAnchor constraintEqualToAnchor:factsCard.bottomAnchor constant:-14]
    ]];

    UIView *detailsCard = [self pp_makeSectionCard];
    [self.contentStack addArrangedSubview:detailsCard];

    UILabel *detailsTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    detailsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailsTitleLabel.font = [GM boldFontWithSize:22];
    detailsTitleLabel.textColor = GM.PrimaryTextColor;
    detailsTitleLabel.text = kLang(@"Details");

    self.detailsBodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.detailsBodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsBodyLabel.font = [GM MidFontWithSize:16];
    self.detailsBodyLabel.textColor = GM.PrimaryTextColor;
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
        [self.closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],

        [self.topActionsStack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [self.topActionsStack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24]
    ]];
}

- (void)pp_setupContactView {
    if (self.isOwner) {
        return;
    }

    self.contactView = [[UserContactView alloc] initWithFrame:CGRectZero];
    self.contactView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contactView.alpha = 1.0;
    self.contactView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.65];
    self.contactView.layer.cornerRadius = 22.0;
    [self.contactView pp_setShadowColor:UIColor.blackColor];
    self.contactView.layer.shadowOpacity = 0.06;
    self.contactView.layer.shadowRadius = 12.0;
    self.contactView.layer.shadowOffset = CGSizeMake(0, 6);
    self.contactView.semanticContentAttribute = GM.setSemantic;

    self.contactGradientLayer = [CAGradientLayer layer];
    self.contactGradientLayer.colors = @[
        (__bridge id)[AppBackgroundClrDarker colorWithAlphaComponent:1.0].CGColor,
        (__bridge id)[AppBackgroundClrLigter colorWithAlphaComponent:1.0].CGColor
    ];
    self.contactGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.contactGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.contactGradientLayer.cornerRadius = 22.0;
    [self.contactView.layer insertSublayer:self.contactGradientLayer atIndex:0];

    [self.view addSubview:self.contactView];
    [NSLayoutConstraint activateConstraints:@[
        [self.contactView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.contactView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.contactView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:10],
        [self.contactView.heightAnchor constraintEqualToConstant:74]
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
    self.subtitleLabel.text = subtitleParts.count > 0 ? [subtitleParts componentsJoinedByString:@"  •  "] : @"Pure Pets";

    for (UIView *view in self.heroBadgesStack.arrangedSubviews) {
        [self.heroBadgesStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    self.heroBadgesStack.hidden = YES;

    NSString *details = PPAdoptTrimmedString(self.model.details);
    if (details.length == 0) {
        details = @"No details added yet.";
    }
    self.detailsBodyLabel.attributedText = [self pp_bodyText:details];

    NSInteger pageCount = MAX(self.model.imageURLs.count, 1);
    self.pageControl.numberOfPages = pageCount;
    self.pageControl.currentPage = 0;
    self.pageControl.hidden = (pageCount < 2);
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

    [UIView animateWithDuration:0.24 animations:^{
        weakSelf.contactView.alpha = 1.0;
    }];
}

#pragma mark - Helpers

- (UIView *)pp_makeSectionCard {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 26.0;
    card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    [card pp_setBorderColor:[[UIColor separatorColor] colorWithAlphaComponent:0.28]];
    card.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        card.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return card;
}

- (NSAttributedString *)pp_bodyText:(NSString *)text {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.lineSpacing = 6.0;
    style.alignment = NSTextAlignmentNatural;
    return [[NSAttributedString alloc] initWithString:text ?: @""
                                           attributes:@{
        NSFontAttributeName: [GM MidFontWithSize:16],
        NSForegroundColorAttributeName: GM.PrimaryTextColor,
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
    return MAX(self.model.imageURLs.count, 1);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPAdoptGalleryCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PPAdoptGalleryCell" forIndexPath:indexPath];

    NSString *imageURL = (indexPath.item < self.model.imageURLs.count) ? PPAdoptTrimmedString(self.model.imageURLs[indexPath.item]) : @"";
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

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return collectionView.bounds.size;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.imagesCV || self.pageControl.numberOfPages == 0) {
        return;
    }

    CGFloat width = MAX(CGRectGetWidth(scrollView.bounds), 1.0);
    NSInteger page = (NSInteger)lround(scrollView.contentOffset.x / width);
    page = MAX(0, MIN(page, self.pageControl.numberOfPages - 1));
    self.pageControl.currentPage = page;
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
