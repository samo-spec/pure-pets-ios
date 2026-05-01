//
//  PPStoryPlayerViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 2/22/26.
//

#import "PPStory.h"
#import "PPStoryPlayerViewController.h"
#import "PPStoriesManager.h"
#import "PPImageLoaderManager.h"
#import "Language.h"
#import "GM.h"
#import "PPModernAvatarRenderer.h"
#import "ImagePicker.h"
#import <FirebaseAuth/FirebaseAuth.h>
#import <AVFoundation/AVFoundation.h>

static NSString * const PPStoryProgressPulseAnimationKey = @"pp.story.progress.pulse";
static NSString * const PPStoryProgressSlideAnimationKey = @"pp.story.progress.slide";
static NSString * const PPStoryCaptionEntranceAnimationKey = @"pp.story.caption.entrance";
static NSString * const PPStoryContentTransitionAnimationKey = @"pp.story.content.transition";
static void *PPStoryPlayerItemStatusContext = &PPStoryPlayerItemStatusContext;

static CAMediaTimingFunction *PPPremiumEaseOut(void)
{
    return [CAMediaTimingFunction functionWithControlPoints:0.4f:0.0f:0.2f:1.0f];
}

static CAMediaTimingFunction *PPPremiumEaseInOut(void)
{
    return [CAMediaTimingFunction functionWithControlPoints:0.4f:0.0f:0.2f:1.0f];
}

static CAMediaTimingFunction *PPPremiumEaseIn(void)
{
    return [CAMediaTimingFunction functionWithControlPoints:0.4f:0.0f:0.6f:1.0f];
}

@interface PPStoryEditViewController : UIViewController <UITextViewDelegate, TOCropViewControllerDelegate, UIAdaptivePresentationControllerDelegate>
@property (nonatomic, copy) void (^onSave)(NSString *caption, UIImage * _Nullable newImage, PPStoryEditViewController *editor);
@property (nonatomic, copy) void (^onCancel)(void);
- (instancetype)initWithStoryItem:(PPStoryItem *)item;
- (void)pp_setSaving:(BOOL)saving;
- (void)pp_showError:(NSString *)message;
- (void)pp_markFinished;
@end

@interface PPStoryEditViewController ()
@property (nonatomic, strong) PPStoryItem *item;
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UITextView *captionTextView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *changeMediaButton;
@property (nonatomic, strong) ImagePicker *imagePicker;
@property (nonatomic, strong, nullable) UIImage *selectedImage;
@property (nonatomic, assign) BOOL isSaving;
@property (nonatomic, assign) BOOL didFinish;
@end

@implementation PPStoryEditViewController

