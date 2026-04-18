//
//  ABTableViewCell.m
//  Test
//
//  Created by Alex Bumbu on 06/12/14.
//  Copyright (c) 2014 Alex Bumbu. All rights reserved.
//

#import "ABMenuTableViewCell.h"
#import "UITableView+VisibleMenuCell.h"

static CGFloat const kSpringAnimationDuration = 0.58;
static CGFloat const kAnimationDuration = 0.24;
static CGFloat const kHighlightAnimationDuration = 0.45;
static CGFloat const kHorizontalPadding = 16.0;
static CGFloat const kSurfaceVerticalInset = 4.0;
static CGFloat const kIconContainerSize = 40.0;
static CGFloat const kChevronSize = 11.0;

@interface ABMenuTableViewCell ()

@property (nonatomic, weak) UITableView *parentTableView;
@property (nonatomic, assign) ABMenuState rightMenuState;
@property (nonatomic, assign) CGFloat gestureStartMenuWidth;
@property (nonatomic, assign) BOOL ongoingSelection;
@property (nonatomic, strong) UIView *surfaceView;
@property (nonatomic, strong) UIView *iconBackdropView;
@property (nonatomic, strong) UIImageView *disclosureImageView;
@property (nonatomic, strong) CAGradientLayer *surfaceGradientLayer;

@end

@implementation ABMenuTableViewCell {
    CGRect _rightMenuViewInitialFrame;
    UIPanGestureRecognizer *_swipeGesture;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }

    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self commonInit];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];

    UIView *view = self.superview;
    while (view && ![view isKindOfClass:[UITableView class]]) {
        view = view.superview;
    }

    self.parentTableView = (UITableView *)view;
}

- (void)willTransitionToState:(UITableViewCellStateMask)state
{
    if (state == UITableViewCellStateShowingEditControlMask) {
        if (self.rightMenuState == ABMenuStateShown || self.rightMenuState == ABMenuStateShowing) {
            [self updateMenuView:ABMenuUpdateHideAction animated:YES];
        }
    }

    [super willTransitionToState:state];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    ABMenuTableViewCell *cell = nil;
    if (self.parentTableView.visibleMenuCell) {
        if (selected && (self.rightMenuState == ABMenuStateShowing || self.rightMenuState == ABMenuStateShown)) {
            cell = self;
        } else {
            cell = self.parentTableView.visibleMenuCell;
        }

        [cell updateMenuView:ABMenuUpdateHideAction animated:YES];
        self.parentTableView.visibleMenuCell = nil;
        return;
    }

    [super setSelected:selected animated:animated];
    [self pp_updateInteractiveStateAnimated:animated];

    if (!selected) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHighlightAnimationDuration * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            self.ongoingSelection = NO;
        });
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    CGFloat gestureVelocity = [_swipeGesture velocityInView:self].x;
    if (gestureVelocity) {
        return;
    }

    if (self.parentTableView.visibleMenuCell) {
        return;
    }

    if (self.rightMenuState == ABMenuStateShowing || self.rightMenuState == ABMenuStateShown) {
        return;
    }

    if (highlighted) {
        self.ongoingSelection = YES;
    }

    [super setHighlighted:highlighted animated:animated];
    [self pp_updateInteractiveStateAnimated:animated];
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    [self hideMenu];

    self.ongoingSelection = NO;
    self.rightMenuState = ABMenuStateHidden;
    self.gestureStartMenuWidth = 0.0;
    self.textLabel.transform = CGAffineTransformIdentity;
    self.imageView.transform = CGAffineTransformIdentity;

    if (self.parentTableView.visibleMenuCell == self) {
        self.parentTableView.visibleMenuCell = nil;
    }

    [self pp_updateInteractiveStateAnimated:NO];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self pp_layoutContentChrome];

    if (self.rightMenuState == ABMenuStateHidden && self.rightMenuView) {
        [self hideMenu];
    } else {
        CGFloat currentWidth = CGRectGetWidth(self.rightMenuView.frame);
        self.rightMenuView.frame = [self pp_menuFrameForWidth:currentWidth];
        [self setButtonGardActive];
    }
}

