//
//  selectUserVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import "selectUserVC.h"
#import "UIView+XLFormAdditions.h"
#import "UISearchBar+FMAdd.h"
#import "ImageModel.h"
#import "PPModernAvatarRenderer.h"

#import "AppDelegate.h"

@interface selectUserVC ()<UITableViewDelegate,UITableViewDataSource,UISearchBarDelegate>
{
    BOOL searchEnabled;
    CGFloat topbarHeight;
    FIRStorage *firStorage;
}
@property (nonatomic,strong) NSMutableArray<UserModel *>     *userArray;
@property (nonatomic,strong) NSArray<UserModel *>            *allUsers;
@property (nonatomic)        BOOL           searchBarActive;
@property (nonatomic)        float          searchBarBoundsY;

@end

@implementation selectUserVC

@synthesize rowDescriptor = _rowDescriptor;

-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

#pragma mark - Programmatic UI

- (void)setupViews {
    // Top bar
    _topBarView = [[UIView alloc] init];
    _topBarView.backgroundColor = [UIColor whiteColor];
    _topBarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_topBarView];

    // Title label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_topBarView addSubview:_titleLabel];

    // Close button
    UIButton *closeBTN = [self pp_ButtonWithSystemName:@"multiply" action:@selector(onDissmiss)];
    [_topBarView addSubview:closeBTN];
    [NSLayoutConstraint activateConstraints:@[
        [closeBTN.centerYAnchor constraintEqualToAnchor:_topBarView.centerYAnchor],
        [closeBTN.trailingAnchor constraintEqualToAnchor:_topBarView.trailingAnchor constant:-16],
    ]];

    // Search bar
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_searchBar];

    // Table view
    _selectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _selectTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_selectTableView];
}

- (void)setupConstraints {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        // topBarView
        [_topBarView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [_topBarView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [_topBarView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [_topBarView.heightAnchor constraintEqualToConstant:56],

        // titleLabel centered in topBarView
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_topBarView.centerYAnchor],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_topBarView.leadingAnchor constant:44],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_topBarView.trailingAnchor constant:-44],

        // searchBar below topBarView
        [_searchBar.topAnchor constraintEqualToAnchor:_topBarView.bottomAnchor],
        [_searchBar.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [_searchBar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],

        // selectTableView fills remaining space
        [_selectTableView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor],
        [_selectTableView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [_selectTableView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [_selectTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PPBackgroundColorForIOS26([UIColor whiteColor]);

    [self setupViews];
    [self setupConstraints];

    // Do any additional setup after loading the view.
    searchEnabled = NO;
    _selectTableView.dataSource = self;
    _selectTableView.delegate = self;
    [_selectTableView registerClass:selectTableViewCell.class forCellReuseIdentifier:@"selectTableViewCell"];
    topbarHeight  = ([UIApplication sharedApplication].statusBarFrame.size.height +
                     (self.navigationController.navigationBar.frame.size.height ?: 0.0));
    self.selectTableView.layer.cornerRadius =.0;
    self.selectTableView.clipsToBounds = YES;
    //self.selectTableView.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
   
    firStorage = [FIRStorage storage];
    self.allUsers = [self pp_visibleUsersFromArray:PPUsersArr];
    self.userArray = [self.allUsers mutableCopy];
    
    
    if([_vcName isEqualToString:@"mainController"])
        _titleLabel.text = @"قم باختيار المستخدم لمشاركة البطاقة معه";
    else
        _titleLabel.text = @"محادثة جديدة";
    
    _titleLabel.font = [GM MidFontWithSize:17];
    
    self.view.layer.cornerRadius = 20;
    self.view.clipsToBounds = YES;
    if(self.rowDescriptor.title)
    {
        _topBarView.alpha = 0;
        _searchBar.hx_y = topbarHeight;
        _selectTableView.hx_y = _searchBar.hx_y + _searchBar.height - 30;
        [self changeColor];
    }
    
 
    self.searchBar.backgroundImage = [[UIImage alloc] init];
    // 设置SearchBar的颜色主题为白色
    self.searchBar.barTintColor = [UIColor whiteColor];
    
    self.searchBar.placeholder = @"اكتب هنا للبحث";
    
    UITextField *searchField = [self.searchBar valueForKey:@"searchField"];
    if (searchField) {
        [searchField setBackgroundColor:[UIColor colorWithRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:1]];
       //searchField.layer.cornerRadius = 14.0f;
        [searchField pp_setBorderColor:[UIColor colorWithRed:249/255.0 green:242/255.0 blue:235/255.0 alpha:1]];
        searchField.layer.borderWidth = 0;
        searchField.layer.masksToBounds = NO;
        searchField.layer.cornerRadius =15;
        [searchField pp_setShadowColor:[UIColor blackColor]];
        searchField.layer.shadowOffset = CGSizeMake(0.0,0.0);
        searchField.layer.shadowRadius = 1.0;
        searchField.layer.shadowOpacity = 0.2;
        //searchField.frame = CGRectMake(searchField.frame.origin.x, searchField.frame.origin.y, searchField.frame.size.width, 32);
        searchField.clipsToBounds=NO;
        CGRect bounds = searchField.frame;
        bounds.size.height = 30; //(set your height)
        searchField.bounds = bounds;
        searchField.borderStyle =UITextBorderStyleRoundedRect;
        [searchField setClearButtonMode:UITextFieldViewModeNever];
        searchField.textAlignment = UITextAlignmentCenter;
    }
    
    //3. 设置按钮文字和颜色
    [self.searchBar fm_setCancelButtonTitle:@"إالغاء"];
    //  self.searchBar.tintColor = [UIColor colorWithRed:255.0/255.0 green:248.0/255.0 blue:229.0/255.0 alpha:1];
    //设置取消按钮字体
    [self.searchBar fm_setCancelButtonFont:[UIFont systemFontOfSize:13]];
    //修正光标颜色
    [searchField setTintColor:[UIColor blackColor]];
    
    //4. 设置输入框文字颜色和字体
    [self.searchBar fm_setTextColor:[UIColor blackColor]];
    [self.searchBar fm_setTextFont:[UIFont systemFontOfSize:13]];
    //5. 设置搜索Icon
    
    self.searchBar.delegate = self;
    [self LoadData];
}

-(void)validateForm:(UIBarButtonItem *)buttonItem
{
    [self.navigationController  popViewControllerAnimated:YES];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    if(self.rowDescriptor.title)
    {
        [self changeColor];
        
    }
    
}



- (void)changeColor {
    
    [self.navigationController.navigationBar setAlpha:1];

    //[self setTopGard:_topView];
    UIColor *backgroudColor;
    UIColor *themeColor;
    UIColor *navBarBackgroudColor;
    UIColor *navigationTitleColor;
   
    themeColor = [UIColor colorWithRed:61.0/255. green:62.0/255. blue:101.0/255. alpha:1];
    backgroudColor = [UIColor whiteColor];
        navBarBackgroudColor = [UIColor blackColor];
    navigationTitleColor = [UIColor colorWithHexString:@"#973C62"];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor darkGrayColor]};
    [self.navigationController.navigationBar setBackgroundColor:[UIColor clearColor]];
    [self.navigationController.navigationBar setTintColor:themeColor];
    self.title = _rowDescriptor.selectorTitle;
  
}

-(void)LoadData
{ 
   
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    // getting an NSString
   
     
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.selectTableView reloadData];
        }];
    
    
}