- (instancetype)initWithStoryItem:(PPStoryItem *)item
{
    self = [super init];
    if (self) {
        _item = item;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = AppBackgroundClr ?: UIColor.systemBackgroundColor;
    self.title = kLang(@"story_edit_title");
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(pp_cancelTapped)];
    self.navigationItem.leftBarButtonItem.tintColor = UIColor.labelColor;

    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(0, 0, 92.0, 36.0);
    saveButton.layer.cornerRadius = 18.0;
    saveButton.backgroundColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    saveButton.titleLabel.font = [GM boldFontWithSize:14.0];
    [saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [saveButton setImage:[UIImage imageNamed:@""] forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(pp_saveTapped) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:saveButton];
    self.saveButton = saveButton;

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];

    UIView *previewCard = [[UIView alloc] init];
    previewCard.translatesAutoresizingMaskIntoConstraints = NO;
    previewCard.backgroundColor = UIColor.blackColor;
    previewCard.layer.cornerRadius = 22.0;
    previewCard.clipsToBounds = YES;
    [contentView addSubview:previewCard];

    UIImageView *preview = [[UIImageView alloc] init];
    preview.translatesAutoresizingMaskIntoConstraints = NO;
    preview.contentMode = UIViewContentModeScaleAspectFill;
    preview.clipsToBounds = YES;
    preview.backgroundColor = UIColor.blackColor;
    [previewCard addSubview:preview];
    self.previewImageView = preview;

    UIButton *changeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    changeButton.translatesAutoresizingMaskIntoConstraints = NO;
    changeButton.layer.cornerRadius = 18.0;
    changeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    changeButton.tintColor = UIColor.whiteColor;
    changeButton.titleLabel.font = [GM MidFontWithSize:13.0];
    [changeButton setImage:[UIImage systemImageNamed:@"photo.on.rectangle.angled"] forState:UIControlStateNormal];
    [changeButton setTitle:kLang(@"story_edit_change_media") forState:UIControlStateNormal];
    [changeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    changeButton.imageEdgeInsets = UIEdgeInsetsMake(0, -4, 0, 4);
    [changeButton addTarget:self action:@selector(pp_changeMediaTapped) forControlEvents:UIControlEventTouchUpInside];
    [previewCard addSubview:changeButton];
    self.changeMediaButton = changeButton;

    UIView *captionCard = [[UIView alloc] init];
    captionCard.translatesAutoresizingMaskIntoConstraints = NO;
    captionCard.backgroundColor = [UIColor secondarySystemBackgroundColor];
    captionCard.layer.cornerRadius = 18.0;
    captionCard.layer.borderWidth = 1.0;
    captionCard.layer.borderColor = [[UIColor separatorColor] colorWithAlphaComponent:0.35].CGColor;
    [contentView addSubview:captionCard];

    UITextView *captionTextView = [[UITextView alloc] init];
    captionTextView.translatesAutoresizingMaskIntoConstraints = NO;
    captionTextView.backgroundColor = UIColor.clearColor;
    captionTextView.textColor = UIColor.labelColor;
    captionTextView.tintColor = AppPrimaryClr ?: UIColor.systemPinkColor;
    captionTextView.font = [GM MidFontWithSize:15.0];
    captionTextView.textContainerInset = UIEdgeInsetsMake(14, 12, 14, 12);
    captionTextView.delegate = self;
    captionTextView.textAlignment = [Language alignmentForCurrentLanguage];
    captionTextView.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    captionTextView.text = self.item.caption ?: @"";
    [captionCard addSubview:captionTextView];
    self.captionTextView = captionTextView;

    UILabel *placeholder = [[UILabel alloc] init];
    placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    placeholder.font = [GM MidFontWithSize:15.0];
    placeholder.textColor = UIColor.placeholderTextColor;
    placeholder.text = kLang(@"story_edit_caption_placeholder");
    placeholder.textAlignment = [Language alignmentForCurrentLanguage];
    placeholder.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [captionCard addSubview:placeholder];
    self.placeholderLabel = placeholder;

    UILabel *errorLabel = [[UILabel alloc] init];
    errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    errorLabel.font = [GM MidFontWithSize:13.0];
    errorLabel.textColor = UIColor.systemRedColor;
    errorLabel.numberOfLines = 2;
    errorLabel.hidden = YES;
    errorLabel.textAlignment = [Language alignmentForCurrentLanguage];
    errorLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [contentView addSubview:errorLabel];
    self.errorLabel = errorLabel;

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],

        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24.0],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],

        [previewCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [previewCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],
        [previewCard.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:18.0],
        [previewCard.heightAnchor constraintEqualToAnchor:previewCard.widthAnchor multiplier:1.16],

        [preview.leadingAnchor constraintEqualToAnchor:previewCard.leadingAnchor],
        [preview.trailingAnchor constraintEqualToAnchor:previewCard.trailingAnchor],
        [preview.topAnchor constraintEqualToAnchor:previewCard.topAnchor],
        [preview.bottomAnchor constraintEqualToAnchor:previewCard.bottomAnchor],

        [changeButton.trailingAnchor constraintEqualToAnchor:previewCard.trailingAnchor constant:-14.0],
        [changeButton.bottomAnchor constraintEqualToAnchor:previewCard.bottomAnchor constant:-14.0],
        [changeButton.heightAnchor constraintEqualToConstant:36.0],
        [changeButton.widthAnchor constraintGreaterThanOrEqualToConstant:146.0],

        [captionCard.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
        [captionCard.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],
        [captionCard.topAnchor constraintEqualToAnchor:previewCard.bottomAnchor constant:18.0],
        [captionCard.heightAnchor constraintEqualToConstant:128.0],

        [captionTextView.leadingAnchor constraintEqualToAnchor:captionCard.leadingAnchor],
        [captionTextView.trailingAnchor constraintEqualToAnchor:captionCard.trailingAnchor],
        [captionTextView.topAnchor constraintEqualToAnchor:captionCard.topAnchor],
        [captionTextView.bottomAnchor constraintEqualToAnchor:captionCard.bottomAnchor],

        [placeholder.leadingAnchor constraintEqualToAnchor:captionCard.leadingAnchor constant:17.0],
        [placeholder.trailingAnchor constraintEqualToAnchor:captionCard.trailingAnchor constant:-17.0],
        [placeholder.topAnchor constraintEqualToAnchor:captionCard.topAnchor constant:21.0],

        [errorLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
        [errorLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
        [errorLabel.topAnchor constraintEqualToAnchor:captionCard.bottomAnchor constant:10.0],
        [errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor]
    ]];

    [self pp_loadInitialPreview];
    [self pp_updatePlaceholderVisibility];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.navigationController.presentationController.delegate = self;
}

- (void)pp_loadInitialPreview
{
    UIImage *placeholder = [UIImage imageNamed:@"placeholder"] ?: [UIImage systemImageNamed:@"photo"];
    if (self.item.isVideo) {
        self.previewImageView.contentMode = UIViewContentModeCenter;
        self.previewImageView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.78];
        self.previewImageView.image = [UIImage systemImageNamed:@"play.rectangle.fill"] ?: placeholder;
        return;
    }

    [[PPImageLoaderManager shared] setImageOnImageView:self.previewImageView
                                                    url:self.item.mediaURL.absoluteString
                                            placeholder:placeholder
                                        transitionStyle:PPImageTransitionStyleCrossDissolve
                                             complation:nil];
}

- (void)pp_cancelTapped
{
    [self pp_markFinished];
    __weak typeof(self) weakSelf = self;
    [self dismissViewControllerAnimated:YES completion:^{
        if (weakSelf.onCancel) weakSelf.onCancel();
    }];
}

- (void)pp_saveTapped
{
    if (self.isSaving || !self.onSave) {
        return;
    }
    self.errorLabel.hidden = YES;
    self.onSave(self.captionTextView.text ?: @"", self.selectedImage, self);
}

- (void)pp_changeMediaTapped
{
    if (self.isSaving) {
        return;
    }
    self.imagePicker = [[ImagePicker alloc] initWithPresentingViewController:self];
    __weak typeof(self) weakSelf = self;
    [self.imagePicker showImageSourceSelection:^(UIImage * _Nullable image, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || error || ![image isKindOfClass:UIImage.class]) {
            return;
        }
        [self pp_presentStoryCropperWithImage:image];
    }];
}

- (void)pp_presentStoryCropperWithImage:(UIImage *)image
{
    TOCropViewController *cropVC = [[TOCropViewController alloc] initWithCroppingStyle:TOCropViewCroppingStyleDefault
                                                                                 image:image];
    cropVC.delegate = self;
    cropVC.title = kLang(@"story_edit_crop_title");
    cropVC.doneButtonTitle = kLang(@"Done");
    cropVC.cancelButtonTitle = kLang(@"Cancel");
    cropVC.resetButtonHidden = YES;
    cropVC.aspectRatioPickerButtonHidden = NO;
    cropVC.aspectRatioPreset = CGSizeMake(9.0, 16.0);
    cropVC.aspectRatioLockEnabled = NO;
    cropVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:cropVC animated:YES completion:nil];
}

