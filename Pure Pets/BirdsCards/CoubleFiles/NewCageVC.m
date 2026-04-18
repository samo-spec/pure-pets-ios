//
//  NewCageVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 21/07/2024.
//

#import "NewCageVC.h"
#import "AppDelegate.h"
#import "eggDatesCell.h"

@interface NewCageVC ()<getdataback, UITextFieldDelegate>
{
    NSArray<SubKindModel *> *SubKindsArrayLocal;
    NSMutableArray *childsArray;

    CardModel *FatherClass;
    CardModel *MotherClass;
    long Corners;
    NSDateFormatter *dateFormatter;
 
    //ElasticTransition *tm;
    FIRStorage *firStorage;
    
    NSInteger fatherSelected;
    NSInteger motherSelected;
    CardModel *uploadedCard;
    NSString *oldFatherID;
    NSString *oldMotherID;
}
@property (nonatomic) TTGSnackbar *snakBar;
@property ( nonatomic) UIButton *saveBTN;
@property ( nonatomic) UIButton *closeBTN;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *contentStackView;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UIStackView *cardsStackView;
@property (nonatomic, strong) UILabel *fatherCardTitleLabel;
@property (nonatomic, strong) UILabel *motherCardTitleLabel;
@property (nonatomic, assign) BOOL didBuildLayout;
@end

@implementation NewCageVC

-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

- (void)viewDidLoad {
    [super viewDidLoad];

    fatherSelected = 0;
    motherSelected = 0;
    firStorage = [FIRStorage storage];
    Corners = 20.0;
    if (@available(iOS 26.0, *)) {
        self.view.backgroundColor = UIColor.clearColor;
    } else {
        self.view.backgroundColor = [AppBackgroundClrDarker colorWithAlphaComponent:0.84];
    }
    self.modalInPresentation = YES;

    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd/MM/yyyy"];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];

    childsArray = [[NSMutableArray alloc] init];

    [self setupViews];
    [self setupConstraints];
    [self configureUI];
    [self bindData];
    [self configureSheetPresentationIfNeeded];
}

- (UIFont *)scaledMidFont:(CGFloat)size
{
    return [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:size]];
}

- (UIFont *)scaledBoldFont:(CGFloat)size
{
    return [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM boldFontWithSize:size]];
}

- (UIFont *)scaledRegularFont:(CGFloat)size
{
    return [[UIFontMetrics defaultMetrics] scaledFontForFont:[GM MidFontWithSize:size]];
}

- (void)configureSheetPresentationIfNeeded
{
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController ?: self.navigationController.sheetPresentationController;
        if (!sheet) {
            return;
        }

        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 42.0;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    }
}

- (UIButton *)headerButtonWithTitle:(NSString *)title
                    backgroundColor:(UIColor *)backgroundColor
                          textColor:(UIColor *)textColor
                             action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 22.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.backgroundColor = backgroundColor;
    button.clipsToBounds = YES;

    button.titleLabel.font = [self scaledBoldFont:15];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:textColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
    [button addTarget:self action:@selector(interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];

    return button;
}

