#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "PPDataViewInput.h"
#import "PPFilterModels.h"
#import "PPUniversalCell.h"

NS_ASSUME_NONNULL_BEGIN

@class MainKindsModel;
@class PPUniversalCellViewModel;
@class SubKindModel;

/// Immutable provider identity consumed by the SwiftUI marketplace filter.
/// Provider filtering remains presentation-only; the authoritative VM item
/// array and backend requests are never mutated by this object.
@interface PPMarketplaceProviderOption : NSObject

@property (nonatomic, copy, readonly) NSString *providerID;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *photoURL;
@property (nonatomic, assign, readonly) NSInteger itemCount;

- (instancetype)initWithProviderID:(NSString *)providerID
                              title:(NSString *)title
                           photoURL:(nullable NSString *)photoURL
                          itemCount:(NSInteger)itemCount NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

/// Narrow compatibility seam between the new SwiftUI DataViewer and the
/// production Objective-C services. It deliberately contains no visible UI.
///
/// Ownership:
/// - `PPDataViewVM` remains authoritative for requests, payload mapping,
///   caching, filtering, pagination semantics, and request cancellation.
/// - SwiftUI owns layout, selection presentation, loading/error/empty states,
///   and accessibility.
/// - Existing managers and coordinators continue to own all business actions.
@interface PPMarketplaceDataViewBridge : NSObject <PPUniversalCellDelegate>

@property (nonatomic, weak, nullable) UIViewController *presentingViewController;
@property (nonatomic, strong, readonly) PPDataViewInput *input;

@property (nonatomic, copy, nullable) void (^itemsDidChange)(void);
@property (nonatomic, copy, nullable) void (^itemsDidAppend)(NSArray<NSIndexPath *> *indexPaths);
@property (nonatomic, copy, nullable) void (^loadingDidFail)(NSError *error);
@property (nonatomic, copy, nullable) void (^initialContentDidLoad)(void);
@property (nonatomic, copy, nullable) void (^providerIdentitiesDidChange)(void);
@property (nonatomic, copy, nullable) void (^presentationStateDidChange)(void);

@property (nonatomic, copy, readonly) NSArray<PPUniversalCellViewModel *> *items;
@property (nonatomic, copy, readonly) NSArray<MainKindsModel *> *mainKinds;
@property (nonatomic, copy, readonly) NSArray<SubKindModel *> *subKinds;
@property (nonatomic, strong, readonly, nullable) MainKindsModel *currentMainKind;
@property (nonatomic, assign, readonly) PPDataSection currentSection;
@property (nonatomic, assign, readonly) NSInteger currentSubKindID;
@property (nonatomic, assign, readonly, getter=isLoading) BOOL loading;
@property (nonatomic, assign, readonly, getter=isNetworkAvailable) BOOL networkAvailable;
@property (nonatomic, copy, readonly) NSString *currentMainKindTitle;
@property (nonatomic, copy, readonly) NSString *currentSubKindTitle;
@property (nonatomic, strong, readonly) UIColor *accentColor;
@property (nonatomic, assign, readonly) NSInteger cartItemCount;
@property (nonatomic, assign, readonly) CGFloat bottomNavigationClearance;

- (instancetype)initWithInput:(PPDataViewInput *)input
    NS_SWIFT_NAME(init(input:)) NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Resolves the same initial route precedence as the legacy controller:
/// explicit override, per-kind persisted section, then advertisements.
- (void)start NS_SWIFT_NAME(start());
- (void)reload NS_SWIFT_NAME(reload());
- (void)fetchNextPage NS_SWIFT_NAME(fetchNextPage());

- (void)switchToSection:(PPDataSection)section
    NS_SWIFT_NAME(switchSection(_:));
- (void)switchToMainKind:(MainKindsModel *)mainKind
    NS_SWIFT_NAME(switchMainKind(_:));
- (void)switchToSubKind:(nullable SubKindModel *)subKind
    NS_SWIFT_NAME(switchSubKind(_:));

- (NSInteger)identifierForMainKind:(MainKindsModel *)mainKind
    NS_SWIFT_NAME(identifier(forMainKind:));
- (NSString *)displayTitleForMainKind:(MainKindsModel *)mainKind
    NS_SWIFT_NAME(displayTitle(forMainKind:));
- (NSInteger)identifierForSubKind:(SubKindModel *)subKind
    NS_SWIFT_NAME(identifier(forSubKind:));
- (NSString *)displayTitleForSubKind:(SubKindModel *)subKind
    NS_SWIFT_NAME(displayTitle(forSubKind:));

- (PPFilterState *)filterStateForSection:(PPDataSection)section
    NS_SWIFT_NAME(filterState(for:));
- (void)applyFilterState:(PPFilterState *)filterState
              forSection:(PPDataSection)section
    NS_SWIFT_NAME(applyFilter(_:section:));
- (NSInteger)previewResultCountForFilterState:(PPFilterState *)filterState
    NS_SWIFT_NAME(previewResultCount(for:));
- (NSInteger)activeFilterCountForSection:(PPDataSection)section
    NS_SWIFT_NAME(activeFilterCount(for:));

- (BOOL)sectionSupportsProviderFilter:(PPDataSection)section
    NS_SWIFT_NAME(sectionSupportsProviderFilter(_:));
- (NSArray<PPMarketplaceProviderOption *> *)providerOptionsForItems:(NSArray<PPUniversalCellViewModel *> *)items
                                                            section:(PPDataSection)section
    NS_SWIFT_NAME(providerOptions(items:section:));
- (NSArray<PPUniversalCellViewModel *> *)items:(NSArray<PPUniversalCellViewModel *> *)items
                           matchingProviderID:(nullable NSString *)providerID
    NS_SWIFT_NAME(items(_:matchingProviderID:));
- (void)hydrateProviderIdentitiesForItems:(NSArray<PPUniversalCellViewModel *> *)items
                                   section:(PPDataSection)section
    NS_SWIFT_NAME(hydrateProviderIdentities(items:section:));

- (void)openSearch NS_SWIFT_NAME(openSearch());
- (void)openCart NS_SWIFT_NAME(openCart());
- (void)openItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(open(item:));
- (void)playVideoForItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(playVideo(for:));
- (void)changeQuantityForItem:(PPUniversalCellViewModel *)viewModel
                     quantity:(NSInteger)quantity
    NS_SWIFT_NAME(changeQuantity(for:quantity:));
- (void)shareItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(share(item:));
- (void)editItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(edit(item:));
- (void)deleteItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(delete(item:));
- (void)toggleVisibilityForItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(toggleVisibility(for:));
- (void)chatAboutItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(chat(about:));
- (void)reportItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(report(item:));
- (void)toggleSaveForLaterForItem:(PPUniversalCellViewModel *)viewModel
    NS_SWIFT_NAME(toggleSaveForLater(for:));

- (void)screenWillAppear NS_SWIFT_NAME(screenWillAppear());
- (void)screenWillDisappear NS_SWIFT_NAME(screenWillDisappear());
- (void)screenDidShowEmptyState NS_SWIFT_NAME(screenDidShowEmptyState());
- (void)userDidBeginScrolling NS_SWIFT_NAME(userDidBeginScrolling());
- (void)userDidEndScrolling NS_SWIFT_NAME(userDidEndScrolling());
- (void)refreshPresentationState NS_SWIFT_NAME(refreshPresentationState());

@end

NS_ASSUME_NONNULL_END
