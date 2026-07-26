//
//  ViewerVC.m
//  Pure Pets
//
//  Created by Mohammed Ahmed on 25/05/2025.
//

#import "AccessViewerVC.h"

#import "PPAccessoryViewerLegacyBridge.h"
#import "PetAccessory.h"
#import "PetAdManager.h"
#import "SellerProfileVC.h"
#import "UIViewController+PPBottomSurface.h"
#import <Pure_Pets-Swift.h>

@interface AccessViewerVC () <SellerProfileVCDelegate>
@property (nonatomic, strong) PPAccessoryViewerHostingController *swiftUIViewerController;
@property (nonatomic, strong, nullable) NSNumber *previousNavigationBarHidden;
@property (nonatomic, assign) BOOL didTrackViewInteraction;
@end

@implementation AccessViewerVC

#pragma mark - Bottom Surface

- (PPBottomSurfaceKind)pp_preferredBottomSurfaceKind
{
    return PPBottomSurfaceKindNone;
}

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.additionalSafeAreaInsets = UIEdgeInsetsZero;
    
    self.view.clipsToBounds = YES;
    [self pp_installSwiftUIAccessoryViewer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] setSuppressedForCriticalFlow:YES];
    if (!self.previousNavigationBarHidden) {
        self.previousNavigationBarHidden =
            @(self.navigationController.isNavigationBarHidden);
    }
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    [self pp_applyBottomSurfaceAnimated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!self.didTrackViewInteraction) {
        self.didTrackViewInteraction = YES;
        [PPAccessoryViewerLegacyBridge trackInteractionCode:PPItemInteractionTypeView
                                               forAccessory:self.accessAds];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] hideNova];
    [[NovaAmbientAssistantCoordinator sharedCoordinator] setSuppressedForCriticalFlow:NO];
    if (self.previousNavigationBarHidden) {
        [self.navigationController setNavigationBarHidden:self.previousNavigationBarHidden.boolValue
                                                 animated:animated];
        self.previousNavigationBarHidden = nil;
    }
}

#pragma mark - SwiftUI Host

- (void)pp_installSwiftUIAccessoryViewer
{
    if (self.swiftUIViewerController) {
        return;
    }

    PPAccessoryViewerHostingController *viewer =
        [[PPAccessoryViewerHostingController alloc] initWithAccessory:self.accessAds
                                                            presenter:self];
    self.swiftUIViewerController = viewer;
    [self addChildViewController:viewer];
    viewer.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:viewer.view];
    [NSLayoutConstraint activateConstraints:@[
        [viewer.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [viewer.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [viewer.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [viewer.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [viewer didMoveToParentViewController:self];
}

#pragma mark - Seller Profile Delegate

- (void)sellerProfileDidTapContact:(UserModel *)seller
{
    if (!seller || !self.accessAds) {
        return;
    }
    [PPAccessoryViewerLegacyBridge chatWithOwner:seller
                                       accessory:self.accessAds
                              fromViewController:self];
}

- (void)sellerProfileDidTapCall:(UserModel *)seller
{
    if (!seller || !self.accessAds) {
        return;
    }
    [PPAccessoryViewerLegacyBridge callOwner:seller
                                   accessory:self.accessAds
                          fromViewController:self];
}

- (void)sellerProfileDidSelectItem:(id)item
{
    if (![item isKindOfClass:PetAccessory.class]) {
        return;
    }

    PetAccessory *accessory = (PetAccessory *)item;
    NSString *currentID = self.accessAds.accessoryID ?: @"";
    NSString *nextID = accessory.accessoryID ?: @"";
    if (currentID.length > 0 && [currentID isEqualToString:nextID]) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    AccessViewerVC *viewer = [[AccessViewerVC alloc] init];
    viewer.accessAds = accessory;
    viewer.QtyDelegate = self.QtyDelegate;
    viewer.ParentVC = self;
    viewer.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:viewer animated:YES];
}

@end
