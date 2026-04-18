//
//  selectChildViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import "selectChildViewController.h"
#import "AppDelegate.h"
#import "JGProgressHUD.h"
#import "ImageModel.h"
#import "NewCardForm.h"
#import "IQKeyboardManager.h"
#import "PickerSheetViewController.h"
@interface selectChildViewController ()
<
UITableViewDelegate,
UITableViewDataSource,
RemoveChildDelegate,
goToNewCardDelegate,
UITextFieldDelegate,PPChildCellDelegate
>
@property (nonatomic, strong) UITableView *selectTableView;
@property (nonatomic, strong) PPS *ChickPPS;
@property (nonatomic, strong) ChildModel *selectedChild;
@property (nonatomic, strong) UIImageView *cageImageView;

@property (nonatomic, strong) NSDate *selectedBirthDate;
@property (nonatomic, strong) UIImage *addImage;
@property (nonatomic, strong) UIImage *addImageSelected;
@property (nonatomic, strong) NSLayoutConstraint *inputBottomConstraint;

@property (nonatomic, strong) NSMutableArray<CardModel *> *localCardsArray;
@property (nonatomic, strong) UIButton *headerCntainer;
@property (nonatomic, strong) UIButton *ChickPPSBgView;
@property (nonatomic, strong) NSLayoutConstraint *ppsBgTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *ppsBgBottomConstraint;
@property (nonatomic, strong) UILabel *headerNameLabel;
@property (nonatomic, strong) UILabel *headerCountLabel;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) NSMutableSet<NSString *> *pendingChildOperationIDs;
@property (nonatomic, assign) BOOL isFetchingChildren;
@property (nonatomic, assign) BOOL isUploadingChild;
@property (nonatomic, assign) BOOL keyboardManagerWasEnabled;

@end

@implementation selectChildViewController
- (void)onFilterTapped {
    // Deprecated — filter now handled by primary menu
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.modalInPresentation = YES;
    
    self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
   /*
    [self.headerCntainer layoutIfNeeded];

    CGFloat h = self.headerCntainer.bounds.size.height;
    UIButtonConfiguration *cfg = self.headerCntainer.configuration;

    cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    cfg.background.cornerRadius = h / 2.0;
    cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.0];
    cfg.baseBackgroundColor = UIColor.clearColor;

    self.headerCntainer.configuration = cfg;
    
    */
}

