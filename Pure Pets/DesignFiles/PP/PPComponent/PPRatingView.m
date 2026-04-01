//
//  PPRatingView.m
//  Pure Pets
//
//  Design System — Star rating with half-star support.
//

#import "PPRatingView.h"

static const NSInteger kPPMaxStars = 5;

@interface PPRatingView ()

@property (nonatomic, strong) UIStackView *starStack;
@property (nonatomic, strong) UILabel *countLabel;

@end

@implementation PPRatingView

- (instancetype)initWithRating:(CGFloat)rating {
    if (self = [super initWithFrame:CGRectZero]) {
        _rating = rating;
        _reviewCount = 0;
        _starSize = 14.0;
        _starColor = [UIColor colorNamed:@"WarningColor" inBundle:nil compatibleWithTraitCollection:nil]
                     ?: [UIColor systemOrangeColor];
        [self pp_setupUI];
        [self pp_updateStars];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _rating = 0.0;
        _reviewCount = 0;
        _starSize = 14.0;
        _starColor = [UIColor colorNamed:@"WarningColor" inBundle:nil compatibleWithTraitCollection:nil]
                     ?: [UIColor systemOrangeColor];
        [self pp_setupUI];
        [self pp_updateStars];
    }
    return self;
}

#pragma mark - UI

- (void)pp_setupUI {
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _starStack = [[UIStackView alloc] init];
    _starStack.translatesAutoresizingMaskIntoConstraints = NO;
    _starStack.axis = UILayoutConstraintAxisHorizontal;
    _starStack.spacing = 2.0;
    _starStack.alignment = UIStackViewAlignmentCenter;
    [self addSubview:_starStack];

    for (NSInteger i = 0; i < kPPMaxStars; i++) {
        UIImageView *star = [[UIImageView alloc] init];
        star.translatesAutoresizingMaskIntoConstraints = NO;
        star.contentMode = UIViewContentModeScaleAspectFit;
        [star.widthAnchor constraintEqualToConstant:self.starSize].active = YES;
        [star.heightAnchor constraintEqualToConstant:self.starSize].active = YES;
        [_starStack addArrangedSubview:star];
    }

    _countLabel = [[UILabel alloc] init];
    _countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _countLabel.font = [GM fontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    _countLabel.textColor = AppSecondaryTextClr;
    _countLabel.hidden = YES;
    [self addSubview:_countLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_starStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_starStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],

        [_countLabel.leadingAnchor constraintEqualToAnchor:_starStack.trailingAnchor constant:PPSpaceXXS],
        [_countLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_countLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor],

        [self.heightAnchor constraintGreaterThanOrEqualToConstant:self.starSize + 4.0],
    ]];
}

#pragma mark - Update

- (void)setRating:(CGFloat)rating reviewCount:(NSInteger)count {
    _rating = rating;
    _reviewCount = count;
    [self pp_updateStars];
}

- (void)setRating:(CGFloat)rating {
    _rating = rating;
    [self pp_updateStars];
}

- (void)pp_updateStars {
    CGFloat clampedRating = MAX(0.0, MIN(5.0, self.rating));
    NSArray<UIView *> *stars = self.starStack.arrangedSubviews;

    for (NSInteger i = 0; i < kPPMaxStars; i++) {
        UIImageView *starView = (UIImageView *)stars[i];
        NSString *symbolName;

        if (clampedRating >= (i + 1)) {
            symbolName = @"star.fill";
        } else if (clampedRating >= (i + 0.5)) {
            symbolName = @"star.leadinghalf.filled";
        } else {
            symbolName = @"star";
        }

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration configurationWithPointSize:self.starSize
                                                            weight:UIImageSymbolWeightMedium];
        starView.image = [[UIImage systemImageNamed:symbolName withConfiguration:config]
                          imageWithTintColor:self.starColor
                          renderingMode:UIImageRenderingModeAlwaysOriginal];
    }

    if (self.reviewCount > 0) {
        self.countLabel.hidden = NO;
        self.countLabel.text = [NSString stringWithFormat:@"(%ld)", (long)self.reviewCount];
    } else {
        self.countLabel.hidden = YES;
    }
}

@end
