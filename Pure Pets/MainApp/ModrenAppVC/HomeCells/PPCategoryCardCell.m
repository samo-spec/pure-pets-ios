//
//  PPCategoryCardCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 02/01/2026.
//


#import "PPCategoryCardCell.h"
#import "MainKindsModel.h"
#import "PPColorUtils.h"
#import "GM.h"

@interface PPCategoryCardCell ()
@property (nonatomic,
           strong) UIButton *glassBackgroundButton; // modern blur container

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *kindImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSLayoutConstraint *imageTop;
@property (nonatomic, strong) NSLayoutConstraint *kindImageViewCenterY;
@property (nonatomic, strong) MainKindsModel *currentKind;
@property (nonatomic, assign) BOOL isAllOption;
@property (nonatomic, strong) NSLayoutConstraint *glassHeightConstraint;

@end

@implementation PPCategoryCardCell

+ (NSString *)reuseIdentifier {
    return @"PPCategoryCardCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self buildUI];
    }
    return self;
}

#pragma mark - UI

- (void)buildUI {

    self.backgroundColor = UIColor.clearColor;

    // =========================
    // Glass container (modern blur)
    // =========================
    self.glassBackgroundButton = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge configType:PPButtonConfigrationPromp];
    self.glassBackgroundButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassBackgroundButton.backgroundColor = UIColor.clearColor;
    self.glassBackgroundButton.configuration.background.backgroundColor = UIColor.clearColor;
    self.glassBackgroundButton.configuration.baseBackgroundColor = UIColor.clearColor;
    [self.glassBackgroundButton addTarget:self  action:@selector(handleTap)  forControlEvents:UIControlEventTouchUpInside];

    if (@available(iOS 13.0, *)) {
        self.glassBackgroundButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
  
    [self.contentView addSubview:self.glassBackgroundButton];
 
    // add tap recognizer to the blur container (since we removed the button)
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self.glassBackgroundButton addGestureRecognizer:tap];
    self.glassBackgroundButton.userInteractionEnabled = YES;

 
    // Soft shadow (best practice)
    [self pp_setShadowColor:UIColor.blackColor];
    self.layer.shadowOpacity = 0.12;
    self.layer.shadowRadius = 10;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.masksToBounds = NO;

    // =========================
    // Image
    // =========================
    self.imageView = [[UIImageView alloc] init];
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.contentMode = UIViewContentModeScaleToFill;
    self.imageView.layer.cornerRadius = 18;
    self.imageView.layer.masksToBounds = YES;
    self.imageView.alpha = 1;
    
    
    self.kindImageView = [[UIImageView alloc] init];
    self.kindImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.kindImageView.contentMode = UIViewContentModeScaleAspectFit;

    self.kindImageView.layer.masksToBounds = YES;
 
    // =========================
    // Title
    // =========================
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:14];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 1;

    // =========================
    // Hierarchy
    // =========================
    [self.contentView addSubview:self.imageView];
    [self.contentView addSubview:self.glassBackgroundButton];
    [self.contentView addSubview:self.kindImageView];
    [self.contentView addSubview:self.titleLabel];

    // =========================
    // Constraints
    // =========================
    
    [NSLayoutConstraint activateConstraints:@[
        // blur container fills cell
        [self.glassBackgroundButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.glassBackgroundButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.glassBackgroundButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.glassBackgroundButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];
    
    self.glassHeightConstraint = [self.glassBackgroundButton.heightAnchor constraintEqualToConstant:0];
    self.glassHeightConstraint.active = NO;
 
    self.imageTop =  [self.imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5];
    [NSLayoutConstraint activateConstraints:@[
        // image
       
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.glassBackgroundButton.bottomAnchor constant:-5],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.glassBackgroundButton.leadingAnchor constant:5],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.glassBackgroundButton.trailingAnchor constant:-5],
        self.imageTop,
        
       /*
        [self.kindImageView.topAnchor constraintEqualToAnchor:self.glassBackgroundButton.topAnchor constant:6],
        [self.kindImageView.trailingAnchor constraintEqualToAnchor:self.glassBackgroundButton.trailingAnchor constant:-6],
        [self.kindImageView.leadingAnchor constraintEqualToAnchor:self.glassBackgroundButton.leadingAnchor constant:6],
        [self.kindImageView.heightAnchor constraintEqualToAnchor:self.kindImageView.widthAnchor constant:0],
        */
        
        
        [self.kindImageView.topAnchor constraintEqualToAnchor:self.glassBackgroundButton.topAnchor constant:6],
        [self.kindImageView.widthAnchor constraintEqualToConstant:50],
        [self.kindImageView.heightAnchor constraintEqualToConstant:50],
        [self.kindImageView.centerXAnchor constraintEqualToAnchor:self.glassBackgroundButton.centerXAnchor constant:0],
        
        
        // title
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.glassBackgroundButton.bottomAnchor constant:-8],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.glassBackgroundButton.leadingAnchor constant:6],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.glassBackgroundButton.trailingAnchor constant:-6],
        
    ]];
    
    self.kindImageViewCenterY =
        [self.kindImageView.centerYAnchor constraintEqualToAnchor:self.glassBackgroundButton.centerYAnchor];
}