- (void)setupViews
{
    if (self.didBuildLayout) {
        return;
    }

    self.didBuildLayout = YES;

    self.saveBTN = [self headerButtonWithTitle:kLang(@"save")
                               backgroundColor:AppPrimaryClr
                                     textColor:AppForgroundColr
                                        action:@selector(click:)];
    self.closeBTN = [self headerButtonWithTitle:kLang(@"cancel")
                                backgroundColor:AppBackgroundClrDarker
                                      textColor:AppPrimaryClrDarker
                                         action:@selector(dismissBTN:)];
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration filledButtonConfiguration];
    }
    self.closeBTN.configuration = config;
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.showsVerticalScrollIndicator = NO;

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;

    self.contentStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStackView.axis = UILayoutConstraintAxisVertical;
    self.contentStackView.spacing = 24.0;

    self.inputContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.inputContainerView.translatesAutoresizingMaskIntoConstraints = NO;

    self.cardsStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.cardsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.cardsStackView.spacing = 16.0;
    self.cardsStackView.distribution = UIStackViewDistributionFillEqually;
    self.cardsStackView.alignment = UIStackViewAlignmentFill;

    self.fatherCardTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.fatherCardTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.motherCardTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.motherCardTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    // --- Allocate views that were never initialised ---
    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.CageName = [[UITextField alloc] initWithFrame:CGRectZero];
    self.bottomBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.noteLablel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tioView = [[UIView alloc] initWithFrame:CGRectZero];
    self.MotherView = [[UIView alloc] initWithFrame:CGRectZero];
    self.FatherBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.MotherBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.motherRingID = [[UILabel alloc] initWithFrame:CGRectZero];
    self.MotherKind = [[UILabel alloc] initWithFrame:CGRectZero];
    self.MotherImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.FatherKind = [[UILabel alloc] initWithFrame:CGRectZero];
    self.FatherImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.fatherRingID = [[UILabel alloc] initWithFrame:CGRectZero];

    if (!PPIOS26()) {
        self.childsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.RingID = [[UITextField alloc] initWithFrame:CGRectZero];
        self.tempSaveBTN = [UIButton buttonWithType:UIButtonTypeSystem];
        self.DNAImageViw = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.closeBTN.backgroundColor = AppForgroundColr;

    }

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];
    [self.contentView addSubview:self.contentStackView];

    [self.contentStackView addArrangedSubview:self.headerView];
    [self.contentStackView addArrangedSubview:self.inputContainerView];
    [self.contentStackView addArrangedSubview:self.cardsStackView];
    [self.contentStackView addArrangedSubview:self.bottomBarView];

    [self.cardsStackView addArrangedSubview:self.MotherView];
    [self.cardsStackView addArrangedSubview:self.tioView];

    [self setupHeaderView];
    [self setupInputSection];
    [self setupParentCardView:self.MotherView
                   titleLabel:self.motherCardTitleLabel
                   actionView:self.MotherBTN
                    ringLabel:self.motherRingID
                    kindLabel:self.MotherKind
                    imageView:self.MotherImageView];
    [self setupParentCardView:self.tioView
                   titleLabel:self.fatherCardTitleLabel
                   actionView:self.FatherBTN
                    ringLabel:self.fatherRingID
                    kindLabel:self.FatherKind
                    imageView:self.FatherImageView];
    [self setupFooterView];
}

- (void)setupHeaderView
{
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self.headerView addSubview:self.saveBTN];
    [self.headerView addSubview:self.closeBTN];
    [self.headerView addSubview:self.headerTitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.heightAnchor constraintEqualToConstant:56.0],

        [self.saveBTN.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
        [self.saveBTN.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.saveBTN.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [self.saveBTN.widthAnchor constraintGreaterThanOrEqualToConstant:72.0],

        [self.closeBTN.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
        [self.closeBTN.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.closeBTN.heightAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [self.closeBTN.widthAnchor constraintGreaterThanOrEqualToConstant:72.0],

        [self.headerTitleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.saveBTN.trailingAnchor constant:12.0],
        [self.headerTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.closeBTN.leadingAnchor constant:-12.0],
        [self.headerTitleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
        [self.headerTitleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor]
    ]];
}

- (void)setupInputSection
{
    self.CageName.translatesAutoresizingMaskIntoConstraints = NO;
    [self.inputContainerView addSubview:self.CageName];

    [NSLayoutConstraint activateConstraints:@[
        [self.CageName.topAnchor constraintEqualToAnchor:self.inputContainerView.topAnchor constant:4.0],
        [self.CageName.leadingAnchor constraintEqualToAnchor:self.inputContainerView.leadingAnchor constant:16.0],
        [self.CageName.trailingAnchor constraintEqualToAnchor:self.inputContainerView.trailingAnchor constant:-16.0],
        [self.CageName.bottomAnchor constraintEqualToAnchor:self.inputContainerView.bottomAnchor constant:-4.0],
        [self.CageName.heightAnchor constraintEqualToConstant:56.0]
    ]];
}

- (void)setupParentCardView:(UIView *)cardView
                 titleLabel:(UILabel *)titleLabel
                 actionView:(UIButton *)actionView
                  ringLabel:(UILabel *)ringLabel
                  kindLabel:(UILabel *)kindLabel
                  imageView:(UIImageView *)imageView
{
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.layer.cornerRadius = Corners;
    cardView.layer.cornerCurve = kCACornerCurveContinuous;

    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    ringLabel.translatesAutoresizingMaskIntoConstraints = NO;
    kindLabel.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    actionView.translatesAutoresizingMaskIntoConstraints = NO;

    for (UIView *subview in [cardView.subviews copy]) {
        [subview removeFromSuperview];
    }

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[ringLabel, kindLabel]];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 4.0;
    textStack.alignment = UIStackViewAlignmentLeading;

    [cardView addSubview:titleLabel];
    [cardView addSubview:textStack];
    [cardView addSubview:imageView];
    [cardView addSubview:actionView];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:16.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cardView.trailingAnchor constant:-16.0],

        [imageView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16.0],
        [imageView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-16.0],
        [imageView.widthAnchor constraintEqualToConstant:82.0],
        [imageView.heightAnchor constraintEqualToConstant:82.0],
        [imageView.bottomAnchor constraintLessThanOrEqualToAnchor:cardView.bottomAnchor constant:-16.0],

        [textStack.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:16.0],
        [textStack.centerYAnchor constraintEqualToAnchor:imageView.centerYAnchor],
        [textStack.trailingAnchor constraintLessThanOrEqualToAnchor:imageView.leadingAnchor constant:-12.0],
        [textStack.bottomAnchor constraintLessThanOrEqualToAnchor:cardView.bottomAnchor constant:-16.0],

        [actionView.topAnchor constraintEqualToAnchor:cardView.topAnchor],
        [actionView.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor],
        [actionView.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor],
        [actionView.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor],
        [cardView.heightAnchor constraintGreaterThanOrEqualToConstant:156.0]
    ]];
}