- (void)setRightMenuView:(UIView *)rightMenuView
{
    if (_rightMenuView == rightMenuView) {
        return;
    }

    [_rightMenuView removeFromSuperview];
    _rightMenuView = rightMenuView;

    if (!_rightMenuView) {
        _rightMenuViewInitialFrame = CGRectZero;
        return;
    }

    _rightMenuViewInitialFrame = _rightMenuView.frame;
    _rightMenuView.layer.masksToBounds = NO;

    if (self.surfaceView.superview) {
        [self.contentView insertSubview:_rightMenuView belowSubview:self.surfaceView];
    } else {
        [self.contentView insertSubview:_rightMenuView atIndex:0];
    }

    [self hideMenu];
    [self setNeedsLayout];
}

- (BOOL)showingRightMenu
{
    return self.rightMenuState != ABMenuStateHidden;
}

#pragma mark UIGestureRecognizerDelegate Methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != _swipeGesture) {
        return YES;
    }

    if (!self.rightMenuView || CGRectEqualToRect(_rightMenuViewInitialFrame, CGRectZero)) {
        return NO;
    }

    CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self];

    if (self.ongoingSelection || self.editing) {
        return NO;
    }

    if (self.parentTableView.visibleMenuCell && self.parentTableView.visibleMenuCell != self) {
        [self.parentTableView.visibleMenuCell updateMenuView:ABMenuUpdateHideAction animated:YES];
        self.parentTableView.visibleMenuCell = nil;

        if (velocity.x < 0) {
            return NO;
        }
    }

    return fabs(velocity.x) > fabs(velocity.y);
}

#pragma mark Actions

- (void)handleSwipeGesture:(UIPanGestureRecognizer *)gesture
{
    if (!self.rightMenuView) {
        return;
    }

    CGFloat initialWidth = CGRectGetWidth(_rightMenuViewInitialFrame);
    CGFloat currentWidth = CGRectGetWidth(self.rightMenuView.frame);

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            self.gestureStartMenuWidth = currentWidth;
            self.rightMenuState = currentWidth > 0.0 ? ABMenuStateShown : ABMenuStateHidden;
            break;
        }

        case UIGestureRecognizerStateChanged: {
            CGFloat translationX = [gesture translationInView:self].x;
            CGFloat desiredWidth = MAX(0.0, MIN(self.gestureStartMenuWidth - translationX, initialWidth));
            CGFloat deltaWidth = desiredWidth - currentWidth;

            if (fabs(deltaWidth) < FLT_EPSILON) {
                return;
            }

            self.rightMenuState = deltaWidth > 0.0 ? ABMenuStateShowing : ABMenuStateHiding;
            [self updateMenuView:(deltaWidth > 0.0 ? ABMenuUpdateShowAction : ABMenuUpdateHideAction)
                           delta:fabs(deltaWidth)
                        animated:NO
                      completion:nil];
            break;
        }

        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateEnded: {
            CGFloat velocityX = [gesture velocityInView:self].x;
            CGFloat revealedWidth = CGRectGetWidth(self.rightMenuView.frame);
            BOOL shouldShowMenu = NO;

            if (fabs(velocityX) > 180.0) {
                shouldShowMenu = velocityX < 0.0;
            } else {
                shouldShowMenu = revealedWidth >= (initialWidth * 0.45);
            }

            [self updateMenuView:(shouldShowMenu ? ABMenuUpdateShowAction : ABMenuUpdateHideAction)
                        animated:YES];
            break;
        }

        default:
            break;
    }
}

#pragma mark Private Methods

