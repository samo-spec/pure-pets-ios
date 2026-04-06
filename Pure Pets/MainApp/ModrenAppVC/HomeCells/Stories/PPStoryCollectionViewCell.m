//
//  PPStoryCollectionViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStoryCollectionViewCell.h"
#import "Language.h"
#import "PPImageLoaderManager.h"
#import "GM.h"

static const CGFloat PPStoryRingHostSize = 84.0;
static const CGFloat PPStoryAvatarSize = 68.0;
static const CGFloat PPStoryRingLineWidth = 3.4;
static const CGFloat PPStoryTrackLineWidth = 2.0;

@interface PPStoryCollectionViewCell ()
@property (nonatomic, strong) CAShapeLayer *ringGradientMaskLayer;
@end

@implementation PPStoryCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.contentView.clipsToBounds = NO;

        _ringHostView = [[UIView alloc] initWithFrame:CGRectZero];
        _ringHostView.translatesAutoresizingMaskIntoConstraints = NO;
        _ringHostView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
        _ringHostView.layer.cornerRadius = PPStoryRingHostSize * 0.5;
        _ringHostView.layer.masksToBounds = NO;
        _ringHostView.layer.shadowColor = UIColor.blackColor.CGColor;
        _ringHostView.layer.shadowOpacity = 0.10;
        _ringHostView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
        _ringHostView.layer.shadowRadius = 5.0;
        [self.contentView addSubview:_ringHostView];

        _imageView = [[UIImageView alloc] init];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self.ringHostView addSubview:_imageView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [GM MidFontWithSize:11.5];
        _nameLabel.textColor = UIColor.labelColor;
        _nameLabel.numberOfLines = 1;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.textAlignment = NSTextAlignmentNatural;
        _nameLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        [self.contentView addSubview:_nameLabel];

        _ringTrackLayer = [CAShapeLayer layer];
        _ringTrackLayer.fillColor = UIColor.clearColor.CGColor;
        _ringTrackLayer.lineWidth = PPStoryTrackLineWidth;
        _ringTrackLayer.strokeColor = [UIColor colorWithWhite:0.7 alpha:0.32].CGColor;
        _ringTrackLayer.lineCap = kCALineCapRound;
        [self.ringHostView.layer addSublayer:_ringTrackLayer];

        _ringLayer = [CAShapeLayer layer];
        _ringLayer.fillColor = UIColor.clearColor.CGColor;
        _ringLayer.lineWidth = PPStoryRingLineWidth;
        _ringLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        _ringLayer.lineCap = kCALineCapRound;
        [self.ringHostView.layer addSublayer:_ringLayer];

        _ringGradientLayer = [CAGradientLayer layer];
        _ringGradientLayer.startPoint = CGPointMake(0.1, 0.2);
        _ringGradientLayer.endPoint = CGPointMake(0.9, 0.8);
        _ringGradientMaskLayer = [CAShapeLayer layer];
        _ringGradientMaskLayer.fillColor = UIColor.clearColor.CGColor;
        _ringGradientMaskLayer.lineWidth = PPStoryRingLineWidth;
        _ringGradientMaskLayer.lineCap = kCALineCapRound;
        _ringGradientMaskLayer.strokeColor = UIColor.blackColor.CGColor;
        _ringGradientLayer.mask = _ringGradientMaskLayer;
        [self.ringHostView.layer addSublayer:_ringGradientLayer];

        _addBadgeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _addBadgeButton.translatesAutoresizingMaskIntoConstraints = NO;
        _addBadgeButton.hidden = YES;
        _addBadgeButton.backgroundColor = [self pp_appPrimaryColor];
        _addBadgeButton.layer.cornerRadius = 12.0;
        _addBadgeButton.layer.borderWidth = 2.0;
        _addBadgeButton.layer.borderColor = UIColor.systemBackgroundColor.CGColor;
        _addBadgeButton.layer.shadowColor = UIColor.blackColor.CGColor;
        _addBadgeButton.layer.shadowOpacity = 0.15;
        _addBadgeButton.layer.shadowOffset = CGSizeMake(0, 1.0);
        _addBadgeButton.layer.shadowRadius = 2.0;
        UIImage *addIcon = [UIImage systemImageNamed:@"plus"];
        [_addBadgeButton setImage:addIcon forState:UIControlStateNormal];
        _addBadgeButton.tintColor = UIColor.whiteColor;
        [_addBadgeButton addTarget:self
                            action:@selector(pp_addBadgeTapped)
                  forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_addBadgeButton];

        [NSLayoutConstraint activateConstraints:@[
            [_ringHostView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:0.0],
            [_ringHostView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_ringHostView.widthAnchor constraintEqualToConstant:PPStoryRingHostSize],
            [_ringHostView.heightAnchor constraintEqualToConstant:PPStoryRingHostSize],

            [_imageView.centerXAnchor constraintEqualToAnchor:self.ringHostView.centerXAnchor],
            [_imageView.centerYAnchor constraintEqualToAnchor:self.ringHostView.centerYAnchor],
            [_imageView.widthAnchor constraintEqualToConstant:PPStoryAvatarSize],
            [_imageView.heightAnchor constraintEqualToConstant:PPStoryAvatarSize],

            [_nameLabel.topAnchor constraintEqualToAnchor:_ringHostView.bottomAnchor constant:7.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:2.0],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-2.0],
            [_nameLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-2.0],

            [_addBadgeButton.widthAnchor constraintEqualToConstant:24.0],
            [_addBadgeButton.heightAnchor constraintEqualToConstant:24.0],
            [_addBadgeButton.trailingAnchor constraintEqualToAnchor:_ringHostView.trailingAnchor constant:1.0],
            [_addBadgeButton.bottomAnchor constraintEqualToAnchor:_ringHostView.bottomAnchor constant:1.0]
        ]];

        _imageView.layer.cornerRadius = PPStoryAvatarSize * 0.5;
        _imageView.layer.borderWidth = 1.0;
        _imageView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
        _imageView.layer.shadowColor = UIColor.blackColor.CGColor;
        _imageView.layer.shadowOpacity = 0.10;
        _imageView.layer.shadowRadius = 4.0;
        _imageView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
        self.layer.shouldRasterize = NO;

        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self pp_updateRingPath];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    self.nameLabel.text = @"";
    self.accessibilityLabel = @"";
    self.onAddBadgeTapped = nil;
    self.addBadgeButton.hidden = YES;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ringLayer.strokeEnd = 1.0;
    self.ringTrackLayer.opacity = 1.0;
    self.ringGradientLayer.hidden = YES;
    [self.ringTrackLayer removeAllAnimations];
    [self.ringLayer removeAllAnimations];
    [self.ringGradientLayer removeAllAnimations];
    [CATransaction commit];
}

