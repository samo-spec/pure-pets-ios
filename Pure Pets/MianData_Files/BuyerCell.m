//
//  CardsCell.m
//  collevtionViewWithSearchBar
//
//  Created by Homam on 2015-01-02.
//  Copyright (c) 2015 Homam. All rights reserved.
//

#import "BuyerCell.h"
#import "PPMenuHelper.h"

static const CGFloat kShadowOpacityCell = 0.1;
static const CGFloat kShadowRadiusCell = 5.0;
static const CGSize kShadowOffsetCell = {0, 2};

@implementation BuyerCell

-(AppDelegate *)AppDelegate { return (AppDelegate*)[[UIApplication sharedApplication]delegate]; }

-(void)Buyercall:(BuyerModel *)b_model
{
    [self makePhoneCallToNumber:b_model.buyerMobile];
}

-(void)BuyerWhatsAppMessage:(BuyerModel *)b_model
{
    [self sendWhatsAppMessageToNumber:b_model.buyerMobile withMessage:@""];
}

-(void)showDetails:(BuyerModel *)b_model cardModel:(CardModel *)cardModel
{
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];

    viewDataVC *add = [viewDataVC  new];
    add.cardModel = cardModel;
    
    PPNavigationController *nav = [[PPNavigationController alloc] initWithRootViewController:add];
    [AppMgr.topViewController presentViewController:nav animated:YES completion:nil];
}

-(void)returnCard:(BuyerModel *)b_model buyerCell:(BuyerCell *)buyerCell
{
    
   // [buyerCell.uploadProgressView startAnimating];
   // return;
    
    [PPAlertHelper showConfirmationIn:AppMgr.topViewController title:kLang(@"returnCard") subtitle:kLang(@"returnSelledCard") confirmButton:kLang(@"yes") cancelButton:kLang(@"no") icon:[UIImage imageNamed:@"Return"] confirmBlock:^(NSString * _Nullable text,
                                                                                                                                                                                                                     BOOL didConfirm) {
        if(!didConfirm)return;
        
        [buyerCell.uploadProgressView startAnimating];
        // Up
        // Update Cards
        NSDictionary *updates = @{
            @"isSold": @(0),
        };
        CardModel *careToReturn = [CardModel getCardForID:b_model.birdID];
       
        if(!careToReturn){
            NSLog(@"Card Not Found");
            
            [BuyerModel deleteBuyerWithDocumentID:b_model.ID completion:^(NSError * _Nullable error) {
                [buyerCell.uploadProgressView stopAnimating];
                NSLog(@"Bird Returned successfully!");
            }];
            
            //buyerCell.uploadProgressView stopAnimating];
            //return;
        }
        [careToReturn updateCardWithID:careToReturn.ID updateDictionary:updates completion:^(NSError * _Nullable error) {
            if(error) {
                NSLog(@"error %@", error);
            } else {
                
                NSLog(@"Card updated successfully!");
                [b_model updateCageIsSoldForCard:careToReturn withValue:0 completionHandler:^(int result) {
                    NSLog(@"Gage updated successfully!");
                }];
                
                [b_model updateArchiveIsSoldForCard:careToReturn withValue:0 completionHandler:^(int result) {
                    NSLog(@"Archive updated successfully!");
                }];
                
                [BuyerModel deleteBuyerWithDocumentID:b_model.ID completion:^(NSError * _Nullable error) {
                    NSLog(@"Bird Returned successfully!");
                }];
                                
                [buyerCell.uploadProgressView stopAnimating];
                [[AppManager sharedInstance] showSnakBar:kLang(@"Retutn_Compelete") withColor:[GM appPrimaryColor] andDuration:5 containerView:self.topView];
            }
           
        }];
    } cancelBlock:^{
        
    }];
   
   
}

