#import "MyServicesViewController.h"
#import "PPUniversalCell.h"
#import "PPUniversalCellViewModel.h"
#import "PPImageLoaderManager.h"
#import "ServicesManager.h"
#import "CCActivityHUD.h"
#import "CategoryModel.h"
#import <FirebaseAuth/FirebaseAuth.h>

static inline BOOL PPServicesGridIsTablet(CGFloat width)
{
    return width >= 768.0;
}

static inline NSInteger PPServicesGridColumnCount(CGFloat width)
{
    if (width >= 1200.0) {
        return 4;
    }
    if (width >= 820.0) {
        return 3;
    }
    if (width <= 360.0) {
        return 1;
    }
    return 2;
}

@interface MyServicesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PPUniversalCellDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewFlowLayout *collectionLayout;
@property (nonatomic, strong) NSMutableArray<ServiceModel *> *services;
@property (nonatomic, strong) NSMutableArray<ServiceModel *> *filteredServices;
@property (nonatomic, strong) CCActivityHUD *activityHUD;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSString *selectedCategoryID;
@property (nonatomic, strong) NSDate *selectedDate;
@property (nonatomic, assign) CGSize lastResolvedCollectionBoundsSize;

@end

@implementation MyServicesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"خدماتي";
    self.view.backgroundColor = PPBackgroundColorForIOS26(UIColor.systemBackgroundColor);
    [self setupCollectionView];
    [self setupActivityHUD];
    [self setupSearchBar];
    [self startListeningToServices];
    self.navigationController.navigationBar.tintColor = UIColor.labelColor;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self pp_applyCollectionLayoutMetricsIfNeeded];
}

- (void)setupActivityHUD {
    self.activityHUD = [CCActivityHUD new];
    self.activityHUD.isTheOnlyActiveView = YES;
    self.activityHUD.backColor = [UIColor clearColor];
    self.activityHUD.indicatorColor = UIColor.systemBlueColor;
    self.activityHUD.overlayType = CCActivityHUDOverlayTypeShadow;
}

- (void)setupSearchBar {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"ابحث عن الخدمة";
    self.searchBar.delegate = self;
    self.navigationItem.titleView = self.searchBar;
}

- (void)setupCollectionView {
    self.collectionLayout = [[UICollectionViewFlowLayout alloc] init];
    self.collectionLayout.minimumInteritemSpacing = 12.0;
    self.collectionLayout.minimumLineSpacing = 12.0;
    self.collectionLayout.sectionInset = UIEdgeInsetsMake(12.0, 16.0, 24.0, 16.0);

    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.collectionLayout];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [PPUniversalCell pp_registerInCollectionView:self.collectionView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshServices) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];

    [self.view addSubview:self.collectionView];
    [NSLayoutConstraint activateConstraints:@[
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)refreshServices {
    [self.refreshControl beginRefreshing];
    [self startListeningToServices];
    [self.refreshControl endRefreshing];
}

- (void)startListeningToServices {
    NSString *ownerID = [UserManager sharedManager].currentUser.ID;

    [[ServicesManager sharedInstance] listenToAllServicesWithCompletion:^(NSArray<ServiceModel *> *services, NSError *error) {
        if (error) return;

        NSPredicate *mine = [NSPredicate predicateWithFormat:@"serviceOwnerID == %@", ownerID];
        self.services = [[services filteredArrayUsingPredicate:mine] mutableCopy];
        [self applyFilters];
    }];
}

- (void)applyFilters {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(ServiceModel *service, NSDictionary *bindings) {
        BOOL matchesCategory = !self.selectedCategoryID || [service.category isEqualToString:self.selectedCategoryID];
        BOOL matchesDate = !self.selectedDate || [service.availableDate compare:self.selectedDate] != NSOrderedAscending;
        BOOL matchesSearch = self.searchBar.text.length == 0 || [service.title localizedCaseInsensitiveContainsString:self.searchBar.text];
        return matchesCategory && matchesDate && matchesSearch;
    }];

    self.filteredServices = [[self.services filteredArrayUsingPredicate:predicate] mutableCopy];
    [self.collectionView reloadData];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilters];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.filteredServices.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PPUniversalCell *cell = (PPUniversalCell *)[PPUniversalCell pp_dequeueFromCollectionView:collectionView indexPath:indexPath];
    ServiceModel *service = self.filteredServices[indexPath.item];
    PPUniversalCellViewModel *vm = [[PPUniversalCellViewModel alloc] initWithModel:service context:PPCellForServices];
    vm.indexPath = indexPath;
    cell.delegate = self;
    cell.forceShowsOwnerMenuButton = YES;
    cell.showsSubtitle = YES;
    cell.hideTopBadge = NO;
    [cell applyViewModel:vm
                 context:PPCellForServices
              layoutMode:PPCellLayoutModePinterest
            discountMode:PPDiscountStyleBadge
             imageLoader:^(UIImageView * _Nullable iv, NSString * _Nullable url, UIImage * _Nullable ph, UIView * _Nullable card) {
        if (url.length > 0) {
            [[PPImageLoaderManager shared] setImageOnImageView:iv url:url complation:nil];
        }
    }];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat availableWidth = CGRectGetWidth(collectionView.bounds);
    UIEdgeInsets sectionInset = self.collectionLayout.sectionInset;
    NSInteger columns = PPServicesGridColumnCount(availableWidth);
    CGFloat totalSpacing = sectionInset.left + sectionInset.right + (self.collectionLayout.minimumInteritemSpacing * MAX(columns - 1, 0));
    CGFloat itemWidth = floor((availableWidth - totalSpacing) / MAX(columns, 1));
    CGFloat mediaHeight = (columns == 1)
        ? MIN(MAX(itemWidth * 0.74, 240.0), 310.0)
        : MIN(MAX(itemWidth * 1.06, 220.0), 290.0);
    return CGSizeMake(itemWidth, mediaHeight);
}