- (void)updateRightNavigationWithCageInfo
{
    NSString *cageName = PPSafeString(self.CageData.CageName);
    NSInteger count = self.ChildsdataSource.count;

    if (!self.headerCntainer) {
        self.headerCntainer = [self createTopBackground];
        self.headerCntainer.translatesAutoresizingMaskIntoConstraints = NO;

        self.headerNameLabel = [UILabel new];
        self.headerNameLabel.font = [GM boldFontWithSize:18];
        self.headerNameLabel.textColor = AppPrimaryTextClr;
        self.headerNameLabel.translatesAutoresizingMaskIntoConstraints = NO;

        self.headerCountLabel = [UILabel new];
        self.headerCountLabel.font = [GM MidFontWithSize:12];
        self.headerCountLabel.textColor = AppSecondaryTextClr;
        self.headerCountLabel.translatesAutoresizingMaskIntoConstraints = NO;

        UIButton *closeBtn = [PPButtonHelper buttonWithSystemName:@"multiply"
                                                           target:self
                                                           action:@selector(onDissmiss)];
        closeBtn.translatesAutoresizingMaskIntoConstraints = NO;

        self.cageImageView = [[UIImageView alloc] initWithImage:PPImage(@"love-birdsCus.fill")];
        self.cageImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.cageImageView.layer.cornerRadius = 0;
        self.cageImageView.clipsToBounds = YES;
        self.cageImageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.headerCntainer addSubview:self.cageImageView];

        UIStackView *topRow = [[UIStackView alloc] initWithArrangedSubviews:@[
            self.headerNameLabel,
            self.headerCountLabel
        ]];
        topRow.axis = UILayoutConstraintAxisVertical;
        topRow.alignment = UIStackViewAlignmentLeading;
        topRow.spacing = 2;
        topRow.translatesAutoresizingMaskIntoConstraints = NO;

        [self.view addSubview:self.headerCntainer];
        [self.headerCntainer addSubview:topRow];
        [self.headerCntainer addSubview:closeBtn];

        [NSLayoutConstraint activateConstraints:@[
            [self.headerCntainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
            [self.headerCntainer.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
            [self.headerCntainer.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
            [self.headerCntainer.heightAnchor constraintEqualToConstant:60],

            [self.cageImageView.centerYAnchor constraintEqualToAnchor:self.headerCntainer.centerYAnchor constant:-5],
            [self.cageImageView.leadingAnchor constraintEqualToAnchor:self.headerCntainer.leadingAnchor constant:12],
            [self.cageImageView.heightAnchor constraintEqualToConstant:34],
            [self.cageImageView.widthAnchor constraintEqualToConstant:34],

            [topRow.topAnchor constraintEqualToAnchor:self.headerCntainer.topAnchor constant:12],
            [topRow.leadingAnchor constraintEqualToAnchor:self.cageImageView.trailingAnchor constant:12],
            [topRow.trailingAnchor constraintEqualToAnchor:self.headerCntainer.trailingAnchor constant:-12],

            [closeBtn.widthAnchor constraintEqualToConstant:44],
            [closeBtn.heightAnchor constraintEqualToConstant:44],
            [closeBtn.trailingAnchor constraintEqualToAnchor:self.headerCntainer.trailingAnchor constant:-12],
            [closeBtn.centerYAnchor constraintEqualToAnchor:self.headerCntainer.centerYAnchor],
        ]];

        UIButtonConfiguration *cfg = self.headerCntainer.configuration;
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.baseBackgroundColor = UIColor.clearColor;
        self.headerCntainer.configuration = cfg;
    }

    self.headerNameLabel.text = cageName.length ? cageName : kLang(@"Cage");
    self.headerCountLabel.text =
    [NSString stringWithFormat:@"%@   %ld",
     kLang(@"Children"),
     (long)count];
  
}



#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupState];
    [self setupTableView];
    [self setupChickPPS];
    [self setupKeyboardHandling];
    [self fetchChildren];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Setup

- (void)setupState
{
    
    self.ChildsdataSource = [NSMutableArray new];
    self.localCardsArray = AppData.AllCardsDocs.mutableCopy;
    self.selectedBirthDate = [NSDate date];
    self.pendingChildOperationIDs = [NSMutableSet set];
}

- (void)setupTableView
{
    self.selectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.selectTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectTableView.delegate = self;
    self.selectTableView.dataSource = self;
    self.selectTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.selectTableView.backgroundColor = UIColor.clearColor;
    self.selectTableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.selectTableView.tableFooterView = [UIView new];

    [self.selectTableView registerClass:[PPChildCell class]
                 forCellReuseIdentifier:[PPChildCell reuseIdentifier]];

    [self.view addSubview:self.selectTableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.selectTableView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0],
        [self.selectTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.selectTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.selectTableView addGestureRecognizer:tap];
    
    self.selectTableView.contentInset = UIEdgeInsetsMake(70, 0, 80, 0);
    [self setupEmptyStateView];
}



#pragma mark - Keyboard

- (void)setupKeyboardHandling
{
    self.keyboardManagerWasEnabled = [IQKeyboardManager sharedManager].enable;
    [IQKeyboardManager sharedManager].enable = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

-(void)keyboardWillShow:(NSNotification *)n
{
    CGRect kb = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.inputBottomConstraint.constant = -kb.size.height -16;
    [UIView animateWithDuration:0.25 animations:^{
       // [self.ChickPPS updateGlassBackgroundColor:AppPrimaryClr opacity:0.8];
       // self.ChickPPS.backgroundColor = [AppForgroundColr colorWithAlphaComponent:1.0];
        self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
        self.modalInPresentation = YES;
      //  self.ChickPPSBgView.alpha = 1.0;
        [self.view layoutIfNeeded];
    }];
}

-(void)keyboardWillHide:(NSNotification *)n
{
    self.inputBottomConstraint.constant = -16;
    [UIView animateWithDuration:0.25 animations:^{
        //[self.ChickPPS updateGlassBackgroundColor:AppForgroundColr opacity:1];
        //self.ChickPPS.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.8];
        self.view.backgroundColor = PPBackgroundColorForIOS26(AppBackgroundClr);
        self.modalInPresentation = YES;
       // self.ChickPPSBgView.alpha = 0.0;
        [self.view layoutIfNeeded];
    }];
}

- (void)dismissKeyboard
{
    [self.view endEditing:YES];
}

#pragma mark - Data

- (void)fetchChildren
{
    if (self.isFetchingChildren || self.CageData.ID.length == 0) {
        [self updateEmptyState];
        return;
    }

    self.isFetchingChildren = YES;
    NSLog(@"🐣 [fetchChildren] Start — CageID: %@", self.CageData.ID);

    [PPHUD showLoading];

    __weak typeof(self) weakSelf = self;
    [ChildsDataManager fetchChildrenForCageID:self.CageData.ID
                                   completion:^(NSArray<ChildModel *> *children,
                                                NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            strongSelf.isFetchingChildren = NO;
            [PPHUD dismiss];

            if (error) {
                NSLog(@"❌ [fetchChildren] Failed — CageID: %@ | Error: %@",
                      strongSelf.CageData.ID,
                      error.localizedDescription);
                [strongSelf updateEmptyState];
                return;
            }

            NSLog(@"✅ [fetchChildren] Success — CageID: %@ | Count: %lu",
                  strongSelf.CageData.ID,
                  (unsigned long)children.count);

            strongSelf.ChildsdataSource = children.mutableCopy ?: [NSMutableArray array];
            strongSelf.localCardsArray = AppData.AllCardsDocs.mutableCopy;
            [strongSelf.selectTableView reloadData];
            [strongSelf updateRightNavigationWithCageInfo];
            [strongSelf updateEmptyState];
        });
     }];
}

#pragma mark - Actions

- (void)addChildBTN:(id)sender
{
    if (self.isUploadingChild) {
        return;
    }

    NSString *ring =
    [self.ChickPPS.textField.text stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (ring.length == 0) {
        [[AppManager sharedInstance]
         showSnakBar:kLang(@"AddRingIDFirst")
         withColor:[GM appPrimaryColor]
         andDuration:3
         containerView:self.headerCntainer];
        

        self.ChickPPS.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];

        
        return;
    }

    for (ChildModel *existingChild in self.ChildsdataSource) {
        if ([existingChild.ChildRingID caseInsensitiveCompare:ring] == NSOrderedSame &&
            existingChild.isDeleted != 1) {
            [[AppManager sharedInstance]
             showSnakBar:kLang(@"youHaveBird")
             withColor:[GM appPrimaryColor]
             andDuration:3
             containerView:self.headerCntainer ?: self.view];
            return;
        }
    }

    for (CardModel *card in AppData.AllCardsDocs) {
        if ([card.RingID caseInsensitiveCompare:ring] == NSOrderedSame &&
            card.isDeleted != 1) {
            [[AppManager sharedInstance]
             showSnakBar:kLang(@"youHaveBird")
             withColor:[GM appPrimaryColor]
             andDuration:3
             containerView:self.headerCntainer ?: self.view];
            return;
        }
    }

    self.ChickPPS.textField.text = ring;
    [self uploadChild];
}

- (void)onBirthDateChanged:(UIDatePicker *)picker
{
    self.selectedBirthDate = picker.date;
}

#pragma mark - TableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.ChildsdataSource.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 90;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PPChildCell *cell =
    [tableView dequeueReusableCellWithIdentifier:[PPChildCell reuseIdentifier]
                                    forIndexPath:indexPath];
    cell.delegate = self;
    if (indexPath.row >= self.ChildsdataSource.count) { NSLog(@"❌ cellForRowAtIndexPath: row %ld out of bounds (ChildsdataSource.count=%lu)", (long)indexPath.row, (unsigned long)self.ChildsdataSource.count); return cell; }
    [cell configureWithChild:self.ChildsdataSource[indexPath.row]];
    return cell;
}









































