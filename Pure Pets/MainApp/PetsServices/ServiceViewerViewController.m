//
//  ServiceViewerViewController.m
//  Pure Pets
//

#import "ServiceViewerViewController.h"
#import "ServiceModel.h"
#import "GM.h"
#import "PetAdManager.h"
#import "PPAlertHelper.h"
#import "PPCommerceFeedbackManager.h"
#import "AppClasses.h"
#import "UserModel.h"

@interface ServiceViewerViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UIImageView *heroImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIView *descriptionCard;
@property (nonatomic, strong) UILabel *descriptionTitleLabel;
@property (nonatomic, strong) UILabel *descriptionBodyLabel;
@property (nonatomic, strong) UIView *detailsCard;
@property (nonatomic, strong) UIStackView *detailsStack;
@property (nonatomic, strong) UIStackView *actionStack;
@property (nonatomic, strong) UIButton *callButton;
@property (nonatomic, strong) UIButton *chatButton;
@property (nonatomic, strong) UIButton *locationButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *reportButton;
@property (nonatomic, strong) CAGradientLayer *heroOverlay;
@property (nonatomic, strong) UserModel *ownerModel;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@property (nonatomic, assign) BOOL isResolvingOwner;
@end

@implementation ServiceViewerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.view.layer.cornerRadius = 24.0;
    self.view.layer.masksToBounds = YES;
    self.modalInPresentation = NO;

    [self setupLayout];
    [self applyModelContent];
    [self loadOwnerIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [self trackServiceInteraction:PPItemInteractionTypeView];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.heroOverlay.frame = self.heroCard.bounds;
}

#pragma mark - Layout

- (void)setupLayout {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.alwaysBounceVertical = YES;

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.backgroundColor = UIColor.clearColor;

    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.contentView];

    UILayoutGuide *contentGuide;
    UILayoutGuide *frameGuide;
    if (@available(iOS 11.0, *)) {
        contentGuide = self.scrollView.contentLayoutGuide;
        frameGuide = self.scrollView.frameLayoutGuide;
    } else {
        contentGuide = self.scrollView;
        frameGuide = self.scrollView;
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:contentGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:contentGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:contentGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:contentGuide.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:frameGuide.widthAnchor],
    ]];

    [self buildHeroSection];
    [self buildDescriptionSection];
    [self buildDetailsSection];
    [self buildActionsSection];
}