- (void)commonInit
{
    self.ongoingSelection = NO;
    self.rightMenuState = ABMenuStateHidden;
    self.gestureStartMenuWidth = 0.0;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.clipsToBounds = NO;
    self.contentView.clipsToBounds = NO;

    if (!self.surfaceView) {
        self.surfaceView = [[UIView alloc] initWithFrame:CGRectZero];
        self.surfaceView.userInteractionEnabled = NO;
        self.surfaceView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.88];
        [self.contentView insertSubview:self.surfaceView atIndex:0];
    }

    if (!self.surfaceGradientLayer) {
        self.surfaceGradientLayer = [CAGradientLayer layer];
        [self.surfaceView.layer insertSublayer:self.surfaceGradientLayer atIndex:0];
    }

    if (!self.iconBackdropView) {
        self.iconBackdropView = [[UIView alloc] initWithFrame:CGRectZero];
        self.iconBackdropView.userInteractionEnabled = NO;
        self.iconBackdropView.backgroundColor = [[UIColor colorWithHexString:@"#973C62"] colorWithAlphaComponent:0.12];
        [self.contentView addSubview:self.iconBackdropView];
    }

    if (!self.disclosureImageView) {
        self.disclosureImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:PPIsRL ? @"chevron.backward" : @"chevron.forward"]];
        self.disclosureImageView.userInteractionEnabled = NO;
        self.disclosureImageView.contentMode = UIViewContentModeScaleAspectFit;
        self.disclosureImageView.tintColor = [[UIColor colorWithHexString:@"#3D3E65"] colorWithAlphaComponent:0.52];
        [self.contentView addSubview:self.disclosureImageView];
    }

    self.surfaceView.layer.borderWidth = 1.0;
    [self.surfaceView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.28]];
    self.surfaceView.layer.masksToBounds = YES;
    self.iconBackdropView.layer.masksToBounds = YES;

    if (!_swipeGesture) {
        _swipeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
        _swipeGesture.delegate = self;
        [self addGestureRecognizer:_swipeGesture];
    }
}