-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

- (void)scrollToBottom {
    if (self.ChildsdataSource.count == 0) return;
    NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:self.ChildsdataSource.count - 1 inSection:0];
    [self.selectTableView scrollToRowAtIndexPath:lastIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}
  
-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.CageData.ID.length > 0) {
        [ChildsDataManager syncDetailsCountForCageID:self.CageData.ID completion:^(NSError * _Nullable error) {
            
        }];
    }

    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [IQKeyboardManager sharedManager].enable = self.keyboardManagerWasEnabled;
    }
}
- (void)RemoveChild:(ChildModel *)child
{
    [self DeleteChild:child FromCageWithID:child.CageID];
}
- (void)DeleteChild:(ChildModel *)childModel FromCageWithID:(NSString *)CageID
{
    if (!childModel || !childModel.ID.length || !CageID.length) {
        return;
    }

    if ([self.pendingChildOperationIDs containsObject:childModel.ID]) {
        return;
    }
    [self.pendingChildOperationIDs addObject:childModel.ID];

    [PPHUD showLoading];
    __weak typeof(self) weakSelf = self;
    [ChildsDataManager setChildDeleted:YES
                           forChildID:childModel.ID
                               cageID:CageID
                           completion:^(NSError * _Nullable error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            [strongSelf.pendingChildOperationIDs removeObject:childModel.ID];

            if (error) {
                NSLog(@"❌ [DeleteChild] Firestore ERROR: %@", error.localizedDescription);
                [PPHUD dismiss];
                return;
            }

            [strongSelf removeChildFromUI:childModel];
            [PPHUD dismiss];
            [strongSelf showSnakeBarWithUndoAndText:kLang(@"ChildMovedToTrash")
                                              Child:childModel];
        });
    }];
}

- (void)moveChildToTrashAndDelete:(ChildModel *)child
{
    [PPHUD showLoading];
    NSString *userID = UserManager.sharedManager.currentUser.ID;
    NSString *cageID = self.CageData.ID;

    // 1️⃣ Resolve card
    CardModel *card =
    [[AppData.AllCardsDocs filteredArrayUsingPredicate:
      [NSPredicate predicateWithFormat:@"ID == %@", child.CardID]] firstObject];

    NSString *title = card.CardTitle ?: @"";
    NSString *imageUrl = @"";

    if (card.imagesUrls.count > 0) {
        imageUrl = PPSafeString(card.imagesUrls.firstObject.absoluteString);
    }

    // 2️⃣ Build Trash document
    NSString *trashID =
    [NSString stringWithFormat:@"TRASH_%@_%@", userID, child.ID];

    NSDictionary *trashData = @{
        @"ID": trashID,
        @"ownerID": userID,
        @"RefType": @(RefTypeChild),
        @"RefID": child.ID,
        @"CardID": child.CardID ?: @"",
        @"CageID": child.CageID ?: @"",
        @"title": title,
        @"imageUrl": imageUrl,
        @"DeletedAt": [NSDate date],
        @"isDeleted": @1,
        @"cameFrom": @(CameFromChilds)
    };

    FIRFirestore *db = [FIRFirestore firestore];

    // 3️⃣ Write Trash
    [[[db collectionWithPath:@"TrashCol"]
      documentWithPath:trashID] setData:trashData];

    // 4️⃣ Soft delete child
    [ChildsDataManager setChildDeleted:YES
                            forChildID:child.ID
                               cageID:cageID
                            completion:^(NSError * _Nullable error)
    {
        if (error) {
            NSLog(@"❌ Delete child failed: %@", error);
            return;
        }

        // 5️⃣ UI update
        [self removeChildFromUI:child];
        [PPHUD dismiss];
        // 6️⃣ Snackbar with undo
        [self showUndoSnackbarForChild:child];
        
        
    }];
}

