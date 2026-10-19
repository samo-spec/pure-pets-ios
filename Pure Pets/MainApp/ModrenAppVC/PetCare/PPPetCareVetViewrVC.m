//
//  PPPetCareVetViewrVC.m
//  Pure Pets
//
//  UIKit navigation and action owner for the SwiftUI care introductions.
//

#import "PPPetCareVetViewrVC.h"
#import "VetModel.h"
#import "GM.h"
#import "Language.h"
#import "MainKindsModel.h"
#import "MainKindsArrayManager.h"
#import "PPAlertHelper.h"
#import <Pure_Pets-Swift.h>

@interface PPPetCareVetViewrVC ()
@property (nonatomic, strong) VetModel *vet;
@property (nonatomic, copy, nullable) NSString *mainKindName;
@property (nonatomic, strong) PPVetViewerHostingController *hostingController;
@property (nonatomic, assign) BOOL previousNavBarHidden;
@property (nonatomic, assign) BOOL openingContact;
@end

@implementation PPPetCareVetViewrVC

- (instancetype)initWithVet:(VetModel *)vet mainKindName:(nullable NSString *)mainKindName
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _vet = vet;
        _mainKindName = [mainKindName copy];
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.ppBackground;
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pp_presentationDidChange:)
                                              name:PPLanguageDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pp_presentationDidChange:)
                                              name:PPMainKindsUpdatedNotification object:nil];

    PPVetViewerContent *content = [self pp_buildPresentationContent];

    __weak typeof(self) weakSelf = self;
    _hostingController = [[PPVetViewerHostingController alloc] initWithContent:content
                                                                        onCall:^{
        [weakSelf pp_callTapped];
    } onWhatsApp:^{
        [weakSelf pp_whatsappTapped];
    } onShare:^{
        [weakSelf pp_shareTapped];
    } onDismiss:^{
        [weakSelf pp_dismissTapped];
    }];

    [self addChildViewController:_hostingController];
    _hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_hostingController.view];

    [NSLayoutConstraint activateConstraints:@[
        [_hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [_hostingController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self pp_refreshPresentation];
    if (self.navigationController) {
        self.previousNavBarHidden = self.navigationController.navigationBarHidden;
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.navigationController) {
        [self.navigationController setNavigationBarHidden:self.previousNavBarHidden animated:animated];
    }
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)pp_presentationDidChange:(NSNotification *)notification
{
    if (NSThread.isMainThread) {
        [self pp_refreshPresentation];
    } else {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf pp_refreshPresentation]; });
    }
}

- (void)pp_refreshPresentation
{
    self.view.semanticContentAttribute = [Language semanticAttributeForCurrentLanguage];
    [self.hostingController updateWithContent:[self pp_buildPresentationContent]];
}

#pragma mark - Content Builder

- (PPVetViewerContent *)pp_buildPresentationContent
{
    PPVetViewerContent *content = [[PPVetViewerContent alloc] init];
    content.vetID = self.vet.vetID ?: @"";
    content.title = self.vet.title ?: @"";
    content.isCompany = (self.vet.type == VetTypeCompany);
    content.logoURL = self.vet.logoURL ?: @"";
    content.descriptionText = self.vet.descriptionText ?: @"";
    content.phone = self.vet.phone ?: @"";
    content.whatsapp = self.vet.whatsapp ?: @"";
    content.vetCost = self.vet.vetCost;
    content.readyToContact = self.vet.readyToContact;
    content.isDisabled = self.vet.isDisabled;
    content.verificationStatus = self.vet.verificationStatus ?: @"";
    content.subscriptionActive = self.vet.subscriptionActive;
    content.subscriptionTier = self.vet.subscriptionTier;
    content.availableDate = self.vet.availableDate;

    NSArray<MainKindsModel *> *kinds = [[MainKindsArrayManager shared] visibleMainKindsSnapshot];
    content.mainKindName = @"";
    for (MainKindsModel *kind in kinds) {
        if (kind.ID == self.vet.petMainKindID && kind.ID > 0) {
            content.mainKindName = [self pp_nameForKind:kind];
            break;
        }
    }
    if (content.mainKindName.length == 0 && self.vet.petMainKindID > 0) {
        content.mainKindName = self.mainKindName ?: @"";
    }

    NSMutableArray<NSString *> *species = [NSMutableArray array];
    for (id value in self.vet.animalTypes) {
        NSString *raw = [value isKindOfClass:NSString.class] ? value :
            ([value isKindOfClass:NSNumber.class] ? [value stringValue] : @"");
        NSString *name = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) continue;
        BOOL isIdentifier = [name rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
        NSString *resolved = isIdentifier ? @"" : name;
        for (MainKindsModel *kind in kinds) {
            if ((isIdentifier && kind.ID == name.integerValue) ||
                (kind.KindNameAr.length > 0 && [kind.KindNameAr caseInsensitiveCompare:name] == NSOrderedSame) ||
                (kind.KindNameEn.length > 0 && [kind.KindNameEn caseInsensitiveCompare:name] == NSOrderedSame)) {
                resolved = [self pp_nameForKind:kind];
                break;
            }
        }
        if (resolved.length > 0 && ![species containsObject:resolved]) [species addObject:resolved];
    }
    content.animalTypes = species;
    content.cityID = self.vet.cityID ?: @"";
    content.cityName = self.vet.cityName ?: @"";
    content.workingAreas = self.vet.workingAreas ?: @[];
    content.address = self.vet.address ?: @"";
    content.licenseNumber = self.vet.licenseNumber ?: @"";
    content.workingHours = self.vet.workingHours ?: @"";
    content.emergency247 = self.vet.emergency247;
    content.homeVisitAvailable = self.vet.homeVisitAvailable;

    return content;
}