- (void)pp_layoutContentChrome
{
    CGRect surfaceFrame = [self pp_surfaceFrame];
    surfaceFrame.origin.x = 0;
    surfaceFrame.origin.y = 0;
    surfaceFrame.size.width = surfaceFrame.size.width - 0;
    surfaceFrame.size.height = surfaceFrame.size.height - 0;
    self.surfaceView.frame = surfaceFrame;
    self.surfaceView.layer.cornerRadius = 22.0;
    self.surfaceGradientLayer.frame = self.surfaceView.bounds;
    self.surfaceGradientLayer.colors = @[
        (id)[[UIColor whiteColor] colorWithAlphaComponent:0.98].CGColor,
        (id)[[UIColor colorWithHexString:@"#F7F8FC"] colorWithAlphaComponent:0.92].CGColor
    ];
    self.surfaceGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    self.surfaceGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    self.surfaceGradientLayer.cornerRadius = self.surfaceView.layer.cornerRadius;

    [self pp_setShadowColor:[UIColor colorWithRed:15.0 / 255.0
                                            green:23.0 / 255.0
                                             blue:42.0 / 255.0
                                            alpha:1.0]];
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    self.layer.shadowRadius = 18.0;
    self.layer.masksToBounds = NO;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:surfaceFrame
                                                       cornerRadius:self.surfaceView.layer.cornerRadius].CGPath;

    BOOL isRTL = [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.semanticContentAttribute] == UIUserInterfaceLayoutDirectionRightToLeft;
    BOOL hasImage = self.imageView.image != nil;
    CGFloat midY = CGRectGetMidY(surfaceFrame);

    self.disclosureImageView.hidden = NO;
    CGFloat chevronX = isRTL ?
        CGRectGetMinX(surfaceFrame) + kHorizontalPadding :
        CGRectGetMaxX(surfaceFrame) - kHorizontalPadding - kChevronSize;
    self.disclosureImageView.frame = CGRectMake(chevronX,
                                                midY - (kChevronSize * 0.75),
                                                kChevronSize,
                                                kChevronSize * 1.5);
    self.disclosureImageView.transform = isRTL ? CGAffineTransformMakeScale(-1.0, 1.0) : CGAffineTransformIdentity;

    CGRect iconFrame = CGRectZero;
    if (hasImage) {
        CGFloat iconX = isRTL ?
            CGRectGetMaxX(surfaceFrame) - kHorizontalPadding - kIconContainerSize :
            CGRectGetMinX(surfaceFrame) + kHorizontalPadding;
        iconFrame = CGRectMake(iconX,
                               midY - (kIconContainerSize / 2.0),
                               kIconContainerSize,
                               kIconContainerSize);
        self.iconBackdropView.hidden = NO;
        self.iconBackdropView.frame = iconFrame;
        self.iconBackdropView.layer.cornerRadius = kIconContainerSize / 2.0;
        self.imageView.hidden = NO;
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.tintColor = [UIColor colorWithHexString:@"#973C62"];
        self.imageView.frame = CGRectInset(iconFrame, 9.0, 9.0);
    } else {
        self.iconBackdropView.hidden = YES;
        self.imageView.hidden = YES;
    }

    CGFloat textMinX = isRTL ?
        CGRectGetMaxX(self.disclosureImageView.frame) + 12.0 :
        (hasImage ? CGRectGetMaxX(iconFrame) + 12.0 : CGRectGetMinX(surfaceFrame) + kHorizontalPadding);
    CGFloat textMaxX = isRTL ?
        (hasImage ? CGRectGetMinX(iconFrame) - 12.0 : CGRectGetMaxX(surfaceFrame) - kHorizontalPadding) :
        CGRectGetMinX(self.disclosureImageView.frame) - 12.0;
    CGFloat textWidth = MAX(0.0, textMaxX - textMinX);

    self.textLabel.backgroundColor = UIColor.clearColor;
    self.textLabel.numberOfLines = 2;
    self.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.textLabel.textAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;

    CGSize textSize = [self.textLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    CGFloat textHeight = MIN(MAX(textSize.height, 24.0), CGRectGetHeight(surfaceFrame) - 20.0);
    self.textLabel.frame = CGRectMake(textMinX,
                                      midY - (textHeight / 2.0),
                                      textWidth,
                                      textHeight);

    CGFloat revealedWidth = CGRectGetWidth(self.rightMenuView.frame);
    if (revealedWidth > 0.0) {
        for (UIView *subview in [self pp_swipeableSubviews]) {
            CGRect frame = subview.frame;
            frame.origin.x -= revealedWidth;
            subview.frame = frame;
        }
    }
}

- (void)pp_updateInteractiveStateAnimated:(BOOL)animated
{
    BOOL isActive = self.isHighlighted && self.rightMenuState == ABMenuStateHidden;
    CGAffineTransform transform = isActive ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    CGFloat alpha = isActive ? 0.96 : 1.0;

    void (^changes)(void) = ^{
        self.surfaceView.transform = transform;
        self.surfaceView.alpha = alpha;
        self.iconBackdropView.transform = transform;
    };

    if (animated) {
        [UIView animateWithDuration:0.22 animations:changes];
    } else {
        changes();
    }
}

- (CGRect)pp_surfaceFrame
{
    return CGRectInset(self.contentView.bounds, 0.0, kSurfaceVerticalInset);
}

- (CGRect)pp_menuFrameForWidth:(CGFloat)width
{
    CGRect surfaceFrame = [self pp_surfaceFrame];
    CGFloat clampedWidth = MAX(0.0, MIN(width, CGRectGetWidth(_rightMenuViewInitialFrame)));
    return CGRectMake(CGRectGetMaxX(self.contentView.bounds) - clampedWidth,
                      CGRectGetMinY(surfaceFrame),
                      clampedWidth,
                      CGRectGetHeight(surfaceFrame));
}

