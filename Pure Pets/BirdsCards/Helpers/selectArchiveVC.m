//
//  selectArchiveVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import "AAPopupView.h"
#import "ArchiveDetailsModel.h"
#import "ImageModel.h"
#import "JGProgressHUD.h"
#import "Language.h"
#import "selectArchiveVC.h"
@interface selectArchiveVC ()<UITableViewDelegate, UITableViewDataSource, ABCellMenuViewDelegate> {
    NSString *recivedRingID;
    int reloadAnimationFlag;
}
@property (nonatomic, strong) TTGSnackbar *snakBar;
@property (nonatomic, strong) AAPopupView *archivePopupView;
@property (nonatomic, strong) NSMutableArray<ArchiveDetailsModel *> *archiveDetails;
@property (nonatomic, strong) UIButton *dismissButton;
@property (nonatomic, strong) UIView *sheetHandleView;
@property (nonatomic, strong) UIView *backgroundOrbView;
@property (nonatomic, strong) UIView *secondaryOrbView;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *countBadgeLabel;
@property (nonatomic, strong) UIImageView *heroIconView;
@property (nonatomic, strong) UILabel *popupTitleLabel;
@property (nonatomic, strong) UILabel *popupSubtitleLabel;
@end
static NSString *menuCellIdentifier = @"Default Cell";
@implementation selectArchiveVC

- (BOOL)pp_isLeftToRight
{
    return [Language languageVal] == 0;
}

- (NSTextAlignment)pp_primaryAlignment
{
    return [self pp_isLeftToRight] ? NSTextAlignmentLeft : NSTextAlignmentRight;
}

- (void)pp_applyElevatedStyleToView:(UIView *)view cornerRadius:(CGFloat)cornerRadius
{
    view.layer.cornerRadius = cornerRadius;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:PPIOS26() ? 0.16 : 0.34].CGColor;
    view.layer.shadowColor = [UIColor colorWithRed:23.0 / 255.0
                                             green:36.0 / 255.0
                                              blue:65.0 / 255.0
                                             alpha:1.0].CGColor;
    view.layer.shadowOpacity = PPIOS26() ? 0.10 : 0.08;
    view.layer.shadowOffset = CGSizeMake(0.0, 14.0);
    view.layer.shadowRadius = 26.0;
    view.layer.masksToBounds = NO;
}

- (void)pp_styleChipLabel:(UILabel *)label highlighted:(BOOL)highlighted
{
    label.font = [GM MidFontWithSize:13];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = highlighted ? AppForgroundColr : AppPrimaryTextClr;
    label.backgroundColor = highlighted ? GM.appPrimaryColor : [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.56 : 0.88];
    label.layer.cornerRadius = 16.0;
    label.layer.masksToBounds = YES;
}

- (void)pp_styleTableCell:(UITableViewCell *)cell inTableView:(UITableView *)tableView
{
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.70 : 0.96];
    cell.contentView.layer.cornerRadius = (tableView == self.selectTableView) ? 24.0 : 18.0;
    cell.contentView.layer.masksToBounds = YES;
    cell.contentView.layer.borderWidth = 1.0;
    cell.contentView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:PPIOS26() ? 0.12 : 0.28].CGColor;

    cell.layer.cornerRadius = cell.contentView.layer.cornerRadius;
    cell.layer.shadowColor = [UIColor colorWithRed:15.0 / 255.0
                                             green:23.0 / 255.0
                                              blue:42.0 / 255.0
                                             alpha:1.0].CGColor;
    cell.layer.shadowOpacity = 0.07;
    cell.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    cell.layer.shadowRadius = 18.0;
    cell.layer.masksToBounds = NO;
    cell.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds
                                                       cornerRadius:cell.contentView.layer.cornerRadius].CGPath;

    UIView *selectedBackground = [[UIView alloc] initWithFrame:cell.bounds];
    selectedBackground.backgroundColor = [GM.appPrimaryColor colorWithAlphaComponent:0.12];
    selectedBackground.layer.cornerRadius = cell.contentView.layer.cornerRadius;
    selectedBackground.layer.masksToBounds = YES;
    cell.selectedBackgroundView = selectedBackground;
}

- (void)pp_updateLayoutDirection
{
    UISemanticContentAttribute attribute = [self pp_isLeftToRight] ?
        UISemanticContentAttributeForceLeftToRight :
        UISemanticContentAttributeForceRightToLeft;

    self.view.semanticContentAttribute = attribute;
    self.selectTableView.semanticContentAttribute = attribute;
    self.archiveTableView.semanticContentAttribute = attribute;

    self.titleLa.textAlignment = [self pp_primaryAlignment];
    self.titleLabel.textAlignment = [self pp_primaryAlignment];
    self.summaryLabel.textAlignment = [self pp_primaryAlignment];
    self.popupTitleLabel.textAlignment = [self pp_primaryAlignment];
    self.popupSubtitleLabel.textAlignment = [self pp_primaryAlignment];
}

