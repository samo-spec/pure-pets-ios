//
//  PPOrderSupportComposerViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 7/14/26.
//

#import "PPOrderSupportComposerViewController.h"

@interface PPOrderSupportComposerViewController () <PHPickerViewControllerDelegate>
@property (nonatomic, strong) PPOrder *order;
@property (nonatomic, assign) PPOrderCustomerActionType actionType;
@property (nonatomic, strong) PPOrderManager *orderManager;
@property (nonatomic, copy) dispatch_block_t onComplete;
@property (nonatomic, strong) NSArray<NSDictionary *> *reasonOptions;
@property (nonatomic, strong) NSDictionary *selectedReason;
@property (nonatomic, strong) NSArray<NSDictionary *> *composerItems;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedItemIDs;
@property (nonatomic, strong) NSMutableArray<UIImage *> *selectedImages;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIView *formSurfaceView;
@property (nonatomic, strong) UIStackView *formStackView;
@property (nonatomic, strong) UIView *notesSurfaceView;
@property (nonatomic, strong) UIButton *reasonButton;
@property (nonatomic, strong) UIStackView *itemsStackView;
@property (nonatomic, strong) UITextView *notesTextView;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) UILabel *attachmentsLabel;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIActivityIndicatorView *submitActivityIndicator;
@property (nonatomic, strong) NSLayoutConstraint *scrollViewBottomConstraint;
@property (nonatomic, strong) NSArray<UIView *> *entranceViews;
@property (nonatomic, assign) BOOL didPrepareEntrance;
@property (nonatomic, assign) BOOL didRunEntrance;
@end

@implementation PPOrderSupportComposerViewController