- (void)cropViewController:(TOCropViewController *)cropViewController
            didCropToImage:(UIImage *)image
                  withRect:(CGRect)cropRect
                     angle:(NSInteger)angle
{
    (void)cropRect;
    (void)angle;
    self.selectedImage = image;
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFill;
    [UIView transitionWithView:self.previewImageView
                      duration:0.22
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        self.previewImageView.image = image;
    } completion:nil];
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)cropViewController:(TOCropViewController *)cropViewController
        didFinishCancelled:(BOOL)cancelled
{
    (void)cancelled;
    [cropViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)pp_setSaving:(BOOL)saving
{
    self.isSaving = saving;
    self.captionTextView.editable = !saving;
    self.changeMediaButton.enabled = !saving;
    self.saveButton.enabled = !saving;
    self.saveButton.alpha = saving ? 0.72 : 1.0;
    [self.saveButton setTitle:kLang(saving ? @"story_edit_saving" : @"story_edit_save")
                     forState:UIControlStateNormal];
}

- (void)pp_showError:(NSString *)message
{
    self.errorLabel.text = message.length ? message : kLang(@"story_edit_failed");
    self.errorLabel.hidden = NO;
}

- (void)pp_markFinished
{
    self.didFinish = YES;
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
    (void)presentationController;
    if (!self.didFinish && self.onCancel) {
        self.onCancel();
    }
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController
{
    (void)presentationController;
    return !self.isSaving;
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self pp_updatePlaceholderVisibility];
}

- (BOOL)textView:(UITextView *)textView
shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)text
{
    NSString *current = textView.text ?: @"";
    NSString *next = [current stringByReplacingCharactersInRange:range withString:text ?: @""];
    return next.length <= 500;
}

- (void)pp_updatePlaceholderVisibility
{
    NSString *caption = [self.captionTextView.text stringByTrimmingCharactersInSet:
                         NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.placeholderLabel.hidden = caption.length > 0;
}

@end

@interface PPStoryPlayerViewController () <UIGestureRecognizerDelegate>

- (void)loadStory;
- (void)showItem;
- (void)nextItem;
- (void)nextStory;
- (void)pp_stopAllProgressAnimations;
- (void)pp_stopCurrentPlaybackAndPreserveProgress:(BOOL)preserve;
- (void)pp_dismissViewerAnimated:(BOOL)animated;
- (void)pp_updateMuteButtonAppearance;
- (void)pp_dismissButtonTapped;
- (void)pp_muteButtonTapped;
- (void)pp_editButtonTapped;
- (void)handleTap:(UITapGestureRecognizer *)tap;
- (void)pp_handleDismissPan:(UIPanGestureRecognizer *)pan;
- (void)showImageItem:(PPStoryItem *)item;
- (void)playVideoItem:(PPStoryItem *)item;
- (void)pp_animateProgressContainerEntrance;
- (void)pp_startPulseAnimationForProgressView:(UIProgressView *)progressView;
- (void)pp_startSlideAnimationForProgressView:(UIProgressView *)progressView;
- (void)pp_updateUserInfoForCurrentStory;
- (void)pp_updateControlsForCurrentItem:(PPStoryItem *)item;
- (NSTimeInterval)pp_safeDuration:(NSTimeInterval)duration fallback:(NSTimeInterval)fallback;
- (NSString *)pp_itemKeyForCurrentPositionWithItem:(PPStoryItem *)item;
- (void)pp_handleImageTick:(CADisplayLink *)displayLink;
- (void)pp_configureProgressBarsForCurrentStory;
- (PPStory * _Nullable)pp_currentStory;
- (PPStoryItem * _Nullable)pp_currentStoryItem;
- (BOOL)pp_canEditCurrentStory;
- (void)pp_replaceCurrentItemWithItem:(PPStoryItem *)updatedItem;
- (void)pp_commitStoryEditWithCaption:(NSString *)caption newImage:(UIImage * _Nullable)newImage editor:(id)editor;

@property (nonatomic, strong) NSArray<PPStory *> *stories;
@property (nonatomic, assign) NSInteger currentStoryIndex;
@property (nonatomic, assign) NSInteger currentItemIndex;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) NSMutableArray<UIProgressView *> *progressBars;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIButton *editButton;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UIPanGestureRecognizer *dismissPanGesture;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSValue *> *videoResumeTimesByItemKey;
@property (nonatomic, strong, nullable) AVPlayerItem *currentPlayerItem;
@property (nonatomic, strong, nullable) NSString *currentVideoItemKey;
@property (nonatomic, assign) NSTimeInterval currentVideoFallbackDuration;
@property (nonatomic, assign) BOOL hasStartedCurrentVideoPlayback;
@property (nonatomic, assign) BOOL isPlayerMuted;
@property (nonatomic, assign) NSInteger videoLoadToken;
@property (nonatomic, assign) BOOL isInteractiveDismissInProgress;
@property (nonatomic, assign) BOOL isPausedByLongPress;

@property (nonatomic, strong) id playerTimeObserver;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval imageStartTime;
@property (nonatomic, assign) NSTimeInterval imageDuration;

@property (nonatomic, strong) UIImageView *userAvatarView;
@property (nonatomic, strong) UILabel *userNameHeaderLabel;
@property (nonatomic, strong) UILabel *storyTimeLabel;
@property (nonatomic, assign) NSTimeInterval pausedImageElapsed;
@property (nonatomic, assign) BOOL isCommittingStoryEdit;
@end

@implementation PPStoryPlayerViewController