- (void)pp_refreshHeaderContent
{
    NSString *archiveName = self.archiveClass.archiveTitle.length ?
        self.archiveClass.archiveTitle :
        kLang(@"untitledArchive");
    NSString *datePrefix =
        [kLang(@"CreateDate") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *createdDate = self.archiveClass.archiveDate ?
        [[AppManager sharedInstance] managerStringfromDate:self.archiveClass.archiveDate] :
        @"";

    self.titleLa.text = kLang(@"archive_sheet_heading");
    self.titleLabel.text = archiveName;
    self.summaryLabel.text = kLang(@"archive_sheet_subtitle");
    self.archiveDate.text = createdDate.length ?
        [NSString stringWithFormat:@"%@ %@", datePrefix, createdDate] :
        datePrefix;
    self.countBadgeLabel.text =
        [NSString stringWithFormat:@"%ld %@", (long)self.archiveDetails.count, kLang(@"ArchiveCardsCount")];

    self.popupTitleLabel.text = kLang(@"archive_move_title");
    self.popupSubtitleLabel.text = kLang(@"archive_move_subtitle");
    self.RingID.text = kLang(@"archive_move_picker_hint");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor colorWithHexString:@"#F4F7FB"]);
    [self setupViews];
    [self setupConstraints];

    self.view.layer.cornerRadius = 28;
    self.view.clipsToBounds = YES;

    _selectTableView.dataSource = self;
    _selectTableView.delegate = self;
    _archiveTableView.dataSource = self;
    _archiveTableView.delegate = self;
    reloadAnimationFlag = 0;

    self.archiveDetails = [NSMutableArray array];
    [self pp_updateLayoutDirection];
    [self pp_refreshHeaderContent];
    [self setupArchive];
    [self loadArchiveDetails];
}