+ (instancetype)controllerWithOrder:(PPOrder *)order
                         actionType:(PPOrderCustomerActionType)actionType
                       orderManager:(PPOrderManager *)orderManager
                         onComplete:(dispatch_block_t)onComplete
{
    PPOrderSupportComposerViewController *vc = [PPOrderSupportComposerViewController new];
    vc.order = order;
    vc.actionType = actionType;
    vc.orderManager = orderManager ?: [PPOrderManager shared];
    vc.onComplete = onComplete;
    return vc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
    self.title = [PPOrderManager displayTitleForActionType:self.actionType];
    [self pp_orderApplyChevronBackButton];
    self.reasonOptions = [self.orderManager reasonOptionsForAction:self.actionType];
    self.selectedItemIDs = [NSMutableSet set];
    self.selectedImages = [NSMutableArray array];
    self.composerItems = PPOrderSupportComposerItems(self.order);
    BOOL isRTL = [Language isRTL];
    NSTextAlignment leadingAlignment = isRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    UISemanticContentAttribute semantic = Language.semanticAttributeForCurrentLanguage;

    self.view.semanticContentAttribute = semantic;

    UIView *ambientWash = [[UIView alloc] initWithFrame:CGRectZero];
    ambientWash.translatesAutoresizingMaskIntoConstraints = NO;
    ambientWash.userInteractionEnabled = NO;
    ambientWash.backgroundColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.035];
    PPApplyContinuousCorners(ambientWash, 999.0);
    [self.view addSubview:ambientWash];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.semanticContentAttribute = semantic;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = PPSpaceLG;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.semanticContentAttribute = semantic;
    [self.scrollView addSubview:self.stackView];

    self.scrollViewBottomConstraint = [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor];
    [NSLayoutConstraint activateConstraints:@[
        [ambientWash.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.72],
        [ambientWash.heightAnchor constraintEqualToAnchor:ambientWash.widthAnchor],
        [ambientWash.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:90.0],
        [ambientWash.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:28.0],

        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        self.scrollViewBottomConstraint,

        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20.0],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20.0],
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:PPSpaceLG],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-(PPSpaceXL + 120.0)],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40.0]
    ]];

    UILabel *intro = [[UILabel alloc] initWithFrame:CGRectZero];
    intro.font = [self pp_composerFont:[GM MidFontWithSize:15] textStyle:UIFontTextStyleSubheadline];
    intro.textColor = UIColor.secondaryLabelColor;
    intro.numberOfLines = 0;
    intro.textAlignment = leadingAlignment;
    intro.semanticContentAttribute = semantic;
    intro.adjustsFontForContentSizeCategory = YES;
    intro.text = [self.orderManager eligibilityForAction:self.actionType
                                                   order:self.order
                                                requests:@[]
                                           referenceDate:[NSDate date]].message;
    intro.accessibilityTraits = UIAccessibilityTraitStaticText;
    [self.stackView addArrangedSubview:intro];

    self.formSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.formSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    PPOrderDetailsApplySurface(self.formSurfaceView, PPCornerCard, YES);
    [self.stackView addArrangedSubview:self.formSurfaceView];

    self.formStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.formStackView.axis = UILayoutConstraintAxisVertical;
    self.formStackView.spacing = PPSpaceMD;
    self.formStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.formStackView.semanticContentAttribute = semantic;
    [self.formSurfaceView addSubview:self.formStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.formStackView.leadingAnchor constraintEqualToAnchor:self.formSurfaceView.leadingAnchor constant:PPSpaceLG],
        [self.formStackView.trailingAnchor constraintEqualToAnchor:self.formSurfaceView.trailingAnchor constant:-PPSpaceLG],
        [self.formStackView.topAnchor constraintEqualToAnchor:self.formSurfaceView.topAnchor constant:PPSpaceLG],
        [self.formStackView.bottomAnchor constraintEqualToAnchor:self.formSurfaceView.bottomAnchor constant:-PPSpaceLG]
    ]];

    self.reasonButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self pp_applyComposerControlStyleToButton:self.reasonButton filled:NO];
    self.reasonButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    self.reasonButton.semanticContentAttribute = semantic;
    self.reasonButton.titleLabel.font = [self pp_composerFont:[GM boldFontWithSize:16] textStyle:UIFontTextStyleBody];
    self.reasonButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.reasonButton.titleLabel.textAlignment = leadingAlignment;
    [self.reasonButton setTitleColor:[GM appPrimaryColor] forState:UIControlStateNormal];
    [self.reasonButton setTitle:kLang(@"order_request_select_reason") forState:UIControlStateNormal];
    self.reasonButton.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    self.reasonButton.accessibilityLabel = kLang(@"order_request_select_reason");
    [self.reasonButton addTarget:self action:@selector(selectReasonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.reasonButton addTarget:self action:@selector(pp_controlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.reasonButton addTarget:self action:@selector(pp_controlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.formStackView addArrangedSubview:self.reasonButton];
    [self.reasonButton.heightAnchor constraintGreaterThanOrEqualToConstant:56.0].active = YES;

    self.itemsStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.itemsStackView.axis = UILayoutConstraintAxisVertical;
    self.itemsStackView.spacing = 10.0;
    self.itemsStackView.semanticContentAttribute = semantic;
    [self.formStackView addArrangedSubview:self.itemsStackView];
    [self rebuildItemsSelection];

    self.notesSurfaceView = [[UIView alloc] initWithFrame:CGRectZero];
    self.notesSurfaceView.translatesAutoresizingMaskIntoConstraints = NO;
    PPOrderDetailsApplySurface(self.notesSurfaceView, PPCornerMedium, NO);
    [self.formStackView addArrangedSubview:self.notesSurfaceView];

    UILabel *notesTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    notesTitle.translatesAutoresizingMaskIntoConstraints = NO;
    notesTitle.font = [self pp_composerFont:[GM boldFontWithSize:13] textStyle:UIFontTextStyleCaption1];
    notesTitle.adjustsFontForContentSizeCategory = YES;
    notesTitle.textColor = UIColor.secondaryLabelColor;
    notesTitle.textAlignment = leadingAlignment;
    notesTitle.semanticContentAttribute = semantic;
    notesTitle.text = kLang(@"order_request_notes_title");
    [self.notesSurfaceView addSubview:notesTitle];

    self.notesTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 0, 140)];
    self.notesTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.notesTextView.font = [self pp_composerFont:[GM MidFontWithSize:16] textStyle:UIFontTextStyleBody];
    self.notesTextView.adjustsFontForContentSizeCategory = YES;
    self.notesTextView.backgroundColor = UIColor.clearColor;
    self.notesTextView.textContainerInset = UIEdgeInsetsMake(6, 0, 0, 0);
    self.notesTextView.textAlignment = leadingAlignment;
    self.notesTextView.semanticContentAttribute = semantic;
    self.notesTextView.text = @"";
    self.notesTextView.accessibilityLabel = kLang(@"order_request_notes_title");
    [self.notesSurfaceView addSubview:self.notesTextView];
    [NSLayoutConstraint activateConstraints:@[
        [notesTitle.leadingAnchor constraintEqualToAnchor:self.notesSurfaceView.leadingAnchor constant:PPSpaceMD],
        [notesTitle.trailingAnchor constraintEqualToAnchor:self.notesSurfaceView.trailingAnchor constant:-PPSpaceMD],
        [notesTitle.topAnchor constraintEqualToAnchor:self.notesSurfaceView.topAnchor constant:PPSpaceMD],
        [self.notesTextView.leadingAnchor constraintEqualToAnchor:self.notesSurfaceView.leadingAnchor constant:PPSpaceMD],
        [self.notesTextView.trailingAnchor constraintEqualToAnchor:self.notesSurfaceView.trailingAnchor constant:-PPSpaceMD],
        [self.notesTextView.topAnchor constraintEqualToAnchor:notesTitle.bottomAnchor constant:4.0],
        [self.notesTextView.bottomAnchor constraintEqualToAnchor:self.notesSurfaceView.bottomAnchor constant:-PPSpaceSM],
        [self.notesTextView.heightAnchor constraintGreaterThanOrEqualToConstant:136.0]
    ]];

    self.addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self pp_applyComposerControlStyleToButton:self.addPhotoButton filled:NO];
    self.addPhotoButton.contentEdgeInsets = UIEdgeInsetsMake(14, 16, 14, 16);
    self.addPhotoButton.titleLabel.font = [self pp_composerFont:[GM boldFontWithSize:16] textStyle:UIFontTextStyleBody];
    self.addPhotoButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.addPhotoButton setTitleColor:[GM appPrimaryColor] forState:UIControlStateNormal];
    [self.addPhotoButton setTitle:kLang(@"order_request_add_photos") forState:UIControlStateNormal];
    self.addPhotoButton.accessibilityLabel = kLang(@"order_request_add_photos");
    [self.addPhotoButton addTarget:self action:@selector(addPhotosTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.addPhotoButton addTarget:self action:@selector(pp_controlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.addPhotoButton addTarget:self action:@selector(pp_controlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.formStackView addArrangedSubview:self.addPhotoButton];
    [self.addPhotoButton.heightAnchor constraintGreaterThanOrEqualToConstant:56.0].active = YES;

    self.attachmentsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.attachmentsLabel.font = [self pp_composerFont:[GM MidFontWithSize:13] textStyle:UIFontTextStyleCaption1];
    self.attachmentsLabel.adjustsFontForContentSizeCategory = YES;
    self.attachmentsLabel.textColor = UIColor.secondaryLabelColor;
    self.attachmentsLabel.numberOfLines = 0;
    self.attachmentsLabel.textAlignment = leadingAlignment;
    self.attachmentsLabel.semanticContentAttribute = semantic;
    [self.formStackView addArrangedSubview:self.attachmentsLabel];
    [self refreshAttachmentLabel];

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self pp_applyComposerControlStyleToButton:self.submitButton filled:YES];
    [self.submitButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [self pp_composerFont:[GM boldFontWithSize:17] textStyle:UIFontTextStyleHeadline];
    self.submitButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.submitButton setTitle:kLang(@"order_request_submit") forState:UIControlStateNormal];
    self.submitButton.accessibilityLabel = kLang(@"order_request_submit");
    [self.submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.submitButton addTarget:self action:@selector(pp_controlTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.submitButton addTarget:self action:@selector(pp_controlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.stackView addArrangedSubview:self.submitButton];
    [self.submitButton.heightAnchor constraintGreaterThanOrEqualToConstant:58.0].active = YES;

    if (@available(iOS 13.0, *)) {
        self.submitActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        self.submitActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    }
    self.submitActivityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.submitActivityIndicator.hidesWhenStopped = YES;
    self.submitActivityIndicator.color = UIColor.whiteColor;
    [self.submitButton addSubview:self.submitActivityIndicator];
    [NSLayoutConstraint activateConstraints:@[
        [self.submitActivityIndicator.centerYAnchor constraintEqualToAnchor:self.submitButton.centerYAnchor],
        [self.submitActivityIndicator.trailingAnchor constraintEqualToAnchor:self.submitButton.trailingAnchor constant:-PPSpaceLG]
    ]];

    self.entranceViews = @[intro, self.formSurfaceView, self.submitButton];
    [self pp_prepareEntranceState];

    UITapGestureRecognizer *dismissKeyboardTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pp_dismissKeyboard)];
    dismissKeyboardTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:dismissKeyboardTap];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_prepareEntranceState];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self pp_runEntranceIfNeeded];
}