- (instancetype)initWithStories:(NSArray<PPStory *> *)stories startIndex:(NSInteger)index {
    self = [super init];
    if (self) {
        _stories = stories ?: @[];
        _currentStoryIndex = MAX(index, 0);
        _currentItemIndex = 0;
        _progressBars = [NSMutableArray array];
        _videoResumeTimesByItemKey = [NSMutableDictionary dictionary];
        _isPlayerMuted = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.backgroundColor = UIColor.blackColor;
    [self.view addSubview:_imageView];

    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
    _playerLayer.frame = self.view.bounds;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:_playerLayer];

    _progressContainer = [[UIView alloc] init];
    _progressContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_progressContainer];
    [NSLayoutConstraint activateConstraints:@[
        [_progressContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [_progressContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [_progressContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [_progressContainer.heightAnchor constraintEqualToConstant:4.0]
    ]];

    [self pp_setupControls];
    [self pp_setupGestures];
    [self loadStory];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.playerLayer.frame = self.view.bounds;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pp_stopAllProgressAnimations];
    [self.timer invalidate];
    self.timer = nil;
    [self.player pause];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (self.isBeingDismissed || self.navigationController.isBeingDismissed) {
        [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
    }
}

- (void)dealloc
{
    [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
}

#pragma mark - Setup

- (void)pp_setupControls
{
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.translatesAutoresizingMaskIntoConstraints = NO;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 16.0;
    avatar.layer.borderWidth = 1.5;
    [avatar pp_setBorderColor:[UIColor colorWithWhite:1.0 alpha:0.85]];
    avatar.image = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    avatar.tintColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    [self.view addSubview:avatar];
    self.userAvatarView = avatar;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    nameLabel.textColor = UIColor.whiteColor;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    nameLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:nameLabel];
    self.userNameHeaderLabel = nameLabel;

    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    timeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    timeLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:timeLabel];
    self.storyTimeLabel = timeLabel;

    UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    dismissButton.tintColor = UIColor.whiteColor;
    dismissButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
    dismissButton.layer.cornerRadius = 18.0;
    [dismissButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    [dismissButton addTarget:self action:@selector(pp_dismissButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:dismissButton];
    self.dismissButton = dismissButton;

    UIButton *muteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    muteButton.translatesAutoresizingMaskIntoConstraints = NO;
    muteButton.tintColor = UIColor.whiteColor;
    muteButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
    muteButton.layer.cornerRadius = 18.0;
    [muteButton addTarget:self action:@selector(pp_muteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    muteButton.hidden = YES;
    [self.view addSubview:muteButton];
    self.muteButton = muteButton;
    [self pp_updateMuteButtonAppearance];

    UIButton *editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    editButton.translatesAutoresizingMaskIntoConstraints = NO;
    editButton.tintColor = UIColor.whiteColor;
    editButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
    editButton.layer.cornerRadius = 18.0;
    [editButton setImage:[UIImage systemImageNamed:@"pencil"] forState:UIControlStateNormal];
    [editButton addTarget:self action:@selector(pp_editButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    editButton.hidden = YES;
    [self.view addSubview:editButton];
    self.editButton = editButton;

    UILabel *captionLabel = [[UILabel alloc] init];
    captionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    captionLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    captionLabel.textColor = UIColor.whiteColor;
    captionLabel.numberOfLines = 3;
    captionLabel.textAlignment = NSTextAlignmentCenter;
    captionLabel.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    captionLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    captionLabel.hidden = YES;
    captionLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.view addSubview:captionLabel];
    self.captionLabel = captionLabel;

    [NSLayoutConstraint activateConstraints:@[
        [avatar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [avatar.topAnchor constraintEqualToAnchor:self.progressContainer.bottomAnchor constant:10.0],
        [avatar.widthAnchor constraintEqualToConstant:32.0],
        [avatar.heightAnchor constraintEqualToConstant:32.0],

        [nameLabel.leadingAnchor constraintEqualToAnchor:avatar.trailingAnchor constant:8.0],
        [nameLabel.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:muteButton.leadingAnchor constant:-8.0],

        [timeLabel.leadingAnchor constraintEqualToAnchor:nameLabel.trailingAnchor constant:6.0],
        [timeLabel.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],

        [dismissButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [dismissButton.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [dismissButton.widthAnchor constraintEqualToConstant:36.0],
        [dismissButton.heightAnchor constraintEqualToConstant:36.0],

        [editButton.trailingAnchor constraintEqualToAnchor:dismissButton.leadingAnchor constant:-8.0],
        [editButton.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [editButton.widthAnchor constraintEqualToConstant:36.0],
        [editButton.heightAnchor constraintEqualToConstant:36.0],

        [muteButton.trailingAnchor constraintEqualToAnchor:editButton.leadingAnchor constant:-8.0],
        [muteButton.centerYAnchor constraintEqualToAnchor:avatar.centerYAnchor],
        [muteButton.widthAnchor constraintEqualToConstant:36.0],
        [muteButton.heightAnchor constraintEqualToConstant:36.0],

        [captionLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:28.0],
        [captionLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-28.0],
        [captionLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-26.0]
    ]];

    [nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                              forAxis:UILayoutConstraintAxisHorizontal];
    [timeLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                forAxis:UILayoutConstraintAxisHorizontal];
}

- (void)pp_setupGestures
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                           action:@selector(handleTap:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleLongPress:)];
    longPress.minimumPressDuration = 0.25;
    longPress.cancelsTouchesInView = NO;
    longPress.delegate = self;
    [self.view addGestureRecognizer:longPress];

    self.dismissPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pp_handleDismissPan:)];
    self.dismissPanGesture.delegate = self;
    self.dismissPanGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.dismissPanGesture];
}

#pragma mark - Story Flow

- (void)loadStory {
    [self.timer invalidate];
    self.timer = nil;
    [self pp_stopAllProgressAnimations];
    [self pp_stopCurrentPlaybackAndPreserveProgress:NO];

    [self.progressBars makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.progressBars removeAllObjects];

    if (self.currentStoryIndex >= self.stories.count) {
        [self pp_dismissViewerAnimated:YES];
        return;
    }

    PPStory *story = self.stories[self.currentStoryIndex];
    NSInteger count = story.items.count;
    if (count == 0) {
        [self nextStory];
        return;
    }

    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: @"";
    if (currentUID.length > 0 && ![story.userID isEqualToString:currentUID]) {
        story.isSeen = YES;
        [[PPStoriesManager shared] recordViewForStoryOwnerID:story.userID completion:nil];
    }

    [self pp_updateUserInfoForCurrentStory];

    CGFloat totalW = self.view.bounds.size.width - 24.0;
    CGFloat spacing = 4.0;
    CGFloat barW = (totalW - (count - 1) * spacing) / MAX(count, 1);

    for (NSInteger i = 0; i < count; i++) {
        UIProgressView *pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        pv.progressTintColor = UIColor.whiteColor;
        pv.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.24];
        pv.translatesAutoresizingMaskIntoConstraints = NO;
        pv.progress = 0.0;
        pv.layer.cornerRadius = 2.0;
        pv.clipsToBounds = YES;
        [self.progressContainer addSubview:pv];
        [NSLayoutConstraint activateConstraints:@[
            [pv.leadingAnchor constraintEqualToAnchor:self.progressContainer.leadingAnchor constant:(barW + spacing) * i],
            [pv.widthAnchor constraintEqualToConstant:barW],
            [pv.topAnchor constraintEqualToAnchor:self.progressContainer.topAnchor],
            [pv.bottomAnchor constraintEqualToAnchor:self.progressContainer.bottomAnchor]
        ]];
        [self.progressBars addObject:pv];
    }

    [self pp_animateProgressContainerEntrance];
    self.currentItemIndex = 0;
    [self showItem];
}

- (void)showItem {
    [self.timer invalidate];
    self.timer = nil;
    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];

    PPStory *story = self.stories[self.currentStoryIndex];
    if (self.currentItemIndex >= story.items.count) {
        [self nextStory];
        return;
    }

    for (NSInteger i = 0; i < self.progressBars.count; i++) {
        UIProgressView *bar = self.progressBars[i];
        bar.progress = (i < self.currentItemIndex) ? 1.0 : 0.0;
        [bar.layer removeAnimationForKey:PPStoryProgressPulseAnimationKey];
        [bar.layer removeAnimationForKey:PPStoryProgressSlideAnimationKey];
        bar.alpha = 1.0;
    }

    PPStoryItem *item = story.items[self.currentItemIndex];
    [self pp_updateControlsForCurrentItem:item];
    if (item.isVideo) {
        [self playVideoItem:item];
    } else {
        [self showImageItem:item];
    }
}

- (void)showImageItem:(PPStoryItem *)item {
    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];
    self.playerLayer.player = nil;
    self.muteButton.hidden = YES;
    self.imageView.hidden = NO;

    UIImage *placeholder = [UIImage imageNamed:@"placeholder"];
    if (!placeholder) {
        placeholder = [UIImage systemImageNamed:@"photo"];
    }
    [[PPImageLoaderManager shared] setImageOnImageView:self.imageView
                                                    url:item.mediaURL.absoluteString
                                            placeholder:placeholder
                                        transitionStyle:PPImageTransitionStyleCrossDissolve
                                             complation:nil];

    NSTimeInterval duration = [self pp_safeDuration:item.duration fallback:5.0];
    self.imageDuration = duration;
    self.imageStartTime = CACurrentMediaTime();

    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }

    self.displayLink =
    [CADisplayLink displayLinkWithTarget:self
                                selector:@selector(pp_handleImageTick:)];

    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];
}