- (void)setupViews
{
    self.backgroundOrbView = [[UIView alloc] init];
    self.backgroundOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundOrbView.backgroundColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.12];
    [self.view addSubview:self.backgroundOrbView];

    self.secondaryOrbView = [[UIView alloc] init];
    self.secondaryOrbView.translatesAutoresizingMaskIntoConstraints = NO;
    self.secondaryOrbView.backgroundColor = [[UIColor colorWithHexString:@"#3D3E65"] colorWithAlphaComponent:0.08];
    [self.view addSubview:self.secondaryOrbView];

    _topBarView = [[UIView alloc] init];
    _topBarView.translatesAutoresizingMaskIntoConstraints = NO;
    _topBarView.backgroundColor = [AppForgroundColr colorWithAlphaComponent:PPIOS26() ? 0.74 : 0.96];
    [self.view addSubview:_topBarView];

    self.sheetHandleView = [[UIView alloc] init];
    self.sheetHandleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheetHandleView.backgroundColor = [[UIColor labelColor] colorWithAlphaComponent:0.14];
    [_topBarView addSubview:self.sheetHandleView];

    _titleLa = [[UILabel alloc] init];
    _titleLa.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLa.font = [GM MidFontWithSize:12];
    _titleLa.textColor = [UIColor secondaryLabelColor];
    [_topBarView addSubview:_titleLa];

    _dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_dismissButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    _dismissButton.tintColor = AppPrimaryTextClr;
    _dismissButton.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.70];
    _dismissButton.layer.cornerRadius = 18.0;
    [_dismissButton addTarget:self action:@selector(dismissBTN:) forControlEvents:UIControlEventTouchUpInside];
    [_topBarView addSubview:_dismissButton];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [GM MidFontWithSize:22];
    _titleLabel.textColor = AppPrimaryTextClr;
    _titleLabel.numberOfLines = 2;
    [_topBarView addSubview:_titleLabel];

    self.summaryLabel = [[UILabel alloc] init];
    self.summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.summaryLabel.font = [GM MidFontWithSize:14];
    self.summaryLabel.textColor = [UIColor secondaryLabelColor];
    self.summaryLabel.numberOfLines = 0;
    [_topBarView addSubview:self.summaryLabel];

    self.heroIconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"archivebox.fill"]];
    self.heroIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.heroIconView.contentMode = UIViewContentModeCenter;
    self.heroIconView.tintColor = AppForgroundColr;
    self.heroIconView.backgroundColor = GM.appPrimaryColor;
    self.heroIconView.layer.cornerRadius = 22.0;
    self.heroIconView.layer.masksToBounds = YES;
    [_topBarView addSubview:self.heroIconView];

    _archiveDate = [[UILabel alloc] init];
    _archiveDate.translatesAutoresizingMaskIntoConstraints = NO;
    [self pp_styleChipLabel:_archiveDate highlighted:NO];
    [_topBarView addSubview:_archiveDate];

    self.countBadgeLabel = [[UILabel alloc] init];
    self.countBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self pp_styleChipLabel:self.countBadgeLabel highlighted:YES];
    [_topBarView addSubview:self.countBadgeLabel];

    _selectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _selectTableView.translatesAutoresizingMaskIntoConstraints = NO;
    _selectTableView.backgroundColor = UIColor.clearColor;
    _selectTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _selectTableView.showsVerticalScrollIndicator = NO;
    _selectTableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 26.0, 0.0);
    _selectTableView.tableFooterView = [UIView new];
    [_selectTableView registerClass:[ABMenuTableViewCell class] forCellReuseIdentifier:menuCellIdentifier];
    [self.view addSubview:_selectTableView];

    _archiveView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 430)];
    _archiveView.backgroundColor = PPBackgroundColorForIOS26([AppForgroundColr colorWithAlphaComponent:0.98]);

    self.popupTitleLabel = [[UILabel alloc] init];
    self.popupTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.popupTitleLabel.font = [GM MidFontWithSize:18];
    self.popupTitleLabel.textColor = AppPrimaryTextClr;
    [_archiveView addSubview:self.popupTitleLabel];

    self.popupSubtitleLabel = [[UILabel alloc] init];
    self.popupSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.popupSubtitleLabel.font = [GM MidFontWithSize:13];
    self.popupSubtitleLabel.textColor = [UIColor secondaryLabelColor];
    self.popupSubtitleLabel.numberOfLines = 0;
    [_archiveView addSubview:self.popupSubtitleLabel];

    _RingID = [[UITextField alloc] init];
    _RingID.translatesAutoresizingMaskIntoConstraints = NO;
    _RingID.borderStyle = UITextBorderStyleNone;
    _RingID.userInteractionEnabled = NO;
    _RingID.textAlignment = NSTextAlignmentCenter;
    _RingID.textColor = AppPrimaryTextClr;
    _RingID.backgroundColor = [[GM appPrimaryColor] colorWithAlphaComponent:0.08];
    _RingID.layer.cornerRadius = 16.0;
    _RingID.layer.masksToBounds = YES;
    _RingID.font = [GM MidFontWithSize:14];
    [_archiveView addSubview:_RingID];

    _addConteinerView = [[UIView alloc] init];
    _addConteinerView.translatesAutoresizingMaskIntoConstraints = NO;
    [_archiveView addSubview:_addConteinerView];

    _AddBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    _AddBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [_AddBTN setTitle:kLang(@"addArchiveTitle") forState:UIControlStateNormal];
    [_AddBTN setTitleColor:AppForgroundColr forState:UIControlStateNormal];
    _AddBTN.backgroundColor = GM.appPrimaryColor;
    _AddBTN.layer.cornerRadius = 16.0;
    _AddBTN.layer.masksToBounds = YES;
    _AddBTN.titleLabel.font = [GM MidFontWithSize:14];
    [_AddBTN addTarget:self action:@selector(addarchiveBTN:) forControlEvents:UIControlEventTouchUpInside];
    [_addConteinerView addSubview:_AddBTN];

    UIButton *closeArchiveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeArchiveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeArchiveBtn setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    closeArchiveBtn.tintColor = AppPrimaryTextClr;
    closeArchiveBtn.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.78];
    closeArchiveBtn.layer.cornerRadius = 16.0;
    closeArchiveBtn.layer.masksToBounds = YES;
    [closeArchiveBtn addTarget:self action:@selector(closeArchiveBTN:) forControlEvents:UIControlEventTouchUpInside];
    [_archiveView addSubview:closeArchiveBtn];

    _archiveTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _archiveTableView.translatesAutoresizingMaskIntoConstraints = NO;
    _archiveTableView.backgroundColor = UIColor.clearColor;
    _archiveTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _archiveTableView.showsVerticalScrollIndicator = NO;
    _archiveTableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 18.0, 0.0);
    _archiveTableView.tableFooterView = [UIView new];
    [_archiveView addSubview:_archiveTableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.popupTitleLabel.topAnchor constraintEqualToAnchor:_archiveView.topAnchor constant:20.0],
        [self.popupTitleLabel.leadingAnchor constraintEqualToAnchor:_archiveView.leadingAnchor constant:18.0],

        [closeArchiveBtn.topAnchor constraintEqualToAnchor:_archiveView.topAnchor constant:18.0],
        [closeArchiveBtn.trailingAnchor constraintEqualToAnchor:_archiveView.trailingAnchor constant:-18.0],
        [closeArchiveBtn.widthAnchor constraintEqualToConstant:32.0],
        [closeArchiveBtn.heightAnchor constraintEqualToConstant:32.0],

        [self.popupTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeArchiveBtn.leadingAnchor constant:-12.0],

        [self.popupSubtitleLabel.topAnchor constraintEqualToAnchor:self.popupTitleLabel.bottomAnchor constant:6.0],
        [self.popupSubtitleLabel.leadingAnchor constraintEqualToAnchor:_archiveView.leadingAnchor constant:18.0],
        [self.popupSubtitleLabel.trailingAnchor constraintEqualToAnchor:_archiveView.trailingAnchor constant:-18.0],

        [_RingID.topAnchor constraintEqualToAnchor:self.popupSubtitleLabel.bottomAnchor constant:16.0],
        [_RingID.leadingAnchor constraintEqualToAnchor:_archiveView.leadingAnchor constant:18.0],
        [_RingID.trailingAnchor constraintEqualToAnchor:_archiveView.trailingAnchor constant:-18.0],
        [_RingID.heightAnchor constraintEqualToConstant:42.0],

        [_addConteinerView.topAnchor constraintEqualToAnchor:_RingID.bottomAnchor constant:14.0],
        [_addConteinerView.leadingAnchor constraintEqualToAnchor:_archiveView.leadingAnchor constant:18.0],
        [_addConteinerView.trailingAnchor constraintEqualToAnchor:_archiveView.trailingAnchor constant:-18.0],
        [_addConteinerView.heightAnchor constraintEqualToConstant:48.0],

        [_AddBTN.leadingAnchor constraintEqualToAnchor:_addConteinerView.leadingAnchor],
        [_AddBTN.trailingAnchor constraintEqualToAnchor:_addConteinerView.trailingAnchor],
        [_AddBTN.topAnchor constraintEqualToAnchor:_addConteinerView.topAnchor],
        [_AddBTN.bottomAnchor constraintEqualToAnchor:_addConteinerView.bottomAnchor],
        [_AddBTN.centerYAnchor constraintEqualToAnchor:_addConteinerView.centerYAnchor],

        [_archiveTableView.topAnchor constraintEqualToAnchor:_addConteinerView.bottomAnchor constant:12.0],
        [_archiveTableView.leadingAnchor constraintEqualToAnchor:_archiveView.leadingAnchor constant:10.0],
        [_archiveTableView.trailingAnchor constraintEqualToAnchor:_archiveView.trailingAnchor constant:-10.0],
        [_archiveTableView.bottomAnchor constraintEqualToAnchor:_archiveView.bottomAnchor constant:-12.0],
    ]];
}

