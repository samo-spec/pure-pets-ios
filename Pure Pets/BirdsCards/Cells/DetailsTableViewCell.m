//
//  DetailsTableViewCell.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import "DetailsTableViewCell.h"
#import "PrefixHeader.pch"
#import "Language.h"

@interface DetailsTableViewCell ()

@property (nonatomic, assign) BOOL didSetupViews;
@property (nonatomic, strong) NSLayoutConstraint *detailsButtonLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *detailsButtonTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *deleteButtonLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *deleteButtonTrailingConstraint;

@end

@implementation DetailsTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)commonInit {
    if (self.didSetupViews) return;
    self.didSetupViews = YES;

    self.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentView.backgroundColor = UIColor.clearColor;

    self.titleLablel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLablel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLablel.font = [GM MidFontWithSize:14];
    self.titleLablel.textColor = UIColor.labelColor;
    self.titleLablel.numberOfLines = 2;
    [self.contentView addSubview:self.titleLablel];

    self.detailsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.detailsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsButton.backgroundColor = [GM appPrimaryColor];
    self.detailsButton.tintColor = UIColor.whiteColor;
    [self.detailsButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.detailsButton.titleLabel.font = [GM MidFontWithSize:12];
    self.detailsButton.layer.cornerRadius = 12.0;
    self.detailsButton.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    self.detailsButton.alpha = 0.0;
    [self.detailsButton addTarget:self action:@selector(detailsButtonClikk:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.detailsButton];

    self.deleteInfoBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.deleteInfoBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [self.deleteInfoBTN setImage:[UIImage systemImageNamed:@"info.circle.fill"] forState:UIControlStateNormal];
    self.deleteInfoBTN.tintColor = [GM appPrimaryColor];
    self.deleteInfoBTN.alpha = 0.0;
    [self.deleteInfoBTN addTarget:self action:@selector(delInfoAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.deleteInfoBTN];

    self.showParentDetails = [UIButton buttonWithType:UIButtonTypeSystem];
    self.showParentDetails.hidden = YES;
    self.showParentDetailsAction = [UIButton buttonWithType:UIButtonTypeSystem];
    self.showParentDetailsAction.hidden = YES;

    UIImage *image = [YYImage imageNamed:@"warningAnimation.gif"];
    self.warningImageView = [[YYAnimatedImageView alloc] initWithImage:image];
    self.warningImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.warningImageView.alpha = 0.0;
    [self.contentView addSubview:self.warningImageView];

    self.detailsButtonTrailingConstraint =
    [self.detailsButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16];
    self.detailsButtonLeadingConstraint =
    [self.detailsButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];
    self.deleteButtonTrailingConstraint =
    [self.deleteInfoBTN.trailingAnchor constraintEqualToAnchor:self.detailsButton.leadingAnchor constant:-8];
    self.deleteButtonLeadingConstraint =
    [self.deleteInfoBTN.leadingAnchor constraintEqualToAnchor:self.detailsButton.trailingAnchor constant:8];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLablel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.titleLablel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.titleLablel.trailingAnchor constraintLessThanOrEqualToAnchor:self.deleteInfoBTN.leadingAnchor constant:-8],

        [self.detailsButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.detailsButton.heightAnchor constraintGreaterThanOrEqualToConstant:30],

        [self.deleteInfoBTN.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.deleteInfoBTN.widthAnchor constraintEqualToConstant:28],
        [self.deleteInfoBTN.heightAnchor constraintEqualToConstant:28],

        [self.warningImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.warningImageView.trailingAnchor constraintEqualToAnchor:self.deleteInfoBTN.leadingAnchor constant:-8],
        [self.warningImageView.widthAnchor constraintEqualToConstant:24],
        [self.warningImageView.heightAnchor constraintEqualToConstant:24]
    ]];

    [self updateSemanticLayout];
}