- (void)setupFooterView
{
    self.bottomBarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.noteLablel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomBarView addSubview:self.noteLablel];

    [NSLayoutConstraint activateConstraints:@[
        [self.noteLablel.topAnchor constraintEqualToAnchor:self.bottomBarView.topAnchor constant:16.0],
        [self.noteLablel.leadingAnchor constraintEqualToAnchor:self.bottomBarView.leadingAnchor constant:16.0],
        [self.noteLablel.trailingAnchor constraintEqualToAnchor:self.bottomBarView.trailingAnchor constant:-16.0],
        [self.noteLablel.bottomAnchor constraintEqualToAnchor:self.bottomBarView.bottomAnchor constant:-16.0]
    ]];
}

- (void)setupConstraints
{
    NSLayoutConstraint *bottomConstraint;
    if (@available(iOS 15.0, *)) {
        bottomConstraint = [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor];
    } else {
        bottomConstraint = [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        bottomConstraint,

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.contentStackView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
        [self.contentStackView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.contentStackView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [self.contentStackView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24.0]
    ]];
}

- (void)configureUI
{
    self.headerView.backgroundColor = AppClearClr;

    self.headerTitleLabel.font = [self scaledBoldFont:18.0];
    self.headerTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.headerTitleLabel.textColor = AppPrimaryClrDarker;
    self.headerTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.headerTitleLabel.numberOfLines = 1;
    self.headerTitleLabel.minimumScaleFactor = 0.85;
    self.headerTitleLabel.adjustsFontSizeToFitWidth = YES;

    self.inputContainerView.backgroundColor = AppForgroundColr;
    self.inputContainerView.layer.cornerRadius = 20.0;
    self.inputContainerView.layer.cornerCurve = kCACornerCurveContinuous;
    if (@available(iOS 26.0, *)) {
        self.inputContainerView.layer.borderWidth = 1.0;
        [self.inputContainerView pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:0.30]];
    }

    self.CageName.delegate = self;
    self.CageName.font = [self scaledMidFont:17.0];
    self.CageName.adjustsFontForContentSizeCategory = YES;
    self.CageName.backgroundColor = AppClearClr;
    self.CageName.textColor = AppPrimaryClrDarker;
    self.CageName.textAlignment = NSTextAlignmentCenter;
     self.CageName.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.CageName.returnKeyType = UIReturnKeyDone;
    self.CageName.attributedPlaceholder =
    [[NSAttributedString alloc] initWithString:kLang(@"enterBoxName")
                                    attributes:@{
        NSForegroundColorAttributeName: [AppPrimaryClrDarker colorWithAlphaComponent:0.45],
        NSFontAttributeName: [self scaledMidFont:17.0]
    }];
    UIView *leadingPadding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    UIView *trailingPadding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.CageName.leftView = leadingPadding;
    self.CageName.leftViewMode = UITextFieldViewModeAlways;
    self.CageName.rightView = trailingPadding;
    self.CageName.rightViewMode = UITextFieldViewModeAlways;
    [self.CageName addTarget:self action:@selector(textFieldEditingDidBegin:) forControlEvents:UIControlEventEditingDidBegin];
    [self.CageName addTarget:self action:@selector(textFieldEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    [self.CageName addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];

    self.fatherCardTitleLabel.font = [self scaledBoldFont:16.0];
    self.fatherCardTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.fatherCardTitleLabel.textColor = AppPrimaryClrDarker;
    self.fatherCardTitleLabel.textAlignment = NSTextAlignmentNatural;

    self.motherCardTitleLabel.font = [self scaledBoldFont:16.0];
    self.motherCardTitleLabel.adjustsFontForContentSizeCategory = YES;
    self.motherCardTitleLabel.textColor = AppPrimaryClrDarker;
    self.motherCardTitleLabel.textAlignment = NSTextAlignmentNatural;

    NSArray<UILabel *> *detailLabels = @[self.fatherRingID, self.FatherKind, self.motherRingID, self.MotherKind];
    for (UILabel *label in detailLabels) {
        label.font = [self scaledMidFont:14.0];
        label.adjustsFontForContentSizeCategory = YES;
        label.textColor = [AppPrimaryClrDarker colorWithAlphaComponent:0.82];
        label.textAlignment = NSTextAlignmentNatural;
        label.numberOfLines = 2;
    }

    NSArray<UIView *> *cardViews = @[self.MotherView, self.tioView];
    for (UIView *cardView in cardViews) {
        cardView.backgroundColor = AppForgroundColr;
        cardView.layer.cornerRadius = Corners;
        cardView.layer.cornerCurve = kCACornerCurveContinuous;

        if (@available(iOS 26.0, *)) {
            // Liquid-style visible borders for glass UI
            cardView.layer.borderWidth = 0.85;
            [cardView pp_setBorderColor:[AppBackgroundClrDarker colorWithAlphaComponent:0.75]];
        }
    }

    NSArray<UIImageView *> *imageViews = @[self.MotherImageView, self.FatherImageView];
    for (UIImageView *imageView in imageViews) {
        imageView.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.95];
        imageView.layer.cornerRadius = 16.0;
        imageView.layer.cornerCurve = kCACornerCurveContinuous;
        imageView.layer.masksToBounds = YES;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.image = [UIImage imageNamed:@"placeholder"];
    }

    NSArray<UIButton *> *cardButtons = @[self.MotherBTN, self.FatherBTN];
    for (UIButton *button in cardButtons) {
        button.backgroundColor = AppClearClr;
        [button setTitle:nil forState:UIControlStateNormal];
        [button setImage:nil forState:UIControlStateNormal];
        [button addTarget:self action:@selector(interactiveButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside];
        [button addTarget:self action:@selector(interactiveButtonTouchUp:) forControlEvents:UIControlEventTouchCancel];
    }
    [self.MotherBTN addTarget:self action:@selector(motherRingIDTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.FatherBTN addTarget:self action:@selector(fatherRingIDTapped:) forControlEvents:UIControlEventTouchUpInside];

    self.bottomBarView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.78];
    self.bottomBarView.layer.cornerRadius = 18.0;
    self.bottomBarView.layer.cornerCurve = kCACornerCurveContinuous;
    if (@available(iOS 26.0, *)) {
        self.bottomBarView.layer.borderWidth = 1.0;
        [self.bottomBarView pp_setBorderColor:[AppBackgroundClrDarker colorWithAlphaComponent:0.80]];
    }

    self.noteLablel.font = [self scaledRegularFont:14.0];
    self.noteLablel.adjustsFontForContentSizeCategory = YES;
    self.noteLablel.textColor = [AppPrimaryClrDarker colorWithAlphaComponent:0.72];
    self.noteLablel.numberOfLines = 0;
    self.noteLablel.textAlignment = NSTextAlignmentCenter;

    self.saveBTN.accessibilityLabel = kLang(@"save");
    self.closeBTN.accessibilityLabel = kLang(@"cancel");
    self.CageName.accessibilityLabel = kLang(@"enterBoxName");
    self.MotherBTN.accessibilityLabel = kLang(@"mother_card_accessibility");
    self.FatherBTN.accessibilityLabel = kLang(@"father_card_accessibility");
}

- (void)bindData
{
    self.noteLablel.text = kLang(@"boxNote");
    self.headerTitleLabel.text = [self.FromAction isEqualToString:@"Edit"] ? kLang(@"editBox") : kLang(@"addBox");

    if ([self.FromAction isEqualToString:@"Edit"]) {
        FatherClass = [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.CageData.FatherRingID]] firstObject];
        MotherClass = [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.CageData.MotherRingID]] firstObject];

        if (FatherClass.cardSection != CardSectionArchive) {
            fatherSelected = 1;
            oldFatherID = FatherClass.ID;
        }

        if (MotherClass.cardSection != CardSectionArchive) {
            motherSelected = 1;
            oldMotherID = MotherClass.ID;
        }

        self.CageName.text = self.CageData.CageName;
    }

    [self refreshParentCardState];
}