- (UIFont *)pp_composerFont:(UIFont *)font textStyle:(UIFontTextStyle)textStyle
{
    if (!font) return [UIFont preferredFontForTextStyle:textStyle];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics metricsForTextStyle:textStyle] scaledFontForFont:font];
    }
    return font;
}

- (void)pp_applyComposerControlStyleToButton:(UIButton *)button filled:(BOOL)filled
{
    if (!button) return;
    button.adjustsImageWhenHighlighted = NO;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    PPApplyContinuousCorners(button, PPCornerMedium);
    button.layer.borderWidth = filled ? 0.0 : 0.75;
    if (filled) {
        button.backgroundColor = [GM appPrimaryColor];
        button.layer.shadowColor = [GM appPrimaryColor].CGColor;
        button.layer.shadowOpacity = 0.20;
        button.layer.shadowRadius = 18.0;
        button.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    } else {
        button.backgroundColor = PPOrderDetailsSubsurfaceColor();
        [button pp_setBorderColor:[[UIColor labelColor] colorWithAlphaComponent:0.060]];
        button.layer.shadowOpacity = 0.0;
    }
}

- (void)pp_prepareEntranceState
{
    if (self.didRunEntrance || self.didPrepareEntrance) return;
    self.didPrepareEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in self.entranceViews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }
    for (UIView *view in self.entranceViews) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
    }
    self.formSurfaceView.transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(0.985, 0.985), 0.0, 12.0);
}

