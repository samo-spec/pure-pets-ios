//
//  PPHomeActionCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 26/12/2025.
//


#import "PPHomeActionCell.h"

@interface PPHomeActionCell ()


@end

@implementation PPHomeActionCell

+ (NSString *)reuseIdentifier {
    return @"PPHomeActionCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}

#pragma mark - UI

- (void)setupUI {

    self.contentView.backgroundColor = UIColor.clearColor;

    // =========================
    // Glass Button
    // =========================
    self.actionButton = [UIButton new];
    self.actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.actionButton addTarget:self
                          action:@selector(handleTap)
                forControlEvents:UIControlEventTouchUpInside];
    self.actionButton.tintColor = AppPrimaryClr;
    self.actionButton.showsMenuAsPrimaryAction = YES;
    if (@available(iOS 26.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        //cfg.background.backgroundColor = AppForgroundColr;
        cfg.background.cornerRadius = PPCornersHome;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceLG, PPSpaceMD, PPSpaceLG);
        self.actionButton.configuration = cfg;
    }
    else if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.background.backgroundColor = AppBackgroundClr;
        cfg.background.cornerRadius = PPCornerMedium;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(PPSpaceMD, PPSpaceLG, PPSpaceMD, PPSpaceLG);
        self.actionButton.configuration = cfg;
    }
    else {
        self.actionButton.backgroundColor = AppBackgroundClr;
        self.actionButton.layer.cornerRadius = PPCornerMedium;
        self.actionButton.clipsToBounds = YES;
    }

    [self.contentView addSubview:self.actionButton];

    // =========================
    // Constraints
    // =========================
    [NSLayoutConstraint activateConstraints:@[
        [self.actionButton.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.actionButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.actionButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.actionButton.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

#pragma mark - Configure

- (void)configureWithTitle:(NSString *)title
                systemIcon:(NSString *)systemIconName {

    UIImage *icon = [UIImage pp_symbolNamed:systemIconName pointSize:22 weight:UIImageSymbolWeightSemibold scale:UIImageSymbolScaleLarge palette:@[AppPrimaryClr] makeTemplate:YES];
    if (@available(iOS 15.0, *)) {

        UIButtonConfiguration *cfg = self.actionButton.configuration;
        cfg.title = title;
        cfg.image = icon;
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = PPSpaceSM;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
       // cfg.background.cornerRadius = 16;
        cfg.baseForegroundColor = AppPrimaryClr;
        cfg.attributedTitle =
        [[NSAttributedString alloc] initWithString:title
                                        attributes:@{
            NSFontAttributeName : [GM boldFontWithSize:PPFontSubheadline],
            NSForegroundColorAttributeName : AppPrimaryTextClr
        }];

        self.actionButton.configuration = cfg;
        self.actionButton.clipsToBounds = YES;
    }
    else {
        [self.actionButton setTitle:title forState:UIControlStateNormal];
        [self.actionButton setImage:icon forState:UIControlStateNormal];
        self.actionButton.titleLabel.font = [GM boldFontWithSize:PPFontSubheadline];
        [self.actionButton setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
    }
}

- (void)handleTap {
    if (self.onTap) {
        self.onTap();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.onTap = nil;
}

- (void)setOnTap:(void (^)(void))onTap {
    _onTap = [onTap copy];
}

@end