- (void)refreshParentCardState
{
    self.fatherCardTitleLabel.text = kLang(@"father_title");
    self.motherCardTitleLabel.text = kLang(@"mother_title");

    if (FatherClass && fatherSelected == 1) {
        self.fatherRingID.text = PPSafeString(FatherClass.RingID);
        self.FatherKind.text = PPSafeString(FatherClass.CardTitle);

        NSArray<FileModel *> *files = FatherClass.FilesArray;
        NSString *imageURL = files.count ? files.firstObject.FileUrl : nil;
        [GM setImageFromUrlString:imageURL imageView:self.FatherImageView phImage:@"placeholder"];
    } else {
        self.fatherRingID.text = kLang(@"no_father");
        self.FatherKind.text = kLang(@"fatherRingIDPlace");
        self.FatherImageView.image = [UIImage imageNamed:@"placeholder"];
    }

    if (MotherClass && motherSelected == 1) {
        self.motherRingID.text = PPSafeString(MotherClass.RingID);
        self.MotherKind.text = PPSafeString(MotherClass.CardTitle);

        NSArray<FileModel *> *files = MotherClass.FilesArray;
        NSString *imageURL = files.count ? files.firstObject.FileUrl : nil;
        [GM setImageFromUrlString:imageURL imageView:self.MotherImageView phImage:@"placeholder"];
    } else {
        self.motherRingID.text = kLang(@"no_mother");
        self.MotherKind.text = kLang(@"motherRingIDPlace");
        self.MotherImageView.image = [UIImage imageNamed:@"placeholder"];
    }

    self.FatherBTN.accessibilityValue = self.fatherRingID.text;
    self.MotherBTN.accessibilityValue = self.motherRingID.text;
}

