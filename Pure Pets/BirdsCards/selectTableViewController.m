//
//  selectTableViewController.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/07/2024.
//

#import "selectTableViewController.h"
#import "selectTableViewCell.h"
#import "PrefixHeader.pch"

@interface selectTableViewController () <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSMutableArray<CardModel *> *cardsDataSource;
@property (nonatomic, strong) NSMutableArray<CardModel *> *filteredCards;
@property (nonatomic, strong) NSArray<CardModel *> *allCardsArray;
@property (nonatomic, assign) BOOL isSearching;

@end

@implementation selectTableViewController

@synthesize rowDescriptor = _rowDescriptor;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupBaseUI];
    [self setupTableView];
    [self setupSearchController];
    [self loadData];
}

- (void)setupBaseUI {
    self.view.backgroundColor = AppBackgroundClr;
    
    if ([_vcName isEqualToString:@"mother"] || [_vcName isEqualToString:@"motherCage"]) {
        self.title = kLang(@"selectMother");
    } else {
        self.title = kLang(@"selectFather");
    }
    
    if (self.rowDescriptor.selectorTitle) {
        self.title = self.rowDescriptor.selectorTitle;
    }
    
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(dismissVC)];
    self.navigationItem.rightBarButtonItem = closeItem;
}

- (void)setupTableView {
    _selectTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _selectTableView.dataSource = self;
    _selectTableView.delegate = self;
    _selectTableView.backgroundColor = [UIColor clearColor];
    _selectTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _selectTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_selectTableView registerClass:[selectTableViewCell class] forCellReuseIdentifier:@"selectTableViewCell"];
    
    [self.view addSubview:_selectTableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_selectTableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_selectTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_selectTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_selectTableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupSearchController {
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.obscuresBackgroundDuringPresentation = NO;
    _searchController.searchBar.placeholder = kLang(@"searchHere");
    self.navigationItem.searchController = _searchController;
    self.definesPresentationContext = YES;
}

- (void)loadData {
    self.allCardsArray = AppData.UserCardsDocs;
    self.cardsDataSource = [NSMutableArray new];
    self.filteredCards = [NSMutableArray new];
    
    NSInteger sexualRequirement = ([_vcName containsString:@"father"]) ? 1 : 2;
    
    if (self.rowDescriptor.tagM) {
        NSArray<CardModel *> *baseArray = self.allCardsArray;
        if (self.rowDescriptor.selectedKind > 0) {
            NSPredicate *kindPredicate = [NSPredicate predicateWithFormat:@"SELF.SubKind == %ld", (long)self.rowDescriptor.selectedKind];
            baseArray = [baseArray filteredArrayUsingPredicate:kindPredicate];
        }
        
        NSPredicate *sexPredicate = [NSPredicate predicateWithFormat:@"SELF.Sexual == %ld", (long)sexualRequirement];
        self.cardsDataSource = [[baseArray filteredArrayUsingPredicate:sexPredicate] mutableCopy];
    } else {
        for (CardModel *card in self.allCardsArray) {
            if (card.Sexual == sexualRequirement) {
                [self.cardsDataSource addObject:card];
            }
        }
    }
    
    [self.selectTableView reloadData];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    if (searchText.length > 0) {
        self.isSearching = YES;
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"RingID CONTAINS[cd] %@", searchText];
        self.filteredCards = [[self.cardsDataSource filteredArrayUsingPredicate:predicate] mutableCopy];
    } else {
        self.isSearching = NO;
    }
    [self.selectTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.isSearching ? self.filteredCards.count : self.cardsDataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    selectTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"selectTableViewCell" forIndexPath:indexPath];
    
    CardModel *card = self.isSearching ? self.filteredCards[indexPath.row] : self.cardsDataSource[indexPath.row];
    
    cell.birdIdLabel.text = [NSString stringWithFormat:@"%@: %@", kLang(@"RingID"), card.RingID];
    cell.attributeLabel.text = [NSString stringWithFormat:@"%@: %@", kLang(@"attribute"), card.subKindString];
    cell.sexualLabel.text = card.SexualTXT;
    
    NSString *sexIcon = (card.Sexual == 1) ? @"figure.male" : @"figure.female";
    cell.sexualImageView.image = [UIImage systemImageNamed:sexIcon];
    
    if (card.FilesArray.count > 0) {
        [GM setImageFromUrlString:card.FilesArray.firstObject.FileUrl
                        imageView:cell.mainImageView
                          phImage:@"placeholder"];
    } else {
        cell.mainImageView.image = [UIImage imageNamed:@"placeholder"];
    }
    
    // Custom logic for mother/father cage selection
    if ([_vcName hasSuffix:@"Cage"]) {
        if (card.cardSection == CardSectionCage) {
            cell.contentView.alpha = 0.5;
            cell.userInteractionEnabled = NO;
        } else {
            cell.contentView.alpha = 1.0;
            cell.userInteractionEnabled = YES;
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CardModel *selectedCard = self.isSearching ? self.filteredCards[indexPath.row] : self.cardsDataSource[indexPath.row];
    
    if (self.rowDescriptor) {
        self.rowDescriptor.value = selectedCard;
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    
    if ([_vcName hasSuffix:@"Cage"]) {
        [self.delegate setParentClass:selectedCard fromVC:_vcName];
    } else {
        [self.delegate setMotherId:selectedCard.RingID fromVC:_vcName];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Actions

- (void)dismissVC {
    if (self.navigationController.viewControllers.firstObject == self) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end