- (void)pp_handleImageTick:(CADisplayLink *)link
{
    CFTimeInterval elapsed = CACurrentMediaTime() - self.imageStartTime;

    CGFloat progress =
        MIN(1.0, elapsed / MAX(0.2, self.imageDuration));

    if (self.currentItemIndex < self.progressBars.count) {
        UIProgressView *pv = self.progressBars[self.currentItemIndex];
        pv.progress = progress;
    }

    if (progress >= 1.0) {
        [self.displayLink invalidate];
        self.displayLink = nil;
        [self nextItem];
    }
}


- (void)playVideoItem:(PPStoryItem *)storyItem {

    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];
    self.imageView.hidden = YES;
    self.muteButton.hidden = NO;

    NSURL *url = storyItem.mediaURL;
    if (![url isKindOfClass:NSURL.class] || url.absoluteString.length == 0) {
        [self nextItem];
        return;
    }

    AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSArray *keys = @[@"playable", @"duration"];

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    self.currentPlayerItem = playerItem;
    self.currentVideoItemKey = [self pp_itemKeyForCurrentPositionWithItem:storyItem];
    self.currentVideoFallbackDuration =
        [self pp_safeDuration:storyItem.duration fallback:5.0];
    self.hasStartedCurrentVideoPlayback = NO;

    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
        self.player.automaticallyWaitsToMinimizeStalling = YES;
    } else {
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }

    self.player.muted = self.isPlayerMuted;
    self.playerLayer.player = self.player;
    [self pp_updateMuteButtonAppearance];

    __weak typeof(self) weakSelf = self;

    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{

            AVKeyValueStatus playableStatus =
                [asset statusOfValueForKey:@"playable" error:nil];

            if (playableStatus == AVKeyValueStatusLoaded) {

                CMTime durationTime = asset.duration;
                NSTimeInterval duration = CMTimeGetSeconds(durationTime);

                if (!isfinite(duration) || duration <= 0.15) {
                    duration = weakSelf.currentVideoFallbackDuration;
                }

                weakSelf.currentVideoFallbackDuration = duration;

                [weakSelf pp_tryStartCurrentVideoPlaybackIfReady];

            } else {
                [weakSelf nextItem];
            }
        });
    }];

    [playerItem addObserver:self
                 forKeyPath:@"status"
                    options:NSKeyValueObservingOptionInitial |
                            NSKeyValueObservingOptionNew
                    context:PPStoryPlayerItemStatusContext];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(pp_playerItemDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
}
- (void)pp_tryStartCurrentVideoPlaybackIfReady
{
    if (self.hasStartedCurrentVideoPlayback) {
        return;
    }
    if (!self.currentPlayerItem) {
        return;
    }
    if (self.currentPlayerItem.status == AVPlayerItemStatusFailed) {
        [self nextItem];
        return;
    }
    if (self.currentPlayerItem.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }

    self.hasStartedCurrentVideoPlayback = YES;
    NSTimeInterval totalDuration = [self pp_safeDuration:CMTimeGetSeconds(self.currentPlayerItem.duration)
                                                fallback:self.currentVideoFallbackDuration];

    __weak typeof(self) weakSelf = self;

    if (self.playerTimeObserver) {
        [self.player removeTimeObserver:self.playerTimeObserver];
        self.playerTimeObserver = nil;
    }

    self.playerTimeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.05, NSEC_PER_SEC)
                                              queue:dispatch_get_main_queue()
                                         usingBlock:^(CMTime time) {

        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSTimeInterval current = CMTimeGetSeconds(time);
        if (!isfinite(current) || current < 0) return;

        CGFloat progress = (totalDuration > 0.1)
            ? MIN(1.0, current / totalDuration)
            : 0.0;

        if (self.currentItemIndex < self.progressBars.count) {
            UIProgressView *pv = self.progressBars[self.currentItemIndex];
            pv.progress = progress;
        }

        if (progress >= 0.999) {
            if (self.playerTimeObserver) {
                [self.player removeTimeObserver:self.playerTimeObserver];
                self.playerTimeObserver = nil;
            }
            [self nextItem];
        }
    }];
}