- (void)setupConstraints
{
    [NSLayoutConstraint activateConstraints:@[
        [self.backgroundOrbView.widthAnchor constraintEqualToConstant:170.0],
        [self.backgroundOrbView.heightAnchor constraintEqualToConstant:170.0],
        [self.backgroundOrbView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:-36.0],
        [self.backgroundOrbView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:54.0],

        [self.secondaryOrbView.widthAnchor constraintEqualToConstant:128.0],
        [self.secondaryOrbView.heightAnchor constraintEqualToConstant:128.0],
        [self.secondaryOrbView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-42.0],
        [self.secondaryOrbView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:98.0],

        [_topBarView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [_topBarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [_topBarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [_topBarView.heightAnchor constraintEqualToConstant:188.0],

        [self.sheetHandleView.topAnchor constraintEqualToAnchor:_topBarView.topAnchor constant:10.0],
        [self.sheetHandleView.centerXAnchor constraintEqualToAnchor:_topBarView.centerXAnchor],
        [self.sheetHandleView.widthAnchor constraintEqualToConstant:46.0],
        [self.sheetHandleView.heightAnchor constraintEqualToConstant:5.0],

        [_dismissButton.topAnchor constraintEqualToAnchor:_topBarView.topAnchor constant:18.0],
        [_dismissButton.trailingAnchor constraintEqualToAnchor:_topBarView.trailingAnchor constant:-18.0],
        [_dismissButton.widthAnchor constraintEqualToConstant:36.0],
        [_dismissButton.heightAnchor constraintEqualToConstant:36.0],

        [_titleLa.topAnchor constraintEqualToAnchor:self.sheetHandleView.bottomAnchor constant:18.0],
        [_titleLa.leadingAnchor constraintEqualToAnchor:_topBarView.leadingAnchor constant:20.0],
        [_titleLa.trailingAnchor constraintLessThanOrEqualToAnchor:_dismissButton.leadingAnchor constant:-12.0],

        [_titleLabel.topAnchor constraintEqualToAnchor:_titleLa.bottomAnchor constant:6.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_topBarView.leadingAnchor constant:20.0],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconView.leadingAnchor constant:-16.0],

        [self.summaryLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:10.0],
        [self.summaryLabel.leadingAnchor constraintEqualToAnchor:_topBarView.leadingAnchor constant:20.0],
        [self.summaryLabel.trailingAnchor constraintEqualToAnchor:_topBarView.trailingAnchor constant:-20.0],

        [self.heroIconView.trailingAnchor constraintEqualToAnchor:_topBarView.trailingAnchor constant:-20.0],
        [self.heroIconView.bottomAnchor constraintEqualToAnchor:_topBarView.bottomAnchor constant:-22.0],
        [self.heroIconView.widthAnchor constraintEqualToConstant:56.0],
        [self.heroIconView.heightAnchor constraintEqualToConstant:56.0],

        [self.countBadgeLabel.leadingAnchor constraintEqualToAnchor:_topBarView.leadingAnchor constant:20.0],
        [self.countBadgeLabel.bottomAnchor constraintEqualToAnchor:_topBarView.bottomAnchor constant:-22.0],
        [self.countBadgeLabel.heightAnchor constraintEqualToConstant:32.0],
        [self.countBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:88.0],

        [_archiveDate.trailingAnchor constraintLessThanOrEqualToAnchor:self.heroIconView.leadingAnchor constant:-12.0],
        [_archiveDate.centerYAnchor constraintEqualToAnchor:self.countBadgeLabel.centerYAnchor],
        [_archiveDate.heightAnchor constraintEqualToConstant:32.0],
        [_archiveDate.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.countBadgeLabel.trailingAnchor constant:12.0],

        [_selectTableView.topAnchor constraintEqualToAnchor:_topBarView.bottomAnchor constant:16.0],
        [_selectTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_selectTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_selectTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupArchive
{
    self.archiveArray = [self.archiveArray mutableCopy] ?: [NSMutableArray array];

    [self.archiveTableView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
        configer.emptyTitle = kLang(@"archive_move_title");
        configer.emptySubtitle = kLang(@"archive_move_empty_subtitle");
        configer.emptyImage = [UIImage imageNamed:@"empty-boxx"];
    }];

    [self.selectTableView emptyViewConfigerBlock:^(FOREmptyAssistantConfiger *configer) {
        configer.emptyTitle = kLang(@"archive_sheet_heading");
        configer.emptySubtitle = kLang(@"archive_empty_subtitle");
        configer.emptyImage = [UIImage imageNamed:@"archive"];
    }];

    self.archiveTableView.layer.cornerRadius = 22.0;
    self.archiveTableView.clipsToBounds = YES;

    [self pp_applyElevatedStyleToView:self.topBarView cornerRadius:30.0];
    [self pp_applyElevatedStyleToView:self.archiveView cornerRadius:28.0];
    self.archivePopupView =
        [AAPopupView popupWithContentView:self.archiveView
                                 showType:AAPopupViewShowTypeFadeIn
                              dismissType:AAPopupViewDismissTypeFadeOut
                                 maskType:AAPopupViewMaskTypeDimmed
                 dismissOnBackgroundTouch:YES];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pp_updateLayoutDirection];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.view.layer.cornerRadius = 28.0;
    self.backgroundOrbView.layer.cornerRadius = self.backgroundOrbView.bounds.size.width / 2.0;
    self.secondaryOrbView.layer.cornerRadius = self.secondaryOrbView.bounds.size.width / 2.0;
    self.sheetHandleView.layer.cornerRadius = self.sheetHandleView.bounds.size.height / 2.0;

    self.topBarView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.topBarView.bounds cornerRadius:self.topBarView.layer.cornerRadius].CGPath;
    self.archiveView.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.archiveView.bounds cornerRadius:self.archiveView.layer.cornerRadius].CGPath;
}


// MARK: - ArchiveDetails loader
- (void)loadArchiveDetails
{
    [PPHUD showLoading];

    [[ArchivesManager shared]
     fetchArchiveDetailsForArchiveID:self.archiveClass.ID
     completion:^(NSArray<ArchiveDetailsModel *> *details, NSError *error)
     {
         [PPHUD dismiss];
         if (error) return;

         NSPredicate *notDeleted =
         [NSPredicate predicateWithFormat:@"isDeleted == 0"];

         self.archiveDetails =
         [[details filteredArrayUsingPredicate:notDeleted] mutableCopy];

         [self pp_refreshHeaderContent];
         [self.selectTableView reloadData];
         dispatch_async(dispatch_get_main_queue(), ^{
             reloadAnimationFlag = 1;
         });
     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _archiveTableView) {
        return 78.0f;
    }

    return 96.0f;
}

- (NSInteger)   tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
    if (tableView == _archiveTableView) {
        return self.archiveArray.count;
    }

    return self.archiveDetails.count;
}

- (ABMenuTableViewCell *)menuCellAtIndexPath:(NSIndexPath *)indexPath {
    ABMenuTableViewCell *cell = (ABMenuTableViewCell *)[self.selectTableView dequeueReusableCellWithIdentifier:menuCellIdentifier];

    cell.textLabel.font = [GM MidFontWithSize:15];
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.textColor = AppPrimaryTextClr;
    cell.separatorInset = UIEdgeInsetsMake(0, CGRectGetWidth(cell.bounds), 0, 0);
    cell.imageView.tintColor = GM.appPrimaryColor;

    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == _archiveTableView) {
        static NSString *identifier = @"PlainCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];

        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        }

        ArchiveModel *archive = [self.archiveArray objectAtIndex:indexPath.row];
        NSString *archiveTitle = archive.archiveTitle.length ? archive.archiveTitle : kLang(@"untitledArchive");
        NSString *datePrefix = [kLang(@"CreateDate") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *archiveDate = archive.archiveDate ? [[AppManager sharedInstance] managerStringfromDate:archive.archiveDate] : @"";
        BOOL isCurrentArchive = [archive.ID isEqualToString:self.archiveClass.ID];

        cell.textLabel.text = archiveTitle;
        cell.textLabel.font = [GM MidFontWithSize:15];
        cell.textLabel.textColor = AppPrimaryTextClr;
        cell.textLabel.textAlignment = [self pp_primaryAlignment];

        cell.detailTextLabel.text = archiveDate.length ? [NSString stringWithFormat:@"%@ %@", datePrefix, archiveDate] : kLang(@"archive_move_subtitle");
        cell.detailTextLabel.font = [GM MidFontWithSize:12];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.textAlignment = [self pp_primaryAlignment];
        cell.detailTextLabel.numberOfLines = 1;
        cell.imageView.image = [UIImage systemImageNamed:isCurrentArchive ? @"checkmark.circle.fill" : @"archivebox"];
        cell.imageView.tintColor = isCurrentArchive ? GM.appPrimaryColor : [UIColor colorWithHexString:@"#7B8198"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        [self pp_styleTableCell:cell inTableView:tableView];
        return cell;
    }

    ABMenuTableViewCell *cell = nil;
    cell = [self menuCellAtIndexPath:indexPath];

    // custom menu view
    NSString *nibName =  @"ABCellMailStyleMenuView";
    ABCellMenuView *menuView = [ABCellMenuView initWithNib:nibName bundle:nil];
    menuView.delegate = self;
    menuView.indexPath = indexPath;

    ArchiveDetailsModel *detail = self.archiveDetails[indexPath.row];

    CardModel *card =
    [[self.cardsArray filteredArrayUsingPredicate:
      [NSPredicate predicateWithFormat:@"ID == %@", detail.CardID]] firstObject];

    if (card) {
        menuView.cardmodel = card;
        menuView.ImagesArr = card.imagesNames;
        cell.CardToArchiveID = card.ID;
        NSString *ringText = card.RingID.length ?
            [NSString stringWithFormat:@"%@ • %@", kLang(@"RingID"), card.RingID] :
            kLang(@"archiveCard");
        NSString *subtitle = card.CardTitle.length ? card.CardTitle : kLang(@"archive_move_subtitle");
        NSDictionary *titleAttributes = @{
            NSFontAttributeName: [GM MidFontWithSize:15],
            NSForegroundColorAttributeName: AppPrimaryTextClr
        };
        NSDictionary *subtitleAttributes = @{
            NSFontAttributeName: [GM MidFontWithSize:12],
            NSForegroundColorAttributeName: [UIColor secondaryLabelColor]
        };
        NSMutableAttributedString *attributedText =
            [[NSMutableAttributedString alloc] initWithString:ringText attributes:titleAttributes];
        [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:titleAttributes]];
        [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:subtitle attributes:subtitleAttributes]];
        cell.textLabel.attributedText = attributedText;
        cell.imageView.image = [UIImage systemImageNamed:@"bird.fill"];
        cell.imageView.tintColor = GM.appPrimaryColor;
    } else {
        cell.textLabel.text = kLang(@"archiveCard");
        cell.imageView.image = [UIImage systemImageNamed:@"archivebox.fill"];
        cell.imageView.tintColor = GM.appPrimaryColor;
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textAlignment = [self pp_primaryAlignment];
    cell.rightMenuView = menuView;
    [self pp_styleTableCell:cell inTableView:tableView];
    return cell;
}

#pragma mark UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"select NSIndexPath row  %ld", indexPath.row);

    if (tableView == _archiveTableView) {
        [self changeArchive:self.archiveTableView indexPath:indexPath];
        return;
    }

    ABMenuTableViewCell *cell = (ABMenuTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];

    if (cell.showingRightMenu) {
        return;
    }

    [cell updateMenuView:ABMenuUpdateShowAction animated:YES];
    //[self showDetailsForCell:cell];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _archiveTableView) {
        return indexPath;
    }

    ABMenuTableViewCell *cell = (ABMenuTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];

    if (cell.showingRightMenu) {
        //[cell setSelected:NO animated:YES];
        [cell updateMenuView:ABMenuUpdateHideAction animated:YES];
        return indexPath;
    }

    // [cell setSelected:YES animated:YES];
    return indexPath;
}

