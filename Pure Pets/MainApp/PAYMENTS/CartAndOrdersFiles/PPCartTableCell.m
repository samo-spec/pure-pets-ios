//
//  PPCartTableCell 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//


//
//  PPCartTableCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 01/11/2025.
//  Following iOS 26 UI design guidelines
//

#import "PPCartTableCell.h"
#import "CartItem.h"
#import "PPChatsFunc.h"
#import "PPCommerceFeedbackManager.h"
#ifndef DLog
#define DLog(fmt, ...) NSLog((@"[PPCartCell] " fmt), ##__VA_ARGS__)
#endif

@interface PPCartTableCell ()

@property (nonatomic, strong) UIButton *cardContainer;

@property (nonatomic, strong, readwrite) UIImageView *itemImageView;
@property (nonatomic, strong, readwrite) UILabel *nameLabel;
@property (nonatomic, strong, readwrite) UILabel *priceLabel;
@property (nonatomic, strong, readwrite) UILabel *quantityLabel;

@property (nonatomic, strong) UIStackView *textStack;
@property (nonatomic, strong) UIStackView *stepperStack;

@property (nonatomic, strong) UIButton *minusButton;
@property (nonatomic, strong) UIButton *plusButton;
@property (nonatomic, strong) UIButton *removeButton;

@property (nonatomic, strong) CartItem *currentItem;

// Subtle top separator above cardContainer
 
@end

@implementation PPCartTableCell

#pragma mark - Init

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupViews];
    }
    return self;
}

#pragma mark - Setup UI