-(NSArray<UserModel *> *)pp_visibleUsersFromArray:(NSArray<UserModel *> *)sourceUsers
{
    NSMutableArray<UserModel *> *visibleUsers = [NSMutableArray array];
    NSString *currentUID = [FIRAuth auth].currentUser.uid ?: PPCurrentUser.ID ?: @"";
    for (UserModel *user in sourceUsers) {
        if (![user isKindOfClass:UserModel.class]) {
            continue;
        }
        if (user.ID.length == 0) {
            continue;
        }
        if (currentUID.length > 0 && [user.ID isEqualToString:currentUID]) {
            continue;
        }
        if (user.isBlocked || user.chatBlocked || !user.canUseChatFeature) {
            continue;
        }
        if (user.UserName.length == 0 &&
            user.FirstName.length == 0 &&
            user.LastName.length == 0 &&
            user.UserEmail.length == 0) {
            continue;
        }
        [visibleUsers addObject:user];
    }
    return [visibleUsers copy];
}

-(NSString *)pp_searchableTextForUser:(UserModel *)user
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSString *part in @[user.UserName ?: @"",
                             user.FirstName ?: @"",
                             user.LastName ?: @"",
                             user.UserEmail ?: @"",
                             user.MobileNo ?: @""]) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length > 0) {
            [parts addObject:trimmed];
        }
    }
    return [[parts componentsJoinedByString:@" "] lowercaseString];
}

-(void)dealloc{
    // remove Our KVO observer
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





#pragma mark - search
-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
   if ([searchBar.text length] > 0) {
        NSString *searchText = searchBar.text;
        [self filterCurrentDataSourceWith:searchText];
    }
}

