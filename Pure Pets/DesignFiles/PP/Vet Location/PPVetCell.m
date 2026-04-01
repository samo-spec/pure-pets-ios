#import "PPVetCell.h"

@interface PPVetCell ()
@property (nonatomic, strong) UIView *containerView;
@end

@implementation PPVetCell

+ (NSString *)reuseIdentifier { return @"PPVetCellIdentifier"; }

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.clearColor;  // allow spacing
        [self setupViews];
    }
    return self;
}

#pragma mark - Setup
- (void)setupViews {

    // ---------------------------------------------------------
    // 1️⃣ Container view for rounded card + spacing
    // ---------------------------------------------------------
    self.containerView = [[UIView alloc] init];
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.containerView.backgroundColor = AppForgroundColr;
    self.containerView.layer.cornerRadius = 18;
    self.containerView.layer.masksToBounds = YES;

    [self.contentView addSubview:self.containerView];

    // Spacing between cells (top/bottom = 8)
    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:0],
        [self.containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-0],
        [self.containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [self.containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8]
    ]];

    // ---------------------------------------------------------
    // 2️⃣ Labels inside container
    // ---------------------------------------------------------
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.font = [GM boldFontWithSize:18];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.descLabel = [[UILabel alloc] init];
    self.descLabel.font = [GM MidFontWithSize:14];
    self.descLabel.numberOfLines = 2;
    self.descLabel.textColor = [UIColor secondaryLabelColor];
    self.descLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // ---------------------------------------------------------
    // 3️⃣ Buttons inside container
    // ---------------------------------------------------------
    if (@available(iOS 26.0, *)) {
        self.callButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"KLang_Call") font:[GM MidFontWithSize:14] imageName:@"phone.badge.waveform" target:self config:[UIButtonConfiguration glassButtonConfiguration] action:@selector(callTapped)];
        
        self.dirButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"KLang_Directions") font:[GM MidFontWithSize:14] imageName:@"point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath" target:self config:[UIButtonConfiguration glassButtonConfiguration] action:@selector(dirTapped)];
    } else {
        self.callButton = [PPButtonHelper pp_buttonWithTitle:kLang(@"KLang_Call") font:[GM boldFontWithSize:14] imageName:@"phone.badge.waveform" target:self config:[UIButtonConfiguration plainButtonConfiguration] action:@selector(callTapped)];
        self.dirButton  = [PPButtonHelper pp_buttonWithTitle:kLang(@"KLang_Directions") font:[GM boldFontWithSize:14] imageName:@"point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath" target:self config:[UIButtonConfiguration plainButtonConfiguration] action:@selector(dirTapped)];
    }

    // Add to container
    [self.containerView addSubview:self.nameLabel];
    [self.containerView addSubview:self.descLabel];
    [self.containerView addSubview:self.callButton];
    [self.containerView addSubview:self.dirButton];

    // ---------------------------------------------------------
    // 4️⃣ AutoLayout inside container
    // ---------------------------------------------------------
    CGFloat margin = 16;

    [NSLayoutConstraint activateConstraints:@[
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:margin],
        [self.nameLabel.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-margin],
        [self.nameLabel.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:12],
        
        [self.descLabel.leadingAnchor constraintEqualToAnchor:self.nameLabel.leadingAnchor],
        [self.descLabel.trailingAnchor constraintEqualToAnchor:self.nameLabel.trailingAnchor],
        [self.descLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:4],

        [self.dirButton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-margin],
        [self.dirButton.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-12],

        [self.callButton.trailingAnchor constraintEqualToAnchor:self.dirButton.leadingAnchor constant:-margin],
        [self.callButton.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-12]
    ]];
}

#pragma mark - Actions
- (void)callTapped {
    if (self.onCall) self.onCall(self);
}

- (void)dirTapped {
    if (self.onDirections) self.onDirections(self);
}



#pragma mark - Configure
- (void)configureWithName:(NSString *)name description:(NSString *)desc hasPhone:(BOOL)hasPhone {
    self.nameLabel.text = name ?: @"";
    self.descLabel.text = desc ?: @"";
    self.callButton.enabled = hasPhone;
    self.callButton.alpha = hasPhone ? 1.0 : 0.45;
}

#pragma mark - Layout
- (void)layoutSubviews {
    [super layoutSubviews];
    // Inset separator for better look
    self.separatorInset = UIEdgeInsetsMake(0, 16, 0, 16);
}



#pragma mark - Setup
- (UIButton *)styledButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 6;
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 12, 6, 12);
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.titleLabel.adjustsFontForContentSizeCategory = YES;
    return btn;
}
@end