- (void)removeChildFromUI:(ChildModel *)child
{
    NSInteger index =
    [ChildsDataManager indexOfChild:child inArray:self.ChildsdataSource];

    if (index < 0 || index >= (NSInteger)self.ChildsdataSource.count) { NSLog(@"❌ removeChildFromUI: index %ld out of bounds (count=%lu)", (long)index, (unsigned long)self.ChildsdataSource.count); return; }

    [self.ChildsdataSource removeObjectAtIndex:index];
    [self.selectTableView reloadData];

    [self updateRightNavigationWithCageInfo];
    [self updateEmptyState];
}


- (void)showUndoSnackbarForChild:(ChildModel *)child
{
    TTGSnackbar *snackbar =
    [[TTGSnackbar alloc] initWithMessage:kLang(@"ChildMovedToTrash")
                                duration:TTGSnackbarDurationLong];

    snackbar.actionText = kLang(@"Undo");
    snackbar.actionTextColor = AppPrimaryClr;
    snackbar.messageTextColor = UIColor.whiteColor;
    snackbar.backgroundColor = AppPrimaryClr;
    snackbar.cornerRadius = 22;

    __weak typeof(self) weakSelf = self;
    snackbar.actionBlock = ^(TTGSnackbar * _Nonnull bar) {
        [weakSelf restoreChild:child];
    };

    [snackbar show];
}

- (void)restoreChild:(ChildModel *)child
{
    if (!child.ID.length || !child.CageID.length) {
        return;
    }

    if ([self.pendingChildOperationIDs containsObject:child.ID]) {
        return;
    }

    [self.pendingChildOperationIDs addObject:child.ID];
    [PPHUD showLoading];

    __weak typeof(self) weakSelf = self;
    [ChildsDataManager setChildDeleted:NO
                            forChildID:child.ID
                                cageID:child.CageID
                            completion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            [strongSelf.pendingChildOperationIDs removeObject:child.ID];
            [PPHUD dismiss];

            if (error) {
                NSLog(@"❌ Restore child failed: %@", error);
                return;
            }

            if (![strongSelf.ChildsdataSource containsObject:child]) {
                [strongSelf.ChildsdataSource addObject:child];
            }
            [strongSelf.selectTableView reloadData];
            [strongSelf updateRightNavigationWithCageInfo];
            [strongSelf updateEmptyState];

            [[AppManager sharedInstance]
             showSnakBar:kLang(@"RestoredSuccessfully")
             withColor:[GM appPrimaryColor]
             andDuration:2
             containerView:strongSelf.selectTableView];
        });
    }];
}






// MARK: - Card Options
-(void)archiveCardData:(CardModel *)CardData Child:(nullable ChildModel *)child
{

    ArchiveManagerVC *VC= [ArchiveManagerVC new];
    VC.cardToArchive =  CardData;
    VC.FromVC = 1;
    VC.delegate = self;
    if(child)
    {
        VC.childToArchive = child;
        self.selectedChild = child;
    }
     [PPFunc presentSheetFrom:self sheetVC:VC detentStyle:PPSheetDetentStyleProfile];
}

-(void)DeleteChild:(NSString *)CageID
       ChildRingID:(NSString *)ChildRingID
        childIndex:(NSInteger)childIndex
           childID:(NSString *)childID
        childModel:(ChildModel *)childModel
{
    [self DeleteChild:childModel FromCageWithID:CageID];
}



-(void)refreshSelectedChild
{
 
  //  NSLog(@"refreshSelectedChild refreshSelectedChild refreshSelectedChild refreshSelectedChild refreshSelectedChild");
    [_selectTableView reloadData];
}

