//
//  PPNovaChatViewController.m
//  Pure Pets
//

#import "PPNovaChatViewController.h"
#import "ChatMessageModel.h"
#import "ChatMessageCell.h"
#import "PPChatInputBarView.h"
#import "EnumValues.h"
#import "AppManager.h"
#import "PPNavigationController.h"

@interface PPNovaChatViewController () <UITableViewDelegate, UITableViewDataSource, PPChatInputBarViewDelegate>

@property (nonatomic, strong) UIView *novaHeaderView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<ChatMessageModel *> *messages;
@property (nonatomic, strong) PPChatInputBarView *inputbar;
@property (nonatomic, strong) NSLayoutConstraint *inputBarBottomConstraint;
@property (nonatomic, strong) UIButton *bottomFillBlurView;

@end

@implementation PPNovaChatViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"";
    self.view.backgroundColor = AppBackgroundClr;
    self.messages = [NSMutableArray array];

    [self setupNovaHeader];
    [self setupInputView];
    [self setupTableView];
    [self setupBottomFillBlur];

    [self registerForKeyboardNotifications];

    [self insertNovaGreeting];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Initial Data

- (void)insertNovaGreeting {
    NSString *greeting = Language.isRTL
        ? @"أهلاً، أنا نوفا من بيور بتس. أقدر أساعدك في المنتجات، الطلبات، أو نصائح العناية بحيوانك."
        : @"Hi, I'm Nova from Pure Pets. I can help with products, orders, or pet care guidance.";

    [self addMessageWithText:greeting isIncoming:YES];
}

- (void)insertNovaReplyForUserText:(NSString *)userText {
    NSString *trimmedText = [userText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL isArabic = [self textContainsArabic:trimmedText];
    NSString *lowerText = trimmedText.lowercaseString;
    NSString *reply = nil;

    if (isArabic) {
        if ([trimmedText containsString:@"قط"] || [trimmedText containsString:@"قطة"] || [trimmedText containsString:@"قطط"]) {
            reply = @"لو عندك قطة، أقدر أساعدك تختار منتج مناسب من بيور بتس حسب عمرها واحتياجها. تحب أبدأ بالأكل ولا الرمل ولا الألعاب؟";
        } else if ([trimmedText containsString:@"كلب"] || [trimmedText containsString:@"جرو"] || [trimmedText containsString:@"كلاب"]) {
            reply = @"لو عندك كلب، أقدر أرشح لك الأفضل من بيور بتس حسب العمر والحجم. تبحث عن أكل، ألعاب، ولا أدوات عناية؟";
        } else if ([trimmedText containsString:@"طلب"] || [trimmedText containsString:@"اوردر"] || [trimmedText containsString:@"الشحن"] || [trimmedText containsString:@"التوصيل"]) {
            reply = @"أقدر أساعدك في أسئلة الطلبات والتوصيل، لكن لا أستطيع معرفة حالة الطلب بدون ربط البيانات الحقيقية. افتح الطلب من التطبيق أو اكتب لي رقم الطلب لو الربط متاح لاحقاً.";
        } else {
            reply = @"أنا نوفا من بيور بتس. أقدر أساعدك في اختيار المنتجات، الطلبات، أو نصائح العناية بحيوانك. تحب أساعدك في إيه بالضبط؟";
        }
    } else {
        if ([lowerText containsString:@"cat"] || [lowerText containsString:@"kitten"]) {
            reply = @"For a cat or kitten, I can help you choose the right Pure Pets product based on age and need. Are you looking for food, litter, or toys?";
        } else if ([lowerText containsString:@"dog"] || [lowerText containsString:@"puppy"]) {
            reply = @"For a dog or puppy, I can recommend the best Pure Pets option based on age and size. Are you looking for food, toys, or care items?";
        } else if ([lowerText containsString:@"order"] || [lowerText containsString:@"delivery"] || [lowerText containsString:@"shipping"]) {
            reply = @"I can help with order and delivery questions, but I cannot check live order status until real order data is connected.";
        } else {
            reply = @"I'm Nova from Pure Pets. I can help with products, orders, or pet care guidance. What would you like help with?";
        }
    }

    [self addMessageWithText:reply isIncoming:YES];
}

- (BOOL)textContainsArabic:(NSString *)text {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c >= 0x0600 && c <= 0x06FF) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Setup UI

- (void)setupNovaHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = UIColor.clearColor;
    [self.view addSubview:header];
    self.novaHeaderView = header;

    UIView *accentDot = [[UIView alloc] init];
    accentDot.translatesAutoresizingMaskIntoConstraints = NO;
    accentDot.backgroundColor = AppPrimaryClr;
    accentDot.layer.cornerRadius = 3.0;
    if (@available(iOS 13.0, *)) {
        accentDot.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [header addSubview:accentDot];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [GM boldFontWithSize:PPFontTitle1] ?: [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    nameLabel.textColor = AppPrimaryTextClr;
    nameLabel.text = Language.isRTL ? @"نوفا" : @"NOVA";
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 1;
    [header addSubview:nameLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.font = [GM MidFontWithSize:PPFontCaption1] ?: [UIFont systemFontOfSize:PPFontCaption1 weight:UIFontWeightMedium];
    subtitleLabel.textColor = AppSecondaryTextClr;
    subtitleLabel.text = Language.isRTL
        ? @"المساعد الذكي من بيور بتس"
        : @"Pure Pets AI Assistant";
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 1;
    [header addSubview:subtitleLabel];

    CGFloat topOffset = PPNavBarHeightFull + PPSpaceSM;

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:topOffset],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:64.0],

        [accentDot.topAnchor constraintEqualToAnchor:header.topAnchor constant:PPSpaceXS],
        [accentDot.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [accentDot.widthAnchor constraintEqualToConstant:6.0],
        [accentDot.heightAnchor constraintEqualToConstant:6.0],

        [nameLabel.topAnchor constraintEqualToAnchor:accentDot.bottomAnchor constant:PPSpaceXS],
        [nameLabel.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],

        [subtitleLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor],
        [subtitleLabel.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
    ]];
}

- (void)setupInputView {
    self.inputbar = [[PPChatInputBarView alloc] init];
    self.inputbar.delegate = self;
    self.inputbar.translatesAutoresizingMaskIntoConstraints = NO;
    self.inputbar.semanticContentAttribute = GM.setSemantic;

    [self.view addSubview:self.inputbar];
    [self.inputbar resetRecordingUI];

    self.inputBarBottomConstraint = [self.inputbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.inputbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-2],
        [self.inputbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:2],
        self.inputBarBottomConstraint
    ]];
}