- (void)buildHeroSection {
    self.heroCard = [[UIView alloc] init];
    self.heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroCard.backgroundColor = AppForgroundColr;
    self.heroCard.layer.cornerRadius = 22.0;
    self.heroCard.layer.masksToBounds = YES;

    self.heroImageView = [[UIImageView alloc] init];
    self.heroImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.heroImageView.clipsToBounds = YES;
    self.heroImageView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];

    self.heroOverlay = [CAGradientLayer layer];
    self.heroOverlay.colors = @[
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.05].CGColor,
        (__bridge id)[UIColor colorWithWhite:0 alpha:0.62].CGColor
    ];
    self.heroOverlay.startPoint = CGPointMake(0.5, 0.1);
    self.heroOverlay.endPoint = CGPointMake(0.5, 1.0);
    self.heroOverlay.cornerRadius = 22.0;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [GM boldFontWithSize:26];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.numberOfLines = 2;

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [GM MidFontWithSize:13];
    self.subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.88];
    self.subtitleLabel.numberOfLines = 2;

    self.priceLabel = [[UILabel alloc] init];
    self.priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.priceLabel.font = [GM boldFontWithSize:15];
    self.priceLabel.textColor = AppPrimaryTextClr;
    self.priceLabel.backgroundColor = AppForgroundColr;
    self.priceLabel.layer.cornerRadius = 12.0;
    self.priceLabel.layer.masksToBounds = YES;
    self.priceLabel.textAlignment = NSTextAlignmentCenter;

    self.closeButton = [self modernIconButtonWithSymbol:@"xmark" selector:@selector(closeTapped)];
    self.shareButton = [self modernIconButtonWithSymbol:@"square.and.arrow.up" selector:@selector(shareTapped)];

    [self.contentView addSubview:self.heroCard];
    [self.heroCard addSubview:self.heroImageView];
    [self.heroCard addSubview:self.titleLabel];
    [self.heroCard addSubview:self.subtitleLabel];
    [self.heroCard addSubview:self.priceLabel];
    [self.heroCard addSubview:self.closeButton];
    [self.heroCard addSubview:self.shareButton];

    // Only show report button when viewing another user's service
    BOOL isOwner = NO;
    NSString *currentUID = [self trackingUserID];
    if (currentUID.length > 0 && self.service.serviceOwnerID.length > 0 &&
        [currentUID isEqualToString:self.service.serviceOwnerID]) {
        isOwner = YES;
    }
    if (!isOwner) {
        self.reportButton = [self modernIconButtonWithSymbol:@"flag" selector:@selector(reportAdBTN)];
        [self.heroCard addSubview:self.reportButton];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.heroCard.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [self.heroCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.heroCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.heroCard.heightAnchor constraintEqualToConstant:276],

        [self.heroImageView.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor],
        [self.heroImageView.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor],
        [self.heroImageView.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor],
        [self.heroImageView.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor],

        [self.closeButton.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:12],
        [self.closeButton.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:12],
        [self.closeButton.widthAnchor constraintEqualToConstant:36],
        [self.closeButton.heightAnchor constraintEqualToConstant:36],

        [self.shareButton.topAnchor constraintEqualToAnchor:self.heroCard.topAnchor constant:12],
        [self.shareButton.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-12],
        [self.shareButton.widthAnchor constraintEqualToConstant:36],
        [self.shareButton.heightAnchor constraintEqualToConstant:36],

        [self.priceLabel.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-16],
        [self.priceLabel.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-16],
        [self.priceLabel.heightAnchor constraintEqualToConstant:34],
        [self.priceLabel.widthAnchor constraintGreaterThanOrEqualToConstant:96],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:16],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.priceLabel.leadingAnchor constant:-10],
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.subtitleLabel.topAnchor constant:-4],

        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.heroCard.leadingAnchor constant:16],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-16],
        [self.subtitleLabel.bottomAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:-16],
    ]];
    if (self.reportButton) {
        [NSLayoutConstraint activateConstraints:@[
            [self.reportButton.topAnchor constraintEqualToAnchor:self.shareButton.bottomAnchor constant:8],
            [self.reportButton.trailingAnchor constraintEqualToAnchor:self.heroCard.trailingAnchor constant:-12],
            [self.reportButton.widthAnchor constraintEqualToConstant:36],
            [self.reportButton.heightAnchor constraintEqualToConstant:36],
        ]];
    }

    [self.heroCard.layer insertSublayer:self.heroOverlay above:self.heroImageView.layer];
}

- (void)buildDescriptionSection {
    self.descriptionCard = [self cardView];
    self.descriptionTitleLabel = [[UILabel alloc] init];
    self.descriptionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionTitleLabel.font = [GM boldFontWithSize:18];
    self.descriptionTitleLabel.textColor = AppPrimaryTextClr;
    self.descriptionTitleLabel.text = kLang(@"service_view_description_title");

    self.descriptionBodyLabel = [[UILabel alloc] init];
    self.descriptionBodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionBodyLabel.font = [GM MidFontWithSize:15];
    self.descriptionBodyLabel.numberOfLines = 0;
    self.descriptionBodyLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.84];

    [self.contentView addSubview:self.descriptionCard];
    [self.descriptionCard addSubview:self.descriptionTitleLabel];
    [self.descriptionCard addSubview:self.descriptionBodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.descriptionCard.topAnchor constraintEqualToAnchor:self.heroCard.bottomAnchor constant:14],
        [self.descriptionCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.descriptionCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.descriptionTitleLabel.topAnchor constraintEqualToAnchor:self.descriptionCard.topAnchor constant:16],
        [self.descriptionTitleLabel.leadingAnchor constraintEqualToAnchor:self.descriptionCard.leadingAnchor constant:16],
        [self.descriptionTitleLabel.trailingAnchor constraintEqualToAnchor:self.descriptionCard.trailingAnchor constant:-16],

        [self.descriptionBodyLabel.topAnchor constraintEqualToAnchor:self.descriptionTitleLabel.bottomAnchor constant:8],
        [self.descriptionBodyLabel.leadingAnchor constraintEqualToAnchor:self.descriptionCard.leadingAnchor constant:16],
        [self.descriptionBodyLabel.trailingAnchor constraintEqualToAnchor:self.descriptionCard.trailingAnchor constant:-16],
        [self.descriptionBodyLabel.bottomAnchor constraintEqualToAnchor:self.descriptionCard.bottomAnchor constant:-16],
    ]];
}