-(void)setupViews {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    // RTL/LTR
    self.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    self.contentView.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;

    self.cardContainer = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleLarge configType:PPButtonConfigrationGlass];
    self.cardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardContainer.layer.cornerRadius = 18.0;
    self.cardContainer.layer.masksToBounds = YES;
    self.cardContainer.backgroundColor = UIColor.clearColor;
    [self addSubview:self.cardContainer];
 

    // Soft tint overlay for readability
    UIView *tintOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    tintOverlay.userInteractionEnabled = NO;
    tintOverlay.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.0];
    [self.cardContainer addSubview:tintOverlay];

    // Product image
    self.itemImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.itemImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.itemImageView.layer.cornerRadius = 14.0;
    self.itemImageView.clipsToBounds = YES;
    self.itemImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.itemImageView.backgroundColor = UIColor.secondarySystemBackgroundColor;
    [self.cardContainer addSubview:self.itemImageView];

    // Name
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [GM boldFontWithSize:17];
    self.nameLabel.textColor = UIColor.labelColor;
    self.nameLabel.numberOfLines = 2;
    self.nameLabel.textAlignment = NSTextAlignmentNatural;

    // Price
    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.font = [GM MidFontWithSize:16];
    self.priceLabel.textColor = UIColor.secondaryLabelColor;
    self.priceLabel.numberOfLines = 1;
    self.priceLabel.textAlignment = NSTextAlignmentNatural;

    // Text stack
    self.textStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.nameLabel, self.priceLabel]];
    self.textStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.textStack.axis = UILayoutConstraintAxisVertical;
    self.textStack.spacing = 12.0;
    self.textStack.alignment = UIStackViewAlignmentFill;
    [self.cardContainer addSubview:self.textStack];

    // Quantity label
    self.quantityLabel = [[UILabel alloc] init];
    self.quantityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.quantityLabel.font = [GM boldFontWithSize:17];
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    self.quantityLabel.textColor = UIColor.labelColor;
    self.quantityLabel.minimumScaleFactor = 0.8;
    self.quantityLabel.adjustsFontSizeToFitWidth = YES;

    // Buttons
    self.minusButton = [self pp_createIconButtonWithSystemName:@"minus" kind:0];
    [self.minusButton addTarget:self action:@selector(didTapMinus) forControlEvents:UIControlEventTouchUpInside];

    self.plusButton = [self pp_createIconButtonWithSystemName:@"plus" kind:0];
    [self.plusButton addTarget:self action:@selector(didTapPlus) forControlEvents:UIControlEventTouchUpInside];

    self.removeButton = [self pp_createIconButtonWithSystemName:@"trash" kind:1];
    [self.removeButton addTarget:self action:@selector(didTapRemove) forControlEvents:UIControlEventTouchUpInside];
    [self.cardContainer addSubview:self.removeButton];
    
    
    // Pro polish: spring press feedback
    [self pp_applyPressTargetsToButton:self.minusButton];
    [self pp_applyPressTargetsToButton:self.plusButton];
    [self pp_applyPressTargetsToButton:self.removeButton];
    
    

    // Stepper stack (pill)
    UIView *stepperPill = [[UIView alloc] initWithFrame:CGRectZero];
    stepperPill.translatesAutoresizingMaskIntoConstraints = NO;
    stepperPill.layer.cornerRadius = 18.0;
    stepperPill.layer.masksToBounds = YES;
    stepperPill.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.05];
    [self.cardContainer addSubview:stepperPill];

    self.stepperStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.minusButton, self.quantityLabel, self.plusButton]];
    self.stepperStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.stepperStack.axis = UILayoutConstraintAxisHorizontal;
    self.stepperStack.spacing = 8.0;
    self.stepperStack.alignment = UIStackViewAlignmentCenter;
    self.stepperStack.distribution = UIStackViewDistributionFill;
    [stepperPill addSubview:self.stepperStack];

    // Constraints
    //UIView *m = self.contentView;
    [NSLayoutConstraint activateConstraints:@[
        

        [self.cardContainer.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [self.cardContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
        [self.cardContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [self.cardContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],

        [tintOverlay.topAnchor constraintEqualToAnchor:self.cardContainer.topAnchor],
        [tintOverlay.bottomAnchor constraintEqualToAnchor:self.cardContainer.bottomAnchor],
        [tintOverlay.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor],
        [tintOverlay.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor],

        [self.itemImageView.leadingAnchor constraintEqualToAnchor:self.cardContainer.leadingAnchor constant:6],
        [self.itemImageView.topAnchor constraintEqualToAnchor:self.cardContainer.topAnchor constant:6],
        [self.itemImageView.bottomAnchor constraintEqualToAnchor:self.cardContainer.bottomAnchor constant:-6],
        [self.itemImageView.widthAnchor constraintEqualToConstant:88],
        [self.itemImageView.heightAnchor constraintGreaterThanOrEqualToConstant:88],

        [self.removeButton.topAnchor constraintEqualToAnchor:self.cardContainer.topAnchor constant:8],
        [self.removeButton.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor constant:-8],
        [self.removeButton.widthAnchor constraintEqualToConstant:26],
        [self.removeButton.heightAnchor constraintEqualToConstant:26],

        [self.textStack.topAnchor constraintEqualToAnchor:self.itemImageView.topAnchor],
        [self.textStack.leadingAnchor constraintEqualToAnchor:self.itemImageView.trailingAnchor constant:12],
        [self.textStack.trailingAnchor constraintEqualToAnchor:self.removeButton.leadingAnchor constant:-10],

        [stepperPill.trailingAnchor constraintEqualToAnchor:self.cardContainer.trailingAnchor constant:-8],
        [stepperPill.bottomAnchor constraintEqualToAnchor:self.cardContainer.bottomAnchor constant:-8],
        [stepperPill.heightAnchor constraintEqualToConstant:40],
        //[stepperPill.widthAnchor constraintEqualToConstant:44],

        [self.stepperStack.topAnchor constraintEqualToAnchor:stepperPill.topAnchor],
        [self.stepperStack.bottomAnchor constraintEqualToAnchor:stepperPill.bottomAnchor],
        [self.stepperStack.leadingAnchor constraintEqualToAnchor:stepperPill.leadingAnchor constant:10],
        [self.stepperStack.trailingAnchor constraintEqualToAnchor:stepperPill.trailingAnchor constant:-10],

        [self.minusButton.widthAnchor constraintEqualToConstant:20],
        [self.minusButton.heightAnchor constraintEqualToConstant:20],
        [self.plusButton.widthAnchor constraintEqualToConstant:20],
        [self.plusButton.heightAnchor constraintEqualToConstant:20],
        [self.quantityLabel.widthAnchor constraintGreaterThanOrEqualToConstant:30],
    ]];

    // Accessibility
    self.removeButton.accessibilityLabel = NSLocalizedString(@"Remove item", nil);
    self.minusButton.accessibilityLabel = NSLocalizedString(@"Decrease quantity", nil);
    self.plusButton.accessibilityLabel = NSLocalizedString(@"Increase quantity", nil);
}


- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self pp_setCardHighlighted:highlighted animated:animated];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self pp_setCardHighlighted:selected animated:animated];
}



#pragma mark - Helpers