#pragma mark ABCellMenuViewDelegate Methods

- (void)goToviewDataVC:(NSArray<ImageModel *> *)ImagesArr cardClass:(CardModel *)cardClass
{
 
    viewDataVC *add = [[viewDataVC alloc]init];
    
    add.cardModel = cardClass;
    PPNavigationController *nav = [[PPNavigationController alloc]initWithRootViewController:add];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)cellMenuViewFlagBtnTapped:(ABCellMenuView *)menuView {
    NSLog(@"cellMenuViewFlagBtnTapped");
}

NSIndexPath *selectedIndexPath;
CardModel *selectedCard;
- (void)cellMenuViewDeleteBtnTapped:(ABCellMenuView *)menuView {
    NSLog(@"cellMenuViewDeleteBtnTapped");
    selectedIndexPath = menuView.indexPath;
    selectedCard = menuView.cardmodel;


    //archiveCard = CardData;
    [self.archivePopupView show];
    return;
    // update data source
}

- (void)cellMenuViewMoreBtnTapped:(ABCellMenuView *)menuView
{
    NSLog(@"cellMenuViewMoreBtnTapped Delete Options");
    selectedIndexPath = menuView.indexPath;
    selectedCard = menuView.cardmodel;
    
    [PPAlertHelper showConfirmationIn:self title:kLang(@"DeleteCardAlert") subtitle:kLang(@"DeleteCardAlertDesc") confirmButton:kLang(@"yes") cancelButton:kLang(@"no") icon:PPSYSImage(@"trash") confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
        if(!didConfirm) return;
        [self deleteArchive:self.selectTableView
                  indexPath:selectedIndexPath];

        [self showSnakBar:kLang(@"DeletedSuccess")
                withColor:[GM appPrimaryColor]
              andDuration:3];
    } cancelBlock:^{
        
    }];

    
}