- (void)buildDetailsSection {
    self.detailsCard = [self cardView];
    [self.contentView addSubview:self.detailsCard];

    UILabel *detailsTitle = [[UILabel alloc] init];
    detailsTitle.translatesAutoresizingMaskIntoConstraints = NO;
    detailsTitle.font = [GM boldFontWithSize:18];
    detailsTitle.textColor = AppPrimaryTextClr;
    detailsTitle.text = kLang(@"service_view_details_title");
    [self.detailsCard addSubview:detailsTitle];

    self.detailsStack = [[UIStackView alloc] init];
    self.detailsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailsStack.axis = UILayoutConstraintAxisVertical;
    self.detailsStack.spacing = 10;
    [self.detailsCard addSubview:self.detailsStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.detailsCard.topAnchor constraintEqualToAnchor:self.descriptionCard.bottomAnchor constant:12],
        [self.detailsCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.detailsCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [detailsTitle.topAnchor constraintEqualToAnchor:self.detailsCard.topAnchor constant:16],
        [detailsTitle.leadingAnchor constraintEqualToAnchor:self.detailsCard.leadingAnchor constant:16],
        [detailsTitle.trailingAnchor constraintEqualToAnchor:self.detailsCard.trailingAnchor constant:-16],

        [self.detailsStack.topAnchor constraintEqualToAnchor:detailsTitle.bottomAnchor constant:10],
        [self.detailsStack.leadingAnchor constraintEqualToAnchor:self.detailsCard.leadingAnchor constant:16],
        [self.detailsStack.trailingAnchor constraintEqualToAnchor:self.detailsCard.trailingAnchor constant:-16],
        [self.detailsStack.bottomAnchor constraintEqualToAnchor:self.detailsCard.bottomAnchor constant:-16],
    ]];
}

- (void)buildActionsSection {
    self.actionStack = [[UIStackView alloc] init];
    self.actionStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionStack.axis = UILayoutConstraintAxisHorizontal;
    self.actionStack.distribution = UIStackViewDistributionFillEqually;
    self.actionStack.spacing = 10;

    self.callButton = [self actionButtonWithSymbol:@"phone.fill"
                                              title:kLang(@"Call")
                                           selector:@selector(callTapped)];
    self.chatButton = [self actionButtonWithSymbol:@"message.fill"
                                              title:kLang(@"cart_support_chat")
                                           selector:@selector(chatTapped)];
    self.locationButton = [self actionButtonWithSymbol:@"location.fill"
                                                  title:kLang(@"location")
                                               selector:@selector(locationTapped)];

    [self.actionStack addArrangedSubview:self.callButton];
    [self.actionStack addArrangedSubview:self.chatButton];
    [self.actionStack addArrangedSubview:self.locationButton];

    [self.contentView addSubview:self.actionStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.actionStack.topAnchor constraintEqualToAnchor:self.detailsCard.bottomAnchor constant:14],
        [self.actionStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.actionStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.actionStack.heightAnchor constraintEqualToConstant:52],
        [self.actionStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-24],
    ]];
}