/// Modern icon button (supports destructive style)
/// kind: 0 = normal, 1 = destructive
- (UIButton *)pp_createIconButtonWithSystemName:(NSString *)iconName kind:(NSInteger)kind {
    UIButton *btn;

    UIImageSymbolConfiguration *symCfg =
    [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
    UIImage *img = [[UIImage systemImageNamed:iconName] imageByApplyingSymbolConfiguration:symCfg];

    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.contentInsets = NSDirectionalEdgeInsetsMake(6, 6, 6, 6);
        cfg.image = img;
        cfg.baseForegroundColor = (kind == 1) ? UIColor.systemRedColor : UIColor.labelColor;
        cfg.background.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.0];
        if (kind == 1) {
            cfg.background.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.0];
        }
        btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    } else {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setImage:img forState:UIControlStateNormal];
        btn.tintColor = (kind == 1) ? UIColor.systemRedColor : UIColor.labelColor;
        btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
        btn.layer.cornerRadius = 16;
        btn.backgroundColor = (kind == 1) ? [UIColor.systemRedColor colorWithAlphaComponent:0.10] : [[UIColor labelColor] colorWithAlphaComponent:0.06];
    }

    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.adjustsImageWhenHighlighted = YES;
    if (kind == 1) {
       // btn.hidden = YES;
    }
    return btn;
}

-(void)prepareForReuse {
    [super prepareForReuse];
    self.currentItem = nil;
    self.itemImageView.image = nil;
    self.nameLabel.text = @"";
    self.priceLabel.text = @"";
    self.quantityLabel.text = @"";

    [self pp_setCardHighlighted:NO animated:NO];

    self.minusButton.transform = CGAffineTransformIdentity;
    self.plusButton.transform = CGAffineTransformIdentity;
    self.removeButton.transform = CGAffineTransformIdentity;

    self.minusButton.alpha = 1.0;
    self.plusButton.alpha = 1.0;
    self.removeButton.alpha = 1.0;
 
}

#pragma mark - Configuration

- (void)configureWithItem:(CartItem *)item {
    self.currentItem = item;

    self.nameLabel.text = item.name ?: @"";

    // Currency display (kept as-is style but safe)
    self.priceLabel.text = [PPChatsFunc formattedCurrency:item.quantity];

    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)item.quantity];

    [GM setImageFromUrlString:item.imageURL imageView:self.itemImageView phImage:@"placeholder"];
    
    self.priceLabel.text = [PPChatsFunc formattedCurrency:item.price];

    

    DLog(@"Configured cell for itemID=%@ name=%@", item.itemID, item.name);
}

#pragma mark - Actions

- (void)didTapMinus {
    if (!self.currentItem) return;
    DLog(@"Minus tapped for %@", self.currentItem.name);
    if (self.currentItem.quantity > 1) {
        self.currentItem.quantity -= 1;
        self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.currentItem.quantity];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];
    }
    if (self.onAction) self.onAction(self.currentItem, @"minus");
}

- (void)didTapPlus {
    if (!self.currentItem) return;
    DLog(@"Plus tapped for %@", self.currentItem.name);
    self.currentItem.quantity += 1;
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)self.currentItem.quantity];
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventCartQuantityChanged];
    if (self.onAction) self.onAction(self.currentItem, @"plus");
}

- (void)didTapRemove {
    if (!self.currentItem) return;
    DLog(@"Remove tapped for %@", self.currentItem.name);
    if (self.onAction) self.onAction(self.currentItem, @"remove");
}

- (void)layoutSubviews {
    [super layoutSubviews];

    
    
    
}


#pragma mark - Pro polish interactions

- (void)pp_setCardHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    UIView *target = self.cardContainer ?: self.contentView;
 
    CGFloat scale = highlighted ? 0.985 : 1.0;
    CGFloat alpha = highlighted ? 0.94 : 1.0;

   

    void (^changes)(void) = ^{
        target.transform = CGAffineTransformMakeScale(scale, scale);
        target.alpha = alpha;
 
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:changes
                     completion:nil];
}

- (void)pp_applyPressTargetsToButton:(UIButton *)button {
    if (!button) return;

    [button addTarget:self action:@selector(pp_buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(pp_buttonTouchUp:) forControlEvents:UIControlEventTouchCancel];
}

- (void)pp_buttonTouchDown:(UIButton *)button {
    [UIView animateWithDuration:0.08
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        button.transform = CGAffineTransformMakeScale(0.92, 0.92);
        button.alpha = 0.92;
    } completion:nil];
}

- (void)pp_buttonTouchUp:(UIButton *)button {
    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.55
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        button.transform = CGAffineTransformIdentity;
        button.alpha = 1.0;
    } completion:nil];
}


@end
