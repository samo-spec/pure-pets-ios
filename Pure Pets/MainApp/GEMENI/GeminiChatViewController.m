//
//  GeminiChatViewController 2.h
//  Pure Pets
//
//  Created by Mohammed Ahmed on 27/07/2025.
//


// GeminiChatViewController.m

#import "GeminiChatViewController.h"

@interface GeminiChatViewController ()

@property (nonatomic, strong) UITextField *inputTextView;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UITextView *responseTextView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) LOTAnimationView *loadingAnimation;
@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) LOTAnimationView *AiAnimation;
@property (nonatomic, strong) LOTAnimationView *AiButton;

@end

@implementation GeminiChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    //self.title = @"Pure Pets Support";
    self.view.backgroundColor = PPBackgroundColorForIOS26(GM.backOffwhileColor);

    
    [AppClasses setTitle:@"Pure Pets" onController:self backgroundColor:GM.AppForegroundColor align:titleAlignRigth masked:kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner];
    self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
    
  
    /*
     @property (nonatomic, strong) LOTAnimationView *ActivityLoadingAnimationView;
     self.ActivityLoadingAnimationView =  [[LOTAnimationView alloc] init];
     self.ActivityLoadingAnimationView.frame = CGRectMake(self.view.centerX - 90, 100, 180, 180); // Adjust as needed
     self.ActivityLoadingAnimationView.contentMode = UIViewContentModeScaleAspectFill;
     self.ActivityLoadingAnimationView.loopAnimation = YES;
     //self.ActivityLoadingAnimationView.animationSpeed = .5;
     self.ActivityLoadingAnimationView.userInteractionEnabled = YES;
    // self.ActivityLoadingAnimationView.backgroundColor = UIColor.redColor;
     
     // Add tap gesture recognizer
    
    
     
     [self.view addSubview:self.ActivityLoadingAnimationView];
     [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/ActivityLoadingAnimation.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {

         dispatch_async(dispatch_get_main_queue(), ^{
             if (error) {
                 NSLog(@"Lottie --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                 return;
             }

             if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                 NSLog(@"Lottie --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                 return;
             }

             LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
             if (composition) {
                 [self.ActivityLoadingAnimationView setSceneModel:composition];
     [self.AiAnimation play];
             } else {
                 NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
             }
         });

     }];
     */
    
    
    
    self.AiAnimation =  [[LOTAnimationView alloc] init];
    self.AiAnimation.frame = CGRectMake(self.view.centerX - 90, 100, 180, 180); // Adjust as needed
    self.AiAnimation.contentMode = UIViewContentModeScaleAspectFill;
    self.AiAnimation.loopAnimation = YES;
    //self.registerAnimation.animationSpeed = .5;
    self.AiAnimation.userInteractionEnabled = YES;
   // self.registerAnimation.backgroundColor = UIColor.redColor;
    
    // Add tap gesture recognizer
   
   
    
    [self.view addSubview:self.AiAnimation];
    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/Ghostsmart.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {

        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Lottie --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                return;
            }

            if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                NSLog(@"Lottie --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                return;
            }

            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (composition) {
                [self.AiAnimation setSceneModel:composition];
                [self.AiAnimation play];
            } else {
                NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
            }
        });

    }];
    
    
    self.infoLabel =  [[UILabel alloc] initWithFrame:CGRectZero];
    self.infoLabel.numberOfLines = 0;
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.textColor = [UIColor labelColor];
    self.infoLabel.font = [GM fontWithSize:14];

    // Arabic text
    self.infoLabel.text = kLang(@"ask");

    // Add to your view
    [self.view addSubview:self.infoLabel];
    
    // Input field
    self.inputTextView = [[UITextField alloc] initWithFrame:CGRectZero];
    self.inputTextView.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
    self.inputTextView.font = [GM MidFontWithSize:14];
    self.inputTextView.backgroundColor = GM.AppForegroundColor;
    self.inputTextView.layer.borderWidth = 0.0;
    self.inputTextView.layer.cornerRadius = 22.0;
    self.inputTextView.placeholder = kLang(@"Askanythingaboutpets");
    
    // ✨ Optional shadow
    self.inputTextView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.inputTextView.layer.shadowOpacity = 0.1;
    self.inputTextView.layer.shadowOffset = CGSizeMake(0, 1);
    self.inputTextView.layer.shadowRadius = 3;

    // 🔠 Padding
    UIView *leftPadding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.inputTextView.leftView = leftPadding;
    self.inputTextView.leftViewMode = UITextFieldViewModeAlways;
    
    self.inputTextView.rightView = leftPadding;
    self.inputTextView.rightViewMode = UITextFieldViewModeAlways;
    
    [self.view addSubview:self.inputTextView];

    
    self.AiButton = [[LOTAnimationView alloc]init]; // replace with your JSON name
    self.AiButton.frame = CGRectMake(0, 0, 140, 140);
    self.AiButton.contentMode = UIViewContentModeScaleAspectFit;
    //self.loadingAnimation.hidden = YES;
    self.AiButton.loopAnimation = YES;
    self.AiButton.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sendPromptToGemini)];
    [self.AiButton addGestureRecognizer:tap];
    
    [self.view addSubview:self.AiButton];
    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/AiButton.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Lottie --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                return;
            }
            if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                NSLog(@"Lottie --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                return;
            }
            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (composition) {
                [self.AiButton setSceneModel:composition];
                [self.AiButton play];
            } else {
                NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
            }
        });
    }];
    
  
    // Response view
    self.responseTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.responseTextView.font = [GM MidFontWithSize:16];
    self.responseTextView.editable = NO;
    self.responseTextView.layer.borderColor = [UIColor systemGray4Color].CGColor;
    self.responseTextView.layer.borderWidth = 0.0;
    self.responseTextView.layer.cornerRadius = 25.0;
    self.responseTextView.backgroundColor = UIColor.whiteColor;
    self.responseTextView.textAlignment = [Language languageVal] == 0 ? NSTextAlignmentLeft : NSTextAlignmentRight;
    
    // ✨ Optional shadow
    self.responseTextView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.responseTextView.layer.shadowOpacity = 0.1;
    self.responseTextView.layer.shadowOffset = CGSizeMake(0, 1);
    self.responseTextView.layer.shadowRadius = 3;
    self.responseTextView.textColor = [UIColor darkGrayColor];
    
    [self.view addSubview:self.responseTextView];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    
    //AiButton
    self.loadingAnimation = [[LOTAnimationView alloc] init]; // replace with your JSON name
    self.loadingAnimation.frame = CGRectMake(-10, -10, 160, 160);
    self.loadingAnimation.contentMode = UIViewContentModeScaleAspectFit;
    //self.loadingAnimation.hidden = YES;
    self.loadingAnimation.loopAnimation = YES;
    [self.view addSubview:self.loadingAnimation];
    
    [AppClasses fetchLottieJSONFromFirebasePath:@"LottieAnimations/Ai_loadingModel.json" completion:^(NSDictionary * _Nonnull jsonDict, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Lottie --- >>> ❌ Failed to fetch Lottie JSON: %@", error.localizedDescription);
                return;
            }
            if (!jsonDict || ![jsonDict isKindOfClass:[NSDictionary class]]) {
                NSLog(@"Lottie --- >>> ❌ Invalid or nil JSON dictionary for Lottie");
                return;
            }
            LOTComposition *composition = [LOTComposition animationFromJSON:jsonDict];
            if (composition) {
                [self.loadingAnimation setSceneModel:composition];
               // [self.loadingAnimation play];
            } else {
                NSLog(@"Lottie --- >>> ❌ Failed to create LOTComposition from JSON");
            }
        });
    }];
    
    
   
    
    
    [self layoutViews];
}