#pragma mark - PPUniversalCellDelegate

- (void)PPUniversalCell_tapEdit:(PPUniversalCellViewModel *)universalModel {
    NSIndexPath *indexPath = universalModel.indexPath;
    if (!indexPath || indexPath.item >= (NSInteger)self.filteredServices.count) return;
    ServiceModel *service = self.filteredServices[indexPath.item];
}

- (void)PPUniversalCell_tapDelete:(PPUniversalCellViewModel *)universalModel {
    NSIndexPath *indexPath = universalModel.indexPath;
    if (!indexPath || indexPath.item >= (NSInteger)self.filteredServices.count) return;
    ServiceModel *service = self.filteredServices[indexPath.item];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:(kLang(@"service_delete_title") ?: @"Delete Service")
                                                                   message:(kLang(@"service_delete_confirm_msg") ?: @"Are you sure you want to delete this service?")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:(kLang(@"delete") ?: @"Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.activityHUD show];
        [[ServicesManager sharedInstance] deleteService:service.serviceID completion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) ss = weakSelf;
                if (!ss) return;
                [ss.activityHUD dismiss];
                if (error) {
                    [ss showAlert:(kLang(@"service_delete_failed") ?: @"Failed to delete service")];
                }
            });
        }];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:(kLang(@"Cancel") ?: @"Cancel") style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)PPUniversalCell_tapShare:(PPUniversalCellViewModel *)universalModel {
    NSIndexPath *indexPath = universalModel.indexPath;
    if (!indexPath || indexPath.item >= (NSInteger)self.filteredServices.count) return;
    ServiceModel *service = self.filteredServices[indexPath.item];
    NSString *text = [NSString stringWithFormat:@"خدمة: %@\nالسعر: %.2f", service.title, service.price];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activity.popoverPresentationController.sourceView = self.view;
        activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                                        CGRectGetMidY(self.view.bounds),
                                                                        0, 0);
        activity.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    }
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تنبيه" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"تم" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Private

- (void)pp_applyCollectionLayoutMetricsIfNeeded
{
    CGSize boundsSize = self.collectionView.bounds.size;
    if (boundsSize.width <= 0.0 || boundsSize.height <= 0.0 || CGSizeEqualToSize(boundsSize, self.lastResolvedCollectionBoundsSize)) {
        return;
    }

    self.lastResolvedCollectionBoundsSize = boundsSize;

    CGFloat width = CGRectGetWidth(self.view.bounds);
    BOOL isTablet = PPServicesGridIsTablet(width);
    CGFloat sideInset = isTablet ? 24.0 : 16.0;
    CGFloat spacing = isTablet ? 16.0 : 12.0;

    self.collectionLayout.minimumInteritemSpacing = spacing;
    self.collectionLayout.minimumLineSpacing = spacing;
    self.collectionLayout.sectionInset = UIEdgeInsetsMake(12.0, sideInset, 24.0, sideInset);

    [self.collectionLayout invalidateLayout];
}

@end