-(void)goToNewCard:(NSString *)RingID fromVC:(NSString *)fromVc isFound:(int)isFound ImagesArr:(nonnull NSArray<ImageModel *> *)ImagesArr cardID:(nonnull NSString *)cardID
{
    self.localCardsArray = AppData.AllCardsDocs;
    CardModel *serverCardModel = [[self.localCardsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.ID == %@", cardID]] firstObject];

    if (serverCardModel) {
        viewDataVC *add = [viewDataVC new];
        add.cardModel = serverCardModel;
        [PPFunc presentSheetFrom:self sheetVC:add detentStyle:PPSheetDetentStyle80];
        return;
    }

    NewCardForm *vc = [NewCardForm new];
    vc.FromVC = @"childs";
    vc.prefilledRingID = RingID;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
   // NSLog(@"selectedLoacalIndexPath row %ld \n  selectedLoacalIndexPath section  %ld ",selectedLoacalIndexPath.row,selectedLoacalIndexPath.section);
   
      //  selectedLoacalIndexPath = indexPath;
    
    
}

-(void)sellChild:(ChildModel *)childModel cardID:(nonnull CardModel *)card
{
    buyerDataVC *vc = [buyerDataVC new];
     vc.serverCardClass = card;
    [self presentViewController:vc
                         inSize:CGSizeMake(self.view.frame.size.width, self.view.frame.size.height * 0.7)
                      direction:PVCDirectionBottom
                     completion:^{
    }];
}


- (void)delayedMethod
{
    NSLog(@"Executed after delay – reloading childs from ChildsCol");
    [PPHUD showLoading];
    [ChildsDataManager fetchChildrenForCageID:self.CageData.ID
                                   completion:^(NSArray<ChildModel *> *children,
                                                NSError *error)
    {
       

        if (error) {
            NSLog(@"❌ delayedMethod fetch error: %@", error);
            return;
        }

        self.ChildsdataSource = children.mutableCopy;
        [self.selectTableView reloadData];
        [PPHUD dismiss];
    }];
}


-(void)transferChild:(ChildModel *)childModel cardID:(nonnull CardModel *)card
{
 
    PickerSheetViewController *pickerSheet =[PickerSheetViewController new];
    pickerSheet.pick = PickSunCage;

    pickerSheet.cageCompletionHandler = ^(CageModel *selectedcage) {

        NSString *title = kLang(@"transferToBox");
        NSString *subtitle = kLang(@"transferToBoxDesc");

        [PPAlertHelper showConfirmationIn:self
                                    title:title
                                 subtitle:subtitle
                            confirmButton:kLang(@"yes")
                             cancelButton:kLang(@"no")
                                     icon:nil
                              confirmBlock:^(NSString * _Nullable text, BOOL didConfirm)
        {
            if (!didConfirm) return;
            [PPHUD showLoading];
            
            FIRFirestore *db = [FIRFirestore firestore];
            FIRWriteBatch *batch = [db batch];

            NSString *childID   = childModel.ID;
            NSString *oldCageID = self.CageData.ID;
            NSString *newCageID = selectedcage.ID;

            // ===============================
            // OLD child → Away
            // ===============================
            FIRDocumentReference *oldChildRef =
            [[[[db collectionWithPath:@"CagesCol"]
               documentWithPath:oldCageID]
              collectionWithPath:@"ChildsCol"]
             documentWithPath:childID];

            [batch updateData:@{
                @"childBox": @(ChildBoxAway),
                @"childBoxID": newCageID
            } forDocument:oldChildRef];

            // ===============================
            // NEW child → Guest
            // ===============================
            NSString *newChildID =
            [NSString stringWithFormat:@"%@_%@",
             UserManager.sharedManager.currentUser.ID,
             @(NSDate.date.timeIntervalSince1970)];

            ChildModel *newChild = [ChildModel new];
            newChild.ID = newChildID;
            newChild.CageID = newCageID;
            newChild.CardID = childModel.CardID;
            newChild.ChildRingID = childModel.ChildRingID;
            newChild.UserID = childModel.UserID;
            newChild.childBox = ChildBoxGuest;
            newChild.childBoxID = oldCageID;
            newChild.addingDate = [NSDate date];
            newChild.lastUpdated = [NSDate date];

            FIRDocumentReference *newChildRef =
            [[[[db collectionWithPath:@"CagesCol"]
               documentWithPath:newCageID]
              collectionWithPath:@"ChildsCol"]
             documentWithPath:newChildID];

            [batch setData:[newChild dictionaryRepresentation]
                forDocument:newChildRef];

            // ===============================
            // Card → new cage
            // ===============================
            FIRDocumentReference *cardRef =
            [[db collectionWithPath:@"CardsCol"]
             documentWithPath:childModel.CardID];

            [batch updateData:@{@"CageID": newCageID}
                forDocument:cardRef];

            // ===============================
            // COMMIT
            // ===============================
            [batch commitWithCompletion:^(NSError * _Nullable error) {

                if (error) {
                    NSLog(@"❌ Transfer batch failed: %@", error);
                    return;
                }

                NSInteger index = [ChildsDataManager indexOfChild:childModel inArray:self.ChildsdataSource];
                if (index >= 0 && index < (NSInteger)self.ChildsdataSource.count)
                {
                    [self.ChildsdataSource removeObjectAtIndex:index];
                    [self.selectTableView reloadData];
                }
                
                [PPHUD dismiss];
                [[AppManager sharedInstance]
                 showSnakBar:kLang(@"transferSuccess")
                 withColor:[GM appPrimaryColor]
                 andDuration:3
                 containerView:self.headerCntainer];
            }];
             
            
        }  cancelBlock:^{}];
    };

    if (@available(iOS 15.0, *)) {
        pickerSheet.modalPresentationStyle = UIModalPresentationPageSheet;
    } else {
        pickerSheet.modalPresentationStyle = UIModalPresentationFormSheet;
    }

    [self presentViewController:pickerSheet animated:YES completion:nil];
}

 

-(NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
 
    return indexPath;
 
}


-(void)setReturnedMotherId:(NSString *)motherID;
{
    // _motherRingID.text = motherID;
    NSLog(@"returnedMotherId %@",motherID);
}

 
- (IBAction)dismissBTN:(id)sender {
    // [self.delegate referchChils:TRUE];
    [self dismissViewControllerAnimated:YES completion:^{ }];
}


-(void)updateTable:(NSString *)CardID ID:(NSString *)ID
{

    ChildModel *ch = [[ChildModel alloc]init] ;
    ch.ChildRingID = self.ChickPPS.textField.text;
    ch.CardID = CardID;
    ch.ID = ID;
    if(self.ChildsdataSource.count == 0){
        self.ChildsdataSource = [NSMutableArray new];
        [self.ChildsdataSource addObject:ch];
    }
    else
        [self.ChildsdataSource addObject:ch];
    
    
    self.ChickPPS.textField.text = @"";
    [_selectTableView reloadData];
   
}

-(void)uploadChild
{
    if (self.isUploadingChild) {
        return;
    }

    [PPHUD showLoading];
    self.isUploadingChild = YES;
    self.ChickPPS.secondaryButton.enabled = NO;

    CardModel *fatherCard =
    [[AppData.AllCardsDocs filteredArrayUsingPredicate:
      [NSPredicate predicateWithFormat:@"ID == %@", _CageData.FatherRingID]] firstObject];

    NSString *ChickID =
    [self.ChickPPS.textField.text stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *UserID = UserManager.sharedManager.currentUser.ID;
    NSString *CardID = [NSString stringWithFormat:@"%@", UUIDJoin(ChickID)];
    NSDate *birthDate = self.selectedBirthDate ?: [NSDate date];
    NSDate *now = [NSDate date];

    NSInteger subKind = fatherCard.SubKind;
    if (subKind <= 0 && self.CageData.FatherCard) {
        subKind = self.CageData.FatherCard.SubKind;
    }

    if (subKind <= 0) {
        [PPHUD dismiss];
        self.isUploadingChild = NO;
        self.ChickPPS.secondaryButton.enabled = YES;
        [PPAlertHelper showFailIn:self
                            title:kLang(@"create_card_failed_title")
                         subtitle:kLang(@"create_card_failed_subtitle")
                       completion:^{
                           
                       }];
        return;
    }

    NSMutableDictionary *cardDic = @{
        @"ID": CardID,
        @"RingID": ChickID,
        @"SubKind": @(subKind),
        @"BirthDate": birthDate,
        @"AddedDate": now,
        @"lastUpdated": now,
        @"FatherRingID": _CageData.FatherRingID ?: @"",
        @"MotherRingID": _CageData.MotherRingID ?: @"",
        @"UserID": UserID ?: @"",
        @"CageID": _CageData.ID ?: @"",
        @"CardLocation": @"new_child",
        @"cardSection": @(CardSectionNewChild),
        @"isDeleted": @(0),
        @"isSold": @(0),
        @"soldPrice": @""
    }.mutableCopy;

    ChildModel *child = [ChildModel new];
    child.ID = UUIDJoin(@"CHILD");
    child.CageID = self.CageData.ID;
    child.ChildRingID = ChickID;
    child.CardID = CardID;
    child.UserID = UserID;
    child.addingDate = now;
    child.lastUpdated = now;
    child.BirthDate = birthDate;
    child.isDeleted = 0;
    child.isSold = 0;
    child.childBox = ChildBoxHome;
    child.childBoxID = @"";

    FIRFirestore *db = [FIRFirestore firestore];
    FIRDocumentReference *cardRef =
    [[db collectionWithPath:@"CardsCol"] documentWithPath:CardID];
    FIRDocumentReference *childRef =
    [[[[db collectionWithPath:@"CagesCol"] documentWithPath:self.CageData.ID]
      collectionWithPath:@"ChildsCol"] documentWithPath:child.ID];

    FIRWriteBatch *batch = [db batch];
    [batch setData:cardDic forDocument:cardRef];
    [batch setData:[child dictionaryRepresentation] forDocument:childRef];

    [batch commitWithCompletion:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isUploadingChild = NO;
            self.ChickPPS.secondaryButton.enabled = YES;
            if (error) {
                [PPHUD dismiss];
                self.ChickPPS.secondaryButton.selected = NO;
                [self.ChickPPS.btn2 setImage:self.addImage forState:UIControlStateNormal];
                [PPAlertHelper showFailIn:self
                                    title:kLang(@"create_card_failed_title")
                                 subtitle:kLang(@"create_card_failed_subtitle")
                               completion:^{
                                   
                               }];
                NSLog(@"❌ Card/Child batch insert failed: %@", error);
                return;
            }

            [ChildsDataManager syncDetailsCountForCageID:self.CageData.ID
                                              completion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"⚠️ syncDetailsCountForCageID failed after add child: %@", error);
                }
            }];

            [PPHUD dismiss];
            self.ChickPPS.secondaryButton.selected = NO;
            [self.ChickPPS.btn2 setImage:self.addImage forState:UIControlStateNormal];

            [[AppManager sharedInstance]
             showSnakBar:kLang(@"chicksAddedSucssesfuly")
             withColor:[GM appPrimaryColor]
             andDuration:3
             containerView:self.headerCntainer];

            [self.ChildsdataSource addObject:child];
            self.ChickPPS.textField.text = @"";
            [self.selectTableView reloadData];
            [self updateRightNavigationWithCageInfo];
            [self updateEmptyState];
        });
    }];
}