- (void)nextItem {
    self.currentItemIndex += 1;
    [self showItem];
}

- (void)nextStory {
    self.currentStoryIndex += 1;
    [self loadStory];
}


- (void)pp_handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    if (self.isInteractiveDismissInProgress) return;

    if (self.currentItemIndex < 0 ||
        self.currentItemIndex >= self.progressBars.count) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {

        self.isPausedByLongPress = YES;

        [self.player pause];

        if (self.displayLink) {
            self.pausedImageElapsed = CACurrentMediaTime() - self.imageStartTime;
            [self.displayLink invalidate];
            self.displayLink = nil;
        }

        [UIView animateWithDuration:0.28
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.progressContainer.alpha = 0.0;
            self.userAvatarView.alpha = 0.0;
            self.userNameHeaderLabel.alpha = 0.0;
            self.storyTimeLabel.alpha = 0.0;
            self.dismissButton.alpha = 0.0;
            self.muteButton.alpha = 0.0;
            self.editButton.alpha = 0.0;
            self.captionLabel.alpha = 0.0;
            self.imageView.transform = CGAffineTransformMakeScale(0.97, 0.97);
        } completion:nil];
    }

    else if (gesture.state == UIGestureRecognizerStateEnded ||
             gesture.state == UIGestureRecognizerStateCancelled) {

        if (!self.isPausedByLongPress) return;
        self.isPausedByLongPress = NO;

        if (self.currentPlayerItem) {
            [self.player play];
        }
        else if (self.pausedImageElapsed > 0) {
            self.imageStartTime = CACurrentMediaTime() - self.pausedImageElapsed;
            self.pausedImageElapsed = 0;
            self.displayLink =
                [CADisplayLink displayLinkWithTarget:self
                                            selector:@selector(pp_handleImageTick:)];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                                   forMode:NSRunLoopCommonModes];
        }

        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.progressContainer.alpha = 1.0;
            self.userAvatarView.alpha = 1.0;
            self.userNameHeaderLabel.alpha = 1.0;
            self.storyTimeLabel.alpha = 1.0;
            self.dismissButton.alpha = 1.0;
            self.muteButton.alpha = 1.0;
            self.editButton.alpha = 1.0;
            self.captionLabel.alpha = 1.0;
            self.imageView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

#pragma mark - Progress Animations

- (void)pp_startPulseAnimationForProgressView:(UIProgressView *)progressView
{
    if (![progressView isKindOfClass:UIProgressView.class]) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @0.58;
    pulse.toValue = @1.0;
    pulse.duration = 0.55;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = PPPremiumEaseInOut();
    [progressView.layer addAnimation:pulse forKey:PPStoryProgressPulseAnimationKey];
}

- (void)pp_startSlideAnimationForProgressView:(UIProgressView *)progressView
{
    if (![progressView isKindOfClass:UIProgressView.class]) {
        return;
    }

    CABasicAnimation *slide = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    slide.fromValue = @(-3.0);
    slide.toValue = @(0.0);
    slide.duration = 0.30;
    slide.repeatCount = 1;
    slide.timingFunction = PPPremiumEaseOut();
    [progressView.layer addAnimation:slide forKey:PPStoryProgressSlideAnimationKey];
}

- (void)pp_stopAllProgressAnimations
{
    for (NSInteger i = 0; i < self.progressBars.count; i++) {
        UIProgressView *bar = self.progressBars[i];

        bar.progress = (i < self.currentItemIndex) ? 1.0 : 0.0;

        [bar.layer removeAllAnimations];
        bar.layer.speed = 1.0;
        bar.layer.timeOffset = 0.0;
        bar.layer.beginTime = 0.0;
        bar.alpha = 1.0;
    }
}

- (void)pp_animateProgressContainerEntrance
{
    self.progressContainer.alpha = 0.0;
    self.progressContainer.transform = CGAffineTransformMakeTranslation(12.0, -6.0);
    [UIView animateWithDuration:0.38
                          delay:0.06
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.progressContainer.alpha = 1.0;
        self.progressContainer.transform = CGAffineTransformIdentity;
    } completion:nil];
}

#pragma mark - Actions

- (void)handleTap:(UITapGestureRecognizer *)tap {
    if (self.isInteractiveDismissInProgress) {
        return;
    }

    CGPoint loc = [tap locationInView:self.view];

    CGFloat topBarHeight = self.view.safeAreaInsets.top + 60.0;
    if (loc.y < topBarHeight) {
        return;
    }

    CGFloat midX = self.view.bounds.size.width * 0.5;

    // LEFT SIDE → Previous
    if (loc.x < midX) {

        // Previous item
        if (self.currentItemIndex > 0) {
            self.currentItemIndex -= 1;
            [self showItem];
        }
        // Previous story
        else if (self.currentStoryIndex > 0) {
            self.currentStoryIndex -= 1;
            [self loadStory];
        }
    }
    // RIGHT SIDE → Next
    else {
        [self nextItem];
    }
}