- (NSString *)pp_nameForKind:(MainKindsModel *)kind
{
    NSString *preferred = [Language isRTL] ? kind.KindNameAr : kind.KindNameEn;
    NSString *fallback = [Language isRTL] ? kind.KindNameEn : kind.KindNameAr;
    return preferred.length > 0 ? preferred : (fallback ?: @"");
}

#pragma mark - Actions

- (void)pp_dismissTapped
{
    if (self.navigationController && self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (BOOL)pp_canContact
{
    return [PPVetContactRouting isContactAllowedWithStatus:self.vet.verificationStatus ?: @""
                                                disabled:self.vet.isDisabled];
}

- (void)pp_callTapped
{
    if (![self pp_canContact]) return;
    [self pp_openContactURL:[PPVetContactRouting callURLWithPhone:self.vet.phone ?: @""
                                                       whatsapp:self.vet.whatsapp ?: @""]];
}

- (void)pp_whatsappTapped
{
    if (![self pp_canContact]) return;
    [self pp_openContactURL:[PPVetContactRouting whatsAppURLWithPhone:self.vet.phone ?: @""
                                                           whatsapp:self.vet.whatsapp ?: @""]];
}

- (void)pp_openContactURL:(NSURL *)url
{
    if (self.openingContact || self.presentedViewController) return;
    if (!url || ![UIApplication.sharedApplication canOpenURL:url]) {
        [self pp_showContactError];
        return;
    }
    self.openingContact = YES;
    __weak typeof(self) weakSelf = self;
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.openingContact = NO;
            if (!success && self.viewIfLoaded.window) [self pp_showContactError];
        });
    }];
}

- (void)pp_showContactError
{
    if (self.presentedViewController) return;
    [PPAlertHelper showWarningIn:self
                          title:[PPVetDetailLocalization textForKey:@"vet_detail_contact_error_title"]
                       subtitle:[PPVetDetailLocalization textForKey:@"vet_detail_contact_error_body"]];
}

- (void)pp_shareTapped
{
    if (self.presentedViewController || ![self pp_canContact]) return;
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    PPVetViewerContent *content = [self pp_buildPresentationContent];
    NSString *title = content.title.length > 0 ? content.title :
        [PPVetDetailLocalization textForKey:content.isCompany ? @"vet_detail_clinic" : @"vet_detail_doctor"];
    if (title.length > 0) [parts addObject:title];
    if (content.descriptionText.length > 0) [parts addObject:content.descriptionText];
    NSString *phone = [PPVetContactRouting normalizedPhone:content.phone];
    NSString *whatsapp = [PPVetContactRouting normalizedPhone:content.whatsapp];
    if (phone.length > 0) {
        [parts addObject:[NSString stringWithFormat:[PPVetDetailLocalization textForKey:@"vet_detail_share_phone"], phone]];
    }
    if (whatsapp.length > 0 && ![whatsapp isEqualToString:phone]) {
        [parts addObject:[NSString stringWithFormat:[PPVetDetailLocalization textForKey:@"vet_detail_share_whatsapp"], whatsapp]];
    }
    NSString *shareText = [parts componentsJoinedByString:@"\n\n"];
    if (shareText.length == 0) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[shareText]
                                                                           applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    CGFloat x = [Language isRTL] ? 44.0 : MAX(44.0, CGRectGetWidth(self.view.bounds) - 44.0);
    activity.popoverPresentationController.sourceRect = CGRectMake(x, self.view.safeAreaInsets.top + 28.0, 1.0, 1.0);
    [self presentViewController:activity animated:YES completion:nil];
}

@end
