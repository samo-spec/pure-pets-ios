//  MyServicesViewController.m
//  Pure Pets

//  MyServicesViewController.m
//  Pure Pets

#import "MyServicesViewController.h"
#import "ServiceCollectionViewCell.h"
#import "ServicesManager.h"
#import "CCActivityHUD.h"
#import "CategoryModel.h"
#import <FirebaseAuth/FirebaseAuth.h>

@interface MyServicesViewController () <UICollectionViewDelegate, UICollectionViewDataSource, ServiceCollectionViewCellDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray<ServiceModel *> *services;
@property (nonatomic, strong) NSMutableArray<ServiceModel *> *filteredServices;
@property (nonatomic, strong) CCActivityHUD *activityHUD;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSString *selectedCategoryID;
@property (nonatomic, strong) NSDate *selectedDate;

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
    self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
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
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake((self.view.bounds.size.width - 30) / 2, 250);
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);

    self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.collectionView.backgroundColor = UIColor.clearColor;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerClass:[ServiceCollectionViewCell class] forCellWithReuseIdentifier:@"ServiceCell"];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshServices) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];

    [self.view addSubview:self.collectionView];
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
    ServiceCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ServiceCell" forIndexPath:indexPath];
    ServiceModel *service = self.filteredServices[indexPath.item];
    [cell configureWithService:service isUserOwned:YES];
    cell.delegate = self;
    return cell;
}

#pragma mark - ServiceCollectionViewCellDelegate

- (void)serviceCellDidTapEdit:(ServiceCollectionViewCell *)cell {
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
    if (!indexPath) { NSLog(@"❌ MyServicesVC: nil indexPath in didTapEdit"); return; }
    ServiceModel *service = self.filteredServices[indexPath.item];

     
}

- (void)serviceCellDidTapDelete:(ServiceCollectionViewCell *)cell {
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
    if (!indexPath) { NSLog(@"❌ MyServicesVC: nil indexPath in didTapDelete"); return; }
    ServiceModel *service = self.filteredServices[indexPath.item];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حذف الخدمة"
                                                                   message:@"هل أنت متأكد أنك تريد حذف هذه الخدمة؟"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.activityHUD show];
        [[ServicesManager sharedInstance] deleteService:service.serviceID completion:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.activityHUD dismiss];
                if (error) {
                    [self showAlert:@"فشل في حذف الخدمة"];
                }
            });
        }];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    [alert addAction:deleteAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)serviceCellDidTapShare:(ServiceCollectionViewCell *)cell {
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
    if (!indexPath) { NSLog(@"❌ MyServicesVC: nil indexPath in didTapShare"); return; }
    ServiceModel *service = self.filteredServices[indexPath.item];
    NSString *text = [NSString stringWithFormat:@"خدمة: %@\nالسعر: %.2f", service.title, service.price];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activity.popoverPresentationController.sourceView = cell ?: self.view;
        activity.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(CGRectGetMidX(self.view.bounds),
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

@end
