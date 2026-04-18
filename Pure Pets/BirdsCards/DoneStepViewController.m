//
//  RMStepViewController.m
//  RMStepsController-Demo
//
//  Created by Roland Moers on 14.11.13.
//  Copyright (c) 2013 Roland Moers
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "DoneStepViewController.h"
#import "FFLoadingView.h"
#import <AVFoundation/AVFoundation.h>
#import "AppDelegate.h"

static const CGFloat kPhotoViewMargin = 12.0;

@interface DoneStepViewController ()
{
    AVAudioPlayer *_audioPlayer;
}
@property (strong, nonatomic) FFLoadingView *loadingView;
@property (nonatomic, assign) BOOL didBuildLayout;

@end

@implementation DoneStepViewController


-(AppDelegate *)AppDelegate
{
    return (AppDelegate*)[[UIApplication sharedApplication]delegate];
}

-(void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
}

#pragma mark - Programmatic UI

- (void)setupViews
{
    if (self.didBuildLayout) return;
    self.didBuildLayout = YES;

    // -- topLabel --
    self.topLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.topLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.topLabel.textAlignment = NSTextAlignmentCenter;
    self.topLabel.numberOfLines = 0;
    [self.view addSubview:self.topLabel];

    // -- EndBTN --
    self.EndBTN = [UIButton buttonWithType:UIButtonTypeSystem];
    self.EndBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [self.EndBTN setTitle:kLang(@"done") forState:UIControlStateNormal];
    [self.EndBTN setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.EndBTN.backgroundColor = [GM appPrimaryColor];
    self.EndBTN.titleLabel.font = [GM boldFontWithSize:16];
    [self.EndBTN addTarget:self action:@selector(finishBTN:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.EndBTN];
}

- (void)setupConstraints
{
    CGFloat btnHeight = 50.0;
    CGFloat btnWidth  = 200.0;

    [NSLayoutConstraint activateConstraints:@[
        // topLabel: centered horizontally, placed below loading view area
        [self.topLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:300],
        [self.topLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.topLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // EndBTN: centered, fixed size, below topLabel
        [self.EndBTN.topAnchor constraintEqualToAnchor:self.topLabel.bottomAnchor constant:40],
        [self.EndBTN.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.EndBTN.widthAnchor constraintEqualToConstant:btnWidth],
        [self.EndBTN.heightAnchor constraintEqualToConstant:btnHeight],
    ]];

    self.EndBTN.layer.cornerRadius = btnHeight / 2.0;
}

-(void)viewDidLoad
{
    [super viewDidLoad];

    [self setupViews];
    [self setupConstraints];

    NSString * languag = [[NSLocale preferredLanguages] firstObject];
    NSString *Lang = [languag substringToIndex:2];
    
    //NSLog(@"2222222222");
    
    self.loadingView = [[FFLoadingView alloc] initWithFrame:CGRectMake([UIScreen mainScreen].bounds.size.width/2-60, 150, 120, 120)];
    self.loadingView.lineWidth = 7;
    self.loadingView.strokeColor = [GM appPrimaryColor];
    self.loadingView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.loadingView];
   //NSLog(@"33333333333");
    self.navigationItem.hidesBackButton = YES;
    
    // Set TXT Filed Style
    if([Lang isEqualToString:@"ar"])
    {
       
        //_DescTXT.text= @"في حالة اختيار بيانات غير صحيحة سيتم تصحيح البيانات او الغاء الاعلان";
        //[_NewAdBTN setTitle:@"اضافة اعلان اخر" forState:UIControlStateNormal];
        //[_EndBTN setTitle:@"انهاء" forState:UIControlStateNormal];
        //delNTFTile = @"الاعلان تحت المراجعة";
        //delNTFDesc = @"سيتم اخطارك في حاله قبول و نشر الاعلان";
    }
    else
    {
        // delNTFTile = @"Ad is under review";
        // delNTFDesc = @"You will be notified if the ad is accepted and published";
        
        //_DescTXT.text= @"If incorrect data is selected, the data will be corrected or the advertisement will be canceled";
        //[_NewAdBTN setTitle:@"Add another ad" forState:UIControlStateNormal];
        // [_EndBTN setTitle:@"End" forState:UIControlStateNormal];
    }
    //NSLog(@"4444444444");
    
    
    
    
    _topLabel.text = kLang(@"saveDone");
    
    [self.EndBTN pp_setShadowColor:[UIColor lightGrayColor]];
    self.EndBTN.layer.masksToBounds = NO;
    self.EndBTN.layer.cornerRadius =CGRectGetHeight( self.EndBTN.frame)/2;
    self.EndBTN.alpha = 0;
    
    _topLabel.font = [GM boldFontWithSize:18];
    
}
- (void)finishBTN:(id)sender {
    //[self.delegate getDataWithCondition:0 andLoadIndicator:nil];
    //[self.stepsController finishedAllSteps];
    // [add dismissModalViewControllerAnimated:YES];
    if([_FromVC isEqual:@"Cards"])
    {
        
        [self dismissViewControllerAnimated:YES completion:^{
            [self.delegate addedDone];
        }];
         //[add reloadNewData];
         return;
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:^{
            [self.delegate addedDone];
        }];
        return;
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [self changeStatus];
    [self.loadingView finishSuccess:^{
        [UIView animateWithDuration:2.0 animations:^(void) {
            self.EndBTN.alpha = 1;
        }];
    }];
    
    [PPFunc triggerLightHaptic];
    
    //[iSnackBar snackBarWithMessage:delNTFDesc font:[UIFont systemFontOfSize:16] backgroundColor: [(AppDelegate*)[[UIApplication sharedApplication]delegate]AppColorSec:0.9f] textColor: [(AppDelegate*)[[UIApplication sharedApplication]delegate]myTextColor:1.0f] duration:4.0];
    
    //[TSMessage setDelegate:self];
    //[TSMessage showNotificationWithTitle:delNTFTile
     //                          subtitle:delNTFDesc
    //                                type:TSMessageNotificationTypeSuccess] ;
    
    //NSString *txt =@"تمت اضافة اعلان عقارات جديد ، يجب مراجعة وتحديد حالة الاعلان" ;
    //[OneSignal postNotification:@{
    //   @"contents" : @{@"en": txt},
    //   @"app_id":@"be0eefc9-52f3-4a1a-b36d-7e29f0130b11",
    //   @"include_player_ids": @[@"d3a26528-3b35-421d-8b52-583fdaecde10"]
    //}];
}



- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
   
    [self changeStatus];
    
}

- (void)setShadowToView:(UIView *)vName rds:(float)rds
{
    vName.clipsToBounds = NO;
    vName.layer.masksToBounds = NO;
    [vName pp_setShadowColor:[UIColor lightGrayColor]];
    vName.layer.shadowRadius = 1;
    vName.layer.shadowOpacity = 1;
    vName.layer.shadowOffset = CGSizeMake(0.0,0);
    vName.layer.cornerRadius = rds;
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
- (void)changeStatus {
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            //[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
            return;
        }
    }
#endif
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}


@end