- (void)animateTextTypewriterStyle:(NSString *)fullText {
    self.responseTextView.text = @""; // clear old content
    self.responseTextView.hidden = NO;

    __block NSUInteger charIndex = 0;
    NSUInteger totalLength = fullText.length;
    NSTimeInterval typingSpeed = 0.03; // seconds per character

    __weak typeof(self) weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (charIndex < totalLength) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *partialText = [fullText substringToIndex:charIndex + 1];
                weakSelf.responseTextView.text = partialText;

                // Scroll to bottom
                [weakSelf.responseTextView scrollRangeToVisible:NSMakeRange(partialText.length, 0)];
            });

            [NSThread sleepForTimeInterval:typingSpeed];
            charIndex++;
        }
    });
}


- (void)showResponseTextLineByLine:(NSString *)responseText {
    self.responseTextView.text = @"";
    self.responseTextView.hidden = NO;
    
    NSArray<NSString *> *lines = [responseText componentsSeparatedByString:@"\n"];
    __block NSInteger currentLine = 0;

    NSTimeInterval lineDelay = 0.4; // time between lines

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSString *line in lines) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(lineDelay * currentLine * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (currentLine == 0) {
                    weakSelf.responseTextView.text = line;
                } else {
                    weakSelf.responseTextView.text = [weakSelf.responseTextView.text stringByAppendingFormat:@"\n%@", line];
                }

                // Scroll to bottom
                [weakSelf.responseTextView scrollRangeToVisible:NSMakeRange(weakSelf.responseTextView.text.length, 0)];
            });
            currentLine++;
        }
    });
}