- (void)interactiveButtonTouchDown:(UIButton *)sender
{
    UIView *targetView = [self animatedTargetViewForButton:sender];
    [self animatePressState:YES forView:targetView];
}

- (void)interactiveButtonTouchUp:(UIButton *)sender
{
    UIView *targetView = [self animatedTargetViewForButton:sender];
    [self animatePressState:NO forView:targetView];
}

- (UIView *)animatedTargetViewForButton:(UIButton *)button
{
    if (button == self.FatherBTN) {
        return self.tioView;
    }

    if (button == self.MotherBTN) {
        return self.MotherView;
    }

    return button;
}

- (void)animatePressState:(BOOL)isPressed forView:(UIView *)view
{
    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                     animations:^{
        view.transform = isPressed ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
        view.alpha = isPressed ? 0.94 : 1.0;
    } completion:nil];
}

- (void)textFieldEditingDidBegin:(UITextField *)textField
{
    [UIView animateWithDuration:0.2 animations:^{
        self.inputContainerView.transform = CGAffineTransformMakeScale(1.01, 1.01);
        self.inputContainerView.layer.borderWidth = 1.0;
        [self.inputContainerView pp_setBorderColor:[AppPrimaryClr colorWithAlphaComponent:0.35]];
    }];

    CGRect textFieldRect = [self.inputContainerView convertRect:self.inputContainerView.bounds toView:self.scrollView];
    [self.scrollView scrollRectToVisible:CGRectInset(textFieldRect, 0, -24.0) animated:YES];
}