#pragma mark - Configure

- (void)applyModelContent {
    NSString *title = self.service.title.length > 0 ? self.service.title : kLang(@"service_view_default_title");
    self.titleLabel.text = title;

    NSString *category = self.service.category.length > 0 ? self.service.category : kLang(@"Not specified");
    NSString *dateText = self.service.availableDate ? [GM formattedDate:self.service.availableDate] : kLang(@"Not specified");
    self.subtitleLabel.text = [NSString stringWithFormat:@"%@ • %@", category, dateText];

    self.descriptionBodyLabel.text = self.service.desc.length > 0 ? self.service.desc : kLang(@"service_view_no_description");

    NSString *formattedPrice = [GM formatPrice:@(self.service.price) currencyCode:kLang(@"Rials")];
    self.priceLabel.text = formattedPrice.length > 0 ? [NSString stringWithFormat:@"  %@  ", formattedPrice] : [NSString stringWithFormat:@"  %.2f  ", self.service.price];

    [GM setImageFromUrlString:self.service.imageURL imageView:self.heroImageView phImage:@"placeholder"];

    [self reloadDetailsRows];
}

- (void)reloadDetailsRows {
    for (UIView *subview in self.detailsStack.arrangedSubviews) {
        [self.detailsStack removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }

    NSString *category = self.service.category.length > 0 ? self.service.category : kLang(@"Not specified");
    NSString *available = self.service.availableDate ? [GM formattedDate:self.service.availableDate] : kLang(@"Not specified");
    NSString *ownerName = [self.ownerModel PPBestDisplayName];
    NSString *owner = ownerName.length > 0 ? ownerName : kLang(@"service_view_owner_pending");

    [self.detailsStack addArrangedSubview:[self detailRowWithKey:kLang(@"service_view_category") value:category]];
    [self.detailsStack addArrangedSubview:[self detailRowWithKey:kLang(@"service_view_available_date") value:available]];
    [self.detailsStack addArrangedSubview:[self detailRowWithKey:kLang(@"service_view_owner") value:owner]];
}

- (UIView *)detailRowWithKey:(NSString *)key value:(NSString *)value {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *k = [[UILabel alloc] init];
    k.translatesAutoresizingMaskIntoConstraints = NO;
    k.font = [GM MidFontWithSize:14];
    k.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.68];
    k.text = key;

    UILabel *v = [[UILabel alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.font = [GM MidFontWithSize:15];
    v.textColor = AppPrimaryTextClr;
    v.textAlignment = Language.isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;
    v.text = value;

    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [AppPrimaryTextClr colorWithAlphaComponent:0.08];

    [row addSubview:k];
    [row addSubview:v];
    [row addSubview:separator];

    [NSLayoutConstraint activateConstraints:@[
        [k.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [k.topAnchor constraintEqualToAnchor:row.topAnchor],
        [k.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-8],

        [v.leadingAnchor constraintGreaterThanOrEqualToAnchor:k.trailingAnchor constant:12],
        [v.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [v.centerYAnchor constraintEqualToAnchor:k.centerYAnchor],

        [separator.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:28],
    ]];

    return row;
}

#pragma mark - Actions

- (void)closeTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    if (self.presentingViewController ||
        (self.navigationController.presentingViewController && self.navigationController.viewControllers.firstObject == self)) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)shareTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];

    NSString *title = self.service.title.length > 0 ? self.service.title : kLang(@"service_view_default_title");
    NSString *price = [GM formatPrice:@(self.service.price) currencyCode:kLang(@"Rials")];
    NSString *desc = self.service.desc.length > 0 ? self.service.desc : @"";

    NSString *message = [NSString stringWithFormat:@"%@: %@\n%@: %@\n%@",
                         kLang(@"service_view_share_title"),
                         title,
                         kLang(@"Price"),
                         price.length > 0 ? price : [NSString stringWithFormat:@"%.2f", self.service.price],
                         desc];

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[message] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                         CGRectGetMidY(self.view.bounds),
                                                                         0, 0);
        activityVC.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
    [self trackServiceInteraction:PPItemInteractionTypeShare];
}

