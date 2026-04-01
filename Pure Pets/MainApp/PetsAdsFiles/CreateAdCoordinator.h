//
//  CreateAdCoordinator.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 10/01/2026.
//


@interface CreateAdCoordinator : NSObject

@property (nonatomic, strong, readonly) PetAd *ad;
@property (nonatomic, assign, readonly) AdEditorMode mode;

- (instancetype)initForCreate;
- (instancetype)initForEdit:(PetAd *)ad;

// Entry point
- (UIViewController *)start;

// Actions from VC
- (void)updateDraft:(PetAd *)draft;
- (void)submitWithImages:(NSArray<UIImage *> *)images;

// Callbacks
@property (nonatomic, copy) void (^onFinish)(PetAd *ad);
@property (nonatomic, copy) void (^onCancel)(void);

@end