- (void)textFieldEditingDidEnd:(UITextField *)textField
{
    [UIView animateWithDuration:0.2 animations:^{
        self.inputContainerView.transform = CGAffineTransformIdentity;
        self.inputContainerView.layer.borderWidth = 0.0;
        [self.inputContainerView pp_setBorderColor:AppClearClr];
    }];
}

- (void)textFieldEditingChanged:(UITextField *)textField
{
    if (textField == self.CageName) {
        self.CageName.accessibilityValue = [self trimmedCageName];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)updateShadowPaths
{
    NSArray<UIView *> *shadowedViews = @[self.inputContainerView, self.MotherView, self.tioView, self.bottomBarView];
    for (UIView *view in shadowedViews) {
        [view pp_setShadowColor:[AppPrimaryClrDarker colorWithAlphaComponent:0.18]];
        view.layer.shadowOpacity = 0.16;
        view.layer.shadowRadius = 16.0;
        view.layer.shadowOffset = CGSizeMake(0, 8);
        view.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:view.layer.cornerRadius].CGPath;
    }
}

- (NSString *)trimmedCageName
{
    return [self.CageName.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)showMessage:(NSString *)message
{
    if (message.length == 0) {
        return;
    }

    self.snakBar = [[TTGSnackbar alloc] initWithMessage:message duration:1.4];
    [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromBottomBackToBottom];
    self.snakBar.messageTextAlign = NSTextAlignmentCenter;
    self.snakBar.cornerRadius = 20;
    [self.snakBar setIconTintColor:AppForgroundColr];
    [self.snakBar show];
}

- (BOOL)validateBeforeSaving
{
    NSString *cageName = [self trimmedCageName];
    if (cageName.length == 0) {
        [self showMessage:kLang(@"enterBoxName")];
        return NO;
    }

    if (!MotherClass || motherSelected == 0) {
        [self showMessage:kLang(@"selectMother")];
        return NO;
    }

    if (!FatherClass || fatherSelected == 0) {
        [self showMessage:kLang(@"selectFather")];
        return NO;
    }

    if (FatherClass.ID.length == 0 || MotherClass.ID.length == 0) {
        [self showMessage:kLang(@"alertSubtitleError")];
        return NO;
    }

    if ([FatherClass.ID isEqualToString:MotherClass.ID]) {
        [self showMessage:kLang(@"warningTitle")];
        return NO;
    }

    for (CageModel *cage in self.CagedataSource) {
        if (!cage.CageName.length) {
            continue;
        }

        if (self.CageData.ID.length && [cage.ID isEqualToString:self.CageData.ID]) {
            continue;
        }

        if ([cage.CageName caseInsensitiveCompare:cageName] == NSOrderedSame) {
            [self showMessage:kLang(@"boxExist")];
            return NO;
        }
    }

    return YES;
}

- (void)updateSavingState:(BOOL)isSaving
{
    self.isSaving = isSaving;
    self.saveBTN.enabled = !isSaving;
    self.closeBTN.enabled = !isSaving;
    self.CageName.enabled = !isSaving;
    self.FatherBTN.enabled = !isSaving;
    self.MotherBTN.enabled = !isSaving;
    self.saveBTN.alpha = isSaving ? 0.7 : 1.0;
    self.closeBTN.alpha = isSaving ? 0.7 : 1.0;
}
 
- (void)showPickBtnTapped {
    
}



-(IBAction)click:(UIButton*)button{
    if (self.isSaving) {
        return;
    }

    if (![self validateBeforeSaving]) {
        return;
    }

    [self updateSavingState:YES];
    [PPHUD showLoading];

    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd/mm/yyyy"];
    // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
    NSLocale *locale = [[NSLocale alloc]
                        initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];

    NSString *CageName = [self trimmedCageName];
    NSString *FatherRingID = FatherClass.ID;
    NSString *MotherRingID = MotherClass.ID;
    NSString *UserID = UserManager.sharedManager.currentUser.ID;
    if (UserID.length == 0) {
        [PPHUD dismiss];
        [self updateSavingState:NO];
        [PPAlertHelper showFailIn:self
                            title:kLang(@"warningTitle")
                         subtitle:kLang(@"alertSubtitleError")
                       completion:^{}];
        return;
    }
    
    [dateFormatter setDateFormat:@"ddmmssSSS"];
    NSString *CreateDate =[dateFormatter stringFromDate:[NSDate date]];
    NSString *cageID =[NSString stringWithFormat:@"%@_%@",UserID,CreateDate];
    
    if([_FromAction isEqualToString:@"Edit"])
    {
        cageID = self.CageData.ID;
    }
    
    
        NSDate *AddedDate = [NSDate date];
        NSMutableDictionary *Dic = [NSMutableDictionary new];
        [Dic setValue:cageID forKey:@"ID"];
        [Dic setValue:CageName forKey:@"CageName"];
        [Dic setValue:FatherRingID forKey:@"FatherRingID"];
        [Dic setValue:MotherRingID forKey:@"MotherRingID"];
      
        [Dic setValue:AddedDate forKey:@"CreateDate"];
        [Dic setValue:UserID forKey:@"UserID"];
        [Dic setValue:@0 forKey:@"isDeleted"];
    
        FIRFirestore *db = [FIRFirestore firestore];
        FIRCollectionReference *ref = [db collectionWithPath:@"CagesCol"];
        FIRWriteBatch *batch = [db batch];
        FIRDocumentReference *cageRef = [ref documentWithPath:cageID];
        [batch setData:Dic forDocument:cageRef merge:YES];

        NSDictionary *selectedParentUpdates = @{
            @"CardLocation": @"cage",
            @"archiveID": cageID,
            @"CageID": cageID,
            @"cardSection": @(CardSectionCage),
            @"masterArchiveID": @"no_value",
            @"isDeleted": @0,
            @"deleteReason": @""
        };

        FIRDocumentReference *FatherCardCol = [[[AppManager sharedInstance].dF collectionWithPath:@"CardsCol"] documentWithPath:FatherRingID];
        [batch updateData:selectedParentUpdates forDocument:FatherCardCol];

        FIRDocumentReference *MotherCardCol = [[[AppManager sharedInstance].dF collectionWithPath:@"CardsCol"] documentWithPath:MotherRingID];
        [batch updateData:selectedParentUpdates forDocument:MotherCardCol];

        NSDictionary *releasedParentUpdates = @{
            @"CardLocation": @"Cards",
            @"archiveID": @"",
            @"CageID": @"",
            @"cardSection": @(CardSectionCards),
            @"masterArchiveID": @"no_value",
            @"isDeleted": @0,
            @"deleteReason": @""
        };

        if ([self.FromAction isEqualToString:@"Edit"] &&
            oldFatherID.length > 0 &&
            ![oldFatherID isEqualToString:FatherRingID]) {
            FIRDocumentReference *oldFatherRef = [[[AppManager sharedInstance].dF collectionWithPath:@"CardsCol"] documentWithPath:oldFatherID];
            [batch updateData:releasedParentUpdates forDocument:oldFatherRef];
        }

        if ([self.FromAction isEqualToString:@"Edit"] &&
            oldMotherID.length > 0 &&
            ![oldMotherID isEqualToString:MotherRingID]) {
            FIRDocumentReference *oldMotherRef = [[[AppManager sharedInstance].dF collectionWithPath:@"CardsCol"] documentWithPath:oldMotherID];
            [batch updateData:releasedParentUpdates forDocument:oldMotherRef];
        }

        __weak typeof(self) weakSelf = self;
        [batch commitWithCompletion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }

                [PPHUD dismiss];
                [strongSelf updateSavingState:NO];

                if (error != nil) {
                    NSLog(@"FireDB ---->>> Error While Insert Cage %@", error);
                    [PPAlertHelper showFailIn:strongSelf
                                        title:kLang(@"warningTitle")
                                     subtitle:kLang(@"alertSubtitleError")
                                   completion:^{}];
                    return;
                }

                [[ArchivesManager shared]
                 removeArchiveDetailsByCardID:FatherRingID
                 completion:^(NSError * _Nullable error) {
                    NSLog(@"ARCHIVE ---->>> Father removed from archives %@", error ?: @"OK");
                }];

                [[ArchivesManager shared]
                 removeArchiveDetailsByCardID:MotherRingID
                 completion:^(NSError * _Nullable error) {
                    NSLog(@"ARCHIVE ---->>> Mother removed from archives %@", error ?: @"OK");
                }];

                NSLog(@"FireDB ---->>> ALL DATA INSERTED IN ID %@", cageID);
                [button setTitle:kLang(@"save") forState:UIControlStateNormal];
                [strongSelf presetDone];
            });
        }];
    
    
}

