//
//  PPCollection 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 30/09/2025.
//


//
//  PPCollection.m
//

#import "PPCollection.h"
#import "MainKindsModel.h"

@interface PPCollection () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *optionsCollectionView;
@property (nonatomic, strong) UICollectionView *mainCollectionView;
@property (nonatomic, strong) Class registeredCellClass;
@property (nonatomic, assign) NSInteger selectedOptionIndex;

@end

@implementation PPCollection

- (instancetype)initWithOptions:(NSArray<MainKindsModel *> *)optionsArray
                      cellClass:(Class)cellClass
                 optionsPosition:(PPCollectionOptionsPosition)position {
    if (self = [super initWithFrame:CGRectZero]) {
        _optionsArray = optionsArray;
        _filteredItems = @[];
        _allItems = @[];
        _registeredCellClass = cellClass;
        _optionsPosition = position;
        _selectedOptionIndex = -1;

        [self setupUI];
    }
    return self;
}

#pragma mark - Setup

- (void)setupUI {
    // --- Options bar ---
    UICollectionViewFlowLayout *optionsLayout = [[UICollectionViewFlowLayout alloc] init];
    optionsLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    optionsLayout.minimumLineSpacing = 10;
    optionsLayout.minimumInteritemSpacing = 10;

    _optionsCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:optionsLayout];
    _optionsCollectionView.backgroundColor = UIColor.clearColor;
    _optionsCollectionView.showsHorizontalScrollIndicator = NO;
    _optionsCollectionView.delegate = self;
    _optionsCollectionView.dataSource = self;
    [_optionsCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"OptionCell"];
    [self addSubview:_optionsCollectionView];

    // --- Main collection ---
    UICollectionViewFlowLayout *mainLayout = [[UICollectionViewFlowLayout alloc] init];
    mainLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    mainLayout.minimumLineSpacing = 12;
    mainLayout.minimumInteritemSpacing = 12;

    _mainCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:mainLayout];
    _mainCollectionView.backgroundColor = UIColor.clearColor;
    _mainCollectionView.delegate = self;
    _mainCollectionView.dataSource = self;
    [_mainCollectionView registerClass:_registeredCellClass forCellWithReuseIdentifier:@"MainCell"];
    [self addSubview:_mainCollectionView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat optionsHeight = 60.0;
    if (self.optionsPosition == PPCollectionOptionsPositionTop) {
        _optionsCollectionView.frame = CGRectMake(0, 0, self.bounds.size.width, optionsHeight);
        _mainCollectionView.frame = CGRectMake(0, optionsHeight, self.bounds.size.width, self.bounds.size.height - optionsHeight);
    } else {
        _mainCollectionView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - optionsHeight);
        _optionsCollectionView.frame = CGRectMake(0, CGRectGetMaxY(_mainCollectionView.frame), self.bounds.size.width, optionsHeight);
    }
}

#pragma mark - Public

- (void)reloadWithItems:(NSArray *)items {
    NSArray *safeItems = [items isKindOfClass:NSArray.class] ? [items copy] : @[];
    self.allItems = safeItems;
    self.filteredItems = safeItems;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.mainCollectionView reloadData];
    });
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (collectionView == _optionsCollectionView) {
        return self.optionsArray.count;
    }
    return self.filteredItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == _optionsCollectionView) {
        if (indexPath.item >= self.optionsArray.count) {
            return [collectionView dequeueReusableCellWithReuseIdentifier:@"OptionCell" forIndexPath:indexPath];
        }
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"OptionCell" forIndexPath:indexPath];
        MainKindsModel *model = self.optionsArray[indexPath.item];

        // Cleanup
        [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

        // Add label (and could add image if you want)
        UILabel *label = [[UILabel alloc] initWithFrame:cell.contentView.bounds];
        label.text = model.KindName ?: @"Option";
        label.font = [UIFont boldSystemFontOfSize:14];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = (indexPath.item == self.selectedOptionIndex) ? UIColor.whiteColor : UIColor.darkTextColor;
        label.backgroundColor = (indexPath.item == self.selectedOptionIndex) ? UIColor.systemBlueColor : UIColor.systemGray5Color;
        label.layer.cornerRadius = 12;
        label.layer.masksToBounds = YES;
        [cell.contentView addSubview:label];
        return cell;
    } else {
        if (indexPath.item >= self.filteredItems.count) {
            return [collectionView dequeueReusableCellWithReuseIdentifier:@"MainCell" forIndexPath:indexPath];
        }
        UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MainCell" forIndexPath:indexPath];
        // Your custom cell should have a configure method.
        if ([cell respondsToSelector:@selector(configureWithModel:)]) {
            id model = self.filteredItems[indexPath.item];
            @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [cell performSelector:@selector(configureWithModel:) withObject:model];
#pragma clang diagnostic pop
            } @catch (__unused NSException *exception) {
                // Leave the reused cell blank rather than crashing on a bad configure path.
            }
        }
        return cell;
    }
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == _optionsCollectionView) {
        if (indexPath.item >= self.optionsArray.count) {
            return;
        }
        self.selectedOptionIndex = indexPath.item;
        MainKindsModel *selected = self.optionsArray[indexPath.item];

        // Filter items by selected option (dummy filter: match ID)
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            if ([obj respondsToSelector:@selector(ID)]) {
                return [[obj valueForKey:@"ID"] integerValue] == selected.ID;
            }
            return YES;
        }];
        self.filteredItems = [self.allItems filteredArrayUsingPredicate:predicate];
        [_mainCollectionView reloadData];
        [_optionsCollectionView reloadData];

        if (self.onSelectOption) self.onSelectOption(selected, indexPath.item);
    } else {
        if (indexPath.item >= self.filteredItems.count) {
            return;
        }
        id item = self.filteredItems[indexPath.item];
        if (self.onSelectCell) self.onSelectCell(item, indexPath);
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView == _optionsCollectionView) {
        return CGSizeMake(100, 40);
    } else {
        CGFloat width = (self.bounds.size.width - 52) / 2.0;
        return CGSizeMake(width, width * 1.2);
    }
}

@end