- (void)setupActionsMenu {
    if (@available(iOS 14.0, *)) {
        __weak typeof(self) weakSelf = self;

        NSArray *titles = @[
            kLang(@"Details"),
            kLang(@"Call"),
            kLang(@"WhatsApp"),
            kLang(@"printBill"),
            kLang(@"Return")
        ];
       
        NSArray *icons = @[
            [UIImage systemImageNamed:@"doc.text.magnifyingglass"] ?: [UIImage new],
            [UIImage systemImageNamed:@"phone"] ?: [UIImage new],
            [UIImage systemImageNamed:@"message"] ?: [UIImage new],
            [UIImage systemImageNamed:@"printer.inverse"] ?: [UIImage new],
            [UIImage systemImageNamed:@"arrow.uturn.left"] ?: [UIImage new]
        ];

        NSIndexSet *destructive = [NSIndexSet indexSetWithIndex:4];

        [PPMenuHelper presentMenuFromButton:self.cardDetailsBTN
                                     titles:titles
                                     images:icons
                               destructive:destructive
                                   handler:^(NSInteger index, NSString *title) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            switch (index) {
                case 0: // Details
                    [self showDetails:self.B_model cardModel:self.cardModel];
                    break;
                case 1: // Call
                    [self Buyercall:self.B_model];
                    break;
                case 2: // WhatsApp
                    [self BuyerWhatsAppMessage:self.B_model];
                    break;
                case 3: // WhatsApp
                    [self.delegate exportSalesBillForBuyer:self.B_model card:self.cardModel  sender:self.cardDetailsBTN];
                    break;
                case 4: // Return
                    [self returnCard:self.B_model buyerCell:self];
                    break;
            }
        }];
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = AppForgroundColr;
    self.contentView.clipsToBounds = NO;

    // Main container rounding
    self.contentView.layer.cornerRadius = 32;

    // Top banner
    self.topView.layer.cornerRadius = 16;
    self.topView.clipsToBounds = YES;

    // Shadow
    [GM setShadow:self
         sh_Color:[GM AppShadowColor]
          cGSize:kShadowOffsetCell
      sh_Opacity:kShadowOpacityCell
          radius:kShadowRadiusCell];

    // Fonts
    self.cardTitleLabel.font   = [GM boldFontWithSize:16];
    self.buyerNameLabel.font   = [GM MidFontWithSize:14];
    self.mobileNumberLabel.font = [GM MidFontWithSize:14];
    self.cellDateLabel.font     = [GM MidFontWithSize:14];
    self.RingIDLabel.font       = [GM MidFontWithSize:14];
    self.cellAmountLabel.font   = [GM MidFontWithSize:14];

    // BUTTON: Details


    // Shadow for button
    self.cardDetailsBTN = [PPButtonHelper buttonWithSystemName:@"list.bullet" target:self action:@selector(setupActionsMenu)];
    self.cardDetailsBTN.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.cardDetailsBTN];

    
    
    
    self.cardDetailsBTN.layer.shadowOffset  = CGSizeMake(1, 1);
    self.cardDetailsBTN.layer.shadowOpacity = 0.5;
    self.cardDetailsBTN.layer.shadowRadius  = 2;

    [self setupActionsMenu];

    // -------------------------------
    // MAIN IMAGE VIEW
    // -------------------------------
    self.mainImageView= [UIImageView new];
    self.mainImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainImageView.layer.cornerRadius = 22;
    self.mainImageView.clipsToBounds = YES;
    [self.contentView addSubview:self.mainImageView];
    self.mainImageView.contentMode = UIViewContentModeScaleAspectFill;
   
    // -------------------------------
    // MAIN IMAGE VIEW CONSTRAINTS
    // -------------------------------
    [NSLayoutConstraint activateConstraints:@[
        [self.mainImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [self.mainImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.mainImageView.widthAnchor constraintEqualToConstant:self.contentView.hx_w/3 + 40],
        [self.mainImageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
    ]];


    // -------------------------------
    // PROGRESS BAR
    // -------------------------------
    GSIndeterminateProgressView *progressView =
        [[GSIndeterminateProgressView alloc] initWithFrame:CGRectMake(0, self.topView.hx_y, self.contentView.hx_w, 4)];
    progressView.progressTintColor = [GM appPrimaryColor];
    progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    progressView.backgroundColor = UIColor.whiteColor;
    [self.contentView addSubview:progressView];
    self.uploadProgressView = progressView;

  
    [NSLayoutConstraint activateConstraints:@[
        [_cardDetailsBTN.trailingAnchor constraintEqualToAnchor:self.mainImageView.trailingAnchor constant:-12],
        [_cardDetailsBTN.topAnchor constraintEqualToAnchor:self.mainImageView.topAnchor constant:12],
        [_cardDetailsBTN.heightAnchor constraintEqualToConstant:40],
        [_cardDetailsBTN.widthAnchor constraintEqualToConstant:40],
    ]];
}

  
-(void)layoutSubviews
{
    [super layoutSubviews];
    self.uploadProgressView.hx_x = 0;
    self.uploadProgressView.hx_y = 0;
    
    [self.contentView bringSubviewToFront:_cardDetailsBTN];
}

- (IBAction)shareBTN:(id)sender{
    [self.delegate shareCard:_cardModel andImage:_mainImageView.image];
}










- (void)makePhoneCallToNumber:(NSString *)phoneNumber {
    // Format phone number to remove spaces and special characters
    NSString *formattedNumber = [[phoneNumber componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    // Create tel URL
    NSString *phoneURLString = [NSString stringWithFormat:@"tel:%@", formattedNumber];
    NSURL *phoneURL = [NSURL URLWithString:phoneURLString];

    // Check if the device can make calls
    if ([[UIApplication sharedApplication] canOpenURL:phoneURL]) {
        [[UIApplication sharedApplication] openURL:phoneURL options:@{} completionHandler:nil];
    } else {
        NSLog(@"Phone call not supported on this device.");
    }
}

- (void)sendWhatsAppMessageToNumber:(NSString *)phoneNumber withMessage:(NSString *)message {
    // Ensure phone number is in international format (without + or special characters)
    NSString *formattedNumber = [phoneNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
    formattedNumber = [formattedNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // Encode message to be URL-safe
    NSString *encodedMessage = [message stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Create WhatsApp URL
    NSString *whatsappURLString = [NSString stringWithFormat:@"whatsapp://send?phone=%@&text=%@", formattedNumber, encodedMessage];
    NSURL *whatsappURL = [NSURL URLWithString:whatsappURLString];

    // Check if WhatsApp is installed
    if ([[UIApplication sharedApplication] canOpenURL:whatsappURL]) {
        [[UIApplication sharedApplication] openURL:whatsappURL options:@{} completionHandler:nil];
    } else {
        NSLog(@"WhatsApp is not installed on this device.");
    }
}
 
@end