-(void)presetDone
{
    
    [PPAlertHelper showSuccessIn:self title:kLang(@"CageAddedSuccessTitle") subtitle:kLang(@"CageAddedSuccessSubtitle") OKAction:^(NSString * _Nullable text, BOOL didConfirm) {
        [self onDissmiss];
    }];
}
-(void)addedDone
{
    
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

-(void)setMotherId:(NSString *)motherID fromVC:(NSString *)fromVc
{
    
}
- (void)setParentClass:(CardModel *)ParentClass fromVC:(NSString *)fromVc
{
    __weak typeof(self) weakSelf = self;

    // 1️⃣ Check archive state first
    if ([self isCardArchived:ParentClass]) {

        NSString *title = kLang(@"card_in_archive_title");
        NSString *subtitle =
        [NSString stringWithFormat:kLang(@"card_in_archive_subtitle_fmt"),
         ParentClass.RingID ?: @""];

        [PPAlertHelper showConfirmationIn:self
                                    title:title
                                 subtitle:subtitle
                            confirmButton:kLang(@"move_to_box")
                             cancelButton:kLang(@"cancel")
                                     icon:nil
                             confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
        {
            if (!didConfirm) return;

            // User confirmed → continue selection
            [weakSelf applyParentCard:ParentClass fromVC:fromVc];

        } cancelBlock:^{
            // user cancelled → do nothing
        }];

        return; // ⛔️ STOP normal flow until confirmation
    }

    // 2️⃣ Not archived → apply directly
    [self applyParentCard:ParentClass fromVC:fromVc];
}


- (void)applyParentCard:(CardModel *)ParentClass fromVC:(NSString *)fromVc
{
    if ([fromVc isEqualToString:@"motherCage"]) {

        motherSelected = 1;
        MotherClass = ParentClass;

    } else {

        fatherSelected = 1;
        FatherClass = ParentClass;
    }

    [self refreshParentCardState];
}

- (IBAction)motherRingIDTapped:(id)sender {
    if (self.presentedViewController || self.isSaving) {
        return;
    }
    [self.view endEditing:YES];
    selectTableViewController *add = [selectTableViewController new];
    add.vcName = @"motherCage";
    add.delegate = self;
    [self presentViewController:add animated:YES completion:nil];
    NSLog(@"motherRingIDTapped");
}


- (IBAction)fatherRingIDTapped:(id)sender {
    if (self.presentedViewController || self.isSaving) {
        return;
    }

    [self.view endEditing:YES];
    selectTableViewController *add=[selectTableViewController new];
    add.vcName = @"fatherCage";
    add.delegate = self;
    [self presentViewController:add animated:YES completion:nil];
    NSLog(@"motherRingIDTapped");
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self configureSheetPresentationIfNeeded];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateShadowPaths];
}

- (IBAction)dismissBTN:(id)sender {
    if (self.isSaving) {
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (BOOL)isCardArchived:(CardModel *)card
{
    return (card.masterArchiveID.length > 0 &&
            ![card.masterArchiveID isEqualToString:@"no_value"]);
}


@end
