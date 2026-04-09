//
//  AppSearchHelper 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 12/08/2025.
//
// AppSearchHelper.m
// AppSearchHelper.m
// AppSearchHelper.m
#import "AppSearchHelper.h"

#import "SearchManager.h"
#import "AppSearchResultsVC.h"
#import "SearchResultItem.h"

@interface AppSearchHelper () <PYSearchViewControllerDelegate>
@property (nonatomic, strong) NSTimer *debounceTimer;
@property (nonatomic, weak) PYSearchViewController *searchVC;
@property (nonatomic, strong) AppSearchResultsVC *resultsVC;
@end

@implementation AppSearchHelper

+ (void)presentSearchFrom:(UIViewController *)presenter {
    NSLog(@"[Search] presentSearchFrom: presenter=%@", NSStringFromClass(presenter.class));
    AppSearchHelper *H = [AppSearchHelper new];
    [H presentFrom:presenter];
}



- (BOOL)pp_handleShortcut:(NSString *)text inVC:(PYSearchViewController *)svc {
    NSString *k = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];

    // food
    NSSet *foodKeys = [NSSet setWithArray:@[
        @"طعام", @"اكل", @"أكل", @"food",
        [kLang(@"Hot_Food") lowercaseString],
        [kLang(@"Food") lowercaseString]
    ]];
    if ([foodKeys containsObject:k]) {
        [[PetAccessoryManager sharedManager] fetchAccessoriesOfKind:AccessTypeFood completion:^(NSArray<PetAccessory *> *items) {
            NSArray<SearchResultItem *> *mapped = [self pp_itemsFromAccessories:items];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.resultsVC.results = mapped;
                [svc.searchBar resignFirstResponder];
            });
        }];
        return YES;
    }

    // accessories
    NSSet *accKeys = [NSSet setWithArray:@[
        @"اكسسوارات", @"إكسسوارات", @"accessories", @"accessory",
        [kLang(@"Hot_Accessories") lowercaseString],
        [kLang(@"Accessories") lowercaseString]
    ]];
    if ([accKeys containsObject:k]) {
        [[PetAccessoryManager sharedManager] fetchAccessoriesOfKind:AccessTypeAccessory completion:^(NSArray<PetAccessory *> *items) {
            NSArray<SearchResultItem *> *mapped = [self pp_itemsFromAccessories:items];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.resultsVC.results = mapped;
                [svc.searchBar resignFirstResponder];
            });
        }];
        return YES;
    }

    // vets
    NSSet *vetKeys = [NSSet setWithArray:@[
        @"طبيب بيطري", @"بيطري", @"vet", @"veterinarian",
        [kLang(@"Hot_Vet") lowercaseString],
        [kLang(@"Vet") lowercaseString]
    ]];
    if ([vetKeys containsObject:k]) {
        if ([[VetManager sharedManager] respondsToSelector:@selector(fetchAllVetsWithCompletion:)]) {
            [[VetManager sharedManager] fetchAllVetsWithCompletion:^(NSArray<VetModel *> * _Nonnull vetsArray, NSError * _Nullable error) {
                NSArray<SearchResultItem *> *mapped = [self pp_itemsFromVets:vetsArray];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.resultsVC.results = mapped;
                    [svc.searchBar resignFirstResponder];
                });
            }];
        } else {
            [[VetManager sharedManager] getVetsForPetMainKindID:0 completion:^(NSArray<VetModel *> *vets, NSError *err) {
                NSArray<SearchResultItem *> *mapped = [self pp_itemsFromVets:vets];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.resultsVC.results = mapped;
                    [svc.searchBar resignFirstResponder];
                });
            }];
        }
        return YES;
    }

    return NO;
}


- (void)presentFrom:(UIViewController *)presenter {
    NSArray *hot = @[
        kLang(@"Hot_Birds"),
        kLang(@"Hot_Parrot"),
        kLang(@"Hot_Cats"),
        kLang(@"Hot_Dogs"),
        kLang(@"Hot_Vet"),
        kLang(@"Hot_Food"),
        kLang(@"Hot_Cage"),
        kLang(@"Hot_Accessories")
    ];

    PYSearchViewController *svc =
    [PYSearchViewController searchViewControllerWithHotSearches:hot
                                          searchBarPlaceholder:kLang(@"SearchPlaceholder")
                                              didSearchBlock:^(PYSearchViewController * _Nonnull searchVC,
                                                               UISearchBar * _Nonnull searchBar,
                                                               NSString * _Nonnull searchText) {
        if ([self pp_handleShortcut:searchText inVC:searchVC]) return;
        [self performQuery:searchText];
    }];

    self.searchVC = svc;
    svc.delegate = self;

    // styles…
    svc.hotSearchStyle = PYHotSearchStyleColorfulTag;
    svc.searchHistoryStyle = PYSearchHistoryStyleBorderTag;

    // Cancel button via kLang
 
    // Embed our results controller (unchanged)
    self.resultsVC = [AppSearchResultsVC new];
    svc.searchResultShowMode = PYSearchResultShowModeEmbed;
    svc.searchResultController = self.resultsVC;

    // kLang-based styling for the bar
    [self pp_stylePYSearchController:svc];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:svc];
    //nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [presenter.navigationController presentViewController:nav animated:YES completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [svc.view setNeedsLayout];
            [svc.view layoutIfNeeded];
        });
    }];
}


