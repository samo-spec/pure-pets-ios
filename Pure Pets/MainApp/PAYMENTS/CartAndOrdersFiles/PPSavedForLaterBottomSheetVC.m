#import "PPSavedForLaterBottomSheetVC.h"
#import "PPSaveForLaterManager.h"
#import "CartManager.h"
#import "PPImageLoaderManager.h"
#import "PPHUD.h"

// MARK: - Custom Floating Card Cell

@interface PPSavedForLaterCell : UITableViewCell

@property (nonatomic, strong) UIImageView *thumbnailView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UIButton *moveToCartButton;
@property (nonatomic, strong) UIButton *deleteButton;

@property (nonatomic, copy, nullable) void (^onMove)(void);
@property (nonatomic, copy, nullable) void (^onDelete)(void);

@end

@implementation PPSavedForLaterCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UIView *card = [[UIView alloc] init];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark 
                ? [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0] 
                : [UIColor whiteColor];
        }];
        card.layer.cornerRadius = 18.0;
        card.layer.borderWidth = 0.5;
        card.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.15].CGColor;
        [self.contentView addSubview:card];
        
        _thumbnailView = [[UIImageView alloc] init];
        _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbnailView.layer.cornerRadius = 12.0;
        _thumbnailView.clipsToBounds = YES;
        _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailView.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.08];
        [card addSubview:_thumbnailView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.font = [UIFont fontWithName:@"Beiruti-Bold" size:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightBold];
        _titleLabel.numberOfLines = 2;
        [card addSubview:_titleLabel];
        
        _priceLabel = [[UILabel alloc] init];
        _priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _priceLabel.textColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? UIColor.whiteColor : [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        }];
        _priceLabel.font = [UIFont fontWithName:@"Beiruti-Bold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
        [card addSubview:_priceLabel];
        
        _moveToCartButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _moveToCartButton.translatesAutoresizingMaskIntoConstraints = NO;
        _moveToCartButton.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] : [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        }];
        _moveToCartButton.layer.cornerRadius = 14.0;
        _moveToCartButton.clipsToBounds = YES;
        [_moveToCartButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        _moveToCartButton.titleLabel.font = [UIFont fontWithName:@"Beiruti-Bold" size:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightBold];
        [_moveToCartButton addTarget:self action:@selector(moveTapped) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:_moveToCartButton];
        
        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_deleteButton setImage:[[UIImage systemImageNamed:@"trash.fill"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _deleteButton.tintColor = [UIColor systemRedColor];
        [_deleteButton addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:_deleteButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12.0],
            [card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12.0],
            [card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
            [card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],
            
            [_thumbnailView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12.0],
            [_thumbnailView.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [_thumbnailView.widthAnchor constraintEqualToConstant:72.0],
            [_thumbnailView.heightAnchor constraintEqualToConstant:72.0],
            
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:12.0],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_deleteButton.leadingAnchor constant:-8.0],
            [_titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
            
            [_priceLabel.leadingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:12.0],
            [_priceLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
            
            [_moveToCartButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
            [_moveToCartButton.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
            [_moveToCartButton.heightAnchor constraintEqualToConstant:28.0],
            [_moveToCartButton.widthAnchor constraintEqualToConstant:100.0],
            
            [_deleteButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12.0],
            [_deleteButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
            [_deleteButton.widthAnchor constraintEqualToConstant:32.0],
            [_deleteButton.heightAnchor constraintEqualToConstant:32.0]
        ]];
    }
    return self;
}

- (void)moveTapped {
    if (self.onMove) self.onMove();
}

- (void)deleteTapped {
    if (self.onDelete) self.onDelete();
}

@end

// MARK: - Controller Implementation

@interface PPSavedForLaterBottomSheetVC () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<CartItem *> *savedItems;
@end

@implementation PPSavedForLaterBottomSheetVC

- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    
    _dimmingView = [[UIView alloc] initWithFrame:self.view.bounds];
    _dimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.0];
    [self.view addSubview:_dimmingView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissSheet)];
    [_dimmingView addGestureRecognizer:tap];
    
    _containerView = [[UIView alloc] init];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    _containerView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0]
            : [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0];
    }];
    _containerView.layer.cornerRadius = 24.0;
    _containerView.layer.masksToBounds = NO;
    _containerView.layer.shadowColor = UIColor.blackColor.CGColor;
    _containerView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    _containerView.layer.shadowOpacity = 0.22;
    _containerView.layer.shadowRadius = 20.0;
    [self.view addSubview:_containerView];
    
    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:headerView];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.font = [UIFont fontWithName:@"Beiruti-Bold" size:22.0] ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    titleLabel.text = kLang(@"saved_for_later");
    [headerView addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    subtitleLabel.font = [UIFont fontWithName:@"Beiruti-Medium" size:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    subtitleLabel.text = kLang(@"choose_items_to_move");
    [headerView addSubview:subtitleLabel];
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton setImage:[[UIImage systemImageNamed:@"xmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    closeButton.tintColor = [UIColor secondaryLabelColor];
    closeButton.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.12];
    closeButton.layer.cornerRadius = 15.0;
    [closeButton addTarget:self action:@selector(dismissSheet) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeButton];
    
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.15];
    [_containerView addSubview:divider];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [_tableView registerClass:[PPSavedForLaterCell class] forCellReuseIdentifier:@"PPSavedForLaterCell"];
    [_containerView addSubview:_tableView];
    
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat sheetHeight = screenHeight * 0.89;
    
    [NSLayoutConstraint activateConstraints:@[
        [_containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
        [_containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
        [_containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-16.0],
        [_containerView.heightAnchor constraintEqualToConstant:sheetHeight],
        
        [headerView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16.0],
        [headerView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16.0],
        [headerView.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:16.0],
        [headerView.heightAnchor constraintEqualToConstant:54.0],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:4.0],
        
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2.0],
        
        [closeButton.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
        [closeButton.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        [closeButton.widthAnchor constraintEqualToConstant:30.0],
        [closeButton.heightAnchor constraintEqualToConstant:30.0],
        
        [divider.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [divider.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [divider.topAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:12.0],
        [divider.heightAnchor constraintEqualToConstant:0.5],
        
        [_tableView.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:8.0],
        [_tableView.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-16.0]
    ]];
    
    [self loadSavedItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    _containerView.transform = CGAffineTransformMakeTranslation(0.0, screenHeight);
    
    [UIView animateWithDuration:0.4
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.1
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.dimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.4];
        self.containerView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)loadSavedItems {
    self.savedItems = [[PPSaveForLaterManager sharedManager] savedItems];
    [self.tableView reloadData];
}

- (void)dismissSheet {
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    [UIView animateWithDuration:0.3
                     animations:^{
        self.dimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.0];
        self.containerView.transform = CGAffineTransformMakeTranslation(0.0, screenHeight);
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:^{
            if (self.onDismiss) self.onDismiss();
        }];
    }];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.savedItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PPSavedForLaterCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PPSavedForLaterCell" forIndexPath:indexPath];
    
    CartItem *item = self.savedItems[indexPath.row];
    cell.titleLabel.text = item.name;
    cell.priceLabel.text = [NSString stringWithFormat:@"%.2f %@", item.price, kLang(@"Rials")];
    [cell.moveToCartButton setTitle:kLang(@"move_to_cart") forState:UIControlStateNormal];
    
    if (item.imageURL.length > 0) {
        [[PPImageLoaderManager shared] setImageOnImageView:cell.thumbnailView url:item.imageURL placeholder:nil complation:^(UIImage * _Nullable image, NSString * _Nullable urlString) {
        }];
    } else {
        cell.thumbnailView.image = nil;
    }
    
    __weak typeof(self) weakSelf = self;
    cell.onMove = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [PPHUD showLoading:kLang(@"moving_to_cart")];
        
        [[PPSaveForLaterManager sharedManager] removeItem:item];
        [[CartManager sharedManager] addItem:item];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [PPHUD showSuccess:kLang(@"moved_to_cart_success")];
            [strongSelf loadSavedItems];
            if (strongSelf.onItemsMovedToCart) {
                strongSelf.onItemsMovedToCart();
            }
            if (strongSelf.savedItems.count == 0) {
                [strongSelf dismissSheet];
            }
        });
    };
    
    cell.onDelete = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [[PPSaveForLaterManager sharedManager] removeItem:item];
        [strongSelf loadSavedItems];
        if (strongSelf.savedItems.count == 0) {
            [strongSelf dismissSheet];
        }
    };
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 96.0;
}

@end