- (NSArray<UIView *> *)pp_swipeableSubviews
{
    NSMutableArray<UIView *> *subviews = [NSMutableArray array];
    for (UIView *subview in self.contentView.subviews) {
        if (subview == self.rightMenuView) {
            continue;
        }
        [subviews addObject:subview];
    }
    return subviews;
}

- (void)updateMenuView:(ABMenuUpdateAction)action animated:(BOOL)animated
{
    if (!self.rightMenuView) {
        return;
    }

    CGFloat initialWidth = CGRectGetWidth(_rightMenuViewInitialFrame);
    self.rightMenuState = (action == ABMenuUpdateShowAction) ? ABMenuStateShowing : ABMenuStateHiding;

    [self updateMenuView:action
                   delta:initialWidth
                animated:animated
              completion:^{
        self.rightMenuState = (action == ABMenuUpdateShowAction) ? ABMenuStateShown : ABMenuStateHidden;
        if (action == ABMenuUpdateShowAction) {
            self.parentTableView.visibleMenuCell = self;
        } else if (self.parentTableView.visibleMenuCell == self) {
            self.parentTableView.visibleMenuCell = nil;
        }
    }];
}

- (void)updateMenuView:(ABMenuUpdateAction)action
                 delta:(CGFloat)deltaX
              animated:(BOOL)animated
            completion:(void (^)(void))completionHandler
{
    if (!self.rightMenuView) {
        if (completionHandler) {
            completionHandler();
        }
        return;
    }

    CGFloat initialWidth = CGRectGetWidth(_rightMenuViewInitialFrame);
    CGFloat currentWidth = CGRectGetWidth(self.rightMenuView.frame);
    CGFloat requestedWidth = currentWidth + (action * deltaX);
    CGFloat newWidth = MAX(0.0, MIN(requestedWidth, initialWidth));
    CGFloat appliedDelta = newWidth - currentWidth;

    if (fabs(appliedDelta) < FLT_EPSILON) {
        if (completionHandler) {
            completionHandler();
        }
        return;
    }

    CGRect menuNewFrame = [self pp_menuFrameForWidth:newWidth];
    NSArray<UIView *> *swipeableSubviews = [self pp_swipeableSubviews];

    void (^changes)(void) = ^{
        self.rightMenuView.frame = menuNewFrame;

        for (UIView *subview in swipeableSubviews) {
            CGRect frame = subview.frame;
            frame.origin.x -= appliedDelta;
            subview.frame = frame;
        }
    };

    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        [self setButtonGardActive];
        if (completionHandler) {
            completionHandler();
        }
    };

    if (!animated) {
        changes();
        completion(YES);
        return;
    }

    [UIView animateWithDuration:(action == ABMenuUpdateShowAction ? kSpringAnimationDuration : kAnimationDuration)
                          delay:0.0
         usingSpringWithDamping:(action == ABMenuUpdateShowAction ? 0.88 : 1.0)
          initialSpringVelocity:(action == ABMenuUpdateShowAction ? 0.8 : 0.0)
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:completion];
}

- (void)setButtonGardActive
{
    if (!self.rightMenuView) {
        return;
    }

    self.rightMenuView.layer.cornerRadius = 0;
    [self.rightMenuView pp_setShadowColor:[UIColor colorWithRed:89.0 / 255.0
                                                          green:15.0 / 255.0
                                                           blue:45.0 / 255.0
                                                          alpha:1.0]];
    self.rightMenuView.layer.shadowOpacity = 0.20;
    self.rightMenuView.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    self.rightMenuView.layer.shadowRadius = 16.0;
    self.rightMenuView.layer.borderWidth = 1.0;
    [self.rightMenuView pp_setBorderColor:[[UIColor whiteColor] colorWithAlphaComponent:0.18]];
}

- (void)hideMenu
{
    if (!self.rightMenuView) {
        return;
    }

    self.rightMenuView.frame = [self pp_menuFrameForWidth:0.0];
}

@end