- (void)configureWithStory:(PPStory *)story
{
    [self configureWithStory:story currentUserEntry:NO showAddBadge:NO];
}

- (void)configureWithStory:(PPStory *)story
          currentUserEntry:(BOOL)isCurrentUserEntry
              showAddBadge:(BOOL)showAddBadge
{
    NSString *name =
        [story.userName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        name = kLang(@"Unknown");
    }
    self.nameLabel.text = name;
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.font = isCurrentUserEntry ? [GM MidFontWithSize:12.0] : [GM MidFontWithSize:11.5];
    self.addBadgeButton.hidden = !showAddBadge;

    UIColor *primaryRingColor = [self pp_appPrimaryColor];
    UIColor *accentColor = [UIColor colorWithRed:0.91 green:0.16 blue:0.48 alpha:1.0];
    UIColor *warmColor = [UIColor colorWithRed:0.98 green:0.58 blue:0.16 alpha:1.0];
    UIColor *lightColor = [self pp_adjustedColor:primaryRingColor saturation:0.92 brightness:1.08];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (story.isSeen) {
        self.ringTrackLayer.opacity = 1.0;
        self.ringTrackLayer.strokeColor = [UIColor colorWithWhite:0.62 alpha:0.30].CGColor;
        self.ringLayer.strokeColor = [UIColor colorWithWhite:0.60 alpha:0.92].CGColor;
        self.ringLayer.lineWidth = 3.0;
        self.ringGradientMaskLayer.lineWidth = 3.0;
        self.ringGradientLayer.hidden = YES;
    } else {
        self.ringTrackLayer.opacity = 1.0;
        self.ringTrackLayer.strokeColor = [UIColor colorWithWhite:0.65 alpha:0.26].CGColor;
        self.ringLayer.lineWidth = PPStoryRingLineWidth;
        self.ringGradientMaskLayer.lineWidth = PPStoryRingLineWidth;
        self.ringLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
        self.ringGradientLayer.colors = @[
            (__bridge id)warmColor.CGColor,
            (__bridge id)lightColor.CGColor,
            (__bridge id)primaryRingColor.CGColor,
            (__bridge id)accentColor.CGColor
        ];
        self.ringGradientLayer.locations = @[@0.0, @0.30, @0.65, @1.0];
        self.ringGradientLayer.hidden = NO;
    }
    [CATransaction commit];

    if (story.userImageURL) {
        [PPImageLoaderManager.shared setImageOnImageView:self.imageView
                                                     url:story.userImageURL.absoluteString
                                              placeholder:PPSYSImage(@"person.crop.circle.fill")
                                               complation:^(UIImage * _Nullable image, NSString * _Nullable urlString) {
        }];
    } else {
        self.imageView.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    }

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@",
                               name,
                               story.isSeen ? kLang(@"Read") : kLang(@"NewMessage")];
    [self pp_updateRingPath];
}

- (void)pp_updateRingPath
{
    CGRect hostBounds = CGRectIntegral(self.ringHostView.bounds);
    if (CGRectEqualToRect(hostBounds, CGRectZero)) {
        return;
    }

    CGFloat inset = 2.8;
    CGRect ringRect = CGRectInset(hostBounds, inset, inset);
    UIBezierPath *ringPath = [UIBezierPath bezierPathWithOvalInRect:ringRect];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.ringTrackLayer.frame = hostBounds;
    self.ringTrackLayer.path = ringPath.CGPath;
    self.ringGradientLayer.frame = hostBounds;
    self.ringGradientMaskLayer.frame = hostBounds;
    self.ringGradientMaskLayer.path = ringPath.CGPath;
    self.ringLayer.frame = hostBounds;
    self.ringLayer.path = ringPath.CGPath;
    [CATransaction commit];
}

- (void)pp_addBadgeTapped
{
    if (self.onAddBadgeTapped) {
        self.onAddBadgeTapped();
    }
}

- (UIColor *)pp_appPrimaryColor
{
    UIColor *primary = [UIColor colorNamed:@"AppPrimaryClr"];
    if (!primary) {
        primary = [UIColor colorWithRed:0.93 green:0.08 blue:0.38 alpha:1.0];
    }
    return primary;
}

- (UIColor *)pp_adjustedColor:(UIColor *)baseColor
                   saturation:(CGFloat)saturationMultiplier
                   brightness:(CGFloat)brightnessMultiplier
{
    CGFloat h = 0.0;
    CGFloat s = 0.0;
    CGFloat b = 0.0;
    CGFloat a = 0.0;
    if (![baseColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return baseColor;
    }
    s = MIN(MAX(s * saturationMultiplier, 0.0), 1.0);
    b = MIN(MAX(b * brightnessMultiplier, 0.0), 1.0);
    return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
}
@end