-(void)setButtonEnabled:(BOOL)enabled
{
    [self.detailsButton setEnabled:enabled];
    [self.detailsButton setUserInteractionEnabled:enabled];
    self.detailsButton.alpha = enabled ? 1.0 : 0.4;
}

- (void)detailsButtonClikk:(id)sender {
    [self.delegate showData:_parentID rowIndex:_cellRowIndex];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:NO animated:animated];
}
- (void)showParentAction:(id)sender {
}

- (void)delInfoAction:(id)sender {
    if(self.tipView)
        [self.tipView dismissWithCompletion:^{}];
    
    
    
    NSString *DeleteTXT = [NSString stringWithFormat:@"%@\n%@",@"تم حذف هذه البطاقه",self.deleteReason];
    if(self.deleteReason == nil || [self.deleteReason isEqual:nil] || [self.deleteReason isEqualToString:@"(null)"]  || [self.deleteReason isEqualToString:@"(null)"])
        DeleteTXT = [NSString stringWithFormat:@"%@",@"تم حذف هذه البطاقه"];
    ZMJPreferences *preferences = [ZMJPreferences new];
    preferences.drawing.backgroundColor =[UIColor whiteColor];
    preferences.drawing.foregroundColor =[GM appPrimaryColor];
    preferences.drawing.textAlignment = NSTextAlignmentCenter;
    preferences.drawing.font = [GM MidFontWithSize:15];
    preferences.drawing.cornerRadius = 10;
    preferences.drawing.arrowPosition = ZMJArrowPosition_bottom;
    preferences.drawing.shadowColor = UIColor.lightGrayColor;
    
    preferences.animating.dismissTransform = CGAffineTransformMakeTranslation(100, 0);
    preferences.animating.showInitialTransform =CGAffineTransformMakeTranslation(-100, 0);
    preferences.animating.showInitialAlpha = 0;
    preferences.animating.showDuration = 1.5;
    preferences.animating.dismissDuration = 1.5;
    
    self.tipView = [[ZMJTipView alloc] initWithText:DeleteTXT
                                            preferences:preferences
                                               delegate:nil];
    [self.tipView showAnimated:YES forView:self.deleteInfoBTN withinSuperview:self.superview];
    
    NSTimeInterval delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.tipView dismissWithCompletion:^{}];
    });
}

-(void)setTopGard:(UIView *)theView
{
    CAGradientLayer *theViewGradient = [CAGradientLayer layer];
    theViewGradient.colors = [NSArray arrayWithObjects:(id)[GM appPrimaryColor].CGColor, (id)[GM appPrimaryColor].CGColor,  nil];
    theViewGradient.frame = theView.bounds;
    theViewGradient.cornerRadius = 0.0;
    
    [theView.layer insertSublayer:theViewGradient atIndex:0];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLablel.text = nil;
    self.parentID = nil;
    self.deleteReason = nil;
    self.detailsButton.alpha = 0.0;
    self.deleteInfoBTN.alpha = 0.0;
    self.warningImageView.alpha = 0.0;
    self.tipView = nil;
    [self.detailsButton setTitle:nil forState:UIControlStateNormal];
    [self setButtonEnabled:YES];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.detailsButton.layer.cornerRadius = CGRectGetHeight(self.detailsButton.bounds) / 2.0;
    [self updateSemanticLayout];
}

- (void)updateSemanticLayout {
    BOOL isEnglish = [Language languageVal] == 0;
    self.titleLablel.textAlignment = isEnglish ? NSTextAlignmentLeft : NSTextAlignmentRight;
    self.contentView.semanticContentAttribute = isEnglish
    ? UISemanticContentAttributeForceLeftToRight
    : UISemanticContentAttributeForceRightToLeft;

    self.detailsButtonLeadingConstraint.active = !isEnglish;
    self.deleteButtonLeadingConstraint.active = !isEnglish;
    self.detailsButtonTrailingConstraint.active = isEnglish;
    self.deleteButtonTrailingConstraint.active = isEnglish;
}

@end