-(void) filterCurrentDataSourceWith:(NSString *)searchTerm {
    _searchBarActive = true;
    
    
    if ([searchTerm length] > 0) {
        NSString *normalizedTerm = [[searchTerm stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
        NSMutableArray<UserModel *> *filteredResults = [NSMutableArray array];
        for (UserModel *user in self.allUsers) {
            NSString *searchable = [self pp_searchableTextForUser:user];
            if (normalizedTerm.length == 0 || [searchable containsString:normalizedTerm]) {
                [filteredResults addObject:user];
            }
        }
        self.userArray = filteredResults;
        [self.selectTableView reloadData];
    } else {
        [self restoreCurrentDataSource];
    }
}


- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
   
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
    NSLog(@"textDidChange %@",searchBar.text);
    [searchBar setShowsCancelButton:YES animated:YES];
    if ([searchBar.text length] > 0) {
        NSString *searchText = searchBar.text;
        [self filterCurrentDataSourceWith:searchText];
    }
   
}

-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    _searchBarActive = false;
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    [self restoreCurrentDataSource];
    

}

-(void) restoreCurrentDataSource {
    self.userArray = [self.allUsers mutableCopy];
    [self.selectTableView reloadData];
}

- (void)restoreData:(id)sender {
    [self restoreCurrentDataSource];
}

-(void)ResetSearch
{
    searchEnabled = NO;
    
}

#pragma mark - prepareVC
-(void)prepareUI{
    [self addSearchBar];
}
-(void)addSearchBar{
    if (!self.searchBar) {
        self.searchBarBoundsY = self.navigationController.navigationBar.frame.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
       // self.searchBar = [[UISearchBar alloc]initWithFrame:CGRectMake(0,self.searchBarBoundsY, [UIScreen mainScreen].bounds.size.width, 44)];
        self.searchBar.searchBarStyle       = UISearchBarStyleMinimal;
        self.searchBar.tintColor            = [UIColor whiteColor];
        self.searchBar.barTintColor         = [UIColor whiteColor];
        self.searchBar.delegate             = self;
        self.searchBar.placeholder          = @"Enter ring number";
        
        [[UITextField appearanceWhenContainedIn:[UISearchBar class], nil] setTextColor:[UIColor whiteColor]];

    }
    
   //// if (![self.searchBar isDescendantOfView:self.view]) {
        [self.view addSubview:self.searchBar];
   // }
}


-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return  70;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    
 
    return self.userArray.count;
   // return [self.birdsIdsArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *TableIdentifier = @"selectTableViewCell";
    selectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:
                             TableIdentifier];
    if (cell == nil) {
        cell = [[selectTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:TableIdentifier];
    }
    
   /* cell.centerView.layer.cornerRadius = 15;
    cell.MainImageView.layer.cornerRadius = 30;
    //cell.contentView.layer.masksToBounds = true;
    cell.centerView.layer.masksToBounds = false;
    cell.centerView.layer.shadowOffset = CGSizeMake(0, 0);
    [cell.centerView pp_setShadowColor:UIColor.blackColor];
    cell.centerView.layer.shadowOpacity = 0.23;
    cell.centerView.layer.shadowRadius = 1;
    cell.centerView.frame = CGRectMake(5, 5, CGRectGetWidth(cell.contentView.frame) - 10, CGRectGetHeight(cell.contentView.frame) - 10);
    */
    
    cell.mainImageView.layer.cornerRadius = 25;
   // cell.titleLabel.text = self.birdsIdsArray[indexPath.row];
    
    cell.birdIdLabel.text = [self.userArray objectAtIndex:indexPath.row].UserName ;
    cell.attributeLabel.text = [self.userArray objectAtIndex:indexPath.row].UserAbout ;
    cell.sexualLabel.text = nil;
    cell.sexualImageView.image = nil;

    [cell.mainImageView pp_setBorderColor:GM.appPrimaryColor];
    cell.mainImageView.layer.borderWidth = 1.5;
    
    UserModel *cellUser = [self.userArray objectAtIndex:indexPath.row];
    cell.mainImageView.image = [PPModernAvatarRenderer avatarImageForName:cellUser.UserName size:44];
    [GM setImageFromUrlString:cellUser.UserImageUrl.absoluteString imageView:cell.mainImageView phImage:@"man"];
    
    return cell;
}


#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UserModel *selectedClass;
    if (self.searchBarActive) {
        selectedClass = self.userArray[indexPath.row];
    }else{
        selectedClass = self.userArray[indexPath.row];
    }
    

    [self dismissViewControllerAnimated:YES completion:^{
        NSLog(@"User selected %@",  selectedClass);
        [self.delegate selectUser:selectedClass vcName:self.vcName];
    }];
    
    
}




-(void)setReturnedMotherId:(NSString *)motherID;
{
   // _motherRingID.text = motherID;
    NSLog(@"returnedMotherId %@",motherID);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (void)dismissBTN:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