- (void)layoutViews {
    CGFloat padding = 16;
    
    
    self.infoLabel.frame = CGRectMake(padding, GM.navBarPadding + 10, self.view.frame.size.width - 2 * padding, 44);
    self.inputTextView.frame = CGRectMake(padding , self.infoLabel.hx_maxy , self.view.frame.size.width - (2 * padding)  , 44);
    self.AiButton.frame = CGRectMake(padding - 3, self.infoLabel.hx_maxy - 3, 50, 50);
    self.responseTextView.frame = CGRectMake(padding, CGRectGetMaxY(self.AiButton.frame) + 10, self.view.frame.size.width - 2 * padding, self.view.frame.size.height - CGRectGetMaxY(self.AiButton.frame) - GM.bottomPadding);
    
    self.loadingAnimation.frame = CGRectMake(0, 0, 150,150);
    self.spinner.center = CGPointMake(CGRectGetMidX(self.view.frame), CGRectGetMidY(self.view.frame));
    self.loadingAnimation.center = self.responseTextView.center;
    self.sendButton.layer.cornerRadius = 22;
    self.AiAnimation.center = self.responseTextView.center;
    [self.view bringSubviewToFront:self.AiAnimation];
    [self.view bringSubviewToFront:self.AiButton];
}




- (void)sendPromptToGemini {
    NSString *prompt = self.inputTextView.text;
    if (prompt.length == 0) {
        self.responseTextView.text = @"Ask anything about pets";
        return;
    }

    [self.inputTextView resignFirstResponder];
    [self.loadingAnimation play];
    self.loadingAnimation.hidden = NO;
    self.AiAnimation.hidden = YES;
    //[self.spinner startAnimating];
    self.responseTextView.text = @"";

    [GM sendPromptToGemini:prompt completion:^(NSString *responseText, NSError *error) {
        if (responseText) {
            NSLog(@"Gemini Response: %@", responseText);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                if (error) {
                    self.responseTextView.text = [NSString stringWithFormat:@"❌ Error: %@", error.localizedDescription];
                } else {
                    //self.responseTextView.text = responseText;
                    [self.loadingAnimation stop];
                    self.loadingAnimation.hidden = YES;
                    
                    [self showResponseTextLineByLine:responseText];
            
                }
            });
                
        } else {
            NSLog(@"❌ Error GM: %@", error.localizedDescription);
        }
    }];
    
    
}

@end