-(void)moveToBox
{
    //  NSString *CardID = self.ChildsdataSource[self.selectedChildIndex].CardID;
    //  NSString *ChildID = self.ChildsdataSource[self.selectedChildIndex].ID;
}


-(void)showSnakeBarWithUndoAndText:(NSString *)text Child:(ChildModel *)child
{
    TTGSnackbar *snackbar =
    [[TTGSnackbar alloc] initWithMessage:text
                                duration:TTGSnackbarDurationLong];

    snackbar.actionText = kLang(@"Undo");
    snackbar.actionTextColor = [GM appPrimaryColor];
    snackbar.messageTextColor = UIColor.whiteColor;
     snackbar.cornerRadius = 22;
    snackbar.topMargin = 16;
    snackbar.shouldDismissOnSwipe = YES;
    snackbar.backgroundColor = [AppPrimaryClr colorWithAlphaComponent:1.0];
    //snackbar.actionTextColor = UIColor.whiteColor;
    __weak typeof(self) weakSelf = self;
    snackbar.actionBlock = ^(TTGSnackbar * _Nonnull snake) {
        [weakSelf restoreChild:child];
    };
    
    
    //snackbar.actionTextFont = [GM boldFontWithSize:16];
    snackbar.messageTextFont = [GM boldFontWithSize:16];
    snackbar.separateViewBackgroundColor = AppClearClr;
    snackbar.actionMaxWidth = self.view.hx_w - 40;
    //snackbar.actionTextNumberOfLines = 2;
    snackbar.iconImageView.image = [UIImage systemImageNamed:@"arrow.uturn.backward.circle"];
    snackbar.iconContentMode = UIViewContentModeScaleToFill;
    snackbar.iconTintColor = AppForgroundColr;
    //snackbar.separateViewBackgroundColor = AppForgroundColr;
    snackbar.containerView.semanticContentAttribute = GM.setSemantic;
    [snackbar setMessageTextAlign:NSTextAlignmentCenter];
    [snackbar setMessageTextFont:[GM boldFontWithSize:16]];
    [snackbar show];
}
//actionMaxWidth //actionTextNumberOfLines // iconImageView  //iconContentMode  //iconTintColor  //iconImageViewWidth  // separateViewBackgroundColor  //animationType   //     //   //     //   //