- (void)setupBottomFillBlur {
    if (self.bottomFillBlurView) return;

    self.bottomFillBlurView = [PPNavigationController setButtonAsBackroundButtonWithStyle:UIButtonConfigurationCornerStyleFixed configType:PPButtonConfigrationGlass];

    UIButtonConfiguration *cfg = self.bottomFillBlurView.configuration;
    cfg.background.backgroundColor = [UIColor clearColor];
    cfg.baseBackgroundColor = [UIColor clearColor];
    self.bottomFillBlurView.configuration = cfg;

    [self.view insertSubview:self.bottomFillBlurView belowSubview:self.inputbar];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomFillBlurView.topAnchor constraintEqualToAnchor:self.inputbar.topAnchor],
        [self.bottomFillBlurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.bottomFillBlurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.bottomFillBlurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.tableView registerClass:[ChatMessageCell class] forCellReuseIdentifier:@"ChatMessageCell"];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.contentInset = UIEdgeInsetsMake(PPSpaceSM, 0, PPSpaceSM, 0);

    [self.view addSubview:self.tableView];
    if (self.bottomFillBlurView) {
        [self.view bringSubviewToFront:self.bottomFillBlurView];
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
}

#pragma mark - Keyboard

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGFloat safeAreaBottom = self.view.safeAreaInsets.bottom;
    self.inputBarBottomConstraint.constant = -(keyboardFrame.size.height - safeAreaBottom);

    [UIView animateWithDuration:duration delay:0.0 options:(curve << 16) animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self scrollToBottomAnimated:YES];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    self.inputBarBottomConstraint.constant = 0;

    [UIView animateWithDuration:duration delay:0.0 options:(curve << 16) animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.messages.count == 0) return;
    NSIndexPath *bottomIP = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:bottomIP atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}

#pragma mark - Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell" forIndexPath:indexPath];

    ChatMessageModel *msg = self.messages[indexPath.row];
    BOOL isIncoming = ![msg.senderID isEqualToString:[UserManager sharedManager].currentUser.ID];

    PPChatGroupPosition groupPos = PPChatGroupPositionSingle;

    [cell configureWithMessage:msg.text
                          date:msg.timestamp
                    isIncoming:isIncoming
                      maxWidth:MAX_BUBBLE_WIDTH(self.view)
                        status:msg.status
                  messageModel:msg
                 groupPosition:groupPos];

    return cell;
}

#pragma mark - PPChatInputBarViewDelegate

- (void)inputBar:(PPChatInputBarView *)bar didSendText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length == 0) return;

    [self addMessageWithText:trimmedText isIncoming:NO];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self insertNovaReplyForUserText:trimmedText];
    });
}

- (void)addMessageWithText:(NSString *)text isIncoming:(BOOL)isIncoming {
    ChatMessageModel *msg = [[ChatMessageModel alloc] init];
    msg.ID = [[NSUUID UUID] UUIDString];
    msg.text = text;
    msg.timestamp = [NSDate date];
    msg.status = ChatMessageStatusSent;
    msg.messageType = ChatMessageTypeText;
    msg.senderID = isIncoming ? @"nova_bot_id" : [UserManager sharedManager].currentUser.ID;

    [self.messages addObject:msg];

    NSIndexPath *newIP = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[newIP] withRowAnimation:UITableViewRowAnimationBottom];
    [self scrollToBottomAnimated:YES];
}

- (void)inputBar:(PPChatInputBarView *)bar didChangeText:(UITextView *)textView {}
- (void)inputBarDidStartRecording:(PPChatInputBarView *)bar {}
- (void)inputBar:(PPChatInputBarView *)bar didFinishRecordingWithURL:(nullable NSURL *)fileURL duration:(NSTimeInterval)duration locked:(BOOL)locked {}
- (void)inputBarDidCancelRecording:(PPChatInputBarView *)bar {}
- (void)inputBarDidTapAttachImage:(PPChatInputBarView *)bar {}
- (void)inputBarDidTapAttachVideo:(PPChatInputBarView *)bar {}
- (void)inputBar:(PPChatInputBarView *)bar didChangeHeight:(CGFloat)newHeight {}
- (void)inputBarDidToggleRecordingPreview:(PPChatInputBarView *)bar {}
- (void)finishVoiceRecordingAndSend {}
- (void)inputBarDidStopRecordingPreview:(PPChatInputBarView *)bar {}
- (void)recordingBarDidTapPlayFromLocked {}
- (void)recordingBarDidTogglePlayback {}

@end