//[UIColor colorWithRed:39.0/255.0f green:174.0/255.0f blue:96.0/255.0f alpha:1.0]
- (void)showSnakBar:(NSString *)message withColor:(UIColor *)color andDuration:(float)duration
{
    self.snakBar = [[TTGSnackbar alloc]initWithMessage:[NSString stringWithFormat:@"%@", message] duration:duration];
    [self.snakBar setAnimationType:TTGSnackbarAnimationTypeSlideFromTopBackToTop];
    self.snakBar.containerView = self.view;
    [self.snakBar setMessageTextAlign:NSTextAlignmentCenter];
    [self.snakBar setMessageTextFont:[GM MidFontWithSize:14]];
    [self.snakBar setCornerRadius:20];
    self.snakBar.shouldDismissOnSwipe = YES;
    self.snakBar.snackbarMaxWidth = self.view.frame.size.width - 40;
    [self.snakBar setIconTintColor:[UIColor whiteColor]];
    [self.snakBar setBackgroundColor:color];

    [self.snakBar show];
}

- (void)refreshSelectedChild
{
    NSLog(@"refreshSelectedChild refreshSelectedChild refreshSelectedChild refreshSelectedChild refreshSelectedChild");
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}

#pragma mark - UITableViewDelegate methods



- (void)setReturnedMotherId:(NSString *)motherID; {
    // _motherRingID.text = motherID;
    NSLog(@"returnedMotherId %@", motherID);
}