// Call this right after you create PYSearchViewController and before presenting it.
- (void)pp_stylePYSearchController:(PYSearchViewController *)svc {
    if (!svc) return;

    // Background + rounded corners (visible if not full-screen)
    svc.view.backgroundColor = [GM AppForegroundColor];
    svc.view.layer.cornerRadius = 22.0;
    svc.view.layer.masksToBounds = YES;

    // Make internal table(s) match background (best effort without subclassing)

    for (UIView *sub in svc.view.subviews) {
        if ([sub isKindOfClass:[UITableView class]]) {
            ((UITableView *)sub).backgroundColor = [GM backOffwhileColor];
        }
    }

    // --- Search bar styling ---
    UISearchBar *sb = svc.searchBar;
    sb.backgroundImage = [UIImage new];               // remove default bar bg
    sb.searchTextField.backgroundColor = [GM AppForegroundColor];

    sb.searchTextField.layer.cornerRadius = 18;
    sb.searchTextField.layer.masksToBounds = YES;

    // Height = 44 (add a hard constraint on the text field)
    [sb.searchTextField.heightAnchor constraintEqualToConstant:44.0].active = YES;

    // Fonts: text (bold 14), placeholder (mid 14)
    sb.searchTextField.font = [GM MidFontWithSize:14];
    NSString *ph = sb.placeholder ?: kLang(@"searchField");
    sb.searchTextField.attributedPlaceholder =
        [[NSAttributedString alloc] initWithString:ph
                                        attributes:@{
            NSFontAttributeName : [GM fontWithSize:16],
            NSForegroundColorAttributeName : UIColor.placeholderTextColor
        }];

    // LTR/RTL alignment
    sb.searchTextField.textAlignment = ([Language languageVal] == 0) ? NSTextAlignmentLeft : NSTextAlignmentRight;
    sb.semanticContentAttribute = ([Language languageVal] == 0)
        ? UISemanticContentAttributeForceLeftToRight
        : UISemanticContentAttributeForceRightToLeft;

    // Cancel button font
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]]
     setTitleTextAttributes:@{ NSFontAttributeName : [GM MidFontWithSize:14] }
                   forState:UIControlStateNormal];

    // Make sure layout takes the new height/rounding
    [sb setNeedsLayout];
    [sb layoutIfNeeded];
}



#pragma mark - PYSearchViewControllerDelegate (live typing)

- (void)searchViewController:(PYSearchViewController *)searchViewController
        searchTextDidChange:(NSString *)searchText {
    NSLog(@"[Search] searchTextDidChange len=%lu text=\"%@\"",
          (unsigned long)searchText.length, searchText);
    [self debounceQuery:searchText];
}

#pragma mark - Debounce + Query

- (void)debounceQuery:(NSString *)text {
    [self.debounceTimer invalidate];
    __weak typeof(self) weakSelf = self;
    NSLog(@"[Search] debounce schedule (300ms) for \"%@\"", text);
    self.debounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.30
                                                          repeats:NO
                                                            block:^(__unused NSTimer * _Nonnull t) {
        NSLog(@"[Search] debounce fire for \"%@\"", text);
        [weakSelf performQuery:text];
    }];
}

- (void)performQuery:(NSString *)text {
    if (text.length == 0) {
        NSLog(@"[Search] performQuery skipped (empty text)");
        self.resultsVC.results = @[];
        return;
    }

    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    NSLog(@"[Search] performQuery start text=\"%@\"", text);

    [[SearchManager shared] searchText:text completion:^(NSArray<SearchResultItem *> * _Nonnull results) {
        // breakdown by type
        NSInteger cAd=0,cAcc=0,cSvc=0,cVet=0,cFood=0;
        for (SearchResultItem *it in results) {
            switch (it.type) {
                case SearchResultTypePetAd:     cAd++;  break;
                case SearchResultTypeAccessory: cAcc++; break;
                case SearchResultTypeService:   cSvc++; break;
                case SearchResultTypeVet:       cVet++; break;
                case SearchResultTypeFood:     cFood++; break;
            }
        }
        CFTimeInterval dur = CFAbsoluteTimeGetCurrent() - start;
        NSLog(@"[Search] performQuery done (%.2f ms) total=%lu  [Ad=%ld, Acc=%ld, Svc=%ld, Vet=%ld, cFood=%ld]",
              dur*1000.0,
              (unsigned long)results.count,
              (long)cAd,(long)cAcc,(long)cSvc,(long)cVet,(long)cFood);

        if (!self.resultsVC) {
            NSLog(@"[Search][WARN] resultsVC is nil – cannot display results");
            return;
        }
        self.resultsVC.results = results;
    }];
}

- (void)dealloc {
    NSLog(@"[Search] AppSearchHelper dealloc");
    [self.debounceTimer invalidate];
}




#pragma mark - Builders

- (NSArray<SearchResultItem *> *)pp_itemsFromAccessories:(NSArray<PetAccessory *> *)arr {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:arr.count];
    for (PetAccessory *a in arr) {
        SearchResultItem *it = [SearchResultItem new];
        it.type = a.accessKindType == AccessTypeFood ? SearchResultTypeFood : SearchResultTypeAccessory;          // Food is a kind of accessory
        it.rawObject = a;
        it.titleText = a.name ?: a.name ?: @"";
        it.subtitleText = a.desc ?: @"";
        it.imageURLString = a.imageURLsArray[0];
        [out addObject:it];
    }
    return out;
}

- (NSArray<SearchResultItem *> *)pp_itemsFromVets:(NSArray<VetModel *> *)arr {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:arr.count];
    for (VetModel *v in arr) {
        SearchResultItem *it = [SearchResultItem new];
        it.type = SearchResultTypeVet;
        it.rawObject = v;
        it.titleText = v.title ?: @"";
        it.subtitleText = v.descriptionText ?: @"";
        it.imageURLString = v.logoURL;
        [out addObject:it];
    }
    return out;
}

@end
