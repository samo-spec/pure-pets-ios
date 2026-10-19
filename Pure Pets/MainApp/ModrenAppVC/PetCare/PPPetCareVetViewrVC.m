//
//  PPPetCareVetViewrVC.m
//  Pure Pets
//
//  Reinvented from absolute first principles for NextGen V6 Flagship.
//  Category-defining clinical sanctuary details controller hosted in SwiftUI.
//

#import "PPPetCareVetViewrVC.h"
#import "VetModel.h"
#import "GM.h"
#import "Language.h"
#import <Pure_Pets-Swift.h>

@interface PPPetCareVetViewrVC ()
@property (nonatomic, strong) VetModel *vet;
@property (nonatomic, copy, nullable) NSString *mainKindName;
@property (nonatomic, strong) PPVetViewerHostingController *hostingController;
@property (nonatomic, assign) BOOL previousNavBarHidden;
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
    self.view.backgroundColor = UIColor.systemBackgroundColor;

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
        [_hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [_hostingController didMoveToParentViewController:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
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
    content.verificationStatus = self.vet.verificationStatus ?: @"";
    content.subscriptionActive = self.vet.subscriptionActive;
    content.subscriptionTier = self.vet.subscriptionTier;
    content.mainKindName = self.mainKindName ?: @"";

    if (self.vet.availableDate) {
        content.availableDateText = [GM formattedDate:self.vet.availableDate] ?: @"";
    }

    NSMutableArray<NSString *> *species = [NSMutableArray array];
    for (id val in self.vet.animalTypes) {
        if ([val isKindOfClass:NSString.class]) {
            NSString *clean = [(NSString *)val stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (clean.length > 0 && ![species containsObject:clean]) {
                [species addObject:clean];
            }
        }
    }
    content.animalTypes = species;

    return content;
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

- (void)pp_callTapped
{
    NSString *raw = self.vet.phone.length > 0 ? self.vet.phone : self.vet.whatsapp;
    NSString *clean = [self pp_digitsAndPlusFromString:raw];
    if (clean.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt:%@", clean]];
    if (url && [UIApplication.sharedApplication canOpenURL:url]) {
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    }
}

- (void)pp_whatsappTapped
{
    NSString *raw = self.vet.whatsapp.length > 0 ? self.vet.whatsapp : self.vet.phone;
    NSString *clean = [self pp_digitsAndPlusFromString:raw];
    if (clean.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://wa.me/%@", clean]];
    if (url && [UIApplication.sharedApplication canOpenURL:url]) {
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    }
}

- (void)pp_shareTapped
{
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.vet.title.length > 0) {
        [parts addObject:self.vet.title];
    }
    if (self.vet.descriptionText.length > 0) {
        [parts addObject:self.vet.descriptionText];
    }
    if (self.vet.phone.length > 0) {
        [parts addObject:[NSString stringWithFormat:@"Phone: %@", self.vet.phone]];
    }

    NSString *shareText = [parts componentsJoinedByString:@"\n\n"];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[shareText]
                                                                           applicationActivities:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        activity.popoverPresentationController.sourceView = self.view;
        activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), 60.0, 1.0, 1.0);
    }
    [self presentViewController:activity animated:YES completion:nil];
}

- (NSString *)pp_digitsAndPlusFromString:(NSString *)rawNumber
{
    if (rawNumber.length == 0) {
        return @"";
    }
    NSMutableString *clean = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"+0123456789"];
    for (NSUInteger idx = 0; idx < rawNumber.length; idx++) {
        unichar ch = [rawNumber characterAtIndex:idx];
        if ([allowed characterIsMember:ch]) {
            [clean appendFormat:@"%C", ch];
        }
    }
    return clean.copy;
}

@end