/*
 #pragma mark - Navigation

   // In a storyboard-based application, you will often want to do a little preparation before navigation
   - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
   }
 */

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIEdgeInsets insets = tableView == self.selectTableView ?
        UIEdgeInsetsMake(8.0, 16.0, 8.0, 16.0) :
        UIEdgeInsetsMake(6.0, 12.0, 6.0, 12.0);
    cell.frame = UIEdgeInsetsInsetRect(cell.frame, insets);
    [self pp_styleTableCell:cell inTableView:tableView];

    if (reloadAnimationFlag == 0 && tableView == self.selectTableView) {
        cell.alpha = 0.0;
        cell.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
        [UIView animateWithDuration:0.35
                              delay:MIN(indexPath.row * 0.03, 0.18)
             usingSpringWithDamping:0.88
              initialSpringVelocity:0.2
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            cell.alpha = 1.0;
            cell.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)dismissBTN:(id)sender {
    //[self.delegate referchChils];
    [self dismissViewControllerAnimated:YES
                             completion:^{
    }];
}

- (void)addarchiveBTN:(id)sender {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

    [dateFormatter setDateFormat:@"dd/MM/yyyy"];
    // or @"yyyy-MM-dd hh:mm:ss a" if you prefer the time with AM/PM
    NSLocale *locale = [[NSLocale alloc]
                        initWithLocaleIdentifier:@"en"];
    [dateFormatter setLocale:locale];
    __block NSString *archiveOwnerID = UserManager.sharedManager.currentUser.ID;
    __block NSDate *archiveDate = [NSDate date];
    __block NSString *archiveTitle;
    
    [PPAlertHelper showTextFieldAlertIn:self title:kLang(@"addArchiveTitle") subtitle:kLang(@"EnterNewArchiveName") placeholder:kLang(@"ArchiveNameOrNumber") initialText:nil confirmText:kLang(@"save") cancelText:kLang(@"cancel") completion:^(NSString * _Nullable text, BOOL didConfirm) {
        
        if(!didConfirm) return;
        archiveTitle = text;
        
        if ([text isEqualToString:@""]) {
            return;
        }
        
        [PPHUD showLoading];
        NSString *UserID = UserManager.sharedManager.currentUser.ID;
        
        [dateFormatter setDateFormat:@"ddmmssSSS"];
        NSString *CreateDate = [dateFormatter stringFromDate:[NSDate date]];
        NSString *ID = [NSString stringWithFormat:@"ARC_%@_%@", UserID, CreateDate];
        NSDate *AddedDate = [NSDate date];
        NSMutableDictionary *Dic = [NSMutableDictionary new];
        [Dic setValue:ID
               forKey:@"ID"];
        [Dic setValue:archiveTitle
               forKey:@"archiveTitle"];
        [Dic setValue:archiveDate
               forKey:@"archiveDate"];
        [Dic setValue:UserID
               forKey:@"archiveOwnerID"];
        [Dic setValue:AddedDate
               forKey:@"CreateDate"];
        [Dic setValue:@0
               forKey:@"isDeleted"];
        
        FIRFirestore *db = [FIRFirestore firestore];
        FIRCollectionReference *ref = [db collectionWithPath:@"ArchiveCol"];
        
        [[ref documentWithPath:ID] setData:Dic
                                completion:^(NSError *_Nullable error) {
            if (error != nil) {
                NSLog(@"FireDB ---->>> Error While Inser Doc %@", error);
                return;
            }
            
            NSLog(@"FireDB ---->>> ALLL ARCHIVE DATA INSERTED IN ID %@", ID);
            
            ArchiveModel *ar = [ArchiveModel new];
            ar.ID = ID;
            ar.archiveTitle = archiveTitle;
            ar.archiveDate = archiveDate;
            ar.archiveOwnerID = archiveOwnerID;
            
            if (self.archiveArray.count == 0) {
                self.archiveArray = [NSMutableArray<ArchiveModel *>  new];
                [self.archiveArray addObject:ar];
                [self.archiveTableView reloadData];
                [PPHUD dismiss];
            } else {
                [self.archiveArray insertObject:ar
                                        atIndex:0];
                [self.archiveTableView reloadData];
                [PPHUD dismiss];
            }
            
            NSLog(@"FireDB ---->>> ARCHIVE DAT INSERTED IN ID %@", ID);
        }];
        
    }];
   
}

- (void)closeArchiveBTN:(id)sender {
    [self.archivePopupView dismiss:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

// Move ArchiveDetail to another archive
- (void)changeArchive:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
    if (tableView == _archiveTableView) {
        if (selectedIndexPath.row >= self.archiveDetails.count) { NSLog(@"❌ changeArchive: selectedIndexPath.row %ld out of bounds (archiveDetails.count=%lu)", (long)selectedIndexPath.row, (unsigned long)self.archiveDetails.count); return; }
        if (indexPath.row >= self.archiveArray.count) { NSLog(@"❌ changeArchive: indexPath.row %ld out of bounds (archiveArray.count=%lu)", (long)indexPath.row, (unsigned long)self.archiveArray.count); return; }
        CardModel *cardModel =  [[AppData.AllCardsDocs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", self.archiveDetails[selectedIndexPath.row].CardID]] firstObject];

        NSString *archiveTitle = [self.archiveArray objectAtIndex:indexPath.row].archiveTitle;
        NSString *title =  kLang(@"title_ArchiveAlert");
        NSString *subtitle1 = kLang(@"subtitle1_ArchiveAlert");
        NSString *subtitle2 = cardModel.CardTitle;
        NSString *subtitle3 = kLang(@"subtitle3_ArchiveAlert");
        NSString *subtitle4 = kLang(@"subtitle4_ArchiveAlert");
        NSString *subtitle = [NSString stringWithFormat:@"%@ (%@) %@ (%@) %@", subtitle1, subtitle2, subtitle3, archiveTitle, subtitle4];

        [PPAlertHelper showConfirmationIn:self title:title subtitle:subtitle confirmButton:kLang(@"yes") cancelButton:kLang(@"no") icon:PPSYSImage(@"arrow.trianglehead.2.counterclockwise") confirmBlock:^(NSString * _Nullable text, BOOL didConfirm) {
            if(!didConfirm) return;

            if (selectedIndexPath.row >= self.archiveDetails.count) { NSLog(@"❌ changeArchive block: selectedIndexPath.row %ld out of bounds", (long)selectedIndexPath.row); return; }
            ArchiveDetailsModel *detail = self.archiveDetails[selectedIndexPath.row];

            [PPHUD showLoading];

            [[ArchivesManager shared]
             moveArchiveDetail:detail
             toArchiveID:[self.archiveArray objectAtIndex:indexPath.row].ID
             completion:^(NSError *error)
             {
                 [PPHUD dismiss];
                 if (error) return;

                 if (selectedIndexPath.row < self.archiveDetails.count) {
                     [self.archiveDetails removeObjectAtIndex:selectedIndexPath.row];
                     [self pp_refreshHeaderContent];

                     [self.selectTableView deleteRowsAtIndexPaths:@[selectedIndexPath]
                                                 withRowAnimation:UITableViewRowAnimationLeft];
                 } else {
                     NSLog(@"❌ changeArchive completion: selectedIndexPath.row %ld out of bounds", (long)selectedIndexPath.row);
                 }

                 if ([self.delegate respondsToSelector:@selector(ReloadDataSourseDelegate)]) {
                     [self.delegate ReloadDataSourseDelegate];
                 }
             }];
        } cancelBlock:^{
        }];
        return;
    }
}


- (void)deleteArchive:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row >= self.archiveDetails.count) { NSLog(@"❌ deleteArchive: indexPath.row %ld out of bounds (archiveDetails.count=%lu)", (long)indexPath.row, (unsigned long)self.archiveDetails.count); [PPHUD dismiss]; return; }
    ArchiveDetailsModel *detail = self.archiveDetails[indexPath.row];
    NSString *cardID = detail.CardID;

    [PPHUD showLoading];

    [[ArchivesManager shared]
     deleteArchiveDetail:detail
     completion:^(NSError *error)
     {
         if (error) {
             [PPHUD dismiss];
             return;
         }
        [[ArchivesManager shared] syncDetailsCountForArchiveID:self.archiveClass.ID];
         FIRFirestore *db = [FIRFirestore firestore];

         // =====================================================
         // 1️⃣ Mark CARD as deleted (CardsCol)
         // =====================================================
         if (cardID.length) {
             FIRDocumentReference *cardRef =
             [[db collectionWithPath:@"CardsCol"] documentWithPath:cardID];

             [cardRef updateData:@{@"isDeleted": @1} completion:nil];
         }

         // =====================================================
         // 2️⃣ If this ArchiveDetail represents a CHILD
         //     mark Child.isDeleted = 1 inside ChildsArray
         // =====================================================
        if (detail.cardInfo == CardInfoKindCHILDCard && detail.CageID.length) {
             FIRDocumentReference *cageRef =
             [[db collectionWithPath:@"CagesCol"] documentWithPath:detail.CageID];

             [cageRef getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error)
             {
                 if (error || !snapshot.exists) return;

                 NSArray *childs = snapshot.data[@"ChildsArray"];
                 if (![childs isKindOfClass:NSArray.class]) return;

                 NSMutableArray *updated = [childs mutableCopy];

                 NSUInteger idx =
                 [updated indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop)
                 {
                     return [obj[@"CardID"] isEqualToString:cardID];
                 }];

                 if (idx != NSNotFound) {
                     NSMutableDictionary *child = [updated[idx] mutableCopy];
                     child[@"isDeleted"] = @1;
                     updated[idx] = child;

                     [cageRef updateData:@{@"ChildsArray": updated} completion:nil];
                 }
             }];
         }

         // =====================================================
         // 3️⃣ Update UI
         // =====================================================
         [PPHUD dismiss];

         if (indexPath.row < self.archiveDetails.count) {
             [self.archiveDetails removeObjectAtIndex:indexPath.row];
             [self pp_refreshHeaderContent];
             [self.selectTableView deleteRowsAtIndexPaths:@[indexPath]
                                         withRowAnimation:UITableViewRowAnimationLeft];
         } else {
             NSLog(@"❌ deleteArchive completion: indexPath.row %ld out of bounds after async", (long)indexPath.row);
         }

      }];
}

- (void)DeleteChild:(nonnull NSString *)CageID ChildRingID:(nonnull NSString *)ChildRingID childIndex:(NSInteger)childIndex childID:(nonnull NSString *)childID childModel:(nonnull ChildModel *)childModel { 
    
}

- (void)archiveCardData:(nonnull CardModel *)CardData cellIndexPath:(nonnull NSIndexPath *)cellIndexPath { 
    
}

- (void)cellClickArchive:(NSInteger)cellIndex { 
    
}

- (void)cellClickSell:(NSInteger)cellIndex childCard:(nonnull CardModel *)childCard { 
    
}

- (void)cellClickTransfer:(NSInteger)cellIndex { 
    
}


@end
