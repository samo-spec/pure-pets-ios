//
//  PPNovaChatViewController.m
//  Pure Pets
//

#import "PPNovaChatViewController.h"
#import "ChatMessageModel.h"
#import "PPAgentClient.h"
#import "PPAgentMessage.h"
#import "PPNovaMessageBubbleCell.h" // #import "PPNovaMessageBubbleCell.h" #import "ChatMessageCell.h"
#import "PPNovaProductMessageCell.h"
#import "PPNovaReviewMessageCell.h"
#import "PPNovaFloatingInputBarView.h"
#import "AppManager.h"
#import "PPNavigationController.h"
#import "PetAccessoryManager.h"
#import "CartManager.h"
#import "PPNovaLocalChatMemory.h"
#import "CartItem.h"
#import "PPHUD.h"
#import "AccessViewerVC.h"
#import "ViewerVC.h"
#import "ServiceViewerViewController.h"
#import "PPPetCareViewerVC.h"
#import "PetAdManager.h"
#import "AdoptPetManager.h"
#import "AdoptPetModel.h"
#import "AdoptPetDetailsViewController.h"
#import "PPPetCareVetViewrVC.h"
#import "PPOverlayCoordinator.h"
#import "PPChatFeedbackManager.h"
#import "PPAnalytics.h"
#import "PPUserSigningManager.h"
#import "ServicesManager.h"
#import "VetManager.h"
#import <IQKeyboardManager/IQKeyboardManager.h>
#import <QuartzCore/QuartzCore.h>

static UIColor *PPNovaDynamicColor(UIColor *lightColor, UIColor *darkColor) {
    if (@available(iOS 13.0, *)) {
        return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
        }];
    }
    return lightColor;
}

static const CGFloat PPNovaExpandedTableTopInset = 228.0;
static const CGFloat PPNovaCollapsedTableTopInset = 124.0;
static const CGFloat PPNovaTableBottomInset = 22.0;
static NSString * const PPNovaCallableRegion = @"us-central1";
static NSString * const PPNovaCallableName = @"geminiProxy";
static NSString * const PPNovaFirebaseProjectID = @"pure-pets-49199";
static NSString * const PPNovaHistoryEntryCellReuseIdentifier = @"PPNovaHistoryEntryCell";
static NSString * const PPNovaSmartSuggestionWashBreathKey = @"pp.nova.smartSuggestion.washBreath";
static NSString * const PPNovaSmartSuggestionActionBreathKey = @"pp.nova.smartSuggestion.actionBreath";
static NSString * const PPNovaSmartSuggestionColorShiftKey = @"pp.nova.smartSuggestion.colorShift";
static const NSUInteger PPNovaSmartSuggestionPickerVisibleCount = 8;

#pragma mark - Nova Output Presentation

typedef NS_ENUM(NSInteger, PPNovaOutputType) {
    PPNovaOutputTypeText = 0,
    PPNovaOutputTypeProductCards,
    PPNovaOutputTypeAdsCards,
    PPNovaOutputTypeAdoptCards,
    PPNovaOutputTypeVetCards,
    PPNovaOutputTypeServiceCards,
    PPNovaOutputTypeSystemFallback
};

typedef NS_ENUM(NSInteger, PPNovaPresentationAlignment) {
    PPNovaPresentationAlignmentAssistant = 0,
    PPNovaPresentationAlignmentUser,
    PPNovaPresentationAlignmentCentered
};

static NSString *PPNovaOutputTypeName(PPNovaOutputType type) {
    switch (type) {
        case PPNovaOutputTypeText: return @"text";
        case PPNovaOutputTypeProductCards: return @"productCards";
        case PPNovaOutputTypeAdsCards: return @"adsCards";
        case PPNovaOutputTypeAdoptCards: return @"adoptCards";
        case PPNovaOutputTypeVetCards: return @"vetCards";
        case PPNovaOutputTypeServiceCards: return @"serviceCards";
        case PPNovaOutputTypeSystemFallback: return @"systemFallback";
    }
    return @"text";
}

static NSString *PPNovaPresentationAlignmentName(PPNovaPresentationAlignment alignment) {
    switch (alignment) {
        case PPNovaPresentationAlignmentAssistant: return @"assistant";
        case PPNovaPresentationAlignmentUser: return @"user";
        case PPNovaPresentationAlignmentCentered: return @"centered";
    }
    return @"assistant";
}

static BOOL PPNovaOutputTypeRendersCards(PPNovaOutputType type) {
    return type == PPNovaOutputTypeProductCards ||
           type == PPNovaOutputTypeAdsCards ||
           type == PPNovaOutputTypeAdoptCards ||
           type == PPNovaOutputTypeVetCards ||
           type == PPNovaOutputTypeServiceCards;
}

@interface PPNovaOutputStyle : NSObject

@property (nonatomic, assign) PPNovaOutputType outputType;
@property (nonatomic, assign) CGFloat visualWeight;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat spacing;
@property (nonatomic, assign) CGFloat maxWidth;
@property (nonatomic, assign) PPNovaPresentationAlignment alignment;
@property (nonatomic, assign) BOOL shouldRenderCards;
@property (nonatomic, assign) BOOL shouldRenderAssistantText;
@property (nonatomic, copy) NSString *stableReuseIdentifier;
@property (nonatomic, copy) NSString *renderStyle;

@end

@implementation PPNovaOutputStyle
@end

@interface PPNovaMessagePresentation : NSObject

@property (nonatomic, copy) NSString *messageID;
@property (nonatomic, copy) NSString *requestID;
@property (nonatomic, copy) NSString *responseID;
@property (nonatomic, copy) NSString *renderKey;
@property (nonatomic, assign) NSInteger rowIndex;
@property (nonatomic, strong) PPNovaOutputStyle *style;

@end

@implementation PPNovaMessagePresentation
@end

#pragma mark - Nova History Sheet

@interface PPNovaHistoryEntryCell : UITableViewCell

- (void)configureWithMessage:(NSDictionary *)message;

@end

@interface PPNovaHistoryEntryCell ()

@property (nonatomic, strong) UIVisualEffectView *cardView;
@property (nonatomic, strong) UIView *roleDotView;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *messageLabel;

@end

@implementation PPNovaHistoryEntryCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self pp_setupHistoryCell];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.contentView.alpha = 1.0;
    self.contentView.transform = CGAffineTransformIdentity;
    self.messageLabel.text = nil;
    self.roleLabel.text = nil;
    self.timeLabel.text = nil;
}

- (void)pp_setupHistoryCell {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemThinMaterial;
    }

    UIVisualEffectView *cardView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    cardView.translatesAutoresizingMaskIntoConstraints = NO;
    cardView.clipsToBounds = YES;
    cardView.layer.cornerRadius = 18.0;
    cardView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    cardView.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.12].CGColor;
    if (@available(iOS 13.0, *)) {
        cardView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.contentView addSubview:cardView];
    self.cardView = cardView;

    UIView *content = cardView.contentView;
    content.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    UIView *roleDot = [[UIView alloc] init];
    roleDot.translatesAutoresizingMaskIntoConstraints = NO;
    roleDot.layer.cornerRadius = 4.0;
    roleDot.layer.shadowOpacity = 0.18;
    roleDot.layer.shadowRadius = 5.0;
    roleDot.layer.shadowOffset = CGSizeZero;
    [content addSubview:roleDot];
    self.roleDotView = roleDot;

    UILabel *roleLabel = [[UILabel alloc] init];
    roleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    roleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    roleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    roleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [content addSubview:roleLabel];
    self.roleLabel = roleLabel;

    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    timeLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.64];
    timeLabel.textAlignment = Language.isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;
    [content addSubview:timeLabel];
    self.timeLabel = timeLabel;

    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    messageLabel.font = [GM fontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    messageLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.90];
    messageLabel.numberOfLines = 0;
    messageLabel.textAlignment = Language.alignmentForCurrentLanguage;
    messageLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [content addSubview:messageLabel];
    self.messageLabel = messageLabel;

    [NSLayoutConstraint activateConstraints:@[
        [cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:18.0],
        [cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-18.0],
        [cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

        [roleDot.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16.0],
        [roleDot.topAnchor constraintEqualToAnchor:content.topAnchor constant:17.0],
        [roleDot.widthAnchor constraintEqualToConstant:8.0],
        [roleDot.heightAnchor constraintEqualToConstant:8.0],

        [roleLabel.leadingAnchor constraintEqualToAnchor:roleDot.trailingAnchor constant:8.0],
        [roleLabel.centerYAnchor constraintEqualToAnchor:roleDot.centerYAnchor],
        [roleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:timeLabel.leadingAnchor constant:-10.0],

        [timeLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16.0],
        [timeLabel.centerYAnchor constraintEqualToAnchor:roleLabel.centerYAnchor],

        [messageLabel.topAnchor constraintEqualToAnchor:roleLabel.bottomAnchor constant:9.0],
        [messageLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16.0],
        [messageLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16.0],
        [messageLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16.0]
    ]];
}

- (void)configureWithMessage:(NSDictionary *)message {
    NSString *role = [message[@"role"] isKindOfClass:NSString.class] ? message[@"role"] : @"";
    BOOL isUser = [role isEqualToString:@"user"];

    UIColor *novaAccent = nil;
    if (@available(iOS 13.0, *)) {
        novaAccent = UIColor.systemIndigoColor;
    } else {
        novaAccent = [UIColor colorWithRed:0.36 green:0.40 blue:0.84 alpha:1.0];
    }
    UIColor *accent = isUser ? (AppPrimaryClr ?: [UIColor colorWithRed:0.96 green:0.55 blue:0.20 alpha:1.0]) : novaAccent;

    self.roleDotView.backgroundColor = accent;
    self.roleDotView.layer.shadowColor = accent.CGColor;
    self.roleLabel.text = isUser ? kLang(@"nova_history_role_user") : kLang(@"nova_history_role_nova");
    self.roleLabel.textColor = accent;

    NSString *text = [message[@"text"] isKindOfClass:NSString.class] ? message[@"text"] : @"";
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.messageLabel.text = trimmed.length > 0 ? trimmed : kLang(@"nova_history_empty_message");

    NSNumber *timestamp = [message[@"timestamp"] isKindOfClass:NSNumber.class] ? message[@"timestamp"] : nil;
    self.timeLabel.text = [self pp_timeTextForTimestamp:timestamp];
}

- (NSString *)pp_timeTextForTimestamp:(NSNumber *)timestamp {
    if (!timestamp) {
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp.doubleValue];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = NSLocale.currentLocale;
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = [[NSCalendar currentCalendar] isDateInToday:date] ? NSDateFormatterNoStyle : NSDateFormatterShortStyle;
    return [formatter stringFromDate:date] ?: @"";
}

@end

@interface PPNovaHistorySheetViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

- (instancetype)initWithMessages:(NSArray<NSDictionary *> *)messages;

@end

@interface PPNovaHistorySheetViewController ()

@property (nonatomic, copy) NSArray<NSDictionary *> *historyMessages;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, assign) BOOL didRunEntranceAnimation;

@end

@implementation PPNovaHistorySheetViewController

- (instancetype)initWithMessages:(NSArray<NSDictionary *> *)messages {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        NSArray<NSDictionary *> *source = [messages isKindOfClass:NSArray.class] ? messages : @[];
        if (source.count > 80) {
            source = [source subarrayWithRange:NSMakeRange(source.count - 80, 80)];
        }
        self.historyMessages = [[[source reverseObjectEnumerator] allObjects] copy];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.whiteColor;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self pp_setupSheetLayout];

    self.modalInPresentation = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self pp_runEntranceAnimationIfNeeded];
}

- (void)pp_setupSheetLayout {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = UIColor.clearColor;
    header.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:header];
    self.headerView = header;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr ?: UIColor.blackColor;
    titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    titleLabel.text = kLang(@"nova_chat_history");
    [header addSubview:titleLabel];
    self.titleLabel = titleLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.78];
    subtitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    subtitleLabel.text = self.historyMessages.count > 0
        ? [NSString stringWithFormat:kLang(@"nova_chat_history_subtitle_format"), (long)self.historyMessages.count]
        : kLang(@"nova_no_history");
    [header addSubview:subtitleLabel];
    self.subtitleLabel = subtitleLabel;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.tintColor = [AppPrimaryTextClr colorWithAlphaComponent:0.68];
    closeButton.layer.cornerRadius = 18.0;
    closeButton.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    closeButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.20].CGColor;
    closeButton.backgroundColor = [AppPrimaryTextClr colorWithAlphaComponent:0.05];
    if (@available(iOS 13.0, *)) {
        closeButton.layer.cornerCurve = kCACornerCurveContinuous;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                          weight:UIImageSymbolWeightSemibold];
        [closeButton setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:cfg] forState:UIControlStateNormal];
    } else {
        [closeButton setTitle:kLang(@"Cancel") forState:UIControlStateNormal];
    }
    closeButton.accessibilityLabel = kLang(@"Cancel");
    [closeButton addTarget:self action:@selector(pp_closeHistorySheet) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeButton];

    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    clearButton.tintColor = [UIColor.systemRedColor colorWithAlphaComponent:0.82];
    clearButton.titleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    clearButton.layer.cornerRadius = 18.0;
    clearButton.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    clearButton.layer.borderColor = [UIColor.systemRedColor colorWithAlphaComponent:0.18].CGColor;
    clearButton.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.06];
    clearButton.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    if (@available(iOS 13.0, *)) {
        clearButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [clearButton setTitle:kLang(@"nova_history_clear_button") forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(pp_handleClearHistoryTapped) forControlEvents:UIControlEventTouchUpInside];
    clearButton.hidden = self.historyMessages.count == 0;
    [header addSubview:clearButton];
    self.clearButton = clearButton;

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.backgroundColor = UIColor.clearColor;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 112.0;
    tableView.showsVerticalScrollIndicator = NO;
    tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 24.0, 0.0);
    tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    tableView.delegate = self;
    tableView.dataSource = self;
    [tableView registerClass:PPNovaHistoryEntryCell.class forCellReuseIdentifier:PPNovaHistoryEntryCellReuseIdentifier];
    [self.view addSubview:tableView];
    self.tableView = tableView;

    UIView *emptyView = [[UIView alloc] init];
    emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyView.hidden = self.historyMessages.count > 0;
    emptyView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:emptyView];
    self.emptyStateView = emptyView;

    UILabel *emptyTitle = [[UILabel alloc] init];
    emptyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    emptyTitle.font = [GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    emptyTitle.textColor = AppPrimaryTextClr ?: UIColor.blackColor;
    emptyTitle.textAlignment = NSTextAlignmentCenter;
    emptyTitle.text = kLang(@"nova_history_empty_title");
    [emptyView addSubview:emptyTitle];

    UILabel *emptyCopy = [[UILabel alloc] init];
    emptyCopy.translatesAutoresizingMaskIntoConstraints = NO;
    emptyCopy.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    emptyCopy.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.78];
    emptyCopy.textAlignment = NSTextAlignmentCenter;
    emptyCopy.numberOfLines = 0;
    emptyCopy.text = kLang(@"nova_history_empty_subtitle");
    [emptyView addSubview:emptyCopy];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18.0],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [closeButton.topAnchor constraintEqualToAnchor:header.topAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18.0],
        [closeButton.widthAnchor constraintEqualToConstant:36.0],
        [closeButton.heightAnchor constraintEqualToConstant:36.0],

        [titleLabel.topAnchor constraintEqualToAnchor:header.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        [clearButton.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:10.0],
        [clearButton.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [clearButton.heightAnchor constraintEqualToConstant:36.0],
        [clearButton.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6.0],

        [tableView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:16.0],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [emptyView.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor constant:18.0],
        [emptyView.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor constant:-18.0],
        [emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:20.0],

        [emptyTitle.topAnchor constraintEqualToAnchor:emptyView.topAnchor],
        [emptyTitle.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [emptyTitle.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],

        [emptyCopy.topAnchor constraintEqualToAnchor:emptyTitle.bottomAnchor constant:8.0],
        [emptyCopy.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [emptyCopy.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],
        [emptyCopy.bottomAnchor constraintEqualToAnchor:emptyView.bottomAnchor]
    ]];
}

- (void)pp_closeHistorySheet {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_handleClearHistoryTapped {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:kLang(@"nova_history_clear_confirm_title")
                                                                    message:kLang(@"nova_history_clear_confirm_message")
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:kLang(@"nova_history_clear_confirm_action")
                                                          style:UIAlertActionStyleDestructive
                                                        handler:^(__unused UIAlertAction *action) {
        [[PPNovaLocalChatMemory sharedMemory] clearAllMessages];
        self.historyMessages = @[];
        self.clearButton.hidden = YES;
        self.subtitleLabel.text = kLang(@"nova_no_history");
        self.emptyStateView.hidden = NO;
        [self.tableView reloadData];

        [UIView animateWithDuration:0.26
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.emptyStateView.alpha = 1.0;
            self.tableView.alpha = 0.0;
        } completion:nil];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kLang(@"Cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [confirm addAction:clearAction];
    [confirm addAction:cancelAction];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)pp_runEntranceAnimationIfNeeded {
    if (self.didRunEntranceAnimation) {
        return;
    }
    self.didRunEntranceAnimation = YES;

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.headerView.alpha = 1.0;
        self.tableView.alpha = 1.0;
        self.emptyStateView.alpha = self.emptyStateView.hidden ? 0.0 : 1.0;
        return;
    }

    self.headerView.alpha = 0.0;
    self.headerView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
    self.tableView.alpha = 0.0;
    self.tableView.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
    self.emptyStateView.alpha = 0.0;
    self.emptyStateView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);

    [UIView animateWithDuration:0.38
                          delay:0.02
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.headerView.alpha = 1.0;
        self.headerView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [UIView animateWithDuration:0.46
                          delay:0.08
         usingSpringWithDamping:0.92
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.tableView.alpha = 1.0;
        self.tableView.transform = CGAffineTransformIdentity;
        self.emptyStateView.alpha = self.emptyStateView.hidden ? 0.0 : 1.0;
        self.emptyStateView.transform = CGAffineTransformIdentity;
    } completion:nil];

    NSArray<UITableViewCell *> *visibleCells = self.tableView.visibleCells ?: @[];
    [visibleCells enumerateObjectsUsingBlock:^(UITableViewCell *cell, NSUInteger idx, __unused BOOL *stop) {
        cell.contentView.alpha = 0.0;
        cell.contentView.transform = CGAffineTransformMakeTranslation(0.0, 14.0);
        NSTimeInterval delay = 0.15 + MIN(idx, (NSUInteger)8) * 0.035;
        [UIView animateWithDuration:0.34
                              delay:delay
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            cell.contentView.alpha = 1.0;
            cell.contentView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.historyMessages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPNovaHistoryEntryCell *cell = [tableView dequeueReusableCellWithIdentifier:PPNovaHistoryEntryCellReuseIdentifier forIndexPath:indexPath];
    if (indexPath.row < (NSInteger)self.historyMessages.count) {
        [cell configureWithMessage:self.historyMessages[(NSUInteger)indexPath.row]];
    }
    return cell;
}

@end

@interface PPNovaChatViewController () <UITableViewDelegate, UITableViewDataSource, PPNovaFloatingInputBarViewDelegate, PPNovaProductMessageCellDelegate>

@property (nonatomic, strong) UIView *ambientBackgroundView;
@property (nonatomic, strong) UIView *novaChatBottomGlowView;
@property (nonatomic, strong) UIView *novaHeaderView;
@property (nonatomic, strong) UIView *novaHeaderChromeView;
@property (nonatomic, strong) UIView *novaHeaderTopGlowView;
@property (nonatomic, strong) UIView *novaHeaderBottomGlowView;
@property (nonatomic, strong) UIView *novaHeaderSheenView;
@property (nonatomic, strong) CAShapeLayer *novaHeaderLiquidBorderLayer;
@property (nonatomic, strong) CAShapeLayer *novaHeaderLiquidHighlightLayer;
@property (nonatomic, copy) NSArray<UIView *> *novaHeaderMotionDots;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *historyButton;
@property (nonatomic, strong) UIView *headerBrandHaloView;
@property (nonatomic, strong) UIView *headerBrandRingView;
@property (nonatomic, strong) UIView *headerBrandMarkView;
@property (nonatomic, strong) UIView *headerHairlineHost;
@property (nonatomic, strong) UIView *headerLiveCapsule;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerSubtitleLabel;
@property (nonatomic, strong) NSLayoutConstraint *brandRingTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *brandRingCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *brandRingLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *brandRingCollapsedCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *closeButtonTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *closeButtonCollapsedCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *historyButtonTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *historyButtonCollapsedCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *nameLabelCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelCenterXConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *headerNameCollapsedTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *headerSubtitleCollapsedTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *historyButtonLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *historyButtonCollapsedTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *novaHeaderExpandedBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *emptyStateCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *novaHeaderCollapsedBottomConstraint;
@property (nonatomic, assign) BOOL didInitialInset;
@property (nonatomic, assign) BOOL novaHeaderCollapsed;
@property (nonatomic, strong) UIVisualEffectView *typingContainer;
@property (nonatomic, strong) UILabel *typingLabel;
@property (nonatomic, copy)   NSArray<UIView *> *typingDots;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) UIView *emptyStatePulseView;
@property (nonatomic, strong) UIVisualEffectView *smartSuggestionSurfaceView;
@property (nonatomic, strong) UIView *smartSuggestionAccentWashView;
@property (nonatomic, strong) CAGradientLayer *smartSuggestionAccentGradientLayer;
@property (nonatomic, strong) UILabel *smartSuggestionTitleLabel;
@property (nonatomic, strong) UILabel *smartSuggestionTextLabel;
@property (nonatomic, strong) UILabel *smartSuggestionHintLabel;
@property (nonatomic, strong) UIImageView *smartSuggestionActionImageView;
@property (nonatomic, strong) UIButton *smartSuggestionSurfaceButton;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *dynamicSmartSuggestions;
@property (nonatomic, strong) NSTimer *smartSuggestionRotationTimer;
@property (nonatomic, assign) NSUInteger smartSuggestionCurrentIndex;
@property (nonatomic, assign) BOOL smartSuggestionAutoSendEnabled;
@property (nonatomic, assign) BOOL smartSuggestionPickerVisible;
@property (nonatomic, assign) BOOL novaInputHasText;
@property (nonatomic, strong) UIVisualEffectView *smartSuggestionPickerView;
@property (nonatomic, strong) UILabel *smartSuggestionPickerTitleLabel;
@property (nonatomic, strong) UIButton *smartSuggestionAutoSendButton;
@property (nonatomic, strong) UIButton *smartSuggestionShuffleButton;
@property (nonatomic, strong) UIStackView *smartSuggestionPickerStackView;
@property (nonatomic, copy) NSArray<UIButton *> *smartSuggestionPickerButtons;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *smartSuggestionPickerSuggestions;
@property (nonatomic, strong) NSLayoutConstraint *smartSuggestionPickerBottomConstraint;

@property (nonatomic, strong) LOTAnimationView *novaHeaderBackgroundLottie;
@property (nonatomic, copy) NSString *currentHeaderBgAnimationName;
@property (nonatomic, strong) LOTAnimationView *novaRingBackgroundLottie;
@property (nonatomic, strong) LOTAnimationView *novaLoadingLottie; // Added for thinking state
@property (nonatomic, strong) LOTAnimationView *novaEmptyLoaderLottie;
@property (nonatomic, assign) BOOL novaHeaderThinkingAnimationVisible;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ChatMessageModel *> *messages;
@property (nonatomic, strong) PPNovaFloatingInputBarView *inputbar;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *typingBottomConstraint;
@property (nonatomic, assign) CGFloat inputBarRestingBottomConstant;
@property (nonatomic, copy, nullable) NSString *novaPendingPetType;
@property (nonatomic, strong) FIRHTTPSCallable *novaCallable;

// Nova Product / Cart Context
@property (nonatomic, strong, nullable) PetAccessory *lastSuggestedProduct;
@property (nonatomic, strong, nullable) NSArray<PetAccessory *> *lastShownProducts;
@property (nonatomic, strong, nullable) PetAccessory *pendingCartProduct;

// In-session local memory. Lives only while this VC is on screen.
@property (nonatomic, copy, nullable) NSString *novaMemoryPetType;
@property (nonatomic, copy, nullable) NSString *novaMemoryNeed;
@property (nonatomic, copy, nullable) NSString *novaMemoryLanguage;
@property (nonatomic, assign) BOOL novaHasSentFirstMessage;
@property (nonatomic, copy, nonnull) NSString *novaSessionId;

@property (nonatomic, assign) BOOL previousIQEnabled;
@property (nonatomic, assign) BOOL previousToolbarEnabled;
@property (nonatomic, assign) BOOL iqStateSaved;
@property (nonatomic, assign) BOOL dismissed;
@property (nonatomic, assign) CGFloat lastNovaTableLayoutWidth;
@property (nonatomic, assign) NSUInteger novaRequestGeneration;
@property (nonatomic, copy, nullable) NSString *activeNovaRequestID;
@property (nonatomic, copy, nullable) NSString *activeNovaResponseID;
@property (nonatomic, assign) NSUInteger activeNovaCachedProductsBeforeSend;
@property (nonatomic, assign) BOOL activeNovaClearedCachedProducts;
@property (nonatomic, copy, nullable) dispatch_block_t pendingNovaVisibleLayoutRefreshBlock;
@property (nonatomic, assign) BOOL novaLastTableMutationRequestedAutoScroll;
@property (nonatomic, assign) CFTimeInterval novaLastTableMutationTimestamp;

@end

@implementation PPNovaChatViewController

+ (void)presentNovaFromViewController:(UIViewController *)presentingVC {
    // Auth gate. Logged-out users see the standard sign-in flow instead of a
    // dead Nova chat that would only ever return "session expired" from the
    // server. requireSignInFrom: returns YES if already signed in (continue),
    // NO if it just presented sign-in (re-present Nova on success).
    if (presentingVC) {
        BOOL alreadyAuthed =
            [PPUserSigningManager requireSignInFrom:presentingVC
                                            success:^(UserModel * _Nonnull user) {
                                                if (user && presentingVC) {
                                                    [PPNovaChatViewController presentNovaFromViewController:presentingVC];
                                                }
                                            }
                                          cancelled:nil];
        if (!alreadyAuthed) {
            return;
        }
    }

    PPNovaChatViewController *novaVC = [[PPNovaChatViewController alloc] init];
    novaVC.modalInPresentation = YES;
    if (@available(iOS 15.0, *)) {
        novaVC.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = novaVC.sheetPresentationController;
        if (sheet) {
            if (@available(iOS 16.0, *)) {
                sheet.detents = @[ [UISheetPresentationControllerDetent largeDetent]];//customDetent,
            } else {
                sheet.detents = @[[UISheetPresentationControllerDetent largeDetent]];
            }
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 42.0;
        }
    } else {
        novaVC.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    [presentingVC presentViewController:novaVC animated:YES completion:nil];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Stable sessionId per chat — reuse the last known session so the backend
    // Agent Runtime sees consistent conversation context. Only generate a new
    // UUID when absolutely nothing exists yet.
    NSString *storedSessionId = [[PPNovaLocalChatMemory sharedMemory] lastKnownSessionId];
    if (storedSessionId.length > 0) {
        self.novaSessionId = storedSessionId;
        LOG_INFO(@"[PPNovaChat][Session] reused_stored_session_id=%@", self.novaSessionId);
    } else {
        self.novaSessionId = [[NSUUID UUID] UUIDString];
        [[PPNovaLocalChatMemory sharedMemory] setLastKnownSessionId:self.novaSessionId];
        LOG_INFO(@"[PPNovaChat][Session] generated_new_session_id=%@", self.novaSessionId);
    }
    [PPAnalytics logNovaOpenedWithSessionID:self.novaSessionId];

    self.title = @"";
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.messages = [NSMutableArray array];
    self.smartSuggestionAutoSendEnabled = YES;

    [self setupAmbientBackground];
    [self setupNovaBackend];
    [self setupNovaHeader];
    [self setupInputView];
    [self setupTypingIndicator];
    [self setupTableView];
    [self setupNovaEmptyState];

    [self registerForKeyboardNotifications];

    // Delayed load for premium motion feel
    self.novaHeaderView.alpha = 0.0;
    self.novaHeaderView.transform = CGAffineTransformMakeTranslation(0, -10);

    // Lesson: the first real Nova reply IS the greeting now. No more local
    // hardcoded bubble — the Agent Runtime produces a natural, contextual
    // welcome using the STRICT GREETING RULE in its system prompt. The
    // `isFirstAssistantMessage` flag in the first request context tells
    // the backend to allow greeting exactly once.
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) self = wself;
        if (!self || self.dismissed) return;
        // NO more insertNovaGreeting — Nova owns the first message now.
        self.novaMemoryLanguage = Language.isRTL ? @"ar" : @"en";
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.iqStateSaved) {
        self.previousIQEnabled = [IQKeyboardManager sharedManager].enable;
        self.previousToolbarEnabled = [IQKeyboardManager sharedManager].enableAutoToolbar;
        self.iqStateSaved = YES;
    }
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    if (reduceMotion) {
        self.novaHeaderView.alpha = 1.0;
        self.novaHeaderView.transform = CGAffineTransformIdentity;
        self.novaHeaderTopGlowView.alpha = 1.0;
        self.novaChatBottomGlowView.alpha = 1.0;
    } else {
        [UIView animateWithDuration:0.46
                              delay:0.05
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.3
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.novaHeaderView.alpha = 1.0;
            self.novaHeaderView.transform = CGAffineTransformIdentity;
        } completion:nil];

        [UIView animateWithDuration:0.92
                              delay:0.18
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.novaHeaderTopGlowView.alpha = 1.0;
            self.novaChatBottomGlowView.alpha = 1.0;
        } completion:nil];
    }

    [self pp_startHeaderLiveAnimations];
    [self pp_startAmbientBackgroundAnimations];
    [self pp_startNovaSmartSuggestionRotationIfNeeded];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pp_refreshProviderSmartSuggestions];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    BOOL leavingForGood = self.isBeingDismissed || self.isMovingFromParentViewController;
    if (leavingForGood) {
        self.dismissed = YES;
        if (self.iqStateSaved) {
            [IQKeyboardManager sharedManager].enable = self.previousIQEnabled;
            [IQKeyboardManager sharedManager].enableAutoToolbar = self.previousToolbarEnabled;
        }
        [PPAnalytics logNovaClosedWithSessionID:self.novaSessionId
                                    messageCount:self.messages.count];
    }

    [self pp_stopHeaderLiveAnimations];
    [self pp_stopAmbientBackgroundAnimations];
    [self pp_stopNovaSmartSuggestionRotation];
    [self pp_stopTypingDotsAnimation];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self pp_applyNovaSurfaceColors];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateNovaHeaderCollapsedGeometry];
    [self pp_updateNovaHeaderLiquidBorderPath];
    self.smartSuggestionAccentGradientLayer.frame = self.smartSuggestionAccentWashView.bounds;

    if (!self.didInitialInset && CGRectGetHeight(self.inputbar.frame) > 0) {
        self.didInitialInset = YES;
        UIEdgeInsets currentInset = self.tableView.contentInset;
        currentInset.bottom = 0.0;
        self.tableView.contentInset = currentInset;
        self.tableView.scrollIndicatorInsets = currentInset;
    }

    CGFloat tableWidth = CGRectGetWidth(self.tableView.bounds);
    if (tableWidth <= 1.0 || fabs(tableWidth - self.lastNovaTableLayoutWidth) <= 1.0) {
        return;
    }

    self.lastNovaTableLayoutWidth = tableWidth;
    [self pp_scheduleNovaVisibleLayoutRefreshForReason:@"table_width_changed"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.pendingNovaVisibleLayoutRefreshBlock) {
        dispatch_block_cancel(self.pendingNovaVisibleLayoutRefreshBlock);
        self.pendingNovaVisibleLayoutRefreshBlock = nil;
    }
    [self.statusDot.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.novaHeaderLiquidBorderLayer removeAllAnimations];
    [self.novaHeaderLiquidHighlightLayer removeAllAnimations];
    [self.emptyStatePulseView.layer removeAllAnimations];
    [self.novaChatBottomGlowView.layer removeAllAnimations];
    [self pp_stopNovaSmartSuggestionLiveMotion];
    [self pp_stopNovaSmartSuggestionRotation];
    for (UIView *dot in self.typingDots) {
        [dot.layer removeAllAnimations];
    }
}

#pragma mark - Backend

- (void)setupNovaBackend {
    FIRFunctions *functions = [FIRFunctions functionsForRegion:PPNovaCallableRegion];

    // App Check: identical to UserManager / PaymentManager / OrderManager.
    // The backend geminiProxy enforces App Check. Without this the callable
    // returns gRPC 7/16 and the client falls back to nova_error_unavailable.
    SEL limitedUseSetter = NSSelectorFromString(@"setUseAppCheckLimitedUseTokens:");
    if ([functions respondsToSelector:limitedUseSetter]) {
        NSMethodSignature *signature = [functions methodSignatureForSelector:limitedUseSetter];
        if (signature) {
            BOOL enabled = YES;
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:limitedUseSetter];
            [invocation setTarget:functions];
            [invocation setArgument:&enabled atIndex:2];
            [invocation invoke];
            LOG_INFO(@"[PPNovaChat][AppCheck] Enabled limited-use App Check tokens for novaCallable (%@).", PPNovaCallableName);
        }
    } else {
        LOG_WARN(@"[PPNovaChat][AppCheck] FIRFunctions does not respond to setUseAppCheckLimitedUseTokens — App Check may not be attached.");
    }

    self.novaCallable = [functions HTTPSCallableWithName:PPNovaCallableName];
    // Reverting timeout to default 70.0s because 15.0s caused Firebase Functions
    // cold starts and AI delays to timeout frequently.
    self.novaCallable.timeoutInterval = 70.0;
    LOG_INFO(@"[PPNovaChat][Debug] callable url=%@ timeout=%.0fs", [PPNovaChatViewController pp_novaCallableDebugURL], self.novaCallable.timeoutInterval);
}

- (NSString *)pp_newNovaScopedIDWithPrefix:(NSString *)prefix {
    NSString *safePrefix = prefix.length > 0 ? prefix : @"nova";
    return [NSString stringWithFormat:@"%@_%@", safePrefix, [[NSUUID UUID] UUIDString]];
}

- (NSString *)pp_novaResponseIDFromResponseData:(NSDictionary *)data
                                      requestID:(NSString *)requestID
                                         source:(NSString *)source {
    NSArray<NSString *> *keys = @[@"response_id", @"responseId", @"responseID", @"message_id", @"messageId", @"id"];
    if ([data isKindOfClass:NSDictionary.class]) {
        for (NSString *key in keys) {
            NSString *value = [self pp_novaStringFromValue:data[key]];
            if (value.length > 0) {
                return value;
            }
        }
    }
    NSString *base = requestID.length > 0 ? requestID : @"request";
    NSString *safeSource = source.length > 0 ? source : @"response";
    return [NSString stringWithFormat:@"%@_%@_%@", base, safeSource, [[NSUUID UUID] UUIDString]];
}

- (void)pp_prepareNovaRenderStateForRequestID:(NSString *)requestID
                      cachedProductsBeforeSend:(NSUInteger)cachedProductsBeforeSend {
    BOOL hadPendingPayload = cachedProductsBeforeSend > 0 || self.lastSuggestedProduct != nil || self.pendingCartProduct != nil;
    self.activeNovaRequestID = requestID;
    self.activeNovaResponseID = nil;
    self.activeNovaCachedProductsBeforeSend = cachedProductsBeforeSend;
    self.activeNovaClearedCachedProducts = hadPendingPayload;
    [self pp_clearNovaTransientRenderPayloadForReason:@"new_user_message"];

    // Lesson: a new user message starts a fresh request/response context. The
    // newest response owns its own cards; it must never inherit cards from a
    // previous response, and we never re-render historical card payloads here.
    LOG_INFO(@"[PPNovaChat][RenderBinding] request_id=%@ previous_cached_card_count=%lu cleared_transient_payload=%@ historical_restore=NO reused_previous_payload=NO",
             requestID ?: @"",
             (unsigned long)cachedProductsBeforeSend,
             hadPendingPayload ? @"YES" : @"NO");
}

// Single point of truth for clearing the transient render payload (cards that
// the previous response left behind). Used at the start of every new request
// and on any correction/rejection that follows the same pattern.
- (void)pp_clearNovaTransientRenderPayloadForReason:(NSString *)reason {
    BOOL hadAny = self.lastShownProducts.count > 0 || self.lastSuggestedProduct != nil || self.pendingCartProduct != nil;
    self.lastShownProducts = @[];
    self.lastSuggestedProduct = nil;
    self.pendingCartProduct = nil;
    LOG_INFO(@"[PPNovaChat][RenderBinding] transient_payload_clear reason=%@ had_any=%@",
             reason ?: @"unspecified",
             hadAny ? @"YES" : @"NO");
}

- (BOOL)pp_canAttachNovaRenderForRequestID:(NSString *)requestID
                                responseID:(NSString *)responseID
                                generation:(NSUInteger)generation
                                    source:(NSString *)source {
    BOOL hasIDs = requestID.length > 0 && responseID.length > 0;
    BOOL requestMatches = hasIDs && [requestID isEqualToString:self.activeNovaRequestID];
    BOOL responseMatches = hasIDs && (self.activeNovaResponseID.length == 0 || [responseID isEqualToString:self.activeNovaResponseID]);
    BOOL generationMatches = generation == 0 || generation == self.novaRequestGeneration;
    if (requestMatches && responseMatches && generationMatches) {
        return YES;
    }

    NSString *reason = !hasIDs ? @"missing_response_ids" : @"stale_request_or_generation";
    LOG_WARN(@"[PPNovaChat][RenderBinding] append_dropped reason=%@ request_id=%@ response_id=%@ active_request_id=%@ active_response_id=%@ generation=%lu active_generation=%lu source=%@ reused_previous_payload=NO",
             reason,
             requestID ?: @"",
             responseID ?: @"",
             self.activeNovaRequestID ?: @"",
             self.activeNovaResponseID ?: @"",
             (unsigned long)generation,
             (unsigned long)self.novaRequestGeneration,
             source ?: @"unknown");
    return NO;
}

- (NSUInteger)pp_novaRefCountInRefs:(NSArray<NSDictionary<NSString *, NSString *> *> *)refs
                              kinds:(NSSet<NSString *> *)kinds {
    NSUInteger count = 0;
    for (NSDictionary<NSString *, NSString *> *ref in refs) {
        NSString *kind = ref[@"kind"] ?: @"";
        if ([kinds containsObject:kind]) {
            count++;
        }
    }
    return count;
}

- (void)pp_logNovaIncomingRefs:(NSArray<NSDictionary<NSString *, NSString *> *> *)refs
                     requestID:(NSString *)requestID
                    responseID:(NSString *)responseID
                        source:(NSString *)source {
    NSUInteger productsCount = [self pp_novaRefCountInRefs:refs kinds:[NSSet setWithArray:@[@"product", @"medicine"]]];
    NSUInteger adsCount = [self pp_novaRefCountInRefs:refs kinds:[NSSet setWithArray:@[@"pet_ad", @"adoption"]]];
    NSUInteger servicesCount = [self pp_novaRefCountInRefs:refs kinds:[NSSet setWithArray:@[@"service", @"vet"]]];
    LOG_INFO(@"[PPNovaChat][RenderBinding] request_id=%@ response_id=%@ incoming_products_count=%lu incoming_ads_count=%lu incoming_services_count=%lu source=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)productsCount,
             (unsigned long)adsCount,
             (unsigned long)servicesCount,
             source ?: @"unknown");
}

- (void)pp_logNovaIncomingObjects:(NSArray *)objects
                        requestID:(NSString *)requestID
                       responseID:(NSString *)responseID
                           source:(NSString *)source {
    NSUInteger productsCount = 0;
    NSUInteger adsCount = 0;
    NSUInteger servicesCount = 0;
    for (id object in objects) {
        if ([object isKindOfClass:PetAccessory.class]) {
            productsCount++;
        } else if ([object isKindOfClass:PetAd.class] || [object isKindOfClass:AdoptPetModel.class]) {
            adsCount++;
        } else if ([object isKindOfClass:ServiceModel.class] || [object isKindOfClass:VetModel.class]) {
            servicesCount++;
        }
    }
    LOG_INFO(@"[PPNovaChat][RenderBinding] request_id=%@ response_id=%@ incoming_products_count=%lu incoming_ads_count=%lu incoming_services_count=%lu source=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)productsCount,
             (unsigned long)adsCount,
             (unsigned long)servicesCount,
             source ?: @"unknown");
}

- (NSDictionary *)pp_novaResultSetDictionaryFromResponseData:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id resultSet = data[@"result_set"] ?: data[@"resultSet"];
    return [resultSet isKindOfClass:NSDictionary.class] ? (NSDictionary *)resultSet : nil;
}

- (NSUInteger)pp_novaUnsignedIntegerFromValue:(id)value {
    if ([value isKindOfClass:NSArray.class]) {
        return [(NSArray *)value count];
    }
    if ([value respondsToSelector:@selector(unsignedIntegerValue)]) {
        return [value unsignedIntegerValue];
    }
    NSString *text = [self pp_novaStringFromValue:value];
    if (text.length > 0) {
        NSInteger number = text.integerValue;
        return number > 0 ? (NSUInteger)number : 0;
    }
    return 0;
}

- (BOOL)pp_novaBoolFromValue:(id)value defaultValue:(BOOL)defaultValue {
    if ([value isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)value boolValue];
    }
    NSString *text = [[self pp_novaStringFromValue:value] lowercaseString];
    if (text.length == 0) {
        return defaultValue;
    }
    if ([text isEqualToString:@"true"] || [text isEqualToString:@"yes"] || [text isEqualToString:@"1"]) {
        return YES;
    }
    if ([text isEqualToString:@"false"] || [text isEqualToString:@"no"] || [text isEqualToString:@"0"]) {
        return NO;
    }
    return defaultValue;
}

- (NSUInteger)pp_novaBackendResultCountFromResponseData:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return 0;
    }
    __block NSUInteger count = 0;
    void (^consider)(id) = ^(id value) {
        count = MAX(count, [self pp_novaUnsignedIntegerFromValue:value]);
    };
    for (NSString *key in @[@"result_count", @"resultCount", @"product_count", @"productCount", @"renderedProductCount", @"rendered_product_count", @"matchedProductCount", @"matched_product_count"]) {
        consider(data[key]);
    }
    NSDictionary *context = [data[@"_compose_context"] isKindOfClass:NSDictionary.class] ? data[@"_compose_context"] : nil;
    if (!context) {
        context = [data[@"compose_context"] isKindOfClass:NSDictionary.class] ? data[@"compose_context"] : nil;
    }
    if (!context) {
        context = [data[@"composeContext"] isKindOfClass:NSDictionary.class] ? data[@"composeContext"] : nil;
    }
    for (NSString *key in @[@"result_count", @"resultCount", @"card_count", @"cardCount"]) {
        consider(context[key]);
    }
    NSDictionary *resultSet = [self pp_novaResultSetDictionaryFromResponseData:data];
    consider(resultSet[@"items"] ?: resultSet[@"products"]);
    for (NSString *key in @[@"products", @"items", @"resultRefs", @"result_refs"]) {
        consider(data[key]);
    }
    return count;
}

- (NSUInteger)pp_novaBackendResultRefsCountFromResponseData:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return 0;
    }
    NSUInteger count = 0;
    for (NSString *key in @[@"resultRefs", @"result_refs"]) {
        id value = data[key];
        if ([value isKindOfClass:NSArray.class]) {
            count += [(NSArray *)value count];
        }
    }
    NSDictionary *resultSet = [self pp_novaResultSetDictionaryFromResponseData:data];
    id items = resultSet[@"items"];
    if ([items isKindOfClass:NSArray.class]) {
        count += [(NSArray *)items count];
    }
    return count;
}

- (BOOL)pp_novaCardsRequiredFromResponseData:(NSDictionary *)data
                                 resultCount:(NSUInteger)resultCount
                             resultRefsCount:(NSUInteger)resultRefsCount {
    if (![data isKindOfClass:NSDictionary.class]) {
        return NO;
    }
    NSDictionary *resultSet = [self pp_novaResultSetDictionaryFromResponseData:data];
    NSDictionary *context = [data[@"_compose_context"] isKindOfClass:NSDictionary.class] ? data[@"_compose_context"] : nil;
    if (!context) {
        context = [data[@"compose_context"] isKindOfClass:NSDictionary.class] ? data[@"compose_context"] : nil;
    }
    if (!context) {
        context = [data[@"composeContext"] isKindOfClass:NSDictionary.class] ? data[@"composeContext"] : nil;
    }
    BOOL explicitRequired = [self pp_novaBoolFromValue:data[@"cardsRequired"] defaultValue:NO] ||
                            [self pp_novaBoolFromValue:data[@"cards_required"] defaultValue:NO] ||
                            [self pp_novaBoolFromValue:resultSet[@"cardsRequired"] defaultValue:NO] ||
                            [self pp_novaBoolFromValue:resultSet[@"cards_required"] defaultValue:NO] ||
                            [self pp_novaBoolFromValue:context[@"cards_required"] defaultValue:NO];
    BOOL textFallbackAllowed = [self pp_novaBoolFromValue:data[@"textFallbackAllowed"] defaultValue:YES] &&
                               [self pp_novaBoolFromValue:data[@"text_fallback_allowed"] defaultValue:YES] &&
                               [self pp_novaBoolFromValue:resultSet[@"textFallbackAllowed"] defaultValue:YES] &&
                               [self pp_novaBoolFromValue:resultSet[@"text_fallback_allowed"] defaultValue:YES];
    return explicitRequired || resultRefsCount > 0 || (resultCount > 0 && !textFallbackAllowed);
}

- (NSString *)pp_novaResultSourceFromResponseData:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return @"unknown";
    }
    NSDictionary *resultSet = [self pp_novaResultSetDictionaryFromResponseData:data];
    NSDictionary *context = [data[@"_compose_context"] isKindOfClass:NSDictionary.class] ? data[@"_compose_context"] : nil;
    if (!context) {
        context = [data[@"compose_context"] isKindOfClass:NSDictionary.class] ? data[@"compose_context"] : nil;
    }
    if (!context) {
        context = [data[@"composeContext"] isKindOfClass:NSDictionary.class] ? data[@"composeContext"] : nil;
    }
    NSString *source = [self pp_novaStringFromValue:data[@"locked_source"]];
    if (source.length == 0) source = [self pp_novaStringFromValue:resultSet[@"source"]];
    if (source.length == 0) source = [self pp_novaStringFromValue:data[@"source_used"]];
    if (source.length == 0) source = [self pp_novaStringFromValue:context[@"source_used"]];
    if (source.length == 0) source = [self pp_novaStringFromValue:data[@"payload_type"]];
    return source.length > 0 ? source : @"unknown";
}

- (void)pp_logNovaCellPayloadWithRequestID:(NSString *)requestID
                                responseID:(NSString *)responseID
                        backendResultCount:(NSUInteger)backendResultCount
                     backendResultRefsCount:(NSUInteger)backendResultRefsCount
                          parsedResultRefs:(NSUInteger)parsedResultRefs
                             cardsRequired:(BOOL)cardsRequired
                                    source:(NSString *)source {
    LOG_INFO(@"NOVA_CELL_PAYLOAD request_id=%@ response_id=%@ backend_result_count=%lu resultRefs_count=%lu parsed_resultRefs_count=%lu cardsRequired=%@ source=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)backendResultCount,
             (unsigned long)backendResultRefsCount,
             (unsigned long)parsedResultRefs,
             cardsRequired ? @"YES" : @"NO",
             source ?: @"unknown");
}

- (void)pp_handleNovaCellRenderMissingWithRequestID:(NSString *)requestID
                                        responseID:(NSString *)responseID
                                backendResultCount:(NSUInteger)backendResultCount
                             backendResultRefsCount:(NSUInteger)backendResultRefsCount
                                  parsedResultRefs:(NSUInteger)parsedResultRefs
                                      cellsCreated:(NSUInteger)cellsCreated
                                            source:(NSString *)source
                                            reason:(NSString *)reason {
    LOG_WARN(@"NOVA_CELL_RENDER_MISSING request_id=%@ response_id=%@ backend_result_count=%lu resultRefs_count=%lu parsed_resultRefs_count=%lu cells_created=%lu source=%@ reason=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)backendResultCount,
             (unsigned long)backendResultRefsCount,
             (unsigned long)parsedResultRefs,
             (unsigned long)cellsCreated,
             source ?: @"unknown",
             reason ?: @"unknown");
    [self hideNovaTyping];
    NSString *fallback = kLang(@"nova_cell_render_missing");
    if (fallback.length == 0 || [fallback isEqualToString:@"nova_cell_render_missing"]) {
        fallback = kLang(@"nova_suggestions_unavailable");
    }
    if (![self pp_lastNovaTextMessageEquals:fallback]) {
        [self addNovaMessage:fallback requestID:requestID responseID:responseID];
    }
}

- (BOOL)pp_novaReplyLooksLikeManualResultList:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return NO;
    }

    NSArray<NSString *> *patterns = @[
        @"(?m)^\\s*[*•-]\\s+\\S+",
        @"(?m)^\\s*[0-9٠-٩]+[\\.)-]\\s+\\S+"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        if ([regex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)]) {
            return YES;
        }
    }

    NSString *lower = trimmed.lowercaseString;
    NSRegularExpression *digitRegex = [NSRegularExpression regularExpressionWithPattern:@"[0-9٠-٩]" options:0 error:nil];
    BOOL hasDigit = [digitRegex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)] != nil;
    BOOL hasFoundVerb = [lower containsString:@"وجدت"] ||
                        [lower containsString:@"لقِيت"] ||
                        [lower containsString:@"لقيت"] ||
                        [lower containsString:@"found"] ||
                        [lower containsString:@"here are"];
    NSArray<NSString *> *resultTerms = @[
        @"نتائج", @"نتيجة", @"خيارات", @"خيار", @"خدمات", @"خدمة",
        @"عيادات", @"عيادة", @"منتجات", @"منتج", @"results", @"options",
        @"services", @"service", @"clinics", @"clinic", @"vets", @"products"
    ];
    BOOL hasResultTerm = NO;
    for (NSString *term in resultTerms) {
        if ([lower containsString:term]) {
            hasResultTerm = YES;
            break;
        }
    }
    return hasDigit && hasFoundVerb && hasResultTerm;
}

- (NSString *)pp_novaCardFocusedAssistantTextFromText:(NSString *)text {
    NSString *clean = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (clean.length == 0) {
        return nil;
    }
    if ([self pp_novaReplyLooksLikeManualResultList:clean]) {
        LOG_WARN(@"[PPNovaChat][Refs] manual_result_text_suppressed chars=%lu", (unsigned long)clean.length);
        return nil;
    }
    return clean;
}

#pragma mark - Nova Presentation Runtime

- (PPNovaOutputType)pp_novaOutputTypeForCardObject:(id)object {
    if ([object isKindOfClass:ServiceModel.class]) {
        return PPNovaOutputTypeServiceCards;
    }
    if ([object isKindOfClass:VetModel.class]) {
        return PPNovaOutputTypeVetCards;
    }
    if ([object isKindOfClass:AdoptPetModel.class]) {
        return PPNovaOutputTypeAdoptCards;
    }
    if ([object isKindOfClass:PetAd.class]) {
        return PPNovaOutputTypeAdsCards;
    }
    if ([object isKindOfClass:PetAccessory.class]) {
        return PPNovaOutputTypeProductCards;
    }
    return PPNovaOutputTypeProductCards;
}

- (PPNovaOutputType)pp_novaOutputTypeForCardObjects:(NSArray *)objects {
    NSMutableDictionary<NSNumber *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (id object in objects) {
        PPNovaOutputType type = [self pp_novaOutputTypeForCardObject:object];
        NSNumber *key = @(type);
        counts[key] = @((counts[key].integerValue) + 1);
    }

    PPNovaOutputType dominantType = PPNovaOutputTypeProductCards;
    NSInteger dominantCount = 0;
    for (NSNumber *key in counts) {
        NSInteger count = counts[key].integerValue;
        if (count > dominantCount) {
            dominantCount = count;
            dominantType = (PPNovaOutputType)key.integerValue;
        }
    }
    return dominantType;
}

- (PPNovaOutputType)pp_novaOutputTypeForMessage:(ChatMessageModel *)message {
    if (message.messageType == ChatMessageTypeNovaProduct ||
        message.messageType == ChatMessageTypeNovaProductList) {
        return [self pp_novaOutputTypeForCardObjects:(NSArray *)message.novaProducts];
    }
    if (message.messageType == ChatMessageTypeSystem ||
        message.messageType == ChatMessageTypeNovaReview) {
        return PPNovaOutputTypeSystemFallback;
    }
    return PPNovaOutputTypeText;
}

- (NSString *)pp_novaStableReuseIdentifierForOutputType:(PPNovaOutputType)outputType
                                            messageType:(ChatMessageType)messageType {
    if (messageType == ChatMessageTypeNovaReview) {
        return [PPNovaReviewMessageCell reuseIdentifier];
    }
    if (PPNovaOutputTypeRendersCards(outputType)) {
        return [PPNovaProductMessageCell reuseIdentifier];
    }
    return [PPNovaMessageBubbleCell reuseIdentifier];
}

- (PPNovaPresentationAlignment)pp_novaAlignmentForMessage:(ChatMessageModel *)message
                                               outputType:(PPNovaOutputType)outputType {
    if (outputType == PPNovaOutputTypeSystemFallback) {
        return PPNovaPresentationAlignmentCentered;
    }
    BOOL assistant = [message.senderID isEqualToString:@"nova_bot_id"];
    return assistant ? PPNovaPresentationAlignmentAssistant : PPNovaPresentationAlignmentUser;
}

- (PPNovaOutputStyle *)pp_novaOutputStyleForMessage:(ChatMessageModel *)message
                                         outputType:(PPNovaOutputType)outputType
                                         tableWidth:(CGFloat)tableWidth {
    PPNovaOutputStyle *style = [[PPNovaOutputStyle alloc] init];
    style.outputType = outputType;
    style.alignment = [self pp_novaAlignmentForMessage:message outputType:outputType];
    style.shouldRenderCards = PPNovaOutputTypeRendersCards(outputType);
    style.shouldRenderAssistantText = outputType == PPNovaOutputTypeText &&
        [message.senderID isEqualToString:@"nova_bot_id"] &&
        message.text.length > 0;
    style.stableReuseIdentifier = [self pp_novaStableReuseIdentifierForOutputType:outputType
                                                                      messageType:message.messageType];
    style.renderStyle = style.shouldRenderCards ? @"horizontalCards" : @"bubble";
    style.maxWidth = MAX(tableWidth, 1.0);

    UIColor *brand = AppPrimaryClr ?: UIColor.systemOrangeColor;
    UIColor *primaryText = AppPrimaryTextClr ?: UIColor.labelColor;
    style.accentColor = brand;
    style.backgroundColor = style.shouldRenderCards
        ? UIColor.clearColor
        : PPNovaDynamicColor([UIColor colorWithWhite:1.0 alpha:0.93],
                             [UIColor colorWithWhite:1.0 alpha:0.105]);
    style.textColor = (style.alignment == PPNovaPresentationAlignmentUser) ? UIColor.whiteColor : primaryText;
    style.cornerRadius = style.shouldRenderCards ? 0.0 : 24.0;
    style.spacing = style.shouldRenderCards ? 10.0 : 8.0;
    style.visualWeight = style.shouldRenderCards ? 0.86 : (style.shouldRenderAssistantText ? 0.70 : 0.62);
    style.priority = style.shouldRenderCards ? 80 : (style.shouldRenderAssistantText ? 70 : 60);
    if (outputType == PPNovaOutputTypeSystemFallback) {
        style.visualWeight = 0.54;
        style.priority = 45;
    }
    return style;
}

- (NSString *)pp_realNovaIDForCardObject:(id)object {
    if ([object isKindOfClass:PetAccessory.class]) {
        return ((PetAccessory *)object).accessoryID ?: @"";
    }
    if ([object isKindOfClass:ServiceModel.class]) {
        return ((ServiceModel *)object).serviceID ?: @"";
    }
    if ([object isKindOfClass:PetAd.class]) {
        return ((PetAd *)object).adID ?: @"";
    }
    if ([object isKindOfClass:AdoptPetModel.class]) {
        return ((AdoptPetModel *)object).documentID ?: @"";
    }
    if ([object isKindOfClass:VetModel.class]) {
        return ((VetModel *)object).vetID ?: @"";
    }
    return @"";
}

- (NSArray<NSString *> *)pp_realNovaIDsForCardObjects:(NSArray *)objects {
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (id object in objects) {
        NSString *identifier = [self pp_realNovaIDForCardObject:object];
        if (identifier.length > 0) {
            [ids addObject:identifier];
        }
    }
    return ids.copy;
}

- (NSArray *)pp_validNovaCardObjectsFromObjects:(NSArray *)objects
                                         source:(NSString *)source
                                      requestID:(NSString *)requestID
                                     responseID:(NSString *)responseID {
    NSMutableArray *validObjects = [NSMutableArray arrayWithCapacity:objects.count];
    for (id object in objects) {
        NSString *identifier = [self pp_realNovaIDForCardObject:object];
        if (identifier.length == 0) {
            LOG_WARN(@"[PPNovaChat][Presentation] card_output_missing_real_id request_id=%@ response_id=%@ source=%@ objectClass=%@",
                     requestID ?: @"",
                     responseID ?: @"",
                     source ?: @"unknown",
                     NSStringFromClass([object class]));
            NSAssert(identifier.length > 0, @"Nova card output is missing a real retrieved ID.");
            continue;
        }
        [validObjects addObject:object];
    }
    return validObjects.copy;
}

- (NSString *)pp_renderKeyForMessage:(ChatMessageModel *)message
                           outputType:(PPNovaOutputType)outputType {
    NSString *contentKey = @"";
    if (PPNovaOutputTypeRendersCards(outputType)) {
        contentKey = [[self pp_realNovaIDsForCardObjects:(NSArray *)message.novaProducts] componentsJoinedByString:@","];
    } else {
        contentKey = [NSString stringWithFormat:@"%lu", (unsigned long)(message.text ?: @"").hash];
    }
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
            message.ID ?: @"",
            message.novaRequestID ?: @"",
            message.novaResponseID ?: @"",
            PPNovaOutputTypeName(outputType),
            contentKey ?: @""];
}

- (PPNovaMessagePresentation *)pp_presentationForMessage:(ChatMessageModel *)message
                                                rowIndex:(NSInteger)rowIndex {
    CGFloat tableWidth = [self pp_novaMessageLayoutWidthForTableView:self.tableView];
    PPNovaOutputType outputType = [self pp_novaOutputTypeForMessage:message];
    PPNovaMessagePresentation *presentation = [[PPNovaMessagePresentation alloc] init];
    presentation.messageID = message.ID ?: @"";
    presentation.requestID = message.novaRequestID ?: @"";
    presentation.responseID = message.novaResponseID ?: @"";
    presentation.rowIndex = rowIndex;
    presentation.style = [self pp_novaOutputStyleForMessage:message
                                                 outputType:outputType
                                                 tableWidth:tableWidth];
    presentation.renderKey = [self pp_renderKeyForMessage:message outputType:outputType];
    return presentation;
}

- (void)pp_logNovaTableUpdateForMessage:(ChatMessageModel *)message
                               rowIndex:(NSInteger)rowIndex
                                 reason:(NSString *)reason {
    PPNovaMessagePresentation *presentation = [self pp_presentationForMessage:message rowIndex:rowIndex];
    LOG_INFO(@"[PPNovaChat][TableUpdate] messageId=%@ outputType=%@ reuseIdentifier=%@ renderKey=%@ row=%ld reason=%@ alignment=%@ priority=%ld shouldRenderText=%@ shouldRenderCards=%@",
             presentation.messageID ?: @"",
             PPNovaOutputTypeName(presentation.style.outputType),
             presentation.style.stableReuseIdentifier ?: @"",
             presentation.renderKey ?: @"",
             (long)rowIndex,
             reason ?: @"unknown",
             PPNovaPresentationAlignmentName(presentation.style.alignment),
             (long)presentation.style.priority,
             presentation.style.shouldRenderAssistantText ? @"YES" : @"NO",
             presentation.style.shouldRenderCards ? @"YES" : @"NO");
}

- (void)sendNovaRequestForUserText:(NSString *)userText requestID:(NSString *)requestID {
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) {
        [self hideNovaTyping];
        LOG_WARN(@"[PPNovaChat][Debug] branch=rejected_empty_message request_id=%@", requestID ?: @"");
        return;
    }

    // Guard: Firebase Auth user must exist. If nil, show sign-in required
    // instead of letting the callable fail with a cryptic App Check / auth error.
    FIRUser *currentUser = PPCurrentFIRAuthUser;
    if (!currentUser || currentUser.uid.length == 0) {
        [self hideNovaTyping];
        LOG_ERROR(@"[PPNovaChat][Debug] branch=no_firebase_user request_id=%@", requestID ?: @"");
        [self pp_dismissNovaForSignInRequired];
        return;
    }

    // Refresh the ID token if needed so the callable always carries a fresh one.
    // The Firebase Callable SDK auto-attaches `Authorization: Bearer <id_token>`
    // but only if the token is still valid. A stale token causes gRPC 16.
    __weak typeof(self) weakSelf = self;
    [currentUser getIDTokenForcingRefresh:YES completion:^(NSString * _Nullable idToken, NSError * _Nullable tokenError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.dismissed) return;

        if (tokenError || idToken.length == 0) {
            [self hideNovaTyping];
            LOG_ERROR(@"[PPNovaChat][Debug] branch=token_refresh_failed error=%@ request_id=%@",
                      tokenError.localizedDescription ?: @"missing token",
                      requestID ?: @"");
            [self pp_dismissNovaForSignInRequired];
            return;
        }

        LOG_INFO(@"[PPNovaChat][Debug] branch=token_refreshed request_id=%@ token_length=%lu",
                 requestID ?: @"", (unsigned long)idToken.length);

        // Proceed with the actual request now that we have a fresh token.
        [self pp_continueNovaRequestWithText:trimmedText requestID:requestID];
    }];
}

- (void)pp_continueNovaRequestWithText:(NSString *)trimmedText requestID:(NSString *)requestID {
    // pp_updateMemoryFromUserText is already called by the caller before
    // sendNovaRequestForUserText — do not duplicate here.

    [PPAnalytics logNovaMessageSentWithCharCount:trimmedText.length
                                         isArabic:[self textContainsArabic:trimmedText]
                                       sessionID:self.novaSessionId];

    // After the first request is dispatched, every subsequent message tells the
    // backend isFirstAssistantMessage=false so the Agent Runtime enforces the
    // STRICT GREETING RULE (no hello, no re-welcome).
    self.novaHasSentFirstMessage = YES;

    self.novaRequestGeneration = self.novaRequestGeneration + 1;
    NSUInteger generation = self.novaRequestGeneration;
    [self pp_startNovaRequestWatchdogForGeneration:generation userText:trimmedText requestID:requestID];
    [self pp_dispatchNovaRequest:trimmedText attempt:0 generation:generation requestID:requestID];
}

- (void)pp_dispatchNovaRequest:(NSString *)trimmedText attempt:(NSInteger)attempt generation:(NSUInteger)generation requestID:(NSString *)requestID {
    if (self.dismissed) return;
    BOOL hasCatalogIntent = [self pp_novaHasCatalogSearchIntentForUserText:trimmedText];

    if (!self.novaCallable) {
        // Backend not initialized — don't fabricate a Nova reply, just try a
        // local product showcase. If nothing scores high enough, the chat stays
        // silent rather than injecting a templated apology.
        [self hideNovaTyping];
        NSString *responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"local_no_callable"];
        self.activeNovaResponseID = responseID;
        [self pp_logNovaIncomingObjects:@[] requestID:requestID responseID:responseID source:@"local_no_callable"];
        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
                                                 introText:nil
                                                 requestID:requestID
                                                responseID:responseID
                                                generation:generation
                                               completion:nil];
        return;
    }

    NSDictionary *payload = @{
        @"prompt": trimmedText,
        @"context": [self pp_currentContextDictionary],
        @"history": [self pp_currentHistoryArray],
        @"sessionId": self.novaSessionId,
        @"request_id": requestID ?: @"",
        @"requestId": requestID ?: @"",
        @"conversation_state": [self pp_currentNovaBrainStateDictionary]
    };

    LOG_INFO(@"[PPNovaChat][Debug] send url=%@ request_id=%@ requestKeys=%@ authUIDPresent=%@",
             [PPNovaChatViewController pp_novaCallableDebugURL],
             requestID ?: @"",
             [PPNovaChatViewController pp_sortedDictionaryKeys:payload],
             PPCurrentFIRAuthUser.uid.length > 0 ? @"YES" : @"NO");

    __weak typeof(self) weakSelf = self;
    [self.novaCallable callWithObject:payload
                           completion:^(FIRHTTPSCallableResult * _Nullable result, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.dismissed) return;

                if (error) {
                if (attempt == 0 && [PPNovaChatViewController pp_isRetryableNovaError:error]) {
	                    LOG_WARN(@"[PPNovaChat][Debug] branch=retryable_transient attempt=%ld code=%ld httpStatus=%@",
	                             (long)attempt,
	                             (long)error.code,
	                             [PPNovaChatViewController pp_httpStatusDebugStringFromError:error]);
	                    LOG_WARN(@"[PPNovaChat] geminiProxy transient error (will retry once): %@", error.localizedDescription);
	                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	                        __strong typeof(weakSelf) inner = weakSelf;
	                        if (!inner || inner.dismissed) return;
	                        [inner pp_dispatchNovaRequest:trimmedText attempt:1 generation:generation requestID:requestID];
	                    });
                        return;
                    }
                    if (generation != self.novaRequestGeneration) {
                        return;
                    }
                    [self hideNovaTyping];

                    // ── Comprehensive failure diagnostics ──
                    NSString *authUID = PPCurrentFIRAuthUser.uid;
                    BOOL hasAuthUser = authUID.length > 0;
                    NSString *httpStatus = [PPNovaChatViewController pp_httpStatusDebugStringFromError:error];
                    NSArray<NSString *> *userInfoKeys = [PPNovaChatViewController pp_sortedDictionaryKeys:error.userInfo];

                    LOG_ERROR(@"[PPNovaChat] geminiProxy failed (attempt %ld, code=%ld, domain=%@): %@",
                              (long)attempt, (long)error.code, error.domain, error.localizedDescription);
                    LOG_ERROR(@"[PPNovaChat][Diagnostics] endpoint=%@ callable=%@ region=%@ authUserPresent=%@ appCheckConfigured=YES httpStatus=%@ userInfoKeys=%@",
                              [PPNovaChatViewController pp_novaCallableDebugURL],
                              PPNovaCallableName,
                              PPNovaCallableRegion,
                              hasAuthUser ? @"YES" : @"NO",
                              httpStatus ?: @"n/a",
                              userInfoKeys);
                    [PPAnalytics logNovaErrorWithCode:error.code
                                                domain:error.domain
                                               attempt:attempt
                                             sessionID:self.novaSessionId];

                    // If the server attached a structured reason, route to the right UX
                    // (sign-in for no_auth/no_profile; dedicated copy for blocked) instead
                    // of collapsing every auth-side failure into "session expired".
                NSString *serverReason = [PPNovaChatViewController pp_novaServerReasonFromError:error];
                if ([serverReason isEqualToString:@"no_auth"] ||
                    [serverReason isEqualToString:@"no_profile"]) {
                    LOG_WARN(@"[PPNovaChat][Debug] branch=auth_required reason=%@", serverReason);
                    [self pp_dismissNovaForSignInRequired];
                    return;
                }
                if ([serverReason isEqualToString:@"blocked"]) {
                    LOG_WARN(@"[PPNovaChat][Debug] branch=blocked_account reason=%@", serverReason);
                    [self pp_addNovaSystemBubbleIfNew:kLang(@"nova_error_account_blocked")];
                    return;
                }

                // Connectivity-class errors get a localized status message —
                // these are system events, not Nova "answering" a query. Show
                // them at most once per outage streak so the chat doesn't fill
                // up with identical "unavailable" bubbles when the user keeps
                // typing while the backend is down.
                NSString *userFacing = [PPNovaChatViewController pp_userFacingErrorForNovaError:error];
                if (userFacing.length > 0) {
                    NSString *branch = [userFacing isEqualToString:kLang(@"nova_error_unavailable")]
                        ? @"unavailable_connectivity_or_backend"
                        : @"auth_or_permission_error";
                    LOG_WARN(@"[PPNovaChat][Debug] branch=%@ code=%ld httpStatus=%@",
                             branch,
                             (long)error.code,
                             [PPNovaChatViewController pp_httpStatusDebugStringFromError:error]);
	                    // Only the connectivity bubble can be suppressed by a
	                    // successful local product showcase — auth/permission
	                    // errors must always surface so the user knows to re-auth.
	                    if ([userFacing isEqualToString:kLang(@"nova_error_unavailable")]) {
	                        NSString *responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"local_unavailable"];
	                        self.activeNovaResponseID = responseID;
	                        [self pp_logNovaIncomingObjects:@[] requestID:requestID responseID:responseID source:@"local_unavailable"];
	                        __weak typeof(self) localWeakSelf = self;
	                        [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
	                                                                introText:nil
	                                                                requestID:requestID
	                                                               responseID:responseID
	                                                               generation:generation
	                                                              completion:^(BOOL didShow) {
	                            __strong typeof(localWeakSelf) strongSelf = localWeakSelf;
	                            if (!strongSelf || strongSelf.dismissed) return;
	                            if (!didShow) {
	                                [strongSelf pp_addNovaSystemBubbleIfNew:userFacing];
	                            }
	                        }];
	                        return;
	                    }
	                    [self pp_addNovaSystemBubbleIfNew:userFacing];
	                    return;
	                }
	                // Anything else: try a local product showcase silently. No
	                // templated apology — if local search has no relevant items,
	                // the chat stays quiet rather than fabricating a Nova reply.
	                NSString *responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"local_error"];
	                self.activeNovaResponseID = responseID;
	                [self pp_logNovaIncomingObjects:@[] requestID:requestID responseID:responseID source:@"local_error"];
	                [self pp_fetchAndShowLocalNovaShowcaseForUserText:trimmedText
	                                                        introText:nil
	                                                        requestID:requestID
	                                                       responseID:responseID
	                                                       generation:generation
	                                                      completion:nil];
	                return;
	            }
	            if (generation != self.novaRequestGeneration) {
	                return;
	            }

	            NSString *replyText = nil;
	            NSString *serverAction = nil;
	            NSString *responseID = nil;
	            NSDictionary *responseData = nil;
	            NSArray<NSDictionary<NSString *, NSString *> *> *suggestionRefs = @[];
	            if ([result.data isKindOfClass:NSDictionary.class]) {
	                NSDictionary *data = (NSDictionary *)result.data;
	                responseData = data;
	                responseID = [self pp_novaResponseIDFromResponseData:data requestID:requestID source:@"server"];
	                self.activeNovaResponseID = responseID;
	                LOG_INFO(@"[PPNovaChat][Debug] responseKeys=%@ httpStatus=%@",
	                         [PPNovaChatViewController pp_sortedDictionaryKeys:data],
	                         @"n/a");
	                serverAction = [PPNovaChatViewController pp_novaBrainActionFromResponseData:data];
	                // Prefer the new canonical `assistantText` field; fall back to
	                // legacy `text` so older Cloud Function builds still work.
	                id assistantTextValue = data[@"assistantText"];
	                id textValue = data[@"text"];
	                if ([assistantTextValue isKindOfClass:NSString.class] &&
	                    [(NSString *)assistantTextValue length] > 0) {
	                    replyText = (NSString *)assistantTextValue;
	                } else if ([textValue isKindOfClass:NSString.class]) {
	                    replyText = (NSString *)textValue;
	                }
	                suggestionRefs = [self pp_novaSuggestionRefsFromResponseData:data replyText:replyText];
	                LOG_INFO(@"[PPNovaChat][Refs] received_from_server=%lu assistantTextChars=%lu",
	                         (unsigned long)suggestionRefs.count,
	                         (unsigned long)replyText.length);
	            } else {
	                responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"server_non_dictionary"];
	                self.activeNovaResponseID = responseID;
	                LOG_WARN(@"[PPNovaChat][Debug] branch=response_not_dictionary responseType=%@ httpStatus=%@",
	                         result.data ? NSStringFromClass([result.data class]) : @"nil",
	                         @"n/a");
	                suggestionRefs = [self pp_novaSuggestionRefsFromResponseData:nil replyText:replyText];
	            }
	            NSUInteger backendResultCount = [self pp_novaBackendResultCountFromResponseData:responseData];
	            NSUInteger backendResultRefsCount = [self pp_novaBackendResultRefsCountFromResponseData:responseData];
	            BOOL cardsRequired = [self pp_novaCardsRequiredFromResponseData:responseData
	                                                                 resultCount:backendResultCount
	                                                             resultRefsCount:backendResultRefsCount];
	            NSString *resultSource = [self pp_novaResultSourceFromResponseData:responseData];
	            BOOL mustRenderCells = cardsRequired || backendResultCount > 0 || suggestionRefs.count > 0;
	            [self pp_logNovaCellPayloadWithRequestID:requestID
	                                          responseID:responseID
	                                  backendResultCount:backendResultCount
	                               backendResultRefsCount:backendResultRefsCount
	                                    parsedResultRefs:suggestionRefs.count
	                                       cardsRequired:cardsRequired
	                                              source:resultSource];
	            [self pp_logNovaIncomingRefs:suggestionRefs requestID:requestID responseID:responseID source:@"server"];

	            replyText = [replyText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	            // Nova Brain clarification/response actions are terminal: render the
	            // reply and skip the local showcase fallback so unclear text never
	            // triggers product cards.
	            if ([serverAction isEqualToString:@"ASK_CLARIFICATION"] ||
	                [serverAction isEqualToString:@"RESPOND"]) {
	                if (mustRenderCells) {
	                    LOG_WARN(@"[PPNovaChat][Refs] terminal_action_has_result_payload action=%@ backend_result_count=%lu parsed_refs=%lu source=%@",
	                             serverAction ?: @"",
	                             (unsigned long)backendResultCount,
	                             (unsigned long)suggestionRefs.count,
	                             resultSource ?: @"unknown");
	                } else {
	                    [self hideNovaTyping];
	                    NSString *sanitizedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:YES];
	                    if (sanitizedReply.length > 0) {
	                        [self addNovaMessage:sanitizedReply requestID:requestID responseID:responseID];
	                    }
	                    return;
	                }
	            }
	            if (mustRenderCells && suggestionRefs.count == 0) {
	                [self pp_handleNovaCellRenderMissingWithRequestID:requestID
	                                                       responseID:responseID
	                                               backendResultCount:backendResultCount
	                                            backendResultRefsCount:backendResultRefsCount
	                                                 parsedResultRefs:0
	                                                     cellsCreated:0
	                                                           source:resultSource
	                                                           reason:@"parsed_refs_empty"];
	                return;
	            }
	            if (replyText.length == 0 && suggestionRefs.count == 0) {
	                [self hideNovaTyping];
	                LOG_WARN(@"[PPNovaChat][Debug] branch=empty_text_and_empty_products responseKeys=%@",
	                         [result.data isKindOfClass:NSDictionary.class]
	                            ? [PPNovaChatViewController pp_sortedDictionaryKeys:(NSDictionary *)result.data]
	                            : @[]);
	                LOG_WARN(@"[PPNovaChat] geminiProxy returned empty reply and no products; no previous local cards will be reused.");
	                if (hasCatalogIntent) {
	                    [self pp_addNovaProductResultTextForRenderedCount:0
	                                                         proposedText:nil
	                                                             userText:trimmedText
	                                                               source:@"server_empty_response"
	                                                            requestID:requestID
	                                                           responseID:responseID];
	                }
	                return;
	            }

	            NSString *suggestionFallbackText = nil;
	            NSString *pendingResolvedProductText = nil;
	            if (replyText.length > 0) {
	                NSString *sanitizedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:(suggestionRefs.count > 0)];
	                if (sanitizedReply.length > 0) {
	                    if ([self pp_novaReplyContainsNoProductClaim:sanitizedReply]) {
	                        if (suggestionRefs.count > 0) {
	                            pendingResolvedProductText = nil;
	                        } else {
	                            [self hideNovaTyping];
	                            [self addNovaMessage:sanitizedReply requestID:requestID responseID:responseID];
	                            return;
	                        }
	                    } else if (suggestionRefs.count > 0) {
	                        // Always use the server's AI reply alongside product cells.
	                        // The behavior layer already crafted a natural assistant message;
	                        // replacing it with a template silences the AI personality.
	                        pendingResolvedProductText = sanitizedReply;
	                    } else {
	                        [self hideNovaTyping];
	                        [self addNovaMessage:sanitizedReply requestID:requestID responseID:responseID];
	                        return;
	                    }
	                } else if (suggestionRefs.count == 0) {
	                    // Structured-strip emptied a reply that has no product refs.
	                    // Try the lighter strip (only [PRODUCT_ID:] tags) so the
	                    // model's actual answer survives. If even that is empty,
	                    // stay silent — never inject a templated apology on the
	                    // AI's behalf.
	                    NSString *unstrippedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO];
	                    if (unstrippedReply.length > 0) {
	                        [self hideNovaTyping];
	                        [self addNovaMessage:unstrippedReply requestID:requestID responseID:responseID];
	                        return;
	                    } else {
	                        [self hideNovaTyping];
	                        if (hasCatalogIntent) {
	                            [self pp_addNovaProductResultTextForRenderedCount:0
	                                                                 proposedText:nil
	                                                                     userText:trimmedText
	                                                                       source:@"server_text_stripped_empty"
	                                                                    requestID:requestID
	                                                                   responseID:responseID];
	                        }
	                        return;
	                    }
	                } else {
	                    suggestionFallbackText = pendingResolvedProductText ?: [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO];
	                }
	            }

	            if (suggestionRefs.count > 0) {
	                // No scripted fallback text — pass nil so the resolver only
	                // shows the AI's own reply (already added above) plus whatever
	                // products it can resolve. Templated apologies on resolution
	                // failure are gone.
	                [self pp_fetchAndShowNovaSuggestionRefs:suggestionRefs
	                                           fallbackText:pendingResolvedProductText ?: suggestionFallbackText
	                                               userText:trimmedText
	                                              requestID:requestID
	                                             responseID:responseID
	                                             generation:generation
	                                    backendResultCount:backendResultCount
	                                 backendResultRefsCount:backendResultRefsCount
	                                        cardsRequired:mustRenderCells
	                                          resultSource:resultSource];
	            } else {
	                [self hideNovaTyping];
	                if (hasCatalogIntent) {
	                    [self pp_addNovaProductResultTextForRenderedCount:0
	                                                         proposedText:nil
	                                                             userText:trimmedText
	                                                               source:@"server_no_refs"
	                                                            requestID:requestID
	                                                           responseID:responseID];
	                }
		            }
	        });
	    }];
	}

- (void)pp_handleNovaAgentProxyReply:(PPAgentMessage *)reply
                             userText:(NSString *)trimmedText
                            requestID:(NSString *)requestID
                   fallbackResponseID:(NSString *)fallbackResponseID
                           generation:(NSUInteger)generation {
    if (generation != self.novaRequestGeneration) {
        return;
    }

    NSDictionary *responseData = [reply.responseData isKindOfClass:NSDictionary.class] ? reply.responseData : nil;
    NSString *replyText = [reply.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *responseID = responseData
        ? [self pp_novaResponseIDFromResponseData:responseData requestID:requestID source:@"agent_proxy"]
        : (fallbackResponseID.length > 0 ? fallbackResponseID : [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"agent_proxy"]);
    self.activeNovaResponseID = responseID;

    NSArray<NSDictionary<NSString *, NSString *> *> *suggestionRefs =
        [self pp_novaSuggestionRefsFromResponseData:responseData replyText:replyText];
    NSUInteger backendResultCount = [self pp_novaBackendResultCountFromResponseData:responseData];
    NSUInteger backendResultRefsCount = [self pp_novaBackendResultRefsCountFromResponseData:responseData];
    BOOL cardsRequired = [self pp_novaCardsRequiredFromResponseData:responseData
                                                         resultCount:backendResultCount
                                                     resultRefsCount:backendResultRefsCount];
    NSString *resultSource = [self pp_novaResultSourceFromResponseData:responseData];
    BOOL mustRenderCells = cardsRequired || backendResultCount > 0 || suggestionRefs.count > 0;
    BOOL hasCatalogIntent = [self pp_novaHasCatalogSearchIntentForUserText:trimmedText];

    LOG_INFO(@"[PPNovaChat][AgentProxy] responseKeys=%@ assistantTextChars=%lu",
             responseData ? [PPNovaChatViewController pp_sortedDictionaryKeys:responseData] : @[],
             (unsigned long)replyText.length);
    [self pp_logNovaCellPayloadWithRequestID:requestID
                                  responseID:responseID
                          backendResultCount:backendResultCount
                       backendResultRefsCount:backendResultRefsCount
                            parsedResultRefs:suggestionRefs.count
                               cardsRequired:cardsRequired
                                      source:resultSource];
    [self pp_logNovaIncomingRefs:suggestionRefs requestID:requestID responseID:responseID source:@"agent_proxy"];

    if (mustRenderCells && suggestionRefs.count == 0) {
        [self pp_handleNovaCellRenderMissingWithRequestID:requestID
                                               responseID:responseID
                                       backendResultCount:backendResultCount
                                    backendResultRefsCount:backendResultRefsCount
                                         parsedResultRefs:0
                                             cellsCreated:0
                                                   source:resultSource
                                                   reason:@"agent_proxy_parsed_refs_empty"];
        return;
    }

    if (replyText.length == 0 && suggestionRefs.count == 0) {
        [self hideNovaTyping];
        if (hasCatalogIntent) {
            [self pp_addNovaProductResultTextForRenderedCount:0
                                                 proposedText:nil
                                                     userText:trimmedText
                                                       source:@"agent_proxy_empty_response"
                                                    requestID:requestID
                                                   responseID:responseID];
        }
        return;
    }

    NSString *pendingResolvedProductText = nil;
    NSString *suggestionFallbackText = nil;
    if (replyText.length > 0) {
        NSString *sanitizedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:(suggestionRefs.count > 0)];
        if (sanitizedReply.length > 0) {
            if ([self pp_novaReplyContainsNoProductClaim:sanitizedReply]) {
                if (suggestionRefs.count == 0) {
                    [self hideNovaTyping];
                    [self addNovaMessage:sanitizedReply requestID:requestID responseID:responseID];
                    return;
                }
            } else if (suggestionRefs.count > 0) {
                pendingResolvedProductText = [self pp_novaCardFocusedAssistantTextFromText:sanitizedReply];
            } else {
                [self hideNovaTyping];
                [self addNovaMessage:sanitizedReply requestID:requestID responseID:responseID];
                return;
            }
        } else if (suggestionRefs.count == 0) {
            NSString *unstrippedReply = [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO];
            [self hideNovaTyping];
            if (unstrippedReply.length > 0) {
                [self addNovaMessage:unstrippedReply requestID:requestID responseID:responseID];
            } else if (hasCatalogIntent) {
                [self pp_addNovaProductResultTextForRenderedCount:0
                                                     proposedText:nil
                                                         userText:trimmedText
                                                           source:@"agent_proxy_text_stripped_empty"
                                                        requestID:requestID
                                                       responseID:responseID];
            }
            return;
        } else {
            suggestionFallbackText = [self pp_novaCardFocusedAssistantTextFromText:
                                      [self pp_sanitizeNovaReply:replyText hideStructuredSuggestions:NO]];
        }
    }

    if (suggestionRefs.count > 0) {
        [self pp_fetchAndShowNovaSuggestionRefs:suggestionRefs
                                   fallbackText:pendingResolvedProductText ?: suggestionFallbackText
                                       userText:trimmedText
                                      requestID:requestID
                                     responseID:responseID
                                     generation:generation
                            backendResultCount:backendResultCount
                         backendResultRefsCount:backendResultRefsCount
                                cardsRequired:mustRenderCells
                                  resultSource:resultSource];
    } else {
        [self hideNovaTyping];
        if (hasCatalogIntent) {
            [self pp_addNovaProductResultTextForRenderedCount:0
                                                 proposedText:nil
                                                     userText:trimmedText
                                                       source:@"agent_proxy_no_refs"
                                                    requestID:requestID
                                                   responseID:responseID];
        }
    }
}

- (void)pp_startNovaRequestWatchdogForGeneration:(NSUInteger)generation userText:(NSString *)userText requestID:(NSString *)requestID {
    NSString *query = [userText copy] ?: @"";
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(35.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.dismissed || generation != self.novaRequestGeneration) {
            return;
        }
        if (self.typingContainer.alpha <= 0.01) {
            return;
        }

	        LOG_WARN(@"[PPNovaChat][Debug] branch=request_watchdog_timeout generation=%lu",
	                 (unsigned long)generation);
	        [self hideNovaTyping];
	        if ([self pp_novaHasCatalogSearchIntentForUserText:query] &&
	            ![self pp_novaIsGenericConversationText:query]) {
	            NSString *responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"local_watchdog"];
	            self.activeNovaResponseID = responseID;
	            [self pp_logNovaIncomingObjects:@[] requestID:requestID responseID:responseID source:@"local_watchdog"];
	            [self pp_fetchAndShowLocalNovaShowcaseForUserText:query
	                                                    introText:nil
	                                                    requestID:requestID
	                                                   responseID:responseID
	                                                   generation:generation
	                                                   completion:^(BOOL didShow) {
	                if (!didShow) {
	                    [self pp_addNovaSystemBubbleIfNew:kLang(@"nova_error_unavailable")];
	                }
	            }];
	        } else {
	            [self pp_addNovaSystemBubbleIfNew:kLang(@"nova_error_unavailable")];
	        }
    });
}

+ (NSString *)pp_novaCallableDebugURL {
    return [NSString stringWithFormat:@"https://%@-%@.cloudfunctions.net/%@",
            PPNovaCallableRegion,
            PPNovaFirebaseProjectID,
            PPNovaCallableName];
}

+ (NSArray<NSString *> *)pp_sortedDictionaryKeys:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class] || dictionary.count == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *keys = [NSMutableArray arrayWithCapacity:dictionary.count];
    for (id key in dictionary.allKeys) {
        NSString *keyString = [key isKindOfClass:NSString.class] ? key : [key description];
        if (keyString.length > 0) {
            [keys addObject:keyString];
        }
    }
    [keys sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return keys.copy;
}

+ (nullable NSString *)pp_novaBrainActionFromResponseData:(NSDictionary *)data {
    if (![data isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id action = data[@"action"];
    if ([action isKindOfClass:NSString.class] && [(NSString *)action length] > 0) {
        return (NSString *)action;
    }
    id brain = data[@"novaBrain"];
    if ([brain isKindOfClass:NSDictionary.class]) {
        id nestedAction = ((NSDictionary *)brain)[@"action"];
        if ([nestedAction isKindOfClass:NSString.class] && [(NSString *)nestedAction length] > 0) {
            return (NSString *)nestedAction;
        }
    }
    return nil;
}

+ (NSString *)pp_httpStatusDebugStringFromError:(NSError *)error {
    if (!error) {
        return @"n/a";
    }

    id directStatus = error.userInfo[@"status"] ?: error.userInfo[@"httpStatus"] ?: error.userInfo[@"HTTPStatus"];
    if ([directStatus respondsToSelector:@selector(stringValue)]) {
        return [directStatus stringValue];
    }

    for (id key in error.userInfo.allKeys) {
        NSString *keyString = [[key description] lowercaseString];
        if (![keyString containsString:@"status"] && ![keyString containsString:@"http"]) {
            continue;
        }
        id value = error.userInfo[key];
        if ([value isKindOfClass:NSHTTPURLResponse.class]) {
            return [NSString stringWithFormat:@"%ld", (long)[(NSHTTPURLResponse *)value statusCode]];
        }
        if ([value respondsToSelector:@selector(stringValue)]) {
            return [value stringValue];
        }
        if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
            return value;
        }
    }

    return @"n/a";
}

+ (BOOL)pp_isRetryableNovaError:(NSError *)error {
    // Retry on transient gRPC codes (Unknown=2, DeadlineExceeded=4, ResourceExhausted=8,
    // Internal=13, Unavailable=14) and on raw network errors.
    NSInteger code = error.code;
    if (code == 2 || code == 4 || code == 8 || code == 13 || code == 14) return YES;
    if ([error.domain isEqualToString:NSURLErrorDomain]) return YES;
    return NO;
}

+ (nullable NSString *)pp_userFacingErrorForNovaError:(NSError *)error {
    // Map specific error classes to localized user-facing strings. Returning nil means
    // "fall through to the generic local fallback" — used for unknown / handled-elsewhere cases.
    NSInteger code = error.code;
    // Unauthenticated=16, PermissionDenied=7 — surface as session-expired.
    if (code == 16 || code == 7) {
        return kLang(@"nova_error_auth");
    }
    // Unavailable=14 / ResourceExhausted=8 after retry exhausted — be honest, don't pretend.
    if (code == 14 || code == 8) {
        return kLang(@"nova_error_unavailable");
    }
    return nil;
}

// Reads geminiProxy's `details.reason` ({"no_auth","no_profile","blocked"}) so the
// client can route auth-side failures to the right UX. The Functions iOS SDK
// stores the HttpsError details under userInfo[@"details"].
+ (nullable NSString *)pp_novaServerReasonFromError:(NSError *)error {
    if (error.code != 7 && error.code != 16) {
        return nil;
    }
    id details = error.userInfo[@"details"];
    if (![details isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    id reason = ((NSDictionary *)details)[@"reason"];
    return [reason isKindOfClass:NSString.class] ? (NSString *)reason : nil;
}

// Dismiss Nova and re-trigger the standard sign-in flow. Used when the server
// reports the caller is not authenticated (or has no UsersCol profile yet).
- (void)pp_dismissNovaForSignInRequired {
    UIViewController *presenter = self.presentingViewController;
    NSString *signInMessage = kLang(@"nova_error_signin_required");
    [self dismissViewControllerAnimated:YES completion:^{
        UIViewController *target = presenter ?: [UIApplication sharedApplication].delegate.window.rootViewController;
        if (!target) return;
        [PPUserSigningManager requireSignInFrom:target
                                    withMessage:signInMessage
                                        success:^(UserModel * _Nonnull user) {
                                            if (user) {
                                                [PPNovaChatViewController presentNovaFromViewController:target];
                                            }
                                        }
                                      cancelled:nil];
    }];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaSuggestionRefsFromResponseData:(NSDictionary *)data
                                                                                 replyText:(NSString *)replyText
{
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *refs = [NSMutableArray array];

    if ([data isKindOfClass:NSDictionary.class]) {
        NSDictionary<NSString *, NSString *> *keyKinds = @{
            @"productIDs": @"product", @"productIds": @"product", @"product_ids": @"product",
            @"accessoryIDs": @"product", @"accessoryIds": @"product", @"itemIDs": @"product",
            @"medicineIDs": @"medicine", @"medicineIds": @"medicine", @"medicine_ids": @"medicine",
            @"serviceIDs": @"service", @"serviceIds": @"service", @"service_ids": @"service",
            @"petAdIDs": @"pet_ad", @"petAdIds": @"pet_ad", @"pet_ad_ids": @"pet_ad",
            @"adIDs": @"pet_ad", @"adIds": @"pet_ad", @"ad_ids": @"pet_ad",
            @"adoptPetIDs": @"adoption", @"adoptPetIds": @"adoption", @"adopt_pet_ids": @"adoption",
            @"adoptionIDs": @"adoption", @"adoptionIds": @"adoption", @"adoption_ids": @"adoption",
            @"vetIDs": @"vet", @"vetIds": @"vet", @"vet_ids": @"vet",
            @"veterinarianIDs": @"vet", @"veterinarianIds": @"vet", @"veterinarian_ids": @"vet"
        };
        [keyKinds enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *kind, BOOL *stop) {
            [self pp_appendNovaSuggestionRefsFromIDs:data[key] kind:kind toRefs:refs];
        }];

        [self pp_appendNovaSuggestionRefsFromResultSet:data[@"result_set"] toRefs:refs];

        NSString *payloadKind = [self pp_novaSuggestionKindForResultSetSource:[self pp_novaResultSourceFromResponseData:data]];
        NSDictionary<NSString *, NSString *> *arrayKeyKinds = @{
            @"suggestions": @"", @"recommendations": @"", @"results": @"",
            @"resultRefs": @"", @"result_refs": @"",
            @"products": payloadKind.length > 0 ? payloadKind : @"product",
            @"items": payloadKind.length > 0 ? payloadKind : @"product",
            @"services": @"service", @"medicines": @"medicine",
            @"petAds": @"pet_ad", @"pet_ads": @"pet_ad",
            @"adoptions": @"adoption", @"adoptPets": @"adoption", @"adopt_pets": @"adoption",
            @"vets": @"vet", @"veterinarians": @"vet"
        };
        [arrayKeyKinds enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *kind, BOOL *stop) {
            [self pp_appendNovaSuggestionRefsFromValue:data[key]
                                                toRefs:refs
                                         preferredKind:(kind.length > 0 ? kind : nil)];
        }];
    }

    if (replyText.length > 0) {
        LOG_INFO(@"[PPNovaChat][Refs] text-ref fallback disabled; refs must come from structured payload.");
    }
    return [self pp_uniqueNovaSuggestionRefs:refs];
}

- (void)pp_appendNovaSuggestionRefsFromResultSet:(id)value
                                          toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
{
    if (![value isKindOfClass:NSDictionary.class]) {
        return;
    }
    NSDictionary *resultSet = (NSDictionary *)value;
    NSArray *items = [resultSet[@"items"] isKindOfClass:NSArray.class] ? resultSet[@"items"] : @[];
    NSString *setSource = [self pp_novaStringFromValue:resultSet[@"source"]];
    for (id entry in items) {
        if (![entry isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *item = (NSDictionary *)entry;
        NSString *identifier = [self pp_novaStringFromDictionary:item keys:@[@"id", @"documentID", @"documentId", @"docID", @"docId", @"itemID", @"itemId"]];
        NSString *displayName = [self pp_novaResultDisplayNameFromDictionary:item];
        NSString *source = [self pp_novaStringFromValue:item[@"source"]];
        if (source.length == 0) {
            source = setSource;
        }
        if (identifier.length == 0 || displayName.length == 0 || [self pp_novaResultDisplayNameLooksGeneric:displayName]) {
            LOG_WARN(@"NOVA_INVALID_RESULT_METADATA source=%@ id=%@ reason=%@",
                     source ?: @"",
                     identifier ?: @"",
                     identifier.length == 0 ? @"missing_id" : @"missing_displayName");
            continue;
        }
        NSString *preferredKind = [self pp_novaSuggestionKindForResultSetSource:source];
        NSString *kind = [self pp_novaSuggestionKindFromDictionary:item preferredKind:preferredKind];
        if (kind.length > 0 && identifier.length > 0) {
            [refs addObject:@{@"kind": kind, @"id": identifier}];
        }
    }
}

- (NSString *)pp_novaSuggestionKindForResultSetSource:(NSString *)source {
    NSString *raw = [[self pp_novaStringFromValue:source] lowercaseString];
    if ([raw containsString:@"services"] || [raw containsString:@"serviceoffers"] || [raw isEqualToString:@"service"]) {
        return @"service";
    }
    if ([raw containsString:@"veterinarian"] || [raw isEqualToString:@"vets"] || [raw isEqualToString:@"vet"]) {
        return @"vet";
    }
    if ([raw containsString:@"pet_ads"] || [raw isEqualToString:@"ads"] || [raw isEqualToString:@"pet_ad"]) {
        return @"pet_ad";
    }
    if ([raw containsString:@"adopt_pets"] || [raw containsString:@"adoption"]) {
        return @"adoption";
    }
    if ([raw containsString:@"medicine"]) {
        return @"medicine";
    }
    return @"product";
}

- (NSString *)pp_novaResultDisplayNameFromDictionary:(NSDictionary *)dict {
    return [self pp_novaStringFromDictionary:dict keys:@[@"displayName", @"title", @"name", @"name_ar"]];
}

- (BOOL)pp_novaResultDisplayNameLooksGeneric:(NSString *)displayName {
    NSString *normalized = [[[displayName lowercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    NSSet<NSString *> *generic = [NSSet setWithArray:@[@"service", @"خدمة", @"clinic", @"عيادة", @"pet ad", @"إعلان", @"اعلان", @"adoptable pet", @"للتبني", @"product", @"منتج", @"item"]];
    return [generic containsObject:normalized];
}

- (void)pp_appendNovaSuggestionRefsFromIDs:(id)value
                                      kind:(NSString *)kind
                                    toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
{
    if (kind.length == 0) {
        return;
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in (NSArray *)value) {
            NSString *identifier = [self pp_novaStringFromValue:entry];
            if (identifier.length > 0) {
                [refs addObject:@{@"kind": kind, @"id": identifier}];
            }
        }
        return;
    }
    NSString *identifier = [self pp_novaStringFromValue:value];
    if (identifier.length > 0) {
        [refs addObject:@{@"kind": kind, @"id": identifier}];
    }
}

- (void)pp_appendNovaSuggestionRefsFromValue:(id)value
                                      toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
                               preferredKind:(NSString *)preferredKind
{
    if (!value) {
        return;
    }
    if ([value isKindOfClass:NSArray.class]) {
        for (id entry in (NSArray *)value) {
            [self pp_appendNovaSuggestionRefsFromValue:entry toRefs:refs preferredKind:preferredKind];
        }
        return;
    }
    if ([value isKindOfClass:NSDictionary.class]) {
        NSDictionary *dict = (NSDictionary *)value;
        NSString *kind = [self pp_novaSuggestionKindFromDictionary:dict preferredKind:preferredKind];
        NSString *identifier = [self pp_novaSuggestionIdentifierFromDictionary:dict kind:kind];
        if (kind.length > 0 && identifier.length > 0) {
            [refs addObject:@{@"kind": kind, @"id": identifier}];
        }
        return;
    }
    if (preferredKind.length > 0) {
        NSString *identifier = [self pp_novaStringFromValue:value];
        if (identifier.length > 0) {
            [refs addObject:@{@"kind": preferredKind, @"id": identifier}];
        }
    }
}

- (NSString *)pp_novaSuggestionKindFromDictionary:(NSDictionary *)dict preferredKind:(NSString *)preferredKind {
    if ([self pp_novaStringFromDictionary:dict keys:@[@"petAdID", @"petAdId", @"pet_ad_id", @"adID", @"adId", @"ad_id"]].length > 0) {
        return @"pet_ad";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"adoptPetID", @"adoptPetId", @"adopt_pet_id", @"adoptionID", @"adoptionId", @"adoption_id"]].length > 0) {
        return @"adoption";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"serviceID", @"serviceId", @"service_id"]].length > 0) {
        return @"service";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"vetID", @"vetId", @"vet_id", @"veterinarianID", @"veterinarianId", @"veterinarian_id"]].length > 0) {
        return @"vet";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"medicineID", @"medicineId", @"medicine_id"]].length > 0) {
        return @"medicine";
    }
    if ([self pp_novaStringFromDictionary:dict keys:@[@"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"]].length > 0) {
        return @"product";
    }

    id rawKindValue = dict[@"kind"] ?: dict[@"itemType"] ?: dict[@"collection"] ?: dict[@"collectionName"] ?: dict[@"source"] ?: dict[@"resultSource"] ?: dict[@"type"];
    NSString *rawKind = [[self pp_novaStringFromValue:rawKindValue] lowercaseString];
    if ([rawKind containsString:@"pet_ad"] || [rawKind containsString:@"pet ad"] ||
        [rawKind containsString:@"pet_ads"] || [rawKind isEqualToString:@"ads"]) {
        return @"pet_ad";
    }
    if ([rawKind containsString:@"adoption"] || [rawKind containsString:@"adopt"] ||
        [rawKind containsString:@"adopt_pets"]) {
        return @"adoption";
    }
    if ([rawKind containsString:@"service"]) {
        return @"service";
    }
    if ([rawKind containsString:@"vet"] || [rawKind containsString:@"veterinarian"]) {
        return @"vet";
    }
    if ([rawKind containsString:@"medicine"] || [rawKind containsString:@"medic"] || [rawKind containsString:@"pharmacy"]) {
        return @"medicine";
    }
    if ([rawKind containsString:@"product"] || [rawKind containsString:@"accessory"] || [rawKind containsString:@"petaccessor"]) {
        return @"product";
    }

    id accessKindValue = dict[@"accessKindType"] ?: dict[@"access_kind_type"] ?: dict[@"type"];
    if ([accessKindValue respondsToSelector:@selector(integerValue)] &&
        [accessKindValue integerValue] == AccessTypePetMedicine) {
        return @"medicine";
    }
    return preferredKind.length > 0 ? preferredKind : @"product";
}

- (NSString *)pp_novaSuggestionIdentifierFromDictionary:(NSDictionary *)dict kind:(NSString *)kind {
    NSArray<NSString *> *primaryKeys = @[@"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"];
    if ([kind isEqualToString:@"service"]) {
        primaryKeys = @[@"serviceID", @"serviceId", @"service_id"];
    } else if ([kind isEqualToString:@"vet"]) {
        primaryKeys = @[@"vetID", @"vetId", @"vet_id", @"veterinarianID", @"veterinarianId", @"veterinarian_id"];
    } else if ([kind isEqualToString:@"pet_ad"]) {
        primaryKeys = @[@"petAdID", @"petAdId", @"pet_ad_id", @"adID", @"adId", @"ad_id", @"productID", @"productId", @"product_id"];
    } else if ([kind isEqualToString:@"adoption"]) {
        primaryKeys = @[@"adoptPetID", @"adoptPetId", @"adopt_pet_id", @"adoptionID", @"adoptionId", @"adoption_id", @"productID", @"productId", @"product_id"];
    } else if ([kind isEqualToString:@"medicine"]) {
        primaryKeys = @[@"medicineID", @"medicineId", @"medicine_id", @"productID", @"productId", @"product_id", @"accessoryID", @"accessoryId", @"accessory_id"];
    }
    NSString *identifier = [self pp_novaStringFromDictionary:dict keys:primaryKeys];
    if (identifier.length > 0) {
        return identifier;
    }
    return [self pp_novaStringFromDictionary:dict keys:@[@"id", @"documentID", @"documentId", @"docID", @"docId", @"itemID", @"itemId"]];
}

- (NSString *)pp_novaStringFromDictionary:(NSDictionary *)dict keys:(NSArray<NSString *> *)keys {
    for (NSString *key in keys) {
        NSString *value = [self pp_novaStringFromValue:dict[key]];
        if (value.length > 0) {
            return value;
        }
    }
    return @"";
}

- (NSString *)pp_novaStringFromValue:(id)value {
    if ([value isKindOfClass:NSString.class]) {
        return [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [[value stringValue] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return @"";
}

- (void)pp_appendNovaSuggestionRefsFromText:(NSString *)text
                                     toRefs:(NSMutableArray<NSDictionary<NSString *, NSString *> *> *)refs
{
    if (text.length == 0) {
        return;
    }
    NSArray<NSDictionary<NSString *, NSString *> *> *patterns = @[
        @{@"kind": @"product", @"pattern": @"\\[PRODUCT_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"service", @"pattern": @"\\[SERVICE_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"medicine", @"pattern": @"\\[MEDICINE_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"pet_ad", @"pattern": @"\\[PET_AD_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"pet_ad", @"pattern": @"\\[AD_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"adoption", @"pattern": @"\\[ADOPTION_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"adoption", @"pattern": @"\\[ADOPT_PET_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"vet", @"pattern": @"\\[VET_ID:\\s*([^\\]]+)\\]"},
        @{@"kind": @"vet", @"pattern": @"\\[VETERINARIAN_ID:\\s*([^\\]]+)\\]"}
    ];
    for (NSDictionary<NSString *, NSString *> *entry in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:entry[@"pattern"]
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (!regex) {
            continue;
        }
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges < 2) {
                continue;
            }
            NSString *identifier = [[text substringWithRange:[match rangeAtIndex:1]]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (identifier.length > 0) {
                [refs addObject:@{@"kind": entry[@"kind"], @"id": identifier}];
            }
        }
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_uniqueNovaSuggestionRefs:(NSArray<NSDictionary<NSString *, NSString *> *> *)refs {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *ordered = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary<NSString *, NSString *> *ref in refs) {
        NSString *kind = ref[@"kind"];
        NSString *identifier = [self pp_normalizedNovaSuggestionIdentifier:ref[@"id"]];
        if (kind.length == 0 || identifier.length == 0) {
            continue;
        }
        NSString *key = [NSString stringWithFormat:@"%@:%@", kind, identifier];
        if ([seen containsObject:key]) {
            continue;
        }
        [seen addObject:key];
        [ordered addObject:@{@"kind": kind, @"id": identifier}];
    }
    return ordered.copy;
}

- (NSString *)pp_normalizedNovaSuggestionIdentifier:(NSString *)identifier {
    NSString *normalized = [identifier isKindOfClass:NSString.class]
        ? [identifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
        : @"";
    if (normalized.length == 0) {
        return @"";
    }

    NSString *pathless = normalized.lastPathComponent;
    if (pathless.length > 0 &&
        ([normalized containsString:@"/petAccessories/"] ||
         [normalized containsString:@"/serviceOffers/"] ||
         [normalized containsString:@"/veterinarians/"] ||
         [normalized containsString:@"/pet_ads/"] ||
         [normalized containsString:@"/adopt_pets/"] ||
         [normalized hasPrefix:@"petAccessories/"] ||
         [normalized hasPrefix:@"serviceOffers/"] ||
         [normalized hasPrefix:@"veterinarians/"] ||
         [normalized hasPrefix:@"pet_ads/"] ||
         [normalized hasPrefix:@"adopt_pets/"])) {
        normalized = pathless;
    }

    return [normalized stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)pp_fetchAndShowNovaSuggestionRefs:(NSArray<NSDictionary<NSString *, NSString *> *> *)refs
                             fallbackText:(NSString *)fallbackText
                                 userText:(NSString *)userText
                                requestID:(NSString *)requestID
                               responseID:(NSString *)responseID
                               generation:(NSUInteger)generation
                        backendResultCount:(NSUInteger)backendResultCount
                     backendResultRefsCount:(NSUInteger)backendResultRefsCount
                             cardsRequired:(BOOL)cardsRequired
                               resultSource:(NSString *)resultSource {
    if (refs.count == 0) {
        if (cardsRequired || backendResultCount > 0) {
            [self pp_handleNovaCellRenderMissingWithRequestID:requestID
                                                   responseID:responseID
                                           backendResultCount:backendResultCount
                                        backendResultRefsCount:backendResultRefsCount
                                             parsedResultRefs:0
                                                 cellsCreated:0
                                                       source:resultSource ?: @"server"
                                                       reason:@"resolver_called_without_refs"];
        }
        return;
    }

    NSMutableArray<NSString *> *accessoryIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *serviceIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *petAdIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *adoptionIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *vetIDs = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *ref in refs) {
        NSString *kind = ref[@"kind"];
        NSString *identifier = ref[@"id"];
        if (identifier.length == 0) {
            continue;
        }
        if ([kind isEqualToString:@"service"]) {
            [serviceIDs addObject:identifier];
        } else if ([kind isEqualToString:@"vet"]) {
            [vetIDs addObject:identifier];
        } else if ([kind isEqualToString:@"pet_ad"]) {
            [petAdIDs addObject:identifier];
        } else if ([kind isEqualToString:@"adoption"]) {
            [adoptionIDs addObject:identifier];
        } else {
            [accessoryIDs addObject:identifier];
        }
    }

    dispatch_group_t group = dispatch_group_create();
    __block NSArray<PetAccessory *> *resolvedAccessories = @[];
    __block NSArray<ServiceModel *> *resolvedServices = @[];
    __block NSArray<PetAd *> *resolvedPetAds = @[];
    __block NSArray<AdoptPetModel *> *resolvedAdoptions = @[];
    __block NSArray<VetModel *> *resolvedVets = @[];
    __block BOOL didFinish = NO;

    if (accessoryIDs.count > 0) {
        dispatch_group_enter(group);
        [PetAccessoryManager fetchAccessoriesWithIDs:accessoryIDs completion:^(NSArray<PetAccessory *> * _Nonnull accessories) {
            resolvedAccessories = accessories ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (serviceIDs.count > 0) {
        dispatch_group_enter(group);
        [self pp_fetchNovaServicesWithIDs:serviceIDs completion:^(NSArray<ServiceModel *> *services) {
            resolvedServices = services ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (vetIDs.count > 0) {
        dispatch_group_enter(group);
        [self pp_fetchNovaVetsWithIDs:vetIDs completion:^(NSArray<VetModel *> *vets) {
            resolvedVets = vets ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (petAdIDs.count > 0) {
        dispatch_group_enter(group);
        [PetAdManager fetchAdsWithIDs:petAdIDs completion:^(NSArray<PetAd *> *ads) {
            resolvedPetAds = ads ?: @[];
            dispatch_group_leave(group);
        }];
    }

    if (adoptionIDs.count > 0) {
        dispatch_group_enter(group);
        [AdoptPetManager.shared fetchPetsWithIDs:adoptionIDs completion:^(NSArray<AdoptPetModel *> * _Nullable pets, NSError * _Nullable error) {
            if (error) {
                LOG_WARN(@"[PPNovaChat][Refs] adoption resolution error=%@", error.localizedDescription);
            }
            resolvedAdoptions = pets ?: @[];
            dispatch_group_leave(group);
        }];
    }

    __weak typeof(self) weakSelf = self;
	    void (^finish)(BOOL timedOut) = ^(BOOL timedOut) {
	        __strong typeof(weakSelf) self = weakSelf;
	        if (didFinish || !self || self.dismissed) {
	            return;
	        }
	        didFinish = YES;
	        if (![self pp_canAttachNovaRenderForRequestID:requestID
	                                           responseID:responseID
	                                           generation:generation
	                                               source:@"server_resolution"]) {
	            return;
	        }

	        if (timedOut) {
	            LOG_WARN(@"[PPNovaChat] Nova suggestion resolution timed out: %@", refs);
        }

        [self hideNovaTyping];

        NSDictionary<NSString *, PetAccessory *> *accessoriesByID = [self pp_novaAccessoriesByID:resolvedAccessories];
        NSDictionary<NSString *, ServiceModel *> *servicesByID = [self pp_novaServicesByID:resolvedServices];
        NSDictionary<NSString *, PetAd *> *petAdsByID = [self pp_novaPetAdsByID:resolvedPetAds];
        NSDictionary<NSString *, AdoptPetModel *> *adoptionsByID = [self pp_novaAdoptionsByID:resolvedAdoptions];
        NSDictionary<NSString *, VetModel *> *vetsByID = [self pp_novaVetsByID:resolvedVets];
        NSMutableArray *objects = [NSMutableArray array];
        for (NSDictionary<NSString *, NSString *> *ref in refs) {
            NSString *identifier = ref[@"id"];
            NSString *kind = ref[@"kind"];
            id object = nil;
            if ([kind isEqualToString:@"service"]) {
                object = servicesByID[identifier];
            } else if ([kind isEqualToString:@"vet"]) {
                object = vetsByID[identifier];
            } else if ([kind isEqualToString:@"pet_ad"]) {
                object = petAdsByID[identifier];
            } else if ([kind isEqualToString:@"adoption"]) {
                object = adoptionsByID[identifier];
            } else {
                object = accessoriesByID[identifier];
            }
            if (object) {
                [objects addObject:object];
            }
        }

        // Per Nova architecture rules: card-resolution failure must NEVER
        // swallow the assistant's natural text. If Nova said something and we
        // simply can't resolve the IDs, the customer still gets her words.
        // Telemetry counts what we received vs. resolved so we can see
        // unresolved IDs in production logs.
        NSUInteger requestedCount = refs.count;
        NSUInteger resolvedCount = objects.count;
        NSUInteger unresolvedCount = (requestedCount > resolvedCount) ? (requestedCount - resolvedCount) : 0;
        BOOL hasAssistantText = fallbackText.length > 0;
        LOG_INFO(@"[PPNovaChat][Refs] received=%lu resolved=%lu unresolved=%lu assistantTextChars=%lu",
                 (unsigned long)requestedCount,
                 (unsigned long)resolvedCount,
                 (unsigned long)unresolvedCount,
                 (unsigned long)fallbackText.length);

        if (objects.count == 0) {
            LOG_WARN(@"[PPNovaChat] Nova returned %lu suggestion ref(s) but none resolved: %@",
                     (unsigned long)refs.count, refs);

            [PPAnalytics logNovaShowcaseResolutionFailedWithRequestedCount:refs.count
                                                              resolvedCount:0
                                                                  sessionID:self.novaSessionId];

	            // Resolution failed. Preserve Nova's text, but do not substitute
	            // any previous local card payload for this response.
	            if (cardsRequired || backendResultCount > 0) {
	                [self pp_handleNovaCellRenderMissingWithRequestID:requestID
	                                                       responseID:responseID
	                                               backendResultCount:backendResultCount
	                                            backendResultRefsCount:backendResultRefsCount
	                                                 parsedResultRefs:refs.count
	                                                     cellsCreated:0
	                                                           source:resultSource ?: @"server"
	                                                           reason:@"resolution_empty"];
	            } else if (hasAssistantText) {
	                [self pp_addNovaProductResultTextForRenderedCount:0
	                                                     proposedText:fallbackText
	                                                         userText:userText
	                                                           source:@"server_resolution_empty_assistantText_preserved"
	                                                        requestID:requestID
	                                                       responseID:responseID];
	            } else if ([self pp_novaHasCatalogSearchIntentForUserText:userText]) {
	                [self pp_addNovaProductResultTextForRenderedCount:0
	                                                     proposedText:nil
	                                                         userText:userText
	                                                           source:@"server_resolution_empty"
	                                                        requestID:requestID
	                                                       responseID:responseID];
	            }
	            return;
	        }

        // Resolved-IDs telemetry per spec — every server-resolution turn logs
        // received vs. resolved vs. unresolved IDs and the source/type used,
        // plus whether assistantText was shown alongside the cards.
        NSMutableDictionary<NSString *, NSNumber *> *typeCounts = [NSMutableDictionary dictionary];
        for (NSDictionary<NSString *, NSString *> *ref in refs) {
            NSString *typeKey = ref[@"kind"].length > 0 ? ref[@"kind"] : @"product";
            typeCounts[typeKey] = @(typeCounts[typeKey].integerValue + 1);
        }
        LOG_INFO(@"[PPNovaChat][Refs] success received=%lu resolved=%lu unresolved=%lu typeCounts=%@ assistantTextRendered=%@",
                 (unsigned long)refs.count,
                 (unsigned long)objects.count,
                 (unsigned long)((refs.count > objects.count) ? (refs.count - objects.count) : 0),
                 typeCounts,
                 fallbackText.length > 0 ? @"YES" : @"NO");
        LOG_INFO(@"NOVA_CELL_RENDER_RESULT request_id=%@ response_id=%@ backend_result_count=%lu resultRefs_count=%lu parsed_resultRefs_count=%lu cells_created=%lu source=%@ message_type=%@ universalCell=YES",
                 requestID ?: @"",
                 responseID ?: @"",
                 (unsigned long)backendResultCount,
                 (unsigned long)backendResultRefsCount,
                 (unsigned long)refs.count,
                 (unsigned long)objects.count,
                 resultSource ?: @"server",
                 objects.count > 1 ? @"ChatMessageTypeNovaProductList" : @"ChatMessageTypeNovaProduct");

	        [self pp_addNovaProductResultTextForRenderedCount:objects.count
	                                             proposedText:fallbackText
	                                                 userText:userText
	                                                   source:@"server"
	                                                requestID:requestID
	                                               responseID:responseID];
	        [self pp_showNovaSuggestionObjects:objects
	                                    source:@"server"
	                                 requestID:requestID
	                                responseID:responseID
	                                generation:generation];

        // Save the synthetic product marker to local memory so context is retained
        NSInteger n = (NSInteger)objects.count;
        NSMutableArray *names = [NSMutableArray array];
        for (NSInteger pidx = 0; pidx < MIN(n, 4); pidx++) {
            NSString *name = [self pp_novaDisplayNameForSuggestionObject:objects[pidx]];
            if (name.length > 0) [names addObject:name];
        }
        if (names.count > 0) {
            NSString *marker = [NSString stringWithFormat:@"[Nova showed %ld product%@: %@]",
                                (long)n, n == 1 ? @"" : @"s",
                                [names componentsJoinedByString:@", "]];
            [[PPNovaLocalChatMemory sharedMemory] addMessageWithRole:@"nova" text:marker];
        }
    };

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        finish(YES);
    });

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        finish(NO);
    });
}

- (void)pp_fetchNovaServicesWithIDs:(NSArray<NSString *> *)serviceIDs
                         completion:(void (^)(NSArray<ServiceModel *> *services))completion
{
    if (serviceIDs.count == 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSMutableArray<ServiceModel *> *results = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    for (NSString *serviceID in serviceIDs) {
        if (serviceID.length == 0) {
            continue;
        }
        dispatch_group_enter(group);
        [[[db collectionWithPath:@"serviceOffers"] documentWithPath:serviceID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable doc, NSError * _Nullable error) {
            if (doc.exists && doc.data) {
                ServiceModel *model = [[ServiceModel alloc] initWithDictionary:doc.data documentID:doc.documentID];
                if (model.isLive) {
                    @synchronized (results) {
                        [results addObject:model];
                    }
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion(results.copy);
    });
}

- (void)pp_fetchNovaVetsWithIDs:(NSArray<NSString *> *)vetIDs
                     completion:(void (^)(NSArray<VetModel *> *vets))completion
{
    if (vetIDs.count == 0) {
        if (completion) completion(@[]);
        return;
    }

    FIRFirestore *db = [FIRFirestore firestore];
    NSMutableArray<VetModel *> *results = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    for (NSString *vetID in vetIDs) {
        if (vetID.length == 0) {
            continue;
        }
        dispatch_group_enter(group);
        [[[db collectionWithPath:@"veterinarians"] documentWithPath:vetID]
         getDocumentWithCompletion:^(FIRDocumentSnapshot * _Nullable doc, NSError * _Nullable error) {
            if (doc.exists && doc.data) {
                VetModel *model = [VetModel fromDictionary:doc.data withID:doc.documentID];
                if ([self pp_novaVetIsListable:model]) {
                    @synchronized (results) {
                        [results addObject:model];
                    }
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) completion(results.copy);
    });
}

- (BOOL)pp_novaVetIsListable:(VetModel *)vet
{
    if (![vet isKindOfClass:VetModel.class] || vet.isDisabled) {
        return NO;
    }
    NSString *status = [vet.verificationStatus.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (status.length == 0) {
        return YES;
    }
    return [@[@"approved", @"active", @"verified"] containsObject:status];
}

- (NSDictionary<NSString *, PetAccessory *> *)pp_novaAccessoriesByID:(NSArray<PetAccessory *> *)accessories {
    NSMutableDictionary<NSString *, PetAccessory *> *map = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        if (![item isKindOfClass:PetAccessory.class] || item.accessoryID.length == 0) {
            continue;
        }
        map[item.accessoryID] = item;
    }
    return map.copy;
}

- (NSDictionary<NSString *, ServiceModel *> *)pp_novaServicesByID:(NSArray<ServiceModel *> *)services {
    NSMutableDictionary<NSString *, ServiceModel *> *map = [NSMutableDictionary dictionary];
    for (ServiceModel *service in services) {
        if (![service isKindOfClass:ServiceModel.class] || service.serviceID.length == 0) {
            continue;
        }
        map[service.serviceID] = service;
    }
    return map.copy;
}

- (NSDictionary<NSString *, VetModel *> *)pp_novaVetsByID:(NSArray<VetModel *> *)vets {
    NSMutableDictionary<NSString *, VetModel *> *map = [NSMutableDictionary dictionary];
    for (VetModel *vet in vets) {
        if (![vet isKindOfClass:VetModel.class] || vet.vetID.length == 0) {
            continue;
        }
        map[vet.vetID] = vet;
    }
    return map.copy;
}

- (NSDictionary<NSString *, PetAd *> *)pp_novaPetAdsByID:(NSArray<PetAd *> *)ads {
    NSMutableDictionary<NSString *, PetAd *> *map = [NSMutableDictionary dictionary];
    for (PetAd *ad in ads) {
        if (![ad isKindOfClass:PetAd.class] || ad.adID.length == 0) {
            continue;
        }
        map[ad.adID] = ad;
    }
    return map.copy;
}

- (NSDictionary<NSString *, AdoptPetModel *> *)pp_novaAdoptionsByID:(NSArray<AdoptPetModel *> *)pets {
    NSMutableDictionary<NSString *, AdoptPetModel *> *map = [NSMutableDictionary dictionary];
    for (AdoptPetModel *pet in pets) {
        if (![pet isKindOfClass:AdoptPetModel.class] || pet.documentID.length == 0) {
            continue;
        }
        map[pet.documentID] = pet;
    }
    return map.copy;
}

- (void)pp_showNovaSuggestionObjects:(NSArray *)objects {
    // Lesson: cards belong only to the response that returned them. Callers
    // must pass an explicit request_id/response_id pair — never let a card
    // batch silently bind to whatever the active context happens to be.
    LOG_WARN(@"[PPNovaChat][RenderBinding] append_dropped reason=missing_explicit_response_context source=convenience_no_ids incoming_card_count=%lu reused_previous_payload=NO",
             (unsigned long)objects.count);
}

- (void)pp_showNovaSuggestionObjects:(NSArray *)objects source:(NSString *)source {
    LOG_WARN(@"[PPNovaChat][RenderBinding] append_dropped reason=missing_explicit_response_context source=%@ incoming_card_count=%lu reused_previous_payload=NO",
             source ?: @"convenience_no_ids",
             (unsigned long)objects.count);
}

- (void)pp_showNovaSuggestionObjects:(NSArray *)objects
                              source:(NSString *)source
                           requestID:(NSString *)requestID
                          responseID:(NSString *)responseID
                          generation:(NSUInteger)generation {
    NSArray *validObjects = [self pp_validNovaCardObjectsFromObjects:objects
                                                              source:source
                                                           requestID:requestID
                                                          responseID:responseID];
    // Empty payload means no cards for this response. Lesson: never invent
    // cards out of nothing, never carry forward the previous response's batch.
    if (validObjects.count == 0) {
        LOG_INFO(@"[PPNovaChat][RenderBinding] empty_payload_no_cards request_id=%@ response_id=%@ source=%@ reused_previous_payload=NO",
                 requestID ?: @"",
                 responseID ?: @"",
                 source ?: @"unknown");
        return;
    }
    if (requestID.length == 0 || responseID.length == 0) {
        LOG_WARN(@"[PPNovaChat][RenderBinding] append_dropped reason=missing_response_ids request_id=%@ response_id=%@ source=%@ incoming_card_count=%lu reused_previous_payload=NO",
                 requestID ?: @"",
                 responseID ?: @"",
                 source ?: @"unknown",
                 (unsigned long)validObjects.count);
        return;
    }
    if (![self pp_canAttachNovaRenderForRequestID:requestID
                                       responseID:responseID
                                       generation:generation
                                           source:source]) {
        return;
    }
    [self pp_logNovaIncomingObjects:validObjects requestID:requestID responseID:responseID source:source];

    NSArray<PetAccessory *> *cartableProducts = [self pp_cartableNovaProductsFromObjects:validObjects];
    self.lastShownProducts = cartableProducts;
    if (validObjects.count == 1 && [validObjects.firstObject isKindOfClass:PetAccessory.class]) {
        self.lastSuggestedProduct = (PetAccessory *)validObjects.firstObject;
        self.pendingCartProduct = (PetAccessory *)validObjects.firstObject;
    } else {
        self.lastSuggestedProduct = nil;
        self.pendingCartProduct = nil;
    }

    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.messageType = validObjects.count > 1 ? ChatMessageTypeNovaProductList : ChatMessageTypeNovaProduct;
    msg.novaProducts = (NSArray<PetAccessory *> *)validObjects;
    msg.novaRequestID = requestID;
    msg.novaResponseID = responseID;
    msg.timestamp = [NSDate date];
    msg.senderID = @"nova_bot_id";

    [self pp_appendNovaMessageModel:msg updateReason:@"insert_cards"];

    LOG_INFO(@"NOVA_RENDERED_CELL_COUNT rendered=%lu source=%@",
             (unsigned long)validObjects.count,
             source ?: @"unknown");
    LOG_INFO(@"NOVA_CELL_MESSAGE_INSERTED request_id=%@ response_id=%@ cells_created=%lu message_type=%@ universalCell=YES source=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)validObjects.count,
             msg.messageType == ChatMessageTypeNovaProductList ? @"ChatMessageTypeNovaProductList" : @"ChatMessageTypeNovaProduct",
             source ?: @"unknown");
    LOG_INFO(@"[PPNovaChat][RenderBinding] request_id=%@ response_id=%@ appended_section_id=%@ attached_to_message_id=%@ reused_previous_payload=NO source=%@",
             requestID ?: @"",
             responseID ?: @"",
             msg.ID ?: @"",
             msg.ID ?: @"",
             source ?: @"unknown");

    [PPAnalytics logNovaShowcaseShownWithItemCount:validObjects.count
                                          sessionID:self.novaSessionId
                                             source:source];
}

- (void)pp_fetchAndShowLocalNovaShowcaseForUserText:(NSString *)userText
                                         completion:(void (^)(BOOL didShow))completion
{
    NSString *requestID = self.activeNovaRequestID ?: [self pp_newNovaScopedIDWithPrefix:@"request"];
    NSString *responseID = self.activeNovaResponseID ?: [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"local"];
    [self pp_fetchAndShowLocalNovaShowcaseForUserText:userText
                                            introText:nil
                                            requestID:requestID
                                           responseID:responseID
                                           generation:self.novaRequestGeneration
                                           completion:completion];
}

- (void)pp_fetchAndShowLocalNovaShowcaseForUserText:(NSString *)userText
                                          introText:(nullable NSString *)introText
                                        completion:(void (^)(BOOL didShow))completion
{
    NSString *requestID = self.activeNovaRequestID ?: [self pp_newNovaScopedIDWithPrefix:@"request"];
    NSString *responseID = self.activeNovaResponseID ?: [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"local"];
    [self pp_fetchAndShowLocalNovaShowcaseForUserText:userText
                                            introText:introText
                                            requestID:requestID
                                           responseID:responseID
                                           generation:self.novaRequestGeneration
                                           completion:completion];
}

- (void)pp_fetchAndShowLocalNovaShowcaseForUserText:(NSString *)userText
                                          introText:(nullable NSString *)introText
                                          requestID:(NSString *)requestID
                                         responseID:(NSString *)responseID
                                         generation:(NSUInteger)generation
                                        completion:(void (^)(BOOL didShow))completion
{
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self pp_updateMemoryFromUserText:trimmedText];
    [self pp_logNovaIntentForUserText:trimmedText stage:@"local_search_start"];

    if (![self pp_canAttachNovaRenderForRequestID:requestID
                                       responseID:responseID
                                       generation:generation
                                           source:@"local_search_start"]) {
        if (completion) completion(NO);
        return;
    }

    if (![self pp_shouldAttemptLocalNovaShowcaseForUserText:trimmedText] || [self pp_lastMessageIsNovaShowcase]) {
        LOG_INFO(@"NOVA_PRODUCTS_COUNT count=0 source=local reason=not_attempted");
        if (completion) completion(NO);
        return;
    }

    NSString *currentNeed = [self pp_localNovaNeedLabelFromUserText:trimmedText];
    NSString *currentPetType = [self pp_localNovaPetTypeFromUserText:trimmedText];
    NSString *need = currentNeed ?: @"";
    NSString *petType = currentPetType ?: @"";
    AccessKindType kind = [self pp_localNovaShowcaseKindForNeed:need petType:petType];
    LOG_INFO(@"NOVA_SEARCH_QUERY raw=%@ normalized=%@ kind=%ld need=%@ petType=%@",
             trimmedText ?: @"",
             [self pp_normalizedNovaIntentText:trimmedText],
             (long)kind,
             need ?: @"",
             petType ?: @"");
    __weak typeof(self) weakSelf = self;
    [[PetAccessoryManager sharedManager] fetchAccessoriesOfKind:kind completion:^(NSArray<PetAccessory *> *accessories) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.dismissed) {
            if (completion) completion(NO);
            return;
        }
        if (![self pp_canAttachNovaRenderForRequestID:requestID
                                           responseID:responseID
                                           generation:generation
                                               source:@"local_search_finish"]) {
            if (completion) completion(NO);
            return;
        }
        if ([self pp_lastMessageIsNovaShowcase]) {
            if (completion) completion(NO);
            return;
        }

        NSArray<PetAccessory *> *ranked = [self pp_rankedLocalNovaAccessories:accessories
                                                                     userText:trimmedText
                                                                         need:need
                                                                      petType:petType
                                                                        limit:6];
        LOG_INFO(@"NOVA_PRODUCTS_COUNT count=%lu source=local kind=%ld need=%@ petType=%@",
                 (unsigned long)ranked.count,
                 (long)kind,
                 need ?: @"",
                 petType ?: @"");
        if (ranked.count == 0) {
            if (completion) completion(NO);
            return;
        }

        [self pp_addNovaProductResultTextForRenderedCount:ranked.count
                                             proposedText:introText
                                                 userText:trimmedText
                                                   source:@"local"
                                                requestID:requestID
                                               responseID:responseID];
        [self pp_showNovaSuggestionObjects:ranked
                                    source:@"local"
                                 requestID:requestID
                                responseID:responseID
                                generation:generation];
        if (completion) completion(YES);
    }];
}

- (NSString *)pp_normalizedNovaIntentText:(NSString *)text {
    NSString *value = (text ?: @"").lowercaseString;
    NSDictionary<NSString *, NSString *> *replacements = @{
        @"إ": @"ا", @"أ": @"ا", @"آ": @"ا",
        @"ى": @"ي", @"ة": @"ه", @"ؤ": @"و", @"ئ": @"ي"
    };
    for (NSString *key in replacements) {
        value = [value stringByReplacingOccurrencesOfString:key withString:replacements[key]];
    }
    NSCharacterSet *punctuation = [NSCharacterSet characterSetWithCharactersInString:@"-_/.,;:!?()[]{}\"'`~|<>،؟؛"];
    NSArray<NSString *> *parts = [value componentsSeparatedByCharactersInSet:punctuation];
    value = [parts componentsJoinedByString:@" "];
    while ([value containsString:@"  "]) {
        value = [value stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (NSArray<NSString *> *)pp_novaShowcaseDisplayAliases {
    return @[
        @"show", @"show me", @"display", @"recommend", @"recommendation", @"recommendations",
        @"suggest", @"suggestion", @"suggestions", @"ads", @"ad",
        @"اعرض", @"عرض", @"وريني", @"ارني", @"رشح", @"رشحلي", @"رشح لي",
        @"اقتراحات", @"اقتراح", @"توصيات", @"اعلانات", @"إعلانات"
    ];
}

- (BOOL)pp_normalizedNovaText:(NSString *)text containsAlias:(NSString *)alias {
    NSString *normalized = [self pp_normalizedNovaIntentText:text];
    NSString *needle = [self pp_normalizedNovaIntentText:alias];
    if (normalized.length == 0 || needle.length == 0) {
        return NO;
    }
    if ([needle containsString:@" "]) {
        return [normalized containsString:needle];
    }
    NSArray<NSString *> *tokens = [normalized componentsSeparatedByString:@" "];
    return [tokens containsObject:needle];
}

- (BOOL)pp_novaTextHasShowcaseDisplayIntent:(NSString *)text {
    for (NSString *alias in [self pp_novaShowcaseDisplayAliases]) {
        if ([self pp_normalizedNovaText:text containsAlias:alias]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_novaIsGenericConversationText:(NSString *)text {
    NSString *normalized = [self pp_normalizedNovaIntentText:text];
    if (normalized.length == 0) {
        return YES;
    }
    NSSet<NSString *> *exact = [NSSet setWithArray:@[
        @"hi", @"hello", @"hey", @"salam", @"ok", @"okay",
        @"thanks", @"thank you", @"how are you", @"nova",
        @"هاي", @"هاى", @"هلا", @"اهلا", @"اهلين", @"مرحبا",
        @"السلام عليكم", @"نوفا", @"نوڤا", @"شكرا", @"تمام", @"اوكي"
    ]];
    if ([exact containsObject:normalized]) {
        return YES;
    }
    NSSet<NSString *> *tokensAllowed = [NSSet setWithArray:@[
        @"hi", @"hello", @"hey", @"ok", @"okay", @"thanks", @"thank", @"you", @"how", @"are",
        @"nova",
        @"هاي", @"هاى", @"هلا", @"اهلا", @"اهلين", @"مرحبا", @"نوفا", @"نوڤا", @"السلام", @"عليكم", @"شكرا", @"تمام", @"اوكي"
    ]];
    NSArray<NSString *> *tokens = [normalized componentsSeparatedByString:@" "];
    if (tokens.count > 0 && tokens.count <= 4) {
        for (NSString *token in tokens) {
            if (![tokensAllowed containsObject:token]) {
                return NO;
            }
        }
        return YES;
    }
    return NO;
}

- (NSString *)pp_novaSearchTextByRemovingDisplayIntent:(NSString *)text {
    NSString *normalized = [self pp_normalizedNovaIntentText:text];
    for (NSString *alias in [self pp_novaShowcaseDisplayAliases]) {
        NSString *needle = [self pp_normalizedNovaIntentText:alias];
        if (needle.length == 0) {
            continue;
        }
        NSString *pattern = [NSString stringWithFormat:@"(^| )%@( ?)", [NSRegularExpression escapedPatternForString:needle]];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        normalized = [regex stringByReplacingMatchesInString:normalized
                                                     options:0
                                                       range:NSMakeRange(0, normalized.length)
                                                withTemplate:@" "];
        while ([normalized containsString:@"  "]) {
            normalized = [normalized stringByReplacingOccurrencesOfString:@"  " withString:@" "];
        }
        normalized = [normalized stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    return normalized;
}

- (BOOL)pp_novaHasCatalogSearchIntentForUserText:(NSString *)userText {
    if ([self pp_novaIsGenericConversationText:userText]) {
        return NO;
    }
    NSString *need = [self pp_localNovaNeedLabelFromUserText:userText];
    NSString *petType = [self pp_localNovaPetTypeFromUserText:userText];
    if (need.length > 0 || petType.length > 0 || [self pp_novaTextHasShowcaseDisplayIntent:userText]) {
        return YES;
    }
    return [self pp_novaSearchTextByRemovingDisplayIntent:userText].length > 0;
}

- (BOOL)pp_novaDisplayIntentIsMissingTargetForUserText:(NSString *)userText {
    if (![self pp_novaTextHasShowcaseDisplayIntent:userText]) {
        return NO;
    }
    NSString *need = [self pp_localNovaNeedLabelFromUserText:userText];
    NSString *petType = [self pp_localNovaPetTypeFromUserText:userText];
    NSString *remainingQuery = [self pp_novaSearchTextByRemovingDisplayIntent:userText];
    BOOL hasMemoryTarget = self.novaMemoryNeed.length > 0 || self.novaMemoryPetType.length > 0;
    return need.length == 0 && petType.length == 0 && remainingQuery.length == 0 && !hasMemoryTarget;
}

- (void)pp_logNovaIntentForUserText:(NSString *)userText stage:(NSString *)stage {
    NSString *need = [self pp_localNovaNeedLabelFromUserText:userText] ?: self.novaMemoryNeed ?: @"";
    NSString *petType = [self pp_localNovaPetTypeFromUserText:userText] ?: self.novaMemoryPetType ?: @"";
    BOOL showcaseIntent = [self pp_novaTextHasShowcaseDisplayIntent:userText];
    BOOL displayOnly = [self pp_novaDisplayIntentIsMissingTargetForUserText:userText];
    LOG_INFO(@"NOVA_INTENT stage=%@ showcase=%@ displayOnly=%@ need=%@ petType=%@",
             stage ?: @"",
             showcaseIntent ? @"YES" : @"NO",
             displayOnly ? @"YES" : @"NO",
             need,
             petType);
}

- (BOOL)pp_lastNovaTextMessageEquals:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return NO;
    }
    for (NSInteger i = (NSInteger)self.messages.count - 1; i >= 0; i--) {
        ChatMessageModel *msg = self.messages[i];
        if (![msg.senderID isEqualToString:@"nova_bot_id"]) {
            continue;
        }
        if (msg.messageType != ChatMessageTypeText) {
            return NO;
        }
        return [[msg.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqualToString:trimmed];
    }
    return NO;
}

- (void)pp_addNovaProductResultTextForRenderedCount:(NSUInteger)renderedCount
                                       proposedText:(NSString *)proposedText
                                           userText:(NSString *)userText
                                             source:(NSString *)source
                                          requestID:(NSString *)requestID
                                         responseID:(NSString *)responseID {
    if (![self pp_canAttachNovaRenderForRequestID:requestID
                                       responseID:responseID
                                       generation:self.novaRequestGeneration
                                           source:source]) {
        return;
    }
    NSString *cleanProposed = [proposedText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *decision = @"no_products";
    NSString *textToShow = nil;

    if (renderedCount > 0) {
        if (cleanProposed.length > 0 && ![self pp_novaReplyContainsNoProductClaim:cleanProposed]) {
            textToShow = [self pp_novaCardFocusedAssistantTextFromText:cleanProposed];
            decision = textToShow.length > 0 ? @"proposed_text_with_rendered_products" : @"manual_result_text_suppressed";
        } else {
            decision = cleanProposed.length == 0 ? @"cards_only_no_ai_text" : @"cards_only_suppressed_no_product_text";
        }
    } else {
        if (cleanProposed.length > 0) {
            textToShow = cleanProposed;
            decision = @"proposed_text_without_products";
        } else {
            decision = @"no_products_no_ai_text";
        }
    }

    LOG_INFO(@"NOVA_PRODUCTS_COUNT request_id=%@ response_id=%@ count=%lu source=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)renderedCount,
             source ?: @"unknown");
    LOG_INFO(@"NOVA_RENDERED_CELL_COUNT request_id=%@ response_id=%@ rendered=%lu source=%@",
             requestID ?: @"",
             responseID ?: @"",
             (unsigned long)renderedCount,
             source ?: @"unknown");
    LOG_INFO(@"NOVA_TEXT_DECISION request_id=%@ response_id=%@ decision=%@ rendered=%lu source=%@ text=%@",
             requestID ?: @"",
             responseID ?: @"",
             decision,
             (unsigned long)renderedCount,
             source ?: @"unknown",
             textToShow ?: @"");

    if (textToShow.length > 0 && ![self pp_lastNovaTextMessageEquals:textToShow]) {
        [self addNovaMessage:textToShow requestID:requestID responseID:responseID];
    }
}

- (BOOL)pp_shouldAttemptLocalNovaShowcaseForUserText:(NSString *)userText {
    NSString *lower = [userText.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (lower.length == 0 || [self pp_novaIsGenericConversationText:lower]) {
        return NO;
    }
    NSString *need = [self pp_localNovaNeedLabelFromUserText:lower];
    NSString *petType = [self pp_localNovaPetTypeFromUserText:lower];
    if ([self pp_localNovaPetTypeIsLivePet:petType]) {
        return YES;
    }
    if (need.length > 0) {
        return petType.length > 0;
    }
    if ([self pp_novaTextHasShowcaseDisplayIntent:lower]) {
        return petType.length > 0;
    }
    return NO;
}

- (AccessKindType)pp_localNovaShowcaseKindForNeed:(NSString *)needLabel petType:(NSString *)petType {
    NSString *need = needLabel.lowercaseString ?: @"";
    if ([need isEqualToString:@"food"]) {
        return AccessTypeFood;
    }
    if ([need isEqualToString:@"medicine"]) {
        return AccessTypePetMedicine;
    }
    if ([self pp_localNovaPetTypeIsLivePet:petType]) {
        return AccessTypeLivePet;
    }
    return AccessTypeAccessory;
}

- (NSArray<PetAccessory *> *)pp_rankedLocalNovaAccessories:(NSArray<PetAccessory *> *)accessories
                                                  userText:(NSString *)userText
                                                      need:(NSString *)need
                                                   petType:(NSString *)petType
                                                     limit:(NSUInteger)limit
{
    // Minimum *semantic* relevance score (need-match, pet-match, or token-match —
    // bare in-stock + has-image bonuses don't count). Off-topic queries score
    // below this and produce an empty result, so we never showcase random items.
    static const NSInteger kMinNovaRelevance = 3;

    NSMutableArray<PetAccessory *> *eligible = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSNumber *> *scoresByID = [NSMutableDictionary dictionary];
    for (PetAccessory *item in accessories) {
        if (![item isKindOfClass:PetAccessory.class] || item.accessoryID.length == 0) {
            continue;
        }
        if (petType.length > 0 && ![self pp_localNovaAccessory:item matchesPetType:petType]) {
            continue;
        }
        NSInteger relevance = [self pp_localNovaAccessoryRelevanceScore:item
                                                                userText:userText
                                                                    need:need
                                                                 petType:petType];
        if (relevance < kMinNovaRelevance) {
            continue;
        }
        scoresByID[item.accessoryID] = @(relevance + [self pp_localNovaAccessoryQualityScore:item]);
        [eligible addObject:item];
    }
    if (eligible.count == 0) {
        return @[];
    }

    NSArray<PetAccessory *> *sorted = [eligible sortedArrayUsingComparator:^NSComparisonResult(PetAccessory *left, PetAccessory *right) {
        NSInteger leftScore = scoresByID[left.accessoryID].integerValue;
        NSInteger rightScore = scoresByID[right.accessoryID].integerValue;
        if (leftScore > rightScore) return NSOrderedAscending;
        if (leftScore < rightScore) return NSOrderedDescending;

        NSDate *leftDate = [left.createdAt isKindOfClass:NSDate.class] ? left.createdAt : NSDate.distantPast;
        NSDate *rightDate = [right.createdAt isKindOfClass:NSDate.class] ? right.createdAt : NSDate.distantPast;
        return [rightDate compare:leftDate];
    }];

    NSUInteger count = MIN(limit, sorted.count);
    return [sorted subarrayWithRange:NSMakeRange(0, count)];
}

// Pure semantic signal — does the item match the user's stated need / pet /
// keywords? Used as the gate for inclusion (bare popularity bonuses don't
// qualify an item).
- (NSInteger)pp_localNovaAccessoryRelevanceScore:(PetAccessory *)item
                                         userText:(NSString *)userText
                                             need:(NSString *)needLabel
                                          petType:(NSString *)petTypeLabel {
    NSString *haystack = [[NSString stringWithFormat:@"%@ %@",
                           item.name ?: @"",
                           item.desc ?: @""] lowercaseString];
    NSString *need = needLabel.lowercaseString ?: @"";
    NSString *petType = petTypeLabel.lowercaseString ?: @"";
    NSInteger score = 0;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForNeed:need]]) score += 8;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForPetType:petType]]) score += 5;
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_tokenKeywordsFromUserText:userText]]) score += 3;
    return score;
}

// Tie-breaker bonuses — applied only after relevance passes the gate.
- (NSInteger)pp_localNovaAccessoryQualityScore:(PetAccessory *)item {
    NSInteger score = 0;
    if (item.quantity > 0) score += 2;
    if (item.imageURLsArray.count > 0) score += 1;
    return score;
}

- (nullable NSString *)pp_localNovaNeedLabelFromUserText:(NSString *)userText {
    NSString *lower = userText.lowercaseString ?: @"";
    NSArray<NSDictionary<NSString *, id> *> *needKeywords = @[
        @{@"label": @"food", @"keys": @[@"food", @"feed", @"meal", @"kibble", @"treat", @"snack", @"أكل", @"اكل", @"طعام", @"غذاء", @"دراي"]},
        @{@"label": @"medicine", @"keys": @[@"medicine", @"medication", @"vitamin", @"supplement", @"treatment", @"دواء", @"أدوية", @"ادوية", @"فيتامين", @"علاج"]},
        @{@"label": @"cage", @"keys": @[@"cage", @"carrier", @"crate", @"kennel", @"bed", @"aquarium", @"tank", @"قفص", @"حاملة", @"حقيبة", @"حقيبه", @"بيت", @"حوض"]},
        @{@"label": @"toy", @"keys": @[@"toy", @"toys", @"play", @"ball", @"chew", @"لعبة", @"لعبه", @"ألعاب", @"العاب", @"كرة"]},
        @{@"label": @"care", @"keys": @[@"care", @"grooming", @"shampoo", @"brush", @"clean", @"عناية", @"عنايه", @"شامبو", @"تنظيف", @"نظافة"]},
        @{@"label": @"litter", @"keys": @[@"litter", @"sand", @"رمل", @"فضلات", @"ليتر"]}
    ];

    for (NSDictionary<NSString *, id> *entry in needKeywords) {
        NSArray<NSString *> *keys = entry[@"keys"];
        if ([self pp_string:lower containsAnyNovaKeyword:keys]) {
            return entry[@"label"];
        }
    }
    return nil;
}

- (nullable NSString *)pp_localNovaPetTypeFromUserText:(NSString *)userText {
    NSString *lower = userText.lowercaseString ?: @"";
    NSArray<NSDictionary<NSString *, id> *> *petKeywords = @[
        @{@"label": @"cat", @"keys": @[@"cat", @"cats", @"kitten", @"kitty", @"قط", @"قطة", @"قطه", @"قطط", @"بسه", @"بسة"]},
        @{@"label": @"dog", @"keys": @[@"dog", @"dogs", @"puppy", @"pup", @"كلب", @"كلبة", @"كلبه", @"كلاب", @"جرو"]},
        @{@"label": @"bird", @"keys": @[@"bird", @"birds", @"طير", @"طائر", @"طيور", @"عصفور", @"عصافير"]},
        @{@"label": @"parrot", @"keys": @[@"parrot", @"parrots", @"cockatiel", @"cockatoo", @"budgie", @"ببغاء", @"كروان", @"كاسكو"]},
        @{@"label": @"fish", @"keys": @[@"fish", @"fishes", @"aquarium", @"سمك", @"سمكة", @"سمكه", @"أسماك", @"اسماك"]},
        @{@"label": @"rabbit", @"keys": @[@"rabbit", @"rabbits", @"bunny", @"أرنب", @"ارنب", @"أرانب", @"ارانب"]},
        @{@"label": @"hamster", @"keys": @[@"hamster", @"hamsters", @"هامستر", @"هامستار"]},
        @{@"label": @"turtle", @"keys": @[@"turtle", @"turtles", @"tortoise", @"سلحفاة", @"سلحفاه", @"سلاحف"]}
    ];
    for (NSDictionary<NSString *, id> *entry in petKeywords) {
        if ([self pp_string:lower containsAnyNovaKeyword:entry[@"keys"]]) {
            return entry[@"label"];
        }
    }
    return nil;
}

- (BOOL)pp_localNovaPetTypeIsLivePet:(NSString *)petType {
    NSString *value = petType.lowercaseString ?: @"";
    return [@[@"bird", @"parrot", @"fish", @"rabbit", @"hamster", @"turtle"] containsObject:value];
}

- (BOOL)pp_localNovaAccessory:(PetAccessory *)item matchesPetType:(NSString *)petType {
    NSString *value = petType.lowercaseString ?: @"";
    if (value.length == 0) {
        return YES;
    }
    NSString *haystack = [[NSString stringWithFormat:@"%@ %@",
                           item.name ?: @"",
                           item.desc ?: @""] lowercaseString];
    if ([self pp_string:haystack containsAnyNovaKeyword:[self pp_localNovaKeywordsForPetType:value]]) {
        return YES;
    }
    if ([value isEqualToString:@"cat"] && item.petMainCategoryID == 5) return YES;
    if ([value isEqualToString:@"dog"] && item.petMainCategoryID == 6) return YES;
    if (([value isEqualToString:@"bird"] || [value isEqualToString:@"parrot"]) && item.petMainCategoryID == 0) return YES;
    if ([value isEqualToString:@"fish"] && item.petMainCategoryID == 1) return YES;
    if (([value isEqualToString:@"hamster"] || [value isEqualToString:@"rabbit"]) && item.petMainCategoryID == 2) return YES;
    return NO;
}

- (NSArray<NSString *> *)pp_localNovaKeywordsForNeed:(NSString *)need {
    if ([need isEqualToString:@"food"]) return @[@"food", @"kibble", @"treat", @"snack", @"أكل", @"اكل", @"طعام", @"دراي"];
    if ([need isEqualToString:@"medicine"]) return @[@"medicine", @"vitamin", @"supplement", @"treatment", @"دواء", @"فيتامين", @"علاج"];
    if ([need isEqualToString:@"cage"]) return @[@"cage", @"carrier", @"crate", @"bed", @"قفص", @"حقيبة", @"حقيبه", @"بيت"];
    if ([need isEqualToString:@"toy"]) return @[@"toy", @"ball", @"chew", @"لعبة", @"لعبه", @"كرة"];
    if ([need isEqualToString:@"care"]) return @[@"grooming", @"shampoo", @"brush", @"clean", @"شامبو", @"تنظيف", @"عناية", @"عنايه"];
    if ([need isEqualToString:@"litter"]) return @[@"litter", @"sand", @"رمل", @"ليتر"];
    return @[];
}

- (NSArray<NSString *> *)pp_localNovaKeywordsForPetType:(NSString *)petType {
    if ([petType isEqualToString:@"cat"]) return @[@"cat", @"kitten", @"قط", @"قطة", @"قطه", @"قطط"];
    if ([petType isEqualToString:@"dog"]) return @[@"dog", @"puppy", @"كلب", @"كلبة", @"كلبه", @"جرو"];
    if ([petType isEqualToString:@"bird"]) return @[@"bird", @"طير", @"طائر", @"طيور", @"عصفور"];
    if ([petType isEqualToString:@"parrot"]) return @[@"parrot", @"cockatiel", @"budgie", @"ببغاء", @"كروان"];
    if ([petType isEqualToString:@"fish"]) return @[@"fish", @"aquarium", @"سمك", @"سمكة", @"سمكه", @"حوض"];
    if ([petType isEqualToString:@"rabbit"]) return @[@"rabbit", @"bunny", @"أرنب", @"ارنب"];
    if ([petType isEqualToString:@"hamster"]) return @[@"hamster", @"هامستر"];
    if ([petType isEqualToString:@"turtle"]) return @[@"turtle", @"tortoise", @"سلحفاة", @"سلحفاه"];
    return @[];
}

- (NSArray<NSString *> *)pp_tokenKeywordsFromUserText:(NSString *)userText {
    NSArray<NSString *> *parts = [userText.lowercaseString componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        if (trimmed.length >= 3) {
            [tokens addObject:trimmed];
        }
    }
    return tokens.copy;
}

- (BOOL)pp_string:(NSString *)text containsAnyNovaKeyword:(NSArray<NSString *> *)keywords {
    if (text.length == 0 || keywords.count == 0) {
        return NO;
    }
    for (NSString *keyword in keywords) {
        NSString *normalized = keyword.lowercaseString;
        if (normalized.length > 0 && [text containsString:normalized]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_lastMessageIsNovaShowcase {
    ChatMessageModel *last = self.messages.lastObject;
    return last.messageType == ChatMessageTypeNovaProduct ||
           last.messageType == ChatMessageTypeNovaProductList;
}

- (NSArray<PetAccessory *> *)pp_cartableNovaProductsFromObjects:(NSArray *)objects {
    NSMutableArray<PetAccessory *> *products = [NSMutableArray array];
    for (id object in objects) {
        if ([object isKindOfClass:PetAccessory.class]) {
            [products addObject:(PetAccessory *)object];
        }
    }
    return products.copy;
}

- (NSString *)pp_novaDisplayNameForSuggestionObject:(id)object {
    if ([object isKindOfClass:PetAccessory.class]) {
        PetAccessory *acc = (PetAccessory *)object;
        NSString *name = acc.name ?: @"";
        NSString *priceStr = acc.price ? [NSString stringWithFormat:@" (%.2f QAR)", [acc.price doubleValue]] : @"";
        return [name stringByAppendingString:priceStr];
    }
    if ([object isKindOfClass:ServiceModel.class]) {
        ServiceModel *srv = (ServiceModel *)object;
        NSString *name = srv.title ?: @"";
        NSString *priceStr = srv.price ? [NSString stringWithFormat:@" (%.2f QAR)", srv.price] : @"";
        return [name stringByAppendingString:priceStr];
    }
    if ([object isKindOfClass:VetModel.class]) {
        VetModel *vet = (VetModel *)object;
        return vet.title ?: @"";
    }
    if ([object isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)object;
        NSString *name = ad.adTitle ?: @"";
        NSString *priceStr = ad.price ? [NSString stringWithFormat:@" (%.2f QAR)", [ad.price doubleValue]] : @"";
        return [name stringByAppendingString:priceStr];
    }
    if ([object isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = (AdoptPetModel *)object;
        return pet.name ?: @"";
    }
    return @"";
}

#pragma mark - Initial Data

// Templated local-fallback reply was removed in the behavioral refactor: it
// was the source of the "rigid handler text overrides AI" complaint. When the
// model is unreachable or returns nothing, we now stay silent and let the
// product-showcase path speak instead. The Arabic word maps below are still
// used by `pp_buildPreviousUserFactsString` to seed the agent's context.

- (BOOL)textContainsArabic:(NSString *)text {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0x0600 && c <= 0x06FF) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Local Session Memory

- (void)pp_updateMemoryFromUserText:(NSString *)text {
    if (text.length == 0) return;

    NSString *lower = [text lowercaseString];
    BOOL isArabic = [self textContainsArabic:text];

    // Language sticks to the user's last expressed language; never overwritten to nil.
    self.novaMemoryLanguage = isArabic ? @"ar" : @"en";

    NSArray<NSDictionary *> *petKeywords = @[
        @{@"label": @"cat",     @"keys": @[@"cat", @"cats", @"kitten", @"kitty",
                                            @"قط", @"قطة", @"قطه", @"قطتي", @"قطط", @"بسة", @"بسه", @"هر", @"هرة"]},
        @{@"label": @"dog",     @"keys": @[@"dog", @"dogs", @"puppy", @"pup",
                                            @"كلب", @"كلبة", @"كلبه", @"كلبي", @"جرو", @"كلاب"]},
        @{@"label": @"bird",    @"keys": @[@"bird", @"birds",
                                            @"طير", @"طائر", @"طيور", @"عصفور", @"عصافير"]},
        @{@"label": @"parrot",  @"keys": @[@"parrot", @"parrots", @"cockatiel", @"cockatoo", @"budgie",
                                            @"ببغاء", @"ببغاوات", @"كاسكو", @"درة", @"كروان"]},
        @{@"label": @"fish",    @"keys": @[@"fish", @"fishes", @"aquarium",
                                            @"سمك", @"سمكة", @"سمكه", @"أسماك", @"اسماك"]},
        @{@"label": @"rabbit",  @"keys": @[@"rabbit", @"rabbits", @"bunny",
                                            @"أرنب", @"ارنب", @"أرانب", @"ارانب"]},
        @{@"label": @"hamster", @"keys": @[@"hamster", @"hamsters",
                                            @"هامستر", @"هامستار"]},
        @{@"label": @"turtle",  @"keys": @[@"turtle", @"turtles", @"tortoise",
                                            @"سلحفاة", @"سلحفاه", @"سلاحف"]}
    ];

    for (NSDictionary *p in petKeywords) {
        BOOL matched = NO;
        for (NSString *kw in p[@"keys"]) {
            if ([lower containsString:kw] || [text containsString:kw]) {
                matched = YES;
                break;
            }
        }
        if (matched) {
            self.novaMemoryPetType = p[@"label"];
            break;
        }
    }

    NSArray<NSDictionary *> *needKeywords = @[
        @{@"label": @"food",     @"keys": @[@"food", @"feed", @"meal", @"kibble", @"treat", @"snack",
                                             @"dry food", @"wet food", @"dry", @"wet",
                                             @"أكل", @"اكل", @"طعام", @"غذاء", @"دراي", @"وجبة", @"وجبه", @"تغذية"]},
        @{@"label": @"cage",     @"keys": @[@"cage", @"carrier", @"crate", @"kennel", @"bed",
                                             @"aquarium", @"tank",
                                             @"قفص", @"أقفاص", @"اقفاص", @"حاملة", @"حقيبة", @"حقيبه",
                                             @"بيت", @"حوض", @"ناقلة", @"كاريير"]},
        @{@"label": @"toy",      @"keys": @[@"toy", @"toys", @"play", @"ball", @"chew",
                                             @"لعبة", @"لعبه", @"لعب", @"ألعاب", @"العاب", @"كرة"]},
        @{@"label": @"medicine", @"keys": @[@"medicine", @"medication", @"vitamin", @"vitamins",
                                             @"supplement", @"supplements", @"treatment",
                                             @"دواء", @"أدوية", @"ادوية", @"فيتامين", @"فيتامينات", @"علاج"]},
        @{@"label": @"care",     @"keys": @[@"care", @"grooming", @"groom", @"shampoo", @"brush",
                                             @"bath", @"nail", @"clean",
                                             @"عناية", @"عنايه", @"شامبو", @"تنظيف", @"نظافة",
                                             @"تمشيط", @"استحمام", @"تقليم"]},
        @{@"label": @"litter",   @"keys": @[@"litter", @"litter box", @"potty", @"toilet", @"sand",
                                             @"رمل", @"فضلات", @"ليتر"]}
    ];

    for (NSDictionary *n in needKeywords) {
        BOOL matched = NO;
        for (NSString *kw in n[@"keys"]) {
            if ([lower containsString:kw] || [text containsString:kw]) {
                matched = YES;
                break;
            }
        }
        if (matched) {
            self.novaMemoryNeed = n[@"label"];
            break;
        }
    }
}

- (NSString *)pp_arabicPetWord:(NSString *)label {
    NSDictionary *map = @{
        @"cat": @"قطة", @"dog": @"كلب", @"bird": @"طائر", @"parrot": @"ببغاء",
        @"fish": @"سمكة", @"rabbit": @"أرنب", @"hamster": @"هامستر", @"turtle": @"سلحفاة"
    };
    return map[label] ?: label;
}

- (NSString *)pp_arabicNeedWord:(NSString *)label {
    NSDictionary *map = @{
        @"food": @"أكل", @"cage": @"قفص", @"toy": @"لعبة",
        @"medicine": @"دواء", @"care": @"عناية", @"litter": @"رمل"
    };
    return map[label] ?: label;
}

- (NSString *)pp_buildPreviousUserFactsString {
    BOOL isArabic = [self.novaMemoryLanguage isEqualToString:@"ar"];
    NSMutableArray<NSString *> *bits = [NSMutableArray array];

    if (self.novaMemoryPetType.length > 0) {
        if (isArabic) {
            [bits addObject:[NSString stringWithFormat:@"المستخدم لديه %@", [self pp_arabicPetWord:self.novaMemoryPetType]]];
        } else {
            [bits addObject:[NSString stringWithFormat:@"User has a %@", self.novaMemoryPetType]];
        }
    }
    if (self.novaMemoryNeed.length > 0) {
        if (isArabic) {
            [bits addObject:[NSString stringWithFormat:@"يبحث عن %@", [self pp_arabicNeedWord:self.novaMemoryNeed]]];
        } else {
            [bits addObject:[NSString stringWithFormat:@"is looking for %@", self.novaMemoryNeed]];
        }
    }
    if (bits.count == 0) return @"";

    NSString *joiner = isArabic ? @" و" : @" and ";
    return [bits componentsJoinedByString:joiner];
}

- (NSDictionary *)pp_currentContextDictionary {
    NSMutableDictionary *ctx = [NSMutableDictionary dictionary];
    if (self.novaMemoryPetType.length > 0)  ctx[@"petType"] = self.novaMemoryPetType;
    if (self.novaMemoryNeed.length > 0)     ctx[@"need"] = self.novaMemoryNeed;
    if (self.novaMemoryLanguage.length > 0) ctx[@"language"] = self.novaMemoryLanguage;

    // Tell the backend this is the first assistant message so Nova can deliver
    // a natural, contextual greeting. After the first reply lands, the flag
    // flips to NO for all subsequent messages (enforcing the STRICT GREETING RULE).
    ctx[@"isFirstAssistantMessage"] = @(!self.novaHasSentFirstMessage);

    // Personalization signals — keep optional, never block on missing values.
    NSString *firstName = [PPCurrentUser.FirstName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (firstName.length > 0) {
        ctx[@"firstName"] = firstName;
    }
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
    if (hour >= 0 && hour < 24) {
        ctx[@"localHour"] = @(hour);
    }

    NSString *facts = [self pp_buildPreviousUserFactsString];
    if (facts.length > 0) {
        ctx[@"previousUserFacts"] = facts;
    }
    return [ctx copy];
}

- (NSDictionary *)pp_currentNovaBrainStateDictionary {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    if (self.novaMemoryPetType.length > 0) {
        state[@"animal"] = self.novaMemoryPetType;
    }
    if (self.novaMemoryNeed.length > 0) {
        state[@"category"] = self.novaMemoryNeed;
    }
    if (self.novaMemoryLanguage.length > 0) {
        state[@"user_language"] = self.novaMemoryLanguage;
    }
    NSMutableArray<NSString *> *shownProductIDs = [NSMutableArray array];
    for (PetAccessory *product in self.lastShownProducts) {
        if ([product isKindOfClass:PetAccessory.class] && product.accessoryID.length > 0) {
            [shownProductIDs addObject:product.accessoryID];
        }
    }
    if (shownProductIDs.count > 0) {
        state[@"last_products_shown"] = shownProductIDs.copy;
    }
    return state.copy;
}

- (NSArray *)pp_currentHistoryArray {
    // We used to synthesize history here, but we now rely on PPNovaLocalChatMemory
    // which accurately preserves history across sessions. We return up to 12
    // recent items to give the backend proxy a rich contextual window.

    NSArray *localHistory = [[PPNovaLocalChatMemory sharedMemory] recentHistoryLimit:12];
    NSMutableArray *history = [NSMutableArray array];

    // The geminiProxy.js expects objects in the shape:
    // { "role": "user"|"model", "text": "..." } OR { "role": "user"|"model", "parts": [{ "text": "..." }] }
    // We convert the PPNovaLocalChatMemory dict to match what the proxy currently parses smoothly.

    for (NSDictionary *dict in localHistory) {
        [history addObject:@{
            @"role": dict[@"role"],
            @"parts": @[@{ @"text": dict[@"text"] }]
        }];
    }

    // Do not include the very last user message in the history block since it is
    // passed as the "prompt" argument to the Cloud Function.
    if (history.count > 0) {
        NSDictionary *last = history.lastObject;
        if ([last[@"role"] isEqualToString:@"user"]) {
            [history removeLastObject];
        }
    }

    return [history copy];
}

#pragma mark - Setup UI

- (void)setupAmbientBackground {
    UIView *backgroundView = [[UIView alloc] init];
    backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundView.userInteractionEnabled = NO;
    backgroundView.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    [self.view addSubview:backgroundView];
    self.ambientBackgroundView = backgroundView;

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    bottomGlowView.layer.cornerRadius = 170.0;
    bottomGlowView.layer.shadowOpacity = 0.22;
    bottomGlowView.layer.shadowRadius = 42.0;
    bottomGlowView.layer.shadowOffset = CGSizeZero;
    bottomGlowView.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        bottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [backgroundView addSubview:bottomGlowView];
    self.novaChatBottomGlowView = bottomGlowView;

    [NSLayoutConstraint activateConstraints:@[
        [backgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [backgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [backgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [backgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [bottomGlowView.widthAnchor constraintEqualToConstant:340.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:340.0],
        [bottomGlowView.leadingAnchor constraintEqualToAnchor:backgroundView.leadingAnchor constant:-96.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:backgroundView.bottomAnchor constant:128.0]
    ]];

    [self pp_applyNovaSurfaceColors];
}

- (void)pp_applyNovaSurfaceColors {
    UIColor *brand = [self pp_novaHeaderAccentColor];
    UIColor *baseBackground = [self pp_novaHeaderCanvasColor];
    UIColor *surface = [self pp_novaHeaderSurfaceColor];
    UIColor *primaryText = [self pp_novaHeaderPrimaryTextColor];
    UIColor *secondaryText = [self pp_novaHeaderSecondaryTextColor];
    self.ambientBackgroundView.backgroundColor = baseBackground;
    self.novaChatBottomGlowView.backgroundColor = PPNovaDynamicColor([brand colorWithAlphaComponent:0.13],
                                                                     [brand colorWithAlphaComponent:0.22]);
    self.novaChatBottomGlowView.layer.shadowColor = brand.CGColor;
    self.emptyStatePulseView.backgroundColor = [brand colorWithAlphaComponent:0.10];
    [self pp_applyNovaSmartSuggestionColorsWithBrand:brand
                                             surface:surface
                                         primaryText:primaryText
                                       secondaryText:secondaryText];
    if ([self.novaHeaderChromeView isKindOfClass:UIVisualEffectView.class]) {
        ((UIVisualEffectView *)self.novaHeaderChromeView).effect = [UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]];
    }
    self.novaHeaderChromeView.backgroundColor = PPNovaDynamicColor([surface colorWithAlphaComponent:0.12],
                                                                   [surface colorWithAlphaComponent:0.28]);
    self.novaHeaderChromeView.layer.borderColor = [brand colorWithAlphaComponent:0.16].CGColor;
    self.novaHeaderTopGlowView.backgroundColor = PPNovaDynamicColor([brand colorWithAlphaComponent:0.30],
                                                                    [brand colorWithAlphaComponent:0.26]);
    self.novaHeaderTopGlowView.layer.shadowColor = brand.CGColor;
    self.novaHeaderBottomGlowView.backgroundColor = PPNovaDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.18],
                                                                       [UIColor.whiteColor colorWithAlphaComponent:0.045]);
    self.novaHeaderSheenView.backgroundColor = PPNovaDynamicColor([brand colorWithAlphaComponent:0.045],
                                                                  [brand colorWithAlphaComponent:0.085]);
    [self pp_installNovaHeaderLiquidBorderIfNeeded];
    UIColor *liquidBorder = PPNovaDynamicColor([brand colorWithAlphaComponent:0.14],
                                               [UIColor.whiteColor colorWithAlphaComponent:0.12]);
    UIColor *liquidHighlight = PPNovaDynamicColor([brand colorWithAlphaComponent:0.42],
                                                  [UIColor.whiteColor colorWithAlphaComponent:0.34]);
    if (@available(iOS 13.0, *)) {
        liquidBorder = [liquidBorder resolvedColorWithTraitCollection:self.traitCollection];
        liquidHighlight = [liquidHighlight resolvedColorWithTraitCollection:self.traitCollection];
    }
    self.novaHeaderLiquidBorderLayer.strokeColor = liquidBorder.CGColor;
    self.novaHeaderLiquidHighlightLayer.strokeColor = liquidHighlight.CGColor;
    self.novaHeaderLiquidHighlightLayer.shadowColor = liquidHighlight.CGColor;
    self.headerHairlineHost.backgroundColor = [secondaryText colorWithAlphaComponent:0.10];
    self.headerBrandHaloView.backgroundColor = PPNovaDynamicColor([AppBackgroundClr colorWithAlphaComponent:0.10],
                                                                  [AppForgroundColr colorWithAlphaComponent:0.18]);
    self.headerBrandHaloView.layer.shadowColor = brand.CGColor;
    self.statusDot.backgroundColor = AppBageColor();
    self.statusDot.layer.shadowColor = brand.CGColor;
    self.headerLiveCapsule.backgroundColor = [brand colorWithAlphaComponent:0.10];
    self.headerLiveCapsule.layer.borderColor = [brand colorWithAlphaComponent:0.18].CGColor;
    self.headerBrandRingView.backgroundColor = [brand colorWithAlphaComponent:0.10];
    self.headerBrandRingView.layer.borderColor = [brand colorWithAlphaComponent:0.24].CGColor;
    self.headerBrandMarkView.backgroundColor = surface;
    self.headerBrandMarkView.layer.borderColor = [brand colorWithAlphaComponent:0.14].CGColor;
    self.headerNameLabel.textColor = primaryText;
    self.headerSubtitleLabel.textColor = [secondaryText colorWithAlphaComponent:0.92];
    self.statusLabel.textColor = [primaryText colorWithAlphaComponent:0.78];
    self.closeButton.backgroundColor = PPNovaDynamicColor([surface colorWithAlphaComponent:0.82],
                                                          [surface colorWithAlphaComponent:0.58]);
    self.closeButton.layer.borderColor = [brand colorWithAlphaComponent:0.08].CGColor;
    self.closeButton.tintColor = [primaryText colorWithAlphaComponent:0.62];

    [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        dot.backgroundColor = idx % 2 == 0 ? brand : PPNovaDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.92],
                                                                        [UIColor.whiteColor colorWithAlphaComponent:0.68]);
        dot.layer.shadowColor = brand.CGColor;
    }];
}

- (UIColor *)pp_resolvedNovaLayerColor:(UIColor *)color {
    if (@available(iOS 13.0, *)) {
        return [color resolvedColorWithTraitCollection:self.traitCollection];
    }
    return color;
}

- (NSArray<UIColor *> *)pp_novaSmartSuggestionPaletteForIndex:(NSUInteger)index {
    NSArray<NSArray<UIColor *> *> *palettes = @[
        @[[UIColor colorWithRed:0.98 green:0.43 blue:0.34 alpha:1.0],
          [UIColor colorWithRed:0.96 green:0.64 blue:0.22 alpha:1.0]],
        @[[UIColor colorWithRed:0.18 green:0.66 blue:0.88 alpha:1.0],
          [UIColor colorWithRed:0.20 green:0.78 blue:0.60 alpha:1.0]],
        @[[UIColor colorWithRed:0.64 green:0.42 blue:0.92 alpha:1.0],
          [UIColor colorWithRed:0.90 green:0.36 blue:0.62 alpha:1.0]],
        @[[UIColor colorWithRed:0.18 green:0.73 blue:0.50 alpha:1.0],
          [UIColor colorWithRed:0.38 green:0.80 blue:0.32 alpha:1.0]],
        @[[UIColor colorWithRed:0.30 green:0.55 blue:0.93 alpha:1.0],
          [UIColor colorWithRed:0.46 green:0.36 blue:0.86 alpha:1.0]],
        @[[UIColor colorWithRed:0.16 green:0.70 blue:0.70 alpha:1.0],
          [UIColor colorWithRed:0.36 green:0.72 blue:0.94 alpha:1.0]],
        @[[UIColor colorWithRed:0.95 green:0.58 blue:0.24 alpha:1.0],
          [UIColor colorWithRed:0.92 green:0.38 blue:0.42 alpha:1.0]],
        @[[UIColor colorWithRed:0.52 green:0.42 blue:0.92 alpha:1.0],
          [UIColor colorWithRed:0.22 green:0.72 blue:0.92 alpha:1.0]]
    ];
    return palettes[index % palettes.count];
}

- (void)pp_applyNovaSmartSuggestionColorsWithBrand:(UIColor *)brand
                                           surface:(UIColor *)surface
                                       primaryText:(UIColor *)primaryText
                                     secondaryText:(UIColor *)secondaryText {
    [self pp_applyNovaSmartSuggestionColorsWithBrand:brand
                                             surface:surface
                                         primaryText:primaryText
                                       secondaryText:secondaryText
                                            animated:NO];
}

- (void)pp_applyNovaSmartSuggestionColorsWithBrand:(UIColor *)brand
                                           surface:(UIColor *)surface
                                       primaryText:(UIColor *)primaryText
                                     secondaryText:(UIColor *)secondaryText
                                          animated:(BOOL)animated {
    if (!self.smartSuggestionSurfaceView) {
        return;
    }

    NSArray<UIColor *> *palette = [self pp_novaSmartSuggestionPaletteForIndex:self.smartSuggestionCurrentIndex];
    UIColor *suggestionAccent = palette.firstObject ?: brand;
    UIColor *suggestionCompanion = palette.count > 1 ? palette[1] : brand;
    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    UIColor *surfaceFill = PPNovaDynamicColor([suggestionAccent colorWithAlphaComponent:0.095],
                                              [suggestionCompanion colorWithAlphaComponent:0.115]);
    UIColor *strokeColor = [suggestionAccent colorWithAlphaComponent:isDark ? 0.28 : 0.22];
    UIColor *washStart = [suggestionAccent colorWithAlphaComponent:isDark ? 0.24 : 0.17];
    UIColor *washMid = [suggestionCompanion colorWithAlphaComponent:isDark ? 0.18 : 0.12];
    UIColor *washEnd = [surface colorWithAlphaComponent:0.0];
    NSArray *gradientColors = @[
        (id)[self pp_resolvedNovaLayerColor:washStart].CGColor,
        (id)[self pp_resolvedNovaLayerColor:washMid].CGColor,
        (id)[self pp_resolvedNovaLayerColor:washEnd].CGColor
    ];
    NSArray *previousGradientColors = self.smartSuggestionAccentGradientLayer.colors;
    void (^changes)(void) = ^{
        self.smartSuggestionAccentWashView.alpha = 1.0;
        self.smartSuggestionAccentGradientLayer.frame = self.smartSuggestionAccentWashView.bounds;
        self.smartSuggestionAccentGradientLayer.colors = gradientColors;
        self.smartSuggestionAccentGradientLayer.locations = @[@0.0, @0.45, @1.0];
        self.smartSuggestionAccentGradientLayer.startPoint = Language.isRTL ? CGPointMake(1.0, 0.0) : CGPointMake(0.0, 0.0);
        self.smartSuggestionAccentGradientLayer.endPoint = Language.isRTL ? CGPointMake(0.0, 1.0) : CGPointMake(1.0, 1.0);

        self.smartSuggestionSurfaceView.backgroundColor = surfaceFill;
        self.smartSuggestionSurfaceView.layer.borderColor = [self pp_resolvedNovaLayerColor:strokeColor].CGColor;
        self.smartSuggestionSurfaceView.layer.shadowColor = [self pp_resolvedNovaLayerColor:suggestionCompanion].CGColor;
        self.smartSuggestionSurfaceView.layer.shadowOpacity = isDark ? 0.16 : 0.13;
        self.smartSuggestionSurfaceView.layer.shadowRadius = 20.0;
        self.smartSuggestionSurfaceView.layer.shadowOffset = CGSizeMake(0.0, 12.0);
        self.smartSuggestionTitleLabel.textColor = [secondaryText colorWithAlphaComponent:0.74];
        self.smartSuggestionTextLabel.textColor = primaryText;
        self.smartSuggestionHintLabel.textColor = [secondaryText colorWithAlphaComponent:0.74];
        self.smartSuggestionActionImageView.tintColor = suggestionAccent;
    };

    self.smartSuggestionSurfaceView.effect = [UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]];
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
    } else {
        [UIView animateWithDuration:0.34
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
        if (previousGradientColors.count == gradientColors.count) {
            CABasicAnimation *colorShift = [CABasicAnimation animationWithKeyPath:@"colors"];
            colorShift.fromValue = previousGradientColors;
            colorShift.toValue = gradientColors;
            colorShift.duration = 0.34;
            colorShift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [self.smartSuggestionAccentGradientLayer addAnimation:colorShift forKey:PPNovaSmartSuggestionColorShiftKey];
        }
    }

    self.smartSuggestionPickerView.effect = [UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]];
    self.smartSuggestionPickerView.backgroundColor = PPNovaDynamicColor([surface colorWithAlphaComponent:0.56],
                                                                        [surface colorWithAlphaComponent:0.36]);
    self.smartSuggestionPickerView.layer.borderColor = [suggestionAccent colorWithAlphaComponent:0.16].CGColor;
    self.smartSuggestionPickerView.layer.shadowColor = [self pp_resolvedNovaLayerColor:suggestionCompanion].CGColor;
    self.smartSuggestionPickerTitleLabel.textColor = primaryText;
    [self pp_updateNovaSmartSuggestionAutoSendButtonAnimated:NO];

    [self.smartSuggestionPickerButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, __unused BOOL *stop) {
        BOOL selected = idx == self.smartSuggestionCurrentIndex;
        UIColor *fillColor = selected
            ? [suggestionAccent colorWithAlphaComponent:0.14]
            : PPNovaDynamicColor([surface colorWithAlphaComponent:0.38],
                                 [UIColor.whiteColor colorWithAlphaComponent:0.055]);
        UIColor *buttonStrokeColor = selected ? [suggestionAccent colorWithAlphaComponent:0.24] : [secondaryText colorWithAlphaComponent:0.10];
        UIColor *titleColor = selected ? suggestionAccent : [primaryText colorWithAlphaComponent:0.88];
        button.backgroundColor = fillColor;
        button.layer.borderColor = [self pp_resolvedNovaLayerColor:buttonStrokeColor].CGColor;
        button.tintColor = titleColor;
        [button setTitleColor:titleColor forState:UIControlStateNormal];
        [button setTitleColor:[titleColor colorWithAlphaComponent:0.72] forState:UIControlStateHighlighted];
    }];
}

- (void)pp_startAmbientBackgroundAnimations {
    [self.emptyStatePulseView.layer removeAllAnimations];
    [self.novaChatBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderTopGlowView.layer removeAllAnimations];
    [self.smartSuggestionAccentWashView.layer removeAnimationForKey:PPNovaSmartSuggestionWashBreathKey];
    [self.smartSuggestionActionImageView.layer removeAnimationForKey:PPNovaSmartSuggestionActionBreathKey];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.emptyStatePulseView.transform = CGAffineTransformIdentity;
        self.novaChatBottomGlowView.transform = CGAffineTransformIdentity;
        self.novaHeaderTopGlowView.transform = CGAffineTransformIdentity;
        self.smartSuggestionAccentWashView.layer.opacity = 1.0;
        self.smartSuggestionActionImageView.transform = CGAffineTransformIdentity;
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.fromValue = @0.985;
    pulse.toValue = @1.025;
    pulse.duration = 4.8;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.emptyStatePulseView.layer addAnimation:pulse forKey:@"pp_novaEmptyPulse"];

    // Top halo (just below the header) — slow inhale, gentle vertical drift, soft breath.
    CABasicAnimation *topHaloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    topHaloScale.fromValue = @0.94;
    topHaloScale.toValue = @1.06;
    topHaloScale.duration = 6.8;
    topHaloScale.autoreverses = YES;
    topHaloScale.repeatCount = HUGE_VALF;
    topHaloScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderTopGlowView.layer addAnimation:topHaloScale forKey:@"pp_novaHeaderTopHaloScale"];

    CABasicAnimation *topHaloDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    topHaloDrift.fromValue = @(-12.0);
    topHaloDrift.toValue = @(8.0);
    topHaloDrift.duration = 7.6;
    topHaloDrift.autoreverses = YES;
    topHaloDrift.repeatCount = HUGE_VALF;
    topHaloDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderTopGlowView.layer addAnimation:topHaloDrift forKey:@"pp_novaHeaderTopHaloDrift"];

    CABasicAnimation *topHaloBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    topHaloBreath.fromValue = @0.78;
    topHaloBreath.toValue = @1.0;
    topHaloBreath.duration = 5.4;
    topHaloBreath.autoreverses = YES;
    topHaloBreath.repeatCount = HUGE_VALF;
    topHaloBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderTopGlowView.layer addAnimation:topHaloBreath forKey:@"pp_novaHeaderTopHaloBreath"];

    // Bottom halo (opposite corner) — counter-phase scale, drift, breath.
    CABasicAnimation *bottomGlowScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    bottomGlowScale.fromValue = @0.965;
    bottomGlowScale.toValue = @1.045;
    bottomGlowScale.duration = 7.4;
    bottomGlowScale.autoreverses = YES;
    bottomGlowScale.repeatCount = HUGE_VALF;
    bottomGlowScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaChatBottomGlowView.layer addAnimation:bottomGlowScale forKey:@"pp_novaBottomGlowScale"];

    CABasicAnimation *bottomGlowDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    bottomGlowDrift.fromValue = @(10.0);
    bottomGlowDrift.toValue = @(-14.0);
    bottomGlowDrift.duration = 8.2;
    bottomGlowDrift.autoreverses = YES;
    bottomGlowDrift.repeatCount = HUGE_VALF;
    bottomGlowDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaChatBottomGlowView.layer addAnimation:bottomGlowDrift forKey:@"pp_novaBottomGlowDrift"];

    CABasicAnimation *bottomGlowBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    bottomGlowBreath.fromValue = @1.0;
    bottomGlowBreath.toValue = @0.74;
    bottomGlowBreath.duration = 6.2;
    bottomGlowBreath.autoreverses = YES;
    bottomGlowBreath.repeatCount = HUGE_VALF;
    bottomGlowBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaChatBottomGlowView.layer addAnimation:bottomGlowBreath forKey:@"pp_novaBottomGlowBreath"];

    [self pp_startNovaSmartSuggestionLiveMotionIfNeeded];
}

- (void)pp_stopAmbientBackgroundAnimations {
    [self.emptyStatePulseView.layer removeAllAnimations];
    [self.novaChatBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderTopGlowView.layer removeAllAnimations];
    [self pp_stopNovaSmartSuggestionLiveMotion];
}

- (void)pp_startNovaSmartSuggestionLiveMotionIfNeeded {
    if (!self.smartSuggestionAccentWashView || !self.smartSuggestionActionImageView || UIAccessibilityIsReduceMotionEnabled()) {
        return;
    }

    CABasicAnimation *washBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    washBreath.fromValue = @0.72;
    washBreath.toValue = @1.0;
    washBreath.duration = 5.6;
    washBreath.autoreverses = YES;
    washBreath.repeatCount = HUGE_VALF;
    washBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.smartSuggestionAccentWashView.layer addAnimation:washBreath forKey:PPNovaSmartSuggestionWashBreathKey];

    CAKeyframeAnimation *actionBreath = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    actionBreath.values = @[@1.0, @1.075, @1.0];
    actionBreath.keyTimes = @[@0.0, @0.48, @1.0];
    actionBreath.duration = 4.8;
    actionBreath.repeatCount = HUGE_VALF;
    actionBreath.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
    ];
    [self.smartSuggestionActionImageView.layer addAnimation:actionBreath forKey:PPNovaSmartSuggestionActionBreathKey];
}

- (void)pp_stopNovaSmartSuggestionLiveMotion {
    [self.smartSuggestionAccentWashView.layer removeAnimationForKey:PPNovaSmartSuggestionWashBreathKey];
    [self.smartSuggestionActionImageView.layer removeAnimationForKey:PPNovaSmartSuggestionActionBreathKey];
    self.smartSuggestionAccentWashView.layer.opacity = 1.0;
    self.smartSuggestionActionImageView.transform = CGAffineTransformIdentity;
}

- (UIColor *)pp_novaHeaderAccentColor {
    return AppPrimaryClr ?: UIColor.systemTealColor;
}

- (UIColor *)pp_novaHeaderCanvasColor {
    return AppBackgroundClr ?: UIColor.secondarySystemBackgroundColor;
}

- (UIColor *)pp_novaHeaderSurfaceColor {
    return AppForgroundColr ?: UIColor.systemBackgroundColor;
}

- (UIBlurEffectStyle)pp_novaHeaderGlassBlurStyle {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIBlurEffectStyleSystemThinMaterialDark
            : UIBlurEffectStyleSystemUltraThinMaterialLight;
    }
    return UIBlurEffectStyleExtraLight;
}

- (UIColor *)pp_novaHeaderPrimaryTextColor {
    return AppPrimaryTextClr ?: UIColor.labelColor;
}

- (UIColor *)pp_novaHeaderSecondaryTextColor {
    return AppSecondaryTextClr ?: UIColor.secondaryLabelColor;
}

- (CGFloat)pp_novaHeaderBackgroundAlphaForCurrentState {
    return self.novaHeaderCollapsed ? 0.35 : 0.65;
}

- (CGFloat)pp_novaHeaderSheenAlphaForCurrentState {
    return self.novaHeaderCollapsed ? 0.42 : 0.72;
}

- (void)pp_loadNovaIdentityAnimationIntoView:(LOTAnimationView *)animationView {
    if (!animationView) {
        return;
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *localCandidates = @[
        @{@"name": @"Ncolored", @"type": @"json"}
    ];
    for (NSDictionary<NSString *, NSString *> *candidate in localCandidates) {
        NSString *path = [[NSBundle mainBundle] pathForResource:candidate[@"name"] ofType:candidate[@"type"]];
        if (path.length == 0) {
            continue;
        }

        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data.length == 0) {
            continue;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        LOTComposition *composition = [json isKindOfClass:NSDictionary.class] ? [LOTComposition animationFromJSON:json] : nil;
        if (composition) {
            animationView.animationSpeed = 0.86;
            [animationView setSceneModel:composition];
            [self pp_revealNovaIdentityAnimationView:animationView];
            return;
        }
    }

    NSArray<NSString *> *paths = @[
        @"LottieAnimations/Ncolored.json"
    ];
    [self pp_loadNovaIdentityAnimationPaths:paths index:0 intoView:animationView];
}

- (void)pp_loadNovaIdentityAnimationPaths:(NSArray<NSString *> *)paths
                                    index:(NSUInteger)index
                                 intoView:(LOTAnimationView *)animationView
{
    if (!animationView) {
        return;
    }

    if (index >= paths.count) {
        __weak typeof(self) weakSelf = self;
        __weak LOTAnimationView *weakAnimationView = animationView;
        [AppClasses setAnimationNamed:@"nova-ring-bg"
                               ToView:animationView
                            withSpeed:0.86
                           completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) self = weakSelf;
                LOTAnimationView *strongAnimationView = weakAnimationView;
                if (!self || self.dismissed || !strongAnimationView || !success) {
                    return;
                }
                [self pp_revealNovaIdentityAnimationView:strongAnimationView];
            });
        }];
        return;
    }

    NSString *path = paths[index];
    __weak typeof(self) weakSelf = self;
    __weak LOTAnimationView *weakAnimationView = animationView;
    [AppClasses fetchLottieJSONFromFirebasePath:path completion:^(NSDictionary *jsonDict, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            LOTAnimationView *strongAnimationView = weakAnimationView;
            if (!self || self.dismissed || !strongAnimationView) {
                return;
            }

            if (error || ![jsonDict isKindOfClass:NSDictionary.class]) {
                [self pp_loadNovaIdentityAnimationPaths:paths index:index + 1 intoView:strongAnimationView];
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (!composition) {
                [self pp_loadNovaIdentityAnimationPaths:paths index:index + 1 intoView:strongAnimationView];
                return;
            }

            strongAnimationView.animationSpeed = 0.86;
            [strongAnimationView setSceneModel:composition];
            [self pp_revealNovaIdentityAnimationView:strongAnimationView];
        });
    }];
}

- (void)pp_revealNovaIdentityAnimationView:(LOTAnimationView *)animationView {
    if (!animationView) {
        return;
    }

    if (UIAccessibilityIsReduceMotionEnabled()) {
        [animationView stop];
        animationView.alpha = 1.0;
        return;
    }

    [animationView play];
    [UIView animateWithDuration:0.44
                          delay:0.08
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        animationView.alpha = 1.0;
        animationView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)setupNovaHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = UIColor.clearColor;
    header.clipsToBounds = NO;
    header.layer.shadowColor = UIColor.blackColor.CGColor;
    header.layer.shadowOpacity = 0.07;
    header.layer.shadowRadius = 30.0;
    header.layer.shadowOffset = CGSizeMake(0.0, 18.0);
    [self.view addSubview:header];
    self.novaHeaderView = header;

    UIVisualEffectView *chromeView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]]];
    chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    chromeView.clipsToBounds = YES;
    chromeView.backgroundColor = [[self pp_novaHeaderSurfaceColor] colorWithAlphaComponent:0.50];
    chromeView.layer.cornerRadius = 32.0;
    chromeView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    chromeView.layer.borderColor = [[self pp_novaHeaderAccentColor] colorWithAlphaComponent:0.12].CGColor;
    chromeView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    chromeView.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        chromeView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [header addSubview:chromeView];
    self.novaHeaderChromeView = chromeView;

    UIView *contentView = chromeView.contentView;
    contentView.clipsToBounds = YES;

    [NSLayoutConstraint activateConstraints:@[
        [chromeView.topAnchor constraintEqualToAnchor:header.topAnchor constant:14.0],
        [chromeView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16.0],
        [chromeView.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16.0],
        [chromeView.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8.0]
    ]];

    UIView *topGlowView = [[UIView alloc] init];
    topGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    topGlowView.userInteractionEnabled = NO;
    topGlowView.backgroundColor = [[self pp_novaHeaderAccentColor] colorWithAlphaComponent:0.16];
    topGlowView.layer.cornerRadius = 150.0;
    topGlowView.layer.shadowColor = [self pp_novaHeaderAccentColor].CGColor;
    topGlowView.layer.shadowOpacity = 0.22;
    topGlowView.layer.shadowRadius = 36.0;
    topGlowView.layer.shadowOffset = CGSizeZero;
    topGlowView.alpha = 0.0;
    if (@available(iOS 13.0, *)) {
        topGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.ambientBackgroundView addSubview:topGlowView];
    self.novaHeaderTopGlowView = topGlowView;

    UIView *bottomGlowView = [[UIView alloc] init];
    bottomGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomGlowView.userInteractionEnabled = NO;
    bottomGlowView.backgroundColor = PPNovaDynamicColor([UIColor.whiteColor colorWithAlphaComponent:0.28],
                                                       [UIColor.whiteColor colorWithAlphaComponent:0.05]);
    bottomGlowView.layer.cornerRadius = 76.0;
    bottomGlowView.layer.shadowColor = UIColor.whiteColor.CGColor;
    bottomGlowView.layer.shadowOpacity = 0.12;
    bottomGlowView.layer.shadowRadius = 18.0;
    bottomGlowView.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        bottomGlowView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:bottomGlowView];
    self.novaHeaderBottomGlowView = bottomGlowView;

    LOTAnimationView *backgroundLottie = [LOTAnimationView new];
    backgroundLottie.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundLottie.userInteractionEnabled = NO;
    backgroundLottie.contentMode = UIViewContentModeScaleAspectFill;
    backgroundLottie.loopAnimation = YES;
    backgroundLottie.animationSpeed = 0.92;
    backgroundLottie.alpha = 0.0;
    [contentView addSubview:backgroundLottie];
    self.novaHeaderBackgroundLottie = backgroundLottie;
    //self.currentHeaderBgAnimationName = @"novawave";

    [NSLayoutConstraint activateConstraints:@[
        [topGlowView.widthAnchor constraintEqualToConstant:300.0],
        [topGlowView.heightAnchor constraintEqualToConstant:300.0],
        [topGlowView.centerYAnchor constraintEqualToAnchor:header.bottomAnchor constant:-32.0],
        [topGlowView.centerXAnchor constraintEqualToAnchor:header.centerXAnchor constant:104.0],

        [bottomGlowView.widthAnchor constraintEqualToConstant:152.0],
        [bottomGlowView.heightAnchor constraintEqualToConstant:152.0],
        [bottomGlowView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:46.0],
        [bottomGlowView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:18.0],

        [backgroundLottie.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [backgroundLottie.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [backgroundLottie.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [backgroundLottie.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    UIView *sheenView = [[UIView alloc] init];
    sheenView.translatesAutoresizingMaskIntoConstraints = NO;
    sheenView.userInteractionEnabled = NO;
    sheenView.alpha = [self pp_novaHeaderSheenAlphaForCurrentState];
    sheenView.backgroundColor = [[self pp_novaHeaderAccentColor] colorWithAlphaComponent:0.045];
    sheenView.layer.cornerRadius = 56.0;
    if (@available(iOS 13.0, *)) {
        sheenView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:sheenView];
    self.novaHeaderSheenView = sheenView;

    [NSLayoutConstraint activateConstraints:@[
        [sheenView.widthAnchor constraintEqualToConstant:112.0],
        [sheenView.heightAnchor constraintEqualToConstant:112.0],
        [sheenView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:-28.0],
        [sheenView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:28.0]
    ]];

    NSArray<NSDictionary<NSString *, NSNumber *> *> *dotSpecs = @[
        @{@"x": @22.0,  @"y": @20.0, @"s": @5.0},
        @{@"x": @70.0,  @"y": @72.0, @"s": @4.0},
        @{@"x": @126.0, @"y": @34.0, @"s": @5.0},
        @{@"x": @202.0, @"y": @112.0, @"s": @4.0},
        @{@"x": @248.0, @"y": @62.0, @"s": @5.0}
    ];
    NSMutableArray<UIView *> *motionDots = [NSMutableArray arrayWithCapacity:dotSpecs.count];
    for (NSDictionary<NSString *, NSNumber *> *spec in dotSpecs) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.userInteractionEnabled = NO;
        dot.alpha = 0.22;
        CGFloat size = spec[@"s"].doubleValue;
        dot.layer.cornerRadius = size / 2.0;
        dot.layer.shadowOpacity = 0.10;
        dot.layer.shadowRadius = 5.0;
        dot.layer.shadowOffset = CGSizeZero;
        [contentView addSubview:dot];
        [NSLayoutConstraint activateConstraints:@[
            [dot.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:spec[@"x"].doubleValue],
            [dot.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:spec[@"y"].doubleValue],
            [dot.widthAnchor constraintEqualToConstant:size],
            [dot.heightAnchor constraintEqualToConstant:size]
        ]];
        [motionDots addObject:dot];
    }
    self.novaHeaderMotionDots = motionDots.copy;

    UIColor *accentColor = [self pp_novaHeaderAccentColor];

    UIView *brandHalo = [[UIView alloc] init];
    brandHalo.translatesAutoresizingMaskIntoConstraints = NO;
    brandHalo.userInteractionEnabled = NO;
    brandHalo.backgroundColor = [AppBackgroundClr colorWithAlphaComponent:0.10];
    brandHalo.layer.cornerRadius = 30.0;
    brandHalo.layer.shadowColor = accentColor.CGColor;
    brandHalo.layer.shadowOpacity = 0.16;
    brandHalo.layer.shadowRadius = 18.0;
    brandHalo.layer.shadowOffset = CGSizeZero;
    if (@available(iOS 13.0, *)) {
        brandHalo.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandHalo];
    self.headerBrandHaloView = brandHalo;

    LOTAnimationView *loadingLottie = [LOTAnimationView animationNamed:@"nova_loading"];
    loadingLottie.translatesAutoresizingMaskIntoConstraints = NO;
    loadingLottie.userInteractionEnabled = NO;
    loadingLottie.contentMode = UIViewContentModeScaleAspectFit;
    loadingLottie.loopAnimation = YES;
    loadingLottie.animationSpeed = 1.0;
    loadingLottie.alpha = 0.0;
    loadingLottie.clipsToBounds = YES;
    [brandHalo addSubview:loadingLottie];
    self.novaLoadingLottie = loadingLottie;

    UIView *brandRing = [[UIView alloc] init];
    brandRing.translatesAutoresizingMaskIntoConstraints = NO;
    brandRing.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    brandRing.layer.cornerRadius = 29.0;
    brandRing.layer.borderWidth = 1.2 / UIScreen.mainScreen.scale;
    brandRing.layer.borderColor = [accentColor colorWithAlphaComponent:0.24].CGColor;
    brandRing.layer.shadowColor = UIColor.blackColor.CGColor;
    brandRing.layer.shadowOpacity = 0.07;
    brandRing.layer.shadowRadius = 17.0;
    brandRing.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    if (@available(iOS 13.0, *)) {
        brandRing.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandRing];
    self.headerBrandRingView = brandRing;

    UIView *brandMark = [[UIView alloc] init];
    brandMark.translatesAutoresizingMaskIntoConstraints = NO;
    brandMark.backgroundColor = AppClearClr;
    brandMark.clipsToBounds = YES;
    brandMark.layer.cornerRadius = 31.0;
    brandMark.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    brandMark.layer.borderColor = [accentColor colorWithAlphaComponent:0.14].CGColor;
    brandMark.layer.shadowColor = UIColor.blackColor.CGColor;
    brandMark.layer.shadowOpacity = 0.08;
    brandMark.layer.shadowRadius = 12.0;
    brandMark.layer.shadowOffset = CGSizeMake(0.0, 7.0);
    if (@available(iOS 13.0, *)) {
        brandMark.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [contentView addSubview:brandMark];
    self.headerBrandMarkView = brandMark;

    LOTAnimationView *identityLottie = [[LOTAnimationView alloc] init];
    identityLottie.translatesAutoresizingMaskIntoConstraints = NO;
    identityLottie.userInteractionEnabled = NO;
    identityLottie.contentMode = UIViewContentModeScaleAspectFit;
    identityLottie.loopAnimation = YES;
    identityLottie.animationSpeed = 0.86;
    identityLottie.alpha = 0.0;
    identityLottie.transform = CGAffineTransformMakeScale(0.94, 0.94);
    identityLottie.clipsToBounds = YES;
    [brandMark addSubview:identityLottie];
    self.novaRingBackgroundLottie = identityLottie;
    [self pp_loadNovaIdentityAnimationIntoView:identityLottie];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    nameLabel.textColor = UIColor.whiteColor;
    nameLabel.text = kLang(@"nova_title");
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.minimumScaleFactor = 0.82;
    if (!Language.isRTL) {
        // Subtle premium tracking on the wordmark.
        NSAttributedString *attr = [[NSAttributedString alloc]
                                    initWithString:nameLabel.text
                                    attributes:@{ NSKernAttributeName: @1.4 }];
        nameLabel.attributedText = attr;
    }
    [contentView addSubview:nameLabel];
    self.headerNameLabel = nameLabel;

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor.whiteColor colorWithAlphaComponent:0.82]; // Off-white
    subtitleLabel.text = kLang(@"nova_subtitle");
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.adjustsFontSizeToFitWidth = YES;
    subtitleLabel.minimumScaleFactor = 0.86;
    [contentView addSubview:subtitleLabel];
    self.headerSubtitleLabel = subtitleLabel;

    UIView *liveCapsule = [[UIView alloc] init];
    liveCapsule.translatesAutoresizingMaskIntoConstraints = NO;
    liveCapsule.backgroundColor = [accentColor colorWithAlphaComponent:0.10];
    liveCapsule.layer.cornerRadius = 13.0;
    liveCapsule.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        liveCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    }
    liveCapsule.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    liveCapsule.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55].CGColor;
    [contentView addSubview:liveCapsule];
    self.headerLiveCapsule = liveCapsule;

    UIView *liveContent = liveCapsule;

    UIView *accentDot = [[UIView alloc] init];
    accentDot.translatesAutoresizingMaskIntoConstraints = NO;
    accentDot.backgroundColor = accentColor;
    accentDot.layer.cornerRadius = 3.5;
    accentDot.layer.shadowColor = accentColor.CGColor;
    accentDot.layer.shadowOpacity = 0.55;
    accentDot.layer.shadowRadius = 4.0;
    accentDot.layer.shadowOffset = CGSizeZero;
    [liveContent addSubview:accentDot];
    self.statusDot = accentDot;

    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    statusLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    statusLabel.text = kLang(@"nova_status_online");
    [liveContent addSubview:statusLabel];
    self.statusLabel = statusLabel;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                          weight:UIImageSymbolWeightSemibold];
        UIImage *xmark = [UIImage systemImageNamed:@"xmark" withConfiguration:cfg];
        [closeButton setImage:xmark forState:UIControlStateNormal];
    } else {
        [closeButton setTitle:@"✕" forState:UIControlStateNormal];
    }
    closeButton.tintColor = [AppPrimaryTextClr colorWithAlphaComponent:0.62];
    closeButton.layer.cornerRadius = 18.0;
    closeButton.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    closeButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    closeButton.layer.shadowColor = UIColor.blackColor.CGColor;
    closeButton.layer.shadowOpacity = 0.035;
    closeButton.layer.shadowRadius = 10.0;
    closeButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    if (@available(iOS 13.0, *)) {
        closeButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    closeButton.accessibilityLabel = kLang(@"nova_close_accessibility");
    closeButton.accessibilityTraits = UIAccessibilityTraitButton;
    [closeButton addTarget:self
                    action:@selector(pp_handleNovaHeaderControlPressDown:)
          forControlEvents:UIControlEventTouchDown];
    [closeButton addTarget:self
                    action:@selector(pp_handleNovaHeaderControlPressUp:)
          forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [closeButton addTarget:self
                    action:@selector(pp_handleNovaCloseTapped:)
          forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:closeButton];
    self.closeButton = closeButton;

    // History button starts on the leading edge, then joins the trailing action cluster when collapsed.
    UIButton *historyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    historyButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                          weight:UIImageSymbolWeightSemibold];
        UIImage *clockIcon = [UIImage systemImageNamed:@"clock.arrow.circlepath" withConfiguration:cfg];
        [historyButton setImage:clockIcon forState:UIControlStateNormal];
    } else {
        [historyButton setTitle:@"⏱" forState:UIControlStateNormal];
    }
    historyButton.tintColor = [AppPrimaryTextClr colorWithAlphaComponent:0.55];
    historyButton.layer.cornerRadius = 18.0;
    historyButton.layer.borderWidth = 0.5 / UIScreen.mainScreen.scale;
    historyButton.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    historyButton.layer.shadowColor = UIColor.blackColor.CGColor;
    historyButton.layer.shadowOpacity = 0.035;
    historyButton.layer.shadowRadius = 10.0;
    historyButton.layer.shadowOffset = CGSizeMake(0.0, 5.0);
    if (@available(iOS 13.0, *)) {
        historyButton.layer.cornerCurve = kCACornerCurveContinuous;
    }
    historyButton.accessibilityLabel = kLang(@"nova_history_accessibility");
    [historyButton addTarget:self
                      action:@selector(pp_handleNovaHeaderControlPressDown:)
            forControlEvents:UIControlEventTouchDown];
    [historyButton addTarget:self
                      action:@selector(pp_handleNovaHeaderControlPressUp:)
            forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [historyButton addTarget:self
                      action:@selector(pp_handleNovaHistoryTapped:)
            forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:historyButton];
    self.historyButton = historyButton;

    UIView *hairlineHost = [[UIView alloc] init];
    hairlineHost.translatesAutoresizingMaskIntoConstraints = NO;
    hairlineHost.userInteractionEnabled = NO;
    hairlineHost.backgroundColor = [UIColor.separatorColor colorWithAlphaComponent:0.28];
    [contentView addSubview:hairlineHost];
    self.headerHairlineHost = hairlineHost;

    header.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", nameLabel.text, statusLabel.text];

    CGFloat topOffset = 20.0; // Sheet grabber clearance inside the Pro-login style host.

    // Expanded bottom constraint (online status capsule)
    self.novaHeaderExpandedBottomConstraint = [liveCapsule.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-14.0];

    // Collapsed bottom constraint (avatar ring)
    self.novaHeaderCollapsedBottomConstraint = [brandRing.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-12.0];
    self.novaHeaderCollapsedBottomConstraint.active = NO;

    // Brand Ring (Avatar) Constraints
    self.brandRingTopConstraint = [brandRing.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset];
    self.brandRingCenterXConstraint = [brandRing.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor];
    self.brandRingLeadingConstraint = [brandRing.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0];
    self.brandRingCollapsedCenterYConstraint = [brandRing.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor];
    self.brandRingCollapsedCenterYConstraint.active = NO;
    self.closeButtonTopConstraint = [closeButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset];
    self.closeButtonCollapsedCenterYConstraint = [closeButton.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor];
    self.closeButtonCollapsedCenterYConstraint.active = NO;
    self.historyButtonTopConstraint = [historyButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:topOffset];
    self.historyButtonCollapsedCenterYConstraint = [historyButton.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor];
    self.historyButtonCollapsedCenterYConstraint.active = NO;

    // Name Label (Title) Constraints
    self.nameLabelCenterXConstraint = [nameLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor];
    self.nameLabelLeadingConstraint = [nameLabel.leadingAnchor constraintEqualToAnchor:brandRing.trailingAnchor constant:14.0];
    self.nameLabelTopConstraint = [nameLabel.topAnchor constraintEqualToAnchor:brandRing.bottomAnchor constant:3.0]; // Moved up (8.0 -> 3.0)
    self.nameLabelCenterYConstraint = [nameLabel.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor constant:0.0];

    // Subtitle Label Constraints
    self.subtitleLabelCenterXConstraint = [subtitleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor];
    self.subtitleLabelLeadingConstraint = [subtitleLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor];
    self.subtitleLabelTopConstraint = [subtitleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor constant:2.0];

    self.historyButtonLeadingConstraint = [historyButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:12.0];
    self.historyButtonCollapsedTrailingConstraint = [historyButton.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-8.0];
    self.historyButtonCollapsedTrailingConstraint.active = NO;
    self.headerNameCollapsedTrailingConstraint = [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:historyButton.leadingAnchor constant:-10.0];
    self.headerNameCollapsedTrailingConstraint.active = NO;
    self.headerSubtitleCollapsedTrailingConstraint = [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:historyButton.leadingAnchor constant:-10.0];
    self.headerSubtitleCollapsedTrailingConstraint.active = NO;

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [brandHalo.centerXAnchor constraintEqualToAnchor:brandRing.centerXAnchor],
        [brandHalo.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor],
        [brandHalo.widthAnchor constraintEqualToConstant:60.0],
        [brandHalo.heightAnchor constraintEqualToConstant:60.0],

        [loadingLottie.centerXAnchor constraintEqualToAnchor:brandHalo.centerXAnchor],
        [loadingLottie.centerYAnchor constraintEqualToAnchor:brandHalo.centerYAnchor],
        [loadingLottie.widthAnchor constraintEqualToAnchor:brandHalo.widthAnchor constant:0.0],
        [loadingLottie.heightAnchor constraintEqualToAnchor:brandHalo.heightAnchor constant:0.0],

        self.brandRingTopConstraint,
        self.brandRingCenterXConstraint,
        [brandRing.widthAnchor constraintEqualToConstant:58.0],
        [brandRing.heightAnchor constraintEqualToConstant:58.0],

        [brandMark.centerXAnchor constraintEqualToAnchor:brandRing.centerXAnchor],
        [brandMark.centerYAnchor constraintEqualToAnchor:brandRing.centerYAnchor],
        [brandMark.widthAnchor constraintEqualToConstant:62.0],
        [brandMark.heightAnchor constraintEqualToConstant:62.0],

        [identityLottie.topAnchor constraintEqualToAnchor:brandMark.topAnchor constant:10.0],
        [identityLottie.leadingAnchor constraintEqualToAnchor:brandMark.leadingAnchor constant:10.0],
        [identityLottie.trailingAnchor constraintEqualToAnchor:brandMark.trailingAnchor constant:-10.0],
        [identityLottie.bottomAnchor constraintEqualToAnchor:brandMark.bottomAnchor constant:-10.0],

        self.nameLabelCenterXConstraint,
        self.nameLabelTopConstraint,
        [nameLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        self.subtitleLabelCenterXConstraint,
        self.subtitleLabelTopConstraint,
        [subtitleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        [liveCapsule.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:8.0],
        [liveCapsule.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [liveCapsule.heightAnchor constraintEqualToConstant:26.0],
        self.novaHeaderExpandedBottomConstraint,

        [accentDot.leadingAnchor constraintEqualToAnchor:liveContent.leadingAnchor constant:10.0],
        [accentDot.centerYAnchor constraintEqualToAnchor:liveContent.centerYAnchor],
        [accentDot.widthAnchor constraintEqualToConstant:7.0],
        [accentDot.heightAnchor constraintEqualToConstant:7.0],

        [statusLabel.leadingAnchor constraintEqualToAnchor:accentDot.trailingAnchor constant:6.0],
        [statusLabel.trailingAnchor constraintEqualToAnchor:liveContent.trailingAnchor constant:-12.0],
        [statusLabel.centerYAnchor constraintEqualToAnchor:liveContent.centerYAnchor],

        [hairlineHost.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [hairlineHost.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [hairlineHost.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [hairlineHost.heightAnchor constraintEqualToConstant:1.0],

        // Close button: top-trailing of header, auto-flips for RTL via semantic attribute.
        self.closeButtonTopConstraint,
        [closeButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-12.0],
        [closeButton.widthAnchor constraintEqualToConstant:36.0],
        [closeButton.heightAnchor constraintEqualToConstant:36.0],

        // History button: expanded on leading side; collapsed beside trailing close action.
        self.historyButtonTopConstraint,
        self.historyButtonLeadingConstraint,
        [historyButton.widthAnchor constraintEqualToConstant:36.0],
        [historyButton.heightAnchor constraintEqualToConstant:36.0]
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleNovaHeaderTap:)];
    tap.cancelsTouchesInView = NO;
    [header addGestureRecognizer:tap];

    [self pp_applyNovaSurfaceColors];
}

- (CALayer *)pp_novaHeaderLiquidBorderHostLayer {
    if ([self.novaHeaderChromeView isKindOfClass:UIVisualEffectView.class]) {
        return ((UIVisualEffectView *)self.novaHeaderChromeView).contentView.layer;
    }
    return self.novaHeaderChromeView.layer;
}

- (void)pp_installNovaHeaderLiquidBorderIfNeeded {
    if (!self.novaHeaderChromeView || self.novaHeaderLiquidBorderLayer) {
        return;
    }

    CALayer *host = [self pp_novaHeaderLiquidBorderHostLayer];

    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.fillColor = UIColor.clearColor.CGColor;
    borderLayer.lineCap = kCALineCapRound;
    borderLayer.lineJoin = kCALineJoinRound;
    borderLayer.lineWidth = 1.0 / UIScreen.mainScreen.scale;
    borderLayer.opacity = 0.72;
    borderLayer.zPosition = 60.0;
    [host addSublayer:borderLayer];
    self.novaHeaderLiquidBorderLayer = borderLayer;

    CAShapeLayer *highlightLayer = [CAShapeLayer layer];
    highlightLayer.fillColor = UIColor.clearColor.CGColor;
    highlightLayer.lineCap = kCALineCapRound;
    highlightLayer.lineJoin = kCALineJoinRound;
    highlightLayer.lineWidth = 1.55 / UIScreen.mainScreen.scale;
    highlightLayer.opacity = 0.36;
    highlightLayer.shadowOpacity = 0.32;
    highlightLayer.shadowRadius = 6.0;
    highlightLayer.shadowOffset = CGSizeZero;
    highlightLayer.zPosition = 61.0;
    [host addSublayer:highlightLayer];
    self.novaHeaderLiquidHighlightLayer = highlightLayer;

    [self pp_updateNovaHeaderLiquidBorderPath];
}

- (CGFloat)pp_novaHeaderChromeCornerRadiusForBounds:(CGRect)bounds {
    CGFloat height = CGRectGetHeight(bounds);
    if (height <= 0.0) {
        return self.novaHeaderCollapsed ? 28.0 : 32.0;
    }
    if (self.novaHeaderCollapsed) {
        return height / 2.0;
    }
    return MIN(32.0, MAX(18.0, height * 0.24));
}

- (void)pp_updateNovaHeaderCollapsedGeometry {
    if (!self.novaHeaderChromeView) {
        return;
    }

    CGRect chromeBounds = self.novaHeaderChromeView.bounds;
    if (!CGRectIsEmpty(chromeBounds)) {
        CGFloat chromeRadius = [self pp_novaHeaderChromeCornerRadiusForBounds:chromeBounds];
        self.novaHeaderChromeView.layer.cornerRadius = chromeRadius;
        if (!CGRectIsEmpty(self.novaHeaderChromeView.frame)) {
            self.novaHeaderView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.novaHeaderChromeView.frame
                                                                             cornerRadius:chromeRadius].CGPath;
        }
    }

    NSMutableArray<UIView *> *circleViews = [NSMutableArray array];
    if (self.headerBrandHaloView) { [circleViews addObject:self.headerBrandHaloView]; }
    if (self.headerBrandRingView) { [circleViews addObject:self.headerBrandRingView]; }
    if (self.headerBrandMarkView) { [circleViews addObject:self.headerBrandMarkView]; }
    if (self.novaRingBackgroundLottie) { [circleViews addObject:self.novaRingBackgroundLottie]; }
    if (self.novaLoadingLottie) { [circleViews addObject:self.novaLoadingLottie]; }
    if (self.closeButton) { [circleViews addObject:self.closeButton]; }
    if (self.historyButton) { [circleViews addObject:self.historyButton]; }
    if (self.headerLiveCapsule) { [circleViews addObject:self.headerLiveCapsule]; }
    if (self.statusDot) { [circleViews addObject:self.statusDot]; }
    for (UIView *view in circleViews) {
        if (!view.superview || CGRectIsEmpty(view.bounds)) {
            continue;
        }
        CGFloat radius = MIN(CGRectGetWidth(view.bounds), CGRectGetHeight(view.bounds)) / 2.0;
        view.layer.cornerRadius = radius;
        view.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:radius].CGPath;
    }
}

- (void)pp_updateNovaHeaderLiquidBorderPath {
    if (!self.novaHeaderChromeView || !self.novaHeaderLiquidBorderLayer || !self.novaHeaderLiquidHighlightLayer) {
        return;
    }

    CGRect bounds = self.novaHeaderChromeView.bounds;
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat inset = MAX(1.0 / scale, 0.5);
    CGRect pathRect = CGRectInset(bounds, inset, inset);
    CGFloat radius = [self pp_novaHeaderChromeCornerRadiusForBounds:pathRect];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:pathRect cornerRadius:radius];
    CGFloat perimeter = MAX(1.0, ((CGRectGetWidth(pathRect) + CGRectGetHeight(pathRect)) * 2.0) - (8.0 * radius) + ((CGFloat)M_PI * 2.0 * radius));
    CGFloat dashLength = MAX(44.0, MIN(86.0, perimeter * 0.13));
    CGFloat gapLength = MAX(120.0, perimeter - dashLength);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.novaHeaderLiquidBorderLayer.frame = bounds;
    self.novaHeaderLiquidHighlightLayer.frame = bounds;
    self.novaHeaderLiquidBorderLayer.path = path.CGPath;
    self.novaHeaderLiquidHighlightLayer.path = path.CGPath;
    self.novaHeaderLiquidHighlightLayer.shadowPath = path.CGPath;
    self.novaHeaderLiquidHighlightLayer.lineDashPattern = @[@(dashLength), @(gapLength)];
    [CATransaction commit];
}

- (void)pp_handleNovaHeaderTap:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:self.closeButton];
    if (!self.closeButton.hidden && CGRectContainsPoint(self.closeButton.bounds, point)) {
        return;
    }
    CGPoint historyPoint = [tap locationInView:self.historyButton];
    if (!self.historyButton.hidden && CGRectContainsPoint(self.historyButton.bounds, historyPoint)) {
        return;
    }
    if (self.novaHeaderCollapsed) {
        [self pp_setNovaHeaderCollapsed:NO animated:YES];
    }
}

- (void)pp_setNovaHeaderCollapsed:(BOOL)collapsed animated:(BOOL)animated {
    [self pp_setNovaHeaderCollapsed:collapsed animated:animated updateInsets:YES];
}

- (void)pp_setNovaHeaderCollapsed:(BOOL)collapsed animated:(BOOL)animated updateInsets:(BOOL)updateInsets {
    if (!self.novaHeaderView || self.novaHeaderCollapsed == collapsed) {
        return;
    }

    self.novaHeaderCollapsed = collapsed;
    self.novaHeaderExpandedBottomConstraint.active = !collapsed;
    self.novaHeaderCollapsedBottomConstraint.active = collapsed;

    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    NSTimeInterval duration = (animated && !reduceMotion) ? (collapsed ? 0.32 : 0.46) : 0.0;
    CGFloat capsuleAlpha = collapsed ? 0.0 : 1.0;
    CGFloat subtitleAlpha = collapsed ? 0.0 : 1.0;
    CGAffineTransform textTransform = collapsed ? CGAffineTransformMakeTranslation(0.0, -8.0) : CGAffineTransformIdentity;
    CGAffineTransform ringTransform = collapsed ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
    CGAffineTransform haloTransform = collapsed ? CGAffineTransformMakeScale(0.78, 0.78) : CGAffineTransformIdentity;
    CGAffineTransform glowTransform = collapsed ? CGAffineTransformMakeTranslation(0.0, -10.0) : CGAffineTransformIdentity;

    void (^changes)(void) = ^{
        self.headerNameLabel.alpha = 1.0;
        self.headerSubtitleLabel.alpha = subtitleAlpha;
        self.headerLiveCapsule.alpha = capsuleAlpha;

        // Toggle Layout Constraints
        self.brandRingTopConstraint.active = !collapsed;
        self.brandRingCenterXConstraint.active = !collapsed;
        self.brandRingLeadingConstraint.active = collapsed;
        self.brandRingCollapsedCenterYConstraint.active = collapsed;
        self.closeButtonTopConstraint.active = !collapsed;
        self.closeButtonCollapsedCenterYConstraint.active = collapsed;
        self.historyButtonTopConstraint.active = !collapsed;
        self.historyButtonCollapsedCenterYConstraint.active = collapsed;

        self.nameLabelCenterXConstraint.active = !collapsed;
        self.nameLabelLeadingConstraint.active = collapsed;

        self.nameLabelTopConstraint.active = !collapsed;
        self.nameLabelCenterYConstraint.active = collapsed;

        self.subtitleLabelCenterXConstraint.active = !collapsed;
        self.subtitleLabelLeadingConstraint.active = collapsed;
        self.historyButtonLeadingConstraint.active = !collapsed;
        self.historyButtonCollapsedTrailingConstraint.active = collapsed;
        self.headerNameCollapsedTrailingConstraint.active = collapsed;
        self.headerSubtitleCollapsedTrailingConstraint.active = collapsed;

        // Update Alignment
        self.headerNameLabel.textAlignment = collapsed ? NSTextAlignmentNatural : NSTextAlignmentCenter;
        self.headerSubtitleLabel.textAlignment = collapsed ? NSTextAlignmentNatural : NSTextAlignmentCenter;

        self.headerNameLabel.transform = collapsed ? CGAffineTransformIdentity : textTransform;
        self.headerSubtitleLabel.transform = collapsed ? CGAffineTransformIdentity : textTransform;

        self.headerLiveCapsule.transform = collapsed ? CGAffineTransformMakeTranslation(0.0, -10.0) : CGAffineTransformIdentity;
        self.headerBrandHaloView.alpha = collapsed ? 0.96 : 1.0;
        self.headerBrandHaloView.transform = haloTransform;
        self.headerBrandRingView.transform = ringTransform;
        self.headerBrandMarkView.transform = ringTransform;
        self.novaRingBackgroundLottie.transform = collapsed ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
        self.novaHeaderBottomGlowView.alpha = collapsed ? 0.50 : 1.0;
        self.novaHeaderBottomGlowView.transform = collapsed ? CGAffineTransformMakeTranslation(0.0, 8.0) : CGAffineTransformIdentity;
        (void)glowTransform;
        self.novaHeaderSheenView.alpha = [self pp_novaHeaderSheenAlphaForCurrentState];
        self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
        self.novaHeaderView.layer.shadowOpacity = collapsed ? 0.045 : 0.07;
        [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
            dot.alpha = collapsed ? 0.12 : (idx % 2 == 0 ? 0.28 : 0.20);
            dot.transform = collapsed ? CGAffineTransformMakeScale(0.82, 0.82) : CGAffineTransformIdentity;
        }];

        // Close button: collapse to trailing edge with reduced scale/opacity
        CGFloat closeAlpha = collapsed ? 0.45 : 1.0;
        CGAffineTransform closeTransform = collapsed ? CGAffineTransformMakeScale(0.82, 0.82) : CGAffineTransformIdentity;
        self.closeButton.alpha = closeAlpha;
        self.closeButton.transform = closeTransform;

        // History button: collapse beside the trailing close action so history stays reachable.
        self.historyButton.alpha = collapsed ? 0.90 : 1.0;
        self.historyButton.transform = collapsed ? CGAffineTransformMakeScale(0.90, 0.90) : CGAffineTransformIdentity;

        [self.view layoutIfNeeded];
        [self pp_updateNovaHeaderCollapsedGeometry];
        [self pp_updateNovaHeaderLiquidBorderPath];
    };

    if (updateInsets) {
       // [self pp_applyNovaTableInsetsForCurrentHeaderState];
    }

    if (duration <= 0.0) {
        changes();
        [self pp_startHeaderLiveAnimations];
        return;
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.91
          initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:changes
                     completion:^(__unused BOOL finished) {
        [self pp_startHeaderLiveAnimations];
    }];
}

- (void)pp_applyNovaTableInsetsForCurrentHeaderState {
    if (!self.tableView) {
        return;
    }

    CGFloat topInset = (self.novaHeaderCollapsed ? PPNovaCollapsedTableTopInset : PPNovaExpandedTableTopInset) + 12.0;
    UIEdgeInsets inset = self.tableView.contentInset;
    inset.top = topInset;
    inset.bottom = 0.0;
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

- (void)pp_handleNovaHeaderControlPressDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.alpha = 0.78;
        return;
    }

    [UIView animateWithDuration:0.10
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.94, 0.94);
        sender.alpha = 0.82;
    } completion:nil];
}

- (void)pp_handleNovaHeaderControlPressUp:(UIButton *)sender {
    CGFloat targetAlpha = 1.0;
    CGAffineTransform targetTransform = CGAffineTransformIdentity;
    if (self.novaHeaderCollapsed) {
        if (sender == self.closeButton) {
            targetAlpha = 0.45;
            targetTransform = CGAffineTransformMakeScale(0.82, 0.82);
        } else if (sender == self.historyButton) {
            targetAlpha = 0.90;
            targetTransform = CGAffineTransformMakeScale(0.90, 0.90);
        }
    }

    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.18
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.18
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sender.transform = targetTransform;
        sender.alpha = targetAlpha;
    } completion:nil];
}

- (void)pp_handleNovaCloseTapped:(UIButton *)sender {
    [self pp_handleNovaHeaderControlPressUp:sender];
    [self.view endEditing:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_handleNovaHistoryTapped:(UIButton *)sender {
    [self pp_handleNovaHeaderControlPressUp:sender];
    PPNovaLocalChatMemory *memory = [PPNovaLocalChatMemory sharedMemory];
    NSArray<NSDictionary *> *history = [memory allMessages] ?: @[];

    PPNovaHistorySheetViewController *sheetVC = [[PPNovaHistorySheetViewController alloc] initWithMessages:history];
    sheetVC.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = sheetVC.sheetPresentationController;
        if (sheet) {
            if (@available(iOS 16.0, *)) {
                UISheetPresentationControllerDetentIdentifier compactIdentifier = @"pp.nova.history.compact";
                UISheetPresentationControllerDetent *compact =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:compactIdentifier
                                                                        resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                    return MIN(context.maximumDetentValue, MAX(360.0, context.maximumDetentValue * 0.56));
                }];
                sheet.detents = @[compact, UISheetPresentationControllerDetent.largeDetent];
                sheet.selectedDetentIdentifier = compactIdentifier;
            } else {
                sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent,
                                  UISheetPresentationControllerDetent.largeDetent];
            }
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 34.0;
            sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        }
    }

    [self presentViewController:sheetVC animated:YES completion:nil];
}

- (void)pp_startHeaderLiveAnimations {
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();

    [self.statusDot.layer removeAllAnimations];
    [self.novaHeaderBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderSheenView.layer removeAllAnimations];
    [self.headerBrandHaloView.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.novaHeaderLiquidBorderLayer removeAllAnimations];
    [self.novaHeaderLiquidHighlightLayer removeAllAnimations];
    for (UIView *dot in self.novaHeaderMotionDots) {
        [dot.layer removeAllAnimations];
    }
    [self pp_updateNovaHeaderLiquidBorderPath];
    if (reduceMotion) {
        self.novaHeaderLiquidBorderLayer.opacity = self.novaHeaderCollapsed ? 0.52 : 0.68;
        self.novaHeaderLiquidHighlightLayer.opacity = self.novaHeaderCollapsed ? 0.18 : 0.28;
        self.statusDot.alpha = 1.0;
        self.statusDot.transform = CGAffineTransformIdentity;
        self.novaHeaderBottomGlowView.transform = CGAffineTransformIdentity;
        self.novaHeaderSheenView.transform = CGAffineTransformIdentity;
        self.headerBrandHaloView.alpha = self.novaHeaderCollapsed ? 0.56 : 1.0;
        self.headerBrandHaloView.transform = self.novaHeaderCollapsed ? CGAffineTransformMakeScale(0.78, 0.78) : CGAffineTransformIdentity;
        self.headerBrandRingView.alpha = 1.0;
        self.headerBrandRingView.transform = self.novaHeaderCollapsed ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
        self.headerBrandMarkView.transform = self.headerBrandRingView.transform;
        [self.novaHeaderBackgroundLottie stop];
        self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
        [self.novaRingBackgroundLottie stop];
        [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
            dot.alpha = self.novaHeaderCollapsed ? 0.12 : (idx % 2 == 0 ? 0.28 : 0.20);
            dot.transform = CGAffineTransformIdentity;
        }];
        return;
    }

    [self.novaHeaderBackgroundLottie play];
    self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
    [self.novaRingBackgroundLottie play];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.88;
    scale.toValue = @1.08;
    scale.duration = 2.4;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.statusDot.layer addAnimation:scale forKey:@"pp_statusDotScale"];

    CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    opacity.fromValue = @0.62;
    opacity.toValue = @1.0;
    opacity.duration = 2.4;
    opacity.autoreverses = YES;
    opacity.repeatCount = HUGE_VALF;
    opacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.statusDot.layer addAnimation:opacity forKey:@"pp_statusDotOpacity"];

    CABasicAnimation *bottomGlowDrift = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    bottomGlowDrift.fromValue = @(10.0);
    bottomGlowDrift.toValue = @(-2.0);
    bottomGlowDrift.duration = 5.8;
    bottomGlowDrift.autoreverses = YES;
    bottomGlowDrift.repeatCount = HUGE_VALF;
    bottomGlowDrift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderBottomGlowView.layer addAnimation:bottomGlowDrift forKey:@"pp_novaHeaderBottomGlowDrift"];

    CABasicAnimation *sheenBreath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    sheenBreath.fromValue = @([self pp_novaHeaderSheenAlphaForCurrentState] * 0.62);
    sheenBreath.toValue = @([self pp_novaHeaderSheenAlphaForCurrentState]);
    sheenBreath.duration = 5.2;
    sheenBreath.autoreverses = YES;
    sheenBreath.repeatCount = HUGE_VALF;
    sheenBreath.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderSheenView.layer addAnimation:sheenBreath forKey:@"pp_novaHeaderSheenBreath"];

    CFTimeInterval baseTime = CACurrentMediaTime();
    [self.novaHeaderMotionDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        CAKeyframeAnimation *dotScale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        dotScale.values = @[@0.82, @1.28, @0.92];
        dotScale.keyTimes = @[@0.0, @0.48, @1.0];
        dotScale.duration = 4.6 + (idx * 0.35);
        dotScale.repeatCount = HUGE_VALF;
        dotScale.autoreverses = YES;
        dotScale.beginTime = baseTime + (idx * 0.18);
        dotScale.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
        ];
        [dot.layer addAnimation:dotScale forKey:@"pp_novaHeaderDotScale"];

        CAKeyframeAnimation *dotOpacity = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        CGFloat baseAlpha = self.novaHeaderCollapsed ? 0.12 : (idx % 2 == 0 ? 0.28 : 0.20);
        dotOpacity.values = @[@(baseAlpha * 0.62), @(MIN(baseAlpha + 0.18, 0.48)), @(baseAlpha)];
        dotOpacity.keyTimes = @[@0.0, @0.50, @1.0];
        dotOpacity.duration = dotScale.duration;
        dotOpacity.repeatCount = HUGE_VALF;
        dotOpacity.autoreverses = YES;
        dotOpacity.beginTime = dotScale.beginTime;
        [dot.layer addAnimation:dotOpacity forKey:@"pp_novaHeaderDotOpacity"];
    }];

    CABasicAnimation *haloOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloOpacity.fromValue = @(self.novaHeaderCollapsed ? 0.36 : 0.58);
    haloOpacity.toValue = @(self.novaHeaderCollapsed ? 0.62 : 1.0);
    haloOpacity.duration = 6.2;
    haloOpacity.autoreverses = YES;
    haloOpacity.repeatCount = HUGE_VALF;
    haloOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandHaloView.layer addAnimation:haloOpacity forKey:@"pp_novaBrandHaloOpacity"];

    CABasicAnimation *haloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    haloScale.fromValue = @(self.novaHeaderCollapsed ? 0.78 : 0.96);
    haloScale.toValue = @(self.novaHeaderCollapsed ? 0.86 : 1.055);
    haloScale.duration = 6.2;
    haloScale.autoreverses = YES;
    haloScale.repeatCount = HUGE_VALF;
    haloScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandHaloView.layer addAnimation:haloScale forKey:@"pp_novaBrandHaloScale"];

    CABasicAnimation *ringOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    ringOpacity.fromValue = @0.62;
    ringOpacity.toValue = @1.0;
    ringOpacity.duration = 5.6;
    ringOpacity.autoreverses = YES;
    ringOpacity.repeatCount = HUGE_VALF;
    ringOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandRingView.layer addAnimation:ringOpacity forKey:@"pp_novaBrandRingOpacity"];

    CABasicAnimation *ringScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    ringScale.fromValue = @(self.novaHeaderCollapsed ? 0.94 : 0.992);
    ringScale.toValue = @(self.novaHeaderCollapsed ? 0.98 : 1.022);
    ringScale.duration = 5.6;
    ringScale.autoreverses = YES;
    ringScale.repeatCount = HUGE_VALF;
    ringScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.headerBrandRingView.layer addAnimation:ringScale forKey:@"pp_novaBrandRingScale"];

    self.novaHeaderLiquidBorderLayer.opacity = self.novaHeaderCollapsed ? 0.54 : 0.72;
    self.novaHeaderLiquidHighlightLayer.opacity = self.novaHeaderCollapsed ? 0.24 : 0.36;

    CABasicAnimation *borderPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    borderPulse.fromValue = @(self.novaHeaderCollapsed ? 0.42 : 0.58);
    borderPulse.toValue = @(self.novaHeaderCollapsed ? 0.58 : 0.78);
    borderPulse.duration = 5.8;
    borderPulse.autoreverses = YES;
    borderPulse.repeatCount = HUGE_VALF;
    borderPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderLiquidBorderLayer addAnimation:borderPulse forKey:@"pp_novaHeaderLiquidBorderPulse"];

    CABasicAnimation *liquidFlow = [CABasicAnimation animationWithKeyPath:@"lineDashPhase"];
    liquidFlow.fromValue = @0.0;
    liquidFlow.toValue = @(-260.0);
    liquidFlow.duration = self.novaHeaderCollapsed ? 9.6 : 7.8;
    liquidFlow.repeatCount = HUGE_VALF;
    liquidFlow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.novaHeaderLiquidHighlightLayer addAnimation:liquidFlow forKey:@"pp_novaHeaderLiquidBorderFlow"];

    CABasicAnimation *highlightPulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    highlightPulse.fromValue = @(self.novaHeaderCollapsed ? 0.16 : 0.24);
    highlightPulse.toValue = @(self.novaHeaderCollapsed ? 0.30 : 0.46);
    highlightPulse.duration = 4.9;
    highlightPulse.autoreverses = YES;
    highlightPulse.repeatCount = HUGE_VALF;
    highlightPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.novaHeaderLiquidHighlightLayer addAnimation:highlightPulse forKey:@"pp_novaHeaderLiquidBorderGlow"];
}

- (void)pp_stopHeaderLiveAnimations {
    [self.statusDot.layer removeAllAnimations];
    [self.novaHeaderBottomGlowView.layer removeAllAnimations];
    [self.novaHeaderSheenView.layer removeAllAnimations];
    [self.headerBrandHaloView.layer removeAllAnimations];
    [self.headerBrandRingView.layer removeAllAnimations];
    [self.headerBrandMarkView.layer removeAllAnimations];
    [self.novaHeaderLiquidBorderLayer removeAllAnimations];
    [self.novaHeaderLiquidHighlightLayer removeAllAnimations];
    for (UIView *dot in self.novaHeaderMotionDots) {
        [dot.layer removeAllAnimations];
    }
    [self.novaHeaderBackgroundLottie stop];
    [self.novaRingBackgroundLottie stop];
}

- (void)pp_showThinkingHeaderLottieWithAnimation:(NSString *)animationName {
    self.novaHeaderThinkingAnimationVisible = YES;
    [self pp_transitionHeaderBackgroundToAnimation:animationName];

    [self.novaLoadingLottie play];
    [UIView animateWithDuration:0.3 animations:^{
        self.novaLoadingLottie.alpha = 0.7;
    }];
}

- (void)pp_hideThinkingHeaderLottie {
    self.novaHeaderThinkingAnimationVisible = NO;

    //[self pp_transitionHeaderBackgroundToAnimation:@"novawave"];

    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.novaLoadingLottie.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        if (!self.novaHeaderThinkingAnimationVisible) {
            [self.novaLoadingLottie stop];
        }
    }];
}

- (void)pp_transitionHeaderBackgroundToAnimation:(NSString *)animationName {
    if (!self.novaHeaderBackgroundLottie) return;
    if ([self.currentHeaderBgAnimationName isEqualToString:animationName]) {
        [self.novaHeaderBackgroundLottie play];
        [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.24
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
        } completion:nil];
        return;
    }

    self.currentHeaderBgAnimationName = animationName;

    [UIView animateWithDuration:0.32
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.novaHeaderBackgroundLottie.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (!self || self.dismissed) return;

        __weak typeof(self) wself = self;
        [AppClasses setAnimationNamed:animationName
                               ToView:self.novaHeaderBackgroundLottie
                            withSpeed:1.0
                           completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wself) self = wself;
                if (!self || self.dismissed) return;

                // If it changed AGAIN while we were loading, don't show the old one.
                if (![self.currentHeaderBgAnimationName isEqualToString:animationName]) return;

                if (success) {
                    [self.novaHeaderBackgroundLottie play];
                    [UIView animateWithDuration:0.38
                                          delay:0.06
                         usingSpringWithDamping:0.84
                          initialSpringVelocity:0.3
                                        options:UIViewAnimationOptionCurveEaseOut
                                     animations:^{
                        self.novaHeaderBackgroundLottie.alpha = [self pp_novaHeaderBackgroundAlphaForCurrentState];
                    } completion:nil];
                }
            });
        }];
    }];
}

- (void)setupInputView {
    self.inputbar = [[PPNovaFloatingInputBarView alloc] init];
    self.inputbar.delegate = self;
    self.inputbar.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.inputbar];

    self.inputBarRestingBottomConstant = -10.0;
    self.inputBarBottomConstraint = [self.inputbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:self.inputBarRestingBottomConstant];
    NSLayoutConstraint *compactWidth = [self.inputbar.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-24.0];
    compactWidth.priority = 999.0;
    NSLayoutConstraint *readableWidth = [self.inputbar.widthAnchor constraintEqualToConstant:760.0];
    readableWidth.priority = 998.0;

    [NSLayoutConstraint activateConstraints:@[
        [self.inputbar.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16.0],
        [self.inputbar.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16.0],
        [self.inputbar.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.inputbar.widthAnchor constraintLessThanOrEqualToConstant:760.0],
        compactWidth,
        readableWidth,
        self.inputBarBottomConstraint
    ]];

}

- (void)setupTypingIndicator {
    UIBlurEffectStyle typingBlurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        typingBlurStyle = UIBlurEffectStyleSystemThinMaterial;
    }
    UIVisualEffectView *capsule = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:typingBlurStyle]];
    capsule.translatesAutoresizingMaskIntoConstraints = NO;
    capsule.layer.cornerRadius = 16.0;
    capsule.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        capsule.layer.cornerCurve = kCACornerCurveContinuous;
    }
    capsule.layer.borderWidth = 0.0 / [UIScreen mainScreen].scale;
    capsule.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.55].CGColor;
    capsule.alpha = 0.0;
    capsule.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [self.view addSubview:capsule];
    self.typingContainer = capsule;

    UIView *content = capsule.contentView;

    UIColor *dotColor = AppPrimaryClr ?: [UIColor colorWithRed:0.98 green:0.70 blue:0.42 alpha:1.0];
    UIStackView *dotsStack = [[UIStackView alloc] init];
    dotsStack.translatesAutoresizingMaskIntoConstraints = NO;
    dotsStack.axis = UILayoutConstraintAxisHorizontal;
    dotsStack.alignment = UIStackViewAlignmentCenter;
    dotsStack.spacing = 4.0;
    [content addSubview:dotsStack];

    NSMutableArray<UIView *> *dots = [NSMutableArray arrayWithCapacity:3];
    for (NSInteger i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] init];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        dot.backgroundColor = dotColor;
        dot.layer.cornerRadius = 3.0;
        [dotsStack addArrangedSubview:dot];
        [NSLayoutConstraint activateConstraints:@[
            [dot.widthAnchor constraintEqualToConstant:6.0],
            [dot.heightAnchor constraintEqualToConstant:6.0]
        ]];
        [dots addObject:dot];
    }
    self.typingDots = [dots copy];

    self.typingLabel = [[UILabel alloc] init];
    self.typingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.typingLabel.font = [GM MidFontWithSize:PPFontFootnote] ?: [UIFont systemFontOfSize:PPFontFootnote weight:UIFontWeightMedium];
    self.typingLabel.textColor = [AppPrimaryTextClr colorWithAlphaComponent:0.78];
    [content addSubview:self.typingLabel];

    self.typingBottomConstraint = [capsule.bottomAnchor constraintEqualToAnchor:self.inputbar.topAnchor constant:-8];

    [NSLayoutConstraint activateConstraints:@[
        self.typingBottomConstraint,
        [capsule.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:0],
        [capsule.heightAnchor constraintEqualToConstant:32.0],

        [dotsStack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12.0],
        [dotsStack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],

        [self.typingLabel.leadingAnchor constraintEqualToAnchor:dotsStack.trailingAnchor constant:8.0],
        [self.typingLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12.0],
        [self.typingLabel.centerYAnchor constraintEqualToAnchor:content.centerYAnchor]
    ]];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaBaseSmartSuggestionSpecs {
    return @[
        @{@"titleKey": @"nova_smart_suggestion_cat_food",
          @"promptKey": @"nova_smart_suggestion_cat_food_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_bird_bundle",
          @"promptKey": @"nova_smart_suggestion_bird_bundle_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_medicine",
          @"promptKey": @"nova_smart_suggestion_medicine_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_care",
          @"promptKey": @"nova_smart_suggestion_care_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_dog_toys",
          @"promptKey": @"nova_smart_suggestion_dog_toys_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_cat_litter",
          @"promptKey": @"nova_smart_suggestion_cat_litter_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_fish_setup",
          @"promptKey": @"nova_smart_suggestion_fish_setup_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_live_pets",
          @"promptKey": @"nova_smart_suggestion_live_pets_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_services",
          @"promptKey": @"nova_smart_suggestion_services_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_vets",
          @"promptKey": @"nova_smart_suggestion_vets_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_adoption",
          @"promptKey": @"nova_smart_suggestion_adoption_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_pet_ads",
          @"promptKey": @"nova_smart_suggestion_pet_ads_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_bird_food",
          @"promptKey": @"nova_smart_suggestion_bird_food_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_dog_grooming",
          @"promptKey": @"nova_smart_suggestion_dog_grooming_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_cat_carrier",
          @"promptKey": @"nova_smart_suggestion_cat_carrier_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_aquarium_cleaning",
          @"promptKey": @"nova_smart_suggestion_aquarium_cleaning_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_rabbit_food",
          @"promptKey": @"nova_smart_suggestion_rabbit_food_prompt"},
        @{@"titleKey": @"nova_smart_suggestion_travel_kit",
          @"promptKey": @"nova_smart_suggestion_travel_kit_prompt"}
    ];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaSmartSuggestionSpecs {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *combined = [NSMutableArray array];
    if (self.dynamicSmartSuggestions.count > 0) {
        [combined addObjectsFromArray:self.dynamicSmartSuggestions];
    }
    [combined addObjectsFromArray:[self pp_novaBaseSmartSuggestionSpecs]];
    return [self pp_uniqueNovaSmartSuggestionSpecs:combined];
}

- (NSString *)pp_titleForNovaSmartSuggestionSpec:(NSDictionary<NSString *, NSString *> *)spec {
    NSString *title = spec[@"title"];
    NSString *titleKey = spec[@"titleKey"];
    if (title.length == 0 && titleKey.length > 0) {
        title = kLang(titleKey);
    }
    return title ?: @"";
}

- (NSString *)pp_promptForNovaSmartSuggestionSpec:(NSDictionary<NSString *, NSString *> *)spec {
    NSString *prompt = spec[@"prompt"];
    NSString *promptKey = spec[@"promptKey"];
    if (prompt.length == 0 && promptKey.length > 0) {
        prompt = [kLang(promptKey) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return prompt ?: @"";
}

- (NSString *)pp_signatureForNovaSmartSuggestionSpec:(NSDictionary<NSString *, NSString *> *)spec {
    NSString *title = [[self pp_titleForNovaSmartSuggestionSpec:spec] lowercaseString] ?: @"";
    NSString *prompt = [[self pp_promptForNovaSmartSuggestionSpec:spec] lowercaseString] ?: @"";
    return [NSString stringWithFormat:@"%@|%@", title, prompt];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_uniqueNovaSmartSuggestionSpecs:(NSArray<NSDictionary<NSString *, NSString *> *> *)specs {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *unique = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    for (NSDictionary<NSString *, NSString *> *spec in specs) {
        NSString *title = [self pp_titleForNovaSmartSuggestionSpec:spec];
        NSString *prompt = [self pp_promptForNovaSmartSuggestionSpec:spec];
        if (title.length == 0 || prompt.length == 0) {
            continue;
        }

        NSString *signature = [self pp_signatureForNovaSmartSuggestionSpec:spec];
        if (signature.length == 0 || [seen containsObject:signature]) {
            continue;
        }

        [seen addObject:signature];
        [unique addObject:spec];
    }

    return unique.copy;
}

- (NSString *)pp_signatureForNovaSmartSuggestionSet:(NSArray<NSDictionary<NSString *, NSString *> *> *)specs {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *spec in specs) {
        NSString *signature = [self pp_signatureForNovaSmartSuggestionSpec:spec];
        if (signature.length > 0) {
            [parts addObject:signature];
        }
    }
    [parts sortUsingSelector:@selector(compare:)];
    return [parts componentsJoinedByString:@"#"];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_firstNovaSmartSuggestionSpecs:(NSArray<NSDictionary<NSString *, NSString *> *> *)specs
                                                                                limit:(NSUInteger)limit {
    if (specs.count == 0 || limit == 0) {
        return @[];
    }
    NSUInteger count = MIN(limit, specs.count);
    return [specs subarrayWithRange:NSMakeRange(0, count)];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_randomNovaSmartSuggestionPickerSpecsAvoidingSpecs:(NSArray<NSDictionary<NSString *, NSString *> *> *)previousSpecs {
    NSArray<NSDictionary<NSString *, NSString *> *> *allSuggestions = [self pp_novaSmartSuggestionSpecs];
    if (allSuggestions.count <= 1) {
        return allSuggestions ?: @[];
    }

    NSUInteger count = MIN(PPNovaSmartSuggestionPickerVisibleCount, allSuggestions.count);
    NSString *previousSignature = [self pp_signatureForNovaSmartSuggestionSet:previousSpecs ?: @[]];
    NSArray<NSDictionary<NSString *, NSString *> *> *candidate = nil;

    for (NSUInteger attempt = 0; attempt < 6; attempt++) {
        NSMutableArray<NSDictionary<NSString *, NSString *> *> *shuffled = [allSuggestions mutableCopy];
        for (NSUInteger remaining = shuffled.count; remaining > 1; remaining--) {
            NSUInteger index = remaining - 1;
            NSUInteger randomIndex = (NSUInteger)arc4random_uniform((uint32_t)remaining);
            [shuffled exchangeObjectAtIndex:index withObjectAtIndex:randomIndex];
        }

        candidate = [shuffled subarrayWithRange:NSMakeRange(0, count)];
        NSString *candidateSignature = [self pp_signatureForNovaSmartSuggestionSet:candidate];
        if (previousSignature.length == 0 || ![candidateSignature isEqualToString:previousSignature]) {
            break;
        }
    }

    return candidate ?: [self pp_firstNovaSmartSuggestionSpecs:allSuggestions limit:count];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)pp_novaSmartSuggestionPickerSpecs {
    if (self.smartSuggestionPickerSuggestions.count > 0) {
        return self.smartSuggestionPickerSuggestions;
    }
    return [self pp_firstNovaSmartSuggestionSpecs:[self pp_novaSmartSuggestionSpecs]
                                           limit:PPNovaSmartSuggestionPickerVisibleCount];
}

- (NSUInteger)pp_indexOfNovaSmartSuggestionSpec:(NSDictionary<NSString *, NSString *> *)target
                                  inSuggestions:(NSArray<NSDictionary<NSString *, NSString *> *> *)suggestions {
    NSString *targetSignature = [self pp_signatureForNovaSmartSuggestionSpec:target];
    if (targetSignature.length == 0) {
        return NSNotFound;
    }

    __block NSUInteger foundIndex = NSNotFound;
    [suggestions enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *spec, NSUInteger idx, BOOL *stop) {
        if ([[self pp_signatureForNovaSmartSuggestionSpec:spec] isEqualToString:targetSignature]) {
            foundIndex = idx;
            *stop = YES;
        }
    }];
    return foundIndex;
}

- (void)pp_refreshNovaSmartSuggestionPickerChoicesAnimated:(BOOL)animated {
    NSArray<NSDictionary<NSString *, NSString *> *> *previousSpecs = self.smartSuggestionPickerSuggestions;
    self.smartSuggestionPickerSuggestions = [self pp_randomNovaSmartSuggestionPickerSpecsAvoidingSpecs:previousSpecs];

    BOOL shouldAnimate = animated &&
        self.smartSuggestionPickerVisible &&
        !self.smartSuggestionPickerView.hidden &&
        !UIAccessibilityIsReduceMotionEnabled();

    void (^rebuild)(void) = ^{
        [self pp_rebuildNovaSmartSuggestionButtons];
    };

    if (!shouldAnimate) {
        rebuild();
        return;
    }

    [UIView transitionWithView:self.smartSuggestionPickerStackView
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:rebuild
                    completion:^(__unused BOOL finished) {
        [self.smartSuggestionPickerButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, __unused BOOL *stop) {
            button.alpha = 0.0;
            button.transform = CGAffineTransformMakeTranslation(0.0, 6.0);
            [UIView animateWithDuration:0.24
                                  delay:MIN(idx, (NSUInteger)7) * 0.018
                 usingSpringWithDamping:0.92
                  initialSpringVelocity:0.10
                                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                button.alpha = 1.0;
                button.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
    }];
}

- (NSDictionary<NSString *, NSString *> *)pp_currentNovaSmartSuggestionSpec {
    NSArray<NSDictionary<NSString *, NSString *> *> *suggestions = [self pp_novaSmartSuggestionSpecs];
    if (suggestions.count == 0) {
        return nil;
    }
    NSUInteger index = MIN(self.smartSuggestionCurrentIndex, suggestions.count - 1);
    return suggestions[index];
}

- (UIButton *)pp_makeNovaSmartSuggestionPickerButtonWithTitle:(NSString *)title index:(NSUInteger)index {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = (NSInteger)index;
    button.clipsToBounds = YES;
    button.layer.cornerRadius = 16.0;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 14.0, 0.0, 14.0);
    button.titleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    button.titleLabel.numberOfLines = 1;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    button.accessibilityLabel = title;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPickerTap:) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressCancel:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }

    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:42.0]
    ]];
    return button;
}

- (void)pp_refreshProviderSmartSuggestions {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *specs = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    NSObject *leaveLock = [NSObject new];
    void (^addSpec)(NSString *, NSString *) = ^(NSString *title, NSString *prompt) {
        if (title.length == 0 || prompt.length == 0) return;
        @synchronized (specs) {
            [specs addObject:@{@"title": title, @"prompt": prompt}];
        }
    };

    for (MainKindsModel *kind in PPMainKindsArray) {
        if (!kind.isVisibleInUserApp) continue;
        if (kind.KindName.length == 0) continue;

        BOOL hasItems = NO;
        for (SubKindModel *sub in kind.SubKindsArray) {
            if (sub.have_items > 0) { hasItems = YES; break; }
        }
        if (hasItems) {
            NSString *title = [NSString stringWithFormat:kLang(@"nova_provider_products_title"), kind.KindName];
            NSString *prompt = [NSString stringWithFormat:kLang(@"nova_provider_products_prompt"), kind.KindName];
            addSpec(title, prompt);
        }
    }

    __block BOOL adsDidLeave = NO;
    BOOL (^markAdsFinished)(void) = ^BOOL{
        @synchronized (leaveLock) {
            if (adsDidLeave) return NO;
            adsDidLeave = YES;
        }
        return YES;
    };
    dispatch_group_enter(group);
    FIRQuery *adsQuery = [[[AppMgr.dF collectionWithPath:kPetAdsCollection]
                            queryWhereField:@"status" isEqualTo:@(1)]
                           queryLimitedTo:1];
    [adsQuery getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (!markAdsFinished()) return;
        if (!error && snapshot.documents.count > 0) {
            addSpec(kLang(@"nova_provider_ads_title_default"),
                    kLang(@"nova_provider_ads_prompt_default"));
        }
        dispatch_group_leave(group);
    }];

    __block BOOL adoptDidLeave = NO;
    BOOL (^markAdoptFinished)(void) = ^BOOL{
        @synchronized (leaveLock) {
            if (adoptDidLeave) return NO;
            adoptDidLeave = YES;
        }
        return YES;
    };
    dispatch_group_enter(group);
    FIRQuery *adoptQuery = [[AppMgr.dF collectionWithPath:@"adopt_pets"] queryLimitedTo:1];
    [adoptQuery getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (!markAdoptFinished()) return;
        if (!error && snapshot.documents.count > 0) {
            addSpec(kLang(@"nova_provider_adopt_title"),
                    kLang(@"nova_provider_adopt_prompt"));
        }
        dispatch_group_leave(group);
    }];

    __block BOOL servicesDidLeave = NO;
    BOOL (^markServicesFinished)(void) = ^BOOL{
        @synchronized (leaveLock) {
            if (servicesDidLeave) return NO;
            servicesDidLeave = YES;
        }
        return YES;
    };
    dispatch_group_enter(group);
    FIRQuery *servicesQuery = [[AppMgr.dF collectionWithPath:@"serviceOffers"] queryLimitedTo:1];
    [servicesQuery getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
        if (!markServicesFinished()) return;
        if (!error && snapshot.documents.count > 0) {
            addSpec(kLang(@"nova_provider_services_title"),
                    kLang(@"nova_provider_services_prompt"));
        }
        dispatch_group_leave(group);
    }];

    __block BOOL vetsDidLeave = NO;
    BOOL (^markVetsFinished)(void) = ^BOOL{
        @synchronized (leaveLock) {
            if (vetsDidLeave) return NO;
            vetsDidLeave = YES;
        }
        return YES;
    };
    dispatch_group_enter(group);
    [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> *vets, __unused NSError *error) {
        if (!markVetsFinished()) return;
        if (vets.count > 0) {
            addSpec(kLang(@"nova_provider_vets_title"),
                    kLang(@"nova_provider_vets_prompt"));
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (specs.count == 0) {
            self.dynamicSmartSuggestions = @[];
            if (self.smartSuggestionPickerVisible) {
                [self pp_refreshNovaSmartSuggestionPickerChoicesAnimated:YES];
            } else {
                self.smartSuggestionPickerSuggestions = nil;
                [self pp_rebuildNovaSmartSuggestionButtons];
            }
            return;
        }
        NSArray *sorted = [specs sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"title"] compare:b[@"title"]];
        }];
        self.dynamicSmartSuggestions = sorted;
        if (self.smartSuggestionPickerVisible) {
            [self pp_refreshNovaSmartSuggestionPickerChoicesAnimated:YES];
        } else {
            self.smartSuggestionPickerSuggestions = nil;
            [self pp_rebuildNovaSmartSuggestionButtons];
        }
    });
}

- (void)pp_rebuildNovaSmartSuggestionButtons {
    if (!self.smartSuggestionPickerStackView) return;

    for (UIView *subview in self.smartSuggestionPickerStackView.arrangedSubviews.copy) {
        [self.smartSuggestionPickerStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }

    NSArray<NSDictionary<NSString *, NSString *> *> *suggestions = [self pp_novaSmartSuggestionPickerSpecs];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    [suggestions enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSString *> *spec, NSUInteger idx, __unused BOOL *stop) {
        UIButton *button = [self pp_makeNovaSmartSuggestionPickerButtonWithTitle:[self pp_titleForNovaSmartSuggestionSpec:spec] index:idx];
        [self.smartSuggestionPickerStackView addArrangedSubview:button];
        [buttons addObject:button];
    }];
    self.smartSuggestionPickerButtons = buttons.copy;

    NSArray<NSDictionary<NSString *, NSString *> *> *allSuggestions = [self pp_novaSmartSuggestionSpecs];
    if (allSuggestions.count > 0) {
        self.smartSuggestionCurrentIndex = MIN(self.smartSuggestionCurrentIndex, allSuggestions.count - 1);
    } else {
        self.smartSuggestionCurrentIndex = 0;
    }
    [self pp_configureCurrentNovaSmartSuggestionAnimated:NO];
    [self pp_applyNovaSurfaceColors];
}

- (void)pp_configureCurrentNovaSmartSuggestionAnimated:(BOOL)animated {
    NSDictionary<NSString *, NSString *> *spec = [self pp_currentNovaSmartSuggestionSpec];
    NSString *title = [self pp_titleForNovaSmartSuggestionSpec:spec];
    NSString *prompt = [self pp_promptForNovaSmartSuggestionSpec:spec];
    if (title.length == 0) {
        title = kLang(@"nova_smart_suggestion_cat_food");
    }
    if (prompt.length == 0) {
        prompt = kLang(@"nova_smart_suggestion_cat_food_prompt");
    }

    [self pp_applyNovaSmartSuggestionColorsWithBrand:[self pp_novaHeaderAccentColor]
                                             surface:[self pp_novaHeaderSurfaceColor]
                                         primaryText:[self pp_novaHeaderPrimaryTextColor]
                                       secondaryText:[self pp_novaHeaderSecondaryTextColor]
                                            animated:animated];

    void (^changes)(void) = ^{
        self.smartSuggestionTitleLabel.text = kLang(@"nova_smart_suggestions_title");
        self.smartSuggestionTextLabel.text = title;
        self.smartSuggestionHintLabel.text = self.smartSuggestionAutoSendEnabled
            ? kLang(@"nova_smart_suggestion_auto_hint")
            : kLang(@"nova_smart_suggestion_fill_hint");
        self.smartSuggestionSurfaceButton.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", title, self.smartSuggestionHintLabel.text ?: @""];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }

    CGFloat direction = Language.isRTL ? -1.0 : 1.0;
    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.smartSuggestionTextLabel.alpha = 0.0;
        self.smartSuggestionHintLabel.alpha = 0.0;
        self.smartSuggestionTextLabel.transform = CGAffineTransformMakeTranslation(10.0 * direction, 0.0);
        self.smartSuggestionHintLabel.transform = CGAffineTransformMakeTranslation(8.0 * direction, 0.0);
    } completion:^(__unused BOOL finished) {
        changes();
        self.smartSuggestionTextLabel.transform = CGAffineTransformMakeTranslation(-12.0 * direction, 0.0);
        self.smartSuggestionHintLabel.transform = CGAffineTransformMakeTranslation(-10.0 * direction, 0.0);
        [UIView animateWithDuration:0.34
                              delay:0.0
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            self.smartSuggestionTextLabel.alpha = 1.0;
            self.smartSuggestionHintLabel.alpha = 1.0;
            self.smartSuggestionTextLabel.transform = CGAffineTransformIdentity;
            self.smartSuggestionHintLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_advanceNovaSmartSuggestionAnimated:(BOOL)animated {
    NSArray<NSDictionary<NSString *, NSString *> *> *suggestions = [self pp_novaSmartSuggestionSpecs];
    if (suggestions.count == 0) return;
    self.smartSuggestionCurrentIndex = (self.smartSuggestionCurrentIndex + 1) % suggestions.count;
    [self pp_configureCurrentNovaSmartSuggestionAnimated:animated];
}

- (void)pp_startNovaSmartSuggestionRotationIfNeeded {
    if (self.smartSuggestionRotationTimer ||
        self.smartSuggestionPickerVisible ||
        self.novaInputHasText ||
        [self pp_hasUserMessageInCurrentNovaSession] ||
        [self pp_novaSmartSuggestionSpecs].count <= 1) {
        return;
    }

    self.smartSuggestionRotationTimer =
        [NSTimer timerWithTimeInterval:4.8
                                target:self
                              selector:@selector(pp_handleNovaSmartSuggestionRotationTimer:)
                              userInfo:nil
                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.smartSuggestionRotationTimer forMode:NSRunLoopCommonModes];
}

- (void)pp_stopNovaSmartSuggestionRotation {
    [self.smartSuggestionRotationTimer invalidate];
    self.smartSuggestionRotationTimer = nil;
}

- (void)pp_handleNovaSmartSuggestionRotationTimer:(NSTimer *)timer {
    if (self.smartSuggestionPickerVisible || [self pp_hasUserMessageInCurrentNovaSession]) {
        [self pp_stopNovaSmartSuggestionRotation];
        return;
    }
    [self pp_advanceNovaSmartSuggestionAnimated:YES];
}

- (void)setupNovaEmptyState {
    UIView *emptyView = [[UIView alloc] init];
    emptyView.translatesAutoresizingMaskIntoConstraints = NO;
    emptyView.userInteractionEnabled = YES;
    emptyView.alpha = 1.0;
    [self.view insertSubview:emptyView aboveSubview:self.tableView];
    self.emptyStateView = emptyView;

    UIView *pulseView = [[UIView alloc] init];
    pulseView.translatesAutoresizingMaskIntoConstraints = NO;
    pulseView.backgroundColor = [(AppPrimaryClr ?: UIColor.systemOrangeColor) colorWithAlphaComponent:0.10];
    pulseView.layer.cornerRadius = 28.0;
    pulseView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        pulseView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [emptyView addSubview:pulseView];
    self.emptyStatePulseView = pulseView;

    LOTAnimationView *loaderLottie = [[LOTAnimationView alloc] init];
    loaderLottie.translatesAutoresizingMaskIntoConstraints = NO;
    loaderLottie.contentMode = UIViewContentModeScaleAspectFit;
    loaderLottie.loopAnimation = YES;
    [pulseView addSubview:loaderLottie];
    self.novaEmptyLoaderLottie = loaderLottie;
    [Styling setAnimationNamed:@"NovaLoader1.json"
                        toView:loaderLottie
                     withSpeed:0.8
                 loopAnimation:YES
                      autoplay:YES
                    completion:^(__unused BOOL success) {}];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:PPFontTitle3] ?: [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = AppPrimaryTextClr;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = kLang(@"nova_empty_title");
    [emptyView addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    subtitleLabel.textColor = [AppSecondaryTextClr colorWithAlphaComponent:0.82];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.text = kLang(@"nova_empty_subtitle");
    [emptyView addSubview:subtitleLabel];

    UIVisualEffectView *suggestionView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self pp_novaHeaderGlassBlurStyle]]];
    suggestionView.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionView.clipsToBounds = YES;
    suggestionView.layer.cornerRadius = 22.0;
    suggestionView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    suggestionView.layer.shadowOpacity = 0.10;
    suggestionView.layer.shadowRadius = 18.0;
    suggestionView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    suggestionView.alpha = 0.0;
    suggestionView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    suggestionView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    suggestionView.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        suggestionView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [emptyView addSubview:suggestionView];
    self.smartSuggestionSurfaceView = suggestionView;

    UIView *accentWashView = [[UIView alloc] init];
    accentWashView.translatesAutoresizingMaskIntoConstraints = NO;
    accentWashView.userInteractionEnabled = NO;
    accentWashView.backgroundColor = UIColor.clearColor;
    [suggestionView.contentView addSubview:accentWashView];
    self.smartSuggestionAccentWashView = accentWashView;

    CAGradientLayer *accentGradientLayer = [CAGradientLayer layer];
    accentGradientLayer.masksToBounds = YES;
    [accentWashView.layer addSublayer:accentGradientLayer];
    self.smartSuggestionAccentGradientLayer = accentGradientLayer;

    UILabel *suggestionTitleLabel = [[UILabel alloc] init];
    suggestionTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionTitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    suggestionTitleLabel.text = kLang(@"nova_smart_suggestions_title");
    suggestionTitleLabel.textAlignment = Language.alignmentForCurrentLanguage;
    suggestionTitleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [suggestionView.contentView addSubview:suggestionTitleLabel];
    self.smartSuggestionTitleLabel = suggestionTitleLabel;

    UILabel *suggestionTextLabel = [[UILabel alloc] init];
    suggestionTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionTextLabel.font = [GM boldFontWithSize:PPFontHeadline] ?: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    suggestionTextLabel.textAlignment = Language.alignmentForCurrentLanguage;
    suggestionTextLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    suggestionTextLabel.numberOfLines = 1;
    suggestionTextLabel.adjustsFontSizeToFitWidth = YES;
    suggestionTextLabel.minimumScaleFactor = 0.78;
    [suggestionView.contentView addSubview:suggestionTextLabel];
    self.smartSuggestionTextLabel = suggestionTextLabel;

    UILabel *suggestionHintLabel = [[UILabel alloc] init];
    suggestionHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    suggestionHintLabel.font = [GM MidFontWithSize:PPFontCaption2] ?: [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    suggestionHintLabel.textAlignment = Language.alignmentForCurrentLanguage;
    suggestionHintLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    suggestionHintLabel.numberOfLines = 1;
    [suggestionView.contentView addSubview:suggestionHintLabel];
    self.smartSuggestionHintLabel = suggestionHintLabel;

    UIImageView *actionImageView = [[UIImageView alloc] init];
    actionImageView.translatesAutoresizingMaskIntoConstraints = NO;
    actionImageView.contentMode = UIViewContentModeScaleAspectFit;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15.0
                                                                                          weight:UIImageSymbolWeightSemibold];
        actionImageView.image = [UIImage systemImageNamed:@"sparkles" withConfiguration:cfg];
    }
    [suggestionView.contentView addSubview:actionImageView];
    self.smartSuggestionActionImageView = actionImageView;

    UIButton *surfaceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    surfaceButton.translatesAutoresizingMaskIntoConstraints = NO;
    surfaceButton.backgroundColor = UIColor.clearColor;
    surfaceButton.accessibilityTraits = UIAccessibilityTraitButton;
    [surfaceButton addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressDown:) forControlEvents:UIControlEventTouchDown];
    [surfaceButton addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressCancel:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [surfaceButton addTarget:self action:@selector(pp_handleNovaSmartSuggestionPillTapped:) forControlEvents:UIControlEventTouchUpInside];
    [suggestionView.contentView addSubview:surfaceButton];
    self.smartSuggestionSurfaceButton = surfaceButton;

    NSLayoutConstraint *suggestionWidthConstraint = [suggestionView.widthAnchor constraintEqualToAnchor:emptyView.widthAnchor];
    suggestionWidthConstraint.priority = 999.0;
    NSLayoutConstraint *suggestionMaxWidthConstraint = [suggestionView.widthAnchor constraintLessThanOrEqualToConstant:540.0];

    self.emptyStateCenterYConstraint = [emptyView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:8.0];

    [NSLayoutConstraint activateConstraints:@[
        [emptyView.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor constant:12.0],
        [emptyView.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor constant:-12.0],
        self.emptyStateCenterYConstraint,

        [pulseView.topAnchor constraintEqualToAnchor:emptyView.topAnchor],
        [pulseView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [pulseView.widthAnchor constraintEqualToConstant:56.0],
        [pulseView.heightAnchor constraintEqualToConstant:56.0],

        [loaderLottie.centerXAnchor constraintEqualToAnchor:pulseView.centerXAnchor],
        [loaderLottie.centerYAnchor constraintEqualToAnchor:pulseView.centerYAnchor],
        [loaderLottie.widthAnchor constraintEqualToConstant:58.0],
        [loaderLottie.heightAnchor constraintEqualToConstant:58.0],

        [titleLabel.topAnchor constraintEqualToAnchor:pulseView.bottomAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:7.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:emptyView.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:emptyView.trailingAnchor],

        [suggestionView.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:18.0],
        [suggestionView.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [suggestionView.leadingAnchor constraintGreaterThanOrEqualToAnchor:emptyView.leadingAnchor],
        [suggestionView.trailingAnchor constraintLessThanOrEqualToAnchor:emptyView.trailingAnchor],
        suggestionWidthConstraint,
        suggestionMaxWidthConstraint,
        [suggestionView.bottomAnchor constraintEqualToAnchor:emptyView.bottomAnchor],

        [accentWashView.topAnchor constraintEqualToAnchor:suggestionView.contentView.topAnchor],
        [accentWashView.leadingAnchor constraintEqualToAnchor:suggestionView.contentView.leadingAnchor],
        [accentWashView.trailingAnchor constraintEqualToAnchor:suggestionView.contentView.trailingAnchor],
        [accentWashView.bottomAnchor constraintEqualToAnchor:suggestionView.contentView.bottomAnchor],

        [suggestionTitleLabel.topAnchor constraintEqualToAnchor:suggestionView.contentView.topAnchor constant:13.0],
        [suggestionTitleLabel.leadingAnchor constraintEqualToAnchor:suggestionView.contentView.leadingAnchor constant:18.0],
        [suggestionTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:actionImageView.leadingAnchor constant:-12.0],

        [suggestionTextLabel.topAnchor constraintEqualToAnchor:suggestionTitleLabel.bottomAnchor constant:3.0],
        [suggestionTextLabel.leadingAnchor constraintEqualToAnchor:suggestionTitleLabel.leadingAnchor],
        [suggestionTextLabel.trailingAnchor constraintLessThanOrEqualToAnchor:actionImageView.leadingAnchor constant:-12.0],

        [suggestionHintLabel.topAnchor constraintEqualToAnchor:suggestionTextLabel.bottomAnchor constant:3.0],
        [suggestionHintLabel.leadingAnchor constraintEqualToAnchor:suggestionTitleLabel.leadingAnchor],
        [suggestionHintLabel.trailingAnchor constraintLessThanOrEqualToAnchor:actionImageView.leadingAnchor constant:-12.0],
        [suggestionHintLabel.bottomAnchor constraintEqualToAnchor:suggestionView.contentView.bottomAnchor constant:-13.0],

        [actionImageView.trailingAnchor constraintEqualToAnchor:suggestionView.contentView.trailingAnchor constant:-18.0],
        [actionImageView.centerYAnchor constraintEqualToAnchor:suggestionView.contentView.centerYAnchor],
        [actionImageView.widthAnchor constraintEqualToConstant:24.0],
        [actionImageView.heightAnchor constraintEqualToConstant:24.0],

        [surfaceButton.topAnchor constraintEqualToAnchor:suggestionView.contentView.topAnchor],
        [surfaceButton.leadingAnchor constraintEqualToAnchor:suggestionView.contentView.leadingAnchor],
        [surfaceButton.trailingAnchor constraintEqualToAnchor:suggestionView.contentView.trailingAnchor],
        [surfaceButton.bottomAnchor constraintEqualToAnchor:suggestionView.contentView.bottomAnchor]
    ]];

    [self setupNovaSmartSuggestionPicker];
    [self pp_rebuildNovaSmartSuggestionButtons];
    [self pp_applyNovaSurfaceColors];
    [self updateNovaEmptyStateAnimated:NO];
}

- (UIButton *)pp_makeNovaSuggestionPickerControlButtonWithTitle:(NSString *)title systemImage:(NSString *)systemImageName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.clipsToBounds = YES;
    button.layer.cornerRadius = 15.0;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.titleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 12.0);
    button.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [button setTitle:title forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:12.0
                                                                                          weight:UIImageSymbolWeightSemibold];
        UIImage *image = [UIImage systemImageNamed:systemImageName withConfiguration:cfg];
        [button setImage:image forState:UIControlStateNormal];
        button.imageEdgeInsets = UIEdgeInsetsMake(0.0, Language.isRTL ? 6.0 : -6.0, 0.0, Language.isRTL ? -6.0 : 6.0);
    }
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressDown:) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(pp_handleNovaSmartSuggestionPressCancel:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside];
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:34.0],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:112.0]
    ]];
    return button;
}

- (void)setupNovaSmartSuggestionPicker {
    if (self.smartSuggestionPickerView) {
        return;
    }

    UIBlurEffectStyle blurStyle = UIBlurEffectStyleRegular;
    if (@available(iOS 13.0, *)) {
        blurStyle = UIBlurEffectStyleSystemThinMaterial;
    }

    UIVisualEffectView *pickerView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:blurStyle]];
    pickerView.translatesAutoresizingMaskIntoConstraints = NO;
    pickerView.clipsToBounds = YES;
    pickerView.layer.cornerRadius = 26.0;
    pickerView.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    pickerView.layer.shadowOpacity = 0.16;
    pickerView.layer.shadowRadius = 28.0;
    pickerView.layer.shadowOffset = CGSizeMake(0.0, 16.0);
    pickerView.alpha = 0.0;
    pickerView.hidden = YES;
    pickerView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
    pickerView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    pickerView.contentView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 13.0, *)) {
        pickerView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [self.view addSubview:pickerView];
    self.smartSuggestionPickerView = pickerView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [GM boldFontWithSize:PPFontSubheadline] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    titleLabel.text = kLang(@"nova_suggestion_picker_title");
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [pickerView.contentView addSubview:titleLabel];
    self.smartSuggestionPickerTitleLabel = titleLabel;

    UIButton *shuffleButton = [self pp_makeNovaSuggestionPickerControlButtonWithTitle:kLang(@"nova_suggestion_picker_change")
                                                                          systemImage:@"shuffle"];
    [shuffleButton addTarget:self action:@selector(pp_handleNovaSuggestionShuffleTapped:) forControlEvents:UIControlEventTouchUpInside];
    [pickerView.contentView addSubview:shuffleButton];
    self.smartSuggestionShuffleButton = shuffleButton;

    UIButton *autoSendButton = [self pp_makeNovaSuggestionPickerControlButtonWithTitle:kLang(@"nova_suggestion_auto_send")
                                                                           systemImage:@"paperplane.fill"];
    [autoSendButton addTarget:self action:@selector(pp_handleNovaAutoSendToggle:) forControlEvents:UIControlEventTouchUpInside];
    [pickerView.contentView addSubview:autoSendButton];
    self.smartSuggestionAutoSendButton = autoSendButton;

    UIStackView *pickerStack = [[UIStackView alloc] init];
    pickerStack.translatesAutoresizingMaskIntoConstraints = NO;
    pickerStack.axis = UILayoutConstraintAxisVertical;
    pickerStack.alignment = UIStackViewAlignmentFill;
    pickerStack.distribution = UIStackViewDistributionFill;
    pickerStack.spacing = 8.0;
    pickerStack.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [pickerView.contentView addSubview:pickerStack];
    self.smartSuggestionPickerStackView = pickerStack;

    self.smartSuggestionPickerBottomConstraint = [pickerView.bottomAnchor constraintEqualToAnchor:self.inputbar.topAnchor constant:-10.0];

    [NSLayoutConstraint activateConstraints:@[
        self.smartSuggestionPickerBottomConstraint,
        [pickerView.leadingAnchor constraintEqualToAnchor:self.inputbar.leadingAnchor],
        [pickerView.trailingAnchor constraintEqualToAnchor:self.inputbar.trailingAnchor],

        [shuffleButton.topAnchor constraintEqualToAnchor:pickerView.contentView.topAnchor constant:14.0],
        [shuffleButton.leadingAnchor constraintEqualToAnchor:pickerView.contentView.leadingAnchor constant:14.0],

        [autoSendButton.topAnchor constraintEqualToAnchor:pickerView.contentView.topAnchor constant:14.0],
        [autoSendButton.trailingAnchor constraintEqualToAnchor:pickerView.contentView.trailingAnchor constant:-14.0],

        [titleLabel.centerYAnchor constraintEqualToAnchor:autoSendButton.centerYAnchor],
        [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:shuffleButton.trailingAnchor constant:10.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:autoSendButton.leadingAnchor constant:-10.0],
        [titleLabel.centerXAnchor constraintEqualToAnchor:pickerView.contentView.centerXAnchor],

        [pickerStack.topAnchor constraintEqualToAnchor:autoSendButton.bottomAnchor constant:12.0],
        [pickerStack.leadingAnchor constraintEqualToAnchor:pickerView.contentView.leadingAnchor constant:12.0],
        [pickerStack.trailingAnchor constraintEqualToAnchor:pickerView.contentView.trailingAnchor constant:-12.0],
        [pickerStack.bottomAnchor constraintEqualToAnchor:pickerView.contentView.bottomAnchor constant:-12.0]
    ]];

    [self pp_updateNovaSmartSuggestionAutoSendButtonAnimated:NO];
}

- (void)updateNovaEmptyStateAnimated:(BOOL)animated {
    BOOL shouldShow = ![self pp_hasUserMessageInCurrentNovaSession];
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;

    void (^changes)(void) = ^{
        self.emptyStateView.alpha = targetAlpha;
        self.emptyStateView.userInteractionEnabled = shouldShow;
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        self.emptyStateView.hidden = !shouldShow;
        self.smartSuggestionSurfaceView.alpha = shouldShow ? 1.0 : 0.0;
        self.smartSuggestionSurfaceView.transform = CGAffineTransformIdentity;
        self.smartSuggestionSurfaceButton.userInteractionEnabled = shouldShow;
        if (shouldShow) {
            [self pp_startNovaSmartSuggestionRotationIfNeeded];
        } else {
            [self pp_stopNovaSmartSuggestionRotation];
        }
        if (!shouldShow) [self pp_hideNovaSmartSuggestionPickerAnimated:NO];
        return;
    }

    if (shouldShow) {
        self.emptyStateView.hidden = NO;
        self.smartSuggestionSurfaceView.alpha = 0.0;
        self.smartSuggestionSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
        self.smartSuggestionSurfaceButton.userInteractionEnabled = YES;
    } else {
        self.smartSuggestionSurfaceButton.userInteractionEnabled = NO;
        [self pp_hideNovaSmartSuggestionPickerAnimated:YES];
    }

    [UIView animateWithDuration:0.30
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.24
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        changes();
    } completion:^(__unused BOOL finished) {
        self.emptyStateView.hidden = !shouldShow;
    }];

    if (shouldShow) {
        [UIView animateWithDuration:0.38
                              delay:0.12
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.32
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.smartSuggestionSurfaceView.alpha = 1.0;
            self.smartSuggestionSurfaceView.transform = CGAffineTransformIdentity;
        } completion:nil];

        [self pp_startNovaSmartSuggestionRotationIfNeeded];
    } else {
        [UIView animateWithDuration:0.18
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            self.smartSuggestionSurfaceView.alpha = 0.0;
            self.smartSuggestionSurfaceView.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
        } completion:nil];
        [self pp_stopNovaSmartSuggestionRotation];
    }
}

- (BOOL)pp_hasUserMessageInCurrentNovaSession {
    for (ChatMessageModel *message in self.messages) {
        if (![message.senderID isEqualToString:@"nova_bot_id"]) {
            return YES;
        }
    }
    return NO;
}

- (void)pp_updateNovaSmartSuggestionAutoSendButtonAnimated:(BOOL)animated {
    if (!self.smartSuggestionAutoSendButton) return;

    UIColor *brand = [self pp_novaHeaderAccentColor] ?: (AppPrimaryClr ?: [UIColor colorWithRed:0.96 green:0.55 blue:0.20 alpha:1.0]);
    UIColor *primaryText = AppPrimaryTextClr ?: UIColor.labelColor;
    UIColor *textColor = self.smartSuggestionAutoSendEnabled ? UIColor.whiteColor : [primaryText colorWithAlphaComponent:0.82];
    UIColor *fillColor = self.smartSuggestionAutoSendEnabled ? brand : [primaryText colorWithAlphaComponent:0.055];
    UIColor *borderColor = self.smartSuggestionAutoSendEnabled ? [brand colorWithAlphaComponent:0.40] : [[UIColor separatorColor] colorWithAlphaComponent:0.18];

    void (^changes)(void) = ^{
        self.smartSuggestionAutoSendButton.backgroundColor = fillColor;
        self.smartSuggestionAutoSendButton.layer.borderColor = borderColor.CGColor;
        self.smartSuggestionAutoSendButton.tintColor = textColor;
        [self.smartSuggestionAutoSendButton setTitleColor:textColor forState:UIControlStateNormal];
        self.smartSuggestionAutoSendButton.accessibilityValue = self.smartSuggestionAutoSendEnabled ? kLang(@"nova_suggestion_auto_send_on") : kLang(@"nova_suggestion_auto_send_off");
        self.smartSuggestionHintLabel.text = self.smartSuggestionAutoSendEnabled ? kLang(@"nova_smart_suggestion_auto_hint") : kLang(@"nova_smart_suggestion_fill_hint");
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        changes();
        return;
    }

    [UIView transitionWithView:self.smartSuggestionAutoSendButton
                      duration:0.20
                       options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                    animations:changes
                    completion:nil];
}

- (void)pp_updateNovaSmartSuggestionPickerSelection {
    [self pp_applyNovaSmartSuggestionColorsWithBrand:[self pp_novaHeaderAccentColor]
                                             surface:[self pp_novaHeaderSurfaceColor]
                                         primaryText:[self pp_novaHeaderPrimaryTextColor]
                                       secondaryText:[self pp_novaHeaderSecondaryTextColor]
                                            animated:NO];
}

- (void)pp_showNovaSmartSuggestionPickerAnimated:(BOOL)animated {
    if (self.smartSuggestionPickerVisible) {
        return;
    }

    self.smartSuggestionPickerVisible = YES;
    [self pp_stopNovaSmartSuggestionRotation];
    [self pp_refreshNovaSmartSuggestionPickerChoicesAnimated:NO];
    [self.view bringSubviewToFront:self.smartSuggestionPickerView];
    [self.view bringSubviewToFront:self.inputbar];
    self.smartSuggestionPickerView.hidden = NO;

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        self.smartSuggestionPickerView.alpha = 1.0;
        self.smartSuggestionPickerView.transform = CGAffineTransformIdentity;
        return;
    }

    self.smartSuggestionPickerView.alpha = 0.0;
    self.smartSuggestionPickerView.transform = CGAffineTransformMakeTranslation(0.0, 18.0);
    [UIView animateWithDuration:0.38
                          delay:0.0
         usingSpringWithDamping:0.90
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.smartSuggestionPickerView.alpha = 1.0;
        self.smartSuggestionPickerView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self.smartSuggestionPickerButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, __unused BOOL *stop) {
        button.alpha = 0.0;
        button.transform = CGAffineTransformMakeTranslation(0.0, 10.0);
        [UIView animateWithDuration:0.28
                              delay:0.08 + MIN(idx, (NSUInteger)7) * 0.025
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.12
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            button.alpha = 1.0;
            button.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_hideNovaSmartSuggestionPickerAnimated:(BOOL)animated {
    if (!self.smartSuggestionPickerVisible && self.smartSuggestionPickerView.hidden) {
        return;
    }

    self.smartSuggestionPickerVisible = NO;
    void (^finish)(void) = ^{
        self.smartSuggestionPickerView.hidden = YES;
        self.smartSuggestionPickerView.alpha = 0.0;
        self.smartSuggestionPickerView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
        [self pp_startNovaSmartSuggestionRotationIfNeeded];
    };

    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        finish();
        return;
    }

    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.smartSuggestionPickerView.alpha = 0.0;
        self.smartSuggestionPickerView.transform = CGAffineTransformMakeTranslation(0.0, 16.0);
    } completion:^(__unused BOOL finished) {
        finish();
    }];
}

- (void)pp_applyNovaSuggestionPrompt:(NSString *)prompt {
    NSString *trimmed = [prompt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return;

    [self pp_hideNovaSmartSuggestionPickerAnimated:YES];
    [self pp_setNovaHeaderCollapsed:YES animated:NO updateInsets:NO];

    if (self.smartSuggestionAutoSendEnabled) {
        [self pp_handleNovaSubmittedText:trimmed];
        return;
    }

    [self.inputbar setText:trimmed];
    if ([self.inputbar respondsToSelector:@selector(focusTextInput)]) {
        [self.inputbar focusTextInput];
    }
}

- (void)pp_handleNovaSmartSuggestionPressDown:(UIButton *)sender {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        sender.alpha = 0.72;
        return;
    }
    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:nil];
}

- (void)pp_handleNovaSmartSuggestionPressCancel:(UIButton *)sender {
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.16
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.alpha = 1.0;
        sender.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_handleNovaSmartSuggestionPillTapped:(UIButton *)sender {
    if ([self pp_hasUserMessageInCurrentNovaSession]) {
        return;
    }
    [self pp_handleNovaSmartSuggestionPressCancel:sender];
    [self pp_showNovaSmartSuggestionPickerAnimated:YES];
}

- (void)pp_handleNovaSmartSuggestionPickerTap:(UIButton *)sender {
    NSArray<NSDictionary<NSString *, NSString *> *> *suggestions = [self pp_novaSmartSuggestionPickerSpecs];
    if (suggestions.count == 0) {
        return;
    }
    if (sender.tag < 0 || sender.tag >= (NSInteger)suggestions.count) {
        return;
    }

    NSDictionary<NSString *, NSString *> *selectedSpec = suggestions[(NSUInteger)sender.tag];
    NSUInteger selectedIndex = [self pp_indexOfNovaSmartSuggestionSpec:selectedSpec
                                                         inSuggestions:[self pp_novaSmartSuggestionSpecs]];
    if (selectedIndex != NSNotFound) {
        self.smartSuggestionCurrentIndex = selectedIndex;
    }
    [self pp_configureCurrentNovaSmartSuggestionAnimated:YES];

    NSString *prompt = [self pp_promptForNovaSmartSuggestionSpec:selectedSpec];
    if (prompt.length == 0) return;

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.0 : 0.12;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        sender.transform = CGAffineTransformMakeScale(0.975, 0.975);
        sender.alpha = 0.84;
    } completion:^(__unused BOOL finished) {
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
        [self pp_applyNovaSuggestionPrompt:prompt];
    }];
}

- (void)pp_handleNovaAutoSendToggle:(UIButton *)sender {
    self.smartSuggestionAutoSendEnabled = !self.smartSuggestionAutoSendEnabled;
    [self pp_handleNovaSmartSuggestionPressCancel:sender];
    [self pp_updateNovaSmartSuggestionAutoSendButtonAnimated:YES];
    [self pp_configureCurrentNovaSmartSuggestionAnimated:YES];
}

- (void)pp_handleNovaSuggestionShuffleTapped:(UIButton *)sender {
    [self pp_handleNovaSmartSuggestionPressCancel:sender];
    [self pp_refreshNovaSmartSuggestionPickerChoicesAnimated:YES];
}

- (void)pp_startTypingDotsAnimation {
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *dot in self.typingDots) {
            [dot.layer removeAllAnimations];
            dot.layer.opacity = 1.0;
        }
        return;
    }

    CFTimeInterval baseTime = CACurrentMediaTime();
    NSTimeInterval phase = 0.14;
    NSTimeInterval duration = 0.86;

    [self.typingDots enumerateObjectsUsingBlock:^(UIView *dot, NSUInteger idx, __unused BOOL *stop) {
        [dot.layer removeAllAnimations];

        CAKeyframeAnimation *bounce = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.y"];
        bounce.values = @[@0.0, @(-4.0), @0.0, @0.0];
        bounce.keyTimes = @[@0.0, @0.30, @0.55, @1.0];
        bounce.duration = duration;
        bounce.repeatCount = HUGE_VALF;
        bounce.beginTime = baseTime + (idx * phase);
        bounce.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
        ];
        [dot.layer addAnimation:bounce forKey:@"pp_typingDotBounce"];

        CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        fade.values = @[@0.45, @1.0, @0.45, @0.45];
        fade.keyTimes = @[@0.0, @0.30, @0.55, @1.0];
        fade.duration = duration;
        fade.repeatCount = HUGE_VALF;
        fade.beginTime = baseTime + (idx * phase);
        [dot.layer addAnimation:fade forKey:@"pp_typingDotFade"];
    }];
}

- (void)pp_stopTypingDotsAnimation {
    for (UIView *dot in self.typingDots) {
        [dot.layer removeAllAnimations];
    }
}

- (void)showNovaTyping {
    self.typingLabel.text = kLang(@"nova_typing");
    self.statusLabel.text = kLang(@"nova_status_thinking");

    [self pp_startTypingDotsAnimation];

    NSInteger roll = arc4random_uniform(5) + 1;
    NSString *thinkingAnim = [NSString stringWithFormat:@"novabg%ld", (long)roll];
    [self pp_showThinkingHeaderLottieWithAnimation:thinkingAnim];

    if (UIAccessibilityIsReduceMotionEnabled()) {
        self.typingContainer.alpha = 1.0;
        self.typingContainer.transform = CGAffineTransformIdentity;
        return;
    }

    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.typingContainer.alpha = 1.0;
        self.typingContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideNovaTyping {
    self.statusLabel.text = kLang(@"nova_status_online");

    [self pp_hideThinkingHeaderLottie];

    [UIView animateWithDuration:0.22
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.typingContainer.alpha = 0.0;
        self.typingContainer.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(BOOL finished) {
        if (self.typingContainer.alpha == 0.0) {
            [self pp_stopTypingDotsAnimation];
        }
    }];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.tableView registerClass:[PPNovaMessageBubbleCell class] forCellReuseIdentifier:[PPNovaMessageBubbleCell reuseIdentifier]];
    [self.tableView registerClass:[PPNovaProductMessageCell class] forCellReuseIdentifier:[PPNovaProductMessageCell reuseIdentifier]];
    [self.tableView registerClass:[PPNovaReviewMessageCell class] forCellReuseIdentifier:[PPNovaReviewMessageCell reuseIdentifier]];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 92;
    self.tableView.estimatedSectionHeaderHeight = 0.0;
    self.tableView.estimatedSectionFooterHeight = 0.0;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.delaysContentTouches = NO;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0.0;
    }
     self.tableView.scrollIndicatorInsets = self.tableView.contentInset;

    [self.view addSubview:self.tableView];

    if (self.novaHeaderView) {
        [self.view bringSubviewToFront:self.novaHeaderView];
    }
    if (self.typingContainer) {
        [self.view bringSubviewToFront:self.typingContainer];
    }
    if (self.inputbar) {
        [self.view bringSubviewToFront:self.inputbar];
    }

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.novaHeaderView.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.inputbar.topAnchor],
    ]];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboardOnTap:)];
    dismissTap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:dismissTap];
}

- (void)pp_dismissKeyboardOnTap:(UITapGestureRecognizer *)tap {
    [self.view endEditing:YES];
}

#pragma mark - Keyboard

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)pp_appDidEnterBackground:(__unused NSNotification *)note {
    [self pp_stopHeaderLiveAnimations];
    [self pp_stopAmbientBackgroundAnimations];
    [self pp_stopTypingDotsAnimation];
}

- (void)pp_appWillEnterForeground:(__unused NSNotification *)note {
    if (self.dismissed || self.view.window == nil) return;
    [self pp_startHeaderLiveAnimations];
    [self pp_startAmbientBackgroundAnimations];
    if (self.typingContainer.alpha > 0.5) {
        [self pp_startTypingDotsAnimation];
    }
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGRect keyboardInView = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardInView), 0.0);
    CGFloat keyboardOffset = MAX(overlap - self.view.safeAreaInsets.bottom, 0.0);

    self.emptyStateCenterYConstraint.constant = 8.0 - (keyboardOffset > 0 ? keyboardOffset / 2.0 : 0);

    BOOL wasNearBottom = [self pp_novaIsScrolledNearBottom];
    BOOL shouldCollapseHeader = keyboardOffset > 0.0 && !self.novaHeaderCollapsed;
 
    CGFloat targetBottomConstant = keyboardOffset > 0.0
        ? -(keyboardOffset + 8.0)
        : self.inputBarRestingBottomConstant;

    if (shouldCollapseHeader) {
        [self pp_setNovaHeaderCollapsed:YES animated:NO updateInsets:NO];
    }

    UIViewAnimationOptions options = ((UIViewAnimationOptions)curve << 16) |
        UIViewAnimationOptionBeginFromCurrentState |
        UIViewAnimationOptionAllowUserInteraction;

    [UIView animateWithDuration:duration delay:0.0 options:options animations:^{
        self.inputBarBottomConstraint.constant = targetBottomConstant;
 
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (wasNearBottom) {
            [self scrollToBottomAnimated:NO];
        }
    }];
}

- (BOOL)pp_novaIsScrolledNearBottom {
    if (self.messages.count == 0) return YES;
    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat visibleHeight = CGRectGetHeight(self.tableView.bounds) - self.tableView.contentInset.top - self.tableView.contentInset.bottom;
    if (contentHeight <= visibleHeight) return YES;
    CGFloat bottomEdge = contentHeight + self.tableView.contentInset.bottom;
    CGFloat currentBottom = self.tableView.contentOffset.y + CGRectGetHeight(self.tableView.bounds);
    return (bottomEdge - currentBottom) < 60.0;
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.messages.count == 0) return;
    NSInteger tableRows = [self.tableView numberOfRowsInSection:0];
    if (tableRows <= 0) return;
    NSInteger bottomRow = MIN((NSInteger)self.messages.count, tableRows) - 1;
    if (bottomRow < 0) return;
    NSIndexPath *bottomIP = [NSIndexPath indexPathForRow:bottomRow inSection:0];
    [self.tableView scrollToRowAtIndexPath:bottomIP atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}

#pragma mark - Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count) {
        return [[UITableViewCell alloc] init];
    }
    ChatMessageModel *msg = self.messages[indexPath.row];
    PPNovaMessagePresentation *presentation = [self pp_presentationForMessage:msg rowIndex:indexPath.row];
    [self pp_logNovaTableUpdateForMessage:msg rowIndex:indexPath.row reason:@"cellForRow"];

    if (msg.messageType == ChatMessageTypeNovaProduct || msg.messageType == ChatMessageTypeNovaProductList) {
        PPNovaProductMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:presentation.style.stableReuseIdentifier forIndexPath:indexPath];
        cell.delegate = self;
        cell.accessibilityIdentifier = presentation.renderKey;
        [cell configureWithMessage:msg maxWidth:presentation.style.maxWidth];
        return cell;
    }

    if (msg.messageType == ChatMessageTypeNovaReview) {
        PPNovaReviewMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:presentation.style.stableReuseIdentifier forIndexPath:indexPath];
        cell.accessibilityIdentifier = presentation.renderKey;
        [cell configureWithMessage:msg maxWidth:presentation.style.maxWidth];
        return cell;
    }

    PPNovaMessageBubbleCell *cell = [tableView dequeueReusableCellWithIdentifier:presentation.style.stableReuseIdentifier forIndexPath:indexPath];
    cell.accessibilityIdentifier = presentation.renderKey;
    [cell configureWithMessage:msg maxWidth:presentation.style.maxWidth];
    /*
     [cell configureWithMessage:msg.text
                           date:msg.timestamp
                     isIncoming:[msg.senderID isEqualToString:@"nova_bot_id"]
                       maxWidth:[self pp_novaMessageLayoutWidthForTableView:tableView]
                         status:msg.status
                   messageModel:msg groupPosition:PPChatGroupPositionSingle]o
     */

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.messages.count) {
        return 102.0;
    }
    ChatMessageModel *msg = self.messages[indexPath.row];
    if (msg.messageType == ChatMessageTypeNovaProduct || msg.messageType == ChatMessageTypeNovaProductList) {
        return 350.0;
    }
    if (msg.messageType == ChatMessageTypeNovaReview) {
        return 130.0;
    }
    return 102.0;
}

- (CGFloat)pp_novaMessageLayoutWidthForTableView:(UITableView *)tableView {
    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (width <= 1.0) {
        width = CGRectGetWidth(self.view.bounds);
    }
    if (width <= 1.0) {
        width = UIScreen.mainScreen.bounds.size.width;
    }
    return width;
}

- (void)pp_updateVisibleNovaMessageCellWidthsForTableWidth:(CGFloat)tableWidth {
    for (UITableViewCell *visibleCell in self.tableView.visibleCells) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:visibleCell];
        if (indexPath.row < 0 || indexPath.row >= self.messages.count) continue;
        ChatMessageModel *message = self.messages[indexPath.row];
        PPNovaMessagePresentation *presentation = [self pp_presentationForMessage:message rowIndex:indexPath.row];
        [self pp_logNovaTableUpdateForMessage:message rowIndex:indexPath.row reason:@"visible_width_refresh"];

        if ([visibleCell isKindOfClass:PPNovaProductMessageCell.class]) {
            [(PPNovaProductMessageCell *)visibleCell updateAvailableWidth:tableWidth];
            visibleCell.accessibilityIdentifier = presentation.renderKey;
            continue;
        }

        if ([visibleCell isKindOfClass:PPNovaReviewMessageCell.class]) {
            PPNovaReviewMessageCell *cell = (PPNovaReviewMessageCell *)visibleCell;
            cell.accessibilityIdentifier = presentation.renderKey;
            [cell configureWithMessage:message maxWidth:presentation.style.maxWidth];
            continue;
        }

        if ([visibleCell isKindOfClass:PPNovaMessageBubbleCell.class]) {
            PPNovaMessageBubbleCell *cell = (PPNovaMessageBubbleCell *)visibleCell;
            cell.accessibilityIdentifier = presentation.renderKey;
            [cell configureWithMessage:message maxWidth:presentation.style.maxWidth];
            continue;
        }

    }
}

- (void)pp_scheduleNovaVisibleLayoutRefreshForReason:(NSString *)reason {
    if (self.pendingNovaVisibleLayoutRefreshBlock) {
        dispatch_block_cancel(self.pendingNovaVisibleLayoutRefreshBlock);
        self.pendingNovaVisibleLayoutRefreshBlock = nil;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_block_t block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.dismissed) return;
        self.pendingNovaVisibleLayoutRefreshBlock = nil;
        LOG_INFO(@"[PPNovaChat][TableUpdate] debounced_visible_refresh reason=%@", reason ?: @"unknown");
        [self pp_refreshVisibleNovaCellLayoutForCurrentTableWidth];
    });
    self.pendingNovaVisibleLayoutRefreshBlock = block;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.055 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)pp_refreshVisibleNovaCellLayoutForCurrentTableWidth {
    CGFloat width = [self pp_novaMessageLayoutWidthForTableView:self.tableView];
    [self pp_updateVisibleNovaMessageCellWidthsForTableWidth:width];
    [UIView performWithoutAnimation:^{
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.messages.count) return;

    ChatMessageModel *message = self.messages[indexPath.row];
    if (message.didAnimateInsert || UIAccessibilityIsReduceMotionEnabled()) {
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
        message.didAnimateInsert = YES;
        return;
    }

    message.didAnimateInsert = YES;
    cell.alpha = 0.0;
    cell.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0.0, 16.0),
                                             CGAffineTransformMakeScale(0.985, 0.985));
    NSTimeInterval delay = MIN(indexPath.row * 0.025, 0.09);
    [UIView animateWithDuration:0.38
                          delay:delay
         usingSpringWithDamping:0.91
          initialSpringVelocity:0.16
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        cell.alpha = 1.0;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - PPNovaFloatingInputBarViewDelegate

- (void)novaInputBarDidBeginEditing:(PPNovaFloatingInputBarView *)bar {
    if (self.smartSuggestionPickerVisible) {
        [self pp_hideNovaSmartSuggestionPickerAnimated:YES];
    }
}

- (void)novaInputBarDidTapSuggestions:(PPNovaFloatingInputBarView *)bar {
    if (self.smartSuggestionPickerVisible) {
        [self pp_hideNovaSmartSuggestionPickerAnimated:YES];
        return;
    }

    [self pp_setNovaHeaderCollapsed:YES animated:YES updateInsets:NO];
    [self pp_showNovaSmartSuggestionPickerAnimated:YES];
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeText:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.novaInputHasText = trimmed.length > 0;
    if (trimmed.length > 0) {
        [self pp_stopNovaSmartSuggestionRotation];
    } else {
        [self pp_startNovaSmartSuggestionRotationIfNeeded];
    }
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didSendText:(NSString *)text {
    [self pp_hideNovaSmartSuggestionPickerAnimated:YES];
    [self pp_handleNovaSubmittedText:text];
}

- (void)novaInputBar:(PPNovaFloatingInputBarView *)bar didChangeHeight:(CGFloat)height {
    CGFloat keyboardOffset = -(self.inputBarBottomConstraint.constant) - 8.0;
    if (keyboardOffset < 0) keyboardOffset = 0;

    BOOL wasNearBottom = [self pp_novaIsScrolledNearBottom];

    [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        UIEdgeInsets currentInset = self.tableView.contentInset;
        currentInset.bottom = 0.0;
        self.tableView.contentInset = currentInset;
        self.tableView.scrollIndicatorInsets = currentInset;
        [self.view layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        if (wasNearBottom) {
            [self scrollToBottomAnimated:NO];
        }
    }];
}

- (void)pp_handleNovaSubmittedText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) return;
    NSString *requestID = [self pp_newNovaScopedIDWithPrefix:@"request"];

    [self pp_hideNovaSmartSuggestionPickerAnimated:YES];
    [self pp_stopNovaSmartSuggestionRotation];
    [self addUserMessage:trimmedText requestID:requestID];

    // Check for "add to cart" intent
    if ([self pp_isAddToCartIntent:trimmedText]) {
        NSString *responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"cart"];
        if (self.pendingCartProduct) {
            [self pp_handleAddToCartForProduct:self.pendingCartProduct requestID:requestID responseID:responseID];
            return;
        } else if (self.lastShownProducts.count > 1) {
            NSString *reply = kLang(@"nova_add_to_cart_which");
            [self addNovaMessage:reply requestID:requestID responseID:responseID];
            return;
        }
    }

    NSUInteger cachedProductsBeforeSend = self.lastShownProducts.count;
    [self pp_prepareNovaRenderStateForRequestID:requestID
                        cachedProductsBeforeSend:cachedProductsBeforeSend];
    [self pp_updateMemoryFromUserText:trimmedText];
    [self pp_logNovaIntentForUserText:trimmedText stage:@"submitted"];
    [PPAnalytics logNovaMessageSentWithCharCount:trimmedText.length
                                         isArabic:[self textContainsArabic:trimmedText]
                                       sessionID:self.novaSessionId];
    self.novaHasSentFirstMessage = YES;
    self.novaRequestGeneration = self.novaRequestGeneration + 1;
    NSUInteger generation = self.novaRequestGeneration;
    [self pp_startNovaRequestWatchdogForGeneration:generation userText:trimmedText requestID:requestID];

    [self showNovaTyping];

    // Route through the Cloud Run proxy only; the legacy callable path is kept
    // defined for now but must not race this send action.
    NSString *responseID = [self pp_novaResponseIDFromResponseData:nil requestID:requestID source:@"agent_proxy"];
    PPAgentClient *agent = [PPAgentClient shared];
    if (![agent.sessionId hasPrefix:@"s_"]) {
        agent.sessionId = self.novaSessionId;
    }
    __weak typeof(self) weakSelf = self;
    [agent sendMessage:trimmedText completion:^(PPAgentMessage *reply, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf.dismissed) return;
            if (error) {
                [strongSelf hideNovaTyping];
                PPAgentMessage *fallback = [PPAgentMessage agentText:NSLocalizedString(@"nova_error_generic", nil)];
                [strongSelf addNovaMessage:fallback.text requestID:requestID responseID:responseID];
                return;
            }
            [strongSelf pp_handleNovaAgentProxyReply:reply
                                             userText:trimmedText
                                            requestID:requestID
                                   fallbackResponseID:responseID
                                           generation:generation];
        });
    }];
}

// Production-safe add-to-cart intent classifier.
// Adding to cart is irreversible from a trust standpoint — false positives are far worse
// than false negatives. Rules:
//   1. Cap total length (≤30 chars) — true affirmations are short.
//   2. Reject if any negation token is present (English/Arabic).
//   3. Tier 1: bare-word exact match (e.g., "اريد" alone — but not "اريد المساعدة").
//   4. Tier 2: prefix + word-boundary match with ≤15-char tail
//      (e.g., "yes please" YES; "yes I have a question" NO).
- (BOOL)pp_isAddToCartIntent:(NSString *)text {
    if (text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0 || trimmed.length > 30) return NO;
    NSString *lower = [trimmed lowercaseString];

    // -- Negations short-circuit --------------------------------------------------
    NSArray<NSString *> *englishNegations = @[
        @"don't", @"dont", @"do not", @"not", @"no", @"never", @"won't", @"wont"
    ];
    for (NSString *neg in englishNegations) {
        if ([self pp_lowercase:lower containsWord:neg]) return NO;
    }
    NSArray<NSString *> *arabicNegationsSubstr = @[
        @"لا ", @" لا", @"لست", @"ليس", @"ليست",
        @"ما ", @" ما", @"مش ", @"مو ", @"مب "
    ];
    for (NSString *neg in arabicNegationsSubstr) {
        if ([trimmed containsString:neg]) return NO;
    }
    if ([trimmed isEqualToString:@"لا"] || [trimmed isEqualToString:@"ما"]) return NO;

    // -- Tier 1: bare-word exact match. Words too generic for substring matching --
    // ("اريد" alone is fine; "اريد المساعدة" must NOT trigger.)
    NSArray<NSString *> *exactOnly = @[
        @"اريد", @"أريد", @"بدي", @"ابي", @"أبي", @"ودي",
        @"حسنا", @"حسناً", @"موافق", @"please"
    ];
    for (NSString *aff in exactOnly) {
        if ([trimmed isEqualToString:aff] || [lower isEqualToString:aff.lowercaseString]) return YES;
    }

    // -- Tier 2: prefix + boundary + short tail -----------------------------------
    NSArray<NSString *> *prefixAffirmatives = @[
        @"yes", @"yep", @"yeah", @"yup", @"sure", @"ok", @"okay",
        @"add it", @"add to cart", @"add",
        @"buy it", @"buy", @"take it", @"i want it", @"i'll take",
        @"do it", @"go ahead", @"please add",
        @"نعم", @"ايوه", @"ايوا", @"ايه",
        @"اضف", @"أضف", @"اضفه", @"أضفه", @"اضيفه", @"أضيفه", @"اضفها", @"أضفها",
        @"اشتري", @"اشتريه",
        @"تمام", @"ماشي", @"يلا", @"هيا", @"اوكي", @"أوكي"
    ];
    for (NSString *aff in prefixAffirmatives) {
        NSString *lp = aff.lowercaseString;
        if (![lower hasPrefix:lp]) continue;
        NSInteger affLen = (NSInteger)lp.length;
        if ((NSInteger)lower.length == affLen) return YES;
        unichar nextChar = [lower characterAtIndex:affLen];
        BOOL isWordBoundary = (nextChar == ' ' || nextChar == ',' || nextChar == '.' ||
                               nextChar == '!' || nextChar == '\t' || nextChar == 0x060C);
        if (!isWordBoundary) continue;
        if ((NSInteger)lower.length - affLen <= 15) return YES;
    }
    return NO;
}

- (BOOL)pp_lowercase:(NSString *)haystack containsWord:(NSString *)word {
    if (word.length == 0 || haystack.length == 0) return NO;
    NSString *escaped = [NSRegularExpression escapedPatternForString:word];
    NSString *pattern = [NSString stringWithFormat:@"(^|\\W)%@(\\W|$)", escaped];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    if (!regex) return NO;
    return [regex numberOfMatchesInString:haystack
                                  options:0
                                    range:NSMakeRange(0, haystack.length)] > 0;
}

- (void)pp_handleAddToCartForProduct:(PetAccessory *)product {
    [self pp_handleAddToCartForProduct:product requestID:nil responseID:nil];
}

- (void)pp_handleAddToCartForProduct:(PetAccessory *)product
                            requestID:(NSString *)requestID
                           responseID:(NSString *)responseID {
    [PPHUD showLoading:@""];

    CartItem *item = [[CartItem alloc] initWithAccessory:product quantity:1];
    item.type = product.isPetMedicine ? @"petMedicine" : @"petAccessory";

    BOOL success = [[CartManager sharedManager] addItem:item];

    if (success) {
        NSString *category = [NSString stringWithFormat:@"acc-%ld", (long)product.petMainCategoryID];
        [PPAnalytics logAddToCartItemID:product.accessoryID
                                    name:product.name
                                category:category
                                   price:product.finalPrice.doubleValue
                                quantity:1];

        UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
        [fb prepare];
        [fb notificationOccurred:UINotificationFeedbackTypeSuccess];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        [PPHUD dismiss];
        if (success) {
            NSString *msg = kLang(@"nova_added_to_cart");
            [self addNovaMessage:msg requestID:requestID responseID:responseID];
            self.pendingCartProduct = nil; // Clear after adding
        } else {
            NSString *msg = kLang(@"nova_add_to_cart_failed");
            [self addNovaMessage:msg requestID:requestID responseID:responseID];
        }
    });
}

- (void)addUserMessage:(NSString *)text {
    [self addUserMessage:text requestID:nil];
}

- (void)addUserMessage:(NSString *)text requestID:(NSString *)requestID {
    [self addMessageWithText:text isIncoming:NO requestID:requestID responseID:nil];
}

- (void)addNovaMessage:(NSString *)text {
    [self addNovaMessage:text requestID:nil responseID:nil];
}

- (void)addNovaMessage:(NSString *)text requestID:(NSString *)requestID responseID:(NSString *)responseID {
    [self addMessageWithText:text isIncoming:YES requestID:requestID responseID:responseID];
}

// Adds a Nova-side system bubble (connectivity status, blocked-account, etc.)
// only if the previous Nova message wasn't already this exact text. Prevents
// the "Nova is unavailable / Nova is unavailable / Nova is unavailable" loop
// when the user keeps typing during a backend outage.
- (void)pp_addNovaSystemBubbleIfNew:(NSString *)text {
    if (text.length == 0) {
        return;
    }
    for (NSInteger i = (NSInteger)self.messages.count - 1; i >= 0; i--) {
        ChatMessageModel *msg = self.messages[i];
        if (![msg.senderID isEqualToString:@"nova_bot_id"]) {
            continue;
        }
        if (msg.messageType != ChatMessageTypeText) {
            break;
        }
        if ([msg.text isEqualToString:text]) {
            return;
        }
        break;
    }
    [self addNovaMessage:text];
}

- (void)addMessageWithText:(NSString *)text isIncoming:(BOOL)isIncoming {
    [self addMessageWithText:text isIncoming:isIncoming requestID:nil responseID:nil];
}

- (void)addMessageWithText:(NSString *)text
                isIncoming:(BOOL)isIncoming
                 requestID:(NSString *)requestID
                responseID:(NSString *)responseID {
    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.text = text;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSent;
    msg.messageType = ChatMessageTypeText;
    msg.senderID = isIncoming ? @"nova_bot_id" : [UserManager sharedManager].currentUser.ID;
    msg.novaRequestID = requestID;
    msg.novaResponseID = responseID;
    // Lesson: text-only / clarification / correction / rejection bubbles never
    // own card payloads. Cards belong only to the response that returned them.
    msg.novaProducts = nil;

    [[PPNovaLocalChatMemory sharedMemory] addMessageWithRole:isIncoming ? @"nova" : @"user" text:text];

    [[PPChatFeedbackManager shared] playFeedbackForEvent:isIncoming ? PPChatFeedbackEventIncomingActiveChat : PPChatFeedbackEventOutgoingSend];
    [self pp_appendNovaMessageModel:msg updateReason:isIncoming ? @"insert_assistant_text" : @"insert_user_text"];

    LOG_INFO(@"[PPNovaChat][RenderBinding] text_bubble_attached request_id=%@ response_id=%@ attached_to_message_id=%@ role=%@ incoming_card_count=0 reused_previous_payload=NO",
             requestID ?: @"",
             responseID ?: @"",
             msg.ID ?: @"",
             isIncoming ? @"nova" : @"user");
}

- (void)pp_appendNovaMessageModel:(ChatMessageModel *)message updateReason:(NSString *)reason {
    if (!message) {
        return;
    }

    NSInteger oldRowCount = [self.tableView numberOfRowsInSection:0];
    ChatMessageModel *previousMessage = self.messages.lastObject;
    BOOL relatedCardsFollowAssistantText = [reason isEqualToString:@"insert_cards"] &&
        previousMessage.messageType == ChatMessageTypeText &&
        [previousMessage.senderID isEqualToString:@"nova_bot_id"] &&
        [previousMessage.novaRequestID isEqualToString:message.novaRequestID ?: @""] &&
        [previousMessage.novaResponseID isEqualToString:message.novaResponseID ?: @""];
    CFTimeInterval now = CACurrentMediaTime();
    BOOL recentAutoScroll = self.novaLastTableMutationRequestedAutoScroll &&
        (now - self.novaLastTableMutationTimestamp) < 1.0;
    BOOL shouldAutoScroll = [self pp_novaIsScrolledNearBottom] ||
        (relatedCardsFollowAssistantText && recentAutoScroll);
    [self.messages addObject:message];
    NSArray<NSIndexPath *> *deletedIndexPaths = [self pp_deletedIndexPathsByTrimmingMessageHistoryIfNeeded];
    NSInteger insertedRow = (NSInteger)self.messages.count - 1;
    NSIndexPath *insertedIndexPath = insertedRow >= 0 ? [NSIndexPath indexPathForRow:insertedRow inSection:0] : nil;

    [self updateNovaEmptyStateAnimated:YES];
    [self pp_logNovaTableUpdateForMessage:message rowIndex:insertedRow reason:reason ?: @"append"];
    [self pp_applyNovaTableMutationWithInsertedIndexPath:insertedIndexPath
                                       deletedIndexPaths:deletedIndexPaths
                                             oldRowCount:oldRowCount
                                        shouldAutoScroll:shouldAutoScroll
                                            updateReason:reason ?: @"append"];
    self.novaLastTableMutationRequestedAutoScroll = shouldAutoScroll;
    self.novaLastTableMutationTimestamp = now;
}

// Cap message history at 100; when exceeded drop oldest 20 with targeted deletes.
// A long Nova session would otherwise grow unbounded (memory + scroll perf).
- (NSArray<NSIndexPath *> *)pp_deletedIndexPathsByTrimmingMessageHistoryIfNeeded {
    static const NSUInteger kCap = 100;
    static const NSUInteger kTrimChunk = 20;
    if (self.messages.count <= kCap) return @[];
    NSUInteger targetFloor = kCap - kTrimChunk;
    if (self.messages.count <= targetFloor) return @[];
    NSUInteger removeCount = self.messages.count - targetFloor;
    NSMutableArray<NSIndexPath *> *deleted = [NSMutableArray arrayWithCapacity:removeCount];
    for (NSUInteger idx = 0; idx < removeCount; idx++) {
        [deleted addObject:[NSIndexPath indexPathForRow:(NSInteger)idx inSection:0]];
    }
    [self.messages removeObjectsInRange:NSMakeRange(0, removeCount)];
    return deleted.copy;
}

- (void)pp_trimMessageHistoryIfNeeded {
    NSInteger oldRowCount = [self.tableView numberOfRowsInSection:0];
    NSArray<NSIndexPath *> *deletedIndexPaths = [self pp_deletedIndexPathsByTrimmingMessageHistoryIfNeeded];
    if (deletedIndexPaths.count == 0) {
        return;
    }
    [self pp_applyNovaTableMutationWithInsertedIndexPath:nil
                                       deletedIndexPaths:deletedIndexPaths
                                             oldRowCount:oldRowCount
                                        shouldAutoScroll:NO
                                            updateReason:@"history_trim"];
}

- (void)pp_applyNovaTableMutationWithInsertedIndexPath:(NSIndexPath *)insertedIndexPath
                                    deletedIndexPaths:(NSArray<NSIndexPath *> *)deletedIndexPaths
                                          oldRowCount:(NSInteger)oldRowCount
                                     shouldAutoScroll:(BOOL)shouldAutoScroll
                                         updateReason:(NSString *)reason {
    NSInteger insertedCount = insertedIndexPath ? 1 : 0;
    NSInteger expectedOldRows = (NSInteger)self.messages.count - insertedCount + (NSInteger)deletedIndexPaths.count;
    if (oldRowCount != expectedOldRows) {
        CGPoint preservedOffset = self.tableView.contentOffset;
        LOG_WARN(@"[PPNovaChat][TableUpdate] full_reload_reconcile reason=%@ tableRows=%ld expectedOldRows=%ld finalRows=%lu inserted=%ld deleted=%lu",
                 reason ?: @"unknown",
                 (long)oldRowCount,
                 (long)expectedOldRows,
                 (unsigned long)self.messages.count,
                 (long)insertedCount,
                 (unsigned long)deletedIndexPaths.count);
        [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
            [self.tableView layoutIfNeeded];
        }];
        if (shouldAutoScroll) {
            [self scrollToBottomAnimated:NO];
        } else {
            [self.tableView setContentOffset:preservedOffset animated:NO];
        }
        return;
    }

    CGPoint preservedOffset = self.tableView.contentOffset;
    LOG_INFO(@"[PPNovaChat][TableUpdate] targeted_mutation reason=%@ oldRows=%ld finalRows=%lu inserted=%ld deleted=%lu autoScroll=%@",
             reason ?: @"unknown",
             (long)oldRowCount,
             (unsigned long)self.messages.count,
             (long)insertedCount,
             (unsigned long)deletedIndexPaths.count,
             shouldAutoScroll ? @"YES" : @"NO");

    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        if (shouldAutoScroll) {
            [self scrollToBottomAnimated:YES];
        } else {
            [self.tableView setContentOffset:preservedOffset animated:NO];
        }
    }];
    [self.tableView beginUpdates];
    if (deletedIndexPaths.count > 0) {
        [self.tableView deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationNone];
    }
    if (insertedIndexPath) {
        [self.tableView insertRowsAtIndexPaths:@[insertedIndexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
    [self.tableView endUpdates];
    [CATransaction commit];
}

// Best-effort principle-based reply sanitizer. Backend `sanitize_reply` flags issues but
// does not hard-strip; this is the client-side belt-and-suspenders so users never see:
//   - re-greetings (the screen already showed one when it opened),
//   - pressure phrases that the Nova baseline explicitly removed
//     (limited stock / availability / reserve-now / pressure CTAs, EN + AR).
// If everything gets stripped, returns "" — caller (pp_dispatchNovaRequest) skips the bubble.
- (NSString *)pp_sanitizeNovaReply:(NSString *)text hideStructuredSuggestions:(BOOL)hideStructuredSuggestions {
    if (text.length == 0) return text;

    NSString *result = text;
    if (hideStructuredSuggestions) {
        result = [self pp_stripStructuredNovaSuggestionText:result];
    }
    result = [self pp_stripNovaSuggestionReferenceTags:result];

    // Collapse runs of whitespace introduced by mid-text strips.
    NSRegularExpression *ws = [NSRegularExpression regularExpressionWithPattern:@"[ \\t]{2,}"
                                                                        options:0
                                                                          error:nil];
    if (ws) {
        result = [ws stringByReplacingMatchesInString:result
                                              options:0
                                                range:NSMakeRange(0, result.length)
                                         withTemplate:@" "];
    }
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return result;
}

- (NSString *)pp_stripNovaSuggestionReferenceTags:(NSString *)text {
    if (text.length == 0) return text;

    NSString *result = text;
    NSArray<NSString *> *patterns = @[
        @"\\[PRODUCT_ID:\\s*[^\\]]+\\]",
        @"\\[SERVICE_ID:\\s*[^\\]]+\\]",
        @"\\[MEDICINE_ID:\\s*[^\\]]+\\]",
        @"\\[PET_AD_ID:\\s*[^\\]]+\\]",
        @"\\[AD_ID:\\s*[^\\]]+\\]",
        @"\\[ADOPTION_ID:\\s*[^\\]]+\\]",
        @"\\[ADOPT_PET_ID:\\s*[^\\]]+\\]",
        @"\\[VET_ID:\\s*[^\\]]+\\]",
        @"\\[VETERINARIAN_ID:\\s*[^\\]]+\\]"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (!regex) continue;
        result = [regex stringByReplacingMatchesInString:result
                                                 options:0
                                                   range:NSMakeRange(0, result.length)
                                            withTemplate:@""];
    }
    return result;
}

- (NSString *)pp_stripStructuredNovaSuggestionText:(NSString *)text {
    if (text.length == 0) return text;

    NSString *result = text;
    NSRegularExpression *tagSentenceRegex =
    [NSRegularExpression regularExpressionWithPattern:@"[^\\.\\n!؟\\?]*(?:\\[PRODUCT_ID:|\\[SERVICE_ID:|\\[MEDICINE_ID:|\\[PET_AD_ID:|\\[AD_ID:|\\[ADOPTION_ID:|\\[ADOPT_PET_ID:|\\[VET_ID:|\\[VETERINARIAN_ID:)[^\\.\\n!؟\\?]*[\\.\\n!؟\\?]?"
                                             options:NSRegularExpressionCaseInsensitive
                                               error:nil];
    if (tagSentenceRegex) {
        result = [tagSentenceRegex stringByReplacingMatchesInString:result
                                                            options:0
                                                              range:NSMakeRange(0, result.length)
                                                       withTemplate:@"\n"];
    }

    NSMutableArray<NSString *> *keptLines = [NSMutableArray array];
    NSArray<NSString *> *lines = [result componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length == 0) {
            continue;
        }
        if ([self pp_isNovaStructuredSuggestionLine:trimmed]) {
            continue;
        }
        [keptLines addObject:trimmed];
    }
    if (keptLines.count == 1) {
        NSString *onlyLine = keptLines.firstObject;
        if ([onlyLine hasSuffix:@":"] || [onlyLine hasSuffix:@"："] || [onlyLine hasSuffix:@"،"]) {
            return @"";
        }
    }
    return [keptLines componentsJoinedByString:@"\n"];
}

- (BOOL)pp_novaReplyContainsNoProductClaim:(NSString *)text {
    if (text.length == 0) {
        return NO;
    }
    NSArray<NSString *> *patterns = @[
        @"couldn['’]?t\\s+find",
        @"could\\s+not\\s+find",
        @"can['’]?t\\s+find",
        @"cannot\\s+find",
        @"didn['’]?t\\s+find",
        @"did\\s+not\\s+find",
        @"unable\\s+to\\s+find",
        @"no\\s+(matching\\s+)?(products?|items?|results?|matches?|inventory)",
        @"not\\s+available",
        @"current\\s+inventory",
        @"check\\s+(the\\s+)?(pure\\s+pets\\s+)?catalog",
        @"لم\\s+أجد",
        @"لا\\s*أجد",
        @"لم\\s+اجد",
        @"لا\\s*اجد",
        @"لم\\s+نجد",
        @"لا\\s*نجد",
        @"ما\\s+لقيت",
        @"ما\\s+لقينا",
        @"لا\\s+يوجد",
        @"لا\\s+توجد",
        @"غير\\s+متوفر"
    ];
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        if (regex && [regex numberOfMatchesInString:text options:0 range:NSMakeRange(0, text.length)] > 0) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)pp_isNovaStructuredSuggestionLine:(NSString *)line {
    if (line.length == 0) {
        return YES;
    }

    NSString *lower = line.lowercaseString;
    if ([lower containsString:@"productid"] ||
        [lower containsString:@"product_ids"] ||
        [lower containsString:@"serviceid"] ||
        [lower containsString:@"service_ids"] ||
        [lower containsString:@"medicineid"] ||
        [lower containsString:@"medicine_ids"] ||
        [lower containsString:@"petadid"] ||
        [lower containsString:@"pet_ad_ids"] ||
        [lower containsString:@"adoptionid"] ||
        [lower containsString:@"adoption_ids"] ||
        [lower containsString:@"adoptpetid"] ||
        [lower containsString:@"adopt_pet_ids"] ||
        [lower containsString:@"vetid"] ||
        [lower containsString:@"vet_ids"] ||
        [lower containsString:@"veterinarianid"] ||
        [lower containsString:@"veterinarian_ids"]) {
        return YES;
    }
    NSArray<NSString *> *headers = @[
        @"curated picks", @"suggestions", @"suggestion", @"recommended products",
        @"recommended items", @"recommended services", @"products", @"services", @"medicines",
        @"pet ads", @"ads", @"adoptions", @"adoption posts", @"vets", @"veterinarians",
        @"اختيارات", @"اختيارات مناسبة", @"اقتراحات", @"الاقتراحات",
        @"منتجات", @"المنتجات", @"خدمات", @"الخدمات", @"أدوية", @"الأدوية",
        @"إعلانات", @"اعلانات", @"تبني", @"للتبني", @"أطباء", @"اطباء", @"بيطريين"
    ];
    for (NSString *header in headers) {
        if ([lower isEqualToString:header] ||
            [lower isEqualToString:[header stringByAppendingString:@":"]] ||
            [lower isEqualToString:[header stringByAppendingString:@"："]]) {
            return YES;
        }
    }
    if (([lower containsString:@"recommend"] ||
         [line containsString:@"أنصح"] ||
         [line containsString:@"أرشح"]) &&
        ([line hasSuffix:@":"] || [line hasSuffix:@"："])) {
        return YES;
    }

    unichar first = [line characterAtIndex:0];
    if (first == '-' || first == 0x2022 || first == '*') {
        return YES;
    }

    NSRegularExpression *numberedLineRegex =
    [NSRegularExpression regularExpressionWithPattern:@"^\\d+[\\).]\\s+"
                                             options:0
                                               error:nil];
    return [numberedLineRegex numberOfMatchesInString:line
                                              options:0
                                                range:NSMakeRange(0, line.length)] > 0;
}



- (void)animateInsertedRowAtIndexPath:(NSIndexPath *)indexPath {
    [self pp_applyNovaTableMutationWithInsertedIndexPath:indexPath
                                       deletedIndexPaths:@[]
                                             oldRowCount:[self.tableView numberOfRowsInSection:0]
                                        shouldAutoScroll:[self pp_novaIsScrolledNearBottom]
                                            updateReason:@"legacy_insert"];
}

#pragma mark - PPNovaProductMessageCellDelegate

- (void)novaProductCell_didTapAddToCart:(id)item {
    if (![item isKindOfClass:PetAccessory.class]) {
        return;
    }
    [self pp_handleAddToCartForProduct:(PetAccessory *)item];
}

- (void)novaProductCell_didTapProduct:(id)item {
    if ([item isKindOfClass:PetAd.class]) {
        PetAd *ad = (PetAd *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"pet_ad"
                                               itemID:ad.adID
                                            sessionID:self.novaSessionId];
        ViewerVC *viewer = [[ViewerVC alloc] init];
        viewer.ad = ad;
        [self pp_openNovaStackViewer:viewer];
        return;
    }

    if ([item isKindOfClass:AdoptPetModel.class]) {
        AdoptPetModel *pet = (AdoptPetModel *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"adoption"
                                               itemID:pet.documentID
                                            sessionID:self.novaSessionId];
        AdoptPetDetailsViewController *viewer = [[AdoptPetDetailsViewController alloc] initWithModel:pet];
        [self pp_openNovaStackViewer:viewer];
        return;
    }

    if ([item isKindOfClass:ServiceModel.class]) {
        ServiceModel *service = (ServiceModel *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"service"
                                               itemID:service.serviceID
                                            sessionID:self.novaSessionId];
        ServiceViewerViewController *viewer = [ServiceViewerViewController new];
        viewer.service = service;
        [PPFunc presentSheetFrom:self sheetVC:viewer detentStyle:PPSheetDetentStyleLargeOnly];
        return;
    }

    if ([item isKindOfClass:VetModel.class]) {
        VetModel *vet = (VetModel *)item;
        [PPAnalytics logNovaPreviewOpenedWithItemKind:@"vet"
                                               itemID:vet.vetID
                                            sessionID:self.novaSessionId];
        PPPetCareVetViewrVC *viewer = [[PPPetCareVetViewrVC alloc] initWithVet:vet
                                                                  mainKindName:nil];
        [PPFunc presentSheetFrom:self sheetVC:viewer detentStyle:PPSheetDetentStyleLargeOnly];
        return;
    }

    if (![item isKindOfClass:PetAccessory.class]) {
        return;
    }

    PetAccessory *product = (PetAccessory *)item;
    [PPAnalytics logNovaPreviewOpenedWithItemKind:(product.isPetMedicine ? @"medicine" : @"product")
                                           itemID:product.accessoryID
                                        sessionID:self.novaSessionId];
    NSString *category = [NSString stringWithFormat:@"acc-%ld", (long)product.petMainCategoryID];
    [PPAnalytics logSelectItemWithItemID:product.accessoryID
                                     name:product.name
                                 category:category
                                    price:product.finalPrice.doubleValue
                                 listName:@"nova_chat"];

    if (product.isPetMedicine) {
        VetMedicineModel *medicine = [self pp_novaMedicineModelFromAccessory:product];
        PPPetCareViewerVC *viewer = [[PPPetCareViewerVC alloc] initWithMedicine:medicine
                                                                   mainKindName:kLang(@"pet_care_all_pets")];
        [self pp_openNovaStackViewer:viewer];
        return;
    }

    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = product;
    [self pp_openNovaStackViewer:viewer];
}

- (VetMedicineModel *)pp_novaMedicineModelFromAccessory:(PetAccessory *)accessory {
    NSMutableDictionary *data = [[accessory toFirestoreDictionary] mutableCopy] ?: [NSMutableDictionary dictionary];
    data[@"accessKindType"] = @(AccessTypePetMedicine);
    data[@"type"] = @(AccessTypePetMedicine);
    if (accessory.name.length > 0) {
        data[@"title"] = accessory.name;
        data[@"name"] = accessory.name;
        data[@"nameEn"] = accessory.name;
    }
    if (accessory.desc.length > 0) {
        data[@"description"] = accessory.desc;
        data[@"desc"] = accessory.desc;
        data[@"descEn"] = accessory.desc;
    }
    NSString *firstImage = [accessory.imageURLsArray.firstObject isKindOfClass:NSString.class]
        ? accessory.imageURLsArray.firstObject
        : @"";
    if (firstImage.length > 0) {
        data[@"imageUrl"] = firstImage;
    }
    data[@"stockQuantity"] = @(MAX(accessory.quantity, 0));
    data[@"quantity"] = @(MAX(accessory.quantity, 0));
    data[@"isAvailable"] = @(accessory.quantity > 0);
    data[@"isPublished"] = @YES;
    if (!data[@"currency"]) {
        data[@"currency"] = @"QAR";
    }
    return [VetMedicineModel fromDictionary:data withID:accessory.accessoryID ?: @""];
}

- (void)pp_openNovaStackViewer:(UIViewController *)viewer {
    if (!viewer) {
        return;
    }
    viewer.hidesBottomBarWhenPushed = YES;
    if (self.navigationController) {
        [self.navigationController pushViewController:viewer animated:YES];
    } else {
        PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:viewer];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

@end