- (void)callTapped {
    if (![self ensureSignedInForContactAction]) {
        return;
    }
    [self loadOwnerIfNeeded];

    if (self.ownerModel.MobileNo.length == 0) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"No Number")
                         subtitle:kLang(@"This user has no phone number")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [AppClasses callPhoneNumber:self.ownerModel.MobileNo fromViewController:self];
    [self trackServiceInteraction:PPItemInteractionTypeCall];
}

- (void)chatTapped {
    if (![self ensureSignedInForContactAction]) {
        return;
    }
    [self loadOwnerIfNeeded];

    if (!self.ownerModel) {
        [PPAlertHelper showInfoIn:self
                            title:kLang(@"error")
                         subtitle:kLang(@"service_view_contact_loading")];
        [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
        return;
    }

    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [GM chatWith:self.ownerModel FromController:self];
    [self trackServiceInteraction:PPItemInteractionTypeChat];
}

- (void)locationTapped {
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentAction];
    [PPAlertHelper showInfoIn:self
                        title:kLang(@"location")
                     subtitle:kLang(@"service_view_location_unavailable")];
}

#pragma mark - Owner

- (void)loadOwnerIfNeeded {
    if (self.ownerModel || self.isResolvingOwner || self.service.serviceOwnerID.length == 0) {
        return;
    }

    self.isResolvingOwner = YES;
    __weak typeof(self) weakSelf = self;
    [UsrMgr getOtherUserModelFromFirestoreWithUID:self.service.serviceOwnerID completion:^(UserModel * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.isResolvingOwner = NO;
        if (error || !user) {
            return;
        }
        strongSelf.ownerModel = user;
        [strongSelf reloadDetailsRows];
    }];
}

- (BOOL)ensureSignedInForContactAction {
    if (UserManager.sharedManager.isUserLoggedIn) {
        return YES;
    }
    [[PPCommerceFeedbackManager shared] playEvent:PPCommerceFeedbackEventPaymentFailure];
    [UserManager showPromptOnTopController];
    return NO;
}

#pragma mark - Tracking

- (NSString *)trackingUserID {
    NSString *userID = [UserManager sharedManager].currentUser.ID;
    if (userID.length > 0) {
        return userID;
    }
    if (PPCurrentFIRAuthUser.uid.length > 0) {
        return PPCurrentFIRAuthUser.uid;
    }
    return nil;
}

- (void)trackServiceInteraction:(PPItemInteractionType)interaction {
    if (self.service.serviceID.length == 0) {
        return;
    }
    [PetAdManager trackInteraction:interaction
                         forItemID:self.service.serviceID
                        collection:@"serviceOffers"
                            userID:[self trackingUserID]
                        completion:nil];
}

#pragma mark - UI Helpers

- (UIView *)cardView {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = AppForgroundColr;
    card.layer.cornerRadius = 20.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [AppPrimaryTextClr colorWithAlphaComponent:0.06].CGColor;
    card.layer.shadowColor = AppShadowClr.CGColor;
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowOffset = CGSizeMake(0, 4);
    card.layer.shadowRadius = 12;
    return card;
}