#pragma mark - Tap Handler

- (void)handleTap {
    if (self.onSelect) {
        self.onSelect(self.currentKind, self.isAllOption);
    }
}




#pragma mark - Configuration

- (void)configureWithMainKind:(nullable MainKindsModel *)kind
                        isAll:(BOOL)isAll
                     selected:(BOOL)selected
{
    // ---- Hard reset (reuse safety)
    self.imageView.hidden = NO;
    self.kindImageView.image = nil;
    self.imageView.image = nil;
    self.titleLabel.text = @"";

    self.currentKind = kind;
    self.isAllOption = isAll;

 
    // ---- Base appearance
    UIColor *baseTextColor = AppPrimaryTextClr ?: UIColor.labelColor;
    //UIColor *selectedBG = [PPColorUtils pp_selectedCellColorFromPrimary];

    // ---- Configure “All”
    if (isAll) {
        self.imageView.hidden = YES;
        // Disable top alignment
        self.imageTop.constant = 0;
        // Do NOT toggle kindImageViewCenterY for selection
        // Resize icon to 32x32
        for (NSLayoutConstraint *c in self.kindImageView.constraints) {
            if (c.firstAttribute == NSLayoutAttributeWidth ||
                c.firstAttribute == NSLayoutAttributeHeight) {
                c.constant = 28;
            }
        }
        self.titleLabel.textColor = baseTextColor;
        self.kindImageView.image =
        [UIImage pp_symbolNamed:@"icoGrid.fill"
                      pointSize:18
                         weight:UIImageSymbolWeightSemibold
                          scale:UIImageSymbolScaleLarge
                        palette:@[AppSecondaryTextClr]
                   makeTemplate:YES];
        self.kindImageView.tintColor = AppSecondaryTextClr;
    } else {
        // ---- Normal category
        // Do NOT toggle kindImageViewCenterY for selection
        self.imageView.hidden = NO;
        self.imageTop.constant = 5;
        // Restore icon size to 40x40
        for (NSLayoutConstraint *c in self.kindImageView.constraints) {
            if (c.firstAttribute == NSLayoutAttributeWidth ||
                c.firstAttribute == NSLayoutAttributeHeight) {
                c.constant = 40;
            }
        }
        self.titleLabel.text = kind.KindName ?: @"";
        self.imageView.image = PPImage(kind.KindImageNamed);
        self.kindImageView.image = PPImage(kind.KindImageNamed);
        self.titleLabel.textColor = baseTextColor;
    }

    // Apply selection visual state (pure data binding, no animation here)
    [self applySelection:selected animated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self pp_refreshThemeColors];
        }
    }
}

- (void)pp_refreshThemeColors
{
    [self pp_setShadowColor:UIColor.blackColor];
    self.titleLabel.textColor = AppPrimaryTextClr ?: UIColor.labelColor;
    [self applySelection:self.selected animated:NO];
}

#pragma mark - Reuse

- (void)prepareForReuse {
    [super prepareForReuse];

    self.imageView.hidden = NO;
    self.imageView.image = nil;
    self.titleLabel.text = @"";
 
    self.kindImageViewCenterY.active = NO;
    self.glassHeightConstraint.active = NO;
    self.glassBackgroundButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.00];
    [self applySelection:NO animated:NO];
    
}
// MARK: Selection Visuals

// Dedicated selection applier (single source of truth)
- (void)applySelection:(BOOL)selected animated:(BOOL)animated {
    CGFloat scale = selected ? 1.04 : 1.0;
    CGFloat alpha = selected ? 1.0 : 0.85;

    UIColor *bgColor = selected
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:1.0 alpha:0.06];

    UIColor *borderColor = selected
        ? AppPrimaryClr
        : [[UIColor separatorColor] colorWithAlphaComponent:0.25];

    void (^changes)(void) = ^{
        self.glassBackgroundButton.backgroundColor = bgColor;
        [self.glassBackgroundButton pp_setBorderColor:borderColor];
        self.transform = CGAffineTransformMakeScale(scale, scale);
        self.alpha = alpha;
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

// UIKit-native: let selection state drive visuals
- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self applySelection:selected animated:YES];
}

@end