- (void)pp_dismissButtonTapped
{
    [self pp_dismissViewerAnimated:YES];
}

- (void)pp_muteButtonTapped
{
    self.isPlayerMuted = !self.isPlayerMuted;
    self.player.muted = self.isPlayerMuted;
    [self pp_updateMuteButtonAppearance];
}

- (void)pp_editButtonTapped
{
    if (self.isCommittingStoryEdit) {
        return;
    }
    PPStory *story = [self pp_currentStory];
    PPStoryItem *item = [self pp_currentStoryItem];
    if (!story || !item || ![self pp_canEditCurrentStory]) {
        return;
    }

    [self pp_stopCurrentPlaybackAndPreserveProgress:YES];

    PPStoryEditViewController *editor = [[PPStoryEditViewController alloc] initWithStoryItem:item];
    __weak typeof(self) weakSelf = self;
    editor.onCancel = ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self showItem];
    };
    editor.onSave = ^(NSString *caption, UIImage * _Nullable newImage, PPStoryEditViewController *editorVC) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self pp_commitStoryEditWithCaption:caption newImage:newImage editor:editorVC];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        nav.sheetPresentationController.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pp_commitStoryEditWithCaption:(NSString *)caption
                              newImage:(UIImage * _Nullable)newImage
                                editor:(PPStoryEditViewController *)editor
{
    PPStory *story = [self pp_currentStory];
    PPStoryItem *item = [self pp_currentStoryItem];
    if (!story || !item || ![self pp_canEditCurrentStory]) {
        [editor pp_showError:kLang(@"story_edit_not_allowed")];
        return;
    }

    PPStoryItem *previousItem = [PPStoryItem new];
    previousItem.mediaURL = item.mediaURL;
    previousItem.isVideo = item.isVideo;
    previousItem.duration = item.duration;
    previousItem.caption = item.caption;

    NSString *trimmedCaption = [caption stringByTrimmingCharactersInSet:
                                NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    self.isCommittingStoryEdit = YES;
    [editor pp_setSaving:YES];

    item.caption = trimmedCaption;
    if ([newImage isKindOfClass:UIImage.class]) {
        item.isVideo = NO;
        item.duration = 5.0;
        self.playerLayer.player = nil;
        self.imageView.hidden = NO;
        self.imageView.image = newImage;
    }
    [self pp_updateControlsForCurrentItem:item];

    __weak typeof(self) weakSelf = self;
    [[PPStoriesManager shared] updateStoryItemForCurrentUserWithStoryID:story.userID
                                                              itemIndex:self.currentItemIndex
                                                                caption:trimmedCaption
                                                               newImage:newImage
                                                             completion:^(PPStoryItem * _Nullable updatedItem, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        self.isCommittingStoryEdit = NO;
        [editor pp_setSaving:NO];

        if (error || !updatedItem) {
            [self pp_replaceCurrentItemWithItem:previousItem];
            [self pp_updateControlsForCurrentItem:previousItem];
            [editor pp_showError:kLang(@"story_edit_failed")];
            return;
        }

        [self pp_replaceCurrentItemWithItem:updatedItem];
        if (self.onStoryUpdated) {
            self.onStoryUpdated(story);
        }
        [editor pp_markFinished];
        [editor dismissViewControllerAnimated:YES completion:^{
            [self showItem];
        }];
    }];
}

- (void)pp_updateMuteButtonAppearance
{
    NSString *imageName = self.isPlayerMuted ? @"speaker.slash.fill" : @"speaker.wave.2.fill";
    [self.muteButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}

- (void)pp_dismissViewerAnimated:(BOOL)animated
{
    [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
    [self dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark - Swipe Down Dismiss

- (void)pp_handleDismissPan:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self.view];
    CGFloat y = MAX(translation.y, 0.0);
    CGFloat progress = MIN(1.0, y / 220.0);

    if (pan.state == UIGestureRecognizerStateBegan ||
        pan.state == UIGestureRecognizerStateChanged) {
        self.isInteractiveDismissInProgress = YES;
        self.view.transform = CGAffineTransformMakeTranslation(0.0, y);
        self.view.alpha = 1.0 - (progress * 0.45);
        return;
    }

    if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled ||
        pan.state == UIGestureRecognizerStateFailed) {
        CGPoint velocity = [pan velocityInView:self.view];
        BOOL shouldDismiss = (y > 130.0 || velocity.y > 1100.0);

        if (shouldDismiss) {
            [self pp_stopCurrentPlaybackAndPreserveProgress:NO];
            [UIView animateWithDuration:0.26
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                self.view.transform = CGAffineTransformMakeTranslation(0.0, self.view.bounds.size.height);
                self.view.alpha = 0.0;
            } completion:^(__unused BOOL finished) {
                self.isInteractiveDismissInProgress = NO;
                [self dismissViewControllerAnimated:NO completion:nil];
            }];
        } else {
            [UIView animateWithDuration:0.32
                                  delay:0.0
                 usingSpringWithDamping:0.82
                  initialSpringVelocity:0.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                self.view.transform = CGAffineTransformIdentity;
                self.view.alpha = 1.0;
            } completion:^(__unused BOOL finished) {
                self.isInteractiveDismissInProgress = NO;
            }];
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.dismissPanGesture) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:self.view];
        return fabs(velocity.y) > fabs(velocity.x) && velocity.y > 0.0;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    UIView *view = touch.view;
    while (view && view != self.view) {
        if ([view isKindOfClass:UIControl.class]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

#pragma mark - Player Events

- (void)pp_stopCurrentPlaybackAndPreserveProgress:(BOOL)preserve
{
    [self.timer invalidate];
    self.timer = nil;

    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }

    if (self.currentPlayerItem) {
        if (preserve && self.currentVideoItemKey.length > 0) {
            CMTime currentTime = self.currentPlayerItem.currentTime;
            if (CMTIME_IS_VALID(currentTime) && CMTimeGetSeconds(currentTime) > 0.1) {
                self.videoResumeTimesByItemKey[self.currentVideoItemKey] =
                    [NSValue valueWithCMTime:currentTime];
            }
        }
        [self.player pause];
    }
}

- (void)pp_playerItemDidFinish:(NSNotification *)notification
{
    if (notification.object != self.currentPlayerItem) {
        return;
    }
    if (self.currentVideoItemKey.length > 0) {
        [self.videoResumeTimesByItemKey removeObjectForKey:self.currentVideoItemKey];
    }
    [self nextItem];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    (void)change;
    if (context == PPStoryPlayerItemStatusContext) {
        if (object == self.currentPlayerItem && [keyPath isEqualToString:@"status"]) {
            [self pp_tryStartCurrentVideoPlaybackIfReady];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Helpers

- (PPStory * _Nullable)pp_currentStory
{
    if (self.currentStoryIndex < 0 || self.currentStoryIndex >= (NSInteger)self.stories.count) {
        return nil;
    }
    return self.stories[self.currentStoryIndex];
}

- (PPStoryItem * _Nullable)pp_currentStoryItem
{
    PPStory *story = [self pp_currentStory];
    if (!story || self.currentItemIndex < 0 || self.currentItemIndex >= (NSInteger)story.items.count) {
        return nil;
    }
    return story.items[self.currentItemIndex];
}

- (NSString *)pp_currentUserID
{
    NSString *uid = [FIRAuth auth].currentUser.uid ?: @"";
    return [uid stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (BOOL)pp_canEditCurrentStory
{
    PPStory *story = [self pp_currentStory];
    NSString *currentUserID = [self pp_currentUserID];
    return story.userID.length > 0 &&
           currentUserID.length > 0 &&
           [story.userID isEqualToString:currentUserID];
}

- (void)pp_updateControlsForCurrentItem:(PPStoryItem *)item
{
    self.editButton.hidden = ![self pp_canEditCurrentStory];

    NSString *caption = [item.caption stringByTrimmingCharactersInSet:
                         NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    BOOL showCaption = caption.length > 0;

    if (showCaption) {
        self.captionLabel.text = caption;
        self.captionLabel.textAlignment = [Language alignmentForCurrentLanguage];
        self.captionLabel.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
        self.captionLabel.hidden = NO;

        [self.captionLabel.layer removeAnimationForKey:PPStoryCaptionEntranceAnimationKey];
        self.captionLabel.alpha = 0.0;
        self.captionLabel.transform = CGAffineTransformMakeTranslation(0.0, 8.0);

        [UIView animateWithDuration:0.42
                              delay:0.12
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.captionLabel.alpha = 1.0;
            self.captionLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        self.captionLabel.alpha = 0.0;
        self.captionLabel.hidden = YES;
    }
}

- (void)pp_replaceCurrentItemWithItem:(PPStoryItem *)updatedItem
{
    PPStory *story = [self pp_currentStory];
    if (!story || !updatedItem || self.currentItemIndex < 0 || self.currentItemIndex >= (NSInteger)story.items.count) {
        return;
    }

    NSMutableArray<PPStoryItem *> *items = [story.items mutableCopy] ?: [NSMutableArray array];
    items[self.currentItemIndex] = updatedItem;
    story.items = items.copy;
}

- (NSTimeInterval)pp_safeDuration:(NSTimeInterval)duration fallback:(NSTimeInterval)fallback
{
    if (isfinite(duration) && duration > 0.15) {
        return duration;
    }
    if (isfinite(fallback) && fallback > 0.15) {
        return fallback;
    }
    return 5.0;
}

- (NSString *)pp_itemKeyForCurrentPositionWithItem:(PPStoryItem *)item
{
    if (self.currentStoryIndex < 0 || self.currentStoryIndex >= self.stories.count) {
        return [NSString stringWithFormat:@"story-%ld-item-%ld", (long)self.currentStoryIndex, (long)self.currentItemIndex];
    }

    PPStory *story = self.stories[self.currentStoryIndex];
    NSString *userID = story.userID ?: @"";
    NSString *media = item.mediaURL.absoluteString ?: @"";
    return [NSString stringWithFormat:@"%@|%ld|%@", userID, (long)self.currentItemIndex, media];
}

#pragma mark - User Info

- (void)pp_updateUserInfoForCurrentStory
{
    if (self.currentStoryIndex < 0 || self.currentStoryIndex >= (NSInteger)self.stories.count) {
        return;
    }

    PPStory *story = self.stories[self.currentStoryIndex];

    NSString *name = [story.userName stringByTrimmingCharactersInSet:
                      NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0) {
        name = kLang(@"Unknown");
    }
    self.userNameHeaderLabel.text = name;
    self.storyTimeLabel.text = [self pp_timeAgoFromDate:story.updatedAt];

    if (story.userImageURL) {
        [PPImageLoaderManager.shared setImageOnImageView:self.userAvatarView
                                                      url:story.userImageURL.absoluteString
                                               placeholder:[PPModernAvatarRenderer avatarImageForName:story.userName size:32]
                                                complation:nil];
    } else {
        self.userAvatarView.image = [PPModernAvatarRenderer avatarImageForName:story.userName size:32];
    }
}

- (NSString *)pp_timeAgoFromDate:(NSDate *)date
{
    if (!date) return @"";

    if (@available(iOS 13.0, *)) {
        NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
        formatter.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleAbbreviated;
        return [formatter localizedStringForDate:date relativeToDate:[NSDate date]];
    }

    NSTimeInterval seconds = -[date timeIntervalSinceNow];
    if (seconds < 60) return @"now";
    if (seconds < 3600) return [NSString stringWithFormat:@"%ldm", (long)(seconds / 60)];
    if (seconds < 86400) return [NSString stringWithFormat:@"%ldh", (long)(seconds / 3600)];
    return [NSString stringWithFormat:@"%ldd", (long)(seconds / 86400)];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

@end
