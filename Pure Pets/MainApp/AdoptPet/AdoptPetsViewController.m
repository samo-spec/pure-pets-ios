//
//  AdoptPetsViewController.m
//  Pure Pets
//

#import "AdoptPetsViewController.h"
#import "AddAdoptPetViewController.h"
#import "PPRolePermission.h"
#import "UserModel.h"

@interface AdoptPetsViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, AdoptCollectionViewCellDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<AdoptPetModel *> *items;
@property (nonatomic, strong) id<FIRListenerRegistration> listener;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation AdoptPetsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = PPBackgroundColorForIOS26(GM.backOffwhileColor);
    self.items = [NSMutableArray array];

    [self pp_setupCollectionView];
   
    
    [self pp_setupEmptyStateLabel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self pp_navBarApplyBase:PPNavBarBaseLayoutAuto button:nil title:kLang(@"AdoptPet") showBack:YES];
    [self startListening];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self pp_updateCollectionInsetsForBottomBar];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self pp_stopListening];
}

- (void)dealloc {
    [self pp_stopListening];
}

#pragma mark - Setup

- (void)pp_setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 12;
    layout.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[AdoptPetCell class] forCellWithReuseIdentifier:@"AdoptPetCell"];

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    [self.view addSubview:self.collectionView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:10],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)pp_setupBottomBar {
   
}

- (void)pp_setupEmptyStateLabel {
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [GM MidFontWithSize:15];
    self.emptyLabel.textColor = GM.SecondaryTextColor;
    self.emptyLabel.text = kLang(@"No pets available");
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [self.emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24]
    ]];
}

- (void)pp_updateCollectionInsetsForBottomBar {
    CGFloat bottomInset = 100.0;
    self.collectionView.contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset;
}

#pragma mark - Listening

- (void)pp_stopListening {
    if (self.listener) {
        [self.listener remove];
        self.listener = nil;
    }
}

- (void)startListening {
    [self pp_stopListening];

    __weak typeof(self) weakSelf = self;
    self.listener = [AdoptPetManager.shared observeAllPetsWithUpdate:^(NSArray<AdoptPetModel *> * _Nonnull pets, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            NSLog(@"[AdoptPets] listener error: %@", error.localizedDescription);
            return;
        }

        strongSelf.items = pets.mutableCopy ?: [NSMutableArray array];
        [strongSelf.collectionView reloadData];
        [strongSelf pp_updateEmptyState];
    }];
}

- (void)pp_updateEmptyState {
    self.emptyLabel.hidden = (self.items.count > 0);
}

#pragma mark - Navigation Actions