- (UIButton *)createCategoriesBackground
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration clearGlassButtonConfiguration];
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleFixed;
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];
        cfg.baseBackgroundColor = UIColor.clearColor;
        cfg.background.cornerRadius = 0;

        
        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
      } else {
         

        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}

- (UIButton *)createTopBackground
{
    UIButton *bgButton;
    if (@available(iOS 26.0, *)) {
        // 🧊 iOS 26+ system glass button
        UIButtonConfiguration *cfg = [UIButtonConfiguration glassButtonConfiguration];
        
        cfg.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        cfg.background.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.5];
        cfg.baseBackgroundColor = UIColor.clearColor;
        cfg.background.cornerRadius = 0;

        
        bgButton = [UIButton  buttonWithType:UIButtonTypeSystem];
        bgButton.configuration = cfg;
      } else {
         

        // 🌫️ Fallback for iOS <26
        bgButton = [UIButton buttonWithType:UIButtonTypeSystem];
        bgButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        bgButton.layer.cornerRadius = 16;
        bgButton.layer.masksToBounds = YES;
        [bgButton pp_setShadowColor:AppShadowClr];
        bgButton.layer.shadowOpacity = 0.15;
        bgButton.layer.shadowRadius = 8;
        bgButton.layer.shadowOffset = CGSizeMake(0, 4);
    }

    bgButton.translatesAutoresizingMaskIntoConstraints = NO;
    return bgButton;
}