- (UIButton *)modernIconButtonWithSymbol:(NSString *)symbol selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    UIImage *icon = [[UIImage systemImageNamed:symbol] imageByApplyingSymbolConfiguration:cfg];
    [button setImage:icon forState:UIControlStateNormal];

    button.tintColor = AppPrimaryTextClr;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.92];
    button.layer.cornerRadius = 18;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [AppPrimaryTextClr colorWithAlphaComponent:0.08].CGColor;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)actionButtonWithSymbol:(NSString *)symbol title:(NSString *)title selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.layer.cornerRadius = 16.0;
    button.layer.masksToBounds = YES;
    button.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.9];
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [AppPrimaryTextClr colorWithAlphaComponent:0.08].CGColor;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    UIImage *image = [[UIImage systemImageNamed:symbol] imageByApplyingSymbolConfiguration:cfg];
    [button setImage:image forState:UIControlStateNormal];
    [button setTitle:[NSString stringWithFormat:@"  %@", title] forState:UIControlStateNormal];
    [button setTitleColor:AppPrimaryTextClr forState:UIControlStateNormal];
    button.tintColor = AppPrimaryClr;
    button.titleLabel.font = [GM MidFontWithSize:14];
    button.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;

    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)reportAdBTN {
    if (![UserManager sharedManager].isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    NSString *currentUID = [self trackingUserID];
    if (currentUID.length > 0 && self.service.serviceOwnerID.length > 0 &&
        [currentUID isEqualToString:self.service.serviceOwnerID]) {
        return;
    }

    UIAlertController *sheet = [UIAlertController
        alertControllerWithTitle:kLang(@"report_alert_title")
        message:kLang(@"report_alert_message")
        preferredStyle:UIAlertControllerStyleActionSheet];

    NSDictionary *reasons = @{
        @"spam": kLang(@"report_reason_spam"),
        @"inappropriate_content": kLang(@"report_reason_inappropriate"),
        @"scam_fraud": kLang(@"report_reason_fraud"),
        @"wrong_category": kLang(@"report_reason_wrong_category"),
        @"other": kLang(@"report_reason_other")
    };

    for (NSString *code in @[@"inappropriate_content", @"scam_fraud", @"wrong_category", @"spam", @"other"]) {
        [sheet addAction:[UIAlertAction actionWithTitle:reasons[code]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {
                [self submitServiceReportWithReasonCode:code];
            }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
        style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.reportButton;
        sheet.popoverPresentationController.sourceRect = self.reportButton.bounds;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)submitServiceReportWithReasonCode:(NSString *)reasonCode {
    NSString *uid = [self trackingUserID];
    if (uid.length == 0 || self.service.serviceID.length == 0) return;

    FIRFirestore *db = [FIRFirestore firestore];

    // 1. Flag on the content document (array-union for multi-reporter support)
    FIRDocumentReference *contentRef = [[db collectionWithPath:@"serviceOffers"]
                                        documentWithPath:self.service.serviceID];

    [contentRef updateData:@{
        @"reportedBy"    : [FIRFieldValue fieldValueForArrayUnion:@[uid]],
        @"reportCount"   : [FIRFieldValue fieldValueForIntegerIncrement:1],
        @"lastReportedAt": [FIRFieldValue fieldValueForServerTimestamp]
    } completion:nil];

    // 2. Write a dedicated report document for audit trail
    NSString *reportID = [NSString stringWithFormat:@"%@_%@", self.service.serviceID, uid];
    FIRDocumentReference *reportRef = [[db collectionWithPath:@"reports"] documentWithPath:reportID];

    NSDictionary *reportData = @{
        @"reportId"         : reportID,
        @"contentId"        : self.service.serviceID,
        @"contentType"      : @"serviceOffer",
        @"collection"       : @"serviceOffers",
        @"reason"           : reasonCode,
        @"reporterUid"      : uid,
        @"reportedOwnerUid" : self.service.serviceOwnerID ?: @"",
        @"status"           : @"pending",
        @"platform"         : @"ios",
        @"createdAt"        : [FIRFieldValue fieldValueForServerTimestamp],
        @"updatedAt"        : [FIRFieldValue fieldValueForServerTimestamp]
    };

    [reportRef setData:reportData merge:YES completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [PPAlertHelper showInfoIn:self title:kLang(@"error") subtitle:kLang(@"report_submit_failed_message")];
            } else {
                [PPAlertHelper showSuccessIn:self title:kLang(@"report_submit_title") subtitle:kLang(@"report_submit_message")];
            }
        });
    }];
}

@end