- (IBAction)showHome {
    CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)showSupport {
    CompanyLocationVC *vc = [[CompanyLocationVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)notificationsBtnTapped:(UIButton *)sender {}

- (void)chatsBtnTapped:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    UserChatsViewController *vc = [[UserChatsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)shoppingCartClicked:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    OrderHistoryViewController *vc = [[OrderHistoryViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)cartClicked:(UIButton *)sender {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }
    CartViewController *vc = [[CartViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)addNewPetForAdopt {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    if (UserManager.sharedManager.isCurrentUserBlocked) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Account blocked")
                          subtitle:kLang(@"Your account is blocked. You can't add adoption posts right now.")];
        return;
    }

    if (![self pp_currentUserHasAnyPermissionInKeys:@[kPermAdoption, kPermAdminAll]]) {
        [PPAlertHelper showErrorIn:self
                             title:kLang(@"Permission denied")
                          subtitle:kLang(@"You don't have permission to add adoption posts.")];
        return;
    }

    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] init];
    vc.modalInPresentation = NO;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.layer.cornerRadius = 20;
    nav.navigationBar.clipsToBounds = YES;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)favTapped {
    if (!UserManager.sharedManager.isUserLoggedIn) {
        [UserManager showPromptOnTopController];
        return;
    }

    MyItemsViewController *vc = [[MyItemsViewController alloc] initWithMode:MyItemsModeFavorites
                                                                    viewType:ViewTypeAdopt];
    vc.modalInPresentation = NO;
    vc.navigationItem.backButtonTitle = @"";
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.items.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AdoptPetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AdoptPetCell" forIndexPath:indexPath];
    if (indexPath.item >= (NSInteger)self.items.count) return cell;
    AdoptPetModel *model = self.items[indexPath.item];

    NSString *cityName = [CitiesManager.shared cityNameForID:model.cityID];
    [cell configureWithName:model.name
                   imageURL:model.imageURLs.firstObject
                   subtitle:cityName
              adoptPetModel:model];

    BOOL isOwner = [self pp_isOwnerForModel:model];
    [cell pp_applyOwnerMode:isOwner animated:NO];
    cell.delegate = self;
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat available = collectionView.bounds.size.width - (12 * 3);
    CGFloat width = floor(available / 2.0);
    return CGSizeMake(width, width + 45.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= self.items.count) {
        return;
    }
    AdoptPetModel *selected = self.items[indexPath.item];
    BOOL isOwner = [self pp_isOwnerForModel:selected];
    AdoptPetDetailsViewController *vc = [[AdoptPetDetailsViewController alloc] initWithModel:selected isOwner:isOwner];
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = vc.sheetPresentationController;
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 30;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - AdoptCollectionViewCellDelegate

- (void)adoptCellDidTapFavorite:(AdoptPetCell *)cell {
    // FavoriteButton handles persistence internally.
}

- (void)adoptCellDidTapShare:(AdoptPetCell *)cell {
    AdoptPetModel *model = cell.adoptModel;
    if (!model) {
        return;
    }

    NSMutableArray *shareItems = [NSMutableArray array];
    NSString *title = model.name.length > 0 ? model.name : kLang(@"AdoptPet");
    [shareItems addObject:title];

    NSString *imageURL = model.imageURLs.firstObject;
    if (imageURL.length > 0) {
        NSURL *url = [NSURL URLWithString:imageURL];
        if (url) {
            [shareItems addObject:url];
        }
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:shareItems
                                                                               applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = cell ?: self.view;
        activityVC.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                                              CGRectGetMidY(self.view.bounds),
                                                                                              0, 0);
        activityVC.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)adoptCellDidTapEdit:(AdoptPetCell *)cell onModel:(AdoptPetModel *)adoptModel {
    if (![self pp_isOwnerForModel:adoptModel]) {
        return;
    }

    AddAdoptPetViewController *vc = [[AddAdoptPetViewController alloc] initWithPet:adoptModel];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)adoptCellDidTapDelete:(AdoptPetCell *)cell onModel:(AdoptPetModel *)adoptModel {
    if (![self pp_isOwnerForModel:adoptModel] || adoptModel.documentID.length == 0) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:kLang(@"Delete")
                                                                   message:kLang(@"Are you sure you want to delete this post?")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:kLang(@"Delete")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        [[AdoptPetManager shared] deletePetWithID:adoptModel.documentID completion:^(BOOL success, NSError * _Nullable error) {
            if (!success && error) {
                [PPAlertHelper showErrorIn:strongSelf
                                     title:kLang(@"error")
                                  subtitle:error.localizedDescription ?: kLang(@"unknownError")];
            }
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Helpers

- (BOOL)pp_isOwnerForModel:(AdoptPetModel *)model {
    NSString *currentUserID = UserManager.sharedManager.currentUser.ID;
    if (currentUserID.length == 0 || model.ownerID.length == 0) {
        return NO;
    }
    return [model.ownerID isEqualToString:currentUserID];
}

- (BOOL)pp_currentUserHasAnyPermissionInKeys:(NSArray<NSString *> *)permissionKeys {
    UserModel *currentUser = UserManager.sharedManager.currentUser;
    if (!currentUser) {
        return NO;
    }
    return [currentUser hasAnyPermissionInKeys:permissionKeys];
}

@end