- (void)setupChickPPS {
    if (self.ChickPPS) return;

    self.ChickPPS = [[PPS alloc] initWithFrame:CGRectZero];
    self.ChickPPS.translatesAutoresizingMaskIntoConstraints = NO;
    self.ChickPPS.delegate = (id<PPSDelegate>)self;
    self.ChickPPS.barStyle = PPSBarStyleTextfield;
    // ChickPPS background view (shown only with keyboard)
    self.ChickPPSBgView = [self createCategoriesBackground];
    self.ChickPPSBgView.translatesAutoresizingMaskIntoConstraints = NO;
     self.ChickPPSBgView.alpha = 1.0;
 
    [self.view addSubview:self.ChickPPSBgView ];

  

    self.ChickPPS.blurEnabled = YES;
    self.ChickPPS.shadowEnabled = YES;
    self.ChickPPS.debounceInterval = 0.16;
    self.ChickPPS.fuzzyEnabled = YES;
    self.ChickPPS.caseInsensitive = NO;
    self.ChickPPS.diacriticsInsensitive = NO;
    self.ChickPPS.minRelevanceScore = 0.35;
    self.ChickPPS.maxResults = 100;
   
    self.ChickPPS.backgroundColor = [AppForgroundColr colorWithAlphaComponent:0.9];
    self.inputBottomConstraint =
    [self.ChickPPS.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16];
    // Buttons
    //UIImage *fil = [UIImage systemImageNamed:@"line.3.horizontal.decrease.circle"];
    //[_vc.searchView configurePrimaryButtonWithImage:fil target:self action:@selector(onFilterTapped:)];
    self.ChickPPS.showsPrimaryButton = YES;
    self.ChickPPS.showsSecondaryButton = YES;

    // Localization
    self.ChickPPS.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];

    // Appearance
    self.ChickPPS.shadowEnabled = YES;
    self.ChickPPS.blurEnabled = YES;
    self.ChickPPS.glassAlpha = 0.0;
    self.ChickPPS.returnKeyType = UIReturnKeyDone;
    self.ChickPPS.debounceInterval = 0.18;

    // Placeholder
    self.ChickPPS.textField.placeholder = kLang(@"Enter chick ring ID");
     
    [self.view addSubview:self.ChickPPS];
    
    
    self.addImage = [UIImage pp_symbolNamed:@"arrow.up.circle.dotted" pointSize:22 weight:UIImageSymbolWeightMedium scale:UIImageSymbolScaleLarge palette:@[UIColor.grayColor,UIColor.grayColor] makeTemplate:YES];
    
        
    self.addImageSelected = [UIImage pp_symbolNamed:@"arrow.up.circle" pointSize:22 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleLarge palette:@[UIColor.grayColor,AppPrimaryClr] makeTemplate:YES];
    UIImage *dateImage = [UIImage imageNamed:@"calendarCus"];

    // you can access Primary at  search.btn1
    //[self.ChickPPS configurePrimaryButtonWithImage:addImage selectedImage:addImageSelected target:self action:@selector(addChildBTN:)];
    //[self.ChickPPS configureSecondaryButtonWithImage:dateImage target:self action:@selector(showDatePicker:)];
    [self.ChickPPS configureSecondaryButtonWithImage:self.addImage target:self action:@selector(addChildBTN:)];
    [self.ChickPPS configurePrimaryButtonWithImage:dateImage target:nil action:nil];
   
    
    self.ChickPPS.showsPrimaryButton = NO;
    self.ChickPPS.showsSecondaryButton = YES;
    self.ChickPPS.showsDateButton = YES;
    self.ChickPPS.primaryButton.imageEdgeInsets = UIEdgeInsetsMake(4,
                                                                   4,
                                                                   4,
                                                                   4);
    self.ChickPPS.btn2.clipsToBounds = NO;
    self.ChickPPS.btn2.layer.masksToBounds = NO;
    
    //self.ChickPPS.dateButton.clipsToBounds = NO;
    //self.ChickPPS.dateButton.layer.masksToBounds = NO;
    
    
    if (self.addImageSelected) {
        [self.ChickPPS.btn1 setImage:self.addImageSelected forState:UIControlStateSelected];
    }
    self.ChickPPS.strokeColor = [AppForgroundColr colorWithAlphaComponent:1.0];
    self.ChickPPS.vcParent = self;
    
    [NSLayoutConstraint activateConstraints:@[
        // ChickID
        self.inputBottomConstraint,
        [self.ChickPPS.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.ChickPPS.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.ChickPPS.heightAnchor constraintEqualToConstant:60],

        

        // Table bottom
        [self.selectTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    self.ppsBgTopConstraint =
    [self.ChickPPSBgView.topAnchor constraintEqualToAnchor:self.ChickPPS.topAnchor constant:-16];

    self.ppsBgBottomConstraint =
    [self.ChickPPSBgView.bottomAnchor constraintEqualToAnchor:self.ChickPPS.bottomAnchor constant:100];

    [NSLayoutConstraint activateConstraints:@[
        self.ppsBgTopConstraint,
        self.ppsBgBottomConstraint,
        [self.ChickPPSBgView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.ChickPPSBgView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    [Styling addLiquidGlassBorderToView:self.ChickPPS cornerRadius:30];
   
}
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *tipText = Language.isRTL ? @"اضغط لاختيار التاريخ" : @"Tap to select date";
        [self.ChickPPS.dateButton showTipOnceWithText:tipText inViewController:self];
    });
}
 
- (void)setupEmptyStateView
{
    UIView *emptyView = [[UIView alloc] initWithFrame:self.selectTableView.bounds];
    emptyView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    emptyView.hidden = YES;

    UIImageView *icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:@"tray"]];
    icon.tintColor = [UIColor secondaryLabelColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *label = [UILabel new];
    label.text = kLang(@"noChicksAdded");
    label.font = [GM MidFontWithSize:15];
    label.textColor = [UIColor secondaryLabelColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [emptyView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:emptyView.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:emptyView.centerYAnchor constant:-40]
    ]];

    self.selectTableView.backgroundView = emptyView;
    self.emptyStateView = emptyView;
}

- (void)updateEmptyState
{
    if (!self.emptyStateView) {
        return;
    }

    self.emptyStateView.hidden = (self.ChildsdataSource.count > 0 || self.isFetchingChildren);
}


#pragma mark - PPSDelegate

- (void)searchViewDidBeginEditing:(PPS *)view {
    // optional
}

- (void)searchViewDidEndEditing:(PPS *)view {
    if (view.textField.text.length == 0) {
        self.ChickPPS.secondaryButton.selected = NO;
        [self.ChickPPS.btn2 setImage:self.addImage forState:UIControlStateNormal];
    }
}

// Updated to use SF Symbols replace animation on iOS 17+, fallback for older versions
- (void)searchView:(PPS *)view didChangeText:(NSString *)text
{
    UIButton *button = self.ChickPPS.btn2;
    BOOL isEmpty = (text.length == 0);
    UIImage *targetImage = isEmpty ? self.addImage : self.addImageSelected;

    if (@available(iOS 17.0, *)) {
        UIImageSymbolConfiguration *cfg;
        if(isEmpty)
            cfg= [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.grayColor,UIColor.lightGrayColor]];
        else
            cfg= [UIImageSymbolConfiguration configurationWithPaletteColors:@[AppPrimaryClr,UIColor.grayColor]];


        UIImage *symbol = [targetImage imageByApplyingSymbolConfiguration:cfg];

        [UIView animateWithDuration:0.35
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [button setImage:symbol forState:UIControlStateNormal];
            [button layoutIfNeeded];
        } completion:nil];

    } else {
        [button setImage:targetImage forState:UIControlStateNormal];
    }
}
@end