- (void)pp_runEntranceIfNeeded
{
    if (self.didRunEntrance) return;
    self.didRunEntrance = YES;
    if (UIAccessibilityIsReduceMotionEnabled()) {
        for (UIView *view in self.entranceViews) {
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }
        return;
    }
    [self.view layoutIfNeeded];
    [self.entranceViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        (void)stop;
        NSTimeInterval delay = 0.04 * idx;
        [UIView animateWithDuration:0.42
                              delay:delay
             usingSpringWithDamping:0.90
              initialSpringVelocity:0.28
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

- (void)pp_controlTouchDown:(UIControl *)control
{
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.08
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        control.transform = CGAffineTransformMakeScale(0.985, 0.985);
    } completion:nil];
}

- (void)pp_controlTouchUp:(UIControl *)control
{
    if (UIAccessibilityIsReduceMotionEnabled()) {
        control.transform = CGAffineTransformIdentity;
        return;
    }
    [UIView animateWithDuration:0.18
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.35
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        control.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)pp_dismissKeyboard
{
    [self.view endEditing:YES];
}

- (void)pp_keyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect convertedFrame = [self.view convertRect:keyboardFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(convertedFrame));
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = (UIViewAnimationOptions)([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
    self.scrollViewBottomConstraint.constant = -overlap;
    UIEdgeInsets inset = self.scrollView.contentInset;
    inset.bottom = overlap > 0.0 ? PPSpaceXL : 0.0;
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:options | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)pp_keyboardWillHide:(NSNotification *)notification
{
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.scrollViewBottomConstraint.constant = 0.0;
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)showMessage:(NSString *)message title:(NSString *)title
{
    NSString *safeMessage = message.length > 0
        ? [PPFirebaseSessionBridge publicMessageForText:message fallbackKey:@"pp_order_support_submit_failed"]
        : message;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:safeMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"OK") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)selectReasonTapped
{
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:kLang(@"order_request_select_reason")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    for (NSDictionary *reason in self.reasonOptions) {
        [sheet addAction:[UIAlertAction actionWithTitle:reason[@"title"]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            self.selectedReason = reason;
            [self.reasonButton setTitle:reason[@"title"] forState:UIControlStateNormal];
            self.reasonButton.accessibilityValue = reason[@"title"];
            UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
            [feedback selectionChanged];
            [self rebuildItemsSelection];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:kLang(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.reasonButton;
        sheet.popoverPresentationController.sourceRect = self.reasonButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)rebuildItemsSelection
{
    for (UIView *view in self.itemsStackView.arrangedSubviews) {
        [self.itemsStackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    BOOL requiresItems = self.selectedReason ? [self.selectedReason[@"requiresItemSelection"] boolValue] : NO;
    self.itemsStackView.hidden = !requiresItems || self.composerItems.count == 0;
    if (self.itemsStackView.hidden) return;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.font = [self pp_composerFont:[GM boldFontWithSize:15] textStyle:UIFontTextStyleSubheadline];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = UIColor.labelColor;
    title.textAlignment = Language.alignmentForCurrentLanguage;
    title.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
    title.text = kLang(@"order_request_items_title");
    [self.itemsStackView addArrangedSubview:title];

    for (NSInteger index = 0; index < (NSInteger)self.composerItems.count; index++) {
        NSDictionary *item = self.composerItems[index];
        NSString *itemID = item[@"id"] ?: @"";
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = index;
        [self pp_applyComposerControlStyleToButton:button filled:NO];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage;
        button.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
        button.titleLabel.font = [self pp_composerFont:[GM MidFontWithSize:15] textStyle:UIFontTextStyleBody];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.titleLabel.numberOfLines = 0;
        button.titleLabel.textAlignment = Language.alignmentForCurrentLanguage;
        BOOL selected = [self.selectedItemIDs containsObject:itemID];
        NSString *titleText = [NSString stringWithFormat:@"%@ ×%@%@", item[@"name"] ?: itemID, item[@"quantity"] ?: @1, selected ? @"  ✓" : @""];
        [button setTitle:titleText forState:UIControlStateNormal];
        [button setTitleColor:selected ? UIColor.whiteColor : UIColor.labelColor forState:UIControlStateNormal];
        button.accessibilityLabel = titleText;
        button.accessibilityTraits = selected ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
        if (selected) {
            button.backgroundColor = [GM appPrimaryColor];
            [button pp_setBorderColor:[[GM appPrimaryColor] colorWithAlphaComponent:0.82]];
            button.layer.shadowColor = [GM appPrimaryColor].CGColor;
            button.layer.shadowOpacity = 0.16;
            button.layer.shadowRadius = 14.0;
            button.layer.shadowOffset = CGSizeMake(0.0, 8.0);
        }
        [button addTarget:self action:@selector(toggleItemSelection:) forControlEvents:UIControlEventTouchUpInside];
        [button addTarget:self action:@selector(pp_controlTouchDown:) forControlEvents:UIControlEventTouchDown];
        [button addTarget:self action:@selector(pp_controlTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.itemsStackView addArrangedSubview:button];
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:52.0].active = YES;
    }
}

- (void)toggleItemSelection:(UIButton *)sender
{
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.composerItems.count) return;
    NSDictionary *item = self.composerItems[index];
    NSString *itemID = item[@"id"] ?: @"";
    if (itemID.length == 0) return;
    if ([self.selectedItemIDs containsObject:itemID]) {
        [self.selectedItemIDs removeObject:itemID];
    } else {
        [self.selectedItemIDs addObject:itemID];
    }
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
    [self rebuildItemsSelection];
}

- (void)addPhotosTapped
{
    if (self.selectedImages.count >= kOrderSupportComposerMaxAttachments) {
        [self showMessage:kLang(@"order_support_too_many_photos")
                    title:kLang(@"order_request_attachments_title")];
        return;
    }

    if (@available(iOS 14.0, *)) {
        PHPickerConfiguration *config = [PHPickerConfiguration new];
        config.selectionLimit = MAX(1, kOrderSupportComposerMaxAttachments - (NSInteger)self.selectedImages.count);
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [self showMessage:kLang(@"order_request_photos_unavailable")
                    title:kLang(@"order_request_attachments_title")];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0))
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<UIImage *> *loadedImages = [NSMutableArray array];
    for (PHPickerResult *result in results) {
        if (![result.itemProvider canLoadObjectOfClass:UIImage.class]) continue;
        dispatch_group_enter(group);
        [result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage * _Nullable image, NSError * _Nullable __unused error) {
            if ([image isKindOfClass:UIImage.class]) {
                @synchronized (loadedImages) {
                    [loadedImages addObject:image];
                }
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        for (UIImage *image in loadedImages) {
            if (self.selectedImages.count >= kOrderSupportComposerMaxAttachments) break;
            [self.selectedImages addObject:image];
        }
        [self refreshAttachmentLabel];
    });
}

- (void)refreshAttachmentLabel
{
    if (self.selectedImages.count == 0) {
        self.attachmentsLabel.text = kLang(@"order_request_photos_optional");
        self.attachmentsLabel.accessibilityLabel = kLang(@"order_request_photos_optional");
    } else {
        self.attachmentsLabel.text = [NSString stringWithFormat:kLang(@"order_request_photos_count"), (long)self.selectedImages.count];
        self.attachmentsLabel.accessibilityLabel = self.attachmentsLabel.text;
    }
}

- (void)setSubmitLoading:(BOOL)loading
{
    self.submitButton.enabled = !loading;
    self.reasonButton.enabled = !loading;
    self.addPhotoButton.enabled = !loading;
    self.notesTextView.editable = !loading;
    [self.submitButton setTitle:(loading ? kLang(@"order_request_submitting") : kLang(@"order_request_submit")) forState:UIControlStateNormal];
    self.submitButton.alpha = loading ? 0.86 : 1.0;
    if (loading) {
        [self.submitActivityIndicator startAnimating];
    } else {
        [self.submitActivityIndicator stopAnimating];
    }
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, loading ? kLang(@"order_request_submitting") : kLang(@"order_request_submit"));
}

- (void)submitTapped
{
    if (!self.selectedReason && self.reasonOptions.count > 0) {
        [self showMessage:kLang(@"order_request_select_reason")
                    title:self.title];
        return;
    }
    if ([self.selectedReason[@"requiresItemSelection"] boolValue] && self.selectedItemIDs.count == 0) {
        [self showMessage:kLang(@"order_request_select_items_error")
                    title:self.title];
        return;
    }

    [self setSubmitLoading:YES];
    NSString *draftID = NSUUID.UUID.UUIDString;
    __weak typeof(self) weakSelf = self;

    void (^submitDraft)(NSArray<PPOrderSupportAttachment *> *) = ^(NSArray<PPOrderSupportAttachment *> *attachments) {
        PPOrderSupportDraft *draft = [PPOrderSupportDraft new];
        draft.actionType = self.actionType;
        draft.reasonCode = self.selectedReason ? (self.selectedReason[@"code"] ?: @"other") : @"other";
        draft.reasonTitle = self.selectedReason ? (self.selectedReason[@"title"] ?: @"") : @"";
        draft.issueCategory = self.selectedReason ? (self.selectedReason[@"code"] ?: @"other") : @"other";
        draft.subject = [PPOrderManager displayTitleForActionType:self.actionType];
        draft.notes = self.notesTextView.text ?: @"";
        draft.selectedItemIDs = self.selectedItemIDs.allObjects ?: @[];
        draft.attachments = attachments ?: @[];

        [self.orderManager submitSupportDraft:draft
                                     forOrder:self.order
                                   completion:^(PPOrderSupportRequest * _Nullable request, BOOL __unused deduplicated, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setSubmitLoading:NO];
                if (error) {
                    [strongSelf showMessage:error.localizedDescription ?: kLang(@"SomethingWentWrong")
                                    title:strongSelf.title];
                    return;
                }
                if (strongSelf.onComplete) strongSelf.onComplete();
                if (request) {
                    UINotificationFeedbackGenerator *feedback = [UINotificationFeedbackGenerator new];
                    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
                    UIViewController *detailsVC = [PPOrderSupportRequestDetailsViewController controllerWithOrder:strongSelf.order
                                                                                                   orderManager:strongSelf.orderManager
                                                                                                        request:request];
                    if (strongSelf.navigationController) {
                        NSMutableArray *stack = strongSelf.navigationController.viewControllers.mutableCopy;
                        if (stack.count > 0) {
                            [stack removeLastObject];
                        }
                        [stack addObject:detailsVC];
                        [strongSelf.navigationController setViewControllers:stack animated:YES];
                    }
                } else {
                    [strongSelf.navigationController popViewControllerAnimated:YES];
                }
            });
        }];
    };

    if (self.selectedImages.count == 0) {
        submitDraft(@[]);
        return;
    }

    [self.orderManager uploadEvidenceImages:self.selectedImages
                                   forOrder:self.order
                            draftIdentifier:draftID
                                   progress:nil
                                 completion:^(NSArray<PPOrderSupportAttachment *> *attachments, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                [strongSelf setSubmitLoading:NO];
                [strongSelf showMessage:error.localizedDescription ?: kLang(@"order_support_upload_failed")
                                title:strongSelf.title];
                return;
            }
            submitDraft(attachments ?: @[]);
        });
    }];
}

@end
